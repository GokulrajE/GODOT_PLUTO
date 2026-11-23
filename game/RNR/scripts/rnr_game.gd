extends Control

const GameInput = preload("res://scripts/gameplay/game_input.gd")
const ArcadeAssets = preload("res://scripts/ui/arcade_assets.gd")

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ──────────────────────────────────────────────────────────────────
const GAME_LEFT:     float = 20.0
const GAME_RIGHT:    float = 1146.0
const CLOUD_W:       float = 160.0
const CLOUD_H:       float = 90.0
const CLOUD_Y:       float = 105.0     # cloud top Y
const CLOUD_HALF:    float = 80.0      # half-width for movement clamping
const SEED_Y:        float = 620.0     # baseline Y (bottom of seed/plant sprite)
const SEED_COUNT:    int   = 5
const SEED_SIZE:     float = 44.0      # seed sprite size (smaller)
const SEED_HALF_W:   float = 36.0      # cloud-over-seed detection radius
const RAIN_EMIT_INTERVAL: float = 0.025
const RAIN_COL_W:    float = 100.0      # rain column total width

# Ten plants, four growth stages each (sprout, vegetative, budding, fully grown) cut from the sheet
# in game/RNR/sprites/. Stage 0 is always the seed. Each slot gets a different plant every game.
const PLANT_NAMES = ["watermelon", "strawberry", "sunflower", "tomato", "carrot", "blueberry", "pumpkin", "corn", "tulip", "flower"]
const PLANT_PATH := "res://game/RNR/sprites/plants/%s_%d.png"
const PLANT_SCALE := 0.383         # texture pixels (3x the sheet) -> screen pixels
const PLANT_MAX_W := 215.0         # widest a plant may get, so neighbours never overlap
const PLANT_BAR_GAP := 112.0       # progress bar sits this far to the right of the slot centre
const PLANT_SIZES_SEED := 44.0

# ── Speed ────────────────────────────────────────────────────────────────────
const MIN_SPEED:          float = 10.0
const MAX_SPEED:          float = 40.0
const TRIAL_DURATION:     float = 60.0
const MIN_MOVE_DURATION:  float = 0.5
const MAX_MOVE_DURATION:  float = 4.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WAITING, START, SPAWNTARGET, MOVE, SUCCESS, FAILURE, STOP, DONE, PAUSED }
var _state:      State = State.WAITING
var _prev_state: State = State.WAITING

# ── Flags ─────────────────────────────────────────────────────────────────────
var _game_started:  bool = false
var _seed_grown:    bool = false
var _seed_missed:   bool = false
var _game_finished: bool = false

# ── Score ─────────────────────────────────────────────────────────────────────
var _time_left: float = TRIAL_DURATION
var n_targets:  int   = 0
var n_success:  int   = 0
var n_failure:  int   = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _event_delay:           float = 0.0
var _run_once:              bool  = false
var _aprom:                 Array = []
var _prom:                  Array = []
var _arom:                  Array = []
var _move_duration:         float = 2.0
var _mech_min_duration: float = MIN_MOVE_DURATION
var _mech_max_duration: float = MAX_MOVE_DURATION
var _cloud_x:               float = 583.0
var _target_seed:           int   = -1
var _rain_timer:            float = 0.0
var _highlight_timer:       float = 0.0
var _rain_duration_to_grow: float = 0.3
var _is_raining:            bool  = false
var _pulse_t:               float = 0.0   # drives highlight pulse animation
var _rain_anim_t:           float = 0.0   # drives rain drop scroll animation

var _seed_textures:    Array = []   # per slot: [seed, sprout, vegetative, budding, grown]
var _slot_plants:      Array = []   # plant name per slot
var _slot_scale:       Array = []   # sheet-to-screen scale per slot
var _ambience:         Control = null
var _rain_fx:          Control = null
var _seed_nodes:       Array = []   # TextureRect per slot
var _ring_nodes:       Array = []   # glow-ring Panel per slot
var _bar_bg_nodes:     Array = []   # thin grey progress bg per slot
var _bar_fill_nodes:   Array = []   # coloured fill inside bar per slot
var _seed_stage:       Array = []
var _slot_positions:   Array = []

