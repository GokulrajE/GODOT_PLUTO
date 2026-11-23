extends Control
## Stacked bar showing how the session time is split between mechanisms.
## `segments` = [{minutes, color}]; `capacity` > 0 draws the unused part of the limit as an empty track.

var segments: Array = []
var capacity := 0.0
var over := false

func set_data(new_segments: Array, new_capacity: float, is_over: bool) -> void:
	segments = new_segments
	capacity = new_capacity
	over = is_over
	queue_redraw()

func _draw() -> void:
	var radius := size.y * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e1ebef")
	track.set_corner_radius_all(int(radius))
	track.border_color = Color("c4d4da") if not over else Color("c0273a")
	track.set_border_width_all(1)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var total := 0.0
	for seg in segments: total += float(seg.minutes)
	var scale_to := maxf(capacity, total)
	if scale_to <= 0.0: return
	var x := 0.0
	var count := segments.size()
	for i in count:
		var seg: Dictionary = segments[i]
		var w := size.x * float(seg.minutes) / scale_to
		if w <= 0.5: continue
		var r := Rect2(x, 2, minf(w, size.x - x), size.y - 4)
		var box := StyleBoxFlat.new()
		box.bg_color = seg.color
		box.corner_radius_top_left = int(radius) - 2 if i == 0 else 3
		box.corner_radius_bottom_left = box.corner_radius_top_left
		var last := (x + w) >= size.x - 1.0
		box.corner_radius_top_right = int(radius) - 2 if last else 3
		box.corner_radius_bottom_right = box.corner_radius_top_right
		draw_style_box(box, r)
		var font := get_theme_default_font()
		if w > 54.0:
			draw_string(font, Vector2(r.position.x + 10, r.position.y + r.size.y * 0.5 + 6), "%d min" % int(seg.minutes), HORIZONTAL_ALIGNMENT_LEFT, w - 12, 15, Color.WHITE)
		x += w + 2.0
