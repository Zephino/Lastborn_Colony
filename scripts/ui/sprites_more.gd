## Sprites for the buildings added in 00.01.26 (Fusion Core, Beam Catcher,
## Reclaimer, Fab Shop, Drone Bay, Radio Station, Rescue Station, Academy,
## Hazard Lab, Garden Cavern, Lounge), and for drones and satellites.
## sprites.gd draws the dome, tunnels and ports and calls in here for the
## fittings: *_pre before the dome (things behind it), *_post after (things on
## or in front of it). Same coordinate rules as sprites.gd.
extends RefCounted

const S = preload("res://scripts/ui/sprites.gd")

const FUSION := Color(0.55, 0.85, 1.0)
const RESCUE := Color(1.0, 0.35, 0.25)
const LIME := Color(0.60, 1.0, 0.30)
const BLUE := Color(0.45, 0.60, 1.0)
const STEAM := Color(0.92, 0.94, 1.0)


static func _f(c: Color, state: Dictionary) -> Color:
	return S._fade(c, state)


# ============================================================ top-down

static func top_pre(ci: CanvasItem, type: String, c: Vector2, s: float, rad: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	match type:
		"catcher":
			# The target ring the beam is aimed at, and the capacitor coils.
			for k in 4:
				ci.draw_circle(c, s * (0.46 - k * 0.10), md.darkened(0.2) if k % 2 == 0 else _f(Color(S.GOLD.r, S.GOLD.g, S.GOLD.b, 0.55), state))
			for p in [Vector2(-0.30, -0.30), Vector2(0.32, -0.30), Vector2(-0.30, 0.32)]:
				var q: Vector2 = c + p * s
				ci.draw_circle(q, s * 0.055, md)
				ci.draw_circle(q, s * 0.04, m.lightened(0.1))
				S._glow(ci, q, s * 0.018, _f(S.GOLD, state), state)
		"fab":
			# A factory hall at the back with a sawtooth roof and a chimney, and parts crates at the front-left.
			var hall := Rect2(c + Vector2(-s * 0.49, -s * 0.49), Vector2(s * 0.40, s * 0.24))
			ci.draw_rect(hall, md)
			for k in 4:
				var x := hall.position.x + s * 0.02 + k * s * 0.095
				ci.draw_rect(Rect2(Vector2(x, hall.position.y + s * 0.02), Vector2(s * 0.05, hall.size.y - s * 0.04)), _f(Color(0.55, 0.56, 0.58), state))
				ci.draw_rect(Rect2(Vector2(x + s * 0.05, hall.position.y + s * 0.02), Vector2(s * 0.04, hall.size.y - s * 0.04)), _f(S.GLASS, state).lightened(0.3))
			var chimney := c + Vector2(s * 0.38, -s * 0.38)
			ci.draw_circle(chimney, s * 0.06, md)
			ci.draw_circle(chimney, s * 0.035, Color(0.05, 0.05, 0.05, m.a))
			if S._lit(state):
				ci.draw_circle(chimney + Vector2(s * 0.04, -s * 0.04), s * 0.05, Color(0.3, 0.3, 0.32, 0.4))
			for k in 3:
				var box := Rect2(c + Vector2(-s * (0.47 - (k % 2) * 0.12), s * (0.28 + (k / 2) * 0.1)), Vector2(s * 0.11, s * 0.09))
				ci.draw_rect(box, _f(Color(0.30, 0.42, 0.58), state))
				ci.draw_rect(box, md, false, 1.0)
		"dronebay":
			# A garage at the front-left with a roll-up door, a driveway, and a charging rack at the back.
			var garage := Rect2(c + Vector2(-s * 0.49, s * 0.16), Vector2(s * 0.30, s * 0.26))
			ci.draw_rect(garage, _f(Color(0.50, 0.52, 0.56), state))
			for k in 4:
				ci.draw_line(Vector2(garage.position.x, garage.position.y + s * 0.03 + k * s * 0.06), Vector2(garage.end.x, garage.position.y + s * 0.03 + k * s * 0.06), _f(Color(0.40, 0.42, 0.46), state), 1.5)
			ci.draw_rect(Rect2(Vector2(garage.position.x + s * 0.03, garage.end.y - s * 0.02), Vector2(garage.size.x - s * 0.06, s * 0.03)), _f(S.HAZARD, state))
			ci.draw_rect(Rect2(Vector2(garage.position.x + s * 0.03, garage.end.y + s * 0.01), Vector2(garage.size.x - s * 0.06, s * 0.07)), _f(Color(0.30, 0.30, 0.32), state))
			var rack := Rect2(c + Vector2(-s * 0.48, -s * 0.46), Vector2(s * 0.30, s * 0.12))
			ci.draw_rect(rack, md)
			for k in 3:
				S._glow(ci, rack.position + Vector2(s * (0.05 + k * 0.10), s * 0.06), s * 0.015, _f(S.GREEN, state), state)
			# A one-bay parking lot at the back-right, with a drone parked in it.
			var lot := Rect2(c + Vector2(s * 0.20, -s * 0.49), Vector2(s * 0.29, s * 0.29))
			ci.draw_rect(lot, _f(Color(0.24, 0.24, 0.26), state))
			var paint := _f(Color(0.92, 0.92, 0.88), state)
			ci.draw_polyline(PackedVector2Array([lot.position + Vector2(s * 0.04, lot.size.y - s * 0.03), lot.position + Vector2(s * 0.04, s * 0.04), lot.position + Vector2(lot.size.x - s * 0.04, s * 0.04), lot.position + Vector2(lot.size.x - s * 0.04, lot.size.y - s * 0.03)]), paint, 1.5)
			S._top_drone(ci, lot.get_center() + Vector2(0, -s * 0.01), s * 0.11, state)
		"academy":
			# A fenced playground at the front-left (slide and swings), a yellow school bus at the back-right, and a flagpole.
			var yard := Rect2(c + Vector2(-s * 0.49, s * 0.20), Vector2(s * 0.29, s * 0.29))
			ci.draw_rect(yard, _f(Color(0.36, 0.55, 0.32), state))
			ci.draw_rect(yard, _f(S.WHITE, state), false, 1.5)
			ci.draw_line(yard.position + Vector2(s * 0.04, s * 0.06), yard.position + Vector2(s * 0.22, s * 0.06), _f(RESCUE, state), 2.0)
			for k in 2:
				ci.draw_rect(Rect2(yard.position + Vector2(s * (0.08 + k * 0.08), s * 0.08), Vector2(s * 0.03, s * 0.04)), md)
			S._rot_rect(ci, yard.position + Vector2(s * 0.15, s * 0.20), Vector2(1, 0.6), s * 0.17, s * 0.045, _f(S.CYAN, state))
			ci.draw_circle(yard.position + Vector2(s * 0.06, s * 0.22), s * 0.035, _f(Color(0.85, 0.75, 0.50), state))
			S._rot_rect(ci, c + Vector2(s * 0.32, -s * 0.41), Vector2(1, 0), s * 0.30, s * 0.10, _f(Color(0.98, 0.78, 0.15), state))
			for k in 4:
				ci.draw_rect(Rect2(c + Vector2(s * (0.20 + k * 0.065), -s * 0.44), Vector2(s * 0.04, s * 0.03)), _f(S.GLASS, state).darkened(0.3))
			ci.draw_circle(c + Vector2(s * 0.16, s * 0.47), s * 0.02, md)
			ci.draw_rect(Rect2(c + Vector2(s * 0.16, s * 0.43), Vector2(s * 0.08, s * 0.045)), _f(BLUE, state))
		"hazlab":
			# A thick blast wall all round, with hazard stripes.
			ci.draw_circle(c, rad * 1.45, _f(Color(0.42, 0.42, 0.40), state))
			ci.draw_circle(c, rad * 1.25, _f(Color(0.30, 0.30, 0.29), state))
			for i in 20:
				var a0 := i * TAU / 20.0
				ci.draw_arc(c, rad * 1.35, a0, a0 + TAU / 40.0, 4, _f(S.HAZARD, state) if i % 2 == 0 else Color(0.05, 0.05, 0.05, m.a), maxf(2.0, s * 0.03))

static func top_post(ci: CanvasItem, type: String, c: Vector2, s: float, rad: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	match type:
		"catcher":
			# The funnel lens seen from above, glowing where the beam lands.
			ci.draw_circle(c, rad * 1.3, md)
			ci.draw_circle(c, rad * 1.1, _f(S.GOLD, state))
			ci.draw_circle(c, rad * 0.55, Color(1.0, 0.97, 0.85, _f(S.GOLD, state).a) if S._lit(state) else md)
			S._glow(ci, c, s * 0.05, _f(S.GOLD, state), state)
		"fab":
			# Inside: a conveyor belt carrying parts between two yellow robot arms.
			ci.draw_rect(Rect2(c + Vector2(-rad * 0.7, -rad * 0.1), Vector2(rad * 1.4, rad * 0.2)), md)
			for k in 6:
				ci.draw_line(c + Vector2(-rad * 0.6 + k * rad * 0.24, -rad * 0.1), c + Vector2(-rad * 0.6 + k * rad * 0.24, rad * 0.1), m, 1.0)
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-rad * 0.5 + k * rad * 0.38, -rad * 0.06), Vector2(rad * 0.14, rad * 0.12)), _f(Color(0.30, 0.42, 0.58), state))
			for side in [-1.0, 1.0]:
				var foot: Vector2 = c + Vector2(side * rad * 0.25, -side * rad * 0.5)
				var elbow: Vector2 = c + Vector2(side * rad * 0.05, -side * rad * 0.35)
				var hand: Vector2 = c + Vector2(side * rad * 0.1, -side * rad * 0.1)
				ci.draw_polyline(PackedVector2Array([foot, elbow, hand]), _f(S.HAZARD, state), maxf(2.0, s * 0.03))
				ci.draw_circle(foot, s * 0.025, md)
				S._glow(ci, hand, s * 0.012, _f(S.AMBER, state), state)
		"dronebay":
			# Two drones docked inside.
			S._top_drone(ci, c + Vector2(0, -rad * 0.35), rad * 0.32, state)
			S._top_drone(ci, c + Vector2(0, rad * 0.35), rad * 0.32, state)
		"academy":
			# A brick roof with a ring of skylights, the bell tower in the middle, and the porch at the front-right.
			var brick := _f(Color(0.72, 0.36, 0.26), state)
			var trim := _f(Color(0.92, 0.88, 0.80), state)
			ci.draw_circle(c, rad * 0.82, brick)
			for k in 8:
				var dir := Vector2.from_angle(k * TAU / 8.0)
				ci.draw_line(c + dir * rad * 0.2, c + dir * rad * 0.82, brick.darkened(0.15), 1.0)
				S._rot_rect(ci, c + Vector2.from_angle(k * TAU / 8.0 + PI / 8.0) * rad * 0.55, Vector2.from_angle(k * TAU / 8.0 + PI / 8.0), rad * 0.16, rad * 0.10, _f(S.AMBER, state).lightened(0.2))
			ci.draw_arc(c, rad * 0.82, 0, TAU, 36, trim, 2.0)
			ci.draw_arc(c - Vector2(rad * 0.3, rad * 0.3), rad * 0.4, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.35 * brick.a), 2.0)
			# The bell tower from above: a red pyramid roof.
			var tw2 := rad * 0.22
			var red := _f(Color(0.80, 0.28, 0.22), state)
			for k in 4:
				var a0 := Vector2.from_angle(k * PI / 2.0 + PI / 4.0) * tw2 * 1.41
				var a1 := Vector2.from_angle((k + 1) * PI / 2.0 + PI / 4.0) * tw2 * 1.41
				ci.draw_colored_polygon(PackedVector2Array([c + a0, c + a1, c]), red.darkened(0.08 * k))
			S._glow(ci, c, s * 0.012, _f(S.GOLD, state), state)
			# The porch with its steps, at the front-right.
			var dd := Vector2(1, 1).normalized()
			S._rot_rect(ci, c + dd * rad * 0.98, dd, s * 0.10, s * 0.18, trim.darkened(0.1))
			S._rot_rect(ci, c + dd * rad * 0.92, dd, s * 0.06, s * 0.14, trim)
		"hazlab":
			# A glowing green containment sphere.
			S._glow(ci, c, rad * 0.30, _f(LIME, state), state)
			ci.draw_arc(c, rad * 0.4, 0, TAU, 20, md, 2.0)
			# Glowing waste barrels at the front-left, and a warning sign at the front-right.
			for k in 3:
				var bp := c + Vector2(-s * (0.40 - (k % 2) * 0.08), s * (0.36 + (k / 2) * 0.07))
				ci.draw_circle(bp, s * 0.035, _f(S.HAZARD, state).darkened(0.1))
				ci.draw_circle(bp, s * 0.02, _f(LIME, state))
			var sp := c + Vector2(s * 0.38, s * 0.38)
			ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -s * 0.06), sp + Vector2(s * 0.055, s * 0.04), sp + Vector2(-s * 0.055, s * 0.04)]), _f(S.HAZARD, state))
			ci.draw_line(sp + Vector2(0, -s * 0.025), sp + Vector2(0, s * 0.012), Color(0.05, 0.05, 0.05, m.a), 1.5)

