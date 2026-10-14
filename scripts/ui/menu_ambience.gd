extends Control
## Small drifting highlights at the margins, away from patient instructions.
var phase := 0.0
var refresh := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
		if phase != 0.0:
			phase = 0.0
			queue_redraw()
		return
	phase += delta
	refresh += delta
	if refresh >= 0.033:
		refresh = 0.0
		queue_redraw()
func _draw() -> void:
	for i in range(8):
		var x := 18.0 + float(i % 2) * (size.x - 36.0)
		var y := 110.0 + float(i / 2) * 165.0 + sin(phase * 0.55 + i) * 9.0
		var tint := Color("4a9d91") if i % 2 == 0 else Color("b89048")
		tint.a = 0.3
		draw_circle(Vector2(x, y), 3.0 + float(i % 3), tint)
