## Saves are the state Dictionary written as JSON to user://saves/<slot>.json.
## JSON has no integer type, so normalize() restores ints after loading.
extends RefCounted

const NewGame = preload("res://scripts/sim/new_game.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")
const GameData = preload("res://scripts/sim/game_data.gd")

const DIR := "user://saves"
const INT_FIELDS := ["version", "seed", "rng", "turn", "site", "story_cooldown", "width", "height", "next_id", "payments_made", "missed_in_row", "storm", "surge", "rest", "pods", "lander"]
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
	"difficulty": "normal",
	"site": 0,
	"manifest": {},
	"kits": {},
	"elders": 0.0,
	"crime": 0.0,
	"plague": {"active": false, "turns_left": 0, "cure": 0.0, "need": 0.0},
	"research": {"current": "", "progress": 0.0, "done": []},
	"factions": {"company": 50.0, "union": 50.0},
	"flags": {},
	"story_done": [],
	"story_cooldown": 0,
	"pods": 0,
	"lander": 0,
	"drones": {},
	"satellites": {},
	"waste": 0.0,
	"trained": 0.0,
	# Saves from before door rules keep joining on any side.
	"door_rules": false,
}


static func normalize(state: Dictionary) -> void:
	for k in DEFAULTS:
		if not state.has(k):
			var d: Variant = DEFAULTS[k]
			# Copy lists and dictionaries, so loaded games never share one.
			state[k] = d.duplicate(true) if (typeof(d) == TYPE_DICTIONARY or typeof(d) == TYPE_ARRAY) else d
	if not state.has("debt_total"):
		state["debt_total"] = 6000.0
	# A save can come from a file or the cloud: never trust its text or ids.
	state["colony_name"] = TextRules.clean_colony_name(str(state.get("colony_name", "")))
	if not GameData.has_planet(str(state["planet"])):
		state["planet"] = GameData.DEFAULT_PLANET
	if not GameData.has_difficulty(str(state["difficulty"])):
		state["difficulty"] = GameData.DEFAULT_DIFFICULTY
	for k in INT_FIELDS:
		state[k] = int(state[k])
	# Saves from before the Deep existed: make the level from the map seed.
	if not state.has("deep"):
		const MapGen = preload("res://scripts/sim/map_gen.gd")
		state["deep"] = MapGen.generate_deep(int(state["seed"]), str(state["planet"]))
	var occupancy := {}
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		for k in STRUCT_INT_FIELDS:
			s[k] = int(s[k])
		s["z"] = clampi(int(s.get("z", 0)), 0, 1)
		s["rot"] = posmod(int(s.get("rot", 0)), 4)
		if s.has("build_turns"):
			s["build_turns"] = int(s["build_turns"])
		occupancy[NewGame.cell_key(s["x"], s["y"], s["z"])] = id
	state["occupancy"] = occupancy
	state["plague"]["turns_left"] = int(state["plague"]["turns_left"])
	for k in state["kits"]:
		state["kits"][k] = int(state["kits"][k])
	for group in ["drones", "satellites"]:
		for k in state[group]:
			state[group][k] = int(state[group][k])
	# Saves from before parts existed.
	if not state["stock"].has("parts"):
		state["stock"]["parts"] = 0.0
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
