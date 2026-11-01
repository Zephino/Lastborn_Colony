## Building and terrain art for Lastborn Colony, drawn in code (no image files).
##
## We're in space: every building is a pressurised DOME. Domes next to each
## other are joined by a short TUNNEL, with an AIRLOCK where the tunnel meets
## each dome. Heat Main tiles are longer tunnels. Each dome shows its job
## through the glass and with fittings outside (mirror wings, chimneys, tanks).
##
## Two styles of every sprite:
##   draw_top(): seen from straight above, for the square top-down map.
##   draw_iso(): seen at an angle ("isometric"), for a diamond-tile map.
##
## `state` (optional): {"built": bool, "active": bool, "links": Array}.
##   built  false: drawn faint (under construction).
##   active false: dimmed (idle).
##   links  the neighbouring tiles with a building, as Vector2i (1,0), (-1,0),
##          (0,1), (0,-1). A tunnel and airlock are drawn toward each one.
##          A Heat Main without links is drawn as a cross.
## Everything here is original.
extends RefCounted

const METAL := Color(0.46, 0.49, 0.54)
const METAL_DARK := Color(0.22, 0.24, 0.28)
const GLASS := Color(0.55, 0.80, 0.95, 0.42)
const AMBER := Color(1.00, 0.70, 0.25)
const CYAN := Color(0.35, 0.90, 1.00)
const GOLD := Color(1.00, 0.80, 0.38)
const ORANGE := Color(1.00, 0.55, 0.20)
const GREEN := Color(0.40, 0.95, 0.55)
const TEAL := Color(0.30, 0.82, 0.76)
const VIOLET := Color(0.72, 0.56, 1.00)
const WHITE := Color(0.90, 0.93, 0.96)
const WATER := Color(0.35, 0.65, 1.00)

## The glowing band colour of each building (its group colour).
const ACCENT := {
	"hull": ORANGE, "main": ORANGE, "shaft": ORANGE, "shaft_base": ORANGE,
	"mirror": CYAN, "vent": GOLD, "drill": WATER, "splitter": CYAN, "vat": GREEN, "bunk": GOLD,
	"cutter": TEAL, "forge": ORANGE, "rail": GOLD,
	"commons": GREEN, "clinic": TEAL, "cache": GOLD, "lab": VIOLET, "workshop": CYAN, "warden": VIOLET,
}
## What fills each dome (seen through the glass).
const INTERIOR := {
	"hull": Color(0.30, 0.26, 0.22), "vat": Color(0.08, 0.34, 0.22), "commons": Color(0.14, 0.40, 0.22),
	"clinic": Color(0.80, 0.86, 0.90), "drill": Color(0.14, 0.26, 0.44), "splitter": Color(0.20, 0.32, 0.42),
	"forge": Color(0.30, 0.16, 0.10), "lab": Color(0.20, 0.16, 0.32),
}
## Dome size (radius, as a fraction of a tile) for each building.
const DOME_SIZE := {"hull": 0.44, "mirror": 0.20, "cache": 0.34, "warden": 0.28, "shaft": 0.30}
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# ============================================================ helpers

static func _fade(c: Color, state: Dictionary) -> Color:
	if not state.get("built", true):
		return Color(c.r, c.g, c.b, c.a * 0.35)
	if not state.get("active", true):
		return c.darkened(0.45)
	return c


static func _lit(state: Dictionary) -> bool:
	return state.get("built", true) and state.get("active", true)


static func _ellipse(center: Vector2, rx: float, ry: float, from_deg: float = 0.0, to_deg: float = 360.0, steps: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _glow(ci: CanvasItem, p: Vector2, r: float, c: Color, state: Dictionary) -> void:
	if not _lit(state):
		return
	for i in 3:
		ci.draw_circle(p, r * (1.0 + i * 0.6), Color(c.r, c.g, c.b, 0.16 / (i + 1)))
	ci.draw_circle(p, r * 0.5, Color(c.r, c.g, c.b, 0.9))


static func _links(type: String, state: Dictionary) -> Array:
	if state.has("links"):
		return state["links"]
	return DIRS if type == "main" else []


# ============================================================ top-down

static func _top_dome(ci: CanvasItem, c: Vector2, rad: float, acc: Color, inside: Color, state: Dictionary) -> void:
	ci.draw_circle(c + Vector2(rad * 0.10, rad * 0.14), rad * 1.04, Color(0, 0, 0, 0.28 * _fade(Color.WHITE, state).a))
	ci.draw_circle(c, rad, _fade(METAL_DARK, state))
	ci.draw_circle(c, rad * 0.88, _fade(inside, state))
	ci.draw_arc(c, rad * 0.94, 0, TAU, 40, _fade(acc, state), maxf(1.5, rad * 0.08))
	var glass := _fade(GLASS, state)
	ci.draw_circle(c, rad * 0.86, Color(glass.r, glass.g, glass.b, glass.a * 0.55))
	# Ribs of the dome frame.
	for i in 3:
		var dir := Vector2.from_angle(i * PI / 3.0)
		ci.draw_line(c - dir * rad * 0.86, c + dir * rad * 0.86, _fade(Color(0.75, 0.82, 0.90, 0.35), state), 1.0)
	ci.draw_arc(c, rad * 0.55, 0, TAU, 28, _fade(Color(0.75, 0.82, 0.90, 0.30), state), 1.0)
	ci.draw_arc(c - Vector2(rad * 0.25, rad * 0.25), rad * 0.45, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.55 * _fade(Color.WHITE, state).a), 2.0)


