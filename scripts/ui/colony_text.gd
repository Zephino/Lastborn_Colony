## Text for the inspector panel and the Colony report, built from the game
## state. Pure functions with no nodes, so the tests can check them.
## Inspector text uses BBCode (a RichTextLabel); the report is plain text.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Research = preload("res://scripts/sim/research.gd")
const TextRules = preload("res://scripts/sim/text_rules.gd")

const RED := "#ff6a5a"
const AMBER := "#e8b04a"
const TERRAIN_NAMES := {"deepvent": "Deep vent", "vein": "Ore vein", "aquifer": "Aquifer"}
const TERRAIN_HELP := {
	"rock": "Solid rock: building here means digging (+%d alloy, +%d turns).",
	"cavern": "An open cavern: build here at the normal price.",
	"vein": "A rich ore vein: Seam Cutters here cut 50%% more ore.",
	"aquifer": "Underground water: Ice Drills work here.",
	"deepvent": "A deep vent: a Vent Tap here gives 50%% more heat.",
	"bedrock": "Bedrock: nothing can be built here, and no shaft can reach it.",
}
const IDLE_TEXT := {
	"workers": "not enough free workers",
	"power": "not enough power",
	"heat": "not enough heat",
	"marks": "not enough marks to pay its running cost",
}


static func fmt(v: float) -> String:
	return str(int(round(v)))


static func signed(v: float) -> String:
	var n := int(round(v))
	return ("+%d" % n) if n >= 0 else str(n)


## The colony summary shown when no tile is selected.
static func summary(state: Dictionary) -> String:
	var b := GameData.balance()
	var lines := PackedStringArray()
	lines.append("[b]%s[/b], on %s (%s)" % [TextRules.escape_bbcode(str(state["colony_name"])), GameData.planet(state["planet"])["name"], GameData.difficulty(state["difficulty"])["name"]])
	lines.append("Adults %s, children %s, elders %s." % [fmt(float(state["adults"])), fmt(float(state["children"])), fmt(float(state["elders"]))])
	lines.append("Crime %s." % fmt(float(state["crime"])))
	lines.append("Company relations %s, Union %s." % [fmt(float(state["factions"]["company"])), fmt(float(state["factions"]["union"]))])
	if state["plague"]["active"]:
		lines.append("[color=%s]Plague! Cure %d of %d, %d turns left.[/color]" % [RED, int(state["plague"]["cure"]), int(state["plague"]["need"]), int(state["plague"]["turns_left"])])
	lines.append("Production efficiency %d%% (from morale)." % int(round(Turn.efficiency(state) * 100.0)))
	lines.append("Storage %s per resource." % fmt(float(state["report"].get("storage", b["base_storage"]))))
	lines.append("Payments made %d. Missed in a row: %d of %d." % [int(state["payments_made"]), int(state["missed_in_row"]), int(b["max_missed"])])
	if int(state["storm"]) > 0:
		lines.append("[color=%s]Grit front: solar panels weakened for %d more turns.[/color]" % [AMBER, int(state["storm"])])
	if int(state["surge"]) > 0:
		lines.append("[color=%s]Vent surge: %d more turns.[/color]" % [AMBER, int(state["surge"])])
	var idle: Dictionary = state["report"].get("idle_reasons", {})
	if not idle.is_empty():
		lines.append("[color=%s]%d building(s) idle. See the Colony report.[/color]" % [RED, idle.size()])
	lines.append("\nSelect a tile to inspect it.")
	return "\n".join(lines)


