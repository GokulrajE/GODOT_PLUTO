extends Node3D
## Bullock Cart game — PLUTO device steers when connected; keyboard/mouse fallback when not.
const Cart = preload("res://game/BULLOCK_CART/scripts/cart_actor.gd")
const Track = preload("res://game/BULLOCK_CART/scripts/track.gd")
const ChaseCamera = preload("res://game/BULLOCK_CART/scripts/chase_camera.gd")
const Race = preload("res://game/BULLOCK_CART/scripts/lane_race.gd")
const COLLECTION_FRONT := 3.05
const Palette = preload("res://scripts/ui/ui_palette.gd")
const LANTERN_SEQUENCE := ["power", "power", "rare", "power", "power3x"]
var lantern_variant := 0

const AAN = preload("res://scripts/PlutoAAN.gd")
var aan = AAN.new()
var therapy_active := false
var device_session := false
var aan_enabled := false
var therapy_target := -1.0
var encountered: Dictionary = {}
var therapy_aprom: Array = [-45.0, 45.0]
var race := Race.new()
@export var motion_preview := false
var rivals: Array[Node3D] = []
var boost_label: Label
var detail_button: Button
var sun: DirectionalLight3D
var finish_gate: Node3D
var high_detail := true
var cart: Node3D
var track: Node3D
var targets: Array[Node3D] = []
var elapsed := 0.0
var hits := 0
var running := false
var paused := false
var hud: Label
var feedback: Label
var feedback_time := 0.0
var modal: PanelContainer
var modal_title: Label
var modal_body: Label
var play_button: Button
var pause_button: Button
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var music_button: Button
var reduced := false
var camera: Camera3D
var collection_fx: Node3D
var race_audio: Node
var race_hint: Label
var audio_panel: PanelContainer
var feedback_pulse := 0.0
var previous_place := 1
var race_dashboard: Control
var countdown_remaining := 0.0
var difficulty_select: OptionButton
var difficulty_help: Label
var result_board: VBoxContainer
var finish_announced := false
var retry_button: Button
var course_records := ConfigFile.new()
var completed_difficulty := 2
var duration_select: OptionButton
var section_banner: Label
var section_banner_time := 0.0
var last_section_name := ""
var score_pops: Array[Dictionary] = []
var rival_score_labels: Array[Label3D] = []
var rival_score_previous: Array[int] = [0, 0]
var mouse_x_accum := 0.0
var device_prev_button := 0
var top_bar: HBoxContainer
var mini_hud: Control
var mini_time_label: Label
var mini_score_label: Label
var mini_pos_label: Label
var mini_pause_btn: Button

# Shared HUD-card interface — game_hud_card.gd reads these two properties.
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _time_left: float:
	get: return _mp_time_left if motion_preview else maxf(0.0, race.TIME_LIMIT - race.elapsed)
var n_success: int:
	get: return _mp_n_success if motion_preview else hits

# ---- motion_preview therapeutic mode ----
enum MPState { WAITING, START, SPAWN_TARGET, MOVE, SUCCESS, FAILURE, STOP, DONE }
var _mp_state: MPState = MPState.WAITING
var _mp_prev_state: MPState = MPState.WAITING
var _mp_target_lane: int = 2
var _mp_move_elapsed: float = 0.0
var _mp_event_delay: float = 0.0
var _mp_game_finished: bool = false
var _mp_n_targets: int = 0
var _mp_n_success: int = 0
var _mp_n_failure: int = 0
var _mp_time_left: float = 60.0
const MP_TRIAL_DURATION := 60.0
var _mp_yesterday_hits: int = 0
var _mp_earned_star := false
var _mp_celeb_card: Control
const MP_MIN_SPEED := 10.0
const MP_MAX_SPEED := 40.0
var _mp_game_speed: float = 10.0
var _mp_move_duration: float = 2.0
var _mp_mech_min_duration: float = 0.5
var _mp_mech_max_duration: float = 4.0
var _mp_aprom: Array = [-45.0, 45.0]
var _mp_arom: Array = [-30.0, 30.0]
var _mp_prom: Array = [-45.0, 45.0]
var _mp_aan = null
var _mp_use_aan: bool = false
var _mp_wait_panel: Control
var _mp_pause_panel: Control
var _mp_over_panel: Control
var _mp_speed_panel: Control
var _mp_speed_lbl: Label
var _mp_speed_info_lbl: Label
var _mp_header_timer: Label
var _mp_header_score: Label
var _mp_dec_btn: Button
var _mp_inc_btn: Button
var _mp_lane_indicator: Node3D
var _mp_indicator_elapsed: float = 0.0
var _mp_spawn_distance: float = 0.0
var _preloaded_cart_sheets: Dictionary = {}
var _preloaded_cart_meta: Dictionary = {}
var _preloaded_flowers: Array[Texture2D] = []
var _preloaded_multi_tex: Texture2D
var _preloaded_rare_tex: Texture2D
var _preloaded_p3x_tex: Texture2D

func _retry_course() -> void:
	race.layout_seed = race.actual_seed
	difficulty_select.select(completed_difficulty)
	start_ride()

func _course_record_key() -> String:
	return "v2_%d_%d" % [race.difficulty, race.actual_seed]

func _ready() -> void:
	_preload_assets()
	AppData.set_game("BULLOCK-CART")
	EventBus.button_released.connect(_device_button)
	course_records.load("user://bullock-course-records.cfg")
	get_window().content_scale_size = Vector2i(1280, 800)
	race.timed_mode = true
	race.game_duration = 180.0
	race.reset()
	high_detail = not (OS.get_name() == "Linux" and OS.has_feature("arm64"))
	reduced = bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	if motion_preview:
		sky_material.sky_top_color = Color("0e1a38")
		sky_material.sky_horizon_color = Color("c45520")
		sky_material.ground_horizon_color = Color("6b2e10")
		sky_material.ground_bottom_color = Color("100808")
	else:
		sky_material.sky_top_color = Color("7ec4e8")
		sky_material.sky_horizon_color = Color("f2e8d5")
		sky_material.ground_horizon_color = Color("e0d8c0")
		sky_material.ground_bottom_color = Color("a0a07a")
	sky.sky_material = sky_material
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ffb89aff") if motion_preview else Color("fff8e8")
	environment.environment.ambient_light_energy = 0.18 if motion_preview else 0.75
	environment.environment.ambient_light_sky_contribution = 0.0
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = Color("fba88aff") if motion_preview else Color("d8e4d0")
	environment.environment.fog_density = 0.000 if motion_preview else 0.0012
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -60, 0) if motion_preview else Vector3(-45, -30, 0)
	sun.light_color = Color("da8f1fff") if motion_preview else Color("fffef5")
	sun.light_energy = 0.30 if motion_preview else 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	sun.shadow_bias = 0.03
	add_child(sun)
	camera = ChaseCamera.new()
	camera.fixed_rear = motion_preview
	if motion_preview: camera.rear_offset = Vector3(0, 4.6, 12.5)
	add_child(camera)
	camera.reset(Vector3.ZERO)
	camera.fov = 58
	camera.current = true
	track = Track.new()
	if motion_preview: track.road_width = race.ROAD_WIDTH
	add_child(track)
	collection_fx = preload("res://game/BULLOCK_CART/scripts/collection_fx.gd").new()
	add_child(collection_fx)
	var actor_script = preload("res://game/BULLOCK_CART/scripts/png_cart_actor.gd") if motion_preview else Cart
	cart = actor_script.new()
	add_child(cart)
	if motion_preview:
		var player_tag := Label3D.new()
		player_tag.text = "YOU"
		player_tag.position.y = 2.5
		player_tag.font_size = 56
		player_tag.pixel_size = .0045
		player_tag.modulate = Color("ffe38a")
		player_tag.outline_size = 8
		player_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cart.add_child(player_tag)
	for i in range(2):
		var rival: Node3D = actor_script.new()
		if motion_preview: rival.appearance = &"amber" if i == 0 else &"indigo"
		if not motion_preview: rival.bull_variant = "brown" if i == 0 else "black"
		rival.checked_driver = i == 0
		rival.paint = Color("aa5728") if i == 0 else Color("55549b")
		add_child(rival)
		rivals.append(rival)
		var name_tag := Label3D.new()
		name_tag.text = "RAMASAMI" if i == 0 else "MUNUSAMI"
		name_tag.position.y = 2.9
		if motion_preview: name_tag.position.y = 2.5
		name_tag.font_size = 40
		name_tag.pixel_size = 0.003
		if motion_preview: name_tag.pixel_size = .005
		name_tag.outline_size = 5
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rival.add_child(name_tag)
		var score_tag := Label3D.new()
		score_tag.font_size = 34
		score_tag.pixel_size = 0.005
		score_tag.position.y = 1.8 if motion_preview else 2.2
		score_tag.modulate = Color("cceeee")
		score_tag.outline_size = 5
		score_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		score_tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		score_tag.hide()
		rival.add_child(score_tag)
		rival_score_labels.append(score_tag)
	for _pi in range(6):
		var pop := Label3D.new()
		pop.font_size = 130
		pop.pixel_size = 0.0038
		pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pop.outline_size = 10
		pop.modulate.a = 0.0
		add_child(pop)
		score_pops.append({"label": pop, "age": 1.0, "color": Color.WHITE})
	_build_targets()
	finish_gate = Node3D.new()
	add_child(finish_gate)
	if race.timed_mode: finish_gate.hide()
	var gate_half: float = track.road_width * .5
	for x in [-gate_half, gate_half]: Cart.box(finish_gate, Vector3(x, 2.3, 0), Vector3(0.18, 4.6, 0.18), Color("5a3d25"))
	Cart.box(finish_gate, Vector3(0, 4.4, 0), Vector3(track.road_width + .2, 0.9, 0.12), Color("eee7cb"))
	var finish_sign := Label3D.new()
	finish_sign.text = "FINISH"
	finish_sign.position = Vector3(0, 4.4, 0.12)
	finish_sign.font_size = 100
	finish_sign.pixel_size = 0.006
	finish_sign.modulate = Color("214e40")
	finish_gate.add_child(finish_sign)
	race_audio = preload("res://game/BULLOCK_CART/scripts/race_audio.gd").new()
	add_child(race_audio)
	music = race_audio.music
	sound = race_audio.effect
	_build_ui()
	preload("res://scripts/ui/game_chrome.gd").bullock.call_deferred(self)
	_apply_detail()
	_reset_targets()
	if not motion_preview:
		var kb_hint := ("Move the device to steer  •  Device button: pause/resume" if PlutoComm.is_connected else "← → / A D  •  Space: boost")
		_show_modal("BULLOCK TRAIL", "Steer left and right to collect lanterns and score points!\nBlue lantern = boost  •  Clay pot = super boost  •  Gold = ultra boost\n" + kb_hint + "  •  Esc: pause", "Start race")
	else:
		_mp_init_rom_data()
		_mp_calc_speed()
		_mp_yesterday_hits = DataManager.read_yesterday_hits(AppData.selected_game_name, AppData.mechanism_name)
		# Target itself is the steering cue; no lane highlight.
		modal.hide()
		top_bar.hide()
		mini_hud.hide()
		_mp_wait_panel.show()
		_mp_state = MPState.WAITING
		_mp_prev_state = MPState.WAITING
	# Start streaming if device is connected but idle (e.g. game launched standalone)
	if PlutoComm.is_connected and not PlutoComm.is_streaming:
		PlutoComm.start_stream()

