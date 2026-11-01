## Building and terrain art for Lastborn Colony, drawn in code (no image files).
## Every building has its own silhouette, in two styles:
##   draw_top(): seen from straight above, for the square top-down map.
##   draw_iso(): seen at an angle ("isometric"), for a diamond-tile map.
## Style: dark metal, glass roofs, and a glowing accent colour per building
## group (energy cyan/gold, life support green/teal, industry orange, civic
## violet). Everything here is original.
##
## `state` (optional): {"built": bool, "active": bool, "links": Array}.
## Unbuilt buildings are drawn faint; idle ones are dimmed. "links" (for Heat
## Mains) lists the neighbouring directions it connects to, as Vector2i
## (1,0), (-1,0), (0,1), (0,-1); without it a main is drawn as a cross.
extends RefCounted

const METAL := Color(0.42, 0.45, 0.50)
const METAL_DARK := Color(0.22, 0.24, 0.28)
const GLASS := Color(0.62, 0.85, 0.95, 0.55)
const CYAN := Color(0.35, 0.90, 1.00)
const GOLD := Color(1.00, 0.78, 0.35)
const ORANGE := Color(1.00, 0.55, 0.20)
const GREEN := Color(0.40, 0.95, 0.55)
const TEAL := Color(0.30, 0.80, 0.75)
const VIOLET := Color(0.70, 0.55, 1.00)
const WHITE := Color(0.90, 0.93, 0.96)
const WATER := Color(0.35, 0.65, 1.00)

const ACCENT := {
	"hull": ORANGE, "main": ORANGE, "shaft": ORANGE, "shaft_base": ORANGE,
	"mirror": CYAN, "vent": GOLD, "drill": WATER, "splitter": CYAN, "vat": GREEN, "bunk": GOLD,
	"cutter": TEAL, "forge": ORANGE, "rail": GOLD,
	"commons": GREEN, "clinic": TEAL, "cache": GOLD, "lab": VIOLET, "workshop": CYAN, "warden": VIOLET,
}


# ============================================================ helpers

static func _fade(c: Color, state: Dictionary) -> Color:
	if not state.get("built", true):
		return Color(c.r, c.g, c.b, c.a * 0.35)
	if not state.get("active", true):
		return c.darkened(0.45)
	return c


