## Headless tests. A script error inside a test stops only that test function,
## so CI also fails the run if Godot prints "SCRIPT ERROR" (see web.yml).
## Run from the repository root:
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
const Research = preload("res://scripts/sim/research.gd")
const TestOnline = preload("res://tests/test_online.gd")
const Manifest = preload("res://scripts/sim/manifest.gd")
const MapGen = preload("res://scripts/sim/map_gen.gd")
const ColonyText = preload("res://scripts/ui/colony_text.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")
const ScoreEntry = preload("res://scripts/net/score_entry.gd")

var checks := 0
var failures := 0



func _init() -> void:
	test_rng()
	test_scripts_load()
	test_data()
	test_new_game()
	test_placement()
	test_determinism()
	test_save_round_trip()
	test_input_rules()
	test_manifest()
	test_difficulty()
	test_story()
	test_deep()
	test_colony_text()
	test_planets_and_sites()
	test_research()
	test_life_stages()
	test_crime()
	test_breakdowns_and_repairs()
	test_plague()
	print("Online (no network)")
	TestOnline.run(check)
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
	check(GameData.building_ids().size() == 19, "19 buildings loaded")
	check(GameData.events().size() == 10, "10 events loaded")
	check(GameData.research_topics().size() == 13, "13 research topics loaded")
	for t in GameData.research_topics():
		for req in t["requires"]:
			check(not GameData.topic(req).is_empty(), "%s requires a real topic (%s)" % [t["id"], req])
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
	var before_demolish := float(s["stock"]["alloy"])
	check(Actions.demolish(s, "2")["ok"] and float(s["stock"]["alloy"]) == before_demolish + 3.0, "demolishing refunds half")


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
	var old: Dictionary = JSON.parse_string(SaveGame.to_text(NewGame.create(4, "Margin")))
	for k in ["planet", "site", "manifest", "kits", "elders", "crime", "plague", "research", "debt_total"]:
		old.erase(k)
	var upgraded: Variant = SaveGame.from_text(JSON.stringify(old))
	check(typeof(upgraded) == TYPE_DICTIONARY and upgraded["planet"] == "brume", "a save from an older version still loads")
	if typeof(upgraded) == TYPE_DICTIONARY:
		Turn.end_turn(upgraded)
		check(int(upgraded["turn"]) == 2, "an older save plays on")


## Loads every script in the game, so a script with an error fails the tests
## even when no test calls into it (the interface scripts especially).
func test_scripts_load() -> void:
	print("Scripts")
	var dirs := ["res://scripts/sim", "res://scripts/ui", "res://scripts/net"]
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var script: Script = load(dir + "/" + file)
			check(script != null and script.can_instantiate(), "%s/%s loads" % [dir.trim_prefix("res://"), file])


func test_colony_text() -> void:
	print("Inspector and report text")
	var s := _colony_with(["vat", "splitter", "drill"])
	s["adults"] = 2.0
	Turn.end_turn(s)
	var reasons: Dictionary = s["report"]["idle_reasons"]
	check(not reasons.is_empty(), "buildings without workers are recorded as idle")
	var any: String = reasons.keys()[0]
	check(reasons[any] == "workers", "the idle reason is the missing workers")
	var st: Dictionary = s["structures"][any]
	check(ColonyText.problem(s, st).begins_with("Idle last turn: not enough free workers"), "the inspector explains why it's idle")
	var text := ColonyText.report(s)
	for part in ["POWER", "STOCK", "PEOPLE", "IDLE OR STARVED", "RESEARCH", "DEBT"]:
		check(text.contains(part), "the report has a %s section" % part)
	check(ColonyText.tile(s, Vector2i(int(st["x"]), int(st["y"]))).contains("Idle last turn"), "the tile text shows the problem")
	check(ColonyText.summary(s).contains("idle"), "the summary points to idle buildings")


