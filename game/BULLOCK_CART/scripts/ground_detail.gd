extends RefCounted
## Instanced ground dressing: visual detail without a node for every pebble or footprint.
var groups: Array[Node3D] = []
var sand: StandardMaterial3D

func decorate(parent: Node3D, index: int, sand_surface: StandardMaterial3D, verge_shift := 0.0) -> void:
	sand = sand_surface
	var root := Node3D.new()
	parent.add_child(root)
	groups.append(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1073 + index * 17
	var pebble := SphereMesh.new()
	pebble.radial_segments = 8
	pebble.rings = 4
	var stones: Array[Transform3D] = []
	var prints: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in range(16):
			var at := Vector3(side * (verge_shift + rng.randf_range(4.4, 13.0)), .03, rng.randf_range(-5, 0))
			var width := rng.randf_range(.06, .20)
			stones.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width, width * .45, width * 1.5)), at))
		for i in range(6):
			var at := Vector3(side * (6.9 + verge_shift + .12 * (i % 2)), .006, -i * .7)
			prints.append(Transform3D(Basis(Vector3.UP, side * .15).scaled(Vector3(.12, .008, .28)), at))
		# Low irregular banks break up the flat horizon behind the festival stalls.
		if index % 3 == 0:
			var mound := MeshInstance3D.new()
			var bank := SphereMesh.new()
			bank.radial_segments = 24
			bank.rings = 12
			mound.mesh = bank
			mound.material_override = sand
			mound.position = Vector3(side * (23 + verge_shift), -.4, -2)
			mound.scale = Vector3(19, 2.7 + index % 2, 14)
			root.add_child(mound)
	_batch(root, pebble, stones, Color("877052"))
	_batch(root, pebble, prints, Color("b59a70"))
	if index % 3 == 0:
		var petals: Array[Transform3D] = []
		var x := (-1.0 if index % 2 == 0 else 1.0) * (8.2 + verge_shift)
		for i in range(24):
			var angle := TAU * i / 24
			petals.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.10, .035, .10)), Vector3(x + cos(angle) * .65, .03, .8 + sin(angle) * .65)))
		_batch(root, pebble, petals, Color("e89e27"))
		# A low woven mat in front of a stall gives its entrance a defined place.
		var mat := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.0, 1.25)
		mat.mesh = plane
		mat.position = Vector3(x, .008, -.8)
		mat.material_override = preload("res://game/BULLOCK_CART/scripts/surface_materials.gd").textured(Color("7c4430"), Color("ba8d5c"), Vector3(3, 3, 3), index)
		root.add_child(mat)

func _batch(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], color: Color) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = transforms.size()
	for i in transforms.size(): batch.multimesh.set_instance_transform(i, transforms[i])
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)

func set_detail(high: bool) -> void:
	for i in groups.size(): groups[i].visible = high or i % 4 == 0
