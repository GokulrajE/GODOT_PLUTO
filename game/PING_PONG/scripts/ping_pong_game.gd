extends Control

const _PlutoAAN = preload("res://scripts/PlutoAAN.gd")

# ── Layout ────────────────────────────────────────────────────────────────────
const GAME_TOP:    float = 82.0
const GAME_BOTTOM: float = 628.0
const GAME_LEFT:   float = 0.0
const GAME_RIGHT:  float = 1152.0

# Player on RIGHT (green), Enemy on LEFT (red) — matches Unity layout
const PLAYER_X:       float = 1097.0
const ENEMY_X:        float = 55.0
const TRIAL_DURATION: float = 60.0

# ── Speed ─────────────────────────────────────────────────────────────────────
const MIN_SPEED:       float = 10.0
const MAX_SPEED:       float = 40.0
const MIN_BALL_SPEED:  float = 280.0
const MAX_BALL_SPEED:  float = 620.0
const MIN_ENEMY_SPEED: float = 180.0
const MAX_ENEMY_SPEED: float = 440.0

var _game_speed:  float = MIN_SPEED
var _ball_speed:  float = MIN_BALL_SPEED
var _enemy_speed: float = MIN_ENEMY_SPEED

# ── Paddle/ball dimensions read from scene nodes in _ready() ──────────────────
var _player_w: float = 18.0
var _player_h: float = 120.0
var _enemy_w:  float = 18.0
var _enemy_h:  float = 120.0
var _ball_sz:  float = 28.0
var _player_hw: float = 9.5
var _player_hh: float = 55.0
var _enemy_hw:  float = 9.0
var _enemy_hh:  float = 55.0

# ── State machine ─────────────────────────────────────────────────────────────
enum State { WAITING, START, MOVE, SCORE_FLASH, STOP, DONE, PAUSED }
var _state:      State = State.WAITING
var _prev_state: State = State.WAITING

# ── Flags ─────────────────────────────────────────────────────────────────────
var _game_started:  bool = false
var _game_finished: bool = false

# ── Score / time ──────────────────────────────────────────────────────────────
var _time_left:   float = TRIAL_DURATION
var n_targets:    int   = 0
var n_success:    int   = 0
var n_failure:    int   = 0
var _flash_timer:   float = 0.0
var _player_score:  int   = 0
var _cpu_score:     int   = 0

# ── Ball physics ───────────────────────────────────────────────────────────────
var _player_y: float = 0.0
var _enemy_y:  float = 0.0
var _ball_x:   float = 0.0
var _ball_y:   float = 0.0
var _ball_vx:  float = 0.0
var _ball_vy:  float = 0.0

var _aan:           RefCounted = null
var _use_aan:       bool       = false
var _is_cpm:        bool       = false
var _arom_nodes:    Array      = []
var _pred_segs:     Array      = []
const PRED_SEG_COUNT: int      = 100
var _event_delay:   float      = 0.0
var _aan_trial_set: bool       = false

var _aprom: Array = []
var _prom:  Array = []
var _arom:  Array = []

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _player_paddle: TextureRect = $PlayerPaddle
@onready var _enemy_paddle:  TextureRect = $EnemyPaddle
@onready var _ball_node:     TextureRect       = $Ball
@onready var _timer_lbl:     Label             = $UI/Header/TimerLabel
@onready var _score_lbl:     Label             = $UI/Header/ScoreLabel
@onready var _wait_panel:    Control           = $UI/WaitPanel
@onready var _pause_panel:   Control           = $UI/PausePanel
@onready var _over_panel:    Control           = $UI/GameOverPanel
@onready var _final_lbl:     Label             = $UI/GameOverPanel/ScoreLabel
@onready var _flash_rect:    ColorRect         = $UI/FlashRect
@onready var _bounce_sfx:    AudioStreamPlayer = $BounceSound
@onready var _win_sfx:       AudioStreamPlayer = $WinSound
@onready var _lose_sfx:      AudioStreamPlayer = $LoseSound
@onready var _music:         AudioStreamPlayer = $Music
@onready var _speed_panel:   Panel             = $UI/SpeedPanel
@onready var _speed_lbl:     Label             = $UI/SpeedPanel/SpeedRow/SpeedLabel
@onready var _speed_info_lbl: Label            = $UI/SpeedPanel/SessionLabel
@onready var _dec_btn:       Button            = $UI/SpeedPanel/SpeedRow/DecreaseButton
@onready var _inc_btn:       Button            = $UI/SpeedPanel/SpeedRow/IncreaseButton

