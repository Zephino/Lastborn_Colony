## Draws the colony map at an angle (isometric), with the building sprites
## from scripts/ui/sprites.gd, and turns mouse and touch input into tile
## clicks. Click or tap: select or build. Drag (any button or one finger): pan,
## and a drag never selects or builds. Wheel, two-finger pinch, or zoom_by():
## zoom. Arrow keys / WASD pan (handled by main.gd).
##
## Tiles are diamonds: tile (x, y) has its centre at
##   origin + ((x - y) * tile_size / 2, (x + y) * tile_size / 4)
## where tile_size is the diamond's width in pixels.
extends Control

signal tile_clicked(cell: Vector2i)
signal tile_hovered(cell: Vector2i)

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")
const Sprites = preload("res://scripts/ui/sprites.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")
const People = preload("res://scripts/ui/people.gd")
const Turn = preload("res://scripts/sim/turn.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MIN_TILE := 36.0
const MAX_TILE := 220.0

var state: Dictionary = {}
## Width of one diamond tile, in pixels.
var tile_size := 120.0
var pan := Vector2.ZERO
var selected := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var build_type := ""
## How the building being placed is turned (0-3), or -1 to turn it automatically.
var build_rot := -1
## Which level is shown: 0 the surface, 1 the Deep.
var level := 0
## Whether the map moves: blinking lights, steam, the lift, rovers driving,
## the Reclaimer's truck and the lander coming down. Settings can turn it off.
var animate := true
## Seconds since the map started, for the animations.
var clock := 0.0
var _since_draw := 0.0
## When the lander last started coming down (in clock seconds), and the turn
## that brought it, so it lands once per arrival.
var _land_start := -100.0
var _land_turn := -1
## Seconds the lander takes to come down.
const LAND_TIME := 2.6
var _dragging := false
## A left press becomes a pan once it moves this far; otherwise it is a click.
const DRAG_THRESHOLD := 10.0
var _left_down := false
var _left_panning := false
var _left_from := Vector2.ZERO
## Fingers on the screen (index -> position), for two-finger pinch and pan.
var _touches := {}
var _pinch_distance := 0.0
var _pinch_center := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_state(s: Dictionary) -> void:
	state = s
	pan = Vector2.ZERO
	# A game that starts (or loads) with the lander already down doesn't replay it.
	_land_turn = int(s.get("turn", -1)) if int(s.get("lander", 0)) > 0 else -1
	queue_redraw()


func _process(delta: float) -> void:
	if not animate or state.is_empty() or not is_visible_in_tree():
		return
	clock += delta
	_since_draw += delta
	# About 20 pictures a second is smooth enough, and kind to phones.
	if _since_draw >= 0.05:
		_since_draw = 0.0
		queue_redraw()


## Screen offset of a (fractional) tile position from the map's origin.
func _proj(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * tile_size * 0.5, (cell.x + cell.y) * tile_size * 0.25)


## Fractional tile position under a screen point (the inverse of _proj).
func _unproj(pos: Vector2) -> Vector2:
	var p := pos - _origin()
	var a := p.x / (tile_size * 0.5)
	var b := p.y / (tile_size * 0.25)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Where tile (0, 0)'s centre is on screen. The map's middle sits in the middle
## of the view, moved by pan.
func _origin() -> Vector2:
	var mid := Vector2(float(state.get("width", 1)) - 1.0, float(state.get("height", 1)) - 1.0) * 0.5
	return size * 0.5 + pan - _proj(mid)


## Centre of tile c on screen.
func cell_center(c: Vector2i) -> Vector2:
	return _origin() + _proj(Vector2(c))


func cell_at(pos: Vector2) -> Vector2i:
	var f := _unproj(pos)
	var c := Vector2i(int(floor(f.x + 0.5)), int(floor(f.y + 0.5)))
	if state.is_empty() or not Actions.inside(state, c.x, c.y):
		return Vector2i(-1, -1)
	return c


func _gui_input(event: InputEvent) -> void:
	if state.is_empty():
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
		return
	if event is InputEventMagnifyGesture:
		_zoom((event as InputEventMagnifyGesture).factor, (event as InputEventMagnifyGesture).position)
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.0 / 1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_down = true
				_left_panning = false
				_left_from = mb.position
			else:
				if _left_down and not _left_panning:
					var c := cell_at(mb.position)
					if c.x >= 0:
						tile_clicked.emit(c)
				_left_down = false
				_left_panning = false
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_down and not _left_panning and mm.position.distance_to(_left_from) > DRAG_THRESHOLD:
			_left_panning = true
			pan += mm.position - _left_from
			queue_redraw()
		elif _dragging or _left_panning:
			pan += mm.relative
			queue_redraw()
		var c := cell_at(mm.position)
		if c != hover:
			hover = c
			tile_hovered.emit(c)
			queue_redraw()


## Two fingers: pinch to zoom, move both to pan. A second finger also cancels
## the tap the first finger started, so pinching never selects or builds.
func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		if _touches.size() >= 2:
			_left_down = false
			_left_panning = true
			_start_pinch()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			var dist := a.distance_to(b)
			var center := (a + b) * 0.5
			if _pinch_distance > 0.0:
				_zoom(dist / _pinch_distance, center)
				pan += center - _pinch_center
				queue_redraw()
			_pinch_distance = dist
			_pinch_center = center
	accept_event()


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_distance = (pts[0] as Vector2).distance_to(pts[1])
	_pinch_center = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


## Zoom in (>1) or out (<1) around the middle of the map view.
func zoom_by(factor: float) -> void:
	_zoom(factor, size * 0.5)


func pan_by(delta: Vector2) -> void:
	pan += delta
	queue_redraw()


## Moves the view so this tile is in the middle.
func center_on(cell: Vector2i) -> void:
	var mid := Vector2(float(state.get("width", 1)) - 1.0, float(state.get("height", 1)) - 1.0) * 0.5
	pan = _proj(mid) - _proj(Vector2(cell))
	queue_redraw()


## Zooms so the tile point under `at` stays under it.
func _zoom(factor: float, at: Vector2) -> void:
	var before := _unproj(at)
	tile_size = clampf(tile_size * factor, MIN_TILE, MAX_TILE)
	var after := _unproj(at)
	pan += _proj(after) - _proj(before)
	queue_redraw()


func _draw() -> void:
	if state.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
		return
	Sprites.anim_t = clock if animate else 0.0
	# The lander comes down when it arrives (once per arrival).
	if animate and int(state.get("lander", 0)) > 0 and _land_turn != int(state["turn"]):
		_land_turn = int(state["turn"])
		_land_start = clock
	# Each planet has its own ground colours and sky; the Deep keeps its own.
	Sprites.set_planet(str(state.get("planet", "")) if level == 0 else "")
	draw_rect(Rect2(Vector2.ZERO, size), Sprites.sky(str(state.get("planet", ""))) if level == 0 else Color(0.05, 0.06, 0.08))
	var w := int(state["width"])
	var h := int(state["height"])
	var tw := tile_size
	var view := Rect2(Vector2(-tw * 2.0, -tw * 2.0), size + Vector2(tw * 4.0, tw * 4.0))
	var lamps := _deep_light() if level == 1 else {}
	# Ground, back to front, with the climate tint on the surface and lamplight
	# in the Deep.
	for sum in w + h - 1:
		for x in range(maxi(0, sum - h + 1), mini(w, sum + 1)):
			var y := sum - x
			var c := cell_center(Vector2i(x, y))
			if not view.has_point(c):
				continue
			# Rock with a building on it has been dug out, so it isn't drawn raised.
			Sprites.terrain_iso(self, Actions.terrain_at(state, x, y, level), c, tw, Actions.structure_at(state, x, y, level).is_empty())
			if level == 0:
				var l := GameData.light_at(x, state["planet"])
				var tint := Color(0.2, 0.35, 0.8, 0.22 * clampf(1.0 - l, 0.0, 1.0)) if l < 1.0 else Color(1.0, 0.6, 0.2, 0.18 * clampf(l - 1.0, 0.0, 1.0))
				draw_colored_polygon(_diamond(c, 1.0), tint)
			else:
				var lit: float = float(lamps.get(Vector2i(x, y), 0.0))
				var shade := Color(0.0, 0.0, 0.02, 0.62 * (1.0 - lit))
				var ground := Actions.terrain_at(state, x, y, level)
				if (ground == "rock" or ground == "vein") and Actions.structure_at(state, x, y, level).is_empty():
					# Raised rock: shade its sides and top too.
					var up := Vector2(0, tw * 0.14)
					var dm := _diamond(c, 1.0)
					draw_colored_polygon(PackedVector2Array([dm[0] - up, dm[1] - up, dm[1], dm[2], dm[3], dm[3] - up]), shade)
				else:
					draw_colored_polygon(_diamond(c, 1.0), shade)
				if lit > 0.0:
					draw_colored_polygon(_diamond(c, 1.0), Color(1.0, 0.78, 0.45, 0.10 * lit))
	# Where the next building would go, and the selected tile, under the buildings.
	if hover.x >= 0:
		var hc := cell_center(hover)
		if build_type != "":
			var ok: bool = Actions.check_place(state, build_type, hover.x, hover.y, level, build_rot)["ok"]
			draw_colored_polygon(_diamond(hc, 1.0), Color(0.3, 1.0, 0.5, 0.40) if ok else Color(1.0, 0.3, 0.3, 0.40))
		draw_polyline(_diamond_loop(hc, 1.0), Color(1, 1, 1, 0.75), 1.5)
	if selected.x >= 0:
		draw_polyline(_diamond_loop(cell_center(selected), 1.0), Color(1.0, 0.85, 0.3), 2.5)
	# Buildings, tunnels and working drones, back to front so nearer ones cover
	# farther ones.
	var drones := _drone_spots()
	var people := _colonist_spots()
	for sum in w + h - 1:
		for x in range(maxi(0, sum - h + 1), mini(w, sum + 1)):
			var y := sum - x
			var cell := Vector2i(x, y)
			var s := Actions.structure_at(state, x, y, level)
			if s.is_empty() and not drones.has(cell) and not people.has(cell):
				continue
			var c := cell_center(cell)
			if not view.has_point(c):
				continue
			if not s.is_empty():
				_draw_structure(s, c)
			for type in drones.get(cell, []):
				# Each drone sits at the tile's front corner, at half a tile's scale.
				# Each rover faces along the line it drives on.
				Sprites.more().draw_unit(self, type, c + _proj(Vector2(0.26, 0.26) + _drive(cell, type)), tile_size * 0.62, (cell.x + cell.y) % 2 != 0)
			for p in people.get(cell, []):
				var walk := Vector2.ZERO
				var stride: bool = p["stride"]
				if animate:
					# Colonists stroll a little way back and forth.
					var ph: float = clock * 0.6 + float(p["at"].x) * 7.0 + float(cell.x)
					walk = Vector2(sin(ph), 0.0) * 0.08 * float(p["facing"])
					stride = int(clock * 4.0 + cell.y) % 2 == 0
				People.draw_colonist(self, c + _proj(p["at"] + walk), tile_size * 0.22, p["job"], p["facing"], stride)
	if level == 0:
		_draw_orbit()
	# The building being placed, see-through, turned the way it would be built,
	# with its doors showing.
	if build_type != "" and hover.x >= 0 and Actions.structure_at(state, hover.x, hover.y, level).is_empty():
		var rot := preview_rot()
		var doors := Actions.door_dirs(build_type, maxi(rot, 0))
		var ghost := {"built": false, "links": [], "doors": doors}
		Sprites.draw_iso(self, build_type, cell_center(hover), tile_size, ghost)
		for d in doors:
			var edge := cell_center(hover) + _proj(Vector2(d) * 0.5)
			draw_circle(edge, maxf(4.0, tile_size * 0.05), Color(1.0, 0.55, 0.20))
			draw_circle(edge, maxf(2.0, tile_size * 0.025), Color(1.0, 0.9, 0.6))
	# The selected tile's outline again, faintly, so it shows through tall buildings.
	if selected.x >= 0:
		draw_polyline(_diamond_loop(cell_center(selected), 1.0), Color(1.0, 0.85, 0.3, 0.45), 1.5)


func _diamond(c: Vector2, k: float) -> PackedVector2Array:
	var hx := tile_size * 0.5 * k
	var hy := tile_size * 0.25 * k
	return PackedVector2Array([c + Vector2(0, -hy), c + Vector2(hx, 0), c + Vector2(0, hy), c + Vector2(-hx, 0)])


func _diamond_loop(c: Vector2, k: float) -> PackedVector2Array:
	var d := _diamond(c, k)
	d.append(d[0])
	return d


## Which sides of a structure join a neighbour on the same level: where their
## doors meet (or any side, in games from before door rules). A shaft also
## joins straight down, which isn't shown as a side.
func _links(s: Dictionary) -> Array:
	var out: Array = []
	for d in DIRS:
		var n: Vector2i = Vector2i(int(s["x"]), int(s["y"])) + d
		if not Actions.inside(state, n.x, n.y):
			continue
		var other := Actions.structure_at(state, n.x, n.y, level)
		if not other.is_empty() and Actions.joined(state, s, other, d):
			out.append(d)
	return out


## How the building being placed would be turned on the hovered tile.
func preview_rot() -> int:
	if build_rot >= 0:
		return build_rot
	if hover.x < 0:
		return 0
	return maxi(0, Actions.auto_rot(state, build_type, hover.x, hover.y, level))


## A quarter-turn for the building being placed.
func rotate_build() -> void:
	build_rot = (preview_rot() + 1) % 4
	queue_redraw()


func _draw_structure(s: Dictionary, c: Vector2) -> void:
	var tw := tile_size
	var def := GameData.building(s["type"])
	var conduit: bool = def.get("conduit", false)
	var look := {
		"built": bool(s["built"]),
		"active": bool(s["active"]) or conduit or not s["built"],
		"links": _links(s),
	}
	if Actions.door_rules(state):
		look["doors"] = Actions.door_dirs(str(s["type"]), int(s.get("rot", 0)))
	if s["type"] == "shaft" or s["type"] == "shaft_base":
		# The lift goes up and down between turns, or all the time when animating.
		look["car"] = "up" if int(state["turn"]) % 2 == 0 else "down"
		if animate:
			look["lift"] = 0.5 + 0.5 * sin(clock * 0.5)
	if s["type"] == "reclaimer" and s["active"] and animate:
		# A truck comes round every 12 seconds or so to drop off junk.
		look["truck_trip"] = fmod(clock / 12.0 + float(int(s["x"]) * 3 + int(s["y"])) * 0.17, 1.0)
	if s["type"] == "hull":
		look["ship"] = int(state.get("lander", 0)) > 0
		look["ship_door"] = int(state.get("lander_door", 0))
		if animate and clock - _land_start < LAND_TIME:
			look["ship_drop"] = 1.0 - (clock - _land_start) / LAND_TIME
	Sprites.draw_iso(self, s["type"], c, tw, look)
	# Status markers above the tile.
	var mark := c - Vector2(0, tw * 0.42)
	if not s["built"]:
		var frac := float(s["progress"]) / maxf(1.0, float(s.get("build_turns", GameData.num(def, "turns"))))
		var bar := Rect2(c + Vector2(-tw * 0.22, tw * 0.10), Vector2(tw * 0.44, maxf(3.0, tw * 0.04)))
		draw_rect(bar, Color(0, 0, 0, 0.65))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(0.4, 0.9, 1.0))
	elif int(s["damaged"]) > 0:
		var k := tw * 0.07
		draw_circle(mark, k * 1.5, Color(0, 0, 0, 0.6))
		draw_line(mark - Vector2(k, k), mark + Vector2(k, k), Color(1.0, 0.85, 0.2), 2.5)
		draw_line(mark + Vector2(-k, k), mark + Vector2(k, -k), Color(1.0, 0.85, 0.2), 2.5)
	elif not s["active"] and not conduit:
		draw_circle(mark, maxf(4.0, tw * 0.05), Color(0, 0, 0, 0.6))
		draw_circle(mark, maxf(3.0, tw * 0.035), Color(1.0, 0.3, 0.3))