var _aan:        RefCounted = null
var _use_aan:    bool       = false
var _game_speed: float      = 10.0
var _is_cpm:     bool       = false
var _show_arom:  bool       = false
var _arom_guides: Control

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _cloud:          TextureRect       = $Cloud
@onready var _seed_container: Control           = $SeedContainer
@onready var _timer_lbl:      Label             = $UI/Header/TimerLabel
@onready var _score_lbl:      Label             = $UI/Header/ScoreLabel
@onready var _wait_panel:     Control           = $UI/WaitPanel
@onready var _pause_panel:    Control           = $UI/PausePanel
@onready var _over_panel:     Control           = $UI/GameOverPanel
@onready var _final_lbl:      Label             = $UI/GameOverPanel/ScoreLabel
@onready var _music:          AudioStreamPlayer = $Music
@onready var _success_sfx:    AudioStreamPlayer = $SuccessSound
@onready var _miss_sfx:       AudioStreamPlayer = $MissSound
@onready var _speed_panel:    Panel             = $UI/SpeedPanel
@onready var _speed_lbl:      Label             = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl: Label             = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:        Button            = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:        Button            = $UI/SpeedPanel/SpeedRow/IncreaseButton

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	preload("res://scripts/ui/game_chrome.gd").apply.call_deferred($UI)
	_build_slot_positions()
	_load_seed_textures()
	_init_rom_data()
	_arom_guides = Control.new()
	_arom_guides.name = "AromGuides"
	_arom_guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arom_guides.z_index = 5
	add_child(_arom_guides)
	_arom_guides.draw.connect(_draw_arom_guides)
	_calc_speed()
	_spawn_seeds()
	_build_cloud_character()
	_build_rain_fx()
	_set_cloud_x(583.0)
	_ambience = preload("res://game/RNR/scripts/rnr_ambience.gd").new()
	add_child(_ambience)
	_ambience.setup(self)
	_wait_panel.visible  = true
	_pause_panel.visible = false
	_over_panel.visible  = false
	_speed_panel.visible = false
	_refresh_speed_label()
	_dec_btn.pressed.connect(_decrease_speed)
	_inc_btn.pressed.connect(_increase_speed)
	$UI/Header/ExitButton.pressed.connect(_on_exit_pressed)
	$UI/GameOverPanel/ExitButton.pressed.connect(_on_exit_pressed)
	EventBus.button_released.connect(_on_pluto_button)
	_yesterday_hits = DataManager.read_yesterday_hits(AppData.selected_game_name, AppData.mechanism_name)
	_celeb_card.star_reached_header.connect(_on_star_reached_header)
	_update_star_display()

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)

# ── Build helpers ─────────────────────────────────────────────────────────────
func _build_slot_positions() -> void:
	var margin := 90.0
	var step   := (GAME_RIGHT - margin - (GAME_LEFT + margin)) / float(SEED_COUNT - 1)
	for i in SEED_COUNT:
		_slot_positions.append(GAME_LEFT + margin + step * float(i))

func _load_seed_textures() -> void:
	_seed_textures.clear()
	_slot_plants.clear()
	_slot_scale.clear()
	var names: Array = PLANT_NAMES.duplicate()
	names.shuffle()
	for slot in SEED_COUNT:
		var plant_name: String = names[slot % names.size()]
		_slot_plants.append(plant_name)
		var stages: Array = [ArcadeAssets.plant(0)]
		var widest := 1.0
		for stage in range(1, 5):
			var texture := load(PLANT_PATH % [plant_name, stage]) as Texture2D
			stages.append(texture)
			if texture: widest = maxf(widest, float(texture.get_width()))
		_seed_textures.append(stages)
		_slot_scale.append(minf(PLANT_SCALE, PLANT_MAX_W / widest))

## Height (screen px) of a slot's plant at a growth stage; the seed keeps the fixed seed size.
func _stage_height(slot: int, stage: int) -> float:
	if stage <= 0: return PLANT_SIZES_SEED
	var texture := _seed_textures[slot][stage] as Texture2D
	if texture == null: return PLANT_SIZES_SEED
	return float(texture.get_height()) * float(_slot_scale[slot])