## Why a building isn't doing its job, or "" if it is.
static func problem(state: Dictionary, s: Dictionary) -> String:
	var def := GameData.building(s["type"])
	if not s["built"]:
		return ""
	if int(s["damaged"]) > 0:
		return "Damaged: back in %d turns." % int(s["damaged"])
	if def.get("conduit", false):
		return "" if Turn.connectivity(state).has(s["id"]) else "Not connected to the Landing Pad."
	if not Turn.connectivity(state).has(s["id"]):
		return "Not connected to the Landing Pad. Join it to the colony with buildings or heat mains."
	var reasons: Dictionary = state["report"].get("idle_reasons", {})
	if reasons.has(s["id"]):
		var why: String = reasons[s["id"]]
		var fix := {"workers": "Free up workers (fewer buildings) or grow the colony.",
			"power": "Build more Solar Arrays or stop other buildings.",
			"heat": "Build a Vent Tap or a Forge (it gives off heat), or research Insulated Mains.",
			"marks": "Sell more alloy through a Spin Launcher."}
		return "Idle last turn: %s. %s" % [IDLE_TEXT.get(why, why), fix.get(why, "")]
	if state["report"].get("holding", {}).has(s["id"]):
		return "Paused: the colony already holds %d parts. It starts again when parts are used." % int(GameData.num(GameData.building(s["type"]), "max_stock"))
	var starved: Dictionary = state["report"].get("starved", {})
	if starved.has(s["id"]):
		return "Running, but out of %s last turn, so it made nothing." % starved[s["id"]]
	return ""


## The inspector text for a selected tile.
static func tile(state: Dictionary, c: Vector2i, z: int = 0) -> String:
	var planet: String = state["planet"]
	var lines := PackedStringArray()
	var terrain := Actions.terrain_at(state, c.x, c.y, z)
	lines.append("[b]%s[/b]  (%d, %d)%s" % [TERRAIN_NAMES.get(terrain, terrain.capitalize()), c.x, c.y, "  in the Deep" if z == 1 else ""])
	if z == 0:
		lines.append("Light %.2f   Heat factor %.2f" % [GameData.light_at(c.x, planet), GameData.cold_at(c.x, planet)])
	else:
		lines.append("No light   Heat factor %.2f (steady underground)" % float(GameData.balance()["deep"]["cold"]))
	if TERRAIN_HELP.has(terrain):
		var help: String = TERRAIN_HELP[terrain]
		if terrain == "rock":
			var deep: Dictionary = GameData.balance()["deep"]
			help = help % [int(deep["excavate_cost"]), int(deep["excavate_turns"])]
		lines.append(help)
	var s := Actions.structure_at(state, c.x, c.y, z)
	if s.is_empty():
		return "\n".join(lines)
	var def := GameData.building(s["type"])
	lines.append("")
	lines.append("[b][color=#f29e4c]%s[/color][/b]" % def["name"])
	var trouble := problem(state, s)
	if not s["built"]:
		lines.append("Under construction: %d of %d turns." % [int(s["progress"]), int(GameData.num(def, "turns"))])
	elif trouble != "":
		lines.append("[color=%s]%s[/color]" % [RED, trouble])
	elif def.get("conduit", false):
		lines.append("Carrying heat.")
	else:
		lines.append("Running.")
	lines.append(GameData.desc(def))
	var needs := PackedStringArray()
	if GameData.num(def, "workers") > 0.0:
		needs.append("%d workers" % int(GameData.num(def, "workers")))
	if GameData.num(def, "power_use") > 0.0:
		needs.append("%s power" % GameData.num(def, "power_use"))
	if GameData.num(def, "heat_need") > 0.0:
		var hn := GameData.num(def, "heat_need") * Turn.cold_for(state, s) * Research.mult(state, "heat_need")
		needs.append("%.1f heat" % hn)
	var inputs: Dictionary = def.get("inputs", {})
	for k in inputs:
		needs.append("%s %s" % [inputs[k], k])
	if not needs.is_empty():
		lines.append("Uses: " + ", ".join(needs))
	var boost := Research.mult(state, "out:" + str(s["type"]))
	var gives := PackedStringArray()
	if GameData.num(def, "power_gen") > 0.0:
		var pg := GameData.num(def, "power_gen") * boost
		if def.get("solar", false):
			pg *= GameData.light_at(int(s["x"]), planet)
		gives.append("%.1f power" % pg)
	if GameData.num(def, "heat_gen") > 0.0:
		gives.append("%.1f heat" % (GameData.num(def, "heat_gen") * boost))
	var outputs: Dictionary = def.get("outputs", {})
	for k in outputs:
		gives.append("%s %s" % [fmt(float(outputs[k]) * boost), k])
	if GameData.num(def, "housing") > 0.0:
		gives.append("housing %d" % int(GameData.num(def, "housing") + Research.add(state, "housing:" + str(s["type"]))))
	if GameData.num(def, "storage") > 0.0:
		gives.append("storage +%d" % int(GameData.num(def, "storage")))
	if def.has("parts_cost"):
		lines.append("Built with %d alloy and %d parts." % [int(GameData.num(def, "cost")), int(GameData.num(def, "parts_cost"))])
	if GameData.num(def, "upkeep") > 0.0:
		gives.append("costs %d marks a turn" % int(GameData.num(def, "upkeep")))
	if GameData.num(def, "export") > 0.0:
		gives.append("exports up to %d alloy" % int(GameData.num(def, "export") + Research.add(state, "export:" + str(s["type"]))))
	if not gives.is_empty():
		lines.append("Gives: " + ", ".join(gives))
	return "\n".join(lines)


