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
	"forge": Color(0.30, 0.16, 0.10), "lab": Color(0.20, 0.16, 0.32), "vent": Color(0.22, 0.08, 0.04),
}
## Dome size (radius, as a fraction of a tile) for each building.
const DOME_SIZE := {"hull": 0.46, "mirror": 0.20, "cache": 0.34, "warden": 0.28, "shaft": 0.40, "rail": 0.22, "vent": 0.34, "forge": 0.34}
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


## A round tube from the edge of the dome to the tile's edge, with a round
## airlock collar where it meets the dome.
static func _top_link(ci: CanvasItem, c: Vector2, s: float, d: Vector2i, rad: float, state: Dictionary) -> void:
	var dir := Vector2(d)
	var from := c + dir * rad * 0.85
	var to := c + dir * s * 0.5
	_top_tube(ci, from, to, s, state)
	# Airlock: a round collar around the tube, with amber rings.
	var lock_c := c + dir * (rad + s * 0.035)
	ci.draw_circle(lock_c, s * 0.115, _fade(METAL_DARK, state))
	ci.draw_circle(lock_c, s * 0.095, _fade(METAL, state))
	var amber := _fade(AMBER, state)
	ci.draw_arc(lock_c, s * 0.095, 0, TAU, 20, amber, 2.0)
	ci.draw_arc(lock_c, s * 0.055, 0, TAU, 16, amber, 1.5)
	ci.draw_circle(lock_c, s * 0.03, _fade(METAL_DARK, state))


