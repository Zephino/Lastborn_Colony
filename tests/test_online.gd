## Headless checks for the online code that needs no network: building and
## checking leaderboard scores, reading the Worker's answers, the account file,
## the server addresses, and tidying and checking suggestions. Called from tests/run_tests.gd:
##   const TestOnline = preload("res://tests/test_online.gd")
##   TestOnline.run(check)
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const OnlineConfig = preload("res://scripts/net/online_config.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")
const Online = preload("res://scripts/net/online.gd")

const OK_RESULT := 0  # HTTPRequest.RESULT_SUCCESS
const NO_CONNECTION := 4  # HTTPRequest.RESULT_CANT_CONNECT


static func run(check: Callable) -> void:
	print("Online")
	_score_entries(check)
	_score_checks(check)
	_replies(check)
	_account_file(check)
	_config(check)
	_suggestions(check)


static func _score_entries(check: Callable) -> void:
	var state := NewGame.create(7, "Margin Point")
	var start := {"debt": float(state["debt_total"]), "adults": float(state["adults"]), "children": float(state["children"]), "elders": float(state["elders"])}
	var e := ScoreEntry.from_state(state, "  Zeph!! ino ", "")
	check.call(e["name"] == "Zeph ino", "score name keeps only safe characters")
	check.call(e["colony"] == "Margin Point", "score carries the colony name")
	check.call(e["planet"] == "brume", "score planet defaults to brume")
	check.call(e["ending"] == "retired", "an unfinished game is sent as retired")
	check.call(e["turn"] == 1 and e["debt_paid"] == 0, "a new colony has turn 1 and nothing paid")
	check.call(e["debt_total"] == int(start["debt"]), "debt_total comes from the state's starting debt")
	check.call(e["population"] == int(round(float(start["adults"]) + float(start["children"]) + float(start.get("elders", 0)))), "population counts adults, children and elders")
	check.call(e["version"] == str(ProjectSettings.get_setting("application/config/version")), "score carries the game version")
	check.call(ScoreEntry.problem(e) == "", "a fresh game's score passes the Worker's rules")
	check.call(not e.has("date"), "the date is left to the Worker")

	state["turn"] = 88
	state["debt"] = 1500.4
	state["adults"] = 40.6
	state["ending"] = "receivership"
	e = ScoreEntry.from_state(state, "Ari", "")
	check.call(e["ending"] == "receivership" and e["turn"] == 88, "score uses the state's ending and turn")
	check.call(e["debt_paid"] == int(start["debt"]) - 1500, "debt_paid is the debt paid off, rounded")
	e = ScoreEntry.from_state(state, "Ari", "retired")
	check.call(e["ending"] == "retired", "ending_override wins")

	state["ending"] = "free"
	state["debt"] = -3.0
	e = ScoreEntry.from_state(state, "Ari", "")
	check.call(e["debt_paid"] == e["debt_total"] and ScoreEntry.problem(e) == "", "a free colony has paid everything")
	state["planet"] = "cinder"
	state["colony_name"] = "Ünïcode ✓"
	state["turn"] = 99999
	e = ScoreEntry.from_state(state, "Ari", "")
	check.call(e["planet"] == "cinder", "score uses the state's planet when set")
	check.call(e["colony"] == "ncode", "colony name keeps only safe characters")
	check.call(e["turn"] == ScoreEntry.MAX_TURN, "turn is capped at the Worker's limit")
	state["colony_name"] = "✓✓"
	check.call(ScoreEntry.from_state(state, "Ari", "")["colony"] == OnlineConfig.text("default_colony"), "an unusable colony name falls back to the default")
	check.call(ScoreEntry.clean_name("ABCDEFGHIJKLMNOPQRST", ScoreEntry.MAX_NAME_LENGTH).length() == 16, "player names are cut to 16")