func _neon_mat(color: Color, alpha: float, priority: int = 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = priority
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m

func _build_targets() -> void:
	for t in targets: t.queue_free()
	targets.clear()
	var multi_tex: Texture2D = _preloaded_multi_tex if _preloaded_multi_tex else load("res://game/BULLOCK_CART/assets/generated/multiple powers.png")
	var rare_tex: Texture2D = _preloaded_rare_tex if _preloaded_rare_tex else load("res://game/BULLOCK_CART/assets/generated/rarePower.png")
	var p3x_tex: Texture2D = _preloaded_p3x_tex if _preloaded_p3x_tex else load("res://game/BULLOCK_CART/assets/generated/power3X.png")
	var tw := multi_tex.get_width() * 0.5 if multi_tex else 128.0
	var th := multi_tex.get_height() * 0.5 if multi_tex else 128.0
	# Ring glow texture: transparent center, glowing rim, transparent outer
	var glow_img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for gy in 128:
		for gx in 128:
			var d := Vector2(gx - 63.5, gy - 63.5).length() / 63.5
			var ring_a := maxf(0.0, 1.0 - absf(d - 0.62) * 6.0)
			ring_a = ring_a * ring_a * 0.96
			var fill_a := maxf(0.0, 0.4 - d * 1.2) * 0.12
			glow_img.set_pixel(gx, gy, Color(1, 1, 1, minf(1.0, ring_a + fill_a)))
	var glow_tex := ImageTexture.create_from_image(glow_img)
	for target_idx in race.pickups.size():
		var target := Node3D.new()
		add_child(target)
		if motion_preview:
			# Aura glow quad sits behind the sprite (sprites write depth in opaque pass)
			var aura := MeshInstance3D.new(); aura.name = "aura"
			var qm := QuadMesh.new(); qm.size = Vector2(4.2, 4.2)
			aura.mesh = qm
			var aura_mat := StandardMaterial3D.new()
			aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			aura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			aura_mat.albedo_texture = glow_tex
			aura_mat.albedo_color = Color("67f5ed")
			aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			aura.material_override = aura_mat
			aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			aura.position.y = 1.05
			target.add_child(aura)
			# Spinning ground ring that encircles the pickup base
			var gr_mesh := TorusMesh.new()
			gr_mesh.inner_radius = 0.55; gr_mesh.outer_radius = 0.68
			gr_mesh.rings = 32; gr_mesh.ring_segments = 6
			var ground_ring := MeshInstance3D.new(); ground_ring.name = "ground_ring"
			ground_ring.mesh = gr_mesh
			ground_ring.position.y = 0.08
			var gr_mat := StandardMaterial3D.new()
			gr_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gr_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gr_mat.albedo_color = Color("67f5ed88")
			ground_ring.material_override = gr_mat
			ground_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			target.add_child(ground_ring)
			# Sprites in front of the aura
			var lantern := Sprite3D.new(); lantern.name = "v_power"
			if multi_tex:
				var atlas := AtlasTexture.new()
				atlas.atlas = multi_tex
				atlas.region = Rect2((target_idx % 2) * tw, ((target_idx >> 1) % 2) * th, tw, th)
				lantern.texture = atlas
				lantern.pixel_size = 1.65 / th
			else:
				lantern.texture = preload("res://game/BULLOCK_CART/assets/generated/festival-boost-lantern.png")
				lantern.pixel_size = 1.65 / lantern.texture.get_height()
			lantern.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lantern.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			lantern.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lantern.position.y = 1.05
			target.add_child(lantern)
			var rv2 := Sprite3D.new(); rv2.name = "v_rare"
			if rare_tex: rv2.texture = rare_tex; rv2.pixel_size = 1.9 / rare_tex.get_height()
			rv2.billboard = BaseMaterial3D.BILLBOARD_ENABLED; rv2.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			rv2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			rv2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rv2.position.y = 1.05
			target.add_child(rv2)
			var xv2 := Sprite3D.new(); xv2.name = "v_power3x"
			if p3x_tex: xv2.texture = p3x_tex; xv2.pixel_size = 2.1 / p3x_tex.get_height()
			xv2.billboard = BaseMaterial3D.BILLBOARD_ENABLED; xv2.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			xv2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			xv2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			xv2.position.y = 1.05
			target.add_child(xv2)
		else:
			var pv := Node3D.new(); pv.name = "v_power"; target.add_child(pv)
			var r1 := TorusMesh.new(); r1.inner_radius = 0.26; r1.outer_radius = 0.43; r1.rings = 16; r1.ring_segments = 6
			Cart.piece(pv, Vector3.ZERO, r1, Color("31e2e5")).rotation.x = PI / 2
			var bolt := Cart.box(pv, Vector3.ZERO, Vector3(0.13, 0.55, 0.12), Color("eeffff")); bolt.rotation.z = -0.5
			var cv := Node3D.new(); cv.name = "v_coin"; target.add_child(cv)
			var r2 := TorusMesh.new(); r2.inner_radius = 0.26; r2.outer_radius = 0.43; r2.rings = 16; r2.ring_segments = 6
			Cart.piece(cv, Vector3.ZERO, r2, Color("ffc523")).rotation.x = PI / 2
			Cart.ball(cv, Vector3.ZERO, Vector3(0.35, 0.35, 0.12), Color("fff29c"))
			var rv := Sprite3D.new(); rv.name = "v_rare"
			if rare_tex: rv.texture = rare_tex; rv.pixel_size = 1.9 / rare_tex.get_height()
			rv.billboard = BaseMaterial3D.BILLBOARD_ENABLED; rv.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			rv.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			rv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			target.add_child(rv)
			var xv := Sprite3D.new(); xv.name = "v_power3x"
			if p3x_tex: xv.texture = p3x_tex; xv.pixel_size = 2.1 / p3x_tex.get_height()
			xv.billboard = BaseMaterial3D.BILLBOARD_ENABLED; xv.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			xv.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			xv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			target.add_child(xv)
		targets.append(target)
func _reset_targets() -> void:
	if targets.size() != race.pickups.size(): _build_targets()
	for i in targets.size():
		if i >= race.pickups.size():
			targets[i].hide()
			continue
		targets[i].position = Vector3(race.pickups[i].x, 1.15, race.racers[0].distance - race.pickups[i].distance - COLLECTION_FRONT)
		targets[i].visible = true
		targets[i].scale = Vector3.ONE
		var kind: String = race.pickups[i].kind
		targets[i].get_node("v_power").visible = kind == "power"
		targets[i].get_node("v_rare").visible = kind == "rare"
		targets[i].get_node("v_power3x").visible = kind == "power3x"
		if not motion_preview:
			targets[i].get_node("v_coin").visible = kind == "coin"
		# Per-kind neon color: 3x=gold, rare=red, power cycles blue/green/red/purple
		var neon: Color
		match kind:
			"power3x": neon = Color("ccaaff")
			"rare":    neon = Color("ff6644")
			_:
				match i % 4:
					1: neon = Color("44ee88")
					2: neon = Color("ff6644")
					3: neon = Color("cc88ff")
					_: neon = Color("67f5ed")
		if motion_preview:
			var aura := targets[i].get_node_or_null("aura") as MeshInstance3D
			if aura: (aura.material_override as StandardMaterial3D).albedo_color = neon
			var ground_ring := targets[i].get_node_or_null("ground_ring") as MeshInstance3D
			if ground_ring: (ground_ring.material_override as StandardMaterial3D).albedo_color = Color(neon.r, neon.g, neon.b, 0.55)
	for i in rivals.size():
		rivals[i].position = Vector3(race.racers[i + 1].x, 0, race.racers[0].distance - race.racers[i + 1].distance)
		rivals[i].show_boost(false)
		rivals[i].visible = not motion_preview or race.difficulty != 0
	cart.show_boost(false)
	finish_gate.position.z = -Race.LENGTH - COLLECTION_FRONT

func start_ride(with_countdown := true) -> void:
	_finish_therapy()
	collection_fx.reset()
	race_audio.start_race()
	audio_panel.hide()
	previous_place = 3 if motion_preview else 1
	feedback_pulse = 0
	feedback.scale = Vector2.ONE
	cart.freeze_effects(false)
	for rival in rivals: rival.freeze_effects(false)
	if motion_preview: race.difficulty = difficulty_select.selected
	if duration_select:
		race.game_duration = ([60.0, 180.0, 300.0])[duration_select.selected]
	race.reset()
	if retry_button: retry_button.hide()
	finish_announced = false
	previous_place = race.player_place()
	if motion_preview:
		cart.reset_motion()
		for rival in rivals: rival.reset_motion()
	rival_score_previous = [0, 0]
	last_section_name = ""
	elapsed = 0
	hits = 0
	cart.position.x = 0
	cart.rotation.y = 0.0
	for rival in rivals: rival.rotation.y = 0.0
	camera.reset(Vector3.ZERO)
	_reset_targets()
	AppData.start_new_trial()
	therapy_active = true
	device_session = not AppData.demo_mode and PlutoComm.is_connected
	encountered.clear()
	therapy_target = -1.0
	aan.reset_trial()
	var mech = AppData.selected_mechanism
	aan_enabled = device_session and mech != null and AppData.mechanism_name not in ["FME1", "FME2", "NOMECH"]
	if mech != null:
		therapy_aprom = mech.current_aprom.duplicate()
		aan.arom = mech.current_arom.duplicate()
		aan.prom = mech.current_prom.duplicate()
	aan_enabled = aan_enabled and aan.arom.size() >= 2 and aan.prom.size() >= 2 and therapy_aprom.size() >= 2
	running = true
	paused = false
	_log_therapy("COUNTDOWN")
	play_button.release_focus()
	modal.hide()
	pause_button.disabled = false
	if mini_pause_btn: mini_pause_btn.disabled = false
	top_bar.hide()
	mini_hud.show()
	countdown_remaining = 3.0 if motion_preview and with_countdown else 0.0
	feedback.text = "3" if countdown_remaining > 0 else ("Tap ← → to change lanes • Blue boosts activate automatically" if motion_preview else "Collect cyan power • Space to boost")
	feedback_time = 3.0
	_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and running and not paused:
		mouse_x_accum += event.relative.x

func _process(delta: float) -> void:
	var _fs := get_node_or_null("GameUI/Interface/FloatScore")
	if _fs:
		var _hits: int = n_success
		var _stars := 0
		for _t in [5, 15, 30]: if _hits >= _t: _stars += 1
		var _cc := _fs.get_node_or_null("CollectCount") as Label
		if _cc: _cc.text = str(_hits)
		var _sc := _fs.get_node_or_null("StarCount") as Label
		if _sc: _sc.text = str(_stars)
	if motion_preview:
		_process_mp(delta)
		return
	if not running or paused:
		mouse_x_accum = 0.0
		device_prev_button = PlutoComm.button if PlutoComm.is_connected else 0
		if not paused: race_audio.advance(delta)
		return
	var left  := Input.is_physical_key_pressed(KEY_LEFT)  or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
	var key_dir := float(right) - float(left)
	var mouse_dir := clampf(mouse_x_accum / 200.0, -1.0, 1.0)
	mouse_x_accum = 0.0
	var direction: float
	var device_target_x := INF
	var device_target_lane := -1
	if PlutoComm.is_connected and PlutoComm.is_streaming:
		# Same mapping as Hat Trick: use aprom range from selected mechanism
		var aprom: Array = [-45.0, 45.0]
		if AppData.selected_mechanism != null and AppData.selected_mechanism.current_aprom.size() >= 2:
			aprom = AppData.selected_mechanism.current_aprom
		else:
			aprom = [AppData.mech_offset - AppData.calib_angle * 0.5,
					 AppData.mech_offset + AppData.calib_angle * 0.5]
		var t := clampf((PlutoComm.angle - aprom[0]) / maxf(aprom[1] - aprom[0], 1.0), 0.0, 1.0)
		direction = t * 2.0 - 1.0  # 0..1 → -1..1 for camera/animation lean
		var x_min := race.lane_x(race.lane_min)
		var x_max := race.lane_x(race.lane_max)
		device_target_x    = lerpf(x_min, x_max, t)
		device_target_lane = race.lane_min + roundi(t * float(race.lane_max - race.lane_min))

	else:
		direction = mouse_dir if absf(mouse_dir) > absf(key_dir) else key_dir
	# Instant 1:1 mapping: bypass lane interpolation and set X directly from device angle.
	if device_target_x != INF and race.racers[0].finish < 0 and not race.complete:
		race.racers[0].x            = device_target_x
		race.racers[0].lane         = device_target_lane
		race.racers[0].lateral_speed = 0.0
	step(delta, 0.0 if device_target_x != INF else direction)

func step(delta: float, direction: float) -> void:
	if not running or paused: return
	if device_session and (not PlutoComm.is_connected or not PlutoComm.is_streaming):
		_pause("Device disconnected. Reconnect before continuing.")
		return
	# Bound simulation steps after stalls; never jump over the collection plane.
	var dt := clampf(delta, 0, .25 if motion_preview else .1)
	if countdown_remaining > 0:
		countdown_remaining = maxf(0, countdown_remaining - dt)
		feedback.text = str(ceili(countdown_remaining)) if countdown_remaining > 0 else "GO!  Collect the lanterns!"
		feedback_time = 2.0
		return
	if not motion_preview:
		AppData.record_active_time(minf(dt, maxf(0.0, race.game_duration - race.elapsed)))
		_update_assistance(dt)
	collection_fx.advance(dt)
	race_audio.advance(dt)
	feedback_pulse = maxf(0, feedback_pulse - dt)
	feedback.pivot_offset = feedback.size * .5
	feedback.scale = Vector2.ONE * (1.0 if reduced else 1.0 + sin(feedback_pulse / .4 * PI) * .10)
	var old_distance: float = race.racers[0].distance
	var old_rival_distances: Array[float] = []
	if motion_preview:
		for i in rivals.size(): old_rival_distances.append(race.racers[i + 1].distance)
	var passed: Array[float] = []
	for pickup in race.pickups:
		if pickup.distance >= old_distance: passed.append(pickup.distance)
	race.advance(dt, direction)
	if motion_preview and _mp_state == MPState.MOVE and not race.pickups.is_empty():
		var remaining := maxf(0.0, 1.0 - (_mp_move_elapsed + dt) / _mp_move_duration)
		race.pickups[0].distance = race.racers[0].distance + maxf(24.0, race.BASE_SPEED * _mp_move_duration) * remaining
	for distance in passed:
		if distance <= race.racers[0].distance: encountered[distance] = true
	if not motion_preview: _log_therapy("MOVE")
	elapsed = race.elapsed
	cart.position.x = race.racers[0].x
	cart.rotation.y = lerpf(cart.rotation.y, -race.racers[0].lateral_speed * 0.085, 1.0 - exp(-dt * 6.0))
	if motion_preview:
		cart.forward_speed = race.racers[0].speed
		cart.show_boost(race.racers[0].boost > 0)
		var phys_dist: float = race.racers[0].distance - old_distance
		var anim_dist: float = phys_dist * (1.4 if race.racers[0].boost > 0 else 1.0)
		cart.advance_motion(dt, anim_dist, race.racers[0].lateral_speed / 3.8, reduced)
	else: cart.animate(dt * (1.6 if race.racers[0].boost > 0 else 1.0), direction, reduced)
	cart.show_boost(race.racers[0].boost > 0)
	camera.boost_strength = 1.0 if race.racers[0].boost > 0 else 0.0
	camera.follow(cart.position, direction, dt, reduced)
	track.advance(race.racers[0].distance - old_distance, dt, reduced)
	for i in rivals.size():
		var rival_data: Dictionary = race.racers[i + 1]
		rivals[i].position = Vector3(rival_data.x, 0, race.racers[0].distance - rival_data.distance)
		rivals[i].rotation.y = lerpf(rivals[i].rotation.y, -rival_data.lateral_speed * 0.085, 1.0 - exp(-dt * 6.0))
		rivals[i].visible = absf(rivals[i].position.z) < 90 and (not motion_preview or race.difficulty != 0)
		rivals[i].show_boost(rival_data.speed > race.BASE_SPEED + 1.2)
		if rival_data.finish < 0:
			if motion_preview:
				rivals[i].forward_speed = rival_data.speed
				rivals[i].advance_motion(dt, rival_data.distance - old_rival_distances[i], rival_data.lateral_speed / 3.8, reduced)
			else: rivals[i].animate(dt * (1.6 if rival_data.boost > 0 else 1.0), 0, reduced)
	var time_left_s := race.game_duration - race.elapsed
	var final_urgency := race.timed_mode and time_left_s < 10.0
	for i in mini(targets.size(), race.pickups.size()):
		var target := targets[i]
		var pickup: Dictionary = race.pickups[i]
		target.position = Vector3(pickup.x, 1.15, race.racers[0].distance - pickup.distance - COLLECTION_FRONT)
		target.visible = pickup.owner < 0 and target.position.z < 10 and target.position.z > -180
		if not reduced and target.visible:
			var kind: String = pickup.kind
			var urgency_mult := 2.0 if final_urgency else 1.0
			var bob_speed := (4.5 if kind == "power3x" else (3.5 if kind == "rare" else 2.5)) * urgency_mult
			target.position.y += sin(elapsed * bob_speed + i) * (0.22 if kind != "power" else 0.13)
			if not motion_preview:
				target.rotation.y += dt * (2.8 if kind == "power3x" else (2.2 if kind == "rare" else 1.5))
			if motion_preview:
				var aura := target.get_node_or_null("aura") as MeshInstance3D
				if aura:
					var amat := aura.material_override as StandardMaterial3D
					if amat:
						var ps := (5.0 if kind == "power3x" else (3.5 if kind == "rare" else 2.0)) * urgency_mult
						var base_a := 0.82 if kind == "power3x" else (0.75 if kind == "rare" else 0.68)
						var amp := 0.18 if kind != "power" else 0.14
						var col := amat.albedo_color
						col.a = base_a + sin(elapsed * ps + i * 0.8) * amp
						amat.albedo_color = col
				var ground_ring := target.get_node_or_null("ground_ring") as MeshInstance3D
				if ground_ring:
					var spin := (4.5 if kind == "power3x" else (3.2 if kind == "rare" else 2.2)) * urgency_mult
					ground_ring.rotation.y += dt * spin
					var gr_mat := ground_ring.material_override as StandardMaterial3D
					if gr_mat:
						gr_mat.albedo_color.a = 0.42 + sin(elapsed * 2.8 + i * 0.6) * 0.28
	# Update rival score labels
	for i in mini(rivals.size(), rival_score_labels.size()):
		rival_score_labels[i].text = "%d pts" % race.racers[i + 1].score
	for event in race.events:
		if event.racer == 0:
			hits += 1
			var tier := 3 if event.kind == "power3x" else (2 if event.kind == "rare" else (1 if event.kind == "power" or event.bonus else 0))
			var text: String
			if event.kind == "power3x":
				text = "+%d  •  ULTRA BOOST!" % event.points
			elif event.kind == "rare":
				text = "+%d  •  SUPER BOOST!" % event.points
			elif event.kind == "power":
				text = "+%d  •  BOOST!" % event.points
			else:
				text = "+%d" % event.points
			var clr := Color("ffd700") if event.kind == "power3x" else (Color("ff9de8") if event.kind == "rare" else (Color("8cfff1") if event.kind == "power" or event.bonus else Color("ffe38a")))
			_show_feedback(text, clr)
			_spawn_score_pop(event.points, tier)
			if tier >= 2: camera.impulse(0.20 if tier == 3 else 0.13)
			elif tier == 1: camera.impulse(0.06)

			var neon_col: Color
			match event.kind:
				"power3x": neon_col = Color("ccaaff")
				"rare":    neon_col = Color("ff6644")
				_:
					match event.id % 4:
						1: neon_col = Color("44ee88")
						2: neon_col = Color("ff6644")
						3: neon_col = Color("cc88ff")
						_: neon_col = Color("67f5ed")
			collection_fx.collect(Vector3(cart.position.x, 1.25, -COLLECTION_FRONT), tier, reduced, high_detail, neon_col)
			track.festival.cheer_strength = 1.0
			race_audio.celebrate("boost" if event.kind in ["power", "rare", "power3x"] or event.bonus else ("streak" if event.bonus else "collect"))
		else:
			# Rival collected — trigger their urge animation
			var ri: int = event.racer - 1
			if ri < rivals.size(): rivals[ri].set("pending_flick", true)
	# Advance score pop animations
	for pop_dict in score_pops:
		if pop_dict.age >= 1.0: continue
		pop_dict.age += dt
		var t: float = minf(pop_dict.age, 1.0)
		var pop_lbl := pop_dict.label as Label3D
		pop_lbl.position.y = 2.0 + t * 2.8
		var fc: Color = pop_dict.color
		pop_lbl.modulate = Color(fc.r, fc.g, fc.b, maxf(0.0, 1.0 - t * 1.3))
	# Section banner (motion preview only)
	if motion_preview and section_banner:
		var new_sec := race.section_name(race.racers[0].distance)
		if new_sec != last_section_name and elapsed > 1.0:
			last_section_name = new_sec
			section_banner.text = "— " + new_sec + " —"
			section_banner_time = 2.5
		if section_banner_time > 0:
			section_banner_time = maxf(0.0, section_banner_time - dt)
			section_banner.modulate.a = minf(1.0, section_banner_time) * minf(1.0, (2.5 - section_banner_time) * 4.0)
		else:
			section_banner.modulate.a = 0.0
	if motion_preview and race.racers[0].finish >= 0 and not finish_announced:
		finish_announced = true
		cart.show_boost(false)
		cart.freeze_effects(true)
		_show_feedback("FINISHED!  %.2f seconds" % race.racers[0].finish, Color("8cfff1"))
	var place: int = race.player_place()
	if elapsed > 2.0 and place < previous_place and race.events.is_empty():
		_show_feedback("OVERTAKE!  •  Position %d" % place, Color("ffe38a"))
		track.festival.cheer_strength = 1.0
		race_audio.celebrate("overtake")
	previous_place = place
	if not race.timed_mode:
		finish_gate.position.z = race.racers[0].distance - Race.LENGTH - COLLECTION_FRONT
	feedback_time = maxf(0, feedback_time - dt)
	if feedback_time == 0: feedback.text = ""
	_update_hud()
	if not motion_preview and race.complete: finish_ride()

func _update_hud() -> void:
	if race_dashboard: race_dashboard.update_race(race)
	if mini_hud and mini_hud.visible:
		if race.timed_mode:
			var tl := maxf(0.0, race.game_duration - race.elapsed)
			mini_time_label.text = "%02d:%02d" % [int(tl / 60.0), int(tl) % 60]
		else:
			mini_time_label.text = "%02d:%02d" % [int(elapsed / 60.0), int(elapsed) % 60]
		mini_score_label.text = "* %d" % race.racers[0].score
		mini_pos_label.text = ["1ST", "2ND", "3RD"][clampi(race.player_place() - 1, 0, 2)]
	if race.timed_mode:
		var time_left := maxf(0.0, race.game_duration - race.elapsed)
		hud.text = "POS %d/3  •  %02d:%02d LEFT  •  %d PTS" % [race.player_place(), int(time_left / 60.0), int(time_left) % 60, race.racers[0].score]
	else:
		hud.text = "POS %d/3  •  %02d:%02d  •  %d m  •  %d PTS" % [race.player_place(), int(elapsed / 60.0), int(elapsed) % 60, maxi(0, int(Race.LENGTH - race.racers[0].distance)), race.racers[0].score]
	if boost_label:
		if motion_preview:
			boost_label.text = "BOOST %.1f s" % race.racers[0].boost if race.racers[0].boost > 0 else "BLUE PICKUP = AUTO BOOST"
		elif race.racers[0].boost > 0:
			boost_label.text = "BOOST %.1f s" % race.racers[0].boost
		elif race.racers[0].power > 0:
			var stash: Array = race.racers[0].power_stash
			var next_kind: String = str(stash[0]) if not stash.is_empty() else "power"
			var kind_map: Dictionary = {"power3x": "3X ULTRA", "rare": "RARE BOOST", "power": "BOOST"}
			var kind_label: String = kind_map.get(next_kind, "BOOST")
			boost_label.text = "POWER %d/3  •  %s READY  •  SPACE" % [race.racers[0].power, kind_label]
		else:
			boost_label.text = "COLLECT CYAN POWER  •  SPACE TO BOOST"
	if race_hint:
		var gap := 0.0
		if race.timed_mode:
			for rival in race.racers: gap = maxf(gap, float(rival.score - race.racers[0].score))
		else:
			for rival in race.racers: gap = maxf(gap, rival.distance - race.racers[0].distance)
		var challenge := "LEADING" if race.player_place() == 1 else ("ALMOST TIED" if gap < 5 else ("%.0f m TO LEADER" % gap if not race.timed_mode else "%d PTS TO LEAD" % int(gap)))
		if race.racers[0].drafting and race.racers[0].boost <= 0: challenge = "SLIPSTREAM • SPEED +"
		if motion_preview:
			if race.racers[0].drafting:
				challenge = "SLIPSTREAM READY • CHANGE LANE TO PASS" if race.racers[0].draft_charge >= 1.2 else "SLIPSTREAM • BUILDING"
			elif race.racers[0].slingshot > 0: challenge = "SLINGSHOT • PASS NOW!"
			challenge = race.section_name(race.racers[0].distance) + " • " + challenge
		if motion_preview and race.racers[0].contact_time > 0: challenge = "GENTLE CONTACT • RECOVERING"
		if motion_preview and race.difficulty == 0: challenge = "PRACTICE • 3 ACTIVE LANES"
		if motion_preview and race.racers[0].finish >= 0 and not race.complete: challenge = "YOU FINISHED • WATCH THE OTHERS FINISH"
		race_hint.text = ("%s  •  Tap ← → to change lanes" if motion_preview else "%s  •  3 pickups = extra boost") % challenge

func _spawn_score_pop(points: int, tier: int) -> void:
	var pop_dict: Dictionary
	for p in score_pops:
		if p.age >= 1.0: pop_dict = p; break
	if pop_dict.is_empty(): return
	pop_dict.age = 0.0
	var lbl := pop_dict.label as Label3D
	var text := "+%d" % points
	if tier == 3: text += "  3X!"
	elif tier == 2: text += "  RARE!"
	var c := Color("ffd700") if tier == 3 else (Color("ff9de8") if tier == 2 else Color("8cfff1"))
	pop_dict.color = c
	lbl.outline_modulate = Color(0, 0, 0, 0.7)
	lbl.text = text
	lbl.modulate = c
	lbl.position = Vector3(cart.position.x, 2.0, -COLLECTION_FRONT - 0.5)


func _show_feedback(message: String, color: Color) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", color)
	feedback_time = 1.8
	feedback_pulse = .4

func finish_ride() -> void:
	_finish_therapy()
	# End-of-race burst: all carts do one final urge gesture
	if motion_preview:
		cart.set("pending_flick", true)
		for rival in rivals: rival.set("pending_flick", true)
	cart.freeze_effects(true)
	for rival in rivals: rival.freeze_effects(true)
	running = false
	feedback.text = ""
	pause_button.disabled = true
	if mini_pause_btn: mini_pause_btn.disabled = true
	top_bar.show()
	mini_hud.hide()
	var dur_min := int(race.game_duration / 60.0)
	var title := "TIME'S UP!"
	var message := "Your score:  %d pts\n%d lanterns collected in %d min\nCollect rare & gold lanterns for bigger scores!" % [race.racers[0].score, hits, dur_min]
	if not motion_preview:
		_show_modal(title, message, "Play again")
	else:
		if race.difficulty == 0: title = "PRACTICE COMPLETE"
		completed_difficulty = race.difficulty
		_show_modal(title, message, "New course")
		result_board.show_results(race)
		retry_button.show()

	race_audio.finish_race()

func _pause(message := "Take your time. Your ride is paused.") -> void:
	if not running: return
	cart.freeze_effects(true)
	for rival in rivals: rival.freeze_effects(true)
	paused = true
	_disable_assistance()
	_log_therapy("PAUSED")
	race_audio.set_paused(true)
	top_bar.show()
	mini_hud.hide()
	_show_modal("A little rest", message, "Continue ride")

func _play() -> void:
	if paused:
		if device_session and (not PlutoComm.is_connected or not PlutoComm.is_streaming): return
		therapy_target = -1.0
		_log_therapy("MOVE")
		cart.freeze_effects(false)
		for rival in rivals: rival.freeze_effects(false)
		paused = false
		play_button.release_focus()
		modal.hide()
		race_audio.set_paused(false)
		audio_panel.hide()
		top_bar.hide()
		mini_hud.show()
	else:
		if motion_preview: race.layout_seed = 0
		start_ride()

func _unhandled_key_input(event: InputEvent) -> void:
	if motion_preview and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_mp_pluto_action()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE and running and not paused and not motion_preview:
		if race.activate_boost(0):
			_show_feedback("BOOST!", Color("8cfff1"))
			race_audio.celebrate("boost")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C and not motion_preview:
		camera.side_view = not camera.side_view
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G and event.ctrl_pressed and motion_preview:
		if _mp_speed_panel:
			if _mp_speed_panel.visible: _mp_speed_panel.hide()
			else: _mp_speed_panel.show()
	if event.is_action_pressed("ui_cancel"):
		if motion_preview:
			if paused: _mp_resume()
			elif running: _mp_pause()
		else:
			if paused: _play()
			else: _pause()

func _show_modal(title: String, message: String, action: String) -> void:
	if result_board: result_board.hide()
	if difficulty_select:
		difficulty_select.visible = not running
		difficulty_help.visible = not running
	if duration_select:
		duration_select.visible = not running
	modal_title.text = title
	modal_body.text = message
	play_button.text = action
	modal.show()
	play_button.grab_focus()
	if motion_preview: _center_modal.call_deferred()

func _center_modal() -> void:
	if modal and is_instance_valid(modal.get_parent()):
		var minimum := modal.get_combined_minimum_size()
		var desired := Vector2(maxf(620, minimum.x), minimum.y)
		if not modal.size.is_equal_approx(desired): modal.size = desired
		modal.position = (modal.get_parent().size - modal.size) * .5

func _style(color: Color) -> StyleBoxFlat:
	var style := Palette.surface(color)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.set_meta("arcade_authored_control", true)
	button.text = text
	button.custom_minimum_size = Vector2(160, 54)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_hover_color", Palette.INK)
	button.add_theme_color_override("font_focus_color", Palette.INK)
	button.add_theme_stylebox_override("normal", Palette.chrome("button-lime"))
	button.add_theme_stylebox_override("focus", Palette.surface(Color(0, 0, 0, 0), 14, Palette.ACCENT))
	button.add_theme_stylebox_override("hover", Palette.chrome("button-purple"))
	button.add_theme_stylebox_override("pressed", Palette.chrome("button-purple"))
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameUI"
	add_child(canvas)
	var root := Control.new()
	root.name = "Interface"
	root.theme = preload("res://Assets/Arcade/daylight-theme.tres")
	root.set_meta("arcade_authored_control", true)
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top_bar = top
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26
	top.offset_right = -26
	top.offset_top = 22
	top.add_theme_constant_override("separation", 12)
	race_dashboard = preload("res://game/BULLOCK_CART/scripts/race_hud.gd").new()
	race_dashboard.auto_boost = motion_preview
	race_dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(race_dashboard)
	hud = Label.new()
	hud.set_meta("arcade_authored_control", true)
	hud.add_theme_color_override("font_color", Color("244b46"))
	hud.add_theme_font_size_override("font_size", 23)
	race_dashboard.add_child(hud)
	hud.hide()
	music_button = _button("Audio ♪", top, _toggle_audio_panel)
	pause_button = _button("Pause  Ⅱ", top, _pause)
	pause_button.disabled = true
	detail_button = _button("PC detail", top, _toggle_detail)
	detail_button.custom_minimum_size.x = 130
	boost_label = Label.new()
	boost_label.set_meta("arcade_authored_control", true)
	boost_label.hide()
	root.add_child(boost_label)
	boost_label.position = Vector2(30, 120)
	boost_label.add_theme_font_size_override("font_size", 22)
	boost_label.add_theme_color_override("font_color", Color("ddffff"))
	boost_label.add_theme_color_override("font_outline_color", Color("173b3c"))
	boost_label.add_theme_constant_override("outline_size", 7)
	race_hint = Label.new()
	race_hint.set_meta("arcade_authored_control", true)
	root.add_child(race_hint)
	race_hint.position = Vector2(30, 205 if motion_preview else 175)
	race_hint.add_theme_font_size_override("font_size", 18)
	race_hint.add_theme_color_override("font_color", Color("fff4dd"))
	race_hint.add_theme_color_override("font_outline_color", Color("352919"))
	race_hint.add_theme_constant_override("outline_size", 6)
	feedback = Label.new()
	feedback.set_meta("arcade_authored_control", true)
	root.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	feedback.offset_top = -75
	feedback.offset_bottom = -25
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 28)
	feedback.add_theme_color_override("font_color", Color("ffffff"))
	feedback.add_theme_color_override("font_outline_color", Color("304936"))
	feedback.add_theme_constant_override("outline_size", 8)

	section_banner = Label.new()
	section_banner.set_meta("arcade_authored_control", true)
	section_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	section_banner.offset_left = -340; section_banner.offset_right = 340
	section_banner.offset_top = -24; section_banner.offset_bottom = 24
	section_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_banner.add_theme_font_size_override("font_size", 30)
	section_banner.add_theme_color_override("font_color", Color("ffe38a"))
	section_banner.add_theme_color_override("font_outline_color", Color("2a1505"))
	section_banner.add_theme_constant_override("outline_size", 10)
	section_banner.modulate.a = 0.0
	root.add_child(section_banner)
	modal = PanelContainer.new()
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -310
	modal.offset_right = 310
	modal.offset_top = -265 if motion_preview else -160
	modal.offset_bottom = 265 if motion_preview else 160
	modal.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	if motion_preview: modal.resized.connect(_center_modal)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12 if motion_preview else 18)
	modal.add_child(column)
	modal_title = Label.new()
	modal_title.set_meta("arcade_authored_control", true)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_font_size_override("font_size", 36)
	modal_title.add_theme_color_override("font_color", Palette.INK)
	column.add_child(modal_title)
	modal_body = Label.new()
	modal_body.set_meta("arcade_authored_control", true)
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_body.add_theme_font_size_override("font_size", 20)
	modal_body.add_theme_color_override("font_color", Palette.INK)
	column.add_child(modal_body)
	if motion_preview:
		result_board = preload("res://game/BULLOCK_CART/scripts/race_result_board.gd").new()
		column.add_child(result_board)
		result_board.hide()
		difficulty_select = OptionButton.new()
		difficulty_select.set_meta("arcade_authored_control", true)
		for level in race.LEVELS: difficulty_select.add_item(level)
		difficulty_select.select(race.difficulty)
		difficulty_select.custom_minimum_size.y = 44
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			difficulty_select.add_theme_color_override(state, Color("ffffff"))
		for state in ["normal", "hover", "pressed", "focus"]:
			difficulty_select.add_theme_stylebox_override(state, _style(Color("225d60")))
		var popup := difficulty_select.get_popup()
		popup.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
		popup.add_theme_stylebox_override("hover", _style(Color("225d60")))
		popup.add_theme_color_override("font_color", Color("203f40"))
		popup.add_theme_color_override("font_hover_color", Color.WHITE)
		column.add_child(difficulty_select)
		difficulty_help = Label.new()
		difficulty_help.set_meta("arcade_authored_control", true)
		difficulty_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		difficulty_help.add_theme_color_override("font_color", Palette.INK)
		difficulty_help.add_theme_font_size_override("font_size", 16)
		difficulty_help.text = race.LEVEL_HELP[race.difficulty]
		column.add_child(difficulty_help)
		difficulty_select.item_selected.connect(func(index: int): difficulty_help.text = race.LEVEL_HELP[index])
	duration_select = OptionButton.new()
	duration_select.set_meta("arcade_authored_control", true)
	for dur in ["1 minute", "3 minutes", "5 minutes"]:
		duration_select.add_item(dur)
	duration_select.select(1)
	duration_select.custom_minimum_size.y = 44
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		duration_select.add_theme_color_override(state, Color("ffffff"))
	for state in ["normal", "hover", "pressed", "focus"]:
		duration_select.add_theme_stylebox_override(state, _style(Color("225d60")))
	var dur_popup := duration_select.get_popup()
	dur_popup.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	dur_popup.add_theme_stylebox_override("hover", _style(Color("225d60")))
	dur_popup.add_theme_color_override("font_color", Color("203f40"))
	dur_popup.add_theme_color_override("font_hover_color", Color.WHITE)
	column.add_child(duration_select)
	play_button = _button("Start ride", column, _play)
	if motion_preview:
		retry_button = _button("Retry same course", column, _retry_course)
		retry_button.hide()
	_button("Choose game", column, func(): get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn"))
	_build_audio_panel(root)
	# Minimal in-game overlay — time left, position, score, tiny pause button
	mini_hud = Control.new()
	mini_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mini_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(mini_hud)
	mini_time_label = Label.new()
	mini_time_label.set_meta("arcade_authored_control", true)
	mini_time_label.position = Vector2(18, 14)
	mini_time_label.add_theme_font_size_override("font_size", 28)
	mini_time_label.add_theme_color_override("font_color", Color("e8fffd"))
	mini_time_label.add_theme_color_override("font_outline_color", Color("071f1e"))
	mini_time_label.add_theme_constant_override("outline_size", 9)
	mini_hud.add_child(mini_time_label)
	mini_pos_label = Label.new()
	mini_pos_label.set_meta("arcade_authored_control", true)
	mini_pos_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mini_pos_label.offset_top = 10
	mini_pos_label.offset_bottom = 56
	mini_pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mini_pos_label.add_theme_font_size_override("font_size", 36)
	mini_pos_label.add_theme_color_override("font_color", Color("ffd568"))
	mini_pos_label.add_theme_color_override("font_outline_color", Color("1e1000"))
	mini_pos_label.add_theme_constant_override("outline_size", 10)
	mini_hud.add_child(mini_pos_label)
	mini_score_label = Label.new()
	mini_score_label.set_meta("arcade_authored_control", true)
	mini_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini_score_label.offset_left = -260
	mini_score_label.offset_right = -70
	mini_score_label.offset_top = 14
	mini_score_label.add_theme_font_size_override("font_size", 28)
	mini_score_label.add_theme_color_override("font_color", Color("ffd568"))
	mini_score_label.add_theme_color_override("font_outline_color", Color("1e1000"))
	mini_score_label.add_theme_constant_override("outline_size", 9)
	mini_hud.add_child(mini_score_label)
	mini_pause_btn = Button.new()
	mini_pause_btn.set_meta("arcade_authored_control", true)
	mini_pause_btn.text = "II"
	mini_pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini_pause_btn.offset_left = -60
	mini_pause_btn.offset_right = -10
	mini_pause_btn.offset_top = 10
	mini_pause_btn.offset_bottom = 54
	mini_pause_btn.add_theme_font_size_override("font_size", 18)
	mini_pause_btn.add_theme_color_override("font_color", Color("ffffff"))
	mini_pause_btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	mini_pause_btn.add_theme_color_override("font_focus_color", Color("ffffff"))
	mini_pause_btn.add_theme_stylebox_override("normal", _style(Color(0.09, 0.40, 0.42, 0.55)))
	mini_pause_btn.add_theme_stylebox_override("hover", _style(Color(0.14, 0.51, 0.51, 0.80)))
	mini_pause_btn.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.30, 0.31, 0.80)))
	mini_pause_btn.pressed.connect(_pause)
	mini_hud.add_child(mini_pause_btn)
	mini_hud.hide()
	if motion_preview:
		_mp_build_panels(root)
		_mp_header_timer = Label.new()
		_mp_header_timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_mp_header_timer.offset_top = 14
		_mp_header_timer.offset_bottom = 54
		_mp_header_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mp_header_timer.add_theme_font_size_override("font_size", 30)
		_mp_header_timer.add_theme_color_override("font_color", Color("ffffff"))
		_mp_header_timer.add_theme_color_override("font_outline_color", Color("071f1e"))
		_mp_header_timer.add_theme_constant_override("outline_size", 9)
		_mp_header_timer.text = "Time: 60 s"
		mini_hud.add_child(_mp_header_timer)
		_mp_header_score = Label.new()
		_mp_header_score.position = Vector2(18, 60)
		_mp_header_score.add_theme_font_size_override("font_size", 20)
		_mp_header_score.add_theme_color_override("font_color", Color("ffd568"))
		_mp_header_score.add_theme_color_override("font_outline_color", Color("1e1000"))
		_mp_header_score.add_theme_constant_override("outline_size", 7)
		_mp_header_score.text = "Score: 0 / 0"
		mini_hud.add_child(_mp_header_score)
	# FloatScore: collect icon + count, star icon + count — top-left
	var fs := Panel.new()
	fs.name = "FloatScore"
	fs.set_meta("arcade_authored_control", true)
	fs.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	fs.offset_left = 12; fs.offset_right = 260; fs.offset_top = 12; fs.offset_bottom = 68
	fs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs_bg := StyleBoxFlat.new()
	fs_bg.bg_color = Color(0.07, 0.11, 0.18, 0.84)
	fs_bg.set_corner_radius_all(12)
	fs_bg.set_border_width_all(1)
	fs_bg.border_color = Color(1, 1, 1, 0.10)
	fs.add_theme_stylebox_override("panel", fs_bg)
	root.add_child(fs)
	var fs_ci := TextureRect.new()
	fs_ci.set_meta("arcade_authored_control", true)
	fs_ci.texture = load("res://game/BULLOCK_CART/assets/generated/festival-boost-lantern.png")
	fs_ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fs_ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fs_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fs_ci.position = Vector2(6, 7); fs_ci.size = Vector2(38, 38)
	fs.add_child(fs_ci)
	var fs_cl := Label.new()
	fs_cl.name = "CollectCount"
	fs_cl.set_meta("arcade_authored_control", true)
	fs_cl.add_theme_font_size_override("font_size", 26)
	fs_cl.add_theme_color_override("font_color", Color("e8f4fc"))
	fs_cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fs_cl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	fs_cl.position = Vector2(50, 11); fs_cl.size = Vector2(60, 32)
	fs_cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fs.add_child(fs_cl)
	var fs_si := TextureRect.new()
	fs_si.name = "StarIcon"
	fs_si.set_meta("arcade_authored_control", true)
	fs_si.texture = preload("res://scripts/ui/arcade_assets.gd").sprite("star")
	fs_si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fs_si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fs_si.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fs_si.position = Vector2(122, 11); fs_si.size = Vector2(32, 32)
	fs.add_child(fs_si)
	var fs_sc := Label.new()
	fs_sc.name = "StarCount"
	fs_sc.set_meta("arcade_authored_control", true)
	fs_sc.add_theme_font_size_override("font_size", 26)
	fs_sc.add_theme_color_override("font_color", Color("efbc46"))
	fs_sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fs_sc.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	fs_sc.position = Vector2(160, 11); fs_sc.size = Vector2(50, 32)
	fs_sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fs.add_child(fs_sc)

	# GameHudCard: time ring — below FloatScore
	var hud_card := preload("res://scripts/ui/game_hud_card.gd").new()
	hud_card.name = "GameHudCard"
	hud_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud_card.position = Vector2(12, 76)
	root.add_child(hud_card)

	# GameTrialCard: session ring — bottom-right
	var trial_card := preload("res://scripts/ui/game_trial_card.gd").new()
	trial_card.name = "GameTrialCard"
	trial_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	trial_card.offset_left = -170; trial_card.offset_right = -12
	trial_card.offset_top  = -60;  trial_card.offset_bottom = -12
	root.add_child(trial_card)
	_update_hud()

