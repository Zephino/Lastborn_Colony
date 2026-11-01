## Headless checks for the buildings, drones, satellites and systems added
## together: Fab Shop parts, research-locked buildings, Drone Bay drones,
## satellites, supply pods, waste and Reclaimers, Academy specialists, the
## Lounge's running cost, Signal Masts, Rescue Stations and Beam Catchers.
## Called from tests/run_tests.gd:
##   const TestFleet = preload("res://tests/test_fleet.gd")
##   TestFleet.run(check)
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")
const Manifest = preload("res://scripts/sim/manifest.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func run(check: Callable) -> void:
	print("New buildings, drones and satellites")
	_data(check)
	_parts_and_research(check)
	_drones(check)
	_satellites_and_pods(check)
	_waste_and_training(check)
	_civic(check)
	_saves(check)


## A fresh colony with plenty of everything, and no random events.
static func _colony(seed_value: int = 5) -> Dictionary:
	var s := NewGame.create(seed_value, "Margin")
	# Below the 300 storage cap, so nothing is lost to it.
	for k in ["alloy", "parts", "food", "oxygen", "water"]:
		s["stock"][k] = 250.0
	s["stock"]["credits"] = 1000.0
	s["adults"] = 60.0
	return s


## Puts a finished building of this type on the first free tile next to the
## colony where its terrain allows (no cost), and returns its id.
static func _put(s: Dictionary, type: String) -> String:
	var def := GameData.building(type)
	for y in int(s["height"]):
		for x in int(s["width"]):
			if not Actions.structure_at(s, x, y).is_empty() or not Actions.touches_colony(s, x, y):
				continue
			if Actions.terrain_at(s, x, y) in def["terrain"]:
				return NewGame.add_structure(s, type, x, y, true)
	return ""


## Ends a turn with events held back, so results don't depend on luck.
static func _turn(s: Dictionary) -> void:
	s["story_done"] = GameData.story_events().map(func(e: Dictionary) -> String: return e["id"])
	var saved := float(GameData.balance()["event_chance"])
	GameData.balance()["event_chance"] = 0.0
	Turn.end_turn(s)
	GameData.balance()["event_chance"] = saved


static func _data(check: Callable) -> void:
	for id in GameData.building_ids():
		var def := GameData.building(id)
		if def.has("requires_research"):
			check.call(not GameData.topic(def["requires_research"]).is_empty(), "%s needs a real research topic" % id)
	for t in Fleet.drone_order():
		check.call(not Fleet.drone_def(t).is_empty(), "drone %s is defined" % t)
	for t in Fleet.sat_order():
		check.call(not Fleet.sat_def(t).is_empty(), "satellite %s is defined" % t)
	check.call("parts" in GameData.balance()["stored_resources"], "parts are a stored resource")


static func _parts_and_research(check: Callable) -> void:
	var s := _colony()
	var fab := _put(s, "fab")
	for _i in 3:
		_put(s, "mirror")
	_turn(s)
	check.call(s["structures"][fab]["active"], "a Fab Shop runs")
	check.call(float(s["report"]["net"]["parts"]) > 0.0, "a Fab Shop makes parts (%s)" % s["report"]["net"]["parts"])
	var spot := Vector2i(-1, -1)
	for y in int(s["height"]):
		for x in int(s["width"]):
			if spot.x < 0 and Actions.structure_at(s, x, y).is_empty() and Actions.touches_colony(s, x, y) and Actions.terrain_at(s, x, y) == "regolith":
				spot = Vector2i(x, y)
	var r: Dictionary = Actions.check_place(s, "fusion", spot.x, spot.y)
	check.call(not r["ok"] and str(r["reason"]).contains("Contained Fusion"), "a Fusion Core needs its research first")
	s["research"]["done"].append("fusion")
	s["stock"]["parts"] = 5.0
	r = Actions.check_place(s, "fusion", spot.x, spot.y)
	check.call(not r["ok"] and str(r["reason"]).contains("parts"), "a Fusion Core needs 12 parts")
	s["stock"]["parts"] = 20.0
	var alloy := float(s["stock"]["alloy"])
	check.call(Actions.place(s, "fusion", spot.x, spot.y)["ok"], "with the research and parts, a Fusion Core can be built")
	check.call(float(s["stock"]["parts"]) == 8.0 and float(s["stock"]["alloy"]) == alloy - 40.0, "it costs 40 alloy and 12 parts")
	var id: String = Actions.structure_at(s, spot.x, spot.y)["id"]
	check.call(Actions.demolish(s, id)["ok"] and float(s["stock"]["parts"]) == 20.0, "demolishing an unfinished building returns its parts")


static func _drones(check: Callable) -> void:
	var s := _colony()
	var r := Actions.build_drone(s, "grader")
	check.call(not r["ok"] and str(r["reason"]).contains("Drone Bay"), "drones need a Drone Bay")
	_put(s, "dronebay")
	_turn(s)
	check.call(int(s["report"]["drone_slots"]) == 4, "a working Drone Bay controls 4 drones")
	var parts := float(s["stock"]["parts"])
	check.call(Actions.build_drone(s, "grader")["ok"] and Fleet.owned(s, "grader") == 1, "a Grader can be built")
	check.call(float(s["stock"]["parts"]) == parts - 3.0, "a Grader costs 3 parts")
	# A Grader adds a turn of progress to a surface building.
	var spot := _free_regolith(s)
	Actions.place(s, "commons", spot.x, spot.y)
	var commons := Actions.structure_at(s, spot.x, spot.y)
	_turn(s)
	check.call(int(commons["progress"]) == 2, "a Grader speeds up construction (progress %d after one turn)" % int(commons["progress"]))
	# Prospectors bring in ore.
	for _i in 3:
		Actions.build_drone(s, "prospector")
	var work := Fleet.working(s)
	check.call(int(work["grader"]) == 1 and int(work["prospector"]) == 3, "drones fill the free slots in order")
	Actions.build_drone(s, "prospector")
	check.call(int(Fleet.working(s)["prospector"]) == 3, "drones beyond the Drone Bay's slots sit idle")
	var ore := float(s["stock"]["ore"])
	_turn(s)
	check.call(float(s["stock"]["ore"]) >= ore + 6.0, "working Prospectors bring in 2 ore each")
	# A Borer waives the extra cost of digging into rock.
	var before := Actions.build_cost(s, "bunk", 0, 0, 1)
	s["deep"][0][0] = "rock"
	var dig := Actions.build_cost(s, "bunk", 0, 0, 1)
	s["drones"]["borer"] = 1
	check.call(dig == 12.0 and Actions.build_cost(s, "bunk", 0, 0, 1) == 8.0 and before > 0.0, "owning a Borer makes digging into rock cost nothing extra")
	s["research"]["done"].append("drone_swarms")
	_turn(s)
	check.call(int(s["report"]["drone_slots"]) == 6, "Drone Swarms research adds 2 slots per Drone Bay")


static func _free_regolith(s: Dictionary) -> Vector2i:
	for y in int(s["height"]):
		for x in int(s["width"]):
			if Actions.structure_at(s, x, y).is_empty() and Actions.touches_colony(s, x, y) and Actions.terrain_at(s, x, y) == "regolith":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _satellites_and_pods(check: Callable) -> void:
	var s := _colony()
	var r := Actions.launch_satellite(s, "relay")
	check.call(not r["ok"] and str(r["reason"]).contains("Launch Rail"), "satellites need a working Launch Rail")
	_put(s, "rail")
	for _i in 2:
		_put(s, "mirror")
	_turn(s)
	check.call(Actions.launch_satellite(s, "relay")["ok"] and Fleet.sats(s, "relay") == 1, "a relay satellite can be launched")
	check.call(not Actions.launch_satellite(s, "relay")["ok"], "only one relay satellite helps")
	check.call(Fleet.sat_morale(s) == 3.0, "a relay satellite gives morale +3")
	r = Actions.launch_satellite(s, "power")
	check.call(not r["ok"] and str(r["reason"]).contains("Power Beaming"), "power satellites need Power Beaming")
	# Beam Catchers turn power satellites into power.
	s["research"]["done"].append("beaming")
	check.call(Actions.launch_satellite(s, "power")["ok"], "a power satellite can be launched after Power Beaming")
	_turn(s)
	var gen := float(s["report"]["power_gen"])
	var catcher := _put(s, "catcher")
	_turn(s)
	check.call(s["structures"][catcher]["active"] and float(s["report"]["power_gen"]) >= gen + 9.9, "a Beam Catcher gives 10 power per satellite")
	# Supply pods.
	var m := Manifest.recommended()
	m.erase("water")
	m["pod"] = 1
	var p := NewGame.create(5, "Margin", {"manifest": m})
	check.call(int(p["pods"]) == 1, "a supply pod can be packed")
	var alloy := float(p["stock"]["alloy"])
	check.call(Actions.call_pod(p)["ok"] and float(p["stock"]["alloy"]) == alloy + 50.0, "calling a pod down brings 50 alloy")
	check.call(not Actions.call_pod(p)["ok"], "a pod can be called only once")


static func _waste_and_training(check: Callable) -> void:
	var s := _colony()
	s["waste"] = 100.0
	check.call(Fleet.waste_morale(s) == 6.0, "waste over 40 lowers morale (60 over: -6)")
	check.call(Fleet.waste_plague(s) == 1.5, "lots of waste makes plague more likely")
	var rec := _put(s, "reclaimer")
	for _i in 2:
		_put(s, "mirror")
	var ore := float(s["stock"]["ore"])
	_turn(s)
	check.call(s["structures"][rec]["active"] and float(s["stock"]["ore"]) > ore, "a Reclaimer recovers ore from waste")
	check.call(float(s["waste"]) < 100.0, "a Reclaimer brings waste down (%s)" % s["waste"])
	var t := _colony()
	var academy := _put(t, "academy")
	for _i in 2:
		_put(t, "mirror")
	_turn(t)
	_turn(t)
	check.call(t["structures"][academy]["active"] and float(t["trained"]) > 0.0, "an Academy trains specialists")
	t["trained"] = 1000.0
	_turn(t)
	check.call(float(t["trained"]) <= float(t["adults"]) * 0.3 + 0.001, "specialists are capped at 30% of adults")
	check.call(absf(Fleet.trained_mult(t, "forge") - 1.15) < 0.001 and Fleet.trained_mult(t, "bunk") == 1.0, "specialists add up to 15% to industry and labs only")


static func _civic(check: Callable) -> void:
	var s := _colony()
	var lounge := _put(s, "lounge")
	var mast := _put(s, "mast")
	for _i in 2:
		_put(s, "mirror")
	var credits := float(s["stock"]["credits"])
	_turn(s)
	check.call(s["structures"][lounge]["active"], "a Lounge runs while it can be paid for")
	check.call(float(s["stock"]["credits"]) <= credits - 3.0, "a Lounge costs 3 marks a turn")
	check.call(s["structures"][mast]["active"] and float(s["report"]["trade_bonus"]) == 1.0, "a Signal Mast adds 1 mark to the alloy price")
	s["stock"]["credits"] = 0.0
	_turn(s)
	check.call(not s["structures"][lounge]["active"] and s["report"]["idle_reasons"].get(lounge, "") == "marks", "with no marks, the Lounge closes")
	var r := _colony()
	_put(r, "rescue")
	_turn(r)
	check.call(Fleet.shelter(r) == 0.5, "a working Rescue Station halves disaster damage")


static func _saves(check: Callable) -> void:
	var s := _colony()
	s["drones"]["hauler"] = 2
	s["satellites"]["weather"] = 1
	s["pods"] = 1
	s["waste"] = 12.5
	_turn(s)
	var loaded: Variant = SaveGame.from_text(SaveGame.to_text(s))
	check.call(typeof(loaded) == TYPE_DICTIONARY and Fleet.owned(loaded, "hauler") == 2 and Fleet.sats(loaded, "weather") == 1 and int(loaded["pods"]) == 1, "drones, satellites and pods survive a save")
	var old := SaveGame.to_text(s)
	var d: Dictionary = JSON.parse_string(old)
	for k in ["drones", "satellites", "pods", "waste", "trained"]:
		d.erase(k)
	(d["stock"] as Dictionary).erase("parts")
	var upgraded: Variant = SaveGame.from_text(JSON.stringify(d))
	check.call(typeof(upgraded) == TYPE_DICTIONARY and float(upgraded["stock"]["parts"]) == 0.0 and Fleet.drones_total(upgraded) == 0, "a save from before drones and parts still loads")
	if typeof(upgraded) == TYPE_DICTIONARY:
		Turn.end_turn(upgraded)
		check.call(int(upgraded["turn"]) == int(s["turn"]) + 1, "and plays on")
