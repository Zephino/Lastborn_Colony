## The game's dialogs that aren't part of play: Research, Settings (fullscreen,
## install, update, Google sign-in, cloud save) and the Leaderboard. Split out
## of main.gd; `main` is the main screen (scripts/ui/main.gd), which owns the
## state, the online client and the dialog layer.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Research = preload("res://scripts/sim/research.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const AppActions = preload("res://scripts/ui/app_actions.gd")
const OnlineConfig = preload("res://scripts/net/online_config.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")

const PROFILE_PATH := "user://profile.json"

var main  # the main screen (scripts/ui/main.gd); untyped so its own methods can be called
var board_planet := GameData.DEFAULT_PLANET


func _init(owner_screen: Object) -> void:
	main = owner_screen


# ---------------------------------------------------------------- Research

func show_research() -> void:
	var options: Array = []
	for t in Research.available(main.state):
		var label := "%s (%d): %s" % [t["name"], int(t["cost"]), t["desc"]]
		options.append([label, _choose_research.bind(t["id"]), true])
	var done := PackedStringArray()
	for id in Research.done(main.state):
		done.append(GameData.topic(id)["name"])
	var body := "Survey Labs produce research toward one topic at a time. Changing topic loses progress on the old one."
	if main.state["plague"]["active"]:
		body += "\n\nDuring the plague, all research goes to the cure first."
	body += "\n\nFinished: " + (", ".join(done) if not done.is_empty() else "none yet") + "."
	if options.is_empty():
		body += "\n\nEverything has been researched."
	options.append(["Back", Callable(main, "close_modal"), true])
	main.show_modal("Research", body, options, true)


func _choose_research(id: String) -> void:
	Actions.set_research(main.state, id)
	main.close_modal()
	main.refresh()


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
		if main.online.is_signed_in():
			notes.append("Signed in as %s. Cloud save keeps one game for your account, so you can carry on from another device." % main.online.account_name())
			options.append(["Save this game to the cloud" if not main.state.is_empty() else "Save my last saved game to the cloud", _cloud_upload, not main.state.is_empty() or SaveGame.exists("manual")])
			options.append(["Load my game from the cloud", Callable(main.online, "download_save"), true])
			options.append(["Sign out", Callable(main.online, "sign_out"), true])
		elif main.online.is_signing_in():
			notes.append("Finish signing in with Google in your browser.")
			options.append(["Cancel sign-in", Callable(main.online, "cancel_sign_in"), true])
		else:
			options.append(["Sign in with Google", Callable(main.online, "start_sign_in"), true])
			notes.append("Signing in lets you keep a cloud save and carry on from another device. It's optional.")
	options.append(["Back", _close_settings, true])
	var body := "Lastborn Colony v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	if not notes.is_empty():
		body += "\n\n" + "\n".join(notes)
	main.show_modal("Settings", body, options, true)
	main.settings_open = true


func _close_settings() -> void:
	main.close_modal()


func _on_fullscreen() -> void:
	AppActions.toggle_fullscreen()
	show_settings.call_deferred()


func _on_install() -> void:
	if AppActions.install_state() == "ready":
		AppActions.install()
	show_settings.call_deferred()


func _on_update() -> void:
	if main.state.size() > 0 and main.state.get("ending", "") == "":
		SaveGame.save(main.state, "autosave")
	AppActions.update_now()


# ---------------------------------------------------------------- Online

func _on_account_changed() -> void:
	main._refresh_signed_in()
	if main.settings_open:
		show_settings()


func _on_player_name_changed(text: String) -> void:
	# The field keeps what was typed; only the cleaned name is stored and sent.
	main.player_name = TextRules.clean_name(text, TextRules.MAX_PLAYER_NAME)
	_save_profile()


func _load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return {"name": TextRules.clean_name(str(parsed.get("name", "")), TextRules.MAX_PLAYER_NAME)}


func _save_profile() -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": main.player_name}))


func _post_score(ending_override: String) -> void:
	if main.state.is_empty():
		return
	var entry := ScoreEntry.from_state(main.state, main.player_name, ending_override)
	var problem := ScoreEntry.problem(entry)
	if problem != "":
		main._toast(problem)
		return
	main.online.submit_score(entry)
	main._toast("Sending score…")




func show_leaderboard(planet_id: String = "") -> void:
	if planet_id != "":
		board_planet = planet_id
	main.show_modal("Leaderboard: %s" % GameData.planet(board_planet)["name"], "Loading…", _board_options(), true)
	main.online.fetch_board(board_planet)


func _board_options() -> Array:
	var options: Array = []
	for p in GameData.planets():
		if p["id"] != board_planet:
			options.append(["Show %s" % p["name"], show_leaderboard.bind(p["id"]), true])
	options.append(["Back", Callable(main, "close_modal"), true])
	return options