## A tunnel from the edge of the dome to the tile's edge, with an airlock.
static func _top_link(ci: CanvasItem, c: Vector2, s: float, d: Vector2i, rad: float, state: Dictionary) -> void:
	var dir := Vector2(d)
	var side := Vector2(-dir.y, dir.x)
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var from := c + dir * rad * 0.85
	var to := c + dir * s * 0.5
	var orange := _fade(ORANGE, state)
	# The tube, like a Heat Main: dark casing, metal core, glowing orange stripe, ribs.
	ci.draw_colored_polygon(PackedVector2Array([from + side * s * 0.12, to + side * s * 0.12, to - side * s * 0.12, from - side * s * 0.12]), md)
	ci.draw_line(from, to, m, s * 0.10)
	ci.draw_line(from, to, Color(orange.r, orange.g, orange.b, 0.8 * orange.a), s * 0.035)
	var rib := c + dir * (rad + (s * 0.5 - rad) * 0.7)
	ci.draw_line(rib + side * s * 0.13, rib - side * s * 0.13, md.darkened(0.3), 2.0)
	# Airlock: a wider chamber against the dome, with amber door stripes.
	var lock_c := c + dir * (rad + s * 0.04)
	var half := s * 0.075
	var chamber := PackedVector2Array([lock_c + side * s * 0.13 - dir * half, lock_c + side * s * 0.13 + dir * half, lock_c - side * s * 0.13 + dir * half, lock_c - side * s * 0.13 - dir * half])
	ci.draw_colored_polygon(chamber, m)
	var amber := _fade(AMBER, state)
	ci.draw_line(lock_c + side * s * 0.11 - dir * half * 0.6, lock_c - side * s * 0.11 - dir * half * 0.6, amber, 2.0)
	ci.draw_line(lock_c + side * s * 0.11 + dir * half * 0.6, lock_c - side * s * 0.11 + dir * half * 0.6, amber, 2.0)
	# The opening in the dome wall: an orange ring.
	_top_port(ci, c + dir * rad * 0.92, s, state, false)


## A tube opening in the dome wall: an orange ring around a dark hole.
## Capped (no tunnel yet) ports get a metal cap with a small orange light.
static func _top_port(ci: CanvasItem, p: Vector2, s: float, state: Dictionary, capped: bool) -> void:
	var orange := _fade(ORANGE, state)
	ci.draw_circle(p, s * 0.075, _fade(METAL_DARK, state))
	ci.draw_circle(p, s * 0.045, _fade(METAL, state) if capped else Color(0.03, 0.02, 0.02, orange.a))
	ci.draw_arc(p, s * 0.07, 0, TAU, 18, orange, maxf(1.5, s * 0.022))
	if capped:
		ci.draw_circle(p, s * 0.015, orange)