## The Colony report: where everything goes, in plain text.
static func report(state: Dictionary) -> String:
	var b := GameData.balance()
	var r: Dictionary = state["report"]
	var lines := PackedStringArray()
	if r.is_empty():
		return "End a turn to see the colony's first report."
	lines.append("POWER %s of %s free.  HEAT %s of %s free.  WORKERS %d of %d free." % [
		fmt(float(r["power_free"])), fmt(float(r["power_gen"])), fmt(float(r["heat_free"])), fmt(float(r["heat_gen"])),
		int(r["workers_free"]), int(r["workers_total"])])
	var net: Dictionary = r.get("net", {})
	var parts := PackedStringArray()
	for k in ["food", "oxygen", "water", "ore", "alloy", "parts", "credits"]:
		var label: String = "marks" if k == "credits" else str(k)
		parts.append("%s %s (%s)" % [label, fmt(float(state["stock"][k])), signed(float(net.get(k, 0.0)))])
	lines.append("STOCK (change last turn): " + ", ".join(parts))
	var pop := Turn.population(state)
	lines.append("PEOPLE %s, housing %s. Births %.1f, deaths %.1f last turn. Morale %s (heading for %s). Crime %s." % [
		fmt(pop), fmt(float(r["housing"])), float(r.get("births", 0.0)), float(r.get("deaths", 0.0)),
		fmt(float(state["morale"])), fmt(float(r.get("morale_target", state["morale"]))), fmt(float(state["crime"]))])
	var shortages: Dictionary = r.get("shortages", {})
	if not shortages.is_empty():
		lines.append("SHORTAGES: " + ", ".join(PackedStringArray(shortages.keys())) + ". People die when these run out.")
	var idle: Dictionary = r.get("idle_reasons", {})
	var starved: Dictionary = r.get("starved", {})
	if idle.is_empty() and starved.is_empty():
		lines.append("BUILDINGS: everything that can run is running.")
	else:
		var counts := {}
		for id in idle:
			if not state["structures"].has(id):
				continue
			var key := "%s (%s)" % [GameData.building(state["structures"][id]["type"])["name"], IDLE_TEXT.get(idle[id], idle[id])]
			counts[key] = int(counts.get(key, 0)) + 1
		for id in starved:
			if not state["structures"].has(id):
				continue
			var key := "%s (out of %s)" % [GameData.building(state["structures"][id]["type"])["name"], starved[id]]
			counts[key] = int(counts.get(key, 0)) + 1
		var items := PackedStringArray()
		for key in counts:
			items.append("%d × %s" % [int(counts[key]), key])
		lines.append("IDLE OR STARVED: " + ", ".join(items))
	lines.append(fleet_line(state))
	var f: Dictionary = state["factions"]
	var fnotes := PackedStringArray()
	var b2 := GameData.balance()
	if float(f["company"]) >= float(b2["company_good"]):
		fnotes.append("the Company sends extra settlers")
	elif float(f["company"]) <= float(b2["company_bad"]):
		fnotes.append("the Company sends no settlers")
	if float(f["union"]) <= float(b2["union_strike_level"]):
		fnotes.append("the crews are close to striking")
	lines.append("FACTIONS: Company %s, Union %s (out of 100)%s." % [fmt(float(f["company"])), fmt(float(f["union"])), (": " + ", ".join(fnotes)) if not fnotes.is_empty() else ""])
	var research: Dictionary = state["research"]
	if state["plague"]["active"]:
		lines.append("RESEARCH: all labs on the plague cure, %d of %d." % [int(state["plague"]["cure"]), int(state["plague"]["need"])])
	elif research["current"] != "":
		var t := GameData.topic(research["current"])
		lines.append("RESEARCH: %s, %d of %d (%.1f a turn)." % [t["name"], int(research["progress"]), int(t["cost"]), float(r.get("research_points", 0.0))])
	else:
		lines.append("RESEARCH: no topic chosen. %d finished." % research["done"].size())
	var schedule := PackedStringArray()
	var turn := Turn.next_payment_turn(state)
	var amount := Turn.next_payment_amount(state)
	var debt := float(state["debt"])
	var made := int(state["payments_made"])
	for i in 3:
		if debt <= 0.0:
			break
		var a := minf(Turn.payment_for(state, made + i), debt) if i > 0 else amount
		schedule.append("turn %d: %s" % [turn + i * int(b["payment_interval"]), fmt(a)])
		debt -= a
	lines.append("DEBT %s marks. Next payments: %s." % [fmt(float(state["debt"])), ", ".join(schedule)])
	return "\n\n".join(lines)


