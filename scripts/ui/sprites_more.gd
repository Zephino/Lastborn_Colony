## Sprites for the buildings added in 00.01.26 (Fusion Core, Beam Catcher,
## Reclaimer, Fab Shop, Drone Bay, Signal Mast, Rescue Station, Academy,
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
		"fusion":
			# Two big cooling towers at the sides, with clouds of steam.
			for p in [Vector2(-0.34, 0.34), Vector2(0.34, -0.34)]:
				var t: Vector2 = c + p * s
				ci.draw_circle(t, s * 0.16, md)
				ci.draw_circle(t, s * 0.14, _f(Color(0.78, 0.78, 0.76), state))
				ci.draw_circle(t, s * 0.09, Color(0.05, 0.05, 0.06, m.a))
				if S._lit(state):
					for k in 3:
						ci.draw_circle(t + Vector2(s * (0.02 + k * 0.03), -s * (0.02 + k * 0.03)), s * (0.08 + k * 0.02), Color(STEAM.r, STEAM.g, STEAM.b, 0.45 - k * 0.12))
		"catcher":
			# Four fields of receiving mesh round the receiver.
			for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var q := Rect2(c + Vector2(p.x * s * 0.27 - s * 0.19, p.y * s * 0.27 - s * 0.19), Vector2(s * 0.38, s * 0.38))
				ci.draw_rect(q, md)
				ci.draw_rect(q.grow(-s * 0.02), _f(Color(0.20, 0.24, 0.32), state))
				for k in 5:
					var t := float(k + 1) / 6.0
					ci.draw_line(Vector2(q.position.x + q.size.x * t, q.position.y), Vector2(q.position.x + q.size.x * t, q.end.y), _f(Color(0.55, 0.62, 0.75), state), 1.0)
					ci.draw_line(Vector2(q.position.x, q.position.y + q.size.y * t), Vector2(q.end.x, q.position.y + q.size.y * t), _f(Color(0.40, 0.46, 0.58), state), 1.0)
		"reclaimer":
			# A hopper of junk at the back, a water tank at the right, an ore bin at the front-left.
			var hop := Rect2(c + Vector2(-s * 0.48, -s * 0.48), Vector2(s * 0.22, s * 0.22))
			ci.draw_rect(hop, md)
			for k in 5:
				S._rot_rect(ci, hop.position + Vector2(s * (0.05 + (k % 3) * 0.06), s * (0.06 + (k / 3) * 0.08)), Vector2.from_angle(k * 1.3), s * 0.06, s * 0.03, _f([Color(0.6, 0.55, 0.45), Color(0.5, 0.5, 0.55), Color(0.65, 0.35, 0.3)][k % 3], state))
			ci.draw_circle(c + Vector2(s * 0.36, -s * 0.36), s * 0.11, md)
			ci.draw_circle(c + Vector2(s * 0.36, -s * 0.36), s * 0.085, _f(S.WATER, state).darkened(0.2))
			var bin := Rect2(c + Vector2(-s * 0.47, s * 0.28), Vector2(s * 0.18, s * 0.16))
			ci.draw_rect(bin, md)
			for k in 4:
				ci.draw_circle(bin.position + Vector2(s * (0.05 + (k % 2) * 0.08), s * (0.05 + (k / 2) * 0.06)), s * 0.03, _f(Color(0.45, 0.6, 0.58), state))
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
		"mast":
			# Guy wires from the mast to three anchors.
			for ang in [200.0, 320.0, 80.0]:
				var anchor := c + Vector2.from_angle(deg_to_rad(ang)) * s * 0.46
				ci.draw_line(c, anchor, _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
				ci.draw_rect(Rect2(anchor - Vector2(s * 0.025, s * 0.025), Vector2(s * 0.05, s * 0.05)), md)
		"rescue":
			# A stack of brace beams at the back, a rescue rover at the front-left.
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * (0.47 - k * 0.05)), Vector2(s * 0.26, s * 0.035)), _f(S.HAZARD, state).darkened(0.15))
			_top_rover(ci, c + Vector2(-s * 0.34, s * 0.36), s, _f(RESCUE, state), state)
		"academy":
			# A playground at the front-left (slide and swings), a tree, and a yellow school bus at the back.
			var yard := Rect2(c + Vector2(-s * 0.49, s * 0.22), Vector2(s * 0.27, s * 0.26))
			ci.draw_rect(yard, _f(Color(0.36, 0.55, 0.32), state))
			ci.draw_line(yard.position + Vector2(s * 0.04, s * 0.05), yard.position + Vector2(s * 0.22, s * 0.05), _f(RESCUE, state), 2.0)
			for k in 2:
				ci.draw_line(yard.position + Vector2(s * (0.08 + k * 0.08), s * 0.05), yard.position + Vector2(s * (0.08 + k * 0.08), s * 0.10), md, 1.0)
			S._rot_rect(ci, yard.position + Vector2(s * 0.14, s * 0.18), Vector2(1, 0.6), s * 0.16, s * 0.04, _f(S.CYAN, state))
			S._rot_rect(ci, c + Vector2(s * 0.30, -s * 0.40), Vector2(1, 0), s * 0.30, s * 0.10, _f(Color(0.98, 0.78, 0.15), state))
			for k in 4:
				ci.draw_rect(Rect2(c + Vector2(s * (0.18 + k * 0.065), -s * 0.43), Vector2(s * 0.04, s * 0.03)), _f(S.GLASS, state).darkened(0.3))
			ci.draw_circle(c + Vector2(-s * 0.40, -s * 0.40), s * 0.08, _f(Color(0.30, 0.62, 0.32), state))
		"hazlab":
			# A thick blast wall all round, with hazard stripes.
			ci.draw_circle(c, rad * 1.45, _f(Color(0.42, 0.42, 0.40), state))
			ci.draw_circle(c, rad * 1.25, _f(Color(0.30, 0.30, 0.29), state))
			for i in 20:
				var a0 := i * TAU / 20.0
				ci.draw_arc(c, rad * 1.35, a0, a0 + TAU / 40.0, 4, _f(S.HAZARD, state) if i % 2 == 0 else Color(0.05, 0.05, 0.05, m.a), maxf(2.0, s * 0.03))
		"lounge":
			# A neon sign at the front-left.
			var sign := Rect2(c + Vector2(-s * 0.48, s * 0.30), Vector2(s * 0.22, s * 0.1))
			ci.draw_rect(sign, md)
			S._glow(ci, sign.get_center() - Vector2(s * 0.05, 0), s * 0.025, _f(S.PINK, state), state)
			S._glow(ci, sign.get_center() + Vector2(s * 0.05, 0), s * 0.025, _f(S.CYAN, state), state)