## A round tube seen from above: shaded so it looks rounded, with the glowing
## orange stripe along its top and rib rings.
static func _top_tube(ci: CanvasItem, from: Vector2, to: Vector2, s: float, state: Dictionary) -> void:
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var orange := _fade(ORANGE, state)
	var w := s * 0.11
	# Rounded shading: dark edges, lighter middle.
	for band in [[1.0, md], [0.75, m.darkened(0.15)], [0.45, m], [0.2, m.lightened(0.18)]]:
		var k: float = band[0]
		ci.draw_colored_polygon(PackedVector2Array([from + side * w * k, to + side * w * k, to - side * w * k, from - side * w * k]), band[1])
	ci.draw_line(from, to, Color(orange.r, orange.g, orange.b, 0.85 * orange.a), s * 0.03)
	var length := from.distance_to(to)
	var ribs := maxi(1, int(length / (s * 0.18)))
	for k in ribs:
		var p := from + dir * length * (float(k) + 0.5) / ribs
		ci.draw_line(p + side * w, p - side * w, md.darkened(0.25), 2.0)


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
	if type == "hull":
		_top_pad(ci, c, s, rad, links, state)
		return
	if type == "shaft":
		_top_hole(ci, c, s, rad, links, state)
		return
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
			# The launch track across the back of the tile: a bed, twin rails,
			# glowing accelerator coils, and a cargo pod waiting at the start.
			var y := c.y - s * 0.33
			ci.draw_rect(Rect2(Vector2(r.position.x, y - s * 0.09), Vector2(s, s * 0.18)), md)
			ci.draw_line(Vector2(r.position.x, y - s * 0.045), Vector2(r.end.x, y - s * 0.045), a, 2.0)
			ci.draw_line(Vector2(r.position.x, y + s * 0.045), Vector2(r.end.x, y + s * 0.045), a, 2.0)
			for k in 5:
				var x := r.position.x + s * (0.30 + k * 0.15)
				ci.draw_rect(Rect2(Vector2(x - s * 0.025, y - s * 0.13), Vector2(s * 0.05, s * 0.26)), m)
				ci.draw_rect(Rect2(Vector2(x - s * 0.012, y - s * 0.12), Vector2(s * 0.024, s * 0.24)), _fade(CYAN, state))
			var pod := Rect2(Vector2(r.position.x + s * 0.05, y - s * 0.06), Vector2(s * 0.18, s * 0.12))
			ci.draw_rect(pod, _fade(WHITE, state))
			ci.draw_rect(Rect2(pod.position + Vector2(pod.size.x - s * 0.04, 0), Vector2(s * 0.04, pod.size.y)), a)
			# A feed tube from the control dome up to the track.
			ci.draw_line(c, Vector2(c.x, y + s * 0.09), md, s * 0.06)
			_glow(ci, Vector2(r.end.x - s * 0.03, y), s * 0.035, _fade(CYAN, state), state)
		"vent":
			# Radiator fins on both sides carry the heat away.
			for side in [-1.0, 1.0]:
				var fin := Rect2(c + Vector2(side * s * 0.36 - s * 0.07, -s * 0.30), Vector2(s * 0.14, s * 0.60))
				ci.draw_rect(fin, md)
				for k in 7:
					var fy := fin.position.y + s * 0.04 + k * s * 0.08
					ci.draw_line(Vector2(fin.position.x + 2, fy), Vector2(fin.end.x - 2, fy), _fade(Color(0.95, 0.72, 0.35), state), 1.5)
			# Relief valves letting off white steam.
			if _lit(state):
				for k in 3:
					ci.draw_circle(c + Vector2(-s * 0.22 + k * s * 0.05, -s * 0.40 - k * s * 0.03), s * (0.04 + k * 0.015), Color(0.95, 0.95, 1.0, 0.35 - k * 0.08))
		"forge":
			# A conveyor belt bringing ore in from the left, with ore on it.
			var belt := Rect2(Vector2(r.position.x, c.y - s * 0.07), Vector2(s * 0.30, s * 0.14))
			ci.draw_rect(belt, md)
			for k in 4:
				ci.draw_line(Vector2(belt.position.x + k * s * 0.08, belt.position.y), Vector2(belt.position.x + k * s * 0.08, belt.end.y), m, 1.0)
			for k in 2:
				ci.draw_circle(Vector2(belt.position.x + s * (0.06 + k * 0.12), c.y), s * 0.035, _fade(Color(0.45, 0.42, 0.40), state))
			# Finished alloy bars stacked at the front-right.
			for k in 3:
				var bar := Rect2(c + Vector2(s * 0.20 + (k % 2) * s * 0.07, s * 0.30 - (k / 2) * s * 0.06), Vector2(s * 0.12, s * 0.05))
				ci.draw_rect(bar, _fade(Color(0.80, 0.84, 0.90), state))
				ci.draw_rect(bar, md, false, 1.0)
		"drill":
			ci.draw_circle(c + Vector2(s * 0.30, s * 0.30), s * 0.13, _fade(Color(0.25, 0.45, 0.75), state))
		"lab":
			# A satellite dish at the back-right corner.
			var dish := c + Vector2(s * 0.33, -s * 0.33)
			ci.draw_circle(dish, s * 0.13, md)
			ci.draw_circle(dish, s * 0.11, _fade(Color(0.85, 0.88, 0.94), state))
			ci.draw_arc(dish, s * 0.07, 0, TAU, 16, _fade(Color(0.6, 0.65, 0.72), state), 1.0)
			ci.draw_line(dish, dish + Vector2(-s * 0.06, s * 0.06), md, 2.0)
			ci.draw_circle(dish + Vector2(-s * 0.06, s * 0.06), s * 0.02, a)
			# Glowing specimen tubes along the front-left.
			for k in 3:
				var tube := c + Vector2(-s * 0.40 + k * s * 0.09, s * 0.36)
				var col: Color = [GREEN, CYAN, VIOLET][k]
				ci.draw_circle(tube, s * 0.045, md)
				_glow(ci, tube, s * 0.03, _fade(col, state), state)
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
			# The vent itself under the glass: a glowing magma pool with cracks.
			var hot := _fade(Color(1.0, 0.42, 0.10), state)
			ci.draw_circle(c, rad * 0.55, _fade(Color(0.35, 0.10, 0.04), state))
			ci.draw_circle(c, rad * 0.42, hot.darkened(0.2))
			ci.draw_circle(c, rad * 0.25, _fade(Color(1.0, 0.80, 0.30), state))
			for k in 5:
				var dir := Vector2.from_angle(k * TAU / 5.0 + 0.3)
				ci.draw_line(c + dir * rad * 0.55, c + dir * rad * 0.80, hot, 1.5)
			_glow(ci, c, rad * 0.20, hot, state)
			# A big valve wheel on the front.
			var wheel := c + Vector2(rad * 0.62, rad * 0.62)
			ci.draw_arc(wheel, s * 0.08, 0, TAU, 18, _fade(Color(0.85, 0.25, 0.20), state), 3.0)
			for k in 3:
				ci.draw_line(wheel, wheel + Vector2.from_angle(k * TAU / 3.0) * s * 0.08, _fade(Color(0.85, 0.25, 0.20), state), 2.0)
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
			# The crucible pouring molten metal, with sparks.
			ci.draw_circle(c + Vector2(-rad * 0.10, rad * 0.10), rad * 0.34, md)
			_glow(ci, c + Vector2(-rad * 0.10, rad * 0.10), rad * 0.24, a, state)
			if _lit(state):
				for k in 6:
					ci.draw_circle(c + Vector2(-rad * 0.10, rad * 0.10) + Vector2.from_angle(k * 1.1) * rad * (0.36 + 0.08 * (k % 3)), 1.5, Color(1.0, 0.85, 0.4, 0.9))
			# Twin smokestacks with dark smoke.
			for k in 2:
				var stack := c + Vector2(rad * (0.30 + k * 0.32), -rad * (0.55 - k * 0.15))
				ci.draw_circle(stack, s * 0.065, md.darkened(0.2))
				ci.draw_circle(stack, s * 0.035, Color(0.04, 0.04, 0.04, a.a))
				if _lit(state):
					ci.draw_circle(stack + Vector2(s * 0.05, -s * 0.06), s * 0.05, Color(0.20, 0.20, 0.22, 0.45))
		"rail":
			_glow(ci, c, s * 0.035, a, state)
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
			# Observatory slit across the dome, and the telescope looking out of it.
			ci.draw_rect(Rect2(c - Vector2(rad * 0.08, rad * 0.86), Vector2(rad * 0.16, rad * 0.86)), md)
			ci.draw_line(c, c + Vector2(0, -rad * 0.75), m.lightened(0.2), maxf(2.0, s * 0.04))
			ci.draw_circle(c + Vector2(0, -rad * 0.75), s * 0.03, _fade(Color(0.6, 0.85, 1.0), state))
			# A hologram of an atom: three orbits and a glowing core.
			var holo := _fade(Color(0.75, 0.60, 1.0, 0.9), state)
			var core := c + Vector2(0, rad * 0.22)
			for k in 3:
				var orbit := PackedVector2Array()
				for i in 25:
					var t := i * TAU / 24.0
					orbit.append(core + Vector2(cos(t) * rad * 0.42, sin(t) * rad * 0.14).rotated(k * PI / 3.0))
				ci.draw_polyline(orbit, holo, 1.5)
			_glow(ci, core, s * 0.035, holo, state)
			# Electrons.
			for k in 3:
				_glow(ci, core + Vector2(rad * 0.42, 0).rotated(k * PI / 3.0 + 0.6), s * 0.012, _fade(CYAN, state), state)
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