## Draws building `type` filling `r` (one map tile), seen from above.
static func draw_top(ci: CanvasItem, type: String, r: Rect2, state: Dictionary = {}) -> void:
	var s := r.size.x
	var c := r.get_center()
	var acc: Color = ACCENT.get(type, CYAN)
	var a := _fade(acc, state)
	var m := _fade(METAL, state)
	var md := _fade(METAL_DARK, state)
	var links := _links(type, state)
	if type == "main":
		_top_tunnel(ci, c, s, links, state)
		return
	var rad: float = float(DOME_SIZE.get(type, 0.38)) * s
	for d in links:
		_top_link(ci, c, s, d, rad, state)
	# Fittings outside the dome, drawn first so the dome sits on top.
	match type:
		"mirror":
			for side in [-1.0, 1.0]:
				for k in 2:
					var p: Vector2 = c + Vector2(side * s * (0.20 + k * 0.15), 0)
					ci.draw_rect(Rect2(p - Vector2(s * 0.065, s * 0.36), Vector2(s * 0.13, s * 0.72)), md)
					ci.draw_rect(Rect2(p - Vector2(s * 0.05, s * 0.34), Vector2(s * 0.10, s * 0.68)), _fade(Color(0.50, 0.82, 1.0), state))
		"splitter":
			for side in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(side * s * 0.34, -s * 0.30), s * 0.12, m)
				ci.draw_circle(c + Vector2(side * s * 0.34, -s * 0.30), s * 0.07, _fade(Color(0.85, 0.95, 1.0), state))
		"rail":
			ci.draw_rect(Rect2(c + Vector2(0, -s * 0.10), Vector2(s * 0.5, s * 0.20)), md)
			ci.draw_line(c + Vector2(0, -s * 0.06), c + Vector2(s * 0.5, -s * 0.06), a, 2.0)
			ci.draw_line(c + Vector2(0, s * 0.06), c + Vector2(s * 0.5, s * 0.06), a, 2.0)
		"drill":
			ci.draw_circle(c + Vector2(s * 0.30, s * 0.30), s * 0.13, _fade(Color(0.25, 0.45, 0.75), state))
	_top_dome(ci, c, rad, acc, INTERIOR.get(type, Color(0.26, 0.28, 0.32)), state)
	# Every side without a tunnel still has a capped orange port, ready for one.
	for d in DIRS:
		if not (d in links):
			_top_port(ci, c + Vector2(d) * rad * 0.92, s, state, true)
		else:
			_top_port(ci, c + Vector2(d) * rad * 0.92, s, state, false)
	# What shows through the glass, or on top.
	match type:
		"hull":
			ci.draw_arc(c, rad * 0.62, 0, TAU, 32, a, 3.0)
			ci.draw_line(c, c + Vector2(rad * 0.45, -rad * 0.45), m, 3.0)
			_glow(ci, c + Vector2(rad * 0.45, -rad * 0.45), s * 0.04, a, state)
			_glow(ci, c, s * 0.06, a, state)
		"mirror":
			_glow(ci, c, s * 0.05, a, state)
		"vent":
			ci.draw_circle(c, rad * 0.45, md)
			ci.draw_circle(c, rad * 0.30, Color(0.05, 0.03, 0.02, a.a))
			_glow(ci, c, rad * 0.22, a, state)
		"drill":
			ci.draw_line(c - Vector2(rad * 0.6, 0), c + Vector2(rad * 0.6, 0), m, 2.0)
			ci.draw_line(c - Vector2(0, rad * 0.6), c + Vector2(0, rad * 0.6), m, 2.0)
			_glow(ci, c, s * 0.05, a, state)
		"splitter":
			ci.draw_circle(c + Vector2(-rad * 0.3, 0), rad * 0.28, _fade(Color(0.80, 0.92, 1.0, 0.8), state))
			ci.draw_circle(c + Vector2(rad * 0.3, 0), rad * 0.22, _fade(Color(0.80, 0.92, 1.0, 0.8), state))
		"vat":
			for i in 5:
				var x := c.x - rad * 0.6 + i * rad * 0.3
				ci.draw_polyline(PackedVector2Array([Vector2(x, c.y + rad * 0.6), Vector2(x + rad * 0.10, c.y), Vector2(x - rad * 0.05, c.y - rad * 0.6)]), a, 2.0)
		"bunk":
			for i in 8:
				ci.draw_rect(Rect2(c + Vector2.from_angle(i * TAU / 8.0) * rad * 0.62 - Vector2(s * 0.03, s * 0.03), Vector2(s * 0.06, s * 0.06)), a)
		"cutter":
			var hub := c + Vector2(-rad * 0.1, -rad * 0.1)
			ci.draw_arc(hub, rad * 0.5, 0, TAU, 24, a, 2.0)
			for i in 8:
				ci.draw_line(hub, hub + Vector2.from_angle(i * TAU / 8.0) * rad * 0.5, m, 2.0)
		"forge":
			ci.draw_circle(c + Vector2(rad * 0.35, -rad * 0.35), rad * 0.22, md)
			ci.draw_circle(c + Vector2(rad * 0.35, -rad * 0.35), rad * 0.12, Color(0.05, 0.05, 0.05, a.a))
			_glow(ci, c + Vector2(-rad * 0.15, rad * 0.15), rad * 0.28, a, state)
		"rail":
			_glow(ci, c + Vector2(s * 0.42, 0), s * 0.05, a, state)
		"commons":
			for p in [Vector2(-0.3, -0.25), Vector2(0.32, -0.1), Vector2(0, 0.35), Vector2(-0.28, 0.25)]:
				ci.draw_circle(c + p * rad, rad * 0.20, a)
		"clinic":
			ci.draw_rect(Rect2(c - Vector2(rad * 0.14, rad * 0.5), Vector2(rad * 0.28, rad * 1.0)), a)
			ci.draw_rect(Rect2(c - Vector2(rad * 0.5, rad * 0.14), Vector2(rad * 1.0, rad * 0.28)), a)
		"cache":
			for i in 4:
				ci.draw_rect(Rect2(c + Vector2((i % 2) * rad * 0.5 - rad * 0.48, (i / 2) * rad * 0.5 - rad * 0.48), Vector2(rad * 0.44, rad * 0.44)), md.lightened(0.2))
		"lab":
			ci.draw_rect(Rect2(c - Vector2(rad * 0.08, rad * 0.86), Vector2(rad * 0.16, rad * 1.72)), md)
			ci.draw_line(c, c + Vector2(rad * 0.6, -rad * 0.6), a, 3.0)
			_glow(ci, c + Vector2(rad * 0.6, -rad * 0.6), s * 0.04, a, state)
		"workshop":
			ci.draw_line(c + Vector2(-rad * 0.7, -rad * 0.2), c + Vector2(rad * 0.7, -rad * 0.2), m, 3.0)
			ci.draw_rect(Rect2(c + Vector2(rad * 0.1, -rad * 0.32), Vector2(rad * 0.24, rad * 0.24)), a)
		"warden":
			ci.draw_circle(c, rad * 0.45, md)
			_glow(ci, c, rad * 0.30, a, state)
			ci.draw_line(c, c + Vector2(s * 0.42, -s * 0.18), Color(a.r, a.g, a.b, 0.45 * a.a), s * 0.08)
		"shaft":
			ci.draw_rect(Rect2(c - Vector2(rad * 0.55, rad * 0.55), Vector2(rad * 1.1, rad * 1.1)), Color(0.02, 0.02, 0.04, a.a))
			for i in 3:
				ci.draw_line(c + Vector2(-rad * 0.4, -rad * 0.3 + i * rad * 0.3), c + Vector2(rad * 0.4, -rad * 0.3 + i * rad * 0.3), a, 2.0)
		"shaft_base":
			ci.draw_circle(c, rad * 0.4, Color(0.02, 0.02, 0.04, a.a))
			for i in 4:
				_glow(ci, c + Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * rad * 0.62, s * 0.03, a, state)
	if not state.get("built", true):
		ci.draw_arc(c, rad, 0, TAU, 32, Color(acc.r, acc.g, acc.b, 0.8), 1.5)


