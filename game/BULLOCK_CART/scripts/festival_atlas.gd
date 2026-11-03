extends RefCounted
## Original PNGs are untouched; alpha bounds define six aligned atlas regions.
static func regions(atlas: Texture2D, data: JSON) -> Array[AtlasTexture]:
	var textures: Array[AtlasTexture] = []
	for frame in data.data.frames:
		var bounds: Array = frame.region
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
		texture.filter_clip = true
		textures.append(texture)
	return textures