## The Landing Hull as a landing pad, like a helipad: a round platform with a
## painted ring, a big H, landing lights around the edge, and a small control
## dome at one corner.
static func _top_pad(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var paint := _fade(Color(0.96, 0.82, 0.30), state)
	var orange := _fade(ORANGE, state)
	ci.draw_circle(c + Vector2(rad * 0.08, rad * 0.10), rad * 1.02, Color(0, 0, 0, 0.28 * paint.a))
	ci.draw_circle(c, rad, md)
	ci.draw_circle(c, rad * 0.92, m.darkened(0.25))
	ci.draw_arc(c, rad * 0.94, 0, TAU, 40, orange, maxf(1.5, s * 0.02))
	ci.draw_arc(c, rad * 0.62, 0, TAU, 36, paint, maxf(2.0, s * 0.03))
	# The H.
	var hw := rad * 0.30
	var hh := rad * 0.42
	var bar := maxf(2.0, rad * 0.11)
	ci.draw_rect(Rect2(c + Vector2(-hw, -hh), Vector2(bar, hh * 2.0)), paint)
	ci.draw_rect(Rect2(c + Vector2(hw - bar, -hh), Vector2(bar, hh * 2.0)), paint)
	ci.draw_rect(Rect2(c + Vector2(-hw, -bar * 0.5), Vector2(hw * 2.0, bar)), paint)
	# Landing lights around the edge.
	for i in 12:
		_glow(ci, c + Vector2.from_angle(i * TAU / 12.0) * rad * 0.80, s * 0.018, orange, state)
	# Ports on every side (open where a tunnel joins).
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))
	# The control dome at the back-left corner.
	_top_dome(ci, c + Vector2(-s * 0.36, -s * 0.36), s * 0.12, orange, Color(0.30, 0.26, 0.22), state)
	_glow(ci, c + Vector2(-s * 0.36, -s * 0.36), s * 0.025, orange, state)


## The Shaft, seen from above: an open hole into the ground. Rock walls fade to
## black, a striped rim with lights runs round it, a ladder goes down one side,
## and a hoist frame spans the opening.
static func _top_hole(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var orange := _fade(ORANGE, state)
	var rock := _fade(Color(0.30, 0.26, 0.23), state)
	# Rim: a metal ring with hazard stripes.
	ci.draw_circle(c, rad, md)
	for i in 16:
		var a0 := i * TAU / 16.0
		ci.draw_arc(c, rad * 0.93, a0, a0 + TAU / 32.0, 4, orange if i % 2 == 0 else Color(0.05, 0.05, 0.05, orange.a), maxf(2.0, s * 0.03))
	# The hole: rock walls getting darker with depth.
	for k in 6:
		var t := float(k) / 5.0
		ci.draw_circle(c + Vector2(0, rad * 0.05 * t), rad * (0.84 - 0.62 * t), rock.lerp(Color(0.0, 0.0, 0.0, rock.a), t))
	# A ladder down the far wall.
	for side in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(side * rad * 0.10, -rad * 0.82), c + Vector2(side * rad * 0.06, -rad * 0.25), m, 1.5)
	for k in 5:
		var y := -rad * 0.78 + k * rad * 0.12
		ci.draw_line(c + Vector2(-rad * 0.09, y), c + Vector2(rad * 0.09, y), m, 1.0)
	# Hoist frame across the opening, with its cable going down.
	ci.draw_line(c + Vector2(-rad * 0.95, rad * 0.25), c + Vector2(rad * 0.95, rad * 0.25), md.lightened(0.15), maxf(2.0, s * 0.035))
	ci.draw_circle(c + Vector2(0, rad * 0.25), s * 0.04, m)
	ci.draw_circle(c + Vector2(0, rad * 0.25), s * 0.015, orange)
	# Airtight: a clear pressure dome over the whole pit, held down by a bolted
	# seal ring, so the colony's air can't escape down the shaft.
	var glass := _fade(GLASS, state)
	ci.draw_circle(c, rad * 0.88, Color(glass.r, glass.g, glass.b, glass.a * 0.45))
	for i in 3:
		var dir := Vector2.from_angle(i * PI / 3.0 + PI / 6.0)
		ci.draw_line(c - dir * rad * 0.86, c + dir * rad * 0.86, _fade(Color(0.75, 0.82, 0.90, 0.30), state), 1.0)
	ci.draw_arc(c, rad * 0.55, 0, TAU, 28, _fade(Color(0.75, 0.82, 0.90, 0.25), state), 1.0)
	ci.draw_arc(c - Vector2(rad * 0.25, rad * 0.25), rad * 0.45, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.55 * glass.a / GLASS.a), 2.0)
	ci.draw_arc(c, rad * 0.88, 0, TAU, 36, m.lightened(0.2), maxf(2.0, s * 0.025))
	for i in 16:
		ci.draw_circle(c + Vector2.from_angle(i * TAU / 16.0) * rad * 0.88, maxf(1.2, s * 0.011), md)
	for i in 4:
		_glow(ci, c + Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * rad * 0.97, s * 0.02, orange, state)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))