func test_input_rules() -> void:
	print("Input cleaning")
	var hostile := {
		"'; DROP TABLE scores; --": "DROP TABLE scores --",
		"1 OR 1=1": "1 OR 11",
		"<script>alert(1)</script>": "scriptalert1script",
		"[color=red]Red[/color]": "colorredRedcolor",
		"[url=https://x.y]click[/url]": "urlhttpsxyclickurl",
		"Bad\u202Ename": "Badname",
		"Zero\u200Bwidth": "Zerowidth",
		"Tab\tand\nnewline": "Tab and newline",
		"  lots    of   space  ": "lots of space",
	}
	for raw in hostile:
		var input: String = str(raw).c_unescape()
		var out := TextRules.clean_name(input, 40)
		check(out == hostile[raw], "name cleaning: %s -> %s" % [JSON.stringify(raw), out])
	check(TextRules.clean_name("x".repeat(500), 16).length() == 16, "names are cut to their maximum length")
	check(TextRules.clean_colony_name("[[[]]]") == TextRules.DEFAULT_COLONY, "a name with nothing usable becomes the default")
	var text := TextRules.clean_text("Hi\u0000 there;\u202E 'quoted' <b>\nline two".c_unescape(), 200, true)
	check(not text.contains("\u0000".c_unescape()) and not text.contains("\u202E".c_unescape()), "free text drops control and bidi characters")
	check(text.contains("'quoted'") and text.contains(";") and text.contains("\n"), "free text keeps punctuation and line breaks as plain text")
	check(not TextRules.clean_text("a\nb".c_unescape(), 20).contains("\n"), "single-line text has no line breaks")
	check(TextRules.escape_bbcode("[url]x[/url]") == "[lb]url]x[lb]/url]", "text shown in rich labels can't open tags")
	var s := NewGame.create(1, "[color=red]<b>Evil</b>'; DROP")
	check(s["colony_name"] == "colorredbEvilb DROP", "a new colony's name is cleaned (%s)" % s["colony_name"])
	var forged: Dictionary = JSON.parse_string(SaveGame.to_text(s))
	forged["colony_name"] = "[img]http://x/a.png[/img]"
	forged["planet"] = "../../etc"
	var loaded: Variant = SaveGame.from_text(JSON.stringify(forged))
	check(typeof(loaded) == TYPE_DICTIONARY and not str(loaded["colony_name"]).contains("[") and loaded["planet"] == "brume", "a tampered save's name and planet are cleaned on load")
	check(not ColonyText.summary(loaded).contains("[img]"), "the summary never shows a typed tag")


func test_difficulty() -> void:
	print("Difficulty")
	check(GameData.difficulties().size() == 3, "3 difficulties loaded")
	var normal := NewGame.create(1, "Margin")
	check(normal["difficulty"] == "normal" and float(normal["debt"]) == 6000.0, "Normal is the default and keeps the 6,000-mark debt")
	var easy := NewGame.create(1, "Margin", {"difficulty": "easy"})
	var hard := NewGame.create(1, "Margin", {"difficulty": "hard"})
	check(float(easy["debt"]) == 4500.0 and float(hard["debt"]) == 7500.0, "Easy and Hard scale the debt (4,500 and 7,500)")
	check(Turn.payment_for(normal, 3) == 180.0 and Turn.payment_for(easy, 3) == 150.0 and Turn.payment_for(hard, 3) == 210.0, "payments grow faster on Hard and slower on Easy")
	check(not NewGame.create(1, "Margin", {"difficulty": "nightmare"})["difficulty"] != "normal", "an unknown difficulty falls back to Normal")
	var old: Dictionary = JSON.parse_string(SaveGame.to_text(normal))
	old.erase("difficulty")
	var loaded: Dictionary = SaveGame.from_text(JSON.stringify(old))
	check(loaded["difficulty"] == "normal", "a save from before difficulty levels loads as Normal")
	var e := ScoreEntry.from_state(hard, "Ari", "")
	check(e["difficulty"] == "hard" and ScoreEntry.problem(e) == "", "scores carry their difficulty")


## Ends turns until a given story event is waiting, answering others with their first non-ending choice.
func _play_until_event(s: Dictionary, id: String, turns: int) -> bool:
	for _i in turns:
		if s["pending_event"] == id:
			return true
		if s["pending_event"] != "":
			var ev := GameData.event(s["pending_event"])
			var choices: Array = ev["choices"]
			for i in choices.size():
				if not (choices[i]["effects"] as Dictionary).has("ending") and Actions.choice_allowed(s, choices[i]):
					Actions.resolve_event(s, i)
					break
		Turn.end_turn(s)
	return s["pending_event"] == id


