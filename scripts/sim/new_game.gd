## Builds a fresh game state. The state is a plain Dictionary that holds the
## whole game and serialises straight to JSON (see save_game.gd).
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const MapGen = preload("res://scripts/sim/map_gen.gd")
const Rng = preload("res://scripts/sim/rng.gd")
const Manifest = preload("res://scripts/sim/manifest.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")

const SAVE_VERSION := 1


## options (all optional): "planet" (id), "difficulty" (id), "site" (landing site index),
## "manifest" (cargo, see manifest.gd; defaults to the recommended load).
static func create(game_seed: int, colony_name: String, options: Dictionary = {}) -> Dictionary:
	colony_name = TextRules.clean_colony_name(colony_name)
	var b := GameData.balance()
	var start: Dictionary = b["start"]
	var planet_id: String = str(options.get("planet", GameData.DEFAULT_PLANET))
	var site: int = int(options.get("site", 0))
	var difficulty_id: String = str(options.get("difficulty", GameData.DEFAULT_DIFFICULTY))
	if not GameData.has_difficulty(difficulty_id):
		difficulty_id = GameData.DEFAULT_DIFFICULTY
	var manifest: Dictionary = options.get("manifest", Manifest.recommended())
	var map := MapGen.generate(game_seed, planet_id, site)
	var state := {
		"version": SAVE_VERSION,
		"seed": game_seed,
		# Offset the event stream from the map stream so they do not correlate.
		"rng": (game_seed ^ Rng.hash_seed(colony_name)) & Rng.M32,
		"turn": 1,
		"colony_name": colony_name,
		"planet": planet_id,
		"difficulty": difficulty_id,
		"site": site,
		"manifest": manifest.duplicate(),
		"kits": {},
		"door_rules": true,
		"pods": 0,
		# Turns the lander stays on the pad (it's there when you land).
		"lander": 1,
		# Which of the pad's four airlocks the lander docks at (0-3; it moves round each landing).
		"lander_door": 0,
		"drones": {},
		"satellites": {},
		"waste": 0.0,
		"trained": 0.0,
		# Power and heat saved by Battery Banks and Heat Stores.
		"battery": 0.0,
		"heat_bank": 0.0,
		"width": int(b["map_width"]),
		"height": int(b["map_height"]),
		"tiles": map["tiles"],
		"deep": MapGen.generate_deep(game_seed, planet_id),
		"structures": {},
		"next_id": 1,
		"occupancy": {},
		"stock": (start["stock"] as Dictionary).duplicate(),
		"debt": 0.0,
		"debt_total": 0.0,
		"payments_made": 0,
		"missed_in_row": 0,
		"adults": float(start["adults"]),
		"children": float(start["children"]),
		"elders": float(start.get("elders", 0.0)),
		"crime": 0.0,
		"plague": {"active": false, "turns_left": 0, "cure": 0.0, "need": 0.0},
		"research": {"current": "", "progress": 0.0, "done": []},
		"factions": {"company": float(b["faction_start"]), "union": float(b["faction_start"])},
		"flags": {},
		"story_done": [],
		"story_cooldown": 0,
		"morale": float(start["morale"]),
		"export_reserve": float(b["export_reserve"]),
		"storm": 0,
		"surge": 0,
		"rest": 0,
		"pending_event": "",
		"ending": "",
		"stats": {"births": 0.0, "deaths": 0.0, "arrivals": 0.0, "exported": 0.0},
		"report": {},
		"log": [],
	}
	Manifest.apply(state, manifest)
	var hull: Array = map["hull"]
	add_structure(state, "hull", int(hull[0]), int(hull[1]), true)
	state["log"].append({"turn": 1, "text": "The ship settles onto the landing pad at %s. Payments to the Company begin on turn %d." % [colony_name, int(b["first_payment_turn"])]})
	return state


## Adds a structure record. Insertion order of state["structures"] is the
## processing order inside a priority band, so keep ids increasing.
## z is the level: 0 the surface, 1 the Deep.
## rot: how many quarter-turns the building is turned (which way its doors face).
static func add_structure(state: Dictionary, type: String, x: int, y: int, built: bool, z: int = 0, rot: int = 0) -> String:
	var id := str(int(state["next_id"]))
	state["next_id"] = int(state["next_id"]) + 1
	state["structures"][id] = {
		"id": id,
		"type": type,
		"x": x,
		"y": y,
		"z": z,
		"rot": posmod(rot, 4),
		"progress": 0,
		"built": built,
		"damaged": 0,
		"active": built,
	}
	state["occupancy"][cell_key(x, y, z)] = id
	return id


## Surface tiles keep the plain "x,y" key; the Deep adds the level.
static func cell_key(x: int, y: int, z: int = 0) -> String:
	return "%d,%d" % [x, y] if z == 0 else "%d,%d,%d" % [x, y, z]
