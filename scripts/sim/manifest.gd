## The ship's manifest: what the colony brings down, chosen before landing.
## Each unit of cargo fills one bay and is bought on credit from the Company,
## so it adds to the starting debt (data/cargo.json). A manifest is a plain
## Dictionary {item_id: count}.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")


static func recommended() -> Dictionary:
	return (GameData.cargo()["recommended"] as Dictionary).duplicate()


static func bays() -> int:
	return int(GameData.cargo()["bays"])


static func bays_used(manifest: Dictionary) -> int:
	var n := 0
	for id in manifest:
		n += int(manifest[id])
	return n


## The debt the colony starts with: the bare ship plus every unit of cargo,
## scaled by the difficulty (Easy is cheaper, Hard dearer).
static func debt_of(manifest: Dictionary, difficulty_id: String = GameData.DEFAULT_DIFFICULTY) -> float:
	var debt := float(GameData.cargo()["base_debt"])
	for id in manifest:
		debt += float(GameData.cargo_item(id).get("debt", 0)) * int(manifest[id])
	return round(debt * float(GameData.difficulty(difficulty_id)["debt"]))


## {"ok": bool, "reason": String}
static func check(manifest: Dictionary) -> Dictionary:
	for id in manifest:
		var item := GameData.cargo_item(str(id))
		if item.is_empty():
			return {"ok": false, "reason": "Unknown cargo: %s." % id}
		var n := int(manifest[id])
		if n < 0 or n > int(item["max"]):
			return {"ok": false, "reason": "%s: at most %d." % [item["name"], int(item["max"])]}
	if bays_used(manifest) > bays():
		return {"ok": false, "reason": "The hold has only %d bays." % bays()}
	return {"ok": true, "reason": ""}


## Adds the cargo to a new game's people, stock and prefab kits.
static func apply(state: Dictionary, manifest: Dictionary) -> void:
	for id in manifest:
		var item := GameData.cargo_item(str(id))
		var n := int(manifest[id])
		if item.is_empty() or n <= 0:
			continue
		var adds: Dictionary = item.get("adds", {})
		for k in adds:
			var v := float(adds[k]) * n
			if state["stock"].has(k):
				state["stock"][k] = float(state["stock"][k]) + v
			else:
				state[k] = float(state[k]) + v
		if item.has("pod"):
			state["pods"] = int(state.get("pods", 0)) + int(item["pod"]) * n
		if item.has("kit"):
			var kits: Dictionary = state["kits"]
			kits[item["kit"]] = int(kits.get(item["kit"], 0)) + n
	state["debt"] = debt_of(manifest, str(state.get("difficulty", GameData.DEFAULT_DIFFICULTY)))
	state["debt_total"] = state["debt"]
