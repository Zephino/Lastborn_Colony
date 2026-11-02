## The picture in a probe report: the ground round a landing site, drawn at an
## angle the way the game map is, with the probe standing where the ship
## would land.
extends Control

const Sprites = preload("res://scripts/ui/sprites.gd")

## How many tiles out from the landing spot to show.
const RADIUS := 4

var tiles: Array = []
var hull := Vector2i(-1, -1)
## The site's lucky find ("" for none), drawn two tiles from the probe.
var find := ""
var planet_id := ""


func show_map(map: Dictionary, lucky: String = "", planet: String = "") -> void:
	find = lucky
	planet_id = planet
	tiles = map["tiles"]
	var h: Array = map["hull"]
	hull = Vector2i(int(h[0]), int(h[1]))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Sprites.sky(planet_id) if planet_id != "" else Color(0.05, 0.06, 0.08))
	if tiles.is_empty():
		return
	Sprites.set_planet(planet_id)
	# Fit a diamond of (2 * RADIUS + 1) tiles across.
	var n := 2 * RADIUS + 1
	var tw := minf(size.x / n, size.y * 2.0 / n) * 0.98
	var mid := size * 0.5 + Vector2(0, tw * 0.1)
	for sum in range(-2 * RADIUS, 2 * RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var dy := sum - dx
			if absi(dy) > RADIUS:
				continue
			var x := hull.x + dx
			var y := hull.y + dy
			if y < 0 or y >= tiles.size() or x < 0 or x >= tiles[y].size():
				continue
			var c := mid + Vector2((dx - dy) * tw * 0.5, (dx + dy) * tw * 0.25)
			Sprites.terrain_iso(self, tiles[y][x], c, tw)
	_draw_find(mid + Vector2((2 - 1) * tw * 0.5, (2 + 1) * tw * 0.25), tw)
	_draw_probe(mid, tw)


## The lucky find: a crashed lander, a stack of supply crates, or ore glowing
## through the ground.
func _draw_find(c: Vector2, tw: float) -> void:
	match find:
		"wreck":
			var hull_col := Color(0.70, 0.70, 0.72)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-tw * 0.30, tw * 0.02), c + Vector2(tw * 0.18, -tw * 0.14), c + Vector2(tw * 0.28, -tw * 0.06), c + Vector2(-tw * 0.20, tw * 0.10)]), hull_col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(tw * 0.18, -tw * 0.14), c + Vector2(tw * 0.32, -tw * 0.30), c + Vector2(tw * 0.36, -tw * 0.22), c + Vector2(tw * 0.28, -tw * 0.06)]), hull_col.darkened(0.25))
			draw_line(c + Vector2(-tw * 0.05, -tw * 0.02), c + Vector2(-tw * 0.18, -tw * 0.22), Color(0.3, 0.3, 0.32), 2.0)
			draw_circle(c + Vector2(tw * 0.0, tw * 0.0), tw * 0.03, Color(0.95, 0.55, 0.20))
			for k in 3:
				draw_circle(c + Vector2(tw * (0.02 + k * 0.03), -tw * (0.10 + k * 0.07)), tw * (0.03 + k * 0.012), Color(0.35, 0.35, 0.38, 0.5 - k * 0.12))
		"cache":
			var crate := Color(0.62, 0.46, 0.28)
			for k in 3:
				var p := c + Vector2((k - 1) * tw * 0.10, -(k % 2) * tw * 0.06)
				draw_rect(Rect2(p - Vector2(tw * 0.06, tw * 0.10), Vector2(tw * 0.12, tw * 0.10)), crate)
				draw_rect(Rect2(p - Vector2(tw * 0.06, tw * 0.10), Vector2(tw * 0.12, tw * 0.10)), crate.darkened(0.4), false, 1.5)
				draw_line(p - Vector2(tw * 0.06, tw * 0.05), p + Vector2(tw * 0.06, -tw * 0.05), Color(0.85, 0.25, 0.20), 2.0)
			draw_line(c + Vector2(tw * 0.18, 0), c + Vector2(tw * 0.18, -tw * 0.28), Color(0.3, 0.3, 0.32), 1.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(tw * 0.18, -tw * 0.28), c + Vector2(tw * 0.30, -tw * 0.24), c + Vector2(tw * 0.18, -tw * 0.20)]), Color(1.0, 0.85, 0.25))
		"seam":
			for k in 3:
				var a := c + Vector2((k - 1) * tw * 0.12, (k % 2) * tw * 0.04)
				draw_line(a + Vector2(-tw * 0.08, tw * 0.02), a + Vector2(tw * 0.08, -tw * 0.03), Color(0.30, 0.95, 0.85), maxf(2.5, tw * 0.025))
				draw_circle(a, tw * 0.05, Color(0.30, 0.95, 0.85, 0.25))


## A small landing probe: three legs, a gold-foil body, a dish and a light.
func _draw_probe(c: Vector2, tw: float) -> void:
	var dark := Color(0.20, 0.22, 0.26)
	var body := c - Vector2(0, tw * 0.28)
	for k in 3:
		var a := k * TAU / 3.0 + 0.4
		var foot := c + Vector2(cos(a) * tw * 0.22, sin(a) * tw * 0.11)
		draw_line(body + Vector2(cos(a) * tw * 0.05, tw * 0.04), foot, dark, maxf(2.0, tw * 0.025))
		draw_circle(foot, tw * 0.025, dark)
	draw_rect(Rect2(body - Vector2(tw * 0.09, tw * 0.07), Vector2(tw * 0.18, tw * 0.12)), Color(0.85, 0.68, 0.25))
	draw_rect(Rect2(body - Vector2(tw * 0.09, tw * 0.07), Vector2(tw * 0.18, tw * 0.12)), dark, false, 1.5)
	var dish := body - Vector2(-tw * 0.03, tw * 0.16)
	draw_line(body - Vector2(0, tw * 0.07), dish, dark, 1.5)
	draw_colored_polygon(Sprites._ellipse(dish, tw * 0.07, tw * 0.035), Color(0.92, 0.94, 0.96))
	draw_circle(body + Vector2(tw * 0.05, -tw * 0.02), tw * 0.02, Color(0.4, 1.0, 0.6))
	for k in 3:
		draw_arc(dish, tw * (0.10 + k * 0.06), deg_to_rad(-70), deg_to_rad(-20), 6, Color(0.45, 0.85, 1.0, 0.7 - k * 0.2), 1.5)
