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
const SetupFlow = preload("res://scripts/ui/setup_flow.gd")
const ColonyText = preload("res://scripts/ui/colony_text.gd")
const Menus = preload("res://scripts/ui/menus.gd")



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
var menus: RefCounted


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
	menus = Menus.new(self)
	online = Online.new()
	add_child(online)
	online.board_loaded.connect(menus._on_board_loaded)
	online.score_submitted.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.sign_in_message.connect(_toast)
	online.account_changed.connect(menus._on_account_changed)
	online.cloud_saved.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.cloud_loaded.connect(menus._on_cloud_loaded)
	player_name = menus._load_profile().get("name", "")
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
	player_edit.text_changed.connect(menus._on_player_name_changed)
	box.add_child(player_edit)
	box.add_child(_button("New colony", _on_new_colony.bind(name_edit, seed_box)))
	for slot in ["manual", "autosave"]:
		if SaveGame.exists(slot):
			var label := "Load saved game" if slot == "manual" else "Load autosave"
			box.add_child(_button(label, func() -> void: _load(slot)))
	box.add_child(_button("Leaderboard", show_leaderboard.bind("")))
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
	var seed_value := int(seed_box.value)
	_clear_screen()
	var flow := SetupFlow.new()
	add_child(flow)
	screen = flow
	flow.setup(seed_value)
	flow.cancelled.connect(show_title)
	flow.finished.connect(_start_new.bind(seed_value, colony))


func _start_new(options: Dictionary, seed_value: int, colony: String) -> void:
	state = NewGame.create(seed_value, colony, options)
	show_game()
	var planet := GameData.planet(state["planet"])
	var kits := PackedStringArray()
	for k in state["kits"]:
		kits.append("%d × %s" % [int(state["kits"][k]), GameData.building(k)["name"]])
	var body := "The hull is down on %s. Starting debt: %d marks. The first payment is due on turn %d." % [planet["name"], int(state["debt"]), int(GameData.balance()["first_payment_turn"])]
	if not kits.is_empty():
		body += "\n\nPrefab kits in the hold (free to place, shown on the left): " + ", ".join(kits) + "."
	show_modal("Landed", body, [["Begin", close_modal, true]], true)


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
	buttons.add_child(_button("Colony report", show_report))
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
		["Retire: post this colony's progress to the leaderboard", menus._post_score.bind("retired"), OnlineConfig.enabled()],
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
	show_modal(e["title"], body, [["Post score to the leaderboard", menus._post_score.bind(""), OnlineConfig.enabled()], ["Look around", close_modal, true], ["Back to title", show_title, true]])


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
	return ColonyText.fmt(v)


func _signed(v: float) -> String:
	return ColonyText.signed(v)


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
		var kits := int(state["kits"].get(id, 0))
		build_buttons[id].text = "%s  (%s)" % [def["name"], ("prefab ×%d" % kits) if kits > 0 else str(int(GameData.num(def, "cost")))]
		build_buttons[id].disabled = (kits <= 0 and float(stock["alloy"]) < GameData.num(def, "cost")) or state["ending"] != ""
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
				text += "  Heat here: %.1f." % (GameData.num(def, "heat_need") * GameData.cold_at(h.x, state["planet"]))
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
	var s := _selected_structure()
	demolish_button.visible = not s.is_empty() and s["type"] != "hull"
	inspector.text = ColonyText.summary(state) if c.x < 0 else ColonyText.tile(state, c)


func show_report() -> void:
	show_modal("Colony report, turn %d" % (int(state["turn"]) - 1), ColonyText.report(state), [["Back", close_modal, true]], true)


func _refresh_log() -> void:
	var lines := PackedStringArray()
	for entry in state["log"]:
		lines.append("[color=#8a93a0]T%d[/color]  %s" % [int(entry["turn"]), entry["text"]])
	log_view.text = "\n".join(lines)


# ---------------------------------------------------------------- Menus (scripts/ui/menus.gd)

func show_research() -> void:
	menus.show_research()


func show_settings() -> void:
	menus.show_settings()


func show_leaderboard(planet_id: String = "") -> void:
	menus.show_leaderboard(planet_id)


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