func test_story() -> void:
	print("Story and factions")
	var known := ["company", "union", "flag", "ending", "morale", "credits", "alloy", "rest", "debt", "adults", "food", "oxygen", "water", "ore"]
	for e in GameData.story_events():
		var has_way_on := false
		for c in e["choices"]:
			var effects: Dictionary = c["effects"]
			for k in effects:
				check(k in known, "%s: effect %s is understood" % [e["id"], k])
			if effects.has("ending"):
				check(GameData.story()["endings"].has(effects["ending"]), "%s: ending %s has text" % [e["id"], effects["ending"]])
			else:
				has_way_on = true
		check(has_way_on, "%s: there is always a choice that doesn't end the game" % e["id"])
	var s := NewGame.create(1, "Margin")
	check(float(s["factions"]["company"]) == 50.0 and float(s["factions"]["union"]) == 50.0, "both factions start at 50")
	check(_play_until_event(s, "first_shift", 6), "the first story event arrives early")
	Actions.resolve_event(s, 0)
	check(float(s["factions"]["union"]) == 60.0, "a choice changes the Union's standing")
	check(s["story_done"].has("first_shift"), "a story event happens once")
	# The Assembly: a strong Union and a weak Company can end the game.
	var a := NewGame.create(2, "Margin")
	a["turn"] = 60
	a["factions"] = {"company": 20.0, "union": 90.0}
	a["story_done"] = []
	for e in GameData.story_events():
		if e["id"] != "assembly":
			a["story_done"].append(e["id"])
	Turn.end_turn(a)
	check(a["pending_event"] == "assembly", "the Assembly comes when the Union is strong and the Company weak")
	Actions.resolve_event(a, 1)
	check(a["ending"] == "independence", "declaring the colony free ends the game as Independence")
	var e2 := ScoreEntry.from_state(a, "Ari", "")
	check(e2["ending"] == "independence" and ScoreEntry.problem(e2) == "", "an Independence score can be posted")
	# A flag set by one choice unlocks a later event.
	var f := NewGame.create(3, "Margin")
	f["turn"] = 36
	f["story_done"] = []
	for e in GameData.story_events():
		if e["id"] != "promise_kept":
			f["story_done"].append(e["id"])
	Turn.end_turn(f)
	check(f["pending_event"] == "", "a follow-up waits for the flag it needs")
	Actions.apply_effects(f, {"flag": "promised_shipments"})
	f["story_cooldown"] = 0
	Turn.end_turn(f)
	check(f["pending_event"] == "promise_kept", "the follow-up comes once the flag is set")
	# Company relations change who comes on the supply drop.
	var p := NewGame.create(4, "Margin")
	p["turn"] = 30
	p["factions"]["company"] = 10.0
	p["story_done"] = GameData.story_events().map(func(x): return x["id"])
	var adults := float(p["adults"])
	Turn.end_turn(p)
	check(int(p["payments_made"]) == 1 and float(p["adults"]) < adults + 3.0, "a Company that dislikes you sends no settlers")
	check(float(p["factions"]["company"]) == 13.0, "paying on time raises Company relations")
	var old: Dictionary = JSON.parse_string(SaveGame.to_text(p))
	for k in ["factions", "flags", "story_done", "story_cooldown"]:
		old.erase(k)
	var loaded: Dictionary = SaveGame.from_text(JSON.stringify(old))
	check(float(loaded["factions"]["union"]) == 50.0 and loaded["story_done"].is_empty(), "a save from before the story loads with neutral factions")


