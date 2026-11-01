## The whole interface, built in code: title screen, briefing, game screen,
## event and ending dialogs. All game rules live in scripts/sim/; this file
## only calls them and displays the state.
extends Control

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const AppActions = preload("res://scripts/ui/app_actions.gd")
const Research = preload("res://scripts/sim/research.gd")
const Online = preload("res://scripts/net/online.gd")
const OnlineConfig = preload("res://scripts/net/online_config.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")

const PROFILE_PATH := "user://profile.json"
const PLANET := "brume"
const PLANET_NAME := "Brume"

const BG := Color(0.06, 0.07, 0.09)
const PANEL := Color(0.10, 0.11, 0.14)
const ACCENT := Color(0.95, 0.62, 0.30)
const CATEGORIES := [["core", "Network"], ["energy", "Energy"], ["life", "Life support"], ["industry", "Industry"], ["civic", "Civic"]]
const STAT_KEYS := ["turn", "pop", "morale", "power", "heat", "workers", "food", "oxygen", "water", "ore", "alloy", "marks", "debt", "payment"]

var state: Dictionary = {}
var screen: Control
var map_view: MapView
var stat_labels := {}
var build_buttons := {}
var inspector: RichTextLabel
var demolish_button: Button
var reserve_label: Label
var research_button: Button
var log_view: RichTextLabel
var end_turn_button: Button
var run_button: Button
var hint_label: Label
var modal: Control
var modal_can_cancel := false
var busy := false
var online: Node
var toast: Label
var toast_left := 0.0
var player_name := ""
var settings_open := false


func _ready() -> void:
	var t := Theme.new()
	t.default_font_size = 15
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel_style)
	theme = t
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	online = Online.new()
	add_child(online)
	online.board_loaded.connect(_on_board_loaded)
	online.score_submitted.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.sign_in_message.connect(_toast)
	online.account_changed.connect(_on_account_changed)
	online.cloud_saved.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.cloud_loaded.connect(_on_cloud_loaded)
	player_name = _load_profile().get("name", "")
	show_title()


func _clear_screen() -> void:
	close_modal()
	if screen != null:
		screen.queue_free()
	screen = null
	map_view = null


