## Building and terrain art for Lastborn Colony, drawn in code (no image files).
##
## We're in space: every building is a pressurised DOME. Domes next to each
## other are joined by a short TUNNEL, with an AIRLOCK where the tunnel meets
## each dome. Tunnel tiles are longer tunnels. Each dome shows its job
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
##          A Tunnel without links is drawn as a cross.
## Everything here is original.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")

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
const DOME_SIZE := {"battery": 0.42, "heatstore": 0.42, "school": 0.24, "hull": 0.46, "mirror": 0.42, "drill": 0.40, "cache": 0.34, "warden": 0.28, "shaft": 0.40, "rail": 0.40, "vent": 0.34, "forge": 0.34, "lab": 0.44,
	"vat": 0.44, "bunk": 0.26, "cutter": 0.38, "workshop": 0.30,
	"fusion": 0.24, "catcher": 0.16, "reclaimer": 0.30, "fab": 0.32, "dronebay": 0.28, "mast": 0.22,
	"rescue": 0.32, "academy": 0.36, "hazlab": 0.26, "garden": 0.19, "lounge": 0.24, "commons": 0.36, "clinic": 0.24}
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The Reclaimer's drop-off bay, for drawing a truck there and for animations
## later. Points are (along the hall, toward its front), in tile units from
## the tile centre: "park" is where a truck stops, "pit" where it tips its load.
const RECLAIMER_BAY := {"park": Vector2(-0.14, 0.33), "pit": Vector2(-0.42, 0.33)}
## How many doors (tunnel entrances) each building has. Sides with a tunnel
## always get an open door; spare doors show as capped ones, front sides first.
## 4: hubs where people live, gather or pass between levels.
## 2: workplaces on the way between places (in one side, out the other).
## 1: out-of-the-way sites, machines tied to the ground, and places kept apart for safety.
const DOORS := {"battery": 1, "heatstore": 1, "school": 4, "mushroom": 2, "waterworks": 2, "market": 2,
	"hull": 4, "shaft": 4, "shaft_base": 4, "bunk": 4, "commons": 4, "clinic": 4, "academy": 4, "lounge": 4, "garden": 4,
	"splitter": 2, "vat": 2, "forge": 2, "fab": 2, "reclaimer": 2, "cache": 2, "lab": 2, "workshop": 2, "warden": 2, "rescue": 2,
	"mirror": 1, "vent": 1, "drill": 1, "cutter": 1, "rail": 1, "mast": 1, "catcher": 1, "dronebay": 1, "fusion": 1, "hazlab": 1,
}
## Spare doors go on the front sides first; a two-door building's second door
## faces its first (opposite sides).
const DOOR_ORDER := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
## The sides that show a capped door for the building being drawn.
static var _cap_sides: Array = []


## The sides that show a capped door, and the way a hall lies, for the building
## being drawn. With "doors" in the state (the game's door rules), its doors are
## exactly those sides; otherwise its door count is laid out as in DOOR_ORDER.
static func _set_doors(type: String, links: Array, state: Dictionary) -> void:
	_vault_axis = 0
	if state.has("doors"):
		var doors: Array = state["doors"]
		_cap_sides = []
		for d in doors:
			if not (d in links):
				_cap_sides.append(d)
		# A two-door hall lies along its doors.
		if doors.size() == 2 and (doors[0] as Vector2i).x == 0:
			_vault_axis = 1
	else:
		_cap_sides = cap_sides(type, links)


## Which way a rounded hall (vault) lies: 0 along u, 1 along v.
static var _vault_axis := 0


## _iso for a point given along/across the hall (swapped when it lies along v).
static func _isov(c: Vector2, tw: float, along: float, across: float, h: float = 0.0) -> Vector2:
	var q := _va(along, across)
	return _iso(c, tw, q.x, q.y, h)


## (u, v) for a hall lying along u, swapped when it lies along v.
static func _va(u: float, v: float) -> Vector2:
	return Vector2(u, v) if _vault_axis == 0 else Vector2(v, u)


static func cap_sides(type: String, links: Array) -> Array:
	var spare := int(DOORS.get(type, 2)) - links.size()
	var out: Array = []
	if int(DOORS.get(type, 2)) == 2 and links.size() == 1 and not (-(links[0] as Vector2i) in links):
		return [-(links[0] as Vector2i)]
	for d in DOOR_ORDER:
		if spare <= 0:
			break
		if not (d in links):
			out.append(d)
			spare -= 1
	return out

## Not every building is a dome: some are rounded halls (a barrel vault, like
## an arched hangar), a tall tank, or a tower. All are sealed and rounded.
const SHAPE := {
	"workshop": "vault", "fab": "vault", "dronebay": "vault", "cache": "vault", "rescue": "vault", "reclaimer": "vault",
	"splitter": "silo", "warden": "tower",
}


## A vault's half-length (along u) and half-width (across), in tile units, from its size.
static func _vault_dims(r: float) -> Vector2:
	return Vector2(r * 1.3, r * 0.82)


## How far the hull reaches from the centre toward side d (tile units): where its doors are.
static func _ext(type: String, d: Vector2i, r: float) -> float:
	match SHAPE.get(type, "dome"):
		"vault":
			var dims := _vault_dims(r)
			var along_u := _vault_axis == 0
			return (dims.x if d.x != 0 else dims.y) if along_u else (dims.y if d.x != 0 else dims.x)
		"silo":
			return r * 0.78
	return r


## The hull's height (tile units), used for things placed on top.
static func _hull_height(type: String, r: float) -> float:
	match SHAPE.get(type, "dome"):
		"vault":
			return _vault_dims(r).y + 0.03
		"silo":
			return r * 1.9
		"tower":
			return 0.62
	return r * 0.75


static func _top_hull(ci: CanvasItem, type: String, c: Vector2, rad: float, acc: Color, inside: Color, state: Dictionary) -> void:
	match SHAPE.get(type, "dome"):
		"vault":
			var dims := _vault_dims(rad)
			if _vault_axis == 1:
				dims = Vector2(dims.y, dims.x)
			var box := Rect2(c - dims, dims * 2.0)
			ci.draw_rect(Rect2(box.position + Vector2(rad * 0.08, rad * 0.12), box.size), Color(0, 0, 0, 0.28 * _fade(Color.WHITE, state).a))
			ci.draw_rect(box, _fade(METAL_DARK, state))
			ci.draw_rect(box.grow(-rad * 0.10), _fade(inside, state))
			ci.draw_rect(box.grow(-rad * 0.05), _fade(acc, state), false, maxf(1.5, rad * 0.06))
			var glass := _fade(GLASS, state)
			ci.draw_rect(box.grow(-rad * 0.10), Color(glass.r, glass.g, glass.b, glass.a * 0.55))
			for k in 5:
				var x := box.position.x + box.size.x * (k + 1) / 6.0
				ci.draw_line(Vector2(x, box.position.y + rad * 0.1), Vector2(x, box.end.y - rad * 0.1), _fade(Color(0.75, 0.82, 0.90, 0.35), state), 1.0)
			ci.draw_line(Vector2(box.position.x + rad * 0.1, c.y - dims.y * 0.35), Vector2(box.end.x - rad * 0.1, c.y - dims.y * 0.35), Color(1, 1, 1, 0.45 * glass.a / GLASS.a), 2.0)
		"silo":
			var r2 := rad * 0.78
			ci.draw_circle(c, r2 * 1.12, _fade(METAL_DARK, state))
			ci.draw_arc(c, r2 * 1.05, 0, TAU, 36, _fade(acc, state), maxf(1.5, rad * 0.06))
			_top_dome(ci, c, r2, acc, inside, state)
		"tower":
			ci.draw_circle(c + Vector2(rad * 0.1, rad * 0.14), rad * 1.04, Color(0, 0, 0, 0.28 * _fade(Color.WHITE, state).a))
			ci.draw_circle(c, rad, _fade(METAL_DARK, state))
			ci.draw_circle(c, rad * 0.88, _fade(METAL, state).darkened(0.1))
			ci.draw_arc(c, rad * 0.94, 0, TAU, 40, _fade(acc, state), maxf(1.5, rad * 0.08))
		_:
			_top_dome(ci, c, rad, acc, inside, state)


static func _iso_hull(ci: CanvasItem, type: String, c: Vector2, tw: float, r: float, h: float, acc: Color, inside: Color, state: Dictionary) -> void:
	match SHAPE.get(type, "dome"):
		"vault":
			_iso_vault(ci, c, tw, _vault_dims(r), acc, inside, state)
		"silo":
			# A tall banded tank with a glass cap.
			var r2 := r * 0.78
			var body_h := h - r2 * 0.6 - 0.05
			var m := _fade(METAL, state)
			_cyl(ci, c, tw, 0, 0, r2 * 1.08, 0.04, _fade(METAL_DARK, state), _fade(METAL_DARK, state))
			_cyl(ci, c, tw, 0, 0, r2, body_h, m, m, 0.04)
			var base := _iso(c, tw, 0, 0, 0.04)
			var rx := r2 * tw * 0.72
			for k in 3:
				var z := 0.04 + body_h * (0.25 + k * 0.25)
				ci.draw_polyline(_ellipse(base - Vector2(0, (z - 0.04) * tw), rx, rx * 0.5, 0, 180, 16), _fade(acc, state) if k == 1 else m.darkened(0.25), 2.5 if k == 1 else 1.5)
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(rx * 0.55, rx * 0.2), base + Vector2(rx * 0.75, rx * 0.12), base + Vector2(rx * 0.75, rx * 0.12) - Vector2(0, body_h * tw * 0.9), base + Vector2(rx * 0.55, rx * 0.2) - Vector2(0, body_h * tw * 0.9)]), m.lightened(0.15))
			_iso_dome(ci, c - Vector2(0, (body_h + 0.02) * tw), tw, r2, r2 * 0.6, acc, inside, state)
		"tower":
			# A watchtower: a low drum, a tall column and a glass lookout cab.
			var md := _fade(METAL_DARK, state)
			var m := _fade(METAL, state)
			# The drum is as tall as the airlocks, so tunnels meet a real wall.
			_cyl(ci, c, tw, 0, 0, r, 0.24, md.lightened(0.1), m)
			ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.02), r * tw * 0.72, r * tw * 0.36, 0, 180, 18), _fade(acc, state), 2.0)
			ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.22), r * tw * 0.72, r * tw * 0.36, 0, 180, 18), md, 1.5)
			for k in 3:
				var ang := deg_to_rad(60.0 + k * 30.0)
				var wp := _iso(c, tw, 0, 0, 0.16) + Vector2(cos(ang) * r * tw * 0.72, sin(ang) * r * tw * 0.36)
				ci.draw_rect(Rect2(wp - Vector2(tw * 0.012, tw * 0.015), Vector2(tw * 0.024, tw * 0.025)), _fade(Color(1.0, 0.82, 0.45), state))
			_cyl(ci, c, tw, 0, 0, 0.07, 0.24, m.darkened(0.1), m, 0.24)
			for k in 2:
				var z := 0.30 + k * 0.08
				ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, z), 0.07 * tw * 0.72, 0.07 * tw * 0.36, 0, 180, 10), md, 1.5)
			_cyl(ci, c, tw, 0, 0, 0.15, 0.03, md, md, 0.48)
			_cyl(ci, c, tw, 0, 0, 0.13, 0.08, _fade(GLASS, state).lightened(0.2), md.lightened(0.2), 0.51)
			_cyl(ci, c, tw, 0, 0, 0.15, 0.02, md, m, 0.59)
			_glow(ci, _iso(c, tw, 0, 0, 0.55), tw * 0.04, _fade(acc, state), state)
			if _lit(state):
				var src := _iso(c, tw, 0.1, 0.06, 0.55)
				ci.draw_colored_polygon(PackedVector2Array([src, src + Vector2(tw * 0.40, tw * 0.16), src + Vector2(tw * 0.34, tw * 0.28)]), Color(acc.r, acc.g, acc.b, 0.18))
		_:
			_iso_dome(ci, c, tw, r, h, acc, inside, state)


## A barrel vault at an angle: an arched glass hall lying along u, with metal
## ribs, a glazed end and a coloured band round its foot.
static func _iso_vault(ci: CanvasItem, c: Vector2, tw: float, dims: Vector2, acc: Color, inside: Color, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var hl := dims.x
	var hw := dims.y
	var z0 := 0.03
	var lo := _va(-hl - 0.01, -hw - 0.01)
	var hi := _va(hl + 0.01, hw + 0.01)
	_box(ci, c, tw, lo.x, lo.y, hi.x, hi.y, z0, md, md.lightened(0.1))
	var shell := PackedVector2Array()
	for t in [-hl, hl]:
		for k in 13:
			var a := PI * k / 12.0
			shell.append(_isov(c, tw, t, hw * cos(a), z0 + hw * sin(a)))
	var hull := Geometry2D.convex_hull(shell)
	ci.draw_colored_polygon(hull, _fade(inside, state))
	var glass := _fade(GLASS, state)
	ci.draw_colored_polygon(hull, Color(glass.r, glass.g, glass.b, glass.a * 0.6))
	var rib := _fade(Color(0.80, 0.86, 0.94, 0.45), state)
	for k in 6:
		var t := -hl + 2.0 * hl * k / 5.0
		var arc := PackedVector2Array()
		for j in 13:
			var a := PI * j / 12.0
			arc.append(_isov(c, tw, t, hw * cos(a), z0 + hw * sin(a)))
		ci.draw_polyline(arc, rib if k < 5 else md.lightened(0.2), 1.0 if k < 5 else 2.5)
	ci.draw_line(_isov(c, tw, -hl, hw * cos(1.2), z0 + hw * sin(1.2)), _isov(c, tw, hl, hw * cos(1.2), z0 + hw * sin(1.2)), Color(1, 1, 1, 0.5 * glass.a / GLASS.a), 2.0)
	ci.draw_line(_isov(c, tw, -hl, hw, z0), _isov(c, tw, hl, hw, z0), _fade(acc, state), maxf(1.5, tw * 0.012))
	ci.draw_line(_isov(c, tw, hl, -hw, z0), _isov(c, tw, hl, hw, z0), _fade(acc, state), maxf(1.5, tw * 0.012))


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
	if anim_t > 0.0:
		# Lights pulse gently, each a little out of step with the others.
		var pulse := 0.75 + 0.25 * sin(anim_t * 3.0 + p.x * 0.07 + p.y * 0.05)
		c = Color(c.r, c.g, c.b, c.a * pulse)
		r *= 0.9 + 0.1 * pulse
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
## Sides without a tunnel get a capped door only while the building has doors
## to spare (DOORS); the rest are plain wall.
static func _top_port(ci: CanvasItem, p: Vector2, s: float, state: Dictionary, capped: bool, dir: Vector2i = Vector2i.ZERO) -> void:
	if capped and not (dir in _cap_sides):
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
	_set_doors(type, links, state)
	if type == "main":
		_top_tunnel(ci, c, s, links, state)
		return
	var rad: float = float(DOME_SIZE.get(type, 0.38)) * s
	for d in links:
		_top_link(ci, c, s, d, _ext(type, d, rad / s) * s, state)
	if type == "hull":
		_top_pad(ci, c, s, rad, links, state)
		return
	if type == "shaft":
		_top_hole(ci, c, s, rad, links, state)
		return
	if type == "mast":
		_top_radio(ci, c, s, links, state)
		return
	if type == "mirror":
		_top_mirror(ci, c, s, links, state)
		return
	if type == "drill":
		_top_drill(ci, c, s, links, state)
		return
	if type == "rescue":
		_top_rescue(ci, c, s, links, state)
		return
	if type == "commons":
		_top_commons(ci, c, s, links, state)
		return
	if type == "clinic":
		_top_clinic(ci, c, s, links, state)
		return
	if type == "garden":
		_top_garden(ci, c, s, links, state)
		return
	if type == "bunk":
		_top_bunk(ci, c, s, links, state)
		return
	if type in ["battery", "heatstore", "mushroom", "waterworks", "market", "school"]:
		_top_new(ci, type, c, s, links, state)
		return
	if type == "lounge":
		_top_lounge(ci, c, s, links, state)
		return
	if type == "fusion":
		_top_fusion(ci, c, s, links, state)
		return
	if type == "reclaimer":
		_top_reclaimer(ci, c, s, links, state)
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
	_top_hull(ci, type, c, rad, acc, INTERIOR.get(type, Color(0.26, 0.28, 0.32)), state)
	# Every side without a tunnel still has a capped orange port, ready for one.
	for d in DIRS:
		if not (d in links):
			_top_port(ci, c + Vector2(d) * _ext(type, d, rad / s) * s * 0.92, s, state, true, d)
		else:
			_top_port(ci, c + Vector2(d) * _ext(type, d, rad / s) * s * 0.92, s, state, false, d)
	# What shows through the glass, or on top.
	match type:
		"hull":
			ci.draw_arc(c, rad * 0.62, 0, TAU, 32, a, 3.0)
			ci.draw_line(c, c + Vector2(rad * 0.45, -rad * 0.45), m, 3.0)
			_glow(ci, c + Vector2(rad * 0.45, -rad * 0.45), s * 0.04, a, state)
			_glow(ci, c, s * 0.06, a, state)
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
		"splitter":
			ci.draw_circle(c + Vector2(-rad * 0.3, 0), rad * 0.28, _fade(Color(0.80, 0.92, 1.0, 0.8), state))
			ci.draw_circle(c + Vector2(rad * 0.3, 0), rad * 0.22, _fade(Color(0.80, 0.92, 1.0, 0.8), state))
		"rail":
			_glow(ci, c, s * 0.035, a, state)
		"cache":
			# Crates and barrels stacked in the warehouse hall.
			for i in 6:
				var box := Rect2(c + Vector2(-rad * 0.95 + (i % 3) * rad * 0.66, -rad * 0.45 + (i / 3) * rad * 0.5), Vector2(rad * 0.5, rad * 0.38))
				ci.draw_rect(box, _fade(Color(0.62, 0.50, 0.34), state) if i % 2 == 0 else _fade(Color(0.40, 0.52, 0.62), state))
				ci.draw_rect(box, md, false, 1.0)
		"workshop":
			# A tool wall at the back, and a drone (a rover missing a wheel) up on a yellow lift.
			ci.draw_rect(Rect2(c + Vector2(-rad * 0.50, -rad * 0.80), Vector2(rad * 1.0, rad * 0.16)), _fade(Color(0.45, 0.34, 0.22), state))
			for k in 5:
				ci.draw_line(c + Vector2(-rad * 0.42 + k * rad * 0.20, -rad * 0.76), c + Vector2(-rad * 0.36 + k * rad * 0.20, -rad * 0.68), m.lightened(0.3), 2.0)
			var lift := Rect2(c - Vector2(rad * 0.42, rad * 0.32), Vector2(rad * 0.84, rad * 0.64))
			ci.draw_rect(lift, _fade(HAZARD, state).darkened(0.1))
			ci.draw_rect(lift, md, false, 1.5)
			_top_drone(ci, c, rad * 0.40, state, true)
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
			# The lookout cab on top of the tower, with its searchlight.
			ci.draw_circle(c, rad * 0.50, md)
			ci.draw_circle(c, rad * 0.42, _fade(GLASS, state).lightened(0.2))
			ci.draw_circle(c, rad * 0.30, m)
			_glow(ci, c, rad * 0.20, a, state)
			ci.draw_line(c, c + Vector2(s * 0.42, -s * 0.18), Color(a.r, a.g, a.b, 0.45 * a.a), s * 0.08)
		"shaft":
			ci.draw_rect(Rect2(c - Vector2(rad * 0.55, rad * 0.55), Vector2(rad * 1.1, rad * 1.1)), Color(0.02, 0.02, 0.04, a.a))
			for i in 3:
				ci.draw_line(c + Vector2(-rad * 0.4, -rad * 0.3 + i * rad * 0.3), c + Vector2(rad * 0.4, -rad * 0.3 + i * rad * 0.3), a, 2.0)
		"shaft_base":
			# Looking down on the lift tube: ribbed rings round the lift car.
			ci.draw_circle(c, rad * 0.55, md)
			for k in [0.55, 0.47]:
				ci.draw_arc(c, rad * k, 0, TAU, 24, m.lightened(0.15), 1.5)
			ci.draw_circle(c, rad * 0.38, Color(0.02, 0.02, 0.04, a.a))
			ci.draw_rect(Rect2(c - Vector2(rad * 0.2, rad * 0.2), Vector2(rad * 0.4, rad * 0.4)), _fade(Color(0.95, 0.75, 0.25), state))
			ci.draw_line(c - Vector2(rad * 0.2, 0), c + Vector2(rad * 0.2, 0), md, 1.5)
			for i in 4:
				_glow(ci, c + Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * rad * 0.72, s * 0.03, a, state)
	more().top_post(ci, type, c, s, rad, state)
	if not state.get("built", true):
		if SHAPE.get(type, "dome") == "vault":
			var dims := _vault_dims(rad)
			ci.draw_rect(Rect2(c - dims, dims * 2.0), Color(acc.r, acc.g, acc.b, 0.8), false, 1.5)
		else:
			ci.draw_arc(c, rad, 0, TAU, 32, Color(acc.r, acc.g, acc.b, 0.8), 1.5)


## The Landing Pad, like a helipad: a round platform with a
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
	# A small airlock building at each door, on the pad's edge; tunnels run into it.
	for d in DIRS:
		_top_gatehouse(ci, c, s, rad, d, state)
		_top_port(ci, c + Vector2(d) * (rad * 0.89 + s * 0.07), s, state, not (d in links), d)
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
	# The lift tube rising out of the pit, seen from above: its lid, the
	# A-frame across it and the cable wheel.
	var tube := rad * 0.60
	ci.draw_circle(c, tube, m.darkened(0.1))
	ci.draw_arc(c, tube, 0, TAU, 28, orange, maxf(1.5, s * 0.02))
	ci.draw_arc(c, tube * 0.8, 0, TAU, 24, m.lightened(0.2), 1.0)
	ci.draw_circle(c, tube * 0.45, md)
	ci.draw_line(c - Vector2(tube * 0.95, 0), c + Vector2(tube * 0.95, 0), md.lightened(0.25), maxf(2.0, s * 0.03))
	ci.draw_rect(Rect2(c - Vector2(s * 0.015, s * 0.06), Vector2(s * 0.03, s * 0.12)), m.lightened(0.2))
	ci.draw_circle(c, s * 0.018, md)
	_glow(ci, c + Vector2(0, -tube * 0.7), s * 0.018, orange, state)
	for i in 4:
		_glow(ci, c + Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * rad * 0.97, s * 0.02, orange, state)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links), d)


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


