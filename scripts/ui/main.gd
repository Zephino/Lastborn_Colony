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
const Tips = preload("res://scripts/sim/tips.gd")
const StatsGraph = preload("res://scripts/ui/stats_graph.gd")
const Records = preload("res://scripts/ui/records.gd")
const Online = preload("res://scripts/net/online.gd")
const OnlineConfig = preload("res://scripts/net/online_config.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")
const SetupFlow = preload("res://scripts/ui/setup_flow.gd")
const ColonyText = preload("res://scripts/ui/colony_text.gd")
const Menus = preload("res://scripts/ui/menus.gd")
const FleetMenu = preload("res://scripts/ui/fleet_menu.gd")
const SpriteIcon = preload("res://scripts/ui/sprite_icon.gd")
const StatIcon = preload("res://scripts/ui/stat_icon.gd")
const UiUtil = preload("res://scripts/ui/ui_util.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")



const BG := Color(0.06, 0.07, 0.09)
const PANEL := Color(0.10, 0.11, 0.14)
const ACCENT := Color(0.95, 0.62, 0.30)
const CATEGORIES := [["core", "Network"], ["energy", "Energy"], ["life", "Life support"], ["industry", "Industry"], ["civic", "Civic"]]
const STAT_KEYS := ["turn", "pop", "morale", "power", "heat", "workers", "food", "oxygen", "water", "ore", "alloy", "parts", "marks", "debt", "payment"]

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
## Map animations on or off (Settings), remembered in user://settings.cfg.
var animations := true
## First-game tips on or off (Settings), remembered in user://settings.cfg.
var tips_on := true
var tip_bar: PanelContainer
var tip_label: Label
## The turn a tip was last checked, so at most one new tip shows a turn.
var _tip_turn := -1
const SETTINGS_PATH := "user://settings.cfg"
var menus: RefCounted
var fleet_menu: RefCounted
## The picture of the selected building at the top of the side panel.
var building_pic: Control
var signed_in_label: Label
var narrow_game := false
var ui_theme: Theme
var placing_bar: PanelContainer
var surface_button: Button
var deep_button: Button
var level_toggle: Button
var placing_label: Label


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		animations = bool(cfg.get_value("display", "animations", true))
		tips_on = bool(cfg.get_value("display", "tips", true))
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	var t := Theme.new()
	t.default_font_size = 15
	ui_theme = t
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", panel_style)
	theme = t
	_apply_ui_scale()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	menus = Menus.new(self)
	fleet_menu = FleetMenu.new(self)
	online = Online.new()
	add_child(online)
	online.board_loaded.connect(menus._on_board_loaded)
	online.score_submitted.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.sign_in_message.connect(_toast)
	online.account_changed.connect(menus._on_account_changed)
	online.cloud_saved.connect(func(_ok: bool, message: String) -> void: _toast(message))
	online.cloud_loaded.connect(menus._on_cloud_loaded)
	if online.has_signal("suggestion_sent"):
		online.suggestion_sent.connect(menus._on_suggestion_sent)
	player_name = menus._load_profile().get("name", "")
	show_title()