func _ready() -> void:
	_player_w = _player_paddle.size.x
	_player_h = _player_paddle.size.y
	_enemy_w  = _enemy_paddle.size.x
	_enemy_h  = _enemy_paddle.size.y
	_player_hw = _player_w * 0.5
	_player_hh = _player_h * 0.5
	_enemy_hw  = _enemy_w  * 0.5
	_enemy_hh  = _enemy_h  * 0.5
	_ball_sz = _ball_node.size.x

	_create_center_dashes()
	_init_rom_data()
	_calc_speed()

	_player_y = (GAME_TOP + GAME_BOTTOM) * 0.5
	_enemy_y  = (GAME_TOP + GAME_BOTTOM) * 0.5
	_reset_ball()
	_update_paddle_positions()

	_wait_panel.visible  = true
	_pause_panel.visible = false
	_over_panel.visible  = false
	_flash_rect.visible  = false
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
	_place_arom_lines()

	if _bounce_sfx.stream is AudioStreamWAV:
		(_bounce_sfx.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)

# ── Speed ─────────────────────────────────────────────────────────────────────
func _calc_speed() -> void:
	_game_speed = MIN_SPEED
	if AppData.speed_data != null:
		_game_speed = clamp(AppData.speed_data.game_speed, MIN_SPEED, MAX_SPEED)
	_recalc_from_game_speed()

