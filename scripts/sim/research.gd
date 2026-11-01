## Research: Survey Labs produce points toward one chosen topic at a time.
## Finished topics apply effects, looked up here by key:
##   "out:<building>"     multiplies that building's output (power, heat, goods)
##   "heat_need", "wear", "storm", "plague", "crime", "elder_death"  multipliers
##   "housing:<building>", "export:<building>", "morale"             additions
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")


static func done(state: Dictionary) -> Array:
	return state["research"]["done"]


static func is_done(state: Dictionary, id: String) -> bool:
	return id in done(state)


## Product of a multiplier effect across finished topics (1.0 if none).
static func mult(state: Dictionary, key: String) -> float:
	var m := 1.0
	for id in done(state):
		var effects: Dictionary = GameData.topic(id).get("effects", {})
		if effects.has(key):
			m *= float(effects[key])
	return m


## Sum of an additive effect across finished topics (0.0 if none).
static func add(state: Dictionary, key: String) -> float:
	var total := 0.0
	for id in done(state):
		var effects: Dictionary = GameData.topic(id).get("effects", {})
		if effects.has(key):
			total += float(effects[key])
	return total


## Topics that are not finished and whose prerequisites are.
static func available(state: Dictionary) -> Array:
	var out: Array = []
	for t in GameData.research_topics():
		if is_done(state, t["id"]):
			continue
		var ready := true
		for req in t["requires"]:
			if not is_done(state, req):
				ready = false
		if ready:
			out.append(t)
	return out


static func is_available(state: Dictionary, id: String) -> bool:
	for t in available(state):
		if t["id"] == id:
			return true
	return false
