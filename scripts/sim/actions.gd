## Player actions. Each one checks its rules and returns {"ok": bool, "reason": String},
## so the UI can explain why something was refused.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Rng = preload("res://scripts/sim/rng.gd")
const Research = preload("res://scripts/sim/research.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason}


static func inside(state: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < int(state["width"]) and y < int(state["height"])


const SURFACE_TERRAIN := ["regolith", "ice", "vent", "seam", "ridge", "deepice", "scorch"]
const DEEP_TERRAIN := ["cavern", "rock", "vein", "aquifer", "deepvent", "bedrock"]


## z is the level: 0 the surface, 1 the Deep.
static func terrain_at(state: Dictionary, x: int, y: int, z: int = 0) -> String:
	return state["tiles"][y][x] if z == 0 else state["deep"][y][x]


static func structure_at(state: Dictionary, x: int, y: int, z: int = 0) -> Dictionary:
	var id: String = state["occupancy"].get(NewGame.cell_key(x, y, z), "")
	if id == "":
		return {}
	return state["structures"][id]


## The sides a building's doors face (tunnels join only through doors), after
## turning it `rot` quarter-turns. Base layouts: 1 door faces +y; 2 doors face
## +x and -x (in one side, out the other); 4 doors face every side.
static func door_dirs(type: String, rot: int) -> Array:
	var n := int(GameData.building(type).get("doors", 4))
	var base: Array = DIRS if n >= 4 else ([Vector2i(1, 0), Vector2i(-1, 0)] if n == 2 else [Vector2i(0, 1)])
	var out: Array = []
	for d in base:
		var v: Vector2i = d
		for _i in posmod(rot, 4):
			v = Vector2i(-v.y, v.x)
		out.append(v)
	return out


## Whether this game uses door rules (saves from before them connect on any side).
static func door_rules(state: Dictionary) -> bool:
	return bool(state.get("door_rules", false))


## Whether structure s has a door on side d.
static func has_door(s: Dictionary, d: Vector2i) -> bool:
	return d in door_dirs(str(s["type"]), int(s.get("rot", 0)))


## Whether two neighbouring structures join, where b sits on a's side d.
static func joined(state: Dictionary, a: Dictionary, b: Dictionary, d: Vector2i) -> bool:
	if not door_rules(state):
		return true
	return has_door(a, d) and has_door(b, -d)


## Whether a building of this type, turned `rot`, at (x, y) would join the colony
## through one of its doors.
static func connects(state: Dictionary, type: String, x: int, y: int, z: int, rot: int) -> bool:
	if not door_rules(state):
		return touches_colony(state, x, y, z)
	for d in door_dirs(type, rot):
		var n: Vector2i = Vector2i(x, y) + d
		if not inside(state, n.x, n.y):
			continue
		var other := structure_at(state, n.x, n.y, z)
		if not other.is_empty() and has_door(other, -d):
			return true
	return false


## The first turn (0-3) that lets this building join the colony here, or -1.
static func auto_rot(state: Dictionary, type: String, x: int, y: int, z: int = 0) -> int:
	for r in 4:
		if connects(state, type, x, y, z, r):
			return r
	return -1


static func touches_colony(state: Dictionary, x: int, y: int, z: int = 0) -> bool:
	for d in DIRS:
		var n: Vector2i = Vector2i(x, y) + d
		if inside(state, n.x, n.y) and not structure_at(state, n.x, n.y, z).is_empty():
			return true
	return false


## Digging into solid rock in the Deep costs extra alloy and turns.
static func excavation(state: Dictionary, x: int, y: int, z: int) -> bool:
	return z == 1 and terrain_at(state, x, y, z) == "rock"


static func build_cost(state: Dictionary, type: String, x: int, y: int, z: int = 0) -> float:
	var cost := GameData.num(GameData.building(type), "cost")
	# While the colony owns a Borer, digging into rock costs nothing extra.
	if excavation(state, x, y, z) and Fleet.owned(state, "borer") == 0:
		# A Heat Main is a narrow tunnel: digging one through rock costs less.
		var deep: Dictionary = GameData.balance()["deep"]
		cost += float(deep.get("excavate_cost_main", deep["excavate_cost"])) if type == "main" else float(deep["excavate_cost"])
	return cost


## Parts a building needs on top of its alloy (from a Fab Shop).
static func parts_cost(type: String) -> float:
	return GameData.num(GameData.building(type), "parts_cost")


## Whether the colony could pay for this building right now (research, alloy, parts), ignoring the tile.
static func affordable(state: Dictionary, type: String) -> bool:
	if has_kit(state, type):
		return true
	return unlocked(state, type) and float(state["stock"]["alloy"]) >= GameData.num(GameData.building(type), "cost") and float(state["stock"]["parts"]) >= parts_cost(type)


## The price as shown in the build menu, e.g. "14" or "40 + 12 parts".
static func price_text(state: Dictionary, type: String, units: bool = false) -> String:
	if has_kit(state, type):
		return "prefab ×%d" % int(state["kits"][type])
	var def := GameData.building(type)
	var text := str(int(GameData.num(def, "cost"))) + (" alloy" if units else "")
	if parts_cost(type) > 0.0:
		text += " + %d parts" % int(parts_cost(type))
	if not unlocked(state, type):
		text += (", needs the %s research" % GameData.topic(def["requires_research"])["name"]) if units else ", locked"
	return text


## Whether the research a building needs is done (or it needs none).
static func unlocked(state: Dictionary, type: String) -> bool:
	var need := str(GameData.building(type).get("requires_research", ""))
	return need == "" or Research.is_done(state, need)


## rot: how the building is turned (0-3), or -1 to turn it automatically to the
## first way that joins the colony.
static func check_place(state: Dictionary, type: String, x: int, y: int, z: int = 0, rot: int = -1) -> Dictionary:
	if state["ending"] != "":
		return result(false, "The game is over.")
	if not GameData.has_building(type):
		return result(false, "Unknown building.")
	var def := GameData.building(type)
	if not def.get("buildable", true):
		return result(false, "%s cannot be built." % def["name"])
	if not unlocked(state, type):
		return result(false, "%s needs the %s research first." % [def["name"], GameData.topic(def["requires_research"])["name"]])
	if not inside(state, x, y):
		return result(false, "Outside the map.")
	if not structure_at(state, x, y, z).is_empty():
		return result(false, "That tile is already in use.")
	var terrain := terrain_at(state, x, y, z)
	if not (terrain in def["terrain"]):
		var level_terrain: Array = SURFACE_TERRAIN if z == 0 else DEEP_TERRAIN
		var allowed := PackedStringArray()
		for t in def["terrain"]:
			if t in level_terrain:
				allowed.append(t)
		if allowed.is_empty():
			return result(false, "%s can only be built %s." % [def["name"], "on the surface" if z == 1 else "in the Deep"])
		return result(false, "%s must be built on %s." % [def["name"], " or ".join(allowed)])
	if type == "shaft" and terrain_at(state, x, y, 1) == "bedrock":
		return result(false, "Solid bedrock below: a shaft can't be dug here.")
	if not touches_colony(state, x, y, z):
		return result(false, "Must be next to the colony. Extend with heat mains." if z == 0 else "Must be next to the colony in the Deep. Start from a Shaft Landing.")
	if door_rules(state):
		var r := auto_rot(state, type, x, y, z) if rot < 0 else rot
		if r < 0 or not connects(state, type, x, y, z, r):
			return result(false, "No door lines up with the colony here. Turn the building (R) so a door faces a door or Heat Main next to it." if rot >= 0 else "None of its doors can face a door or Heat Main here. Lay a Heat Main up to it, or build next to a building with a spare door.")
	if has_kit(state, type):
		return result(true)
	var cost := build_cost(state, type, x, y, z)
	if float(state["stock"]["alloy"]) < cost:
		return result(false, "Needs %d alloy%s." % [int(cost), " (including digging)" if excavation(state, x, y, z) and cost > GameData.num(def, "cost") else ""])
	if float(state["stock"]["parts"]) < parts_cost(type):
		return result(false, "Needs %d parts (made by a Fab Shop)." % int(parts_cost(type)))
	return result(true)


## Prefab kits from the ship's manifest are placed without spending alloy.
static func has_kit(state: Dictionary, type: String) -> bool:
	return int(state.get("kits", {}).get(type, 0)) > 0


static func place(state: Dictionary, type: String, x: int, y: int, z: int = 0, rot: int = -1) -> Dictionary:
	var check := check_place(state, type, x, y, z, rot)
	if not check["ok"]:
		return check
	var turn_to := rot
	if turn_to < 0:
		turn_to = maxi(0, auto_rot(state, type, x, y, z))
	if has_kit(state, type):
		state["kits"][type] = int(state["kits"][type]) - 1
	else:
		state["stock"]["alloy"] = float(state["stock"]["alloy"]) - build_cost(state, type, x, y, z)
		state["stock"]["parts"] = float(state["stock"]["parts"]) - parts_cost(type)
	var id := NewGame.add_structure(state, type, x, y, false, z, turn_to)
	if excavation(state, x, y, z):
		var def := GameData.building(type)
		state["structures"][id]["build_turns"] = int(GameData.num(def, "turns")) + int(GameData.balance()["deep"]["excavate_turns"])
	return result(true)


static func demolish(state: Dictionary, id: String) -> Dictionary:
	if not state["structures"].has(id):
		return result(false, "Nothing to demolish.")
	var s: Dictionary = state["structures"][id]
	if s["type"] == "hull":
		return result(false, "The Landing Pad cannot be demolished.")
	if s["type"] == "shaft_base":
		return result(false, "Demolish the Shaft on the surface to close this landing.")
	var def := GameData.building(s["type"])
	var refund := GameData.num(def, "cost")
	var parts_back := GameData.num(def, "parts_cost")
	if s["built"]:
		refund *= float(GameData.balance()["demolish_refund"])
		parts_back *= float(GameData.balance()["demolish_refund"])
	state["stock"]["alloy"] = float(state["stock"]["alloy"]) + floorf(refund)
	state["stock"]["parts"] = float(state["stock"]["parts"]) + floorf(parts_back)
	state["occupancy"].erase(NewGame.cell_key(int(s["x"]), int(s["y"]), int(s.get("z", 0))))
	state["structures"].erase(id)
	# Closing a shaft also removes its landing in the Deep.
	if s["type"] == "shaft":
		var below := structure_at(state, int(s["x"]), int(s["y"]), 1)
		if not below.is_empty() and below["type"] == "shaft_base":
			state["occupancy"].erase(NewGame.cell_key(int(s["x"]), int(s["y"]), 1))
			state["structures"].erase(below["id"])
	return result(true)


## Can the colony pay these costs ({alloy, parts, credits})? Returns "" or what's missing.
static func _missing(state: Dictionary, costs: Dictionary) -> String:
	var names := {"alloy": "alloy", "parts": "parts", "credits": "marks"}
	for k in names:
		if float(state["stock"][k]) < float(costs.get(k, 0.0)):
			return "Needs %d %s." % [int(costs[k]), names[k]]
	return ""


static func _spend(state: Dictionary, costs: Dictionary) -> void:
	for k in ["alloy", "parts", "credits"]:
		state["stock"][k] = float(state["stock"][k]) - float(costs.get(k, 0.0))


static func _has_built(state: Dictionary, type: String, active: bool = false) -> bool:
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["type"] == type and s["built"] and (not active or s["active"]):
			return true
	return false


## Builds a work drone at a Drone Bay.
static func check_drone(state: Dictionary, type: String) -> Dictionary:
	if state["ending"] != "":
		return result(false, "The game is over.")
	var def := Fleet.drone_def(type)
	if def.is_empty():
		return result(false, "Unknown drone.")
	if not _has_built(state, "dronebay"):
		return result(false, "Build a Drone Bay first.")
	var missing := _missing(state, def)
	return result(missing == "", missing)


static func build_drone(state: Dictionary, type: String) -> Dictionary:
	var check := check_drone(state, type)
	if not check["ok"]:
		return check
	_spend(state, Fleet.drone_def(type))
	state["drones"][type] = Fleet.owned(state, type) + 1
	state["log"].append({"turn": int(state["turn"]), "text": "A new %s rolls out of the Drone Bay." % Fleet.drone_def(type)["name"]})
	return result(true)


## Launches a satellite from a Spin Launcher that worked last turn.
static func check_satellite(state: Dictionary, type: String) -> Dictionary:
	if state["ending"] != "":
		return result(false, "The game is over.")
	var def := Fleet.sat_def(type)
	if def.is_empty():
		return result(false, "Unknown satellite.")
	var need := str(def.get("requires_research", ""))
	if need != "" and not Research.is_done(state, need):
		return result(false, "Needs the %s research first." % GameData.topic(need)["name"])
	if Fleet.sats(state, type) >= int(def["max"]):
		return result(false, "You already have %d in orbit, the most that helps." % int(def["max"]))
	if not _has_built(state, "rail", true):
		return result(false, "Needs a working Spin Launcher.")
	var missing := _missing(state, def)
	return result(missing == "", missing)


static func launch_satellite(state: Dictionary, type: String) -> Dictionary:
	var check := check_satellite(state, type)
	if not check["ok"]:
		return check
	_spend(state, Fleet.sat_def(type))
	state["satellites"][type] = Fleet.sats(state, type) + 1
	state["log"].append({"turn": int(state["turn"]), "text": "The Spin Launcher flings a %s into orbit." % str(Fleet.sat_def(type)["name"]).to_lower()})
	return result(true)


## Calls a supply pod down from the ship in orbit.
static func call_pod(state: Dictionary) -> Dictionary:
	if state["ending"] != "":
		return result(false, "The game is over.")
	if int(state["pods"]) <= 0:
		return result(false, "No supply pods are left aboard the ship.")
	state["pods"] = int(state["pods"]) - 1
	var pod: Dictionary = GameData.balance()["pod"]
	for k in pod:
		state["stock"][k] = float(state["stock"][k]) + float(pod[k])
	state["log"].append({"turn": int(state["turn"]), "text": "A supply lander comes down from the ship onto the landing pad with the pod's cargo."})
	state["lander"] = 1
	state["lander_door"] = (int(state.get("lander_door", 0)) + 1) % 4
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
	radius = maxi(0, radius + Fleet.quake_radius(state))
	var shelter := Fleet.shelter(state)
	var hit := 0
	var saved := 0
	for id in ids:
		var s: Dictionary = state["structures"][id]
		if not s["built"] or s["type"] in ["hull", "main", "cache", "shaft_base"] or int(s.get("z", 0)) != 0:
			continue
		if maxi(absi(int(s["x"]) - int(center["x"])), absi(int(s["y"]) - int(center["y"]))) > radius:
			continue
		if Rng.chance(state, 0.5):
			# A working Rescue Station braces some buildings in time.
			if shelter < 1.0 and not Rng.chance(state, shelter):
				saved += 1
				continue
			s["damaged"] = maxi(int(s["damaged"]), int(GameData.balance()["repair_turns"]))
			hit += 1
	state["log"].append({"turn": int(state["turn"]), "text": "The icequake damaged %d buildings near (%d, %d)." % [hit, int(center["x"]), int(center["y"])]})
	if saved > 0:
		state["log"].append({"turn": int(state["turn"]), "text": "Rescue crews braced %d more in time." % saved})


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
		var shelter := Fleet.shelter(state)
		if shelter < 1.0 and not Rng.chance(state, shelter):
			state["log"].append({"turn": int(state["turn"]), "text": "Rescue crews stopped a breakdown at the %s." % GameData.building(state["structures"][hit]["type"])["name"]})
			continue
		state["structures"][hit]["damaged"] = int(GameData.balance()["repair_turns"])
		var bname: String = GameData.building(state["structures"][hit]["type"])["name"]
		state["log"].append({"turn": int(state["turn"]), "text": "%s is down for repairs." % bname})
