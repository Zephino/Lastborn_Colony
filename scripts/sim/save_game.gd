## Saves are the state Dictionary written as JSON to user://saves/<slot>.json.
## JSON has no integer type, so normalize() restores ints after loading.
extends RefCounted

const NewGame = preload("res://scripts/sim/new_game.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")
const GameData = preload("res://scripts/sim/game_data.gd")

const DIR := "user://saves"
const INT_FIELDS := ["version", "seed", "rng", "turn", "site", "width", "height", "next_id", "payments_made", "missed_in_row", "storm", "surge", "rest"]
const STRUCT_INT_FIELDS := ["x", "y", "progress", "damaged"]


## Keys must stay unsorted (structure order is processing order) and floats
## must keep full precision, or a loaded game would drift from the original.
## The occupancy index is left out; normalize() rebuilds it on load.
static func to_text(state: Dictionary) -> String:
	var copy := state.duplicate()
	copy.erase("occupancy")
	return JSON.stringify(copy, "", false, true)


## Returns the state Dictionary, or an error message String.
static func from_text(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "The save file could not be read."
	var state: Dictionary = parsed
	if int(state.get("version", 0)) != NewGame.SAVE_VERSION or not state.has("tiles") or not state.has("structures") or not state.has("log"):
		return "Not a Lastborn Colony save file."
	normalize(state)
	return state


## Fields added after the first release, with the value an older save means.
const DEFAULTS := {
	"planet": "brume",
	"site": 0,
	"manifest": {},
	"kits": {},
	"elders": 0.0,
	"crime": 0.0,
	"plague": {"active": false, "turns_left": 0, "cure": 0.0, "need": 0.0},
	"research": {"current": "", "progress": 0.0, "done": []},
}


static func normalize(state: Dictionary) -> void:
	for k in DEFAULTS:
		if not state.has(k):
			state[k] = (DEFAULTS[k] as Variant) if typeof(DEFAULTS[k]) != TYPE_DICTIONARY else (DEFAULTS[k] as Dictionary).duplicate(true)
	if not state.has("debt_total"):
		state["debt_total"] = 6000.0
	# A save can come from a file or the cloud: never trust its text or ids.
	state["colony_name"] = TextRules.clean_colony_name(str(state.get("colony_name", "")))
	if not GameData.has_planet(str(state["planet"])):
		state["planet"] = GameData.DEFAULT_PLANET
	for k in INT_FIELDS:
		state[k] = int(state[k])
	var occupancy := {}
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		for k in STRUCT_INT_FIELDS:
			s[k] = int(s[k])
		occupancy[NewGame.cell_key(s["x"], s["y"])] = id
	state["occupancy"] = occupancy
	state["plague"]["turns_left"] = int(state["plague"]["turns_left"])
	for k in state["kits"]:
		state["kits"][k] = int(state["kits"][k])
	for k in state["manifest"]:
		state["manifest"][k] = int(state["manifest"][k])
	for entry in state["log"]:
		entry["turn"] = int(entry["turn"])


static func path_for(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


static func save(state: Dictionary, slot: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null:
		return "Could not save: %s" % error_string(FileAccess.get_open_error())
	f.store_string(to_text(state))
	f.close()
	return ""


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


static func load_slot(slot: String) -> Variant:
	if not exists(slot):
		return "That save does not exist."
	return from_text(FileAccess.get_file_as_string(path_for(slot)))
