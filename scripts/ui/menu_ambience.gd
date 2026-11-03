extends Control
## Sparse sunlight motes; fixed count and capped redraw rate for smaller devices.
var phase := 0.0
var refresh := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)) or not is_visible_in_tree(): return
	phase += minf(delta, 0.1)
	refresh += delta
	if refresh >= 0.05:
		refresh = 0.0
		queue_redraw()
func _draw() -> void:
	for i in range(18):
		var x := fposmod(float(i) * 83.7 + sin(phase * 0.12 + i) * 16.0, maxf(size.x, 1.0))
		var y := fposmod(float(i) * 137.3 - phase * (4.0 + i % 3), maxf(size.y, 1.0))
		var tint := Color(1.0, 0.87, 0.53, 0.45)
		draw_circle(Vector2(x, y), 1.5 + float(i % 3) * 0.5, tint)
