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
const PINK := Color(1.00, 0.45, 0.85)

## The glowing band colour of each building (its group colour).
const ACCENT := {
	"hull": ORANGE, "main": ORANGE, "shaft": ORANGE, "shaft_base": ORANGE,
	"mirror": CYAN, "vent": GOLD, "drill": WATER, "splitter": CYAN, "vat": GREEN, "bunk": GOLD,
	"cutter": TEAL, "forge": ORANGE, "rail": GOLD,
	"commons": GREEN, "clinic": TEAL, "cache": GOLD, "lab": VIOLET, "workshop": CYAN, "warden": VIOLET,
	"fusion": Color(0.55, 0.85, 1.0), "catcher": GOLD, "reclaimer": GREEN, "fab": AMBER, "dronebay": Color(1.0, 0.72, 0.12),
	"mast": CYAN, "rescue": Color(1.0, 0.35, 0.25), "academy": Color(0.45, 0.60, 1.0), "hazlab": Color(0.60, 1.0, 0.30),
	"garden": GREEN, "lounge": PINK,
}
## What fills each dome (seen through the glass).
const INTERIOR := {
	"hull": Color(0.30, 0.26, 0.22), "vat": Color(0.05, 0.30, 0.30), "commons": Color(0.14, 0.40, 0.22),
	"clinic": Color(0.80, 0.86, 0.90), "drill": Color(0.14, 0.26, 0.44), "splitter": Color(0.20, 0.32, 0.42),
	"forge": Color(0.30, 0.16, 0.10), "lab": Color(0.20, 0.16, 0.32), "vent": Color(0.22, 0.08, 0.04),
	"bunk": Color(0.34, 0.26, 0.20), "workshop": Color(0.22, 0.26, 0.30), "cutter": Color(0.20, 0.24, 0.26),
	"fusion": Color(0.10, 0.12, 0.18), "reclaimer": Color(0.16, 0.22, 0.16), "fab": Color(0.24, 0.24, 0.26),
	"dronebay": Color(0.22, 0.22, 0.24), "rescue": Color(0.30, 0.16, 0.14), "academy": Color(0.26, 0.22, 0.18),
	"hazlab": Color(0.10, 0.16, 0.08), "garden": Color(0.14, 0.30, 0.14), "lounge": Color(0.18, 0.10, 0.24),
}
## Dome size (radius, as a fraction of a tile) for each building.
const DOME_SIZE := {"hull": 0.46, "mirror": 0.20, "cache": 0.34, "warden": 0.28, "shaft": 0.40, "rail": 0.40, "vent": 0.34, "forge": 0.34, "lab": 0.44,
	"vat": 0.44, "bunk": 0.36, "cutter": 0.38, "workshop": 0.30,
	"fusion": 0.36, "catcher": 0.16, "reclaimer": 0.30, "fab": 0.32, "dronebay": 0.28, "mast": 0.22,
	"rescue": 0.32, "academy": 0.36, "hazlab": 0.26, "garden": 0.44, "lounge": 0.34}
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## The newer buildings' fittings, drones and satellites live in sprites_more.gd.
## It is loaded on first use (it preloads this script, so this can't preload it).
static var _more_script: Script = null


