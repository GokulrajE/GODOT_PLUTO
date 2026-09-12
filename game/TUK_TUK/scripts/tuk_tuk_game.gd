extends Control

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ────────────────────────────────────────────────────────────────────
const GAME_LEFT:       float = 20.0
const GAME_RIGHT:      float = 1146.0
const GAME_TOP:        float = 82.0
const GAME_BOTTOM:     float = 562.0
const PLAYER_X:        float = 220.0
const ROCK_W:          float = 90.0
const ROCK_H:          float = 320.0
const GAP_H:           float = 188.0
const SPAWN_X:         float = 1240.0
const DESPAWN_X:       float = -110.0
const BG_W:            float = 1200.0
const HIT_MARGIN_X:    float = 50.0
const HIT_MARGIN_Y:    float = 70.0

# ── Speed ─────────────────────────────────────────────────────────────────────
const MIN_SPEED:          float = 10.0
const MAX_SPEED:          float = 40.0
const TRIAL_DURATION:     float = 60.0
const MIN_SCROLL:         float = 160.0
const MAX_SCROLL:         float = 460.0
const MIN_SPAWN_INTERVAL: float = 0.9
const MAX_SPAWN_INTERVAL: float = 3.2

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WAITING, START, MOVE, FAILURE, STOP, DONE, PAUSED }
var _state:      State = State.WAITING
var _prev_state: State = State.WAITING

# ── Flags ─────────────────────────────────────────────────────────────────────
var _game_started:  bool = false
var _game_finished: bool = false

# ── Score ─────────────────────────────────────────────────────────────────────
var _time_left: float = TRIAL_DURATION
var n_targets:  int   = 0
var n_success:  int   = 0
var n_failure:  int   = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _aprom:          Array = []
var _prom:           Array = []
var _arom:           Array = []
var _player_y:       float = 0.0
var _player_w:       float = 72.0
var _player_h:       float = 72.0
var _shake_x:        float = 0.0
var _scroll_speed:   float = 200.0
var _spawn_interval: float = 2.0
var _spawn_timer:    float = 0.5
var _game_speed:     float = 10.0
var _fail_flash_t:   float = 0.0
var _aan_target_gap_y: float = -1.0

var _columns:       Array     = []
var _rock_tex:      Texture2D = null
var _rock_down_tex: Texture2D = null

var _bg1: TextureRect = null
var _bg2: TextureRect = null

var _aan:     RefCounted = null
var _use_aan: bool       = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _player:         TextureRect       = $Player
@onready var _rock_container: Control           = $RockContainer
@onready var _timer_lbl:      Label             = $UI/Header/TimerLabel
@onready var _score_lbl:      Label             = $UI/Header/ScoreLabel
@onready var _wait_panel:     Control           = $UI/WaitPanel
@onready var _pause_panel:    Control           = $UI/PausePanel
@onready var _over_panel:     Control           = $UI/GameOverPanel
@onready var _final_lbl:      Label             = $UI/GameOverPanel/ScoreLabel
@onready var _die_sfx:        AudioStreamPlayer = $DieSound
@onready var _pass_sfx:       AudioStreamPlayer = $PassSound
@onready var _speed_panel:    Panel             = $UI/SpeedPanel
@onready var _speed_lbl:      Label             = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl: Label             = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:        Button            = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:        Button            = $UI/SpeedPanel/SpeedRow/IncreaseButton

func _ready() -> void:
	_load_textures()
	_setup_scrolling_bg()
	_init_rom_data()
	_calc_speed()
	_player_w = _player.size.x if _player.size.x > 0.0 else 72.0
	_player_h = _player.size.y if _player.size.y > 0.0 else 72.0
	_player_y = (GAME_TOP + GAME_BOTTOM) * 0.5
	_update_player_node()
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
	var bgm = load("res://game/TUK_TUK/audio/bgd music/Naan Autokaran Intro Music (BGM) _ T.Thuvarakan.mp3")
	if bgm:
		$Music.stream = bgm
		$Music.play()

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)