## What shape a tunnel piece is, from its links: "none", "end", "straight",
## "corner", "tee" or "cross".
static func tunnel_shape(links: Array) -> String:
	match links.size():
		0:
			return "none"
		1:
			return "end"
		2:
			var a: Vector2i = links[0]
			var b: Vector2i = links[1]
			return "straight" if a + b == Vector2i.ZERO else "corner"
		3:
			return "tee"
	return "cross"


## A Heat Main (tunnel) tile, top-down. Straight runs are one continuous tube,
## corners get an elbow, T-junctions and crossroads a round hub, and a dead end
## a capped end with an orange light.
static func _top_tunnel(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var a := _fade(ORANGE, state)
	match tunnel_shape(links):
		"none":
			_top_tube(ci, c - Vector2(s * 0.22, 0), c + Vector2(s * 0.22, 0), s, state)
			_top_cap(ci, c - Vector2(s * 0.22, 0), s, state)
			_top_cap(ci, c + Vector2(s * 0.22, 0), s, state)
		"end":
			_top_tube(ci, c, c + Vector2(links[0]) * s * 0.5, s, state)
			_top_cap(ci, c, s, state)
		"straight":
			_top_tube(ci, c - Vector2(links[0]) * s * 0.5, c + Vector2(links[0]) * s * 0.5, s, state)
		"corner":
			for d in links:
				_top_tube(ci, c, c + Vector2(d) * s * 0.5, s, state)
			# The elbow: a round joint the width of the tube.
			ci.draw_circle(c, s * 0.11, md)
			ci.draw_circle(c, s * 0.085, m)
			ci.draw_arc(c, s * 0.06, 0, TAU, 16, Color(a.r, a.g, a.b, 0.85 * a.a), 2.0)
		_:
			for d in links:
				_top_tube(ci, c, c + Vector2(d) * s * 0.5, s, state)
			ci.draw_circle(c, s * 0.17, md)
			ci.draw_circle(c, s * 0.14, m)
			ci.draw_arc(c, s * 0.14, 0, TAU, 20, a, 2.0)
			ci.draw_circle(c, s * 0.06, m.lightened(0.2))


## The closed end of a tube: a round cap with an orange light.
static func _top_cap(ci: CanvasItem, p: Vector2, s: float, state: Dictionary) -> void:
	ci.draw_circle(p, s * 0.12, _fade(METAL_DARK, state))
	ci.draw_circle(p, s * 0.095, _fade(METAL, state))
	_glow(ci, p, s * 0.03, _fade(ORANGE, state), state)


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


## A round tube lying along one axis of the tile (axis 0 = u, 1 = v), from a0
## to a1, its centre line at height z, radius rr (all in tile widths).
static func _iso_tube(ci: CanvasItem, c: Vector2, tw: float, axis: int, a0: float, a1: float, rr: float, z: float, col: Color, stripe: Color = Color(0, 0, 0, 0)) -> void:
	var across := Vector2(-0.5, 0.25) * tw if axis == 0 else Vector2(0.5, 0.25) * tw
	var up := Vector2(0, -tw)
	var lo := minf(a0, a1)
	var hi := maxf(a0, a1)
	var ends: Array = []
	for t in [lo, hi]:
		var base := _iso(c, tw, t, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, t, z)
		var ring := PackedVector2Array()
		for i in 20:
			var th := i * TAU / 20.0
			ring.append(base + (across * cos(th) + up * sin(th)) * rr)
		ends.append([base, ring])
	var all := PackedVector2Array()
	all.append_array(ends[0][1])
	all.append_array(ends[1][1])
	ci.draw_colored_polygon(Geometry2D.convex_hull(all), col.darkened(0.30))
	# A lighter band along the top so it reads as round.
	var top0: Vector2 = ends[0][0] + up * rr * 0.55
	var top1: Vector2 = ends[1][0] + up * rr * 0.55
	ci.draw_line(top0, top1, col.lightened(0.10), maxf(2.0, tw * rr * 0.55))
	if stripe.a > 0.0:
		ci.draw_line(ends[0][0] + up * rr * 0.9, ends[1][0] + up * rr * 0.9, stripe, 2.5)
	# The end nearer the viewer shows its round face.
	ci.draw_colored_polygon(ends[1][1], col)


## A round tube from the dome's edge to the tile edge, with a round airlock
## collar where it meets the dome.
static func _iso_link(ci: CanvasItem, c: Vector2, tw: float, d: Vector2i, r: float, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var amber := _fade(AMBER, state)
	var orange := _fade(ORANGE, state)
	var axis := 0 if d.x != 0 else 1
	var sign := float(d.x if d.x != 0 else d.y)
	_iso_tube(ci, c, tw, axis, sign * r * 0.8, sign * 0.5, 0.075, 0.09, m, Color(orange.r, orange.g, orange.b, 0.85 * orange.a))
	# The airlock collar: a short, wider round section with amber rings.
	var l0 := sign * (r + 0.01)
	var l1 := sign * (r + 0.09)
	_iso_tube(ci, c, tw, axis, l0, l1, 0.115, 0.09, m.lightened(0.1))
	var face := _iso(c, tw, maxf(l0, l1), 0.0, 0.09) if axis == 0 else _iso(c, tw, 0.0, maxf(l0, l1), 0.09)
	var across := Vector2(-0.5, 0.25) * tw if axis == 0 else Vector2(0.5, 0.25) * tw
	for k in [0.11, 0.07]:
		var ring := PackedVector2Array()
		for i in 21:
			var th := i * TAU / 20.0
			ring.append(face + (across * cos(th) + Vector2(0, -tw) * sin(th)) * k)
		ci.draw_polyline(ring, amber, 1.5)


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
	if type == "hull":
		_iso_pad(ci, c, tw, r, links, state)
		return
	if type == "shaft":
		_iso_hole(ci, c, tw, r, links, state)
		return
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
		"rail":
			_iso_launch_track(ci, c, tw, state)
		"vent":
			# Radiator fin banks behind the dome, and steam from relief valves.
			for u in [-0.36, 0.30]:
				var v0 := -0.40 if u > 0 else -0.10
				_box(ci, c, tw, u - 0.05, v0, u + 0.05, v0 + 0.32, 0.30, md)
				for k in 6:
					var hgt := 0.05 + k * 0.045
					ci.draw_line(_iso(c, tw, u + 0.05, v0, hgt), _iso(c, tw, u + 0.05, v0 + 0.32, hgt), _fade(Color(0.95, 0.72, 0.35), state), 1.2)
			_cyl(ci, c, tw, -0.05, -0.36, 0.035, 0.40, m, m)
			if _lit(state):
				for k in 3:
					ci.draw_circle(_iso(c, tw, -0.05, -0.36, 0.48 + k * 0.10) + Vector2(k * tw * 0.03, 0), tw * (0.04 + k * 0.018), Color(0.95, 0.95, 1.0, 0.30 - k * 0.07))
		"forge":
			# Conveyor bringing ore in from the back-left, and twin smokestacks behind.
			_box(ci, c, tw, -0.50, -0.08, -0.20, 0.08, 0.10, md, m.darkened(0.1))
			for k in 2:
				_iso_sphere(ci, _iso(c, tw, -0.44 + k * 0.12, 0, 0.13), tw * 0.025, _fade(Color(0.45, 0.42, 0.40), state))
			for k in 2:
				_cyl(ci, c, tw, 0.04 + k * 0.18, -0.30 + k * 0.06, 0.05, 0.46 - k * 0.06, md.darkened(0.15), Color(0.05, 0.05, 0.05, a.a))
		"lab":
			# Sensor mast at the back, with a blinking light.
			var mast := _iso(c, tw, -0.36, -0.30)
			ci.draw_line(mast, mast - Vector2(0, tw * 0.40), md.lightened(0.2), tw * 0.014)
			for k in 2:
				ci.draw_line(mast - Vector2(tw * 0.04, tw * (0.26 + k * 0.08)), mast - Vector2(-tw * 0.04, tw * (0.26 + k * 0.08)), md.lightened(0.2), 1.5)
			_glow(ci, mast - Vector2(0, tw * 0.42), tw * 0.016, _fade(Color(1.0, 0.35, 0.35), state), state)
			# Satellite dish on a stand, at the back-right, tilted to the sky.
			var foot := _iso(c, tw, 0.34, -0.34)
			var head := foot - Vector2(0, tw * 0.22)
			ci.draw_line(foot, head, md, tw * 0.02)
			var dish := _ellipse(head + Vector2(tw * 0.02, -tw * 0.04), tw * 0.13, tw * 0.07, 0, 360, 24)
			var tilted := PackedVector2Array()
			for p in dish:
				tilted.append(head + (p - head).rotated(-0.45))
			ci.draw_colored_polygon(tilted, _fade(Color(0.86, 0.89, 0.95), state))
			ci.draw_polyline(tilted, md, 1.5)
			ci.draw_line(head, head + Vector2(tw * 0.06, -tw * 0.12), md, 1.5)
			_glow(ci, head + Vector2(tw * 0.06, -tw * 0.12), tw * 0.012, a, state)
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
			# The magma pool glowing inside the dome.
			var hot := _fade(Color(1.0, 0.42, 0.10), state)
			var pool := _iso(c, tw, 0, 0, 0.07)
			ci.draw_colored_polygon(_ellipse(pool, r * tw * 0.50, r * tw * 0.25), _fade(Color(0.35, 0.10, 0.04), state))
			ci.draw_colored_polygon(_ellipse(pool, r * tw * 0.36, r * tw * 0.18), hot.darkened(0.15))
			ci.draw_colored_polygon(_ellipse(pool, r * tw * 0.20, r * tw * 0.10), _fade(Color(1.0, 0.80, 0.30), state))
			_glow(ci, pool, tw * 0.05, hot, state)
			# A big red valve wheel on the front.
			var wheel := _iso(c, tw, r * 0.95, r * 0.40, 0.12)
			var red := _fade(Color(0.85, 0.25, 0.20), state)
			ci.draw_polyline(_ellipse(wheel, tw * 0.045, tw * 0.055), red, 2.5)
			for k in 3:
				ci.draw_line(wheel, wheel + Vector2(cos(k * TAU / 3.0) * tw * 0.045, sin(k * TAU / 3.0) * tw * 0.055), red, 1.5)
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
			# Dark smoke from the stacks, a glowing furnace door, and sparks.
			if _lit(state):
				for k in 2:
					var top := _iso(c, tw, 0.04 + k * 0.18, -0.30 + k * 0.06, 0.46 - k * 0.06)
					for j in 3:
						ci.draw_circle(top - Vector2(-j * tw * 0.03, tw * (0.05 + j * 0.06)), tw * (0.035 + j * 0.015), Color(0.20, 0.20, 0.22, 0.45 - j * 0.12))
			var mouth := _iso(c, tw, 0.05, r * 0.9, 0.10)
			ci.draw_colored_polygon(_ellipse(mouth, tw * 0.08, tw * 0.06, 180, 360, 10), a)
			_glow(ci, mouth, tw * 0.045, a, state)
			if _lit(state):
				for k in 5:
					ci.draw_circle(mouth + Vector2(cos(k * 1.3) * tw * 0.09, -absf(sin(k * 1.3)) * tw * 0.08), 1.5, Color(1.0, 0.85, 0.4, 0.9))
			# Finished alloy bars stacked at the front-right.
			for k in 3:
				var u := 0.30 + (k % 2) * 0.08
				var z := 0.0 + (k / 2) * 0.04
				_box(ci, c, tw, u - 0.04, 0.30, u + 0.03, 0.42, 0.035, _fade(Color(0.80, 0.84, 0.90), state), Color(0, 0, 0, 0), z)
		"rail":
			_glow(ci, _iso(c, tw, 0, 0, 0.10), tw * 0.03, a, state)
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
			# Observatory slit and a telescope tube pointing out of it.
			var slit := PackedVector2Array([apex + Vector2(-tw * 0.03, 0), apex + Vector2(tw * 0.03, 0), _iso(c, tw, 0.0, 0.30, 0.10) + Vector2(tw * 0.03, 0), _iso(c, tw, 0.0, 0.30, 0.10) + Vector2(-tw * 0.03, 0)])
			ci.draw_colored_polygon(slit, md)
			var eye := apex + Vector2(-tw * 0.10, -tw * 0.17)
			ci.draw_line(apex + Vector2(0, tw * 0.03), eye, m.lightened(0.25), tw * 0.035)
			ci.draw_circle(eye, tw * 0.02, _fade(Color(0.6, 0.85, 1.0), state))
			# The atom hologram glowing inside the glass.
			var holo := _fade(Color(0.75, 0.60, 1.0, 0.9), state)
			var core := _iso(c, tw, 0, 0, 0.17)
			for k in 3:
				var orbit := PackedVector2Array()
				for i in 25:
					var t := i * TAU / 24.0
					orbit.append(core + Vector2(cos(t) * tw * 0.11, sin(t) * tw * 0.035).rotated(k * PI / 3.0))
				ci.draw_polyline(orbit, holo, 1.5)
			_glow(ci, core, tw * 0.022, holo, state)
			for k in 3:
				_glow(ci, core + Vector2(tw * 0.11, 0).rotated(k * PI / 3.0 + 0.6), tw * 0.008, _fade(CYAN, state), state)
			# Glowing specimen tubes in front.
			for k in 3:
				var col: Color = [GREEN, CYAN, VIOLET][k]
				_cyl(ci, c, tw, -0.28 + k * 0.10, 0.40, 0.035, 0.12, _fade(col, state).darkened(0.1), _fade(col, state))
				_glow(ci, _iso(c, tw, -0.28 + k * 0.10, 0.40, 0.12), tw * 0.012, _fade(col, state), state)
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


## The landing pad at an angle: a low round platform with a painted ring and H
## lying flat on it, landing lights, a control dome at the back corner, and
## tunnels to its edge.
static func _iso_pad(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var paint := _fade(Color(0.96, 0.82, 0.30), state)
	var orange := _fade(ORANGE, state)
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	# The control dome sits behind the pad, at the back corner.
	var dome_c := _iso(c, tw, -0.36, -0.36)
	_iso_dome(ci, dome_c, tw, 0.13, 0.11, orange, Color(0.30, 0.26, 0.22), state)
	_glow(ci, _iso(dome_c, tw, 0, 0, 0.17), tw * 0.018, orange, state)
	_cyl(ci, c, tw, 0, 0, r, 0.05, md, m.darkened(0.2))
	var top := 0.05
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, top), r * tw * 0.66, r * tw * 0.33), orange, 2.0)
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, top), r * tw * 0.45, r * tw * 0.225), paint, 3.0)
	# The H, painted flat on the platform along the tile's axes.
	var hw := r * 0.30
	var hh := r * 0.42
	var bar := r * 0.11
	for rect in [[-hw, -hh, -hw + bar, hh], [hw - bar, -hh, hw, hh], [-hw, -bar * 0.5, hw, bar * 0.5]]:
		ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, rect[0], rect[1], top), _iso(c, tw, rect[2], rect[1], top), _iso(c, tw, rect[2], rect[3], top), _iso(c, tw, rect[0], rect[3], top)]), paint)
	for i in 12:
		var q := Vector2.from_angle(i * TAU / 12.0) * r * 0.80
		_glow(ci, _iso(c, tw, q.x, q.y, top), tw * 0.014, orange, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.97, d.y * r * 0.97, 0.03), tw, state, true)