func _label(text: String, size_px: int = 0, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size_px > 0:
		l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b


# ---------------------------------------------------------------- Title

func show_title() -> void:
	_clear_screen()
	state = {}
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	screen = root
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := _label(GameData.story()["title"], 56, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("A colony on the edge between night and day.", 16, Color(0.75, 0.78, 0.82))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	box.add_child(_label("Colony name"))
	var name_edit := LineEdit.new()
	name_edit.text = "Margin"
	box.add_child(name_edit)
	box.add_child(_label("Map seed"))
	var seed_box := SpinBox.new()
	seed_box.min_value = 1
	seed_box.max_value = 999999
	seed_box.value = randi_range(1, 999999)
	box.add_child(seed_box)
	box.add_child(_label("Your name on the leaderboard"))
	var player_edit := LineEdit.new()
	player_edit.text = player_name
	player_edit.max_length = ScoreEntry.MAX_NAME_LENGTH
	player_edit.placeholder_text = "Letters, numbers, spaces, - and _"
	player_edit.text_changed.connect(_on_player_name_changed)
	box.add_child(player_edit)
	box.add_child(_button("New colony", _on_new_colony.bind(name_edit, seed_box)))
	for slot in ["manual", "autosave"]:
		if SaveGame.exists(slot):
			var label := "Load saved game" if slot == "manual" else "Load autosave"
			box.add_child(_button(label, func() -> void: _load(slot)))
	box.add_child(_button("Leaderboard", show_leaderboard))
	box.add_child(_button("Settings", show_settings))
	if not AppActions.is_web():
		box.add_child(_button("Quit", func() -> void: get_tree().quit()))
	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 13, Color(0.55, 0.6, 0.66))
	root.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


func _on_new_colony(name_edit: LineEdit, seed_box: SpinBox) -> void:
	var colony := name_edit.text.strip_edges()
	if colony == "":
		colony = "Margin"
	_start_new(int(seed_box.value), colony)


func _start_new(seed_value: int, colony: String) -> void:
	state = NewGame.create(seed_value, colony)
	show_game()
	var paragraphs: Array = GameData.story()["intro"]
	show_modal("Briefing", "\n\n".join(PackedStringArray(paragraphs)), [["Begin", close_modal, true]], true)


func _load(slot: String) -> void:
	var loaded: Variant = SaveGame.load_slot(slot)
	if typeof(loaded) == TYPE_STRING:
		show_modal("Could not load", loaded, [["OK", close_modal, true]])
		return
	state = loaded
	show_game()
	_after_turn()


# ---------------------------------------------------------------- Game screen

func show_game() -> void:
	_clear_screen()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	screen = root

	# Top bar.
	var top := PanelContainer.new()
	root.add_child(top)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 18)
	top.add_child(stats)
	stat_labels.clear()
	for key in STAT_KEYS:
		var l := _label("")
		stats.add_child(l)
		stat_labels[key] = l

	# Middle: build menu | map | inspector.
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	middle.add_child(left)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(menu)
	menu.add_child(_button("Select  (Esc)", func() -> void: _set_build("")))
	build_buttons.clear()
	for cat in CATEGORIES:
		menu.add_child(_label(cat[1], 13, ACCENT))
		for id in GameData.building_ids():
			var def := GameData.building(id)
			if def["category"] != cat[0] or not def.get("buildable", true):
				continue
			var b := Button.new()
			b.toggle_mode = true
			b.text = "%s  (%d)" % [def["name"], int(GameData.num(def, "cost"))]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = def["desc"]
			b.pressed.connect(func() -> void: _set_build("" if map_view.build_type == id else id))
			menu.add_child(b)
			build_buttons[id] = b

	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.tile_clicked.connect(_on_tile_clicked)
	map_view.tile_hovered.connect(func(_c: Vector2i) -> void: _refresh_hint())
	middle.add_child(map_view)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	middle.add_child(right)
	var right_box := VBoxContainer.new()
	right.add_child(right_box)
	inspector = RichTextLabel.new()
	inspector.bbcode_enabled = true
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(inspector)
	demolish_button = _button("Demolish", _on_demolish)
	right_box.add_child(demolish_button)
	right_box.add_child(HSeparator.new())
	right_box.add_child(_label("Research", 13, ACCENT))
	research_button = _button("", show_research)
	research_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	research_button.clip_text = true
	right_box.add_child(research_button)
	right_box.add_child(_label("Company account", 13, ACCENT))
	var pay_row := HBoxContainer.new()
	right_box.add_child(pay_row)
	pay_row.add_child(_button("Pay 100", func() -> void: _pay(100.0)))
	pay_row.add_child(_button("Pay 500", func() -> void: _pay(500.0)))
	var reserve_row := HBoxContainer.new()
	right_box.add_child(reserve_row)
	reserve_label = _label("")
	reserve_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve_label.tooltip_text = "Launch rails never sell alloy below this amount."
	reserve_row.add_child(reserve_label)
	reserve_row.add_child(_button("-10", func() -> void: _change_reserve(-10.0)))
	reserve_row.add_child(_button("+10", func() -> void: _change_reserve(10.0)))

	# Bottom: log and turn controls.
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 170)
	root.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom.add_child(bottom_row)
	var log_box := VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(log_box)
	hint_label = _label("", 13, Color(0.7, 0.75, 0.8))
	log_box.add_child(hint_label)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_child(log_view)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(150, 0)
	bottom_row.add_child(buttons)
	end_turn_button = _button("End turn  (Enter)", func() -> void: _run_turns(1))
	buttons.add_child(end_turn_button)
	run_button = _button("Run 5 turns", func() -> void: _run_turns(5))
	buttons.add_child(run_button)
	buttons.add_child(_button("Save", _on_save))
	buttons.add_child(_button("Menu", _on_menu))

	map_view.set_state(state)
	refresh()