## A small rescue rover seen from above.
static func _top_rover(ci: CanvasItem, p: Vector2, s: float, col: Color, state: Dictionary) -> void:
	var body := Rect2(p - Vector2(s * 0.09, s * 0.06), Vector2(s * 0.18, s * 0.12))
	for w in [body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]:
		ci.draw_circle(w, s * 0.025, Color(0.08, 0.08, 0.09, col.a))
	ci.draw_rect(body, col)
	ci.draw_rect(Rect2(body.position + Vector2(s * 0.02, s * 0.02), Vector2(s * 0.05, s * 0.08)), _f(S.CYAN, state).darkened(0.3))
	S._glow(ci, body.get_center() + Vector2(s * 0.03, 0), s * 0.015, _f(Color(0.4, 0.6, 1.0), state), state)


# ============================================================ angled

static func iso_pre(ci: CanvasItem, type: String, c: Vector2, tw: float, r: float, h: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	match type:

		"fab":
			# The factory hall behind, with a sawtooth roof of skylights, and a smoking chimney.
			var grey := _f(Color(0.55, 0.56, 0.58), state)
			S._box(ci, c, tw, -0.49, -0.49, -0.09, -0.25, 0.16, grey)
			for k in 4:
				var u0 := -0.49 + k * 0.10
				var tri := PackedVector2Array([S._iso(c, tw, u0, -0.25, 0.16), S._iso(c, tw, u0 + 0.10, -0.25, 0.16), S._iso(c, tw, u0 + 0.10, -0.25, 0.24)])
				ci.draw_colored_polygon(tri, grey.darkened(0.3))
				var glass := PackedVector2Array([S._iso(c, tw, u0 + 0.10, -0.49, 0.16), S._iso(c, tw, u0 + 0.10, -0.25, 0.16), S._iso(c, tw, u0 + 0.10, -0.25, 0.24), S._iso(c, tw, u0 + 0.10, -0.49, 0.24)])
				ci.draw_colored_polygon(glass, _f(S.GLASS, state).lightened(0.3))
				var slope := PackedVector2Array([S._iso(c, tw, u0, -0.49, 0.16), S._iso(c, tw, u0 + 0.10, -0.49, 0.24), S._iso(c, tw, u0 + 0.10, -0.25, 0.24), S._iso(c, tw, u0, -0.25, 0.16)])
				ci.draw_colored_polygon(slope, grey.lightened(0.1))
			S._cyl(ci, c, tw, 0.36, -0.38, 0.05, 0.50, md, Color(0.05, 0.05, 0.05, m.a))
			if S._lit(state):
				var top := S._iso(c, tw, 0.36, -0.38, 0.50)
				for k in 3:
					ci.draw_circle(top - Vector2(-k * tw * 0.03, tw * (0.05 + k * 0.05)), tw * (0.035 + k * 0.015), Color(0.3, 0.3, 0.32, 0.45 - k * 0.12))
		"dronebay":
			S._box(ci, c, tw, -0.48, -0.46, -0.18, -0.34, 0.14, md, md.lightened(0.15))
			for k in 3:
				S._glow(ci, S._iso(c, tw, -0.43 + k * 0.1, -0.34, 0.10), tw * 0.012, _f(S.GREEN, state), state)
			# A one-bay parking lot at the right, with a drone parked in it.
			var lot := PackedVector2Array([S._iso(c, tw, 0.20, -0.49, 0.005), S._iso(c, tw, 0.49, -0.49, 0.005), S._iso(c, tw, 0.49, -0.20, 0.005), S._iso(c, tw, 0.20, -0.20, 0.005)])
			ci.draw_colored_polygon(lot, _f(Color(0.24, 0.24, 0.26), state))
			var paint := _f(Color(0.92, 0.92, 0.88), state)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, 0.24, -0.23, 0.006), S._iso(c, tw, 0.24, -0.45, 0.006), S._iso(c, tw, 0.45, -0.45, 0.006), S._iso(c, tw, 0.45, -0.23, 0.006)]), paint, 1.5)
			S._iso_drone(ci, S._iso(c, tw, 0.345, -0.345) - c + c, tw, 0.0, 0.11, state)
		"academy":
			# A yellow school bus parked at the back-right.
			var bus := _f(Color(0.98, 0.78, 0.15), state)
			S._box(ci, c, tw, 0.18, -0.46, 0.48, -0.36, 0.12, bus, Color(0, 0, 0, 0), 0.02)
			for k in 4:
				var u := 0.21 + k * 0.065
				ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, u, -0.36, 0.08), S._iso(c, tw, u + 0.04, -0.36, 0.08), S._iso(c, tw, u + 0.04, -0.36, 0.12), S._iso(c, tw, u, -0.36, 0.12)]), _f(S.GLASS, state).darkened(0.3))
			for u in [0.24, 0.42]:
				ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, u, -0.36, 0.02), tw * 0.02, tw * 0.02), Color(0.08, 0.08, 0.09, bus.a))
		"hazlab":
			# The blast wall: back half first, so the dome sits inside it.
			_blast_wall(ci, c, tw, r, state, true)


