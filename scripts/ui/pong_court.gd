@tool
extends Node2D
## Court geometry is visible in the editor and at runtime.
func _draw() -> void:
	# Quiet dark lanes separate the paddles from the bright arena stands.
	for x in [35.0, 1091.0]:
		var lane := StyleBoxFlat.new()
		lane.bg_color = Color("10243a")
		lane.border_color = Color("56768d")
		lane.set_border_width_all(1)
		lane.set_corner_radius_all(12)
		draw_style_box(lane, Rect2(x, 90, 40, 530))
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color("8a79d8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	draw_style_box(style, Rect2(24, 86, 1118, 538))
	draw_arc(Vector2(583, 355), 62, 0, TAU, 64, Color(0.58, 0.52, 0.88, 0.45), 2, true)
