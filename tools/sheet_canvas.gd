## Draws the sprite concept sheet (see tools/sprite_sheet.gd).
extends Control

const Sprites = preload("res://scripts/ui/sprites.gd")
const GameData = preload("res://scripts/sim/game_data.gd")

var page := "surface"
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _text(t: String, p: Vector2, sz: int, col: Color = Color.WHITE) -> void:
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09))
	if page == "surface":
		_buildings("Surface buildings. Left: top-down. Right: angled. Small: under construction / idle.", _level_ids("surface"), false)
	elif page == "deep":
		_buildings("Deep buildings (underground). Left: top-down. Right: angled. Small: under construction / idle.", _level_ids("deep"), false)
	elif page == "both":
		_buildings("Buildings that go on both levels: on the surface (middle) and in the Deep (right).", _level_ids("both"), true)
	elif page == "units":
		_units()
	elif page == "tunnels":
		_tunnels()
	else:
		_world()


## The building ids for one level: "surface", "deep" or "both". The Landing
## Pad and Shaft lead the surface page; the Shaft Landing leads the Deep page.
func _level_ids(level: String) -> Array:
	var out: Array = []
	if level == "deep":
		out.append("shaft_base")
	for id in GameData.building_ids():
		var note := GameData.level_note(GameData.building(id))
		var where := "surface" if note == "Surface only." else ("deep" if note == "Deep only." else "both")
		if id in ["hull", "shaft"]:
			where = "surface"
		if where == level and not (id in out):
			out.append(id)
	return out


## The ground a building is shown on: the first ground of that level it may use.
func _ground(id: String, deep: bool) -> String:
	var deep_kinds := ["cavern", "rock", "vein", "aquifer", "deepvent"]
	for t in GameData.building(id).get("terrain", []):
		if (t in deep_kinds) == deep:
			return "cavern" if t == "rock" else t
	return "cavern" if deep else "regolith"


func _buildings(title: String, ids: Array, both: bool) -> void:
	var cols := 4
	var cw := 470.0
	var ch := 250.0
	for i in ids.size():
		var id: String = ids[i]
		var o := Vector2(20 + (i % cols) * cw, 70 + (i / cols) * ch)
		draw_rect(Rect2(o, Vector2(cw - 12, ch - 12)), Color(0.10, 0.11, 0.14))
		_text(GameData.building(id)["name"], o + Vector2(12, 26), 20, Color(1.0, 0.82, 0.48))
		var r := Rect2(o + Vector2(14, 44), Vector2(120, 120))
		# Each building is shown with a tunnel at every door it has.
		var doors := int(Sprites.DOORS.get(id, 2))
		var sample := {"links": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)].slice(0, doors)}
		if doors == 2 or id == "main":
			# Two-door buildings are passed through: in one side, out the other.
			sample = {"links": [Vector2i(1, 0), Vector2i(-1, 0)]}
		var label := "" if id == "main" else "%d door%s" % [doors, "" if doors == 1 else "s"]
		var deep_page := page == "deep"
		var ground := _ground(id, deep_page)
		Sprites.terrain_top(self, ground, r)
		Sprites.draw_top(self, id, r, sample)
		if both:
			# The same building on the surface and in the Deep.
			var c1 := o + Vector2(230, 150)
			var c2 := o + Vector2(370, 150)
			Sprites.terrain_iso(self, _ground(id, false), c1, 140.0)
			Sprites.draw_iso(self, id, c1, 140.0, sample)
			Sprites.terrain_iso(self, _ground(id, true), c2, 140.0, false)
			Sprites.draw_iso(self, id, c2, 140.0, sample)
			_text("Surface", o + Vector2(200, ch - 30), 16, Color(0.95, 0.80, 0.55))
			_text("Deep", o + Vector2(350, ch - 30), 16, Color(0.55, 0.80, 0.95))
		else:
			# The Shaft Landing's lift tube is tall, so it is drawn smaller.
			var big := 140.0 if id == "shaft_base" else 200.0
			var c := o + Vector2(290, 150 if big > 150.0 else 185)
			Sprites.terrain_iso(self, ground, c, big, false)
			Sprites.draw_iso(self, id, c, big, sample)
		# Labels go on last, so a tall building can't cover them.
		if label != "":
			draw_rect(Rect2(o + Vector2(cw - 100, 8), Vector2(86, 24)), Color(0.10, 0.11, 0.14))
			_text(label, o + Vector2(cw - 90, 26), 16, Color(0.7, 0.75, 0.8))
		# Under construction and idle, small.
		var y := o.y + ch - 64
		for j in 2:
			var st := {"built": false} if j == 0 else {"active": false}
			var rr := Rect2(Vector2(o.x + 14 + j * 60, y), Vector2(44, 44))
			Sprites.terrain_top(self, ground, rr)
			Sprites.draw_top(self, id, rr, st)
			if not both:
				var cc := Vector2(o.x + 160 + j * 70, y + 30)
				Sprites.terrain_iso(self, ground, cc, 60.0, false)
				Sprites.draw_iso(self, id, cc, 60.0, st)
	# The page title last, over anything tall.
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 60)), Color(0.06, 0.07, 0.09))
	_text(title, Vector2(24, 40), 22, Color(0.95, 0.62, 0.30))