static func _score_checks(check: Callable) -> void:
	var good := {"name": "Ari", "colony": "Margin", "planet": "brume", "ending": "silent", "turn": 50, "debt_paid": 900.0, "debt_total": 6000, "population": 0, "version": "00.01.04"}
	check.call(ScoreEntry.problem(good) == "", "a valid score passes (whole floats from JSON count)")
	var bad := [
		[{"name": ""}, "invalid name"],
		[{"name": "<b>"}, "invalid name"],
		[{"colony": "x;y"}, "invalid colony"],
		[{"planet": "Brume"}, "invalid planet"],
		[{"ending": "won"}, "invalid ending"],
		[{"turn": 0}, "invalid turn"],
		[{"turn": 5001}, "invalid turn"],
		[{"turn": 12.5}, "invalid turn"],
		[{"debt_paid": 6001}, "invalid debt"],
		[{"debt_paid": -1}, "invalid debt"],
		[{"debt_total": 1000001}, "invalid debt"],
		[{"ending": "free"}, "invalid debt"],
		[{"population": 100001}, "invalid population"],
		[{"population": "12"}, "invalid population"],
		[{"version": "1.2.3"}, "invalid version"],
	]
	for case in bad:
		var entry: Dictionary = good.duplicate()
		entry.merge(case[0], true)
		check.call(ScoreEntry.problem(entry) == case[1], "score check refuses %s (%s)" % [JSON.stringify(case[0]), case[1]])


static func _replies(check: Callable) -> void:
	var board := Online.board_reply(OK_RESULT, 200, '{"planet":"brume","entries":[{"name":"A"},7,{"name":"B"}]}')
	check.call(board["error"] == "" and (board["entries"] as Array).size() == 2, "board reply keeps the rows")
	board = Online.board_reply(NO_CONNECTION, 0, "")
	check.call(board["error"] == OnlineConfig.text("no_connection") and (board["entries"] as Array).is_empty(), "offline board gives a short message")
	check.call(Online.board_reply(OK_RESULT, 404, "")["error"] == OnlineConfig.text("not_set_up"), "a missing Worker says it isn't set up")
	check.call(Online.board_reply(OK_RESULT, 200, "<html>")["error"] == OnlineConfig.text("board_unreadable"), "a garbled board is reported, not crashed on")
	var sent := Online.score_reply(OK_RESULT, 200, '{"accepted":true,"rank":3}')
	check.call(sent["ok"] and sent["message"] == OnlineConfig.text("score_accepted") % 3, "accepted score reports its rank")
	check.call(Online.score_reply(OK_RESULT, 200, '{"accepted":false}')["message"] == OnlineConfig.text("score_not_top"), "a score off the board says so")
	check.call(not Online.score_reply(OK_RESULT, 429, "{}")["ok"], "rate limited score is not ok")
	check.call(Online.score_reply(OK_RESULT, 400, '{"error":"invalid turn"}')["message"] == OnlineConfig.text("score_refused") % "invalid turn", "refused score says why")
	check.call(Online.cloud_save_reply(OK_RESULT, 200, "{}")["ok"], "cloud save ok")
	check.call(Online.cloud_save_reply(OK_RESULT, 429, "{}")["message"] == OnlineConfig.text("cloud_too_soon"), "cloud save too soon")
	check.call(Online.cloud_save_reply(NO_CONNECTION, 0, "")["message"] == OnlineConfig.text("no_connection"), "cloud save offline")
	var save_text := '{"version":1,"structures":{"2":{},"10":{}},"debt":5123.456789012345}'
	var loaded := Online.cloud_load_reply(OK_RESULT, 200, JSON.stringify({"save": save_text, "updated": 5}))
	check.call(loaded["error"] == "" and loaded["text"] == save_text, "cloud load returns the exact save text")
	check.call(Online.cloud_load_reply(OK_RESULT, 200, '{"save":null,"updated":0}')["error"] == OnlineConfig.text("cloud_empty"), "no cloud save yet is reported")
	check.call(Online.cloud_load_reply(OK_RESULT, 401, "{}")["error"] == OnlineConfig.text("cloud_bad_account"), "a bad account code is reported")
	check.call(Online.parse_json("") == null and Online.parse_json("{") == null, "broken JSON parses to null quietly")


static func _account_file(check: Callable) -> void:
	var path := "user://test_account.json"
	Online.write_account(path, {"code": "ABCDEFGHJK23", "email": "a@b.c"})
	var back := Online.read_account(path)
	check.call(back.get("code") == "ABCDEFGHJK23" and back.get("email") == "a@b.c", "account file round-trips")
	DirAccess.remove_absolute(path)
	check.call(Online.read_account(path).is_empty(), "no account file means signed out")