# ── Init ──────────────────────────────────────────────────────────────────────
func _load_textures() -> void:
	_rock_tex      = load("res://game/TUK_TUK/sprites/New level/rock.png")
	_rock_down_tex = load("res://game/TUK_TUK/sprites/New level/rockDown.png")

func _setup_scrolling_bg() -> void:
	var tex: Texture2D = load("res://game/TUK_TUK/sprites/New level/background.png")
	if tex == null: return
	$Background.visible = false
	_bg1 = TextureRect.new()
	_bg1.texture      = tex
	_bg1.size         = Vector2(BG_W, 640.0)
	_bg1.position     = Vector2(0.0, 0.0)
	_bg1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg1.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_bg1)
	move_child(_bg1, 0)
	_bg2 = _bg1.duplicate() as TextureRect
	_bg2.position = Vector2(BG_W, 0.0)
	add_child(_bg2)
	move_child(_bg2, 1)

func _scroll_bg(delta: float) -> void:
	if _bg1 == null: return
	var spd: float = _scroll_speed * 0.3
	_bg1.position.x -= spd * delta
	_bg2.position.x -= spd * delta
	if _bg1.position.x <= -BG_W: _bg1.position.x = _bg2.position.x + BG_W
	if _bg2.position.x <= -BG_W: _bg2.position.x = _bg1.position.x + BG_W

func _init_rom_data() -> void:
	if AppData.selected_mechanism == null:
		_aprom = [-45.0, 45.0]; _arom = [-30.0, 30.0]; _prom = [-45.0, 45.0]
		return
	_aprom = AppData.selected_mechanism.current_aprom
	_arom  = AppData.selected_mechanism.current_arom
	_prom  = AppData.selected_mechanism.current_prom
	if _aprom.size() < 2: _aprom = [-45.0, 45.0]
	if _arom.size()  < 2: _arom  = [-30.0, 30.0]
	if _prom.size()  < 2: _prom  = [-45.0, 45.0]

func _calc_speed() -> void:
	_game_speed = MIN_SPEED
	if AppData.speed_data != null:
		_game_speed = clamp(AppData.speed_data.game_speed, MIN_SPEED, MAX_SPEED)
	_recalc_from_game_speed()

