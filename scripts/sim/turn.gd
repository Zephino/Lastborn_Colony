## Advances the game by one turn. The steps run in a fixed order and results
## depend on it; see README.md, "Turn order".
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Rng = preload("res://scripts/sim/rng.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func log_msg(state: Dictionary, text: String) -> void:
	var entries: Array = state["log"]
	entries.append({"turn": int(state["turn"]), "text": text})
	var limit: int = int(GameData.balance()["log_limit"])
	while entries.size() > limit:
		entries.pop_front()


static func end_turn(state: Dictionary) -> void:
	if state["ending"] != "" or state["pending_event"] != "":
		return
	var before: Dictionary = (state["stock"] as Dictionary).duplicate()
	_construction(state)
	_repairs(state)
	var connected := connectivity(state)
	var rep := _allocate(state, connected)
	_produce(state, rep)
	_cap_storage(state, rep)
	_life_support(state, rep)
	_population(state, rep)
	_morale(state, rep)
	_payments(state, rep)
	_timers(state)
	_events(state)
	_endings(state)
	var net := {}
	for key in state["stock"]:
		net[key] = float(state["stock"][key]) - float(before.get(key, 0.0))
	rep["net"] = net
	state["report"] = rep
	state["turn"] = int(state["turn"]) + 1


# 1. Construction: each unfinished building gains one turn of progress.
static func _construction(state: Dictionary) -> void:
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["built"]:
			continue
		s["progress"] = int(s["progress"]) + 1
		var def := GameData.building(s["type"])
		if int(s["progress"]) >= int(GameData.num(def, "turns")):
			s["built"] = true
			if s["type"] != "main":
				log_msg(state, "%s is complete." % def["name"])


# 2. Repairs count down; a damaged building stays idle until it reaches zero.
static func _repairs(state: Dictionary) -> void:
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if int(s["damaged"]) > 0:
			s["damaged"] = int(s["damaged"]) - 1
			if int(s["damaged"]) == 0:
				log_msg(state, "%s is back online." % GameData.building(s["type"])["name"])


# 3. Connectivity: finished buildings joined to the hull through other finished buildings.
static func connectivity(state: Dictionary) -> Dictionary:
	var connected := {}
	var start := ""
	for id in state["structures"]:
		if state["structures"][id]["type"] == "hull":
			start = id
			break
	if start == "":
		return connected
	connected[start] = true
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var s: Dictionary = state["structures"][queue[head]]
		head += 1
		for d in DIRS:
			var n: Vector2i = Vector2i(int(s["x"]), int(s["y"])) + d
			var other_id: String = state["occupancy"].get(NewGame.cell_key(n.x, n.y), "")
			if other_id == "" or connected.has(other_id):
				continue
			if state["structures"][other_id]["built"]:
				connected[other_id] = true
				queue.append(other_id)
	return connected


# 4. Allocation: generators first, then consumers in priority order. A building
#    runs only if it gets all its workers, power and heat; otherwise it idles.
static func _allocate(state: Dictionary, connected: Dictionary) -> Dictionary:
	var b := GameData.balance()
	var workers_total := 0 if int(state["rest"]) > 0 else int(floor(float(state["adults"])))
	var workers := workers_total
	var power := 0.0
	var heat := 0.0
	var power_gen := 0.0
	var heat_gen := 0.0
	var idle := 0
	var eligible: Array = []
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		s["active"] = false
		var def := GameData.building(s["type"])
		if s["built"] and connected.has(id) and int(s["damaged"]) == 0 and not def.get("conduit", false):
			eligible.append(id)

	# Pass 1: pure generators (no power or heat needs).
	for pri in 10:
		for id in eligible:
			var s: Dictionary = state["structures"][id]
			var def := GameData.building(s["type"])
			if int(GameData.num(def, "priority")) != pri:
				continue
			var pg := GameData.num(def, "power_gen")
			var hg := GameData.num(def, "heat_gen")
			if (pg <= 0.0 and hg <= 0.0) or GameData.num(def, "power_use") > 0.0 or GameData.num(def, "heat_need") > 0.0:
				continue
			var need := int(GameData.num(def, "workers"))
			if workers < need:
				continue
			workers -= need
			s["active"] = true
			if def.get("solar", false):
				pg *= GameData.light_at(int(s["x"]))
				if int(state["storm"]) > 0:
					pg *= float(b["storm_solar_factor"])
			if s["type"] == "vent" and int(state["surge"]) > 0:
				hg *= float(b["surge_vent_factor"])
			power += pg
			heat += hg
	power_gen = power
	heat_gen = heat

	# Pass 2: everything else.
	for pri in 10:
		for id in eligible:
			var s: Dictionary = state["structures"][id]
			if s["active"]:
				continue
			var def := GameData.building(s["type"])
			if int(GameData.num(def, "priority")) != pri:
				continue
			var need := int(GameData.num(def, "workers"))
			var pu := GameData.num(def, "power_use")
			var hn := GameData.num(def, "heat_need") * GameData.cold_at(int(s["x"]))
			if workers >= need and power >= pu and heat >= hn:
				workers -= need
				power -= pu
				heat -= hn
				var hg := GameData.num(def, "heat_gen")
				heat += hg
				heat_gen += hg
				s["active"] = true
			else:
				idle += 1

	var housing := 0.0
	var storage := float(b["base_storage"])
	var morale_bonus := 0.0
	var health := 1.0
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		var def := GameData.building(s["type"])
		if s["built"]:
			storage += GameData.num(def, "storage")
		if s["active"]:
			housing += GameData.num(def, "housing")
			morale_bonus += GameData.num(def, "morale")
			if def.has("health"):
				health = minf(health, float(def["health"]))
	return {
		"workers_total": workers_total,
		"workers_free": workers,
		"power_gen": power_gen,
		"power_free": power,
		"heat_gen": heat_gen,
		"heat_free": heat,
		"idle": idle,
		"housing": housing,
		"storage": storage,
		"morale_bonus": minf(morale_bonus, float(b["morale_building_cap"])),
		"health": health,
		"shortages": {},
	}


static func efficiency(state: Dictionary) -> float:
	var b := GameData.balance()
	return clampf(0.5 + float(state["morale"]) / 100.0, float(b["efficiency_min"]), float(b["efficiency_max"]))


# 5. Production, in priority order so water is made before it is used.
static func _produce(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var stock: Dictionary = state["stock"]
	var e := efficiency(state)
	rep["efficiency"] = e
	for pri in 10:
		for id in state["structures"]:
			var s: Dictionary = state["structures"][id]
			if not s["active"]:
				continue
			var def := GameData.building(s["type"])
			if int(GameData.num(def, "priority")) != pri:
				continue
			var inputs: Dictionary = def.get("inputs", {})
			var ok := true
			for k in inputs:
				if float(stock[k]) < float(inputs[k]):
					ok = false
			if ok:
				for k in inputs:
					stock[k] = float(stock[k]) - float(inputs[k])
				var outputs: Dictionary = def.get("outputs", {})
				for k in outputs:
					stock[k] = float(stock[k]) + float(outputs[k]) * e
			if def.has("export"):
				var amount := minf(float(def["export"]), float(stock["alloy"]) - float(state["export_reserve"]))
				if amount > 0.0:
					stock["alloy"] = float(stock["alloy"]) - amount
					stock["credits"] = float(stock["credits"]) + amount * float(b["alloy_price"])
					state["stats"]["exported"] = float(state["stats"]["exported"]) + amount


# 6. Anything over storage capacity is lost. Marks are not stored physically.
static func _cap_storage(state: Dictionary, rep: Dictionary) -> void:
	var cap := float(rep["storage"])
	for k in GameData.balance()["stored_resources"]:
		state["stock"][k] = minf(float(state["stock"][k]), cap)


# 7. Life support: everyone eats, breathes and drinks. Shortfalls kill.
static func _life_support(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var pop := float(state["adults"]) + float(state["children"])
	var deaths := 0.0
	var shortages: Dictionary = rep["shortages"]
	var ls: Dictionary = b["life_support"]
	for k in ["food", "oxygen", "water"]:
		var rule: Dictionary = ls[k]
		var need := pop * float(rule["per_person"])
		var have := float(state["stock"][k])
		if have >= need:
			state["stock"][k] = have - need
		else:
			var frac := 1.0 - have / need
			state["stock"][k] = 0.0
			shortages[k] = frac
			deaths += pop * frac * float(rule["lethality"]) * float(rep["health"])
	rep["shortage_deaths"] = deaths


# 8. Population: births, children growing up, deaths.
static func _population(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var adults := float(state["adults"])
	var children := float(state["children"])
	var pop := adults + children
	var housing := float(rep["housing"])
	var births := 0.0
	if pop < housing:
		births = adults * float(b["birth_rate"]) * (float(state["morale"]) / 60.0)
	children += births
	var grow := children / float(b["child_turns"])
	children -= grow
	adults += grow
	var deaths := float(rep["shortage_deaths"])
	deaths += pop * float(b["base_death_rate"]) * float(rep["health"])
	var excess := maxf(0.0, pop - housing)
	deaths += excess * float(b["overcrowding_death_rate"])
	if pop > 0.0:
		adults -= deaths * adults / pop
		children -= deaths * children / pop
	state["adults"] = maxf(0.0, adults)
	state["children"] = maxf(0.0, children)
	state["stats"]["births"] = float(state["stats"]["births"]) + births
	state["stats"]["deaths"] = float(state["stats"]["deaths"]) + deaths
	rep["births"] = births
	rep["deaths"] = deaths
	rep["overcrowding"] = excess / maxf(pop, 1.0)
	if float(rep["shortage_deaths"]) >= 0.5:
		log_msg(state, "Shortages killed %d colonists." % int(round(float(rep["shortage_deaths"]))))


# 9. Morale drifts toward a target set by comfort, shortages and debt.
static func _morale(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var target := float(b["morale_base"]) + float(rep["morale_bonus"])
	var ls: Dictionary = b["life_support"]
	for k in rep["shortages"]:
		target += float(ls[k]["morale"])
	target += float(b["overcrowding_morale"]) * float(rep["overcrowding"])
	target += float(b["morale_per_missed_payment"]) * int(state["missed_in_row"])
	var m := float(state["morale"])
	m += (target - m) * float(b["morale_drift"])
	state["morale"] = clampf(m, 0.0, 100.0)
	rep["morale_target"] = target
	if float(state["morale"]) < float(b["defection_morale"]):
		var lost := float(state["adults"]) * float(b["defection_rate"])
		state["adults"] = float(state["adults"]) - lost
		if lost >= 0.5:
			log_msg(state, "%d colonists walked out to the Company depot." % int(round(lost)))


static func payment_due(_state: Dictionary, turn: int) -> bool:
	var b := GameData.balance()
	var first := int(b["first_payment_turn"])
	return turn >= first and (turn - first) % int(b["payment_interval"]) == 0


static func next_payment_turn(state: Dictionary) -> int:
	var t := int(state["turn"])
	while not payment_due(state, t):
		t += 1
	return t


static func next_payment_amount(state: Dictionary) -> float:
	var b := GameData.balance()
	var amount := float(b["payment_base"]) + float(b["payment_step"]) * int(state["payments_made"])
	return minf(amount, float(state["debt"]))


# 10. Company payments.
static func _payments(state: Dictionary, rep: Dictionary) -> void:
	if float(state["debt"]) <= 0.0 or not payment_due(state, int(state["turn"])):
		return
	var b := GameData.balance()
	var amount := next_payment_amount(state)
	var stock: Dictionary = state["stock"]
	if float(stock["credits"]) >= amount:
		stock["credits"] = float(stock["credits"]) - amount
		state["debt"] = float(state["debt"]) - amount
		state["payments_made"] = int(state["payments_made"]) + 1
		state["missed_in_row"] = 0
		var arriving := float(b["immigrants"])
		var housing := float(rep["housing"])
		if float(state["adults"]) + float(state["children"]) + arriving <= housing:
			state["adults"] = float(state["adults"]) + arriving
			state["stats"]["arrivals"] = float(state["stats"]["arrivals"]) + arriving
			log_msg(state, "Paid the Company %d marks. %d new colonists came down on the supply drop." % [int(amount), int(arriving)])
		else:
			log_msg(state, "Paid the Company %d marks. No room for new colonists this time." % int(amount))
	else:
		state["missed_in_row"] = int(state["missed_in_row"]) + 1
		state["debt"] = float(state["debt"]) + amount * float(b["missed_penalty"])
		state["morale"] = clampf(float(state["morale"]) + float(b["missed_payment_morale"]), 0.0, 100.0)
		log_msg(state, "Missed a payment of %d marks (%d in a row). The Company adds a penalty." % [int(amount), int(state["missed_in_row"])])


# 11. Timers for storms, vent surges and rest days.
static func _timers(state: Dictionary) -> void:
	for k in ["storm", "surge", "rest"]:
		if int(state[k]) > 0:
			state[k] = int(state[k]) - 1


# 12. Random events. Events with choices pause the game until resolved.
static func _events(state: Dictionary) -> void:
	var b := GameData.balance()
	if int(state["turn"]) < int(b["event_grace_turns"]):
		return
	if not Rng.chance(state, float(b["event_chance"])):
		return
	var list := GameData.events()
	var weights: Array = []
	for e in list:
		weights.append(float(e.get("weight", 1.0)))
	var ev: Dictionary = list[Rng.weighted_index(state, weights)]
	log_msg(state, "%s. %s" % [ev["title"], ev["body"]])
	Actions.apply_effects(state, ev.get("effects", {}))
	if ev.has("choices"):
		state["pending_event"] = ev["id"]


# 13. Endings.
static func _endings(state: Dictionary) -> void:
	var b := GameData.balance()
	var ending := ""
	if float(state["debt"]) <= 0.01:
		ending = "free"
	elif int(state["missed_in_row"]) >= int(b["max_missed"]):
		ending = "receivership"
	elif float(state["adults"]) + float(state["children"]) < 1.0:
		ending = "silent"
	if ending != "":
		state["ending"] = ending
		state["pending_event"] = ""
		log_msg(state, GameData.story()["endings"][ending]["title"] + ".")
