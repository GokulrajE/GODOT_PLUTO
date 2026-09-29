extends TextureRect
## Mirrored panorama loops continuously without seams or gameplay displacement.
var scroll_phase := 0.0
func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float phase = 0.0; void fragment(){ vec2 uv=UV; uv.x=1.0-abs(mod(uv.x+phase,2.0)-1.0); COLOR=texture(TEXTURE,uv); }"
	material = ShaderMaterial.new()
	material.shader = shader
func step(delta: float, running: bool, paused: bool) -> void:
	if not running or paused or bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)): return
	scroll_phase = fmod(scroll_phase + delta * 0.035, 2.0)
	material.set_shader_parameter("phase", scroll_phase)
