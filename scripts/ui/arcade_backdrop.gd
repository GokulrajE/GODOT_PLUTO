@tool
extends Control
## Quiet daylight canvas shared by authored menu scenes.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f1f8fc"))
	draw_circle(Vector2(size.x, 0), size.x * 0.32, Color("e3f3f4"))
	draw_circle(Vector2(0, size.y), size.x * 0.24, Color("e5effa"))
