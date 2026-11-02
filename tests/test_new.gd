## Headless checks for the second round of new content: Battery Bank, Heat
## Store, Mushroom Farm, Water Recycler, Trading Post and Schoolhouse; the
## Sweeper, Mechanic, Medic and Scout rovers; and the Survey satellite.
## Most checks build two copies of the same colony, one with the new thing and
## one without, and compare them after a turn.
## Called from tests/run_tests.gd:
##   const TestNew = preload("res://tests/test_new.gd")
##   TestNew.run(check)
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")
const TestFleet = preload("res://tests/test_fleet.gd")


static func run(check: Callable) -> void:
	print("Second round: storage, food, water, trade, school, rovers, survey")
	_levels(check)
	_storage(check)
	_mushroom(check)
	_water(check)
	_trade(check)
	_school(check)
	_rovers(check)
	_survey(check)
	_saves(check)


## A colony with plenty of power and heat (a Fusion Core) and everything stocked.
static func _colony() -> Dictionary:
	var s: Dictionary = TestFleet._colony()
	TestFleet._put(s, "fusion")
	for _i in 2:
		TestFleet._put(s, "vent")
	return s


static func _levels(check: Callable) -> void:
	var want := {"battery": "Surface only.", "heatstore": "", "mushroom": "Deep only.", "waterworks": "Deep only.", "market": "Surface only.", "school": "Deep only."}
	for id in want:
		check.call(GameData.level_note(GameData.building(id)) == want[id], "%s goes on the right level" % id)
	for t in ["sweeper", "mechanic", "medic", "scout"]:
		check.call(t in Fleet.drone_order(), "the %s can be built at a Drone Bay" % t)
	check.call("survey" in Fleet.sat_order(), "the Survey satellite can be launched")


static func _storage(check: Callable) -> void:
	var s := _colony()
	var bank := TestFleet._put(s, "battery")
	var store := TestFleet._put(s, "heatstore")
	TestFleet._turn(s)
	var r: Dictionary = s["report"]
	check.call(s["structures"][bank]["active"] and s["structures"][store]["active"], "a Battery Bank and a Heat Store work with no workers")
	check.call(is_equal_approx(float(s["battery"]), clampf(float(r["power_free"]), 0.0, 15.0)), "a Battery Bank saves up to 15 spare power (saved %s)" % s["battery"])
	check.call(is_equal_approx(float(s["heat_bank"]), clampf(float(r["heat_free"]), 0.0, 10.0)), "a Heat Store saves up to 10 spare heat (saved %s)" % s["heat_bank"])
	var saved := float(s["battery"])
	TestFleet._turn(s)
	check.call(is_equal_approx(float(s["report"]["stored_power"]), saved), "saved power is used the next turn")
	# With no bank, nothing is saved.
	var t := _colony()
	TestFleet._turn(t)
	check.call(float(t["battery"]) == 0.0 and float(t["heat_bank"]) == 0.0, "without a bank or store, nothing is saved")


static func _mushroom(check: Callable) -> void:
	var a := _colony()
	var b := _colony()
	var farm := TestFleet._put(b, "mushroom")
	TestFleet._turn(a)
	TestFleet._turn(b)
	check.call(b["structures"][farm]["active"], "a Mushroom Farm runs in the Deep")
	var food := float(b["stock"]["food"]) - float(a["stock"]["food"])
	check.call(food > 4.0, "a Mushroom Farm grows food (%.1f more)" % food)
	check.call(GameData.num(GameData.building("mushroom"), "heat_need") < GameData.num(GameData.building("vat"), "heat_need"), "a Mushroom Farm needs less heat than a Kelp Vat")


static func _water(check: Callable) -> void:
	var a := _colony()
	var b := _colony()
	TestFleet._put(b, "waterworks")
	TestFleet._turn(a)
	TestFleet._turn(b)
	check.call(is_equal_approx(float(b["report"]["water_saving"]), 0.25), "a Water Recycler saves 25% of the water")
	check.call(float(b["stock"]["water"]) > float(a["stock"]["water"]), "with a Water Recycler, less water is used")
	for _i in 2:
		TestFleet._put(b, "waterworks")
	TestFleet._turn(b)
	check.call(is_equal_approx(float(b["report"]["water_saving"]), 0.5), "only two Water Recyclers count")