func _world() -> void:
	_text("Terrain and a sample colony: top-down (left) and angled (right).", Vector2(24, 40), 24, Color(0.95, 0.62, 0.30))
	var kinds: Array = Sprites.TERRAIN.keys()
	for i in kinds.size():
		var t: String = kinds[i]
		var x := 24 + i * 140
		Sprites.terrain_top(self, t, Rect2(Vector2(x + 20, 70), Vector2(80, 80)))
		Sprites.terrain_iso(self, t, Vector2(x + 60, 210), 110.0)
		_text(t, Vector2(x + 20, 290), 16, Color(1.0, 0.82, 0.48))
	# A small colony, the same layout both ways.
	var ground := [
		["ice", "ice", "regolith", "regolith", "regolith", "seam", "regolith"],
		["ice", "ice", "regolith", "regolith", "regolith", "seam", "regolith"],
		["vent", "regolith", "regolith", "regolith", "regolith", "regolith", "regolith"],
		["regolith", "regolith", "regolith", "regolith", "regolith", "regolith", "ridge"],
		["regolith", "regolith", "regolith", "regolith", "regolith", "regolith", "ridge"],
	]
	var b := {
		Vector2i(0, 1): "drill", Vector2i(1, 1): "splitter", Vector2i(2, 1): "main", Vector2i(3, 1): "vat", Vector2i(4, 1): "main", Vector2i(5, 1): "cutter",
		Vector2i(0, 2): "vent", Vector2i(1, 2): "main", Vector2i(2, 2): "main", Vector2i(3, 2): "hull", Vector2i(4, 2): "forge", Vector2i(5, 2): "rail",
		Vector2i(2, 3): "bunk", Vector2i(3, 3): "commons", Vector2i(4, 3): "mirror", Vector2i(5, 3): "mirror",
		Vector2i(2, 4): "clinic", Vector2i(3, 4): "lab", Vector2i(4, 4): "cache", Vector2i(1, 3): "warden", Vector2i(1, 4): "shaft", Vector2i(0, 4): "workshop",
	}
	var ts := 96.0
	var o := Vector2(40, 340)
	for y in ground.size():
		for x in ground[y].size():
			var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
			Sprites.terrain_top(self, ground[y][x], r)
			if b.has(Vector2i(x, y)):
				Sprites.draw_top(self, b[Vector2i(x, y)], r, _links(b, Vector2i(x, y)))
	var tw := 150.0
	var origin := Vector2(1280, 330)
	for sum in ground.size() + ground[0].size():
		for x in ground[0].size():
			var y: int = sum - x
			if y < 0 or y >= ground.size():
				continue
			var c := origin + Vector2((x - y) * tw * 0.5, (x + y) * tw * 0.25)
			Sprites.terrain_iso(self, ground[y][x], c, tw)
	for sum in ground.size() + ground[0].size():
		for x in ground[0].size():
			var y: int = sum - x
			if y < 0 or y >= ground.size() or not b.has(Vector2i(x, y)):
				continue
			var c := origin + Vector2((x - y) * tw * 0.5, (x + y) * tw * 0.25)
			Sprites.draw_iso(self, b[Vector2i(x, y)], c, tw, _links(b, Vector2i(x, y)))


## Which neighbours a building is joined to by tunnels (any building next to it).
func _links(b: Dictionary, cell: Vector2i) -> Dictionary:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if b.has(cell + d):
			out.append(d)
	return {"links": out}


