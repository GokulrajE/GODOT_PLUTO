extends RefCounted
## Transparent decorative PNGs share one texture and the paused simulation clock.
const FLAGS_LIGHTS = preload("res://game/BULLOCK_CART/assets/generated/road-flags-lights.png")
const Shape = preload("res://game/BULLOCK_CART/scripts/cart_actor.gd")
var sections: Array[Node3D] = []
var strings: Array[Sprite3D] = []

func _string(parent: Node3D, position: Vector3, width: float, turn: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = FLAGS_LIGHTS
	sprite.pixel_size = width / FLAGS_LIGHTS.get_width()
	sprite.position = position
	sprite.rotation.y = turn
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	strings.append(sprite)

func decorate(group: Node3D, index: int, verge_shift := 0.0) -> void:
	if index % 4 != 0: return
	var section := Node3D.new()
	group.add_child(section)
	sections.append(section)
	var height := 7.5 if verge_shift > 0 else 5.5
	# Visible pennants stay above 4.7 m, clear of cart, driver and follow cameras.
	_string(section, Vector3(0, height, 0), 11.6 + verge_shift * 2, 0)
	strings[-1].scale.y = 11.6 / (11.6 + verge_shift * 2)
	for side in [-1.0, 1.0]:
		# Side strings run with the road; they do not swivel toward the camera.
		_string(section, Vector3(side * (5.8 + verge_shift), height, -5.8), 11.6, PI / 2)
		for z in [0.0, -11.6]:
			var pole := CylinderMesh.new()
			pole.top_radius = .045
			pole.bottom_radius = .06
			pole.height = height + .93
			pole.radial_segments = 6
			Shape.piece(section, Vector3(side * (5.8 + verge_shift), pole.height * .5, z), pole, Color("786248"))

func set_detail(high: bool) -> void:
	for i in sections.size(): sections[i].visible = high or i % 2 == 0

func animate(phase: float, reduced: bool) -> void:
	for i in strings.size():
		strings[i].rotation.x = 0 if reduced else sin(phase * 1.7 + i * .8) * .025