func _recalc_from_game_speed() -> void:
	var t: float    = clamp((_game_speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	_scroll_speed   = lerp(MIN_SCROLL, MAX_SCROLL, t)
	_spawn_interval = lerp(MAX_SPAWN_INTERVAL, MIN_SPAWN_INTERVAL, t)

func _increase_speed() -> void:
	if _game_speed >= MAX_SPEED: return
	_game_speed += 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _decrease_speed() -> void:
	if _game_speed <= MIN_SPEED: return
	_game_speed -= 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _refresh_speed_label() -> void:
	_speed_lbl.text      = "%d" % int(_game_speed)
	_speed_info_lbl.text = "Scroll: %.0f px/s" % _scroll_speed

func _save_speed() -> void:
	if AppData.speed_data != null:
		AppData.speed_data.set_game_speed(_game_speed)
		AppData.speed_data.set_move_duration(_spawn_interval)

# ── Angle ↔ Screen ────────────────────────────────────────────────────────────
func angle_to_screen_y(angle: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]:
		return (GAME_TOP + GAME_BOTTOM) * 0.5
	var t: float = (angle - float(_aprom[0])) / (float(_aprom[1]) - float(_aprom[0]))
	return lerp(GAME_BOTTOM - _player_h * 0.5, GAME_TOP + _player_h * 0.5, clamp(t, 0.0, 1.0))

func _screen_y_to_angle(sy: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]: return 0.0
	var range_lo: float = GAME_BOTTOM - _player_h * 0.5
	var range_hi: float = GAME_TOP    + _player_h * 0.5
	var t: float        = (sy - range_lo) / (range_hi - range_lo)
	return lerp(float(_aprom[0]), float(_aprom[1]), clamp(t, 0.0, 1.0))

func _update_player_node() -> void:
	_player.position = Vector2(PLAYER_X - _player_w * 0.5 + _shake_x, _player_y - _player_h * 0.5)

# ── Column management ─────────────────────────────────────────────────────────
func _spawn_column() -> void:
	n_targets += 1
	var margin:   float = 55.0
	var gap_y:    float = randf_range(GAME_TOP + GAP_H * 0.5 + margin, GAME_BOTTOM - GAP_H * 0.5 - margin)

	var top := TextureRect.new()
	top.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	top.size         = Vector2(ROCK_W, ROCK_H)
	top.position     = Vector2(SPAWN_X - ROCK_W * 0.5, gap_y - GAP_H * 0.5 - ROCK_H)
	if _rock_down_tex: top.texture = _rock_down_tex
	_rock_container.add_child(top)

	var bot := TextureRect.new()
	bot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bot.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bot.size         = Vector2(ROCK_W, ROCK_H)
	bot.position     = Vector2(SPAWN_X - ROCK_W * 0.5, gap_y + GAP_H * 0.5)
	if _rock_tex: bot.texture = _rock_tex
	_rock_container.add_child(bot)

	_columns.append({"top": top, "bot": bot, "gap_y": gap_y, "x": SPAWN_X, "scored": false})

func _clear_columns() -> void:
	for col in _columns:
		(col.top as TextureRect).queue_free()
		(col.bot as TextureRect).queue_free()
	_columns.clear()

func _update_columns(delta: float) -> void:
	var to_remove: Array = []
	for col in _columns:
		col.x -= _scroll_speed * delta
		(col.top as TextureRect).position.x = col.x - ROCK_W * 0.5
		(col.bot as TextureRect).position.x = col.x - ROCK_W * 0.5
		# Score when column fully passes the player
		if not col.scored and (col.x + ROCK_W * 0.5) < (PLAYER_X - _player_w * 0.5):
			col.scored = true
			n_success += 1
			_pass_sfx.play()
		if col.x < DESPAWN_X:
			(col.top as TextureRect).queue_free()
			(col.bot as TextureRect).queue_free()
			to_remove.append(col)
	for col in to_remove:
		_columns.erase(col)

func _check_collision() -> bool:
	# Use a smaller hitbox inset from the sprite edges for fair collision
	var hw: float = (_player_w - HIT_MARGIN_X * 2.0) * 0.5
	var hh: float = (_player_h - HIT_MARGIN_Y * 2.0) * 0.5
	var pr := Rect2(PLAYER_X - hw, _player_y - hh, hw * 2.0, hh * 2.0)
	if _player_y - hh < GAME_TOP or _player_y + hh > GAME_BOTTOM:
		return true
	for col in _columns:
		if abs(col.x - PLAYER_X) > ROCK_W * 2.0: continue
		var top_r := Rect2(col.x - ROCK_W * 0.5, col.gap_y - GAP_H * 0.5 - ROCK_H, ROCK_W, ROCK_H)
		var bot_r := Rect2(col.x - ROCK_W * 0.5, col.gap_y + GAP_H * 0.5, ROCK_W, ROCK_H)
		if pr.intersects(top_r) or pr.intersects(bot_r):
			return true
	return false

func _get_next_column() -> Dictionary:
	var best_x: float = 1e9
	var result := {"x": -1.0, "gap_y": (GAME_TOP + GAME_BOTTOM) * 0.5}
	for col in _columns:
		if not col.scored and float(col.x) > PLAYER_X and float(col.x) < best_x:
			best_x        = float(col.x)
			result.x      = float(col.x)
			result.gap_y  = float(col.gap_y)
	return result

# ── Main loop ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tick(delta)
	_refresh_ui()
	_update_log_state()

func _tick(delta: float) -> void:
	var playing := (_state != State.WAITING and _state != State.PAUSED
					and _state != State.STOP  and _state != State.DONE)
	if playing and _time_left > 0.0:
		_time_left -= delta

	match _state:
		State.WAITING:
			if _game_started: _state = State.START

		State.START:
			_begin_game()
			_spawn_timer = 0.4
			_state = State.MOVE

		State.MOVE:
			# Player Y from PLUTO (or keyboard in debug)
			var ty: float = angle_to_screen_y(PlutoComm.angle)
			if Input.is_key_pressed(KEY_UP):   ty = _player_y - 350.0 * delta
			elif Input.is_key_pressed(KEY_DOWN): ty = _player_y + 350.0 * delta
			_player_y = clamp(ty, GAME_TOP + _player_h * 0.5, GAME_BOTTOM - _player_h * 0.5)
			_player.visible = true
			_update_player_node()

			# Spawn and scroll columns
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_column()
				_spawn_timer = _spawn_interval
			_update_columns(delta)
			_scroll_bg(delta)

			# AAN — target is the approaching column's gap centre
			if _use_aan and _aan != null:
				var next := _get_next_column()
				var gap_y: float = float(next.gap_y)
				var tgt_angle: float = _screen_y_to_angle(gap_y)
				if abs(gap_y - _aan_target_gap_y) > 8.0:
					_aan_target_gap_y = gap_y
					var dist_x: float = float(next.x) - PLAYER_X if float(next.x) > 0.0 else 1200.0
					var ttc: float    = max(0.3, dist_x / max(_scroll_speed, 1.0))
					_aan.reset_trial()
					_aan.set_new_trial_details(PlutoComm.angle, tgt_angle, ttc, _game_speed)
				_aan.update(PlutoComm.angle, delta, false)
				if _aan.state_change: _update_pluto_aan_target()

			# Collision
			if _check_collision():
				n_failure    += 1
				_fail_flash_t = 0.75
				_die_sfx.play()
				_state = State.FAILURE

			if _time_left <= 0.0:
				_state = State.STOP

		State.FAILURE:
			_fail_flash_t -= delta
			_shake_x = sin(_fail_flash_t * 40.0) * 10.0
			_player.visible = fmod(_fail_flash_t * 10.0, 1.0) > 0.5
			_update_player_node()
			_update_columns(delta)
			_scroll_bg(delta)
			if _fail_flash_t <= 0.0:
				_shake_x = 0.0
				_player.visible = true
				_aan_target_gap_y = -1.0
				_state = State.MOVE

		State.STOP:
			if _use_aan and _aan != null:
				_aan.update(PlutoComm.angle, delta, true)
				if _aan.state_change: _update_pluto_aan_target()
				var aan_done: bool = (_aan.state == _PlutoAAN.State.AROM_MOVING
					or _aan.state == _PlutoAAN.State.IDLE
					or _aan.state == _PlutoAAN.State.NONE)
				if not aan_done: return
			_end_game()
			_state = State.DONE

		State.DONE, State.PAUSED:
			pass

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
	_clear_columns()
	_save_speed()
	AppData.stop_trial(n_targets, n_success, n_failure)
	_final_lbl.text      = "%d / %d\nPress PLUTO button to play again" % [n_success, n_targets]
	_over_panel.visible  = true
	_speed_panel.visible = false

# ── UI ────────────────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	_timer_lbl.text = "Time: %02d s" % maxi(0, ceili(_time_left))
	_score_lbl.text = "Score: %02d"  % n_success

func _update_log_state() -> void:
	AppData.log_player_x = PLAYER_X
	AppData.log_player_y = _player_y
	var next := _get_next_column()
	AppData.log_target_x = float(next.x)
	AppData.log_target_y = float(next.gap_y)
	AppData.log_game_state = State.keys()[_state]
	if _aan != null:
		AppData.log_aan_target = _aan.target_position
		AppData.log_aan_init   = _aan.initial_position
		AppData.log_aan_state  = _PlutoAAN.State.keys()[_aan.state]
	else:
		AppData.log_aan_target = 0.0; AppData.log_aan_init = 0.0; AppData.log_aan_state = ""

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
		_clear_columns()
		_save_speed()
		AppData.stop_trial(n_targets, n_success, n_failure)
	get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