func _toggle_music() -> void:
	MenuMusic.set_muted(not MenuMusic.muted)
	race_audio.sync_music_mute()

func _toggle_audio_panel() -> void:
	if audio_panel.visible:
		audio_panel.hide()
		return
	if running and not paused: _pause()
	audio_panel.show()

func _build_audio_panel(root: Control) -> void:
	audio_panel = PanelContainer.new()
	root.add_child(audio_panel)
	audio_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	audio_panel.offset_left = -335
	audio_panel.offset_right = -26
	audio_panel.offset_top = 90
	audio_panel.add_theme_stylebox_override("panel", _style(Color("fff4dc")))
	var column := VBoxContainer.new()
	audio_panel.add_child(column)
	var enabled := CheckButton.new()
	enabled.set_meta("arcade_authored_control", true)
	enabled.text = "Background music"
	enabled.button_pressed = not MenuMusic.muted
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		enabled.add_theme_color_override(state, Color("244b46"))
	column.add_child(enabled)
	enabled.toggled.connect(func(_value: bool): _toggle_music())
	for channel in ["music", "crowd", "effects"]:
		var label := Label.new()
		label.set_meta("arcade_authored_control", true)
		label.text = {"music": "BGM volume", "crowd": "Crowd & Tamil cheers", "effects": "Pickup effects"}[channel]
		label.add_theme_color_override("font_color", Color("244b46"))
		column.add_child(label)
		var slider := HSlider.new()
		slider.name = channel.capitalize() + "Volume"
		slider.set_meta("arcade_authored_control", true)
		slider.max_value = 1.0
		slider.step = .05
		slider.custom_minimum_size = Vector2(250, 28)
		slider.value = race_audio.get(channel + "_level")
		column.add_child(slider)
		slider.value_changed.connect(func(value: float): race_audio.set_level(channel, value))
	_button("Close audio", column, func(): audio_panel.hide())
	var credits := RichTextLabel.new()
	credits.set_meta("arcade_authored_control", true)
	credits.bbcode_enabled = true
	credits.fit_content = true
	credits.custom_minimum_size.x = 250
	credits.add_theme_font_size_override("normal_font_size", 12)
	credits.add_theme_color_override("default_color", Color("244b46"))
	credits.text = "Music: bgm1.mp3 / bgm2.mp3 (project supplied)\nTracks alternate on replay and when a song ends.\nCrowd: [url=https://opengameart.org/content/free-crowd-cheering-sounds]Gregor Quendel[/url] ([url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]), edited\nTamil cheers: synthesized voices"
	credits.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	column.add_child(credits)
	audio_panel.hide()

