class_name MagicTransition
extends RefCounted
## Scene change with a cinematic light reveal: a soft circle of light opens from `origin` (screen
## pixels); the old screen slowly zooms and frosts toward it while the new scene appears underneath,
## edged by a thin glowing rim. (The class name is kept so existing callers keep working.)

const SHADER := preload("res://Assets/Arcade/scene_reveal.gdshader")

static func go(from: Node, scene_path: String, origin_px: Vector2 = Vector2(-1, -1), duration: float = 1.25) -> void:
	var tree := from.get_tree()
	var viewport := from.get_viewport()
	var image: Image = null
	if DisplayServer.get_name() != "headless":      # no screen to capture without a renderer
		image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		tree.change_scene_to_file(scene_path)
		return
	image.generate_mipmaps()                         # the frosted blur samples the smaller levels
	var screen := viewport.get_visible_rect().size
	var origin := Vector2(0.5, 0.5) if origin_px.x < 0 else origin_px / screen
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))

	var layer := CanvasLayer.new()
	layer.layer = 128
	tree.root.add_child(layer)
	var cover := TextureRect.new()
	cover.texture = ImageTexture.create_from_image(image)
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_STOP      # swallow clicks while it plays
	cover.set_meta("full_color", true)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("origin", origin)
	mat.set_shader_parameter("aspect", screen.x / maxf(screen.y, 1.0))
	mat.set_shader_parameter("progress", 0.0)
	cover.material = mat
	layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	tree.change_scene_to_file(scene_path)
	await tree.process_frame
	await tree.process_frame
	if reduced:
		# no travelling light for people who prefer less motion: a short crossfade instead
		var fade := tree.create_tween()
		fade.tween_property(cover, "modulate:a", 0.0, 0.3)
		await fade.finished
		layer.queue_free()
		return
	var tween := tree.create_tween()
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	layer.queue_free()
