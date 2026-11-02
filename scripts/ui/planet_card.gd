## The top of a planet's card on the "Choose a planet" screen: a drawn globe
## in the planet's own style, its name and difficulty pips, its tagline, and
## bars comparing it with the other worlds. The look comes from the planet's
## "look" in data/planets.json.
extends Control

const GameData = preload("res://scripts/sim/game_data.gd")

var planet: Dictionary = {}
var font: Font
var selected := false


func _ready() -> void:
	font = ThemeDB.fallback_font


func show_planet(p: Dictionary, is_selected: bool = false) -> void:
	planet = p
	selected = is_selected
	queue_redraw()


func _col(key: String, fallback: Color) -> Color:
	var a: Array = planet.get("look", {}).get(key, [])
	return Color(float(a[0]), float(a[1]), float(a[2])) if a.size() == 3 else fallback


## The 0-1 scores the bars show, from the planet's data.
func stats() -> Array:
	var w: Dictionary = planet.get("event_weights", {})
	var sun := (float(planet["light_west"]) + float(planet["light_east"])) * 0.5
	var warm := clampf(1.0 - (float(planet["cold_offset"]) - sun - 0.2) / 1.2, 0.0, 1.0)
	return [
		["Sunlight", clampf(sun / 1.5, 0.0, 1.0), Color(1.0, 0.85, 0.35)],
		["Warmth", warm, Color(1.0, 0.55, 0.30)],
		["Ice", clampf(float(planet["ice"]) / 1.8, 0.0, 1.0), Color(0.70, 0.85, 1.0)],
		["Vents", clampf(float(planet["vents"]) / 18.0, 0.0, 1.0), Color(1.0, 0.45, 0.20)],
		["Ore", clampf(float(planet["seams"]) / 13.0, 0.0, 1.0), Color(0.35, 0.85, 0.80)],
		["Ridges", clampf(float(planet["ridges"]) / 15.0, 0.0, 1.0), Color(0.60, 0.60, 0.65)],
		["Storms", clampf(float(w.get("dust_storm", 1.0)) / 2.5, 0.0, 1.0), Color(0.85, 0.70, 0.50)],
		["Quakes", clampf(maxf(float(w.get("icequake", 1.0)), float(w.get("seismic", 1.0))) / 3.0, 0.0, 1.0), Color(0.85, 0.50, 0.85)],
	]


