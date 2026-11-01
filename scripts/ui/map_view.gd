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
## Which level is shown: 0 the surface, 1 the Deep.
var level := 0
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	if state.is_empty():
		return
	var w := int(state["width"])
	var h := int(state["height"])
	var tw := tile_size
	var view := Rect2(Vector2(-tw * 2.0, -tw * 2.0), size + Vector2(tw * 4.0, tw * 4.0))
	# Ground, back to front, with the climate tint on the surface.
	for sum in w + h - 1:
		for x in range(maxi(0, sum - h + 1), mini(w, sum + 1)):
			var y := sum - x
			var c := cell_center(Vector2i(x, y))
			if not view.has_point(c):
				continue
			Sprites.terrain_iso(self, Actions.terrain_at(state, x, y, level), c, tw)
			if level == 0:
				var l := GameData.light_at(x, state["planet"])
				var tint := Color(0.2, 0.35, 0.8, 0.22 * clampf(1.0 - l, 0.0, 1.0)) if l < 1.0 else Color(1.0, 0.6, 0.2, 0.18 * clampf(l - 1.0, 0.0, 1.0))
				draw_colored_polygon(_diamond(c, 1.0), tint)
	# Where the next building would go, and the selected tile, under the buildings.
	if hover.x >= 0:
		var hc := cell_center(hover)
		if build_type != "":
			var ok: bool = Actions.check_place(state, build_type, hover.x, hover.y, level)["ok"]
			draw_colored_polygon(_diamond(hc, 1.0), Color(0.3, 1.0, 0.5, 0.40) if ok else Color(1.0, 0.3, 0.3, 0.40))
		draw_polyline(_diamond_loop(hc, 1.0), Color(1, 1, 1, 0.75), 1.5)
	if selected.x >= 0:
		draw_polyline(_diamond_loop(cell_center(selected), 1.0), Color(1.0, 0.85, 0.3), 2.5)
	# Buildings and tunnels, back to front so nearer ones cover farther ones.
	for sum in w + h - 1:
		for x in range(maxi(0, sum - h + 1), mini(w, sum + 1)):
			var y := sum - x
			var s := Actions.structure_at(state, x, y, level)
			if s.is_empty():
				continue
			var c := cell_center(Vector2i(x, y))
			if not view.has_point(c):
				continue
			_draw_structure(s, c)
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


## Which sides of a structure join a neighbour on the same level (for tunnels
## and doors). A shaft also joins straight down, which isn't shown as a side.
func _links(s: Dictionary) -> Array:
	var out: Array = []
	for d in DIRS:
		var n: Vector2i = Vector2i(int(s["x"]), int(s["y"])) + d
		if Actions.inside(state, n.x, n.y) and not Actions.structure_at(state, n.x, n.y, level).is_empty():
			out.append(d)
	return out


func _draw_structure(s: Dictionary, c: Vector2) -> void:
	var tw := tile_size
	var def := GameData.building(s["type"])
	var conduit: bool = def.get("conduit", false)
	var look := {
		"built": bool(s["built"]),
		"active": bool(s["active"]) or conduit or not s["built"],
		"links": _links(s),
	}
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
