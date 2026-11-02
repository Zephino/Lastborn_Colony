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
			# A heap of mixed junk at the back-right, carried into the dome on a conveyor.
			var junk := [Color(0.62, 0.55, 0.45), Color(0.50, 0.52, 0.58), Color(0.70, 0.36, 0.30), Color(0.40, 0.58, 0.45), Color(0.75, 0.70, 0.40)]
			var heap := c + Vector2(s * 0.36, -s * 0.36)
			for k in 11:
				var off := Vector2.from_angle(k * 2.3) * s * (0.03 + (k % 4) * 0.025)
				S._rot_rect(ci, heap + off, Vector2.from_angle(k * 1.7), s * 0.07, s * 0.045, _f(junk[k % 5], state))
			S._rot_rect(ci, c.lerp(heap, 0.55), Vector2(1, -1), s * 0.26, s * 0.08, md)
			for k in 4:
				S._rot_rect(ci, c.lerp(heap, 0.42 + k * 0.08), Vector2(1, 1), s * 0.08, s * 0.01, m)
			# A tank of recovered water at the back-left.
			ci.draw_circle(c + Vector2(-s * 0.38, -s * 0.38), s * 0.085, md)
			ci.draw_circle(c + Vector2(-s * 0.38, -s * 0.38), s * 0.065, _f(S.WATER, state).darkened(0.2))
			# Crushed-scrap bales at the front-left, strapped.
			for k in 3:
				var bale := Rect2(c + Vector2(-s * (0.48 - (k % 2) * 0.12), s * (0.27 + (k / 2) * 0.11)), Vector2(s * 0.11, s * 0.10))
				ci.draw_rect(bale, _f(junk[(k + 1) % 5], state).darkened(0.1))
				ci.draw_line(Vector2(bale.position.x, bale.get_center().y), Vector2(bale.end.x, bale.get_center().y), md, 1.0)
				ci.draw_rect(bale, md, false, 1.0)
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
		"mast":
			# Guy wires from the mast to three anchors.
			for ang in [200.0, 320.0, 80.0]:
				var anchor := c + Vector2.from_angle(deg_to_rad(ang)) * s * 0.46
				ci.draw_line(c, anchor, _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
				ci.draw_rect(Rect2(anchor - Vector2(s * 0.025, s * 0.025), Vector2(s * 0.05, s * 0.05)), md)
		"rescue":
			# A stack of brace beams at the back, and the rescue rover parked by the bay door.
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * (0.47 - k * 0.05)), Vector2(s * 0.26, s * 0.035)), _f(S.HAZARD, state).darkened(0.15))
			_top_rover(ci, c + Vector2(0, s * 0.41), s, _f(RESCUE, state), state)
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
		"lounge":
			# A neon sign on a post at the front-left, and string lights round the dome.
			var sign := Rect2(c + Vector2(-s * 0.48, s * 0.30), Vector2(s * 0.22, s * 0.1))
			ci.draw_rect(sign, md)
			ci.draw_rect(sign, _f(S.PINK, state), false, 1.5)
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
			# The shredder: two toothed rollers.
			for k in 2:
				var roll := Rect2(c + Vector2(-rad * 0.5, -rad * 0.38 + k * rad * 0.24), Vector2(rad * 0.62, rad * 0.18))
				ci.draw_rect(roll, m.lightened(0.1))
				for t in 6:
					var x := roll.position.x + rad * 0.05 + t * rad * 0.1
					ci.draw_line(Vector2(x, roll.position.y), Vector2(x, roll.end.y), md, 1.0)
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
			# A red roll-up bay door on the front, a red stripe along the roof,
			# and red and blue beacons on the ridge.
			var hw := rad * 0.82
			var door := Rect2(c + Vector2(-s * 0.14, hw - s * 0.05), Vector2(s * 0.28, s * 0.07))
			ci.draw_rect(door, _f(RESCUE, state))
			for k in 4:
				ci.draw_line(Vector2(door.position.x, door.position.y + k * s * 0.018), Vector2(door.end.x, door.position.y + k * s * 0.018), _f(RESCUE, state).darkened(0.3), 1.0)
			ci.draw_line(c + Vector2(-rad * 1.2, 0), c + Vector2(rad * 1.2, 0), _f(RESCUE, state), maxf(2.0, s * 0.025))
			S._glow(ci, c + Vector2(-s * 0.08, -hw * 0.3), s * 0.022, _f(RESCUE, state), state)
			S._glow(ci, c + Vector2(s * 0.08, -hw * 0.3), s * 0.022, _f(Color(0.35, 0.55, 1.0), state), state)
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
			# A glowing dance floor, a round bar, a neon rim and string lights.
			var cols := [S.PINK, S.CYAN, S.GOLD, S.VIOLET]
			for i in 3:
				for j in 3:
					ci.draw_rect(Rect2(c + Vector2(-rad * 0.36 + i * rad * 0.24, -rad * 0.36 + j * rad * 0.24), Vector2(rad * 0.22, rad * 0.22)), _f(cols[(i + j) % 4], state) * Color(1, 1, 1, 0.8))
			ci.draw_arc(c, rad * 0.62, deg_to_rad(20), deg_to_rad(160), 12, _f(Color(0.55, 0.38, 0.26), state), maxf(3.0, s * 0.05))
			ci.draw_arc(c, rad * 0.96, 0, TAU, 40, _f(S.PINK, state), maxf(2.5, s * 0.03))
			for k in 12:
				S._glow(ci, c + Vector2.from_angle(k * TAU / 12.0 + 0.13) * rad * 0.80, s * 0.012, _f(cols[k % 4], state), state)

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
			# A tank of recovered water at the back.
			S._cyl(ci, c, tw, -0.36, -0.36, 0.12, 0.26, _f(S.WATER, state).darkened(0.25), _f(S.WATER, state).darkened(0.05))
			# A heap of mixed junk at the right, and a conveyor carrying it up into the dome.
			var junk := [Color(0.62, 0.55, 0.45), Color(0.50, 0.52, 0.58), Color(0.70, 0.36, 0.30), Color(0.40, 0.58, 0.45), Color(0.75, 0.70, 0.40)]
			for k in 14:
				var layer := 0 if k < 8 else (1 if k < 12 else 2)
				var ang := k * 2.3
				var rr := 0.10 - layer * 0.035
				S._iso_sphere(ci, S._iso(c, tw, 0.36 + cos(ang) * rr, -0.36 + sin(ang) * rr, 0.02 + layer * 0.045), tw * 0.03, _f(junk[k % 5], state))
			var belt := PackedVector2Array([S._iso(c, tw, 0.30, -0.24, 0.06), S._iso(c, tw, 0.24, -0.30, 0.06), S._iso(c, tw, 0.10, -0.16, 0.20), S._iso(c, tw, 0.16, -0.10, 0.20)])
			ci.draw_colored_polygon(belt, md)
			for k in 4:
				var t := 0.2 + k * 0.2
				ci.draw_line(belt[0].lerp(belt[3], t), belt[1].lerp(belt[2], t), m, 1.0)
			for k in 2:
				S._iso_sphere(ci, belt[0].lerp(belt[2], 0.3 + k * 0.35) - Vector2(0, tw * 0.015), tw * 0.018, _f(junk[k + 2], state))

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
		"mast":
			for ang in [200.0, 320.0]:
				var q := Vector2.from_angle(deg_to_rad(ang)) * 0.46
				ci.draw_line(S._iso(c, tw, 0, 0, 0.75), S._iso(c, tw, q.x, q.y), _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
		"rescue":
			for k in 3:
				S._box(ci, c, tw, -0.48, -0.47 + k * 0.05, -0.22, -0.44 + k * 0.05, 0.03, _f(S.HAZARD, state).darkened(0.15), Color(0, 0, 0, 0), k * 0.03)
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
			# Inside: the shredder's two toothed rollers, with a green glow below.
			var mid := S._iso(c, tw, 0, 0, 0.10)
			S._glow(ci, mid + Vector2(0, tw * 0.02), tw * 0.03, _f(S.GREEN, state), state)
			for k in 2:
				var roller := S._iso(c, tw, 0, -0.06 + k * 0.09) - c + c
				S._iso_tube(ci, roller, tw, 0, -0.14, 0.14, 0.035, 0.12, m.lightened(0.05))
				for t in 5:
					var u := -0.12 + t * 0.06
					ci.draw_line(S._iso(c, tw, u, -0.06 + k * 0.09, 0.12) - Vector2(0, tw * 0.03), S._iso(c, tw, u, -0.06 + k * 0.09, 0.12) - Vector2(0, tw * 0.045), md, 1.5)
			# Crushed-scrap bales stacked at the left, strapped.
			var junk := [Color(0.62, 0.55, 0.45), Color(0.50, 0.52, 0.58), Color(0.70, 0.36, 0.30), Color(0.40, 0.58, 0.45), Color(0.75, 0.70, 0.40)]
			for k in 3:
				var u := -0.48 + (k % 2) * 0.11
				var v := 0.28 + (k / 2) * 0.04
				var z := (k / 2) * 0.09
				S._box(ci, c, tw, u, v, u + 0.10, v + 0.10, 0.09, _f(junk[(k + 1) % 5], state).darkened(0.1), Color(0, 0, 0, 0), z)
				ci.draw_line(S._iso(c, tw, u + 0.10, v, z + 0.045), S._iso(c, tw, u + 0.10, v + 0.10, z + 0.045), md, 1.5)
				ci.draw_line(S._iso(c, tw, u, v + 0.10, z + 0.045), S._iso(c, tw, u + 0.10, v + 0.10, z + 0.045), md, 1.5)
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
		"mast":
			# A lattice mast, wide at the foot, with two dishes, a red light on top
			# and signal waves.
			var top := S._iso(c, tw, 0, 0, 0.85)
			var foot := S._iso(c, tw, 0, 0, h)
			var w0 := tw * 0.055
			for side in [-1.0, 1.0]:
				ci.draw_line(foot + Vector2(side * w0, 0), top + Vector2(side * tw * 0.008, 0), md.lightened(0.25), 2.0)
			for k in 8:
				var t0 := float(k) / 8.0
				var t1 := float(k + 1) / 8.0
				var a0 := w0 * (1.0 - t0) + tw * 0.008 * t0
				var a1 := w0 * (1.0 - t1) + tw * 0.008 * t1
				var sd := 1.0 if k % 2 == 0 else -1.0
				ci.draw_line(foot.lerp(top, t0) + Vector2(-a0 * sd, 0), foot.lerp(top, t1) + Vector2(a1 * sd, 0), m, 1.0)
				ci.draw_line(foot.lerp(top, t1) + Vector2(-a1, 0), foot.lerp(top, t1) + Vector2(a1, 0), m.darkened(0.2), 1.0)
			for p in [[0.45, 1.0], [0.68, -1.0]]:
				var at: Vector2 = foot.lerp(top, p[0])
				var side: float = p[1]
				var dish: Vector2 = at + Vector2(side * tw * 0.07, 0)
				ci.draw_line(at, dish, md, 2.0)
				ci.draw_colored_polygon(S._ellipse(dish, tw * 0.028, tw * 0.05), _f(S.WHITE, state).darkened(0.05))
				ci.draw_colored_polygon(S._ellipse(dish + Vector2(side * tw * 0.006, 0), tw * 0.018, tw * 0.036), _f(S.WHITE, state).darkened(0.25))
				ci.draw_line(dish, dish + Vector2(side * tw * 0.04, 0), md, 1.0)
				ci.draw_circle(dish + Vector2(side * tw * 0.04, 0), 1.5, md)
			S._glow(ci, top, tw * 0.016, _f(Color(1.0, 0.3, 0.3), state), state)
			for k in 3:
				ci.draw_arc(top, tw * (0.07 + k * 0.05), deg_to_rad(-70), deg_to_rad(-20), 6, _f(S.CYAN, state) * Color(1, 1, 1, 0.8 - k * 0.2), 1.5)
			var q := Vector2.from_angle(deg_to_rad(80.0)) * 0.46
			ci.draw_line(S._iso(c, tw, 0, 0, 0.75), S._iso(c, tw, q.x, q.y), _f(Color(0.75, 0.78, 0.84, 0.7), state), 1.0)
		"rescue":
			# A red roll-up bay door in the hall's curved side, a red stripe,
			# red and blue beacons on the roof, and the rescue rover out front.
			var dims := Vector2(r * 1.3, r * 0.82)
			var red := _f(RESCUE, state)
			var z0 := 0.03
			var pts := PackedVector2Array()
			for k in 6:
				var ang := deg_to_rad(70.0 * k / 5.0)
				pts.append(S._isov(c, tw, -0.15, dims.y * cos(ang), z0 + dims.y * sin(ang)))
			for k in 6:
				var ang := deg_to_rad(70.0 * (5 - k) / 5.0)
				pts.append(S._isov(c, tw, 0.15, dims.y * cos(ang), z0 + dims.y * sin(ang)))
			ci.draw_colored_polygon(pts, red)
			for k in range(1, 5):
				var ang := deg_to_rad(70.0 * k / 5.0)
				ci.draw_line(S._isov(c, tw, -0.15, dims.y * cos(ang), z0 + dims.y * sin(ang)), S._isov(c, tw, 0.15, dims.y * cos(ang), z0 + dims.y * sin(ang)), red.darkened(0.3), 1.0)
			ci.draw_line(S._isov(c, tw, -dims.x, dims.y * cos(1.1), z0 + dims.y * sin(1.1)), S._isov(c, tw, dims.x, dims.y * cos(1.1), z0 + dims.y * sin(1.1)), red, maxf(2.0, tw * 0.014))
			var ridge := z0 + dims.y
			S._glow(ci, S._isov(c, tw, -0.08, 0, ridge + 0.02), tw * 0.02, red, state)
			S._glow(ci, S._isov(c, tw, 0.08, 0, ridge + 0.02), tw * 0.02, _f(Color(0.35, 0.55, 1.0), state), state)
			_iso_rover(ci, c, tw, S._va(0.0, 0.41), red, state)
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
			# A neon rim round the foot of the dome, and string lights draped across it.
			var base := S._iso(c, tw, 0, 0, 0.05)
			var rx := r * tw * 0.72
			ci.draw_polyline(S._ellipse(base, rx * 1.0, rx * 0.5, 0, 180, 20), _f(S.PINK, state), maxf(2.5, tw * 0.018))
			for row in 2:
				var t: float = [0.35, 0.7][row]
				var ring := base - Vector2(0, h * tw * t)
				var k_r := sqrt(1.0 - t * t)
				for k in 9:
					var ang := deg_to_rad(10.0 + k * 20.0)
					S._glow(ci, ring + Vector2(cos(ang) * rx * k_r, sin(ang) * rx * 0.5 * k_r), tw * 0.008, _f(cols[(k + row) % 4], state), state)
			S._glow(ci, apex + Vector2(0, tw * 0.03), tw * 0.02, _f(S.PINK, state), state)
			# A neon sign on a post at the left.
			ci.draw_line(S._iso(c, tw, -0.38, 0.32), S._iso(c, tw, -0.38, 0.32, 0.18), md, tw * 0.012)
			S._box(ci, c, tw, -0.48, 0.30, -0.28, 0.34, 0.10, md, Color(0, 0, 0, 0), 0.18)
			ci.draw_polyline(PackedVector2Array([S._iso(c, tw, -0.48, 0.34, 0.19), S._iso(c, tw, -0.28, 0.34, 0.19), S._iso(c, tw, -0.28, 0.34, 0.27), S._iso(c, tw, -0.48, 0.34, 0.27), S._iso(c, tw, -0.48, 0.34, 0.19)]), _f(S.PINK, state), 1.5)
			S._glow(ci, S._iso(c, tw, -0.42, 0.34, 0.23), tw * 0.018, _f(S.PINK, state), state)
			S._glow(ci, S._iso(c, tw, -0.34, 0.34, 0.23), tw * 0.018, _f(S.CYAN, state), state)

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

## The colony's lander standing on the Landing Pad: four splayed legs with
## footpads, a gold-foil engine section with its nozzle, a white body with an
## orange band and a ring of lit portholes, a rounded nose with a red light,
## and a hatch with its ramp down to the pad.
static func draw_lander(ci: CanvasItem, c: Vector2, tw: float, state: Dictionary) -> void:
	var white := _f(Color(0.92, 0.93, 0.95), state)
	var shade := _f(Color(0.70, 0.72, 0.76), state)
	var gold := _f(Color(0.85, 0.66, 0.25), state)
	var orange := _f(S.ORANGE, state)
	var md := _f(S.METAL_DARK, state)
	var pad_z := 0.05
	# Scorch on the pad under the engine.
	ci.draw_colored_polygon(S._ellipse(S._iso(c, tw, 0, 0, pad_z), tw * 0.16, tw * 0.08), Color(0.05, 0.05, 0.05, 0.35 * white.a))
	# Legs: the two at the back first.
	var legs := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for k in 4:
		var q: Vector2 = legs[k].normalized()
		if q.x + q.y > 0.0:
			continue
		_lander_leg(ci, c, tw, q, pad_z, shade, md)
	# The engine nozzle and the gold-foil engine section.
	S._cyl(ci, c, tw, 0, 0, 0.06, 0.05, md, md.darkened(0.3), pad_z + 0.02)
	S._cyl(ci, c, tw, 0, 0, 0.11, 0.07, gold, gold.lightened(0.15), pad_z + 0.07)
	for k in 5:
		var ang := deg_to_rad(20.0 + k * 35.0)
		var base := S._iso(c, tw, 0, 0, pad_z + 0.07)
		ci.draw_line(base + Vector2(cos(ang) * 0.11 * tw * 0.72, sin(ang) * 0.11 * tw * 0.36), base + Vector2(cos(ang) * 0.11 * tw * 0.72, sin(ang) * 0.11 * tw * 0.36 - 0.07 * tw), gold.darkened(0.25), 1.0)
	# The body.
	var body_z := pad_z + 0.14
	var body_h := 0.30
	var base_b := S._iso(c, tw, 0, 0, body_z)
	var rx := 0.10 * tw * 0.72
	var body := S._ellipse(base_b, rx, rx * 0.5, 0, 180, 14)
	body.append_array(S._ellipse(base_b - Vector2(0, body_h * tw), rx, rx * 0.5, 180, 0, 14))
	ci.draw_colored_polygon(body, white)
	# Shade the right side so it reads as round.
	ci.draw_colored_polygon(PackedVector2Array([base_b + Vector2(rx * 0.35, rx * 0.47), base_b + Vector2(rx, 0), base_b + Vector2(rx, -body_h * tw), base_b + Vector2(rx * 0.35, rx * 0.47 - body_h * tw)]), shade)
	ci.draw_polyline(S._ellipse(base_b - Vector2(0, body_h * tw * 0.30), rx, rx * 0.5, 0, 180, 14), orange, maxf(2.0, tw * 0.016))
	# Portholes round the upper body.
	for k in 4:
		var ang := deg_to_rad(35.0 + k * 37.0)
		var p := base_b - Vector2(0, body_h * tw * 0.65) + Vector2(cos(ang) * rx * 0.95, sin(ang) * rx * 0.47)
		ci.draw_circle(p, maxf(1.5, tw * 0.011), md)
		ci.draw_circle(p, maxf(1.0, tw * 0.007), _f(Color(1.0, 0.85, 0.5), state))
	# The rounded nose and its light.
	var top := base_b - Vector2(0, body_h * tw)
	var nose := S._ellipse(top, rx, rx * 0.5, 0, 180, 14)
	nose.append_array(S._ellipse(top, rx, tw * 0.10, 180, 360, 14))
	ci.draw_colored_polygon(nose, white)
	ci.draw_arc(top - Vector2(rx * 0.3, tw * 0.05), rx * 0.35, deg_to_rad(200), deg_to_rad(260), 6, Color(1, 1, 1, 0.8 * white.a), 1.5)
	S._glow(ci, top - Vector2(0, tw * 0.10), tw * 0.012, _f(Color(1.0, 0.3, 0.3), state), state)
	# The hatch facing forward, and its ramp down to the pad.
	var hatch := base_b + Vector2(rx * 0.25, rx * 0.47)
	ci.draw_colored_polygon(PackedVector2Array([hatch + Vector2(-tw * 0.022, 0), hatch + Vector2(tw * 0.022, 0), hatch + Vector2(tw * 0.022, -tw * 0.07), hatch + Vector2(-tw * 0.022, -tw * 0.07)]), md)
	ci.draw_colored_polygon(PackedVector2Array([hatch + Vector2(-tw * 0.018, -tw * 0.005), hatch + Vector2(tw * 0.018, -tw * 0.005), hatch + Vector2(tw * 0.018, -tw * 0.062), hatch + Vector2(-tw * 0.018, -tw * 0.062)]), _f(Color(1.0, 0.85, 0.5), state))
	ci.draw_colored_polygon(PackedVector2Array([hatch + Vector2(-tw * 0.022, 0), hatch + Vector2(tw * 0.022, 0), S._iso(c, tw, 0.30, 0.30, pad_z) + Vector2(tw * 0.05, 0), S._iso(c, tw, 0.30, 0.30, pad_z) + Vector2(-tw * 0.05, 0)]), shade.darkened(0.1))
	# The two front legs.
	for k in 4:
		var q: Vector2 = legs[k].normalized()
		if q.x + q.y <= 0.0:
			continue
		_lander_leg(ci, c, tw, q, pad_z, shade, md)


static func _lander_leg(ci: CanvasItem, c: Vector2, tw: float, q: Vector2, pad_z: float, col: Color, dark: Color) -> void:
	var hip := S._iso(c, tw, q.x * 0.09, q.y * 0.09, pad_z + 0.16)
	var knee := S._iso(c, tw, q.x * 0.20, q.y * 0.20, pad_z + 0.10)
	var foot := S._iso(c, tw, q.x * 0.24, q.y * 0.24, pad_z)
	ci.draw_polyline(PackedVector2Array([hip, knee, foot]), dark, maxf(2.0, tw * 0.018))
	ci.draw_polyline(PackedVector2Array([hip, knee, foot]), col, maxf(1.0, tw * 0.008))
	ci.draw_line(S._iso(c, tw, q.x * 0.10, q.y * 0.10, pad_z + 0.09), knee, dark, maxf(1.0, tw * 0.008))
	ci.draw_colored_polygon(S._ellipse(foot, tw * 0.03, tw * 0.015), dark)


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