func _draw() -> void:
	if planet.is_empty():
		return
	var bg := Color(0.11, 0.12, 0.16) if not selected else Color(0.16, 0.15, 0.20)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), _col("accent", Color.WHITE) if selected else Color(0.24, 0.26, 0.32), false, 2.0)
	var gr := minf(size.y * 0.42, size.x * 0.16)
	var gc := Vector2(gr + 16.0, size.y * 0.5)
	_starfield(Rect2(Vector2(4, 4), Vector2(gr * 2.0 + 24.0, size.y - 8.0)))
	_globe(gc, gr)
	var x := gc.x + gr + 18.0
	var name_size := 24
	draw_string(font, Vector2(x, 32), planet["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(1.0, 0.82, 0.48))
	var nw := font.get_string_size(planet["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	_badge(Vector2(x + nw + 12.0, 14.0))
	draw_string(font, Vector2(x, 54), planet["tagline"], HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10.0, 15, Color(0.80, 0.84, 0.90))
	# Stat bars in two columns.
	var rows := stats()
	var colw := (size.x - x - 16.0) * 0.5
	for i in rows.size():
		var cx := x + (i % 2) * colw
		var cy := 72.0 + (i / 2) * 24.0
		var label: String = rows[i][0]
		draw_string(font, Vector2(cx, cy + 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.74, 0.80))
		var bar := Rect2(Vector2(cx + 66.0, cy + 3.0), Vector2(colw - 80.0, 9.0))
		draw_rect(bar, Color(0.20, 0.22, 0.27))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(rows[i][1]), bar.size.y)), rows[i][2])


## The difficulty word with up to five pips.
func _badge(at: Vector2) -> void:
	var rank := int(planet.get("look", {}).get("rank", 2))
	var word: String = planet["difficulty"]
	var cols := [Color(0.45, 0.85, 0.50), Color(0.55, 0.80, 0.95), Color(0.95, 0.80, 0.35), Color(1.0, 0.55, 0.30), Color(1.0, 0.35, 0.35)]
	var col: Color = cols[clampi(rank - 1, 0, 4)]
	var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var box := Rect2(at, Vector2(tw + 16.0 + 5 * 10.0, 22.0))
	draw_rect(box, Color(col.r, col.g, col.b, 0.18))
	draw_rect(box, col, false, 1.5)
	draw_string(font, at + Vector2(8, 16), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	for k in 5:
		var pc := at + Vector2(tw + 16.0 + k * 10.0, 11.0)
		draw_circle(pc, 3.5, col if k < rank else Color(col.r, col.g, col.b, 0.25))


func _starfield(r: Rect2) -> void:
	draw_rect(r, Color(0.02, 0.03, 0.06))
	var h := hash(str(planet["id"]))
	for k in 26:
		var p := r.position + Vector2(float((h >> (k % 20)) % 97) / 97.0 * r.size.x, float((h * (k + 3)) % 89) / 89.0 * r.size.y)
		draw_circle(p, 0.9 + (k % 3) * 0.3, Color(1, 1, 1, 0.35 + (k % 4) * 0.12))


## A circle of radius r cut by the horizontal lines y0 and y1 (relative to the
## centre), as a polygon: for bands of colour across the globe.
func _slice(c: Vector2, r: float, y0: float, y1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 10
	for k in steps + 1:
		var y := lerpf(y0, y1, float(k) / steps)
		pts.append(c + Vector2(-sqrt(maxf(0.0, r * r - y * y)), y))
	for k in range(steps, -1, -1):
		var y := lerpf(y0, y1, float(k) / steps)
		pts.append(c + Vector2(sqrt(maxf(0.0, r * r - y * y)), y))
	return pts


func _globe(c: Vector2, r: float) -> void:
	var base := _col("base", Color(0.5, 0.5, 0.5))
	var band := _col("band", Color(0.8, 0.8, 0.8))
	var accent := _col("accent", Color.WHITE)
	# A soft glow of atmosphere.
	for k in 4:
		draw_circle(c, r + 6.0 - k * 1.5, Color(accent.r, accent.g, accent.b, 0.05 + k * 0.03))
	draw_circle(c, r, base)
	var h := hash(str(planet["id"]))
	match str(planet.get("look", {}).get("style", "banded")):
		"split":
			# Locked face-to-sun: an ice cap on the night side, a hot glow on the day side.
			draw_colored_polygon(_side(c, r, -1.0, 0.55), band)
			draw_colored_polygon(_side(c, r, 1.0, 0.75), Color(accent.r, accent.g, accent.b, 0.55))
			draw_colored_polygon(_side(c, r, 1.0, 0.45), Color(1.0, 0.8, 0.4, 0.6))
		"banded":
			for k in 6:
				var y0 := -r + (k * 2 + 1) * r / 6.5
				draw_colored_polygon(_slice(c, r, y0, y0 + r * 0.16), Color(band.r, band.g, band.b, 0.75))
			draw_colored_polygon(_slice(c, r, -r * 0.06, r * 0.06), Color(accent.r, accent.g, accent.b, 0.5))
		"icy":
			draw_colored_polygon(_slice(c, r, -r, -r * 0.55), band)
			draw_colored_polygon(_slice(c, r, r * 0.6, r), band)
			for k in 5:
				var a := float((h >> k) % 360) * PI / 180.0
				var p := c + Vector2(cos(a), sin(a)) * r * 0.45
				draw_line(p, p + Vector2(cos(a + 1.2), sin(a + 1.2)) * r * 0.4, band.lightened(0.2), 1.5)
			draw_circle(c + Vector2(r * 0.25, r * 0.15), r * 0.08, accent)
		"rocky":
			for k in 7:
				var p := c + Vector2(float((h >> k) % 100) / 100.0 - 0.5, float((h >> (k + 5)) % 100) / 100.0 - 0.5) * r * 1.3
				if p.distance_to(c) < r * 0.82:
					draw_circle(p, r * (0.08 + (k % 3) * 0.04), band)
					draw_arc(p, r * (0.08 + (k % 3) * 0.04), PI * 0.9, PI * 1.6, 8, base.lightened(0.25), 1.5)
			for k in 3:
				var a := -0.6 + k * 0.5
				draw_line(c + Vector2(-r * 0.7, r * a * 0.6), c + Vector2(r * 0.6, r * (a * 0.6 + 0.2)), Color(accent.r, accent.g, accent.b, 0.8), 1.5)
		"volcanic":
			for k in 6:
				var a := float((h >> (k * 2)) % 360) * PI / 180.0
				var p := c + Vector2(cos(a), sin(a)) * r * (0.2 + 0.1 * (k % 4))
				draw_polyline(PackedVector2Array([p, p + Vector2(r * 0.15, r * 0.08), p + Vector2(r * 0.22, r * 0.25)]), accent, 2.0)
				draw_circle(p, r * 0.05, Color(1.0, 0.75, 0.3))
			draw_colored_polygon(_slice(c, r, -r * 0.2, r * 0.0), Color(band.r, band.g, band.b, 0.6))
		"ocean":
			for k in 6:
				var p := c + Vector2(float((h >> k) % 100) / 100.0 - 0.5, float((h >> (k + 7)) % 100) / 100.0 - 0.5) * r * 1.2
				if p.distance_to(c) < r * 0.8:
					draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.15, 0), p + Vector2(0, -r * 0.1), p + Vector2(r * 0.18, -r * 0.02), p + Vector2(r * 0.05, r * 0.1)]), band)
			draw_colored_polygon(_slice(c, r, -r, -r * 0.7), band)
		"dim":
			draw_colored_polygon(_slice(c, r, -r, -r * 0.65), band)
			draw_colored_polygon(_slice(c, r, r * 0.7, r), band)
			for k in 4:
				draw_circle(c + Vector2(-r * 0.3 + k * r * 0.2, r * (0.1 * (k % 2))), r * 0.04, Color(1.0, 0.55, 0.25))
	# Shade the side away from the star, and add a highlight.
	draw_colored_polygon(_side(c, r, -1.0, 0.25), Color(0, 0, 0, 0.45))
	draw_circle(c + Vector2(r * 0.35, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.12))
	draw_arc(c, r, 0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.6), 1.5)


## The part of the globe on one side (-1 left, 1 right) of a curved line: the
## terminator, bulging by `bulge` of the radius.
func _side(c: Vector2, r: float, side: float, bulge: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 25:
		var a := -PI * 0.5 + float(k) / 24.0 * PI
		pts.append(c + Vector2(side * cos(a) * r, sin(a) * r))
	for k in range(24, -1, -1):
		var a := -PI * 0.5 + float(k) / 24.0 * PI
		pts.append(c + Vector2(side * cos(a) * r * (1.0 - bulge), sin(a) * r))
	return pts