static func iso_post(ci: CanvasItem, type: String, c: Vector2, tw: float, r: float, h: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	var apex := S._iso(c, tw, 0, 0, 0.05 + h)
	match type:
		"fab":
			# Inside: a conveyor with parts, and two yellow robot arms over it.
			var belt := PackedVector2Array([S._iso(c, tw, -0.22, -0.04, 0.07), S._iso(c, tw, 0.22, -0.04, 0.07), S._iso(c, tw, 0.22, 0.04, 0.07), S._iso(c, tw, -0.22, 0.04, 0.07)])
			ci.draw_colored_polygon(belt, md)
			for k in 3:
				var u := -0.16 + k * 0.13
				S._box(ci, c, tw, u, -0.03, u + 0.06, 0.03, 0.03, _f(Color(0.30, 0.42, 0.58), state), Color(0, 0, 0, 0), 0.07)
			for side in [-1.0, 1.0]:
				var foot := S._iso(c, tw, side * 0.08, -side * 0.14, 0.06)
				var elbow := S._iso(c, tw, side * 0.10, -side * 0.06, 0.17)
				var hand := S._iso(c, tw, side * 0.04, 0.0, 0.12)
				ci.draw_polyline(PackedVector2Array([foot, elbow, hand]), _f(S.HAZARD, state), tw * 0.015)
				S._glow(ci, hand, tw * 0.01, _f(S.AMBER, state), state)
			for k in 3:
				var u := -0.47 + (k % 2) * 0.12
				S._box(ci, c, tw, u, 0.28 + (k / 2) * 0.1, u + 0.1, 0.36 + (k / 2) * 0.1, 0.07, _f(Color(0.30, 0.42, 0.58), state), Color(0, 0, 0, 0), (k / 2) * 0.07)
		"dronebay":
			S._iso_drone(ci, S._iso(c, tw, -0.04, -0.04) - c + c, tw, 0.05, 0.11, state)
			# The garage: a box with a roll-up door, half open, a drone parked inside and a light above.
			var wall := _f(Color(0.50, 0.52, 0.56), state)
			var u0 := -0.49
			var u1 := -0.17
			var v0 := 0.14
			var v1 := 0.46
			var hgt := 0.20
			S._box(ci, c, tw, u0, v0, u1, v1, hgt, wall, wall.lightened(0.1))
			var door := PackedVector2Array([S._iso(c, tw, u0 + 0.04, v1, 0.0), S._iso(c, tw, u1 - 0.04, v1, 0.0), S._iso(c, tw, u1 - 0.04, v1, 0.16), S._iso(c, tw, u0 + 0.04, v1, 0.16)])
			ci.draw_colored_polygon(door, Color(0.06, 0.06, 0.07, wall.a))
			S._iso_drone(ci, S._iso(c, tw, (u0 + u1) * 0.5, v1 - 0.08) - c + c, tw, 0.0, 0.08, state)
			var roll := PackedVector2Array([S._iso(c, tw, u0 + 0.04, v1, 0.08), S._iso(c, tw, u1 - 0.04, v1, 0.08), S._iso(c, tw, u1 - 0.04, v1, 0.16), S._iso(c, tw, u0 + 0.04, v1, 0.16)])
			ci.draw_colored_polygon(roll, wall.lightened(0.15))
			for k in 4:
				var z := 0.09 + k * 0.02
				ci.draw_line(S._iso(c, tw, u0 + 0.04, v1, z), S._iso(c, tw, u1 - 0.04, v1, z), wall.darkened(0.2), 1.0)
			ci.draw_line(S._iso(c, tw, u0 + 0.04, v1, 0.0), S._iso(c, tw, u1 - 0.04, v1, 0.0), _f(S.HAZARD, state), 2.0)
			S._glow(ci, S._iso(c, tw, (u0 + u1) * 0.5, v1, 0.185), tw * 0.012, _f(S.AMBER, state), state)
		"academy":
			_school(ci, c, tw, r, h, state)
		"hazlab":
			var orb := S._iso(c, tw, 0, 0, 0.05 + h * 0.45)
			S._glow(ci, orb, tw * 0.06, _f(LIME, state), state)
			_blast_wall(ci, c, tw, r, state, false)
			S._glow(ci, apex - Vector2(0, tw * 0.02), tw * 0.02, _f(S.HAZARD, state), state)
			# Glowing waste barrels at the left.
			for k in 3:
				var u := -0.44 + (k % 2) * 0.08
				var v := 0.34 + (k / 2) * 0.07
				S._cyl(ci, c, tw, u, v, 0.035, 0.08, _f(S.HAZARD, state).darkened(0.1), _f(LIME, state))
				S._glow(ci, S._iso(c, tw, u, v, 0.08), tw * 0.012, _f(LIME, state), state)
			# A yellow warning sign on a post at the front.
			var foot := S._iso(c, tw, 0.40, 0.40)
			var sign := S._iso(c, tw, 0.40, 0.40, 0.22)
			ci.draw_line(foot, sign, md, tw * 0.01)
			ci.draw_colored_polygon(PackedVector2Array([sign + Vector2(0, -tw * 0.05), sign + Vector2(tw * 0.045, tw * 0.03), sign + Vector2(-tw * 0.045, tw * 0.03)]), _f(S.HAZARD, state))
			ci.draw_line(sign + Vector2(0, -tw * 0.02), sign + Vector2(0, tw * 0.008), Color(0.05, 0.05, 0.05, m.a), 2.0)
			ci.draw_circle(sign + Vector2(0, tw * 0.02), 1.2, Color(0.05, 0.05, 0.05, m.a))

## The Academy at an angle: a brick schoolhouse dome with two rows of lit
## classroom windows, a bell tower with a clock, a porch with columns, a
## flagpole and a fenced playground.
static func _school(ci: CanvasItem, c: Vector2, tw: float, r: float, h: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var brick := _f(Color(0.72, 0.36, 0.26), state)
	var trim := _f(Color(0.92, 0.88, 0.80), state)
	var lit := _f(Color(1.0, 0.82, 0.45), state)
	var base := S._iso(c, tw, 0, 0, 0.05)
	var rx := r * tw * 0.72
	var ry := rx * 0.5
	var hh := h * tw
	var shell := S._ellipse(base, rx, ry, 0, 180, 16)
	shell.append_array(S._ellipse(base, rx, hh, 180, 360, 20))
	ci.draw_colored_polygon(shell, brick)
	ci.draw_colored_polygon(S._ellipse(base - Vector2(rx * 0.35, hh * 0.55), rx * 0.40, hh * 0.38, 180, 300, 10), brick.lightened(0.10))
	# Two rows of classroom windows round the front, and a white trim band.
	for row in 2:
		var t: float = [0.22, 0.58][row]
		var ring_c := base - Vector2(0, hh * t)
		var k_r := sqrt(1.0 - t * t)
		for k in 7:
			var ang := deg_to_rad(15.0 + k * 25.0)
			var p := ring_c + Vector2(cos(ang) * rx * k_r, sin(ang) * ry * k_r)
			var w := tw * 0.022 * sin(ang) + tw * 0.006
			ci.draw_rect(Rect2(p - Vector2(w * 0.5, tw * 0.018), Vector2(w, tw * 0.03)), lit)
		ci.draw_polyline(S._ellipse(ring_c + Vector2(0, tw * 0.025), rx * k_r, ry * k_r, 5, 175, 16), trim, 1.5)
	ci.draw_polyline(S._ellipse(base, rx * 0.99, ry * 0.99, 0, 180, 16), trim, 2.5)
	# The bell tower: a cream tower, an open belfry with a gold bell, a clock and a red roof.
	var z0 := 0.05 + h * 0.75
	S._box(ci, c, tw, -0.07, -0.07, 0.07, 0.07, 0.20, trim, Color(0, 0, 0, 0), z0)
	for face in [[0.07, -0.05, 0.07, 0.05], [-0.05, 0.07, 0.05, 0.07]]:
		var open := PackedVector2Array([S._iso(c, tw, face[0], face[1], z0 + 0.12), S._iso(c, tw, face[2], face[3], z0 + 0.12), S._iso(c, tw, face[2], face[3], z0 + 0.18), S._iso(c, tw, face[0], face[1], z0 + 0.18)])
		ci.draw_colored_polygon(open, Color(0.10, 0.08, 0.06, trim.a))
	S._iso_sphere(ci, S._iso(c, tw, 0.07, 0.07, z0 + 0.14), tw * 0.016, _f(S.GOLD, state))
	var clock := S._iso(c, tw, 0.07, 0.0, z0 + 0.06)
	ci.draw_colored_polygon(S._ellipse(clock, tw * 0.022, tw * 0.028), _f(S.WHITE, state))
	ci.draw_line(clock, clock - Vector2(0, tw * 0.018), md, 1.0)
	ci.draw_line(clock, clock + Vector2(tw * 0.012, tw * 0.004), md, 1.0)
	var red := _f(Color(0.80, 0.28, 0.22), state)
	var peak := S._iso(c, tw, 0, 0, z0 + 0.32)
	var e := [S._iso(c, tw, -0.085, -0.085, z0 + 0.20), S._iso(c, tw, 0.085, -0.085, z0 + 0.20), S._iso(c, tw, 0.085, 0.085, z0 + 0.20), S._iso(c, tw, -0.085, 0.085, z0 + 0.20)]
	ci.draw_colored_polygon(PackedVector2Array([e[1], e[2], peak]), red.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([e[2], e[3], peak]), red)
	# The porch at the front: steps, four columns, a flat roof and a gable, with the door behind.
	var u0 := r * 0.52
	var u1 := r * 1.02
	S._box(ci, c, tw, u0, u0, u1, u1, 0.025, trim.darkened(0.12))
	var door := PackedVector2Array([S._iso(c, tw, u0, u0 + 0.05, 0.025), S._iso(c, tw, u0 + 0.06, u0, 0.025), S._iso(c, tw, u0 + 0.06, u0, 0.13), S._iso(c, tw, u0, u0 + 0.05, 0.13)])
	ci.draw_colored_polygon(door, _f(Color(0.45, 0.28, 0.18), state))
	for q in [Vector2(u1 - 0.015, u0 + 0.03), Vector2(u1 - 0.015, u1 - 0.015), Vector2(u0 + 0.03, u1 - 0.015)]:
		ci.draw_line(S._iso(c, tw, q.x, q.y, 0.025), S._iso(c, tw, q.x, q.y, 0.15), trim, tw * 0.014)
	S._box(ci, c, tw, u0, u0, u1, u1, 0.025, trim, Color(0, 0, 0, 0), 0.15)
	var g0 := S._iso(c, tw, u0, u1, 0.175)
	var g1 := S._iso(c, tw, u1, u1, 0.175)
	ci.draw_colored_polygon(PackedVector2Array([g0, g1, g0.lerp(g1, 0.5) - Vector2(0, tw * 0.05)]), trim.darkened(0.05))
	ci.draw_polyline(PackedVector2Array([g0, g0.lerp(g1, 0.5) - Vector2(0, tw * 0.05), g1]), brick, 1.5)
	# A flagpole by the porch.
	ci.draw_line(S._iso(c, tw, 0.16, 0.47), S._iso(c, tw, 0.16, 0.47, 0.46), md, tw * 0.01)
	ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.16, 0.47, 0.46), S._iso(c, tw, 0.28, 0.47, 0.46), S._iso(c, tw, 0.28, 0.47, 0.38), S._iso(c, tw, 0.16, 0.47, 0.38)]), _f(BLUE, state))
	# A fenced playground at the left: swings, a slide and a sandpit.
	var g := [S._iso(c, tw, -0.49, 0.20, 0.0), S._iso(c, tw, -0.20, 0.20, 0.0), S._iso(c, tw, -0.20, 0.49, 0.0), S._iso(c, tw, -0.49, 0.49, 0.0)]
	ci.draw_colored_polygon(PackedVector2Array(g), _f(Color(0.36, 0.55, 0.32), state))
	ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, -0.43, 0.42, 0.0), tw * 0.04, tw * 0.02), _f(Color(0.85, 0.75, 0.50), state))
	for u in [-0.45, -0.29]:
		ci.draw_line(S._iso(c, tw, u, 0.26), S._iso(c, tw, u, 0.26, 0.14), md, 1.5)
	ci.draw_line(S._iso(c, tw, -0.45, 0.26, 0.14), S._iso(c, tw, -0.29, 0.26, 0.14), _f(RESCUE, state), 2.0)
	for u in [-0.40, -0.34]:
		ci.draw_line(S._iso(c, tw, u, 0.26, 0.14), S._iso(c, tw, u, 0.26, 0.05), md, 1.0)
	ci.draw_line(S._iso(c, tw, -0.24, 0.38, 0.12), S._iso(c, tw, -0.38, 0.44, 0.01), _f(S.CYAN, state), tw * 0.02)
	ci.draw_line(S._iso(c, tw, -0.24, 0.38, 0.0), S._iso(c, tw, -0.24, 0.38, 0.12), md, 1.5)
	var fence := _f(S.WHITE, state)
	ci.draw_polyline(PackedVector2Array([g[1], g[2], g[3]]), fence, 1.0)
	ci.draw_polyline(PackedVector2Array([g[1] - Vector2(0, tw * 0.04), g[2] - Vector2(0, tw * 0.04), g[3] - Vector2(0, tw * 0.04)]), fence, 1.0)
	for k in 7:
		var t := float(k) / 6.0
		var p: Vector2 = g[2].lerp(g[3], t) if k < 4 else g[1].lerp(g[2], (t - 0.5) * 2.0)
		ci.draw_line(p, p - Vector2(0, tw * 0.04), fence, 1.0)


## A big hourglass-shaped cooling tower at (u, v), hgt tile-widths tall, with steam.
static func _cooling_tower(ci: CanvasItem, c: Vector2, tw: float, p: Vector2, hgt: float, state: Dictionary) -> void:
	var concrete := _f(Color(0.78, 0.78, 0.76), state)
	var base := S._iso(c, tw, p.x, p.y)
	var top := S._iso(c, tw, p.x, p.y, hgt)
	var waist := base.lerp(top, 0.65)
	var w0 := tw * 0.13
	var wm := tw * 0.08
	var wt := tw * 0.095
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		var y := base.lerp(top, t)
		# Wide at the foot, narrow at the waist, flaring a little at the top.
		var w := lerpf(w0, wm, t / 0.65) if t < 0.65 else lerpf(wm, wt, (t - 0.65) / 0.35)
		left.append(y + Vector2(-w, 0))
		right.append(y + Vector2(w, 0))
	right.reverse()
	var body := left.duplicate()
	body.append_array(right)
	ci.draw_colored_polygon(S._ellipse(base, w0, w0 * 0.5), concrete.darkened(0.35))
	ci.draw_colored_polygon(body, concrete)
	# Shade the right-hand side so it reads as round.
	var shade := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		var w := lerpf(w0, wm, t / 0.65) if t < 0.65 else lerpf(wm, wt, (t - 0.65) / 0.35)
		shade.append(base.lerp(top, t) + Vector2(w * 0.35, 0))
	var edge := right.duplicate()
	edge.reverse()
	shade.reverse()
	var side := edge.duplicate()
	side.append_array(shade)
	ci.draw_colored_polygon(side, concrete.darkened(0.18))
	ci.draw_colored_polygon(S._ellipse(base, w0, w0 * 0.5, 0, 180, 12) + PackedVector2Array([base + Vector2(-w0, 0)]), concrete.darkened(0.1))
	ci.draw_colored_polygon(S._ellipse(top, wt, wt * 0.45), concrete.darkened(0.3))
	ci.draw_colored_polygon(S._ellipse(top, wt * 0.8, wt * 0.35), Color(0.05, 0.05, 0.06, concrete.a))
	ci.draw_polyline(PackedVector2Array([waist + Vector2(-wm, 0), waist + Vector2(wm, 0)]), concrete.darkened(0.12), 1.0)
	if S._lit(state):
		for k in 4:
			ci.draw_circle(top - Vector2(-k * tw * 0.03, tw * (0.06 + k * 0.06)), tw * (0.07 + k * 0.025), Color(STEAM.r, STEAM.g, STEAM.b, 0.5 - k * 0.11))


