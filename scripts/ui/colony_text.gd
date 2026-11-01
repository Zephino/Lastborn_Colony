## Text for the inspector panel and the Colony report, built from the game
## state. Pure functions with no nodes, so the tests can check them.
## Inspector text uses BBCode (a RichTextLabel); the report is plain text.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Research = preload("res://scripts/sim/research.gd")

const RED := "#ff6a5a"
const AMBER := "#e8b04a"
const IDLE_TEXT := {
	"workers": "not enough free workers",
	"power": "not enough power",
	"heat": "not enough heat",
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
	lines.append("[b]%s[/b], on %s" % [state["colony_name"], GameData.planet(state["planet"])["name"]])
	lines.append("Adults %s, children %s, elders %s." % [fmt(float(state["adults"])), fmt(float(state["children"])), fmt(float(state["elders"]))])
	lines.append("Crime %s." % fmt(float(state["crime"])))
	if state["plague"]["active"]:
		lines.append("[color=%s]Plague! Cure %d of %d, %d turns left.[/color]" % [RED, int(state["plague"]["cure"]), int(state["plague"]["need"]), int(state["plague"]["turns_left"])])
	lines.append("Production efficiency %d%% (from morale)." % int(round(Turn.efficiency(state) * 100.0)))
	lines.append("Storage %s per resource." % fmt(float(state["report"].get("storage", b["base_storage"]))))
	lines.append("Payments made %d. Missed in a row: %d of %d." % [int(state["payments_made"]), int(state["missed_in_row"]), int(b["max_missed"])])
	if int(state["storm"]) > 0:
		lines.append("[color=%s]Grit front: mirrors weakened for %d more turns.[/color]" % [AMBER, int(state["storm"])])
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
		return "" if Turn.connectivity(state).has(s["id"]) else "Not connected to the hull."
	if not Turn.connectivity(state).has(s["id"]):
		return "Not connected to the hull. Join it to the colony with buildings or heat mains."
	var reasons: Dictionary = state["report"].get("idle_reasons", {})
	if reasons.has(s["id"]):
		var why: String = reasons[s["id"]]
		var fix := {"workers": "Free up workers (fewer buildings) or grow the colony.",
			"power": "Build more Mirror Fields or stop other buildings.",
			"heat": "Build a Vent Tap or a Forge (it gives off heat), or research Insulated Mains."}
		return "Idle last turn: %s. %s" % [IDLE_TEXT.get(why, why), fix.get(why, "")]
	var starved: Dictionary = state["report"].get("starved", {})
	if starved.has(s["id"]):
		return "Running, but out of %s last turn, so it made nothing." % starved[s["id"]]
	return ""


## The inspector text for a selected tile.
static func tile(state: Dictionary, c: Vector2i) -> String:
	var planet: String = state["planet"]
	var lines := PackedStringArray()
	var terrain := Actions.terrain_at(state, c.x, c.y)
	lines.append("[b]%s[/b]  (%d, %d)" % [terrain.capitalize(), c.x, c.y])
	lines.append("Light %.2f   Heat factor %.2f" % [GameData.light_at(c.x, planet), GameData.cold_at(c.x, planet)])
	var s := Actions.structure_at(state, c.x, c.y)
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
	lines.append(def["desc"])
	var needs := PackedStringArray()
	if GameData.num(def, "workers") > 0.0:
		needs.append("%d workers" % int(GameData.num(def, "workers")))
	if GameData.num(def, "power_use") > 0.0:
		needs.append("%s power" % GameData.num(def, "power_use"))
	if GameData.num(def, "heat_need") > 0.0:
		var hn := GameData.num(def, "heat_need") * GameData.cold_at(int(s["x"]), planet) * Research.mult(state, "heat_need")
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
	for k in ["food", "oxygen", "water", "ore", "alloy", "credits"]:
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
		var a := minf(float(b["payment_base"]) + float(b["payment_step"]) * (made + i), debt) if i > 0 else amount
		schedule.append("turn %d: %s" % [turn + i * int(b["payment_interval"]), fmt(a)])
		debt -= a
	lines.append("DEBT %s marks. Next payments: %s." % [fmt(float(state["debt"])), ", ".join(schedule)])
	return "\n\n".join(lines)