## Phones and high-density screens have 2-3 physical pixels per point; without
## this, every menu would be drawn tiny. The interface is laid out in points
## and scaled up by the device's pixel ratio.
func _apply_ui_scale() -> void:
	var win := get_window()
	var ratio := 1.0
	if AppActions.is_web():
		ratio = clampf(DisplayServer.screen_get_scale(), 1.0, 4.0)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(maxi(1, int(win.size.x / ratio)), maxi(1, int(win.size.y / ratio)))
	# Phones: slightly bigger text everywhere.
	if ui_theme != null:
		ui_theme.default_font_size = 17 if win.content_scale_size.x < 600 else 15


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
	var narrow := _view_size().x < 520.0
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	screen = root
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(minf(420.0, _view_size().x - 32.0), 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label(GameData.story()["title"], 40 if narrow else 56, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var sub := _label("A colony on the edge between night and day.", 16, Color(0.75, 0.78, 0.82))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	signed_in_label = _label("", 14, Color(0.45, 0.85, 0.55))
	signed_in_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(signed_in_label)
	_refresh_signed_in()
	box.add_child(HSeparator.new())
	box.add_child(_label("Colony name"))
	var name_edit := LineEdit.new()
	name_edit.text = "Margin"
	name_edit.max_length = TextRules.MAX_COLONY_NAME
	name_edit.placeholder_text = "Letters, numbers, spaces, - and _"
	name_edit.custom_minimum_size = Vector2(0, 44)
	box.add_child(name_edit)
	box.add_child(_label("Map seed"))
	var seed_box := SpinBox.new()
	seed_box.min_value = 1
	seed_box.max_value = 999999
	seed_box.rounded = true
	seed_box.value = randi_range(1, 999999)
	seed_box.custom_minimum_size = Vector2(0, 44)
	box.add_child(seed_box)
	box.add_child(_label("Your name on the leaderboard"))
	var player_edit := LineEdit.new()
	player_edit.text = player_name
	player_edit.max_length = TextRules.MAX_PLAYER_NAME
	player_edit.placeholder_text = "Letters, numbers, spaces, - and _"
	player_edit.custom_minimum_size = Vector2(0, 44)
	player_edit.text_changed.connect(menus._on_player_name_changed)
	box.add_child(player_edit)
	box.add_child(_title_button("New colony", _on_new_colony.bind(name_edit, seed_box)))
	for slot in ["manual", "autosave"]:
		if SaveGame.exists(slot):
			var label := "Load saved game" if slot == "manual" else "Load autosave"
			box.add_child(_title_button(label, func() -> void: _load(slot)))
	box.add_child(_title_button("How to play", menus.show_help.bind(0)))
	box.add_child(_title_button("Leaderboard", show_leaderboard.bind("")))
	box.add_child(_title_button("Suggest a feature", menus.show_suggestion_form))
	box.add_child(_title_button("Settings", show_settings))
	box.add_child(_title_button("Quit", _quit))
	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 13, Color(0.55, 0.6, 0.66))
	root.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)


func _title_button(text: String, action: Callable) -> Button:
	var b := _button(text, action)
	b.custom_minimum_size = Vector2(0, 44)
	return b


## Shows "Signed in with Google" on the title screen (no name: Settings has that).
func _refresh_signed_in() -> void:
	if signed_in_label == null or not is_instance_valid(signed_in_label):
		return
	signed_in_label.text = "Signed in with Google" if online != null and online.is_signed_in() else ""
	signed_in_label.visible = signed_in_label.text != ""


## Quit: closes the game. In a browser a page can't always close its own tab,
## so if it's still open after trying, say so.
func _quit() -> void:
	if not AppActions.is_web():
		get_tree().quit()
		return
	JavaScriptBridge.eval("window.close()", true)
	show_modal("Quit", "Your games are saved in this browser. You can close this tab now.", [["Back", close_modal, true]], true)


## The screen size in interface units (after scaling for the device).
func _view_size() -> Vector2:
	return get_viewport_rect().size


func _on_new_colony(name_edit: LineEdit, seed_box: SpinBox) -> void:
	var colony := TextRules.clean_colony_name(name_edit.text)
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
	var body := "The ship is down on the landing pad on %s. Starting debt: %d marks. The first payment is due on turn %d." % [planet["name"], int(state["debt"]), int(GameData.balance()["first_payment_turn"])]
	if not kits.is_empty():
		body += "\n\nPrefab kits in the hold (free to place, shown on the left): " + ", ".join(kits) + "."
	_tip_turn = -1
	show_modal("Landed", body, [["Begin", _begin, true]], true)


## Closes the landing message and shows the first tip.
func _begin() -> void:
	close_modal()
	_check_tip()