## A Tunnel tile, top-down. Straight runs are one continuous tube,
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
## When true, u and v trade places: a drawing made facing along u then faces
## along v instead. In this view that is a left-right mirror, and nearer and
## farther stay the same, so a rover can be turned without redrawing it.
static var swap_uv := false


static func _iso(c: Vector2, tw: float, u: float, v: float, h: float = 0.0) -> Vector2:
	if swap_uv:
		return c + Vector2((v - u) * tw * 0.5, (u + v) * tw * 0.25 - h * tw)
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
## A round tube lying along one axis of the tile (axis 0 = u, 1 = v), from a0
## to a1, its centre line at height z, radius rr (all in tile widths). It is
## shaded like a metal cylinder lit from above, with ribs every fifth of a
## tile, an optional coloured stripe along its upper side, and flanges (raised
## bands) where it meets the next tile's tube.
static func _iso_tube(ci: CanvasItem, c: Vector2, tw: float, axis: int, a0: float, a1: float, rr: float, z: float, col: Color, stripe: Color = Color(0, 0, 0, 0), flanges: bool = true) -> void:
	var lo := minf(a0, a1)
	var hi := maxf(a0, a1)
	if hi - lo <= 0.0:
		return
	var across := Vector2(-0.5, 0.25) * tw if axis == 0 else Vector2(0.5, 0.25) * tw
	var up := Vector2(0, -tw)
	var b0 := _iso(c, tw, lo, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, lo, z)
	var b1 := _iso(c, tw, hi, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, hi, z)
	# Silhouette in the darkest shade, then bands round the visible side, back to
	# front, each lit by how much it faces up and toward the viewer.
	var all := PackedVector2Array()
	for b in [b0, b1]:
		for i in 16:
			var th := i * TAU / 16.0
			all.append(b + (across * cos(th) + up * sin(th)) * rr)
	ci.draw_colored_polygon(Geometry2D.convex_hull(all), col.darkened(0.45))
	var steps := 9
	for k in steps:
		var t0 := deg_to_rad(170.0 - k * 26.0)
		var t1 := deg_to_rad(170.0 - (k + 1) * 26.0)
		var mid := (t0 + t1) * 0.5
		var light := clampf(cos(mid) * 0.35 + sin(mid) * 0.75, -0.6, 1.0)
		var shade := col.lightened(light * 0.35) if light > 0.0 else col.darkened(-light * 0.5)
		var o0 := (across * cos(t0) + up * sin(t0)) * rr
		var o1 := (across * cos(t1) + up * sin(t1)) * rr
		ci.draw_colored_polygon(PackedVector2Array([b0 + o0, b1 + o0, b1 + o1, b0 + o1]), shade)
	# A soft highlight along the top.
	var hl := (across * cos(deg_to_rad(80.0)) + up * sin(deg_to_rad(80.0))) * rr
	ci.draw_line(b0 + hl, b1 + hl, col.lightened(0.45), maxf(1.0, tw * rr * 0.12))
	if stripe.a > 0.0:
		var so := (across * cos(deg_to_rad(40.0)) + up * sin(deg_to_rad(40.0))) * rr
		ci.draw_line(b0 + so, b1 + so, stripe, maxf(1.5, tw * rr * 0.18))
	# Ribs, and flanges where the tube crosses a tile edge.
	var rib := col.darkened(0.35)
	var t := ceilf(lo * 5.0 - 0.001) / 5.0
	while t <= hi + 0.001:
		var edge := absf(absf(t) - 0.5) < 0.01
		if t > lo + 0.01 or edge:
			if edge and flanges:
				_flange(ci, c, tw, axis, t, rr, z, col)
			else:
				var base := _iso(c, tw, t, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, t, z)
				var arc := PackedVector2Array()
				for j in 12:
					var th := deg_to_rad(-80.0 + j * 250.0 / 11.0)
					arc.append(base + (across * cos(th) + up * sin(th)) * rr)
				ci.draw_polyline(arc, rib, 1.0)
		t += 0.2


## A raised ring round a tube at position t along its axis: where two tubes
## join, or where a tube plugs into a junction.
static func _flange(ci: CanvasItem, c: Vector2, tw: float, axis: int, t: float, rr: float, z: float, col: Color) -> void:
	var across := Vector2(-0.5, 0.25) * tw if axis == 0 else Vector2(0.5, 0.25) * tw
	var up := Vector2(0, -tw)
	var base := _iso(c, tw, t, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, t, z)
	var ring := PackedVector2Array()
	for j in 17:
		var th := j * TAU / 16.0
		ring.append(base + (across * cos(th) + up * sin(th)) * rr * 1.2)
	ci.draw_colored_polygon(ring, col.darkened(0.15))
	ci.draw_polyline(ring, col.darkened(0.45), 1.0)
	var lit := PackedVector2Array()
	for j in 8:
		var th := deg_to_rad(40.0 + j * 100.0 / 7.0)
		lit.append(base + (across * cos(th) + up * sin(th)) * rr * 1.12)
	ci.draw_polyline(lit, col.lightened(0.35), maxf(1.0, tw * rr * 0.15))


## A round tube from the building's edge to the tile edge, with a neat airlock
## collar where it meets the building.
static func _iso_link(ci: CanvasItem, c: Vector2, tw: float, d: Vector2i, r: float, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var amber := _fade(AMBER, state)
	var orange := _fade(ORANGE, state)
	var stripe := Color(orange.r, orange.g, orange.b, 0.9 * orange.a)
	var axis := 0 if d.x != 0 else 1
	var sign := float(d.x if d.x != 0 else d.y)
	var rr := 0.07
	var z := 0.09
	var c0 := sign * (r - 0.02)
	var c1 := sign * (r + 0.07)
	# The part of the tube farther from the viewer goes first, then the collar,
	# then the nearer part, so each covers what is behind it.
	var inner := [sign * r * 0.8, c0]
	var outer := [c1, sign * 0.5]
	var first: Array = outer if sign < 0.0 else inner
	var last: Array = inner if sign < 0.0 else outer
	_iso_tube(ci, c, tw, axis, first[0], first[1], rr, z, m, stripe)
	# The collar: a wider, short ring of metal with an amber band.
	_iso_tube(ci, c, tw, axis, c0, c1, rr * 1.38, z, m.lightened(0.08), Color(0, 0, 0, 0), false)
	var mid_t := (c0 + c1) * 0.5
	var mid := _iso(c, tw, mid_t, 0.0, z) if axis == 0 else _iso(c, tw, 0.0, mid_t, z)
	var across := Vector2(-0.5, 0.25) * tw if axis == 0 else Vector2(0.5, 0.25) * tw
	var band := PackedVector2Array()
	for j in 14:
		var th := deg_to_rad(-80.0 + j * 250.0 / 13.0)
		band.append(mid + (across * cos(th) + Vector2(0, -tw) * sin(th)) * rr * 1.40)
	ci.draw_polyline(band, amber, maxf(1.5, tw * 0.012))
	# A small status light on top of the collar.
	_glow(ci, mid + Vector2(0, -tw) * rr * 1.45, tw * 0.008, amber, state)
	_iso_tube(ci, c, tw, axis, last[0], last[1], rr, z, m, stripe)


## Draws building `type` on the diamond tile centred at `c`, `tw` pixels wide.
static func draw_iso(ci: CanvasItem, type: String, c: Vector2, tw: float, state: Dictionary = {}) -> void:
	var acc: Color = ACCENT.get(type, CYAN)
	var a := _fade(acc, state)
	var m := _fade(METAL, state)
	var md := _fade(METAL_DARK, state)
	var links := _links(type, state)
	_set_doors(type, links, state)
	if type == "main":
		_iso_tunnel(ci, c, tw, links, state)
		return
	var r: float = float(DOME_SIZE.get(type, 0.38))
	var h := _hull_height(type, r)
	if type == "hull":
		_iso_pad(ci, c, tw, r, links, state)
		return
	if type == "shaft":
		_iso_hole(ci, c, tw, r, links, state)
		return
	if type == "shaft_base":
		_iso_landing(ci, c, tw, links, state)
		return
	if type == "catcher":
		_iso_catcher(ci, c, tw, links, state)
		return
	if type == "mast":
		_iso_radio(ci, c, tw, links, state)
		return
	if type == "mirror":
		_iso_mirror(ci, c, tw, links, state)
		return
	if type == "drill":
		_iso_drill(ci, c, tw, links, state)
		return
	if type == "rescue":
		_iso_rescue(ci, c, tw, links, state)
		return
	if type == "commons":
		_iso_commons(ci, c, tw, links, state)
		return
	if type == "clinic":
		_iso_clinic(ci, c, tw, links, state)
		return
	if type == "garden":
		_iso_garden(ci, c, tw, links, state)
		return
	if type == "bunk":
		_iso_bunk(ci, c, tw, links, state)
		return
	if type == "battery":
		_iso_battery(ci, c, tw, links, state)
		return
	if type == "heatstore":
		_iso_heatstore(ci, c, tw, links, state)
		return
	if type == "mushroom":
		_iso_mushroom(ci, c, tw, links, state)
		return
	if type == "waterworks":
		_iso_waterworks(ci, c, tw, links, state)
		return
	if type == "market":
		_iso_market(ci, c, tw, links, state)
		return
	if type == "school":
		_iso_school(ci, c, tw, links, state)
		return
	if type == "lounge":
		_iso_lounge(ci, c, tw, links, state)
		return
	if type == "fusion":
		_iso_fusion(ci, c, tw, links, state)
		return
	if type == "reclaimer":
		_iso_reclaimer(ci, c, tw, links, state)
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
			_iso_link(ci, c, tw, d, _ext(type, d, r), state)
	# Fittings behind or beside the dome.
	match type:
		"splitter":
			for v in [-0.34, 0.0]:
				_cyl(ci, c, tw, 0.34, v - 0.04, 0.10, 0.22, m, m)
				_iso_sphere(ci, _iso(c, tw, 0.34, v - 0.04, 0.32), tw * 0.08, _fade(Color(0.85, 0.95, 1.0), state))
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
				_steam(ci, _iso(c, tw, -0.05, -0.36, 0.44), tw, 1.0, 3, 0.30)
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
	_iso_hull(ci, type, c, tw, r, h, acc, INTERIOR.get(type, Color(0.26, 0.28, 0.32)), state)
	var apex := _iso(c, tw, 0, 0, 0.05 + h)
	# Features on or through the dome.
	match type:
		"hull":
			ci.draw_line(apex, apex - Vector2(0, tw * 0.22), m, tw * 0.02)
			_glow(ci, apex - Vector2(0, tw * 0.22), tw * 0.03, a, state)
			_glow(ci, _iso(c, tw, 0, 0, 0.18), tw * 0.06, a, state)
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
		"splitter":
			_glow(ci, _iso(c, tw, 0, 0, 0.16), tw * 0.05, a, state)
		"rail":
			_glow(ci, _iso(c, tw, 0, 0, 0.10), tw * 0.03, a, state)
		"cache":
			# Stacks of crates and barrels inside the warehouse hall.
			var crate := _fade(Color(0.62, 0.50, 0.34), state)
			for k in 6:
				var u := -0.30 + (k % 3) * 0.20
				var v := -0.10 + (k / 3) * 0.10
				_box(ci, c, tw, u, v, u + 0.12, v + 0.08, 0.08, crate if k % 2 == 0 else _fade(Color(0.40, 0.52, 0.62), state), Color(0, 0, 0, 0), 0.03)
			_box(ci, c, tw, -0.30, -0.10, -0.18, -0.02, 0.07, crate.darkened(0.1), Color(0, 0, 0, 0), 0.11)
			_box(ci, c, tw, 0.10, -0.10, 0.22, -0.02, 0.07, crate.darkened(0.1), Color(0, 0, 0, 0), 0.11)
		"workshop":
			# A tool wall at the back, and a drone (a rover missing a wheel) up on a yellow scissor lift.
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
			_iso_drone(ci, c, tw, 0.18, 0.11, state, true)
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
			pass
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
			_iso_link(ci, c, tw, d, _ext(type, d, r), state)
	# The two sides facing the viewer show their orange ports: a capped one where
	# there's no tunnel, an open ring where a tunnel's airlock joins.
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * _ext(type, d, r) * 0.86, d.y * _ext(type, d, r) * 0.86, 0.12), tw, state, true, d)


## A port on the dome's side, seen at an angle: an orange ring, capped or open.
## Capped ones follow the same door count as _top_port.
static func _iso_port(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary, capped: bool, dir: Vector2i = Vector2i.ZERO) -> void:
	if capped and not (dir in _cap_sides):
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
	# A small airlock building at each door, back ones first; tunnels run into
	# them. The ship, when it's on the pad, stands between the back and front ones.
	for d in [Vector2i(0, -1), Vector2i(-1, 0)]:
		_iso_gatehouse(ci, c, tw, r, d, state)
	if state.get("ship", false):
		more().draw_lander(ci, c, tw, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		_iso_gatehouse(ci, c, tw, r, d, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.11), tw, state, true, d)


## The landing pad's airlock building on side d, seen from above: a small
## block with a glass roof bubble and an orange band on its outer wall.
static func _top_gatehouse(ci: CanvasItem, c: Vector2, s: float, rad: float, d: Vector2i, state: Dictionary) -> void:
	var dir := Vector2(d)
	var side := dir.orthogonal()
	var p := c + dir * rad * 0.89
	var half_along := s * 0.07
	var half_across := s * 0.10
	var corners := PackedVector2Array([p - dir * half_along - side * half_across, p + dir * half_along - side * half_across, p + dir * half_along + side * half_across, p - dir * half_along + side * half_across])
	ci.draw_colored_polygon(corners, _fade(METAL_DARK, state))
	var inner := PackedVector2Array()
	for q in corners:
		inner.append(p + (q - p) * 0.8)
	ci.draw_colored_polygon(inner, _fade(METAL, state))
	ci.draw_line(corners[1], corners[2], _fade(ORANGE, state), 2.0)
	ci.draw_circle(p, s * 0.04, _fade(GLASS, state).lightened(0.3))
	# The door on the pad side, with a lit step in front of it.
	var door := p - dir * half_along
	ci.draw_line(door - side * s * 0.035, door + side * s * 0.035, Color(0.08, 0.07, 0.06, _fade(METAL, state).a), maxf(3.0, s * 0.035))
	ci.draw_line(door - dir * s * 0.02 - side * s * 0.03, door - dir * s * 0.02 + side * s * 0.03, _fade(AMBER, state), 2.0)


## The same airlock building at an angle: a block standing on the pad's rim,
## with a rounded glass roof, a window and an orange band by the door.
static func _iso_gatehouse(ci: CanvasItem, c: Vector2, tw: float, r: float, d: Vector2i, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var along0 := r * 0.80
	var along1 := r * 0.98
	var across := 0.09
	var u0: float
	var u1: float
	var v0: float
	var v1: float
	if d.x != 0:
		u0 = minf(d.x * along0, d.x * along1)
		u1 = maxf(d.x * along0, d.x * along1)
		v0 = -across
		v1 = across
	else:
		v0 = minf(d.y * along0, d.y * along1)
		v1 = maxf(d.y * along0, d.y * along1)
		u0 = -across
		u1 = across
	_box(ci, c, tw, u0, v0, u1, v1, 0.13, m, m.lightened(0.15), 0.05)
	var mid := Vector2((u0 + u1) * 0.5, (v0 + v1) * 0.5)
	_iso_dome(ci, _iso(c, tw, mid.x, mid.y, 0.18) - _iso(c, tw, 0, 0, 0) + c, tw, 0.065, 0.05, ORANGE, Color(0.30, 0.26, 0.22), state)
	# An orange band round the foot of the visible walls.
	ci.draw_line(_iso(c, tw, u1, v0, 0.07), _iso(c, tw, u1, v1, 0.07), _fade(ORANGE, state), 2.0)
	ci.draw_line(_iso(c, tw, u0, v1, 0.07), _iso(c, tw, u1, v1, 0.07), _fade(ORANGE, state), 2.0)
	# The door on the pad side (seen on the two back buildings, whose pad side faces us),
	# with a light over it.
	if d.x < 0 or d.y < 0:
		var door: PackedVector2Array
		var lamp: Vector2
		if d.x < 0:
			door = PackedVector2Array([_iso(c, tw, u1, -0.035, 0.05), _iso(c, tw, u1, 0.035, 0.05), _iso(c, tw, u1, 0.035, 0.145), _iso(c, tw, u1, -0.035, 0.145)])
			lamp = _iso(c, tw, u1, 0.0, 0.16)
		else:
			door = PackedVector2Array([_iso(c, tw, -0.035, v1, 0.05), _iso(c, tw, 0.035, v1, 0.05), _iso(c, tw, 0.035, v1, 0.145), _iso(c, tw, -0.035, v1, 0.145)])
			lamp = _iso(c, tw, 0.0, v1, 0.16)
		ci.draw_colored_polygon(door, Color(0.08, 0.07, 0.06, m.a))
		ci.draw_polyline(PackedVector2Array([door[0], door[3], door[2], door[1]]), m.darkened(0.3), 1.5)
		_glow(ci, lamp, tw * 0.01, _fade(AMBER, state), state)


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
	# The top of the lift tube rises out of the pit (the same tube the Shaft
	# Landing shows coming down in the Deep), under a lifting frame.
	var tr := 0.24
	var trx := tr * tw * 0.72
	var top_z := 0.50
	# The lift car is at the top unless it has gone down to the Deep.
	var car_up: bool = str(state.get("car", "up")) == "up"
	var up := float(state.get("lift", 1.0 if car_up else 0.0))
	_lift_tube(ci, c, tw, tr, -0.04, top_z, false, lerpf(0.16, top_z - 0.20, up), state)
	var lid := _iso(c, tw, 0, 0, top_z)
	ci.draw_colored_polygon(_ellipse(lid, trx * 1.08, trx * 0.54), m.lightened(0.15))
	ci.draw_polyline(_ellipse(lid, trx * 1.08, trx * 0.54), orange, 2.0)
	ci.draw_colored_polygon(_ellipse(lid, trx * 0.5, trx * 0.25), md)
	# The lifting frame: an A-frame on the lid holding the cable wheel.
	var wheel := _iso(c, tw, 0, 0, top_z + 0.24)
	var frame := md.lightened(0.25)
	for side in [-1.0, 1.0]:
		ci.draw_line(lid + Vector2(side * trx * 0.95, 0), wheel, frame, maxf(2.0, tw * 0.014))
		ci.draw_line(lid + Vector2(side * trx * 0.5, trx * 0.4), wheel, frame.darkened(0.15), maxf(1.5, tw * 0.01))
	ci.draw_line(lid, wheel, Color(0.75, 0.75, 0.75, m.a), 1.5)
	ci.draw_arc(wheel, tw * 0.055, 0, TAU, 16, m.lightened(0.2), maxf(2.0, tw * 0.014))
	ci.draw_line(wheel - Vector2(tw * 0.05, 0), wheel + Vector2(tw * 0.05, 0), m, 1.5)
	ci.draw_line(wheel - Vector2(0, tw * 0.05), wheel + Vector2(0, tw * 0.05), m, 1.5)
	ci.draw_circle(wheel, tw * 0.016, md)
	_glow(ci, wheel - Vector2(0, tw * 0.075), tw * 0.014, orange, state)
	for i in 4:
		var q := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * r * 0.95
		_glow(ci, _iso(c, tw, q.x, q.y, 0.03), tw * 0.014, orange, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.04), tw, state, true, d)


## Tunnels on the far sides of a hub (drawn before it), with radius r.
static func _back_links(ci: CanvasItem, c: Vector2, tw: float, links: Array, r: float, state: Dictionary) -> void:
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, r, state)


## Tunnels on the near sides of a hub (drawn after it), and capped ports on
## near sides with a door but no tunnel.
static func _front_links(ci: CanvasItem, c: Vector2, tw: float, links: Array, r: float, state: Dictionary) -> void:
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]):
			_iso_port(ci, _iso(c, tw, d.x * r, d.y * r, 0.06), tw, state, true, d)


## A café table with a coloured umbrella.
static func _umbrella_table(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, col: Color, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var top := _iso(c, tw, q.x, q.y, 0.17)
	ci.draw_colored_polygon(_ellipse(_iso(c, tw, q.x, q.y, 0.05), tw * 0.04, tw * 0.02), _fade(Color(0.85, 0.80, 0.70), state))
	ci.draw_line(_iso(c, tw, q.x, q.y, 0.0), top, md, maxf(1.0, tw * 0.008))
	var shade := PackedVector2Array()
	shade.append(top - Vector2(0, tw * 0.035))
	shade.append_array(_ellipse(top, tw * 0.075, tw * 0.035, 0, 180, 10))
	ci.draw_colored_polygon(shade, _fade(col, state))
	for side in [-1.0, 1.0]:
		ci.draw_circle(_iso(c, tw, q.x + side * 0.05, q.y + side * 0.03, 0.03), maxf(1.5, tw * 0.012), md.lightened(0.2))


## The Commons: a round canteen hall with a band of warm windows, a skylight
## drum on top, a kitchen chimney, and café tables with umbrellas outside.
static func _iso_commons(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var lit := _lit(state)
	var r := 0.36
	_back_links(ci, c, tw, links, r, state)
	_umbrella_table(ci, c, tw, Vector2(0.40, -0.40), Color(0.95, 0.45, 0.30), state)
	# The kitchen chimney at the back, with steam.
	_cyl(ci, c, tw, -0.16, -0.18, 0.045, 0.50, m.darkened(0.1), md)
	if lit:
		var tip := _iso(c, tw, -0.16, -0.18, 0.52)
		_steam(ci, tip, tw, 0.8, 3, 0.35)
	# The hall: a warm wooden drum.
	var wood := _fade(Color(0.62, 0.40, 0.26), state)
	_cyl(ci, c, tw, 0, 0, r, 0.22, wood, wood.lightened(0.1))
	var rx := r * tw * 0.72
	var base := _iso(c, tw, 0, 0, 0.0)
	# A band of warm windows round the hall, with frames between them.
	var w0 := _iso(c, tw, 0, 0, 0.07)
	var w1 := _iso(c, tw, 0, 0, 0.17)
	var band := _ellipse(w0, rx * 0.995, rx * 0.4975, 0, 180, 20)
	band.append_array(_ellipse(w1, rx * 0.995, rx * 0.4975, 180, 0, 20))
	ci.draw_colored_polygon(band, _fade(Color(1.0, 0.80, 0.45), state) if lit else md)
	for k in 13:
		var ang := deg_to_rad(k * 15.0)
		var off := Vector2(cos(ang) * rx, sin(ang) * rx * 0.5)
		ci.draw_line(w0 + off, w1 + off, wood.darkened(0.3), maxf(1.5, tw * 0.010))
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.20), rx, rx * 0.5, 0, 180, 18), _fade(GREEN, state), maxf(1.5, tw * 0.012))
	# The roof, and the skylight drum on top with a glass dome.
	var roof := _iso(c, tw, 0, 0, 0.22)
	ci.draw_colored_polygon(_ellipse(roof, rx, rx * 0.5), _fade(Color(0.42, 0.30, 0.22), state))
	_cyl(ci, c, tw, 0, 0, 0.18, 0.08, _fade(Color(0.85, 0.82, 0.74), state), _fade(Color(0.85, 0.82, 0.74), state), 0.22)
	var sky := _iso(c, tw, 0, 0, 0.30)
	var srx := 0.18 * tw * 0.72
	var dome := _ellipse(sky, srx, srx * 0.5, 0, 180, 14)
	dome.append_array(_ellipse(sky, srx, tw * 0.07, 180, 360, 14))
	ci.draw_colored_polygon(dome, Color(1.0, 0.85, 0.55, 0.55) if lit else _fade(GLASS, state))
	ci.draw_polyline(_ellipse(sky, srx, srx * 0.5), m.lightened(0.2), 1.5)
	_umbrella_table(ci, c, tw, Vector2(-0.40, 0.40), Color(0.35, 0.70, 0.95), state)
	_umbrella_table(ci, c, tw, Vector2(0.41, 0.41), Color(0.95, 0.80, 0.30), state)
	_front_links(ci, c, tw, links, r, state)


