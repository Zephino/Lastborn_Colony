## Where Lastborn Colony's online services live: the owner's Cloudflare Worker
## (see leaderboard-api/README.md). These are public addresses, not settings
## to tune, so they live here rather than in data/*.json. No secrets here:
## the Worker's keys stay in Cloudflare.
##
## Use with: const OnlineConfig = preload("res://scripts/net/online_config.gd")
extends RefCounted

## The Worker's address only (no path, no trailing slash).
const API_BASE_URL := "https://lastborn-colony.thebotcoder.workers.dev"

## For testing against a Worker running on this computer (`npx wrangler dev`):
## start the game with `-- --api=http://127.0.0.1:8787`. `--api=` with nothing
## after it turns the online features off (to test the offline messages).
static var base_override: String = ""
static var _read_args := false


static func api_base() -> String:
	if not _read_args:
		_read_args = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--api="):
				base_override = arg.trim_prefix("--api=")
				if base_override == "":
					base_override = "off"
	var base := base_override if base_override != "" else API_BASE_URL
	if base == "off":
		return ""
	return base.strip_edges().trim_suffix("/")


## True when a Worker address is set (it may still be offline or not set up).
static func enabled() -> bool:
	return api_base() != ""


## GET (with ?planet=) and POST scores (leaderboard-api/src/board.js); "" when off.
static func leaderboard_url(planet: String = "") -> String:
	var base := api_base()
	if base == "":
		return ""
	if planet == "":
		return base + "/leaderboard"
	return base + "/leaderboard?planet=" + planet.uri_encode()


## Cloud saves (leaderboard-api/src/cloud.js); "" when off.
static func cloud_url() -> String:
	var base := api_base()
	return "" if base == "" else base + "/cloud/save"


## Sign in with Google (leaderboard-api/src/accounts.js), e.g. auth_url("start"); "" when off.
static func auth_url(path: String) -> String:
	var base := api_base()
	return "" if base == "" else base + "/auth/" + path


## Anonymous suggestions (leaderboard-api/src/suggestions.js); "" when off.
static func suggestions_url() -> String:
	var base := api_base()
	return "" if base == "" else base + "/suggestions"


## The privacy policy page (shown by the Worker).
static func privacy_url() -> String:
	var base := api_base()
	return "" if base == "" else base + "/privacy"


static var _text: Dictionary = {}


## A player-facing message from res://data/online.json (the key itself if it's missing).
static func text(key: String) -> String:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/online.json"))
		_text = parsed if parsed is Dictionary else {"_loaded": true}
	return str(_text.get(key, key))