static func top_post(ci: CanvasItem, type: String, c: Vector2, s: float, rad: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	match type:
		"fusion":
			# A concrete containment dome over the glass, with a band and a hatch.
			var concrete := _f(Color(0.74, 0.74, 0.72), state)
			ci.draw_circle(c, rad * 0.82, concrete)
			for k in 3:
				ci.draw_arc(c, rad * (0.35 + k * 0.22), 0, TAU, 32, concrete.darkened(0.15), 1.5)
			ci.draw_arc(c, rad * 0.82, 0, TAU, 36, _f(FUSION, state), 2.0)
			ci.draw_circle(c, rad * 0.16, concrete.darkened(0.25))
			S._glow(ci, c + Vector2(rad * 0.62, rad * 0.62), s * 0.025, _f(FUSION, state), state)
			ci.draw_arc(c - Vector2(rad * 0.3, rad * 0.3), rad * 0.4, deg_to_rad(200), deg_to_rad(260), 8, Color(1, 1, 1, 0.5 * concrete.a), 2.0)
		"catcher":
			# The beam coming down from orbit onto the receiver.
			S._glow(ci, c, s * 0.06, _f(S.GOLD, state), state)
			ci.draw_arc(c, rad * 0.6, 0, TAU, 20, _f(S.GOLD, state), 2.0)
		"reclaimer":
			# Three arrows chasing round: recycling.
			var g := _f(S.GREEN, state)
			for k in 3:
				var a0 := k * TAU / 3.0
				ci.draw_arc(c, rad * 0.45, a0, a0 + TAU / 3.0 - 0.5, 10, g, maxf(2.5, s * 0.035))
				var tip := c + Vector2.from_angle(a0 + TAU / 3.0 - 0.45) * rad * 0.45
				var d := Vector2.from_angle(a0 + TAU / 3.0 - 0.45 + PI / 2.0)
				ci.draw_colored_polygon(PackedVector2Array([tip + d * s * 0.05, tip + d.orthogonal() * s * 0.04, tip - d.orthogonal() * s * 0.04]), g)
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
			S._top_drone(ci, c + Vector2(-rad * 0.35, 0), rad * 0.22, state)
			S._top_drone(ci, c + Vector2(rad * 0.35, 0), rad * 0.22, state)
		"mast":
			# The lattice mast from above, with its dishes and a red light.
			ci.draw_rect(Rect2(c - Vector2(s * 0.05, s * 0.05), Vector2(s * 0.1, s * 0.1)), md)
			ci.draw_line(c - Vector2(s * 0.05, s * 0.05), c + Vector2(s * 0.05, s * 0.05), m, 1.0)
			ci.draw_line(c + Vector2(s * 0.05, -s * 0.05), c - Vector2(s * 0.05, -s * 0.05), m, 1.0)
			for p in [Vector2(0.12, -0.06), Vector2(-0.1, 0.1)]:
				ci.draw_circle(c + p * s, s * 0.055, _f(S.WHITE, state).darkened(0.1))
			S._glow(ci, c, s * 0.02, _f(Color(1.0, 0.3, 0.3), state), state)
			for k in 3:
				ci.draw_arc(c, s * (0.18 + k * 0.08), deg_to_rad(-60), deg_to_rad(-20), 6, _f(S.CYAN, state) * Color(1, 1, 1, 0.8 - k * 0.2), 1.5)
		"rescue":
			# A life ring, and warning beacons round the rim.
			var ring := c
			for k in 8:
				var a0 := k * TAU / 8.0
				ci.draw_arc(ring, rad * 0.42, a0, a0 + TAU / 8.0, 6, _f(RESCUE, state) if k % 2 == 0 else _f(S.WHITE, state), maxf(4.0, s * 0.07))
			for k in 3:
				S._glow(ci, c + Vector2.from_angle(k * TAU / 3.0 + 0.5) * rad * 0.78, s * 0.02, _f(RESCUE, state), state)
		"academy":
			# Rows of desks facing the teacher's desk and a chalkboard, and a clock on top.
			ci.draw_rect(Rect2(c + Vector2(-rad * 0.40, -rad * 0.66), Vector2(rad * 0.8, rad * 0.10)), _f(Color(0.16, 0.30, 0.22), state))
			ci.draw_rect(Rect2(c + Vector2(-rad * 0.18, -rad * 0.46), Vector2(rad * 0.36, rad * 0.12)), _f(Color(0.50, 0.34, 0.22), state))
			for row in 3:
				for col in 4:
					ci.draw_rect(Rect2(c + Vector2(-rad * 0.50 + col * rad * 0.26, -rad * 0.16 + row * rad * 0.24), Vector2(rad * 0.18, rad * 0.11)), _f(Color(0.70, 0.54, 0.34), state))
			ci.draw_circle(c, rad * 0.14, _f(S.WHITE, state))
			ci.draw_line(c, c + Vector2(0, -rad * 0.1), md, 1.5)
			ci.draw_line(c, c + Vector2(rad * 0.07, 0), md, 1.5)
		"hazlab":
			# A glowing green containment sphere.
			S._glow(ci, c, rad * 0.30, _f(LIME, state), state)
			ci.draw_arc(c, rad * 0.4, 0, TAU, 20, md, 2.0)
		"garden":
			# A pond, a path and trees.
			ci.draw_circle(c + Vector2(rad * 0.25, rad * 0.25), rad * 0.28, _f(S.WATER, state).darkened(0.1))
			ci.draw_line(c + Vector2(-rad * 0.8, rad * 0.1), c + Vector2(rad * 0.1, -rad * 0.8), _f(Color(0.75, 0.68, 0.52), state), maxf(2.0, s * 0.03))
			for p in [Vector2(-0.45, -0.25), Vector2(-0.1, -0.5), Vector2(0.4, -0.3), Vector2(-0.45, 0.35), Vector2(-0.05, 0.55)]:
				ci.draw_circle(c + p * rad, rad * 0.17, _f(Color(0.25, 0.55, 0.28), state))
				ci.draw_circle(c + p * rad - Vector2(rad * 0.04, rad * 0.04), rad * 0.10, _f(Color(0.40, 0.78, 0.40), state))
			for k in 3:
				ci.draw_circle(c + Vector2(-rad * 0.2 + k * rad * 0.15, -rad * 0.2), rad * 0.04, _f([S.PINK, S.GOLD, S.WHITE][k], state))
		"lounge":
			# A glowing dance floor and a round bar.
			var cols := [S.PINK, S.CYAN, S.GOLD, S.VIOLET]
			for i in 3:
				for j in 3:
					ci.draw_rect(Rect2(c + Vector2(-rad * 0.36 + i * rad * 0.24, -rad * 0.36 + j * rad * 0.24), Vector2(rad * 0.22, rad * 0.22)), _f(cols[(i + j) % 4], state) * Color(1, 1, 1, 0.8))
			ci.draw_arc(c, rad * 0.62, deg_to_rad(20), deg_to_rad(160), 12, _f(Color(0.55, 0.38, 0.26), state), maxf(3.0, s * 0.05))


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
		"fusion":
			# Two big cooling towers at the sides, waisted like hourglasses, with clouds of steam.
			for p in [Vector2(-0.34, 0.34), Vector2(0.34, -0.34)]:
				_cooling_tower(ci, c, tw, p, 0.44, state)
		"catcher":
			# The mesh fields, tilted toward the sky, round the receiver.
			for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var u0: float = p.x * 0.27 - 0.19
				var v0: float = p.y * 0.27 - 0.19
				var panel := PackedVector2Array([S._iso(c, tw, u0, v0, 0.06), S._iso(c, tw, u0 + 0.38, v0, 0.06), S._iso(c, tw, u0 + 0.38, v0 + 0.38, 0.02), S._iso(c, tw, u0, v0 + 0.38, 0.02)])
				ci.draw_colored_polygon(panel, _f(Color(0.20, 0.24, 0.32), state))
				for k in 5:
					var t := float(k + 1) / 6.0
					ci.draw_line(panel[0].lerp(panel[1], t), panel[3].lerp(panel[2], t), _f(Color(0.55, 0.62, 0.75), state), 1.0)
					ci.draw_line(panel[0].lerp(panel[3], t), panel[1].lerp(panel[2], t), _f(Color(0.40, 0.46, 0.58), state), 1.0)
				ci.draw_polyline(PackedVector2Array([panel[0], panel[1], panel[2], panel[3], panel[0]]), md, 1.5)
		"reclaimer":
			S._box(ci, c, tw, -0.48, -0.48, -0.26, -0.26, 0.12, md, Color(0.3, 0.28, 0.25, md.a))
			for k in 4:
				S._iso_sphere(ci, S._iso(c, tw, -0.44 + (k % 2) * 0.1, -0.44 + (k / 2) * 0.1, 0.14), tw * 0.025, _f([Color(0.6, 0.55, 0.45), Color(0.5, 0.5, 0.55), Color(0.65, 0.35, 0.3), Color(0.55, 0.5, 0.4)][k], state))
			S._cyl(ci, c, tw, 0.36, -0.36, 0.11, 0.30, _f(S.WATER, state).darkened(0.25), _f(S.WATER, state).darkened(0.05))
			ci.draw_line(S._iso(c, tw, 0.12, -0.12, 0.12), S._iso(c, tw, 0.30, -0.30, 0.12), md, tw * 0.03)
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
		"mast":
			for ang in [200.0, 320.0]:
				var q := Vector2.from_angle(deg_to_rad(ang)) * 0.46
				ci.draw_line(S._iso(c, tw, 0, 0, 0.75), S._iso(c, tw, q.x, q.y), _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
		"rescue":
			for k in 3:
				S._box(ci, c, tw, -0.48, -0.47 + k * 0.05, -0.22, -0.44 + k * 0.05, 0.03, _f(S.HAZARD, state).darkened(0.15), Color(0, 0, 0, 0), k * 0.03)
		"academy":
			# A yellow school bus parked at the back-right, and a tree.
			var bus := _f(Color(0.98, 0.78, 0.15), state)
			S._box(ci, c, tw, 0.18, -0.46, 0.48, -0.36, 0.12, bus, Color(0, 0, 0, 0), 0.02)
			for k in 4:
				var u := 0.21 + k * 0.065
				ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, u, -0.36, 0.08), S._iso(c, tw, u + 0.04, -0.36, 0.08), S._iso(c, tw, u + 0.04, -0.36, 0.12), S._iso(c, tw, u, -0.36, 0.12)]), _f(S.GLASS, state).darkened(0.3))
			for u in [0.24, 0.42]:
				ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, u, -0.36, 0.02), tw * 0.02, tw * 0.02), Color(0.08, 0.08, 0.09, bus.a))
			ci.draw_line(S._iso(c, tw, -0.38, -0.38), S._iso(c, tw, -0.38, -0.38, 0.12), _f(Color(0.4, 0.3, 0.2), state), tw * 0.015)
			S._iso_sphere(ci, S._iso(c, tw, -0.38, -0.38, 0.2), tw * 0.08, _f(Color(0.30, 0.62, 0.32), state))
		"hazlab":
			# The blast wall: back half first, so the dome sits inside it.
			_blast_wall(ci, c, tw, r, state, true)