## The Hazard Lab's ring wall with hazard stripes: back half or front half.
static func _blast_wall(ci: CanvasItem, c: Vector2, tw: float, r: float, state: Dictionary, back: bool) -> void:
	var concrete := _f(Color(0.42, 0.42, 0.40), state)
	var base := S._iso(c, tw, 0, 0, 0.0)
	var rx := r * tw * 0.72 * 1.4
	var ry := rx * 0.5
	var hgt := tw * 0.10
	var a0 := 180.0 if back else 0.0
	var a1 := 360.0 if back else 180.0
	var outer := S._ellipse(base, rx, ry, a0, a1, 18)
	var band := outer.duplicate()
	var top := S._ellipse(base - Vector2(0, hgt), rx, ry, a1, a0, 18)
	band.append_array(top)
	ci.draw_colored_polygon(band, concrete.darkened(0.3 if back else 0.15))
	var lip := S._ellipse(base - Vector2(0, hgt), rx, ry, a0, a1, 18)
	lip.append_array(S._ellipse(base - Vector2(0, hgt), rx * 0.86, ry * 0.86, a1, a0, 18))
	ci.draw_colored_polygon(lip, concrete)
	if not back:
		for i in 10:
			var s0 := a0 + i * 18.0
			ci.draw_polyline(S._ellipse(base - Vector2(0, hgt * 0.5), rx * 1.0, ry * 1.0, s0, s0 + 9.0, 3), _f(S.HAZARD, state), tw * 0.025)


static func _iso_rover(ci: CanvasItem, c: Vector2, tw: float, at: Vector2, col: Color, state: Dictionary) -> void:
	var tyre := Color(0.08, 0.08, 0.09, col.a)
	for w in [Vector2(-0.08, -0.06), Vector2(0.08, -0.06)]:
		ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, at.x + w.x, at.y + w.y, 0.03), tw * 0.025, tw * 0.025), tyre)
	S._box(ci, c, tw, at.x - 0.08, at.y - 0.05, at.x + 0.08, at.y + 0.05, 0.06, col, Color(0, 0, 0, 0), 0.03)
	for w in [Vector2(-0.08, 0.06), Vector2(0.08, 0.06)]:
		ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, at.x + w.x, at.y + w.y, 0.03), tw * 0.025, tw * 0.025), tyre)
	S._glow(ci, S._iso(c, tw, at.x, at.y, 0.11), tw * 0.012, _f(Color(0.4, 0.6, 1.0), state), state)


# ============================================================ the ship

## The colony's lander standing on the Landing Pad. A slim, slightly tapered
## body shaded round, with panel seams; a band of dark heat-shield tiles at its
## base over a cluster of three engine bells; landing legs with hydraulic
## pistons; thruster pods and grid fins; an orange stripe with the colony's
## emblem; a band of tinted cockpit windows under a pointed nose with an
## antenna; and a sealed boarding tube from its hatch down into one of the
## pad's airlocks.
static func draw_lander(ci: CanvasItem, c: Vector2, tw: float, state: Dictionary) -> void:
	var white := _f(Color(0.93, 0.94, 0.96), state)
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	var orange := _f(S.ORANGE, state)
	var tile := _f(Color(0.16, 0.17, 0.19), state)
	var pad_z := 0.05
	var body_z := pad_z + 0.10
	var body_h := 0.36
	var r0 := 0.105
	var r1 := 0.085
	# Coming down: "ship_drop" runs from 1 (high in the sky) to 0 (landed). The
	# ship is drawn higher up, with its engines firing and no boarding tube yet.
	var drop := float(state.get("ship_drop", 0.0))
	var pad := c
	if drop > 0.0:
		c = c - Vector2(0, tw * 2.4 * drop * drop)
		var flame := S._iso(c, tw, 0, 0, pad_z + 0.02)
		var length := tw * (0.18 + 0.10 * absf(sin(S.anim_t * 18.0)))
		ci.draw_colored_polygon(PackedVector2Array([flame + Vector2(-tw * 0.07, 0), flame + Vector2(tw * 0.07, 0), flame + Vector2(0, length)]), Color(1.0, 0.65, 0.20, 0.85))
		ci.draw_colored_polygon(PackedVector2Array([flame + Vector2(-tw * 0.035, 0), flame + Vector2(tw * 0.035, 0), flame + Vector2(0, length * 0.6)]), Color(1.0, 0.95, 0.75, 0.95))
		# Dust blown off the pad as it nears the ground.
		var near := 1.0 - drop
		for k in 6:
			var a := k * TAU / 6.0 + S.anim_t
			ci.draw_circle(pad + Vector2(cos(a) * tw * 0.25 * near, sin(a) * tw * 0.12 * near), tw * 0.04 * near, Color(0.82, 0.74, 0.62, 0.35 * near))
	# Scorch on the pad, and the engine glow under the skirt.
	ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, 0, 0, pad_z), tw * 0.17, tw * 0.085), Color(0.04, 0.04, 0.05, 0.4 * white.a))
	var legs := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for q in legs:
		if q.x + q.y < 0.0:
			_lander_leg(ci, c, tw, q.normalized(), pad_z, body_z, m, md)
	# A sealed boarding tube from the hatch down into the pad's airlock on the
	# side it docked at this time, so nobody has to walk outside. One docked at
	# a back airlock goes behind the ship, so it is drawn first.
	var back_dock := dock_dir(state)
	if back_dock.x + back_dock.y < 0 and drop <= 0.0:
		_boarding_tube(ci, c, tw, Vector3(back_dock.x * 0.09, back_dock.y * 0.09, body_z + 0.06), Vector3(back_dock.x * 0.37, back_dock.y * 0.37, 0.12), 0.035, state)
	# Three engine bells.
	for k in 3:
		var a := k * TAU / 3.0 + 0.5
		var eu := cos(a) * 0.045
		var ev := sin(a) * 0.045
		var top := S._iso(c, tw, eu, ev, body_z)
		var bot := S._iso(c, tw, eu, ev, pad_z + 0.025)
		var bell := PackedVector2Array([top + Vector2(-tw * 0.012, 0), top + Vector2(tw * 0.012, 0), bot + Vector2(tw * 0.026, 0), bot + Vector2(-tw * 0.026, 0)])
		ci.draw_colored_polygon(bell, md.lightened(0.1))
		ci.draw_colored_polygon(S._ellipse(bot, tw * 0.026, tw * 0.011), Color(0.05, 0.05, 0.06, white.a))
	S._glow(ci, S._iso(c, tw, 0, 0, pad_z + 0.02), tw * 0.03, _f(Color(0.55, 0.75, 1.0), state), state)
	# The body: a tapered round shell, shaded band by band so it reads as round.
	_lander_shell(ci, c, tw, body_z, body_z + body_h, r0, r1, white, state)
	# Heat-shield tiles round the base.
	_lander_shell(ci, c, tw, body_z, body_z + 0.07, r0 + 0.002, r0 - 0.003, tile, state)
	var base := S._iso(c, tw, 0, 0, body_z)
	for k in 2:
		var z := body_z + 0.025 + k * 0.025
		var rr := lerpf(r0, r1, (z - body_z) / body_h) + 0.002
		ci.draw_polyline(S._ellipse(S._iso(c, tw, 0, 0, z), rr * tw * 0.72, rr * tw * 0.36, 5, 175, 16), tile.lightened(0.15), 1.0)
	for k in 7:
		var ang := deg_to_rad(15.0 + k * 25.0)
		ci.draw_line(base + Vector2(cos(ang) * r0 * tw * 0.72, sin(ang) * r0 * tw * 0.36), base + Vector2(cos(ang) * r0 * tw * 0.72, sin(ang) * r0 * tw * 0.36 - 0.07 * tw), tile.lightened(0.15), 1.0)
	# Panel seams.
	for z in [0.16, 0.24, 0.31]:
		var zz: float = body_z + z
		var rr := lerpf(r0, r1, (zz - body_z) / body_h)
		ci.draw_polyline(S._ellipse(S._iso(c, tw, 0, 0, zz), rr * tw * 0.72, rr * tw * 0.36, 5, 175, 16), white.darkened(0.2), 1.0)
	# The orange stripe and the colony emblem.
	var sz := body_z + 0.11
	var srr := lerpf(r0, r1, 0.11 / body_h)
	ci.draw_polyline(S._ellipse(S._iso(c, tw, 0, 0, sz), srr * tw * 0.72, srr * tw * 0.36, 5, 175, 16), orange, maxf(3.0, tw * 0.02))
	var emblem := S._iso(c, tw, 0, 0, body_z + 0.20) + Vector2(srr * tw * 0.72 * 0.25, srr * tw * 0.36 * 0.95)
	ci.draw_circle(emblem, tw * 0.016, orange)
	ci.draw_circle(emblem, tw * 0.010, white)
	ci.draw_colored_polygon(PackedVector2Array([emblem + Vector2(0, -tw * 0.008), emblem + Vector2(tw * 0.006, tw * 0.005), emblem + Vector2(-tw * 0.006, tw * 0.005)]), orange)
	# Thruster pods on the sides, and grid fins near the top.
	for side in [-1.0, 1.0]:
		var at := S._iso(c, tw, 0, 0, body_z + 0.22) + Vector2(side * r1 * tw * 0.75, 0)
		ci.draw_rect(Rect2(at - Vector2(tw * 0.010, tw * 0.012), Vector2(tw * 0.020, tw * 0.024)), md)
		for k in 3:
			ci.draw_circle(at + Vector2(side * tw * 0.012, (k - 1) * tw * 0.008), maxf(1.0, tw * 0.004), m.lightened(0.3))
		var fin := S._iso(c, tw, 0, 0, body_z + body_h - 0.05) + Vector2(side * r1 * tw * 0.78, 0)
		var fr := Rect2(fin + Vector2(-tw * 0.004 if side > 0 else -tw * 0.036, -tw * 0.018), Vector2(tw * 0.04, tw * 0.036))
		ci.draw_rect(fr, md.lightened(0.2), false, 1.5)
		for g in 2:
			ci.draw_line(Vector2(fr.position.x + fr.size.x * (g + 1) / 3.0, fr.position.y), Vector2(fr.position.x + fr.size.x * (g + 1) / 3.0, fr.end.y), md.lightened(0.2), 1.0)
			ci.draw_line(Vector2(fr.position.x, fr.position.y + fr.size.y * (g + 1) / 3.0), Vector2(fr.end.x, fr.position.y + fr.size.y * (g + 1) / 3.0), md.lightened(0.2), 1.0)
	# The cockpit: a band of tinted windows near the top, catching the light.
	var wz := body_z + body_h - 0.06
	var wr := lerpf(r0, r1, (wz - body_z) / body_h)
	var wc := S._iso(c, tw, 0, 0, wz)
	var band := S._ellipse(wc, wr * tw * 0.73, wr * tw * 0.37, 20, 160, 14)
	band.append_array(S._ellipse(wc - Vector2(0, tw * 0.03), wr * tw * 0.73, wr * tw * 0.37, 160, 20, 14))
	ci.draw_colored_polygon(band, _f(Color(0.10, 0.16, 0.24), state))
	ci.draw_polyline(S._ellipse(wc - Vector2(0, tw * 0.022), wr * tw * 0.66, wr * tw * 0.33, 60, 110, 6), Color(0.75, 0.9, 1.0, 0.8 * white.a), 1.5)
	for k in 4:
		var ang := deg_to_rad(40.0 + k * 33.0)
		var x := wc + Vector2(cos(ang) * wr * tw * 0.73, sin(ang) * wr * tw * 0.37)
		ci.draw_line(x, x - Vector2(0, tw * 0.03), white.darkened(0.3), 1.0)
	# The pointed nose, its antenna and light.
	var top := S._iso(c, tw, 0, 0, body_z + body_h)
	var rx := r1 * tw * 0.72
	var tip := top - Vector2(0, tw * 0.16)
	var right_side := PackedVector2Array()
	for k in 9:
		var t := float(8 - k) / 8.0
		var w := rx * sqrt(maxf(0.0, 1.0 - t * t))
		right_side.append(top.lerp(tip, t) + Vector2(w, 0))
	var nose_poly := S._ellipse(top, rx, rx * 0.5, 0, 180, 14)
	for k in 9:
		var t := float(k) / 8.0
		nose_poly.append(top.lerp(tip, t) + Vector2(-rx * sqrt(maxf(0.0, 1.0 - t * t)), 0))
	nose_poly.append_array(right_side)
	ci.draw_colored_polygon(nose_poly, white)
	var shade_poly := PackedVector2Array()
	for k in 9:
		var t := float(k) / 8.0
		shade_poly.append(top.lerp(tip, t) + Vector2(rx * 0.35 * sqrt(maxf(0.0, 1.0 - t * t)), 0))
	shade_poly.append_array(right_side)
	ci.draw_colored_polygon(shade_poly, white.darkened(0.18))
	ci.draw_line(tip, tip - Vector2(0, tw * 0.05), md, 1.5)
	S._glow(ci, tip - Vector2(0, tw * 0.05), tw * 0.010, _f(Color(1.0, 0.3, 0.3), state), state)
	for q in legs:
		if q.x + q.y >= 0.0:
			_lander_leg(ci, c, tw, q.normalized(), pad_z, body_z, m, md)
	# The boarding tube, when it docks at one of the two front airlocks.
	var dock := dock_dir(state)
	if drop > 0.0:
		return
	if dock.x + dock.y > 0:
		_boarding_tube(ci, c, tw, Vector3(dock.x * 0.09, dock.y * 0.09, body_z + 0.06), Vector3(dock.x * 0.37, dock.y * 0.37, 0.12), 0.035, state)


