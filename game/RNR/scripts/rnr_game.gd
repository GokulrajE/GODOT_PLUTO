extends Control

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ──────────────────────────────────────────────────────────────────
const GAME_LEFT:     float = 20.0
const GAME_RIGHT:    float = 1146.0
const CLOUD_W:       float = 160.0
const CLOUD_H:       float = 90.0
const CLOUD_Y:       float = 105.0     # cloud top Y
const CLOUD_HALF:    float = 80.0      # half-width for movement clamping
const SEED_Y:        float = 535.0     # baseline Y (bottom of seed/plant sprite)
const SEED_COUNT:    int   = 5
const SEED_SIZE:     float = 44.0      # seed sprite size (smaller)
const SEED_HALF_W:   float = 36.0      # cloud-over-seed detection radius
const RAIN_DROP_COUNT: int = 30
const RAIN_DROP_W:   float = 4.0       # width of each raindrop streak
const RAIN_DROP_H:   float = 10.0      # height of each raindrop streak
const RAIN_COL_W:    float = 72.0      # rain column total width

# plant sizes per stage (0=seed … 4=final, bigger each stage)
const PLANT_SIZES = [44.0, 200.0, 200.0, 250.0, 300.0]

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
var _cloud_x:               float = 583.0
var _target_seed:           int   = -1
var _rain_timer:            float = 0.0
var _highlight_timer:       float = 0.0
var _rain_duration_to_grow: float = 0.3
var _is_raining:            bool  = false
var _pulse_t:               float = 0.0   # drives highlight pulse animation
var _rain_anim_t:           float = 0.0   # drives rain drop scroll animation

var _seed_textures:    Array = []
var _seed_nodes:       Array = []   # TextureRect per slot
var _ring_nodes:       Array = []   # glow-ring Panel per slot
var _bar_bg_nodes:     Array = []   # thin grey progress bg per slot
var _bar_fill_nodes:   Array = []   # coloured fill inside bar per slot
var _drop_nodes:       Array = []   # shared rain drops (Control array, moved per tick)
var _seed_stage:       Array = []
var _slot_positions:   Array = []

var _aan:        RefCounted = null
var _use_aan:    bool       = false
var _game_speed: float      = 10.0
var _is_cpm:     bool       = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _cloud:          TextureRect       = $Cloud
@onready var _seed_container: Control           = $SeedContainer
@onready var _timer_lbl:      Label             = $UI/Header/TimerLabel
@onready var _score_lbl:      Label             = $UI/Header/ScoreLabel
@onready var _wait_panel:     Control           = $UI/WaitPanel
@onready var _pause_panel:    Control           = $UI/PausePanel
@onready var _over_panel:     Control           = $UI/GameOverPanel
@onready var _final_lbl:      Label             = $UI/GameOverPanel/ScoreLabel
@onready var _success_sfx:    AudioStreamPlayer = $SuccessSound
@onready var _miss_sfx:       AudioStreamPlayer = $MissSound
@onready var _speed_panel:    Panel             = $UI/SpeedPanel
@onready var _speed_lbl:      Label             = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl: Label             = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:        Button            = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:        Button            = $UI/SpeedPanel/SpeedRow/IncreaseButton

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_slot_positions()
	_load_seed_textures()
	_init_rom_data()
	_calc_speed()
	_spawn_seeds()
	_build_rain_drops()
	_set_cloud_x(583.0)
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
	for p in [
		"res://game/RNR/sprites/seed.png",
		"res://game/RNR/sprites/plant_stage2.png",
		"res://game/RNR/sprites/plant_stage3.png",
		"res://game/RNR/sprites/plant_stage4.png",
		"res://game/RNR/sprites/plant_stage5.png",
	]:
		_seed_textures.append(load(p))