## Where each working drone is shown this turn: {cell: [drone types]}.
## Graders stand by the surface buildings they're helping to build, Borers by
## Shafts and Deep buildings, Haulers by the Seam Cutters they serve, and
## Prospectors roam the empty ground at the colony's edge (a new spot each turn).
func _drone_spots() -> Dictionary:
	var out := {}
	if not state.has("drones") or Fleet.drones_total(state) == 0:
		return out
	var work := Fleet.working(state)
	var help := Fleet.construction_bonus(state)
	var graders := int(work.get("grader", 0))
	var borers := int(work.get("borer", 0))
	for id in help:
		var s: Dictionary = state["structures"][id]
		var digging: bool = s["type"] == "shaft" or int(s.get("z", 0)) == 1
		if int(s.get("z", 0)) != level and not (s["type"] == "shaft" and level == 0):
			continue
		var type := "borer" if digging else "grader"
		if (type == "borer" and borers <= 0) or (type == "grader" and graders <= 0):
			continue
		_add_spot(out, Vector2i(int(s["x"]), int(s["y"])), type)
	var haulers := int(work.get("hauler", 0))
	for id in state["structures"]:
		if haulers <= 0:
			break
		var s: Dictionary = state["structures"][id]
		if s["type"] == "cutter" and s["active"] and int(s.get("z", 0)) == level:
			_add_spot(out, Vector2i(int(s["x"]), int(s["y"])), "hauler")
			haulers -= 1
	# A Hauler takes ore up the lift when any are working.
	if int(work.get("hauler", 0)) > 0:
		for id in state["structures"]:
			var s: Dictionary = state["structures"][id]
			if s["built"] and ((level == 0 and s["type"] == "shaft") or (level == 1 and s["type"] == "shaft_base")):
				_add_spot(out, Vector2i(int(s["x"]), int(s["y"])), "hauler")
	var prospectors := int(work.get("prospector", 0))
	if prospectors > 0 and level == 0:
		var edge: Array = []
		for y in int(state["height"]):
			for x in int(state["width"]):
				if Actions.structure_at(state, x, y).is_empty() and Actions.touches_colony(state, x, y) and Actions.terrain_at(state, x, y) in ["regolith", "ice", "seam"]:
					edge.append(Vector2i(x, y))
		var turn := int(state["turn"])
		for k in mini(prospectors, edge.size()):
			# A fixed shuffle that changes each turn, so they seem to roam.
			var pick: Vector2i = edge[(turn * 7 + k * 13 + k * k * 5) % edge.size()]
			_add_spot(out, pick, "prospector")
		# Scouts roam the edge too, further along it.
		for k in mini(int(work.get("scout", 0)), edge.size()):
			var pick: Vector2i = edge[(turn * 11 + k * 17 + 5) % edge.size()]
			_add_spot(out, pick, "scout")
	# Sweepers at Solar Arrays, Mechanics at broken buildings (or the Workshop),
	# Medics at the Clinic (or the Landing Pad).
	var want := {"sweeper": int(work.get("sweeper", 0)), "mechanic": int(work.get("mechanic", 0)), "medic": int(work.get("medic", 0))}
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if int(s.get("z", 0)) != level or not s["built"]:
			continue
		var cell := Vector2i(int(s["x"]), int(s["y"]))
		if want["sweeper"] > 0 and s["type"] == "mirror":
			_add_spot(out, cell, "sweeper")
			want["sweeper"] -= 1
		elif want["mechanic"] > 0 and int(s["damaged"]) > 0:
			_add_spot(out, cell, "mechanic")
			want["mechanic"] -= 1
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if int(s.get("z", 0)) != level or not s["built"]:
			continue
		var cell := Vector2i(int(s["x"]), int(s["y"]))
		if want["mechanic"] > 0 and s["type"] == "workshop":
			_add_spot(out, cell, "mechanic")
			want["mechanic"] -= 1
		elif want["medic"] > 0 and (s["type"] == "clinic" or s["type"] == "hull"):
			_add_spot(out, cell, "medic")
			want["medic"] -= 1
	return out