## The Commons from above.
static func _top_commons(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	for q in [[Vector2(0.40, -0.40), Color(0.95, 0.45, 0.30)], [Vector2(-0.40, 0.40), Color(0.35, 0.70, 0.95)], [Vector2(0.41, 0.41), Color(0.95, 0.80, 0.30)]]:
		ci.draw_circle(c + q[0] * s, s * 0.075, _fade(q[1], state))
		ci.draw_circle(c + q[0] * s, s * 0.012, md)
	ci.draw_circle(c, s * 0.36, _fade(Color(0.42, 0.30, 0.22), state))
	ci.draw_arc(c, s * 0.36, 0, TAU, 28, _fade(GREEN, state), 2.0)
	ci.draw_circle(c, s * 0.18, _fade(Color(0.85, 0.82, 0.74), state))
	ci.draw_circle(c, s * 0.11, Color(1.0, 0.85, 0.55, 0.8) if _lit(state) else _fade(GLASS, state))
	ci.draw_circle(c + Vector2(-0.14, -0.16) * s, s * 0.04, md)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * s * 0.36, s, state, not (d in links), d)


## The Clinic: a white two-storey hospital block with a teal stripe, rows of
## windows, a teal cross sign on the roof and an ambulance rover outside.
static func _iso_clinic(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var teal := _fade(TEAL, state)
	var lit := _lit(state)
	var hw := 0.24
	var hh := 0.32
	_back_links(ci, c, tw, links, hw, state)
	var white := _fade(Color(0.92, 0.94, 0.96), state)
	_box(ci, c, tw, -hw, -hw, hw, hw, hh, white, _fade(Color(0.80, 0.84, 0.88), state))
	# A teal stripe between the floors.
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, 0.16), _iso(c, tw, hw, hw, 0.16), _iso(c, tw, hw, -hw, 0.16)]), teal, maxf(2.5, tw * 0.02))
	# Two floors of windows on both visible walls (skipping the door in the middle).
	var glass := _fade(Color(0.70, 0.88, 0.98), state) if not lit else _fade(Color(0.95, 0.97, 1.0), state)
	for floor_z in [0.05, 0.20]:
		for k in 4:
			var a := -hw + 0.03 + k * 0.12
			if floor_z < 0.1 and absf(a + 0.04) < 0.09:
				continue
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, a, hw, floor_z), _iso(c, tw, a + 0.08, hw, floor_z), _iso(c, tw, a + 0.08, hw, floor_z + 0.07), _iso(c, tw, a, hw, floor_z + 0.07)]), glass.darkened(0.15))
			ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, hw, a, floor_z), _iso(c, tw, hw, a + 0.08, floor_z), _iso(c, tw, hw, a + 0.08, floor_z + 0.07), _iso(c, tw, hw, a, floor_z + 0.07)]), glass.darkened(0.3))
	# Roof: a parapet, a rooftop unit and the cross sign standing up.
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, -hw, hh), _iso(c, tw, hw, -hw, hh), _iso(c, tw, hw, hw, hh), _iso(c, tw, -hw, hw, hh), _iso(c, tw, -hw, -hw, hh)]), white.darkened(0.15), maxf(2.0, tw * 0.015))
	_box(ci, c, tw, -0.16, -0.16, -0.04, -0.06, 0.05, m, m.lightened(0.15), hh)
	var sign := _iso(c, tw, 0.06, 0.04, hh) - Vector2(0, tw * 0.13)
	ci.draw_line(_iso(c, tw, 0.06, 0.04, hh), sign + Vector2(0, tw * 0.06), md, maxf(1.5, tw * 0.012))
	var cw := tw * 0.11
	ci.draw_rect(Rect2(sign - Vector2(cw * 0.6, cw * 0.6), Vector2(cw * 1.2, cw * 1.2)), white)
	ci.draw_rect(Rect2(sign - Vector2(cw * 0.6, cw * 0.6), Vector2(cw * 1.2, cw * 1.2)), md, false, 1.0)
	ci.draw_rect(Rect2(sign - Vector2(cw * 0.15, cw * 0.48), Vector2(cw * 0.3, cw * 0.96)), teal)
	ci.draw_rect(Rect2(sign - Vector2(cw * 0.48, cw * 0.15), Vector2(cw * 0.96, cw * 0.3)), teal)
	if lit:
		_glow(ci, sign, tw * 0.02, teal, state)
	# An ambulance rover parked at the front corner.
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, a, f, z)
	_rescue_rover(ci, at, tw, 0.36, 0.36, state)
	_front_links(ci, c, tw, links, hw, state)


## The Clinic from above.
static func _top_clinic(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var hw := s * 0.24
	var teal := _fade(TEAL, state)
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.85, 0.88, 0.92), state))
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), teal, false, 2.0)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.03, -s * 0.10), Vector2(s * 0.06, s * 0.20)), teal)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.10, -s * 0.03), Vector2(s * 0.20, s * 0.06)), teal)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.16), Vector2(s * 0.12, s * 0.10)), _fade(METAL, state))
	ci.draw_rect(Rect2(c + Vector2(s * 0.26, s * 0.30), Vector2(s * 0.20, s * 0.12)), _fade(Color(0.88, 0.22, 0.18), state))
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * hw, s, state, not (d in links), d)


## A round tree: a trunk and a leafy ball.
static func _tree(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, size: float, state: Dictionary) -> void:
	ci.draw_line(_iso(c, tw, q.x, q.y, 0.0), _iso(c, tw, q.x, q.y, 0.10 * size), _fade(Color(0.40, 0.28, 0.18), state), maxf(2.0, tw * 0.016))
	_iso_sphere(ci, _iso(c, tw, q.x, q.y, 0.15 * size), tw * 0.07 * size, _fade(Color(0.30, 0.66, 0.30), state))


## A slim glass walkway from a hub at radius r to the tile edge, with a metal
## collar at the edge where it meets the tunnel next door.
static func _glass_walk(ci: CanvasItem, c: Vector2, tw: float, d: Vector2i, r: float, state: Dictionary) -> void:
	var axis := 0 if d.x != 0 else 1
	var sign := float(d.x if d.x != 0 else d.y)
	var glass := _fade(Color(0.70, 0.88, 1.0, 0.55), state)
	var m := _fade(METAL, state)
	_iso_tube(ci, c, tw, axis, sign * r, sign * 0.44, 0.05, 0.07, glass, Color(0, 0, 0, 0), false)
	_iso_tube(ci, c, tw, axis, sign * 0.44, sign * 0.5, 0.07, 0.09, m, _fade(ORANGE, state), false)


## The Garden Cavern: an open cave park. Grass, trees, a pond with lily pads,
## flower beds, tall grow-lights shining like a little sun, and a small glass
## pavilion in the middle where the tunnels meet.
static func _iso_garden(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var lit := _lit(state)
	var r := 0.19
	# The lawn, with a stone edge.
	var lawn := PackedVector2Array([_iso(c, tw, -0.46, -0.46), _iso(c, tw, 0.46, -0.46), _iso(c, tw, 0.46, 0.46), _iso(c, tw, -0.46, 0.46)])
	ci.draw_colored_polygon(lawn, _fade(Color(0.36, 0.58, 0.30), state))
	ci.draw_polyline(PackedVector2Array([lawn[0], lawn[1], lawn[2], lawn[3], lawn[0]]), _fade(Color(0.62, 0.60, 0.55), state), maxf(1.5, tw * 0.012))
	# Warm light pooled on the grass under the grow-lights.
	if lit:
		for q in [Vector2(-0.30, 0.0), Vector2(0.30, 0.0)]:
			ci.draw_colored_polygon(_ellipse(_iso(c, tw, q.x, q.y), tw * 0.22, tw * 0.11), Color(1.0, 0.95, 0.65, 0.18))
	# Stone paths out to the four sides.
	for d in [Vector2(1, 0), Vector2(0, 1)]:
		var p0 := _iso(c, tw, -0.46 * d.x, -0.46 * d.y)
		var p1 := _iso(c, tw, 0.46 * d.x, 0.46 * d.y)
		ci.draw_line(p0, p1, _fade(Color(0.72, 0.68, 0.60), state), maxf(3.0, tw * 0.04))
	# The pond in the back-left corner, with lily pads.
	var pond := _iso(c, tw, -0.27, -0.27)
	ci.draw_colored_polygon(_ellipse(pond, tw * 0.17, tw * 0.085), _fade(Color(0.62, 0.60, 0.55), state))
	ci.draw_colored_polygon(_ellipse(pond, tw * 0.15, tw * 0.072), _fade(WATER, state).darkened(0.1))
	for k in 3:
		ci.draw_circle(pond + Vector2(-tw * 0.06 + k * tw * 0.05, (k % 2) * tw * 0.02 - tw * 0.01), maxf(1.5, tw * 0.014), _fade(Color(0.35, 0.70, 0.35), state))
	ci.draw_arc(pond - Vector2(tw * 0.03, tw * 0.02), tw * 0.05, deg_to_rad(200), deg_to_rad(300), 6, Color(1, 1, 1, 0.5), 1.0)
	for d in links:
		if d.x < 0 or d.y < 0:
			_glass_walk(ci, c, tw, d, r, state)
	# Flower beds in the front-right corner.
	var flowers := [Color(0.95, 0.45, 0.55), Color(0.98, 0.85, 0.35), Color(0.75, 0.55, 0.95), Color(1.0, 1.0, 1.0)]
	for k in 10:
		var fq := Vector2(0.20 + (k % 5) * 0.05, 0.26 + (k / 5) * 0.08 + (k % 2) * 0.02)
		ci.draw_circle(_iso(c, tw, fq.x, fq.y, 0.01), maxf(1.5, tw * 0.013), _fade(flowers[k % 4], state))
	# Trees, back to front.
	for q in [Vector2(0.30, -0.32), Vector2(0.38, -0.14), Vector2(-0.34, 0.20)]:
		_tree(ci, c, tw, q, 1.0, state)
	# The glass pavilion in the middle.
	_cyl(ci, c, tw, 0, 0, r, 0.16, _fade(Color(0.85, 0.85, 0.80), state), _fade(Color(0.85, 0.85, 0.80), state))
	var top := _iso(c, tw, 0, 0, 0.16)
	var rx := r * tw * 0.72
	var cone := _ellipse(top, rx * 1.15, rx * 0.57, 0, 180, 14)
	cone.append(top - Vector2(0, tw * 0.09))
	ci.draw_colored_polygon(cone, _fade(Color(0.30, 0.55, 0.30), state))
	ci.draw_colored_polygon(_ellipse(top, rx * 1.15, rx * 0.57, 180, 360, 14) + PackedVector2Array([top - Vector2(0, tw * 0.09)]), _fade(Color(0.38, 0.65, 0.38), state))
	for k in 5:
		var ang := deg_to_rad(20.0 + k * 35.0)
		var wp := _iso(c, tw, 0, 0, 0.0) + Vector2(cos(ang) * rx, sin(ang) * rx * 0.5)
		ci.draw_line(wp - Vector2(0, tw * 0.02), wp - Vector2(0, tw * 0.10), _fade(GLASS, state).lightened(0.3), maxf(1.5, tw * 0.012))
	# A bench, and the front tree.
	var b0 := _iso(c, tw, -0.30, 0.38, 0.04)
	var b1 := _iso(c, tw, -0.14, 0.38, 0.04)
	ci.draw_line(b0, b1, _fade(Color(0.55, 0.38, 0.24), state), maxf(2.5, tw * 0.02))
	_tree(ci, c, tw, Vector2(0.36, 0.06), 0.8, state)
	# Two tall grow-lights shining down like a little sun.
	for q in [Vector2(-0.30, 0.0), Vector2(0.30, 0.0)]:
		var foot := _iso(c, tw, q.x, q.y + 0.08)
		var lamp := _iso(c, tw, q.x, q.y + 0.08, 0.55)
		ci.draw_line(foot, lamp, md.lightened(0.2), maxf(1.5, tw * 0.012))
		ci.draw_colored_polygon(_ellipse(lamp, tw * 0.05, tw * 0.02), md)
		if lit:
			ci.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-tw * 0.04, 0), lamp + Vector2(tw * 0.04, 0), _iso(c, tw, q.x, q.y) + Vector2(tw * 0.15, 0), _iso(c, tw, q.x, q.y) + Vector2(-tw * 0.15, 0)]), Color(1.0, 0.95, 0.65, 0.10))
			_glow(ci, lamp + Vector2(0, tw * 0.01), tw * 0.03, _fade(Color(1.0, 0.95, 0.70), state), state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_glass_walk(ci, c, tw, d, r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]):
			_iso_port(ci, _iso(c, tw, d.x * r, d.y * r, 0.06), tw, state, true, d)


## The Garden Cavern from above.
static func _top_garden(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	ci.draw_rect(Rect2(c - Vector2(s * 0.46, s * 0.46), Vector2(s * 0.92, s * 0.92)), _fade(Color(0.36, 0.58, 0.30), state))
	ci.draw_line(c - Vector2(s * 0.46, 0), c + Vector2(s * 0.46, 0), _fade(Color(0.72, 0.68, 0.60), state), maxf(3.0, s * 0.05))
	ci.draw_line(c - Vector2(0, s * 0.46), c + Vector2(0, s * 0.46), _fade(Color(0.72, 0.68, 0.60), state), maxf(3.0, s * 0.05))
	ci.draw_circle(c + Vector2(-0.27, -0.27) * s, s * 0.15, _fade(WATER, state).darkened(0.1))
	for q in [Vector2(0.30, -0.32), Vector2(0.38, -0.14), Vector2(-0.34, 0.20), Vector2(0.36, 0.06)]:
		ci.draw_circle(c + q * s, s * 0.07, _fade(Color(0.25, 0.55, 0.25), state))
	var flowers := [Color(0.95, 0.45, 0.55), Color(0.98, 0.85, 0.35), Color(0.75, 0.55, 0.95), Color(1.0, 1.0, 1.0)]
	for k in 10:
		ci.draw_circle(c + Vector2(0.20 + (k % 5) * 0.05, 0.26 + (k / 5) * 0.08) * s, s * 0.015, _fade(flowers[k % 4], state))
	ci.draw_circle(c, s * 0.19, _fade(Color(0.38, 0.65, 0.38), state))
	for q in [Vector2(-0.30, 0.08), Vector2(0.30, 0.08)]:
		_glow(ci, c + q * s, s * 0.03, _fade(Color(1.0, 0.95, 0.70), state), state)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * s * 0.19, s, state, not (d in links), d)


## A window on a wall: on the u = w face (side) or the v = w face (front),
## from `a` to `a + width` along it and from z0 to z1 up it.
static func _wall_window(ci: CanvasItem, c: Vector2, tw: float, front: bool, w: float, a: float, width: float, z0: float, z1: float, col: Color) -> PackedVector2Array:
	var q := PackedVector2Array()
	if front:
		q = PackedVector2Array([_iso(c, tw, a, w, z0), _iso(c, tw, a + width, w, z0), _iso(c, tw, a + width, w, z1), _iso(c, tw, a, w, z1)])
	else:
		q = PackedVector2Array([_iso(c, tw, w, a, z0), _iso(c, tw, w, a + width, z0), _iso(c, tw, w, a + width, z1), _iso(c, tw, w, a, z1)])
	ci.draw_colored_polygon(q, col)
	return q


## The Bunkhouse: a three-storey apartment block with warm lit windows,
## coloured curtains, little balconies, and planters and a water tank on top.
static func _iso_bunk(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var lit := _lit(state)
	var hw := 0.26
	var hh := 0.40
	_back_links(ci, c, tw, links, hw, state)
	var wall := _fade(Color(0.86, 0.74, 0.56), state)
	_box(ci, c, tw, -hw, -hw, hw, hw, hh, wall, _fade(Color(0.55, 0.48, 0.40), state))
	var curtains := [Color(0.85, 0.35, 0.30), Color(0.35, 0.55, 0.90), Color(0.95, 0.75, 0.30), Color(0.45, 0.75, 0.45), Color(0.70, 0.45, 0.85), Color(0.40, 0.80, 0.85)]
	var glow := _fade(Color(1.0, 0.86, 0.55), state)
	var k := 0
	for fl in 3:
		var z0 := 0.04 + fl * 0.12
		for i in 3:
			var a := -0.20 + i * 0.15
			for front in [true, false]:
				k += 1
				if fl == 0 and i == 1:
					continue
				var win := _wall_window(ci, c, tw, front, hw, a, 0.09, z0, z0 + 0.075, glow if lit else md.lightened(0.1))
				# A curtain drawn half across.
				var cur := PackedVector2Array([win[0], win[0].lerp(win[1], 0.35), win[3].lerp(win[2], 0.35), win[3]])
				ci.draw_colored_polygon(cur, _fade(curtains[k % curtains.size()], state).darkened(0.0 if front else 0.2))
				ci.draw_polyline(PackedVector2Array([win[0], win[1], win[2], win[3], win[0]]), md, 1.0)
			# A balcony rail under the upper windows on the front.
			if fl > 0 and i != 1:
				var r0 := _iso(c, tw, a - 0.01, hw + 0.04, z0)
				var r1 := _iso(c, tw, a + 0.10, hw + 0.04, z0)
				ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, a - 0.01, hw, z0), _iso(c, tw, a + 0.10, hw, z0), r1, r0]), wall.darkened(0.25))
				ci.draw_line(r0 - Vector2(0, tw * 0.03), r1 - Vector2(0, tw * 0.03), md, 1.0)
				for t in 4:
					var rp := r0.lerp(r1, float(t) / 3.0)
					ci.draw_line(rp, rp - Vector2(0, tw * 0.03), md, 1.0)
	# Floor lines.
	for fl in [0.15, 0.27]:
		ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, fl), _iso(c, tw, hw, hw, fl), _iso(c, tw, hw, -hw, fl)]), wall.darkened(0.15), 1.0)
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, hh), _iso(c, tw, hw, hw, hh), _iso(c, tw, hw, -hw, hh)]), _fade(GOLD, state), maxf(1.5, tw * 0.012))
	# Roof: planters with greens, and a water tank.
	for q in [Vector2(-0.16, 0.12), Vector2(0.0, 0.16), Vector2(0.14, 0.12)]:
		_box(ci, c, tw, q.x - 0.05, q.y - 0.04, q.x + 0.05, q.y + 0.04, 0.03, _fade(Color(0.45, 0.32, 0.22), state), Color(0, 0, 0, 0), hh)
		_iso_sphere(ci, _iso(c, tw, q.x, q.y, hh + 0.06), tw * 0.035, _fade(Color(0.35, 0.68, 0.35), state))
	_cyl(ci, c, tw, -0.10, -0.12, 0.07, 0.10, m, m.lightened(0.15), hh)
	_front_links(ci, c, tw, links, hw, state)


## The Bunkhouse from above.
static func _top_bunk(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var hw := s * 0.26
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.55, 0.48, 0.40), state))
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(GOLD, state), false, 2.0)
	for q in [Vector2(-0.16, 0.12), Vector2(0.0, 0.16), Vector2(0.14, 0.12)]:
		ci.draw_circle(c + q * s, s * 0.04, _fade(Color(0.35, 0.68, 0.35), state))
	ci.draw_circle(c + Vector2(-0.10, -0.12) * s, s * 0.07, _fade(METAL, state))
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * hw, s, state, not (d in links), d)


