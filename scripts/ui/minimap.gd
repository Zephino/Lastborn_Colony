## A small picture of a map (terrain colours and the landing pad), used to
## compare landing sites before choosing one.
extends Control

const GameData = preload("res://scripts/sim/game_data.gd")

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
## True for a site no probe has scouted: only a rough outline shows (rock that
## can't be built on, and the landing spot), not the ice, vents or seams.
var fog := false
## The planet, for its own ground colours (see data/planets.json "look").
var planet_id := ""


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
			var t: String = tiles[y][x]
			var col: Color = COLORS.get(t, Color.MAGENTA)
			if planet_id != "" and t != "vent" and t != "seam":
				var g: Array = GameData.planet(planet_id).get("look", {}).get("ground", {}).get(t, [])
				if g.size() == 3:
					col = Color(float(g[0]), float(g[1]), float(g[2]))
			if fog:
				col = COLORS["ridge"] if t in ["ridge", "deepice", "scorch"] else Color(0.30, 0.30, 0.32)
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), col)
	if hull.x >= 0:
		var c := origin + (Vector2(hull) + Vector2(0.5, 0.5)) * cell
		draw_circle(c, cell * 1.6, Color(1, 1, 1))
		draw_circle(c, cell * 1.0, Color(0.95, 0.62, 0.30))