func _load(slot: String) -> void:
	_tip_turn = -1
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

	narrow_game = _view_size().x < 760.0
	level_toggle = null
	# Top bar.
	var top := PanelContainer.new()
	root.add_child(top)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 18)
	top.add_child(stats)
	stat_labels.clear()
	stats.add_theme_constant_override("h_separation", 12 if narrow_game else 18)
	for key in STAT_KEYS:
		# Each number has its icon beside it.
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var icon := StatIcon.new(key, 18.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var l := _label("")
		item.add_child(l)
		stats.add_child(item)
		stat_labels[key] = l
		# On phones the less urgent numbers live in the Report instead.
		item.visible = not (narrow_game and key in ["power", "heat", "workers", "ore", "parts", "payment"])

	# Middle: build menu | map | inspector.
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	# Phones: the map gets the whole width. The build list opens from a Build
	# button, the side panel's contents from Info, Research and Company, and
	# the buttons wrap.
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	left.visible = not narrow_game
	middle.add_child(left)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(menu)
	var level_row := HBoxContainer.new()
	menu.add_child(level_row)
	surface_button = _button("Surface", func() -> void: _set_level(0))
	deep_button = _button("Deep", func() -> void: _set_level(1))
	for b in [surface_button, deep_button]:
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_row.add_child(b)
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
			b.tooltip_text = GameData.desc(def)
			b.clip_text = true
			b.pressed.connect(func() -> void: _set_build("" if map_view.build_type == id else id))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row := HBoxContainer.new()
			row.add_child(SpriteIcon.new(id, 40.0))
			row.add_child(b)
			menu.add_child(row)
			build_buttons[id] = b

	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.animate = animations
	map_view.tile_clicked.connect(_on_tile_clicked)
	map_view.tile_hovered.connect(func(_c: Vector2i) -> void: _refresh_hint())
	middle.add_child(map_view)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.visible = not narrow_game
	middle.add_child(right)
	var right_box := VBoxContainer.new()
	right.add_child(right_box)
	building_pic = SpriteIcon.new("", 120.0)
	building_pic.custom_minimum_size = Vector2(0, 120)
	building_pic.visible = false
	right_box.add_child(building_pic)
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
	right_box.add_child(_button("Drones & orbit", show_fleet))
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

	# Shown while a building is chosen: what is being placed, and Cancel. It sits
	# over the top of the map, so the map doesn't jump when it appears.
	placing_bar = PanelContainer.new()
	placing_bar.visible = false
	map_view.add_child(placing_bar)
	placing_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var placing_row := HBoxContainer.new()
	placing_bar.add_child(placing_row)
	placing_label = _label("", 0, ACCENT)
	placing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placing_row.add_child(placing_label)
	var turn_button := _button("Rotate", _rotate_build)
	turn_button.custom_minimum_size = Vector2(88, 44)
	turn_button.tooltip_text = "Turn the building so its doors face where you want (R)."
	placing_row.add_child(turn_button)
	var cancel := _button("Cancel", func() -> void: _set_build(""))
	cancel.custom_minimum_size = Vector2(88, 44)
	placing_row.add_child(cancel)

	# A tip for new players, over the bottom of the map: Got it, or No more tips.
	tip_bar = PanelContainer.new()
	tip_bar.visible = false
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
	tip_style.border_color = ACCENT
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(6)
	tip_style.set_content_margin_all(10)
	tip_bar.add_theme_stylebox_override("panel", tip_style)
	map_view.add_child(tip_bar)
	tip_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tip_bar.offset_left = 12
	tip_bar.offset_right = -12
	tip_bar.offset_bottom = -12
	tip_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 8)
	tip_bar.add_child(tip_row)
	tip_label = _label("", 0, Color.WHITE)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_row.add_child(tip_label)
	var got := _button("Got it", func() -> void: tip_bar.visible = false)
	got.custom_minimum_size = Vector2(88, 40)
	tip_row.add_child(got)
	var off := _button("No more tips", func() -> void: set_tips(false))
	off.custom_minimum_size = Vector2(120, 40)
	tip_row.add_child(off)

	# Bottom: log and turn controls.
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 150 if narrow_game else 170)
	root.add_child(bottom)
	var bottom_row: BoxContainer = VBoxContainer.new() if narrow_game else HBoxContainer.new()
	bottom.add_child(bottom_row)
	var log_box := VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(log_box)
	hint_label = _label("", 13, Color(0.7, 0.75, 0.8))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(120, 0)
	log_box.add_child(hint_label)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_child(log_view)
	var buttons: Container = HFlowContainer.new() if narrow_game else VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(0 if narrow_game else 150, 0)
	if narrow_game:
		bottom_row.add_child(buttons)
		bottom_row.move_child(buttons, 0)
	else:
		bottom_row.add_child(buttons)
	end_turn_button = _button("End turn  (Enter)", func() -> void: _run_turns(1))
	buttons.add_child(end_turn_button)
	run_button = _button("Run 5 turns", func() -> void: _run_turns(5))
	buttons.add_child(run_button)
	if narrow_game:
		buttons.add_child(_button("Build", show_build_menu))
		level_toggle = _button("Deep", func() -> void: _set_level(1 - map_view.level))
		buttons.add_child(level_toggle)
		buttons.add_child(_button("−", func() -> void: map_view.zoom_by(1.0 / 1.25)))
		buttons.add_child(_button("+", func() -> void: map_view.zoom_by(1.25)))
		buttons.add_child(_button("Info", show_info))
		buttons.add_child(_button("Research", show_research))
		buttons.add_child(_button("Company", show_company))
		buttons.add_child(_button("Drones", show_fleet))
	buttons.add_child(_button("Report" if narrow_game else "Colony report", show_report))
	buttons.add_child(_button("Save", _on_save))
	buttons.add_child(_button("Menu", _on_menu))
	if narrow_game:
		for b in buttons.get_children():
			(b as Button).custom_minimum_size = Vector2(44 if (b as Button).text.length() <= 1 else 76, 44)
		end_turn_button.text = "End turn"

	map_view.set_state(state)
	if narrow_game:
		map_view.tile_size = 110.0
	map_view.center_on(_hull_cell())
	_update_level_buttons()
	refresh()


