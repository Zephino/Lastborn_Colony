## Headless tests. Run from the repository root:
##   godot --headless --script res://tests/run_tests.gd
## Exits with code 0 when everything passes, 1 otherwise.
extends SceneTree

const GameData = preload("res://scripts/sim/game_data.gd")
const Rng = preload("res://scripts/sim/rng.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const SaveGame = preload("res://scripts/sim/save_game.gd")
const Bot = preload("res://tests/bot.gd")

var checks := 0
var failures := 0


func _init() -> void:
	test_rng()
	test_data()
	test_new_game()
	test_placement()
	test_determinism()
	test_save_round_trip()
	test_idle_colony_fails()
	test_bot_colonies()
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func play(state: Dictionary, turns: int, use_bot: bool) -> void:
	for _i in turns:
		if state["ending"] != "":
			return
		if use_bot:
			Bot.act(state)
		elif state["pending_event"] != "":
			Actions.resolve_event(state, 0)
		Turn.end_turn(state)


func test_rng() -> void:
	print("RNG")
	var s := {"rng": 12345}
	var expected := [0.9797282677609473, 0.3067522644996643, 0.484205421525985]
	for i in expected.size():
		var v := Rng.next_float(s)
		check(absf(v - float(expected[i])) < 1e-15, "mulberry32 value %d = %s" % [i, v])
	check(Rng.hash_seed("Lastborn Colony") == 1978485852, "FNV-1a hash of 'Lastborn Colony'")


func test_data() -> void:
	print("Data")
	check(GameData.building_ids().size() == 14, "14 buildings loaded")
	check(GameData.events().size() == 9, "9 events loaded")
	check(GameData.light_at(0) < GameData.light_at(31), "light rises toward the day side")
	check(GameData.cold_at(0) > GameData.cold_at(31), "heat need falls toward the day side")
	for id in GameData.building_ids():
		var def := GameData.building(id)
		check(def.has("name") and def.has("terrain") and def.has("priority"), "%s has name, terrain and priority" % id)


func test_new_game() -> void:
	print("New game")
	var s := NewGame.create(1, "Margin")
	check(s["structures"].size() == 1, "starts with only the hull")
	check(int(s["turn"]) == 1, "starts on turn 1")
	var hull: Dictionary = s["structures"]["1"]
	check(hull["type"] == "hull" and hull["built"], "hull is built")
	var found := {"ice": false, "vent": false, "seam": false}
	for y in int(s["height"]):
		for x in int(s["width"]):
			var t: String = s["tiles"][y][x]
			if found.has(t) and absi(x - int(hull["x"])) + absi(y - int(hull["y"])) <= 9:
				found[t] = true
	for t in found:
		check(found[t], "%s near the landing site" % t)


func test_placement() -> void:
	print("Placement")
	var s := NewGame.create(3, "Margin")
	var hx := int(s["structures"]["1"]["x"])
	var hy := int(s["structures"]["1"]["y"])
	check(Actions.check_place(s, "mirror", hx + 1, hy)["ok"], "mirror next to the hull is allowed")
	check(not Actions.check_place(s, "mirror", hx + 4, hy)["ok"], "mirror away from the colony is refused")
	check(not Actions.check_place(s, "drill", hx + 1, hy)["ok"], "drill on regolith is refused")
	check(not Actions.check_place(s, "hull", hx + 1, hy)["ok"], "a second hull is refused")
	var before := float(s["stock"]["alloy"])
	check(Actions.place(s, "mirror", hx + 1, hy)["ok"], "mirror placed")
	check(float(s["stock"]["alloy"]) == before - 6.0, "mirror cost 6 alloy")
	check(not Actions.check_place(s, "mirror", hx + 1, hy)["ok"], "occupied tile is refused")
	Turn.end_turn(s)
	Turn.end_turn(s)
	check(s["structures"]["2"]["built"], "mirror finished after 2 turns")
	check(Actions.demolish(s, "2")["ok"] and float(s["stock"]["alloy"]) == before - 3.0, "demolishing refunds half")


func test_determinism() -> void:
	print("Determinism")
	var a := NewGame.create(5, "Margin")
	var b := NewGame.create(5, "Margin")
	play(a, 60, true)
	play(b, 60, true)
	check(SaveGame.to_text(a) == SaveGame.to_text(b), "same seed and actions give the same game")


func test_save_round_trip() -> void:
	print("Saves")
	var a := NewGame.create(2, "Margin")
	play(a, 40, true)
	var loaded: Variant = SaveGame.from_text(SaveGame.to_text(a))
	check(typeof(loaded) == TYPE_DICTIONARY, "save loads")
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var b: Dictionary = loaded
	play(a, 30, true)
	play(b, 30, true)
	check(SaveGame.to_text(a) == SaveGame.to_text(b), "a loaded game plays on identically")
	check(typeof(SaveGame.from_text("{}")) == TYPE_STRING, "junk is rejected")


func test_idle_colony_fails() -> void:
	print("Idle colony")
	var s := NewGame.create(1, "Margin")
	play(s, 150, false)
	check(s["ending"] == "silent" or s["ending"] == "receivership", "a colony that builds nothing does not survive (%s, turn %d)" % [s["ending"], int(s["turn"])])


func test_bot_colonies() -> void:
	print("Scripted colonies (300 turns max)")
	for seed_value in [1, 2, 3]:
		var s := NewGame.create(seed_value, "Margin")
		play(s, 300, true)
		var pop := float(s["adults"]) + float(s["children"])
		print("    seed %d: turn %d, ending '%s', population %d, debt %d, structures %d" % [seed_value, int(s["turn"]), s["ending"], int(pop), int(s["debt"]), s["structures"].size()])
		check(s["ending"] == "free", "seed %d: the bot buys out the charter" % seed_value)