func _toggle_detail() -> void:
	high_detail = not high_detail
	_apply_detail()

func _apply_detail() -> void:
	sun.shadow_enabled = high_detail
	cart.set_character_detail(high_detail)
	for rival in rivals: rival.set_character_detail(high_detail)
	detail_button.text = "PC detail" if high_detail else "Light detail"
	track.set_detail(high_detail)

func _device_button() -> void:
	if motion_preview:
		_mp_pluto_action()
		return
	if not running: return
	if paused: _play()
	else: _pause()

func _disable_assistance() -> void:
	PlutoComm.set_control_type("NONE")
	PlutoComm.reset_aan_target()
	aan.reset_trial()
	therapy_target = -1.0

func _finish_therapy() -> void:
	_disable_assistance()
	if therapy_active:
		_log_therapy("DONE")
		therapy_active = false
		AppData.stop_trial(maxi(encountered.size(), hits), hits, maxi(0, encountered.size() - hits))

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_device_button):
		EventBus.button_released.disconnect(_device_button)
	if motion_preview:
		PlutoComm.set_control_type("NONE")
		if not _mp_game_finished:
			AppData.stop_trial(_mp_n_targets, _mp_n_success, _mp_n_failure)
		return
	_finish_therapy()

func _log_therapy(state_name: String) -> void:
	AppData.log_game_state = state_name
	AppData.log_player_x = race.racers[0].x
	AppData.log_player_y = race.racers[0].distance
	AppData.log_aan_target = aan.target_position
	AppData.log_aan_init = aan.initial_position
	AppData.log_aan_state = AAN.State.keys()[aan.state]
	if therapy_target < 0:
		AppData.log_target_x = 0.0
		AppData.log_target_y = 0.0