## The Lounge: a dark purple club with pink neon edges, glowing coloured
## windows, a row of marquee bulbs, a neon sign and two crossing spotlights.
static func _iso_lounge(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var lit := _lit(state)
	var pink := _fade(PINK, state)
	var cyan := _fade(CYAN, state)
	var hw := 0.24
	var hh := 0.24
	_back_links(ci, c, tw, links, hw, state)
	# Spotlight beams behind the club, crossing in the sky.
	if lit:
		for side in [-1.0, 1.0]:
			var foot := _iso(c, tw, side * 0.18, -0.18, hh)
			var sky := foot + Vector2(-side * tw * 0.30, -tw * 0.62)
			ci.draw_colored_polygon(PackedVector2Array([foot, sky + Vector2(-tw * 0.05, 0), sky + Vector2(tw * 0.05, 0)]), Color(0.85, 0.75, 1.0, 0.16))
	var wall := _fade(Color(0.24, 0.14, 0.32), state)
	_box(ci, c, tw, -hw, -hw, hw, hw, hh, wall, _fade(Color(0.16, 0.10, 0.22), state))
	# Disco windows: little squares of colour.
	var cols := [Color(1.0, 0.35, 0.70), Color(0.35, 0.85, 1.0), Color(1.0, 0.85, 0.30), Color(0.55, 1.0, 0.55)]
	for front in [true, false]:
		for i in 2:
			var a := -0.19 + i * 0.27
			for j in 3:
				for kz in 2:
					var colr: Color = cols[(i * 3 + j + kz + (1 if front else 0)) % 4]
					_wall_window(ci, c, tw, front, hw, a + j * 0.035, 0.03, 0.07 + kz * 0.04, 0.10 + kz * 0.04, _fade(colr, state) if lit else md)
	# Neon edges and marquee bulbs along the top of the walls.
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, hh), _iso(c, tw, hw, hw, hh), _iso(c, tw, hw, -hw, hh)]), pink, maxf(2.0, tw * 0.016))
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, 0.02), _iso(c, tw, hw, hw, 0.02), _iso(c, tw, hw, -hw, 0.02)]), cyan, maxf(1.5, tw * 0.012))
	for k in 9:
		var t := float(k) / 8.0
		var b := _iso(c, tw, -hw + t * 2.0 * hw, hw, hh - 0.035)
		ci.draw_circle(b, maxf(1.2, tw * 0.008), _fade(Color(1.0, 0.92, 0.6), state) if lit else md.lightened(0.2))
	# The neon sign on the roof: a glass and a music note.
	var base := _iso(c, tw, 0.0, 0.0, hh)
	var sign := base - Vector2(0, tw * 0.13)
	ci.draw_line(base, sign + Vector2(0, tw * 0.05), md, maxf(1.5, tw * 0.012))
	var sw := tw * 0.11
	ci.draw_rect(Rect2(sign - Vector2(sw, sw * 0.5), Vector2(sw * 2.0, sw)), Color(0.08, 0.04, 0.12, wall.a))
	ci.draw_rect(Rect2(sign - Vector2(sw, sw * 0.5), Vector2(sw * 2.0, sw)), pink, false, maxf(1.5, tw * 0.01))
	var gl := sign - Vector2(sw * 0.45, 0)
	ci.draw_polyline(PackedVector2Array([gl + Vector2(-sw * 0.25, -sw * 0.3), gl + Vector2(sw * 0.25, -sw * 0.3), gl, gl + Vector2(-sw * 0.25, -sw * 0.3)]), cyan, maxf(1.2, tw * 0.008))
	ci.draw_line(gl, gl + Vector2(0, sw * 0.3), cyan, maxf(1.2, tw * 0.008))
	var nt := sign + Vector2(sw * 0.45, sw * 0.2)
	ci.draw_circle(nt, sw * 0.12, pink)
	ci.draw_line(nt + Vector2(sw * 0.1, 0), nt + Vector2(sw * 0.1, -sw * 0.45), pink, maxf(1.2, tw * 0.008))
	ci.draw_line(nt + Vector2(sw * 0.1, -sw * 0.45), nt + Vector2(sw * 0.3, -sw * 0.35), pink, maxf(1.2, tw * 0.008))
	if lit:
		_glow(ci, sign, tw * 0.03, pink, state)
	# The spotlights themselves.
	for side in [-1.0, 1.0]:
		ci.draw_circle(_iso(c, tw, side * 0.18, -0.18, hh + 0.01), tw * 0.02, md.lightened(0.3))
	_front_links(ci, c, tw, links, hw, state)


## The Lounge from above.
static func _top_lounge(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var hw := s * 0.24
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.16, 0.10, 0.22), state))
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(PINK, state), false, 2.0)
	ci.draw_rect(Rect2(c - Vector2(s * 0.11, s * 0.05), Vector2(s * 0.22, s * 0.10)), _fade(PINK, state), false, 1.5)
	_glow(ci, c, s * 0.03, _fade(PINK, state), state)
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(side * 0.18, -0.18) * s, s * 0.03, _fade(Color(0.85, 0.75, 1.0), state))
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * hw, s, state, not (d in links), d)


## A cooling tower: a waisted concrete tower with red and white bands and steam.
static func _cooling_tower(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, state: Dictionary) -> void:
	var conc := _fade(Color(0.84, 0.84, 0.82), state)
	var base := _iso(c, tw, q.x, q.y, 0.0)
	var hgt := 0.46
	var pts_l := PackedVector2Array()
	var pts_r := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		var w := tw * (0.11 - 0.05 * sin(t * PI * 0.85))
		var p := base - Vector2(0, tw * hgt * t)
		pts_l.append(p - Vector2(w, 0))
		pts_r.append(p + Vector2(w, 0))
	var body := PackedVector2Array(pts_l)
	for k in range(pts_r.size() - 1, -1, -1):
		body.append(pts_r[k])
	ci.draw_colored_polygon(body, conc)
	# Shade the right side.
	var shade := PackedVector2Array()
	for k in pts_r.size():
		shade.append(pts_l[k].lerp(pts_r[k], 0.55))
	for k in range(pts_r.size() - 1, -1, -1):
		shade.append(pts_r[k])
	ci.draw_colored_polygon(shade, Color(0, 0, 0, 0.18 * conc.a))
	# Red and white bands near the top.
	for b in 2:
		var k := 6 + b
		ci.draw_line(pts_l[k], pts_r[k], _fade(Color(0.85, 0.22, 0.18), state) if b == 0 else conc.lightened(0.1), maxf(2.5, tw * 0.02))
	var top := base - Vector2(0, tw * hgt)
	ci.draw_colored_polygon(_ellipse(top, (pts_r[8].x - pts_l[8].x) * 0.5, tw * 0.02), conc.darkened(0.5))
	if _lit(state):
		_steam(ci, top, tw, 1.4, 4, 0.45)


## The Fusion Core: a round reactor with a glass top showing a glowing blue
## plasma ring held by magnet coils, two cooling towers behind and a small
## transformer yard.
static func _iso_fusion(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var lit := _lit(state)
	var blue := _fade(Color(0.45, 0.85, 1.0), state)
	var r := 0.24
	_back_links(ci, c, tw, links, r, state)
	_cooling_tower(ci, c, tw, Vector2(-0.30, -0.30), state)
	_cooling_tower(ci, c, tw, Vector2(0.14, -0.36), state)
	# The reactor drum.
	var shell := _fade(Color(0.80, 0.84, 0.90), state)
	_cyl(ci, c, tw, 0, 0, r, 0.16, shell, shell)
	var rx := r * tw * 0.72
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.05), rx, rx * 0.5, 0, 180, 18), blue, maxf(2.0, tw * 0.015))
	# Looking in through the glass top: the plasma ring and its coils.
	var top := _iso(c, tw, 0, 0, 0.16)
	ci.draw_colored_polygon(_ellipse(top, rx * 0.92, rx * 0.46), Color(0.04, 0.06, 0.12, shell.a))
	var ring_r := rx * 0.62
	if lit:
		ci.draw_polyline(_ellipse(top, ring_r, ring_r * 0.5), Color(blue.r, blue.g, blue.b, 0.35), maxf(6.0, tw * 0.05))
	ci.draw_polyline(_ellipse(top, ring_r, ring_r * 0.5), blue if lit else md.lightened(0.2), maxf(3.0, tw * 0.025))
	if lit:
		ci.draw_polyline(_ellipse(top, ring_r, ring_r * 0.5), Color(1, 1, 1, 0.9), maxf(1.0, tw * 0.008))
	for k in 8:
		var ang := k * TAU / 8.0
		var cp := top + Vector2(cos(ang) * ring_r, sin(ang) * ring_r * 0.5)
		ci.draw_rect(Rect2(cp - Vector2(tw * 0.016, tw * 0.02), Vector2(tw * 0.032, tw * 0.04)), _fade(Color(0.85, 0.55, 0.20), state))
	# The glass dome over it.
	var dome := _ellipse(top, rx * 0.95, rx * 0.475, 0, 180, 16)
	dome.append_array(_ellipse(top, rx * 0.95, tw * 0.11, 180, 360, 16))
	ci.draw_colored_polygon(dome, Color(0.70, 0.88, 1.0, 0.22 * shell.a))
	ci.draw_polyline(_ellipse(top, rx * 0.95, tw * 0.11, 180, 360, 16), _fade(Color(0.85, 0.92, 1.0, 0.6), state), 1.0)
	ci.draw_polyline(_ellipse(top, rx * 0.95, rx * 0.475), m.lightened(0.2), maxf(1.5, tw * 0.012))
	# The transformer yard at the left corner: boxes with insulators.
	for k in 2:
		var q := Vector2(-0.38 + k * 0.10, 0.30 + k * 0.04)
		_box(ci, c, tw, q.x - 0.04, q.y - 0.04, q.x + 0.04, q.y + 0.04, 0.08, m.darkened(0.1), m)
		for j in 3:
			ci.draw_line(_iso(c, tw, q.x - 0.02 + j * 0.02, q.y, 0.08), _iso(c, tw, q.x - 0.02 + j * 0.02, q.y, 0.13), _fade(Color(0.85, 0.60, 0.40), state), maxf(1.5, tw * 0.01))
	ci.draw_line(_iso(c, tw, -0.28, 0.34, 0.12), _iso(c, tw, -0.16, 0.16, 0.10), md, 1.0)
	_front_links(ci, c, tw, links, r, state)


## The Fusion Core from above.
static func _top_fusion(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var blue := _fade(Color(0.45, 0.85, 1.0), state)
	for q in [Vector2(-0.30, -0.30), Vector2(0.10, -0.36)]:
		ci.draw_circle(c + q * s, s * 0.11, _fade(Color(0.84, 0.84, 0.82), state))
		ci.draw_circle(c + q * s, s * 0.07, _fade(Color(0.35, 0.35, 0.35), state))
	ci.draw_circle(c, s * 0.24, _fade(Color(0.80, 0.84, 0.90), state))
	ci.draw_circle(c, s * 0.20, Color(0.04, 0.06, 0.12, blue.a))
	ci.draw_arc(c, s * 0.13, 0, TAU, 24, blue, maxf(3.0, s * 0.035))
	for k in 8:
		ci.draw_circle(c + Vector2.from_angle(k * TAU / 8.0) * s * 0.13, s * 0.02, _fade(Color(0.85, 0.55, 0.20), state))
	for k in 2:
		ci.draw_rect(Rect2(c + Vector2(-0.42 + k * 0.10, 0.26 + k * 0.04) * s, Vector2(s * 0.08, s * 0.08)), _fade(METAL, state))
	var dd := _solar_door(links, state)
	_top_port(ci, c + Vector2(dd) * s * 0.24, s, state, not (dd in links), dd)


## The Reclaimer: a recycling plant. Junk goes up a conveyor into a hopper on
## the hall's roof; inside it is crushed and sorted; bales come out, sorted
## bins wait out front, and recovered water fills the tank at the back.
static func _iso_reclaimer(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var lit := _lit(state)
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, f, a, z) if on_v else _iso(c, tw, a, f, z)
	var half := 0.30
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, half, state)
	# The water tank at the back.
	var tq: Vector2 = Vector2(-0.34, 0.24) if on_v else Vector2(0.24, -0.34)
	_cyl(ci, c, tw, tq.x, tq.y, 0.10, 0.30, _fade(WATER, state).darkened(0.25), _fade(WATER, state).darkened(0.05))
	# The hall.
	var f0 := -0.22
	var f1 := 0.12
	var hh := 0.22
	var wall := _fade(Color(0.42, 0.52, 0.42), state)
	if on_v:
		_box(ci, c, tw, f0, -half, f1, half, hh, wall, _fade(Color(0.55, 0.60, 0.55), state))
	else:
		_box(ci, c, tw, -half, f0, half, f1, hh, wall, _fade(Color(0.55, 0.60, 0.55), state))
	ci.draw_line(at.call(-half, f1, 0.18), at.call(half, f1, 0.18), _fade(GREEN, state), maxf(2.0, tw * 0.015))
	# The hopper on the roof: a funnel.
	var hc: Vector2 = at.call(0.05, -0.05, hh)
	var hw := tw * 0.10
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hw * 0.4, 0), hc + Vector2(hw * 0.4, 0), hc + Vector2(hw, -tw * 0.12), hc + Vector2(-hw, -tw * 0.12)]), m)
	ci.draw_colored_polygon(_ellipse(hc - Vector2(0, tw * 0.12), hw, hw * 0.45), md)
	# The drop-off bay on the left: a parking pad for a truck, backing its dump
	# bed up to a pit. A conveyor carries the junk from the pit up into the hopper.
	var bay: Dictionary = RECLAIMER_BAY
	var park: Vector2 = bay["park"]
	var pit: Vector2 = bay["pit"]
	var hazard := _fade(HAZARD, state)
	var pad := PackedVector2Array([at.call(park.x - 0.20, park.y - 0.12, 0.004), at.call(park.x + 0.18, park.y - 0.12, 0.004), at.call(park.x + 0.18, park.y + 0.13, 0.004), at.call(park.x - 0.20, park.y + 0.13, 0.004)])
	ci.draw_colored_polygon(pad, _fade(Color(0.40, 0.40, 0.42), state))
	for k in 12:
		var t0 := float(k) / 12.0
		var t1 := float(k + 1) / 12.0
		var stripe := hazard if k % 2 == 0 else Color(0.08, 0.08, 0.08, hazard.a)
		ci.draw_line(pad[0].lerp(pad[1], t0), pad[0].lerp(pad[1], t1), stripe, maxf(1.5, tw * 0.012))
		ci.draw_line(pad[3].lerp(pad[2], t0), pad[3].lerp(pad[2], t1), stripe, maxf(1.5, tw * 0.012))
	# A painted arrow: back up toward the pit.
	var ar0: Vector2 = at.call(park.x + 0.10, park.y, 0.006)
	var ar1: Vector2 = at.call(park.x - 0.10, park.y, 0.006)
	ci.draw_line(ar0, ar1, _fade(WHITE, state), maxf(1.5, tw * 0.012))
	ci.draw_line(ar1, at.call(park.x - 0.05, park.y - 0.04, 0.006), _fade(WHITE, state), maxf(1.5, tw * 0.012))
	ci.draw_line(ar1, at.call(park.x - 0.05, park.y + 0.04, 0.006), _fade(WHITE, state), maxf(1.5, tw * 0.012))
	# The pit, with a rim and junk inside.
	var pit_q := PackedVector2Array([at.call(pit.x - 0.06, pit.y - 0.09, 0.0), at.call(pit.x + 0.06, pit.y - 0.09, 0.0), at.call(pit.x + 0.06, pit.y + 0.09, 0.0), at.call(pit.x - 0.06, pit.y + 0.09, 0.0)])
	ci.draw_colored_polygon(pit_q, Color(0.05, 0.05, 0.06, md.a))
	var junk := [Color(0.62, 0.55, 0.45), Color(0.50, 0.52, 0.58), Color(0.70, 0.36, 0.30), Color(0.40, 0.58, 0.45), Color(0.75, 0.70, 0.40)]
	for k in 6:
		var jp: Vector2 = at.call(pit.x - 0.03 + (k % 3) * 0.03, pit.y - 0.05 + (k / 3) * 0.07, 0.01)
		_iso_sphere(ci, jp, tw * 0.022, _fade(junk[k % 5], state))
	ci.draw_polyline(PackedVector2Array([pit_q[0], pit_q[1], pit_q[2], pit_q[3], pit_q[0]]), hazard, maxf(1.5, tw * 0.012))
	# The conveyor from the pit up into the hopper.
	var c0: Vector2 = at.call(pit.x, pit.y - 0.04, 0.03)
	var c1: Vector2 = hc - Vector2(0, tw * 0.12)
	ci.draw_line(c0, c1, md, maxf(4.0, tw * 0.035))
	ci.draw_line(c0, c1, m.lightened(0.1), maxf(2.0, tw * 0.018))
	for k in 3:
		_iso_sphere(ci, c0.lerp(c1, 0.25 + k * 0.25) - Vector2(0, tw * 0.015), tw * 0.016, _fade(junk[k + 1], state))
	ci.draw_line(c0.lerp(c1, 0.5), c0.lerp(c1, 0.5) + Vector2(0, tw * 0.14), md, 1.0)
	# Sorted bins out front: metal, glass, plastic.
	for k in 3:
		var bcol: Color = [Color(0.60, 0.62, 0.66), Color(0.35, 0.70, 0.40), Color(0.35, 0.55, 0.90)][k]
		var a0 := 0.08 + k * 0.08
		if on_v:
			_box(ci, c, tw, 0.20, a0, 0.26, a0 + 0.06, 0.07, _fade(bcol, state))
		else:
			_box(ci, c, tw, a0, 0.20, a0 + 0.06, 0.26, 0.07, _fade(bcol, state))
	# Bales of crushed scrap at the right end of the front.
	for k in 2:
		var a0 := 0.34
		var z := k * 0.06
		if on_v:
			_box(ci, c, tw, 0.30, a0, 0.40, a0 + 0.10, 0.06, _fade(Color(0.58, 0.52, 0.42), state), Color(0, 0, 0, 0), z)
		else:
			_box(ci, c, tw, a0, 0.30, a0 + 0.10, 0.40, 0.06, _fade(Color(0.58, 0.52, 0.42), state), Color(0, 0, 0, 0), z)
	# A truck parked in the bay when asked for, or coming and going when the
	# map is animated. It is turned to match the hall.
	if state.get("truck", false):
		more().draw_unit(ci, "hauler", at.call(park.x, park.y, 0.0), tw * 0.62, on_v)
	elif state.has("truck_trip"):
		# A truck on its round: drives in from the right, backs into the bay,
		# waits while it tips its load, then drives off again.
		var f := float(state["truck_trip"])
		var off := 0.0
		if f < 0.3:
			off = (1.0 - f / 0.3) * 0.75
		elif f > 0.7:
			off = (f - 0.7) / 0.3 * 0.75
		if off < 0.7:
			more().draw_unit(ci, "hauler", at.call(park.x + off, park.y, 0.0), tw * 0.62, on_v)
	if lit:
		_glow(ci, at.call(0.20, f1, 0.12), tw * 0.016, _fade(GREEN, state), state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, half, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]) and (d.y != 0) == on_v:
			_iso_port(ci, at.call(half, 0.0, 0.06), tw, state, true, d)