## The Shaft at an angle: a round hole in the ground. You see the far inside
## wall going down into darkness, a striped rim with lights, a ladder, and an
## A-frame hoist with its cable dropping into the hole.
static func _iso_hole(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var orange := _fade(ORANGE, state)
	var rock := _fade(Color(0.32, 0.27, 0.24), state)
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	var center := _iso(c, tw, 0, 0, 0.02)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	# Rim.
	ci.draw_colored_polygon(_ellipse(center, rx * 1.06, ry * 1.06), md)
	for i in 16:
		var a0 := float(i) * 360.0 / 16.0
		ci.draw_polyline(_ellipse(center, rx, ry, a0, a0 + 11.25, 3), orange if i % 2 == 0 else Color(0.05, 0.05, 0.05, orange.a), 3.0)
	# The opening: the far wall shows as a band of rock fading down to black.
	var inner_rx := rx * 0.86
	var inner_ry := ry * 0.86
	ci.draw_colored_polygon(_ellipse(center, inner_rx, inner_ry), Color(0.0, 0.0, 0.0, rock.a))
	var depth := tw * 0.30
	# The far inside wall: bands of rock between the top edge of the opening and
	# curves further down inside it, each band darker, so the pit looks deep.
	for k in 4:
		var t0 := float(k) / 4.0
		var t1 := float(k + 1) / 4.0
		var band := _ellipse(center + Vector2(0, inner_ry * 0.9 * t0), inner_rx * (1.0 - 0.10 * t0), inner_ry * (1.0 - 0.45 * t0), 180, 360, 20)
		band.append_array(_ellipse(center + Vector2(0, inner_ry * 0.9 * t1), inner_rx * (1.0 - 0.10 * t1), inner_ry * (1.0 - 0.45 * t1), 360, 180, 20))
		ci.draw_colored_polygon(band, rock.lerp(Color(0, 0, 0, rock.a), 0.15 + t0 * 0.6))
	# Ladder on the far wall.
	for side in [-1.0, 1.0]:
		ci.draw_line(center + Vector2(side * tw * 0.03, -inner_ry * 0.95), center + Vector2(side * tw * 0.03, inner_ry * 0.1), m, 1.5)
	for k in 4:
		var y := -inner_ry * 0.95 + k * inner_ry * 0.27
		ci.draw_line(center + Vector2(-tw * 0.03, y), center + Vector2(tw * 0.03, y), m, 1.0)
	# The A-frame hoist and its cable.
	var top := _iso(c, tw, 0, 0, 0.42)
	for foot in [Vector2(-r * 0.9, 0), Vector2(r * 0.9, 0)]:
		ci.draw_line(_iso(c, tw, foot.x, foot.y - 0.08, 0.02), top, md.lightened(0.2), tw * 0.018)
		ci.draw_line(_iso(c, tw, foot.x, foot.y + 0.08, 0.02), top, md.lightened(0.2), tw * 0.018)
	ci.draw_line(top, center + Vector2(0, inner_ry * 0.4), m, 1.5)
	ci.draw_circle(top, tw * 0.02, m)
	_glow(ci, top, tw * 0.014, orange, state)
	# Airtight: a clear pressure dome over the pit and hoist, sealed at the rim.
	var glass := _fade(GLASS, state)
	var shell := _ellipse(center, rx * 0.97, ry * 0.97, 0, 180, 16)
	shell.append_array(_ellipse(center, rx * 0.97, 0.50 * tw, 180, 360, 22))
	ci.draw_colored_polygon(shell, Color(glass.r, glass.g, glass.b, glass.a * 0.45))
	var rib := _fade(Color(0.80, 0.86, 0.94, 0.40), state)
	for k in [0.35, 0.7]:
		ci.draw_polyline(_ellipse(center, rx * 0.97 * k, 0.50 * tw, 180, 360, 14), rib, 1.0)
	ci.draw_polyline(_ellipse(center - Vector2(0, 0.50 * tw * 0.45), rx * 0.86, ry * 0.86, 180, 360, 16), rib, 1.0)
	ci.draw_arc(center - Vector2(rx * 0.32, 0.50 * tw * 0.58), rx * 0.30, deg_to_rad(190), deg_to_rad(250), 6, Color(1, 1, 1, 0.6 * glass.a / GLASS.a), 2.0)
	ci.draw_polyline(_ellipse(center, rx * 0.97, ry * 0.97), m.lightened(0.2), 3.0)
	for i in 16:
		var ang := i * TAU / 16.0
		ci.draw_circle(center + Vector2(cos(ang) * rx * 0.97, sin(ang) * ry * 0.97), maxf(1.2, tw * 0.008), md)
	for i in 4:
		var q := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * r * 0.95
		_glow(ci, _iso(c, tw, q.x, q.y, 0.03), tw * 0.014, orange, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.04), tw, state, true)