static func more() -> Script:
	if _more_script == null:
		_more_script = load("res://scripts/ui/sprites_more.gd")
	return _more_script


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
## A building has a door only where a tunnel joins it, so sides without a
## tunnel ("capped") show plain wall: nothing is drawn.
static func _top_port(ci: CanvasItem, p: Vector2, s: float, state: Dictionary, capped: bool) -> void:
	if capped:
		return
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
	if type == "rail":
		_top_spin(ci, c, s, links, state)
		return
	if type == "forge":
		_top_forge(ci, c, s, rad, links, state)
		return
	if type == "lab":
		_top_scope(ci, c, s, rad, links, state)
		return
	if type == "vat":
		_top_kelpfarm(ci, c, s, rad, links, state)
		return
	if type == "cutter":
		_top_quarry(ci, c, s, rad, links, state)
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
		"drill":
			ci.draw_circle(c + Vector2(s * 0.30, s * 0.30), s * 0.13, _fade(Color(0.25, 0.45, 0.75), state))
		"bunk":
			# A planter of shrubs at the back, and a lamp post by the front door.
			var bed := Rect2(c + Vector2(-s * 0.47, -s * 0.47), Vector2(s * 0.26, s * 0.13))
			ci.draw_rect(bed, _fade(Color(0.42, 0.30, 0.20), state))
			for k in 3:
				ci.draw_circle(bed.position + Vector2(s * (0.05 + k * 0.08), s * 0.065), s * 0.045, _fade(Color(0.30, 0.68, 0.34), state))
			var post := c + Vector2(s * 0.42, s * 0.24)
			ci.draw_circle(post, s * 0.025, md)
			_glow(ci, post, s * 0.025, _fade(AMBER, state), state)
		"workshop":
			# Parts crates at the back.
			for k in 2:
				var box := Rect2(c + Vector2(-s * (0.47 - k * 0.15), -s * 0.47), Vector2(s * 0.13, s * 0.13))
				ci.draw_rect(box, _fade(Color(0.50, 0.44, 0.34), state))
				ci.draw_rect(box, md, false, 1.5)
				ci.draw_line(box.position, box.end, md, 1.0)
				ci.draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), md, 1.0)
			# A repair pad at the front-left, with a broken rover on it.
			var pad := Rect2(c + Vector2(-s * 0.47, s * 0.17), Vector2(s * 0.30, s * 0.30))
			ci.draw_rect(pad, md.lightened(0.05))
			ci.draw_rect(pad, _fade(HAZARD, state), false, 2.0)
			for k in 8:
				var t := float(k) / 8.0
				ci.draw_line(pad.position + Vector2(pad.size.x * t, 0), pad.position + Vector2(pad.size.x * (t + 0.06), 0), Color(0.05, 0.05, 0.05, a.a), 2.0)
				ci.draw_line(pad.position + Vector2(0, pad.size.y * t), pad.position + Vector2(0, pad.size.y * (t + 0.06)), Color(0.05, 0.05, 0.05, a.a), 2.0)
			var rover := Rect2(c + Vector2(-s * 0.41, s * 0.28), Vector2(s * 0.16, s * 0.11))
			for w in [rover.position, Vector2(rover.end.x, rover.position.y), rover.end, Vector2(rover.position.x, rover.end.y)]:
				ci.draw_circle(w, s * 0.028, Color(0.08, 0.08, 0.09, a.a))
			ci.draw_rect(rover, _fade(Color(0.88, 0.62, 0.28), state))
			ci.draw_rect(Rect2(rover.position + Vector2(s * 0.02, s * 0.02), Vector2(s * 0.05, s * 0.07)), _fade(CYAN, state).darkened(0.3))
			ci.draw_rect(Rect2(rover.position + Vector2(s * 0.09, s * 0.015), Vector2(s * 0.06, s * 0.08)), md)
	more().top_pre(ci, type, c, s, rad, state)
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
		"bunk":
			# Pairs of beds against the walls, a round table and a warm lamp.
			var blankets := [Color(0.85, 0.35, 0.30), Color(0.35, 0.55, 0.90), Color(0.95, 0.75, 0.30), Color(0.45, 0.75, 0.45), Color(0.70, 0.45, 0.85), Color(0.90, 0.55, 0.25), Color(0.40, 0.80, 0.85), Color(0.85, 0.50, 0.65)]
			for i in 4:
				var dir := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
				var side := dir.orthogonal()
				for j in 2:
					var bc := c + dir * rad * 0.50 + side * (j * 2 - 1) * rad * 0.13
					_rot_rect(ci, bc, dir, rad * 0.40, rad * 0.21, md)
					_rot_rect(ci, bc, dir, rad * 0.36, rad * 0.17, _fade(blankets[i * 2 + j], state))
					_rot_rect(ci, bc + dir * rad * 0.12, dir, rad * 0.09, rad * 0.15, _fade(WHITE, state))
			ci.draw_circle(c, rad * 0.22, _fade(Color(0.55, 0.40, 0.26), state))
			ci.draw_arc(c, rad * 0.22, 0, TAU, 20, md, 1.0)
			_glow(ci, c, rad * 0.12, _fade(AMBER, state), state)
			# The front door, lit, at the front-right.
			var dd := Vector2.from_angle(PI / 4.0)
			_rot_rect(ci, c + dd * rad * 0.98, dd, s * 0.07, s * 0.14, md)
			_rot_rect(ci, c + dd * rad * 0.98, dd, s * 0.04, s * 0.10, _fade(AMBER, state))
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
		"workshop":
			# A tool wall at the back, and a drone up on a yellow lift being fixed.
			ci.draw_rect(Rect2(c + Vector2(-rad * 0.50, -rad * 0.80), Vector2(rad * 1.0, rad * 0.16)), _fade(Color(0.45, 0.34, 0.22), state))
			for k in 5:
				ci.draw_line(c + Vector2(-rad * 0.42 + k * rad * 0.20, -rad * 0.76), c + Vector2(-rad * 0.36 + k * rad * 0.20, -rad * 0.68), m.lightened(0.3), 2.0)
			var lift := Rect2(c - Vector2(rad * 0.42, rad * 0.32), Vector2(rad * 0.84, rad * 0.64))
			ci.draw_rect(lift, _fade(HAZARD, state).darkened(0.1))
			ci.draw_rect(lift, md, false, 1.5)
			_top_drone(ci, c, rad * 0.40, state)
			# A robot arm reaches from the dome to the rover, welding it.
			var j0 := c + Vector2(-rad * 0.70, rad * 0.70)
			var j1 := c + Vector2(-s * 0.20, s * 0.43)
			var tip := c + Vector2(-s * 0.30, s * 0.33)
			ci.draw_polyline(PackedVector2Array([j0, j1, tip]), md, s * 0.05)
			ci.draw_polyline(PackedVector2Array([j0, j1, tip]), _fade(Color(0.95, 0.75, 0.25), state), s * 0.028)
			for j in [j0, j1]:
				ci.draw_circle(j, s * 0.03, md)
			_glow(ci, tip, s * 0.025, _fade(Color(0.80, 0.95, 1.0), state), state)
			if _lit(state):
				for k in 6:
					ci.draw_circle(tip + Vector2.from_angle(k * 1.05) * s * (0.04 + (k % 2) * 0.03), 1.4, Color(1.0, 0.85, 0.4, 0.9))
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
	more().top_post(ci, type, c, s, rad, state)
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
	if type == "rail":
		_iso_spin(ci, c, tw, links, state)
		return
	if type == "forge":
		_iso_forge(ci, c, tw, r, links, state)
		return
	if type == "lab":
		_iso_scope(ci, c, tw, r, links, state)
		return
	if type == "vat":
		_iso_kelpfarm(ci, c, tw, r, links, state)
		return
	if type == "cutter":
		_iso_quarry(ci, c, tw, r, links, state)
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
		"bunk":
			# A planter of shrubs at the back.
			_box(ci, c, tw, -0.47, -0.47, -0.21, -0.34, 0.06, _fade(Color(0.42, 0.30, 0.20), state))
			for k in 3:
				_iso_sphere(ci, _iso(c, tw, -0.42 + k * 0.08, -0.40, 0.10), tw * 0.035, _fade(Color(0.30, 0.68, 0.34), state))
		"workshop":
			# Parts crates at the back.
			var crate := _fade(Color(0.50, 0.44, 0.34), state)
			_box(ci, c, tw, -0.47, -0.47, -0.33, -0.33, 0.12, crate)
			_box(ci, c, tw, -0.30, -0.47, -0.18, -0.35, 0.08, crate)
			# A small crane at the right, lifting an engine block.
			var foot := _iso(c, tw, 0.36, -0.36)
			var mast := _iso(c, tw, 0.36, -0.36, 0.45)
			var jib := _iso(c, tw, 0.36, -0.10, 0.45)
			ci.draw_line(foot, mast, _fade(HAZARD, state).darkened(0.2), tw * 0.025)
			ci.draw_line(mast, jib, _fade(HAZARD, state).darkened(0.2), tw * 0.02)
			ci.draw_line(_iso(c, tw, 0.36, -0.36, 0.33), _iso(c, tw, 0.36, -0.24, 0.45), md, 1.5)
			ci.draw_line(jib, _iso(c, tw, 0.36, -0.10, 0.24), m, 1.0)
			_box(ci, c, tw, 0.31, -0.15, 0.41, -0.05, 0.07, _fade(Color(0.55, 0.58, 0.62), state), Color(0, 0, 0, 0), 0.17)
	more().iso_pre(ci, type, c, tw, r, h, state)
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
		"bunk":
			# The same room as the top-down view: pairs of beds against the walls
			# round a table, drawn back to front.
			var blankets := [Color(0.85, 0.35, 0.30), Color(0.35, 0.55, 0.90), Color(0.95, 0.75, 0.30), Color(0.45, 0.75, 0.45), Color(0.70, 0.45, 0.85), Color(0.90, 0.55, 0.25), Color(0.40, 0.80, 0.85), Color(0.85, 0.50, 0.65)]
			var beds: Array = []
			for i in 4:
				var dir := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
				for j in 2:
					var bc := dir * r * 0.50 + dir.orthogonal() * (j * 2 - 1) * r * 0.13
					beds.append([bc.x + bc.y, bc, dir, blankets[i * 2 + j]])
			beds.sort_custom(func(x, y): return x[0] < y[0])
			for b in beds:
				var bc: Vector2 = b[1]
				var dir: Vector2 = b[2]
				_uv_slab(ci, c, tw, bc, dir, r * 0.40, r * 0.21, 0.03, 0.05, md)
				_uv_slab(ci, c, tw, bc, dir, r * 0.36, r * 0.17, 0.012, 0.08, _fade(b[3], state))
				_uv_slab(ci, c, tw, bc + dir * r * 0.12, dir, r * 0.09, r * 0.15, 0.02, 0.085, _fade(WHITE, state))
			_cyl(ci, c, tw, 0, 0, r * 0.22, 0.05, _fade(Color(0.55, 0.40, 0.26), state), Color(0, 0, 0, 0), 0.05)
			_glow(ci, _iso(c, tw, 0, 0, h * 0.75), tw * 0.03, _fade(AMBER, state), state)
			# The lit front door, and a lamp post beside it.
			var door := _iso(c, tw, r * 0.72, r * 0.72, 0.05)
			var arch := PackedVector2Array([door + Vector2(-tw * 0.05, 0), door + Vector2(tw * 0.05, 0)])
			arch.append_array(_ellipse(door - Vector2(0, tw * 0.07), tw * 0.05, tw * 0.05, 0, -180, 10))
			ci.draw_colored_polygon(arch, md)
			var inner := PackedVector2Array([door + Vector2(-tw * 0.033, 0), door + Vector2(tw * 0.033, 0)])
			inner.append_array(_ellipse(door - Vector2(0, tw * 0.07), tw * 0.033, tw * 0.035, 0, -180, 10))
			ci.draw_colored_polygon(inner, _fade(AMBER, state))
			ci.draw_line(_iso(c, tw, 0.42, 0.24), _iso(c, tw, 0.42, 0.24, 0.22), md, tw * 0.012)
			_glow(ci, _iso(c, tw, 0.42, 0.24, 0.23), tw * 0.018, _fade(AMBER, state), state)
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
		"workshop":
			# A tool wall at the back, and a drone up on a yellow scissor lift.
			var wood := _fade(Color(0.45, 0.34, 0.22), state)
			_box(ci, c, tw, -0.18, -0.24, 0.18, -0.20, 0.14, wood, Color(0, 0, 0, 0), 0.05)
			for k in 5:
				var u := -0.14 + k * 0.07
				ci.draw_line(_iso(c, tw, u, -0.20, 0.09), _iso(c, tw, u + 0.02, -0.20, 0.16), m.lightened(0.3), 2.0)
			var yel := _fade(HAZARD, state).darkened(0.1)
			_box(ci, c, tw, -0.11, -0.09, 0.11, 0.09, 0.02, yel, Color(0, 0, 0, 0), 0.05)
			for sd in [-0.09, 0.09]:
				ci.draw_line(_iso(c, tw, -0.10, sd, 0.07), _iso(c, tw, 0.10, sd, 0.16), yel.darkened(0.2), 2.0)
				ci.draw_line(_iso(c, tw, 0.10, sd, 0.07), _iso(c, tw, -0.10, sd, 0.16), yel.darkened(0.2), 2.0)
			_box(ci, c, tw, -0.11, -0.09, 0.11, 0.09, 0.015, yel, Color(0, 0, 0, 0), 0.16)
			_iso_drone(ci, c, tw, 0.19, 0.10, state)
			# The repair pad at the left, with hazard stripes round its edge.
			var corners := [_iso(c, tw, -0.48, 0.17), _iso(c, tw, -0.17, 0.17), _iso(c, tw, -0.17, 0.48), _iso(c, tw, -0.48, 0.48)]
			ci.draw_colored_polygon(PackedVector2Array(corners), md.lightened(0.05))
			for e in 4:
				var p0: Vector2 = corners[e]
				var p1: Vector2 = corners[(e + 1) % 4]
				for k in 8:
					ci.draw_line(p0.lerp(p1, k / 8.0), p0.lerp(p1, (k + 1) / 8.0), _fade(HAZARD, state) if k % 2 == 0 else Color(0.05, 0.05, 0.05, a.a), 2.5)
			# A broken rover on the pad, its hatch open.
			var tyre := Color(0.08, 0.08, 0.09, a.a)
			for w in [Vector2(-0.43, 0.27), Vector2(-0.43, 0.41)]:
				ci.draw_colored_polygon(_ellipse(_iso(c, tw, w.x, w.y, 0.03), tw * 0.03, tw * 0.03), tyre)
			_box(ci, c, tw, -0.42, 0.25, -0.24, 0.43, 0.06, _fade(Color(0.88, 0.62, 0.28), state), Color(0, 0, 0, 0), 0.03)
			for w in [Vector2(-0.23, 0.27), Vector2(-0.23, 0.41)]:
				ci.draw_colored_polygon(_ellipse(_iso(c, tw, w.x, w.y, 0.03), tw * 0.03, tw * 0.03), tyre)
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.32, 0.28, 0.09), _iso(c, tw, -0.26, 0.28, 0.09), _iso(c, tw, -0.26, 0.40, 0.09), _iso(c, tw, -0.32, 0.40, 0.09)]), _fade(CYAN, state).darkened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, -0.34, 0.28, 0.09), _iso(c, tw, -0.34, 0.40, 0.09), _iso(c, tw, -0.42, 0.40, 0.19), _iso(c, tw, -0.42, 0.28, 0.19)]), md)
			# A robot arm reaches from beside the dome over the rover, welding it.
			_cyl(ci, c, tw, -0.16, 0.30, 0.04, 0.05, md, m)
			var joints := PackedVector2Array([_iso(c, tw, -0.16, 0.30, 0.05), _iso(c, tw, -0.20, 0.28, 0.32), _iso(c, tw, -0.33, 0.33, 0.13)])
			ci.draw_polyline(joints, md, tw * 0.03)
			ci.draw_polyline(joints, _fade(Color(0.95, 0.75, 0.25), state), tw * 0.017)
			ci.draw_circle(joints[1], tw * 0.018, md)
			_glow(ci, joints[2], tw * 0.02, _fade(Color(0.80, 0.95, 1.0), state), state)
			if _lit(state):
				for k in 6:
					ci.draw_circle(joints[2] + Vector2(cos(k * 1.05) * tw * (0.03 + (k % 2) * 0.03), -absf(sin(k * 1.05)) * tw * 0.05), 1.5, Color(1.0, 0.85, 0.4, 0.9))
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
	more().iso_post(ci, type, c, tw, r, h, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	# The two sides facing the viewer show their orange ports: a capped one where
	# there's no tunnel, an open ring where a tunnel's airlock joins.
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.86, d.y * r * 0.86, 0.12), tw, state, true)