static func iso_post(ci: CanvasItem, type: String, c: Vector2, tw: float, r: float, h: float, state: Dictionary) -> void:
	var md := _f(S.METAL_DARK, state)
	var m := _f(S.METAL, state)
	var apex := S._iso(c, tw, 0, 0, 0.05 + h)
	match type:
		"fusion":
			# A concrete containment dome over the glass one, like a power station's reactor building.
			var concrete := _f(Color(0.74, 0.74, 0.72), state)
			var base := S._iso(c, tw, 0, 0, 0.05)
			var rx := r * tw * 0.72
			var ry := rx * 0.5
			var shell := S._ellipse(base, rx, ry, 0, 180, 16)
			shell.append_array(S._ellipse(base, rx, h * tw * 0.95, 180, 360, 20))
			ci.draw_colored_polygon(shell, concrete)
			ci.draw_colored_polygon(S._ellipse(base - Vector2(rx * 0.35, h * tw * 0.55), rx * 0.42, h * tw * 0.4, 180, 300, 10), concrete.lightened(0.12))
			ci.draw_polyline(S._ellipse(base, rx * 0.99, ry * 0.99, 0, 180, 16), _f(FUSION, state), 2.0)
			ci.draw_polyline(S._ellipse(base - Vector2(0, h * tw * 0.5), rx * 0.86, ry * 0.86, 0, 180, 16), concrete.darkened(0.15), 1.5)
			# A hatch at the front with a blue glow, and a tall vent stack.
			var door := S._iso(c, tw, r * 0.7, r * 0.7, 0.05)
			ci.draw_colored_polygon(S._ellipse(door - Vector2(0, tw * 0.03), tw * 0.035, tw * 0.035, 180, 360, 8) + PackedVector2Array([door + Vector2(tw * 0.035, 0), door + Vector2(-tw * 0.035, 0)]), concrete.darkened(0.4))
			S._glow(ci, door - Vector2(0, tw * 0.02), tw * 0.015, _f(FUSION, state), state)
		"catcher":
			# A shaft of light from orbit down onto the receiver.
			var gold := _f(S.GOLD, state)
			if S._lit(state):
				var top := apex - Vector2(0, tw * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-tw * 0.02, 0), top + Vector2(tw * 0.02, 0), apex + Vector2(tw * 0.06, 0), apex + Vector2(-tw * 0.06, 0)]), Color(gold.r, gold.g, gold.b, 0.30))
				ci.draw_line(top, apex, Color(1.0, 0.95, 0.8, 0.9), 2.0)
			S._glow(ci, apex, tw * 0.035, gold, state)
		"reclaimer":
			var g := _f(S.GREEN, state)
			var mid := S._iso(c, tw, 0, 0, 0.05 + h * 0.5)
			for k in 3:
				var a0 := rad_to_deg(k * TAU / 3.0)
				ci.draw_polyline(S._ellipse(mid, r * tw * 0.32, r * tw * 0.20, a0, a0 + 90.0, 8), g, 2.5)
			S._box(ci, c, tw, -0.47, 0.28, -0.29, 0.44, 0.07, md)
			for k in 4:
				S._iso_sphere(ci, S._iso(c, tw, -0.43 + (k % 2) * 0.08, 0.32 + (k / 2) * 0.06, 0.08), tw * 0.022, _f(Color(0.45, 0.6, 0.58), state))
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
			S._iso_drone(ci, S._iso(c, tw, -0.06, -0.06) - c + c, tw, 0.06, 0.07, state)
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
			S._iso_drone(ci, S._iso(c, tw, (u0 + u1) * 0.5, v1 - 0.06) - c + c, tw, 0.0, 0.05, state)
			var roll := PackedVector2Array([S._iso(c, tw, u0 + 0.04, v1, 0.08), S._iso(c, tw, u1 - 0.04, v1, 0.08), S._iso(c, tw, u1 - 0.04, v1, 0.16), S._iso(c, tw, u0 + 0.04, v1, 0.16)])
			ci.draw_colored_polygon(roll, wall.lightened(0.15))
			for k in 4:
				var z := 0.09 + k * 0.02
				ci.draw_line(S._iso(c, tw, u0 + 0.04, v1, z), S._iso(c, tw, u1 - 0.04, v1, z), wall.darkened(0.2), 1.0)
			ci.draw_line(S._iso(c, tw, u0 + 0.04, v1, 0.0), S._iso(c, tw, u1 - 0.04, v1, 0.0), _f(S.HAZARD, state), 2.0)
			S._glow(ci, S._iso(c, tw, (u0 + u1) * 0.5, v1, 0.185), tw * 0.012, _f(S.AMBER, state), state)
		"mast":
			var top := S._iso(c, tw, 0, 0, 0.85)
			var foot := S._iso(c, tw, 0, 0, h)
			for side in [-1.0, 1.0]:
				ci.draw_line(foot + Vector2(side * tw * 0.03, 0), top, md.lightened(0.2), 2.0)
			for k in 6:
				var t0 := float(k) / 6.0
				var t1 := float(k + 1) / 6.0
				var w0 := tw * 0.03 * (1.0 - t0)
				var w1 := tw * 0.03 * (1.0 - t1)
				ci.draw_line(foot.lerp(top, t0) + Vector2(-w0, 0), foot.lerp(top, t1) + Vector2(w1, 0), m, 1.0)
			for p in [[0.45, 1.0], [0.65, -1.0]]:
				var at: Vector2 = foot.lerp(top, p[0]) + Vector2(p[1] * tw * 0.04, 0)
				ci.draw_colored_polygon(S._ellipse(at, tw * 0.03, tw * 0.045), _f(S.WHITE, state).darkened(0.1))
			S._glow(ci, top, tw * 0.016, _f(Color(1.0, 0.3, 0.3), state), state)
			for k in 3:
				ci.draw_arc(top, tw * (0.07 + k * 0.05), deg_to_rad(-70), deg_to_rad(-20), 6, _f(S.CYAN, state) * Color(1, 1, 1, 0.8 - k * 0.2), 1.5)
			var q := Vector2.from_angle(deg_to_rad(80.0)) * 0.46
			ci.draw_line(S._iso(c, tw, 0, 0, 0.75), S._iso(c, tw, q.x, q.y), _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
		"rescue":
			var mid := S._iso(c, tw, 0, 0, 0.05 + h * 0.5)
			for k in 8:
				var a0 := k * 45.0
				ci.draw_polyline(S._ellipse(mid, tw * 0.07, tw * 0.07, a0, a0 + 45.0, 4), _f(RESCUE, state) if k % 2 == 0 else _f(S.WHITE, state), tw * 0.025)
			S._glow(ci, apex - Vector2(0, tw * 0.02), tw * 0.025, _f(RESCUE, state), state)
			_iso_rover(ci, c, tw, Vector2(-0.34, 0.36), _f(RESCUE, state), state)
		"academy":
			# A front entrance with columns and a gable, a clock tower with a bell, and a playground.
			var stone := _f(Color(0.88, 0.84, 0.76), state)
			S._box(ci, c, tw, r * 0.55, r * 0.35, r * 0.95, r * 0.95, 0.03, stone)
			for k in 3:
				var v := r * (0.42 + k * 0.22)
				ci.draw_line(S._iso(c, tw, r * 0.93, v, 0.03), S._iso(c, tw, r * 0.93, v, 0.17), stone, tw * 0.014)
			var g0 := S._iso(c, tw, r * 0.95, r * 0.35, 0.17)
			var g1 := S._iso(c, tw, r * 0.95, r * 0.95, 0.17)
			ci.draw_colored_polygon(PackedVector2Array([g0, g1, g0.lerp(g1, 0.5) - Vector2(0, tw * 0.07)]), stone.darkened(0.1))
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, r * 0.95, r * 0.55, 0.03), S._iso(c, tw, r * 0.95, r * 0.75, 0.03), S._iso(c, tw, r * 0.95, r * 0.75, 0.13), S._iso(c, tw, r * 0.95, r * 0.55, 0.13)]), _f(Color(0.45, 0.30, 0.20), state))
			# Clock tower on top.
			S._box(ci, c, tw, -0.05, -0.05, 0.05, 0.05, 0.16, stone, Color(0, 0, 0, 0), h)
			var face := S._iso(c, tw, 0.05, 0.0, h + 0.11)
			ci.draw_colored_polygon(S._ellipse(face, tw * 0.025, tw * 0.03), _f(S.WHITE, state))
			ci.draw_line(face, face - Vector2(0, tw * 0.02), md, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, -0.06, -0.06, h + 0.16), S._iso(c, tw, 0.06, -0.06, h + 0.16), S._iso(c, tw, 0.06, 0.06, h + 0.16), S._iso(c, tw, -0.06, 0.06, h + 0.16)]), stone.darkened(0.2))
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, -0.06, 0.06, h + 0.16), S._iso(c, tw, 0.06, 0.06, h + 0.16), S._iso(c, tw, 0.06, -0.06, h + 0.16), S._iso(c, tw, 0, 0, h + 0.26)]), _f(RESCUE, state).darkened(0.2))
			# Playground: grass, a swing set and a slide.
			var grass := PackedVector2Array([S._iso(c, tw, -0.49, 0.22, 0.0), S._iso(c, tw, -0.22, 0.22, 0.0), S._iso(c, tw, -0.22, 0.48, 0.0), S._iso(c, tw, -0.49, 0.48, 0.0)])
			ci.draw_colored_polygon(grass, _f(Color(0.36, 0.55, 0.32), state))
			for u in [-0.45, -0.29]:
				ci.draw_line(S._iso(c, tw, u, 0.28), S._iso(c, tw, u, 0.28, 0.14), md, 1.5)
			ci.draw_line(S._iso(c, tw, -0.45, 0.28, 0.14), S._iso(c, tw, -0.29, 0.28, 0.14), _f(RESCUE, state), 2.0)
			for u in [-0.40, -0.34]:
				ci.draw_line(S._iso(c, tw, u, 0.28, 0.14), S._iso(c, tw, u, 0.28, 0.05), md, 1.0)
			ci.draw_line(S._iso(c, tw, -0.26, 0.40, 0.12), S._iso(c, tw, -0.42, 0.44, 0.01), _f(S.CYAN, state), tw * 0.02)
			ci.draw_line(S._iso(c, tw, -0.26, 0.40, 0.0), S._iso(c, tw, -0.26, 0.40, 0.12), md, 1.5)
		"hazlab":
			var orb := S._iso(c, tw, 0, 0, 0.05 + h * 0.45)
			S._glow(ci, orb, tw * 0.06, _f(LIME, state), state)
			_blast_wall(ci, c, tw, r, state, false)
			S._glow(ci, apex - Vector2(0, tw * 0.02), tw * 0.02, _f(S.HAZARD, state), state)
		"garden":
			var floor_c := S._iso(c, tw, 0, 0, 0.06)
			ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, 0.12, 0.12, 0.06), r * tw * 0.22, r * tw * 0.11), _f(S.WATER, state).darkened(0.1))
			for p in [Vector2(-0.2, -0.12), Vector2(-0.04, -0.24), Vector2(0.18, -0.14), Vector2(-0.22, 0.14), Vector2(0.0, 0.22)]:
				var foot := S._iso(c, tw, p.x, p.y, 0.06)
				ci.draw_line(foot, foot - Vector2(0, tw * 0.07), _f(Color(0.4, 0.3, 0.2), state), tw * 0.012)
				S._iso_sphere(ci, foot - Vector2(0, tw * 0.10), tw * 0.05, _f(Color(0.32, 0.68, 0.34), state))
			for k in 3:
				ci.draw_circle(floor_c + Vector2(-tw * 0.06 + k * tw * 0.04, tw * 0.03), tw * 0.008, _f([S.PINK, S.GOLD, S.WHITE][k], state))
		"lounge":
			var cols := [S.PINK, S.CYAN, S.GOLD, S.VIOLET]
			for i in 3:
				for j in 3:
					var u := -0.15 + i * 0.1
					var v := -0.15 + j * 0.1
					ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, u, v, 0.06), S._iso(c, tw, u + 0.09, v, 0.06), S._iso(c, tw, u + 0.09, v + 0.09, 0.06), S._iso(c, tw, u, v + 0.09, 0.06)]), _f(cols[(i + j) % 4], state) * Color(1, 1, 1, 0.85))
			S._glow(ci, apex + Vector2(0, tw * 0.03), tw * 0.02, _f(S.PINK, state), state)
			S._box(ci, c, tw, -0.48, 0.28, -0.26, 0.32, 0.12, md, Color(0, 0, 0, 0), 0.04)
			S._glow(ci, S._iso(c, tw, -0.40, 0.30, 0.12), tw * 0.02, _f(S.PINK, state), state)
			S._glow(ci, S._iso(c, tw, -0.32, 0.30, 0.12), tw * 0.02, _f(S.CYAN, state), state)


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


