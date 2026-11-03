extends Node3D
## Reusable bursts, stepped with gameplay so pause and reduced motion are respected.
## tier: 0=coin  1=power  2=rare  3=power3x
const Shape = preload("res://game/BULLOCK_CART/scripts/cart_actor.gd")
var bursts: Array[Dictionary] = []
var next_burst := 0


static func _make_star_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var fx := (float(x) - half + 0.5) / half
			var fy := (float(y) - half + 0.5) / half
			var arm_x := maxf(0.0, 1.0 - absf(fy) * 6.0) * maxf(0.0, 1.0 - absf(fx) * 1.5)
			var arm_y := maxf(0.0, 1.0 - absf(fx) * 6.0) * maxf(0.0, 1.0 - absf(fy) * 1.5)
			var star := clampf((arm_x + arm_y) * 2.0, 0.0, 1.0)
			var r := Vector2(fx, fy).length()
			var glow := maxf(0.0, 1.0 - r * 2.5)
			var alpha := clampf(star + glow * glow * 0.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

static func _load_flower_textures() -> Array:
	var names := ["flower_cherry.png", "flower_hibiscus.png", "flower_sunflower.png",
				  "flower_tulip.png", "flower_blossom.png"]
	var out: Array = []
	for n in names:
		var img := Image.load_from_file(
			"res://game/BULLOCK_CART/assets/generated/" + n)
		if img:
			out.append(ImageTexture.create_from_image(img))
	return out

func _ready() -> void:
	var star_tex := _make_star_texture(64)
	var flower_texs: Array = _load_flower_textures()
	for i in range(6):
		var root := Node3D.new()
		add_child(root)

		# Aura ring — 3 concentric tori: tight core + wider mid glow + broad outer halo
		var aura_rings: Array[MeshInstance3D] = []
		var ring_defs: Array = [
			[0.44, 0.50, 24, 6],   # core  — narrow, fully opaque
			[0.30, 0.62, 24, 6],   # mid   — wider, semi-transparent
			[0.10, 0.80, 24, 6],   # halo  — very wide, faint
		]
		for layer in ring_defs.size():
			var tm := TorusMesh.new()
			tm.inner_radius = ring_defs[layer][0]
			tm.outer_radius = ring_defs[layer][1]
			tm.rings = ring_defs[layer][2]
			tm.ring_segments = ring_defs[layer][3]
			var ar := Shape.piece(root, Vector3.ZERO, tm, Color.WHITE)
			ar.rotation.x = PI / 2
			aura_rings.append(ar)

		# Flowers — 8 billboard quads, each showing a different emoji flower
		var gems: Array[MeshInstance3D] = []
		for j in range(8):
			var fq := QuadMesh.new()
			fq.size = Vector2(0.55, 0.55)
			var fm := MeshInstance3D.new()
			fm.mesh = fq
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			fmat.albedo_color = Color.WHITE
			if flower_texs.size() > 0:
				fmat.albedo_texture = flower_texs[j % flower_texs.size()]
			fm.material_override = fmat
			fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(fm)
			gems.append(fm)

		# Neon speed streaks — 8 thin elongated boxes shooting out
		var streaks: Array[MeshInstance3D] = []
		for k in range(8):
			var streak := Shape.box(root, Vector3.ZERO, Vector3(1.1, 0.06, 0.06), Color.WHITE)
			streak.rotation.z = TAU * k / 8.0
			streaks.append(streak)

		# Spiral vortex — 3 concentric flat rings that spin
		var spiral_rings: Array[MeshInstance3D] = []
		for s in range(3):
			var sr_mesh := TorusMesh.new()
			var r: float = 0.30 + s * 0.18
			sr_mesh.inner_radius = r - 0.05; sr_mesh.outer_radius = r + 0.05
			sr_mesh.rings = 24; sr_mesh.ring_segments = 5
			var sr := Shape.piece(root, Vector3.ZERO, sr_mesh, Color.WHITE)
			sr.rotation.x = PI / 2
			spiral_rings.append(sr)

		# 4-pointed sparkle stars — two billboard quads per star (0°/45°) for an 8-spike effect
		var sparkles: Array[MeshInstance3D] = []
		for p in range(6):
			for _layer in range(2):
				var sq := QuadMesh.new()
				sq.size = Vector2(0.72, 0.72)
				var sm := MeshInstance3D.new()
				sm.mesh = sq
				var smat := StandardMaterial3D.new()
				smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				smat.cull_mode = BaseMaterial3D.CULL_DISABLED
				smat.albedo_texture = star_tex
				smat.albedo_color = Color.WHITE
				sm.material_override = smat
				sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(sm)
				sparkles.append(sm)

		# Apply shared material properties to all children so far
		for mesh in root.get_children():
			mesh.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Full-area flash — QuadMesh billboard added AFTER the shared loop
		var quad := QuadMesh.new()
		quad.size = Vector2(1.5, 1.5)
		var flash := MeshInstance3D.new()
		flash.mesh = quad
		var flash_mat := StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flash_mat.render_priority = -1
		flash_mat.albedo_color = Color.WHITE
		flash.material_override = flash_mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(flash)

		root.hide()
		bursts.append({
			"root": root, "aura_rings": aura_rings, "gems": gems,
			"streaks": streaks, "spiral_rings": spiral_rings,
			"sparkles": sparkles, "flash": flash,
			"age": 1.0, "reduced": false,
			"tier": 0, "duration": 0.75, "scale_max": 2.4,
			"gem_count": 2, "streak_count": 2, "spiral_count": 0,
			"show_sparkles": false, "flash_alpha": 0.0,
		})

func collect(at: Vector3, tier: int, reduced: bool, _high_detail: bool, neon: Color = Color.WHITE) -> void:
	var burst := bursts[next_burst]
	next_burst = (next_burst + 1) % bursts.size()
	burst.age = 0.0
	burst.reduced = reduced
	burst.tier = tier
	burst.root.position = at
	burst.root.show()

	var color: Color = neon

	# Per-tier profile — each tier has distinctly more elements and a longer burst
	match tier:
		3: # power3x — gold-orange, everything maxed
			burst.scale_max = 7.0;  burst.duration = 0.96
			burst.gem_count = 8;    burst.streak_count = 8
			burst.spiral_count = 3; burst.show_sparkles = true
			burst.flash_alpha = 0.82
		2: # rare — purple, 6 gems/streaks, 2 spirals, sparkles
			burst.scale_max = 5.5;  burst.duration = 0.83
			burst.gem_count = 6;    burst.streak_count = 6
			burst.spiral_count = 2; burst.show_sparkles = true
			burst.flash_alpha = 0.62
		1: # power — cyan, 4 gems/streaks, 1 spiral, sparkles
			burst.scale_max = 4.2;  burst.duration = 0.75
			burst.gem_count = 4;    burst.streak_count = 4
			burst.spiral_count = 1; burst.show_sparkles = true
			burst.flash_alpha = 0.48
		_: # coin — yellow, minimal: 2 gems/streaks, no spiral, no sparkles
			burst.scale_max = 3.5;  burst.duration = 0.65
			burst.gem_count = 2;    burst.streak_count = 2
			burst.spiral_count = 0; burst.show_sparkles = false
			burst.flash_alpha = 0.36

	# Aura ring — core bright, mid semi, halo faint; all share the tier color
	var aura_alphas := [1.0, 0.48, 0.18]
	for layer in burst.aura_rings.size():
		burst.aura_rings[layer].scale = Vector3.ONE
		burst.aura_rings[layer].material_override.albedo_color = Color(color.r, color.g, color.b, aura_alphas[layer])

	for i in burst.gems.size():
		burst.gems[i].visible = not reduced and i < burst.gem_count
		burst.gems[i].material_override.albedo_color = Color.WHITE  # keep flower colors natural
		burst.gems[i].position = Vector3.ZERO

	for k in burst.streaks.size():
		burst.streaks[k].visible = not reduced and k < burst.streak_count
		burst.streaks[k].position = Vector3.ZERO
		burst.streaks[k].scale = Vector3.ONE
		burst.streaks[k].material_override.albedo_color = color if k % 2 == 0 else Color(1.0, 1.0, 1.0, 0.9)

	for s in burst.spiral_rings.size():
		burst.spiral_rings[s].visible = not reduced and s < burst.spiral_count
		burst.spiral_rings[s].scale = Vector3.ONE
		var tint := color.lightened(0.15 * s)
		burst.spiral_rings[s].material_override.albedo_color = Color(tint.r, tint.g, tint.b, 0.85)

	for p in range(0, burst.sparkles.size(), 2):
		var sp_color: Color = Color.WHITE if p % 4 == 0 else color.lightened(0.3)
		burst.sparkles[p].visible = not reduced and burst.show_sparkles
		burst.sparkles[p + 1].visible = not reduced and burst.show_sparkles
		burst.sparkles[p].material_override.albedo_color = sp_color
		burst.sparkles[p + 1].material_override.albedo_color = sp_color
		burst.sparkles[p].position = Vector3.ZERO
		burst.sparkles[p + 1].position = Vector3.ZERO

	burst.flash.visible = not reduced
	burst.flash.scale = Vector3.ONE
	burst.flash.material_override.albedo_color = Color(color.r, color.g, color.b, burst.flash_alpha)

func advance(delta: float) -> void:
	for burst in bursts:
		if not burst.root.visible: continue
		burst.age += delta
		var t: float = burst.age / burst.duration
		if t >= 1:
			burst.root.hide()
			continue
		if burst.reduced: continue

		# Aura ring expands — each layer fades at a different rate to preserve the glow shape
		var ring_scale: Vector3 = Vector3.ONE * (1.0 + t * float(burst.scale_max))
		for layer in burst.aura_rings.size():
			burst.aura_rings[layer].scale = ring_scale
		var aura_fade_rates := [1.2, 1.8, 2.8]
		var aura_base_alphas := [1.0, 0.48, 0.18]
		for layer in burst.aura_rings.size():
			var a: float = maxf(0.0, aura_base_alphas[layer] - t * aura_fade_rates[layer])
			var c: Color = burst.aura_rings[layer].material_override.albedo_color
			burst.aura_rings[layer].material_override.albedo_color = Color(c.r, c.g, c.b, a)

		# Flowers arc outward — spread and fade by tier
		var gem_spread: float = 1.2 + burst.tier * 0.2
		var flower_a: float = maxf(0.0, 1.0 - t * 1.4)
		for i in burst.gem_count:
			var angle: float = TAU * i / burst.gem_count
			burst.gems[i].position = Vector3(cos(angle) * t * gem_spread, sin(angle) * t * gem_spread * 0.75 + t * 0.6, 0)
			burst.gems[i].rotation.z += delta * (3.5 + burst.tier * 0.8)
			burst.gems[i].material_override.albedo_color.a = flower_a

		# Speed streaks shoot out — elongation grows with tier
		var streak_elongation: float = 3.5 + burst.tier * 1.5
		for k in burst.streak_count:
			var angle: float = TAU * k / burst.streak_count
			var dist: float = t * 2.8
			burst.streaks[k].position = Vector3(cos(angle) * dist, sin(angle) * dist * 0.55, 0)
			burst.streaks[k].scale = Vector3(1.0 + t * streak_elongation, 1.0, 1.0)
			var streak_a: float = maxf(0.0, 1.0 - t * 2.4)
			var sc: Color = burst.streaks[k].material_override.albedo_color
			burst.streaks[k].material_override.albedo_color = Color(sc.r, sc.g, sc.b, streak_a)

		# Spiral vortex — spin speed and ring count increase with tier
		var spin_scale: float = 1.0 + burst.tier * 0.8
		for s in burst.spiral_count:
			var spin_dir: float = 1.0 if s % 2 == 0 else -1.0
			burst.spiral_rings[s].rotation.y += delta * (5.0 + s * 3.5) * spin_dir * spin_scale
			burst.spiral_rings[s].scale = Vector3.ONE * (1.0 + t * (3.0 + s * 2.0))
			var spiral_a: float = maxf(0.0, 0.85 - t * 1.4)
			var spc: Color = burst.spiral_rings[s].material_override.albedo_color
			burst.spiral_rings[s].material_override.albedo_color = Color(spc.r, spc.g, spc.b, spiral_a)

		# Sparkle stars — only tier 1+ (power and above)
		if burst.show_sparkles:
			for p in range(0, burst.sparkles.size(), 2):
				var star_idx: int = p >> 1
				var angle: float = TAU * star_idx / (burst.sparkles.size() / 2) + t * 1.5
				var dist: float = t * 2.2
				var pos := Vector3(cos(angle) * dist, 0.4 + t * 2.0, sin(angle) * dist * 0.3)
				burst.sparkles[p].position = pos
				burst.sparkles[p + 1].position = pos
				var tumble: float = t * 8.0 + star_idx
				burst.sparkles[p].rotation.z = tumble
				burst.sparkles[p + 1].rotation.z = tumble + PI / 4
				var star_a: float = maxf(0.0, 0.95 - t * 1.2)
				burst.sparkles[p].material_override.albedo_color.a = star_a
				burst.sparkles[p + 1].material_override.albedo_color.a = star_a * 0.55

		# Flash — bigger and lasts longer for higher tiers
		var flash_a: float = maxf(0.0, burst.flash_alpha - t * (2.5 + burst.tier * 0.5))
		burst.flash.scale = Vector3.ONE * (1.0 + t * (1.5 + burst.tier * 0.8))
		var fc: Color = burst.flash.material_override.albedo_color
		burst.flash.material_override.albedo_color = Color(fc.r, fc.g, fc.b, flash_a)

func reset() -> void:
	for burst in bursts: burst.root.hide()
	next_burst = 0