func _spawn_seeds() -> void:
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
		var bar_x := cx + SEED_SIZE * 0.5 + 6.0
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

		# ── Seed / plant sprite ──────────────────────────────────────────────
		var seed := TextureRect.new()
		seed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seed.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		# Fixed base rect — scale is used to resize so aspect ratio is always preserved
		seed.size         = Vector2(SEED_SIZE, SEED_SIZE)
		seed.scale        = Vector2(1.0, 1.0)
		seed.position     = Vector2(cx - SEED_SIZE * 0.5, SEED_Y - SEED_SIZE)
		if _seed_textures.size() > 0 and _seed_textures[0] != null:
			seed.texture = _seed_textures[0]
		_seed_container.add_child(seed)
		_seed_nodes.append(seed)
		_seed_stage.append(0)

# Build shared animated rain drops (one set, repositioned to active slot)
func _build_rain_drops() -> void:
	_drop_nodes.clear()
	for _i in RAIN_DROP_COUNT:
		var drop := ColorRect.new()
		drop.color   = Color(0.55, 0.82, 1.0, 0.9)
		drop.size    = Vector2(RAIN_DROP_W, RAIN_DROP_H)
		drop.visible = false
		_seed_container.add_child(drop)
		_drop_nodes.append(drop)

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

func _calc_speed() -> void:
	_game_speed = MIN_SPEED
	if AppData.speed_data != null:
		_game_speed = clamp(AppData.speed_data.game_speed, MIN_SPEED, MAX_SPEED)
	_recalc_from_game_speed()