## A Heat Main tile: a pressurised tunnel toward each linked neighbour.
static func _top_tunnel(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var a := _fade(ORANGE, state)
	for d in links:
		var dir := Vector2(d)
		var side := Vector2(-dir.y, dir.x)
		var to := c + dir * s * 0.5
		ci.draw_colored_polygon(PackedVector2Array([c + side * s * 0.12, to + side * s * 0.12, to - side * s * 0.12, c - side * s * 0.12]), md)
		ci.draw_line(c, to, m, s * 0.10)
		ci.draw_line(c, to, Color(a.r, a.g, a.b, 0.7 * a.a), s * 0.03)
		for k in 2:
			var p := c + dir * s * (0.18 + k * 0.18)
			ci.draw_line(p + side * s * 0.13, p - side * s * 0.13, md.darkened(0.3), 2.0)
	ci.draw_circle(c, s * 0.14, m)
	ci.draw_circle(c, s * 0.08, md)


# ============================================================ isometric

## Ground point at (u, v) within the tile (each -0.5..0.5), raised by h tile-widths.
static func _iso(c: Vector2, tw: float, u: float, v: float, h: float = 0.0) -> Vector2:
	return c + Vector2((u - v) * tw * 0.5, (u + v) * tw * 0.25 - h * tw)


## An upright box from (u0, v0) to (u1, v1), height h (tile widths), raised by z.
static func _box(ci: CanvasItem, c: Vector2, tw: float, u0: float, v0: float, u1: float, v1: float, h: float, col: Color, top: Color = Color(0, 0, 0, 0), z: float = 0.0) -> void:
	var right := PackedVector2Array([_iso(c, tw, u1, v0, z), _iso(c, tw, u1, v1, z), _iso(c, tw, u1, v1, z + h), _iso(c, tw, u1, v0, z + h)])
	var left := PackedVector2Array([_iso(c, tw, u0, v1, z), _iso(c, tw, u1, v1, z), _iso(c, tw, u1, v1, z + h), _iso(c, tw, u0, v1, z + h)])
	var lid := PackedVector2Array([_iso(c, tw, u0, v0, z + h), _iso(c, tw, u1, v0, z + h), _iso(c, tw, u1, v1, z + h), _iso(c, tw, u0, v1, z + h)])
	ci.draw_colored_polygon(right, col.darkened(0.25))
	ci.draw_colored_polygon(left, col.darkened(0.45))
	ci.draw_colored_polygon(lid, top if top.a > 0.0 else col.lightened(0.15))


## An upright cylinder at (u, v) with radius r and height h (tile widths), raised by z.
static func _cyl(ci: CanvasItem, c: Vector2, tw: float, u: float, v: float, r: float, h: float, col: Color, top: Color = Color(0, 0, 0, 0), z: float = 0.0) -> void:
	var base := _iso(c, tw, u, v, z)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	var body := PackedVector2Array()
	body.append_array(_ellipse(base, rx, ry, 0, 180, 14))
	body.append_array(_ellipse(base - Vector2(0, h * tw), rx, ry, 180, 0, 14))
	ci.draw_colored_polygon(body, col.darkened(0.3))
	ci.draw_colored_polygon(_ellipse(base - Vector2(0, h * tw), rx, ry), top if top.a > 0.0 else col.lightened(0.1))


## A dome: metal base ring, interior colour, then the glass shell with ribs.
static func _iso_dome(ci: CanvasItem, c: Vector2, tw: float, r: float, h: float, acc: Color, inside: Color, state: Dictionary) -> void:
	var base := _iso(c, tw, 0, 0, 0.0)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	ci.draw_colored_polygon(_ellipse(base + Vector2(rx * 0.12, ry * 0.25), rx * 1.08, ry * 1.08), Color(0, 0, 0, 0.25 * _fade(Color.WHITE, state).a))
	_cyl(ci, c, tw, 0, 0, r, 0.05, _fade(METAL_DARK, state), _fade(METAL, state))
	var top := base - Vector2(0, 0.05 * tw)
	var shell := _ellipse(top, rx, ry, 0, 180, 16)
	shell.append_array(_ellipse(top, rx, h * tw, 180, 360, 20))
	ci.draw_colored_polygon(shell, _fade(inside, state))
	ci.draw_polyline(_ellipse(top, rx * 0.98, ry * 0.98, 0, 180, 16), _fade(acc, state), maxf(1.5, tw * 0.012))
	var glass := _fade(GLASS, state)
	ci.draw_colored_polygon(shell, Color(glass.r, glass.g, glass.b, glass.a * 0.6))
	var rib := _fade(Color(0.80, 0.86, 0.94, 0.40), state)
	for k in [0.35, 0.7]:
		ci.draw_polyline(_ellipse(top, rx * k, h * tw, 180, 360, 14), rib, 1.0)
	ci.draw_polyline(_ellipse(top - Vector2(0, h * tw * 0.45), rx * 0.88, ry * 0.88, 180, 360, 16), rib, 1.0)
	ci.draw_arc(top - Vector2(rx * 0.32, h * tw * 0.58), rx * 0.30, deg_to_rad(190), deg_to_rad(250), 6, Color(1, 1, 1, 0.6 * _fade(Color.WHITE, state).a), 2.0)


## A tunnel along one axis from the dome's edge to the tile edge, with an airlock.
static func _iso_link(ci: CanvasItem, c: Vector2, tw: float, d: Vector2i, r: float, state: Dictionary) -> void:
	var dv := Vector2(d)
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var amber := _fade(AMBER, state)
	var a0 := r * 0.8
	var orange := _fade(ORANGE, state)
	var stripe := Color(orange.r, orange.g, orange.b, 0.85 * orange.a)
	if dv.x != 0:
		var lo := minf(dv.x * a0, dv.x * 0.5)
		var hi := maxf(dv.x * a0, dv.x * 0.5)
		_box(ci, c, tw, lo, -0.10, hi, 0.10, 0.12, md, m)
		ci.draw_line(_iso(c, tw, lo, 0, 0.12), _iso(c, tw, hi, 0, 0.12), stripe, 2.5)
		var l0 := dv.x * (r + 0.02) - 0.06
		_box(ci, c, tw, l0, -0.12, l0 + 0.12, 0.12, 0.15, m, m.lightened(0.15))
		ci.draw_line(_iso(c, tw, l0 + 0.12, -0.10, 0.04), _iso(c, tw, l0 + 0.12, 0.10, 0.04), amber, 2.0)
		ci.draw_line(_iso(c, tw, l0 + 0.12, -0.10, 0.11), _iso(c, tw, l0 + 0.12, 0.10, 0.11), amber, 2.0)
	else:
		var lo := minf(dv.y * a0, dv.y * 0.5)
		var hi := maxf(dv.y * a0, dv.y * 0.5)
		_box(ci, c, tw, -0.10, lo, 0.10, hi, 0.12, md, m)
		ci.draw_line(_iso(c, tw, 0, lo, 0.12), _iso(c, tw, 0, hi, 0.12), stripe, 2.5)
		var l0 := dv.y * (r + 0.02) - 0.06
		_box(ci, c, tw, -0.12, l0, 0.12, l0 + 0.12, 0.15, m, m.lightened(0.15))
		ci.draw_line(_iso(c, tw, -0.10, l0 + 0.12, 0.04), _iso(c, tw, 0.10, l0 + 0.12, 0.04), amber, 2.0)
		ci.draw_line(_iso(c, tw, -0.10, l0 + 0.12, 0.11), _iso(c, tw, 0.10, l0 + 0.12, 0.11), amber, 2.0)


## Draws building `type` on the diamond tile centred at `c`, `tw` pixels wide.
static func draw_iso(ci: CanvasItem, type: String, c: Vector2, tw: float, state: Dictionary = {}) -> void:
	var acc: Color = ACCENT.get(type, CYAN)
	var a := _fade(acc, state)
	var m := _fade(METAL, state)
	var md := _fade(METAL_DARK, state)
	var links := _links(type, state)
	if type == "main":
		_iso_tunnel(ci, c, tw, links, state)
		return
	var r: float = float(DOME_SIZE.get(type, 0.38))
	var h := r * 0.75
	# Tunnels toward the back go behind the dome; toward the front, in front of it.
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	# Fittings behind or beside the dome.
	match type:
		"mirror":
			for u in [-0.36, 0.36]:
				ci.draw_line(_iso(c, tw, u, 0), _iso(c, tw, u, 0, 0.12), md, tw * 0.02)
				var panel := PackedVector2Array([_iso(c, tw, u - 0.10, -0.40, 0.08), _iso(c, tw, u + 0.10, -0.40, 0.08), _iso(c, tw, u + 0.10, 0.40, 0.24), _iso(c, tw, u - 0.10, 0.40, 0.24)])
				ci.draw_colored_polygon(panel, _fade(Color(0.45, 0.78, 1.0), state))
				ci.draw_polyline(PackedVector2Array([panel[0], panel[1], panel[2], panel[3], panel[0]]), md, 1.5)
		"splitter":
			for v in [-0.34, 0.0]:
				_cyl(ci, c, tw, 0.34, v - 0.04, 0.10, 0.22, m, m)
				_iso_sphere(ci, _iso(c, tw, 0.34, v - 0.04, 0.32), tw * 0.08, _fade(Color(0.85, 0.95, 1.0), state))
		"drill":
			_cyl(ci, c, tw, -0.30, 0.30, 0.13, 0.26, _fade(Color(0.25, 0.45, 0.75), state), a.darkened(0.2))
	_iso_dome(ci, c, tw, r, h, acc, INTERIOR.get(type, Color(0.26, 0.28, 0.32)), state)
	var apex := _iso(c, tw, 0, 0, 0.05 + h)
	# Features on or through the dome.
	match type:
		"hull":
			ci.draw_line(apex, apex - Vector2(0, tw * 0.22), m, tw * 0.02)
			_glow(ci, apex - Vector2(0, tw * 0.22), tw * 0.03, a, state)
			_glow(ci, _iso(c, tw, 0, 0, 0.18), tw * 0.06, a, state)
		"mirror":
			_glow(ci, apex, tw * 0.025, a, state)
		"vent":
			_cyl(ci, c, tw, 0.10, -0.10, 0.07, 0.30, md, Color(0.06, 0.04, 0.03, a.a), h * 0.6)
			if _lit(state):
				for i in 3:
					ci.draw_circle(_iso(c, tw, 0.10, -0.10, h * 0.6 + 0.38 + i * 0.10) + Vector2(i * tw * 0.03, 0), tw * (0.05 + i * 0.02), Color(0.9, 0.9, 0.95, 0.22 - i * 0.06))
			_glow(ci, _iso(c, tw, 0, 0, 0.12), tw * 0.06, a, state)
		"drill":
			for k in [Vector2(-0.12, -0.12), Vector2(0.12, -0.12), Vector2(0.0, 0.12)]:
				ci.draw_line(_iso(c, tw, k.x, k.y, h * 0.8), apex - Vector2(0, tw * 0.40), m, tw * 0.015)
			_glow(ci, apex - Vector2(0, tw * 0.40), tw * 0.025, a, state)
		"splitter":
			_glow(ci, _iso(c, tw, 0, 0, 0.16), tw * 0.05, a, state)
		"vat":
			for i in 5:
				var u := -0.20 + i * 0.10
				ci.draw_polyline(PackedVector2Array([_iso(c, tw, u, 0.18, 0.06), _iso(c, tw, u + 0.03, 0.18, 0.16), _iso(c, tw, u - 0.02, 0.18, 0.26)]), a, 2.0)
		"bunk":
			for i in 6:
				var ang := deg_to_rad(15 + i * 30)
				ci.draw_rect(Rect2(_iso(c, tw, 0, 0, 0.12) + Vector2(cos(ang) * r * tw * 0.62, sin(ang) * r * tw * 0.20) - Vector2(tw * 0.02, tw * 0.02), Vector2(tw * 0.04, tw * 0.035)), a)
		"cutter":
			var hub := apex + Vector2(tw * 0.14, -tw * 0.06)
			ci.draw_line(apex, hub, m, tw * 0.03)
			ci.draw_colored_polygon(_ellipse(hub, tw * 0.10, tw * 0.10), m)
			for i in 8:
				ci.draw_line(hub, hub + Vector2.from_angle(i * TAU / 8.0) * tw * 0.12, md, 2.0)
			ci.draw_arc(hub, tw * 0.10, 0, TAU, 20, a, 2.0)
		"forge":
			_cyl(ci, c, tw, -0.10, -0.10, 0.07, 0.40, md, Color(0.05, 0.05, 0.05, a.a), h * 0.5)
			var mouth := _iso(c, tw, 0.05, r * 0.9, 0.10)
			ci.draw_colored_polygon(_ellipse(mouth, tw * 0.07, tw * 0.05, 180, 360, 10), a)
			_glow(ci, mouth, tw * 0.04, a, state)
		"rail":
			# The launch ramp leaves the dome toward the viewer, so it goes in front.
			var ramp := PackedVector2Array([_iso(c, tw, r * 0.6, -0.13, 0.05), _iso(c, tw, 0.50, -0.13, 0.36), _iso(c, tw, 0.50, 0.13, 0.36), _iso(c, tw, r * 0.6, 0.13, 0.05)])
			ci.draw_colored_polygon(ramp, md)
			ci.draw_line(_iso(c, tw, r * 0.6, -0.07, 0.06), _iso(c, tw, 0.50, -0.07, 0.37), a, 2.0)
			ci.draw_line(_iso(c, tw, r * 0.6, 0.07, 0.06), _iso(c, tw, 0.50, 0.07, 0.37), a, 2.0)
			_glow(ci, _iso(c, tw, 0.47, 0, 0.36), tw * 0.035, a, state)
		"commons":
			for p in [Vector2(-0.12, 0.05), Vector2(0.12, -0.06), Vector2(0.0, 0.14)]:
				ci.draw_circle(_iso(c, tw, p.x, p.y, 0.14), tw * 0.05, a)
		"clinic":
			var mid := _iso(c, tw, 0, 0, 0.05 + h * 0.55)
			ci.draw_rect(Rect2(mid - Vector2(tw * 0.025, tw * 0.07), Vector2(tw * 0.05, tw * 0.14)), a)
			ci.draw_rect(Rect2(mid - Vector2(tw * 0.07, tw * 0.025), Vector2(tw * 0.14, tw * 0.05)), a)
		"cache":
			ci.draw_rect(Rect2(_iso(c, tw, 0.05, 0.20, 0.10) - Vector2(tw * 0.06, tw * 0.04), Vector2(tw * 0.12, tw * 0.08)), md.lightened(0.2))
			ci.draw_rect(Rect2(_iso(c, tw, 0.05, 0.20, 0.10) - Vector2(tw * 0.06, tw * 0.04), Vector2(tw * 0.12, tw * 0.08)), a, false, 1.5)
		"lab":
			var slit := PackedVector2Array([apex + Vector2(-tw * 0.03, 0), apex + Vector2(tw * 0.03, 0), _iso(c, tw, 0.0, 0.30, 0.10) + Vector2(tw * 0.03, 0), _iso(c, tw, 0.0, 0.30, 0.10) + Vector2(-tw * 0.03, 0)])
			ci.draw_colored_polygon(slit, md)
			ci.draw_line(apex, apex + Vector2(tw * 0.14, -tw * 0.20), a, 3.0)
			_glow(ci, apex + Vector2(tw * 0.14, -tw * 0.20), tw * 0.025, a, state)
		"workshop":
			ci.draw_line(_iso(c, tw, 0.30, -0.30, 0.0), _iso(c, tw, 0.30, -0.30, 0.62), md, tw * 0.025)
			ci.draw_line(_iso(c, tw, 0.30, -0.30, 0.62), _iso(c, tw, -0.10, -0.30, 0.62), md, tw * 0.025)
			ci.draw_line(_iso(c, tw, -0.10, -0.30, 0.62), _iso(c, tw, -0.10, -0.30, 0.42), a, 2.0)
		"warden":
			_cyl(ci, c, tw, 0, 0, 0.09, 0.32, md, m, h)
			_glow(ci, _iso(c, tw, 0, 0, h + 0.36), tw * 0.05, a, state)
		"shaft":
			for corner in [Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2(0.22, 0.22), Vector2(-0.22, 0.22)]:
				ci.draw_line(_iso(c, tw, corner.x, corner.y, 0.05), _iso(c, tw, corner.x * 0.4, corner.y * 0.4, h + 0.25), m, tw * 0.018)
			_glow(ci, _iso(c, tw, 0, 0, h + 0.27), tw * 0.03, a, state)
		"shaft_base":
			for i in 4:
				var q := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * 0.22
				_glow(ci, _iso(c, tw, q.x, q.y, 0.07), tw * 0.02, a, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	# The two sides facing the viewer show their orange ports: a capped one where
	# there's no tunnel, an open ring where a tunnel's airlock joins.
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.86, d.y * r * 0.86, 0.12), tw, state, true)