func test_deep() -> void:
	print("The Deep")
	var s := NewGame.create(3, "Margin")
	check(s["deep"].size() == int(s["height"]) and s["deep"][0].size() == int(s["width"]), "the Deep is as big as the surface")
	var again := NewGame.create(3, "Margin")
	check(JSON.stringify(s["deep"]) == JSON.stringify(again["deep"]), "the Deep is the same for the same seed")
	s["stock"]["alloy"] = 500.0
	var hx := int(s["structures"]["1"]["x"])
	var hy := int(s["structures"]["1"]["y"])
	# Find a spot next to the hull with no bedrock below it.
	var spot := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(hx, hy) + d
		if Actions.check_place(s, "shaft", c.x, c.y)["ok"]:
			spot = c
			break
	check(spot.x >= 0, "a shaft can be placed next to the hull")
	if spot.x < 0:
		return
	check(not Actions.check_place(s, "bunk", spot.x + 1, spot.y, 1)["ok"], "nothing can be built in the Deep before a shaft opens")
	Actions.place(s, "shaft", spot.x, spot.y)
	for _i in 3:
		if s["pending_event"] != "":
			Actions.resolve_event(s, 0)
		Turn.end_turn(s)
	var base := Actions.structure_at(s, spot.x, spot.y, 1)
	check(not base.is_empty() and base["type"] == "shaft_base", "a finished shaft opens a landing in the Deep")
	check(Actions.terrain_at(s, spot.x, spot.y, 1) == "cavern", "the landing is dug out")
	check(not Actions.check_place(s, "mirror", spot.x + 1, spot.y, 1)["ok"], "Mirror Fields can't go underground")
	# Build a bunkhouse next to the landing; rock costs more and takes longer.
	var dig := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = spot + d
		if Actions.inside(s, c.x, c.y) and Actions.check_place(s, "bunk", c.x, c.y, 1)["ok"]:
			dig = c
			break
	check(dig.x >= 0, "a bunkhouse can be placed next to the landing")
	if dig.x < 0:
		return
	var rock := Actions.terrain_at(s, dig.x, dig.y, 1) == "rock"
	var alloy := float(s["stock"]["alloy"])
	Actions.place(s, "bunk", dig.x, dig.y, 1)
	var cost := alloy - float(s["stock"]["alloy"])
	check(cost == (12.0 if rock else 8.0), "digging into rock adds 4 alloy (paid %d)" % int(cost))
	var rock_cell := Vector2i(-1, -1)
	for y in int(s["height"]):
		for x in int(s["width"]):
			if rock_cell.x < 0 and Actions.terrain_at(s, x, y, 1) == "rock":
				rock_cell = Vector2i(x, y)
	check(Actions.build_cost(s, "bunk", rock_cell.x, rock_cell.y, 1) == 12.0 and Actions.build_cost(s, "bunk", rock_cell.x, rock_cell.y, 0) == 8.0, "a bunkhouse in rock costs 12 alloy instead of 8")
	var bunk := Actions.structure_at(s, dig.x, dig.y, 1)
	for _i in 6:
		if s["pending_event"] != "":
			Actions.resolve_event(s, 0)
		Turn.end_turn(s)
	check(bunk["built"], "the underground bunkhouse gets built")
	check(Turn.connectivity(s).has(bunk["id"]), "the Deep is joined to the hull through the shaft")
	check(Turn.cold_for(s, bunk) == float(GameData.balance()["deep"]["cold"]), "the Deep has a steady heat factor")
	# Icequakes don't reach underground.
	for _i in 10:
		Actions.apply_effects(s, {"damage_area": 30})
	check(int(bunk["damaged"]) == 0, "icequakes never damage the Deep")
	var loaded: Dictionary = SaveGame.from_text(SaveGame.to_text(s))
	check(not Actions.structure_at(loaded, dig.x, dig.y, 1).is_empty() and Actions.structure_at(loaded, dig.x, dig.y).is_empty() == Actions.structure_at(s, dig.x, dig.y).is_empty(), "levels survive a save")
	check(Actions.demolish(s, base["id"])["ok"] == false, "the landing can't be demolished on its own")
	var shaft := Actions.structure_at(s, spot.x, spot.y)
	Actions.demolish(s, shaft["id"])
	check(Actions.structure_at(s, spot.x, spot.y, 1).is_empty(), "removing the shaft closes its landing")
	var old: Dictionary = JSON.parse_string(SaveGame.to_text(NewGame.create(5, "Margin")))
	old.erase("deep")
	var upgraded: Dictionary = SaveGame.from_text(JSON.stringify(old))
	check(upgraded.has("deep") and upgraded["deep"].size() == int(upgraded["height"]), "a save from before the Deep gets one")


