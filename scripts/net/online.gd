## Lastborn Colony's online features, through the owner's Cloudflare Worker
## (leaderboard-api/): the shared leaderboard, Sign in with Google, and one
## cloud save per Google account. Add one of these as a child of the main UI:
##
##   const Online = preload("res://scripts/net/online.gd")
##   var online: Node = Online.new()
##   add_child(online)
##
## Everything fails quietly: when the player is offline or the Worker isn't set
## up, the signals still fire with a short message (text in data/online.json)
## and the game plays on. Nothing here is needed to play.
##
## Sign-in works like Mythriven's: the game asks the Worker for a sign-in page
## (POST /auth/start), opens it in the browser (a new tab on the web), and asks
## the Worker every few seconds (GET /auth/poll) until the player has signed in
## with Google there. The Worker then hands over the account's private cloud
## save code, kept in user://account.json on this device only.
##
## Suggestions (like Mythriven's): submit_suggestion() sends a category, title
## and description to POST /suggestions, and the Worker turns it into a GitHub
## issue. The text is tidied here first (clean_suggestion_text), but the Worker
## checks and escapes everything again.
extends Node

const OnlineConfig = preload("res://scripts/net/online_config.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")

## The board for one planet arrived (rows best first), or `error` says why not.
signal board_loaded(entries: Array, error: String)
## A score was sent (or not); `message` is a short sentence for the player.
signal score_submitted(ok: bool, message: String)
## Signed in or out (check is_signed_in() and account_name()).
signal account_changed()
## Progress or problems while signing in, as a sentence for the player.
signal sign_in_message(message: String)
signal cloud_saved(ok: bool, message: String)
## The cloud save's text (a save file for SaveGame.from_text), or "" and why.
signal cloud_loaded(text: String, error: String)
## A suggestion was sent (or not); `message` is a short sentence for the player.
signal suggestion_sent(ok: bool, message: String)
## Whether the Worker takes suggestions right now (answer to check_suggestions).
signal suggestions_status(accepting: bool)

## Seconds between asking the Worker whether the player has signed in.
const POLL_S := 2.0
## How long a sign-in may take (the Worker forgets it after 10 minutes too).
const SIGN_IN_TIMEOUT_S := 600.0
const REQUEST_TIMEOUT_S := 15.0

## Suggestion rules; the same as leaderboard-api/src/suggestions.js (change both together).
const SUGGESTION_CATEGORIES := ["Gameplay", "Balance", "Interface", "Bug", "Online", "Other"]
const SUGGESTION_MIN_TITLE := 5
const SUGGESTION_MAX_TITLE := 100
const SUGGESTION_MIN_DESCRIPTION := 20
const SUGGESTION_MAX_DESCRIPTION := 2000
const SUGGESTION_MAX_LINKS := 2

## Where this device keeps its account (the tests use their own file).
var account_path := "user://account.json"

var _board_http: HTTPRequest
var _score_http: HTTPRequest
var _auth_http: HTTPRequest
var _cloud_http: HTTPRequest
var _suggest_http: HTTPRequest
var _suggest_status_http: HTTPRequest
var _suggest_sending := false
var _cloud_phase := ""
var _account: Dictionary = {}
## "" (not signing in), "starting" or "waiting" (the browser page is open).
var _sign_in_state := ""
var _login := ""
var _poll_in := -1.0
var _sign_in_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_board_http = _make_request(_on_board_reply)
	_score_http = _make_request(_on_score_reply)
	_auth_http = _make_request(_on_auth_reply)
	_cloud_http = _make_request(_on_cloud_reply)
	_suggest_http = _make_request(_on_suggest_reply)
	_suggest_status_http = _make_request(_on_suggest_status_reply)
	_account = read_account(account_path)


