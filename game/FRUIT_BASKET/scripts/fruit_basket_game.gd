extends Control

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ────────────────────────────────────────────────────────────────────
const GAME_LEFT:      float = 20.0
const GAME_RIGHT:     float = 1146.0
const FRUIT_START_Y:  float = 50.0
const BASKET_Y:       float = 510.0
const BASKET_CATCH_H: float = 70.0
const FRUIT_MISS_Y:   float = 620.0
const FRUIT_SIZE:     float = 100.0
const BASKET_SIZE:    float = 150.0
const BASKET_HALF_W:  float = 55.0
const SLOT_COUNT:     int   = 5

const FRUIT_NAMES = ["apple", "lemon", "orange", "strawberry", "blueberry"]

const CAUGHT_ICON_W:    float = 40.0
const CAUGHT_PER_ROW:   int   = 4
const BASKET_FLOOR_Y:   float = 50.0  # offset below basket centre to the interior floor

# ── Speed ─────────────────────────────────────────────────────────────────────
const MIN_SPEED:          float = 10.0
const MAX_SPEED:          float = 40.0
const TRIAL_DURATION:     float = 60.0
const MIN_MOVE_DURATION:  float = 0.5
const MAX_MOVE_DURATION:  float = 4.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WAITING, START, SPAWNFRUIT, MOVE, SUCCESS, FAILURE, STOP, DONE, PAUSED }
var _state:      State = State.WAITING
var _prev_state: State = State.WAITING

# ── Flags ─────────────────────────────────────────────────────────────────────
var _game_started:  bool = false
var _fruit_landed:  bool = false
var _fruit_missed:  bool = false
var _game_finished: bool = false

# ── Score ─────────────────────────────────────────────────────────────────────
var _time_left: float = TRIAL_DURATION
var n_targets:  int   = 0
var n_success:  int   = 0
var n_failure:  int   = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _event_delay:    float   = 0.0
var _run_once:       bool    = false
var _aprom:          Array   = []
var _prom:           Array   = []
var _arom:           Array   = []
var _move_duration:  float   = 2.0
var _fall_speed:     float   = 0.0
var _fruit_x:        float   = 583.0
var _target_slot:    int     = 0
var _fruit_type:     int     = 0
var _current_fruit:  Control = null

var _slot_positions:     Array     = []
var _basket_nodes:       Array     = []
var _basket_rest_y:      Array     = []
var _basket_icon_nodes:  Array     = []
var _basket_count_nodes: Array     = []   # Label per slot showing catch count
var _basket_counts:      Array     = []   # int count per slot
var _caught_icon_nodes:  Array     = []   # Array[Array] of placed catch icons per slot
var _slot_fruit_type:    Array     = []   # shuffled fruit index per slot
var _aura_nodes:         Array     = []
var _ring_nodes:         Array     = []
var _flash_nodes:        Array     = []
var _fruit_textures:     Array     = []

# ── Animation ─────────────────────────────────────────────────────────────────
var _anim_t:         float = 0.0
var _flash_timer:    float = 0.0
var _flash_slot:     int   = -1
var _flash_is_wrong: bool  = false

var _aan:        RefCounted = null
var _use_aan:    bool       = false
var _game_speed: float      = 10.0
var _is_cpm:     bool       = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _fruit_container:  Control           = $FruitContainer
@onready var _basket_container: Control           = $BasketContainer
@onready var _timer_lbl:        Label             = $UI/Header/TimerLabel
@onready var _score_lbl:        Label             = $UI/Header/ScoreLabel
@onready var _wait_panel:       Control           = $UI/WaitPanel
@onready var _pause_panel:      Control           = $UI/PausePanel
@onready var _over_panel:       Control           = $UI/GameOverPanel
@onready var _final_lbl:        Label             = $UI/GameOverPanel/ScoreLabel
@onready var _catch_sfx:        AudioStreamPlayer = $CatchSound
@onready var _miss_sfx:         AudioStreamPlayer = $MissSound
@onready var _speed_panel:      Panel             = $UI/SpeedPanel
@onready var _speed_lbl:        Label             = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl:   Label             = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:          Button            = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:          Button            = $UI/SpeedPanel/SpeedRow/IncreaseButton