func _add_spot(out: Dictionary, cell: Vector2i, type: String) -> void:
	if not out.has(cell):
		out[cell] = []
	(out[cell] as Array).append(type)


## Satellites in orbit, drawn small along the top of the map like a strip of sky.
func _draw_orbit() -> void:
	if not state.has("satellites"):
		return
	var sats: Array = []
	for t in Fleet.sat_order():
		for _i in Fleet.sats(state, t):
			sats.append(t)
	if sats.is_empty():
		return
	var icon := clampf(tile_size * 0.6, 48.0, 84.0)
	var strip := Rect2(Vector2(8, 8), Vector2(minf(size.x - 16.0, 12.0 + sats.size() * icon * 0.9), icon * 0.8))
	draw_rect(strip, Color(0.02, 0.03, 0.06, 0.75))
	for k in 12:
		draw_circle(strip.position + Vector2(fmod(k * 37.0, strip.size.x), fmod(k * 23.0, strip.size.y)), 1.0, Color(1, 1, 1, 0.5))
	draw_string(ThemeDB.fallback_font, strip.position + Vector2(6, 14), "In orbit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.9))
	for k in sats.size():
		var at := strip.position + Vector2(6.0 + icon * 0.45 + k * icon * 0.9, icon * 0.62)
		if at.x > strip.end.x:
			break
		Sprites.more().draw_unit(self, sats[k], at, icon * 0.75)


## Colonists out on the ground in their space suits, a few more as the colony
## grows: about one for every eight people, up to 16 (half as many in the Deep).
## They stand or walk on open ground next to the colony and move every turn.
## Most are workers (orange stripe); some are scientists (teal) if there is a lab,
## and wardens (violet) if there is a Warden Post.
## How brightly each Deep tile is lit (0 dark to 1 bright): the caves are dark
## except where the colony's lamps reach. Working buildings light about two
## tiles round them; idle ones and tunnels only a little.
func _deep_light() -> Dictionary:
	var out := {}
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if int(s.get("z", 0)) != 1:
			continue
		var conduit: bool = GameData.building(s["type"]).get("conduit", false)
		var bright := 1.0 if (s["active"] and s["built"]) or s["type"] == "shaft_base" else (0.55 if conduit and s["built"] else 0.3)
		var reach := 2.6 if bright >= 1.0 else 1.6
		var at := Vector2i(int(s["x"]), int(s["y"]))
		var r := int(ceil(reach))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell := at + Vector2i(dx, dy)
				if not Actions.inside(state, cell.x, cell.y):
					continue
				var d := Vector2(dx, dy).length()
				var v := bright * clampf(1.0 - d / (reach + 0.5), 0.0, 1.0)
				if v > float(out.get(cell, 0.0)):
					out[cell] = v
	return out


func _colonist_spots() -> Dictionary:
	var out := {}
	var pop := Turn.population(state)
	var count := clampi(int(pop / 8.0), 1, 16)
	if level == 1:
		count /= 2
	var walk := ["regolith", "ice", "seam"] if level == 0 else ["cavern", "aquifer"]
	var open: Array = []
	var has_lab := false
	var has_warden := false
	for id in state["structures"]:
		var t: String = state["structures"][id]["type"]
		has_lab = has_lab or t == "lab" or t == "hazlab"
		has_warden = has_warden or t == "warden"
	for y in int(state["height"]):
		for x in int(state["width"]):
			if Actions.structure_at(state, x, y, level).is_empty() and Actions.touches_colony(state, x, y, level) and Actions.terrain_at(state, x, y, level) in walk:
				open.append(Vector2i(x, y))
	if open.is_empty():
		return out
	var turn := int(state["turn"])
	for k in count:
		var cell: Vector2i = open[(turn * 11 + k * 17 + k * k * 3) % open.size()]
		var ou := float((k * 37 + turn * 13) % 7) / 7.0 - 0.45
		var ov := float((k * 23 + turn * 5) % 7) / 7.0 - 0.45
		var job := "worker"
		if has_lab and k % 5 == 1:
			job = "scientist"
		elif has_warden and k % 7 == 3:
			job = "warden"
		if not out.has(cell):
			out[cell] = []
		(out[cell] as Array).append({"at": Vector2(ou, ov) * 0.7, "job": job, "facing": 1.0 if (k + turn) % 2 == 0 else -1.0, "stride": (k + turn) % 3 != 0})
	# People riding the lift: one waiting at the tube's door and, when the car
	# has just arrived on this level, one stepping out.
	var car_here: bool = (int(state["turn"]) % 2 == 0) == (level == 0)
	for id in state["structures"]:
		var st: Dictionary = state["structures"][id]
		var lift: bool = (level == 0 and st["type"] == "shaft") or (level == 1 and st["type"] == "shaft_base")
		if not lift or not st["built"]:
			continue
		var at := Vector2i(int(st["x"]), int(st["y"]))
		if not out.has(at):
			out[at] = []
		(out[at] as Array).append({"at": Vector2(0.30, 0.10), "job": "worker", "facing": -1.0, "stride": false})
		if car_here:
			(out[at] as Array).append({"at": Vector2(0.12, 0.32), "job": "scientist" if has_lab else "worker", "facing": 1.0, "stride": true})
	# Back to front inside a tile too.
	for cell in out:
		(out[cell] as Array).sort_custom(func(a, b): return a["at"].x + a["at"].y < b["at"].x + b["at"].y)
	return out


## How far a working rover has driven from its parking spot right now (in tile
## units): each drives back and forth along its own line, out of step with the
## others. Nothing moves when animations are off.
func _drive(cell: Vector2i, type: String) -> Vector2:
	if not animate:
		return Vector2.ZERO
	var phase := float(cell.x * 13 + cell.y * 7 + type.length() * 3)
	var along := Vector2(-1.0, 0.0) if (cell.x + cell.y) % 2 == 0 else Vector2(0.0, -1.0)
	return along * (0.5 - 0.5 * cos(clock * 0.7 + phase)) * 0.35
