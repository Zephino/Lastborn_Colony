## A scripted player used by the tests: builds whatever the colony is short of,
## keeps an alloy reserve once it can export, and pays the debt down early.
## It is deliberately simple; a good human player should beat it.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const NewGame = preload("res://scripts/sim/new_game.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CRITICAL := ["mirror", "vent", "splitter", "drill", "vat", "bunk"]
const MUST_AFFORD := ["mirror", "splitter", "drill", "vat"]
const CASH_BUFFER := 1200.0


## Plays one turn's worth of decisions (does not end the turn).
static func act(state: Dictionary) -> void:
	if state["pending_event"] != "":
		var ev := GameData.event(state["pending_event"])
		var choices: Array = ev["choices"]
		for i in choices.size():
			if Actions.choice_allowed(state, choices[i]):
				Actions.resolve_event(state, i)
				break
	var credits := float(state["stock"]["credits"])
	if credits > CASH_BUFFER:
		Actions.pay_extra(state, credits - CASH_BUFFER)
	var choice := _choose(state)
	if choice != "":
		_build(state, choice)


static func _count(state: Dictionary, type: String) -> int:
	var n := 0
	for id in state["structures"]:
		if state["structures"][id]["type"] == type:
			n += 1
	return n


static func _choose(state: Dictionary) -> String:
	var alloy := float(state["stock"]["alloy"])
	if alloy < 1.0:
		return ""
	var turn := int(state["turn"])
	var pop := float(state["adults"]) + float(state["children"])
	var rep: Dictionary = state["report"]
	var want: Array = []
	if float(rep.get("power_free", 0.0)) < 5.0:
		want.append("mirror")
	if float(rep.get("heat_free", 0.0)) < 2.0:
		want.append("vent")
	var splitters := ceili(pop * 0.11 / 5.0)
	var vats := ceili(pop * 0.11 / 6.0)
	if _count(state, "splitter") < splitters:
		want.append("splitter")
	if _count(state, "drill") < ceili((2.0 * (splitters + vats) + pop * 0.06) / 5.5):
		want.append("drill")
	if _count(state, "vat") < vats:
		want.append("vat")
	if pop > 40.0 + 12.0 * _count(state, "bunk") - 6.0:
		want.append("bunk")
	var forges := mini(4, 1 + turn / 25)
	if _count(state, "cutter") < ceili(forges * 4.0 / 5.0):
		want.append("cutter")
	if _count(state, "forge") < forges:
		want.append("forge")
	if turn >= 12 and _count(state, "rail") < ceili(forges * 3.0 / 4.0):
		want.append("rail")
	if float(state["morale"]) < 50.0 and _count(state, "commons") < 3 and turn > 15:
		want.append("commons")
	if turn > 40 and _count(state, "clinic") < 1:
		want.append("clinic")
	var cap := float(rep.get("storage", 300.0))
	for k in GameData.balance()["stored_resources"]:
		if float(state["stock"][k]) > cap * 0.9 and _count(state, "cache") < 4:
			want.append("cache")
			break
	var keep := 20.0 if _count(state, "rail") > 0 else 0.0
	for w in want:
		var need := GameData.num(GameData.building(w), "cost") + (0.0 if w in CRITICAL else keep)
		if alloy >= need:
			return w
		if w in MUST_AFFORD:
			return ""
	return ""


## Builds the type at the best adjacent site, or lays a heat main toward the
## nearest tile it needs (ice, vent or seam) if none is in reach.
static func _build(state: Dictionary, type: String) -> void:
	var site := _best_site(state, type)
	if site.x >= 0:
		Actions.place(state, type, site.x, site.y)
		return
	var terrain: Array = GameData.building(type)["terrain"]
	var step := _step_toward(state, terrain)
	if step.x >= 0:
		Actions.place(state, "main", step.x, step.y)


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