func _update_assistance(dt: float) -> void:
	var nearest: Dictionary = {}
	for pickup in race.pickups:
		if pickup.owner == -1 and pickup.distance >= race.racers[0].distance:
			if nearest.is_empty() or pickup.distance < nearest.distance: nearest = pickup
	if nearest.is_empty():
		_disable_assistance()
		return
	AppData.log_target_x = nearest.x
	AppData.log_target_y = nearest.distance
	if therapy_target != nearest.distance:
		therapy_target = nearest.distance
		if aan_enabled:
			PlutoComm.reset_aan_target()
			PlutoComm.set_control_type("POSITIONAAN")
			PlutoComm.set_control_bound(AppData.assist_bound)
			PlutoComm.set_control_dir(0)
			aan.reset_trial()
			var fraction: float = inverse_lerp(race.lane_x(race.lane_min), race.lane_x(race.lane_max), nearest.x)
			var angle: float = clampf(lerpf(therapy_aprom[0], therapy_aprom[1], fraction), aan.prom[0], aan.prom[1])
			var duration: float = maxf(1.0, (nearest.distance - race.racers[0].distance) / maxf(1.0, race.racers[0].speed))
			var speed: float = AppData.speed_data.game_speed if AppData.speed_data != null else 10.0
			aan.set_new_trial_details(PlutoComm.angle, angle, duration, speed)
	if aan_enabled:
		aan.update(PlutoComm.angle, dt, false)
		if aan.state_change:
			if aan.state == AAN.State.AROM_MOVING: PlutoComm.reset_aan_target()
			else:
				var target = aan.get_new_aan_target()
				if target != null: PlutoComm.set_aan_target(target[0], target[1], target[2], target[3])