func test_manifest() -> void:
	print("Ship manifest")
	var rec := Manifest.recommended()
	check(Manifest.check(rec)["ok"], "the recommended manifest is valid")
	check(Manifest.bays_used(rec) <= Manifest.bays(), "the recommended manifest fits the hold")
	var s := NewGame.create(1, "Margin")
	check(float(s["adults"]) == 22.0 and float(s["children"]) == 8.0, "the recommended load brings 22 adults and 8 children")
	check(float(s["stock"]["alloy"]) == 80.0 and float(s["stock"]["food"]) == 150.0, "the recommended load brings 80 alloy and 150 food")
	check(float(s["debt"]) == 6000.0 and float(s["debt_total"]) == 6000.0, "the recommended load costs 6,000 marks of debt")
	check(not Manifest.check({"alloy": 99})["ok"], "too many of one item is refused")
	check(not Manifest.check({"berth": 4, "alloy": 4, "rations": 3})["ok"], "more cargo than bays is refused")
	check(not Manifest.check({"gold": 1})["ok"], "unknown cargo is refused")
	var bare := NewGame.create(1, "Margin", {"manifest": {}})
	check(float(bare["debt"]) == float(GameData.cargo()["base_debt"]), "an empty hold costs only the bare ship")
	var kit := NewGame.create(3, "Margin", {"manifest": {"prefab_mirror": 2}})
	var hx := int(kit["structures"]["1"]["x"])
	var hy := int(kit["structures"]["1"]["y"])
	var alloy := float(kit["stock"]["alloy"])
	check(Actions.place(kit, "mirror", hx + 1, hy)["ok"] and float(kit["stock"]["alloy"]) == alloy, "a prefab kit is placed without spending alloy")
	check(int(kit["kits"]["mirror"]) == 1, "placing a kit uses it up")
	var loaded: Dictionary = SaveGame.from_text(SaveGame.to_text(kit))
	check(int(loaded["kits"]["mirror"]) == 1 and loaded["planet"] == "brume", "kits and planet survive a save")


func test_planets_and_sites() -> void:
	print("Planets and landing sites")
	check(GameData.planets().size() == 3, "3 planets loaded")
	for p in GameData.planets():
		for site in GameData.balance()["landing_sites"].size():
			var m := MapGen.generate(11, p["id"], site)
			var hull: Array = m["hull"]
			var tiles: Array = m["tiles"]
			var ok: bool = tiles[int(hull[1])][int(hull[0])] == "regolith"
			check(ok, "%s site %d: the pad is clear" % [p["id"], site])
	var a := MapGen.generate(5, "brume", 0)
	var b := MapGen.generate(5, "brume", 2)
	check(a["hull"] != b["hull"], "landing sites put the hull in different places")
	var dry := 0
	var wet := 0
	var cm := MapGen.generate(4, "cinder", 0)
	var hm := MapGen.generate(4, "hollow", 0)
	for y in cm["tiles"].size():
		for x in cm["tiles"][y].size():
			dry += 1 if cm["tiles"][y][x] == "ice" else 0
			wet += 1 if hm["tiles"][y][x] == "ice" else 0
	check(dry < wet, "Cinder has less ice than Hollow (%d vs %d)" % [dry, wet])
	check(GameData.light_at(16, "cinder") > GameData.light_at(16, "hollow"), "Cinder is brighter than Hollow")
	var s := NewGame.create(2, "Margin", {"planet": "hollow", "site": 1})
	check(s["planet"] == "hollow" and int(s["site"]) == 1, "a new game remembers its planet and site")


## Builds a lab and power next to the hull and finishes construction.
func _colony_with(types: Array) -> Dictionary:
	var s := NewGame.create(3, "Margin")
	s["stock"]["alloy"] = 500.0
	var hx := int(s["structures"]["1"]["x"])
	var hy := int(s["structures"]["1"]["y"])
	var spots := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	var i := 0
	for t in types:
		while i < spots.size() and not Actions.place(s, t, hx + spots[i].x, hy + spots[i].y)["ok"]:
			i += 1
		i += 1
	for id in s["structures"]:
		s["structures"][id]["built"] = true
	return s


func test_research() -> void:
	print("Research")
	var s := _colony_with(["mirror", "mirror", "lab"])
	check(not Actions.set_research(s, "smelting")["ok"], "a topic with unmet prerequisites is refused")
	check(Actions.set_research(s, "coatings")["ok"], "an available topic can be chosen")
	check(Research.mult(s, "out:mirror") == 1.0, "no bonus before the topic is finished")
	for _i in 40:
		if Research.is_done(s, "coatings"):
			break
		if s["pending_event"] != "":
			Actions.resolve_event(s, 0)
		Turn.end_turn(s)
	check(Research.is_done(s, "coatings"), "the lab finishes the topic")
	check(absf(Research.mult(s, "out:mirror") - 1.25) < 1e-9, "the finished topic boosts mirrors by 25%")
	check(Research.is_available(s, "forecasting"), "finishing a topic unlocks the next one")