func _set_build(id: String) -> void:
	if map_view == null:
		return
	map_view.build_type = id
	for key in build_buttons:
		build_buttons[key].button_pressed = key == id
	map_view.queue_redraw()
	_refresh_hint()


func _on_tile_clicked(cell: Vector2i) -> void:
	if modal != null or state["ending"] != "":
		map_view.selected = cell
		refresh()
		return
	if map_view.build_type != "":
		var r := Actions.place(state, map_view.build_type, cell.x, cell.y)
		if not r["ok"]:
			hint_label.text = r["reason"]
			return
	map_view.selected = cell
	refresh()


func _on_demolish() -> void:
	var s := _selected_structure()
	if s.is_empty():
		return
	var r := Actions.demolish(state, s["id"])
	if not r["ok"]:
		hint_label.text = r["reason"]
	refresh()


func _pay(amount: float) -> void:
	var r := Actions.pay_extra(state, amount)
	if not r["ok"]:
		hint_label.text = r["reason"]
	refresh()


func _change_reserve(delta: float) -> void:
	Actions.set_export_reserve(state, float(state["export_reserve"]) + delta)
	refresh()


func _on_save() -> void:
	var err := SaveGame.save(state, "manual")
	hint_label.text = err if err != "" else "Saved."


func _on_menu() -> void:
	show_modal("Menu", "Unsaved progress since your last save or autosave will be lost.", [
		["Save and quit to title", _save_and_quit, true],
		["Quit to title without saving", show_title, true],
		["Retire: post this colony's progress to the leaderboard", _post_score.bind("retired"), OnlineConfig.enabled()],
		["Settings", show_settings, true],
		["Back to the colony", close_modal, true],
	], true)


func _save_and_quit() -> void:
	SaveGame.save(state, "manual")
	show_title()


func _run_turns(count: int) -> void:
	if busy or modal != null or state.is_empty() or state["ending"] != "":
		return
	busy = true
	for _i in count:
		if state["pending_event"] != "" or state["ending"] != "":
			break
		Turn.end_turn(state)
		var every := int(GameData.balance()["autosave_every"])
		if (int(state["turn"]) - 1) % every == 0:
			SaveGame.save(state, "autosave")
	busy = false
	_after_turn()


func _after_turn() -> void:
	refresh()
	if state["ending"] != "":
		_show_ending()
	elif state["pending_event"] != "":
		_show_event()


func _show_event() -> void:
	var ev := GameData.event(state["pending_event"])
	var options: Array = []
	var choices: Array = ev["choices"]
	for i in choices.size():
		options.append([choices[i]["label"], _resolve_choice.bind(i), Actions.choice_allowed(state, choices[i])])
	show_modal(ev["title"], ev["body"], options)


func _resolve_choice(index: int) -> void:
	Actions.resolve_event(state, index)
	close_modal()
	_after_turn()


func _show_ending() -> void:
	var e: Dictionary = GameData.story()["endings"][state["ending"]]
	var st: Dictionary = state["stats"]
	var body := "%s\n\nTurn %d. Population %d. Born %d, died %d, arrived %d. Alloy exported: %d." % [
		e["body"], int(state["turn"]) - 1, int(_pop()), int(st["births"]), int(st["deaths"]), int(st["arrivals"]), int(st["exported"])]
	show_modal(e["title"], body, [["Post score to the leaderboard", _post_score.bind(""), OnlineConfig.enabled()], ["Look around", close_modal, true], ["Back to title", show_title, true]])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE and modal != null and modal_can_cancel:
		close_modal()
		get_viewport().set_input_as_handled()
		return
	if map_view == null:
		return
	var key := (event as InputEventKey).keycode
	if (key == KEY_ENTER or key == KEY_KP_ENTER) and modal == null:
		_run_turns(1)
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		if modal == null:
			_set_build("")
			map_view.selected = Vector2i(-1, -1)
			refresh()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Display

func _pop() -> float:
	return float(state["adults"]) + float(state["children"])


func _fmt(v: float) -> String:
	return str(int(round(v)))


func _signed(v: float) -> String:
	var n := int(round(v))
	return ("+%d" % n) if n >= 0 else str(n)