# ============================================================
# motion_preview therapeutic mode — all functions below
# ============================================================

func _preload_assets() -> void:
	for key in [&"player", &"amber", &"indigo"]:
		var sheet = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/cart-centered-%s.png" % key)
		if sheet: _preloaded_cart_sheets[key] = sheet
		var meta = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/cart-centered-%s.json" % key)
		if meta: _preloaded_cart_meta[key] = meta
	_preloaded_multi_tex = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/multiple powers.png")
	_preloaded_rare_tex  = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/rarePower.png")
	_preloaded_p3x_tex   = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/power3X.png")
	for fname in ["flower_cherry", "flower_blossom", "flower_hibiscus", "flower_sunflower", "flower_tulip"]:
		var t: Texture2D = ResourceLoader.load("res://game/BULLOCK_CART/assets/generated/%s.png" % fname)
		if t: _preloaded_flowers.append(t)

func _mp_init_rom_data() -> void:
	if AppData.selected_mechanism == null:
		_mp_aprom = [-45.0, 45.0]; _mp_arom = [-30.0, 30.0]; _mp_prom = [-45.0, 45.0]
		_mp_set_min_max_duration()
		return
	_mp_aprom = AppData.selected_mechanism.current_aprom.duplicate()
	_mp_arom  = AppData.selected_mechanism.current_arom.duplicate()
	_mp_prom  = AppData.selected_mechanism.current_prom.duplicate()
	if _mp_aprom.size() < 2: _mp_aprom = [-45.0, 45.0]
	if _mp_arom.size()  < 2: _mp_arom  = [-30.0, 30.0]
	if _mp_prom.size()  < 2: _mp_prom  = [-45.0, 45.0]
	_mp_set_min_max_duration()

func _mp_set_min_max_duration() -> void:
	var range_size := absf(_mp_aprom[1] - _mp_aprom[0])
	_mp_mech_max_duration = clampf(range_size / maxf(MP_MIN_SPEED, 1.0), 1.5, 6.0)
	_mp_mech_min_duration = clampf(range_size / maxf(MP_MAX_SPEED, 1.0), 0.3, 2.0)

func _mp_calc_speed() -> void:
	_mp_game_speed = MP_MIN_SPEED
	if AppData.speed_data != null:
		_mp_game_speed = clampf(AppData.speed_data.game_speed, MP_MIN_SPEED, MP_MAX_SPEED)
	_mp_recalc_from_speed()

func _mp_recalc_from_speed() -> void:
	var t := clampf((_mp_game_speed - MP_MIN_SPEED) / maxf(MP_MAX_SPEED - MP_MIN_SPEED, 1.0), 0.0, 1.0)
	_mp_move_duration = lerpf(_mp_mech_max_duration, _mp_mech_min_duration, t)
	if _mp_speed_lbl:
		_mp_speed_lbl.text = "%d" % int(_mp_game_speed)
	if _mp_speed_info_lbl:
		_mp_speed_info_lbl.text = "Duration: %.1f s\nBound: %.2f" % [_mp_move_duration, AppData.assist_bound]

