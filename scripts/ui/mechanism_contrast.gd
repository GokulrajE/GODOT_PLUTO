@tool
extends TextureRect
## Preserve the icon alpha while choosing black/white from its card surface.
var elapsed := 0.0
var image_cache: Dictionary = {}
func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 ink : source_color = vec4(0.,0.,0.,1.); void fragment(){ COLOR=vec4(ink.rgb,texture(TEXTURE,UV).a * ink.a); }"
	material = ShaderMaterial.new()
	material.shader = shader
	_update_ink()
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.2: return
	elapsed = 0
	_update_ink()
func _update_ink() -> void:
	if not material: return
	var background := Color.WHITE
	var node := get_parent()
	while node:
		var style: StyleBox
		if node is Button: style = node.get_theme_stylebox("pressed" if node.button_pressed else "normal")
		elif node is Panel or node is PanelContainer: style = node.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			background = style.bg_color
			break
		if style is StyleBoxTexture and style.texture:
			var key: int = style.texture.get_instance_id()
			if not image_cache.has(key): image_cache[key] = style.texture.get_image()
			var img: Image = image_cache[key]
			if img: background = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
			break
		node = node.get_parent()
	var luminance := background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
	material.set_shader_parameter("ink", Color.BLACK if luminance > 0.5 else Color.WHITE)
	self_modulate = Color.WHITE
	modulate = Color.WHITE