func _recalc_from_game_speed() -> void:
	var t: float = clamp((_game_speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	_move_duration         = lerp(MAX_MOVE_DURATION, MIN_MOVE_DURATION, t)
	_rain_duration_to_grow = lerp(0.5, 0.15, t)

func _increase_speed() -> void:
	if _game_speed >= MAX_SPEED: return
	_game_speed += 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _decrease_speed() -> void:
	if _game_speed <= MIN_SPEED: return
	_game_speed -= 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _refresh_speed_label() -> void:
	_speed_lbl.text      = "%d" % int(_game_speed)
	_speed_info_lbl.text = "Duration: %.1f s" % _move_duration

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
func _process(delta: float) -> void:
	_move_cloud(delta)
	_tick(delta)
	_animate_visuals(delta)
	_refresh_ui()
	_update_log_state()

func _move_cloud(delta: float) -> void:
	var sx := angle_to_screen(PlutoComm.angle)
	if Input.is_key_pressed(KEY_LEFT):
		sx = _cloud_x - 400.0 * delta
	elif Input.is_key_pressed(KEY_RIGHT):
		sx = _cloud_x + 400.0 * delta
	_set_cloud_x(clamp(sx, GAME_LEFT + CLOUD_HALF, GAME_RIGHT - CLOUD_HALF))

# ── Animate highlight + rain drops each frame ─────────────────────────────────
func _animate_visuals(delta: float) -> void:
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

	# Rain drops + progress bar
	var rain_visible: bool  = _is_raining and active
	var col_top:      float = _cloud.position.y + _cloud.size.y
	var col_bottom:   float = SEED_Y - SEED_SIZE - 4.0
	var col_height:   float = col_bottom - col_top
	var slot_cx:      float = float(_slot_positions[_target_seed]) if _target_seed >= 0 and _target_seed < _slot_positions.size() else 583.0

	for j in RAIN_DROP_COUNT:
		var drop := _drop_nodes[j] as ColorRect
		if rain_visible:
			drop.visible = true
			# Stagger vertical start positions across the column height
			var base_y: float  = col_top + (float(j) / float(RAIN_DROP_COUNT)) * col_height
			var scroll: float  = fmod(_rain_anim_t * 220.0, col_height)
			var drop_y: float  = base_y + scroll
			if drop_y > col_bottom: drop_y -= col_height
			# Distribute drops evenly across column width with slight wobble
			var lane: float    = (float(j % 6) / 5.0 - 0.5) * RAIN_COL_W
			var wobble: float  = sin(float(j) * 2.3 + _rain_anim_t * 1.5) * 4.0
			drop.position = Vector2(slot_cx - RAIN_DROP_W * 0.5 + lane + wobble, drop_y)
			var fade: float = 1.0 - abs(drop_y - (col_top + col_height * 0.5)) / (col_height * 0.5)
			drop.modulate.a = clamp(fade * 0.92, 0.15, 0.92)
		else:
			drop.visible = false

	# Progress bar (show when target active)
	const BAR_H: float = 80.0
	const BAR_W: float = 8.0
	var bar_cx: float = slot_cx + SEED_SIZE * 0.5 + 6.0
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
	var max_stage: int = _seed_textures.size() - 1
	var new_stage: int = _seed_stage[idx] + 1
	if new_stage > max_stage:
		new_stage = 2   # wrap back to stage 3 (index 2) after reaching stage 5
	_seed_stage[idx] = new_stage
	var sz:     float = float(PLANT_SIZES[new_stage]) if new_stage < PLANT_SIZES.size() else 120.0
	var cx:     float = float(_slot_positions[idx])
	var node          := _seed_nodes[idx] as TextureRect
	node.texture      = _seed_textures[new_stage] if new_stage < _seed_textures.size() else null
	# Scale uniformly from base SEED_SIZE so the texture's natural aspect ratio is kept
	var factor: float = sz / SEED_SIZE
	node.scale        = Vector2(factor, factor)
	# Reanchor to bottom-center (scale expands from top-left corner)
	node.position     = Vector2(cx - SEED_SIZE * factor * 0.5, SEED_Y - SEED_SIZE * factor)
	n_success        += 1
	_success_sfx.play()

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
	for drop in _drop_nodes:
		drop.visible = false

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
	n_targets  = 0; n_success = 0; n_failure = 0
	_wait_panel.visible = false
	AppData.start_new_trial()
	_setup_aan()

func _setup_aan() -> void:
	var mech  = AppData.mechanism_name
	_use_aan = PlutoComm.is_connected and mech != "FME1" and mech != "FME2" and mech != "NOMECH"
	_aan     = _PlutoAAN.new()
	if _arom.size() >= 2: _aan.arom = _arom.duplicate()
	if _prom.size() >= 2: _aan.prom = _prom.duplicate()
	if _use_aan:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)

func _end_game() -> void:
	_game_finished = true
	_is_raining    = false
	_hide_all_highlights()
	_save_speed()
	AppData.stop_trial(n_targets, n_success, n_failure)
	_final_lbl.text      = "%d / %d\nPress PLUTO button to play again" % [n_success, n_targets]
	_over_panel.visible  = true
	_speed_panel.visible = false

func _refresh_ui() -> void:
	_timer_lbl.text = "Time: %02d s" % maxi(0, ceili(_time_left))
	_score_lbl.text = "Score: %02d"  % n_success

# ── Logging ───────────────────────────────────────────────────────────────────
func _update_log_state() -> void:
	AppData.log_player_x   = _cloud_x
	AppData.log_player_y   = CLOUD_Y + CLOUD_H * 0.5
	AppData.log_target_x   = _slot_positions[_target_seed] if _target_seed < _slot_positions.size() else 0.0
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
	if not (event is InputEventKey) or not event.pressed: return
	if event.keycode == KEY_SPACE: _on_pluto_button()
	elif event.ctrl_pressed and event.keycode == KEY_G:
		_speed_panel.visible = !_speed_panel.visible

func _on_pluto_button() -> void:
	match _state:
		State.WAITING: _game_started = true
		State.DONE:    get_tree().reload_current_scene()
		State.STOP:    pass
		_:             _toggle_pause()

func _toggle_pause() -> void:
	if _state != State.PAUSED:
		_prev_state = _state; _state = State.PAUSED; _pause_panel.visible = true
	else:
		_state = _prev_state; _pause_panel.visible = false

func _on_exit_pressed() -> void:
	if not _game_finished:
		_is_raining = false
		_hide_all_highlights()
		_save_speed()
		AppData.stop_trial(n_targets, n_success, n_failure)
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