## A port on the dome's side, seen at an angle. As with _top_port, only sides
## with a tunnel get one.
static func _iso_port(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary, capped: bool) -> void:
	if capped:
		return
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


## A rectangle centred on p, `length` long along `along` and `width` wide.
static func _rot_rect(ci: CanvasItem, p: Vector2, along: Vector2, length: float, width: float, col: Color) -> void:
	var d := along.normalized() * length * 0.5
	var w := along.normalized().orthogonal() * width * 0.5
	ci.draw_colored_polygon(PackedVector2Array([p - d - w, p + d - w, p + d + w, p - d + w]), col)


const STEEL := Color(0.38, 0.38, 0.40)


## A low flat box lying on the ground at any angle: centre bc and direction
## `along` are in tile units (u, v), `length` along it and `width` across.
static func _uv_slab(ci: CanvasItem, c: Vector2, tw: float, bc: Vector2, along: Vector2, length: float, width: float, h: float, z: float, col: Color) -> void:
	var d := along.normalized() * length * 0.5
	var w := along.normalized().orthogonal() * width * 0.5
	var lid := PackedVector2Array()
	var all := PackedVector2Array()
	for q in [bc - d - w, bc + d - w, bc + d + w, bc - d + w]:
		lid.append(_iso(c, tw, q.x, q.y, z + h))
		all.append(_iso(c, tw, q.x, q.y, z))
		all.append(_iso(c, tw, q.x, q.y, z + h))
	ci.draw_colored_polygon(Geometry2D.convex_hull(all), col.darkened(0.35))
	ci.draw_colored_polygon(lid, col)


## A four-rotor drone seen from above, one rotor's light red (it's broken).
static func _top_drone(ci: CanvasItem, p: Vector2, size: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	for k in 4:
		ci.draw_line(p, p + Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * size, md, maxf(2.0, size * 0.14))
	for k in 4:
		var e := p + Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * size
		ci.draw_circle(e, size * 0.34, Color(md.r, md.g, md.b, 0.85 * md.a))
		ci.draw_arc(e, size * 0.34, 0, TAU, 16, m.lightened(0.3), 1.0)
		if k != 2:
			var blade := Vector2.from_angle(k * 0.9) * size * 0.30
			ci.draw_line(e - blade, e + blade, m.lightened(0.4), 1.5)
	ci.draw_rect(Rect2(p - Vector2(size * 0.26, size * 0.26), Vector2(size * 0.52, size * 0.52)), _fade(WHITE, state).darkened(0.15))
	_glow(ci, p, size * 0.10, _fade(CYAN, state), state)
	_glow(ci, p + Vector2.from_angle(PI / 4.0 + PI) * size, size * 0.12, _fade(Color(1.0, 0.3, 0.3), state), state)


## The same drone at an angle, sitting at height z; `size` is in tile units.
static func _iso_drone(ci: CanvasItem, c: Vector2, tw: float, z: float, size: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var hub := _iso(c, tw, 0, 0, z + 0.02)
	var ends: Array = []
	for k in 4:
		var q := Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * size
		ends.append(_iso(c, tw, q.x, q.y, z + 0.03))
	for e in ends:
		ci.draw_line(hub, e, md, maxf(2.0, tw * 0.012))
	for k in 4:
		var e: Vector2 = ends[k]
		ci.draw_colored_polygon(_ellipse(e, tw * 0.045, tw * 0.022), Color(md.r, md.g, md.b, 0.85 * md.a))
		ci.draw_polyline(_ellipse(e, tw * 0.045, tw * 0.022), m.lightened(0.3), 1.0)
	_box(ci, c, tw, -0.04, -0.04, 0.04, 0.04, 0.03, _fade(WHITE, state).darkened(0.15), Color(0, 0, 0, 0), z)
	_glow(ci, _iso(c, tw, 0, 0, z + 0.04), tw * 0.012, _fade(CYAN, state), state)
	_glow(ci, ends[2], tw * 0.014, _fade(Color(1.0, 0.3, 0.3), state), state)


## The Kelp Vat, seen from above: a sealed pool farmed like an ocean kelp farm.
## Ropes run out from a centre buoy like spokes, with kelp growing along them,
## and two big floating rings with orange buoys hold them up. A glass pressure
## dome covers the pool, with pink grow lamps round its seal.
static func _top_kelpfarm(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var water := _fade(Color(0.06, 0.32, 0.42), state)
	var rope := _fade(Color(0.85, 0.80, 0.60), state)
	var kelp := _fade(Color(0.30, 0.78, 0.40), state)
	var buoy := _fade(ORANGE, state)
	var ring := _fade(HAZARD, state)
	ci.draw_circle(c + Vector2(rad * 0.08, rad * 0.10), rad * 1.02, Color(0, 0, 0, 0.25 * water.a))
	ci.draw_circle(c, rad, md)
	ci.draw_circle(c, rad * 0.92, water)
	for k in 3:
		ci.draw_arc(c, rad * (0.28 + k * 0.24), 0.4 * k, 0.4 * k + 2.0, 12, Color(0.6, 0.9, 1.0, 0.25 * water.a), 1.0)
	# Ropes from the centre buoy, with kelp growing along them.
	for k in 8:
		var dir := Vector2.from_angle(k * TAU / 8.0 + PI / 8.0)
		ci.draw_line(c + dir * rad * 0.10, c + dir * rad * 0.84, rope, 1.0)
		for t in 6:
			var p := c + dir * rad * (0.18 + t * 0.12)
			var side := dir.orthogonal() * (1.0 if t % 2 == 0 else -1.0)
			_rot_rect(ci, p + side * s * 0.02, dir + side * 0.6, s * 0.05, s * 0.018, kelp)
	# The floating rings and their buoys.
	for k in 2:
		var rr := rad * (0.46 + k * 0.36)
		ci.draw_arc(c, rr, 0, TAU, 48, ring, maxf(2.0, s * 0.022))
		for b in 8 + k * 4:
			var bp := c + Vector2.from_angle(b * TAU / (8 + k * 4)) * rr
			ci.draw_circle(bp, s * 0.022, buoy)
			ci.draw_circle(bp - Vector2(s * 0.007, s * 0.007), s * 0.008, Color(1, 1, 1, 0.6 * buoy.a))
	ci.draw_circle(c, s * 0.045, buoy)
	ci.draw_arc(c, s * 0.045, 0, TAU, 16, md, 1.5)
	# The glass pressure dome and its bolted seal, with grow lamps.
	var glass := _fade(GLASS, state)
	ci.draw_circle(c, rad * 0.90, Color(glass.r, glass.g, glass.b, glass.a * 0.30))
	for i in 3:
		var dir := Vector2.from_angle(i * PI / 3.0 + PI / 6.0)
		ci.draw_line(c - dir * rad * 0.88, c + dir * rad * 0.88, _fade(Color(0.75, 0.82, 0.90, 0.22), state), 1.0)
	ci.draw_arc(c - Vector2(rad * 0.25, rad * 0.25), rad * 0.45, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.5 * glass.a / GLASS.a), 2.0)
	ci.draw_arc(c, rad * 0.92, 0, TAU, 40, m.lightened(0.2), maxf(2.0, s * 0.022))
	for i in 8:
		_glow(ci, c + Vector2.from_angle(i * TAU / 8.0 + PI / 8.0) * rad * 0.96, s * 0.016, _fade(PINK, state), state)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))
	# A crate of harvested kelp at the front-left corner.
	var crate := Rect2(c + Vector2(-s * 0.49, s * 0.33), Vector2(s * 0.16, s * 0.15))
	ci.draw_rect(crate, _fade(Color(0.45, 0.32, 0.20), state))
	ci.draw_rect(crate, md, false, 1.5)
	for k in 4:
		var bundle := crate.position + Vector2(s * (0.045 + (k % 2) * 0.07), s * (0.045 + (k / 2) * 0.06))
		_rot_rect(ci, bundle, Vector2(1, 0.4), s * 0.06, s * 0.03, kelp)


