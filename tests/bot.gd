## A scripted player used by the tests: builds whatever the colony is short of,
## keeps an alloy reserve once it can export, and pays the debt down early.
## It is deliberately simple; a good human player should beat it.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")
const Research = preload("res://scripts/sim/research.gd")
const Turn = preload("res://scripts/sim/turn.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")

## When true, the bot also uses the newer content (parts, drones, satellites,
## Fusion Core, Academy, Signal Mast, Rescue Station, Lounge), for balance checks.
static var advanced := false
## In advanced mode, which extras to use (all by default); the balance tool tries them one at a time.
static var only := ""
const ADVANCED_TOPICS := ["drone_swarms", "beaming", "fusion"]

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MUST_AFFORD := ["mirror", "splitter", "drill", "vat", "rail"]
const CASH_BUFFER := 1200.0
const BUILD_RESERVE := 40.0
const SAVING_RESERVE := 0.0
const ESSENTIAL := ["mirror", "vent", "splitter", "drill", "vat", "bunk", "cutter", "forge", "rail", "lab", "warden"]
## Research order the bot prefers; anything else available comes after.
const TOPIC_ORDER := ["seals", "seam_mapping", "smelting", "mag_rail", "insulation", "coatings", "kelp", "field_medicine", "commons_charter"]


## Plays one turn's worth of decisions (does not end the turn).
static func act(state: Dictionary) -> void:
	if state["pending_event"] != "":
		var ev := GameData.event(state["pending_event"])
		var choices: Array = ev["choices"]
		for i in choices.size():
			# The bot plays for a Free Charter: it never takes a story ending.
			if (choices[i].get("effects", {}) as Dictionary).has("ending"):
				continue
			if Actions.choice_allowed(state, choices[i]):
				Actions.resolve_event(state, i)
				break
	# Spin Launchers sell alloy above the reserve. While the next payment is not covered,
	# keep the reserve low so alloy is sold, and build only essentials.
	var saving := _saving(state)
	Actions.set_export_reserve(state, SAVING_RESERVE if saving else BUILD_RESERVE)
	if state["research"]["current"] == "":
		var options := Research.available(state)
		if not options.is_empty():
			var pick: String = options[0]["id"]
			var order: Array = TOPIC_ORDER.duplicate()
			if advanced:
				order.append_array(ADVANCED_TOPICS)
			for id in order:
				if Research.is_available(state, id):
					pick = id
					break
			Actions.set_research(state, pick)
	var credits := float(state["stock"]["credits"])
	if credits > CASH_BUFFER:
		Actions.pay_extra(state, credits - CASH_BUFFER)
	if advanced:
		_advanced_extras(state)
	# Try the wanted buildings in order until one can actually be placed.
	for choice in _choose(state):
		if _build(state, choice):
			break


static func _saving(state: Dictionary) -> bool:
	if _count(state, "rail") == 0:
		return false
	return float(state["stock"]["credits"]) < Turn.next_payment_amount(state) * 1.5


static func _count(state: Dictionary, type: String) -> int:
	var n := 0
	for id in state["structures"]:
		if state["structures"][id]["type"] == type:
			n += 1
	return n


## Returns the buildings worth trying this turn, most urgent first.
static func _choose(state: Dictionary) -> Array:
	var alloy := float(state["stock"]["alloy"])
	var picks: Array = []
	if alloy < 1.0:
		return picks
	var turn := int(state["turn"])
	var pop := Turn.population(state)
	var rep: Dictionary = state["report"]
	var want: Array = []
	if float(rep.get("power_free", 0.0)) < 3.0 or (int(rep.get("idle", 0)) > 0 and float(rep.get("power_free", 0.0)) < 6.0):
		want.append("mirror")
	if float(rep.get("heat_free", 0.0)) < 2.0 or (int(rep.get("idle", 0)) > 0 and float(rep.get("heat_free", 0.0)) < 3.0):
		want.append("vent")
	var splitters := ceili(pop * 0.11 / 5.0)
	var vats := ceili(pop * 0.11 / 6.0)
	if _count(state, "splitter") < splitters:
		want.append("splitter")
	if _count(state, "drill") < ceili((2.0 * (splitters + vats) + pop * 0.06) / 5.5):
		want.append("drill")
	if _count(state, "vat") < vats:
		want.append("vat")
	if pop > float(rep.get("housing", 40.0)) - 6.0 and _count(state, "bunk") * 12 + 40 < pop + 30.0:
		want.append("bunk")
	var forges := mini(10, 1 + int(pop / 20.0))
	# Ore and a forge first: a rail with no alloy to sell earns nothing.
	if _count(state, "cutter") < 1:
		want.append("cutter")
	if _count(state, "forge") < 1:
		want.append("forge")
	if _count(state, "forge") >= 1 and _count(state, "rail") < ceili(forges * 3.0 / 4.0):
		want.append("rail")
	if _count(state, "cutter") < ceili(forges * 4.0 / 5.0):
		want.append("cutter")
	if _count(state, "forge") < forges:
		want.append("forge")
	if float(state["crime"]) > 8.0 and _count(state, "warden") < 1 + int(pop / 60.0):
		want.append("warden")
	if (state["plague"]["active"] or turn > 30) and _count(state, "lab") < 1 + int(pop / 100.0):
		want.append("lab")
	if turn > 40 and _count(state, "workshop") < 1:
		want.append("workshop")
	if float(state.get("waste", 0.0)) > 40.0 and _count(state, "reclaimer") < 1 + int(pop / 80.0):
		want.append("reclaimer")
	if float(state["morale"]) < 50.0 and _count(state, "commons") < 3 and turn > 15:
		want.append("commons")
	if turn > 40 and _count(state, "clinic") < 1:
		want.append("clinic")
	var cap := float(rep.get("storage", 300.0))
	for k in GameData.balance()["stored_resources"]:
		if float(state["stock"][k]) > cap * 0.9 and _count(state, "cache") < 4:
			want.append("cache")
			break
	if advanced:
		_advanced_wants(state, want, turn, pop)
	var saving := _saving(state)
	for w in want:
		if saving and not (w in ESSENTIAL):
			continue
		if alloy >= GameData.num(GameData.building(w), "cost"):
			picks.append(w)
		elif w in MUST_AFFORD:
			break
	return picks