## Which of the pad's airlocks the lander docks at: "ship_door" 0-3 in the state.
static func dock_dir(state: Dictionary) -> Vector2i:
	var sides := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	return sides[posmod(int(state.get("ship_door", 0)), 4)]


## A body of revolution between heights z0 and z1 (radius r0 at the bottom,
## r1 at the top), shaded in vertical bands so it reads as round.
static func _lander_shell(ci: CanvasItem, c: Vector2, tw: float, z0: float, z1: float, r0: float, r1: float, col: Color, state: Dictionary) -> void:
	var b := S._iso(c, tw, 0, 0, z0)
	var t := S._iso(c, tw, 0, 0, z1)
	var steps := 10
	for k in steps:
		var a0 := deg_to_rad(180.0 * k / steps)
		var a1 := deg_to_rad(180.0 * (k + 1) / steps)
		var light := clampf(cos((a0 + a1) * 0.5 - deg_to_rad(150.0)), -1.0, 1.0)
		var shade := col.lightened(light * 0.12) if light > 0.0 else col.darkened(-light * 0.30)
		var quad := PackedVector2Array([
			b + Vector2(cos(a0) * r0 * tw * 0.72, sin(a0) * r0 * tw * 0.36),
			b + Vector2(cos(a1) * r0 * tw * 0.72, sin(a1) * r0 * tw * 0.36),
			t + Vector2(cos(a1) * r1 * tw * 0.72, sin(a1) * r1 * tw * 0.36),
			t + Vector2(cos(a0) * r1 * tw * 0.72, sin(a0) * r1 * tw * 0.36)])
		ci.draw_colored_polygon(quad, shade)
	ci.draw_colored_polygon(S._ellipse(t, r1 * tw * 0.72, r1 * tw * 0.36), col.lightened(0.05))


## A round tube between two points (u, v, height), shaded, with ribs and an
## orange stripe, and a collar where it meets the ship.
static func _boarding_tube(ci: CanvasItem, c: Vector2, tw: float, a: Vector3, b: Vector3, rr: float, state: Dictionary) -> void:
	var m := _f(S.METAL, state)
	var orange := _f(S.ORANGE, state)
	var dir := Vector2(b.x - a.x, b.y - a.y).normalized()
	var across := S._iso(c, tw, -dir.y, dir.x) - S._iso(c, tw, 0, 0)
	if across.y < 0.0:
		across = -across
	var up := Vector2(0, -tw)
	var pa := S._iso(c, tw, a.x, a.y, a.z)
	var pb := S._iso(c, tw, b.x, b.y, b.z)
	var all := PackedVector2Array()
	for p in [pa, pb]:
		for k in 16:
			var th := k * TAU / 16.0
			all.append(p + (across * cos(th) + up * sin(th)) * rr)
	ci.draw_colored_polygon(Geometry2D.convex_hull(all), m.darkened(0.4))
	for k in 6:
		var t0 := deg_to_rad(150.0 - k * 36.0)
		var t1 := deg_to_rad(150.0 - (k + 1) * 36.0)
		var light := clampf(cos((t0 + t1) * 0.5) * 0.35 + sin((t0 + t1) * 0.5) * 0.75, -0.6, 1.0)
		var shade := m.lightened(light * 0.35) if light > 0.0 else m.darkened(-light * 0.5)
		var o0 := (across * cos(t0) + up * sin(t0)) * rr
		var o1 := (across * cos(t1) + up * sin(t1)) * rr
		ci.draw_colored_polygon(PackedVector2Array([pa + o0, pb + o0, pb + o1, pa + o1]), shade)
	var so := (across * cos(deg_to_rad(40.0)) + up * sin(deg_to_rad(40.0))) * rr
	ci.draw_line(pa + so, pb + so, orange, maxf(1.5, tw * rr * 0.2))
	for k in range(1, 5):
		var p := pa.lerp(pb, k / 5.0)
		var arc := PackedVector2Array()
		for j in 10:
			var th := deg_to_rad(-70.0 + j * 240.0 / 9.0)
			arc.append(p + (across * cos(th) + up * sin(th)) * rr)
		ci.draw_polyline(arc, m.darkened(0.35), 1.0)
	# The collar at the ship's hatch.
	var collar := PackedVector2Array()
	for k in 17:
		var th := k * TAU / 16.0
		collar.append(pa + (across * cos(th) + up * sin(th)) * rr * 1.3)
	ci.draw_polyline(collar, _f(S.AMBER, state), maxf(1.5, tw * 0.008))


static func _lander_leg(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, pad_z: float, body_z: float, col: Color, dark: Color) -> void:
	var hip := S._iso(c, tw, q.x * 0.09, q.y * 0.09, body_z + 0.06)
	var knee := S._iso(c, tw, q.x * 0.20, q.y * 0.20, pad_z + 0.09)
	var foot := S._iso(c, tw, q.x * 0.25, q.y * 0.25, pad_z)
	ci.draw_polyline(PackedVector2Array([hip, knee, foot]), dark, maxf(2.5, tw * 0.02))
	ci.draw_polyline(PackedVector2Array([hip, knee, foot]), col.lightened(0.15), maxf(1.0, tw * 0.008))
	# The hydraulic piston from low on the body out to the knee.
	var root := S._iso(c, tw, q.x * 0.10, q.y * 0.10, body_z - 0.02)
	ci.draw_line(root, root.lerp(knee, 0.55), dark, maxf(2.0, tw * 0.014))
	ci.draw_line(root.lerp(knee, 0.5), knee, col.lightened(0.35), maxf(1.0, tw * 0.007))
	ci.draw_colored_polygon(S._ellipse(foot, tw * 0.034, tw * 0.016), dark)
	ci.draw_colored_polygon(S._ellipse(foot - Vector2(0, tw * 0.004), tw * 0.026, tw * 0.011), col)


# ============================================================ units

## Draws a drone or satellite at an angle, centred on c, about tw pixels wide.
## Draws a drone, rover or satellite at c. along_v turns it to face along v
## instead of u (a left-right mirror in this view).
static func draw_unit(ci: CanvasItem, type: String, c: Vector2, tw: float, along_v: bool = false) -> void:
	S.swap_uv = along_v
	_unit_body(ci, type, c, tw)
	S.swap_uv = false