## The Kelp Vat at an angle: the same ring farm in its pool, under a glass dome.
static func _iso_kelpfarm(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var water := _fade(Color(0.06, 0.32, 0.42), state)
	var rope := _fade(Color(0.85, 0.80, 0.60), state)
	var kelp := _fade(Color(0.30, 0.78, 0.40), state)
	var buoy := _fade(ORANGE, state)
	var ring := _fade(HAZARD, state)
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	_cyl(ci, c, tw, 0, 0, r, 0.04, md, md.lightened(0.1))
	var surf := _iso(c, tw, 0, 0, 0.04)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	ci.draw_colored_polygon(_ellipse(surf, rx * 0.92, ry * 0.92), water)
	# Ropes from the centre buoy with kelp along them, back ones first.
	for k in 8:
		var ang := k * TAU / 8.0 + PI / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		ci.draw_line(_iso(c, tw, dir.x * r * 0.10, dir.y * r * 0.10, 0.045), _iso(c, tw, dir.x * r * 0.84, dir.y * r * 0.84, 0.045), rope, 1.0)
		for t in 6:
			var q := dir * r * (0.18 + t * 0.12)
			var base := _iso(c, tw, q.x, q.y, 0.045)
			var lean := (1.0 if t % 2 == 0 else -1.0) * tw * 0.012
			ci.draw_line(base, base + Vector2(lean, -tw * 0.035), kelp, maxf(1.5, tw * 0.008))
			ci.draw_colored_polygon(_ellipse(base + Vector2(lean * 1.5, -tw * 0.006), tw * 0.016, tw * 0.007), kelp.darkened(0.1))
	# The floating rings and their buoys.
	for k in 2:
		var rr := 0.46 + k * 0.36
		ci.draw_polyline(_ellipse(surf, rx * rr, ry * rr, 0, 360, 40), ring, maxf(2.0, tw * 0.012))
		var n := 8 + k * 4
		for b in n:
			var ang := b * TAU / n
			_iso_sphere(ci, surf + Vector2(cos(ang) * rx * rr, sin(ang) * ry * rr), tw * 0.016, buoy)
	_iso_sphere(ci, surf - Vector2(0, tw * 0.01), tw * 0.03, buoy)
	# The glass pressure dome over the pool, sealed at the rim.
	var glass := _fade(GLASS, state)
	var hgt := 0.28 * tw
	var shell := _ellipse(surf, rx * 0.97, ry * 0.97, 0, 180, 16)
	shell.append_array(_ellipse(surf, rx * 0.97, hgt, 180, 360, 22))
	ci.draw_colored_polygon(shell, Color(glass.r, glass.g, glass.b, glass.a * 0.40))
	var rib := _fade(Color(0.80, 0.86, 0.94, 0.35), state)
	for k in [0.35, 0.7]:
		ci.draw_polyline(_ellipse(surf, rx * 0.97 * k, hgt, 180, 360, 14), rib, 1.0)
	ci.draw_polyline(_ellipse(surf - Vector2(0, hgt * 0.45), rx * 0.86, ry * 0.86, 180, 360, 16), rib, 1.0)
	ci.draw_arc(surf - Vector2(rx * 0.32, hgt * 0.58), rx * 0.30, deg_to_rad(190), deg_to_rad(250), 6, Color(1, 1, 1, 0.6 * glass.a / GLASS.a), 2.0)
	ci.draw_polyline(_ellipse(surf, rx * 0.97, ry * 0.97), m.lightened(0.2), 3.0)
	for i in 8:
		var ang := i * TAU / 8.0 + PI / 8.0
		_glow(ci, surf + Vector2(cos(ang) * rx * 0.97, sin(ang) * ry * 0.97), tw * 0.012, _fade(PINK, state), state)
	# A crate of harvested kelp at the left corner.
	_box(ci, c, tw, -0.49, 0.33, -0.33, 0.48, 0.08, _fade(Color(0.45, 0.32, 0.20), state))
	for k in 4:
		var p := _iso(c, tw, -0.45 + (k % 2) * 0.07, 0.37 + (k / 2) * 0.06, 0.085)
		ci.draw_colored_polygon(_ellipse(p, tw * 0.028, tw * 0.012), kelp)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.03), tw, state, true)


const QUARRY_STEPS := [1.0, 0.74, 0.50, 0.28]