func _spawn_seeds() -> void:
	for child in _seed_container.get_children():
		if child.has_meta("authored_seed"):
			_seed_container.remove_child(child)
			child.queue_free()
	_seed_nodes.clear()
	_ring_nodes.clear()
	_bar_bg_nodes.clear()
	_bar_fill_nodes.clear()
	_seed_stage.clear()

	for i in SEED_COUNT:
		var cx: float = _slot_positions[i]

		# ── Glow ring (highlight) ────────────────────────────────────────────
		# Outer soft aura (large, very transparent)
		var aura_style := StyleBoxFlat.new()
		aura_style.bg_color           = Color(0.1, 1.0, 0.5, 0.0)
		aura_style.corner_radius_top_left    = 60
		aura_style.corner_radius_top_right   = 60
		aura_style.corner_radius_bottom_right = 60
		aura_style.corner_radius_bottom_left  = 60
		var aura_size := SEED_SIZE + 64.0
		var aura := Panel.new()
		aura.add_theme_stylebox_override("panel", aura_style)
		aura.size     = Vector2(aura_size, aura_size)
		aura.position = Vector2(cx - aura_size * 0.5, SEED_Y - SEED_SIZE * 0.5 - aura_size * 0.5)
		aura.visible  = false
		_seed_container.add_child(aura)

		# Inner crisp glowing ring
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color               = Color(0.05, 0.9, 0.4, 0.0)
		ring_style.border_width_left      = 5
		ring_style.border_width_top       = 5
		ring_style.border_width_right     = 5
		ring_style.border_width_bottom    = 5
		ring_style.border_color           = Color(0.1, 1.0, 0.5, 0.0)
		ring_style.corner_radius_top_left    = 44
		ring_style.corner_radius_top_right   = 44
		ring_style.corner_radius_bottom_right = 44
		ring_style.corner_radius_bottom_left  = 44
		var ring_size := SEED_SIZE + 36.0
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", ring_style)
		ring.size     = Vector2(ring_size, ring_size)
		ring.position = Vector2(cx - ring_size * 0.5, SEED_Y - SEED_SIZE * 0.5 - ring_size * 0.5)
		ring.visible  = false
		_seed_container.add_child(ring)
		# Store aura as ring_nodes[i] metadata via a wrapper: pack both into ring's metadata
		ring.set_meta("aura", aura)
		_ring_nodes.append(ring)

		# ── Rain progress bar (right side of seed, 8px wide) ─────────────────
		const BAR_H    := 80.0
		const BAR_W    := 8.0
		var bar_x := cx + PLANT_BAR_GAP
		var bar_y := SEED_Y - SEED_SIZE - BAR_H

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color           = Color(0.7, 0.85, 0.7, 0.35)
		bg_style.corner_radius_top_left    = 4
		bg_style.corner_radius_top_right   = 4
		bg_style.corner_radius_bottom_right = 4
		bg_style.corner_radius_bottom_left  = 4
		var bar_bg := Panel.new()
		bar_bg.add_theme_stylebox_override("panel", bg_style)
		bar_bg.size     = Vector2(BAR_W, BAR_H)
		bar_bg.position = Vector2(bar_x, bar_y)
		bar_bg.visible  = false
		_seed_container.add_child(bar_bg)
		_bar_bg_nodes.append(bar_bg)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color           = Color(0.25, 0.65, 1.0, 0.95)
		fill_style.corner_radius_top_left    = 4
		fill_style.corner_radius_top_right   = 4
		fill_style.corner_radius_bottom_right = 4
		fill_style.corner_radius_bottom_left  = 4
		var bar_fill := Panel.new()
		bar_fill.add_theme_stylebox_override("panel", fill_style)
		bar_fill.size     = Vector2(BAR_W, 0.0)
		bar_fill.position = Vector2(bar_x, bar_y + BAR_H)
		bar_fill.visible  = false
		_seed_container.add_child(bar_fill)
		_bar_fill_nodes.append(bar_fill)

		# ── Seed / plant sprite (added before ring so ring draws on top) ────
		var seed_node := TextureRect.new()
		seed_node.material = preload("res://Assets/Arcade/sprite-contrast.tres")
		seed_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seed_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # smooth when scaled
		seed_node.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		seed_node.size         = Vector2(SEED_SIZE, SEED_SIZE)
		seed_node.scale        = Vector2(1.0, 1.0)
		seed_node.position     = Vector2(cx - SEED_SIZE * 0.5, SEED_Y - SEED_SIZE)
		if _seed_textures.size() > i and _seed_textures[i][0] != null:
			seed_node.texture = _seed_textures[i][0]
			seed_node.size.x = SEED_SIZE * seed_node.texture.get_width() / seed_node.texture.get_height()
			seed_node.position.x = cx - seed_node.size.x * 0.5
		_seed_container.add_child(seed_node)
		_seed_nodes.append(seed_node)
		_seed_stage.append(0)

		# ── Ring must render in front of the seed, so move it to last ──────
		_seed_container.move_child(ring, _seed_container.get_child_count() - 1)