## The Launch Rail's track at an angle: it runs along the back of the tile and
## climbs toward the sky, on pylons, through glowing accelerator coils, with a
## cargo pod waiting at the bottom. The small control dome sits in front of it.
static func _iso_launch_track(ci: CanvasItem, c: Vector2, tw: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var gold := _fade(GOLD, state)
	var cyan := _fade(CYAN, state)
	var v := -0.30
	var u0 := -0.48
	var u1 := 0.50
	var z0 := 0.05
	var z1 := 0.42
	var height := func(u: float) -> float: return lerpf(z0, z1, (u - u0) / (u1 - u0))
	# Pylons from the ground up to the track.
	for u in [-0.15, 0.15, 0.42]:
		var zt: float = height.call(u)
		ci.draw_line(_iso(c, tw, u, v - 0.05), _iso(c, tw, u, v - 0.05, zt), md.lightened(0.15), tw * 0.016)
		ci.draw_line(_iso(c, tw, u, v + 0.05), _iso(c, tw, u, v + 0.05, zt), md.lightened(0.15), tw * 0.016)
	# The track bed and its two rails.
	var bed := PackedVector2Array([_iso(c, tw, u0, v - 0.07, z0), _iso(c, tw, u1, v - 0.07, z1), _iso(c, tw, u1, v + 0.07, z1), _iso(c, tw, u0, v + 0.07, z0)])
	ci.draw_colored_polygon(bed, md)
	ci.draw_line(_iso(c, tw, u0, v - 0.045, z0 + 0.01), _iso(c, tw, u1, v - 0.045, z1 + 0.01), gold, 2.0)
	ci.draw_line(_iso(c, tw, u0, v + 0.045, z0 + 0.01), _iso(c, tw, u1, v + 0.045, z1 + 0.01), gold, 2.0)
	# Accelerator coils: glowing rings around the track.
	var across := Vector2(-0.5, 0.25) * tw
	for u in [-0.25, -0.02, 0.21, 0.44]:
		var ctr := _iso(c, tw, u, v, float(height.call(u)) + 0.05)
		var ring := PackedVector2Array()
		for i in 25:
			var th := i * TAU / 24.0
			ring.append(ctr + (across * cos(th) + Vector2(0, -tw) * sin(th)) * 0.075)
		ci.draw_polyline(ring, m, 4.0)
		ci.draw_polyline(ring, cyan, 2.0)
	# The cargo pod at the bottom of the track.
	var pod := _iso(c, tw, -0.38, v, z0 + 0.05)
	ci.draw_colored_polygon(_ellipse(pod, tw * 0.07, tw * 0.035), _fade(WHITE, state))
	ci.draw_polyline(_ellipse(pod, tw * 0.07, tw * 0.035), md, 1.5)
	ci.draw_circle(pod + Vector2(tw * 0.05, -tw * 0.01), tw * 0.012, gold)
	_glow(ci, _iso(c, tw, u1, v, z1 + 0.05), tw * 0.03, cyan, state)


static func _iso_sphere(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(p, rad, col.darkened(0.25))
	ci.draw_circle(p - Vector2(rad * 0.25, rad * 0.25), rad * 0.6, col)


## A Heat Main (tunnel) tile at an angle, in the same shapes as the top-down one.
static func _iso_tunnel(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var a := _fade(ORANGE, state)
	var stripe := Color(a.r, a.g, a.b, 0.85 * a.a)
	var shape := tunnel_shape(links)
	if shape == "none":
		_iso_tube(ci, c, tw, 0, -0.22, 0.22, 0.085, 0.10, m, stripe)
		_iso_cap(ci, _iso(c, tw, 0.22, 0, 0.10), tw, state)
		return
	if shape == "straight":
		var d: Vector2i = links[0]
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, -0.5, 0.5, 0.085, 0.10, m, stripe)
		return
	var back: Array = []
	var front: Array = []
	for d in links:
		(back if (d.x < 0 or d.y < 0) else front).append(d)
	for d in back:
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, 0.0, float(d.x if d.x != 0 else d.y) * 0.5, 0.085, 0.10, m, stripe)
	if shape == "tee" or shape == "cross":
		# The hub sits between the tubes going back and the ones coming forward.
		_cyl(ci, c, tw, 0, 0, 0.16, 0.20, _fade(METAL_DARK, state), m)
		ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.20), tw * 0.115, tw * 0.058), a, 2.0)
	for d in front:
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, 0.0, float(d.x if d.x != 0 else d.y) * 0.5, 0.085, 0.10, m, stripe)
	# Caps and elbows close the middle of the tile, so they go on top.
	if shape == "end":
		_iso_cap(ci, _iso(c, tw, 0, 0, 0.10), tw, state)
	elif shape == "corner":
		_iso_ball(ci, _iso(c, tw, 0, 0, 0.10), tw * 0.088, m)
		ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.10), tw * 0.055, tw * 0.033), stripe, 1.5)


## A rounded ball joint (the elbow of a corner).
static func _iso_ball(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(p, rad, col.darkened(0.25))
	ci.draw_circle(p - Vector2(rad * 0.2, rad * 0.25), rad * 0.7, col)


## The closed end of a tube at an angle: a round cap with an orange light.
static func _iso_cap(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary) -> void:
	_iso_ball(ci, p, tw * 0.085, _fade(METAL, state))
	_glow(ci, p - Vector2(0, tw * 0.02), tw * 0.022, _fade(ORANGE, state), state)


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
