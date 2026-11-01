## Draws the sprite concept sheet (see tools/sprite_sheet.gd).
extends Control

const Sprites = preload("res://scripts/ui/sprites.gd")
const GameData = preload("res://scripts/sim/game_data.gd")

var page := "buildings"
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _text(t: String, p: Vector2, sz: int, col: Color = Color.WHITE) -> void:
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09))
	if page == "buildings":
		_buildings()
	else:
		_world()


func _buildings() -> void:
	_text("Lastborn Colony: domes joined by tunnels, with an airlock at each dome. Left: top-down. Right: angled. Small: under construction / idle.", Vector2(24, 40), 22, Color(0.95, 0.62, 0.30))
	var ids: Array = GameData.building_ids()
	var cols := 4
	var cw := 470.0
	var ch := 250.0
	for i in ids.size():
		var id: String = ids[i]
		var o := Vector2(20 + (i % cols) * cw, 70 + (i / cols) * ch)
		draw_rect(Rect2(o, Vector2(cw - 12, ch - 12)), Color(0.10, 0.11, 0.14))
		_text(GameData.building(id)["name"], o + Vector2(12, 26), 20, Color(1.0, 0.82, 0.48))
		# Top-down, on one ground tile.
		var r := Rect2(o + Vector2(14, 44), Vector2(120, 120))
		var sample := {"links": [Vector2i(1, 0), Vector2i(0, 1)]} if id != "main" else {"links": [Vector2i(1, 0), Vector2i(-1, 0)]}
		Sprites.terrain_top(self, "regolith", r)
		Sprites.draw_top(self, id, r, sample)
		# Angled, on one diamond.
		var c := o + Vector2(290, 150)
		Sprites.terrain_iso(self, "regolith", c, 200.0)
		Sprites.draw_iso(self, id, c, 200.0, sample)
		# Under construction and idle, small.
		var y := o.y + ch - 64
		for j in 2:
			var st := {"built": false} if j == 0 else {"active": false}
			var rr := Rect2(Vector2(o.x + 14 + j * 60, y), Vector2(44, 44))
			Sprites.terrain_top(self, "regolith", rr)
			Sprites.draw_top(self, id, rr, st)
			var cc := Vector2(o.x + 160 + j * 70, y + 30)
			Sprites.terrain_iso(self, "regolith", cc, 60.0)
			Sprites.draw_iso(self, id, cc, 60.0, st)


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