static func _ellipse(center: Vector2, rx: float, ry: float, from_deg: float = 0.0, to_deg: float = 360.0, steps: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _glow(ci: CanvasItem, p: Vector2, r: float, c: Color, state: Dictionary) -> void:
	if not state.get("built", true) or not state.get("active", true):
		return
	for i in 3:
		ci.draw_circle(p, r * (1.0 + i * 0.6), Color(c.r, c.g, c.b, 0.18 / (i + 1)))
	ci.draw_circle(p, r * 0.5, Color(c.r, c.g, c.b, 0.9))


# ============================================================ top-down

## Draws building `type` filling `r` (one map tile), seen from above.
static func draw_top(ci: CanvasItem, type: String, r: Rect2, state: Dictionary = {}) -> void:
	var s := r.size.x
	var c := r.get_center()
	var acc: Color = ACCENT.get(type, CYAN)
	var m := _fade(METAL, state)
	var md := _fade(METAL_DARK, state)
	var g := _fade(GLASS, state)
	var a := _fade(acc, state)
	var inner := r.grow(-s * 0.08)
	# Soft shadow so buildings sit on the ground.
	if type != "main":
		ci.draw_rect(Rect2(inner.position + Vector2(s * 0.05, s * 0.06), inner.size), Color(0, 0, 0, 0.25 * a.a))
	match type:
		"hull":
			var body := PackedVector2Array([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.22, -s * 0.18), c + Vector2(s * 0.24, s * 0.30), c + Vector2(-s * 0.24, s * 0.30), c + Vector2(-s * 0.22, -s * 0.18)])
			ci.draw_colored_polygon(body, m)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.24, s * 0.08), c + Vector2(-s * 0.42, s * 0.40), c + Vector2(-s * 0.20, s * 0.30)]), md)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.24, s * 0.08), c + Vector2(s * 0.42, s * 0.40), c + Vector2(s * 0.20, s * 0.30)]), md)
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, -s * 0.14), s * 0.10, s * 0.14), g)
			_glow(ci, c + Vector2(0, s * 0.34), s * 0.07, a, state)
		"main":
			for d in state.get("links", [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]):
				var dir := Vector2(d)
				var side := Vector2(-dir.y, dir.x)
				var arm := PackedVector2Array([c + side * s * 0.10, c + side * s * 0.10 + dir * s * 0.5, c - side * s * 0.10 + dir * s * 0.5, c - side * s * 0.10])
				ci.draw_colored_polygon(arm, md)
				ci.draw_line(c, c + dir * s * 0.5, a, s * 0.08)
			ci.draw_colored_polygon(_ellipse(c, s * 0.14, s * 0.14), m)
			_glow(ci, c, s * 0.05, a, state)
		"shaft":
			ci.draw_rect(inner, md)
			ci.draw_rect(inner.grow(-s * 0.12), Color(0.02, 0.02, 0.04, a.a))
			for i in 4:
				var y := inner.position.y + s * (0.22 + 0.15 * i)
				ci.draw_line(Vector2(c.x - s * 0.2, y), Vector2(c.x + s * 0.2, y), a, 2.0)
			ci.draw_rect(inner, a, false, 2.0)
		"shaft_base":
			ci.draw_colored_polygon(_ellipse(c, s * 0.40, s * 0.40), md)
			ci.draw_arc(c, s * 0.40, 0, TAU, 32, a, 2.0)
			ci.draw_colored_polygon(_ellipse(c, s * 0.18, s * 0.18), Color(0.02, 0.02, 0.04, a.a))
			for i in 4:
				_glow(ci, c + Vector2.from_angle(i * TAU / 4.0) * s * 0.30, s * 0.04, a, state)
		"mirror":
			for i in 3:
				var p := inner.position + Vector2(s * 0.04, s * (0.04 + i * 0.28))
				var panel := PackedVector2Array([p, p + Vector2(s * 0.76, 0), p + Vector2(s * 0.70, s * 0.22), p + Vector2(-s * 0.06, s * 0.22)])
				ci.draw_colored_polygon(panel, md)
				ci.draw_colored_polygon(PackedVector2Array([panel[0] + Vector2(s * 0.04, s * 0.03), panel[1] + Vector2(-s * 0.04, s * 0.03), panel[2] + Vector2(-s * 0.04, -s * 0.03), panel[3] + Vector2(s * 0.04, -s * 0.03)]), _fade(Color(0.55, 0.85, 1.0), state))
				ci.draw_line(panel[0] + Vector2(s * 0.10, s * 0.05), panel[1] + Vector2(-s * 0.30, s * 0.05), Color(1, 1, 1, 0.6 * a.a), 1.5)
		"vent":
			ci.draw_colored_polygon(_ellipse(c, s * 0.38, s * 0.38), md)
			ci.draw_colored_polygon(_ellipse(c, s * 0.26, s * 0.26), m)
			ci.draw_colored_polygon(_ellipse(c, s * 0.14, s * 0.14), Color(0.05, 0.03, 0.02, a.a))
			_glow(ci, c, s * 0.10, a, state)
			for i in 6:
				ci.draw_line(c + Vector2.from_angle(i * TAU / 6.0) * s * 0.27, c + Vector2.from_angle(i * TAU / 6.0) * s * 0.38, md.darkened(0.3), 2.0)
		"drill":
			ci.draw_rect(Rect2(inner.position, Vector2(s * 0.5, s * 0.5)), md)
			ci.draw_line(inner.position, inner.position + Vector2(s * 0.5, s * 0.5), m, 2.0)
			ci.draw_line(inner.position + Vector2(s * 0.5, 0), inner.position + Vector2(0, s * 0.5), m, 2.0)
			ci.draw_circle(inner.position + Vector2(s * 0.25, s * 0.25), s * 0.07, a)
			ci.draw_colored_polygon(_ellipse(c + Vector2(s * 0.18, s * 0.18), s * 0.22, s * 0.22), _fade(Color(0.25, 0.45, 0.75), state))
			ci.draw_colored_polygon(_ellipse(c + Vector2(s * 0.15, s * 0.14), s * 0.13, s * 0.13), Color(a.r, a.g, a.b, 0.6 * a.a))
		"splitter":
			ci.draw_rect(Rect2(c - Vector2(s * 0.30, s * 0.05), Vector2(s * 0.60, s * 0.10)), md)
			for side in [-1.0, 1.0]:
				var p: Vector2 = c + Vector2(side * s * 0.22, 0)
				ci.draw_colored_polygon(_ellipse(p, s * 0.2, s * 0.2), m)
				ci.draw_colored_polygon(_ellipse(p + Vector2(-s * 0.05, -s * 0.05), s * 0.10, s * 0.10), _fade(Color(0.85, 0.95, 1.0, 0.8), state))
			_glow(ci, c, s * 0.06, a, state)
		"vat":
			ci.draw_rect(inner, md)
			ci.draw_rect(inner.grow(-s * 0.06), _fade(Color(0.08, 0.30, 0.22), state))
			for i in 4:
				var x := inner.position.x + s * (0.16 + 0.18 * i)
				ci.draw_polyline(PackedVector2Array([Vector2(x, inner.end.y - s * 0.1), Vector2(x + s * 0.05, c.y), Vector2(x - s * 0.03, inner.position.y + s * 0.15)]), a, 2.0)
			ci.draw_rect(inner.grow(-s * 0.06), g)
		"bunk":
			var body := Rect2(r.position + Vector2(s * 0.06, s * 0.22), Vector2(s * 0.88, s * 0.56))
			ci.draw_rect(body, m)
			ci.draw_rect(body.grow(-s * 0.06), g)
			for i in 4:
				ci.draw_rect(Rect2(body.position + Vector2(s * (0.08 + 0.2 * i), s * 0.2), Vector2(s * 0.12, s * 0.12)), a)
		"cutter":
			ci.draw_rect(Rect2(inner.position + Vector2(0, s * 0.5), Vector2(s * 0.84, s * 0.3)), md)
			ci.draw_line(c + Vector2(0, s * 0.2), c + Vector2(-s * 0.08, -s * 0.2), m, s * 0.08)
			var hub := c + Vector2(-s * 0.08, -s * 0.2)
			ci.draw_colored_polygon(_ellipse(hub, s * 0.2, s * 0.2), m)
			for i in 8:
				ci.draw_line(hub, hub + Vector2.from_angle(i * TAU / 8.0) * s * 0.24, md, 2.0)
			ci.draw_arc(hub, s * 0.2, 0, TAU, 24, a, 2.0)
		"forge":
			ci.draw_rect(inner, md)
			ci.draw_rect(Rect2(inner.position + Vector2(s * 0.12, s * 0.12), Vector2(s * 0.40, s * 0.40)), m)
			ci.draw_colored_polygon(_ellipse(inner.end - Vector2(s * 0.18, s * 0.18), s * 0.14, s * 0.14), m.darkened(0.2))
			ci.draw_colored_polygon(_ellipse(inner.end - Vector2(s * 0.18, s * 0.18), s * 0.08, s * 0.08), Color(0.05, 0.05, 0.05, a.a))
			_glow(ci, inner.position + Vector2(s * 0.32, s * 0.32), s * 0.12, a, state)
		"rail":
			ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.30), Vector2(s, s * 0.40)), md)
			ci.draw_line(r.position + Vector2(0, s * 0.38), r.position + Vector2(s, s * 0.38), a, 2.0)
			ci.draw_line(r.position + Vector2(0, s * 0.62), r.position + Vector2(s, s * 0.62), a, 2.0)
			ci.draw_rect(Rect2(c + Vector2(s * 0.05, -s * 0.10), Vector2(s * 0.30, s * 0.20)), m)
			_glow(ci, c + Vector2(s * 0.40, 0), s * 0.06, a, state)
		"commons":
			ci.draw_colored_polygon(_ellipse(c, s * 0.42, s * 0.42), md)
			ci.draw_colored_polygon(_ellipse(c, s * 0.36, s * 0.36), _fade(Color(0.15, 0.40, 0.22), state))
			for p in [Vector2(-0.12, -0.1), Vector2(0.14, -0.05), Vector2(0, 0.15)]:
				ci.draw_circle(c + p * s, s * 0.09, a)
			ci.draw_colored_polygon(_ellipse(c, s * 0.36, s * 0.36), g)
			ci.draw_arc(c, s * 0.36, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.6 * a.a), 2.0)
		"clinic":
			ci.draw_rect(inner, _fade(WHITE, state))
			ci.draw_rect(inner, m, false, 2.0)
			ci.draw_rect(Rect2(c - Vector2(s * 0.07, s * 0.24), Vector2(s * 0.14, s * 0.48)), a)
			ci.draw_rect(Rect2(c - Vector2(s * 0.24, s * 0.07), Vector2(s * 0.48, s * 0.14)), a)
		"cache":
			for i in 4:
				var p := inner.position + Vector2((i % 2) * s * 0.42, (i / 2) * s * 0.42)
				ci.draw_rect(Rect2(p, Vector2(s * 0.38, s * 0.38)), m if i % 3 == 0 else md.lightened(0.15))
				ci.draw_rect(Rect2(p, Vector2(s * 0.38, s * 0.38)), a, false, 1.5)
		"lab":
			ci.draw_rect(Rect2(inner.position + Vector2(0, s * 0.45), Vector2(s * 0.84, s * 0.38)), md)
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, -s * 0.05), s * 0.30, s * 0.30), m)
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, -s * 0.05), s * 0.22, s * 0.22), g)
			ci.draw_line(c + Vector2(0, -s * 0.05), c + Vector2(s * 0.28, -s * 0.35), a, 3.0)
			_glow(ci, c + Vector2(s * 0.28, -s * 0.35), s * 0.05, a, state)
		"workshop":
			ci.draw_rect(inner, m)
			for i in 5:
				ci.draw_line(inner.position + Vector2(s * (0.1 + 0.16 * i), 0), inner.position + Vector2(s * (0.1 + 0.16 * i), s * 0.84), md, 2.0)
			ci.draw_line(inner.position + Vector2(0, s * 0.2), inner.end - Vector2(0, s * 0.64), a, 3.0)
			ci.draw_rect(Rect2(c + Vector2(s * 0.12, -s * 0.24), Vector2(s * 0.12, s * 0.12)), a)
		"warden":
			ci.draw_rect(Rect2(c - Vector2(s * 0.26, s * 0.26), Vector2(s * 0.52, s * 0.52)), md)
			ci.draw_colored_polygon(_ellipse(c, s * 0.18, s * 0.18), m)
			_glow(ci, c, s * 0.10, a, state)
			ci.draw_line(c, c + Vector2(s * 0.40, -s * 0.15), Color(a.r, a.g, a.b, 0.5 * a.a), s * 0.10)
		_:
			ci.draw_rect(inner, m)
	if not state.get("built", true):
		ci.draw_rect(inner, Color(a.r, a.g, a.b, 0.8), false, 1.5)


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