## Shows the surface (0) or the Deep (1).
func _set_level(z: int) -> void:
	map_view.level = z
	map_view.selected = Vector2i(-1, -1)
	if z == 1:
		var landing := Vector2i(-1, -1)
		for id in state["structures"]:
			var st: Dictionary = state["structures"][id]
			if st["type"] == "shaft_base":
				landing = Vector2i(int(st["x"]), int(st["y"]))
				break
		if landing.x >= 0:
			map_view.center_on(landing)
		else:
			_toast("The Deep: build a Shaft on the surface first. When it's finished, a landing opens down here.")
	else:
		map_view.center_on(_hull_cell())
	_update_level_buttons()
	refresh()


func _update_level_buttons() -> void:
	var z: int = map_view.level if map_view != null else 0
	if surface_button != null:
		surface_button.button_pressed = z == 0
		deep_button.button_pressed = z == 1
	if level_toggle != null:
		level_toggle.text = "Surface" if z == 1 else "Deep"


func _hull_cell() -> Vector2i:
	for id in state["structures"]:
		var st: Dictionary = state["structures"][id]
		if st["type"] == "hull":
			return Vector2i(int(st["x"]), int(st["y"]))
	return Vector2i(int(state["width"]) / 2, int(state["height"]) / 2)


## Phones: the build list as a dialog with big buttons. Choosing a building
## starts placing it; the next tap on the map places it once.
func show_build_menu() -> void:
	var options: Array = []
	for cat in CATEGORIES:
		for id in GameData.building_ids():
			var def := GameData.building(id)
			if def["category"] != cat[0] or not def.get("buildable", true):
				continue
			var price := Actions.price_text(state, id, true)
			options.append(["%s (%s)\n%s" % [def["name"], price, GameData.desc(def)], _pick_build.bind(id), Actions.affordable(state, id) and state["ending"] == "", id])
	options.append(["Back", close_modal, true])
	show_modal("Build", "You have %d alloy and %d parts. Choose a building, then tap a tile next to the colony. Dragging the map never builds." % [int(state["stock"]["alloy"]), int(state["stock"]["parts"])], options, true)


