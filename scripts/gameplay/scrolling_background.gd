extends TextureRect
## Mirrored panorama loops continuously without seams or gameplay displacement.
var scroll_phase := 0.0
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://Assets/Arcade/scrolling-panorama.gdshader")

func step(delta: float, running: bool, paused: bool) -> void:
	if not running or paused or bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)): return
	scroll_phase = fmod(scroll_phase + delta * 0.035, 2.0)
	material.set_shader_parameter("phase", scroll_phase)
