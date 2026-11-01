## Advances the game by one turn. The steps run in a fixed order and results
## depend on it; see README.md, "Turn order".
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Rng = preload("res://scripts/sim/rng.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Research = preload("res://scripts/sim/research.gd")

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
	_research_step(state, rep)
	_cap_storage(state, rep)
	_life_support(state, rep)
	_population(state, rep)
	_morale(state, rep)
	_crime(state, rep)
	_wear(state)
	_plague(state, rep)
	_payments(state, rep)
	_timers(state)
	_events(state)
	_endings(state)
	var net := {}
	for key in state["stock"]:
		net[key] = float(state["stock"][key]) - float(before.get(key, 0.0))
	rep["net"] = net
	state["report"] = rep
	_quantize(state)
	state["turn"] = int(state["turn"]) + 1


## Rounds a stored value to 6 decimal places. Godot writes floats to JSON with
## 15 significant digits, so unrounded values would change slightly on every
## save and load, and a loaded game would drift from the original.
static func q(x: float) -> float:
	return roundf(x * 1000000.0) / 1000000.0


static func _quantize(state: Dictionary) -> void:
	for k in ["adults", "children", "elders", "morale", "debt", "export_reserve", "crime"]:
		state[k] = q(float(state[k]))
	state["plague"]["cure"] = q(float(state["plague"]["cure"]))
	state["research"]["progress"] = q(float(state["research"]["progress"]))
	for group in ["stock", "stats"]:
		var d: Dictionary = state[group]
		for k in d:
			d[k] = q(float(d[k]))


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
	# Each Workshop that ran last turn takes one more turn off every repair.
	var speed := 1
	for id in state["structures"]:
		var w: Dictionary = state["structures"][id]
		if w["active"] and GameData.building(w["type"]).has("repair"):
			speed += int(GameData.building(w["type"])["repair"])
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if int(s["damaged"]) > 0:
			s["damaged"] = maxi(0, int(s["damaged"]) - speed)
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
			var boost := Research.mult(state, "out:" + str(s["type"]))
			pg *= boost
			hg *= boost
			if def.get("solar", false):
				pg *= GameData.light_at(int(s["x"]))
				if int(state["storm"]) > 0:
					var loss := (1.0 - float(b["storm_solar_factor"])) * Research.mult(state, "storm")
					pg *= 1.0 - loss
			if s["type"] == "vent" and int(state["surge"]) > 0:
				hg *= float(b["surge_vent_factor"])
			power += pg
			heat += hg
	power_gen = power
	heat_gen = heat

	# Pass 2: everything else.
	var heat_mult := Research.mult(state, "heat_need")
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
			var hn := GameData.num(def, "heat_need") * GameData.cold_at(int(s["x"])) * heat_mult
			if workers >= need and power >= pu and heat >= hn:
				workers -= need
				power -= pu
				heat -= hn
				var hg := GameData.num(def, "heat_gen") * Research.mult(state, "out:" + str(s["type"]))
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
			if GameData.num(def, "housing") > 0.0:
				housing += GameData.num(def, "housing") + Research.add(state, "housing:" + str(s["type"]))
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
	var points := 0.0
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
				var boost := Research.mult(state, "out:" + str(s["type"]))
				for k in outputs:
					stock[k] = float(stock[k]) + float(outputs[k]) * e * boost
			if def.has("research"):
				points += float(def["research"]) * e * float(b["research_per_point"])
			if def.has("export"):
				var cap := float(def["export"]) + Research.add(state, "export:" + str(s["type"]))
				var amount := minf(cap, float(stock["alloy"]) - float(state["export_reserve"]))
				if amount > 0.0:
					stock["alloy"] = float(stock["alloy"]) - amount
					stock["credits"] = float(stock["credits"]) + amount * float(b["alloy_price"])
					state["stats"]["exported"] = float(state["stats"]["exported"]) + amount
	rep["research_points"] = points


# 6. Research. During a plague, all research goes to the cure first.
static func _research_step(state: Dictionary, rep: Dictionary) -> void:
	var points := float(rep["research_points"])
	if points <= 0.0:
		return
	var plague: Dictionary = state["plague"]
	if plague["active"]:
		plague["cure"] = float(plague["cure"]) + points
		return
	var r: Dictionary = state["research"]
	var id: String = r["current"]
	if id == "":
		return
	r["progress"] = float(r["progress"]) + points
	var t := GameData.topic(id)
	if float(r["progress"]) >= float(t["cost"]):
		r["done"].append(id)
		r["current"] = ""
		r["progress"] = 0.0
		log_msg(state, "Research complete: %s. %s" % [t["name"], t["desc"]])


# 7. Anything over storage capacity is lost. Marks are not stored physically.
static func _cap_storage(state: Dictionary, rep: Dictionary) -> void:
	var cap := float(rep["storage"])
	for k in GameData.balance()["stored_resources"]:
		state["stock"][k] = minf(float(state["stock"][k]), cap)


# 8. Life support: everyone eats, breathes and drinks. Shortfalls kill.
static func population(state: Dictionary) -> float:
	return float(state["adults"]) + float(state["children"]) + float(state["elders"])


static func _life_support(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var pop := population(state)
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


# 9. Population: births, growing up, aging, deaths.
static func _population(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var adults := float(state["adults"])
	var children := float(state["children"])
	var elders := float(state["elders"])
	var pop := adults + children + elders
	var housing := float(rep["housing"])
	var births := 0.0
	if pop < housing:
		births = adults * float(b["birth_rate"]) * (float(state["morale"]) / 60.0)
	children += births
	var grow := children / float(b["child_turns"])
	children -= grow
	adults += grow
	var aging := adults * float(b["aging_rate"])
	adults -= aging
	elders += aging
	var elder_deaths := elders * float(b["elder_death_rate"]) * float(rep["health"]) * Research.mult(state, "elder_death")
	elders -= elder_deaths
	var deaths := float(rep["shortage_deaths"])
	deaths += pop * float(b["base_death_rate"]) * float(rep["health"])
	if state["plague"]["active"]:
		deaths += pop * float(b["plague_death_rate"]) * float(rep["health"])
	var excess := maxf(0.0, pop - housing)
	deaths += excess * float(b["overcrowding_death_rate"])
	var living := adults + children + elders
	if living > 0.0:
		adults -= deaths * adults / living
		children -= deaths * children / living
		elders -= deaths * elders / living
	deaths += elder_deaths
	state["adults"] = maxf(0.0, adults)
	state["children"] = maxf(0.0, children)
	state["elders"] = maxf(0.0, elders)
	state["stats"]["births"] = float(state["stats"]["births"]) + births
	state["stats"]["deaths"] = float(state["stats"]["deaths"]) + deaths
	rep["births"] = births
	rep["deaths"] = deaths
	rep["overcrowding"] = excess / maxf(pop, 1.0)
	if float(rep["shortage_deaths"]) >= 0.5:
		log_msg(state, "Shortages killed %d colonists." % int(round(float(rep["shortage_deaths"]))))


# 10. Morale drifts toward a target set by comfort, shortages and debt.
static func _morale(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var target := float(b["morale_base"]) + float(rep["morale_bonus"])
	var ls: Dictionary = b["life_support"]
	for k in rep["shortages"]:
		target += float(ls[k]["morale"])
	target += float(b["overcrowding_morale"]) * float(rep["overcrowding"])
	target += float(b["morale_per_missed_payment"]) * int(state["missed_in_row"])
	target += Research.add(state, "morale")
	target += float(b["crime_morale"]) * float(state["crime"])
	if state["plague"]["active"]:
		target += float(b["plague_morale"])
	var m := float(state["morale"])
	m += (target - m) * float(b["morale_drift"])
	state["morale"] = clampf(m, 0.0, 100.0)
	rep["morale_target"] = target
	if float(state["morale"]) < float(b["defection_morale"]):
		var lost := float(state["adults"]) * float(b["defection_rate"])
		state["adults"] = float(state["adults"]) - lost
		if lost >= 0.5:
			log_msg(state, "%d colonists walked out to the Company depot." % int(round(lost)))


# 11. Crime grows with population, crowding and low morale; Warden Posts hold it down.
static func _crime(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var pop := population(state)
	var raw := pop * float(b["crime_per_person"]) * (1.5 - float(state["morale"]) / 100.0)
	raw += float(b["crime_overcrowding"]) * float(rep["overcrowding"])
	raw *= Research.mult(state, "crime")
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["active"]:
			raw -= GameData.num(GameData.building(s["type"]), "policing")
	var target := clampf(raw, 0.0, 100.0)
	var crime := float(state["crime"])
	crime += (target - crime) * float(b["crime_drift"])
	state["crime"] = clampf(crime, 0.0, 100.0)
	rep["crime_target"] = target
	if crime > 5.0:
		var stock: Dictionary = state["stock"]
		var stolen := 0.0
		for k in ["alloy", "credits"]:
			var amount := float(stock[k]) * crime * float(b["crime_theft"])
			stock[k] = float(stock[k]) - amount
			stolen += amount
		rep["stolen"] = stolen


# 12. Machines wear out and break down at random.
static func _wear(state: Dictionary) -> void:
	var b := GameData.balance()
	var scale := float(b["wear_scale"]) * Research.mult(state, "wear")
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if not s["active"]:
			continue
		var p := GameData.num(GameData.building(s["type"]), "wear") * scale
		if p > 0.0 and Rng.chance(state, p):
			s["damaged"] = int(b["repair_turns"])
			log_msg(state, "%s has broken down." % GameData.building(s["type"])["name"])


# 13. Plague: an outbreak that Survey Labs must research a cure for in time.
static func _plague(state: Dictionary, rep: Dictionary) -> void:
	var b := GameData.balance()
	var plague: Dictionary = state["plague"]
	var pop := population(state)
	if not plague["active"]:
		if int(state["turn"]) < int(b["plague_start_turn"]) or pop < float(b["plague_min_pop"]):
			return
		if not Rng.chance(state, float(b["plague_chance"]) * Research.mult(state, "plague")):
			return
		var window := int(b["plague_window_clinic"]) if float(rep["health"]) < 1.0 else int(b["plague_window"])
		plague["active"] = true
		plague["turns_left"] = window
		plague["cure"] = 0.0
		plague["need"] = float(b["plague_cure_points"]) * maxf(1.0, round(pop / 100.0))
		log_msg(state, "Plague! Survey Labs must find a cure within %d turns." % window)
		return
	if float(plague["cure"]) >= float(plague["need"]):
		plague["active"] = false
		log_msg(state, "A cure has been found. The plague is over.")
		return
	plague["turns_left"] = int(plague["turns_left"]) - 1
	if int(plague["turns_left"]) <= 0:
		var dead := pop * float(b["plague_final_deaths"]) * float(rep["health"])
		var living := population(state)
		if living > 0.0:
			for k in ["adults", "children", "elders"]:
				state[k] = maxf(0.0, float(state[k]) - dead * float(state[k]) / living)
		state["stats"]["deaths"] = float(state["stats"]["deaths"]) + dead
		plague["active"] = false
		log_msg(state, "The plague ran its course without a cure. %d colonists died." % int(round(dead)))


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


# 14. Company payments.
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
		if population(state) + arriving <= housing:
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


# 15. Timers for storms, vent surges and rest days.
static func _timers(state: Dictionary) -> void:
	for k in ["storm", "surge", "rest"]:
		if int(state[k]) > 0:
			state[k] = int(state[k]) - 1


# 16. Random events. Events with choices pause the game until resolved.
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


# 17. Endings.
static func _endings(state: Dictionary) -> void:
	var b := GameData.balance()
	var ending := ""
	if float(state["debt"]) <= 0.01:
		ending = "free"
	elif int(state["missed_in_row"]) >= int(b["max_missed"]):
		ending = "receivership"
	elif population(state) < 1.0:
		ending = "silent"
	if ending != "":
		state["ending"] = ending
		state["pending_event"] = ""
		log_msg(state, GameData.story()["endings"][ending]["title"] + ".")