## A port on the dome's side, seen at an angle: an orange ring, capped or open.
static func _iso_port(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary, capped: bool) -> void:
	var orange := _fade(ORANGE, state)
	ci.draw_colored_polygon(_ellipse(p, tw * 0.055, tw * 0.045), _fade(METAL_DARK, state))
	ci.draw_colored_polygon(_ellipse(p, tw * 0.033, tw * 0.027), _fade(METAL, state) if capped else Color(0.03, 0.02, 0.02, orange.a))
	ci.draw_polyline(_ellipse(p, tw * 0.05, tw * 0.04), orange, 2.0)
	if capped:
		ci.draw_circle(p, tw * 0.01, orange)


static func _iso_sphere(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(p, rad, col.darkened(0.25))
	ci.draw_circle(p - Vector2(rad * 0.25, rad * 0.25), rad * 0.6, col)


## A Heat Main tile: tunnel segments toward each linked neighbour.
static func _iso_tunnel(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var a := _fade(ORANGE, state)
	var ordered: Array = []
	for d in links:
		if d.x < 0 or d.y < 0:
			ordered.push_front(d)
		else:
			ordered.append(d)
	for d in ordered:
		var dv := Vector2(d)
		if dv.x != 0:
			_box(ci, c, tw, minf(0.0, dv.x * 0.5), -0.10, maxf(0.0, dv.x * 0.5), 0.10, 0.12, md, m)
			ci.draw_line(_iso(c, tw, 0, 0, 0.12), _iso(c, tw, dv.x * 0.5, 0, 0.12), Color(a.r, a.g, a.b, 0.7 * a.a), 2.0)
		else:
			_box(ci, c, tw, -0.10, minf(0.0, dv.y * 0.5), 0.10, maxf(0.0, dv.y * 0.5), 0.12, md, m)
			ci.draw_line(_iso(c, tw, 0, 0, 0.12), _iso(c, tw, 0, dv.y * 0.5, 0.12), Color(a.r, a.g, a.b, 0.7 * a.a), 2.0)
	_cyl(ci, c, tw, 0, 0, 0.14, 0.15, md, m)


# ============================================================ terrain

const TERRAIN := {
	"regolith": Color(0.40, 0.35, 0.31), "ice": Color(0.66, 0.79, 0.88), "vent": Color(0.32, 0.25, 0.23),
	"seam": Color(0.36, 0.33, 0.30), "ridge": Color(0.17, 0.17, 0.19), "deepice": Color(0.82, 0.90, 0.97),
	"scorch": Color(0.56, 0.31, 0.17), "rock": Color(0.24, 0.21, 0.20), "cavern": Color(0.36, 0.31, 0.27),
	"vein": Color(0.24, 0.21, 0.20), "aquifer": Color(0.20, 0.30, 0.40), "deepvent": Color(0.30, 0.18, 0.15),
	"bedrock": Color(0.09, 0.08, 0.09),
}


static func _terrain_marks(ci: CanvasItem, t: String, at: Vector2, s: float) -> void:
	match t:
		"vent", "deepvent":
			ci.draw_circle(at, s * 0.16, Color(1.0, 0.45, 0.15, 0.85))
			ci.draw_circle(at, s * 0.08, Color(1.0, 0.88, 0.45))
		"seam", "vein":
			ci.draw_line(at + Vector2(-s * 0.3, -s * 0.1), at + Vector2(s * 0.3, s * 0.08), Color(0.30, 0.80, 0.75), 2.0)
			ci.draw_line(at + Vector2(-s * 0.2, s * 0.15), at + Vector2(s * 0.15, s * 0.02), Color(0.30, 0.80, 0.75), 2.0)
		"aquifer":
			ci.draw_circle(at, s * 0.14, Color(0.45, 0.72, 1.0, 0.8))
		"ice", "deepice":
			ci.draw_line(at + Vector2(-s * 0.2, s * 0.1), at + Vector2(s * 0.1, -s * 0.12), Color(1, 1, 1, 0.45), 1.5)


static func terrain_top(ci: CanvasItem, t: String, r: Rect2) -> void:
	ci.draw_rect(r, TERRAIN.get(t, Color.MAGENTA))
	if t == "ridge" or t == "bedrock":
		ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.12, r.size.y * 0.85), r.get_center() + Vector2(0, -r.size.y * 0.32), r.position + Vector2(r.size.x * 0.88, r.size.y * 0.85)]), Color(0.30, 0.30, 0.33))
	_terrain_marks(ci, t, r.get_center(), r.size.x)


static func terrain_iso(ci: CanvasItem, t: String, c: Vector2, tw: float) -> void:
	var col: Color = TERRAIN.get(t, Color.MAGENTA)
	var diamond := PackedVector2Array([_iso(c, tw, -0.5, -0.5), _iso(c, tw, 0.5, -0.5), _iso(c, tw, 0.5, 0.5), _iso(c, tw, -0.5, 0.5)])
	ci.draw_colored_polygon(diamond, col)
	ci.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0, 0, 0, 0.18), 1.0)
	if t == "ridge" or t == "bedrock":
		_box(ci, c, tw, -0.30, -0.30, 0.30, 0.30, 0.22, Color(0.30, 0.30, 0.33))
	_terrain_marks(ci, t, c, tw * 0.6)