# The cloud is drawn as an animated character with facial reactions (cloud_character.gd); the node
# below it keeps the position the game moves.
func _build_cloud_character() -> void:
	_cloud.self_modulate = Color(1, 1, 1, 0)
	var character: Control = preload("res://game/RNR/scripts/cloud_character.gd").new()
	character.game = self
	character.texture = ArcadeAssets.sprite("cloud")
	_cloud.add_child(character)

# Natural rain (rain_fx.gd): gravity, breeze, cloud-driven lean, splashes on plants and soil.
func _build_rain_fx() -> void:
	_rain_fx = preload("res://game/RNR/scripts/rain_fx.gd").new()
	_rain_fx.game = self
	add_child(_rain_fx)
	move_child(_rain_fx, _seed_container.get_index() + 1)

# ── Init ───────────────────────────────────────────────────────────────────────
func _init_rom_data() -> void:
	if AppData.selected_mechanism == null:
		_aprom = [-45.0, 45.0]; _arom = [-30.0, 30.0]; _prom = [-45.0, 45.0]
		_is_cpm = false
		return
	_aprom  = AppData.selected_mechanism.current_aprom
	_arom   = AppData.selected_mechanism.current_arom
	_prom   = AppData.selected_mechanism.current_prom
	_is_cpm = AppData.selected_mechanism.is_cpm
	if _aprom.size() < 2: _aprom = [-45.0, 45.0]
	if _arom.size()  < 2: _arom  = [-30.0, 30.0]
	if _prom.size()  < 2: _prom  = [-45.0, 45.0]
	set_min_max_duration_of_mech()

func _calc_speed() -> void:
	_game_speed = MIN_SPEED
	if AppData.speed_data != null:
		_game_speed = clamp(AppData.speed_data.game_speed, MIN_SPEED, MAX_SPEED)
	_recalc_from_game_speed()

func set_min_max_duration_of_mech() -> void:
	if AppData.selected_mechanism == null:
		return
	var mech: String = AppData.selected_mechanism.name
	var range_size: float = abs(_aprom[1] - _aprom[0])
	var calc_min: float = range_size / HomerTherapy.MAX_SPEED
	var calc_max: float = range_size / HomerTherapy.MIN_SPEED
	var threshold_min: float
	var threshold_max: float
	match mech:
		"WFE", "WURD":
			threshold_min = HomerTherapy.min_duration_of_mech_wfe_and_wurd
			threshold_max = HomerTherapy.max_duration_of_mech_wfe_and_wurd
		"HOC":
			threshold_min = HomerTherapy.min_duration_of_mech_hoc
			threshold_max = HomerTherapy.max_duration_of_mech_hoc
		_:
			threshold_min = HomerTherapy.min_duration_of_mech_fps_and_fme
			threshold_max = HomerTherapy.max_duration_of_mech_fps_and_fme
	_mech_min_duration = maxf(calc_min, threshold_min)
	_mech_max_duration = minf(calc_max, threshold_max)
	print("mech min duration: ", _mech_min_duration, ", max: ", _mech_max_duration)

func get_target_end_time(game_speed: float) -> float:
	var t: float = (game_speed - HomerTherapy.MIN_SPEED) / (HomerTherapy.MAX_SPEED - HomerTherapy.MIN_SPEED)
	t = clampf(t, 0.0, 1.0)
	return lerpf(_mech_max_duration, _mech_min_duration, t)

