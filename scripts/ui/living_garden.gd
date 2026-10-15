@tool
extends TextureRect
## Background-only motion; form controls remain stationary.
var elapsed := 0.0

func _process(delta: float) -> void:
	if not material is ShaderMaterial:
		return
	var reduced := Engine.is_editor_hint() or bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	elapsed = 0.0 if reduced else elapsed + minf(delta, 0.1)
	material.set_shader_parameter("phase", elapsed)
