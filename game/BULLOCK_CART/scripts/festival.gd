extends RefCounted
## Foreground spectators plus layered photographic market scenery.
const Shape = preload("res://game/BULLOCK_CART/scripts/cart_actor.gd")
var cheering_arms: Array[Node3D] = []
var crowds: Array[Node3D] = []
var simple_people: Array[Node3D] = []
var photo_people: Array[Sprite3D] = []
var crowd_textures: Array[AtlasTexture] = []
var phase := 0.0
var cheer_strength := 0.0
var high_detail := true
var market := preload("res://game/BULLOCK_CART/scripts/festival_market.gd").new()
var festoons := preload("res://game/BULLOCK_CART/scripts/festival_festoons.gd").new()

func rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 8
	var item := Shape.piece(parent, (start + end) * 0.5, mesh, color)
	item.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

func decorate(group: Node3D, index: int, verge_shift := 0.0) -> void:
	market.decorate(group, index, verge_shift)
	festoons.decorate(group, index, verge_shift)
	if index % 2 == 0:
		for crowd_side in [-1.0, 1.0]:
			for i in range(2):
				var spectator := Node3D.new()
				group.add_child(spectator)
				spectator.position = Vector3(crowd_side * (5.8 + verge_shift + (i % 2) * .35), 0, -3.5 + i * 2.4)
				spectator.rotation.y = -crowd_side * PI / 2
				crowds.append(spectator)
				# Retain the compatibility slot without constructing hidden 3D people.
				var simple := Node3D.new()
				spectator.add_child(simple)
				simple_people.append(simple)
				_photo_person(spectator, i + index + (5 if crowd_side > 0 else 0))

func _photo_person(parent: Node3D, variation: int) -> void:
	if crowd_textures.is_empty():
		crowd_textures = preload("res://game/BULLOCK_CART/scripts/festival_atlas.gd").regions(
			preload("res://game/BULLOCK_CART/assets/generated/festival-families-v2.png"),
			preload("res://game/BULLOCK_CART/assets/generated/festival-families-v2.json"))
		var original = preload("res://game/BULLOCK_CART/assets/generated/tamil-cheering-crowd.png")
		for region in [Rect2(0, 0, 500, 887), Rect2(500, 0, 400, 887), Rect2(900, 0, 450, 887), Rect2(1350, 0, 424, 887)]:
			var texture := AtlasTexture.new()
			texture.atlas = original
			texture.region = region
			texture.filter_clip = true
			crowd_textures.append(texture)
	var person := Sprite3D.new()
	person.texture = crowd_textures[variation % crowd_textures.size()]
	person.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	person.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	person.pixel_size = (2.15 + (variation % 3) * .035) / person.texture.get_height()
	person.offset.y = person.texture.get_height() * .5
	if variation % crowd_textures.size() >= 6: person.offset.y -= 14
	person.flip_h = variation % 3 == 0
	person.set_meta("variant", variation % crowd_textures.size())
	person.modulate = Color(.87, .84, .78)
	parent.add_child(person)
	photo_people.append(person)
	# A soft-colored contact patch anchors the billboard's feet on the sand.
	var shadow := CylinderMesh.new()
	shadow.top_radius = .25
	shadow.bottom_radius = .25
	shadow.height = .003
	shadow.radial_segments = 16
	var contact := Shape.piece(parent, Vector3(0, .005, 0), shadow, Color("a68d67"))
	contact.scale.z = .6
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _person(parent: Node3D, shirt: Color, variation: int) -> void:
	var skin := Color("9f6f4a") if variation % 2 else Color("815536")
	var height := .90 + (variation % 3) * .07
	parent.scale = Vector3.ONE * height
	Shape.ball(parent, Vector3(0, 1.17, 0), Vector3(.42, .6, .27), shirt)
	Shape.ball(parent, Vector3(0, 1.68, 0), Vector3(.27, .33, .26), skin)
	Shape.ball(parent, Vector3(0, 1.69, -.14), Vector3(.075, .08, .07), skin)
	Shape.ball(parent, Vector3(0, 1.83, .015), Vector3(.29, .12, .26), Color("452b21") if variation % 2 else Color("bc772d"))
	for side in [-1.0, 1.0]:
		rod(parent, Vector3(side * .11, .12, 0), Vector3(side * .11, .92, 0), .075, Color("e1cfaa"))
		Shape.box(parent, Vector3(side * .11, .06, -.05), Vector3(.16, .12, .28), Color("4b3c30"))
		var arm := Node3D.new()
		parent.add_child(arm)
		arm.position = Vector3(side * .22, 1.40, 0)
		arm.set_meta("phase", variation * .9 + side)
		arm.set_meta("side", side)
		cheering_arms.append(arm)
		rod(arm, Vector3.ZERO, Vector3(side * .14, .32, -.07), .065, shirt)
		rod(arm, Vector3(side * .14, .32, -.07), Vector3(side * .03, .63, -.10), .045, skin)
		Shape.ball(arm, Vector3(side * .03, .65, -.10), Vector3(.11, .15, .08), skin)

func set_detail(high: bool) -> void:
	high_detail = high
	market.set_detail(high)
	festoons.set_detail(high)
	for i in crowds.size(): crowds[i].visible = high or i % 2 == 0
	for simple in simple_people: simple.visible = false
	for person in photo_people: person.visible = true

func advance(delta: float, reduced: bool) -> void:
	if reduced:
		festoons.animate(phase, true)
		return
	phase += delta
	festoons.animate(phase, false)
	cheer_strength = maxf(0, cheer_strength - delta * .6)
	for arm in cheering_arms:
		if not arm.is_visible_in_tree(): continue
		arm.rotation.z = sin(phase * 4.0 + float(arm.get_meta("phase"))) * (.32 + cheer_strength * .24)
		arm.rotation.x = .15 + sin(phase * 3.2 + float(arm.get_meta("phase"))) * .22
	if high_detail:
		for i in photo_people.size():
			photo_people[i].position.y = absf(sin(phase * 5 + i * .8)) * .018 * cheer_strength