func _recalc_from_game_speed() -> void:
	var t: float = clamp((_game_speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	_move_duration         = get_target_end_time(_game_speed)
	_rain_duration_to_grow = lerp(0.5, 0.15, t)

func _increase_speed() -> void:
	if _game_speed >= MAX_SPEED: return
	_game_speed += 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _decrease_speed() -> void:
	if _game_speed <= MIN_SPEED: return
	_game_speed -= 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _refresh_speed_label() -> void:
	_speed_lbl.text      = "%d" % int(_game_speed)
	_speed_info_lbl.text = "Duration: %.1f s\nBound: %.2f" % [_move_duration, AppData.assist_bound]

func _save_speed() -> void:
	if AppData.speed_data != null:
		AppData.speed_data.set_game_speed(_game_speed)
		AppData.speed_data.set_move_duration(_move_duration)

func angle_to_screen(angle: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]: return 583.0
	var t := (angle - float(_aprom[0])) / (float(_aprom[1]) - float(_aprom[0]))
	return lerp(GAME_LEFT, GAME_RIGHT, clamp(t, 0.0, 1.0))

func _screen_to_angle(sx: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]: return 0.0
	var t := (sx - GAME_LEFT) / (GAME_RIGHT - GAME_LEFT)
	return lerp(float(_aprom[0]), float(_aprom[1]), clamp(t, 0.0, 1.0))

func _set_cloud_x(x: float) -> void:
	_cloud_x = x
	_cloud.position.x = x - CLOUD_W * 0.5

# ── Main loop ─────────────────────────────────────────────────────────────────
func _draw_arom_guides() -> void:
	if not _show_arom or _arom.size() < 2 or _is_cpm: return
	var x_left:  float = angle_to_screen(float(_arom[0]))
	var x_right: float = angle_to_screen(float(_arom[1]))
	for x in [x_left, x_right]:
		_arom_guides.draw_line(Vector2(x, 82), Vector2(x, 620), Color("193d59"), 6.0)
		_arom_guides.draw_line(Vector2(x, 82), Vector2(x, 620), Color("a6f5ff"), 3.0)

func _process(delta: float) -> void:
	if _state == State.PAUSED: return
	_move_cloud(delta)
	_tick(delta)
	_animate_visuals(delta)
	_arom_guides.queue_redraw()
	_refresh_ui()
	_update_log_state()

func _move_cloud(delta: float) -> void:
	var sx := GameInput.horizontal(_cloud_x, angle_to_screen(PlutoComm.angle), delta)
	_set_cloud_x(clamp(sx, GAME_LEFT + CLOUD_HALF, GAME_RIGHT - CLOUD_HALF))

# ── Animate highlight + rain drops each frame ─────────────────────────────────
func _animate_visuals(delta: float) -> void:
	for i in _seed_nodes.size():
		var plant: TextureRect = _seed_nodes[i]
		var target: float = plant.get_meta("growth_target", 1.0)
		var factor: float = target if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)) else lerpf(plant.scale.x, target, 1.0 - exp(-10.0 * delta))
		plant.scale = Vector2.ONE * factor
		plant.position = Vector2(float(_slot_positions[i]) - plant.size.x * factor * 0.5, SEED_Y - plant.size.y * factor)
	_pulse_t    += delta
	_rain_anim_t += delta

	var active = _state == State.MOVE or _state == State.SPAWNTARGET
	for i in SEED_COUNT:
		var is_target := (i == _target_seed and active)
		var ring      := _ring_nodes[i] as Panel
		var aura      := ring.get_meta("aura") as Panel

		if is_target:
			ring.visible = true
			aura.visible = true
			# Inner ring: crisp bright pulse  0.7 → 1.0
			var alpha:     float = sin(_pulse_t * 5.0) * 0.15 + 0.85
			var ring_sbox := ring.get_theme_stylebox("panel") as StyleBoxFlat
			ring_sbox.bg_color     = Color(0.05, 0.9, 0.4, alpha * 0.18)
			ring_sbox.border_color = Color(0.1, 1.0, 0.55, alpha)
			# Outer aura: slow breathe 0.08 → 0.22
			var aura_alpha: float  = sin(_pulse_t * 2.8) * 0.07 + 0.15
			var aura_sbox := aura.get_theme_stylebox("panel") as StyleBoxFlat
			aura_sbox.bg_color = Color(0.1, 1.0, 0.5, aura_alpha)
			# Tint seed golden-yellow so it stands out
			_seed_nodes[i].modulate = Color(1.0, 1.0, 0.55, 1.0)
		else:
			ring.visible = false
			aura.visible = false
			if i < _seed_nodes.size():
				_seed_nodes[i].modulate = Color(1, 1, 1, 1)

	var slot_cx: float = float(_slot_positions[_target_seed]) if _target_seed >= 0 and _target_seed < _slot_positions.size() else 583.0

	# Progress bar (show when target active)
	const BAR_H: float = 80.0
	const BAR_W: float = 8.0
	var bar_cx: float = slot_cx + PLANT_BAR_GAP
	var bar_y:  float = SEED_Y - SEED_SIZE - BAR_H
	for i in SEED_COUNT:
		_bar_bg_nodes[i].visible   = (i == _target_seed and active)
		_bar_fill_nodes[i].visible = (i == _target_seed and active and _is_raining)
		if i == _target_seed and active:
			var pct:    float = clamp(_rain_timer / _rain_duration_to_grow, 0.0, 1.0)
			var fill_h: float = pct * BAR_H
			_bar_fill_nodes[i].size     = Vector2(BAR_W, fill_h)
			_bar_fill_nodes[i].position = Vector2(bar_cx, bar_y + BAR_H - fill_h)
			var fill_sbox := _bar_fill_nodes[i].get_theme_stylebox("panel") as StyleBoxFlat
			fill_sbox.bg_color = Color(0.25 + pct * 0.1, 0.65 + pct * 0.3, 1.0, 0.95)

