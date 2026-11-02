## First-game tips: which tip, if any, to show now. Pure rules on the state, so
## they can be tested headless. The text lives in data/tips.json; each tip shows
## once per game (state["tips_seen"]).
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")


static func all() -> Array:
	return GameData.tips()


static func _count(state: Dictionary, type: String) -> int:
	var n := 0
	for id in state["structures"]:
		if state["structures"][id]["type"] == type:
			n += 1
	return n


static func _pop(state: Dictionary) -> float:
	return float(state["adults"]) + float(state["children"]) + float(state["elders"])


## Turns of a resource left at today's use, before anything new is made.
static func _turns_left(state: Dictionary, key: String) -> float:
	var per: float = float(GameData.balance()["life_support"][key]["per_person"]) * _pop(state)
	return float(state["stock"][key]) / maxf(per, 0.001)


## Whether a tip's condition holds now.
static func holds(state: Dictionary, when: String) -> bool:
	var turn := int(state["turn"])
	var rep: Dictionary = state.get("report", {})
	var reasons: Dictionary = rep.get("idle_reasons", {})
	match when:
		"start":
			return turn <= 2
		"no_shaft":
			return turn >= 4 and _count(state, "shaft") == 0
		"deep_open":
			return _count(state, "shaft_base") > 0 and _count(state, "bunk") == 0
		"low_oxygen":
			return turn >= 3 and _turns_left(state, "oxygen") < 6.0
		"low_food":
			return turn >= 3 and _turns_left(state, "food") < 6.0
		"low_water":
			return turn >= 3 and _turns_left(state, "water") < 6.0
		"no_power":
			return reasons.values().has("power")
		"no_heat":
			return reasons.values().has("heat")
		"crowded":
			return not rep.is_empty() and _pop(state) > float(rep.get("housing", 0.0)) + 1.0
		"payment_soon":
			var due := int(GameData.balance()["first_payment_turn"])
			return turn >= due - 8 and turn < due
		"idle_workers":
			return turn >= 6 and int(rep.get("workers_free", 0)) >= 10
		"storm":
			return int(state.get("storm", 0)) > 0
		"low_morale":
			return float(state["morale"]) < 40.0
		"turn_8":
			return turn >= 8
	return false


## The tip to show now ({} for none), marking it seen so it never repeats.
static func next(state: Dictionary) -> Dictionary:
	if not state.has("tips_seen"):
		state["tips_seen"] = []
	var seen: Array = state["tips_seen"]
	for tip in all():
		if tip["id"] in seen:
			continue
		if holds(state, str(tip["when"])):
			seen.append(tip["id"])
			return tip
	return {}