func _on_board_loaded(entries: Array, error: String) -> void:
	if main.modal == null:
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
	main.show_modal("Leaderboard: %s" % GameData.planet(board_planet)["name"], "\n".join(lines), _board_options(), true)


func _cloud_upload() -> void:
	if not main.state.is_empty():
		main.online.upload_save(SaveGame.to_text(main.state))
	elif SaveGame.exists("manual"):
		main.online.upload_save(FileAccess.get_file_as_string(SaveGame.path_for("manual")))


func _on_cloud_loaded(text: String, error: String) -> void:
	if error != "":
		main._toast(error)
		return
	var loaded: Variant = SaveGame.from_text(text)
	if typeof(loaded) == TYPE_STRING:
		main._toast(loaded)
		return
	main.state = loaded
	SaveGame.save(main.state, "manual")
	main.show_game()
	main._after_turn()
	main._toast("Loaded your game from the cloud.")


# ---------------------------------------------------------------- Suggest a feature

const Online = preload("res://scripts/net/online.gd")

var _suggestion_category: OptionButton
var _suggestion_title: LineEdit
var _suggestion_text: TextEdit
var _suggestion_send: Button


## A form that sends a suggestion to the owner (it becomes a GitHub Issue
## through the online service). No account or email is needed. Everything typed
## is cleaned here (TextRules.clean_text) and checked again by the server.
func show_suggestion_form() -> void:
	main.show_modal("Suggest a feature", "Ideas, problems, anything. Your suggestion is posted publicly on the game's GitHub page, so don't include private details.", [], true)
	var box: VBoxContainer = _modal_box()
	_suggestion_category = OptionButton.new()
	_suggestion_category.custom_minimum_size = Vector2(0, 44)
	for c in Online.suggestion_categories():
		_suggestion_category.add_item(str(c))
	box.add_child(main._label("Category"))
	box.add_child(_suggestion_category)
	box.add_child(main._label("Short title"))
	_suggestion_title = LineEdit.new()
	_suggestion_title.max_length = Online.SUGGESTION_MAX_TITLE
	_suggestion_title.custom_minimum_size = Vector2(0, 44)
	_suggestion_title.placeholder_text = "For example: A map legend"
	box.add_child(_suggestion_title)
	box.add_child(main._label("Details"))
	_suggestion_text = TextEdit.new()
	_suggestion_text.custom_minimum_size = Vector2(0, 140)
	_suggestion_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_suggestion_text.placeholder_text = "What would you like, and why? (at least %d characters)" % Online.SUGGESTION_MIN_DESCRIPTION
	_suggestion_text.text_changed.connect(_limit_suggestion_text)
	box.add_child(_suggestion_text)
	_suggestion_send = main._button("Send", _send_suggestion)
	_suggestion_send.custom_minimum_size = Vector2(0, 44)
	box.add_child(_suggestion_send)
	var close: Button = main._button("Close", Callable(main, "close_modal"))
	close.custom_minimum_size = Vector2(0, 44)
	box.add_child(close)
	_suggestion_title.grab_focus.call_deferred()


## The VBox inside the dialog that show_modal just opened.
func _modal_box() -> VBoxContainer:
	var boxes: Array = main.modal.find_children("*", "VBoxContainer", true, false)
	return boxes[0]


func _limit_suggestion_text() -> void:
	if _suggestion_text.text.length() > Online.SUGGESTION_MAX_DESCRIPTION:
		_suggestion_text.text = _suggestion_text.text.substr(0, Online.SUGGESTION_MAX_DESCRIPTION)
		_suggestion_text.set_caret_column(_suggestion_text.get_line(_suggestion_text.get_line_count() - 1).length())
		_suggestion_text.set_caret_line(_suggestion_text.get_line_count() - 1)


func _send_suggestion() -> void:
	var title := TextRules.clean_text(_suggestion_title.text, Online.SUGGESTION_MAX_TITLE)
	var text := TextRules.clean_text(_suggestion_text.text, Online.SUGGESTION_MAX_DESCRIPTION, true)
	var category := _suggestion_category.get_item_text(_suggestion_category.selected)
	var problem := Online.suggestion_problem(category, title, text)
	if problem != "":
		main._toast(problem)
		return
	_suggestion_send.disabled = true
	_suggestion_send.text = "Sending…"
	main.online.submit_suggestion(category, title, text)


func _on_suggestion_sent(ok: bool, message: String) -> void:
	main._toast(message)
	if ok:
		main.close_modal()
	elif _suggestion_send != null and is_instance_valid(_suggestion_send):
		_suggestion_send.disabled = false
		_suggestion_send.text = "Send"
