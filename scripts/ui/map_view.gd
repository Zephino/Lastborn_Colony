## Draws the colony map with simple shapes (no image assets) and turns mouse
## input into tile clicks. Click or tap: select or build. Drag (any button or
## one finger): pan. Wheel: zoom.
extends Control

signal tile_clicked(cell: Vector2i)
signal tile_hovered(cell: Vector2i)

const GameData = preload("res://scripts/sim/game_data.gd")
const Actions = preload("res://scripts/sim/actions.gd")

const TERRAIN_COLORS := {
	"regolith": Color(0.36, 0.33, 0.30),
	"ice": Color(0.66, 0.78, 0.86),
	"vent": Color(0.30, 0.24, 0.23),
	"seam": Color(0.33, 0.31, 0.29),
	"ridge": Color(0.17, 0.17, 0.19),
	"deepice": Color(0.80, 0.88, 0.96),
	"scorch": Color(0.55, 0.30, 0.16),
}

var state: Dictionary = {}
var tile_size := 28.0
var pan := Vector2.ZERO
var selected := Vector2i(-1, -1)
var hover := Vector2i(-1, -1)
var build_type := ""
var _dragging := false
## A left press becomes a pan once it moves this far; otherwise it is a click.
const DRAG_THRESHOLD := 10.0
var _left_down := false
var _left_panning := false
var _left_from := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_state(s: Dictionary) -> void:
	state = s
	pan = Vector2.ZERO
	queue_redraw()


func _origin() -> Vector2:
	var w := float(state.get("width", 0)) * tile_size
	var h := float(state.get("height", 0)) * tile_size
	return (size - Vector2(w, h)) * 0.5 + pan


func cell_at(pos: Vector2) -> Vector2i:
	var p := (pos - _origin()) / tile_size
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if state.is_empty() or not Actions.inside(state, c.x, c.y):
		return Vector2i(-1, -1)
	return c


func _gui_input(event: InputEvent) -> void:
	if state.is_empty():
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


func _zoom(factor: float, at: Vector2) -> void:
	var before := (at - _origin()) / tile_size
	tile_size = clampf(tile_size * factor, 14.0, 56.0)
	var after := (at - _origin()) / tile_size
	pan += (after - before) * tile_size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08))
	if state.is_empty():
		return
	var o := _origin()
	var w := int(state["width"])
	var h := int(state["height"])
	var ts := tile_size
	for y in h:
		for x in w:
			var t: String = state["tiles"][y][x]
			var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
			draw_rect(r, _terrain_color(t, x))
			_draw_terrain_detail(t, r, x, y)
	# Climate shading: cool blue on the night side, warm on the day side.
	for x in w:
		var l := GameData.light_at(x, state["planet"])
		var tint := Color(0.2, 0.35, 0.8, 0.22 * clampf(1.0 - l, 0.0, 1.0)) if l < 1.0 else Color(1.0, 0.6, 0.2, 0.18 * clampf(l - 1.0, 0.0, 1.0))
		draw_rect(Rect2(o + Vector2(x * ts, 0), Vector2(ts, h * ts)), tint)
	# Grid.
	var grid := Color(0, 0, 0, 0.18)
	for x in w + 1:
		draw_line(o + Vector2(x * ts, 0), o + Vector2(x * ts, h * ts), grid)
	for y in h + 1:
		draw_line(o + Vector2(0, y * ts), o + Vector2(w * ts, y * ts), grid)
	# Conduits first so buildings draw over them.
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["type"] == "main":
			_draw_main(s, o)
	for id in state["structures"]:
		var s: Dictionary = state["structures"][id]
		if s["type"] != "main":
			_draw_structure(s, o)
	# Hover and selection.
	if hover.x >= 0:
		var hr := Rect2(o + Vector2(hover) * ts, Vector2(ts, ts))
		if build_type != "":
			var ok: bool = Actions.check_place(state, build_type, hover.x, hover.y)["ok"]
			draw_rect(hr, Color(0.3, 1.0, 0.5, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35))
		draw_rect(hr, Color(1, 1, 1, 0.7), false, 1.5)
	if selected.x >= 0:
		draw_rect(Rect2(o + Vector2(selected) * ts, Vector2(ts, ts)).grow(1), Color(1.0, 0.85, 0.3), false, 2.5)