func _pick_build(id: String) -> void:
	close_modal()
	_set_build(id)


func _set_build(id: String) -> void:
	if map_view == null:
		return
	map_view.build_type = id
	map_view.build_rot = -1
	for key in build_buttons:
		build_buttons[key].button_pressed = key == id
	if placing_bar != null:
		placing_bar.visible = id != ""
		if id != "":
			placing_label.text = "Placing %s: tap a green tile. Its doors (orange) must face a door or Tunnel; Rotate turns it." % GameData.building(id)["name"] if narrow_game else "Placing %s: click a green tile. Its doors (orange) must face a door or Tunnel; R or Rotate turns it. Esc to stop." % GameData.building(id)["name"]
	map_view.queue_redraw()
	_refresh_hint()


## Turns the building being placed a quarter-turn (its doors move round).
func _rotate_build() -> void:
	if map_view == null or map_view.build_type == "":
		return
	map_view.rotate_build()
	_refresh_hint()


func _on_tile_clicked(cell: Vector2i) -> void:
	if modal != null or state["ending"] != "":
		map_view.selected = cell
		refresh()
		return
	if map_view.build_type != "":
		var placed_type: String = map_view.build_type
		var r := Actions.place(state, placed_type, cell.x, cell.y, map_view.level, map_view.build_rot)
		if not r["ok"]:
			hint_label.text = r["reason"]
			if narrow_game:
				_toast(r["reason"])
			return
		map_view.selected = cell
		if narrow_game:
			# One building per choice on phones, so a stray tap can't build again.
			_set_build("")
			_toast("%s placed. It will be built in %d turns." % [GameData.building(placed_type)["name"], int(GameData.num(GameData.building(placed_type), "turns"))])
		refresh()
		return
	map_view.selected = cell
	refresh()
	if narrow_game:
		show_info()


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
		["How to play", menus.show_help.bind(0), true],
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
	_check_tip()
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
	var best := Records.note_game(state)
	if best != "":
		body += "\n\n" + best
	show_modal(e["title"], body, [["Post score to the leaderboard", menus._post_score.bind(""), OnlineConfig.enabled()], ["Graphs and records", show_stats, true], ["Look around", close_modal, true], ["Back to title", show_title, true]])


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
	var step := 48.0
	var pan_keys := {KEY_LEFT: Vector2(step, 0), KEY_A: Vector2(step, 0), KEY_RIGHT: Vector2(-step, 0), KEY_D: Vector2(-step, 0),
		KEY_UP: Vector2(0, step), KEY_W: Vector2(0, step), KEY_DOWN: Vector2(0, -step), KEY_S: Vector2(0, -step)}
	if modal == null and pan_keys.has(key) and not (get_viewport().gui_get_focus_owner() is LineEdit):
		map_view.pan_by(pan_keys[key])
		get_viewport().set_input_as_handled()
		return
	if key == KEY_R and modal == null and map_view.build_type != "" and not (get_viewport().gui_get_focus_owner() is LineEdit):
		_rotate_build()
		get_viewport().set_input_as_handled()
		return
	if (key == KEY_Q or key == KEY_E) and modal == null and not (get_viewport().gui_get_focus_owner() is LineEdit):
		_set_level(0 if key == KEY_Q else 1)
		get_viewport().set_input_as_handled()
		return
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
	for k in ["food", "oxygen", "water", "ore", "alloy", "parts"]:
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
		build_buttons[id].text = "%s  (%s)" % [def["name"], Actions.price_text(state, id)]
		build_buttons[id].disabled = not Actions.affordable(state, id) or state["ending"] != ""
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
		var text := "Placing %s. %s" % [def["name"], GameData.desc(def)]
		var h: Vector2i = map_view.hover
		if h.x >= 0:
			var r := Actions.check_place(state, map_view.build_type, h.x, h.y, map_view.level, map_view.build_rot)
			if not r["ok"]:
				text = r["reason"]
			elif GameData.num(def, "heat_need") > 0.0:
				var cold := float(GameData.balance()["deep"]["cold"]) if map_view.level == 1 else GameData.cold_at(h.x, state["planet"])
				text += "  Heat here: %.1f." % (GameData.num(def, "heat_need") * cold)
				var extra := Actions.build_cost(state, map_view.build_type, h.x, h.y, map_view.level) - GameData.num(def, "cost")
				if extra > 0.0:
					text += "  Digging through rock: +%d alloy, +%d turns." % [int(extra), int(GameData.balance()["deep"]["excavate_turns"])]
		hint_label.text = text
	else:
		hint_label.text = "Tap a tile to inspect it. Tap Build to choose a building. Drag the map to move it; pinch or use − and + to zoom." if narrow_game else "Click a tile to inspect it. Choose a building on the left to place it. Drag the map to move it; wheel to zoom."


