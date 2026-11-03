extends RefCounted
## Transparent 2D roadside cut-outs, using the same low-cost Sprite3D treatment
## as the stalls and family crowd artwork.
var temples: Array[Sprite3D] = []
var phase := 0.0
var _temple_tex: Texture2D  # loaded on first use so Godot can import the PNG first

func decorate(group: Node3D, index: int, verge_shift := 0.0) -> void:
	# Realistic stone gopuram placed far back so it reads as a distant landmark.
	# The PNG is wider than the old SVG (temple + flanking trees) so width is larger.
	if index % 12 == 0:
		if not _temple_tex:
			_temple_tex = load("res://game/BULLOCK_CART/assets/generated/temple-realistic.png")
		if _temple_tex:
			for side in [-1.0, 1.0]:
				# Neutral tint — realistic PNG already has correct colour; just soften slightly for afternoon haze.
				temples.append(_sprite(group, _temple_tex, side, 22.0 + verge_shift, -5.5, 13.0, index, Color(.97, .95, .90)))

func _sprite(parent: Node3D, texture: Texture2D, side: float, distance: float, z: float, width: float, _variation: int, tint := Color(.92, .90, .82)) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = width / texture.get_width()
	sprite.offset.y = texture.get_height() * .5
	sprite.position = Vector3(side * distance, 0, z)
	# BILLBOARD_FIXED_Y: sprite always turns to face the camera on the Y axis.
	# Correct for isometric-view images (temple) — fixed rotation only suits front-facing photos.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.flip_h = side < 0  # mirror on left side so isometric depth reads correctly
	sprite.modulate = tint
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return sprite

func set_detail(_high: bool) -> void:
	pass

func animate(delta: float, reduced: bool) -> void:
	if reduced: return
	phase += delta
	# A small warm pulse makes the painted Pongal lamps feel alive without moving
	# geometry or affecting the road's gameplay readability.
	for i in temples.size(): temples[i].modulate = Color(.90 + sin(phase * 1.8 + i) * .025, .88 + sin(phase * 1.8 + i) * .018, .80)