func _terrain_color(t: String, x: int) -> Color:
	var c: Color = TERRAIN_COLORS.get(t, Color.MAGENTA)
	if t == "regolith" or t == "seam" or t == "vent":
		var warm := clampf((GameData.light_at(x, state["planet"]) - 0.3) / 1.3, 0.0, 1.0)
		c = c.lerp(Color(0.48, 0.36, 0.26), warm * 0.5)
	return c


func _draw_terrain_detail(t: String, r: Rect2, x: int, y: int) -> void:
	var c := r.get_center()
	var ts := tile_size
	match t:
		"ice":
			draw_line(r.position + Vector2(ts * 0.2, ts * 0.7), r.position + Vector2(ts * 0.6, ts * 0.3), Color(1, 1, 1, 0.35), 1.0)
		"vent":
			draw_circle(c, ts * 0.22, Color(0.95, 0.45, 0.15, 0.85))
			draw_circle(c, ts * 0.11, Color(1.0, 0.85, 0.4))
		"seam":
			var seam_col := Color(0.25, 0.62, 0.60)
			draw_line(r.position + Vector2(ts * 0.15, ts * 0.3), r.position + Vector2(ts * 0.85, ts * 0.55), seam_col, 2.0)
			draw_line(r.position + Vector2(ts * 0.2, ts * 0.75), r.position + Vector2(ts * 0.7, ts * 0.6), seam_col, 2.0)
		"ridge":
			var pts := PackedVector2Array([r.position + Vector2(ts * 0.1, ts * 0.85), c + Vector2(0, -ts * 0.35), r.position + Vector2(ts * 0.9, ts * 0.85)])
			draw_colored_polygon(pts, Color(0.28, 0.28, 0.31))
		"regolith":
			# Deterministic speckle so the ground has texture.
			var hsh := (x * 73856093) ^ (y * 19349663)
			if hsh % 5 == 0:
				draw_circle(r.position + Vector2(ts * 0.3, ts * 0.6), ts * 0.06, Color(0, 0, 0, 0.25))


func _draw_main(s: Dictionary, o: Vector2) -> void:
	var ts := tile_size
	var c := o + (Vector2(int(s["x"]), int(s["y"])) + Vector2(0.5, 0.5)) * ts
	var col := Color(0.95, 0.55, 0.25) if s["built"] else Color(0.95, 0.55, 0.25, 0.4)
	draw_circle(c, ts * 0.12, col)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = Vector2i(int(s["x"]), int(s["y"])) + d
		if Actions.inside(state, n.x, n.y) and not Actions.structure_at(state, n.x, n.y).is_empty():
			draw_line(c, c + Vector2(d) * ts * 0.5, col, maxf(2.0, ts * 0.14))


