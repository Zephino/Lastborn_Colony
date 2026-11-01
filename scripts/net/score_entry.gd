## Builds and checks one leaderboard score ("how far you got, on which planet")
## from a Lastborn Colony game state. Pure functions with no nodes, so they run
## headless (tests/test_online.gd). The rules here mirror the Worker's
## (leaderboard-api/src/board.js), which checks everything again; if one side
## changes, change the other.
##
## An entry: {name, colony, planet, ending, turn, debt_paid, debt_total,
## population, version}. The Worker adds the date.
##
## Use with: const ScoreEntry = preload("res://scripts/net/score_entry.gd")
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const OnlineConfig = preload("res://scripts/net/online_config.gd")

const MAX_NAME_LENGTH := 16
const MAX_COLONY_LENGTH := 24
const MAX_TURN := 5000
const MAX_DEBT_TOTAL := 1000000
const MAX_POPULATION := 100000
const ENDINGS := ["free", "receivership", "silent", "retired"]
const DEFAULT_PLANET := "brume"


## The entry for this game. `ending_override` is used when not "" (for
## example "retired" when the player sends a game they are leaving);
## otherwise the state's own ending, or "retired" if the game hasn't ended.
static func from_state(state: Dictionary, player_name: String, ending_override: String) -> Dictionary:
	var ending := ending_override if ending_override != "" else str(state.get("ending", ""))
	if ending == "":
		ending = "retired"
	const Manifest = preload("res://scripts/sim/manifest.gd")
	var debt_total := int(round(float(state.get("debt_total", Manifest.debt_of(Manifest.recommended())))))
	var debt_left := maxf(float(state.get("debt", debt_total)), 0.0)
	var debt_paid := clampi(int(round(float(debt_total) - debt_left)), 0, maxi(debt_total, 0))
	if ending == "free":
		debt_paid = debt_total
	var people := float(state.get("adults", 0.0)) + float(state.get("children", 0.0)) + float(state.get("elders", 0.0))
	var colony := clean_name(str(state.get("colony_name", "")), MAX_COLONY_LENGTH)
	if colony == "":
		colony = OnlineConfig.text("default_colony")
	return {
		"name": clean_name(player_name, MAX_NAME_LENGTH),
		"colony": colony,
		"planet": str(state.get("planet", DEFAULT_PLANET)),
		"difficulty": str(state.get("difficulty", "normal")),
		"ending": ending,
		"turn": clampi(int(state.get("turn", 1)), 1, MAX_TURN),
		"debt_paid": debt_paid,
		"debt_total": debt_total,
		"population": clampi(int(round(people)), 0, MAX_POPULATION),
		"version": str(ProjectSettings.get_setting("application/config/version", "00.00.00")),
	}


## Keeps A-Z, a-z, 0-9, space, _ and -; squeezes spaces; trims; cuts to `max_length`.
static func clean_name(raw: String, max_length: int) -> String:
	var out := ""
	for ch in raw:
		var c := ch.unicode_at(0)
		var ok := (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == " " or ch == "_" or ch == "-"
		if ok and not (ch == " " and out.ends_with(" ")):
			out += ch
	return out.strip_edges().left(max_length).strip_edges()


## "" when the Worker would accept `entry`; otherwise a short reason
## (the same words the Worker uses, e.g. "invalid turn").
static func problem(entry: Dictionary) -> String:
	var player := str(entry.get("name", ""))
	if player == "" or clean_name(player, MAX_NAME_LENGTH) != player:
		return "invalid name"
	var colony := str(entry.get("colony", ""))
	if colony == "" or clean_name(colony, MAX_COLONY_LENGTH) != colony:
		return "invalid colony"
	if not _is_id(str(entry.get("planet", ""))):
		return "invalid planet"
	if not (str(entry.get("difficulty", "normal")) in ["easy", "normal", "hard"]):
		return "invalid difficulty"
	var ending := str(entry.get("ending", ""))
	if not (ending in ENDINGS):
		return "invalid ending"
	if not _whole(entry.get("turn"), 1, MAX_TURN):
		return "invalid turn"
	if not _whole(entry.get("debt_total"), 1, MAX_DEBT_TOTAL):
		return "invalid debt"
	var total := int(entry["debt_total"])
	if not _whole(entry.get("debt_paid"), 0, total):
		return "invalid debt"
	if ending == "free" and int(entry["debt_paid"]) != total:
		return "invalid debt"
	if not _whole(entry.get("population"), 0, MAX_POPULATION):
		return "invalid population"
	var version := str(entry.get("version", ""))
	var parts := version.split(".")
	if parts.size() != 3 or version.length() != 8:
		return "invalid version"
	for p in parts:
		if p.length() != 2 or not p.is_valid_int():
			return "invalid version"
	return ""


## Lower-case letters and digits, 1 to 24 long (planet ids; "_" marks a difficulty on the server).
static func _is_id(text: String) -> bool:
	if text.length() < 1 or text.length() > 24:
		return false
	for ch in text:
		var c := ch.unicode_at(0)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57)):
			return false
	return true


## A whole number (int, or a float with no fraction, as JSON gives) in min..max.
static func _whole(value: Variant, lo: int, hi: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= lo and int(value) <= hi
	if typeof(value) == TYPE_FLOAT:
		var f := float(value)
		return is_finite(f) and f == floorf(f) and f >= lo and f <= hi
	return false
