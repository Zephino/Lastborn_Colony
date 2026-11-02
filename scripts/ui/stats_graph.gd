## Four small line graphs of a colony's history, turn by turn: people, marks,
## debt left and morale. The history is state["history"], one row a turn:
## [turn, population, marks, debt, morale] (see scripts/sim/turn.gd).
extends Control

var history: Array = []
var font: Font

const CHARTS := [
	["People", 1, Color(0.45, 0.85, 1.0)],
	["Marks", 2, Color(1.0, 0.82, 0.35)],
	["Debt left", 3, Color(1.0, 0.45, 0.40)],
	["Morale", 4, Color(0.55, 1.0, 0.55)],
]


func _ready() -> void:
	font = ThemeDB.fallback_font


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.11))
	var cols := 2 if size.x >= 520.0 else 1
	var rows := int(ceil(CHARTS.size() / float(cols)))
	var cw := size.x / cols
	var ch := size.y / rows
	for i in CHARTS.size():
		var r := Rect2(Vector2((i % cols) * cw, (i / cols) * ch), Vector2(cw, ch)).grow(-8.0)
		_chart(r, CHARTS[i][0], int(CHARTS[i][1]), CHARTS[i][2])


func _chart(r: Rect2, title: String, col: int, color: Color) -> void:
	draw_rect(r, Color(0.11, 0.12, 0.16))
	draw_rect(r, Color(0.24, 0.26, 0.32), false, 1.0)
	draw_string(font, r.position + Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	if history.size() < 2:
		return
	var lo := INF
	var hi := -INF
	for row in history:
		var v := float(row[col])
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if col == 4:
		lo = 0.0
		hi = 100.0
	lo = minf(lo, 0.0)
	if hi - lo < 1.0:
		hi = lo + 1.0
	var area := Rect2(r.position + Vector2(44, 26), r.size - Vector2(54, 44))
	# Grid lines and the top and bottom values.
	for k in 3:
		var y := area.position.y + area.size.y * k / 2.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.20, 0.22, 0.27), 1.0)
	draw_string(font, Vector2(r.position.x + 4, area.position.y + 5), _short(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.68, 0.74))
	draw_string(font, Vector2(r.position.x + 4, area.end.y + 4), _short(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.68, 0.74))
	var t0 := float(history[0][0])
	var t1 := float(history[history.size() - 1][0])
	draw_string(font, Vector2(area.position.x, r.end.y - 4), "turn %d" % int(t0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.68, 0.74))
	draw_string(font, Vector2(area.end.x - 50, r.end.y - 4), "turn %d" % int(t1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.68, 0.74))
	var pts := PackedVector2Array()
	for row in history:
		var x := area.position.x + area.size.x * (float(row[0]) - t0) / maxf(t1 - t0, 1.0)
		var y := area.end.y - area.size.y * (float(row[col]) - lo) / (hi - lo)
		pts.append(Vector2(x, y))
	# A soft fill under the line, then the line, then today's value.
	var fill := PackedVector2Array(pts)
	fill.append(Vector2(pts[pts.size() - 1].x, area.end.y))
	fill.append(Vector2(pts[0].x, area.end.y))
	draw_colored_polygon(fill, Color(color.r, color.g, color.b, 0.15))
	draw_polyline(pts, color, 2.0)
	var last := pts[pts.size() - 1]
	draw_circle(last, 3.5, color)
	draw_string(font, r.position + Vector2(r.size.x - 70, 18), _short(float(history[history.size() - 1][col])), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _short(v: float) -> String:
	if absf(v) >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))