func _draw_structure(s: Dictionary, o: Vector2) -> void:
	var ts := tile_size
	var r := Rect2(o + Vector2(int(s["x"]), int(s["y"])) * ts, Vector2(ts, ts)).grow(-ts * 0.08)
	var c := r.get_center()
	var a := 1.0 if s["built"] else 0.45
	var dim := 1.0 if (s["active"] or not s["built"]) else 0.55
	var base := Color(0.62 * dim, 0.66 * dim, 0.70 * dim, a)
	match s["type"]:
		"hull":
			draw_rect(r.grow(ts * 0.04), Color(0.55, 0.58, 0.62, a))
			draw_circle(c, ts * 0.32, Color(0.80, 0.82, 0.86, a))
			draw_circle(c, ts * 0.14, Color(1.0, 0.8, 0.4, a))
		"mirror":
			var pts := PackedVector2Array([r.position + Vector2(ts * 0.15, ts * 0.75), r.position + Vector2(ts * 0.45, ts * 0.15), r.position + Vector2(ts * 0.85, ts * 0.25), r.position + Vector2(ts * 0.55, ts * 0.85)])
			draw_colored_polygon(pts, Color(0.75 * dim, 0.85 * dim, 0.95 * dim, a))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.3, 0.35, 0.45, a), 1.0)
		"vent":
			draw_rect(r.grow(-ts * 0.1), Color(0.35 * dim, 0.30 * dim, 0.28 * dim, a))
			draw_rect(Rect2(c - Vector2(ts * 0.1, ts * 0.38), Vector2(ts * 0.2, ts * 0.4)), Color(0.5 * dim, 0.45 * dim, 0.4 * dim, a))
			draw_circle(c + Vector2(0, -ts * 0.38), ts * 0.1, Color(1.0, 0.55, 0.2, a * dim))
		"drill":
			draw_rect(r.grow(-ts * 0.15), Color(0.4 * dim, 0.55 * dim, 0.7 * dim, a))
			draw_line(c + Vector2(-ts * 0.3, ts * 0.3), c + Vector2(0, -ts * 0.38), base, 2.0)
			draw_line(c + Vector2(ts * 0.3, ts * 0.3), c + Vector2(0, -ts * 0.38), base, 2.0)
		"splitter":
			draw_circle(c + Vector2(-ts * 0.16, 0), ts * 0.2, Color(0.55 * dim, 0.85 * dim, 0.95 * dim, a))
			draw_circle(c + Vector2(ts * 0.18, 0), ts * 0.16, Color(0.85 * dim, 0.95 * dim, 1.0 * dim, a))
		"vat":
			draw_rect(r.grow(-ts * 0.08), Color(0.18 * dim, 0.45 * dim, 0.30 * dim, a))
			for i in 3:
				draw_line(r.position + Vector2(ts * (0.25 + 0.2 * i), ts * 0.8), r.position + Vector2(ts * (0.3 + 0.2 * i), ts * 0.25), Color(0.4 * dim, 0.85 * dim, 0.5 * dim, a), 2.0)
		"bunk":
			draw_rect(r, Color(0.55 * dim, 0.5 * dim, 0.45 * dim, a))
			for i in 3:
				draw_rect(Rect2(r.position + Vector2(ts * (0.12 + 0.26 * i), ts * 0.35), Vector2(ts * 0.14, ts * 0.14)), Color(1.0, 0.85, 0.5, a * dim))
		"cutter":
			draw_circle(c, ts * 0.32, Color(0.45 * dim, 0.6 * dim, 0.58 * dim, a))
			for i in 6:
				var ang := TAU * i / 6.0
				draw_line(c, c + Vector2(cos(ang), sin(ang)) * ts * 0.4, Color(0.25, 0.3, 0.3, a), 2.0)
		"forge":
			draw_rect(r, Color(0.45 * dim, 0.25 * dim, 0.2 * dim, a))
			draw_rect(r.grow(-ts * 0.25), Color(1.0, 0.45 * dim + 0.1, 0.15, a))
		"rail":
			draw_rect(Rect2(r.position + Vector2(0, ts * 0.3), Vector2(r.size.x, ts * 0.25)), Color(0.7 * dim, 0.7 * dim, 0.75 * dim, a))
			draw_line(r.position + Vector2(0, ts * 0.42), r.position + Vector2(r.size.x, ts * 0.12), Color(0.95, 0.8, 0.35, a * dim), 2.0)
		"commons":
			draw_arc(c + Vector2(0, ts * 0.2), ts * 0.36, PI, TAU, 16, Color(0.85 * dim, 0.7 * dim, 0.45 * dim, a), ts * 0.12)
		"clinic":
			draw_rect(r.grow(-ts * 0.06), Color(0.88 * dim, 0.9 * dim, 0.92 * dim, a))
			draw_rect(Rect2(c - Vector2(ts * 0.06, ts * 0.25), Vector2(ts * 0.12, ts * 0.5)), Color(0.2, 0.65, 0.6, a))
			draw_rect(Rect2(c - Vector2(ts * 0.25, ts * 0.06), Vector2(ts * 0.5, ts * 0.12)), Color(0.2, 0.65, 0.6, a))
		"cache":
			draw_rect(r.grow(-ts * 0.12), Color(0.5 * dim, 0.45 * dim, 0.35 * dim, a))
			draw_line(r.position + Vector2(ts * 0.1, ts * 0.45), r.position + Vector2(r.size.x - ts * 0.02, ts * 0.45), Color(0.3, 0.27, 0.2, a), 2.0)
		_:
			draw_rect(r, base)
	# Status markers.
	if not s["built"]:
		var def := GameData.building(s["type"])
		var frac := float(s["progress"]) / maxf(1.0, GameData.num(def, "turns"))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 4), Vector2(r.size.x * frac, 4)), Color(0.4, 0.9, 1.0))
	elif int(s["damaged"]) > 0:
		draw_line(r.position, r.end, Color(1.0, 0.85, 0.2), 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color(1.0, 0.85, 0.2), 2.0)
	elif not s["active"]:
		draw_circle(r.position + Vector2(r.size.x - 4, 4), 3.5, Color(1.0, 0.3, 0.3))
