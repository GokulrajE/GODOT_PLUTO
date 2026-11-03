extends "res://game/BULLOCK_CART/scripts/cart_actor.gd"
## Original generated frames, advanced only by the race simulation clock.
const SHEETS = {
	&"player": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-player.png"),
	&"amber": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-amber.png"),
	&"indigo": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-indigo.png"),
}
const METADATA = {
	&"player": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-player.json"),
	&"amber": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-amber.json"),
	&"indigo": preload("res://game/BULLOCK_CART/assets/generated/cart-centered-indigo.json"),
}
var appearance: StringName = &"player"
const STRIDE_METERS := 4.8
var sprite: AnimatedSprite3D
var frame_offsets: Array[Vector2] = []
var run_clock := 0.0
var flick_clock := -1.0
var forward_speed := 0.0
var was_boosting := false
var lean := 0.0
var stride_distance := 0.0
var pending_flick := false
var urge_cycle := -1
var continuous_urge := false

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	sprite = AnimatedSprite3D.new()
	sprite.name = "GeneratedCartAnimation"
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation("default")
	for clip in ["run", "urge"]:
		sprite.sprite_frames.add_animation(clip)
		sprite.sprite_frames.set_animation_speed(clip, 12.0)
		sprite.sprite_frames.set_animation_loop(clip, clip == "run")
	var sheet: Texture2D = SHEETS.get(appearance, SHEETS[&"player"])
	var metadata: JSON = METADATA.get(appearance, METADATA[&"player"])
	for i in metadata.data.frames.size():
		var data: Dictionary = metadata.data.frames[i]
		var region: Array = data.region
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(region[0], region[1], region[2], region[3])
		texture.filter_clip = true
		sprite.sprite_frames.add_frame("run" if i < 8 else "urge", texture)
		frame_offsets.append(Vector2(data.offset[0], data.offset[1]))
	sprite.pixel_size = 2.55 / 280.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(sprite)
	# Ground contact remains separate from the transparent animation sheet.
	var shadow := PlaneMesh.new()
	shadow.size = Vector2(3.0, 3.0)
	var contact := piece(self, Vector3(0, .045, 0), shadow, Color.WHITE)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment(){ float edge=length((UV-vec2(0.5))*vec2(1.0,1.35)); ALBEDO=vec3(0.12,0.08,0.04); ALPHA=(1.0-smoothstep(0.06,0.5,edge))*0.28; }"
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = shader
	contact.material_override = shadow_material
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aura := TorusMesh.new()
	aura.inner_radius = 1.05
	aura.outer_radius = 1.10
	aura.rings = 32
	aura.ring_segments = 6
	boost_aura = piece(self, Vector3(0, .06, 0), aura, Color("65f7eb"))
	boost_aura.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boost_aura.hide()
	_build_dust()
	dust.position.z = .4
	reset_motion()

func reset_motion() -> void:
	run_clock = 0
	flick_clock = -1
	forward_speed = 0
	was_boosting = false
	stride_distance = 0
	pending_flick = false
	urge_cycle = -1
	continuous_urge = false
	lean = 0
	body.rotation = Vector3.ZERO
	_select_frame("run", 0)

func _select_frame(clip: String, index: int) -> void:
	sprite.animation = clip
	sprite.frame = index
	sprite.offset = frame_offsets[index + (8 if clip == "urge" else 0)]

func animate(delta: float, steering: float, reduced: bool) -> void:
	advance_motion(delta, maxf(0, forward_speed) * delta, steering, reduced)

func advance_motion(delta: float, distance: float, steering: float, reduced: bool) -> void:
	# Use actual progress after collision resolution, including a fully blocked cart.
	var old_cycle := int(floor(stride_distance / STRIDE_METERS))
	stride_distance += maxf(0, distance)
	run_clock = stride_distance / 8.0
	var cycle := int(floor(stride_distance / STRIDE_METERS))
	var stride_phase := fposmod(stride_distance / STRIDE_METERS, 1.0)
	var urge_just_ended := false
	if urge_cycle >= 0 and cycle > urge_cycle:
		if continuous_urge: pending_flick = true
		urge_cycle = -1
		urge_just_ended = true
	# Enter the hand gesture at a shared leg pose, then keep one continuous gait clock.
	# Skip immediate re-trigger when the urge ended this same tick (fire on the next stride instead).
	if pending_flick and cycle > old_cycle and not urge_just_ended:
		urge_cycle = cycle
		pending_flick = false
	flick_clock = stride_phase * STRIDE_METERS / 8.0 if urge_cycle == cycle else -1.0
	_select_frame("urge" if urge_cycle == cycle else "run", mini(7, int(stride_phase * 8)))
	lean = lerpf(lean, steering * .018, 1.0 - exp(-delta * 8))
	body.rotation.z = 0 if reduced else -lean
	dust.emitting = dust.visible and not reduced and delta > 0 and distance / maxf(delta, .00001) > 2

func show_boost(enabled: bool) -> void:
	if enabled and not was_boosting: pending_flick = true
	if not enabled and was_boosting: pending_flick = false
	was_boosting = enabled
	continuous_urge = enabled
	boost_aura.visible = enabled

func set_character_detail(high: bool) -> void:
	if dust:
		dust.visible = high
		if not high: dust.emitting = false
