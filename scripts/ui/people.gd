## Colonists in space suits, and the small resource icons used in the top bar.
## Drawn in code like every other sprite (see sprites.gd).
extends RefCounted

const SUIT := Color(0.90, 0.91, 0.93)
const SUIT_SHADE := Color(0.70, 0.72, 0.76)
const VISOR := Color(0.95, 0.72, 0.25)
const PACK := Color(0.45, 0.48, 0.54)
const WARDEN_SUIT := Color(0.30, 0.36, 0.50)
## Stripe colour by job.
const JOBS := {"worker": Color(1.0, 0.55, 0.20), "scientist": Color(0.30, 0.82, 0.76), "warden": Color(0.72, 0.56, 1.0)}


## A colonist in a space suit standing at `feet`, `hgt` pixels tall, facing
## left (-1) or right (1), mid-stride or standing.
static func draw_colonist(ci: CanvasItem, feet: Vector2, hgt: float, job: String = "worker", facing: float = 1.0, stride: bool = false) -> void:
	var u := hgt / 10.0
	var stripe: Color = JOBS.get(job, JOBS["worker"])
	# Wardens wear dark navy security suits; everyone else white.
	var suit := WARDEN_SUIT if job == "warden" else SUIT
	var shade := WARDEN_SUIT.darkened(0.3) if job == "warden" else SUIT_SHADE
	ci.draw_colored_polygon(_oval(feet, u * 2.4, u * 0.8), Color(0, 0, 0, 0.30))
	# Backpack (behind the body, on the side away from where they face).
	var pack := feet + Vector2(-facing * u * 2.2, -u * 5.1)
	_back_gear(ci, pack, u, job, facing)
	ci.draw_rect(Rect2(pack + Vector2(-u * 0.9, -u * 1.5), Vector2(u * 1.8, u * 3.0)), PACK)
	ci.draw_rect(Rect2(pack + Vector2(-u * 0.9, -u * 1.5), Vector2(u * 1.8, u * 0.6)), PACK.lightened(0.2))
	_pack_front(ci, pack, u, job, facing)
	# Legs, one forward when walking.
	var step := u * 0.9 if stride else 0.0
	ci.draw_line(feet + Vector2(-u * 0.6, -u * 3.2), feet + Vector2(-u * 0.6 - step * facing, -u * 0.4), shade, u * 1.3)
	ci.draw_line(feet + Vector2(u * 0.6, -u * 3.2), feet + Vector2(u * 0.6 + step * facing, -u * 0.4), suit, u * 1.3)
	for x in [-u * 0.6 - step * facing, u * 0.6 + step * facing]:
		ci.draw_rect(Rect2(feet + Vector2(x - u * 0.7, -u * 0.6), Vector2(u * 1.4, u * 0.6)), Color(0.25, 0.26, 0.30))
	# Body with its job stripe.
	ci.draw_rect(Rect2(feet + Vector2(-u * 1.5, -u * 6.8), Vector2(u * 3.0, u * 3.8)), suit)
	ci.draw_rect(Rect2(feet + Vector2(u * 0.6, -u * 6.8), Vector2(u * 0.9, u * 3.8)), shade)
	if job == "worker":
		# A hi-vis vest with silver reflective stripes, and a tool belt with pouches.
		var vest := JOBS["worker"]
		ci.draw_rect(Rect2(feet + Vector2(-u * 1.5, -u * 6.8), Vector2(u * 3.0, u * 3.0)), vest)
		ci.draw_rect(Rect2(feet + Vector2(-u * 0.3, -u * 6.8), Vector2(u * 0.6, u * 3.0)), suit)
		ci.draw_rect(Rect2(feet + Vector2(u * 0.6, -u * 6.8), Vector2(u * 0.9, u * 3.0)), vest.darkened(0.2))
		for y in [-u * 5.6, -u * 4.6]:
			ci.draw_line(feet + Vector2(-u * 1.5, y), feet + Vector2(u * 1.5, y), Color(0.86, 0.88, 0.92), maxf(1.0, u * 0.35))
		ci.draw_rect(Rect2(feet + Vector2(-u * 1.6, -u * 3.6), Vector2(u * 3.2, u * 0.6)), Color(0.42, 0.30, 0.18))
		for x in [-u * 1.3, u * 0.5]:
			ci.draw_rect(Rect2(feet + Vector2(x, -u * 3.3), Vector2(u * 0.8, u * 0.9)), Color(0.50, 0.36, 0.22))
	else:
		ci.draw_rect(Rect2(feet + Vector2(-u * 1.5, -u * 5.2), Vector2(u * 3.0, u * 0.7)), stripe)
	# Arms, swinging a little when walking.
	var swing := u * 0.8 if stride else 0.2 * u
	ci.draw_line(feet + Vector2(-u * 1.6, -u * 6.4), feet + Vector2(-u * 1.9 + swing * facing, -u * 4.0), shade, u * 1.0)
	ci.draw_line(feet + Vector2(u * 1.6, -u * 6.4), feet + Vector2(u * 1.9 - swing * facing, -u * 4.0), suit, u * 1.0)
	if job == "worker":
		# A yellow power drill in the forward hand.
		var grip := feet + Vector2(facing * (u * 1.9 - swing), -u * 4.0)
		ci.draw_rect(Rect2(grip + Vector2(-u * 0.35, -u * 0.2), Vector2(u * 0.7, u * 1.0)), Color(0.20, 0.20, 0.24))
		var body_x := grip.x if facing > 0.0 else grip.x - u * 1.8
		ci.draw_rect(Rect2(Vector2(body_x, grip.y - u * 0.9), Vector2(u * 1.8, u * 0.8)), Color(0.98, 0.80, 0.18))
		ci.draw_line(grip + Vector2(facing * u * 1.8, -u * 0.5), grip + Vector2(facing * u * 2.6, -u * 0.5), Color(0.70, 0.72, 0.76), maxf(1.0, u * 0.3))
	if job == "warden":
		# A gold badge on the chest, and a torch in the forward hand shining ahead.
		var badge := feet + Vector2(-facing * u * 0.6, -u * 6.1)
		ci.draw_colored_polygon(PackedVector2Array([badge + Vector2(-u * 0.5, -u * 0.5), badge + Vector2(u * 0.5, -u * 0.5), badge + Vector2(u * 0.5, u * 0.1), badge + Vector2(0, u * 0.6), badge + Vector2(-u * 0.5, u * 0.1)]), Color(1.0, 0.80, 0.30))
		var hand := feet + Vector2(facing * (u * 1.9 - swing), -u * 4.0)
		ci.draw_line(hand, hand + Vector2(facing * u * 1.2, -u * 0.2), Color(0.20, 0.20, 0.24), u * 0.7)
		var lens := hand + Vector2(facing * u * 1.3, -u * 0.2)
		ci.draw_colored_polygon(PackedVector2Array([lens, lens + Vector2(facing * u * 4.5, -u * 1.4), lens + Vector2(facing * u * 4.5, u * 1.6)]), Color(1.0, 0.95, 0.7, 0.25))
		ci.draw_circle(lens, u * 0.35, Color(1.0, 0.95, 0.75))
	# Helmet with its visor.
	var head := feet + Vector2(0, -u * 8.2)
	ci.draw_circle(head, u * 1.75, suit)
	ci.draw_circle(head + Vector2(u * 0.35, u * 0.25), u * 1.4, shade.darkened(0.05))
	ci.draw_colored_polygon(_oval(head + Vector2(facing * u * 0.45, u * 0.05), u * 1.05, u * 0.75), VISOR)
	ci.draw_circle(head + Vector2(facing * u * 0.15 - u * 0.25, -u * 0.25), u * 0.28, Color(1, 1, 1, 0.75))
	ci.draw_line(head + Vector2(-u * 1.75, -u * 0.2), head + Vector2(-u * 1.95, -u * 1.6), shade, maxf(1.0, u * 0.3))
	if job == "worker":
		# A yellow hard-hat shell over the helmet, with a brim and a headlamp.
		var cap := PackedVector2Array()
		for i in 13:
			var a := deg_to_rad(180.0 + i * 15.0)
			cap.append(head + Vector2(cos(a) * u * 1.9, sin(a) * u * 1.9 - u * 0.15))
		ci.draw_colored_polygon(cap, Color(0.98, 0.80, 0.18))
		ci.draw_line(head + Vector2(-u * 2.2, -u * 0.15), head + Vector2(u * 2.2, -u * 0.15), Color(0.85, 0.66, 0.10), maxf(1.0, u * 0.45))
		ci.draw_line(head + Vector2(0, -u * 2.0), head + Vector2(0, -u * 0.3), Color(0.85, 0.66, 0.10), maxf(1.0, u * 0.3))
		var lamp := head + Vector2(facing * u * 1.5, -u * 0.9)
		ci.draw_circle(lamp, u * 0.42, Color(0.25, 0.25, 0.28))
		ci.draw_circle(lamp + Vector2(facing * u * 0.1, 0), u * 0.26, Color(1.0, 0.97, 0.80))


