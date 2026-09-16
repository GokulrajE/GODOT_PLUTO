extends Control

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ──────────────────────────────────────────────────────────────────
const GAME_LEFT: float       = 20.0
const GAME_RIGHT: float      = 1146.0
const BALL_START_Y: float    = 72.0
const BALL_MISS_Y: float     = 610.0   # below catch zone (hat brim ~496 + catch height)
const HAT_Y_TOP: float       = 490.0   # hat moved to Y≈496 in scene
const HAT_H: float           = 130.0
const HAT_HALF_W: float      = 100.0   # collision half-width
const HAT_W: float           = 200.0   # collision width
const HAT_VISUAL_HALF: float = 71.0    # (202 layout px * 0.7 scale) / 2 — for visual centering and clamping
const CATCH_Y_TOP: float     = 490.0   # aligned to hat brim Y
const CATCH_Y_H: float       = 65.0    # catch window height
const BALL_SIZE: float       = 80.0    # bowling ball (square)
const BOMB_W:    float       = 150.0   # bomb width
const BOMB_H:    float       = 150.0   # bomb height
const MIN_SPEED: float       = 10.0    # minimum game speed (deg/s)
const MAX_SPEED: float       = 40.0    # maximum game speed (deg/s)

# ── Timing ──────────────────────────────────────────────────────────────────
const TRIAL_DURATION: float    = 60.0
const MIN_MOVE_DURATION: float = 0.5
const MAX_MOVE_DURATION: float = 4.0

# ── State machine ────────────────────────────────────────────────────────────
enum State { WAITING, START, SPAWNBALL, MOVE, SUCCESS, FAILURE, STOP, DONE, PAUSED }
var _state: State      = State.WAITING
var _prev_state: State = State.WAITING

# ── Event flags ──────────────────────────────────────────────────────────────
var _game_started:  bool = false
var _ball_caught:   bool = false
var _ball_missed:   bool = false
var _game_finished: bool = false

# ── Score ────────────────────────────────────────────────────────────────────
var _time_left: float = TRIAL_DURATION
var n_targets:  int   = 0
var n_success:  int   = 0
var n_failure:  int   = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _event_delay:   float = 0.0
var _run_once:      bool  = false
var _aprom:         Array = []
var _prom:          Array = []
var _arom:          Array = []
var _move_duration: float = 2.0
var _ball_speed:    float = 0.0
var _hat_x:         float = 583.0
var _target_angle:  float = 0.0
var _current_ball:  Control = null
var _ball_textures: Array   = []

# ── AAN (Assist-As-Needed) ───────────────────────────────────────────────────
var _aan:        RefCounted = null
var _use_aan:    bool       = false
var _game_speed: float      = 10.0
var _is_cpm:     bool       = false

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var _hat_back:       TextureRect        = $HatBack
@onready var _hat_front:      TextureRect        = $HatFront
@onready var _ball_container: Control            = $BallContainer
@onready var _arom_left:      ColorRect          = $AromLeftLine
@onready var _arom_right:     ColorRect          = $AromRightLine
@onready var _timer_lbl:      Label              = $UI/Header/TimerLabel
@onready var _score_lbl:      Label              = $UI/Header/ScoreLabel
@onready var _wait_panel:     Control            = $UI/WaitPanel
@onready var _pause_panel:    Control            = $UI/PausePanel
@onready var _over_panel:     Control            = $UI/GameOverPanel
@onready var _final_lbl:      Label              = $UI/GameOverPanel/ScoreLabel
@onready var _catch_sfx:      AudioStreamPlayer  = $CatchSound
@onready var _miss_sfx:       AudioStreamPlayer  = $MissSound
@onready var _speed_panel:    Panel              = $UI/SpeedPanel
@onready var _speed_lbl:      Label              = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl: Label              = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:        Button             = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:        Button             = $UI/SpeedPanel/SpeedRow/IncreaseButton

func _ready() -> void:
	_load_ball_textures()
	_init_rom_data()
	_calc_speed()
	_place_arom_lines()
	_set_hat_x(583.0)
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

func _load_ball_textures() -> void:
	var t1 = load("res://game/HAT_TIRCK/Sprites/BowlingBallSprite.png")
	var t2 = load("res://game/HAT_TIRCK/Sprites/BombSprite.png")
	if t1: _ball_textures.append(t1)
	if t2: _ball_textures.append(t2)

func _init_rom_data() -> void:
	if AppData.selected_mechanism == null:
		_aprom  = [-45.0, 45.0]
		_arom   = [-30.0, 30.0]
		_prom   = [-45.0, 45.0]
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
	_ball_speed    = (BALL_MISS_Y - BALL_START_Y) / _move_duration

func _increase_speed() -> void:
	if _game_speed >= MAX_SPEED:
		return
	_game_speed += 1.0
	_recalc_from_game_speed()
	_refresh_speed_label()

func _decrease_speed() -> void:
	if _game_speed <= MIN_SPEED:
		return
	_game_speed -= 1.0
	_recalc_from_game_speed()
	_refresh_speed_label()