## The Reclaimer from above.
static func _top_reclaimer(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var p := func(a: float, f: float) -> Vector2:
		return c + (Vector2(f, a) if on_v else Vector2(a, f)) * s
	var rect := Rect2(p.call(-0.30, -0.22), Vector2.ZERO).expand(p.call(0.30, 0.12))
	ci.draw_rect(rect, _fade(Color(0.55, 0.60, 0.55), state))
	ci.draw_rect(rect, _fade(GREEN, state), false, 2.0)
	ci.draw_circle(p.call(0.05, -0.05), s * 0.08, _fade(METAL_DARK, state))
	var tq: Vector2 = p.call(0.24, -0.34)
	ci.draw_circle(tq, s * 0.10, _fade(WATER, state).darkened(0.1))
	# The drop-off bay, the pit, and a truck if one is parked.
	var park: Vector2 = RECLAIMER_BAY["park"]
	var pit: Vector2 = RECLAIMER_BAY["pit"]
	var pad := Rect2(p.call(park.x - 0.20, park.y - 0.12), Vector2.ZERO).expand(p.call(park.x + 0.18, park.y + 0.13))
	ci.draw_rect(pad, _fade(Color(0.40, 0.40, 0.42), state))
	ci.draw_rect(pad, _fade(HAZARD, state), false, 1.5)
	var pr := Rect2(p.call(pit.x - 0.06, pit.y - 0.09), Vector2.ZERO).expand(p.call(pit.x + 0.06, pit.y + 0.09))
	ci.draw_rect(pr, Color(0.05, 0.05, 0.06))
	ci.draw_rect(pr, _fade(HAZARD, state), false, 1.5)
	if state.get("truck", false):
		var tr := Rect2(p.call(park.x - 0.15, park.y - 0.07), Vector2.ZERO).expand(p.call(park.x + 0.15, park.y + 0.07))
		ci.draw_rect(tr, _fade(HAZARD, state))
		ci.draw_rect(Rect2(p.call(park.x + 0.07, park.y - 0.07), Vector2.ZERO).expand(p.call(park.x + 0.15, park.y + 0.07)), _fade(HAZARD, state).darkened(0.25))
	for k in 3:
		var bcol: Color = [Color(0.60, 0.62, 0.66), Color(0.35, 0.70, 0.40), Color(0.35, 0.55, 0.90)][k]
		ci.draw_rect(Rect2(p.call(0.08 + k * 0.08, 0.20), Vector2(s * 0.06, s * 0.06)), _fade(bcol, state))
	ci.draw_rect(Rect2(p.call(0.34, 0.30), Vector2(s * 0.10, s * 0.10)), _fade(Color(0.58, 0.52, 0.42), state))
	for d in DIRS:
		if (d.y != 0) == on_v:
			_top_port(ci, p.call(0.30 * (d.y if on_v else d.x), 0.0), s, state, not (d in links), d)


## The Battery Bank: a control hut by the door and rows of battery cabinets,
## each with a glowing green charge bar.
static func _iso_battery(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var dd := _solar_door(links, state)
	var bc := Vector2(dd) * 0.27
	var hw := 0.15
	var green := _fade(Color(0.40, 1.0, 0.55), state)
	var lit := _lit(state)
	_back_links(ci, c, tw, links, 0.27 + hw, state)
	var cells: Array = []
	for u in [-0.33, -0.11, 0.11, 0.33]:
		for v in [-0.30, 0.0, 0.30]:
			if absf(u - bc.x) < 0.27 and absf(v - bc.y) < 0.27:
				continue
			cells.append(Vector2(u, v))
	cells.sort_custom(func(p, q): return p.x + p.y < q.x + q.y)
	var hut_done := false
	var case_col := _fade(Color(0.30, 0.34, 0.40), state)
	for q in cells:
		if not hut_done and q.x + q.y > bc.x + bc.y:
			_solar_hut(ci, c, tw, bc, hw, dd, state, Color(0.40, 1.0, 0.55))
			hut_done = true
		_box(ci, c, tw, q.x - 0.08, q.y - 0.10, q.x + 0.08, q.y + 0.10, 0.16, case_col, case_col.lightened(0.15))
		# The charge bar on the front face of each cabinet.
		var b0 := _iso(c, tw, q.x - 0.05, q.y + 0.10, 0.04)
		var b1 := _iso(c, tw, q.x - 0.05, q.y + 0.10, 0.13)
		ci.draw_line(b0, b1, Color(0.05, 0.05, 0.06, case_col.a), maxf(3.0, tw * 0.02))
		ci.draw_line(b0, b0.lerp(b1, 0.7), green if lit else case_col.lightened(0.3), maxf(2.0, tw * 0.014))
		ci.draw_line(_iso(c, tw, q.x + 0.02, q.y + 0.10, 0.12), _iso(c, tw, q.x + 0.06, q.y + 0.10, 0.12), _fade(HAZARD, state), maxf(1.5, tw * 0.01))
	if not hut_done:
		_solar_hut(ci, c, tw, bc, hw, dd, state, Color(0.40, 1.0, 0.55))
	_front_links(ci, c, tw, links, 0.27 + hw, state)


## The Heat Store: a big squat insulated tank with orange bands and glowing
## vents, and a pump hut by the door.
static func _iso_heatstore(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var dd := _solar_door(links, state)
	var bc := Vector2(dd) * 0.28
	var hw := 0.13
	var orange := _fade(ORANGE, state)
	var lit := _lit(state)
	_back_links(ci, c, tw, links, 0.28 + hw, state)
	var tq := -Vector2(dd) * 0.10
	var draw_tank := func() -> void:
		var shell := _fade(Color(0.78, 0.74, 0.70), state)
		_cyl(ci, c, tw, tq.x, tq.y, 0.27, 0.30, shell, shell.lightened(0.08))
		var rx := 0.27 * tw * 0.72
		for z in [0.07, 0.15, 0.23]:
			ci.draw_polyline(_ellipse(_iso(c, tw, tq.x, tq.y, z), rx, rx * 0.5, 0, 180, 18), orange, maxf(2.0, tw * 0.016))
		var top := _iso(c, tw, tq.x, tq.y, 0.30)
		for k in 3:
			var vp := top + Vector2((k - 1) * rx * 0.45, (k % 2) * rx * 0.1)
			ci.draw_colored_polygon(_ellipse(vp, tw * 0.03, tw * 0.015), Color(0.15, 0.06, 0.03, shell.a))
			if lit:
				_glow(ci, vp, tw * 0.02, _fade(Color(1.0, 0.5, 0.2), state), state)
				ci.draw_circle(vp - Vector2(0, tw * 0.05), tw * 0.025, Color(1.0, 0.85, 0.7, 0.25))
		# A temperature gauge.
		var g := _iso(c, tw, tq.x, tq.y, 0.18) + Vector2(0, rx * 0.5)
		ci.draw_circle(g, tw * 0.03, _fade(WHITE, state))
		ci.draw_line(g, g + Vector2(tw * 0.02, -tw * 0.015), Color(0.8, 0.2, 0.1, shell.a), 1.5)
	var tank_first := tq.x + tq.y < bc.x + bc.y
	if tank_first:
		draw_tank.call()
	ci.draw_line(_iso(c, tw, tq.x, tq.y, 0.05), _iso(c, tw, bc.x, bc.y, 0.05), _fade(METAL_DARK, state), maxf(3.0, tw * 0.025))
	_solar_hut(ci, c, tw, bc, hw, dd, state, ORANGE)
	if not tank_first:
		draw_tank.call()
	_front_links(ci, c, tw, links, 0.28 + hw, state)


## A mushroom: a stalk and a round cap with spots.
static func _mushroom(ci: CanvasItem, p: Vector2, size: float, cap: Color) -> void:
	ci.draw_line(p, p - Vector2(0, size * 0.9), Color(0.92, 0.88, 0.80, cap.a), maxf(2.0, size * 0.35))
	var top := p - Vector2(0, size * 0.9)
	var dome := _ellipse(top, size * 0.8, size * 0.3, 0, 180, 10)
	dome.append_array(_ellipse(top, size * 0.8, size * 0.6, 180, 360, 10))
	ci.draw_colored_polygon(dome, cap)
	ci.draw_circle(top - Vector2(size * 0.25, size * 0.25), maxf(1.0, size * 0.12), Color(1, 1, 1, 0.7 * cap.a))
	ci.draw_circle(top + Vector2(size * 0.2, -size * 0.35), maxf(1.0, size * 0.1), Color(1, 1, 1, 0.7 * cap.a))


## The Mushroom Farm: a dark grow-hall with purple grow-light strips, and big
## mushrooms growing in beds out front.
static func _iso_mushroom(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var lit := _lit(state)
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, f, a, z) if on_v else _iso(c, tw, a, f, z)
	var half := 0.30
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, half, state)
	var wall := _fade(Color(0.26, 0.22, 0.24), state)
	if on_v:
		_box(ci, c, tw, -0.20, -half, 0.12, half, 0.20, wall, _fade(Color(0.35, 0.30, 0.34), state))
	else:
		_box(ci, c, tw, -half, -0.20, half, 0.12, 0.20, wall, _fade(Color(0.35, 0.30, 0.34), state))
	# Grow-light strips glowing through slots in the wall.
	var violet := _fade(Color(0.80, 0.45, 1.0), state)
	for k in 3:
		var z := 0.05 + k * 0.05
		ci.draw_line(at.call(-half + 0.04, 0.12, z), at.call(half - 0.04, 0.12, z), violet if lit else wall.lightened(0.2), maxf(1.5, tw * 0.012))
	# Misting pipe along the roof edge.
	ci.draw_line(at.call(-half, 0.10, 0.21), at.call(half, 0.10, 0.21), _fade(METAL, state), maxf(1.5, tw * 0.012))
	# Mushroom beds out front.
	var bed := _fade(Color(0.32, 0.24, 0.18), state)
	for k in 2:
		var a0 := -0.28 + k * 0.32
		var p0: Vector2 = at.call(a0, 0.20, 0.0)
		var p1: Vector2 = at.call(a0 + 0.24, 0.20, 0.0)
		var p2: Vector2 = at.call(a0 + 0.24, 0.40, 0.0)
		var p3: Vector2 = at.call(a0, 0.40, 0.0)
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), bed)
		var caps := [Color(0.85, 0.70, 0.50), Color(0.80, 0.35, 0.30), Color(0.92, 0.85, 0.70)]
		for j in 5:
			var mp: Vector2 = at.call(a0 + 0.04 + (j % 3) * 0.08, 0.25 + (j / 3) * 0.09, 0.0)
			_mushroom(ci, mp, tw * (0.035 + (j % 2) * 0.012), _fade(caps[(j + k) % 3], state))
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, half, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]) and (d.y != 0) == on_v:
			_iso_port(ci, at.call(half, 0.0, 0.06), tw, state, true, d)


## One round settling tank with blue water and a turning skimmer arm.
static func _settling_tank(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary) -> void:
	var rx := tw * 0.13
	var rim := _fade(Color(0.70, 0.72, 0.75), state)
	var body := _ellipse(p, rx, rx * 0.5, 0, 180, 14)
	body.append_array(_ellipse(p - Vector2(0, tw * 0.07), rx, rx * 0.5, 180, 0, 14))
	ci.draw_colored_polygon(body, rim.darkened(0.25))
	var top := p - Vector2(0, tw * 0.07)
	ci.draw_colored_polygon(_ellipse(top, rx, rx * 0.5), rim)
	ci.draw_colored_polygon(_ellipse(top, rx * 0.86, rx * 0.43), _fade(WATER, state).darkened(0.05))
	ci.draw_line(top - Vector2(rx * 0.8, rx * 0.1), top + Vector2(rx * 0.8, rx * 0.1), _fade(METAL_DARK, state), maxf(1.5, tw * 0.012))
	ci.draw_circle(top, tw * 0.015, _fade(METAL_DARK, state))
	ci.draw_arc(top + Vector2(rx * 0.3, 0), rx * 0.25, deg_to_rad(200), deg_to_rad(320), 6, Color(1, 1, 1, 0.5), 1.0)


## The Water Recycler: a filter house, two settling tanks of clean water and
## pipes between them.
static func _iso_waterworks(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var lit := _lit(state)
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, f, a, z) if on_v else _iso(c, tw, a, f, z)
	var half := 0.30
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, half, state)
	var wall := _fade(Color(0.60, 0.72, 0.80), state)
	if on_v:
		_box(ci, c, tw, -0.22, -half, 0.08, half, 0.20, wall, _fade(Color(0.70, 0.80, 0.86), state))
	else:
		_box(ci, c, tw, -half, -0.22, half, 0.08, 0.20, wall, _fade(Color(0.70, 0.80, 0.86), state))
	ci.draw_line(at.call(-half, 0.08, 0.16), at.call(half, 0.08, 0.16), _fade(WATER, state), maxf(2.0, tw * 0.015))
	# Filter columns on the roof.
	for k in 3:
		var fp: Vector2 = at.call(-0.20 + k * 0.10, -0.08, 0.20)
		var col := PackedVector2Array([fp + Vector2(-tw * 0.025, 0), fp + Vector2(tw * 0.025, 0), fp + Vector2(tw * 0.025, -tw * 0.10), fp + Vector2(-tw * 0.025, -tw * 0.10)])
		ci.draw_colored_polygon(col, _fade(Color(0.85, 0.90, 0.95), state))
		ci.draw_colored_polygon(_ellipse(fp - Vector2(0, tw * 0.10), tw * 0.025, tw * 0.012), _fade(WATER, state))
	# Two settling tanks out front, with a pipe from the house.
	for k in 2:
		var tp: Vector2 = at.call(-0.16 + k * 0.30, 0.30, 0.0)
		ci.draw_line(at.call(-0.16 + k * 0.30, 0.08, 0.05), tp - Vector2(0, tw * 0.04), _fade(METAL_DARK, state), maxf(2.5, tw * 0.02))
		_settling_tank(ci, tp, tw, state)
	if lit:
		_glow(ci, at.call(0.22, 0.08, 0.11), tw * 0.014, _fade(WATER, state), state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, half, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]) and (d.y != 0) == on_v:
			_iso_port(ci, at.call(half, 0.0, 0.06), tw, state, true, d)


## The Trading Post: a market hall with striped awnings, crates and barrels
## out front, and a sign with a coin.
static func _iso_market(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var md := _fade(METAL_DARK, state)
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, f, a, z) if on_v else _iso(c, tw, a, f, z)
	var half := 0.30
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, half, state)
	var wall := _fade(Color(0.80, 0.66, 0.46), state)
	if on_v:
		_box(ci, c, tw, -0.22, -half, 0.08, half, 0.22, wall, _fade(Color(0.58, 0.38, 0.28), state))
	else:
		_box(ci, c, tw, -half, -0.22, half, 0.08, 0.22, wall, _fade(Color(0.58, 0.38, 0.28), state))
	# Three shop fronts, each under a striped awning.
	var stripes := [[Color(0.90, 0.30, 0.30), Color(0.98, 0.95, 0.90)], [Color(0.30, 0.55, 0.90), Color(0.98, 0.95, 0.90)], [Color(0.30, 0.70, 0.40), Color(0.98, 0.95, 0.90)]]
	for k in 3:
		var a0 := -0.27 + k * 0.19
		var a1 := a0 + 0.16
		ci.draw_colored_polygon(PackedVector2Array([at.call(a0 + 0.02, 0.08, 0.02), at.call(a1 - 0.02, 0.08, 0.02), at.call(a1 - 0.02, 0.08, 0.12), at.call(a0 + 0.02, 0.08, 0.12)]), _fade(Color(1.0, 0.86, 0.58), state).darkened(0.1))
		for j in 4:
			var s0 := a0 + j * 0.04
			var aw := PackedVector2Array([at.call(s0, 0.08, 0.17), at.call(s0 + 0.04, 0.08, 0.17), at.call(s0 + 0.04, 0.16, 0.12), at.call(s0, 0.16, 0.12)])
			ci.draw_colored_polygon(aw, _fade(stripes[k][j % 2], state))
	# The coin sign on the roof.
	var sign: Vector2 = at.call(0.0, -0.07, 0.22) - Vector2(0, tw * 0.09)
	ci.draw_line(at.call(0.0, -0.07, 0.22), sign + Vector2(0, tw * 0.04), md, maxf(1.5, tw * 0.012))
	ci.draw_circle(sign, tw * 0.05, _fade(GOLD, state))
	ci.draw_circle(sign, tw * 0.038, _fade(GOLD, state).darkened(0.15))
	ci.draw_line(sign + Vector2(-tw * 0.015, tw * 0.015), sign + Vector2(-tw * 0.015, -tw * 0.015), _fade(GOLD, state).lightened(0.3), 1.5)
	ci.draw_line(sign + Vector2(tw * 0.015, tw * 0.015), sign + Vector2(tw * 0.015, -tw * 0.015), _fade(GOLD, state).lightened(0.3), 1.5)
	ci.draw_line(sign + Vector2(-tw * 0.015, -tw * 0.015), sign + Vector2(0, 0), _fade(GOLD, state).lightened(0.3), 1.5)
	ci.draw_line(sign + Vector2(tw * 0.015, -tw * 0.015), sign + Vector2(0, 0), _fade(GOLD, state).lightened(0.3), 1.5)
	# Crates and barrels for sale out front.
	var crate := _fade(Color(0.62, 0.46, 0.28), state)
	for k in 3:
		var a0 := -0.30 + k * 0.10
		var z := 0.0 if k < 2 else 0.06
		var aa := a0 if k < 2 else -0.25
		if on_v:
			_box(ci, c, tw, 0.24, aa, 0.32, aa + 0.08, 0.06, crate, crate.lightened(0.1), z)
		else:
			_box(ci, c, tw, aa, 0.24, aa + 0.08, 0.32, 0.06, crate, crate.lightened(0.1), z)
	for k in 2:
		var bp: Vector2 = at.call(0.18 + k * 0.09, 0.30, 0.0)
		var bq: Vector2 = Vector2(0.30, 0.18 + k * 0.09) if on_v else Vector2(0.18 + k * 0.09, 0.30)
		_cyl(ci, c, tw, bq.x, bq.y, 0.04, 0.08, _fade(Color(0.40, 0.55, 0.75), state), _fade(Color(0.50, 0.65, 0.85), state))
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, half, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]) and (d.y != 0) == on_v:
			_iso_port(ci, at.call(half, 0.0, 0.06), tw, state, true, d)


## The Schoolhouse: a bright blue school with big windows full of children's
## drawings, a rainbow arch over the roof, a flag, and a playground with a slide
## and a swing.
static func _iso_school(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var lit := _lit(state)
	var hw := 0.24
	var hh := 0.24
	_back_links(ci, c, tw, links, hw, state)
	# The flag at the back corner.
	var fp := _iso(c, tw, -0.38, -0.38, 0.0)
	var ft := _iso(c, tw, -0.38, -0.38, 0.55)
	ci.draw_line(fp, ft, md.lightened(0.3), maxf(1.5, tw * 0.01))
	ci.draw_colored_polygon(PackedVector2Array([ft, ft + Vector2(tw * 0.09, tw * 0.02), ft + Vector2(0, tw * 0.05)]), _fade(Color(0.98, 0.80, 0.25), state))
	var wall := _fade(Color(0.45, 0.65, 0.92), state)
	_box(ci, c, tw, -hw, -hw, hw, hw, hh, wall, _fade(Color(0.95, 0.90, 0.75), state))
	# Big windows with children's drawings: bright patches of colour.
	var draw := [Color(1.0, 0.45, 0.40), Color(1.0, 0.85, 0.30), Color(0.45, 0.85, 0.45), Color(0.85, 0.55, 1.0)]
	for front in [true, false]:
		for i in 2:
			var a := -0.19 + i * 0.25
			var win := _wall_window(ci, c, tw, front, hw, a, 0.13, 0.07, 0.18, _fade(Color(1.0, 0.95, 0.80), state) if lit else _fade(Color(0.75, 0.85, 0.95), state))
			for k in 3:
				var p := win[0].lerp(win[2], 0.2 + k * 0.3) + Vector2(0, -tw * 0.005 * k)
				ci.draw_rect(Rect2(p - Vector2(tw * 0.01, tw * 0.012), Vector2(tw * 0.02, tw * 0.024)), _fade(draw[(k + i + (1 if front else 0)) % 4], state))
			ci.draw_polyline(PackedVector2Array([win[0], win[1], win[2], win[3], win[0]]), _fade(WHITE, state), 1.5)
	# A rainbow arch over the roof.
	var top := _iso(c, tw, 0, 0, hh)
	var bows := [Color(1.0, 0.35, 0.35), Color(1.0, 0.75, 0.25), Color(0.45, 0.85, 0.45), Color(0.35, 0.60, 1.0)]
	for k in 4:
		ci.draw_arc(top + Vector2(0, tw * 0.02), tw * (0.17 - k * 0.025), PI, TAU, 18, _fade(bows[k], state), maxf(2.0, tw * 0.016))
	# The playground at the front corner: a slide and a swing.
	var sl := _iso(c, tw, 0.36, 0.30, 0.0)
	var st := _iso(c, tw, 0.36, 0.30, 0.16)
	ci.draw_line(sl, st, md, 1.5)
	ci.draw_line(st, _iso(c, tw, 0.36, 0.44, 0.0), _fade(Color(1.0, 0.45, 0.40), state), maxf(2.5, tw * 0.02))
	var s0 := _iso(c, tw, 0.30, 0.40, 0.0)
	var s1 := _iso(c, tw, 0.44, 0.40, 0.0)
	var s0t := s0 - Vector2(0, tw * 0.14)
	var s1t := s1 - Vector2(0, tw * 0.14)
	ci.draw_line(s0, s0t, md, 1.5)
	ci.draw_line(s1, s1t, md, 1.5)
	ci.draw_line(s0t, s1t, md, 1.5)
	var mid := s0t.lerp(s1t, 0.5)
	ci.draw_line(mid, mid + Vector2(0, tw * 0.09), md.lightened(0.3), 1.0)
	ci.draw_line(mid + Vector2(-tw * 0.02, tw * 0.09), mid + Vector2(tw * 0.02, tw * 0.09), _fade(Color(0.35, 0.60, 1.0), state), 2.0)
	_front_links(ci, c, tw, links, hw, state)


## The six newer buildings from above.
static func _top_new(ci: CanvasItem, type: String, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	match type:
		"battery", "heatstore":
			var dd := _solar_door(links, state)
			var hc := c + Vector2(dd) * 0.27 * s
			if type == "battery":
				for u in [-0.33, -0.11, 0.11, 0.33]:
					for v in [-0.30, 0.0, 0.30]:
						if absf(u - dd.x * 0.27) < 0.27 and absf(v - dd.y * 0.27) < 0.27:
							continue
						ci.draw_rect(Rect2(c + Vector2(u - 0.08, v - 0.10) * s, Vector2(0.16, 0.20) * s), _fade(Color(0.30, 0.34, 0.40), state))
						ci.draw_rect(Rect2(c + Vector2(u - 0.05, v - 0.06) * s, Vector2(0.03, 0.12) * s), _fade(Color(0.40, 1.0, 0.55), state))
			else:
				var tq := c - Vector2(dd) * 0.10 * s
				ci.draw_circle(tq, s * 0.27, _fade(Color(0.78, 0.74, 0.70), state))
				ci.draw_arc(tq, s * 0.27, 0, TAU, 24, _fade(ORANGE, state), 2.0)
				ci.draw_arc(tq, s * 0.18, 0, TAU, 24, _fade(ORANGE, state), 1.5)
				_glow(ci, tq, s * 0.03, _fade(ORANGE, state), state)
			var hw := s * (0.15 if type == "battery" else 0.13)
			ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.72, 0.74, 0.80), state))
			ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.40, 1.0, 0.55) if type == "battery" else ORANGE, state), false, 1.5)
			_top_port(ci, hc + Vector2(dd) * hw, s, state, not (dd in links), dd)
		"mushroom", "waterworks", "market":
			var on_v := _along_v(links, state)
			var p := func(a: float, f: float) -> Vector2:
				return c + (Vector2(f, a) if on_v else Vector2(a, f)) * s
			var roof: Color = {"mushroom": Color(0.35, 0.30, 0.34), "waterworks": Color(0.70, 0.80, 0.86), "market": Color(0.58, 0.38, 0.28)}[type]
			var rect := Rect2(p.call(-0.30, -0.22), Vector2.ZERO).expand(p.call(0.30, 0.10))
			ci.draw_rect(rect, _fade(roof, state))
			if type == "mushroom":
				for k in 2:
					var bed := Rect2(p.call(-0.28 + k * 0.32, 0.20), Vector2.ZERO).expand(p.call(-0.04 + k * 0.32, 0.40))
					ci.draw_rect(bed, _fade(Color(0.32, 0.24, 0.18), state))
					for j in 4:
						ci.draw_circle(p.call(-0.24 + k * 0.32 + j * 0.05, 0.28 + (j % 2) * 0.06), s * 0.025, _fade([Color(0.85, 0.70, 0.50), Color(0.80, 0.35, 0.30)][j % 2], state))
			elif type == "waterworks":
				for k in 2:
					ci.draw_circle(p.call(-0.16 + k * 0.30, 0.30), s * 0.12, _fade(Color(0.70, 0.72, 0.75), state))
					ci.draw_circle(p.call(-0.16 + k * 0.30, 0.30), s * 0.10, _fade(WATER, state))
			else:
				var cols := [Color(0.90, 0.30, 0.30), Color(0.30, 0.55, 0.90), Color(0.30, 0.70, 0.40)]
				for k in 3:
					ci.draw_rect(Rect2(p.call(-0.27 + k * 0.19, 0.08), Vector2.ZERO).expand(p.call(-0.11 + k * 0.19, 0.16)), _fade(cols[k], state))
				ci.draw_circle(p.call(0.0, -0.07), s * 0.05, _fade(GOLD, state))
			for d in DIRS:
				if (d.y != 0) == on_v:
					_top_port(ci, p.call(0.30 * (d.y if on_v else d.x), 0.0), s, state, not (d in links), d)
		"school":
			var hw := s * 0.24
			ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.95, 0.90, 0.75), state))
			ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.45, 0.65, 0.92), state), false, 2.0)
			var bows := [Color(1.0, 0.35, 0.35), Color(1.0, 0.75, 0.25), Color(0.45, 0.85, 0.45), Color(0.35, 0.60, 1.0)]
			for k in 4:
				ci.draw_arc(c, s * (0.17 - k * 0.025), PI, TAU, 14, _fade(bows[k], state), 2.0)
			ci.draw_line(c + Vector2(0.36, 0.30) * s, c + Vector2(0.36, 0.44) * s, _fade(Color(1.0, 0.45, 0.40), state), 3.0)
			ci.draw_line(c + Vector2(0.30, 0.40) * s, c + Vector2(0.44, 0.40) * s, md, 2.0)
			for d in DIRS:
				_top_port(ci, c + Vector2(d) * hw, s, state, not (d in links), d)


## Whether a two-door building runs along v (doors facing ±y) rather than u.
static func _along_v(links: Array, state: Dictionary) -> bool:
	for d in links:
		return d.y != 0
	for d in state.get("doors", []):
		return d.y != 0
	return false


