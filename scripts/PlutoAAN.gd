extends RefCounted

# ── Constants ────────────────────────────────────────────────────────────────
const MIN_AVG_SPEED: float        = 10.0
const MAX_AVG_SPEED: float        = 20.0
const MIN_REACH_TIME: float       = 1.0
const BOUNDARY: float             = 0.9
const DEFAULT_CTRL_BOUND: float   = 0.6
const MAX_CTRL_BOUND: float       = 1.0
const MIN_CTRL_BOUND: float       = 0.16
const NO_MOVE_THRESHOLD_SEC: float = 1.5
const POS_TOLERANCE: float        = 0.1

enum State {
	NONE,
	NEW_TRIAL_TARGET_SET,
	AROM_MOVING,
	RELAX_TO_AROM,
	ASSIST_TO_TARGET_IN_BOUNDARY,
	ASSIST_TO_TARGET_AT_BOUNDARY,
	IDLE
}

# ── Public ───────────────────────────────────────────────────────────────────
var initial_position: float = 0.0
var target_position:  float = 0.0
var max_duration:     float = 0.0
var mech_speed:       float = 20.0
var trial_running:    bool  = false
var trial_time:       float = 0.0
var state_change:     bool  = false
var arom: Array = []   # [min, max] in degrees
var prom: Array = []   # [min, max] in degrees

# ── State ─────────────────────────────────────────────────────────────────────
var _state: State = State.NONE
var state: State:
	get: return _state
	set(v):
		state_change = _state != v
		_state = v

# ── AAN target buffer ──────────────────────────────────────────────────────
# [0]=flag(999=invalid), [1]=t0, [2]=t0_time, [3]=tgt, [4]=duration
var _target: Array = [999.0, 0.0, 0.0, 0.0, 0.0]

# ── Position/time queues (keep last 1 second) ─────────────────────────────
var _pos_q:  Array = []
var _time_q: Array = []

# ── No-movement detection ─────────────────────────────────────────────────
var _check_vol_mov:      bool  = false
var _last_checked_pos:   float = NAN
var _no_move_elapsed:    float = 0.0
var _no_move_running:    bool  = false
var _active_range_init:  float = 0.0
var _set_ar_init:        bool  = false

# ── Public API ────────────────────────────────────────────────────────────────

func set_new_trial_details(actual: float, target: float, max_dur: float, mechspd: float) -> void:
	initial_position = actual
	target_position  = target
	max_duration     = max_dur
	mech_speed       = mechspd
	trial_running    = true
	_pos_q.append(actual)
	_time_q.append(trial_time)
	state_change = true
	state = State.NEW_TRIAL_TARGET_SET

func reset_trial() -> void:
	initial_position    = 0.0
	target_position     = 0.0
	max_duration        = 0.0
	trial_running       = false
	_target[0]          = 999.0
	_pos_q.clear()
	_time_q.clear()
	trial_time          = 0.0
	_set_ar_init        = false
	_active_range_init  = 0.0
	_reset_no_move()
	state = State.NONE

# Returns [t0, t0_time, tgt, duration] or null if no valid target.
func get_new_aan_target():
	if _target[0] == 999.0:
		return null
	return [_target[1], _target[2], _target[3], _target[4]]

func update(actual: float, del_t: float, trial_done: bool) -> void:
	state_change = false

	if state == State.NONE:
		return

	trial_time += del_t
	_update_queues(actual, trial_time)

	match state:
		State.NEW_TRIAL_TARGET_SET:
			_check_vol_mov    = false
			_last_checked_pos = NAN
			_reset_no_move()
			match _get_target_type():
				0, 2:  # InAromFromArom, InPromFromArom
					if _is_cpm_mode():
						state = State.ASSIST_TO_TARGET_AT_BOUNDARY
						_gen_assist_to_target(actual, false)
					else:
						state = State.AROM_MOVING
				1, 3:  # InAromFromProm, InPromFromPromCrossArom
					if _is_cpm_mode():
						state = State.ASSIST_TO_TARGET_AT_BOUNDARY
						_gen_assist_to_target(actual, false)
					else:
						state = State.RELAX_TO_AROM
						_gen_relax_to_arom(actual)
				4:     # InPromFromPromNoCrossArom
					state = State.ASSIST_TO_TARGET_AT_BOUNDARY
					_gen_assist_to_target(actual, false)

		State.AROM_MOVING:
			if trial_done:
				state = State.IDLE
				return
			if not _set_ar_init:
				_active_range_init = actual
				_check_vol_mov    = false
				_last_checked_pos = NAN
				_reset_no_move()
				_set_ar_init = true
			if _check_no_movement(actual, _active_range_init, del_t):
				return
			var _dir: int  = signi(int(target_position - initial_position))
			var _arompos: float = (actual - arom[0]) / (arom[1] - arom[0])
			if (_dir > 0 and _arompos >= BOUNDARY) or (_dir < 0 and _arompos <= (1.0 - BOUNDARY)):
				state = State.ASSIST_TO_TARGET_AT_BOUNDARY
				_gen_assist_to_target(actual, true)

		State.RELAX_TO_AROM:
			if _set_ar_init:
				_check_vol_mov    = false
				_reset_no_move()
				_last_checked_pos = NAN
				_set_ar_init      = false
			if _is_actual_in_arom(actual):
				state = State.AROM_MOVING
				_target[0] = 999.0

		State.ASSIST_TO_TARGET_AT_BOUNDARY:
			if trial_done:
				if _is_cpm_mode():
					state = State.IDLE
				else:
					_gen_relax_to_arom(actual)
					state = State.RELAX_TO_AROM

		State.ASSIST_TO_TARGET_IN_BOUNDARY:
			if trial_done:
				if _is_cpm_mode():
					state = State.IDLE
				else:
					_gen_relax_to_arom(actual)
					state = State.RELAX_TO_AROM

		State.IDLE:
			pass