func _refresh_speed_label() -> void:
	_speed_lbl.text = "%d" % int(_game_speed)
	_speed_info_lbl.text = "Duration: %.1f s" % _move_duration

func _save_speed() -> void:
	if AppData.speed_data != null:
		AppData.speed_data.set_game_speed(_game_speed)
		AppData.speed_data.set_move_duration(_move_duration)

func _place_arom_lines() -> void:
	# In CPM mode AROM is ~0 range — hide the lines as they'd overlap at centre
	if _arom.size() < 2 or _is_cpm:
		_arom_left.visible  = false
		_arom_right.visible = false
		return
	_arom_left.position.x  = angle_to_screen(_arom[0]) - 1.0
	_arom_right.position.x = angle_to_screen(_arom[1]) - 1.0

func angle_to_screen(angle: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]:
		return 583.0
	var t: float = (angle - float(_aprom[0])) / (float(_aprom[1]) - float(_aprom[0]))
	return lerp(GAME_LEFT, GAME_RIGHT, clamp(t, 0.0, 1.0))

func _set_hat_x(x: float) -> void:
	_hat_x = x
	_hat_back.position.x  = x - HAT_VISUAL_HALF
	_hat_front.position.x = x - HAT_VISUAL_HALF

func _process(delta: float) -> void:
	_move_hat(delta)
	_tick(delta)
	var active = _state not in [State.WAITING, State.PAUSED, State.STOP, State.DONE]
	if active:
		_move_balls(delta)
	_refresh_ui()
	_update_log_state()

func _update_log_state() -> void:
	AppData.log_player_x  = _hat_x
	AppData.log_player_y  = HAT_Y_TOP
	if _current_ball != null:
		AppData.log_target_x = _current_ball.position.x + _current_ball.size.x * 0.5
		AppData.log_target_y = _current_ball.position.y + _current_ball.size.y * 0.5
	else:
		AppData.log_target_x = 0.0
		AppData.log_target_y = 0.0
	AppData.log_game_state = State.keys()[_state]
	if _aan != null:
		AppData.log_aan_target = _aan.target_position
		AppData.log_aan_init   = _aan.initial_position
		AppData.log_aan_state  = _PlutoAAN.State.keys()[_aan.state]
	else:
		AppData.log_aan_target = 0.0
		AppData.log_aan_init   = 0.0
		AppData.log_aan_state  = ""

func _move_hat(delta: float) -> void:
	var sx := angle_to_screen(PlutoComm.angle)
	# Keyboard fallback for testing without PLUTO hardware
	if Input.is_key_pressed(KEY_LEFT):
		sx = _hat_x - 400.0 * delta
	elif Input.is_key_pressed(KEY_RIGHT):
		sx = _hat_x + 400.0 * delta
	_set_hat_x(clamp(sx, GAME_LEFT + HAT_VISUAL_HALF, GAME_RIGHT - HAT_VISUAL_HALF))

func _tick(delta: float) -> void:
	var playing = (_state != State.WAITING and _state != State.PAUSED
				   and _state != State.STOP and _state != State.DONE)
	if playing and _time_left > 0.0:
		_time_left -= delta

	match _state:
		State.WAITING:
			if _game_started:
				_state = State.START

		State.START:
			_begin_game()
			_state = State.SPAWNBALL

		State.SPAWNBALL:
			if not _run_once:
				_target_angle = _pick_target_angle()
				_spawn_ball()
				if _use_aan and _aan != null:
					_aan.reset_trial()
					_aan.set_new_trial_details(PlutoComm.angle, _target_angle, _move_duration, _game_speed)
				_event_delay = 0.05
				_run_once    = true
			else:
				_event_delay -= delta
				if _event_delay <= 0.0:
					_state = State.MOVE

		State.MOVE:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, false)
				if _aan.state_change:
					_update_pluto_aan_target()
			if _ball_caught:
				_state = State.SUCCESS
			elif _ball_missed:
				_state = State.FAILURE

		State.SUCCESS, State.FAILURE:
			if _event_delay <= 0.0:
				_event_delay = 0.3
			else:
				_event_delay -= delta
				if _event_delay <= 0.0:
					var time_up := _time_left <= 0.0
					_state       = State.STOP if time_up else State.SPAWNBALL
					_ball_caught = false
					_ball_missed = false
					_run_once    = false

		State.STOP:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, true)
				if _aan.state_change:
					_update_pluto_aan_target()
				var aan_done = (_aan.state == _PlutoAAN.State.AROM_MOVING
								or _aan.state == _PlutoAAN.State.IDLE
								or _aan.state == _PlutoAAN.State.NONE)
				if aan_done:
					_end_game()
					_state = State.DONE
					return
				# AAN not yet at AROM (common in CPM mode — patient may never return).
				# Use a timed fallback: 5 s at max speed, 12 s at min speed.
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