static func _unit_body(ci: CanvasItem, type: String, c: Vector2, tw: float) -> void:
	var st := {}
	var md := S.METAL_DARK
	var m := S.METAL
	var yel := S.HAZARD
	var tyre := Color(0.08, 0.08, 0.09)
	match type:
		"grader":
			# A bulldozer: treads, a yellow body and cab cage, a curved blade on
			# hydraulic arms at the front, ripper teeth at the back, and a beacon.
			_tread(ci, c, tw, -0.13, false)
			S._box(ci, c, tw, -0.17, -0.10, 0.11, 0.10, 0.08, yel, yel.lightened(0.1), 0.07)
			S._box(ci, c, tw, -0.17, -0.08, -0.12, 0.08, 0.05, md, Color(0, 0, 0, 0), 0.15)
			for k in 4:
				ci.draw_line(S._iso(c, tw, -0.15, -0.06 + k * 0.04, 0.15), S._iso(c, tw, -0.15, -0.06 + k * 0.04, 0.20), m.lightened(0.2), 1.5)
			# The cab: a cage of bars round tinted glass.
			S._box(ci, c, tw, -0.10, -0.07, 0.03, 0.07, 0.10, S.GLASS.darkened(0.3), S.GLASS.lightened(0.1), 0.15)
			for q in [Vector2(-0.10, 0.07), Vector2(0.03, 0.07), Vector2(0.03, -0.07)]:
				ci.draw_line(S._iso(c, tw, q.x, q.y, 0.15), S._iso(c, tw, q.x, q.y, 0.26), yel.darkened(0.3), 2.0)
			S._box(ci, c, tw, -0.11, -0.08, 0.04, 0.08, 0.015, yel.darkened(0.2), Color(0, 0, 0, 0), 0.25)
			S._glow(ci, S._iso(c, tw, -0.04, 0.0, 0.28), tw * 0.013, S.AMBER, st)
			_tread(ci, c, tw, 0.13, true)
			# Hydraulic arms and the blade.
			for v in [-0.09, 0.09]:
				ci.draw_line(S._iso(c, tw, 0.08, v, 0.10), S._iso(c, tw, 0.22, v, 0.06), md, tw * 0.018)
				ci.draw_line(S._iso(c, tw, 0.06, v, 0.13), S._iso(c, tw, 0.18, v, 0.09), m.lightened(0.3), tw * 0.008)
			var blade := PackedVector2Array()
			var blade_top := PackedVector2Array()
			for k in 9:
				var t := float(k) / 8.0
				var v := lerpf(-0.22, 0.22, t)
				var bow := 0.025 * sin(t * PI)
				blade.append(S._iso(c, tw, 0.24 - bow, v, 0.01))
				blade_top.append(S._iso(c, tw, 0.22 - bow, v, 0.13))
			var face := blade.duplicate()
			var back := blade_top.duplicate()
			back.reverse()
			face.append_array(back)
			ci.draw_colored_polygon(face, yel.darkened(0.15))
			ci.draw_polyline(blade, m.lightened(0.3), 2.0)
			ci.draw_polyline(blade_top, yel.lightened(0.2), 1.5)
			S._glow(ci, S._iso(c, tw, 0.11, 0.06, 0.12), tw * 0.01, S.WHITE, st)
		"borer":
			# A tracked digger with a big spiral drill on an arm, throwing rock chips.
			_tread(ci, c, tw, -0.13, false)
			var org := Color(0.95, 0.55, 0.15)
			S._box(ci, c, tw, -0.20, -0.10, 0.04, 0.10, 0.10, org, org.lightened(0.1), 0.07)
			S._box(ci, c, tw, -0.18, -0.08, -0.06, 0.08, 0.08, S.GLASS.darkened(0.3), S.GLASS.lightened(0.1), 0.17)
			S._box(ci, c, tw, -0.19, -0.09, -0.05, 0.09, 0.015, org.darkened(0.25), Color(0, 0, 0, 0), 0.25)
			S._glow(ci, S._iso(c, tw, -0.12, 0.0, 0.27), tw * 0.013, S.AMBER, st)
			# Hazard stripes along the body.
			for k in 5:
				var u := -0.18 + k * 0.045
				ci.draw_line(S._iso(c, tw, u, 0.10, 0.09), S._iso(c, tw, u + 0.02, 0.10, 0.15), md, 2.0)
			_tread(ci, c, tw, 0.13, true)
			# The arm and the drill motor.
			ci.draw_line(S._iso(c, tw, 0.02, 0.0, 0.16), S._iso(c, tw, 0.14, 0.0, 0.14), md, tw * 0.035)
			S._box(ci, c, tw, 0.10, -0.05, 0.16, 0.05, 0.09, m, m.lightened(0.15), 0.08)
			# The drill: a cone with spiral flutes, pointing forward and a little down.
			var tip := S._iso(c, tw, 0.40, 0.0, 0.07)
			var ring: Array = []
			for k in 12:
				var th := k * TAU / 12.0
				ring.append(S._iso(c, tw, 0.16, 0.08 * cos(th), 0.125 + 0.08 * sin(th)))
			var cone := PackedVector2Array(ring)
			cone.append(tip)
			ci.draw_colored_polygon(Geometry2D.convex_hull(cone), m.lightened(0.15))
			for k in 4:
				var th := k * TAU / 4.0 + 0.4
				var a: Vector2 = S._iso(c, tw, 0.16, 0.08 * cos(th), 0.125 + 0.08 * sin(th))
				var mid := S._iso(c, tw, 0.28, 0.04 * cos(th + 1.2), 0.10 + 0.04 * sin(th + 1.2))
				ci.draw_polyline(PackedVector2Array([a, mid, tip]), md, 1.5)
			ci.draw_circle(tip, tw * 0.008, S.WHITE)
			for k in 5:
				ci.draw_circle(tip + Vector2(cos(k * 1.3) * tw * (0.04 + (k % 2) * 0.03), -absf(sin(k * 1.3)) * tw * 0.05), tw * 0.008, Color(0.45, 0.43, 0.41))
		"prospector":
			# A six-wheeled explorer: rocker arms, a white body with a solar deck,
			# a camera mast and a sampling arm scanning the ground.
			var white := S.WHITE.darkened(0.08)
			for u in [-0.14, 0.0, 0.14]:
				_wheel(ci, c, tw, u, -0.13, 0.04, 0.04)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, -0.14, -0.13, 0.04), S._iso(c, tw, -0.07, -0.13, 0.10), S._iso(c, tw, 0.07, -0.13, 0.10), S._iso(c, tw, 0.14, -0.13, 0.04)]), md, 2.0)
			S._box(ci, c, tw, -0.16, -0.10, 0.14, 0.10, 0.06, white, white.lightened(0.05), 0.09)
			var deck := PackedVector2Array([S._iso(c, tw, -0.18, -0.12, 0.155), S._iso(c, tw, 0.10, -0.12, 0.155), S._iso(c, tw, 0.10, 0.12, 0.155), S._iso(c, tw, -0.18, 0.12, 0.155)])
			ci.draw_colored_polygon(deck, Color(0.25, 0.40, 0.75))
			for k in 3:
				var t := float(k + 1) / 4.0
				ci.draw_line(deck[0].lerp(deck[1], t), deck[3].lerp(deck[2], t), Color(0.55, 0.70, 1.0), 1.0)
			ci.draw_line(deck[0].lerp(deck[3], 0.5), deck[1].lerp(deck[2], 0.5), Color(0.55, 0.70, 1.0), 1.0)
			# Camera mast with a two-eyed head.
			var mast_top := S._iso(c, tw, 0.11, -0.06, 0.36)
			ci.draw_line(S._iso(c, tw, 0.11, -0.06, 0.15), mast_top, md, tw * 0.012)
			S._box(ci, c, tw, 0.08, -0.09, 0.14, -0.03, 0.04, white, Color(0, 0, 0, 0), 0.35)
			for k in 2:
				ci.draw_circle(S._iso(c, tw, 0.14, -0.08 + k * 0.035, 0.37), tw * 0.007, Color(0.15, 0.25, 0.35))
			# Sampling arm with a scanner beam on the ground.
			var elbow := S._iso(c, tw, 0.22, 0.08, 0.16)
			var hand := S._iso(c, tw, 0.30, 0.10, 0.05)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, 0.13, 0.07, 0.12), elbow, hand]), md, tw * 0.012)
			ci.draw_colored_polygon(PackedVector2Array([hand, S._iso(c, tw, 0.36, 0.06, 0.0), S._iso(c, tw, 0.36, 0.16, 0.0)]), Color(S.TEAL.r, S.TEAL.g, S.TEAL.b, 0.35))
			S._glow(ci, hand, tw * 0.01, S.TEAL, st)
			for u in [-0.14, 0.0, 0.14]:
				_wheel(ci, c, tw, u, 0.13, 0.04, 0.04)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, -0.14, 0.13, 0.04), S._iso(c, tw, -0.07, 0.13, 0.10), S._iso(c, tw, 0.07, 0.13, 0.10), S._iso(c, tw, 0.14, 0.13, 0.04)]), md, 2.0)
			S._glow(ci, S._iso(c, tw, 0.14, 0.04, 0.12), tw * 0.01, S.WHITE, st)
		"hauler":
			# A dump truck: a cab at the front and an open dump bed behind it. The
			# bed's sides slope up toward the back, its tall front wall has a lip
			# over the cab, ore is heaped inside, and it tips on a rear hinge,
			# lifted by a piston.
			for u in [-0.20, -0.06, 0.16]:
				_wheel(ci, c, tw, u, -0.12, 0.055, 0.055)
			S._box(ci, c, tw, -0.27, -0.10, 0.25, 0.10, 0.04, md, md.lightened(0.1), 0.06)
			S._box(ci, c, tw, 0.11, -0.10, 0.25, 0.10, 0.12, yel, yel.lightened(0.1), 0.10)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.25, -0.08, 0.15), S._iso(c, tw, 0.25, 0.08, 0.15), S._iso(c, tw, 0.25, 0.08, 0.20), S._iso(c, tw, 0.25, -0.08, 0.20)]), S.GLASS.darkened(0.3))
			S._glow(ci, S._iso(c, tw, 0.25, 0.07, 0.12), tw * 0.01, S.WHITE, st)
			# The piston under the bed, and the hinge at the back.
			ci.draw_line(S._iso(c, tw, 0.02, 0.0, 0.10), S._iso(c, tw, -0.02, 0.0, 0.13), m.lightened(0.3), tw * 0.014)
			ci.draw_circle(S._iso(c, tw, -0.24, 0.10, 0.11), tw * 0.01, md)
			var bed := yel.darkened(0.12)
			var inner := yel.darkened(0.45)
			# Bed corners: floor along the bottom, rim along the top (higher at the back).
			var f_back := -0.24
			var f_front := 0.08
			var r_back := -0.30
			var r_front := 0.09
			var floor_z := 0.11
			var rim_back := 0.22
			var rim_front := 0.21
			# Far side wall (inside face) and the floor, seen over the near wall.
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, f_back, -0.10, floor_z), S._iso(c, tw, f_front, -0.10, floor_z), S._iso(c, tw, r_front, -0.11, rim_front), S._iso(c, tw, r_back, -0.11, rim_back)]), inner)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, f_back, -0.10, floor_z), S._iso(c, tw, f_front, -0.10, floor_z), S._iso(c, tw, f_front, 0.10, floor_z), S._iso(c, tw, f_back, 0.10, floor_z)]), inner.darkened(0.2))
			# Ore heaped in the bed.
			for k in 11:
				var layer := 0 if k < 6 else (1 if k < 10 else 2)
				var ang := k * 2.4
				var spread := 1.0 - layer * 0.35
				_iso_chunk(ci, S._iso(c, tw, -0.10 + cos(ang) * 0.11 * spread, sin(ang) * 0.06 * spread, floor_z + 0.09 + layer * 0.045), tw * 0.034, S.TEAL if k % 3 == 0 else Color(0.45, 0.43, 0.41))
			# The tall front wall with its lip reaching over the cab.
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, f_front, -0.10, floor_z), S._iso(c, tw, f_front, 0.10, floor_z), S._iso(c, tw, r_front, 0.11, rim_front + 0.04), S._iso(c, tw, r_front, -0.11, rim_front + 0.04)]), bed)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, r_front, -0.11, rim_front + 0.04), S._iso(c, tw, 0.20, -0.11, rim_front + 0.04), S._iso(c, tw, 0.20, 0.11, rim_front + 0.04), S._iso(c, tw, r_front, 0.11, rim_front + 0.04)]), bed.lightened(0.12))
			# The near side wall (outside face), with ribs and a rim.
			var near := PackedVector2Array([S._iso(c, tw, f_back, 0.10, floor_z), S._iso(c, tw, f_front, 0.10, floor_z), S._iso(c, tw, r_front, 0.11, rim_front), S._iso(c, tw, r_back, 0.11, rim_back)])
			ci.draw_colored_polygon(near, bed)
			for k in 4:
				var t := 0.15 + k * 0.23
				ci.draw_line(near[0].lerp(near[1], t), near[3].lerp(near[2], t), bed.darkened(0.3), 2.0)
			ci.draw_line(near[3], near[2], bed.lightened(0.25), 2.0)
			ci.draw_line(near[0], near[3], bed.darkened(0.2), 2.0)
			for u in [-0.20, -0.06, 0.16]:
				_wheel(ci, c, tw, u, 0.12, 0.055, 0.055)
			S._glow(ci, S._iso(c, tw, 0.18, 0.0, 0.27), tw * 0.012, S.AMBER, st)
		"sweeper":
			# A small green rover with a spinning brush roller at the front.
			var green := Color(0.35, 0.68, 0.45)
			for u in [-0.12, 0.08]:
				_wheel(ci, c, tw, u, -0.11, 0.045, 0.045)
			S._box(ci, c, tw, -0.18, -0.09, 0.12, 0.09, 0.08, green, green.lightened(0.12), 0.05)
			S._box(ci, c, tw, -0.16, -0.07, -0.04, 0.07, 0.06, Color(0.20, 0.30, 0.40), Color(0.45, 0.65, 0.85), 0.13)
			# The brush roller on arms, with bristles.
			for v in [-0.10, 0.10]:
				ci.draw_line(S._iso(c, tw, 0.10, v, 0.09), S._iso(c, tw, 0.20, v, 0.05), md, 2.0)
			var r0 := S._iso(c, tw, 0.21, -0.11, 0.05)
			var r1 := S._iso(c, tw, 0.21, 0.11, 0.05)
			ci.draw_line(r0, r1, Color(0.85, 0.75, 0.35), tw * 0.04)
			for k in 9:
				var p := r0.lerp(r1, float(k) / 8.0)
				ci.draw_line(p - Vector2(tw * 0.02, tw * 0.01), p + Vector2(tw * 0.02, tw * 0.015), Color(0.55, 0.45, 0.20), 1.0)
			# Dust thrown up by the brush.
			for k in 4:
				ci.draw_circle(S._iso(c, tw, 0.30 + k * 0.03, -0.04 + k * 0.03, 0.04 + k * 0.03), tw * (0.02 + k * 0.008), Color(0.80, 0.72, 0.58, 0.45 - k * 0.08))
			for u in [-0.12, 0.08]:
				_wheel(ci, c, tw, u, 0.11, 0.045, 0.045)
			S._glow(ci, S._iso(c, tw, -0.10, 0.0, 0.21), tw * 0.012, S.AMBER, st)
		"mechanic":
			# A blue-grey service rover with a crane arm and gripper, a toolbox and
			# a flashing amber light.
			var body := Color(0.40, 0.50, 0.62)
			for u in [-0.14, 0.0, 0.14]:
				_wheel(ci, c, tw, u, -0.12, 0.05, 0.05)
			S._box(ci, c, tw, -0.20, -0.10, 0.20, 0.10, 0.08, body, body.lightened(0.12), 0.06)
			S._box(ci, c, tw, 0.08, -0.09, 0.20, 0.09, 0.09, body.darkened(0.1), body.lightened(0.05), 0.14)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.20, -0.07, 0.17), S._iso(c, tw, 0.20, 0.07, 0.17), S._iso(c, tw, 0.20, 0.07, 0.21), S._iso(c, tw, 0.20, -0.07, 0.21)]), S.GLASS.darkened(0.3))
			# The toolbox on the deck.
			S._box(ci, c, tw, -0.16, -0.06, -0.06, 0.04, 0.05, Color(0.85, 0.30, 0.25), Color(0.90, 0.40, 0.32), 0.14)
			# The crane arm: a base, two segments and a gripper.
			var base := S._iso(c, tw, -0.02, 0.0, 0.16)
			var elbow := S._iso(c, tw, -0.06, 0.0, 0.36)
			var hand := S._iso(c, tw, -0.30, 0.04, 0.26)
			ci.draw_circle(base, tw * 0.025, md)
			ci.draw_line(base, elbow, yel, tw * 0.022)
			ci.draw_line(elbow, hand, yel, tw * 0.018)
			ci.draw_circle(elbow, tw * 0.015, md)
			ci.draw_line(hand, hand + Vector2(-tw * 0.025, tw * 0.035), md, 2.0)
			ci.draw_line(hand, hand + Vector2(tw * 0.01, tw * 0.04), md, 2.0)
			for u in [-0.14, 0.0, 0.14]:
				_wheel(ci, c, tw, u, 0.12, 0.05, 0.05)
			S._glow(ci, S._iso(c, tw, 0.14, 0.0, 0.25), tw * 0.014, S.AMBER, st)
		"medic":
			# A white ambulance rover with a teal stripe and cross, and red and blue lights.
			var white := S.WHITE
			var teal := S.TEAL
			for u in [-0.14, 0.12]:
				_wheel(ci, c, tw, u, -0.12, 0.05, 0.05)
			S._box(ci, c, tw, -0.22, -0.10, 0.10, 0.10, 0.16, white, white.lightened(0.05), 0.06)
			S._box(ci, c, tw, 0.10, -0.09, 0.22, 0.09, 0.10, white.darkened(0.05), white, 0.06)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.22, -0.07, 0.10), S._iso(c, tw, 0.22, 0.07, 0.10), S._iso(c, tw, 0.22, 0.07, 0.15), S._iso(c, tw, 0.22, -0.07, 0.15)]), S.GLASS.darkened(0.3))
			ci.draw_line(S._iso(c, tw, -0.22, 0.10, 0.12), S._iso(c, tw, 0.22, 0.10, 0.12), teal, tw * 0.016)
			var cr := S._iso(c, tw, -0.06, 0.10, 0.17)
			ci.draw_rect(Rect2(cr - Vector2(tw * 0.008, tw * 0.025), Vector2(tw * 0.016, tw * 0.05)), teal)
			ci.draw_rect(Rect2(cr - Vector2(tw * 0.025, tw * 0.008), Vector2(tw * 0.05, tw * 0.016)), teal)
			for u in [-0.14, 0.12]:
				_wheel(ci, c, tw, u, 0.12, 0.05, 0.05)
			S._glow(ci, S._iso(c, tw, 0.04, -0.04, 0.24), tw * 0.014, Color(1.0, 0.25, 0.2), st)
			S._glow(ci, S._iso(c, tw, 0.04, 0.04, 0.24), tw * 0.014, Color(0.3, 0.5, 1.0), st)
		"scout":
			# A dune buggy: a low open chassis with a bright tube roll cage, fat
			# knobby tyres sticking out on a wide stance, an open engine at the back
			# with exhaust pipes and a spare tyre, a sloped nose with a bumper and
			# headlights, a helmeted driver, a light bar, an antenna flag and dust.
			var sand := Color(0.86, 0.70, 0.42)
			var cage := Color(1.0, 0.45, 0.18)
			var dark := Color(0.16, 0.16, 0.18)
			# Dust kicked up behind.
			for k in 5:
				ci.draw_circle(S._iso(c, tw, -0.32 - k * 0.05, 0.03 * k - 0.04, 0.04 + k * 0.025), tw * (0.028 + k * 0.012), Color(0.82, 0.72, 0.56, 0.42 - k * 0.07))
			# Far wheels: fat tyres, drawn as two layers for width.
			for u in [-0.16, 0.17]:
				_wheel(ci, c, tw, u, -0.22, 0.075, 0.075)
				_wheel(ci, c, tw, u, -0.18, 0.075, 0.075)
			# Suspension arms out to the wheels.
			for u in [-0.16, 0.17]:
				ci.draw_line(S._iso(c, tw, u, -0.09, 0.10), S._iso(c, tw, u, -0.16, 0.075), md, 2.0)
			# The open engine at the back, with cooling fins.
			S._box(ci, c, tw, -0.27, -0.06, -0.15, 0.06, 0.09, dark, dark.lightened(0.15), 0.08)
			for k in 4:
				var z := 0.10 + k * 0.018
				ci.draw_line(S._iso(c, tw, -0.27, -0.05, z), S._iso(c, tw, -0.27, 0.05, z), m, 1.0)
			# Two exhaust pipes curving up.
			for v in [-0.04, 0.04]:
				ci.draw_polyline(PackedVector2Array([S._iso(c, tw, -0.24, v, 0.12), S._iso(c, tw, -0.29, v, 0.14), S._iso(c, tw, -0.30, v, 0.22)]), m.lightened(0.2), maxf(1.5, tw * 0.012))
			# The spare tyre strapped on the engine.
			var spare := S._iso(c, tw, -0.21, 0.0, 0.20)
			ci.draw_colored_polygon(S._ellipse(spare, tw * 0.055, tw * 0.03), Color(0.10, 0.10, 0.11))
			ci.draw_colored_polygon(S._ellipse(spare, tw * 0.028, tw * 0.015), m)
			# The floor pan and a low sand-coloured tub.
			S._box(ci, c, tw, -0.15, -0.10, 0.16, 0.10, 0.05, sand, sand.lightened(0.1), 0.07)
			# Two bucket seats, and the driver in a helmet.
			for v in [-0.04, 0.04]:
				S._box(ci, c, tw, -0.08, v - 0.03, -0.02, v + 0.03, 0.05, dark, dark.lightened(0.1), 0.12)
				ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, -0.08, v - 0.03, 0.17), S._iso(c, tw, -0.08, v + 0.03, 0.17), S._iso(c, tw, -0.10, v + 0.03, 0.21), S._iso(c, tw, -0.10, v - 0.03, 0.21)]), dark.lightened(0.05))
			var head := S._iso(c, tw, -0.05, 0.04, 0.22)
			ci.draw_circle(head, tw * 0.032, S.WHITE)
			ci.draw_colored_polygon(S._ellipse(head + Vector2(tw * 0.012, tw * 0.004), tw * 0.02, tw * 0.012), Color(1.0, 0.65, 0.20))
			ci.draw_line(S._iso(c, tw, -0.04, 0.04, 0.17), S._iso(c, tw, 0.04, 0.03, 0.18), S.WHITE.darkened(0.15), maxf(2.0, tw * 0.014))
			# The steering wheel.
			ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, 0.05, 0.04, 0.19), tw * 0.018, tw * 0.012), dark)
			# The sloped nose, with a bumper bar and headlights.
			var nose := PackedVector2Array([S._iso(c, tw, 0.16, -0.10, 0.12), S._iso(c, tw, 0.16, 0.10, 0.12), S._iso(c, tw, 0.28, 0.07, 0.08), S._iso(c, tw, 0.28, -0.07, 0.08)])
			ci.draw_colored_polygon(nose, sand.lightened(0.12))
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.28, -0.06, 0.08), S._iso(c, tw, 0.28, 0.06, 0.08), S._iso(c, tw, 0.28, 0.06, 0.05), S._iso(c, tw, 0.28, -0.06, 0.05)]), sand.darkened(0.2))
			ci.draw_line(S._iso(c, tw, 0.31, -0.08, 0.06), S._iso(c, tw, 0.31, 0.08, 0.06), cage.darkened(0.2), maxf(2.0, tw * 0.016))
			for v in [-0.04, 0.04]:
				S._glow(ci, S._iso(c, tw, 0.29, v, 0.10), tw * 0.013, S.WHITE, st)
			# The tube roll cage: a hoop behind the seats, bars forward to the nose,
			# and a top frame with a light bar.
			var hoop := []
			for v in [-0.10, 0.10]:
				hoop.append(S._iso(c, tw, -0.12, v, 0.12))
			var top_b: Array = [S._iso(c, tw, -0.10, -0.10, 0.27), S._iso(c, tw, -0.10, 0.10, 0.27)]
			var top_f: Array = [S._iso(c, tw, 0.06, -0.10, 0.25), S._iso(c, tw, 0.06, 0.10, 0.25)]
			var foot_f: Array = [S._iso(c, tw, 0.16, -0.10, 0.12), S._iso(c, tw, 0.16, 0.10, 0.12)]
			var w := maxf(2.5, tw * 0.016)
			# Far side first.
			ci.draw_line(hoop[0], top_b[0], cage, w)
			ci.draw_line(top_b[0], top_f[0], cage, w)
			ci.draw_line(top_f[0], foot_f[0], cage, w)
			ci.draw_line(top_b[0], top_b[1], cage, w)
			ci.draw_line(top_f[0], top_f[1], cage, w)
			# Light bar on the front of the top frame.
			for k in 3:
				S._glow(ci, top_f[0].lerp(top_f[1], 0.2 + k * 0.3) - Vector2(0, tw * 0.012), tw * 0.011, Color(1.0, 0.95, 0.75), st)
			# Antenna whip with a flag, off the back hoop.
			var whip: Vector2 = top_b[0] - Vector2(tw * 0.015, tw * 0.13)
			ci.draw_line(top_b[0], whip, md, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([whip, whip + Vector2(tw * 0.06, tw * 0.014), whip + Vector2(0, tw * 0.032)]), Color(1.0, 0.85, 0.25))
			# Near side of the cage.
			ci.draw_line(hoop[1], top_b[1], cage, w)
			ci.draw_line(top_b[1], top_f[1], cage, w)
			ci.draw_line(top_f[1], foot_f[1], cage, w)
			# A side bar along the tub.
			ci.draw_line(S._iso(c, tw, -0.14, 0.11, 0.15), S._iso(c, tw, 0.15, 0.11, 0.14), cage.darkened(0.15), maxf(2.0, tw * 0.012))
			# Near suspension arms and fat wheels.
			for u in [-0.16, 0.17]:
				ci.draw_line(S._iso(c, tw, u, 0.09, 0.10), S._iso(c, tw, u, 0.18, 0.075), md, 2.0)
			for u in [-0.16, 0.17]:
				_wheel(ci, c, tw, u, 0.18, 0.075, 0.075)
				_wheel(ci, c, tw, u, 0.22, 0.075, 0.075)
				# Knobby tread blocks round the outside.
				for k in 10:
					var th := k * TAU / 10.0
					ci.draw_circle(S._iso(c, tw, u + 0.08 * cos(th), 0.22, 0.075 + 0.08 * sin(th)), maxf(1.2, tw * 0.007), Color(0.06, 0.06, 0.07))
		"survey":
			# A camera satellite: panels, a body, a big lens looking down and a
			# green scanning beam sweeping the ground.
			_panels(ci, c, tw, Color(0.25, 0.40, 0.75))
			S._box(ci, c, tw, -0.07, -0.07, 0.07, 0.07, 0.14, Color(0.55, 0.62, 0.55), Color(0, 0, 0, 0), 0.2)
			var lens := S._iso(c, tw, 0, 0, 0.19)
			ci.draw_colored_polygon(S._ellipse(lens, tw * 0.06, tw * 0.03), Color(0.08, 0.10, 0.12))
			ci.draw_colored_polygon(S._ellipse(lens, tw * 0.035, tw * 0.018), Color(0.35, 0.85, 0.55))
			var ground := S._iso(c, tw, 0, 0, -0.30)
			ci.draw_colored_polygon(PackedVector2Array([lens + Vector2(-tw * 0.03, 0), lens + Vector2(tw * 0.03, 0), ground + Vector2(tw * 0.16, 0), ground + Vector2(-tw * 0.16, 0)]), Color(0.35, 0.95, 0.55, 0.16))
			for k in 4:
				var t := 0.25 + k * 0.25
				var y := lens.lerp(ground, t)
				var w := tw * (0.03 + 0.13 * t)
				ci.draw_line(y - Vector2(w, 0), y + Vector2(w, 0), Color(0.35, 0.95, 0.55, 0.5), 1.0)
		"weather":
			_panels(ci, c, tw, Color(0.25, 0.40, 0.75))
			S._box(ci, c, tw, -0.07, -0.07, 0.07, 0.07, 0.14, S.WHITE.darkened(0.1), Color(0, 0, 0, 0), 0.2)
			ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, 0.0, 0.08, 0.27), tw * 0.04, tw * 0.03), Color(0.1, 0.12, 0.2))
			S._glow(ci, S._iso(c, tw, 0.0, 0.08, 0.27), tw * 0.015, S.CYAN, st)
			for k in 3:
				ci.draw_arc(S._iso(c, tw, 0, 0, 0.0) + Vector2(0, tw * 0.05), tw * (0.08 + k * 0.05), deg_to_rad(30), deg_to_rad(150), 10, Color(S.CYAN.r, S.CYAN.g, S.CYAN.b, 0.5 - k * 0.12), 1.5)
		"relay":
			_panels(ci, c, tw, Color(0.25, 0.40, 0.75))
			S._box(ci, c, tw, -0.07, -0.07, 0.07, 0.07, 0.14, S.GOLD.darkened(0.2), Color(0, 0, 0, 0), 0.2)
			var dish := S._iso(c, tw, 0, 0, 0.48)
			ci.draw_line(S._iso(c, tw, 0, 0, 0.34), dish, md, 2.0)
			ci.draw_colored_polygon(S._ellipse(dish, tw * 0.13, tw * 0.07), S.WHITE)
			ci.draw_polyline(S._ellipse(dish, tw * 0.13, tw * 0.07), md, 1.5)
			ci.draw_line(dish, dish - Vector2(0, tw * 0.1), md, 1.5)
			S._glow(ci, dish - Vector2(0, tw * 0.1), tw * 0.012, S.GREEN, st)
		"power":
			# A huge gold mirror sail that beams power down.
			var sail := PackedVector2Array([S._iso(c, tw, -0.38, -0.38, 0.4), S._iso(c, tw, 0.38, -0.38, 0.4), S._iso(c, tw, 0.38, 0.38, 0.4), S._iso(c, tw, -0.38, 0.38, 0.4)])
			ci.draw_colored_polygon(sail, S.GOLD.darkened(0.15))
			for k in 3:
				var t := float(k + 1) / 4.0
				ci.draw_line(sail[0].lerp(sail[1], t), sail[3].lerp(sail[2], t), S.GOLD.lightened(0.2), 1.0)
				ci.draw_line(sail[0].lerp(sail[3], t), sail[1].lerp(sail[2], t), S.GOLD.lightened(0.2), 1.0)
			ci.draw_line(sail[0], sail[2], md, 1.5)
			ci.draw_line(sail[1], sail[3], md, 1.5)
			var emitter := S._iso(c, tw, 0, 0, 0.32)
			S._box(ci, c, tw, -0.05, -0.05, 0.05, 0.05, 0.08, md, Color(0, 0, 0, 0), 0.30)
			var ground := S._iso(c, tw, 0, 0, -0.3)
			ci.draw_colored_polygon(PackedVector2Array([emitter + Vector2(-tw * 0.015, 0), emitter + Vector2(tw * 0.015, 0), ground + Vector2(tw * 0.05, 0), ground + Vector2(-tw * 0.05, 0)]), Color(1.0, 0.85, 0.4, 0.3))
			ci.draw_line(emitter, ground, Color(1.0, 0.95, 0.8, 0.9), 2.0)