## The Seam Cutter, seen from above: a stepped quarry pit cut into a teal ore
## seam, with a yellow gantry spanning it and a laser head cutting the seam at
## the bottom. Cut ore blocks wait at one corner and a small control dome sits
## at the back.
static func _top_quarry(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var seam := _fade(TEAL, state)
	var yel := _fade(HAZARD, state)
	var rock := _fade(Color(0.42, 0.37, 0.32), state)
	ci.draw_circle(c, rad * 1.02, md)
	for i in 16:
		var a0 := i * TAU / 16.0
		ci.draw_arc(c, rad * 0.98, a0, a0 + TAU / 32.0, 4, yel if i % 2 == 0 else Color(0.05, 0.05, 0.05, yel.a), maxf(2.0, s * 0.025))
	for k in QUARRY_STEPS.size():
		var rr: float = rad * 0.94 * QUARRY_STEPS[k]
		ci.draw_circle(c, rr, rock.darkened(0.15 * k))
		ci.draw_arc(c, rr, deg_to_rad(150), deg_to_rad(390), 32, rock.darkened(0.15 * k + 0.35), 2.0)
		if k > 0:
			for j in 3:
				var a0 := j * 2.1 + k
				ci.draw_arc(c, rr + s * 0.012, a0, a0 + 0.8, 8, seam, 1.5)
	# The glowing seam across the floor, being cut.
	var vein := PackedVector2Array([c + Vector2(-rad * 0.26, rad * 0.06), c + Vector2(-rad * 0.08, -rad * 0.04), c + Vector2(rad * 0.06, rad * 0.05), c + Vector2(rad * 0.26, -rad * 0.04)])
	ci.draw_polyline(vein, seam, maxf(2.0, s * 0.025))
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 1.0, s, state, not (d in links))
	# The yellow gantry: two rails on legs, a cross beam and the laser head.
	for u in [-0.18, 0.18]:
		ci.draw_line(c + Vector2(u * s, -s * 0.45), c + Vector2(u * s, s * 0.45), md, s * 0.05)
		ci.draw_line(c + Vector2(u * s, -s * 0.45), c + Vector2(u * s, s * 0.45), yel, s * 0.03)
		for v in [-0.45, 0.45]:
			ci.draw_rect(Rect2(c + Vector2(u * s - s * 0.035, v * s - s * 0.035), Vector2(s * 0.07, s * 0.07)), md)
	ci.draw_line(c + Vector2(-s * 0.20, 0), c + Vector2(s * 0.20, 0), md, s * 0.06)
	ci.draw_line(c + Vector2(-s * 0.20, 0), c + Vector2(s * 0.20, 0), yel.darkened(0.1), s * 0.04)
	ci.draw_rect(Rect2(c - Vector2(s * 0.05, s * 0.05), Vector2(s * 0.10, s * 0.10)), md)
	_glow(ci, c, s * 0.035, Color(0.85, 1.0, 0.98, seam.a), state)
	if _lit(state):
		for k in 6:
			ci.draw_circle(c + Vector2.from_angle(k * 1.05 + 0.3) * s * (0.06 + (k % 2) * 0.03), 1.4, Color(0.6, 1.0, 0.95, 0.9))
	# Cut ore blocks at the front-left corner.
	for k in 3:
		var bp := c + Vector2(-s * (0.46 - (k % 2) * 0.09), s * (0.34 + (k / 2) * 0.08))
		ci.draw_rect(Rect2(bp, Vector2(s * 0.08, s * 0.07)), seam.darkened(0.25))
		ci.draw_rect(Rect2(bp, Vector2(s * 0.08, s * 0.07)), md, false, 1.0)
	# The control dome at the back-left corner.
	_top_dome(ci, c + Vector2(-s * 0.39, -s * 0.39), s * 0.09, TEAL, Color(0.20, 0.24, 0.26), state)


## The Seam Cutter at an angle: the stepped pit going down, the gantry over it
## and the laser beam reaching the glowing seam at the bottom.
static func _iso_quarry(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var seam := _fade(TEAL, state)
	var yel := _fade(HAZARD, state)
	var rock := _fade(Color(0.42, 0.37, 0.32), state)
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	var dome_c := _iso(c, tw, -0.39, -0.39)
	_iso_dome(ci, dome_c, tw, 0.09, 0.08, TEAL, Color(0.20, 0.24, 0.26), state)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	var ground := _iso(c, tw, 0, 0, 0.0)
	ci.draw_colored_polygon(_ellipse(ground, rx * 1.04, ry * 1.04), md)
	for i in 16:
		var a0 := float(i) * 360.0 / 16.0
		ci.draw_polyline(_ellipse(ground, rx * 1.0, ry * 1.0, a0, a0 + 11.25, 3), yel if i % 2 == 0 else Color(0.05, 0.05, 0.05, yel.a), 2.5)
	var n: int = QUARRY_STEPS.size()
	var step_z := 0.05
	# Deepest first: the floor with its glowing seam, then each step's back wall
	# and its ledge, working up and out.
	var floor_c := ground + Vector2(0, (n - 1) * step_z * tw)
	var fr: float = QUARRY_STEPS[n - 1] * 0.94
	ci.draw_colored_polygon(_ellipse(floor_c, rx * fr, ry * fr), rock.darkened(0.6))
	ci.draw_polyline(PackedVector2Array([floor_c + Vector2(-rx * 0.24, ry * 0.05), floor_c + Vector2(-rx * 0.08, -ry * 0.10), floor_c + Vector2(rx * 0.06, ry * 0.08), floor_c + Vector2(rx * 0.24, -ry * 0.04)]), seam, 2.5)
	for k in range(n - 2, -1, -1):
		var top_c := ground + Vector2(0, k * step_z * tw)
		var low_c := ground + Vector2(0, (k + 1) * step_z * tw)
		var inner: float = QUARRY_STEPS[k + 1] * 0.94
		var outer: float = QUARRY_STEPS[k] * 0.94
		var wall := _ellipse(top_c, rx * inner, ry * inner, 180, 360, 20)
		wall.append_array(_ellipse(low_c, rx * inner, ry * inner, 360, 180, 20))
		ci.draw_colored_polygon(wall, rock.darkened(0.35 + 0.1 * k))
		ci.draw_polyline(_ellipse(top_c.lerp(low_c, 0.5), rx * inner, ry * inner, 200, 340, 14), seam, 1.5)
		for half in [[180, 360], [0, 180]]:
			var ledge := _ellipse(top_c, rx * outer, ry * outer, half[0], half[1], 20)
			ledge.append_array(_ellipse(top_c, rx * inner, ry * inner, half[1], half[0], 20))
			ci.draw_colored_polygon(ledge, rock.darkened(0.12 * k))
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 1.0, d.y * r * 1.0, 0.03), tw, state, true)
	# The yellow gantry: legs, two rails, a cross beam and the laser head.
	var rail_z := 0.30
	for u in [-0.18, 0.18]:
		for v in [-0.45, 0.45]:
			_box(ci, c, tw, u - 0.025, v - 0.025, u + 0.025, v + 0.025, rail_z, yel.darkened(0.15))
	for u in [-0.18, 0.18]:
		ci.draw_line(_iso(c, tw, u, -0.47, rail_z), _iso(c, tw, u, 0.47, rail_z), md, tw * 0.03)
		ci.draw_line(_iso(c, tw, u, -0.47, rail_z + 0.01), _iso(c, tw, u, 0.47, rail_z + 0.01), yel, tw * 0.018)
	var head := _iso(c, tw, 0, 0.0, rail_z - 0.04)
	ci.draw_line(_iso(c, tw, -0.20, 0.0, rail_z), _iso(c, tw, 0.20, 0.0, rail_z), md, tw * 0.035)
	ci.draw_line(_iso(c, tw, -0.20, 0.0, rail_z + 0.01), _iso(c, tw, 0.20, 0.0, rail_z + 0.01), yel.darkened(0.1), tw * 0.022)
	_box(ci, c, tw, -0.04, -0.04, 0.04, 0.04, 0.06, md, md.lightened(0.2), rail_z - 0.05)
	var hit := floor_c
	ci.draw_line(head, hit, Color(0.6, 1.0, 0.95, 0.35 * seam.a), tw * 0.03)
	ci.draw_line(head, hit, Color(0.9, 1.0, 1.0, 0.9 * seam.a), 2.0)
	_glow(ci, hit, tw * 0.03, Color(0.85, 1.0, 0.98, seam.a), state)
	if _lit(state):
		for k in 6:
			ci.draw_circle(hit + Vector2(cos(k * 1.05) * tw * (0.03 + (k % 2) * 0.03), -absf(sin(k * 1.05)) * tw * 0.04), 1.5, Color(0.6, 1.0, 0.95, 0.9))
	# Cut ore blocks at the left corner.
	for k in 3:
		var u := -0.47 + (k % 2) * 0.09
		var v := 0.33 + (k / 2) * 0.06
		_box(ci, c, tw, u, v, u + 0.08, v + 0.07, 0.06, seam.darkened(0.25), Color(0, 0, 0, 0), (k / 2) * 0.06)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
const MESH := Color(0.78, 0.80, 0.84)
## Where the Survey Lab's three towers stand (angles, top-down, y down).
const SCOPE_TOWERS := [225.0, 345.0, 105.0]