func _ready() -> void:
	_load_textures()
	_init_rom_data()
	_calc_speed()
	_build_baskets()
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

# ── Build ─────────────────────────────────────────────────────────────────────
func _load_textures() -> void:
	for p in [
		"res://game/FRUIT_BASKET/sprites/apple.png",
		"res://game/FRUIT_BASKET/sprites/lemon.png",
		"res://game/FRUIT_BASKET/sprites/orange.png",
		"res://game/FRUIT_BASKET/sprites/strawberry.png",
		"res://game/FRUIT_BASKET/sprites/blueberry.png",
	]:
		_fruit_textures.append(load(p))

func _build_baskets() -> void:
	# Shuffle which fruit type belongs to each slot
	_slot_fruit_type = range(SLOT_COUNT)
	_slot_fruit_type.shuffle()

	var basket_names := ["barsket1", "barsket2", "barsket3", "barsket4", "barsket5"]
	for i in SLOT_COUNT:
		# Use the Sprite2D already placed in the scene — no runtime texture loading needed
		var basket := _basket_container.get_node(basket_names[i]) as Sprite2D
		var cx:     float = basket.position.x
		var rest_y: float = basket.position.y
		_slot_positions.append(cx)
		_basket_nodes.append(basket)
		_basket_rest_y.append(rest_y)
		_caught_icon_nodes.append([])

		# Outer aura (behind basket, large soft glow)
		var aura_size: float = BASKET_SIZE
		var aura_style := StyleBoxFlat.new()
		aura_style.bg_color                   = Color(1.0, 0.85, 0.1, 0.0)
		aura_style.corner_radius_top_left     = 60
		aura_style.corner_radius_top_right    = 60
		aura_style.corner_radius_bottom_right = 60
		aura_style.corner_radius_bottom_left  = 60
		var aura := Panel.new()
		aura.add_theme_stylebox_override("panel", aura_style)
		aura.size     = Vector2(aura_size, aura_size)
		aura.position = Vector2(cx - aura_size * 0.5, rest_y - aura_size * 0.5)
		aura.visible  = false
		_basket_container.add_child(aura)
		_aura_nodes.append(aura)

		# Inner crisp ring
		var ring_size: float = BASKET_SIZE 
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color                   = Color(1.0, 0.85, 0.1, 0.0)
		ring_style.border_width_left          = 4
		ring_style.border_width_top           = 4
		ring_style.border_width_right         = 4
		ring_style.border_width_bottom        = 4
		ring_style.border_color               = Color(1.0, 0.92, 0.2, 0.0)
		ring_style.corner_radius_top_left     = 44
		ring_style.corner_radius_top_right    = 44
		ring_style.corner_radius_bottom_right = 44
		ring_style.corner_radius_bottom_left  = 44
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", ring_style)
		ring.size     = Vector2(ring_size, ring_size)
		ring.position = Vector2(cx - ring_size * 0.5, rest_y - ring_size * 0.5)
		ring.visible  = false
		_basket_container.add_child(ring)
		_ring_nodes.append(ring)

		# Fruit type icon on basket — larger and fully opaque so it's clearly visible
		var fruit_idx: int = _slot_fruit_type[i]
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.size         = Vector2(56.0, 56.0)
		icon.position     = Vector2(cx - 28.0, rest_y - 88.0)
		if fruit_idx < _fruit_textures.size() and _fruit_textures[fruit_idx] != null:
			icon.texture = _fruit_textures[fruit_idx]
		_basket_container.add_child(icon)
		_basket_icon_nodes.append(icon)

		# Flash overlay — Panel so rounded corners work
		var flash_style := StyleBoxFlat.new()
		flash_style.bg_color                   = Color(0, 0, 0, 0)
		flash_style.corner_radius_top_left     = 16
		flash_style.corner_radius_top_right    = 16
		flash_style.corner_radius_bottom_right = 16
		flash_style.corner_radius_bottom_left  = 16
		var flash := Panel.new()
		flash.add_theme_stylebox_override("panel", flash_style)
		flash.size     = Vector2(BASKET_SIZE + 20.0, BASKET_SIZE + 20.0)
		flash.position = Vector2(cx - (BASKET_SIZE + 20.0) * 0.5, rest_y - (BASKET_SIZE + 20.0) * 0.5)
		_basket_container.add_child(flash)
		_flash_nodes.append(flash)

		# Catch counter label — white text, sits above the basket
		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.size     = Vector2(64.0, 30.0)
		count_lbl.position = Vector2(cx - 32.0, rest_y - 130.0)
		count_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		count_lbl.add_theme_font_size_override("font_size", 24)
		_basket_container.add_child(count_lbl)
		_basket_count_nodes.append(count_lbl)
		_basket_counts.append(0)