## Gear that sticks up behind the backpack, by job (drawn before the pack).
static func _back_gear(ci: CanvasItem, pack: Vector2, u: float, job: String, facing: float) -> void:
	match job:
		"worker":
			# A pickaxe slung across the back: a wooden handle, and a curved steel
			# head across its top that tapers to a point at each end.
			var low := pack + Vector2(facing * u * 1.1, u * 1.6)
			var top := pack + Vector2(-facing * u * 1.2, -u * 4.2)
			var along := (top - low).normalized()
			var across := along.orthogonal()
			ci.draw_line(low, top + along * u * 0.3, Color(0.55, 0.38, 0.22), u * 0.5)
			ci.draw_line(low, top + along * u * 0.3, Color(0.68, 0.50, 0.30), u * 0.18)
			var head := top + along * u * 0.2
			var upper := PackedVector2Array()
			var lower := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0 * 2.0 - 1.0
				var centre := head + across * t * u * 2.3 - along * t * t * u * 0.8
				var w := u * 0.45 * (1.0 - absf(t) * 0.92)
				upper.append(centre + along * w)
				lower.append(centre - along * w)
			lower.reverse()
			var blade := upper.duplicate()
			blade.append_array(lower)
			ci.draw_colored_polygon(blade, Color(0.66, 0.68, 0.72))
			ci.draw_polyline(upper, Color(0.88, 0.90, 0.94), maxf(1.0, u * 0.15))
			ci.draw_rect(Rect2(head - Vector2(u * 0.35, u * 0.35), Vector2(u * 0.7, u * 0.7)), Color(0.32, 0.33, 0.36))
		"scientist":
			# A tall antenna with a glowing tip, and a small dish.
			var mast_top := pack + Vector2(-facing * u * 0.4, -u * 6.2)
			ci.draw_line(pack + Vector2(-facing * u * 0.4, -u * 1.4), mast_top, Color(0.55, 0.58, 0.64), maxf(1.0, u * 0.3))
			ci.draw_circle(mast_top, u * 0.45, JOBS["scientist"])
			var dish := pack + Vector2(facing * u * 0.5, -u * 2.6)
			ci.draw_line(pack + Vector2(facing * u * 0.3, -u * 1.4), dish, Color(0.55, 0.58, 0.64), maxf(1.0, u * 0.3))
			ci.draw_colored_polygon(_oval(dish + Vector2(-facing * u * 0.2, -u * 0.3), u * 0.9, u * 0.5), Color(0.88, 0.90, 0.94))
		"warden":
			# A short radio aerial and a small red-and-blue light bar on top of the pack.
			var tip := pack + Vector2(-facing * u * 0.7, -u * 4.4)
			ci.draw_line(pack + Vector2(-facing * u * 0.7, -u * 1.4), tip, Color(0.25, 0.26, 0.30), maxf(1.0, u * 0.25))
			ci.draw_rect(Rect2(pack + Vector2(-u * 0.9, -u * 2.0), Vector2(u * 1.8, u * 0.55)), Color(0.20, 0.20, 0.24))
			ci.draw_rect(Rect2(pack + Vector2(-u * 0.8, -u * 1.95), Vector2(u * 0.75, u * 0.45)), Color(1.0, 0.30, 0.30))
			ci.draw_rect(Rect2(pack + Vector2(u * 0.05, -u * 1.95), Vector2(u * 0.75, u * 0.45)), Color(0.35, 0.55, 1.0))