func _move_balls(delta: float) -> void:
	if _current_ball == null:
		return
	_current_ball.position.y += _ball_speed * delta
	_check_collision()

func _check_collision() -> void:
	if _current_ball == null or _ball_caught or _ball_missed:
		return
	var sz: Vector2 = _current_ball.size
	var cx: float = _current_ball.position.x + sz.x * 0.5
	var cy: float = _current_ball.position.y + sz.y * 0.5
	var catch_rect := Rect2(Vector2(_hat_x - HAT_HALF_W, CATCH_Y_TOP), Vector2(HAT_W, CATCH_Y_H))
	if catch_rect.has_point(Vector2(cx, cy)):
		_ball_was_caught()
	elif _current_ball.position.y + sz.y >= BALL_MISS_Y:
		_ball_was_missed()

func _ball_was_caught() -> void:
	_ball_caught = true
	n_success   += 1
	_catch_sfx.play()
	_kill_ball()

func _ball_was_missed() -> void:
	_ball_missed = true
	n_failure   += 1
	_miss_sfx.play()
	_kill_ball()

func _kill_ball() -> void:
	if _current_ball:
		_current_ball.queue_free()
		_current_ball = null

func _spawn_ball() -> void:
	n_targets += 1
	var ball := TextureRect.new()
	ball.stretch_mode = TextureRect.STRETCH_SCALE
	ball.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	var display_size := Vector2(BALL_SIZE, BALL_SIZE)
	if _ball_textures.size() > 0:
		var tex_idx: int = randi() % _ball_textures.size()
		ball.texture = _ball_textures[tex_idx]
		if tex_idx == 1:
			display_size = Vector2(BOMB_W, BOMB_H)
	_ball_container.add_child(ball)
	ball.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var spawn_x: float = clamp(angle_to_screen(_target_angle), GAME_LEFT + display_size.x * 0.5, GAME_RIGHT - display_size.x * 0.5)
	ball.position = Vector2(spawn_x - display_size.x * 0.5, BALL_START_Y)
	ball.size     = display_size
	_current_ball = ball

func _pick_target_angle() -> float:
	if _prom.size() < 2:
		return 0.0
	return randf_range(_prom[0], _prom[1])

func _update_pluto_aan_target() -> void:
	if _aan == null:
		return
	match _aan.state:
		_PlutoAAN.State.AROM_MOVING:
			PlutoComm.reset_aan_target()
		_PlutoAAN.State.RELAX_TO_AROM, \
		_PlutoAAN.State.ASSIST_TO_TARGET_AT_BOUNDARY, \
		_PlutoAAN.State.ASSIST_TO_TARGET_IN_BOUNDARY:
			var t = _aan.get_new_aan_target()
			if t != null:
				PlutoComm.set_aan_target(t[0], t[1], t[2], t[3])

func _begin_game() -> void:
	_time_left = TRIAL_DURATION
	n_targets  = 0
	n_success  = 0
	n_failure  = 0
	_wait_panel.visible = false
	AppData.start_new_trial()
	_setup_aan()

func _setup_aan() -> void:
	var mech = AppData.mechanism_name
	_use_aan = PlutoComm.is_connected and mech != "FME1" and mech != "FME2" and mech != "NOMECH"
	_aan = _PlutoAAN.new()
	if _arom.size() >= 2:
		_aan.arom = _arom.duplicate()
	if _prom.size() >= 2:
		_aan.prom = _prom.duplicate()
	if _use_aan:
		PlutoComm.set_control_type("POSITIONAAN")
		PlutoComm.set_control_bound(AppData.assist_bound)
		PlutoComm.set_control_dir(0)

func _end_game() -> void:
	_game_finished = true
	PlutoComm.set_control_type("NONE")
	_kill_ball()
	_save_speed()
	AppData.stop_trial(n_targets, n_success, n_failure)
	_final_lbl.text = "%d / %d\nPress PLUTO button to play again" % [n_success, n_targets]
	_over_panel.visible = true
	_speed_panel.visible = false

func _refresh_ui() -> void:
	_timer_lbl.text = "Time: %02d s" % maxi(0, ceili(_time_left))
	_score_lbl.text = "Score: %02d"  % n_success

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_SPACE:
		_on_pluto_button()
	elif event.ctrl_pressed and event.keycode == KEY_G:
		_speed_panel.visible = !_speed_panel.visible

func _on_pluto_button() -> void:
	match _state:
		State.WAITING:
			_game_started = true
		State.DONE:
			get_tree().reload_current_scene()
		State.STOP:
			pass
		_:
			_toggle_pause()

func _toggle_pause() -> void:
	if _state != State.PAUSED:
		_prev_state          = _state
		_state               = State.PAUSED
		_pause_panel.visible = true
	else:
		_state               = _prev_state
		_pause_panel.visible = false

func _on_exit_pressed() -> void:
	if not _game_finished:
		_kill_ball()
		_save_speed()
		AppData.stop_trial(n_targets, n_success, n_failure)
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