## The Rescue Station: a red station block with two roll-up garage bays, a
## rescue rover with flashing lights out front, a siren tower and a stack of
## brace beams. Its two doors are at the ends of the block.
static func _iso_rescue(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var red := _fade(Color(0.82, 0.20, 0.16), state)
	var white := _fade(WHITE, state)
	var lit := _lit(state)
	# A point on the tile: `a` along the building, `f` toward the front (the
	# side facing the viewer), at height z.
	var at := func(a: float, f: float, z: float) -> Vector2:
		return _iso(c, tw, f, a, z) if on_v else _iso(c, tw, a, f, z)
	var half := 0.32
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, half, state)
	# The station block.
	var f0 := -0.24
	var f1 := 0.10
	var hh := 0.24
	if on_v:
		_box(ci, c, tw, f0, -half, f1, half, hh, red, _fade(Color(0.85, 0.85, 0.88), state))
	else:
		_box(ci, c, tw, -half, f0, half, f1, hh, red, _fade(Color(0.85, 0.85, 0.88), state))
	# A white band round the top of the walls.
	ci.draw_polyline(PackedVector2Array([at.call(-half, f1, 0.19), at.call(half, f1, 0.19)]), white, maxf(2.5, tw * 0.02))
	# Two roll-up bay doors on the front; the near one half open.
	for k in 2:
		var a0 := -0.26 + k * 0.30
		var a1 := a0 + 0.22
		var top := 0.16
		var door := PackedVector2Array([at.call(a0, f1, 0.0), at.call(a1, f1, 0.0), at.call(a1, f1, top), at.call(a0, f1, top)])
		ci.draw_colored_polygon(door, _fade(Color(0.80, 0.82, 0.86), state))
		var open := 0.0 if k == 0 else 0.55
		if open > 0.0:
			ci.draw_colored_polygon(PackedVector2Array([at.call(a0, f1, 0.0), at.call(a1, f1, 0.0), at.call(a1, f1, top * open), at.call(a0, f1, top * open)]), Color(0.05, 0.05, 0.06, red.a))
		for sl in 5:
			var z := top * (open + (1.0 - open) * float(sl + 1) / 6.0)
			ci.draw_line(at.call(a0, f1, z), at.call(a1, f1, z), md.lightened(0.3), 1.0)
		ci.draw_polyline(PackedVector2Array([door[0], door[3], door[2], door[1]]), md, 1.5)
	# The siren tower at the back end of the roof.
	var tb: Vector2 = at.call(-0.22, -0.14, hh)
	var tt: Vector2 = at.call(-0.22, -0.14, hh + 0.24)
	ci.draw_line(tb, tt, md.lightened(0.2), maxf(2.5, tw * 0.02))
	ci.draw_circle(tt, tw * 0.03, m)
	_glow(ci, tt - Vector2(tw * 0.02, 0), tw * 0.018, _fade(Color(1.0, 0.25, 0.2), state), state)
	_glow(ci, tt + Vector2(tw * 0.02, 0), tw * 0.018, _fade(Color(0.3, 0.5, 1.0), state), state)
	if lit:
		for k in 2:
			ci.draw_arc(tt, tw * (0.06 + k * 0.04), deg_to_rad(-30), deg_to_rad(30), 6, Color(1.0, 0.4, 0.3, 0.6 - k * 0.2), 1.5)
			ci.draw_arc(tt, tw * (0.06 + k * 0.04), deg_to_rad(150), deg_to_rad(210), 6, Color(0.4, 0.6, 1.0, 0.6 - k * 0.2), 1.5)
	# The rescue rover parked in front of the closed bay.
	_rescue_rover(ci, at, tw, -0.15, 0.28, state)
	# A stack of yellow brace beams out front, ready to load.
	for k in 3:
		for j in 2 - (k / 2):
			var f := 0.30 + j * 0.06 + k * 0.03
			var b0: Vector2 = at.call(0.16, f, 0.02 + k * 0.03)
			var b1: Vector2 = at.call(0.42, f, 0.02 + k * 0.03)
			ci.draw_line(b0, b1, _fade(METAL_DARK, state), maxf(4.0, tw * 0.032))
			ci.draw_line(b0, b1, _fade(HAZARD, state), maxf(2.5, tw * 0.022))
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, half, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]):
			var e: Vector2 = at.call(half, 0.0, 0.06) if (d.y != 0) == on_v else Vector2.INF
			if e != Vector2.INF:
				_iso_port(ci, e, tw, state, true, d)


## A small red rescue rover with a white stripe and a red and blue light bar.
static func _rescue_rover(ci: CanvasItem, at: Callable, tw: float, a: float, f: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var red := _fade(Color(0.88, 0.22, 0.18), state)
	var tyre := Color(0.07, 0.07, 0.08, red.a)
	for w in [[a - 0.07, f - 0.05], [a + 0.07, f - 0.05], [a - 0.07, f + 0.05], [a + 0.07, f + 0.05]]:
		ci.draw_circle(at.call(w[0], w[1], 0.03), tw * 0.03, tyre)
	var body := PackedVector2Array([at.call(a - 0.10, f + 0.06, 0.04), at.call(a + 0.10, f + 0.06, 0.04), at.call(a + 0.10, f + 0.06, 0.11), at.call(a - 0.10, f + 0.06, 0.11)])
	var roof := PackedVector2Array([at.call(a - 0.10, f - 0.06, 0.11), at.call(a + 0.10, f - 0.06, 0.11), at.call(a + 0.10, f + 0.06, 0.11), at.call(a - 0.10, f + 0.06, 0.11)])
	var end := PackedVector2Array([at.call(a + 0.10, f - 0.06, 0.04), at.call(a + 0.10, f + 0.06, 0.04), at.call(a + 0.10, f + 0.06, 0.11), at.call(a + 0.10, f - 0.06, 0.11)])
	ci.draw_colored_polygon(end, red.darkened(0.3))
	ci.draw_colored_polygon(body, red.darkened(0.1))
	ci.draw_colored_polygon(roof, red.lightened(0.15))
	ci.draw_line(at.call(a - 0.10, f + 0.06, 0.075), at.call(a + 0.10, f + 0.06, 0.075), _fade(WHITE, state), maxf(1.5, tw * 0.012))
	ci.draw_colored_polygon(PackedVector2Array([at.call(a + 0.04, f + 0.06, 0.08), at.call(a + 0.09, f + 0.06, 0.08), at.call(a + 0.09, f + 0.06, 0.105), at.call(a + 0.04, f + 0.06, 0.105)]), _fade(Color(0.55, 0.80, 0.95), state))
	_glow(ci, at.call(a - 0.02, f, 0.13), tw * 0.014, _fade(Color(1.0, 0.25, 0.2), state), state)
	_glow(ci, at.call(a + 0.03, f, 0.13), tw * 0.014, _fade(Color(0.3, 0.5, 1.0), state), state)
	ci.draw_line(at.call(a - 0.10, f + 0.06, 0.04), at.call(a + 0.10, f + 0.06, 0.04), md, 1.0)


## The Rescue Station from above.
static func _top_rescue(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var on_v := _along_v(links, state)
	var md := _fade(METAL_DARK, state)
	var red := _fade(Color(0.82, 0.20, 0.16), state)
	var p := func(a: float, f: float) -> Vector2:
		return c + (Vector2(f, a) if on_v else Vector2(a, f)) * s
	var r0: Vector2 = p.call(-0.32, -0.24)
	var r1: Vector2 = p.call(0.32, 0.10)
	var rect := Rect2(r0, Vector2.ZERO).expand(r1)
	ci.draw_rect(rect, _fade(Color(0.85, 0.85, 0.88), state))
	ci.draw_rect(rect, red, false, maxf(2.0, s * 0.03))
	for k in 3:
		var b0: Vector2 = p.call(0.16, 0.30 + k * 0.05)
		var b1: Vector2 = p.call(0.42, 0.30 + k * 0.05)
		ci.draw_line(b0, b1, _fade(HAZARD, state), maxf(2.0, s * 0.02))
	var tower: Vector2 = p.call(-0.22, -0.14)
	ci.draw_circle(tower, s * 0.04, md)
	_glow(ci, tower, s * 0.02, _fade(Color(1.0, 0.25, 0.2), state), state)
	var rv: Vector2 = p.call(-0.15, 0.28)
	var rr := Rect2(rv - Vector2(s * 0.10, s * 0.06), Vector2(s * 0.20, s * 0.12)) if not on_v else Rect2(rv - Vector2(s * 0.06, s * 0.10), Vector2(s * 0.12, s * 0.20))
	ci.draw_rect(rr, red)
	ci.draw_circle(rr.get_center() - Vector2(s * 0.02, 0), s * 0.015, _fade(Color(1.0, 0.25, 0.2), state))
	ci.draw_circle(rr.get_center() + Vector2(s * 0.02, 0), s * 0.015, _fade(Color(0.3, 0.5, 1.0), state))
	for d in DIRS:
		if (d.y != 0) == on_v:
			_top_port(ci, p.call(0.32 * (d.y if on_v else d.x), 0.0), s, state, not (d in links), d)


## The Ice Drill: a striped drilling tower over a frosty borehole, a big
## insulated melt tank where the ice becomes water, and a pump house by the
## door where the tunnel joins. Pipes run between them.
static func _iso_drill(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var dd := _solar_door(links, state)
	var fwd := Vector2(dd)
	var side := Vector2(-fwd.y, fwd.x)
	var bc := fwd * 0.27
	var hw := 0.13
	var hole := -fwd * 0.12 + side * 0.18
	var tank := -fwd * 0.18 - side * 0.22
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, 0.27 + hw, state)
	# Frost round the borehole, and the hole itself.
	var hp := _iso(c, tw, hole.x, hole.y, 0.0)
	ci.draw_colored_polygon(_ellipse(hp, tw * 0.17, tw * 0.085), _fade(Color(0.85, 0.93, 1.0, 0.55), state))
	ci.draw_colored_polygon(_ellipse(hp, tw * 0.07, tw * 0.035), Color(0.02, 0.04, 0.08, 0.95))
	for k in 5:
		var ang := k * 1.3
		ci.draw_circle(hp + Vector2(cos(ang) * tw * 0.12, sin(ang) * tw * 0.055), maxf(1.5, tw * 0.012), _fade(Color(0.75, 0.88, 1.0), state))
	# Draw the three big pieces back to front.
	var parts := [[hole, "rig"], [tank, "tank"], [bc, "hut"]]
	parts.sort_custom(func(a, b): return a[0].x + a[0].y < b[0].x + b[0].y)
	# Pipes along the ground first.
	var md := _fade(METAL_DARK, state)
	var water := _fade(WATER, state)
	for pair in [[hole, tank], [tank, bc]]:
		var a0: Vector2 = pair[0]
		var a1: Vector2 = pair[1]
		ci.draw_line(_iso(c, tw, a0.x, a0.y, 0.03), _iso(c, tw, a1.x, a1.y, 0.03), md, maxf(3.0, tw * 0.024))
		ci.draw_line(_iso(c, tw, a0.x, a0.y, 0.03), _iso(c, tw, a1.x, a1.y, 0.03), water.darkened(0.2), maxf(1.2, tw * 0.010))
	for part in parts:
		var at: Vector2 = part[0]
		match part[1]:
			"rig":
				_drill_rig(ci, c, tw, at, state)
			"tank":
				_melt_tank(ci, c, tw, at, state)
			"hut":
				_solar_hut(ci, c, tw, bc, hw, dd, state, WATER)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, 0.27 + hw, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d == dd:
			_iso_port(ci, _iso(c, tw, d.x * (0.27 + hw), d.y * (0.27 + hw), 0.06), tw, state, true, d)


## The drilling tower: four striped legs to a winch at the top, with the drill
## pipe going down into the hole.
static func _drill_rig(ci: CanvasItem, c: Vector2, tw: float, at: Vector2, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var hazard := _fade(HAZARD, state)
	var top_z := 0.62
	var top := _iso(c, tw, at.x, at.y, top_z)
	var feet := [Vector2(-0.10, -0.10), Vector2(0.10, -0.10), Vector2(-0.10, 0.10), Vector2(0.10, 0.10)]
	# The drill pipe down the middle.
	ci.draw_line(top, _iso(c, tw, at.x, at.y, 0.0), m.lightened(0.15), maxf(2.0, tw * 0.016))
	for f in feet:
		var foot := _iso(c, tw, at.x + f.x, at.y + f.y, 0.0)
		var head := _iso(c, tw, at.x + f.x * 0.25, at.y + f.y * 0.25, top_z)
		# Yellow and black bands up each leg.
		for k in 6:
			var t0 := float(k) / 6.0
			var t1 := float(k + 1) / 6.0
			ci.draw_line(foot.lerp(head, t0), foot.lerp(head, t1), hazard if k % 2 == 0 else Color(0.08, 0.08, 0.08, hazard.a), maxf(2.0, tw * 0.014))
	# Cross braces.
	for z in [0.20, 0.40]:
		var k: float = 1.0 - float(z) / top_z * 0.75
		var ring := PackedVector2Array()
		for f in [Vector2(-0.10, -0.10), Vector2(0.10, -0.10), Vector2(0.10, 0.10), Vector2(-0.10, 0.10), Vector2(-0.10, -0.10)]:
			ring.append(_iso(c, tw, at.x + f.x * k, at.y + f.y * k, z))
		ci.draw_polyline(ring, md, 1.0)
	# The winch on top, and a work light.
	_box(ci, c, tw, at.x - 0.05, at.y - 0.05, at.x + 0.05, at.y + 0.05, 0.06, m, m.lightened(0.15), top_z)
	ci.draw_circle(_iso(c, tw, at.x + 0.05, at.y, top_z + 0.03), tw * 0.025, md)
	_glow(ci, _iso(c, tw, at.x, at.y, top_z + 0.09), tw * 0.016, _fade(AMBER, state), state)


## The insulated melt tank, with frost bands and a little steam on top.
static func _melt_tank(ci: CanvasItem, c: Vector2, tw: float, at: Vector2, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var shell := _fade(Color(0.82, 0.88, 0.95), state)
	var r := 0.13
	var hgt := 0.34
	_cyl(ci, c, tw, at.x, at.y, r, hgt, shell, shell.lightened(0.08))
	var rx := r * tw * 0.72
	for z in [0.08, 0.20, 0.30]:
		ci.draw_polyline(_ellipse(_iso(c, tw, at.x, at.y, z), rx, rx * 0.5, 0, 180, 14), _fade(WATER, state), maxf(1.5, tw * 0.012))
	# A level gauge down the front.
	var g0 := _iso(c, tw, at.x, at.y, 0.06) + Vector2(0, rx * 0.5)
	var g1 := _iso(c, tw, at.x, at.y, 0.28) + Vector2(0, rx * 0.5)
	ci.draw_line(g0, g1, md, maxf(2.0, tw * 0.014))
	ci.draw_line(g0, g0.lerp(g1, 0.65), _fade(WATER, state).lightened(0.2), maxf(1.0, tw * 0.008))
	if _lit(state):
		var lid := _iso(c, tw, at.x, at.y, hgt)
		_steam(ci, lid, tw, 0.8, 3, 0.35)


## The Ice Drill from above.
static func _top_drill(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var dd := _solar_door(links, state)
	var fwd := Vector2(dd)
	var side := Vector2(-fwd.y, fwd.x)
	var hole := c + (-fwd * 0.12 + side * 0.18) * s
	var tank := c + (-fwd * 0.18 - side * 0.22) * s
	var hc := c + fwd * 0.27 * s
	ci.draw_line(hole, tank, md, maxf(3.0, s * 0.03))
	ci.draw_line(tank, hc, md, maxf(3.0, s * 0.03))
	ci.draw_line(hole, tank, _fade(WATER, state).darkened(0.2), maxf(1.2, s * 0.012))
	ci.draw_line(tank, hc, _fade(WATER, state).darkened(0.2), maxf(1.2, s * 0.012))
	ci.draw_circle(hole, s * 0.15, _fade(Color(0.85, 0.93, 1.0, 0.55), state))
	ci.draw_circle(hole, s * 0.06, Color(0.02, 0.04, 0.08, 0.95))
	var hazard := _fade(HAZARD, state)
	for f in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ci.draw_line(hole + f * s * 0.10, hole, hazard, maxf(2.0, s * 0.02))
	ci.draw_rect(Rect2(hole - Vector2(s * 0.04, s * 0.04), Vector2(s * 0.08, s * 0.08)), _fade(METAL, state))
	ci.draw_circle(tank, s * 0.13, _fade(Color(0.82, 0.88, 0.95), state))
	ci.draw_arc(tank, s * 0.13, 0, TAU, 20, _fade(WATER, state), 2.0)
	ci.draw_circle(tank, s * 0.05, md)
	var hw := s * 0.13
	ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.72, 0.74, 0.80), state))
	ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(WATER, state), false, 1.5)
	_top_port(ci, hc + fwd * hw, s, state, not (dd in links), dd)


## The Solar Array (id "mirror"): a little control building by the door, and
## a big field of low solar panels in rows filling the rest of the tile.
static func _iso_mirror(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var dd := _solar_door(links, state)
	var bc := Vector2(dd) * 0.27
	var hw := 0.15
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, 0.27 + hw, state)
	# Panels and the building, back to front.
	var cells: Array = []
	for u in [-0.36, -0.12, 0.12, 0.36]:
		for v in [-0.36, -0.12, 0.12, 0.36]:
			if absf(u - bc.x) < 0.27 and absf(v - bc.y) < 0.27:
				continue
			cells.append(Vector2(u, v))
	cells.sort_custom(func(p, q): return p.x + p.y < q.x + q.y)
	var built := false
	for q in cells:
		if not built and q.x + q.y > bc.x + bc.y:
			_solar_hut(ci, c, tw, bc, hw, dd, state)
			built = true
		_solar_panel(ci, c, tw, q, state)
	if not built:
		_solar_hut(ci, c, tw, bc, hw, dd, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, 0.27 + hw, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d == dd:
			_iso_port(ci, _iso(c, tw, d.x * (0.27 + hw), d.y * (0.27 + hw), 0.06), tw, state, true, d)


## Which side the Solar Array's one door is on.
static func _solar_door(links: Array, state: Dictionary) -> Vector2i:
	if not links.is_empty():
		return links[0]
	var doors: Array = state.get("doors", [])
	return doors[0] if not doors.is_empty() else Vector2i(0, 1)


## The little control building: inverters inside, a cyan trim, a light, and
## an airlock doorway on the door side for the tunnel to plug into.
static func _solar_hut(ci: CanvasItem, c: Vector2, tw: float, bc: Vector2, hw: float, dd: Vector2i, state: Dictionary, trim: Color = CYAN) -> void:
	var md := _fade(METAL_DARK, state)
	var box := _fade(Color(0.70, 0.72, 0.78), state)
	var hh := 0.26
	_box(ci, c, tw, bc.x - hw, bc.y - hw, bc.x + hw, bc.y + hw, hh, box, box.lightened(0.12))
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, bc.x - hw, bc.y + hw, hh), _iso(c, tw, bc.x + hw, bc.y + hw, hh), _iso(c, tw, bc.x + hw, bc.y - hw, hh)]), _fade(trim, state), maxf(1.5, tw * 0.012))
	# Vents on the side wall that isn't the door.
	var vent_u := bc.x + hw
	if dd != Vector2i(1, 0):
		for k in 3:
			ci.draw_line(_iso(c, tw, vent_u, bc.y - 0.07 + k * 0.05, 0.10), _iso(c, tw, vent_u, bc.y - 0.07 + k * 0.05, 0.18), md, 1.0)
	_box(ci, c, tw, bc.x - 0.06, bc.y - 0.06, bc.x + 0.04, bc.y + 0.04, 0.05, md.lightened(0.2), md.lightened(0.3), hh)
	if dd != Vector2i(0, 1):
		_glow(ci, _iso(c, tw, bc.x - 0.05, bc.y + hw, 0.19), tw * 0.014, _fade(Color(0.4, 1.0, 0.5), state), state)
	# The airlock doorway on the visible door wall: an orange frame round a
	# dark opening, sized to the tunnel.
	if dd == Vector2i(1, 0) or dd == Vector2i(0, 1):
		var orange := _fade(ORANGE, state)
		var along := 0
		var fr := PackedVector2Array()
		var op := PackedVector2Array()
		for corner in [[-0.10, 0.0], [0.10, 0.0], [0.10, 0.21], [-0.10, 0.21]]:
			var w: float = corner[0]
			var z: float = corner[1]
			if dd == Vector2i(1, 0):
				fr.append(_iso(c, tw, bc.x + hw, bc.y + w, z))
				op.append(_iso(c, tw, bc.x + hw, bc.y + w * 0.75, z * 0.85 + 0.01))
			else:
				fr.append(_iso(c, tw, bc.x + w, bc.y + hw, z))
				op.append(_iso(c, tw, bc.x + w * 0.75, bc.y + hw, z * 0.85 + 0.01))
		ci.draw_colored_polygon(fr, md.lightened(0.1))
		ci.draw_colored_polygon(op, Color(0.04, 0.04, 0.05, md.a))
		ci.draw_polyline(PackedVector2Array([fr[0], fr[1], fr[2], fr[3], fr[0]]), orange, maxf(1.5, tw * 0.014))


## One low solar panel centred at q, tilted up toward the viewer, on short legs.
static func _solar_panel(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var hu := 0.105
	var hv := 0.085
	var lo := 0.035
	var hi := 0.11
	var p0 := _iso(c, tw, q.x - hu, q.y - hv, hi)
	var p1 := _iso(c, tw, q.x + hu, q.y - hv, hi)
	var p2 := _iso(c, tw, q.x + hu, q.y + hv, lo)
	var p3 := _iso(c, tw, q.x - hu, q.y + hv, lo)
	for u in [q.x - hu + 0.015, q.x + hu - 0.015]:
		ci.draw_line(_iso(c, tw, u, q.y - hv + 0.01, 0.0), _iso(c, tw, u, q.y - hv + 0.01, hi), md, maxf(1.0, tw * 0.008))
	var panel := PackedVector2Array([p0, p1, p2, p3])
	ci.draw_colored_polygon(panel, _fade(Color(0.10, 0.20, 0.42), state))
	var cell := _fade(Color(0.35, 0.55, 0.85), state)
	for k in range(1, 4):
		var t := float(k) / 4.0
		ci.draw_line(p0.lerp(p1, t), p3.lerp(p2, t), cell, 1.0)
	ci.draw_line(p0.lerp(p3, 0.5), p1.lerp(p2, 0.5), cell, 1.0)
	ci.draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), m.lightened(0.25), 1.0)
	ci.draw_line(p0.lerp(p1, 0.2).lerp(p3.lerp(p2, 0.2), 0.2), p0.lerp(p1, 0.5).lerp(p3.lerp(p2, 0.5), 0.7), Color(1, 1, 1, 0.45 * m.a), 1.0)