## The Survey Lab, seen from above: a giant radio dish set into the ground,
## three towers round it, and cables holding a receiver platform over the
## middle. A small glass control dome sits at the back-right corner.
static func _top_scope(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var mesh := _fade(MESH, state)
	var vio := _fade(VIOLET, state)
	# The dish: a rim, then the mesh bowl shaded darker towards its deep middle.
	ci.draw_circle(c + Vector2(rad * 0.06, rad * 0.08), rad * 1.02, Color(0, 0, 0, 0.25 * mesh.a))
	ci.draw_circle(c, rad, md)
	for k in 6:
		var t := float(k) / 5.0
		ci.draw_circle(c, rad * (0.92 - 0.80 * t), mesh.darkened(0.10 + 0.40 * t))
	var line := Color(md.r, md.g, md.b, 0.45 * md.a)
	for k in 4:
		ci.draw_arc(c, rad * (0.20 + k * 0.18), 0, TAU, 32, line, 1.0)
	for k in 12:
		var dir := Vector2.from_angle(k * TAU / 12.0)
		ci.draw_line(c + dir * rad * 0.12, c + dir * rad * 0.92, line, 1.0)
	ci.draw_arc(c, rad * 0.95, 0, TAU, 40, vio, maxf(1.5, s * 0.018))
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))
	# Towers and the cables from their tops to the platform.
	for deg in SCOPE_TOWERS:
		var tp := c + Vector2.from_angle(deg_to_rad(deg)) * rad * 0.98
		ci.draw_line(tp, c, Color(0.85, 0.85, 0.90, 0.75 * mesh.a), 1.5)
	for deg in SCOPE_TOWERS:
		var tp := c + Vector2.from_angle(deg_to_rad(deg)) * rad * 0.98
		ci.draw_rect(Rect2(tp - Vector2(s * 0.045, s * 0.045), Vector2(s * 0.09, s * 0.09)), md)
		ci.draw_rect(Rect2(tp - Vector2(s * 0.03, s * 0.03), Vector2(s * 0.06, s * 0.06)), m.lightened(0.15))
		_glow(ci, tp, s * 0.016, _fade(Color(1.0, 0.35, 0.35), state), state)
	# The triangular platform, its curved arm, and the receiver dome under it.
	var tri := PackedVector2Array()
	for deg in SCOPE_TOWERS:
		tri.append(c + Vector2.from_angle(deg_to_rad(deg)) * rad * 0.24)
	ci.draw_colored_polygon(tri, md)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), m.lightened(0.2), 1.5)
	ci.draw_arc(c, rad * 0.30, deg_to_rad(200), deg_to_rad(340), 12, m.lightened(0.1), maxf(2.0, s * 0.03))
	ci.draw_circle(c + Vector2(0, -rad * 0.30), s * 0.04, _fade(WHITE, state))
	_glow(ci, c + Vector2(0, -rad * 0.30), s * 0.018, vio, state)
	# The control dome at the back-right corner.
	_top_dome(ci, c + Vector2(s * 0.37, -s * 0.37), s * 0.11, VIOLET, INTERIOR["lab"], state)
	_glow(ci, c + Vector2(s * 0.37, -s * 0.37), s * 0.02, vio, state)


## The Survey Lab at an angle: the dish sunk into the ground, three towers, and
## the receiver platform hanging on cables high over the middle.
static func _iso_scope(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var mesh := _fade(MESH, state)
	var vio := _fade(VIOLET, state)
	var cable := Color(0.85, 0.85, 0.90, 0.8 * mesh.a)
	var top_z := 0.42
	var plat_z := 0.34
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	# The control dome sits beside the dish, at the right corner.
	var dome_c := _iso(c, tw, 0.37, -0.37)
	_iso_dome(ci, dome_c, tw, 0.12, 0.10, VIOLET, INTERIOR["lab"], state)
	_glow(ci, _iso(dome_c, tw, 0, 0, 0.15), tw * 0.016, vio, state)
	var towers: Array = []
	for deg in SCOPE_TOWERS:
		var q := Vector2.from_angle(deg_to_rad(deg)) * r * 0.98
		towers.append(q)
	# Back towers first (they stand behind the dish).
	for q in towers:
		if q.x + q.y < 0.1:
			_scope_tower(ci, c, tw, q, top_z, state)
	# The dish: a rim ring, and the bowl going down, shaded darker as it deepens.
	var center := _iso(c, tw, 0, 0, 0.01)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	ci.draw_colored_polygon(_ellipse(center, rx * 1.05, ry * 1.05), md)
	var depth := tw * 0.06
	for k in 6:
		var t := float(k) / 5.0
		ci.draw_colored_polygon(_ellipse(center + Vector2(0, depth * t), rx * (0.95 - 0.75 * t), ry * (0.95 - 0.75 * t)), mesh.darkened(0.05 + 0.40 * t))
	var line := Color(md.r, md.g, md.b, 0.40 * md.a)
	for k in 4:
		var t := float(k + 1) / 5.0
		ci.draw_polyline(_ellipse(center + Vector2(0, depth * t), rx * (0.95 - 0.75 * t), ry * (0.95 - 0.75 * t)), line, 1.0)
	for k in 12:
		var ang := k * TAU / 12.0
		var dir := Vector2(cos(ang), sin(ang) * 0.5)
		ci.draw_line(center + dir * rx * 0.95, center + Vector2(0, depth) + dir * rx * 0.20, line, 1.0)
	ci.draw_polyline(_ellipse(center, rx * 0.97, ry * 0.97), vio, 2.0)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.03), tw, state, true)
	# Cables from every tower top to the platform.
	var plat := _iso(c, tw, 0, 0, plat_z)
	for q in towers:
		if q.x + q.y < 0.1:
			ci.draw_line(_iso(c, tw, q.x, q.y, top_z), plat, cable, 1.5)
	# The receiver dome hanging under the platform, then the platform itself.
	var recv := _iso(c, tw, 0.0, -0.06, plat_z - 0.10)
	ci.draw_line(plat, recv, m, tw * 0.012)
	ci.draw_arc(plat + Vector2(0, tw * 0.02), tw * 0.10, deg_to_rad(20), deg_to_rad(160), 12, m.lightened(0.1), tw * 0.018)
	ci.draw_colored_polygon(_ellipse(recv, tw * 0.035, tw * 0.03, 0, 180, 10) + _ellipse(recv, tw * 0.035, tw * 0.012, 180, 360, 10), _fade(WHITE, state))
	_glow(ci, recv + Vector2(0, tw * 0.03), tw * 0.016, vio, state)
	var tri := PackedVector2Array()
	for deg in SCOPE_TOWERS:
		var q := Vector2.from_angle(deg_to_rad(deg)) * 0.10
		tri.append(_iso(c, tw, q.x, q.y, plat_z))
	ci.draw_colored_polygon(tri, md)
	ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), m.lightened(0.2), 1.5)
	# The front tower and its cable go in front of everything else.
	for q in towers:
		if q.x + q.y >= 0.1:
			_scope_tower(ci, c, tw, q, top_z, state)
			ci.draw_line(_iso(c, tw, q.x, q.y, top_z), plat, cable, 1.5)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)