func _selected_structure() -> Dictionary:
	var c: Vector2i = map_view.selected
	if c.x < 0:
		return {}
	return Actions.structure_at(state, c.x, c.y, map_view.level)


func _refresh_inspector() -> void:
	var c: Vector2i = map_view.selected
	var s := _selected_structure()
	demolish_button.visible = not s.is_empty() and s["type"] != "hull"
	inspector.text = ColonyText.summary(state) if c.x < 0 else ColonyText.tile(state, c, map_view.level)
	if building_pic != null:
		building_pic.show_type("" if s.is_empty() else str(s["type"]))


## Phones: the side panel's contents as dialogs.
func show_info() -> void:
	var s := _selected_structure()
	var options: Array = []
	if not s.is_empty() and s["type"] != "hull":
		options.append(["Demolish", _demolish_and_close, true])
	options.append(["Back", close_modal, true])
	show_modal("Info", _plain(inspector.text), options, true, "" if s.is_empty() else str(s["type"]))


func _demolish_and_close() -> void:
	_on_demolish()
	close_modal()


func show_company() -> void:
	var body := "Debt: %s marks. Next payment: %s on turn %d.\nMarks: %s.\nExport reserve: %d alloy (Spin Launchers never sell below this)." % [
		_fmt(float(state["debt"])), _fmt(Turn.next_payment_amount(state)), Turn.next_payment_turn(state),
		_fmt(float(state["stock"]["credits"])), int(state["export_reserve"])]
	show_modal("Company account", body, [
		["Pay 100 marks early", _company_action.bind("pay", 100.0), true],
		["Pay 500 marks early", _company_action.bind("pay", 500.0), true],
		["Export reserve +10", _company_action.bind("reserve", 10.0), true],
		["Export reserve -10", _company_action.bind("reserve", -10.0), true],
		["Back", close_modal, true]], true)


func _company_action(kind: String, amount: float) -> void:
	if kind == "pay":
		_pay(amount)
	else:
		_change_reserve(amount)
	show_company()


## BBCode text as plain text, for dialogs.
func _plain(bbcode: String) -> String:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = bbcode
	var out := r.get_parsed_text()
	r.free()
	return out


func show_report() -> void:
	show_modal("Colony report, turn %d" % (int(state["turn"]) - 1), ColonyText.report(state), [["Graphs and records", show_stats, true], ["Back", close_modal, true]], true)


func _refresh_log() -> void:
	var lines := PackedStringArray()
	for entry in state["log"]:
		lines.append("[color=#8a93a0]T%d[/color]  %s" % [int(entry["turn"]), TextRules.escape_bbcode(str(entry["text"]))])
	log_view.text = "\n".join(lines)


# ---------------------------------------------------------------- Menus (scripts/ui/menus.gd)