static func _trade(check: Callable) -> void:
	var a := _colony()
	var b := _colony()
	var post := TestFleet._put(b, "market")
	TestFleet._turn(a)
	TestFleet._turn(b)
	check.call(b["structures"][post]["active"], "a Trading Post runs")
	var m: Dictionary = GameData.balance()["market"]
	var f := 1.0 + float(m["swing"]) * sin(1.0 * TAU / float(m["period"]))
	var expect := 5.0 * (3.0 + 2.0 + 24.0) * f
	var got := float(b["stock"]["credits"]) - float(a["stock"]["credits"])
	check.call(absf(got - expect) < 0.01, "a Trading Post sells 5 each of food, water and parts (earned %.2f, expected %.2f)" % [got, expect])
	# It keeps a reserve: with food below 120, only water and parts are sold.
	b["stock"]["food"] = 100.0
	TestFleet._turn(b)
	var f2 := 1.0 + float(m["swing"]) * sin(2.0 * TAU / float(m["period"]))
	check.call(absf(float(b["report"].get("traded", 0.0)) - 5.0 * (2.0 + 24.0) * f2) < 0.01, "food below the reserve is not sold")
	check.call(Turn.market_factor({"turn": 5}) != Turn.market_factor({"turn": 13}), "prices rise and fall over time")


static func _school(check: Callable) -> void:
	var a := _colony()
	var b := _colony()
	for s in [a, b]:
		s["children"] = 10.0
		s["trained"] = 0.0
	TestFleet._put(b, "school")
	TestFleet._turn(a)
	TestFleet._turn(b)
	check.call(float(b["trained"]) > float(a["trained"]), "children who grow up at a Schoolhouse join as specialists (%.2f vs %.2f)" % [b["trained"], a["trained"]])


static func _with_drone(s: Dictionary, type: String, n: int = 1) -> void:
	TestFleet._put(s, "dronebay")
	s["drones"][type] = n
	s["report"]["drone_slots"] = 4


static func _rovers(check: Callable) -> void:
	# Sweepers keep Solar Arrays clean in a grit storm.
	var a := _colony()
	var b := _colony()
	for s in [a, b]:
		for _i in 3:
			TestFleet._put(s, "mirror")
		s["storm"] = 3
	_with_drone(b, "sweeper")
	TestFleet._put(a, "dronebay")
	a["report"]["drone_slots"] = 4
	TestFleet._turn(a)
	TestFleet._turn(b)
	check.call(float(b["report"]["power_gen"]) > float(a["report"]["power_gen"]), "a Sweeper keeps Solar Arrays working in a storm (%.1f vs %.1f power)" % [b["report"]["power_gen"], a["report"]["power_gen"]])
	# Mechanics speed up a repair.
	var c := _colony()
	var d := _colony()
	var hc := TestFleet._put(c, "workshop")
	var hd := TestFleet._put(d, "workshop")
	c["structures"][hc]["damaged"] = 5
	d["structures"][hd]["damaged"] = 5
	_with_drone(d, "mechanic")
	TestFleet._turn(c)
	TestFleet._turn(d)
	check.call(int(d["structures"][hd]["damaged"]) == int(c["structures"][hc]["damaged"]) - 1, "a Mechanic takes one more turn off a repair")
	# Medics mean fewer deaths, up to a limit.
	var e := _colony()
	_with_drone(e, "medic", 1)
	check.call(is_equal_approx(Fleet.medic_mult(e), 0.9), "one Medic means 10% fewer deaths")
	e["drones"]["medic"] = 4
	check.call(is_equal_approx(Fleet.medic_mult(e), 0.7), "Medics cut deaths by 30% at most")
	# Scouts bring back salvage (made certain here).
	var f := _colony()
	_with_drone(f, "scout")
	var scout: Dictionary = Fleet.drone_def("scout")
	var chance := float(scout["chance"])
	scout["chance"] = 1.0
	var alloy := float(f["stock"]["alloy"])
	TestFleet._turn(f)
	scout["chance"] = chance
	check.call(float(f["stock"]["alloy"]) >= alloy + 8.0 - 0.001, "a Scout can bring back salvage")


static func _survey(check: Callable) -> void:
	var s := _colony()
	check.call(Fleet.survey_mult(s) == 1.0, "no Survey satellite, no bonus")
	s["satellites"]["survey"] = 1
	check.call(is_equal_approx(Fleet.survey_mult(s), 1.1), "a Survey satellite makes cutters and drills 10% better")


static func _saves(check: Callable) -> void:
	var s := _colony()
	TestFleet._put(s, "battery")
	TestFleet._turn(s)
	var back: Variant = SaveGame.from_text(SaveGame.to_text(s))
	check.call(back is Dictionary and is_equal_approx(float(back["battery"]), float(s["battery"])), "saved power survives a save and load")
	var old := s.duplicate(true)
	old.erase("battery")
	old.erase("heat_bank")
	var loaded: Variant = SaveGame.from_text(SaveGame.to_text(old))
	check.call(loaded is Dictionary and float(loaded["battery"]) == 0.0 and float(loaded["heat_bank"]) == 0.0, "older saves load with nothing saved")
