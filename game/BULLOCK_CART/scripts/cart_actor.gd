extends Node3D
## Original lightweight cart model. Forward is -Z; feet meet the road at Y=0.
var legs: Array[Node3D] = []
var wheels: Array[Node3D] = []
var phase := 0.0
var body: Node3D
var knees: Array[Node3D] = []
var tails: Array[Node3D] = []
var heads: Array[Node3D] = []
var driver: Node3D
var wood: StandardMaterial3D
var paint := Color("147f83")
var checked_driver := false
var bull_variant := "white"
var boost_aura: MeshInstance3D
var simple_characters: Node3D
var rigged_characters: Node3D
var animation_players: Array[AnimationPlayer] = []
var running_clips: Dictionary = {}
var dust: CPUParticles3D

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return piece(parent, at, mesh, color)

static func ball(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	var result := piece(parent, at, mesh, color)
	result.scale = dimensions
	return result

static func piece(parent: Node3D, at: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = material(color)
	result.position = at
	parent.add_child(result)
	return result

func _ready() -> void:
	wood = preload("res://game/BULLOCK_CART/scripts/surface_materials.gd").textured(Color("583b24"), Color("b98c52"), Vector3(3, 3, 0.3), 15)
	body = Node3D.new()
	add_child(body)
	simple_characters = Node3D.new()
	simple_characters.name = "LightCharacters"
	body.add_child(simple_characters)
	var aura := TorusMesh.new()
	aura.inner_radius = 1.0
	aura.outer_radius = 1.08
	aura.rings = 32
	aura.ring_segments = 6
	boost_aura = piece(self, Vector3(0, 0.1, 0.5), aura, Color("65f7eb"))
	boost_aura.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boost_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boost_aura.hide()
	for plank in range(8):
		box(body, Vector3(-0.72 + plank * 0.205, 0.85, 1.0), Vector3(0.19, 0.16, 1.8), Color.WHITE).material_override = wood
	box(body, Vector3(0, 0.65, 1.05), Vector3(2.1, 0.16, 0.18), Color("493e32"))
	box(body, Vector3(0, 1.1, 1.85), Vector3(1.65, 0.35, 0.1), paint.darkened(0.15))
	for side in [-1.0, 1.0]:
		box(body, Vector3(side * 0.82, 1.15, 1), Vector3(0.1, 0.55, 1.8), paint)
		box(body, Vector3(side * 0.82, 1.48, 1), Vector3(0.13, 0.08, 1.9), Color("efb647"))
		for z in [0.3, 0.8, 1.3, 1.8]:
			ball(body, Vector3(side * 0.89, 1.15, z), Vector3(0.04, 0.13, 0.13), Color("f6c94b"))
		var wheel := Node3D.new()
		body.add_child(wheel)
		wheel.position = Vector3(side * 1.0, 0.74, 1.05)
		wheels.append(wheel)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.60
		rim.outer_radius = 0.72
		rim.rings = 32
		rim.ring_segments = 8
		piece(wheel, Vector3.ZERO, rim, Color("543624")).rotation.z = PI / 2
		var tyre := TorusMesh.new()
		tyre.inner_radius = 0.70
		tyre.outer_radius = 0.74
		tyre.rings = 32
		tyre.ring_segments = 8
		piece(wheel, Vector3.ZERO, tyre, Color("343833")).rotation.z = PI / 2
		ball(wheel, Vector3.ZERO, Vector3(0.26, 0.22, 0.22), Color("ba924e"))
		for angle in range(6):
			var spoke := box(wheel, Vector3.ZERO, Vector3(0.1, 1.34, 0.06), Color("d89c4e"))
			spoke.rotation.x = angle * PI / 6
		box(body, Vector3(side * 0.45, 0.95, -0.7), Vector3(0.09, 0.09, 2.6), Color.WHITE).material_override = wood
		_make_bull(side * 0.72, Color("eee4cf") if side < 0 else Color("ae7650"))
	box(body, Vector3(0, 1.4, -2.4), Vector3(2.2, 0.13, 0.14), Color("9e763d"))
	for x in [-0.72, 0.72]:
		var harness := TorusMesh.new()
		harness.inner_radius = 0.22
		harness.outer_radius = 0.25
		harness.rings = 20
		harness.ring_segments = 6
		piece(simple_characters, Vector3(x, 1.28, -2.05), harness, Color("9b2726")).rotation.x = PI / 2
		for bead in range(5):
			ball(simple_characters, Vector3(x - 0.22 + bead * 0.11, 1.45, -2.18), Vector3(0.09, 0.09, 0.09), Color("e6a628"))
	for side in [-1.0, 1.0]:
		var start := Vector3(side * 0.26, 1.47, -0.23)
		var end := Vector3(side * 0.72, 1.25, -2.4)
		var rope := CylinderMesh.new()
		rope.top_radius = 0.012
		rope.bottom_radius = 0.012
		rope.height = start.distance_to(end)
		rope.radial_segments = 6
		var rein := piece(body, (start + end) * 0.5, rope, Color("593e23"))
		rein.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	# Seated driver, turban, arms and legs; no whip mechanic.
	driver = Node3D.new()
	simple_characters.add_child(driver)
	ball(driver, Vector3(0, 1.65, 0.35), Vector3(0.48, 0.68, 0.35), Color("e3dfc9"))
	ball(driver, Vector3(0, 2.15, 0.3), Vector3(0.32, 0.38, 0.32), Color("9b603e"))
	ball(driver, Vector3(0, 2.14, 0.11), Vector3(0.10, 0.12, 0.14), Color("9b603e"))
	for x in [-0.07, 0.07]:
		ball(driver, Vector3(x, 2.20, 0.15), Vector3(0.035, 0.035, 0.035), Color("2b2b25"))
	for wrap in range(4):
		ball(driver, Vector3(0, 2.29 + wrap * 0.035, 0.3), Vector3(0.43 - wrap * 0.035, 0.12, 0.4), Color("d27b28"))
	for side in [-1.0, 1.0]:
		box(simple_characters, Vector3(side * 0.28, 1.65, 0.02), Vector3(0.13, 0.13, 0.6), Color("f1e5c7"))
		box(simple_characters, Vector3(side * 0.18, 1.12, -0.08), Vector3(0.18, 0.5, 0.2), Color("ece3c9"))
	_build_rigged_characters()
	_build_dust()
	_try_load_glb_body()
	set_character_detail(true)

func _try_load_glb_body() -> void:
	var path := "res://game/BULLOCK_CART/assets/characters/cart_body.glb"
	if not ResourceLoader.exists(path):
		return
	var glb_node := (load(path) as PackedScene).instantiate() as Node3D
	glb_node.name = "GLBCartBody"
	body.add_child(glb_node)
	# Hide procedural shell meshes — wheels are Node3D pivots so their children survive.
	for child in body.get_children():
		if child is MeshInstance3D:
			child.hide()

func _build_dust() -> void:
	dust = CPUParticles3D.new()
	dust.name = "HoofDust"
	add_child(dust)
	dust.position = Vector3(0, .14, -.65)
	dust.amount = 28
	dust.lifetime = .65
	dust.emitting = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(.9, .02, .6)
	dust.direction = Vector3(0, .2, 1)
	dust.spread = 25
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.8
	dust.gravity = Vector3(0, -.6, 0)
	dust.scale_amount_min = .10
	dust.scale_amount_max = .25
	var gradient := Gradient.new()
	gradient.set_color(0, Color(.67, .51, .30, .27))
	gradient.set_color(1, Color(.67, .51, .30, 0))
	dust.color_ramp = gradient
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	dust.mesh = mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_rigged_characters() -> void:
	rigged_characters = Node3D.new()
	rigged_characters.name = "RiggedCharacters"
	body.add_child(rigged_characters)
	var variant_path := "res://game/BULLOCK_CART/assets/characters/bullock_%s.glb" % bull_variant
	var bull_path := variant_path if ResourceLoader.exists(variant_path) else "res://game/BULLOCK_CART/assets/characters/bullock_rigged.glb"
	var bull_scene := load(bull_path) as PackedScene
	for side in [-1.0, 1.0]:
		var bull := bull_scene.instantiate() as Node3D
		rigged_characters.add_child(bull)
		bull.position = Vector3(side * 0.72, 0, -1.55)
		_register_animations(bull, "Walk")
	var driver_path := "res://game/BULLOCK_CART/assets/characters/driver_rigged_checked.glb" if checked_driver else "res://game/BULLOCK_CART/assets/characters/driver_rigged.glb"
	var person := load(driver_path).instantiate() as Node3D
	rigged_characters.add_child(person)
	_register_animations(person, "Ride")

func _register_animations(node: Node, clip: String) -> void:
	if node is AnimationPlayer:
		node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation_name in node.get_animation_list():
			if String(animation_name).contains("Run"):
				node.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
				running_clips[node.get_instance_id()] = animation_name
		for animation_name in node.get_animation_list():
			if String(animation_name).contains(clip):
				node.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
				node.play(animation_name)
				node.advance(0)
				animation_players.append(node)
				break
	for child in node.get_children(): _register_animations(child, clip)

func set_character_detail(high: bool) -> void:
	rigged_characters.visible = high
	simple_characters.visible = not high
	if dust:
		dust.visible = high
		if not high: dust.emitting = false

func _make_bull(x: float, color: Color) -> void:
	var body := simple_characters
	ball(body, Vector3(x, 1.0, -1.55), Vector3(0.65, 0.85, 1.35), color)
	ball(body, Vector3(x, 1.4, -1.8), Vector3(0.52, 0.55, 0.5), color)
	ball(body, Vector3(x, 0.95, -2.05), Vector3(0.23, 0.55, 0.35), color.darkened(0.08))
	var head := Node3D.new()
	body.add_child(head)
	head.position = Vector3(x, 1.3, -2.2)
	heads.append(head)
	ball(head, Vector3(0, -0.05, -0.15), Vector3(0.43, 0.62, 0.65), color)
	ball(head, Vector3(0, -0.26, -0.42), Vector3(0.38, 0.23, 0.24), Color("4f4036"))
	var tail := Node3D.new()
	body.add_child(tail)
	tail.position = Vector3(x, 1.15, -0.95)
	ball(tail, Vector3(0, -0.25, 0.15), Vector3(0.06, 0.6, 0.08), color)
	ball(tail, Vector3(0, -0.57, 0.15), Vector3(0.13, 0.19, 0.12), Color("483a2e"))
	tails.append(tail)
	for side in [-1.0, 1.0]:
		ball(head, Vector3(side * 0.25, 0.1, -0.12), Vector3(0.35, 0.1, 0.17), color)
		ball(head, Vector3(side * 0.2, 0.02, -0.35), Vector3(0.06, 0.07, 0.06), Color("252b2b"))
		for section in range(4):
			var horn := CylinderMesh.new()
			horn.top_radius = 0.055 - section * 0.014
			horn.bottom_radius = 0.069 - section * 0.014
			horn.height = 0.16
			horn.radial_segments = 12
			piece(head, Vector3(side * (0.17 + sin(section * 0.6) * 0.1), 0.28 + section * 0.14, -0.13 + section * 0.025), horn, Color("796e55")).rotation.z = -side * (0.5 - section * 0.25)
		for z in [-1.15, -1.98]:
			var leg := Node3D.new()
			body.add_child(leg)
			leg.position = Vector3(x + side * 0.22, 0.85, z)
			ball(leg, Vector3(0, -0.19, 0), Vector3(0.19, 0.48, 0.20), color)
			var knee := Node3D.new()
			leg.add_child(knee)
			knee.position.y = -0.38
			ball(knee, Vector3(0, -0.16, 0), Vector3(0.12, 0.38, 0.12), color)
			box(knee, Vector3(0, -0.36, -0.03), Vector3(0.18, 0.16, 0.22), Color("453c35"))
			knees.append(knee)
			legs.append(leg)

func animate(delta: float, steering: float, reduced: bool) -> void:
	phase += delta * 7.0
	dust.emitting = rigged_characters.visible and not reduced
	if rigged_characters.visible:
		for player in animation_players:
			var run_clip: String = running_clips.get(player.get_instance_id(), "")
			if not run_clip.is_empty() and player.current_animation != run_clip:
				player.play(run_clip, 0.18)
			player.advance(delta)
	for i in legs.size():
		var gait := phase + (i % 2) * PI + (i / 2 % 2) * PI + (i / 4) * 0.35
		legs[i].rotation.x = sin(gait) * 0.32
		knees[i].rotation.x = maxf(0, cos(gait)) * 0.48
	for wheel in wheels:
		wheel.rotation.x -= delta * 8.0 / 0.74
	for i in heads.size():
		heads[i].rotation.x = 0 if reduced else sin(phase + i * 0.3) * 0.045
		tails[i].rotation.z = 0 if reduced else sin(phase * 0.4 + i) * 0.16
	driver.rotation.x = 0 if reduced else sin(phase * 2) * 0.015
	body.position.y = 0.0 if reduced else sin(phase * 2) * 0.014
	body.rotation.z = 0.0 if reduced else -steering * 0.025

func show_boost(enabled: bool) -> void:
	boost_aura.visible = enabled

func freeze_effects(frozen: bool) -> void:
	dust.speed_scale = 0.0 if frozen else 1.0
	if frozen: dust.emitting = false