## The Solar Array from above: rows of panels and the little building by the door.
static func _top_mirror(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var dd := _solar_door(links, state)
	var bc := Vector2(dd) * 0.27
	for u in [-0.36, -0.12, 0.12, 0.36]:
		for v in [-0.36, -0.12, 0.12, 0.36]:
			if absf(u - bc.x) < 0.27 and absf(v - bc.y) < 0.27:
				continue
			var r := Rect2(c + Vector2((u - 0.105) * s, (v - 0.085) * s), Vector2(s * 0.21, s * 0.17))
			ci.draw_rect(r, _fade(Color(0.10, 0.20, 0.42), state))
			for k in range(1, 4):
				var x := r.position.x + r.size.x * float(k) / 4.0
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), _fade(Color(0.35, 0.55, 0.85), state), 1.0)
			ci.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), _fade(Color(0.35, 0.55, 0.85), state), 1.0)
			ci.draw_rect(r, m.lightened(0.25), false, 1.0)
	var hw := s * 0.15
	var hc := c + bc * s
	ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.72, 0.74, 0.80), state))
	ci.draw_rect(Rect2(hc - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(CYAN, state), false, 1.5)
	_glow(ci, hc, s * 0.02, _fade(Color(0.4, 1.0, 0.5), state), state)
	_top_port(ci, hc + Vector2(dd) * hw, s, state, not (dd in links), dd)


## The Radio Station: a small studio with an "on air" light and a dish on its
## roof, and a broadcast tower behind it sending out radio waves.
static func _iso_radio(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var cyan := _fade(CYAN, state)
	var red := _fade(Color(1.0, 0.25, 0.22), state)
	var lit := _lit(state)
	var hw := 0.22
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, hw, state)
	# The broadcast tower at the back corner: a lattice, wide at the foot.
	var tq := Vector2(0.30, -0.36)
	var foot := _iso(c, tw, tq.x, tq.y, 0.0)
	var top := _iso(c, tw, tq.x, tq.y, 0.70)
	var w0 := tw * 0.06
	for side in [-1.0, 1.0]:
		ci.draw_line(foot + Vector2(side * w0, 0), top + Vector2(side * tw * 0.008, 0), md.lightened(0.25), maxf(2.0, tw * 0.012))
	for k in 7:
		var t0 := float(k) / 7.0
		var t1 := float(k + 1) / 7.0
		var a0 := w0 * (1.0 - t0) + tw * 0.008 * t0
		var a1 := w0 * (1.0 - t1) + tw * 0.008 * t1
		var sd := 1.0 if k % 2 == 0 else -1.0
		ci.draw_line(foot.lerp(top, t0) + Vector2(-a0 * sd, 0), foot.lerp(top, t1) + Vector2(a1 * sd, 0), m, 1.0)
		ci.draw_line(foot.lerp(top, t1) + Vector2(-a1, 0), foot.lerp(top, t1) + Vector2(a1, 0), m.darkened(0.2), 1.0)
	# Red and white bands near the top, and the blinking light.
	for k in 2:
		var p0 := foot.lerp(top, 0.80 + k * 0.08)
		ci.draw_line(p0 + Vector2(-tw * 0.014, 0), p0 + Vector2(tw * 0.014, 0), red if k == 0 else _fade(WHITE, state), 3.0)
	_glow(ci, top, tw * 0.02, red, state)
	# Radio waves going out both ways.
	if lit:
		for k in 3:
			var rr := tw * (0.08 + k * 0.06)
			var col := Color(cyan.r, cyan.g, cyan.b, cyan.a * (0.85 - k * 0.22))
			ci.draw_arc(top, rr, deg_to_rad(-45), deg_to_rad(15), 8, col, 1.5)
			ci.draw_arc(top, rr, deg_to_rad(165), deg_to_rad(225), 8, col, 1.5)
	# The studio: on a plinth, two-tone walls with a stripe, and a roof edge.
	var wall := _fade(Color(0.66, 0.68, 0.74), state)
	var dark := _fade(Color(0.30, 0.34, 0.42), state)
	_box(ci, c, tw, -hw - 0.03, -hw - 0.03, hw + 0.03, hw + 0.03, 0.03, md.lightened(0.1))
	_box(ci, c, tw, -hw, -hw, hw, hw, 0.22, wall, wall.lightened(0.12), 0.03)
	_box(ci, c, tw, -hw, -hw, hw, hw, 0.05, dark, dark, 0.03)
	# The stripe round the walls.
	ci.draw_polyline(PackedVector2Array([_iso(c, tw, -hw, hw, 0.11), _iso(c, tw, hw, hw, 0.11), _iso(c, tw, hw, -hw, 0.11)]), cyan, maxf(2.0, tw * 0.014))
	# The roof edge (a low parapet), and a rooftop machine.
	var rz := 0.25
	var rim := PackedVector2Array([_iso(c, tw, -hw, -hw, rz), _iso(c, tw, hw, -hw, rz), _iso(c, tw, hw, hw, rz), _iso(c, tw, -hw, hw, rz), _iso(c, tw, -hw, -hw, rz)])
	ci.draw_polyline(rim, wall.lightened(0.3), maxf(2.0, tw * 0.016))
	_box(ci, c, tw, 0.06, 0.04, 0.16, 0.14, 0.05, m, m.lightened(0.15), rz)
	for k in 3:
		var gp := _iso(c, tw, 0.08 + k * 0.03, 0.04, rz + 0.025)
		ci.draw_line(gp, gp + Vector2(tw * 0.01, tw * 0.005), md, 1.0)
	# The big studio window on the front, with a microphone inside.
	var gl := PackedVector2Array([_iso(c, tw, -0.17, hw, 0.13), _iso(c, tw, 0.11, hw, 0.13), _iso(c, tw, 0.11, hw, 0.21), _iso(c, tw, -0.17, hw, 0.21)])
	ci.draw_colored_polygon(gl, _fade(Color(1.0, 0.86, 0.58), state) if lit else md)
	var mic_base := _iso(c, tw, -0.03, hw, 0.135)
	var mic := mic_base - Vector2(0, tw * 0.05)
	ci.draw_line(mic_base, mic, dark, 1.5)
	ci.draw_line(mic, mic + Vector2(tw * 0.02, -tw * 0.01), dark, 1.5)
	ci.draw_circle(mic + Vector2(tw * 0.025, -tw * 0.013), maxf(1.5, tw * 0.009), dark)
	ci.draw_polyline(PackedVector2Array([gl[0], gl[1], gl[2], gl[3], gl[0]]), md, 1.5)
	ci.draw_line(gl[0].lerp(gl[1], 0.5), gl[3].lerp(gl[2], 0.5), md, 1.0)
	# The station sign over the window: sound-level bars.
	var sg := PackedVector2Array([_iso(c, tw, -0.17, hw, 0.05), _iso(c, tw, 0.11, hw, 0.05), _iso(c, tw, 0.11, hw, 0.10), _iso(c, tw, -0.17, hw, 0.10)])
	ci.draw_colored_polygon(sg, Color(0.06, 0.07, 0.10, wall.a))
	var bars := [0.4, 0.8, 0.55, 1.0, 0.7, 0.35, 0.9, 0.5]
	for k in bars.size():
		var u := -0.155 + k * 0.033
		var hgt: float = 0.04 * float(bars[k])
		var col := _fade(Color(0.3, 1.0, 0.6), state) if k < 5 else _fade(Color(1.0, 0.8, 0.3), state)
		if not lit:
			col = md.lightened(0.15)
		ci.draw_line(_iso(c, tw, u, hw, 0.055), _iso(c, tw, u, hw, 0.055 + hgt), col, maxf(1.5, tw * 0.012))
	# The round "on air" lamp on the side wall.
	var lamp := _iso(c, tw, hw, -0.08, 0.17)
	ci.draw_circle(lamp, tw * 0.025, md)
	ci.draw_circle(lamp, tw * 0.018, red if lit else md.lightened(0.2))
	if lit:
		_glow(ci, lamp, tw * 0.02, red, state)
	# The cable from the tower to the roof.
	var tie := foot.lerp(top, 0.35)
	var roof_pt := _iso(c, tw, hw, -hw, rz)
	var sag := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		sag.append(tie.lerp(roof_pt, t) + Vector2(0, sin(t * PI) * tw * 0.03))
	ci.draw_polyline(sag, md, 1.0)
	# The dish on the roof, tilted up at the sky.
	var base := _iso(c, tw, -0.08, -0.08, 0.25)
	var dish := base - Vector2(0, tw * 0.06)
	ci.draw_line(base, dish, md, maxf(2.0, tw * 0.014))
	var dr := tw * 0.10
	ci.draw_colored_polygon(_ellipse(dish, dr, dr * 0.62), _fade(WHITE, state).darkened(0.08))
	ci.draw_colored_polygon(_ellipse(dish + Vector2(dr * 0.12, -dr * 0.06), dr * 0.68, dr * 0.40), _fade(WHITE, state).darkened(0.28))
	var feed := dish + Vector2(dr * 0.35, -dr * 0.75)
	ci.draw_line(dish + Vector2(-dr * 0.4, dr * 0.2), feed, md, 1.0)
	ci.draw_line(dish + Vector2(dr * 0.8, 0), feed, md, 1.0)
	ci.draw_circle(feed, maxf(1.5, tw * 0.01), md)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, hw, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]):
			_iso_port(ci, _iso(c, tw, d.x * hw, d.y * hw, 0.06), tw, state, true, d)


## The Radio Station from above: the studio's roof and dish, and the tower in
## the back corner with its light and radio waves.
static func _top_radio(ci: CanvasItem, c: Vector2, s: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var cyan := _fade(CYAN, state)
	var red := _fade(Color(1.0, 0.25, 0.22), state)
	var hw := s * 0.22
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.70, 0.72, 0.78), state))
	ci.draw_rect(Rect2(c - Vector2(hw + s * 0.03, hw + s * 0.03), Vector2(hw * 2.0 + s * 0.06, hw * 2.0 + s * 0.06)), md.lightened(0.1))
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.72, 0.74, 0.80), state))
	ci.draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), _fade(Color(0.85, 0.87, 0.92), state), false, 2.0)
	ci.draw_rect(Rect2(c + Vector2(s * 0.06, s * 0.04), Vector2(s * 0.10, s * 0.10)), m)
	ci.draw_line(c + Vector2(s * 0.30, -s * 0.36), c + Vector2(hw, -hw), md, 1.0)
	var dish := c + Vector2(-s * 0.06, -s * 0.06)
	ci.draw_circle(dish, s * 0.10, _fade(WHITE, state).darkened(0.08))
	ci.draw_circle(dish, s * 0.055, _fade(WHITE, state).darkened(0.28))
	ci.draw_circle(dish, s * 0.015, md)
	ci.draw_rect(Rect2(c + Vector2(s * 0.15, -s * 0.16), Vector2(s * 0.05, s * 0.12)), red)
	var tower := c + Vector2(s * 0.30, -s * 0.36)
	ci.draw_rect(Rect2(tower - Vector2(s * 0.05, s * 0.05), Vector2(s * 0.10, s * 0.10)), md)
	ci.draw_line(tower - Vector2(s * 0.05, s * 0.05), tower + Vector2(s * 0.05, s * 0.05), m, 1.0)
	ci.draw_line(tower + Vector2(s * 0.05, -s * 0.05), tower - Vector2(s * 0.05, -s * 0.05), m, 1.0)
	_glow(ci, tower, s * 0.02, red, state)
	if _lit(state):
		for k in 3:
			ci.draw_arc(tower, s * (0.10 + k * 0.06), deg_to_rad(200), deg_to_rad(340), 8, Color(cyan.r, cyan.g, cyan.b, cyan.a * (0.85 - k * 0.22)), 1.5)
	for d in DIRS:
		_top_port(ci, c + Vector2(d) * hw, s, state, not (d in links), d)


## The Beam Catcher: power beamed down from orbit lands on a golden target
## ring and pours into a funnel lens on a collector tower. Capacitor coils
## round it hold the power, and a converter drum at the base feeds the colony.
static func _iso_catcher(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var gold := _fade(GOLD, state)
	var orange := _fade(ORANGE, state)
	var lit := _lit(state)
	var base_r := 0.20
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, base_r, state)
	# The target ring on the ground: where the beam is aimed.
	var g := _iso(c, tw, 0, 0, 0.0)
	for k in 4:
		var rr := (0.46 - k * 0.10) * tw * 0.72
		ci.draw_colored_polygon(_ellipse(g, rr, rr * 0.5), md.darkened(0.2) if k % 2 == 0 else Color(gold.r, gold.g, gold.b, gold.a * (0.55 if lit else 0.3)))
	for i in 8:
		var ang := i * TAU / 8.0
		ci.draw_line(g + Vector2(cos(ang), sin(ang) * 0.5) * 0.30 * tw * 0.72, g + Vector2(cos(ang), sin(ang) * 0.5) * 0.46 * tw * 0.72, md.darkened(0.3), 1.0)
	# Capacitor coils: stacks of discs on poles, with a glowing cap.
	for q in [Vector2(-0.30, -0.30), Vector2(0.32, -0.30), Vector2(-0.30, 0.32)]:
		var top_z := 0.30
		ci.draw_line(_iso(c, tw, q.x, q.y, 0.0), _iso(c, tw, q.x, q.y, top_z), md.lightened(0.1), maxf(2.0, tw * 0.016))
		for k in 4:
			var dz := 0.07 + k * 0.06
			var dp := _iso(c, tw, q.x, q.y, dz)
			var dr := tw * (0.055 - k * 0.004)
			ci.draw_colored_polygon(_ellipse(dp, dr, dr * 0.5), m.lightened(0.1) if k % 2 == 0 else Color(0.55, 0.45, 0.30, m.a))
			ci.draw_polyline(_ellipse(dp, dr, dr * 0.5, 0, 180, 10), md, 1.0)
		_glow(ci, _iso(c, tw, q.x, q.y, top_z + 0.02), tw * 0.022, gold, state)
	# The converter drum at the base.
	_cyl(ci, c, tw, 0, 0, base_r, 0.13, m, m.lightened(0.15))
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.065), base_r * tw * 0.72, base_r * tw * 0.36, 0, 180, 16), orange, maxf(1.5, tw * 0.012))
	# The collector tower: a lattice mast.
	var t0 := 0.13
	var t1 := 0.34
	for side in [-1.0, 1.0]:
		ci.draw_line(_iso(c, tw, 0, 0, t0) + Vector2(side * tw * 0.05, 0), _iso(c, tw, 0, 0, t1) + Vector2(side * tw * 0.025, 0), md.lightened(0.2), maxf(2.0, tw * 0.014))
	for k in 3:
		var za := t0 + (t1 - t0) * float(k) / 3.0
		var zb := t0 + (t1 - t0) * float(k + 1) / 3.0
		var wa := tw * (0.05 - 0.025 * float(k) / 3.0)
		var wb := tw * (0.05 - 0.025 * float(k + 1) / 3.0)
		ci.draw_line(_iso(c, tw, 0, 0, za) + Vector2(-wa, 0), _iso(c, tw, 0, 0, zb) + Vector2(wb, 0), md, 1.0)
		ci.draw_line(_iso(c, tw, 0, 0, za) + Vector2(wa, 0), _iso(c, tw, 0, 0, zb) + Vector2(-wb, 0), md, 1.0)
	# The funnel lens on top, catching the beam.
	var lens := _iso(c, tw, 0, 0, t1 + 0.10)
	var lr := 0.26 * tw * 0.72
	var cone := _ellipse(lens, lr, lr * 0.5, 0, 180, 16)
	cone.append(_iso(c, tw, 0, 0, t1))
	ci.draw_colored_polygon(cone, m.darkened(0.1))
	ci.draw_colored_polygon(_ellipse(lens, lr, lr * 0.5), md)
	ci.draw_colored_polygon(_ellipse(lens, lr * 0.82, lr * 0.41), Color(gold.r, gold.g, gold.b, gold.a * (0.9 if lit else 0.35)))
	ci.draw_colored_polygon(_ellipse(lens, lr * 0.45, lr * 0.22), Color(1.0, 0.97, 0.85, gold.a) if lit else md)
	ci.draw_polyline(_ellipse(lens, lr, lr * 0.5), m.lightened(0.25), maxf(1.5, tw * 0.012))
	# The beam from orbit, when it's working.
	if lit:
		var sky := lens - Vector2(0, tw * 0.62)
		ci.draw_colored_polygon(PackedVector2Array([sky + Vector2(-lr * 0.30, 0), sky + Vector2(lr * 0.30, 0), lens + Vector2(lr * 0.75, 0), lens + Vector2(-lr * 0.75, 0)]), Color(gold.r, gold.g, gold.b, 0.22))
		ci.draw_colored_polygon(PackedVector2Array([sky + Vector2(-lr * 0.12, 0), sky + Vector2(lr * 0.12, 0), lens + Vector2(lr * 0.35, 0), lens + Vector2(-lr * 0.35, 0)]), Color(1.0, 0.92, 0.6, 0.45))
		ci.draw_line(sky, lens, Color(1.0, 1.0, 0.92, 0.95), maxf(1.5, tw * 0.01))
		for k in 3:
			var rp := lens - Vector2(0, tw * (0.08 + k * 0.14))
			ci.draw_polyline(_ellipse(rp, lr * (0.42 - k * 0.07), lr * (0.21 - k * 0.035)), Color(1.0, 0.9, 0.55, 0.6), 1.0)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, base_r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links) and d in state.get("doors", [d]):
			_iso_port(ci, _iso(c, tw, d.x * base_r * 0.95, d.y * base_r * 0.95, 0.06), tw, state, true, d)


## The lift tube shared by the Shaft (its top) and the Shaft Landing (its
## bottom): ribbed, with a window showing the lift car at height car_z. When
## `fade` is set the tube darkens as it rises into the cave roof.
static func _lift_tube(ci: CanvasItem, c: Vector2, tw: float, tr: float, z0: float, z1: float, fade_up: bool, car_z: float, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var rx := tr * tw * 0.72
	var ry := rx * 0.5
	var steps := 10
	for k in steps:
		var h0 := z0 + (z1 - z0) * float(k) / steps
		var h1 := z0 + (z1 - z0) * float(k + 1) / steps
		var fade := clampf((float(k) / steps - 0.45) / 0.55, 0.0, 1.0) if fade_up else 0.0
		var body := PackedVector2Array()
		var b0 := _iso(c, tw, 0, 0, h0)
		var b1 := _iso(c, tw, 0, 0, h1)
		body.append_array(_ellipse(b0, rx, ry, 0, 180, 14))
		body.append_array(_ellipse(b1, rx, ry, 180, 0, 14))
		var col := m.darkened(0.15).lerp(Color(0.10, 0.10, 0.12, m.a), fade * 0.8)
		ci.draw_colored_polygon(body, col)
		# Shade the right side so it reads as round.
		var sh := PackedVector2Array([b0 + Vector2(rx * 0.45, ry * 0.9), b0 + Vector2(rx, 0), b1 + Vector2(rx, 0), b1 + Vector2(rx * 0.45, ry * 0.9)])
		ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.25 * col.a))
		ci.draw_line(b0 - Vector2(rx * 0.55, -ry * 0.8), b1 - Vector2(rx * 0.55, -ry * 0.8), Color(1, 1, 1, 0.18 * col.a), maxf(1.0, tw * 0.01))
	# Ribs round the tube.
	var rib_z := z0 + 0.05
	while rib_z < z1 - 0.02:
		var t := (rib_z - z0) / (z1 - z0)
		var fa := 1.0 - clampf((t - 0.45) / 0.55, 0.0, 1.0) * 0.7 if fade_up else 1.0
		var ring := _iso(c, tw, 0, 0, rib_z)
		ci.draw_polyline(_ellipse(ring, rx * 1.06, ry * 1.06, 0, 180, 14), Color(md.r, md.g, md.b, md.a * fa), maxf(2.0, tw * 0.022))
		ci.draw_polyline(_ellipse(ring - Vector2(0, 1), rx * 1.06, ry * 1.06, 0, 180, 14), Color(m.r, m.g, m.b, 0.6 * m.a * fa).lightened(0.2), 1.0)
		rib_z += 0.20
	# The window, with the lift car and its cables inside.
	var w0 := _iso(c, tw, 0, 0, z0 + 0.10) + Vector2(0, ry)
	var w1 := _iso(c, tw, 0, 0, minf(z1 - 0.08, z0 + 0.74)) + Vector2(0, ry)
	var ww := rx * 0.42
	ci.draw_colored_polygon(PackedVector2Array([w0 + Vector2(-ww, 0), w0 + Vector2(ww, 0), w1 + Vector2(ww, 0), w1 + Vector2(-ww, 0)]), Color(0.03, 0.04, 0.06, m.a))
	for side in [-0.5, 0.5]:
		ci.draw_line(w1 + Vector2(ww * side, 0), w0 + Vector2(ww * side, 0), Color(0.6, 0.6, 0.6, 0.6 * m.a), 1.0)
	var car := _iso(c, tw, 0, 0, car_z) + Vector2(0, ry)
	var ch := tw * 0.14
	ci.draw_rect(Rect2(car + Vector2(-ww * 0.85, -ch), Vector2(ww * 1.7, ch)), _fade(Color(0.95, 0.75, 0.25), state))
	ci.draw_rect(Rect2(car + Vector2(-ww * 0.6, -ch * 0.8), Vector2(ww * 1.2, ch * 0.45)), _fade(Color(1.0, 0.92, 0.7), state) if _lit(state) else md)
	var glass := _fade(GLASS, state)
	ci.draw_colored_polygon(PackedVector2Array([w0 + Vector2(-ww, 0), w0 + Vector2(ww, 0), w1 + Vector2(ww, 0), w1 + Vector2(-ww, 0)]), Color(glass.r, glass.g, glass.b, glass.a * 0.35))
	ci.draw_polyline(PackedVector2Array([w0 + Vector2(-ww, 0), w0 + Vector2(ww, 0), w1 + Vector2(ww, 0), w1 + Vector2(-ww, 0), w0 + Vector2(-ww, 0)]), md.lightened(0.2), 1.5)