func refresh() -> void:
	if state.is_empty() or map_view == null:
		return
	var rep: Dictionary = state["report"]
	var stock: Dictionary = state["stock"]
	var net: Dictionary = rep.get("net", {})
	var has_rep := not rep.is_empty()
	stat_labels["turn"].text = "Turn %d" % int(state["turn"])
	stat_labels["pop"].text = "Pop %s/%s" % [_fmt(_pop()), _fmt(float(rep.get("housing", 40.0)))]
	stat_labels["morale"].text = "Morale %s" % _fmt(float(state["morale"]))
	stat_labels["power"].text = "Power %s/%s" % [_fmt(float(rep.get("power_free", 0.0))), _fmt(float(rep.get("power_gen", 0.0)))] if has_rep else "Power -"
	stat_labels["heat"].text = "Heat %s/%s" % [_fmt(float(rep.get("heat_free", 0.0))), _fmt(float(rep.get("heat_gen", 0.0)))] if has_rep else "Heat -"
	stat_labels["workers"].text = "Idle workers %d/%d" % [int(rep.get("workers_free", 0)), int(rep.get("workers_total", 0))] if has_rep else "Workers -"
	for k in ["food", "oxygen", "water", "ore", "alloy"]:
		var text := "%s %s" % [k.capitalize(), _fmt(float(stock[k]))]
		if net.has(k):
			text += " (%s)" % _signed(float(net[k]))
		stat_labels[k].text = text
	stat_labels["marks"].text = "Marks %s" % _fmt(float(stock["credits"]))
	stat_labels["debt"].text = "Debt %s" % _fmt(float(state["debt"]))
	stat_labels["payment"].text = "Next payment %s on turn %d" % [_fmt(Turn.next_payment_amount(state)), Turn.next_payment_turn(state)]
	var shortages: Dictionary = rep.get("shortages", {})
	for k in ["food", "oxygen", "water"]:
		stat_labels[k].add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if shortages.has(k) else Color.WHITE)
	stat_labels["debt"].add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if int(state["missed_in_row"]) > 0 else Color.WHITE)

	for id in build_buttons:
		var def := GameData.building(id)
		build_buttons[id].disabled = float(stock["alloy"]) < GameData.num(def, "cost") or state["ending"] != ""
	end_turn_button.disabled = state["ending"] != ""
	run_button.disabled = state["ending"] != ""
	reserve_label.text = "Export reserve: %d alloy" % int(state["export_reserve"])
	var r: Dictionary = state["research"]
	if state["plague"]["active"]:
		research_button.text = "Plague cure: %d / %d" % [int(state["plague"]["cure"]), int(state["plague"]["need"])]
	elif r["current"] == "":
		research_button.text = "Choose a topic…"
	else:
		var t := GameData.topic(r["current"])
		research_button.text = "%s: %d / %d" % [t["name"], int(r["progress"]), int(t["cost"])]

	_refresh_inspector()
	_refresh_log()
	_refresh_hint()
	map_view.queue_redraw()


func _refresh_hint() -> void:
	if map_view == null or hint_label == null:
		return
	if map_view.build_type != "":
		var def := GameData.building(map_view.build_type)
		var text := "Placing %s. %s" % [def["name"], def["desc"]]
		var h: Vector2i = map_view.hover
		if h.x >= 0:
			var r := Actions.check_place(state, map_view.build_type, h.x, h.y)
			if not r["ok"]:
				text = r["reason"]
			elif GameData.num(def, "heat_need") > 0.0:
				text += "  Heat here: %.1f." % (GameData.num(def, "heat_need") * GameData.cold_at(h.x))
		hint_label.text = text
	else:
		hint_label.text = "Click a tile to inspect it. Choose a building on the left to place it. Right-drag to pan, wheel to zoom."


func _selected_structure() -> Dictionary:
	var c: Vector2i = map_view.selected
	if c.x < 0:
		return {}
	return Actions.structure_at(state, c.x, c.y)