func test_life_stages() -> void:
	print("Life stages")
	var s := NewGame.create(1, "Margin")
	for _i in 30:
		if s["pending_event"] != "":
			Actions.resolve_event(s, 0)
		Turn.end_turn(s)
	check(float(s["elders"]) > 0.0, "adults age into elders (%.2f)" % float(s["elders"]))
	check(Turn.population(s) == float(s["adults"]) + float(s["children"]) + float(s["elders"]), "population counts all three groups")


func test_crime() -> void:
	print("Crime")
	var s := NewGame.create(1, "Margin")
	s["adults"] = 120.0
	s["morale"] = 20.0
	for _i in 10:
		if s["pending_event"] != "":
			Actions.resolve_event(s, 0)
		Turn.end_turn(s)
	check(float(s["crime"]) > 10.0, "crowding and low morale raise crime (%.1f)" % float(s["crime"]))
	var w := _colony_with(["mirror", "mirror", "warden", "warden"])
	w["adults"] = 60.0
	for _i in 10:
		Turn.end_turn(w)
	check(float(w["crime"]) < 5.0, "warden posts hold crime down (%.1f)" % float(w["crime"]))


func test_breakdowns_and_repairs() -> void:
	print("Breakdowns")
	var s := _colony_with(["mirror", "mirror", "workshop", "drill"])
	Turn.end_turn(s)
	var target := ""
	for id in s["structures"]:
		if s["structures"][id]["type"] == "mirror":
			target = id
			break
	s["structures"][target]["damaged"] = 3
	Turn.end_turn(s)
	check(int(s["structures"][target]["damaged"]) == 1, "a workshop speeds repairs (3 -> 1 in one turn)")
	Actions.apply_effects(s, {"damage_area": 3})
	var hit := 0
	for id in s["structures"]:
		if int(s["structures"][id]["damaged"]) > 0:
			hit += 1
	check(hit >= 1, "an icequake damages nearby buildings (%d)" % hit)


func test_plague() -> void:
	print("Plague")
	var s := _colony_with(["mirror", "mirror", "lab", "lab"])
	s["plague"] = {"active": true, "turns_left": 15, "cure": 0.0, "need": 5.0}
	Actions.set_research(s, "coatings")
	for _i in 8:
		Turn.end_turn(s)
	check(not s["plague"]["active"], "labs cure the plague before it runs its course")
	var u := NewGame.create(1, "Margin")
	u["plague"] = {"active": true, "turns_left": 3, "cure": 0.0, "need": 10.0}
	var before := Turn.population(u)
	for _i in 4:
		if u["pending_event"] != "":
			Actions.resolve_event(u, 0)
		Turn.end_turn(u)
	check(not u["plague"]["active"] and Turn.population(u) < before * 0.92, "an uncured plague kills about a tenth of the colony")


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
	for diff_id in ["easy", "hard"]:
		var dwins := 0
		for seed_value in [1, 2, 3]:
			var s := NewGame.create(seed_value, "Margin", {"difficulty": diff_id})
			play(s, 300, true)
			print("    %s seed %d: turn %d, ending '%s'" % [diff_id, seed_value, int(s["turn"]), s["ending"]])
			if s["ending"] == "free":
				dwins += 1
		check(dwins >= 2, "%s: the bot wins at least 2 of 3 games (%d)" % [diff_id, dwins])
	for planet_id in ["cinder", "hollow"]:
		var wins := 0
		for seed_value in [1, 2, 3]:
			var s := NewGame.create(seed_value, "Margin", {"planet": planet_id})
			play(s, 300, true)
			print("    %s seed %d: turn %d, ending '%s', population %d" % [planet_id, seed_value, int(s["turn"]), s["ending"], int(Turn.population(s))])
			if s["ending"] == "free":
				wins += 1
		check(wins >= 2, "%s: the bot wins at least 2 of 3 games (%d)" % [planet_id, wins])