func _mp_build_panels(canvas_root: Control) -> void:
	# --- Wait panel ---
	_mp_wait_panel = PanelContainer.new()
	canvas_root.add_child(_mp_wait_panel)
	_mp_wait_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mp_wait_panel.offset_left = -310; _mp_wait_panel.offset_right = 310
	_mp_wait_panel.offset_top = -10; _mp_wait_panel.offset_bottom = 10
	_mp_wait_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mp_wait_panel.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	var wc := VBoxContainer.new()
	wc.add_theme_constant_override("separation", 14)
	_mp_wait_panel.add_child(wc)
	var wt := Label.new()
	wt.text = "BULLOCK CART"
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wt.add_theme_font_size_override("font_size", 40)
	wt.add_theme_color_override("font_color", Palette.INK)
	wc.add_child(wt)
	var wb := Label.new()
	wb.text = "Steer toward each lantern to collect it!\nBlue: boost • Pink: super boost • Gold: ultra boost"
	wb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wb.add_theme_font_size_override("font_size", 18)
	wb.add_theme_color_override("font_color", Palette.INK)
	wb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wc.add_child(wb)
	var wh := Label.new()
	wh.name = "HintLabel"
	wh.text = "Press SPACE or choose Play" if not PlutoComm.is_connected else "Press the PLUTO button or choose Play"
	wh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wh.add_theme_font_size_override("font_size", 18)
	wh.add_theme_color_override("font_color", Palette.INK)
	wc.add_child(wh)
	_button("PLAY", wc, _mp_start_pressed)
	_mp_wait_panel.hide()
	# --- Pause panel ---
	_mp_pause_panel = PanelContainer.new()
	canvas_root.add_child(_mp_pause_panel)
	_mp_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mp_pause_panel.offset_left = -260; _mp_pause_panel.offset_right = 260
	_mp_pause_panel.offset_top = -10; _mp_pause_panel.offset_bottom = 10
	_mp_pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mp_pause_panel.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 14)
	_mp_pause_panel.add_child(pc)
	var pt := Label.new()
	pt.text = "Paused"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_theme_font_size_override("font_size", 40)
	pt.add_theme_color_override("font_color", Palette.INK)
	pc.add_child(pt)
	var ph := Label.new()
	ph.text = "Take your time. Your session is paused."
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.add_theme_font_size_override("font_size", 18)
	ph.add_theme_color_override("font_color", Palette.INK)
	pc.add_child(ph)
	_button("RESUME", pc, _mp_resume)
	_mp_pause_panel.hide()
	# --- Game over panel ---
	_mp_over_panel = PanelContainer.new()
	canvas_root.add_child(_mp_over_panel)
	_mp_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mp_over_panel.offset_left = -310; _mp_over_panel.offset_right = 310
	_mp_over_panel.offset_top = -10; _mp_over_panel.offset_bottom = 10
	_mp_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mp_over_panel.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	var oc := VBoxContainer.new()
	oc.add_theme_constant_override("separation", 14)
	_mp_over_panel.add_child(oc)
	var ot := Label.new()
	ot.text = "Session complete"
	ot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ot.add_theme_font_size_override("font_size", 40)
	ot.add_theme_color_override("font_color", Palette.INK)
	oc.add_child(ot)
	var os_lbl := Label.new()
	os_lbl.name = "MPScoreFinalLabel"
	os_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	os_lbl.add_theme_font_size_override("font_size", 32)
	os_lbl.add_theme_color_override("font_color", Palette.INK)
	oc.add_child(os_lbl)
	_button("PLAY AGAIN", oc, func(): get_tree().reload_current_scene())
	_button("Choose game", oc, _mp_exit_to_games)
	_mp_over_panel.hide()
	# --- Speed panel ---
	_mp_speed_panel = PanelContainer.new()
	canvas_root.add_child(_mp_speed_panel)
	_mp_speed_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mp_speed_panel.offset_left = -220; _mp_speed_panel.offset_right = 220
	_mp_speed_panel.offset_top = -10; _mp_speed_panel.offset_bottom = 10
	_mp_speed_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mp_speed_panel.add_theme_stylebox_override("panel", _style(Palette.NIGHT))
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 10)
	_mp_speed_panel.add_child(sc)
	var spt := Label.new()
	spt.text = "Game speed"
	spt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spt.add_theme_font_size_override("font_size", 24)
	spt.add_theme_color_override("font_color", Palette.INK)
	sc.add_child(spt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	sc.add_child(row)
	_mp_dec_btn = _button("−", row, _mp_decrease_speed)
	_mp_speed_lbl = Label.new()
	_mp_speed_lbl.add_theme_font_size_override("font_size", 28)
	_mp_speed_lbl.add_theme_color_override("font_color", Palette.INK)
	_mp_speed_lbl.custom_minimum_size.x = 100
	_mp_speed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_mp_speed_lbl)
	_mp_inc_btn = _button("+", row, _mp_increase_speed)
	_mp_speed_info_lbl = Label.new()
	_mp_speed_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_speed_info_lbl.add_theme_font_size_override("font_size", 15)
	_mp_speed_info_lbl.add_theme_color_override("font_color", Palette.MUTED)
	sc.add_child(_mp_speed_info_lbl)
	_button("Close", sc, func(): _mp_speed_panel.hide())
	_mp_speed_panel.hide()
	_mp_recalc_from_speed()
	# Daily-star celebration card (same card the other games use), above every panel.
	_mp_celeb_card = preload("res://scenes/CelebrationCard.tscn").instantiate()
	_mp_celeb_card.score_unit = "lanterns"
	canvas_root.add_child(_mp_celeb_card)

func _mp_begin_game() -> void:
	_mp_time_left = MP_TRIAL_DURATION
	lantern_variant = 0
	_mp_n_targets = 0
	_mp_n_success = 0
	_mp_n_failure = 0
	_mp_game_finished = false
	elapsed = 0.0
	hits = 0
	finish_announced = false
	countdown_remaining = 0.0
	encountered.clear()
	race.reset()
	if retry_button: retry_button.hide()
	cart.reset_motion()
	for rival in rivals: rival.reset_motion()
	cart.position.x = 0
	cart.rotation.y = 0.0
	for rival in rivals: rival.rotation.y = 0.0
	camera.reset(Vector3.ZERO)
	_reset_targets()
	running = true
	paused = false
	mini_hud.show()
	top_bar.hide()
	if mini_pause_btn: mini_pause_btn.disabled = false
	pause_button.disabled = false
	race.automatic_pickup_recycling = false
	race.automatic_collection = false
	# Single-lantern mode: replace full pickup list with one placeholder
	race.pickups.clear()
	race.pickups.append({"id": 0, "distance": -999.0, "x": race.lane_x(2),
		"lane": 2, "kind": "power", "owner": -1, "primary": true})
	_reset_targets()  # rebuilds exactly 1 target node
	AppData.start_new_trial()
	_mp_setup_aan()
	race_audio.start_race()

func _mp_setup_aan() -> void:
	_mp_use_aan = not AppData.demo_mode and PlutoComm.is_connected \
				  and AppData.mechanism_name not in ["FME1", "FME2", "NOMECH"]
	_mp_aan = AAN.new()
	_mp_aan.arom = _mp_arom.duplicate()
	_mp_aan.prom = _mp_prom.duplicate()
	if _mp_use_aan and _mp_arom.size() >= 2 and _mp_prom.size() >= 2:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)
	else:
		_mp_use_aan = false

func _mp_end_game() -> void:
	_mp_game_finished = true
	PlutoComm.set_control_type("NONE")
	running = false
	mini_hud.hide()
	top_bar.show()
	race_audio.finish_race()
	if AppData.speed_data != null:
		AppData.speed_data.game_speed = _mp_game_speed
	# Today total = hits already saved today + this trial; award the daily star before stop_trial.
	var today_total := DataManager.read_today_hits(AppData.selected_game_name, AppData.mechanism_name) + _mp_n_success
	_mp_earned_star = AppData.selected_game != null and today_total > _mp_yesterday_hits \
		and today_total > 0 and AppData.selected_game.today_stars == 0
	if _mp_earned_star:
		AppData.selected_game.update_cumulative_stars()
	AppData.stop_trial(_mp_n_targets, _mp_n_success, _mp_n_failure)
	_mp_hide_lane_indicator()
	var over_score := _mp_over_panel.find_child("MPScoreFinalLabel", true, false) as Label
	if over_score:
		over_score.text = "%d / %d\nPress PLUTO button to play again" % [_mp_n_success, _mp_n_targets]
	_mp_over_panel.show()
	if _mp_earned_star and _mp_celeb_card:
		await get_tree().create_timer(0.6).timeout
		var star := get_node_or_null("GameUI/Interface/FloatScore/StarIcon") as Control
		var rect := star.get_global_rect() if star else Rect2(Vector2(140, 20), Vector2(36, 36))
		_mp_celeb_card.show_celebration(_mp_yesterday_hits, today_total, rect)

func _mp_on_outcome(success: bool) -> void:
	if success:
		_mp_n_success += 1
		_show_feedback("COLLECTED!", Color("8cfff1"))
		race_audio.celebrate("collect")
	else:
		_mp_n_failure += 1
		_show_feedback("MISSED!", Color("ff9966"))
	_mp_n_targets += 1

func _mp_pause() -> void:
	if not running or paused: return
	_mp_prev_state = _mp_state
	_mp_state = MPState.WAITING
	paused = true
	race_audio.set_paused(true)
	PlutoComm.set_control_type("NONE")
	_mp_hide_lane_indicator()
	mini_hud.hide()
	_mp_pause_panel.show()

func _mp_resume() -> void:
	if not paused: return
	_mp_pause_panel.hide()
	paused = false
	_mp_state = _mp_prev_state
	race_audio.set_paused(false)
	if _mp_use_aan and running:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)
	mini_hud.show()

## Start the session (wait panel -> first lantern).
func _mp_start_pressed() -> void:
	_mp_wait_panel.hide()
	_mp_state = MPState.START

## Device button / SPACE: same behaviour as every other game (start, pause/resume, play again).
func _mp_pluto_action() -> void:
	if _mp_wait_panel and _mp_wait_panel.visible:
		_mp_start_pressed()
	elif _mp_over_panel and _mp_over_panel.visible:
		get_tree().reload_current_scene()
	elif paused:
		_mp_resume()
	elif running:
		_mp_pause()

func _mp_exit_to_games() -> void:
	PlutoComm.set_control_type("NONE")
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")

func _mp_decrease_speed() -> void:
	_mp_game_speed = maxf(MP_MIN_SPEED, _mp_game_speed - 1.0)
	_mp_recalc_from_speed()

func _mp_increase_speed() -> void:
	_mp_game_speed = minf(MP_MAX_SPEED, _mp_game_speed + 1.0)
	_mp_recalc_from_speed()