static func _config(check: Callable) -> void:
	check.call(OnlineConfig.API_BASE_URL == "https://lastborn-colony.thebotcoder.workers.dev", "Worker address is Lastborn's")
	var saved := OnlineConfig.base_override
	OnlineConfig.base_override = "http://127.0.0.1:8787/"
	check.call(OnlineConfig.leaderboard_url("brume") == "http://127.0.0.1:8787/leaderboard?planet=brume", "leaderboard URL with planet")
	check.call(OnlineConfig.auth_url("poll") == "http://127.0.0.1:8787/auth/poll", "auth URL")
	check.call(OnlineConfig.cloud_url() == "http://127.0.0.1:8787/cloud/save", "cloud URL")
	OnlineConfig.base_override = "off"
	check.call(not OnlineConfig.enabled() and OnlineConfig.cloud_url() == "", "online features can be turned off")
	OnlineConfig.base_override = saved
	for key in ["offline", "no_connection", "not_set_up", "score_accepted", "sign_in_done", "cloud_saved", "cloud_empty"]:
		check.call(OnlineConfig.text(key) != key, "data/online.json has text for %s" % key)


static func _suggestions(check: Callable) -> void:
	check.call(Online.suggestion_categories() == ["Gameplay", "Balance", "Interface", "Bug", "Online", "Other"], "suggestion categories match the Worker's list")
	var cats := Online.suggestion_categories()
	cats.append("Admin")
	check.call(Online.suggestion_categories().size() == 6, "the category list can't be changed by a caller")
	var hidden := "A" + char(0) + "b" + char(0x07) + "c" + char(0x202E) + "d" + char(0x2066) + "e" + char(0x200B) + "f" + char(0xFEFF) + "g" + char(0xAD) + "h" + char(0xE0041) + "i" + char(0x7F) + "j"
	check.call(Online.clean_suggestion_text(hidden, true) == "Abcdefghij", "control, bidi, zero-width and tag characters are removed")
	check.call(Online.clean_suggestion_text("  Two\nline\r\n\ttitle  ", true) == "Two line title", "a title becomes one trimmed line")
	check.call(Online.clean_suggestion_text("One\r\n\r\n\r\n\r\nTwo  \nThree", false) == "One\n\nTwo\nThree", "a description keeps at most one blank line")
	check.call(Online.clean_suggestion_text("Caf\u00e9 \U01F680 '; DROP TABLE scores; --", true) == "Caf\u00e9 \U01F680 '; DROP TABLE scores; --", "ordinary text, accents, emoji and quotes are kept (the server escapes them)")

	var desc := "The Vent Tap heat feels much too strong on Hollow."
	check.call(Online.suggestion_problem("Balance", "Vent Taps", desc) == "", "a normal suggestion passes")
	check.call(Online.suggestion_problem("balance", "Vent Taps", desc) == OnlineConfig.text("suggest_bad_category"), "category must match exactly")
	check.call(Online.suggestion_problem("<script>", "Vent Taps", desc) == OnlineConfig.text("suggest_bad_category"), "an unknown category is refused")
	var title_msg := OnlineConfig.text("suggest_title_length") % [Online.SUGGESTION_MIN_TITLE, Online.SUGGESTION_MAX_TITLE]
	check.call(Online.suggestion_problem("Bug", "Hi", desc) == title_msg, "a title under 5 characters is refused")
	check.call(Online.suggestion_problem("Bug", char(0x200B).repeat(10) + "Hi", desc) == title_msg, "invisible characters don't count toward the title")
	check.call(Online.suggestion_problem("Bug", "x".repeat(101), desc) == title_msg, "a title over 100 characters is refused")
	check.call(Online.suggestion_problem("Bug", "x".repeat(100), desc) == "", "a 100-character title is fine")
	var desc_msg := OnlineConfig.text("suggest_description_length") % [Online.SUGGESTION_MIN_DESCRIPTION, Online.SUGGESTION_MAX_DESCRIPTION]
	check.call(Online.suggestion_problem("Bug", "Vent Taps", "too short") == desc_msg, "a description under 20 characters is refused")
	check.call(Online.suggestion_problem("Bug", "Vent Taps", "y".repeat(2001)) == desc_msg, "a description over 2000 characters is refused")
	check.call(Online.suggestion_problem("Bug", "Vent Taps", "y".repeat(2000)) == "", "a 2000-character description is fine")
	check.call(Online.suggestion_problem("Bug", "Vent Taps", desc + " http://a https://b www.c") == OnlineConfig.text("suggest_too_many_links") % 2, "more than 2 links are refused")

	var client := Online.client_details()
	check.call(client.keys() == ["game_version", "runtime", "device_type", "platform", "browser"], "client details are the five coarse fields only")
	check.call(client["game_version"] == str(ProjectSettings.get_setting("application/config/version")), "client details carry the game version")
	check.call(client["runtime"] in ["Web", "Native"] and client["device_type"] in ["Desktop", "Phone", "Tablet", "Unknown"], "runtime and device come from fixed lists")
	var body := Online.suggestion_payload("Bug", " Map\nflicker" + char(0x202E) + " ", "  " + desc + char(0x200B) + "  ", client)
	check.call(body["title"] == "Map flicker" and body["description"] == desc, "the payload carries tidied text")
	check.call(body["website"] == "", "the payload carries an empty honeypot")
	check.call(body.keys() == ["category", "title", "description", "website", "client"], "the payload has only the expected fields")

	var r := Online.suggestion_reply(OK_RESULT, 201, '{"accepted":true,"issue_number":42}')
	check.call(r["ok"] and r["message"] == OnlineConfig.text("suggest_sent"), "a delivered suggestion is reported")
	check.call(not Online.suggestion_reply(OK_RESULT, 201, "{}")["ok"], "201 without accepted is not success")
	var other := Online.suggestion_reply(OK_RESULT, 200, '{"accepted":true}')
	check.call(not other["ok"] and other["message"] == OnlineConfig.text("server_error") % 200, "only 201 means delivered")
	check.call(Online.suggestion_reply(OK_RESULT, 429, "{}")["message"] == OnlineConfig.text("suggest_rate_limited"), "the daily limit is reported")
	check.call(Online.suggestion_reply(OK_RESULT, 503, '{"error":"x"}')["message"] == OnlineConfig.text("suggest_not_set_up"), "a Worker without a token says suggestions aren't set up")
	check.call(Online.suggestion_reply(OK_RESULT, 404, "")["message"] == OnlineConfig.text("suggest_not_set_up"), "an older Worker without suggestions says so")
	check.call(Online.suggestion_reply(OK_RESULT, 413, "")["message"] == OnlineConfig.text("suggest_too_large"), "a too-large suggestion is reported")
	check.call(Online.suggestion_reply(OK_RESULT, 400, '{"error":"invalid category"}')["message"] == OnlineConfig.text("suggest_refused") % "invalid category", "a refused suggestion says why")
	var odd := Online.suggestion_reply(OK_RESULT, 502, JSON.stringify({"error": "bad" + char(0x202E) + "\n" + "z".repeat(500)}))
	check.call(not odd["ok"] and not ("\n" in odd["message"]) and not (char(0x202E) in odd["message"]) and odd["message"].length() < 400, "a server reason is tidied and cut short before it is shown")
	check.call(Online.suggestion_reply(NO_CONNECTION, 0, "")["message"] == OnlineConfig.text("no_connection"), "offline suggestion gives a short message")
	check.call(Online.suggestion_reply(OK_RESULT, 201, "<html>")["ok"] == false, "a garbled reply is not success")

	check.call(Online.suggestions_status_reply(OK_RESULT, 200, '{"accepting":true}'), "status: accepting")
	check.call(not Online.suggestions_status_reply(OK_RESULT, 200, '{"accepting":false}'), "status: not accepting")
	check.call(not Online.suggestions_status_reply(OK_RESULT, 200, '{"accepting":"true"}'), "status: only a real true counts")
	check.call(not Online.suggestions_status_reply(NO_CONNECTION, 0, ""), "status: offline means not accepting")
	var saved := OnlineConfig.base_override
	OnlineConfig.base_override = "http://127.0.0.1:8787"
	check.call(OnlineConfig.suggestions_url() == "http://127.0.0.1:8787/suggestions", "suggestions URL")
	OnlineConfig.base_override = saved
	for key in ["suggest_sent", "suggest_not_set_up", "suggest_rate_limited", "suggest_refused", "suggest_github_failed", "suggest_title_length", "suggest_description_length", "suggest_bad_category", "suggest_too_many_links", "suggest_too_large", "suggest_busy"]:
		check.call(OnlineConfig.text(key) != key, "data/online.json has text for %s" % key)