# ── Init ──────────────────────────────────────────────────────────────────────
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
	_move_duration = lerp(MAX_MOVE_DURATION, MIN_MOVE_DURATION, t)
	_fall_speed    = (BASKET_Y - FRUIT_START_Y) / _move_duration

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
	var t: float = (angle - float(_aprom[0])) / (float(_aprom[1]) - float(_aprom[0]))
	return lerp(GAME_LEFT, GAME_RIGHT, clamp(t, 0.0, 1.0))

func _screen_to_angle(screen_x: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]: return 0.0
	var t: float = (screen_x - GAME_LEFT) / (GAME_RIGHT - GAME_LEFT)
	return lerp(float(_aprom[0]), float(_aprom[1]), clamp(t, 0.0, 1.0))

func _set_fruit_x(x: float) -> void:
	_fruit_x = x
	if _current_fruit != null:
		_current_fruit.position.x = x - FRUIT_SIZE * 0.5

# ── Main loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_anim_t      += delta
	_flash_timer   = maxf(_flash_timer - delta, 0.0)
	_tick(delta)
	var active: bool = _state not in [State.WAITING, State.PAUSED, State.STOP, State.DONE]
	if active and _current_fruit != null:
		var sx: float = angle_to_screen(PlutoComm.angle)
		if Input.is_key_pressed(KEY_LEFT):
			sx = _fruit_x - 400.0 * delta
		elif Input.is_key_pressed(KEY_RIGHT):
			sx = _fruit_x + 400.0 * delta
		_set_fruit_x(clamp(sx, GAME_LEFT + FRUIT_SIZE * 0.5, GAME_RIGHT - FRUIT_SIZE * 0.5))
		_current_fruit.position.y += _fall_speed * delta
		_check_collision()
	_animate_baskets(active)
	_refresh_ui()
	_update_log_state()

