## Loads the static game data from res://data/*.json once and serves it.
## Nothing here changes during play; all mutable state lives in the state Dictionary.
extends RefCounted

static var _balance: Dictionary = {}
static var _buildings: Dictionary = {}
static var _building_order: Array = []
static var _events: Array = []
static var _story: Dictionary = {}
static var _research: Array = []
static var _planets: Array = []
static var _cargo: Dictionary = {}
static var _difficulties: Array = []


static func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Could not read %s" % path)
	return parsed


static func ensure_loaded() -> void:
	if not _balance.is_empty():
		return
	_balance = _load_json("res://data/balance.json")
	var list: Array = _load_json("res://data/buildings.json")
	for b in list:
		_buildings[b["id"]] = b
		_building_order.append(b["id"])
	_events = _load_json("res://data/events.json")
	_story = _load_json("res://data/story.json")
	_research = _load_json("res://data/research.json")
	_planets = _load_json("res://data/planets.json")
	_cargo = _load_json("res://data/cargo.json")
	_difficulties = _load_json("res://data/difficulty.json")


static func balance() -> Dictionary:
	ensure_loaded()
	return _balance


static func building(id: String) -> Dictionary:
	ensure_loaded()
	return _buildings[id]


static func has_building(id: String) -> bool:
	ensure_loaded()
	return _buildings.has(id)


## Building ids in file order (used for the build menu).
static func building_ids() -> Array:
	ensure_loaded()
	return _building_order


static func events() -> Array:
	ensure_loaded()
	return _events


static func event(id: String) -> Dictionary:
	for e in events():
		if e["id"] == id:
			return e
	return {}


static func research_topics() -> Array:
	ensure_loaded()
	return _research


static func topic(id: String) -> Dictionary:
	for t in research_topics():
		if t["id"] == id:
			return t
	return {}


static func story() -> Dictionary:
	ensure_loaded()
	return _story


## Reads a numeric field from a building definition, defaulting to 0.
static func num(def: Dictionary, key: String) -> float:
	return float(def.get(key, 0.0))


const DEFAULT_PLANET := "brume"


static func planets() -> Array:
	ensure_loaded()
	return _planets


static func has_planet(id: String) -> bool:
	for p in planets():
		if p["id"] == id:
			return true
	return false


static func planet(id: String) -> Dictionary:
	for p in planets():
		if p["id"] == id:
			return p
	return planets()[0]


const DEFAULT_DIFFICULTY := "normal"


static func difficulties() -> Array:
	ensure_loaded()
	return _difficulties


static func has_difficulty(id: String) -> bool:
	for d in difficulties():
		if d["id"] == id:
			return true
	return false


static func difficulty(id: String) -> Dictionary:
	for d in difficulties():
		if d["id"] == id:
			return d
	return difficulty(DEFAULT_DIFFICULTY)


## A difficulty modifier for this game (data/difficulty.json), e.g. "debt".
static func diff(state: Dictionary, key: String) -> float:
	return float(difficulty(str(state.get("difficulty", DEFAULT_DIFFICULTY))).get(key, 1.0))


static func cargo() -> Dictionary:
	ensure_loaded()
	return _cargo


static func cargo_item(id: String) -> Dictionary:
	for item in cargo()["items"]:
		if item["id"] == id:
			return item
	return {}


## Sunlight at column x on a planet: low on the night side (west), high on the day side (east).
static func light_at(x: int, planet_id: String = DEFAULT_PLANET) -> float:
	var p := planet(planet_id)
	var w: int = int(balance()["map_width"])
	var t := float(x) / float(max(w - 1, 1))
	return lerpf(float(p["light_west"]), float(p["light_east"]), t)


## Heat multiplier at column x: buildings need more heat where there is less light.
static func cold_at(x: int, planet_id: String = DEFAULT_PLANET) -> float:
	var b := balance()
	var p := planet(planet_id)
	return clampf(float(p["cold_offset"]) - light_at(x, planet_id), float(b["cold_min"]), float(b["cold_max"]))
