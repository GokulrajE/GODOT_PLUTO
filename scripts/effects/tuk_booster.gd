@tool
extends Node2D
## Visual-only exhaust, anchored in the vehicle's local coordinate system.
var last_y := 0.0
var elapsed := 0.0
var firing := false
var flame_length := 38.0
func _ready() -> void:
	show_behind_parent = true
	position = Vector2(8, 74)
	if not Engine.is_editor_hint(): last_y = get_parent().position.y
func step(delta: float, running: bool, paused: bool) -> void:
	if paused: return
	var player := get_parent() as Control
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	if player:
		player.pivot_offset = player.size * 0.5
		var velocity := (player.position.y - last_y) / maxf(delta, 0.001)
		last_y = player.position.y
		var target := clampf(velocity * 0.00042, -0.12, 0.12) if running and not reduced else 0.0
		player.rotation = 0.0 if reduced else lerpf(player.rotation, target, 1.0 - exp(-10.0 * delta))
	firing = running
	if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
		flame_length = 38
	else:
		if running: elapsed += delta
		flame_length = 68 + sin(elapsed * 22) * 12 + sin(elapsed * 37) * 4
	queue_redraw()
func _draw() -> void:
	if firing or Engine.is_editor_hint():
		# Traveling exhaust rings replace a static-looking plume.
		if not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
			for i in 4:
				var phase := fmod(elapsed * 2.8 + i * 0.25, 1.0)
				draw_arc(Vector2(-18 - phase * 76, 0), 5 + phase * 10, -PI * 0.6, PI * 0.6, 16, Color(0.2, 0.95, 1.0, (1.0 - phase) * 0.7), 2.5, true)
		draw_circle(Vector2(-15, 0), 28, Color(0.2, 0.85, 1, 0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -9), Vector2(-23, -12), Vector2(-flame_length, -3), Vector2(-flame_length - 9, 0), Vector2(-flame_length, 3), Vector2(-23, 12), Vector2(-4, 9)]), Color("217bff"))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -6), Vector2(-20, -7), Vector2(-flame_length * 0.8, 0), Vector2(-20, 7), Vector2(-4, 6)]), Color("32f3ff"))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(-flame_length * 0.5, 0), Vector2(-4, 3)]), Color("e4fcff"))
	draw_rect(Rect2(-8, -10, 15, 20), Color("142144"))
	draw_rect(Rect2(-9, -8, 5, 16), Color("8bc5ee"))
	draw_line(Vector2(-5, -7), Vector2(5, -7), Color("e1f8ff"), 2)