func _refresh_inspector() -> void:
	var c: Vector2i = map_view.selected
	var lines := PackedStringArray()
	var s := _selected_structure()
	demolish_button.visible = not s.is_empty() and s["type"] != "hull"
	if c.x < 0:
		lines.append("[b]%s[/b]" % state["colony_name"])
		lines.append("Adults %s, children %s, elders %s." % [_fmt(float(state["adults"])), _fmt(float(state["children"])), _fmt(float(state["elders"]))])
		lines.append("Crime %s." % _fmt(float(state["crime"])))
		if state["plague"]["active"]:
			lines.append("[color=#ff6a5a]Plague! Cure %d of %d, %d turns left.[/color]" % [int(state["plague"]["cure"]), int(state["plague"]["need"]), int(state["plague"]["turns_left"])])
		lines.append("Production efficiency %d%% (from morale)." % int(round(Turn.efficiency(state) * 100.0)))
		lines.append("Storage %s per resource." % _fmt(float(state["report"].get("storage", GameData.balance()["base_storage"]))))
		lines.append("Payments made %d. Missed in a row: %d of %d." % [int(state["payments_made"]), int(state["missed_in_row"]), int(GameData.balance()["max_missed"])])
		if int(state["storm"]) > 0:
			lines.append("[color=#e8b04a]Grit front: mirrors weakened for %d more turns.[/color]" % int(state["storm"]))
		if int(state["surge"]) > 0:
			lines.append("[color=#e8b04a]Vent surge: %d more turns.[/color]" % int(state["surge"]))
		lines.append("\nSelect a tile to inspect it.")
		inspector.text = "\n".join(lines)
		return
	var terrain := Actions.terrain_at(state, c.x, c.y)
	lines.append("[b]%s[/b]  (%d, %d)" % [terrain.capitalize(), c.x, c.y])
	lines.append("Light %.2f   Heat factor %.2f" % [GameData.light_at(c.x), GameData.cold_at(c.x)])
	if s.is_empty():
		inspector.text = "\n".join(lines)
		return
	var def := GameData.building(s["type"])
	lines.append("")
	lines.append("[b][color=#f29e4c]%s[/color][/b]" % def["name"])
	var status := ""
	if not s["built"]:
		status = "Under construction: %d of %d turns." % [int(s["progress"]), int(GameData.num(def, "turns"))]
	elif int(s["damaged"]) > 0:
		status = "Damaged: back in %d turns." % int(s["damaged"])
	elif def.get("conduit", false):
		status = "Carrying heat." if Turn.connectivity(state).has(s["id"]) else "Not connected to the hull."
	elif s["active"]:
		status = "Running."
	elif not Turn.connectivity(state).has(s["id"]):
		status = "[color=#ff6a5a]Not connected to the hull.[/color]"
	else:
		status = "[color=#ff6a5a]Idle: not enough workers, power or heat.[/color]"
	lines.append(status)
	lines.append(def["desc"])
	var needs := PackedStringArray()
	if GameData.num(def, "workers") > 0.0:
		needs.append("%d workers" % int(GameData.num(def, "workers")))
	if GameData.num(def, "power_use") > 0.0:
		needs.append("%s power" % GameData.num(def, "power_use"))
	if GameData.num(def, "heat_need") > 0.0:
		needs.append("%.1f heat" % (GameData.num(def, "heat_need") * GameData.cold_at(int(s["x"]))))
	var inputs: Dictionary = def.get("inputs", {})
	for k in inputs:
		needs.append("%s %s" % [inputs[k], k])
	if not needs.is_empty():
		lines.append("Uses: " + ", ".join(needs))
	var gives := PackedStringArray()
	if GameData.num(def, "power_gen") > 0.0:
		var pg := GameData.num(def, "power_gen")
		if def.get("solar", false):
			pg *= GameData.light_at(int(s["x"]))
		gives.append("%.1f power" % pg)
	if GameData.num(def, "heat_gen") > 0.0:
		gives.append("%s heat" % GameData.num(def, "heat_gen"))
	var outputs: Dictionary = def.get("outputs", {})
	for k in outputs:
		gives.append("%s %s" % [outputs[k], k])
	if GameData.num(def, "housing") > 0.0:
		gives.append("housing %d" % int(GameData.num(def, "housing")))
	if GameData.num(def, "storage") > 0.0:
		gives.append("storage +%d" % int(GameData.num(def, "storage")))
	if GameData.num(def, "export") > 0.0:
		gives.append("exports up to %d alloy" % int(GameData.num(def, "export")))
	if not gives.is_empty():
		lines.append("Gives: " + ", ".join(gives))
	inspector.text = "\n".join(lines)