## One of the Survey Lab's lattice towers, with a red light on top.
static func _scope_tower(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, top_z: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	_box(ci, c, tw, q.x - 0.03, q.y - 0.03, q.x + 0.03, q.y + 0.03, top_z, m.lightened(0.05))
	for k in 5:
		var z0 := top_z * k / 5.0
		var z1 := top_z * (k + 1) / 5.0
		ci.draw_line(_iso(c, tw, q.x + 0.03, q.y - 0.03, z0), _iso(c, tw, q.x + 0.03, q.y + 0.03, z1), md, 1.0)
		ci.draw_line(_iso(c, tw, q.x - 0.03, q.y + 0.03, z0), _iso(c, tw, q.x + 0.03, q.y + 0.03, z1), md, 1.0)
	_glow(ci, _iso(c, tw, q.x, q.y, top_z + 0.02), tw * 0.014, _fade(Color(1.0, 0.35, 0.35), state), state)
const HAZARD := Color(1.0, 0.72, 0.12)


## The Forge, seen from above: a heavy riveted steel dome (not glass) with
## glowing heat vents, hazard stripes, an ore hopper fed by a conveyor, banded
## smokestacks with a pipe looping into them, a furnace door throwing sparks,
## alloy bars, and an amber warning beacon.
static func _top_forge(ci: CanvasItem, c: Vector2, s: float, rad: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var steel := _fade(STEEL, state)
	var hot := _fade(ORANGE, state)
	var haz := _fade(HAZARD, state)
	for d in links:
		_top_link(ci, c, s, d, rad, state)
	# Conveyor from the left edge into the ore hopper.
	var belt := Rect2(Vector2(c.x - s * 0.5, c.y - s * 0.06), Vector2(s * 0.22, s * 0.12))
	ci.draw_rect(belt, md)
	for k in 3:
		ci.draw_line(Vector2(belt.position.x + k * s * 0.07, belt.position.y), Vector2(belt.position.x + k * s * 0.07, belt.end.y), steel, 1.0)
	ci.draw_circle(Vector2(belt.position.x + s * 0.08, c.y), s * 0.03, _fade(Color(0.45, 0.42, 0.40), state))
	var hop := Rect2(c + Vector2(-s * 0.42, -s * 0.36), Vector2(s * 0.20, s * 0.20))
	ci.draw_rect(hop, md)
	ci.draw_rect(hop.grow(-s * 0.04), steel.darkened(0.25))
	ci.draw_line(hop.position, hop.end, md, 1.0)
	ci.draw_line(Vector2(hop.end.x, hop.position.y), Vector2(hop.position.x, hop.end.y), md, 1.0)
	# The steel dome: shadow, hazard ring, riveted plates, glowing vents.
	ci.draw_circle(c + Vector2(rad * 0.10, rad * 0.14), rad * 1.04, Color(0, 0, 0, 0.30 * steel.a))
	ci.draw_circle(c, rad, md)
	for i in 16:
		var a0 := i * TAU / 16.0
		ci.draw_arc(c, rad * 0.93, a0, a0 + TAU / 32.0, 4, haz if i % 2 == 0 else Color(0.05, 0.05, 0.05, haz.a), maxf(2.0, s * 0.03))
	ci.draw_circle(c, rad * 0.86, steel)
	for k in 6:
		var dir := Vector2.from_angle(k * TAU / 6.0)
		ci.draw_line(c + dir * rad * 0.25, c + dir * rad * 0.86, md, 1.5)
		for j in 3:
			ci.draw_circle(c + dir * rad * (0.38 + j * 0.18) + dir.orthogonal() * s * 0.012, 1.1, md.darkened(0.3))
	ci.draw_arc(c, rad * 0.55, 0, TAU, 28, md, 1.5)
	for k in 3:
		var p := c + Vector2.from_angle(k * TAU / 3.0 + 0.5) * rad * 0.70
		ci.draw_rect(Rect2(p - Vector2(s * 0.04, s * 0.012), Vector2(s * 0.08, s * 0.024)), hot)
	ci.draw_circle(c, rad * 0.24, md)
	ci.draw_circle(c, rad * 0.16, steel.lightened(0.1))
	_glow(ci, c, s * 0.03, _fade(AMBER, state), state)
	# Pipe from the dome to the stacks, and the stacks with hazard bands.
	ci.draw_line(c + Vector2(rad * 0.4, -rad * 0.4), c + Vector2(s * 0.33, -s * 0.33), md, s * 0.07)
	ci.draw_line(c + Vector2(rad * 0.4, -rad * 0.4), c + Vector2(s * 0.33, -s * 0.33), steel, s * 0.045)
	for k in 2:
		var st := c + Vector2(s * (0.30 + k * 0.12), -s * (0.40 - k * 0.12))
		ci.draw_circle(st, s * 0.075, md)
		ci.draw_arc(st, s * 0.065, 0, TAU, 16, haz, 2.0)
		ci.draw_circle(st, s * 0.04, Color(0.03, 0.03, 0.03, steel.a))
		if _lit(state):
			ci.draw_circle(st + Vector2(s * 0.05, -s * 0.05), s * 0.05, Color(0.18, 0.18, 0.20, 0.45))
	# Furnace door at the front, glowing and throwing sparks.
	var door := c + Vector2(0, rad * 0.86)
	ci.draw_rect(Rect2(door - Vector2(s * 0.08, s * 0.05), Vector2(s * 0.16, s * 0.07)), md)
	ci.draw_rect(Rect2(door - Vector2(s * 0.06, s * 0.035), Vector2(s * 0.12, s * 0.04)), hot)
	if _lit(state):
		for k in 5:
			ci.draw_circle(door + Vector2(cos(k * 1.3) * s * 0.10, sin(k * 1.3) * s * 0.05 + s * 0.04), 1.4, Color(1.0, 0.85, 0.4, 0.9))
	# Alloy bars at the front-right.
	for k in 3:
		var bar := Rect2(c + Vector2(s * 0.24 + (k % 2) * s * 0.07, s * 0.33 - (k / 2) * s * 0.06), Vector2(s * 0.12, s * 0.05))
		ci.draw_rect(bar, _fade(Color(0.80, 0.84, 0.90), state))
		ci.draw_rect(bar, md, false, 1.0)
	for d in DIRS:
		if d != Vector2i(0, 1):
			_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))