func _make_request(on_done: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_S
	request.request_completed.connect(on_done)
	add_child(request)
	return request


# --- Leaderboard ----------------------------------------------------------------

## Asks for one planet's board (e.g. "brume"); answers with board_loaded.
func fetch_board(planet: String) -> void:
	if not OnlineConfig.enabled():
		board_loaded.emit.call_deferred([], OnlineConfig.text("offline"))
		return
	_board_http.cancel_request()
	var err := _board_http.request(OnlineConfig.leaderboard_url(planet), PackedStringArray(["Accept: application/json"]))
	if err != OK:
		board_loaded.emit.call_deferred([], OnlineConfig.text("no_connection"))


## Sends one score (build it with ScoreEntry.from_state); answers with score_submitted.
func submit_score(entry: Dictionary) -> void:
	if not OnlineConfig.enabled():
		score_submitted.emit.call_deferred(false, OnlineConfig.text("offline"))
		return
	var why := ScoreEntry.problem(entry)
	if why != "":
		var msg := OnlineConfig.text("score_need_name") if why == "invalid name" else OnlineConfig.text("score_invalid") % why
		score_submitted.emit.call_deferred(false, msg)
		return
	_score_http.cancel_request()
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var err := _score_http.request(OnlineConfig.leaderboard_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(entry))
	if err != OK:
		score_submitted.emit.call_deferred(false, OnlineConfig.text("no_connection"))


func _on_board_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply := board_reply(result, code, body.get_string_from_utf8())
	board_loaded.emit(reply["entries"], reply["error"])


func _on_score_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply := score_reply(result, code, body.get_string_from_utf8())
	score_submitted.emit(reply["ok"], reply["message"])


## {entries, error} from the Worker's answer to GET /leaderboard?planet=…
static func board_reply(result: int, code: int, text: String) -> Dictionary:
	var problem := http_problem(result, code)
	if code == 400:
		problem = OnlineConfig.text("board_bad_planet")
	if problem != "":
		return {"entries": [], "error": problem}
	var parsed: Variant = parse_json(text)
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("entries") is Array):
		return {"entries": [], "error": OnlineConfig.text("board_unreadable")}
	var rows: Array = []
	for row in parsed["entries"]:
		if row is Dictionary:
			rows.append(row)
	return {"entries": rows, "error": ""}


## {ok, message} from the Worker's answer to POST /leaderboard.
static func score_reply(result: int, code: int, text: String) -> Dictionary:
	var parsed: Variant = parse_json(text)
	var reply: Dictionary = parsed if parsed is Dictionary else {}
	if result == HTTPRequest.RESULT_SUCCESS and code == 429:
		return {"ok": false, "message": OnlineConfig.text("score_rate_limited")}
	if result == HTTPRequest.RESULT_SUCCESS and code == 400:
		return {"ok": false, "message": OnlineConfig.text("score_refused") % str(reply.get("error", "?"))}
	var problem := http_problem(result, code)
	if problem != "":
		return {"ok": false, "message": problem}
	if bool(reply.get("accepted", false)):
		return {"ok": true, "message": OnlineConfig.text("score_accepted") % int(reply.get("rank", 0))}
	return {"ok": true, "message": OnlineConfig.text("score_not_top")}


# --- Sign in with Google ------------------------------------------------------------

func is_signed_in() -> bool:
	return str(_account.get("code", "")) != ""


## The signed-in Google account's email ("" when signed out).
func account_name() -> String:
	if not is_signed_in():
		return ""
	var email := str(_account.get("email", ""))
	return email if email != "" else OnlineConfig.text("google_account")


## True while the sign-in page is open in the browser.
func is_signing_in() -> bool:
	return _sign_in_state != ""


