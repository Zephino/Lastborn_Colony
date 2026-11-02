## The steps before landing: briefing, planet, the ship's manifest (what to
## bring, bought on credit), and the landing site. Emits `finished` with the
## options for NewGame.create, or `cancelled` to go back to the title.
extends Control

const GameData = preload("res://scripts/sim/game_data.gd")
const Manifest = preload("res://scripts/sim/manifest.gd")
const MapGen = preload("res://scripts/sim/map_gen.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
const ProbeView = preload("res://scripts/ui/probe_view.gd")
const Probe = preload("res://scripts/sim/probe.gd")
const UiUtil = preload("res://scripts/ui/ui_util.gd")

signal finished(options: Dictionary)
signal cancelled()

const ACCENT := Color(0.95, 0.62, 0.30)
const MUTED := Color(0.72, 0.76, 0.82)

var game_seed := 1
var planet_id := GameData.DEFAULT_PLANET
var difficulty_id := GameData.DEFAULT_DIFFICULTY
var manifest: Dictionary = {}
var page: Control
## Probes used so far, and the sites they scouted ("planet:site" keys).
var probes_used := 0
var scouted := {}
## The site chosen with "Settle here" in a probe report (-1 if none).
var settle_site := -1


func setup(seed_value: int) -> void:
	game_seed = seed_value
	manifest = Manifest.recommended()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_briefing()


# ---------------------------------------------------------------- Helpers

func _new_page(title: String, width: float = 760.0) -> VBoxContainer:
	if page != null:
		page.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	page = scroll
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(width, maxf(320.0, get_viewport_rect().size.x - 32.0)), 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := _label(title, 28 if not _narrow() else 22, ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	return box


## True on phone-sized screens (in interface units, after device scaling).
func _narrow() -> bool:
	return get_viewport_rect().size.x < 640.0


func _width() -> float:
	return get_viewport_rect().size.x


func _label(text: String, size_px: int = 0, color: Color = Color.WHITE, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if size_px > 0:
		l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	return b


## Makes a wrapping button tall enough for its text (see ui_util.gd).
func _fit(b: Button) -> void:
	UiUtil.fit_button_height(b, minf(760.0, _width() - 32.0) - 16.0)


func _nav(box: VBoxContainer, back: Callable, next_label: String, next: Callable) -> Button:
	var row: BoxContainer = HBoxContainer.new() if not _narrow() else VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var b := _button("Back", back)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	var n := _button(next_label, next)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	n.grab_focus.call_deferred()
	return n


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Pages

func show_briefing() -> void:
	var box := _new_page("Briefing")
	var paragraphs: Array = GameData.story()["intro"]
	box.add_child(_label("\n\n".join(PackedStringArray(paragraphs)), 0, Color.WHITE, true))
	_nav(box, func() -> void: cancelled.emit(), "Choose a planet", show_planets)


func show_planets() -> void:
	var box := _new_page("Choose a planet")
	box.add_child(_label("Each world has its own leaderboard.", 0, MUTED, true))
	for p in GameData.planets():
		var b := _button("%s  ·  %s\n%s\n%s" % [p["name"], p["difficulty"], p["tagline"], p["desc"]], _pick_planet.bind(p["id"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fit(b)
		box.add_child(b)
		if p["id"] == planet_id:
			b.grab_focus.call_deferred()
		var seen := _scouted_count(p["id"])
		var probe_text := "Send a probe to %s  (%d of %d probes left)" % [p["name"], _probes_left(), Probe.carried(manifest)]
		if seen > 0:
			probe_text += "  ·  %d site%s scouted" % [seen, "" if seen == 1 else "s"]
		var pb := _button(probe_text, show_probe_target.bind(p["id"]))
		pb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pb.disabled = _probes_left() <= 0 and seen == 0
		_fit(pb)
		box.add_child(pb)
	var back := _button("Back", show_briefing)
	box.add_child(back)


func _pick_planet(id: String) -> void:
	if id != planet_id:
		settle_site = -1
	planet_id = id
	show_difficulty()


func _probes_left() -> int:
	return maxi(0, Probe.carried(manifest) - probes_used)


func _key(pid: String, site: int) -> String:
	return "%s:%d" % [pid, site]


func _scouted_count(pid: String) -> int:
	var n := 0
	for k in scouted:
		if str(k).begins_with(pid + ":"):
			n += 1
	return n


## Where should the probe land? The planet's landing sites, as rough outlines
## until scouted.
func show_probe_target(pid: String) -> void:
	var planet := GameData.planet(pid)
	var box := _new_page("Send a probe to %s" % planet["name"], 900.0)
	box.add_child(_label("Choose where the probe lands. It scouts one landing site and sends back a full report. %d of %d probes left." % [_probes_left(), Probe.carried(manifest)], 0, MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 2 if _width() >= 900.0 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var sites: Array = GameData.balance()["landing_sites"]
	for i in sites.size():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var seen := scouted.has(_key(pid, i))
		cell.add_child(_minimap(pid, i, not seen))
		var label := ("See the report for site %s" if seen else "Probe site %s") % char(65 + i)
		var b := _button(label, _send_probe.bind(pid, i, show_planets))
		b.disabled = not seen and _probes_left() <= 0
		_fit(b)
		cell.add_child(b)
	box.add_child(_button("Back", show_planets))


func _minimap(pid: String, site: int, fog: bool) -> Control:
	var mini := Minimap.new()
	var mini_w := minf(400.0, _width() - 56.0)
	mini.custom_minimum_size = Vector2(mini_w, mini_w * 0.75)
	mini.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mini.fog = fog
	mini.show_map(MapGen.generate(game_seed, pid, site))
	return mini


## Uses a probe on a site (or reopens its report if it was scouted already).
func _send_probe(pid: String, site: int, back: Callable) -> void:
	if not scouted.has(_key(pid, site)):
		if _probes_left() <= 0:
			return
		probes_used += 1
		scouted[_key(pid, site)] = true
	show_probe_report(pid, site, back)


## The probe's report on one site, with Settle here and Look elsewhere.
func show_probe_report(pid: String, site: int, back: Callable) -> void:
	var planet := GameData.planet(pid)
	var r := Probe.report(game_seed, pid, site)
	var box := _new_page("Probe report: %s, site %s" % [planet["name"], char(65 + site)], 900.0)
	var view := ProbeView.new()
	var w := minf(620.0, _width() - 40.0)
	view.custom_minimum_size = Vector2(w, w * 0.55)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	view.show_map(r["map"], r["find"])
	var near: Dictionary = r["near"]
	var below: Dictionary = r["below"]
	var lines := PackedStringArray()
	lines.append("Sunlight: %d%% (Solar Arrays make this much of their best).  Cold: buildings need %.1f times the usual heat." % [int(round(float(r["light"]) * 100.0)), float(r["cold"])])
	lines.append("Nearby: %d ice, %d vents, %d ore seams, %d ridges (can't build on ridges)." % [near["ice"], near["vent"], near["seam"], near["ridge"]])
	lines.append("In the Deep below: %d ore veins, %d underground water, %d deep vents." % [below["vein"], below["aquifer"], below["deepvent"]])
	lines.append("Grit storms here: %s.  Icequakes: %s." % [r["storms"], r["quakes"]])
	box.add_child(_label("\n".join(lines), 0, Color.WHITE, true))
	var find: String = r["find"]
	if find != "":
		var fd := Probe.find_def(find)
		box.add_child(_label("Lucky find: %s. %s" % [fd["name"], fd["desc"]], 0, ACCENT, true))
	else:
		box.add_child(_label("No lucky finds here.", 0, MUTED, true))
	var settle := _button("Settle here", _settle.bind(pid, site))
	_fit(settle)
	box.add_child(settle)
	settle.grab_focus.call_deferred()
	box.add_child(_button("Look elsewhere", back))


func _settle(pid: String, site: int) -> void:
	planet_id = pid
	settle_site = site
	show_difficulty()


func show_difficulty() -> void:
	var box := _new_page("Choose a difficulty")
	box.add_child(_label("Each difficulty has its own leaderboard on every planet.", 0, MUTED, true))
	for d in GameData.difficulties():
		var b := _button("%s\n%s" % [d["name"], d["desc"]], _pick_difficulty.bind(d["id"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_fit(b)
		box.add_child(b)
		if d["id"] == difficulty_id:
			b.grab_focus.call_deferred()
	box.add_child(_button("Back", show_planets))


func _pick_difficulty(id: String) -> void:
	difficulty_id = id
	show_manifest()


func show_manifest() -> void:
	var box := _new_page("Pack the ship")
	var used := Manifest.bays_used(manifest)
	var debt := Manifest.debt_of(manifest, difficulty_id)
	box.add_child(_label("Everything in the hold is bought on credit from the Company: more cargo makes the start easier, but adds to the debt you must pay off.", 0, MUTED, true))
	var summary := _label("Hold: %d / %d bays    Starting debt: %d marks" % [used, Manifest.bays(), int(debt)], 18, ACCENT)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 4 if not _narrow() else 3
	grid.add_theme_constant_override("h_separation", 10)
	box.add_child(grid)
	for item in GameData.cargo()["items"]:
		var id: String = item["id"]
		var n := int(manifest.get(id, 0))
		var narrow := _narrow()
		var text := "%s\n%s" % [item["name"], item["desc"]]
		if narrow:
			text += "\n+%d marks each" % _item_debt(item)
		var item_label := _label(text, 0, Color.WHITE, true)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.custom_minimum_size = Vector2(minf(300.0, _width() - 190.0), 0)
		grid.add_child(item_label)
		if not narrow:
			grid.add_child(_label("+%d marks" % _item_debt(item), 0, MUTED))
		var minus := _button(" − ", _change.bind(id, -1))
		minus.disabled = n <= 0
		minus.custom_minimum_size = Vector2(44, 44)
		grid.add_child(minus)
		var plus := _button("%d  + " % n, _change.bind(id, 1))
		plus.disabled = n >= int(item["max"]) or used >= Manifest.bays()
		plus.custom_minimum_size = Vector2(70, 44)
		plus.tooltip_text = "At most %d." % int(item["max"])
		grid.add_child(plus)
	var presets: BoxContainer = HBoxContainer.new() if not _narrow() else VBoxContainer.new()
	presets.add_theme_constant_override("separation", 10)
	box.add_child(presets)
	var rec := _button("Recommended load", _set_manifest.bind(Manifest.recommended()))
	rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets.add_child(rec)
	var empty := _button("Empty the hold", _set_manifest.bind({}))
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets.add_child(empty)
	_nav(box, show_difficulty, "Choose a landing site", show_sites)


## What one unit of cargo adds to the debt at this difficulty.
func _item_debt(item: Dictionary) -> int:
	return int(round(float(item["debt"]) * float(GameData.difficulty(difficulty_id)["debt"])))


func _change(id: String, delta: int) -> void:
	var next := manifest.duplicate()
	next[id] = int(next.get(id, 0)) + delta
	if int(next[id]) <= 0:
		next.erase(id)
	if Manifest.check(next)["ok"]:
		manifest = next
	show_manifest()


func _set_manifest(m: Dictionary) -> void:
	manifest = m.duplicate()
	show_manifest()


func show_sites() -> void:
	var box := _new_page("Choose a landing site", 900.0)
	var planet := GameData.planet(planet_id)
	box.add_child(_label("%s. The orange dot is where the ship lands. Ice is pale blue, vents orange, ore seams teal, and dark rock can't be built on." % planet["name"], 0, MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 2 if _width() >= 900.0 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var sites: Array = GameData.balance()["landing_sites"]
	box.add_child(_label("Sites you haven't scouted show only a rough outline. %d of %d probes left." % [_probes_left(), Probe.carried(manifest)], 0, MUTED, true))
	var deep: Array = MapGen.generate_deep(game_seed, planet_id)
	for i in sites.size():
		var map := MapGen.generate(game_seed, planet_id, i)
		var seen := scouted.has(_key(planet_id, i))
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		cell.add_child(_minimap(planet_id, i, not seen))
		var note := "%s; %s" % [_site_note(map), _deep_note(map, deep)] if seen else "not scouted"
		if seen and Probe.find_for(game_seed, planet_id, i) != "":
			note += "; lucky find: " + str(Probe.find_def(Probe.find_for(game_seed, planet_id, i))["name"]).to_lower()
		var b := _button("Land at site %s  (%s)" % [char(65 + i), note], _finish.bind(i))
		_fit(b)
		cell.add_child(b)
		if i == maxi(settle_site, 0):
			b.grab_focus.call_deferred()
		if not seen:
			var pb := _button("Send a probe here", _send_probe.bind(planet_id, i, show_sites))
			pb.disabled = _probes_left() <= 0
			_fit(pb)
			cell.add_child(pb)
		else:
			cell.add_child(_button("See the probe report", show_probe_report.bind(planet_id, i, show_sites)))
	var back := _button("Back", show_manifest)
	box.add_child(back)


## How many useful tiles are within 6 steps of the pad.
func _site_note(map: Dictionary) -> String:
	var hull: Array = map["hull"]
	var counts := {"ice": 0, "vent": 0, "seam": 0}
	var tiles: Array = map["tiles"]
	for y in tiles.size():
		for x in tiles[y].size():
			var t: String = tiles[y][x]
			if counts.has(t) and absi(x - int(hull[0])) + absi(y - int(hull[1])) <= 6:
				counts[t] = int(counts[t]) + 1
	return "nearby: %d ice, %d vents, %d seams" % [counts["ice"], counts["vent"], counts["seam"]]


## What the probes found in the Deep within 6 steps of the pad.
func _deep_note(map: Dictionary, deep: Array) -> String:
	var hull: Array = map["hull"]
	var counts := {"vein": 0, "aquifer": 0, "deepvent": 0}
	for y in deep.size():
		for x in deep[y].size():
			var t: String = deep[y][x]
			if counts.has(t) and absi(x - int(hull[0])) + absi(y - int(hull[1])) <= 6:
				counts[t] = int(counts[t]) + 1
	return "below: %d veins, %d aquifers, %d deep vents" % [counts["vein"], counts["aquifer"], counts["deepvent"]]


func _finish(site: int) -> void:
	finished.emit({"planet": planet_id, "difficulty": difficulty_id, "site": site, "manifest": manifest.duplicate(), "find": Probe.find_for(game_seed, planet_id, site)})