## A tyre seen from the side at (u, v), its centre at height z, radius r (tile
## units): a dark tread, a lighter rim and a hub, drawn in the wheel's own plane.
static func _wheel(ci: CanvasItem, c: Vector2, tw: float, u: float, v: float, z: float, r: float) -> void:
	var tyre := PackedVector2Array()
	var rim := PackedVector2Array()
	for k in 16:
		var th := k * TAU / 16.0
		tyre.append(S._iso(c, tw, u + r * cos(th), v, z + r * sin(th)))
		rim.append(S._iso(c, tw, u + r * 0.55 * cos(th), v, z + r * 0.55 * sin(th)))
	ci.draw_colored_polygon(tyre, Color(0.10, 0.10, 0.11))
	for k in 8:
		var th := k * TAU / 8.0
		ci.draw_line(S._iso(c, tw, u + r * 0.8 * cos(th), v, z + r * 0.8 * sin(th)), S._iso(c, tw, u + r * cos(th), v, z + r * sin(th)), Color(0.22, 0.22, 0.24), 1.0)
	ci.draw_colored_polygon(rim, S.METAL)
	ci.draw_circle(S._iso(c, tw, u, v, z), maxf(1.0, tw * r * 0.2), S.METAL_DARK)


## A caterpillar tread on side v of a tracked drone: a dark belt with road
## wheels and tread cleats (near = the side facing the viewer).
static func _tread(ci: CanvasItem, c: Vector2, tw: float, v: float, near: bool) -> void:
	var belt := Color(0.12, 0.12, 0.13)
	S._box(ci, c, tw, -0.22, v - 0.04, 0.18, v + 0.04, 0.08, belt, belt.lightened(0.08))
	if near:
		for k in 4:
			_wheel(ci, c, tw, -0.16 + k * 0.1, v + 0.041, 0.04, 0.03)
		for k in 9:
			var u := -0.21 + k * 0.047
			ci.draw_line(S._iso(c, tw, u, v + 0.04, 0.075), S._iso(c, tw, u + 0.02, v + 0.04, 0.08), Color(0.32, 0.32, 0.34), 1.5)


