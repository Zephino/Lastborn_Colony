## A small picture of a map (terrain colours and the landing pad), used to
## compare landing sites before choosing one.
extends Control

const COLORS := {
	"regolith": Color(0.40, 0.35, 0.30),
	"ice": Color(0.70, 0.82, 0.90),
	"vent": Color(0.95, 0.45, 0.15),
	"seam": Color(0.25, 0.62, 0.60),
	"ridge": Color(0.14, 0.14, 0.16),
	"deepice": Color(0.85, 0.92, 0.98),
	"scorch": Color(0.55, 0.30, 0.16),
}

var tiles: Array = []
var hull := Vector2i(-1, -1)


func show_map(map: Dictionary) -> void:
	tiles = map["tiles"]
	var h: Array = map["hull"]
	hull = Vector2i(int(h[0]), int(h[1]))
	queue_redraw()


func _draw() -> void:
	if tiles.is_empty():
		return
	var rows := tiles.size()
	var cols: int = tiles[0].size()
	var cell := minf(size.x / cols, size.y / rows)
	var origin := (size - Vector2(cols, rows) * cell) * 0.5
	for y in rows:
		for x in cols:
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), COLORS.get(tiles[y][x], Color.MAGENTA))
	if hull.x >= 0:
		var c := origin + (Vector2(hull) + Vector2(0.5, 0.5)) * cell
		draw_circle(c, cell * 1.6, Color(1, 1, 1))
		draw_circle(c, cell * 1.0, Color(0.95, 0.62, 0.30))
