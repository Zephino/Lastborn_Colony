## Drones, satellites, supply pods, waste and specialists: the systems that came
## with the Drone Bay, Fab Shop, Reclaimer, Academy and the Launch Rail's
## satellites. Pure rules on the state Dictionary, like the rest of scripts/sim.
## Numbers live in data/balance.json ("drones", "satellites", "waste",
## "training", "pod").
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Research = preload("res://scripts/sim/research.gd")


static func drone_def(type: String) -> Dictionary:
	return GameData.balance()["drones"]["types"].get(type, {})


static func sat_def(type: String) -> Dictionary:
	return GameData.balance()["satellites"]["types"].get(type, {})


static func drone_order() -> Array:
	return GameData.balance()["drones"]["order"]


static func sat_order() -> Array:
	return GameData.balance()["satellites"]["order"]


static func owned(state: Dictionary, type: String) -> int:
	return int(state["drones"].get(type, 0))


static func drones_total(state: Dictionary) -> int:
	var n := 0
	for t in state["drones"]:
		n += int(state["drones"][t])
	return n


static func sats(state: Dictionary, type: String) -> int:
	return int(state["satellites"].get(type, 0))


## Drone slots from the Drone Bays that worked last turn.
static func slots(state: Dictionary) -> int:
	return int(state.get("report", {}).get("drone_slots", 0))


## How many drones of each type work this turn. Free slots are filled in a
## fixed order (data: drones.order); the rest sit idle.
static func working(state: Dictionary) -> Dictionary:
	var left := slots(state)
	var out := {}
	for t in drone_order():
		var n := mini(owned(state, t), left)
		out[t] = n
		left -= n
	return out


## Extra turns of construction this turn, by structure id. Each working Grader
## helps one surface building; each working Borer one Shaft or Deep building.
static func construction_bonus(state: Dictionary) -> Dictionary:
	var work := working(state)
	var graders := int(work.get("grader", 0))
	var borers := int(work.get("borer", 0))
	var bonus := {}
	for id in state["structures"]:
		if graders <= 0 and borers <= 0:
			break
		var s: Dictionary = state["structures"][id]
		if s["built"]:
			continue
		var digging: bool = s["type"] == "shaft" or int(s.get("z", 0)) == 1
		if digging and borers > 0:
			bonus[id] = 1
			borers -= 1
		elif not digging and graders > 0:
			bonus[id] = 1
			graders -= 1
	return bonus


## Production multiplier from trained specialists for this building type.
static func trained_mult(state: Dictionary, type: String) -> float:
	var t: Dictionary = GameData.balance()["training"]
	if not (type in t["types"]):
		return 1.0
	var adults := float(state["adults"])
	if adults <= 0.0:
		return 1.0
	var share := minf(float(state["trained"]) / adults, float(t["cap"]))
	return 1.0 + float(t["bonus"]) * share


## Morale lost to waste lying around.
static func waste_morale(state: Dictionary) -> float:
	var w: Dictionary = GameData.balance()["waste"]
	var over := maxf(0.0, float(state["waste"]) - float(w["free"]))
	return minf(over * float(w["morale_per"]), float(w["morale_cap"]))


## Plague chance multiplier: much waste helps it spread.
static func waste_plague(state: Dictionary) -> float:
	var w: Dictionary = GameData.balance()["waste"]
	return float(w["plague_mult"]) if float(state["waste"]) > 2.0 * float(w["free"]) else 1.0


## New waste from everyone, less what breaks down by itself.
static func make_waste(state: Dictionary, pop: float) -> void:
	var w: Dictionary = GameData.balance()["waste"]
	state["waste"] = float(state["waste"]) * (1.0 - float(w["decay"])) + pop * float(w["per_person"])


## Specialists trained by working Academies, capped at a share of the adults.
static func train(state: Dictionary) -> void:
	var gain := 0.0
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["active"]:
			gain += GameData.num(GameData.building(s["type"]), "training")
	var cap := float(state["adults"]) * float(GameData.balance()["training"]["cap"])
	state["trained"] = clampf(float(state["trained"]) + gain, 0.0, cap)


## Share of disaster damage that still gets through (1.0 with no Rescue Station working).
static func shelter(state: Dictionary) -> float:
	var f := 1.0
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["active"]:
			var def := GameData.building(s["type"])
			if def.has("shelter"):
				f = minf(f, float(def["shelter"]))
	return f


## Morale from satellites in orbit.
static func sat_morale(state: Dictionary) -> float:
	var m := 0.0
	for t in sat_order():
		m += float(sat_def(t).get("morale", 0.0)) * sats(state, t)
	return m


## How much of a grit front's mirror loss still happens (weather satellites help).
static func storm_mult(state: Dictionary) -> float:
	var m := 1.0
	for t in sat_order():
		if sats(state, t) > 0 and sat_def(t).has("storm"):
			m *= float(sat_def(t)["storm"])
	return m


## Change to an icequake's reach (weather satellites see them coming).
static func quake_radius(state: Dictionary) -> int:
	var r := 0
	for t in sat_order():
		if sats(state, t) > 0:
			r += int(sat_def(t).get("quake_radius", 0))
	return r