## A small rough lump of rock or ore.
static func _iso_chunk(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(p + Vector2.from_angle(i * TAU / 7.0) * r * (0.75 + 0.25 * sin(i * 2.3 + p.x)))
	ci.draw_colored_polygon(pts, col.darkened(0.15))
	ci.draw_circle(p - Vector2(r * 0.25, r * 0.3), r * 0.4, col.lightened(0.1))


## A satellite's two solar wings.
static func _panels(ci: CanvasItem, c: Vector2, tw: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		var v0: float = 0.10 * side
		var v1: float = 0.42 * side
		var wing := PackedVector2Array([S._iso(c, tw, -0.08, v0, 0.27), S._iso(c, tw, 0.08, v0, 0.27), S._iso(c, tw, 0.08, v1, 0.27), S._iso(c, tw, -0.08, v1, 0.27)])
		ci.draw_colored_polygon(wing, col)
		for k in 3:
			var t := float(k + 1) / 4.0
			ci.draw_line(wing[0].lerp(wing[3], t), wing[1].lerp(wing[2], t), col.lightened(0.3), 1.0)
		ci.draw_polyline(PackedVector2Array([wing[0], wing[1], wing[2], wing[3], wing[0]]), S.METAL_DARK, 1.0)
		ci.draw_line(S._iso(c, tw, 0, 0, 0.27), S._iso(c, tw, 0, v0, 0.27), S.METAL, 2.0)