func show_research() -> void:
	menus.show_research()


func show_fleet() -> void:
	fleet_menu.show()


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
	# Size it for its text at a fixed width (an auto-wrapping label otherwise
	# measures itself one word wide and becomes very tall).
	var w := minf(640.0, _view_size().x - 32.0)
	toast.custom_minimum_size = Vector2(w, 0)
	toast.size = Vector2(w, 0)
	toast.size = Vector2(w, toast.get_minimum_size().y)
	toast.position = Vector2((_view_size().x - w) * 0.5, _view_size().y - toast.size.y - 24.0)
	toast_left = 5.0


func _process(delta: float) -> void:
	if toast != null and toast.visible:
		toast_left -= delta
		if toast_left <= 0.0:
			toast.visible = false


# ---------------------------------------------------------------- Modal dialogs

## options: Array of [label, Callable, enabled].
## options: [label, Callable, enabled] or [label, Callable, enabled, building id];
## with a building id the option shows that building's picture beside it.
## picture: a building id to show large under the title.
## extra: an optional control (such as graphs) shown under the heading.
func show_modal(title: String, body: String, options: Array, can_cancel: bool = false, picture: String = "", extra: Control = null, wide: float = 560.0) -> void:
	close_modal()
	modal_can_cancel = can_cancel
	var view := _view_size()
	var width := minf(wide, view.x - 24.0)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	modal = layer
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	# Long dialogs scroll, so they work on short phone screens too.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := _label(title, 26 if view.x >= 520.0 else 22, ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	if picture != "":
		var pic := SpriteIcon.new(picture, 150.0)
		pic.custom_minimum_size = Vector2(width - 24.0, 150.0)
		box.add_child(pic)
	if extra != null:
		extra.custom_minimum_size = Vector2(width - 24.0, maxf(extra.custom_minimum_size.y, 200.0))
		box.add_child(extra)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(width - 20.0, 0)
	box.add_child(text)
	var first: Button = null
	for opt in options:
		var b := _button(opt[0], opt[1])
		b.disabled = not opt[2]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if opt.size() > 3 and str(opt[3]) != "":
			var row := HBoxContainer.new()
			var icon := SpriteIcon.new(str(opt[3]), 72.0)
			if b.disabled:
				icon.modulate = Color(1, 1, 1, 0.45)
			row.add_child(icon)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiUtil.fit_button_height(b, width - 24.0 - 80.0)
			row.add_child(b)
			box.add_child(row)
		else:
			UiUtil.fit_button_height(b, width - 24.0)
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


## Turns the map's animations on or off, and remembers the choice.
func set_animations(on: bool) -> void:
	animations = on
	if map_view != null:
		map_view.animate = on
		map_view.queue_redraw()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "animations", on)
	cfg.save(SETTINGS_PATH)


## Shows the next first-game tip, if tips are on and none showed this turn.
func _check_tip() -> void:
	if not tips_on or tip_bar == null or state.is_empty() or state["ending"] != "":
		return
	if _tip_turn == int(state["turn"]):
		return
	var tip := Tips.next(state)
	if tip.is_empty():
		return
	_tip_turn = int(state["turn"])
	tip_label.text = "Tip: " + str(tip["text"])
	tip_bar.visible = true


## Turns first-game tips on or off, and remembers the choice.
func set_tips(on: bool) -> void:
	tips_on = on
	if tip_bar != null and not on:
		tip_bar.visible = false
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "tips", on)
	cfg.save(SETTINGS_PATH)


## Graphs of how the colony has done turn by turn, and your best results.
func show_stats() -> void:
	var graph := StatsGraph.new()
	graph.history = state.get("history", [])
	graph.custom_minimum_size = Vector2(0, 360)
	var body := Records.summary(str(state.get("planet", "")))
	if graph.history.size() < 2:
		body = "Play a few turns to see the graphs.\n\n" + body
	show_modal("Graphs and records", body, [["Back", close_modal, true]], true, "", graph, 820.0)
