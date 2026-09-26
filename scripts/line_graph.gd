extends Control

var values: Array      = []
var date_labels: Array = []
var goal_minutes: float = 60.0

const _CLR_LINE  = Color(0.082, 0.502, 0.212, 1.0)
const _CLR_FILL  = Color(0.082, 0.502, 0.212, 0.12)
const _CLR_GOAL  = Color(1.0,   0.55,  0.0,   0.85)
const _CLR_GRID  = Color(0.75,  0.85,  0.78,  1.0)
const _CLR_LABEL = Color(0.353, 0.510, 0.369, 1.0)
const _CLR_DOT   = Color(0.082, 0.157, 0.094, 1.0)

const _PAD_L := 44.0
const _PAD_R := 10.0
const _PAD_T := 12.0
const _PAD_B := 26.0

func _draw() -> void:
	if values.is_empty():
		return
	var w  := size.x
	var h  := size.y
	var pw := w - _PAD_L - _PAD_R
	var ph := h - _PAD_T - _PAD_B

	var max_v := goal_minutes * 1.25
	for v in values:
		if float(v) > max_v:
			max_v = float(v)

	var font      := ThemeDB.fallback_font
	var font_size := 10

	for tick in [0, 30, 60]:
		if tick > max_v + 0.1:
			break
		var y  = _PAD_T + ph * (1.0 - tick / max_v)
		draw_dashed_line(Vector2(_PAD_L, y), Vector2(_PAD_L + pw, y), _CLR_GRID, 1.0, 6.0)
		draw_string(font, Vector2(2.0, y + 4.0), "%d" % tick,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _CLR_LABEL)

	var gy = _PAD_T + ph * (1.0 - clamp(goal_minutes, 0.0, max_v) / max_v)
	draw_dashed_line(Vector2(_PAD_L, gy), Vector2(_PAD_L + pw, gy), _CLR_GOAL, 1.5, 10.0)

	var n   := values.size()
	var pts := PackedVector2Array()
	for i in range(n):
		var x = _PAD_L + pw * (float(i) / max(n - 1, 1))
		var y = _PAD_T + ph * (1.0 - clamp(float(values[i]), 0.0, max_v) / max_v)
		pts.append(Vector2(x, y))

	var poly := PackedVector2Array()
	poly.append(Vector2(pts[0].x, _PAD_T + ph))
	for pt in pts:
		poly.append(pt)
	poly.append(Vector2(pts[n - 1].x, _PAD_T + ph))
	draw_colored_polygon(poly, _CLR_FILL)

	draw_polyline(pts, _CLR_LINE, 2.0, true)

	var step = max(1, n / 7)
	for i in range(n):
		var pt      = pts[i]
		var is_last = (i == n - 1)
		draw_circle(pt, 4.0 if is_last else 2.5, _CLR_DOT if is_last else _CLR_LINE)
		if i % step == 0 or is_last:
			var lbl = date_labels[i].substr(5) if date_labels.size() > i else ""
			draw_string(font, Vector2(pt.x - 14.0, _PAD_T + ph + 18.0), lbl,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _CLR_LABEL)
