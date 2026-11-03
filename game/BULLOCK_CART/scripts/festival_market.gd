extends RefCounted
## Fixed roadside image planes: layered depth without camera-facing stall rotation.
const MARKET = preload("res://game/BULLOCK_CART/assets/generated/festival-stalls-v2.png")
const FRAMES = preload("res://game/BULLOCK_CART/assets/generated/festival-stalls-v2.json")
var textures: Array[AtlasTexture] = []
var sections: Array[Node3D] = []
var backdrop_planes: Array[Sprite3D] = []

func decorate(group: Node3D, index: int, verge_shift := 0.0) -> void:
	# A continuous second row fills the spaces between the varied foreground stalls.
	# Recycle with the existing 5 m scenery groups; all planes share one texture.
	for side in [-1.0, 1.0]:
		var backdrop := Sprite3D.new()
		backdrop.texture = preload("res://game/BULLOCK_CART/assets/generated/festival-market.png")
		backdrop.pixel_size = 4.8 / backdrop.texture.get_height()
		backdrop.offset.y = backdrop.texture.get_height() * .40
		backdrop.position = Vector3(side * (12.5 + verge_shift), 0, -2.5)
		backdrop.rotation.y = -side * PI / 3
		backdrop.flip_h = (index + (1 if side > 0 else 0)) % 2 == 0
		backdrop.modulate = Color(.86, .85, .80)
		backdrop.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		backdrop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(backdrop)
		backdrop_planes.append(backdrop)
	if index % 2 != 0: return
	if textures.is_empty():
		textures = preload("res://game/BULLOCK_CART/scripts/festival_atlas.gd").regions(MARKET, FRAMES)
		var original := AtlasTexture.new()
		original.atlas = preload("res://game/BULLOCK_CART/assets/generated/festival-market.png")
		original.region = Rect2(Vector2.ZERO, original.atlas.get_size())
		original.filter_clip = true
		textures.append(original)
	var section := Node3D.new()
	group.add_child(section)
	sections.append(section)
	for side in [-1.0, 1.0]:
		var market := Sprite3D.new()
		var variant: int = (int(index / 2) + (3 if side > 0 else 0)) % textures.size()
		market.texture = textures[variant]
		market.set_meta("variant", variant)
		market.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		market.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		market.pixel_size = (3.6 + .15 * (index % 3)) / market.texture.get_height()
		# Feet are around 90% down the source; transparent padding is below them.
		market.offset.y = market.texture.get_height() * .5
		if variant == 6:
			market.pixel_size = 4.8 / market.texture.get_height()
			market.offset.y = market.texture.get_height() * .40
		market.position = Vector3(side * (9.2 + verge_shift + .3 * (index % 3)), 0, -1.2 - (index % 3))
		if variant == 6: market.position.x = side * (10.8 + verge_shift + .3 * (index % 3))
		market.rotation.y = -side * PI / (3.0 + (index % 3) * .25)
		market.flip_h = false
		market.modulate = Color(.92, .89, .82)
		market.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		section.add_child(market)

func set_detail(high: bool) -> void:
	# Keep the continuous background even in Light mode; thin foreground dressing.
	for i in sections.size(): sections[i].visible = high or i % 2 == 0