# ── State machine ─────────────────────────────────────────────────────────────
func _tick(delta: float) -> void:
	var playing := (_state != State.WAITING and _state != State.PAUSED
					and _state != State.STOP and _state != State.DONE)
	if playing and _time_left > 0.0:
		AppData.record_active_time(minf(delta, _time_left))
		_time_left -= delta

	match _state:
		State.WAITING:
			if _game_started: _state = State.START

		State.START:
			_begin_game()
			_state = State.SPAWNTARGET

		State.SPAWNTARGET:
			if not _run_once:
				_target_seed      = _pick_target_seed()
				_rain_timer       = 0.0
				_highlight_timer  = 0.0
				_seed_grown       = false
				_seed_missed      = false
				_pulse_t          = 0.0
				_rain_anim_t      = 0.0
				n_targets        += 1
				var tgt_angle     := _screen_to_angle(_slot_positions[_target_seed])
				if _use_aan and _aan != null:
					_aan.reset_trial()
					_aan.set_new_trial_details(PlutoComm.angle, tgt_angle, _move_duration, _game_speed)
				_event_delay = 0.05
				_run_once    = true
			else:
				_event_delay -= delta
				if _event_delay <= 0.0:
					_state = State.MOVE

		State.MOVE:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, false)
				if _aan.state_change: _update_pluto_aan_target()
			_update_rain(delta)
			_highlight_timer += delta
			if _seed_grown:
				_state = State.SUCCESS
			elif _highlight_timer >= _move_duration and not _seed_grown:
				_seed_missed = true
				n_failure += 1
				_miss_sfx.play()
				_state = State.FAILURE

		State.SUCCESS, State.FAILURE:
			if _event_delay <= 0.0:
				_event_delay = 0.6
			else:
				_event_delay -= delta
				if _event_delay <= 0.0:
					_is_raining = false
					_hide_all_highlights()
					var time_up := _time_left <= 0.0
					_state      = State.STOP if time_up else State.SPAWNTARGET
					_run_once   = false

		State.STOP:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, true)
				if _aan.state_change: _update_pluto_aan_target()
				var aan_done: bool = (_aan.state == _PlutoAAN.State.AROM_MOVING \
					or _aan.state == _PlutoAAN.State.IDLE \
					or _aan.state == _PlutoAAN.State.NONE)
				if aan_done:
					_end_game()
					_state = State.DONE
					return
				# CPM mode: patient may never return to AROM — timed fallback
				if _event_delay <= 0.0:
					var t: float = clamp((_game_speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
					_event_delay = lerp(12.0, 5.0, t)
				else:
					_event_delay -= delta
					if _event_delay <= 0.0:
						_end_game()
						_state = State.DONE
			else:
				_end_game()
				_state = State.DONE

		State.DONE, State.PAUSED:
			pass

func _update_rain(delta: float) -> void:
	if _target_seed < 0 or _target_seed >= SEED_COUNT:
		return
	var seed_cx: float = float(_slot_positions[_target_seed])
	_is_raining = abs(_cloud_x - seed_cx) < SEED_HALF_W
	if _is_raining:
		_rain_timer += delta
		if _rain_timer >= _rain_duration_to_grow:
			_grow_seed(_target_seed)
	else:
		_rain_timer = max(0.0, _rain_timer - delta * 0.6)

func _grow_seed(idx: int) -> void:
	if _seed_grown: return
	_seed_grown = true
	var max_stage: int = (_seed_textures[idx] as Array).size() - 1
	var new_stage: int = _seed_stage[idx] + 1
	if new_stage > max_stage:
		new_stage = 2   # after the fully grown plant the slot loops back to the budding stage
	_seed_stage[idx] = new_stage
	n_success        += 1
	_success_sfx.play()
	_show_growth_when_rain_lands(idx, new_stage)

## The score and sound happen the moment the target is watered, but the plant itself only visibly
## grows once the rain from the cloud has actually reached it (with a safety timeout).
func _show_growth_when_rain_lands(idx: int, new_stage: int) -> void:
	if _rain_fx != null:
		var asked: float = _rain_fx.clock()
		var deadline := Time.get_ticks_msec() + 1200
		while not _rain_fx.rain_reached(idx, asked) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if not is_inside_tree(): return
	_apply_plant_growth(idx, new_stage)

func _apply_plant_growth(idx: int, new_stage: int) -> void:
	if idx >= _seed_nodes.size() or not is_instance_valid(_seed_nodes[idx]): return
	var sz:     float = _stage_height(idx, new_stage)
	var cx:     float = float(_slot_positions[idx])
	var node          := _seed_nodes[idx] as TextureRect
	node.texture      = _seed_textures[idx][new_stage]
	# Scale uniformly from base SEED_SIZE so the texture's natural aspect ratio is kept
	var factor: float = sz / SEED_SIZE
	node.size = Vector2(SEED_SIZE * node.texture.get_width() / node.texture.get_height(), SEED_SIZE)
	node.set_meta("growth_target", factor)
	# Reanchor to bottom-center (scale expands from top-left corner)
	node.position = Vector2(cx - node.size.x * node.scale.x * 0.5, SEED_Y - node.size.y * node.scale.y)

func _pick_target_seed() -> int:
	# Build candidate list excluding the slot that was just targeted
	var candidates: Array = []
	for i in SEED_COUNT:
		if i != _target_seed:
			candidates.append(i)
	if candidates.is_empty():
		candidates = range(SEED_COUNT)

	if _prom.size() >= 2:
		var angle: float = randf_range(float(_prom[0]), float(_prom[1]))
		var sx:    float = angle_to_screen(angle)
		var best:  int   = candidates[0]
		var best_d: float = abs(sx - float(_slot_positions[best]))
		for i in candidates.slice(1):
			var d: float = abs(sx - float(_slot_positions[i]))
			if d < best_d: best_d = d; best = i
		return best
	return candidates[randi() % candidates.size()]

func _hide_all_highlights() -> void:
	for i in SEED_COUNT:
		_ring_nodes[i].visible    = false
		var _aura := (_ring_nodes[i] as Panel).get_meta("aura") as Panel
		_aura.visible = false
		_bar_bg_nodes[i].visible  = false
		_bar_fill_nodes[i].visible = false
		_seed_nodes[i].modulate   = Color(1, 1, 1, 1)

# ── AAN ───────────────────────────────────────────────────────────────────────
func _update_pluto_aan_target() -> void:
	if _aan == null: return
	match _aan.state:
		_PlutoAAN.State.AROM_MOVING:
			PlutoComm.reset_aan_target()
		_PlutoAAN.State.RELAX_TO_AROM, \
		_PlutoAAN.State.ASSIST_TO_TARGET_AT_BOUNDARY, \
		_PlutoAAN.State.ASSIST_TO_TARGET_IN_BOUNDARY:
			var t = _aan.get_new_aan_target()
			if t != null: PlutoComm.set_aan_target(t[0], t[1], t[2], t[3])

# ── Game lifecycle ────────────────────────────────────────────────────────────
func _begin_game() -> void:
	_time_left = TRIAL_DURATION
	_music.play()
	n_targets  = 0; n_success = 0; n_failure = 0
	_wait_panel.visible = false
	AppData.start_new_trial()
	_setup_aan()

func _setup_aan() -> void:
	var mech  = AppData.mechanism_name
	_use_aan = not AppData.demo_mode and PlutoComm.is_connected and mech != "FME1" and mech != "FME2" and mech != "NOMECH"
	_aan     = _PlutoAAN.new()
	if _arom.size() >= 2: _aan.arom = _arom.duplicate()
	if _prom.size() >= 2: _aan.prom = _prom.duplicate()
	if _use_aan:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)

func _end_game() -> void:
	_game_finished = true
	PlutoComm.set_control_type("NONE")
	_is_raining    = false
	_hide_all_highlights()
	_music.stop()
	_save_speed()
	var today_prior := DataManager.read_today_hits(AppData.selected_game_name, AppData.mechanism_name)
	var today_total := today_prior + n_success
	_earned_star = AppData.selected_game != null and today_total > _yesterday_hits \
		and today_total > 0 and AppData.selected_game.today_stars == 0
	if _earned_star:
		AppData.selected_game.update_cumulative_stars()
	AppData.stop_trial(n_targets, n_success, n_failure)
	_final_lbl.text      = "%d / %d\nPress PLUTO button to play again" % [n_success, n_targets]
	_over_panel.visible  = true
	_speed_panel.visible = false
	if _earned_star:
		await get_tree().create_timer(0.6).timeout
		_show_celebration(today_total)

func _refresh_ui() -> void:
	_timer_lbl.text = "Time: %02d s" % maxi(0, ceili(_time_left))
	_score_lbl.text = "Score: %02d"  % n_success

# ── Logging ───────────────────────────────────────────────────────────────────
func _update_log_state() -> void:
	AppData.log_player_x   = _cloud_x
	AppData.log_player_y   = CLOUD_Y + CLOUD_H * 0.5
	AppData.log_target_x   = _slot_positions[_target_seed] if _target_seed >= 0 and _target_seed < _slot_positions.size() else 0.0
	AppData.log_target_y   = SEED_Y
	AppData.log_game_state = State.keys()[_state]
	if _aan != null:
		AppData.log_aan_target = _aan.target_position
		AppData.log_aan_init   = _aan.initial_position
		AppData.log_aan_state  = _PlutoAAN.State.keys()[_aan.state]
	else:
		AppData.log_aan_target = 0.0
		AppData.log_aan_init   = 0.0
		AppData.log_aan_state  = ""

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE: _on_pluto_button()
	elif event.ctrl_pressed and event.keycode == KEY_G:
		_speed_panel.visible = !_speed_panel.visible
		_show_arom = _speed_panel.visible
		_arom_guides.queue_redraw()
		_refresh_speed_label()

func _on_pluto_button() -> void:
	match _state:
		State.WAITING: _game_started = true
		State.DONE:    get_tree().reload_current_scene()
		State.STOP:    pass
		_:             _toggle_pause()

func _toggle_pause() -> void:
	if _state != State.PAUSED:
		# Same behaviour in every game: free the device and silence the music while paused.
		PlutoComm.set_control_type("NONE")
		PlutoComm.reset_aan_target()
		_prev_state = _state; _state = State.PAUSED; _pause_panel.visible = true
		_music.stream_paused = true
	else:
		if _use_aan and (not PlutoComm.is_connected or not PlutoComm.is_streaming): return
		_state = _prev_state; _pause_panel.visible = false
		_music.stream_paused = false
		if _use_aan and PlutoComm.is_connected:
			PlutoComm.set_control_type("POSITIONAAN")
			PlutoComm.set_control_bound(AppData.assist_bound)
			PlutoComm.set_control_dir(0)
			if _aan != null and _target_seed >= 0 and _target_seed < _slot_positions.size():
				_aan.reset_trial()
				_aan.set_new_trial_details(PlutoComm.angle, _screen_to_angle(_slot_positions[_target_seed]), _move_duration, _game_speed)
	_update_log_state()

func _on_exit_pressed() -> void:
	PlutoComm.set_control_type("NONE")
	if not _game_finished:
		_is_raining = false
		_hide_all_highlights()
		_music.stop()
		_save_speed()
		AppData.stop_trial(n_targets, n_success, n_failure)
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")

# ── Celebration & star UI ─────────────────────────────────────────────────────

var _yesterday_hits: int  = 0
var _earned_star:    bool = false

@onready var _star_img_hdr:   TextureRect = $UI/Header/StarDisplay/StarImg
@onready var _star_count_lbl: Label       = $UI/Header/StarDisplay/StarCountLabel
@onready var _celeb_card:     Control     = $UI/CelebrationCard

func _update_star_display() -> void:
	if _star_count_lbl == null:
		return
	var stars: int = AppData.selected_game.cumulative_stars if AppData.selected_game != null else 0
	_star_count_lbl.text = str(stars)

func _show_celebration(today_total: int) -> void:
	var header_star_rect := _star_img_hdr.get_global_rect()
	_celeb_card.show_celebration(_yesterday_hits, today_total, header_star_rect)

func _on_star_reached_header() -> void:
	_update_star_display()
	for _i in 2:
		var t := create_tween()
		t.tween_property(_star_img_hdr, "modulate", Color(1.6, 1.5, 0.5, 1), 0.12)
		t.tween_property(_star_img_hdr, "modulate", Color(1.0, 1.0, 1.0, 1), 0.12)
		await t.finished