## Every tunnel shape: all 16 combinations of neighbours, both styles.
func _tunnels() -> void:
	_text("Tunnels: every shape (dead end, straight, corner, T-junction, crossroads, and a lone stub). Top-down and angled.", Vector2(24, 40), 22, Color(0.95, 0.62, 0.30))
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var names := {"none": "lone stub", "end": "dead end", "straight": "straight", "corner": "corner", "tee": "T-junction", "cross": "crossroads"}
	for mask in 16:
		var links: Array = []
		for i in 4:
			if mask & (1 << i):
				links.append(dirs[i])
		var o := Vector2(20 + (mask % 4) * 470, 70 + (mask / 4) * 315)
		draw_rect(Rect2(o, Vector2(458, 303)), Color(0.10, 0.11, 0.14))
		_text(names[Sprites.tunnel_shape(links)], o + Vector2(12, 26), 20, Color(1.0, 0.82, 0.48))
		var r := Rect2(o + Vector2(20, 60), Vector2(150, 150))
		Sprites.terrain_top(self, "regolith", r)
		Sprites.draw_top(self, "main", r, {"links": links})
		var c := o + Vector2(320, 150)
		Sprites.terrain_iso(self, "regolith", c, 220.0)
		Sprites.draw_iso(self, "main", c, 220.0, {"links": links})


## Drones (on a patch of ground) and satellites (in space), angled.
func _units() -> void:
	_text("Drones (built at a Drone Bay) and satellites (launched from a Spin Launcher). Angled view.", Vector2(24, 40), 22, Color(0.95, 0.62, 0.30))
	const Fleet = preload("res://scripts/sim/fleet.gd")
	var more: Script = Sprites.more()
	var cw := 470.0
	for i in 4:
		var t: String = Fleet.drone_order()[i]
		var o := Vector2(20 + i * cw, 70)
		draw_rect(Rect2(o, Vector2(cw - 12, 420)), Color(0.10, 0.11, 0.14))
		_text(Fleet.drone_def(t)["name"], o + Vector2(12, 28), 22, Color(1.0, 0.82, 0.48))
		var c := o + Vector2(cw * 0.5 - 6, 260)
		Sprites.terrain_iso(self, "regolith", c, 360.0)
		more.draw_unit(self, t, c, 360.0)
	# Colonists in space suits, by job, and the resource icons.
	const People = preload("res://scripts/ui/people.gd")
	var po := Vector2(20 + 3 * cw, 510)
	draw_rect(Rect2(po, Vector2(cw - 12, 440)), Color(0.10, 0.11, 0.14))
	_text("Colonists and resource icons", po + Vector2(12, 28), 22, Color(1.0, 0.82, 0.48))
	var jobs := ["worker", "scientist", "warden"]
	for k in 3:
		People.draw_colonist(self, po + Vector2(90 + k * 130, 250), 150.0, jobs[k], 1.0 if k != 1 else -1.0, k == 1)
		_text(jobs[k], po + Vector2(55 + k * 130, 285), 16, Color(0.75, 0.78, 0.84))
	var keys := ["pop", "morale", "power", "heat", "workers", "food", "oxygen", "water", "ore", "alloy", "parts", "marks", "debt", "payment", "turn"]
	for k in keys.size():
		People.draw_icon(self, keys[k], po + Vector2(40 + (k % 8) * 52, 330 + (k / 8) * 60), 40.0)
	# The lander on the Landing Pad, docked at each of its four airlocks in turn.
	var lo := Vector2(20, 970)
	draw_rect(Rect2(lo, Vector2(cw * 4 - 12, 350)), Color(0.10, 0.11, 0.14))
	_text("The lander on the Landing Pad (it docks at the next airlock round each time it lands)", lo + Vector2(12, 28), 22, Color(1.0, 0.82, 0.48))
	for k in 4:
		var lc := lo + Vector2(cw * 0.5 - 6 + k * cw, 260)
		Sprites.terrain_iso(self, "regolith", lc, 300.0)
		Sprites.draw_iso(self, "hull", lc, 300.0, {"links": [], "ship": true, "ship_door": k})
	for i in 3:
		var t: String = Fleet.sat_order()[i]
		var o := Vector2(20 + i * cw, 510)
		draw_rect(Rect2(o, Vector2(cw - 12, 440)), Color(0.02, 0.03, 0.06))
		for k in 40:
			draw_circle(o + Vector2(fmod(k * 97.0, cw - 20) + 6, fmod(k * 53.0, 420) + 10), 1.0, Color(1, 1, 1, 0.5))
		_text(Fleet.sat_def(t)["name"], o + Vector2(12, 28), 22, Color(1.0, 0.82, 0.48))
		more.draw_unit(self, t, o + Vector2(cw * 0.5 - 6, 300), 360.0)