## Things strapped on the side of the backpack, by job (drawn over the pack).
static func _pack_front(ci: CanvasItem, pack: Vector2, u: float, job: String, facing: float) -> void:
	match job:
		"worker":
			# A coiled orange hose on the pack.
			ci.draw_arc(pack + Vector2(0, u * 0.3), u * 0.6, 0, TAU, 10, JOBS["worker"], maxf(1.0, u * 0.35))
		"scientist":
			# Three coloured sample tubes in a holder.
			var cols := [Color(0.40, 0.95, 0.55), Color(0.35, 0.90, 1.0), Color(0.72, 0.56, 1.0)]
			for k in 3:
				var x := pack.x - u * 0.6 + k * u * 0.6
				ci.draw_rect(Rect2(Vector2(x - u * 0.2, pack.y - u * 0.2), Vector2(u * 0.4, u * 1.4)), cols[k])
			ci.draw_rect(Rect2(pack + Vector2(-u * 0.9, u * 0.9), Vector2(u * 1.8, u * 0.4)), Color(0.30, 0.32, 0.36))
		"warden":
			# Reflective stripes on the pack.
			ci.draw_line(pack + Vector2(-u * 0.9, u * 0.2), pack + Vector2(u * 0.9, u * 0.2), JOBS["warden"], maxf(1.0, u * 0.35))
			ci.draw_line(pack + Vector2(-u * 0.9, u * 0.9), pack + Vector2(u * 0.9, u * 0.9), JOBS["warden"], maxf(1.0, u * 0.35))


