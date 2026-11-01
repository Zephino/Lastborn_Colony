## Loads the static game data from res://data/*.json once and serves it.
## Nothing here changes during play; all mutable state lives in the state Dictionary.
extends RefCounted

static var _balance: Dictionary = {}
static var _buildings: Dictionary = {}
static var _building_order: Array = []
static var _events: Array = []
static var _story: Dictionary = {}


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


static func story() -> Dictionary:
	ensure_loaded()
	return _story


## Reads a numeric field from a building definition, defaulting to 0.
static func num(def: Dictionary, key: String) -> float:
	return float(def.get(key, 0.0))


## Sunlight at column x: low on the night side (west), high on the day side (east).
static func light_at(x: int) -> float:
	var b := balance()
	var w: int = int(b["map_width"])
	var t := float(x) / float(max(w - 1, 1))
	return lerpf(float(b["light_west"]), float(b["light_east"]), t)


## Heat multiplier at column x: buildings need more heat the further west they sit.
static func cold_at(x: int) -> float:
	var b := balance()
	return clampf(float(b["cold_offset"]) - light_at(x), float(b["cold_min"]), float(b["cold_max"]))
