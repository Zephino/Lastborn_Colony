## Scouting probes, sent before landing. Pure rules, no scene nodes, so the
## setup screens and the tests share them.
## A probe report says what is round a landing site: light and cold, useful
## ground nearby, what lies in the Deep below, how often storms and quakes
## hit, and any lucky find. Finds are fixed by the seed, planet and site (not
## by the game's random stream), so every player sees the same ones.
## Numbers live in data/balance.json ("probes").
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const MapGen = preload("res://scripts/sim/map_gen.gd")
const Rng = preload("res://scripts/sim/rng.gd")

## How far from the pad (in steps) counts as "nearby".
const NEAR := 6


static func rules() -> Dictionary:
	return GameData.balance()["probes"]


## How many probes a ship carries with this cargo.
static func carried(manifest: Dictionary) -> int:
	var r := rules()
	return int(r["free"]) + int(r["per_cargo"]) * int(manifest.get("probe", 0))


## The lucky find at a site: "" (none), or an id from balance probes.finds.
static func find_for(game_seed: int, planet_id: String, site: int) -> String:
	var finds: Dictionary = rules()["finds"]
	var ids: Array = finds.keys()
	ids.sort()
	var h := Rng.hash_seed("%d:%s:%d" % [game_seed, planet_id, site])
	var slots := int(rules()["find_slots"])
	var k := h % slots
	return ids[k] if k < ids.size() else ""


static func find_def(id: String) -> Dictionary:
	return rules()["finds"].get(id, {})


## Words for how often an event happens on a planet, from its weight there.
static func how_often(planet_id: String, event_id: String) -> String:
	var w := float(GameData.planet(planet_id).get("event_weights", {}).get(event_id, 1.0))
	if w < 0.6:
		return "rarely"
	if w < 1.5:
		return "sometimes"
	return "often"


## Everything a probe sends back about one landing site.
static func report(game_seed: int, planet_id: String, site: int) -> Dictionary:
	var map := MapGen.generate(game_seed, planet_id, site)
	var deep := MapGen.generate_deep(game_seed, planet_id)
	var hull: Array = map["hull"]
	var hx := int(hull[0])
	var hy := int(hull[1])
	var near := {"ice": 0, "vent": 0, "seam": 0, "ridge": 0}
	var below := {"vein": 0, "aquifer": 0, "deepvent": 0}
	var tiles: Array = map["tiles"]
	for y in tiles.size():
		for x in tiles[y].size():
			if absi(x - hx) + absi(y - hy) > NEAR:
				continue
			var t: String = tiles[y][x]
			if near.has(t):
				near[t] = int(near[t]) + 1
			var d: String = deep[y][x]
			if below.has(d):
				below[d] = int(below[d]) + 1
	return {
		"map": map,
		"light": GameData.light_at(hx, planet_id),
		"cold": GameData.cold_at(hx, planet_id),
		"near": near,
		"below": below,
		"storms": how_often(planet_id, "dust_storm"),
		"quakes": how_often(planet_id, "icequake"),
		"find": find_for(game_seed, planet_id, site),
	}


## Gives a new colony its site's lucky find.
static func apply_find(state: Dictionary, find: String) -> void:
	var def := find_def(find)
	if def.is_empty():
		return
	var give: Dictionary = def.get("stock", {})
	for k in give:
		state["stock"][k] = float(state["stock"].get(k, 0.0)) + float(give[k])
	# A rich seam: some plain ground two steps from the pad becomes ore seam.
	var seams := int(def.get("seams", 0))
	if seams > 0:
		var hull: Dictionary = {}
		for id in state["structures"]:
			if state["structures"][id]["type"] == "hull":
				hull = state["structures"][id]
		if not hull.is_empty():
			for d in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 1), Vector2i(1, 2)]:
				if seams <= 0:
					break
				var x: int = int(hull["x"]) + d.x
				var y: int = int(hull["y"]) + d.y
				if y >= 0 and y < state["tiles"].size() and x >= 0 and x < state["tiles"][y].size() and state["tiles"][y][x] == "regolith":
					state["tiles"][y][x] = "seam"
					seams -= 1
	state["log"].append({"turn": 1, "text": str(def.get("log", ""))})