static func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A small icon for a resource or stat in the top bar, centred on c, s pixels across.
## Keys: pop, morale, power, heat, workers, food, oxygen, water, ore, alloy,
## parts, marks, debt, payment, turn.
static func draw_icon(ci: CanvasItem, key: String, c: Vector2, s: float) -> void:
	var u := s / 10.0
	match key:
		"pop":
			# A space helmet.
			ci.draw_circle(c, u * 4.2, SUIT)
			ci.draw_colored_polygon(_oval(c + Vector2(u * 0.8, u * 0.4), u * 2.6, u * 2.0), VISOR)
			ci.draw_circle(c + Vector2(-u * 0.2, -u * 0.6), u * 0.7, Color(1, 1, 1, 0.8))
		"workers":
			ci.draw_circle(c + Vector2(0, -u * 0.5), u * 3.6, SUIT)
			ci.draw_colored_polygon(_oval(c + Vector2(u * 0.6, 0), u * 2.2, u * 1.7), VISOR)
			ci.draw_rect(Rect2(c + Vector2(-u * 4.0, u * 2.8), Vector2(u * 8.0, u * 1.4)), JOBS["worker"])
		"morale":
			ci.draw_circle(c, u * 4.3, Color(1.0, 0.82, 0.30))
			ci.draw_circle(c + Vector2(-u * 1.5, -u * 1.0), u * 0.6, Color(0.2, 0.15, 0.1))
			ci.draw_circle(c + Vector2(u * 1.5, -u * 1.0), u * 0.6, Color(0.2, 0.15, 0.1))
			ci.draw_arc(c + Vector2(0, u * 0.3), u * 2.2, deg_to_rad(20), deg_to_rad(160), 8, Color(0.2, 0.15, 0.1), maxf(1.0, u * 0.6))
		"power":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 1.0, -u * 4.6), c + Vector2(-u * 2.6, u * 0.6), c + Vector2(-u * 0.2, u * 0.6), c + Vector2(-u * 1.0, u * 4.6), c + Vector2(u * 2.6, -u * 0.8), c + Vector2(u * 0.2, -u * 0.8)]), Color(1.0, 0.85, 0.25))
		"heat":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 4.6), c + Vector2(u * 3.0, u * 0.5), c + Vector2(u * 2.2, u * 3.6), c + Vector2(0, u * 4.4), c + Vector2(-u * 2.2, u * 3.6), c + Vector2(-u * 3.0, u * 0.5)]), Color(1.0, 0.45, 0.15))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 0.8), c + Vector2(u * 1.4, u * 1.8), c + Vector2(0, u * 3.4), c + Vector2(-u * 1.4, u * 1.8)]), Color(1.0, 0.85, 0.35))
		"food":
			# A bundle of kelp fronds.
			for k in 3:
				var x := (k - 1) * u * 1.6
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x, u * 4.4), c + Vector2(x - u * 1.2, -u * 1.0), c + Vector2(x + (k - 1) * u * 0.8, -u * 4.6), c + Vector2(x + u * 1.2, -u * 1.0)]), Color(0.30, 0.78, 0.40).lightened(0.1 * k))
			ci.draw_rect(Rect2(c + Vector2(-u * 2.6, u * 1.6), Vector2(u * 5.2, u * 1.0)), Color(0.75, 0.6, 0.35))
		"oxygen":
			# A gas bottle marked O2.
			ci.draw_rect(Rect2(c + Vector2(-u * 2.2, -u * 2.8), Vector2(u * 4.4, u * 7.2)), Color(0.45, 0.80, 1.0))
			ci.draw_circle(c + Vector2(0, -u * 2.8), u * 2.2, Color(0.45, 0.80, 1.0))
			ci.draw_rect(Rect2(c + Vector2(-u * 0.8, -u * 5.4), Vector2(u * 1.6, u * 1.4)), Color(0.4, 0.42, 0.48))
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(-u * 2.0, u * 2.6), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(6.0, u * 3.6)), Color(0.05, 0.2, 0.35))
		"water":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u * 4.8), c + Vector2(u * 2.6, -u * 0.4), c + Vector2(u * 3.2, u * 1.8), c + Vector2(u * 1.8, u * 4.0), c + Vector2(0, u * 4.6), c + Vector2(-u * 1.8, u * 4.0), c + Vector2(-u * 3.2, u * 1.8), c + Vector2(-u * 2.6, -u * 0.4)]), Color(0.35, 0.65, 1.0))
			ci.draw_arc(c + Vector2(-u * 0.8, u * 1.6), u * 1.6, deg_to_rad(110), deg_to_rad(200), 6, Color(1, 1, 1, 0.7), maxf(1.0, u * 0.6))
		"ore":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 4.2, u * 1.4), c + Vector2(-u * 2.6, -u * 2.8), c + Vector2(u * 1.0, -u * 4.0), c + Vector2(u * 4.2, -u * 0.6), c + Vector2(u * 3.0, u * 3.6), c + Vector2(-u * 1.6, u * 3.8)]), Color(0.45, 0.43, 0.41))
			ci.draw_line(c + Vector2(-u * 2.4, -u * 0.6), c + Vector2(u * 2.6, u * 1.2), Color(0.30, 0.85, 0.80), maxf(1.0, u * 0.9))
			ci.draw_line(c + Vector2(-u * 0.4, -u * 2.6), c + Vector2(u * 0.6, u * 2.6), Color(0.30, 0.85, 0.80), maxf(1.0, u * 0.6))
		"alloy":
			# A stack of ingots.
			for k in 2:
				var y := u * (1.6 - k * 3.2)
				var w := u * (8.4 - k * 2.0)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.5, y + u * 1.6), c + Vector2(w * 0.5, y + u * 1.6), c + Vector2(w * 0.38, y - u * 1.2), c + Vector2(-w * 0.38, y - u * 1.2)]), Color(0.80, 0.84, 0.90).darkened(0.12 * k))
				ci.draw_line(c + Vector2(-w * 0.38, y - u * 1.2), c + Vector2(w * 0.38, y - u * 1.2), Color(1, 1, 1, 0.8), maxf(1.0, u * 0.5))
		"parts":
			# A hex nut and a bolt.
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(i * TAU / 6.0) * u * 4.2)
			ci.draw_colored_polygon(hex, Color(0.40, 0.55, 0.72))
			ci.draw_circle(c, u * 1.8, Color(0.12, 0.14, 0.18))
		"marks":
			ci.draw_circle(c, u * 4.4, Color(0.95, 0.75, 0.25))
			ci.draw_circle(c, u * 3.3, Color(1.0, 0.85, 0.40))
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(-u * 2.0, u * 1.9), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(6.0, u * 5.0)), Color(0.55, 0.38, 0.10))
		"debt":
			# A paper bill with a red corner.
			ci.draw_rect(Rect2(c + Vector2(-u * 3.2, -u * 4.4), Vector2(u * 6.4, u * 8.8)), Color(0.92, 0.90, 0.84))
			for k in 3:
				ci.draw_line(c + Vector2(-u * 2.2, -u * 2.2 + k * u * 1.8), c + Vector2(u * 2.2, -u * 2.2 + k * u * 1.8), Color(0.45, 0.45, 0.45), maxf(1.0, u * 0.5))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 3.2, u * 1.4), c + Vector2(u * 3.2, u * 4.4), c + Vector2(u * 0.2, u * 4.4)]), Color(0.95, 0.35, 0.30))
		"payment", "turn":
			# A calendar page.
			ci.draw_rect(Rect2(c + Vector2(-u * 3.8, -u * 3.4), Vector2(u * 7.6, u * 7.6)), Color(0.92, 0.92, 0.94))
			ci.draw_rect(Rect2(c + Vector2(-u * 3.8, -u * 3.4), Vector2(u * 7.6, u * 2.2)), Color(0.95, 0.40, 0.30) if key == "payment" else Color(0.40, 0.60, 0.95))
			for k in 3:
				for j in 2:
					ci.draw_rect(Rect2(c + Vector2(-u * 2.6 + k * u * 2.0, u * 0.0 + j * u * 1.8), Vector2(u * 1.2, u * 1.0)), Color(0.45, 0.45, 0.50))