func _mp_tick(delta: float) -> void:
	if paused: return
	match _mp_state:
		MPState.WAITING:
			pass
		MPState.START:
			_mp_begin_game()
			_mp_state = MPState.SPAWN_TARGET
		MPState.SPAWN_TARGET:
			if _mp_time_left <= 0.0:
				_mp_state = MPState.STOP
				return
			_mp_move_elapsed = 0.0
			_mp_event_delay = 0.05
			var lane_count := race.lane_max - race.lane_min + 1
			_mp_target_lane = race.lane_min + (randi() % lane_count)
			# Place lantern 20m ahead of the player in the target lane
			_mp_spawn_distance = race.racers[0].distance + maxf(24.0, race.BASE_SPEED * _mp_move_duration)
			race.pickups[0].distance = _mp_spawn_distance
			race.pickups[0].x       = race.lane_x(_mp_target_lane)
			race.pickups[0].lane    = _mp_target_lane
			race.pickups[0].owner   = -1
			race.pickups[0].kind = LANTERN_SEQUENCE[lantern_variant % LANTERN_SEQUENCE.size()]
			_set_lantern_variant(lantern_variant)
			lantern_variant += 1
			_reset_targets()

			if _mp_use_aan and _mp_aan != null:
				var _aprom_now: Array = _mp_aprom
				if AppData.selected_mechanism == null or AppData.selected_mechanism.current_aprom.size() < 2:
					_aprom_now = [AppData.mech_offset - AppData.calib_angle * 0.5,
								  AppData.mech_offset + AppData.calib_angle * 0.5]
				var fraction := inverse_lerp(float(race.lane_min), float(race.lane_max), float(_mp_target_lane))
				var target_angle := clampf(lerpf(float(_aprom_now[0]), float(_aprom_now[1]), fraction), float(_mp_prom[0]), float(_mp_prom[1]))
				PlutoComm.reset_aan_target()
				PlutoComm.set_control_type("POSITIONAAN")
				PlutoComm.set_control_bound(AppData.assist_bound)
				PlutoComm.set_control_dir(0)
				_mp_aan.reset_trial()
				_mp_aan.set_new_trial_details(PlutoComm.angle, target_angle, _mp_move_duration, _mp_game_speed)
			_mp_state = MPState.MOVE
		MPState.MOVE:
			_mp_move_elapsed += delta
			_mp_time_left = maxf(0.0, _mp_time_left - delta)
			AppData.record_active_time(delta)
			if _mp_use_aan and _mp_aan != null:
				_mp_aan.update(PlutoComm.angle, delta, false)
				if _mp_aan.state_change:
					if _mp_aan.state == AAN.State.AROM_MOVING: PlutoComm.reset_aan_target()
					else:
						var target = _mp_aan.get_new_aan_target()
						if target != null: PlutoComm.set_aan_target(target[0], target[1], target[2], target[3])
			# Resolve exactly once at the speed-dependent arrival time.
			if _mp_move_elapsed >= _mp_move_duration and race.pickups[0].owner < 0:
				var caught: bool = absf(race.racers[0].x - race.pickups[0].x) <= race._pickup_reach()
				race.pickups[0].owner = 0 if caught else 3
				if caught: race._award_pickup(0, race.pickups[0])
				_mp_on_outcome(caught)
				_mp_state = MPState.SUCCESS if caught else MPState.FAILURE
				_mp_event_delay = 0.4
				return
			# Success: lantern collected (owner set by race.advance)
			if not race.pickups.is_empty() and race.pickups[0].owner >= 0:
				_mp_on_outcome(true)
				_mp_hide_lane_indicator()
				_mp_state = MPState.SUCCESS
				_mp_event_delay = 0.4
			# Miss: player has driven past the lantern without collecting it
			elif not race.pickups.is_empty() and race.racers[0].distance > race.pickups[0].distance + 3.0:
				_mp_on_outcome(false)
				_mp_hide_lane_indicator()
				_mp_state = MPState.FAILURE
				_mp_event_delay = 0.4
			# Fallback: time up
			elif _mp_time_left <= 0.0:
				_mp_on_outcome(false)
				_mp_hide_lane_indicator()
				_mp_state = MPState.STOP
		MPState.SUCCESS, MPState.FAILURE:
			_mp_event_delay = maxf(0.0, _mp_event_delay - delta)
			if _mp_event_delay <= 0.0:
				if _mp_time_left > 0.0:
					_mp_state = MPState.SPAWN_TARGET
				else:
					_mp_state = MPState.STOP
		MPState.STOP:
			_mp_state = MPState.DONE
			_mp_end_game()
		MPState.DONE:
			pass

func _process_mp(delta: float) -> void:
	var device_target_x := INF
	var device_target_lane := -1
	var direction := 0.0
	if PlutoComm.is_connected and PlutoComm.is_streaming:
		# Same fallback as non-preview _process(): use calibration data when mechanism not selected
		var aprom: Array = _mp_aprom
		if AppData.selected_mechanism == null or AppData.selected_mechanism.current_aprom.size() < 2:
			aprom = [AppData.mech_offset - AppData.calib_angle * 0.5,
					 AppData.mech_offset + AppData.calib_angle * 0.5]
		var range_size: float = float(aprom[1]) - float(aprom[0])
		var t := clampf((PlutoComm.angle - aprom[0]) / (range_size if range_size != 0.0 else 1.0), 0.0, 1.0)
		direction = t * 2.0 - 1.0
		device_target_x    = lerpf(race.lane_x(race.lane_min), race.lane_x(race.lane_max), t)
		device_target_lane = race.lane_min + roundi(t * float(race.lane_max - race.lane_min))
	else:
		var l := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		var r := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		direction = float(r) - float(l)
	var allow_move := running and not paused and _mp_state in [MPState.SPAWN_TARGET, MPState.MOVE, MPState.SUCCESS, MPState.FAILURE]
	if allow_move:
		if device_target_x != INF:
			race.racers[0].x = device_target_x
			race.racers[0].lane = device_target_lane
			race.racers[0].lateral_speed = 0.0
		step(delta, 0.0 if device_target_x != INF else direction)
	elif running and not paused:
		race_audio.advance(delta)
	_mp_tick(delta)
	_mp_refresh_hud()
	_mp_log_state()
	if _mp_lane_indicator and _mp_lane_indicator.visible:
		_mp_lane_indicator.position.z = -(20.0 + COLLECTION_FRONT)
		_mp_lane_indicator.position.x = race.lane_x(_mp_target_lane)
		_mp_animate_indicator(delta)

func _mp_refresh_hud() -> void:
	if _mp_header_timer and mini_hud and mini_hud.visible:
		_mp_header_timer.text = "Time: %02d s" % maxi(0, ceili(_mp_time_left))
	if _mp_header_score and mini_hud and mini_hud.visible:
		_mp_header_score.text = "Score: %d / %d" % [_mp_n_success, _mp_n_targets]

func _mp_log_state() -> void:
	AppData.log_player_x   = race.racers[0].x
	AppData.log_player_y   = race.racers[0].distance
	AppData.log_target_x   = race.lane_x(_mp_target_lane) if _mp_state in [MPState.SPAWN_TARGET, MPState.MOVE] else 0.0
	AppData.log_target_y   = 0.0
	AppData.log_game_state = MPState.keys()[_mp_state]
	if _mp_aan != null:
		AppData.log_aan_target = _mp_aan.target_position
		AppData.log_aan_init   = _mp_aan.initial_position
		AppData.log_aan_state  = AAN.State.keys()[_mp_aan.state]

func _mp_build_lane_indicator() -> void:
	_mp_lane_indicator = Node3D.new()
	add_child(_mp_lane_indicator)
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color("ffd700")
	arch_mat.emission_enabled = true
	arch_mat.emission = Color("ffe040")
	arch_mat.emission_energy_multiplier = 1.5
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.25, 4.0, 0.25)
	for px in [-1.5, 1.5]:
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.material_override = arch_mat
		pillar.position = Vector3(px, 2.0, 0.0)
		_mp_lane_indicator.add_child(pillar)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(3.25, 0.25, 0.25)
	var bar := MeshInstance3D.new()
	bar.mesh = bar_mesh
	bar.material_override = arch_mat
	bar.position = Vector3(0.0, 4.0, 0.0)
	_mp_lane_indicator.add_child(bar)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(1.0, 0.9, 0.2, 0.5)
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(4.5, 5.0)
	var glow := MeshInstance3D.new()
	glow.name = "GlowQuad"
	glow.mesh = glow_mesh
	glow.material_override = glow_mat
	glow.position = Vector3(0.0, 2.0, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mp_lane_indicator.add_child(glow)
	var countdown_lbl := Label3D.new()
	countdown_lbl.name = "CountdownLabel"
	countdown_lbl.text = ""
	countdown_lbl.font_size = 80
	countdown_lbl.pixel_size = 0.006
	countdown_lbl.position = Vector3(0.0, 5.2, 0.0)
	countdown_lbl.modulate = Color("ffe38a")
	countdown_lbl.outline_size = 10
	countdown_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mp_lane_indicator.add_child(countdown_lbl)
	_mp_lane_indicator.hide()

func _mp_show_lane_indicator(lane: int) -> void:
	if not _mp_lane_indicator: return
	_mp_lane_indicator.position = Vector3(race.lane_x(lane), 0.0, -(20.0 + COLLECTION_FRONT))
	_mp_indicator_elapsed = 0.0
	_mp_lane_indicator.show()

func _mp_hide_lane_indicator() -> void:
	if _mp_lane_indicator: _mp_lane_indicator.hide()

func _mp_animate_indicator(dt: float) -> void:
	_mp_indicator_elapsed += dt
	var glow := _mp_lane_indicator.get_node_or_null("GlowQuad") as MeshInstance3D
	if glow:
		var gmat := glow.material_override as StandardMaterial3D
		if gmat:
			var col := gmat.albedo_color
			col.a = 0.35 + sin(_mp_indicator_elapsed * 4.0) * 0.22
			gmat.albedo_color = col
	var countdown := _mp_lane_indicator.get_node_or_null("CountdownLabel") as Label3D
	if countdown:
		var remaining := maxf(0.0, _mp_move_duration - _mp_move_elapsed)
		countdown.text = "%.1f s" % remaining

func _set_lantern_variant(variant: int) -> void:
	if targets.is_empty(): return
	var sprite = targets[0].get_node_or_null("v_power")
	if sprite == null or not sprite.texture is AtlasTexture: return
	var atlas := sprite.texture as AtlasTexture
	var cell := Vector2(atlas.atlas.get_width(), atlas.atlas.get_height()) * 0.5
	atlas.region = Rect2(Vector2(variant % 2, (variant >> 1) % 2) * cell, cell)