static func _dome(ci: CanvasItem, c: Vector2, tw: float, u: float, v: float, r: float, h: float, col: Color, z: float = 0.0) -> void:
	var base := _iso(c, tw, u, v, z)
	var rx := r * tw * 0.72
	var pts := _ellipse(base, rx, rx * 0.5, 0, 180, 14)
	pts.append_array(_ellipse(base, rx, h * tw, 180, 360, 18))
	ci.draw_colored_polygon(pts, col)
	ci.draw_arc(base - Vector2(rx * 0.3, h * tw * 0.55), rx * 0.35, deg_to_rad(190), deg_to_rad(250), 6, Color(1, 1, 1, 0.55 * col.a), 2.0)


## Draws building `type` on the diamond tile centred at `c`, `tw` pixels wide.
static func draw_iso(ci: CanvasItem, type: String, c: Vector2, tw: float, state: Dictionary = {}) -> void:
	var acc: Color = ACCENT.get(type, CYAN)
	var m := _fade(METAL, state)
	var md := _fade(METAL_DARK, state)
	var g := _fade(GLASS, state)
	var a := _fade(acc, state)
	# Shadow on the ground.
	if type != "main":
		ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.42, -0.42), _iso(c, tw, 0.48, -0.42), _iso(c, tw, 0.48, 0.48), _iso(c, tw, -0.42, 0.48)]), Color(0, 0, 0, 0.22 * a.a))
	match type:
		"hull":
			_cyl(ci, c, tw, 0, 0, 0.30, 0.42, m)
			_dome(ci, c, tw, 0, 0, 0.30, 0.22, m.lightened(0.1), 0.42)
			_dome(ci, c, tw, 0.05, 0.05, 0.12, 0.08, g, 0.56)
			for p in [Vector2(-0.35, 0.2), Vector2(0.2, -0.35), Vector2(0.3, 0.3)]:
				ci.draw_line(_iso(c, tw, p.x, p.y), _iso(c, tw, p.x * 0.6, p.y * 0.6, 0.18), md, tw * 0.03)
			_glow(ci, _iso(c, tw, 0.2, 0.2, 0.12), tw * 0.035, a, state)
		"main":
			for d in state.get("links", [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]):
				var dv := Vector2(d)
				var u0 := minf(0.0, dv.x * 0.5) if dv.x != 0 else -0.09
				var u1 := maxf(0.0, dv.x * 0.5) if dv.x != 0 else 0.09
				var v0 := minf(0.0, dv.y * 0.5) if dv.y != 0 else -0.09
				var v1 := maxf(0.0, dv.y * 0.5) if dv.y != 0 else 0.09
				_box(ci, c, tw, u0, v0, u1, v1, 0.07, md, a)
			_cyl(ci, c, tw, 0, 0, 0.13, 0.09, m)
		"shaft":
			_box(ci, c, tw, -0.42, -0.42, 0.42, 0.42, 0.06, md)
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.28, -0.28, 0.06), _iso(c, tw, 0.28, -0.28, 0.06), _iso(c, tw, 0.28, 0.28, 0.06), _iso(c, tw, -0.28, 0.28, 0.06)]), Color(0.02, 0.02, 0.04, a.a))
			for corner in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(0.4, 0.4), Vector2(-0.4, 0.4)]:
				ci.draw_line(_iso(c, tw, corner.x, corner.y, 0.06), _iso(c, tw, corner.x, corner.y, 0.38), m, tw * 0.025)
			# The headframe: a ring of beams at the top, open in the middle.
			for e in [[-0.42, -0.42, 0.42, -0.34], [-0.42, 0.34, 0.42, 0.42], [-0.42, -0.42, -0.34, 0.42], [0.34, -0.42, 0.42, 0.42]]:
				_box(ci, c, tw, e[0], e[1], e[2], e[3], 0.03, md, a, 0.36)
		"shaft_base":
			_cyl(ci, c, tw, 0, 0, 0.42, 0.04, md, md.lightened(0.15))
			ci.draw_colored_polygon(_ellipse(_iso(c, tw, 0, 0, 0.04), tw * 0.13, tw * 0.065), Color(0.02, 0.02, 0.04, a.a))
			for i in 4:
				var q := Vector2.from_angle(i * TAU / 4.0) * 0.3
				_glow(ci, _iso(c, tw, q.x, q.y, 0.05), tw * 0.025, a, state)
		"mirror":
			for i in 3:
				var u := -0.3 + i * 0.3
				ci.draw_line(_iso(c, tw, u, 0), _iso(c, tw, u, 0, 0.12), md, tw * 0.02)
				var panel := PackedVector2Array([_iso(c, tw, u - 0.12, -0.36, 0.08), _iso(c, tw, u + 0.12, -0.36, 0.08), _iso(c, tw, u + 0.12, 0.36, 0.22), _iso(c, tw, u - 0.12, 0.36, 0.22)])
				ci.draw_colored_polygon(panel, _fade(Color(0.45, 0.78, 1.0), state))
				ci.draw_polyline(PackedVector2Array([panel[0], panel[1], panel[2], panel[3], panel[0]]), md, 1.5)
		"vent":
			_cyl(ci, c, tw, 0, 0, 0.36, 0.06, md)
			_cyl(ci, c, tw, 0, 0, 0.16, 0.36, m, Color(0.06, 0.04, 0.03, a.a), 0.06)
			_glow(ci, _iso(c, tw, 0, 0, 0.42), tw * 0.05, a, state)
			if state.get("active", true) and state.get("built", true):
				for i in 3:
					ci.draw_circle(_iso(c, tw, 0, 0, 0.55 + i * 0.12) + Vector2(i * tw * 0.03, 0), tw * (0.06 + i * 0.02), Color(0.9, 0.9, 0.95, 0.25 - i * 0.06))
		"drill":
			_box(ci, c, tw, -0.4, -0.4, 0.4, 0.4, 0.05, md)
			var top := _iso(c, tw, -0.1, -0.1, 0.75)
			for corner in [Vector2(-0.3, -0.3), Vector2(0.1, -0.3), Vector2(0.1, 0.1), Vector2(-0.3, 0.1)]:
				ci.draw_line(_iso(c, tw, corner.x, corner.y, 0.05), top, m, tw * 0.02)
			_glow(ci, top, tw * 0.03, a, state)
			_cyl(ci, c, tw, 0.24, 0.24, 0.16, 0.25, _fade(Color(0.25, 0.45, 0.75), state), a.darkened(0.2), 0.05)
		"splitter":
			_box(ci, c, tw, -0.4, -0.12, 0.4, 0.12, 0.08, md)
			for u in [-0.22, 0.22]:
				_cyl(ci, c, tw, u, 0, 0.17, 0.18, m, m, 0.08)
				_dome(ci, c, tw, u, 0, 0.17, 0.14, _fade(Color(0.80, 0.92, 1.0), state), 0.26)
			_glow(ci, _iso(c, tw, 0, 0, 0.12), tw * 0.03, a, state)
		"vat":
			_box(ci, c, tw, -0.38, -0.38, 0.38, 0.38, 0.06, md)
			_box(ci, c, tw, -0.32, -0.32, 0.32, 0.32, 0.34, _fade(Color(0.10, 0.36, 0.25), state), Color(0, 0, 0, 0), 0.06)
			for i in 4:
				var u := -0.2 + i * 0.13
				ci.draw_polyline(PackedVector2Array([_iso(c, tw, u, 0.32, 0.08), _iso(c, tw, u + 0.04, 0.32, 0.22), _iso(c, tw, u - 0.02, 0.32, 0.36)]), a, 2.0)
			_box(ci, c, tw, -0.32, -0.32, 0.32, 0.32, 0.34, g, Color(g.r, g.g, g.b, 0.25), 0.06)
		"bunk":
			_box(ci, c, tw, -0.44, -0.24, 0.44, 0.30, 0.26, m)
			for i in 4:
				var u := -0.34 + i * 0.22
				ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, u, 0.30, 0.10), _iso(c, tw, u + 0.12, 0.30, 0.10), _iso(c, tw, u + 0.12, 0.30, 0.18), _iso(c, tw, u, 0.30, 0.18)]), a)
			_box(ci, c, tw, -0.40, -0.20, 0.40, 0.26, 0.05, g, Color(g.r, g.g, g.b, 0.6), 0.26)
		"cutter":
			_box(ci, c, tw, -0.38, -0.30, 0.38, 0.30, 0.12, md)
			ci.draw_line(_iso(c, tw, 0, 0, 0.12), _iso(c, tw, -0.25, -0.25, 0.42), m, tw * 0.05)
			var hub := _iso(c, tw, -0.25, -0.25, 0.42)
			ci.draw_colored_polygon(_ellipse(hub, tw * 0.14, tw * 0.14), m)
			for i in 8:
				ci.draw_line(hub, hub + Vector2.from_angle(i * TAU / 8.0) * tw * 0.17, md, 2.0)
			ci.draw_arc(hub, tw * 0.14, 0, TAU, 24, a, 2.0)
		"forge":
			_box(ci, c, tw, -0.40, -0.40, 0.40, 0.40, 0.30, md)
			_cyl(ci, c, tw, -0.2, -0.2, 0.10, 0.42, m, Color(0.05, 0.05, 0.05, a.a), 0.30)
			var mouth := PackedVector2Array([_iso(c, tw, -0.15, 0.40, 0.04), _iso(c, tw, 0.15, 0.40, 0.04), _iso(c, tw, 0.15, 0.40, 0.20), _iso(c, tw, -0.15, 0.40, 0.20)])
			ci.draw_colored_polygon(mouth, a)
			_glow(ci, _iso(c, tw, 0, 0.40, 0.12), tw * 0.05, a, state)
		"rail":
			var ramp := PackedVector2Array([_iso(c, tw, -0.48, -0.16), _iso(c, tw, 0.48, -0.16, 0.30), _iso(c, tw, 0.48, 0.16, 0.30), _iso(c, tw, -0.48, 0.16)])
			ci.draw_colored_polygon(ramp, md)
			ci.draw_line(_iso(c, tw, -0.48, -0.08, 0.01), _iso(c, tw, 0.48, -0.08, 0.31), a, 2.0)
			ci.draw_line(_iso(c, tw, -0.48, 0.08, 0.01), _iso(c, tw, 0.48, 0.08, 0.31), a, 2.0)
			for u in [-0.2, 0.2]:
				ci.draw_line(_iso(c, tw, u, 0), _iso(c, tw, u, 0, (u + 0.48) * 0.31), m, tw * 0.03)
			_glow(ci, _iso(c, tw, 0.40, 0, 0.30), tw * 0.04, a, state)
		"commons":
			_cyl(ci, c, tw, 0, 0, 0.42, 0.05, md)
			_dome(ci, c, tw, 0, 0, 0.40, 0.30, _fade(Color(0.18, 0.45, 0.25), state), 0.05)
			for p in [Vector2(-0.1, 0.05), Vector2(0.12, -0.08)]:
				ci.draw_circle(_iso(c, tw, p.x, p.y, 0.15), tw * 0.06, a)
			_dome(ci, c, tw, 0, 0, 0.40, 0.30, g, 0.05)
		"clinic":
			_box(ci, c, tw, -0.38, -0.38, 0.38, 0.38, 0.24, _fade(WHITE, state))
			# A plus sign lying flat on the roof, along the tile's two axes.
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.24, -0.06, 0.24), _iso(c, tw, 0.24, -0.06, 0.24), _iso(c, tw, 0.24, 0.06, 0.24), _iso(c, tw, -0.24, 0.06, 0.24)]), a)
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.06, -0.24, 0.24), _iso(c, tw, 0.06, -0.24, 0.24), _iso(c, tw, 0.06, 0.24, 0.24), _iso(c, tw, -0.06, 0.24, 0.24)]), a)
		"cache":
			_box(ci, c, tw, -0.40, -0.40, 0.0, 0.0, 0.18, m)
			_box(ci, c, tw, 0.04, -0.40, 0.40, 0.0, 0.14, md.lightened(0.15))
			_box(ci, c, tw, -0.40, 0.04, 0.0, 0.40, 0.14, md.lightened(0.15))
			_box(ci, c, tw, 0.04, 0.04, 0.40, 0.40, 0.18, m)
			_box(ci, c, tw, -0.30, -0.30, 0.0, 0.0, 0.12, m.lightened(0.1), Color(0, 0, 0, 0), 0.18)
			_glow(ci, _iso(c, tw, 0.22, 0.22, 0.18), tw * 0.025, a, state)
		"lab":
			_box(ci, c, tw, -0.40, -0.40, 0.40, 0.40, 0.14, md)
			_dome(ci, c, tw, -0.05, -0.05, 0.30, 0.24, m, 0.14)
			_dome(ci, c, tw, -0.05, -0.05, 0.20, 0.16, g, 0.20)
			ci.draw_line(_iso(c, tw, -0.05, -0.05, 0.30), _iso(c, tw, 0.25, -0.30, 0.55), a, 3.0)
			_glow(ci, _iso(c, tw, 0.25, -0.30, 0.55), tw * 0.03, a, state)
		"workshop":
			_box(ci, c, tw, -0.42, -0.42, 0.42, 0.42, 0.26, m)
			var door := PackedVector2Array([_iso(c, tw, -0.2, 0.42), _iso(c, tw, 0.2, 0.42), _iso(c, tw, 0.2, 0.42, 0.20), _iso(c, tw, -0.2, 0.42, 0.20)])
			ci.draw_colored_polygon(door, md.darkened(0.3))
			ci.draw_line(_iso(c, tw, 0.3, -0.3, 0.26), _iso(c, tw, 0.3, -0.3, 0.62), md, tw * 0.03)
			ci.draw_line(_iso(c, tw, 0.3, -0.3, 0.62), _iso(c, tw, -0.2, -0.3, 0.62), md, tw * 0.03)
			ci.draw_line(_iso(c, tw, -0.2, -0.3, 0.62), _iso(c, tw, -0.2, -0.3, 0.40), a, 2.0)
		"warden":
			_box(ci, c, tw, -0.22, -0.22, 0.22, 0.22, 0.52, md)
			_box(ci, c, tw, -0.30, -0.30, 0.30, 0.30, 0.14, m, Color(0, 0, 0, 0), 0.52)
			_glow(ci, _iso(c, tw, 0, 0, 0.74), tw * 0.06, a, state)
		_:
			_box(ci, c, tw, -0.4, -0.4, 0.4, 0.4, 0.3, m)


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