## One line for the report: drones, satellites, waste and specialists.
static func fleet_line(state: Dictionary) -> String:
	var b := GameData.balance()
	var bits := PackedStringArray()
	var total := Fleet.drones_total(state)
	if total > 0 or Fleet.slots(state) > 0:
		var work: Dictionary = state["report"].get("drones_working", {})
		var busy := 0
		for t in work:
			busy += int(work[t])
		bits.append("%d drones (%d working, %d Drone Bay slots)" % [total, busy, Fleet.slots(state)])
	var up := PackedStringArray()
	for t in Fleet.sat_order():
		if Fleet.sats(state, t) > 0:
			up.append("%d %s" % [Fleet.sats(state, t), str(Fleet.sat_def(t)["name"]).to_lower()])
	if not up.is_empty():
		bits.append("in orbit: " + ", ".join(up))
	var waste_note := "waste %s" % fmt(float(state["waste"]))
	if Fleet.waste_morale(state) > 0.0:
		waste_note += " (morale -%s; build a Reclaimer)" % fmt(Fleet.waste_morale(state))
	bits.append(waste_note)
	if float(state["trained"]) > 0.0:
		bits.append("%s specialists (+%d%% industry and research)" % [fmt(float(state["trained"])), int(round((Fleet.trained_mult(state, "forge") - 1.0) * 100.0))])
	if int(state["pods"]) > 0:
		bits.append("%d supply pods aboard the ship" % int(state["pods"]))
	return "COLONY SYSTEMS: " + "; ".join(bits) + "."


## The Drones & Orbit dialog's text.
static func fleet_summary(state: Dictionary) -> String:
	var lines := PackedStringArray()
	if Fleet.slots(state) > 0:
		lines.append("Your working Drone Bays control %d drones; any more sit idle. Drones work in this order: Graders, Borers, Prospectors, Haulers." % Fleet.slots(state))
	else:
		lines.append("Drones need a working Drone Bay (Industry). Each one controls 4 drones.")
	lines.append("Satellites are launched from a working Spin Launcher. Parts come from a Fab Shop. You have %d alloy, %d parts and %d marks." % [int(state["stock"]["alloy"]), int(state["stock"]["parts"]), int(state["stock"]["credits"])])
	lines.append(fleet_line(state).trim_prefix("COLONY SYSTEMS: "))
	return "\n\n".join(lines)