## The Forge at an angle: the same heavy industrial plant in 3/4 view.
static func _iso_forge(ci: CanvasItem, c: Vector2, tw: float, r: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var steel := _fade(STEEL, state)
	var hot := _fade(ORANGE, state)
	var haz := _fade(HAZARD, state)
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	# Banded smokestacks behind, with smoke, and the pipe looping into them.
	for k in 2:
		var u := 0.10 + k * 0.20
		var v := -0.34 + k * 0.06
		var hgt := 0.50 - k * 0.07
		_cyl(ci, c, tw, u, v, 0.06, hgt, md, Color(0.04, 0.04, 0.04, steel.a))
		for band in [0.25, 0.45]:
			ci.draw_polyline(_ellipse(_iso(c, tw, u, v, hgt * band + 0.05), tw * 0.043, tw * 0.022, 0, 180, 10), haz, 3.0)
		if _lit(state):
			var top := _iso(c, tw, u, v, hgt)
			for j in 3:
				ci.draw_circle(top - Vector2(-j * tw * 0.03, tw * (0.05 + j * 0.06)), tw * (0.035 + j * 0.015), Color(0.18, 0.18, 0.20, 0.45 - j * 0.12))
	var pipe := PackedVector2Array([_iso(c, tw, 0.05, -0.10, 0.30), _iso(c, tw, 0.05, -0.10, 0.44), _iso(c, tw, 0.10, -0.30, 0.44)])
	ci.draw_polyline(pipe, md, tw * 0.05)
	ci.draw_polyline(pipe, steel, tw * 0.032)
	# Ore hopper on legs at the back-left, fed by a conveyor.
	_box(ci, c, tw, -0.50, -0.06, -0.24, 0.06, 0.06, md, steel.darkened(0.15), 0.10)
	for k in 2:
		_iso_sphere(ci, _iso(c, tw, -0.44 + k * 0.10, 0, 0.19), tw * 0.022, _fade(Color(0.45, 0.42, 0.40), state))
	for leg in [Vector2(-0.38, -0.30), Vector2(-0.22, -0.30), Vector2(-0.38, -0.14), Vector2(-0.22, -0.14)]:
		ci.draw_line(_iso(c, tw, leg.x, leg.y), _iso(c, tw, leg.x, leg.y, 0.26), md, tw * 0.012)
	var funnel := PackedVector2Array([_iso(c, tw, -0.42, -0.34, 0.42), _iso(c, tw, -0.18, -0.34, 0.42), _iso(c, tw, -0.26, -0.18, 0.26), _iso(c, tw, -0.34, -0.18, 0.26)])
	ci.draw_colored_polygon(funnel, steel.darkened(0.2))
	ci.draw_polyline(PackedVector2Array([funnel[0], funnel[1], funnel[2], funnel[3], funnel[0]]), md, 1.5)
	# The steel dome: hazard-striped base, riveted opaque plates, glowing vents.
	var base := _iso(c, tw, 0, 0, 0.0)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	var h := r * 0.80
	ci.draw_colored_polygon(_ellipse(base + Vector2(rx * 0.12, ry * 0.25), rx * 1.08, ry * 1.08), Color(0, 0, 0, 0.28 * steel.a))
	_cyl(ci, c, tw, 0, 0, r, 0.07, md, md)
	for i in 16:
		var a0 := float(i) * 180.0 / 16.0
		ci.draw_polyline(_ellipse(base - Vector2(0, tw * 0.035), rx, ry, a0, a0 + 11.25 * 0.9, 3), haz if i % 2 == 0 else Color(0.05, 0.05, 0.05, haz.a), tw * 0.03)
	var top := base - Vector2(0, tw * 0.07)
	var shell := _ellipse(top, rx, ry, 0, 180, 16)
	shell.append_array(_ellipse(top, rx, h * tw, 180, 360, 20))
	ci.draw_colored_polygon(shell, steel)
	ci.draw_colored_polygon(_ellipse(top - Vector2(rx * 0.30, h * tw * 0.45), rx * 0.45, h * tw * 0.35, 180, 300, 10), steel.lightened(0.12))
	for k in [0.33, 0.66]:
		ci.draw_polyline(_ellipse(top, rx * k, h * tw, 180, 360, 14), md, 1.5)
	ci.draw_polyline(_ellipse(top - Vector2(0, h * tw * 0.45), rx * 0.88, ry * 0.88, 180, 360, 16), md, 1.5)
	for k in 7:
		var ang := deg_to_rad(200 + k * 20)
		ci.draw_circle(top - Vector2(0, h * tw * 0.45) + Vector2(cos(ang) * rx * 0.88, sin(ang) * ry * 0.88), 1.3, md.darkened(0.3))
	for k in 3:
		var vp := top + Vector2((k - 1) * rx * 0.42, -h * tw * (0.30 + 0.05 * absf(k - 1)))
		ci.draw_colored_polygon(PackedVector2Array([vp + Vector2(-tw * 0.025, -tw * 0.006), vp + Vector2(tw * 0.025, -tw * 0.006), vp + Vector2(tw * 0.025, tw * 0.006), vp + Vector2(-tw * 0.025, tw * 0.006)]), hot)
	# Warning beacon on top.
	var apex := top - Vector2(0, h * tw)
	_cyl(ci, c, tw, 0, 0, 0.05, 0.05, md, md, 0.07 + h - 0.02)
	_glow(ci, apex - Vector2(0, tw * 0.05), tw * 0.025, _fade(AMBER, state), state)
	# Furnace door, sparks and alloy bars at the front.
	var mouth := _iso(c, tw, 0.05, r * 0.92, 0.10)
	ci.draw_colored_polygon(_ellipse(mouth, tw * 0.09, tw * 0.065, 180, 360, 10), md)
	ci.draw_colored_polygon(_ellipse(mouth, tw * 0.07, tw * 0.05, 180, 360, 10), hot)
	_glow(ci, mouth, tw * 0.045, hot, state)
	if _lit(state):
		for k in 5:
			ci.draw_circle(mouth + Vector2(cos(k * 1.3) * tw * 0.09, -absf(sin(k * 1.3)) * tw * 0.08), 1.5, Color(1.0, 0.85, 0.4, 0.9))
	for k in 3:
		var u := 0.30 + (k % 2) * 0.08
		_box(ci, c, tw, u - 0.04, 0.30, u + 0.03, 0.42, 0.035, _fade(Color(0.80, 0.84, 0.90), state), Color(0, 0, 0, 0), (k / 2) * 0.04)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	if not (Vector2i(1, 0) in links):
		_iso_port(ci, _iso(c, tw, r * 0.98, 0, 0.12), tw, state, true)


## The Launch Rail as a spin launcher, seen from above: a big sealed vacuum
## drum with a spinning arm inside (motion trails glowing), a launch tube
## leaving its rim, and a small control dome at the front corner.
static func _top_spin(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var gold := _fade(GOLD, state)
	var cyan := _fade(CYAN, state)
	var rad := s * 0.40
	var drum := c + Vector2(0, -s * 0.02)
	for d in links:
		_top_link(ci, c, s, d, rad, state)
	# The launch tube, leaving the drum's rim and running off the tile's edge.
	var exit := drum + Vector2(rad * 0.15, -rad * 0.98)
	_top_tube(ci, exit, Vector2(c.x + s * 0.5, exit.y), s, state)
	ci.draw_circle(c + Vector2(s * 0.47, exit.y - c.y), s * 0.03, gold)
	# The drum: shadow, bolted rim, dark window, spinning arm and trails.
	ci.draw_circle(drum + Vector2(rad * 0.08, rad * 0.10), rad * 1.02, Color(0, 0, 0, 0.28 * m.a))
	ci.draw_circle(drum, rad, md)
	ci.draw_circle(drum, rad * 0.88, m.darkened(0.15))
	for i in 20:
		ci.draw_circle(drum + Vector2.from_angle(i * TAU / 20.0) * rad * 0.94, maxf(1.2, s * 0.01), md.darkened(0.3))
	ci.draw_circle(drum, rad * 0.78, Color(0.04, 0.05, 0.08, m.a))
	for k in 3:
		ci.draw_arc(drum, rad * (0.70 - k * 0.12), 0.4 + k * 0.5, 2.2 + k * 0.5, 16, Color(cyan.r, cyan.g, cyan.b, (0.7 - k * 0.15) * cyan.a), 2.0)
	ci.draw_line(drum + Vector2(-rad * 0.66, rad * 0.20), drum + Vector2(rad * 0.66, -rad * 0.20), m.lightened(0.2), maxf(2.0, s * 0.03))
	ci.draw_circle(drum + Vector2(rad * 0.66, -rad * 0.20), s * 0.035, _fade(WHITE, state))
	ci.draw_circle(drum + Vector2(-rad * 0.66, rad * 0.20), s * 0.03, m)
	ci.draw_circle(drum, s * 0.05, md)
	_glow(ci, drum, s * 0.025, gold, state)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links))
	# The control dome at the front-left corner.
	_top_dome(ci, c + Vector2(-s * 0.36, s * 0.36), s * 0.11, gold, Color(0.26, 0.28, 0.32), state)


## The spin launcher at an angle: a wide, low vacuum drum with a window on top
## showing the spinning arm, a launch tube climbing from its rim toward the sky,
## and a small control dome in front.
static func _iso_spin(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var gold := _fade(GOLD, state)
	var cyan := _fade(CYAN, state)
	var r := 0.40
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)
	# The launch tube, behind the drum, climbing toward the sky.
	var t0 := _iso(c, tw, 0.05, -0.36, 0.14)
	var t1 := _iso(c, tw, 0.50, -0.36, 0.62)
	for u in [0.22, 0.42]:
		var zt := lerpf(0.14, 0.62, (u - 0.05) / 0.45)
		ci.draw_line(_iso(c, tw, u, -0.36), _iso(c, tw, u, -0.36, zt), md.lightened(0.15), tw * 0.016)
	ci.draw_line(t0, t1, md, tw * 0.07)
	ci.draw_line(t0, t1, m, tw * 0.05)
	ci.draw_line(t0, t1, _fade(ORANGE, state), 2.0)
	ci.draw_colored_polygon(_ellipse(t1, tw * 0.035, tw * 0.03), md)
	_glow(ci, t1, tw * 0.02, gold, state)
	# The drum.
	_cyl(ci, c, tw, 0, 0, r, 0.16, md, m.darkened(0.15))
	var top := _iso(c, tw, 0, 0, 0.16)
	var rx := r * tw * 0.72
	for i in 20:
		var ang := i * TAU / 20.0
		ci.draw_circle(top + Vector2(cos(ang) * rx * 0.93, sin(ang) * rx * 0.465), maxf(1.2, tw * 0.007), md.darkened(0.3))
	ci.draw_colored_polygon(_ellipse(top, rx * 0.80, rx * 0.40), Color(0.04, 0.05, 0.08, m.a))
	for k in 3:
		var arc := _ellipse(top, rx * (0.72 - k * 0.12), rx * (0.36 - k * 0.06), 30 + k * 30, 140 + k * 30, 14)
		ci.draw_polyline(arc, Color(cyan.r, cyan.g, cyan.b, (0.75 - k * 0.15) * cyan.a), 2.0)
	var arm_a := top + Vector2(-rx * 0.66, rx * 0.10)
	var arm_b := top + Vector2(rx * 0.66, -rx * 0.10)
	ci.draw_line(arm_a, arm_b, m.lightened(0.2), tw * 0.018)
	_iso_sphere(ci, arm_b, tw * 0.03, _fade(WHITE, state))
	ci.draw_circle(arm_a, tw * 0.022, m)
	_glow(ci, top, tw * 0.02, gold, state)
	# The control dome in front.
	_iso_dome(ci, _iso(c, tw, -0.30, 0.34), tw, 0.12, 0.10, gold, Color(0.26, 0.28, 0.32), state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.08), tw, state, true)


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
