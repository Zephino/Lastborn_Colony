## Player actions. Each one checks its rules and returns {"ok": bool, "reason": String},
## so the UI can explain why something was refused.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Rng = preload("res://scripts/sim/rng.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason}


static func inside(state: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < int(state["width"]) and y < int(state["height"])


static func terrain_at(state: Dictionary, x: int, y: int) -> String:
	return state["tiles"][y][x]


static func structure_at(state: Dictionary, x: int, y: int) -> Dictionary:
	var id: String = state["occupancy"].get(NewGame.cell_key(x, y), "")
	if id == "":
		return {}
	return state["structures"][id]


static func touches_colony(state: Dictionary, x: int, y: int) -> bool:
	for d in DIRS:
		var n: Vector2i = Vector2i(x, y) + d
		if inside(state, n.x, n.y) and not structure_at(state, n.x, n.y).is_empty():
			return true
	return false


static func check_place(state: Dictionary, type: String, x: int, y: int) -> Dictionary:
	if state["ending"] != "":
		return result(false, "The game is over.")
	if not GameData.has_building(type):
		return result(false, "Unknown building.")
	var def := GameData.building(type)
	if not def.get("buildable", true):
		return result(false, "%s cannot be built." % def["name"])
	if not inside(state, x, y):
		return result(false, "Outside the map.")
	if not structure_at(state, x, y).is_empty():
		return result(false, "That tile is already in use.")
	var terrain := terrain_at(state, x, y)
	if not (terrain in def["terrain"]):
		var allowed: Array = def["terrain"]
		return result(false, "%s must be built on %s." % [def["name"], " or ".join(PackedStringArray(allowed))])
	if not touches_colony(state, x, y):
		return result(false, "Must be next to the colony. Extend with heat mains.")
	if has_kit(state, type):
		return result(true)
	var cost := GameData.num(def, "cost")
	if float(state["stock"]["alloy"]) < cost:
		return result(false, "Needs %d alloy." % int(cost))
	return result(true)


## Prefab kits from the ship's manifest are placed without spending alloy.
static func has_kit(state: Dictionary, type: String) -> bool:
	return int(state.get("kits", {}).get(type, 0)) > 0


static func place(state: Dictionary, type: String, x: int, y: int) -> Dictionary:
	var check := check_place(state, type, x, y)
	if not check["ok"]:
		return check
	var def := GameData.building(type)
	if has_kit(state, type):
		state["kits"][type] = int(state["kits"][type]) - 1
	else:
		state["stock"]["alloy"] = float(state["stock"]["alloy"]) - GameData.num(def, "cost")
	NewGame.add_structure(state, type, x, y, false)
	return result(true)


static func demolish(state: Dictionary, id: String) -> Dictionary:
	if not state["structures"].has(id):
		return result(false, "Nothing to demolish.")
	var s: Dictionary = state["structures"][id]
	if s["type"] == "hull":
		return result(false, "The hull cannot be demolished.")
	var def := GameData.building(s["type"])
	var refund := GameData.num(def, "cost")
	if s["built"]:
		refund *= float(GameData.balance()["demolish_refund"])
	state["stock"]["alloy"] = float(state["stock"]["alloy"]) + floorf(refund)
	state["occupancy"].erase(NewGame.cell_key(int(s["x"]), int(s["y"])))
	state["structures"].erase(id)
	return result(true)


static func pay_extra(state: Dictionary, amount: float) -> Dictionary:
	amount = minf(amount, float(state["debt"]))
	if amount <= 0.0:
		return result(false, "Nothing to pay.")
	if float(state["stock"]["credits"]) < amount:
		return result(false, "Not enough marks.")
	state["stock"]["credits"] = float(state["stock"]["credits"]) - amount
	state["debt"] = float(state["debt"]) - amount
	state["log"].append({"turn": int(state["turn"]), "text": "Paid %d marks toward the debt early." % int(amount)})
	return result(true)


static func set_export_reserve(state: Dictionary, amount: float) -> void:
	state["export_reserve"] = maxf(0.0, amount)


static func set_research(state: Dictionary, id: String) -> Dictionary:
	const Research = preload("res://scripts/sim/research.gd")
	if id != "" and not Research.is_available(state, id):
		return result(false, "That topic is not available yet.")
	if id != state["research"]["current"]:
		state["research"]["current"] = id
		state["research"]["progress"] = 0.0
	return result(true)


static func choice_allowed(state: Dictionary, choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("requires", {})
	for key in req:
		if float(state["stock"].get(key, 0.0)) < float(req[key]):
			return false
	return true


static func resolve_event(state: Dictionary, choice_index: int) -> Dictionary:
	var id: String = state["pending_event"]
	if id == "":
		return result(false, "No event is waiting.")
	var ev := GameData.event(id)
	var choices: Array = ev.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return result(false, "No such choice.")
	var choice: Dictionary = choices[choice_index]
	if not choice_allowed(state, choice):
		return result(false, "You cannot afford that.")
	apply_effects(state, choice.get("effects", {}))
	state["pending_event"] = ""
	state["log"].append({"turn": int(state["turn"]), "text": "%s: %s." % [ev["title"], choice["label"]]})
	return result(true)


## Applies an event effect dictionary. Keys:
## stock names (food, credits, ...) add to stock; morale/adults/debt add to those;
## storm/surge/rest set a timer in turns; damage shuts down that many random buildings.
## Story effects: company/union change those relations (0-100); flag sets a
## story flag; ending ends the game with that ending.
static func apply_effects(state: Dictionary, effects: Dictionary) -> void:
	for key in effects:
		if key == "flag":
			state["flags"][str(effects[key])] = true
			continue
		if key == "ending":
			var ending := str(effects[key])
			state["ending"] = ending
			state["pending_event"] = ""
			state["log"].append({"turn": int(state["turn"]), "text": GameData.story()["endings"][ending]["title"] + "."})
			continue
		var v := float(effects[key])
		match key:
			"company", "union":
				state["factions"][key] = clampf(float(state["factions"][key]) + v, 0.0, 100.0)
			"morale":
				state["morale"] = clampf(float(state["morale"]) + v, 0.0, 100.0)
			"adults":
				state["adults"] = float(state["adults"]) + v
				state["stats"]["arrivals"] = float(state["stats"]["arrivals"]) + v
			"debt":
				state["debt"] = maxf(0.0, float(state["debt"]) + v)
			"storm", "surge", "rest":
				state[key] = maxi(int(state[key]), int(v))
			"damage":
				_damage_random(state, int(v))
			"damage_area":
				_damage_area(state, int(v))
			_:
				if state["stock"].has(key):
					state["stock"][key] = maxf(0.0, float(state["stock"][key]) + v)


## Damages buildings within a radius of a random building in the colony.
static func _damage_area(state: Dictionary, radius: int) -> void:
	var ids: Array = state["structures"].keys()
	if ids.size() < 2:
		return
	var center: Dictionary = state["structures"][Rng.pick(state, ids)]
	var hit := 0
	for id in ids:
		var s: Dictionary = state["structures"][id]
		if not s["built"] or s["type"] in ["hull", "main", "cache"]:
			continue
		if maxi(absi(int(s["x"]) - int(center["x"])), absi(int(s["y"]) - int(center["y"]))) > radius:
			continue
		if Rng.chance(state, 0.5):
			s["damaged"] = maxi(int(s["damaged"]), int(GameData.balance()["repair_turns"]))
			hit += 1
	state["log"].append({"turn": int(state["turn"]), "text": "The icequake damaged %d buildings near (%d, %d)." % [hit, int(center["x"]), int(center["y"])]})


static func _damage_random(state: Dictionary, count: int) -> void:
	for _i in count:
		var candidates: Array = []
		for id in state["structures"]:
			var s: Dictionary = state["structures"][id]
			if s["built"] and int(s["damaged"]) == 0 and s["type"] != "hull" and s["type"] != "main" and s["type"] != "cache":
				candidates.append(id)
		if candidates.is_empty():
			return
		var hit: String = Rng.pick(state, candidates)
		state["structures"][hit]["damaged"] = int(GameData.balance()["repair_turns"])
		var bname: String = GameData.building(state["structures"][hit]["type"])["name"]
		state["log"].append({"turn": int(state["turn"]), "text": "%s is down for repairs." % bname})
