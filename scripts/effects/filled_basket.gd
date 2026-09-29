@tool
extends TextureRect
## Decorative fruit pile. Count labels remain the authoritative catch totals.
@export var fruit_texture: Texture2D:
	set(value):
		fruit_texture = value
		queue_redraw()
var caught := 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func set_caught(value: int) -> void:
	caught = value
	queue_redraw()
func _draw() -> void:
	if not fruit_texture: return
	var places := [Vector2(19, 25), Vector2(57, 29), Vector2(94, 25), Vector2(38, 6), Vector2(76, 4)]
	for i in places.size():
		draw_texture_rect(fruit_texture, Rect2(places[i], Vector2(39, 39)), false)
	for i in mini(caught, 3):
		draw_texture_rect(fruit_texture, Rect2(Vector2(35 + i * 25, -9), Vector2(34, 34)), false)
	# Foreground rim seats the fruit pile inside the basket opening.
	draw_polyline(PackedVector2Array([Vector2(12, 56), Vector2(38, 64), Vector2(75, 67), Vector2(112, 64), Vector2(140, 56)]), Color("8c4519"), 6, true)
	draw_polyline(PackedVector2Array([Vector2(12, 54), Vector2(38, 61), Vector2(75, 64), Vector2(112, 61), Vector2(140, 54)]), Color("ffd17a"), 3, true)
