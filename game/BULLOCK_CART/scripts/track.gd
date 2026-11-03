extends Node3D
const Model = preload("res://game/BULLOCK_CART/scripts/cart_actor.gd")
const TREE = preload("res://game/BULLOCK_CART/assets/models/tree_oak.glb")
const ROCK = preload("res://game/BULLOCK_CART/assets/models/rock_largeA.glb")
var road_width := 8.6
var scenery: Array[Node3D] = []
var road_material: StandardMaterial3D
var road: MeshInstance3D
var sand_material: StandardMaterial3D
var low_road: StandardMaterial3D
var panorama: MeshInstance3D
var simple_trees: Array[Node3D] = []
var detailed_trees: Array[Sprite3D] = []
var simple_buildings: Array[Node3D] = []
const Surfaces = preload("res://game/BULLOCK_CART/scripts/surface_materials.gd")
var festival := preload("res://game/BULLOCK_CART/scripts/festival.gd").new()
var ground_detail := preload("res://game/BULLOCK_CART/scripts/ground_detail.gd").new()
var pongal_landmarks := preload("res://game/BULLOCK_CART/scripts/pongal_landmarks.gd").new()

func _ready() -> void:
	var verge_shift := (road_width - 8.6) * .5
	sand_material = Surfaces.textured(Color("b99358"), Color("e4c58c"), Vector3(0.75, 0.75, 0.75), 73)
	sand_material.albedo_color = Color(.68, .68, .68)
	Model.box(self, Vector3(0, -0.16, -35), Vector3(160, 0.25, 180), Color.WHITE).material_override = sand_material
	road_material = Surfaces.textured(Color("aa7f48"), Color("d9b579"), Vector3(0.8, 0.8, 0.8), 24)
	low_road = road_material
	road = Model.box(self, Vector3(0, -0.01, -35), Vector3(road_width, 0.08, 180), Color.WHITE)
	road.material_override = road_material
	for i in range(24):
		var group := Node3D.new()
		add_child(group)
		group.position = Vector3(0, 0, 9 - i * 5)
		scenery.append(group)
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree := TREE.instantiate() as Node3D
		group.add_child(tree)
		tree.position.x = side * (15.0 + verge_shift + i % 3 * 2)
		tree.scale = Vector3.ONE * (2.6 + (i % 3) * 0.45)
		tree.rotation.y = i * 1.7
		simple_trees.append(tree)
		var detailed_tree := Sprite3D.new()
		detailed_tree.texture = load("res://game/BULLOCK_CART/assets/generated/neem-tree.png")
		detailed_tree.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		detailed_tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		detailed_tree.pixel_size = 7.5 / detailed_tree.texture.get_height()
		detailed_tree.offset.y = detailed_tree.texture.get_height() * 0.5
		detailed_tree.position.x = tree.position.x
		detailed_tree.flip_h = i % 2 == 0
		group.add_child(detailed_tree)
		detailed_trees.append(detailed_tree)
		var rock := ROCK.instantiate() as Node3D
		group.add_child(rock)
		rock.position = Vector3(-side * (8.0 + verge_shift), 0, -1.8)
		rock.scale = Vector3.ONE * 0.7
		for edge in [-1.0, 1.0]:
			Model.box(group, Vector3(edge * (4.9 + verge_shift), 0.45, 0), Vector3(0.12, 0.9, 0.12), Color("86633d"))
			Model.box(group, Vector3(edge * (4.9 + verge_shift), 0.65, -2.5), Vector3(0.08, 0.09, 5.0), Color("aa8755"))
		if i % 4 == 0:
			var first_building_part := group.get_child_count()
			var house_x := side * (11.0 + verge_shift + i % 3)
			Model.box(group, Vector3(house_x, 1.5, -2), Vector3(4, 3, 4), Color("d6bb8d"))
			var roof := CylinderMesh.new()
			roof.top_radius = 0.0
			roof.bottom_radius = 3.2
			roof.height = 1.6
			roof.radial_segments = 4
			Model.piece(group, Vector3(house_x, 3.8, -2), roof, Color("8c5d43")).rotation.y = PI / 4
			Model.box(group, Vector3(house_x, 0.8, 0.02), Vector3(0.9, 1.6, 0.08), Color("594d38"))
			for dx in [-1.25, 1.25]:
				Model.box(group, Vector3(house_x + dx, 1.7, 0.04), Vector3(0.65, 0.7, 0.1), Color("314e4a"))
				Model.box(group, Vector3(house_x + dx, 1.7, 0.1), Vector3(0.06, 0.75, 0.08), Color("ad8b5c"))
			Model.box(group, Vector3(house_x, 0.12, 0.55), Vector3(1.6, 0.22, 1), Color("999381"))
			for part in range(first_building_part, group.get_child_count()): simple_buildings.append(group.get_child(part))
		# Small roadside shrubs soften the edge of the track.
		for shrub in range(3):
			Model.ball(group, Vector3(side * (13.8 + verge_shift + shrub * 0.6), 0.22, -1.5 - shrub), Vector3(0.8, 0.65, 0.7), Color("627843"))
		festival.decorate(group, i, verge_shift)
		pongal_landmarks.decorate(group, i, verge_shift)
		ground_detail.decorate(group, i, sand_material, verge_shift)
	if road_width > 10:
		# Soft, translucent wheel ruts suggest lanes without painted road stripes.
		var rut_shader := Shader.new()
		rut_shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled; void fragment(){ float edge = 1.0 - smoothstep(0.10, 0.50, abs(UV.x - 0.5)); float grain = 0.75 + 0.25 * sin(UV.y * 960.0); ALBEDO = vec3(0.23, 0.16, 0.08); ALPHA = edge * grain * 0.45; }"
		var rut_material := ShaderMaterial.new()
		rut_material.shader = rut_shader
		var rut_mesh := PlaneMesh.new()
		rut_mesh.size = Vector2(.25, 180)
		for lane in range(5):
			for wheel in [-.75, .75]:
				var rut := MeshInstance3D.new()
				rut.mesh = rut_mesh
				rut.material_override = rut_material
				rut.position = Vector3((lane - 2) * 2.8 + wheel, .035, -35)
				rut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(rut)
	# Distant matte plate has no collision or gameplay elements.
	panorama = MeshInstance3D.new()
	# Wrap the plate behind the track so camera changes cannot expose a flat edge.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment in range(49):
		var u := float(segment) / 48.0
		var angle := lerpf(-2.1, 2.1, u)
		for row in range(2):
			vertices.append(Vector3(sin(angle) * 115, 136.0 - row * 247.5, -cos(angle) * 115))
			uvs.append(Vector2(u, row))
		if segment < 48:
			var v := segment * 2
			indices.append_array(PackedInt32Array([v, v + 1, v + 2, v + 2, v + 1, v + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var backdrop_mesh := ArrayMesh.new()
	backdrop_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	panorama.mesh = backdrop_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load("res://game/BULLOCK_CART/assets/generated/village-panorama.png")
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	panorama.material_override = mat
	panorama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panorama)

func set_detail(high: bool) -> void:
	festival.set_detail(high)
	pongal_landmarks.set_detail(high)
	ground_detail.set_detail(high)
	for tree in simple_trees: tree.visible = not high
	for tree in detailed_trees: tree.visible = high
	for building in simple_buildings: building.visible = not high
	if high:
		road_material = StandardMaterial3D.new()
		road_material.albedo_color = Color(1.0, 0.89, 0.65)
		road_material.albedo_texture = load("res://game/BULLOCK_CART/assets/terrain/dirt_diff_4k.jpg")
		road_material.normal_enabled = true
		road_material.normal_texture = load("res://game/BULLOCK_CART/assets/terrain/dirt_nor_gl_4k.jpg")
		road_material.roughness_texture = load("res://game/BULLOCK_CART/assets/terrain/dirt_rough_4k.jpg")
		road_material.uv1_triplanar = true
		road_material.uv1_scale = Vector3.ONE * 0.22
	else: road_material = low_road
	road.material_override = road_material

func advance(distance: float, delta: float, reduced: bool) -> void:
	festival.advance(delta, reduced)
	pongal_landmarks.animate(delta, reduced)
	sand_material.uv1_offset.z = fposmod(sand_material.uv1_offset.z - distance * sand_material.uv1_scale.z, 256.0)
	road_material.uv1_offset.z = fposmod(road_material.uv1_offset.z - distance * road_material.uv1_scale.z, 256.0)
	for group in scenery:
		group.position.z += distance
		if group.position.z > 14:
			group.position.z -= 120