func _refresh_log() -> void:
	var lines := PackedStringArray()
	for entry in state["log"]:
		lines.append("[color=#8a93a0]T%d[/color]  %s" % [int(entry["turn"]), entry["text"]])
	log_view.text = "\n".join(lines)


# ---------------------------------------------------------------- Research

func show_research() -> void:
	var options: Array = []
	for t in Research.available(state):
		var label := "%s (%d): %s" % [t["name"], int(t["cost"]), t["desc"]]
		options.append([label, _choose_research.bind(t["id"]), true])
	var done := PackedStringArray()
	for id in Research.done(state):
		done.append(GameData.topic(id)["name"])
	var body := "Survey Labs produce research toward one topic at a time. Changing topic loses progress on the old one."
	if state["plague"]["active"]:
		body += "\n\nDuring the plague, all research goes to the cure first."
	body += "\n\nFinished: " + (", ".join(done) if not done.is_empty() else "none yet") + "."
	if options.is_empty():
		body += "\n\nEverything has been researched."
	options.append(["Back", close_modal, true])
	show_modal("Research", body, options, true)


func _choose_research(id: String) -> void:
	Actions.set_research(state, id)
	close_modal()
	refresh()


# ---------------------------------------------------------------- Settings

func show_settings() -> void:
	var notes := PackedStringArray()
	var options: Array = []
	if AppActions.can_fullscreen():
		options.append(["Fullscreen: %s" % ("On" if AppActions.is_fullscreen() else "Off"), _on_fullscreen, true])
	if AppActions.is_web():
		var install := AppActions.install_state()
		match install:
			"installed":
				options.append(["Installed as an app", _on_install, false])
			"ios":
				options.append(["Install app", _on_install, true])
				notes.append("On iPhone or iPad: tap Share, then Add to Home Screen.")
			"ready":
				options.append(["Install app", _on_install, true])
			_:
				options.append(["Install app", _on_install, false])
				notes.append("Install app works in Chrome and Edge (and on phones) once the page has loaded.")
		options.append(["Update app", _on_update, true])
		notes.append("Update app reloads the newest version from the internet. Your saved games are kept.")
	if OnlineConfig.enabled():
		if online.is_signed_in():
			notes.append("Signed in as %s. Cloud save keeps one game for your account, so you can carry on from another device." % online.account_name())
			options.append(["Save this game to the cloud" if not state.is_empty() else "Save my last saved game to the cloud", _cloud_upload, not state.is_empty() or SaveGame.exists("manual")])
			options.append(["Load my game from the cloud", online.download_save, true])
			options.append(["Sign out", online.sign_out, true])
		elif online.is_signing_in():
			notes.append("Finish signing in with Google in your browser.")
			options.append(["Cancel sign-in", online.cancel_sign_in, true])
		else:
			options.append(["Sign in with Google", online.start_sign_in, true])
			notes.append("Signing in lets you keep a cloud save and carry on from another device. It's optional.")
	options.append(["Back", _close_settings, true])
	var body := "Lastborn Colony v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	if not notes.is_empty():
		body += "\n\n" + "\n".join(notes)
	show_modal("Settings", body, options, true)
	settings_open = true


func _close_settings() -> void:
	close_modal()


func _on_fullscreen() -> void:
	AppActions.toggle_fullscreen()
	show_settings.call_deferred()


func _on_install() -> void:
	if AppActions.install_state() == "ready":
		AppActions.install()
	show_settings.call_deferred()


func _on_update() -> void:
	if state.size() > 0 and state.get("ending", "") == "":
		SaveGame.save(state, "autosave")
	AppActions.update_now()


