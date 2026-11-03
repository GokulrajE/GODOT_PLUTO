extends RefCounted
## Small procedural textures generated once, with no asset/network dependencies.
static func textured(dark: Color, light: Color, grain: Vector3, seed_value: int) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.uv1_triplanar = true
	mat.uv1_scale = grain
	mat.roughness = 0.95
	return mat