func _recalc_from_game_speed() -> void:
	var t: float = clamp((_game_speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	_ball_speed  = lerp(MIN_BALL_SPEED,  MAX_BALL_SPEED,  t)
	_enemy_speed = lerp(MIN_ENEMY_SPEED, MAX_ENEMY_SPEED, t)

func _increase_speed() -> void:
	if _game_speed >= MAX_SPEED: return
	_game_speed += 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _decrease_speed() -> void:
	if _game_speed <= MIN_SPEED: return
	_game_speed -= 1.0; _recalc_from_game_speed(); _refresh_speed_label()

func _refresh_speed_label() -> void:
	_speed_lbl.text      = "%d" % int(_game_speed)
	_speed_info_lbl.text = "Ball: %.0f px/s\nBound: %.2f" % [_ball_speed, AppData.assist_bound]

func _save_speed() -> void:
	if AppData.speed_data != null:
		AppData.speed_data.set_game_speed(_game_speed)

# ── Init ──────────────────────────────────────────────────────────────────────
func _create_center_dashes() -> void:
	var cx:     float = GAME_RIGHT * 0.5 - 2.0
	var dash_h: float = 26.0
	var gap_h:  float = 18.0
	var y:      float = GAME_TOP + 4.0
	while y + dash_h <= GAME_BOTTOM:
		var dash := ColorRect.new()
		dash.size     = Vector2(4.0, dash_h)
		dash.position = Vector2(cx, y)
		dash.color    = Color(1, 1, 1, 0.35)
		add_child(dash)
		y += dash_h + gap_h

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

# ── Angle ↔ Screen ────────────────────────────────────────────────────────────
func angle_to_screen_y(angle: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]:
		return (GAME_TOP + GAME_BOTTOM) * 0.5
	var t: float = (angle - float(_aprom[0])) / (float(_aprom[1]) - float(_aprom[0]))
	return lerp(GAME_BOTTOM - _player_h * 0.5, GAME_TOP + _player_h * 0.5, clamp(t, 0.0, 1.0))

func _screen_y_to_angle(sy: float) -> float:
	if _aprom.size() < 2 or _aprom[0] == _aprom[1]: return 0.0
	var lo: float = GAME_BOTTOM - _player_h * 0.5
	var hi: float = GAME_TOP    + _player_h * 0.5
	return lerp(float(_aprom[0]), float(_aprom[1]), clamp((sy - lo) / (hi - lo), 0.0, 1.0))

# ── Positions ─────────────────────────────────────────────────────────────────
func _reset_ball() -> void:
	_ball_x = (GAME_LEFT + GAME_RIGHT) * 0.5
	_ball_y = (GAME_TOP  + GAME_BOTTOM) * 0.5
	var deg: float = randf_range(25.0, 55.0) * (1.0 if randf() > 0.5 else -1.0)
	var rad: float = deg_to_rad(deg)
	_ball_vx = -abs(cos(rad) * _ball_speed)
	_ball_vy =      sin(rad) * _ball_speed
	_ball_node.position = Vector2(_ball_x - _ball_sz * 0.5, _ball_y - _ball_sz * 0.5)

func _update_paddle_positions() -> void:
	_player_paddle.position = Vector2(PLAYER_X - _player_w * 0.5, _player_y - _player_h * 0.5)
	_enemy_paddle.position  = Vector2(ENEMY_X  - _enemy_w  * 0.5, _enemy_y  - _enemy_h  * 0.5)
	_ball_node.position     = Vector2(_ball_x  - _ball_sz  * 0.5, _ball_y   - _ball_sz  * 0.5)

# ── Main loop ─────────────────────────────────────────────────────────────────
func _place_arom_lines() -> void:
	if _arom.size() < 2 or _is_cpm: return
	var y_top: float = angle_to_screen_y(float(_arom[1]))
	var y_bot: float = angle_to_screen_y(float(_arom[0]))
	var x1:    float = PLAYER_X - 90.0
	var x2:    float = PLAYER_X + 20.0
	var col:   Color = Color(0.0, 1.0, 1.0, 0.75)
	var lines_data: Array = [
		[Vector2(x1, y_top - 1.0), Vector2(x2 - x1, 2.0), col],
		[Vector2(x1, y_bot - 1.0), Vector2(x2 - x1, 2.0), col],
		[Vector2(x1, minf(y_top, y_bot)), Vector2(2.0, absf(y_bot - y_top)), Color(0.0, 1.0, 1.0, 0.3)],
	]
	for d in lines_data:
		var line := ColorRect.new()
		line.position     = d[0]
		line.size         = d[1]
		line.color        = d[2]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.visible      = false
		add_child(line)
		move_child(line, $UI.get_index())
		_arom_nodes.append(line)
	# Pre-allocate dashed prediction segments
	for _i in PRED_SEG_COUNT:
		var seg := Line2D.new()
		seg.width         = 2.0
		seg.default_color = Color(1.0, 1.0, 0.0, 0.7)
		seg.visible       = false
		add_child(seg)
		move_child(seg, $UI.get_index())
		_pred_segs.append(seg)
	# Easy Mode toggle — always visible, bottom-left corner of game area
	var easy_btn := CheckButton.new()
	easy_btn.text           = "Easy Mode"
	easy_btn.button_pressed = AppData.ping_pong_easy_mode
	easy_btn.size           = Vector2(160.0, 36.0)
	easy_btn.position       = Vector2(8.0, GAME_BOTTOM - 44.0)
	easy_btn.add_theme_font_size_override("font_size", 16)
	easy_btn.toggled.connect(func(on: bool) -> void:
		AppData.ping_pong_easy_mode = on
		AppData.save_settings())
	$UI.add_child(easy_btn)

func _get_ball_path_points() -> PackedVector2Array:
	if _ball_vx <= 0.0: return PackedVector2Array()
	var pts: Array[Vector2] = []
	var x:   float = _ball_x
	var y:   float = _ball_y
	var vy:  float = _ball_vy
	var tx:  float = PLAYER_X - _player_w * 0.5
	pts.append(Vector2(x, y))
	for _b in 12:
		if x >= tx: break
		var ttc:    float = (tx - x) / _ball_vx
		var t_wall: float = INF
		if vy < 0.0:
			t_wall = (GAME_TOP - y) / vy
		elif vy > 0.0:
			t_wall = (GAME_BOTTOM - y) / vy
		if t_wall <= 0.001 or t_wall >= ttc:
			pts.append(Vector2(tx, y + vy * ttc))
			break
		x += _ball_vx * t_wall
		y += vy * t_wall
		pts.append(Vector2(x, y))
		vy = -vy
	return PackedVector2Array(pts)

func _path_pt(segs: Array, lengths: Array, dist: float) -> Vector2:
	var cum: float = 0.0
	for k in segs.size():
		if dist <= cum + lengths[k]:
			var t: float = (dist - cum) / maxf(lengths[k], 0.001)
			return (segs[k][0] as Vector2).lerp(segs[k][1] as Vector2, t)
		cum += lengths[k]
	return segs[-1][1] as Vector2

func _update_prediction_line() -> void:
	if _pred_segs.is_empty(): return
	if not AppData.ping_pong_easy_mode or _ball_vx <= 0.0 or _state != State.MOVE:
		for seg in _pred_segs: seg.visible = false
		return
	var path: PackedVector2Array = _get_ball_path_points()
	if path.size() < 2:
		for seg in _pred_segs: seg.visible = false
		return
	var p_segs:  Array = []
	var lengths: Array = []
	var total:   float = 0.0
	for k in range(path.size() - 1):
		var l: float = path[k].distance_to(path[k + 1])
		p_segs.append([path[k], path[k + 1]])
		lengths.append(l)
		total += l
	if total < 0.001:
		for seg in _pred_segs: seg.visible = false
		return
	const DASH: float = 14.0
	const GAP:  float = 8.0
	var d: float = 0.0
	var i: int   = 0
	while d < total and i < _pred_segs.size():
		var d_end: float = minf(d + DASH, total)
		(_pred_segs[i] as Line2D).points  = PackedVector2Array([
			_path_pt(p_segs, lengths, d),
			_path_pt(p_segs, lengths, d_end)])
		(_pred_segs[i] as Line2D).visible = true
		i += 1
		d += DASH + GAP
	while i < _pred_segs.size():
		(_pred_segs[i] as Line2D).visible = false
		i += 1

func _process(delta: float) -> void:
	_tick(delta)
	_refresh_ui()
	_update_log_state()
	_update_prediction_line()
func _tick(delta: float) -> void:
	var playing := (_state != State.WAITING and _state != State.PAUSED
					and _state != State.STOP  and _state != State.DONE
					and _state != State.SCORE_FLASH)
	if playing and _time_left > 0.0:
		_time_left -= delta

	match _state:
		State.WAITING:
			if _game_started: _state = State.START

		State.START:
			_begin_game()
			_state = State.MOVE

		State.MOVE:
			var ty: float = angle_to_screen_y(PlutoComm.angle)
			if Input.is_key_pressed(KEY_UP):   ty = _player_y - 420.0 * delta
			elif Input.is_key_pressed(KEY_DOWN): ty = _player_y + 420.0 * delta
			_player_y = clamp(ty, GAME_TOP + _player_h * 0.5, GAME_BOTTOM - _player_h * 0.5)

			if _ball_vx < 0.0:
				var ey_target: float = clamp(_ball_y, GAME_TOP + _enemy_h * 0.5, GAME_BOTTOM - _enemy_h * 0.5)
				_enemy_y = clamp(_enemy_y + clamp(ey_target - _enemy_y, -_enemy_speed * delta, _enemy_speed * delta),
								 GAME_TOP + _enemy_h * 0.5, GAME_BOTTOM - _enemy_h * 0.5)

			if _use_aan and _aan != null:
				if _ball_vx > 0.0:
					if not _aan_trial_set:
						_aan_trial_set = true
						var pred_y: float = _predict_ball_y_at_player()
						var ttc: float    = max(0.1, (PLAYER_X - _ball_x) / _ball_vx)
						_aan.set_new_trial_details(PlutoComm.angle, _screen_y_to_angle(pred_y), ttc, 10.0)
				else:
					_aan_trial_set = false
				_aan.update(PlutoComm.angle, delta, false)
				if _aan.state_change: _update_pluto_aan_target()

			# Swept paddle collision: compute exact hit time so ball never tunnels inside paddle
			var _moved: bool = false
			if _ball_vx > 0.0:
				var paddle_left: float = PLAYER_X - _player_hw
				var t_hit: float = (paddle_left - (_ball_x + _ball_sz * 0.5)) / _ball_vx
				if t_hit >= 0.0 and t_hit <= delta:
					var hit_y: float = _ball_y + _ball_vy * t_hit
					if abs(hit_y - _player_y) < (_player_hh + _ball_sz * 0.5):
						_ball_x   = paddle_left - _ball_sz * 0.5
						_ball_y   = hit_y
						_ball_vx  = -abs(_ball_vx)
						_ball_vy += (hit_y - _player_y) * 2.5
						_ball_vy  = clamp(_ball_vy, -_ball_speed * 1.2, _ball_speed * 1.2)
						_ball_x  += _ball_vx * (delta - t_hit)
						_ball_y  += _ball_vy * (delta - t_hit)
						n_success += 1
						_bounce_sfx.pitch_scale = 1.2
						_bounce_sfx.play()
						_moved = true
			elif _ball_vx < 0.0:
				var paddle_right: float = ENEMY_X + _enemy_hw
				var t_hit: float = (paddle_right - (_ball_x - _ball_sz * 0.5)) / _ball_vx
				if t_hit >= 0.0 and t_hit <= delta:
					var hit_y: float = _ball_y + _ball_vy * t_hit
					if abs(hit_y - _enemy_y) < (_enemy_hh + _ball_sz * 0.5):
						_ball_x   = paddle_right + _ball_sz * 0.5
						_ball_y   = hit_y
						_ball_vx  = abs(_ball_vx)
						_ball_vy += (hit_y - _enemy_y) * 2.5
						_ball_vy  = clamp(_ball_vy, -_ball_speed * 1.2, _ball_speed * 1.2)
						_ball_x  += _ball_vx * (delta - t_hit)
						_ball_y  += _ball_vy * (delta - t_hit)
						n_targets += 1
						_bounce_sfx.pitch_scale = 1.0
						_bounce_sfx.play()
						_moved = true
			if not _moved:
				_ball_x += _ball_vx * delta
				_ball_y += _ball_vy * delta

			

			if _ball_y - _ball_sz * 0.5 < GAME_TOP:
				_ball_y  = GAME_TOP + _ball_sz * 0.5
				_ball_vy = abs(_ball_vy)
			elif _ball_y + _ball_sz * 0.5 > GAME_BOTTOM:
				_ball_y  = GAME_BOTTOM - _ball_sz * 0.5
				_ball_vy = -abs(_ball_vy)

			if _ball_x + _ball_sz * 0.5 > GAME_RIGHT:
				n_failure += 1
				_cpu_score += 1
				_lose_sfx.play()
				_flash_rect.color   = Color(0.9, 0.1, 0.1, 0.3)
				_flash_rect.visible = true
				_flash_timer = 0.55
				_state = State.SCORE_FLASH
			elif _ball_x + _ball_sz * 0.5 < GAME_LEFT:
				_player_score += 1
				_win_sfx.play()
				_flash_rect.color   = Color(0.1, 0.85, 0.3, 0.25)
				_flash_rect.visible = true
				_flash_timer = 0.4
				_state = State.SCORE_FLASH

			_update_paddle_positions()

			if _time_left <= 0.0:
				_state = State.STOP

		State.SCORE_FLASH:
			_flash_timer -= delta
			if _flash_timer <= 0.0:
				_flash_rect.visible = false
				_enemy_y = (GAME_TOP + GAME_BOTTOM) * 0.5
				_aan_trial_set = false
				_reset_ball()
				_state = State.MOVE if _time_left > 0.0 else State.STOP

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

func _speed_bump() -> float:
	return clamp(1.0 + float(n_success) * 0.015, 1.0, 1.35)

func _predict_ball_y_at_player() -> float:
	if _ball_vx <= 0.0: return _ball_y
	var dx:      float = PLAYER_X - _ball_x
	var ttc:     float = dx / _ball_vx
	var pred_y:  float = _ball_y + _ball_vy * ttc
	var range_h: float = GAME_BOTTOM - GAME_TOP
	pred_y -= GAME_TOP
	pred_y = fmod(abs(pred_y), range_h * 2.0)
	if pred_y > range_h: pred_y = range_h * 2.0 - pred_y
	return pred_y + GAME_TOP

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
	_player_score = 0; _cpu_score = 0
	_wait_panel.visible  = false
	_speed_panel.visible = false
	_music.play()
	AppData.start_new_trial()
	_setup_aan()

func _setup_aan() -> void:
	var mech: String = AppData.mechanism_name
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
	_music.stop()
	_save_speed()
	var today_prior := DataManager.read_today_hits(AppData.selected_game_name, AppData.mechanism_name)
	var today_total := today_prior + n_success
	_earned_star = AppData.selected_game != null and today_total > _yesterday_hits \
		and today_total > 0 and AppData.selected_game.today_stars == 0
	if _earned_star:
		AppData.selected_game.update_cumulative_stars()
	AppData.stop_trial(n_targets, n_success, n_failure)
	_final_lbl.text     = "You: %d  |  CPU: %d\nPress PLUTO button to play again" % [n_success, n_targets]
	_over_panel.visible  = true
	_speed_panel.visible = false
	if _earned_star:
		await get_tree().create_timer(0.6).timeout
		_show_celebration(today_total)

# ── UI ────────────────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	_timer_lbl.text = "Time: %02d s" % maxi(0, ceili(_time_left))
	_score_lbl.text = "You %d  :  %d CPU" % [n_success, n_targets]

func _update_log_state() -> void:
	AppData.log_player_x   = PLAYER_X
	AppData.log_player_y   = _player_y
	AppData.log_target_x   = _ball_x
	AppData.log_target_y   = _ball_y
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
		for n in _arom_nodes: n.visible = _speed_panel.visible
		_refresh_speed_label()

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
	_music.stop()
	if not _game_finished:
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