# ---------------------------------------------------------------- Online

func _on_account_changed() -> void:
	if settings_open:
		show_settings()


func _on_player_name_changed(text: String) -> void:
	player_name = text
	_save_profile()


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": player_name}))


func _post_score(ending_override: String) -> void:
	if state.is_empty():
		return
	var entry := ScoreEntry.from_state(state, player_name, ending_override)
	var problem := ScoreEntry.problem(entry)
	if problem != "":
		_toast(problem)
		return
	online.submit_score(entry)
	_toast("Sending score…")


func show_leaderboard() -> void:
	show_modal("Leaderboard: %s" % PLANET_NAME, "Loading…", [["Back", close_modal, true]], true)
	online.fetch_board(PLANET)


func _on_board_loaded(entries: Array, error: String) -> void:
	if modal == null:
		return
	var lines := PackedStringArray()
	if error != "":
		lines.append(error)
	elif entries.is_empty():
		lines.append("No scores yet. Finish a colony and post your score to be the first.")
	else:
		lines.append("Free charters first (fewest turns), then the most debt paid.\n")
		var rank := 1
		for e in entries.slice(0, 25):
			var how := ""
			if e.get("ending", "") == "free":
				how = "bought out the charter in %d turns" % int(e.get("turn", 0))
			else:
				var endings := {"receivership": "taken by the Company", "silent": "went silent", "retired": "retired"}
				how = "paid %d of %d marks, %s on turn %d" % [int(e.get("debt_paid", 0)), int(e.get("debt_total", 0)), endings.get(e.get("ending", ""), "ended"), int(e.get("turn", 0))]
			lines.append("%d. %s (%s): %s" % [rank, e.get("name", "?"), e.get("colony", "?"), how])
			rank += 1
	show_modal("Leaderboard: %s" % PLANET_NAME, "\n".join(lines), [["Back", close_modal, true]], true)


func _cloud_upload() -> void:
	if not state.is_empty():
		online.upload_save(SaveGame.to_text(state))
	elif SaveGame.exists("manual"):
		online.upload_save(FileAccess.get_file_as_string(SaveGame.path_for("manual")))


func _on_cloud_loaded(text: String, error: String) -> void:
	if error != "":
		_toast(error)
		return
	var loaded: Variant = SaveGame.from_text(text)
	if typeof(loaded) == TYPE_STRING:
		_toast(loaded)
		return
	state = loaded
	SaveGame.save(state, "manual")
	show_game()
	_after_turn()
	_toast("Loaded your game from the cloud.")


## A short message along the bottom of the screen that fades after a few seconds.
func _toast(message: String) -> void:
	if toast == null:
		toast = Label.new()
		toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.03, 0.05, 0.92)
		style.set_content_margin_all(10)
		style.set_corner_radius_all(6)
		toast.add_theme_stylebox_override("normal", style)
		toast.z_index = 100
		add_child(toast)
	toast.text = message
	toast.visible = true
	move_child(toast, get_child_count() - 1)
	toast.custom_minimum_size = Vector2(minf(640.0, size.x - 32.0), 0)
	toast.reset_size()
	toast.position = Vector2((size.x - toast.size.x) * 0.5, size.y - toast.size.y - 24.0)
	toast_left = 5.0


func _process(delta: float) -> void:
	if toast != null and toast.visible:
		toast_left -= delta
		if toast_left <= 0.0:
			toast.visible = false


# ---------------------------------------------------------------- Modal dialogs

## options: Array of [label, Callable, enabled].
func show_modal(title: String, body: String, options: Array, can_cancel: bool = false) -> void:
	close_modal()
	modal_can_cancel = can_cancel
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	modal = layer
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label(title, 26, ACCENT))
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(540, 0)
	box.add_child(text)
	var first: Button = null
	for opt in options:
		var b := _button(opt[0], opt[1])
		b.disabled = not opt[2]
		b.custom_minimum_size = Vector2(0, 44)
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first != null:
		first.grab_focus.call_deferred()


func close_modal() -> void:
	if modal != null:
		modal.queue_free()
	modal = null
	settings_open = false
