extends Control
## Little numbered flags planted on the range bar: one pole per AROM cycle end (1, 2, 3, 4, 5).
## Low ends carry a flag that points right, high ends a flag that points left, so the two groups
## fly toward each other; neighbouring cycles alternate between two pole heights so they do not
## sit on top of each other. The best cycle of a finished trial is drawn in gold.

const FLAG_W := 26.0
const FLAG_H := 17.0
const POLE := Color("2b4666")

## [{x, color, label, best, side, level}] in this control's own coordinates.
var items: Array = []
var track_top := 40.0
var track_bottom := 62.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("arcade_authored_control", true)

func set_items(new_items: Array, top: float, bottom: float) -> void:
	items = new_items
	track_top = top
	track_bottom = bottom
	queue_redraw()

func _text_color(fill: Color) -> Color:
	var luminance := fill.r * 0.2126 + fill.g * 0.7152 + fill.b * 0.0722
	return Color("1d2b3a") if luminance > 0.62 else Color.WHITE

func _draw() -> void:
	var font := get_theme_default_font()
	# draw the best cycle last so its flag is never hidden by a neighbour
	var ordered := items.duplicate()
	ordered.sort_custom(func(a, b): return int(a.best) < int(b.best))
	for item in ordered:
		var x: float = item.x
		var side: float = item.side
		var top: float = track_top - 16.0 - float(item.level) * 18.0
		var fill: Color = item.color
		var outline := fill.darkened(0.45)
		# pole and the foot where it meets the bar
		draw_line(Vector2(x, top), Vector2(x, track_bottom - 1.0), POLE, 2.0, true)
		draw_circle(Vector2(x, (track_top + track_bottom) * 0.5), 3.4, Color.WHITE)
		draw_arc(Vector2(x, (track_top + track_bottom) * 0.5), 3.4, 0.0, TAU, 12, POLE, 1.4, true)
		# swallow-tail pennant
		var w := FLAG_W + (3.0 if item.best else 0.0)
		var h := FLAG_H + (2.0 if item.best else 0.0)
		var points := PackedVector2Array([
			Vector2(x, top), Vector2(x + side * w, top), Vector2(x + side * (w - 6.0), top + h * 0.5),
			Vector2(x + side * w, top + h), Vector2(x, top + h),
		])
		draw_colored_polygon(points, fill)
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, outline, 1.6 if item.best else 1.2, true)
		var label: String = item.label
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var cx := x + side * (w - 6.0) * 0.5
		draw_string(font, Vector2(cx - size.x * 0.5, top + h * 0.5 + 4.6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _text_color(fill))