## Builds the type at the best adjacent site, or lays a heat main toward the
## nearest tile it needs (ice, vent or seam) if none is in reach.
static func _build(state: Dictionary, type: String) -> bool:
	var site := _best_site(state, type)
	if site.x >= 0:
		return Actions.place(state, type, site.x, site.y)["ok"]
	var terrain: Array = GameData.building(type)["terrain"]
	var step := _step_toward(state, terrain)
	if step.x >= 0:
		return Actions.place(state, "main", step.x, step.y)["ok"]
	return false


static func _hull(state: Dictionary) -> Vector2i:
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["type"] == "hull":
			return Vector2i(int(s["x"]), int(s["y"]))
	return Vector2i.ZERO


static func _best_site(state: Dictionary, type: String) -> Vector2i:
	var hull := _hull(state)
	var best := Vector2i(-1, -1)
	var best_score := INF
	for y in int(state["height"]):
		for x in int(state["width"]):
			if not Actions.check_place(state, type, x, y)["ok"]:
				continue
			var score := float(absi(x - hull.x) + absi(y - hull.y))
			if type == "mirror":
				score -= 0.6 * float(x - hull.x)
			var t := Actions.terrain_at(state, x, y)
			if t == "ice" and type != "drill":
				score += 3.0
			if score < best_score:
				best_score = score
				best = Vector2i(x, y)
	return best


## Breadth-first search from the colony's edge over open regolith/ice to the
## nearest free tile of a wanted terrain. Returns the first tile to lay a main on.
static func _step_toward(state: Dictionary, terrain: Array) -> Vector2i:
	var parent := {}
	var queue: Array = []
	for y in int(state["height"]):
		for x in int(state["width"]):
			if _open(state, x, y) and Actions.touches_colony(state, x, y):
				parent[Vector2i(x, y)] = Vector2i(x, y)
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if not Actions.inside(state, n.x, n.y) or not Actions.structure_at(state, n.x, n.y).is_empty():
				continue
			if Actions.terrain_at(state, n.x, n.y) in terrain:
				var p := c
				while parent[p] != p:
					p = parent[p]
				return p
			if _open(state, n.x, n.y) and not parent.has(n):
				parent[n] = c
				queue.append(n)
	return Vector2i(-1, -1)


static func _open(state: Dictionary, x: int, y: int) -> bool:
	if not Actions.structure_at(state, x, y).is_empty():
		return false
	var t := Actions.terrain_at(state, x, y)
	return t == "regolith" or t == "ice"


## Advanced mode: which of the newer buildings the bot wants this turn.
static func _advanced_wants(state: Dictionary, want: Array, turn: int, pop: float) -> void:
	if turn > 35 and _count(state, "fab") < 1:
		if only == "" or only == "fab" or (only == "drones" and "fab" in ["fab", "dronebay"]):
			want.append("fab")
	if turn > 40 and _count(state, "dronebay") < 1:
		if only == "" or only == "dronebay" or (only == "drones" and "dronebay" in ["fab", "dronebay"]):
			want.append("dronebay")
	if turn > 50 and _count(state, "mast") < mini(3, 1 + int(pop / 60.0)):
		if only == "" or only == "mast" or (only == "drones" and "mast" in ["fab", "dronebay"]):
			want.append("mast")
	if turn > 60 and _count(state, "academy") < 1:
		if only == "" or only == "academy" or (only == "drones" and "academy" in ["fab", "dronebay"]):
			want.append("academy")
	if turn > 60 and _count(state, "rescue") < 1:
		if only == "" or only == "rescue" or (only == "drones" and "rescue" in ["fab", "dronebay"]):
			want.append("rescue")
	if Actions.unlocked(state, "fusion") and _count(state, "fusion") < 1 + int(pop / 120.0):
		if only == "" or only == "fusion" or (only == "drones" and "fusion" in ["fab", "dronebay"]):
			want.append("fusion")
	if float(state["morale"]) < 45.0 and _count(state, "lounge") < 1 and float(state["stock"]["credits"]) > 400.0:
		if only == "" or only == "lounge" or (only == "drones" and "lounge" in ["fab", "dronebay"]):
			want.append("lounge")


## Advanced mode: drones, satellites and supply pods, bought when affordable.
static func _advanced_extras(state: Dictionary) -> void:
	var slots := Fleet.slots(state)
	if (only == "" or only == "drones") and Fleet.drones_total(state) < slots:
		for t in ["prospector", "hauler", "grader"]:
			if Actions.check_drone(state, t)["ok"] and Fleet.owned(state, t) < 2:
				Actions.build_drone(state, t)
				break
	if (only == "" or only == "relay") and float(state["stock"]["credits"]) > CASH_BUFFER * 0.8 and Actions.check_satellite(state, "relay")["ok"]:
		Actions.launch_satellite(state, "relay")