# ── Private helpers ───────────────────────────────────────────────────────────

func _is_cpm_mode() -> bool:
	if arom.size() < 2:
		return false
	return abs(arom[1] - arom[0]) <= 5.0

# Returns: 0=InAromFromArom, 1=InAromFromProm, 2=InPromFromArom,
#          3=InPromFromPromCrossArom, 4=InPromFromPromNoCrossArom, 5=None
func _get_target_type() -> int:
	if not trial_running:
		return 5
	var init_in_arom: bool = _is_actual_in_arom(initial_position)
	if target_position >= arom[0] and target_position <= arom[1]:
		return 0 if init_in_arom else 1
	if init_in_arom:
		return 2
	if (target_position < arom[0] and initial_position < arom[0]) \
	or (target_position > arom[1] and initial_position > arom[1]):
		return 4
	return 3

func _is_actual_in_arom(actual: float) -> bool:
	return actual >= arom[0] and actual <= arom[1]

func _get_nearest_arom_edge(actual: float) -> float:
	return arom[0] if abs(actual - arom[0]) < abs(actual - arom[1]) else arom[1]

func _gen_relax_to_arom(actual: float) -> void:
	var edge: float = _get_nearest_arom_edge(actual)
	_target[0] = 0.0
	_target[1] = actual
	_target[2] = 0.0
	_target[3] = edge
	_target[4] = clamp(abs(edge - actual) / mech_speed, MIN_REACH_TIME, max_duration)

func _gen_assist_to_target(actual: float, from_arom: bool) -> void:
	var elapsed_speed: float = abs(actual - initial_position) / max(trial_time, 0.001)
	var avg_spd: float = clamp(elapsed_speed, MIN_AVG_SPEED, mech_speed)
	var max_dur: float = clamp(abs(target_position - actual) / avg_spd, MIN_REACH_TIME, max_duration)
	_target[0] = 0.0
	_target[1] = actual
	_target[2] = -0.25 * max_dur if from_arom else 0.0
	_target[3] = target_position
	_target[4] = max_dur

func _check_no_movement(actual: float, arom_init_pos: float, del_t: float) -> bool:
	var arom_range: float = arom[1] - arom[0]
	if arom_range <= 0.0:
		return false

	var gate_dist: float      = 0.25 * arom_range
	var moved_from_init: float = abs(actual - arom_init_pos)

	if not _check_vol_mov:
		if moved_from_init + POS_TOLERANCE >= gate_dist:
			_check_vol_mov    = true
			_reset_no_move()
			_last_checked_pos = actual
		else:
			_reset_no_move()
			_last_checked_pos = actual
			return false

	if is_nan(_last_checked_pos):
		_last_checked_pos = actual

	if abs(actual - _last_checked_pos) <= POS_TOLERANCE:
		_no_move_running = true
		_no_move_elapsed += del_t
		if _no_move_elapsed >= NO_MOVE_THRESHOLD_SEC:
			state = State.ASSIST_TO_TARGET_IN_BOUNDARY
			_gen_assist_to_target(actual, true)
			_check_vol_mov = false
			_reset_no_move()
			return true
	else:
		_reset_no_move()
		_last_checked_pos = actual

	return false

func _reset_no_move() -> void:
	_no_move_running = false
	_no_move_elapsed = 0.0

func _update_queues(actual: float, t: float) -> void:
	if _time_q.size() > 0 and (t - _time_q[0]) >= 1.0:
		_pos_q.pop_front()
		_time_q.pop_front()
	_pos_q.append(actual)
	_time_q.append(t)