## The Shaft Landing in the Deep: the shaft comes down from the cave roof as a
## tall ribbed tube onto a landing deck, with the lift car seen through its window.
static func _iso_landing(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var md := _fade(METAL_DARK, state)
	var m := _fade(METAL, state)
	var orange := _fade(ORANGE, state)
	var deck_r := 0.40
	for d in links:
		if d.x < 0 or d.y < 0:
			_iso_link(ci, c, tw, d, deck_r, state)
	# The landing deck, with a hazard-striped edge.
	var center := _iso(c, tw, 0, 0, 0.0)
	var drx := deck_r * tw * 0.72
	_cyl(ci, c, tw, 0, 0, deck_r, 0.06, md, md.lightened(0.12))
	var top := _iso(c, tw, 0, 0, 0.06)
	for i in 20:
		var a0 := float(i) * 18.0
		ci.draw_polyline(_ellipse(top, drx * 0.94, drx * 0.47, a0, a0 + 12.0, 3), orange if i % 2 == 0 else Color(0.05, 0.05, 0.05, orange.a), 2.5)
	for i in 4:
		var q := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * deck_r * 0.82
		_glow(ci, _iso(c, tw, q.x, q.y, 0.07), tw * 0.014, orange, state)
	# The tube: from the deck up into the dark of the cave roof.
	var tr := 0.24
	var rx := tr * tw * 0.72
	var ry := rx * 0.5
	var z1 := 1.45
	# The lift car rests on the deck unless it has gone up to the surface.
	var car_down: bool = str(state.get("car", "down")) == "down"
	var up := float(state.get("lift", 0.0 if car_down else 1.0))
	_lift_tube(ci, c, tw, tr, 0.06, z1, true, lerpf(0.30, 0.78, up), state)
	# Where the tube meets the cave roof: a rough collar of rock.
	var roof := _iso(c, tw, 0, 0, z1)
	var rock := _fade(Color(0.30, 0.27, 0.25), state)
	var collar := PackedVector2Array()
	var lip := PackedVector2Array()
	for i in 18:
		var ang := float(i) / 18.0 * TAU
		var k := 1.9 + 0.35 * sin(ang * 3.0 + 1.0) + 0.2 * sin(ang * 7.0)
		collar.append(roof + Vector2(cos(ang) * rx * k, sin(ang) * ry * k * 1.1 - tw * 0.05))
		if sin(ang) >= -0.1:
			lip.append(collar[collar.size() - 1])
	# The roof rock: a hanging slab with a broken lower edge.
	var hang := PackedVector2Array(collar)
	ci.draw_colored_polygon(hang, rock.darkened(0.35))
	var under := PackedVector2Array()
	for p2 in lip:
		under.append(p2)
	for i in range(lip.size() - 1, -1, -1):
		under.append(lip[i] + Vector2(0, tw * (0.05 + 0.03 * sin(i * 2.3))))
	ci.draw_colored_polygon(under, rock.darkened(0.55))
	ci.draw_polyline(lip, rock.lightened(0.15), 1.5)
	# The tube's steel sleeve where it passes through the rock.
	var sleeve := _iso(c, tw, 0, 0, z1 - 0.04)
	ci.draw_colored_polygon(_ellipse(sleeve, rx * 1.18, ry * 1.18, 0, 180, 14), md)
	ci.draw_polyline(_ellipse(sleeve, rx * 1.18, ry * 1.18, 0, 180, 14), orange, 2.0)
	# A warning light where the lift arrives.
	_glow(ci, _iso(c, tw, 0, 0, 0.92) + Vector2(rx * 0.7, ry * 0.4), tw * 0.016, orange, state)
	for d in links:
		if d.x > 0 or d.y > 0:
			_iso_link(ci, c, tw, d, deck_r, state)
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not (d in links):
			_iso_port(ci, _iso(c, tw, d.x * deck_r * 0.95, d.y * deck_r * 0.95, 0.04), tw, state, true, d)


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


## A small six-wheeled work drone (a rover) seen from above, nose to the right.
## A broken one is missing a wheel and shows a red light.
static func _top_drone(ci: CanvasItem, p: Vector2, size: float, state: Dictionary, broken: bool = false) -> void:
	var md := _fade(METAL_DARK, state)
	var tyre := Color(0.08, 0.08, 0.09, md.a)
	var length := size * 1.5
	var width := size * 0.9
	for k in 3:
		for side in [-1.0, 1.0]:
			if broken and k == 2 and side > 0.0:
				continue
			var w := p + Vector2(-length * 0.32 + k * length * 0.32, side * width * 0.55)
			ci.draw_rect(Rect2(w - Vector2(size * 0.17, size * 0.09), Vector2(size * 0.34, size * 0.18)), tyre)
	var body := Rect2(p - Vector2(length * 0.5, width * 0.5), Vector2(length, width))
	ci.draw_rect(body, _fade(Color(0.95, 0.74, 0.18), state))
	ci.draw_rect(body, md, false, 1.0)
	ci.draw_rect(Rect2(body.end - Vector2(length * 0.30, width * 0.85), Vector2(length * 0.22, width * 0.7)), _fade(CYAN, state).darkened(0.35))
	ci.draw_rect(Rect2(body.position + Vector2(length * 0.12, width * 0.2), Vector2(length * 0.4, width * 0.6)), md.lightened(0.2))
	_glow(ci, Vector2(body.end.x, p.y), size * 0.08, _fade(WHITE, state), state)
	if broken:
		ci.draw_rect(Rect2(p + Vector2(length * 0.42, width * 0.9), Vector2(size * 0.34, size * 0.18)), tyre)
		_glow(ci, p, size * 0.12, _fade(Color(1.0, 0.3, 0.3), state), state)


## The same rover at an angle, sitting at height z; `size` is in tile units.
static func _iso_drone(ci: CanvasItem, c: Vector2, tw: float, z: float, size: float, state: Dictionary, broken: bool = false) -> void:
	var md := _fade(METAL_DARK, state)
	var tyre := Color(0.08, 0.08, 0.09, md.a)
	var hl := size * 0.75
	var hw := size * 0.45
	var wr := size * 0.22
	var wheel_z := z + wr
	# Far-side wheels, the body, then near-side wheels.
	for k in 3:
		var u := -hl * 0.65 + k * hl * 0.65
		ci.draw_colored_polygon(_ellipse(_iso(c, tw, u, -hw, wheel_z), tw * wr * 0.75, tw * wr * 0.75), tyre)
	var yel := _fade(Color(0.95, 0.74, 0.18), state)
	_box(ci, c, tw, -hl, -hw, hl, hw, size * 0.32, yel, Color(0, 0, 0, 0), z + wr * 0.9)
	_box(ci, c, tw, -hl * 0.6, -hw * 0.6, hl * 0.2, hw * 0.6, size * 0.14, md.lightened(0.2), Color(0, 0, 0, 0), z + wr * 0.9 + size * 0.32)
	var top := z + wr * 0.9 + size * 0.32
	ci.draw_colored_polygon(PackedVector2Array([_iso(c, tw, hl, -hw * 0.7, top - size * 0.04), _iso(c, tw, hl, hw * 0.7, top - size * 0.04), _iso(c, tw, hl, hw * 0.7, top - size * 0.18), _iso(c, tw, hl, -hw * 0.7, top - size * 0.18)]), _fade(CYAN, state).darkened(0.35))
	for k in 3:
		if broken and k == 2:
			continue
		var u := -hl * 0.65 + k * hl * 0.65
		var wp := _iso(c, tw, u, hw, wheel_z)
		ci.draw_colored_polygon(_ellipse(wp, tw * wr * 0.75, tw * wr * 0.75), tyre)
		ci.draw_colored_polygon(_ellipse(wp, tw * wr * 0.3, tw * wr * 0.3), md.lightened(0.3))
	_glow(ci, _iso(c, tw, hl, 0, top - size * 0.1), tw * size * 0.12, _fade(WHITE, state), state)
	if broken:
		ci.draw_colored_polygon(_ellipse(_iso(c, tw, hl * 1.4, hw * 1.6, z + 0.005), tw * wr * 0.75, tw * wr * 0.35), tyre)
		_glow(ci, _iso(c, tw, 0, 0, top + size * 0.16), tw * size * 0.15, _fade(Color(1.0, 0.3, 0.3), state), state)


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
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links), d)
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
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.03), tw, state, true, d)


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
		_top_port(ci, c + Vector2(d) * rad * 1.0, s, state, not (d in links), d)
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
			_iso_port(ci, _iso(c, tw, d.x * r * 1.0, d.y * r * 1.0, 0.03), tw, state, true, d)
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
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links), d)
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
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.03), tw, state, true, d)
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
			_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links), d)


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
		_iso_port(ci, _iso(c, tw, r * 0.98, 0, 0.12), tw, state, true, Vector2i(1, 0))


## The Spin Launcher as a spin launcher, seen from above: a big sealed vacuum
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
		_top_port(ci, c + Vector2(d) * rad * 0.97, s, state, not (d in links), d)
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
			_iso_port(ci, _iso(c, tw, d.x * r * 0.98, d.y * r * 0.98, 0.08), tw, state, true, d)


static func _iso_sphere(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(p, rad, col.darkened(0.25))
	ci.draw_circle(p - Vector2(rad * 0.25, rad * 0.25), rad * 0.6, col)


## A Tunnel tile at an angle, in the same shapes as the top-down one.
static func _iso_tunnel(ci: CanvasItem, c: Vector2, tw: float, links: Array, state: Dictionary) -> void:
	var m := _fade(METAL, state)
	var a := _fade(ORANGE, state)
	var stripe := Color(a.r, a.g, a.b, 0.9 * a.a)
	var rr := 0.07
	var z := 0.09
	var shape := tunnel_shape(links)
	if shape == "none":
		_iso_tube(ci, c, tw, 0, -0.22, 0.22, rr, z, m, stripe)
		_iso_cap(ci, _iso(c, tw, 0.22, 0, z), tw, state)
		return
	if shape == "straight":
		var d: Vector2i = links[0]
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, -0.5, 0.5, rr, z, m, stripe)
		return
	var back: Array = []
	var front: Array = []
	for d in links:
		(back if (d.x < 0 or d.y < 0) else front).append(d)
	var hub := shape == "tee" or shape == "cross"
	# At a junction the tubes stop at the hub's wall; elsewhere they meet in the middle.
	var start := HUB_R if hub else 0.0
	for d in back:
		var sg := float(d.x if d.x != 0 else d.y)
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, sg * start, sg * 0.5, rr, z, m, stripe)
	if hub:
		# A junction hub: a domed drum with an orange band.
		_hub(ci, c, tw, m, a, state)
	for d in front:
		var sg := float(d.x if d.x != 0 else d.y)
		_iso_tube(ci, c, tw, 0 if d.x != 0 else 1, sg * start, sg * 0.5, rr, z, m, stripe)
		if hub:
			_flange(ci, c, tw, 0 if d.x != 0 else 1, sg * (start + 0.015), rr, z, m)
	if shape == "end":
		_iso_cap(ci, _iso(c, tw, 0, 0, z), tw, state)
	elif shape == "corner":
		_iso_ball(ci, _iso(c, tw, 0, 0, z), tw * rr * 1.25, m)
		ci.draw_arc(_iso(c, tw, 0, 0, z), tw * rr * 1.25, deg_to_rad(200), deg_to_rad(330), 10, stripe, maxf(1.5, tw * 0.012))


## A tunnel junction: a short drum with a domed lid, an orange band and a light.
const HUB_R := 0.16


static func _hub(ci: CanvasItem, c: Vector2, tw: float, m: Color, a: Color, state: Dictionary) -> void:
	var r := HUB_R
	var hgt := 0.27
	_cyl(ci, c, tw, 0, 0, r, hgt, m, m.lightened(0.1))
	var base := _iso(c, tw, 0, 0, 0.0)
	var rx := r * tw * 0.72
	# Shade the drum's right side so it reads as round.
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(rx * 0.4, rx * 0.46), base + Vector2(rx, 0), base + Vector2(rx, -hgt * tw), base + Vector2(rx * 0.4, rx * 0.46 - hgt * tw)]), m.darkened(0.25))
	ci.draw_polyline(_ellipse(_iso(c, tw, 0, 0, 0.09), rx, rx * 0.5, 0, 180, 16), a, maxf(1.5, tw * 0.014))
	var top := _iso(c, tw, 0, 0, hgt)
	var lid := _ellipse(top, rx, rx * 0.5, 0, 180, 14)
	lid.append_array(_ellipse(top, rx, tw * 0.06, 180, 360, 14))
	ci.draw_colored_polygon(lid, m.lightened(0.18))
	ci.draw_arc(top - Vector2(rx * 0.3, tw * 0.035), rx * 0.35, deg_to_rad(200), deg_to_rad(260), 6, Color(1, 1, 1, 0.5 * m.a), 1.5)
	_glow(ci, top - Vector2(0, tw * 0.06), tw * 0.012, a, state)


## A rounded ball joint (the elbow of a corner), shaded like the tubes.
static func _iso_ball(ci: CanvasItem, p: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(p, rad, col.darkened(0.45))
	ci.draw_circle(p - Vector2(rad * 0.08, rad * 0.10), rad * 0.88, col.darkened(0.1))
	ci.draw_circle(p - Vector2(rad * 0.2, rad * 0.25), rad * 0.62, col.lightened(0.12))
	ci.draw_circle(p - Vector2(rad * 0.35, rad * 0.4), rad * 0.22, col.lightened(0.45))


## The closed end of a tube at an angle: a rounded cap with an orange light.
static func _iso_cap(ci: CanvasItem, p: Vector2, tw: float, state: Dictionary) -> void:
	_iso_ball(ci, p, tw * 0.085, _fade(METAL, state))
	_glow(ci, p - Vector2(0, tw * 0.02), tw * 0.018, _fade(ORANGE, state), state)


# ============================================================ terrain

const TERRAIN := {
	"regolith": Color(0.40, 0.35, 0.31), "ice": Color(0.66, 0.79, 0.88), "vent": Color(0.32, 0.25, 0.23),
	"seam": Color(0.36, 0.33, 0.30), "ridge": Color(0.17, 0.17, 0.19), "deepice": Color(0.82, 0.90, 0.97),
	"scorch": Color(0.56, 0.31, 0.17), "rock": Color(0.24, 0.21, 0.20), "cavern": Color(0.36, 0.31, 0.27),
	"vein": Color(0.24, 0.21, 0.20), "aquifer": Color(0.20, 0.30, 0.40), "deepvent": Color(0.30, 0.18, 0.15),
	"bedrock": Color(0.09, 0.08, 0.09),
}


## The animation clock in seconds, set by the map before it draws (0 when
## animations are off, and on the sprite sheets, so pictures stay still).
static var anim_t := 0.0


## Puffs of steam or smoke rising from p and fading. Still when animations are off.
static func _steam(ci: CanvasItem, p: Vector2, tw: float, size: float, n: int = 3, alpha: float = 0.35) -> void:
	for k in n:
		var f := float(k) / n
		if anim_t > 0.0:
			f = fmod(anim_t * 0.35 + float(k) / n + p.x * 0.001, 1.0)
		var rise := p - Vector2(-f * tw * 0.06 * size, tw * (0.04 + f * 0.22) * size)
		ci.draw_circle(rise, tw * (0.025 + f * 0.04) * size, Color(0.95, 0.96, 1.0, alpha * (1.0 - f)))


## The planet whose ground is being drawn: its colours replace TERRAIN's, and
## it may add a ground detail (grass, embers, frost and so on). Set by the map
## and the probe picture before they draw; "" means the default look.
static var ground_planet := ""
static var ground := {}
static var ground_detail := ""


static func set_planet(planet_id: String) -> void:
	if planet_id == ground_planet:
		return
	ground_planet = planet_id
	ground = {}
	ground_detail = ""
	if planet_id == "":
		return
	var look: Dictionary = GameData.planet(planet_id).get("look", {})
	var g: Dictionary = look.get("ground", {})
	for k in g:
		var a: Array = g[k]
		ground[k] = Color(float(a[0]), float(a[1]), float(a[2]))
	ground_detail = str(look.get("detail", ""))


## A planet's sky colour (behind the map), or the default.
static func sky(planet_id: String) -> Color:
	var a: Array = GameData.planet(planet_id).get("look", {}).get("sky", [])
	return Color(float(a[0]), float(a[1]), float(a[2])) if a.size() == 3 else Color(0.05, 0.06, 0.08)


## The colour of a kind of ground on the current planet.
static func tcol(t: String) -> Color:
	return ground.get(t, TERRAIN.get(t, Color.MAGENTA))


## The current planet's ground detail on a plain tile, varied by position.
static func _ground_detail(ci: CanvasItem, c: Vector2, tw: float) -> void:
	if ground_detail == "":
		return
	var h := (int(c.x * 3.0) * 73856093) ^ (int(c.y * 5.0) * 19349663)
	for k in 3:
		var q := Vector2(float((h >> (k * 4)) & 15) / 15.0 - 0.5, float((h >> (k * 4 + 2)) & 15) / 15.0 - 0.5) * 0.7
		var p := _iso(c, tw, q.x, q.y)
		match ground_detail:
			"grass":
				for j in 3:
					ci.draw_line(p + Vector2((j - 1) * tw * 0.012, 0), p + Vector2((j - 1) * tw * 0.02, -tw * 0.035), Color(0.45, 0.62, 0.35), maxf(1.0, tw * 0.008))
			"embers":
				ci.draw_circle(p, maxf(1.0, tw * 0.012), Color(1.0, 0.45, 0.15, 0.8))
				if k == 0:
					ci.draw_line(p + Vector2(-tw * 0.08, tw * 0.01), p + Vector2(tw * 0.06, -tw * 0.02), Color(0.10, 0.08, 0.08), maxf(1.0, tw * 0.01))
			"cracks":
				ci.draw_polyline(PackedVector2Array([p + Vector2(-tw * 0.08, 0), p + Vector2(-tw * 0.02, -tw * 0.015), p + Vector2(tw * 0.03, tw * 0.01), p + Vector2(tw * 0.09, -tw * 0.01)]), Color(0.55, 0.70, 0.85, 0.8), 1.0)
			"frost":
				ci.draw_circle(p, maxf(1.0, tw * 0.01), Color(0.85, 0.92, 1.0, 0.55))
			"shards":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-tw * 0.03, 0), p + Vector2(0, -tw * 0.03), p + Vector2(tw * 0.025, tw * 0.005)]), Color(0.60, 0.58, 0.60))
			"dunes":
				if k < 2:
					ci.draw_arc(p, tw * 0.07, deg_to_rad(200), deg_to_rad(340), 6, Color(0.70, 0.50, 0.34, 0.8), 1.0)


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
	ci.draw_rect(r, tcol(t))
	if t == "ridge" or t == "bedrock":
		ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.12, r.size.y * 0.85), r.get_center() + Vector2(0, -r.size.y * 0.32), r.position + Vector2(r.size.x * 0.88, r.size.y * 0.85)]), Color(0.30, 0.30, 0.33))
	_terrain_marks(ci, t, r.get_center(), r.size.x)


static func terrain_iso(ci: CanvasItem, t: String, c: Vector2, tw: float, raised: bool = true) -> void:
	var col: Color = tcol(t)
	var diamond := PackedVector2Array([_iso(c, tw, -0.5, -0.5), _iso(c, tw, 0.5, -0.5), _iso(c, tw, 0.5, 0.5), _iso(c, tw, -0.5, 0.5)])
	# Solid rock in the Deep stands up as rough blocks (you dig into them to
	# build); open cavern is the floor between them. Built-on rock is dug out.
	if raised and (t == "rock" or t == "vein"):
		ci.draw_colored_polygon(diamond, TERRAIN["cavern"].darkened(0.35))
		var rh := (int(c.x * 7.0) ^ int(c.y * 13.0)) & 7
		var hgt := 0.10 + 0.03 * float(rh & 3) / 3.0
		var stone := col.lightened(0.04 + 0.025 * float(rh))
		_box(ci, c, tw, -0.5, -0.5, 0.5, 0.5, hgt, stone, stone.lightened(0.08))
		var top := PackedVector2Array([_iso(c, tw, -0.5, -0.5, hgt), _iso(c, tw, 0.5, -0.5, hgt), _iso(c, tw, 0.5, 0.5, hgt), _iso(c, tw, -0.5, 0.5, hgt)])
		ci.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), col.darkened(0.35), 1.0)
		ci.draw_line(_iso(c, tw, -0.3, -0.1, hgt), _iso(c, tw, 0.1, 0.2, hgt), col.darkened(0.25), 1.0)
		if t == "vein":
			var glow := Color(0.30, 0.85, 0.80)
			ci.draw_line(_iso(c, tw, -0.35, 0.1, hgt), _iso(c, tw, 0.3, -0.15, hgt), glow, maxf(2.0, tw * 0.025))
			ci.draw_line(_iso(c, tw, 0.5, -0.3, hgt * 0.4), _iso(c, tw, 0.5, 0.2, hgt * 0.7), glow, maxf(1.5, tw * 0.015))
			ci.draw_line(_iso(c, tw, -0.2, 0.5, hgt * 0.3), _iso(c, tw, 0.25, 0.5, hgt * 0.6), glow, maxf(1.5, tw * 0.015))
		return
	if t == "rock":
		col = TERRAIN["cavern"].darkened(0.1)
	ci.draw_colored_polygon(diamond, col)
	ci.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0, 0, 0, 0.18), 1.0)
	if t == "regolith":
		_ground_detail(ci, c, tw)
	if t == "ridge" or t == "bedrock":
		var rcol := Color(0.14, 0.13, 0.14) if t == "bedrock" else (tcol("ridge").lightened(0.35) if ground.has("ridge") else Color(0.30, 0.30, 0.33))
		_box(ci, c, tw, -0.30, -0.30, 0.30, 0.30, 0.22, rcol)
	if t == "cavern":
		# Pebbles on the cave floor.
		var hsh := int(c.x * 3.0) ^ int(c.y * 5.0)
		for k in 3:
			var q := Vector2(float((hsh >> (k * 3)) & 7) / 7.0 - 0.5, float((hsh >> (k * 3 + 1)) & 7) / 7.0 - 0.5) * 0.7
			ci.draw_circle(_iso(c, tw, q.x, q.y), maxf(1.0, tw * 0.012), col.darkened(0.3))
		return
	if t == "aquifer":
		ci.draw_colored_polygon(_ellipse(c, tw * 0.28, tw * 0.13), Color(0.25, 0.50, 0.85, 0.9))
		ci.draw_arc(c - Vector2(tw * 0.05, tw * 0.02), tw * 0.10, deg_to_rad(200), deg_to_rad(300), 6, Color(1, 1, 1, 0.4), 1.5)
		return
	if t == "deepvent":
		ci.draw_line(c + Vector2(-tw * 0.22, tw * 0.03), c + Vector2(tw * 0.2, -tw * 0.04), Color(1.0, 0.45, 0.15), maxf(2.0, tw * 0.03))
		ci.draw_circle(c, tw * 0.07, Color(1.0, 0.55, 0.20, 0.9))
		ci.draw_circle(c, tw * 0.035, Color(1.0, 0.9, 0.5))
		return
	if t == "vein":
		ci.draw_line(_iso(c, tw, -0.35, 0.1), _iso(c, tw, 0.3, -0.15), Color(0.30, 0.85, 0.80), maxf(2.0, tw * 0.025))
		return
	_terrain_marks(ci, t, c, tw * 0.6)