# ============================================================ units

## Draws a drone or satellite at an angle, centred on c, about tw pixels wide.
static func draw_unit(ci: CanvasItem, type: String, c: Vector2, tw: float) -> void:
	var st := {}
	var md := S.METAL_DARK
	var m := S.METAL
	var yel := S.HAZARD
	var tyre := Color(0.08, 0.08, 0.09)
	match type:
		"grader":
			_tracks(ci, c, tw)
			S._box(ci, c, tw, -0.16, -0.10, 0.12, 0.10, 0.10, yel, Color(0, 0, 0, 0), 0.06)
			S._box(ci, c, tw, -0.12, -0.07, 0.02, 0.07, 0.08, md, S.GLASS.lightened(0.2), 0.16)
			# The wide blade at the front.
			ci.draw_colored_polygon(PackedVector2Array([S._iso(c, tw, 0.22, -0.20, 0.02), S._iso(c, tw, 0.22, 0.20, 0.02), S._iso(c, tw, 0.20, 0.20, 0.14), S._iso(c, tw, 0.20, -0.20, 0.14)]), m.lightened(0.15))
			ci.draw_line(S._iso(c, tw, 0.12, 0.0, 0.09), S._iso(c, tw, 0.20, 0.0, 0.08), md, tw * 0.02)
			S._glow(ci, S._iso(c, tw, -0.05, 0.0, 0.26), tw * 0.015, S.AMBER, st)
		"borer":
			_tracks(ci, c, tw)
			S._box(ci, c, tw, -0.18, -0.10, 0.06, 0.10, 0.14, yel.darkened(0.1), Color(0, 0, 0, 0), 0.06)
			# The drill cone, pointing forward, with its spiral.
			var tipp := S._iso(c, tw, 0.36, 0.0, 0.12)
			var b0 := S._iso(c, tw, 0.06, -0.09, 0.12)
			var b1 := S._iso(c, tw, 0.06, 0.09, 0.12)
			var b2 := S._iso(c, tw, 0.06, 0.0, 0.22)
			var b3 := S._iso(c, tw, 0.06, 0.0, 0.02)
			ci.draw_colored_polygon(Geometry2D.convex_hull(PackedVector2Array([tipp, b0, b1, b2, b3])), m.lightened(0.2))
			for k in 4:
				var t := 0.15 + k * 0.2
				ci.draw_line(b2.lerp(tipp, t), b3.lerp(tipp, t + 0.08), md, 1.5)
			S._glow(ci, S._iso(c, tw, -0.1, 0.0, 0.24), tw * 0.015, S.AMBER, st)
		"prospector":
			for u in [-0.14, 0.0, 0.14]:
				for v in [-0.10, 0.10]:
					ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, u, v, 0.04), tw * 0.035, tw * 0.035), tyre)
			S._box(ci, c, tw, -0.18, -0.09, 0.18, 0.09, 0.06, S.WHITE.darkened(0.1), Color(0, 0, 0, 0), 0.05)
			ci.draw_line(S._iso(c, tw, -0.1, -0.05, 0.11), S._iso(c, tw, -0.1, -0.05, 0.36), md, 2.0)
			ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, -0.1, -0.05, 0.38), tw * 0.05, tw * 0.03), S.WHITE)
			S._glow(ci, S._iso(c, tw, -0.1, -0.05, 0.38), tw * 0.012, S.CYAN, st)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, 0.14, 0.05, 0.11), S._iso(c, tw, 0.24, 0.05, 0.16), S._iso(c, tw, 0.30, 0.08, 0.04)]), md, 2.0)
			S._glow(ci, S._iso(c, tw, 0.30, 0.08, 0.04), tw * 0.012, S.TEAL, st)
		"hauler":
			for u in [-0.2, -0.04, 0.16]:
				for v in [-0.12, 0.12]:
					ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, u, v, 0.045), tw * 0.04, tw * 0.04), tyre)
			S._box(ci, c, tw, -0.26, -0.11, 0.24, 0.11, 0.05, md, Color(0, 0, 0, 0), 0.05)
			S._box(ci, c, tw, 0.10, -0.10, 0.24, 0.10, 0.12, yel, Color(0, 0, 0, 0), 0.10)
			S._box(ci, c, tw, -0.26, -0.11, 0.06, 0.11, 0.10, m, Color(0, 0, 0, 0), 0.10)
			for k in 6:
				S._iso_sphere(ci, S._iso(c, tw, -0.22 + (k % 3) * 0.1, -0.05 + (k / 3) * 0.1, 0.22), tw * 0.03, S.TEAL if k % 2 == 0 else Color(0.45, 0.43, 0.41))
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


## Caterpillar tracks under a tracked drone.
static func _tracks(ci: CanvasItem, c: Vector2, tw: float) -> void:
	for v in [-0.13, 0.13]:
		S._box(ci, c, tw, -0.22, v - 0.04, 0.18, v + 0.04, 0.07, Color(0.12, 0.12, 0.13))
		for k in 5:
			var u := -0.2 + k * 0.09
			ci.draw_line(S._iso(c, tw, u, v + 0.04, 0.0), S._iso(c, tw, u, v + 0.04, 0.07), Color(0.3, 0.3, 0.32), 1.0)


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