# ── Basket animation ──────────────────────────────────────────────────────────
func _animate_baskets(active: bool) -> void:
	for i in SLOT_COUNT:
		var is_target: bool = (i == _target_slot and active and
			(_state == State.MOVE or _state == State.SPAWNFRUIT))
		var cx:     float = float(_slot_positions[i])
		var rest_y: float = float(_basket_rest_y[i])
		var basket    := _basket_nodes[i]      as Sprite2D
		var bicon     := _basket_icon_nodes[i] as TextureRect
		var count_lbl := _basket_count_nodes[i] as Label
		var aura      := _aura_nodes[i]        as Panel
		var ring      := _ring_nodes[i]        as Panel
		var flash_cr  := _flash_nodes[i]       as Panel

		if is_target:
			# Bounce basket, icon, and counter together
			var bounce: float = sin(_anim_t * 6.5) * 9.0
			basket.position.y    = rest_y + bounce
			bicon.position.y     = rest_y - 88.0 + bounce
			count_lbl.position.y = rest_y - 130.0 + bounce
			basket.position.x    = cx
			bicon.position.x     = cx - 28.0
			count_lbl.position.x = cx - 32.0
			aura.visible = true
			ring.visible = true
			# Slow breathe on aura, fast crisp pulse on ring border
			var aura_alpha: float = sin(_anim_t * 3.0) * 0.08 + 0.15
			var ring_alpha: float = sin(_anim_t * 5.2) * 0.2 + 0.82
			var aura_sbox := aura.get_theme_stylebox("panel") as StyleBoxFlat
			aura_sbox.bg_color     = Color(1.0, 0.85, 0.1, aura_alpha)
			var ring_sbox := ring.get_theme_stylebox("panel") as StyleBoxFlat
			ring_sbox.bg_color     = Color(1.0, 0.85, 0.1, aura_alpha * 0.25)
			ring_sbox.border_color = Color(1.0, 0.93, 0.2, ring_alpha)
		else:
			# Reset to rest position
			basket.position.y    = rest_y
			bicon.position.y     = rest_y - 88.0
			count_lbl.position.y = rest_y - 130.0
			aura.visible = false
			ring.visible = false

		# Flash overlay + shake (applied after base position, overrides X if shaking)
		var flash_sbox := flash_cr.get_theme_stylebox("panel") as StyleBoxFlat
		if i == _flash_slot and _flash_timer > 0.0:
			var pct: float = _flash_timer / 0.55
			if _flash_is_wrong:
				flash_sbox.bg_color = Color(1.0, 0.1, 0.1, pct * 0.55)
				var shake: float = sin(_anim_t * 55.0) * (pct * 9.0)
				basket.position.x    = cx + shake
				bicon.position.x     = cx - 28.0 + shake
				count_lbl.position.x = cx - 32.0 + shake
			else:
				flash_sbox.bg_color  = Color(0.15, 1.0, 0.35, pct * 0.5)
				basket.position.x    = cx
				bicon.position.x     = cx - 28.0
				count_lbl.position.x = cx - 32.0
		else:
			flash_sbox.bg_color = Color(0, 0, 0, 0)
			if not is_target:
				basket.position.x    = cx
				bicon.position.x     = cx - 28.0
				count_lbl.position.x = cx - 32.0

		# Move all caught icons with the basket (same dx/dy as the basket sprite)
		var basket_dx: float = basket.position.x - cx
		var basket_dy: float = basket.position.y - rest_y
		for j in (_caught_icon_nodes[i] as Array).size():
			var c_icon := (_caught_icon_nodes[i] as Array)[j] as TextureRect
			var rp: Vector2 = _caught_icon_rest_pos(i, j)
			c_icon.position = rp + Vector2(basket_dx, basket_dy)

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
			_state = State.SPAWNFRUIT

		State.SPAWNFRUIT:
			if not _run_once:
				_target_slot = randi() % SLOT_COUNT
				_fruit_type  = _slot_fruit_type[_target_slot]
				_spawn_fruit()
				var target_angle := _screen_to_angle(_slot_positions[_target_slot])
				if _use_aan and _aan != null:
					_aan.reset_trial()
					_aan.set_new_trial_details(PlutoComm.angle, target_angle, _move_duration, _game_speed)
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
			if _fruit_landed:  _state = State.SUCCESS
			elif _fruit_missed: _state = State.FAILURE

		State.SUCCESS, State.FAILURE:
			if _event_delay <= 0.0:
				_event_delay = 0.65
			else:
				_event_delay -= delta
				if _event_delay <= 0.0:
					var time_up := _time_left <= 0.0
					_state        = State.STOP if time_up else State.SPAWNFRUIT
					_fruit_landed = false
					_fruit_missed = false
					_run_once     = false

		State.STOP:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, true)
				if _aan.state_change: _update_pluto_aan_target()
				var aan_done: bool = (_aan.state == _PlutoAAN.State.AROM_MOVING
					or _aan.state == _PlutoAAN.State.IDLE
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

# ── Collision ─────────────────────────────────────────────────────────────────
func _check_collision() -> void:
	if _current_fruit == null or _fruit_landed or _fruit_missed:
		return
	var fruit_cx: float = _current_fruit.position.x + FRUIT_SIZE * 0.5
	var fruit_cy: float = _current_fruit.position.y + FRUIT_SIZE * 0.5

	if fruit_cy >= BASKET_Y and fruit_cy <= BASKET_Y + BASKET_CATCH_H:
		for i in SLOT_COUNT:
			if abs(fruit_cx - float(_slot_positions[i])) < BASKET_HALF_W:
				if i == _target_slot:
					_fruit_was_caught()
				else:
					_fruit_was_missed(i)
				return
	elif _current_fruit.position.y >= FRUIT_MISS_Y:
		_fruit_was_missed(-1)

func _fruit_was_caught() -> void:
	_fruit_landed = true
	n_success    += 1
	_catch_sfx.play()
	_trigger_flash(_target_slot, false)
	_place_caught_icon(_target_slot, _fruit_type)
	# Increment per-basket counter
	_basket_counts[_target_slot] += 1
	(_basket_count_nodes[_target_slot] as Label).text = str(_basket_counts[_target_slot])
	_kill_fruit()

func _fruit_was_missed(wrong_slot: int = -1) -> void:
	_fruit_missed = true
	n_failure    += 1
	if wrong_slot >= 0:
		# Wrong basket: lower pitch to distinguish from "fell to ground"
		_miss_sfx.pitch_scale = 0.72
		_miss_sfx.play()
		_trigger_flash(wrong_slot, true)
	else:
		_miss_sfx.pitch_scale = 1.0
		_miss_sfx.play()
	_kill_fruit()

func _trigger_flash(slot: int, is_wrong: bool) -> void:
	_flash_slot     = slot
	_flash_is_wrong = is_wrong
	_flash_timer    = 0.55

func _caught_icon_rest_pos(slot: int, idx: int) -> Vector2:
	var cx:     float = float(_slot_positions[slot])
	var rest_y: float = float(_basket_rest_y[slot])
	var col:    int   = idx % CAUGHT_PER_ROW
	var row:    int   = int(float(idx) / CAUGHT_PER_ROW)
	var start_x: float = cx - (CAUGHT_PER_ROW * CAUGHT_ICON_W) * 0.5
	# Row 0 sits at the basket floor; rows stack upward with no gap
	return Vector2(start_x + col * CAUGHT_ICON_W,
				   rest_y + BASKET_FLOOR_Y - (row + 1) * CAUGHT_ICON_W)

func _place_caught_icon(slot: int, fruit_type: int) -> void:
	if fruit_type >= _fruit_textures.size() or _fruit_textures[fruit_type] == null:
		return
	var count: int = _basket_counts[slot]   # already incremented
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.size         = Vector2(CAUGHT_ICON_W, CAUGHT_ICON_W)
	icon.texture      = _fruit_textures[fruit_type]
	icon.position     = _caught_icon_rest_pos(slot, count - 1)
	_basket_container.add_child(icon)
	_caught_icon_nodes[slot].append(icon)

func _kill_fruit() -> void:
	if _current_fruit:
		_current_fruit.queue_free()
		_current_fruit = null

func _spawn_fruit() -> void:
	n_targets += 1
	var fruit := TextureRect.new()
	fruit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fruit.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	fruit.size         = Vector2(FRUIT_SIZE, FRUIT_SIZE)
	if _fruit_type < _fruit_textures.size() and _fruit_textures[_fruit_type] != null:
		fruit.texture = _fruit_textures[_fruit_type]
	_fruit_container.add_child(fruit)
	fruit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fruit_x       = 583.0
	fruit.position = Vector2(_fruit_x - FRUIT_SIZE * 0.5, FRUIT_START_Y)
	_current_fruit = fruit

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
	for i in SLOT_COUNT:
		_basket_counts[i] = 0
		(_basket_count_nodes[i] as Label).text = "0"
	_wait_panel.visible = false
	AppData.start_new_trial()
	_setup_aan()

func _setup_aan() -> void:
	var mech = AppData.mechanism_name
	_use_aan = PlutoComm.is_connected and mech != "FME1" and mech != "FME2" and mech != "NOMECH"
	_aan     = _PlutoAAN.new()
	if _arom.size() >= 2: _aan.arom = _arom.duplicate()
	if _prom.size()  >= 2: _aan.prom = _prom.duplicate()
	if _use_aan:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)

func _end_game() -> void:
	_game_finished = true
	_kill_fruit()
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
	AppData.log_player_x = _fruit_x
	AppData.log_player_y = (_current_fruit.position.y + FRUIT_SIZE * 0.5) if _current_fruit else 0.0
	if _target_slot >= 0 and _target_slot < _slot_positions.size():
		AppData.log_target_x = float(_slot_positions[_target_slot])
		AppData.log_target_y = BASKET_Y
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
		_kill_fruit()
		_save_speed()
		AppData.stop_trial(n_targets, n_success, n_failure)
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