## Opens Google's sign-in in the browser and waits for it (sign_in_message, then account_changed).
func start_sign_in() -> void:
	if not OnlineConfig.enabled():
		sign_in_message.emit.call_deferred(OnlineConfig.text("offline"))
		return
	if _sign_in_state != "":
		sign_in_message.emit.call_deferred(OnlineConfig.text("sign_in_busy"))
		return
	# On the web, open the tab now, while the button press still counts as the
	# player's own action; otherwise the browser may block it as a pop-up.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__lastbornSignIn = window.open('', '_blank');", true)
	_sign_in_state = "starting"
	_auth_http.cancel_request()
	var body := JSON.stringify({"code": ""})
	var err := _auth_http.request(OnlineConfig.auth_url("start"), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	if err != OK:
		_stop_sign_in(OnlineConfig.text("no_connection"))


## Stops waiting for a sign-in the player abandoned.
func cancel_sign_in() -> void:
	if _sign_in_state != "":
		_stop_sign_in(OnlineConfig.text("sign_in_cancelled"))


## Forgets the account on this device (the cloud save stays on the server).
func sign_out() -> void:
	if _sign_in_state != "":
		_stop_sign_in("")
	_cloud_http.cancel_request()
	_cloud_phase = ""
	_account = {}
	if FileAccess.file_exists(account_path):
		DirAccess.remove_absolute(account_path)
	sign_in_message.emit(OnlineConfig.text("signed_out"))
	account_changed.emit()


func _process(delta: float) -> void:
	if _sign_in_state != "waiting":
		return
	_sign_in_left -= delta
	if _sign_in_left <= 0.0:
		_stop_sign_in(OnlineConfig.text("sign_in_expired"))
		return
	if _poll_in < 0.0:
		return
	_poll_in -= delta
	if _poll_in <= 0.0:
		_poll_in = -1.0
		if _auth_http.request(OnlineConfig.auth_url("poll") + "?login=" + _login) != OK:
			_poll_in = POLL_S


func _on_auth_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = parse_json(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
	var reply: Dictionary = parsed if parsed is Dictionary else {}
	if _sign_in_state == "starting":
		if result == HTTPRequest.RESULT_SUCCESS and (code == 503 or code == 404):
			_stop_sign_in(OnlineConfig.text("sign_in_not_set_up"))
		elif code != 200 or str(reply.get("login", "")) == "":
			_stop_sign_in(OnlineConfig.text("no_connection"))
		else:
			_login = str(reply["login"])
			_sign_in_state = "waiting"
			_sign_in_left = SIGN_IN_TIMEOUT_S
			_poll_in = POLL_S
			_open_page(str(reply.get("url", "")))
		return
	if _sign_in_state != "waiting":
		return
	# Still waiting, or a dropped reply: ask again shortly.
	_poll_in = POLL_S
	if code != 200:
		return
	match str(reply.get("state", "")):
		"done":
			var sync_code := str(reply.get("code", ""))
			if sync_code == "":
				_stop_sign_in(OnlineConfig.text("no_connection"))
				return
			_account = {"code": sync_code, "email": str(reply.get("email", "")).left(120)}
			write_account(account_path, _account)
			_stop_sign_in(OnlineConfig.text("sign_in_done") % account_name())
			account_changed.emit()
		"cancelled":
			_stop_sign_in(OnlineConfig.text("sign_in_cancelled"))
		"expired":
			_stop_sign_in(OnlineConfig.text("sign_in_expired"))


func _stop_sign_in(message: String) -> void:
	if _sign_in_state == "starting" and OS.has_feature("web"):
		# The tab opened early never got its page: close it.
		JavaScriptBridge.eval("if (window.__lastbornSignIn) { window.__lastbornSignIn.close(); window.__lastbornSignIn = null; }", true)
	_auth_http.cancel_request()
	_sign_in_state = ""
	_login = ""
	_poll_in = -1.0
	if message != "":
		sign_in_message.emit(message)


## Opens the sign-in page in the browser (the tab opened early, on the web).
func _open_page(url: String) -> void:
	if url == "":
		return
	if OS.has_feature("web"):
		var js := "(function(u){var w=window.__lastbornSignIn;window.__lastbornSignIn=null;if(w&&!w.closed){w.location.href=u;return true;}return !!window.open(u,'_blank');})(%s)" % JSON.stringify(url)
		if not bool(JavaScriptBridge.eval(js, true)):
			_stop_sign_in(OnlineConfig.text("sign_in_popup_blocked"))
			return
	else:
		OS.shell_open(url)
	sign_in_message.emit(OnlineConfig.text("sign_in_opened"))


## The saved account ({code, email}), or {} if there's none or it can't be read.
static func read_account(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = parse_json(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and str((parsed as Dictionary).get("code", "")) != "":
		return {"code": str(parsed["code"]), "email": str(parsed.get("email", ""))}
	return {}


static func write_account(path: String, account: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"code": str(account.get("code", "")), "email": str(account.get("email", ""))}))
	f.close()


# --- Cloud save -----------------------------------------------------------------

## Stores a save file's text (SaveGame.to_text) as this account's cloud save; answers with cloud_saved.
func upload_save(text: String) -> void:
	if not _cloud_ready():
		cloud_saved.emit.call_deferred(false, _cloud_unavailable())
		return
	_cloud_http.cancel_request()
	_cloud_phase = "put"
	var err := _cloud_http.request(OnlineConfig.cloud_url(), _cloud_headers(), HTTPClient.METHOD_PUT, text)
	if err != OK:
		_cloud_phase = ""
		cloud_saved.emit.call_deferred(false, OnlineConfig.text("no_connection"))


## Fetches this account's cloud save; answers with cloud_loaded.
func download_save() -> void:
	if not _cloud_ready():
		cloud_loaded.emit.call_deferred("", _cloud_unavailable())
		return
	_cloud_http.cancel_request()
	_cloud_phase = "get"
	var err := _cloud_http.request(OnlineConfig.cloud_url(), _cloud_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_cloud_phase = ""
		cloud_loaded.emit.call_deferred("", OnlineConfig.text("no_connection"))


func _cloud_ready() -> bool:
	return OnlineConfig.enabled() and is_signed_in()


func _cloud_unavailable() -> String:
	return OnlineConfig.text("offline") if not OnlineConfig.enabled() else OnlineConfig.text("cloud_need_sign_in")


func _cloud_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + str(_account.get("code", "")), "Content-Type: application/json", "Accept: application/json"])


func _on_cloud_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var phase := _cloud_phase
	_cloud_phase = ""
	var text := body.get_string_from_utf8()
	if phase == "put":
		var saved := cloud_save_reply(result, code, text)
		cloud_saved.emit(saved["ok"], saved["message"])
	elif phase == "get":
		var loaded := cloud_load_reply(result, code, text)
		cloud_loaded.emit(loaded["text"], loaded["error"])


## {ok, message} from the Worker's answer to PUT /cloud/save.
static func cloud_save_reply(result: int, code: int, text: String) -> Dictionary:
	if result == HTTPRequest.RESULT_SUCCESS:
		match code:
			200:
				return {"ok": true, "message": OnlineConfig.text("cloud_saved")}
			429:
				return {"ok": false, "message": OnlineConfig.text("cloud_too_soon")}
			413:
				return {"ok": false, "message": OnlineConfig.text("cloud_too_large")}
			401:
				return {"ok": false, "message": OnlineConfig.text("cloud_bad_account")}
			400:
				var parsed: Variant = parse_json(text)
				var why := str((parsed as Dictionary).get("error", "?")) if parsed is Dictionary else "?"
				return {"ok": false, "message": OnlineConfig.text("cloud_refused") % why}
	return {"ok": false, "message": http_problem(result, code)}


## {text, error} from the Worker's answer to GET /cloud/save: the save file's text, or "" and why.
static func cloud_load_reply(result: int, code: int, text: String) -> Dictionary:
	if result == HTTPRequest.RESULT_SUCCESS and code == 401:
		return {"text": "", "error": OnlineConfig.text("cloud_bad_account")}
	var problem := http_problem(result, code)
	if problem != "":
		return {"text": "", "error": problem}
	var parsed: Variant = parse_json(text)
	if not (parsed is Dictionary):
		return {"text": "", "error": OnlineConfig.text("cloud_unreadable")}
	var save: Variant = (parsed as Dictionary).get("save")
	if save == null:
		return {"text": "", "error": OnlineConfig.text("cloud_empty")}
	if typeof(save) != TYPE_STRING or str(save) == "":
		return {"text": "", "error": OnlineConfig.text("cloud_unreadable")}
	return {"text": str(save), "error": ""}


# --- Suggestions ------------------------------------------------------------------

## The categories a suggestion may have (the Worker accepts exactly these).
static func suggestion_categories() -> Array:
	return SUGGESTION_CATEGORIES.duplicate()


## Asks whether the Worker takes suggestions; answers with suggestions_status.
func check_suggestions() -> void:
	if not OnlineConfig.enabled():
		suggestions_status.emit.call_deferred(false)
		return
	_suggest_status_http.cancel_request()
	if _suggest_status_http.request(OnlineConfig.suggestions_url(), PackedStringArray(["Accept: application/json"])) != OK:
		suggestions_status.emit.call_deferred(false)


## Sends an anonymous suggestion; answers with suggestion_sent.
func submit_suggestion(category: String, title: String, description: String) -> void:
	if not OnlineConfig.enabled():
		suggestion_sent.emit.call_deferred(false, OnlineConfig.text("offline"))
		return
	if _suggest_sending:
		suggestion_sent.emit.call_deferred(false, OnlineConfig.text("suggest_busy"))
		return
	var why := suggestion_problem(category, title, description)
	if why != "":
		suggestion_sent.emit.call_deferred(false, why)
		return
	var body := JSON.stringify(suggestion_payload(category, title, description, client_details()))
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if _suggest_http.request(OnlineConfig.suggestions_url(), headers, HTTPClient.METHOD_POST, body) != OK:
		suggestion_sent.emit.call_deferred(false, OnlineConfig.text("no_connection"))
		return
	_suggest_sending = true


func _on_suggest_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_suggest_sending = false
	var reply := suggestion_reply(result, code, body.get_string_from_utf8())
	suggestion_sent.emit(reply["ok"], reply["message"])


func _on_suggest_status_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	suggestions_status.emit(suggestions_status_reply(result, code, body.get_string_from_utf8()))


## Removes characters that don't print or can hide or reverse text (controls,
## bidirectional marks, zero-width spaces, BOM, tag characters), turns tabs into
## spaces and trims. `one_line` (titles) folds all spacing into single spaces;
## otherwise line ends are kept, with at most one blank line in a row.
static func clean_suggestion_text(text: String, one_line: bool) -> String:
	var out := ""
	for ch in text.replace("\r\n", "\n").replace("\r", "\n"):
		var c := ch.unicode_at(0)
		if c == 0x09:
			out += " "
		elif c == 0x0A or c == 0x85 or c == 0x2028 or c == 0x2029:
			out += "\n"
		elif not _invisible(c):
			out += ch
	if one_line:
		var words := out.replace("\n", " ").split(" ", false)
		return " ".join(words).strip_edges()
	var lines := out.split("\n")
	var kept := PackedStringArray()
	var blank := 0
	for line in lines:
		var tidy := line.strip_edges(false, true)
		blank = blank + 1 if tidy == "" else 0
		if blank < 2:
			kept.append(tidy)
	return "\n".join(kept).strip_edges()


static func _invisible(c: int) -> bool:
	return c < 0x20 or (c >= 0x7F and c <= 0x9F) or c == 0xAD or c == 0x34F or c == 0x61C \
		or c == 0x115F or c == 0x1160 or c == 0x180E or (c >= 0x200B and c <= 0x200F) \
		or (c >= 0x202A and c <= 0x202E) or (c >= 0x2060 and c <= 0x2064) or (c >= 0x2066 and c <= 0x206F) \
		or c == 0x3164 or c == 0xFEFF or c == 0xFFA0 or (c >= 0xFFF9 and c <= 0xFFFB) \
		or (c >= 0xD800 and c <= 0xDFFF) or (c >= 0xE0000 and c <= 0xE007F)


## "" when the suggestion meets the Worker's rules; otherwise a sentence for the player.
static func suggestion_problem(category: String, title: String, description: String) -> String:
	if not (category in SUGGESTION_CATEGORIES):
		return OnlineConfig.text("suggest_bad_category")
	var t := clean_suggestion_text(title, true).length()
	if t < SUGGESTION_MIN_TITLE or t > SUGGESTION_MAX_TITLE:
		return OnlineConfig.text("suggest_title_length") % [SUGGESTION_MIN_TITLE, SUGGESTION_MAX_TITLE]
	var text := clean_suggestion_text(description, false)
	if text.length() < SUGGESTION_MIN_DESCRIPTION or text.length() > SUGGESTION_MAX_DESCRIPTION:
		return OnlineConfig.text("suggest_description_length") % [SUGGESTION_MIN_DESCRIPTION, SUGGESTION_MAX_DESCRIPTION]
	var lower := text.to_lower()
	if lower.count("http://") + lower.count("https://") + lower.count("www.") > SUGGESTION_MAX_LINKS:
		return OnlineConfig.text("suggest_too_many_links") % SUGGESTION_MAX_LINKS
	return ""


## What POST /suggestions receives. "website" is the hidden spam trap: always "".
static func suggestion_payload(category: String, title: String, description: String, client: Dictionary) -> Dictionary:
	return {
		"category": category,
		"title": clean_suggestion_text(title, true),
		"description": clean_suggestion_text(description, false),
		"website": "",
		"client": client,
	}


## Coarse details only: game version, web or app, desktop/phone/tablet, OS
## family, browser family. The browser's user agent is read here, on the
## player's device, and never sent.
static func client_details() -> Dictionary:
	var os_name := OS.get_name()
	var details := {
		"game_version": str(ProjectSettings.get_setting("application/config/version", "Unknown")),
		"runtime": "Native",
		"device_type": "Phone" if os_name == "Android" or os_name == "iOS" else "Desktop",
		"platform": os_name if os_name in ["Windows", "macOS", "Linux", "Android", "iOS", "FreeBSD"] else "Unknown",
		"browser": "N/A",
	}
	if not OS.has_feature("web"):
		return details
	details["runtime"] = "Web"
	var js := "(function(){var u=navigator.userAgent||'';var ipad=/iPad/i.test(u)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);" \
		+ "var o='Unknown';if(ipad||/iPhone|iPod/i.test(u))o='iOS';else if(/Android/i.test(u))o='Android';else if(/Windows/i.test(u))o='Windows';" \
		+ "else if(/CrOS/i.test(u))o='ChromeOS';else if(/Mac OS X|Macintosh/i.test(u))o='macOS';else if(/Linux/i.test(u))o='Linux';" \
		+ "var d='Desktop';if(ipad||/Tablet/i.test(u)||(o==='Android'&&!/Mobile/i.test(u)))d='Tablet';else if(/iPhone|iPod|Android|Mobile/i.test(u))d='Phone';" \
		+ "var b='Other';if(/SamsungBrowser/i.test(u))b='Samsung Internet';else if(/Edg/i.test(u))b='Edge';else if(/OPR|Opera/i.test(u))b='Opera';" \
		+ "else if(/Firefox|FxiOS/i.test(u))b='Firefox';else if(/Chrome|CriOS/i.test(u))b='Chrome';else if(/Safari/i.test(u))b='Safari';" \
		+ "return [d,o,b].join('|');})()"
	var raw: Variant = JavaScriptBridge.eval(js, true)
	var parts := str(raw).split("|") if raw is String else PackedStringArray()
	details["device_type"] = parts[0] if parts.size() == 3 else "Unknown"
	details["platform"] = parts[1] if parts.size() == 3 else "Unknown"
	details["browser"] = parts[2] if parts.size() == 3 else "Other"
	return details


## {ok, message} from the Worker's answer to POST /suggestions.
static func suggestion_reply(result: int, code: int, text: String) -> Dictionary:
	var parsed: Variant = parse_json(text)
	var reply: Dictionary = parsed if parsed is Dictionary else {}
	# The Worker's reason, tidied and cut short before it is shown.
	var why := clean_suggestion_text(str(reply.get("error", "?")), true).left(200)
	if result == HTTPRequest.RESULT_SUCCESS:
		match code:
			201:
				if bool(reply.get("accepted", false)):
					return {"ok": true, "message": OnlineConfig.text("suggest_sent")}
				return {"ok": false, "message": OnlineConfig.text("server_error") % code}
			400:
				return {"ok": false, "message": OnlineConfig.text("suggest_refused") % why}
			413:
				return {"ok": false, "message": OnlineConfig.text("suggest_too_large")}
			429:
				return {"ok": false, "message": OnlineConfig.text("suggest_rate_limited")}
			404, 503:
				return {"ok": false, "message": OnlineConfig.text("suggest_not_set_up")}
			502:
				return {"ok": false, "message": OnlineConfig.text("suggest_github_failed") % why}
	var problem := http_problem(result, code)
	return {"ok": false, "message": problem if problem != "" else OnlineConfig.text("server_error") % code}


## True only when the Worker answered GET /suggestions with {"accepting": true}.
static func suggestions_status_reply(result: int, code: int, text: String) -> bool:
	if http_problem(result, code) != "":
		return false
	var parsed: Variant = parse_json(text)
	if not (parsed is Dictionary):
		return false
	var accepting: Variant = (parsed as Dictionary).get("accepting")
	return typeof(accepting) == TYPE_BOOL and bool(accepting)


# --- Shared -----------------------------------------------------------------------

## "" when the request worked; otherwise a short sentence for the player.
static func http_problem(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS or code == 0:
		return OnlineConfig.text("no_connection")
	if code == 503 or code == 404:
		return OnlineConfig.text("not_set_up")
	if code < 200 or code >= 300:
		return OnlineConfig.text("server_error") % code
	return ""


## Parsed JSON, or null (without printing an error for an empty or broken reply).
static func parse_json(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
