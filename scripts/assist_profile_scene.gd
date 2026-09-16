extends Control

# ── Header ────────────────────────────────────────────────────────────
@onready var mech_label:        Label  = $HeaderPanel/MechLabel
@onready var assess_button:     Button = $HeaderPanel/AssessButton

# ── Main panel ────────────────────────────────────────────────────────
@onready var instruction_label: Label   = $MainPanel/InstructionLabel
@onready var inst1_label:       Label   = $MainPanel/Inst1Label
@onready var angle_label:       Label   = $MainPanel/AngleLabel
@onready var slider_track:      Control = $MainPanel/SliderContainer/SliderTrack
@onready var min_cursor:        Control = $MainPanel/SliderContainer/MinCursor
@onready var max_cursor:        Control = $MainPanel/SliderContainer/MaxCursor
@onready var curr_cursor:       Control = $MainPanel/SliderContainer/CurrentCursor
@onready var left_label:        Label   = $MainPanel/LeftLabel
@onready var center_label:      Label   = $MainPanel/CenterLabel
@onready var right_label:       Label   = $MainPanel/RightLabel

const DIRECTION_TEXT = [
	["Flexion",    "Extension"],
	["Radial Dev", "Ulnar Dev"],
	["Pronation",  "Supination"],
	["Open",       "Open"],
	["",           ""],
	["",           ""],
]

enum AssistState { INIT, ASSESS }
var _state: AssistState = AssistState.INIT

var _is_button_pressed:      bool  = false
var _run_once1:              bool  = false
var _reached_positive:       bool  = false
var _reached_negative:       bool  = false
var _going_positive:         bool  = true
var _once_reached:           bool  = false
var _first_positive_start:   bool  = true
var _first_negative_start:   bool  = true

var _torque:                 float = 0.0
var _stop_clock:             float = 0.0
var _trail_duration:         float = 1.0
var _stuck_timer:            float = 0.0
var _positive_timer:         float = 0.0
var _negative_timer:         float = 0.0
var _positive_stuck_attempts: int  = 0
var _negative_stuck_attempts: int  = 0
var _max_angle:              float = 0.0
var _min_angle:              float = 0.0
var _prev_angle:             float = 0.0

var _target_positive_end:    float = 0.0
var _target_negative_end:    float = 0.0
var _ang_limit:              float = 0.0
var _tmin:                   float = 0.0
var _tmax:                   float = 0.0

const ENDPOINT_TOLERANCE:    float = 5.0
const STUCK_THRESHOLD_TIME:  float = 3.0
const MAX_STUCK_ATTEMPTS:    int   = 2
const MAX_DIR_DURATION:      float = 15.0
const UPDATE_INTERVAL:       float = 0.05

var _assess_timer: float = 0.0

func _ready() -> void:
	mech_label.text = _get_mech_display_name()

	assess_button.pressed.connect(func():
		PlutoComm.set_control_type("NONE")
		get_tree().change_scene_to_file("res://scenes/AssessmentScene.tscn")
	)

	EventBus.button_released.connect(_on_pluto_button)
	EventBus.new_sensor_data.connect(_on_data)

	_initialize_assessment()

func _initialize_assessment() -> void:
	_run_once1               = false
	_torque                  = 0.0
	_going_positive          = true
	_reached_positive        = false
	_reached_negative        = false
	_once_reached            = false
	_first_positive_start    = true
	_first_negative_start    = true
	_stuck_timer             = 0.0
	_positive_stuck_attempts = 0
	_negative_stuck_attempts = 0
	_min_angle               = 0.0
	_max_angle               = 0.0
	_stop_clock              = 0.0
	_assess_timer            = 0.0
	_prev_angle              = PlutoComm.angle
	_state                   = AssistState.INIT

	if AppData.mechanism_name == "HOC":
		_ang_limit = float(AppData.calib_angle)
	else:
		_ang_limit = AppData.mech_offset

	var _rom = AppData.selected_mechanism.curr_rom if AppData.selected_mechanism != null else null
	_target_positive_end = _rom.prom_max if _rom != null else 0.0
	_target_negative_end = _rom.prom_min if _rom != null else 0.0

	_tmin = PlutoComm.angle
	_tmax = PlutoComm.angle

	_setup_labels()

	curr_cursor.visible = true
	min_cursor.visible  = true
	max_cursor.visible  = true

	instruction_label.modulate = Color(1.0, 0.5, 0.0)
	instruction_label.text     = ""
	inst1_label.text           = "Press PLUTO button to start the AAN"

func _process(delta: float) -> void:
	if not is_node_ready():
		return
	var angle = PlutoComm.angle
	angle_label.text = "Angle: %d" % int(angle)
	_update_curr_cursor(angle)
	_update_min_max_cursors()
	_run_state_machine(delta)

func _on_data() -> void:
	pass

func _on_pluto_button() -> void:
	_is_button_pressed = true

func _run_state_machine(delta: float) -> void:
	match _state:
		AssistState.INIT:
			curr_cursor.visible = true
			if _is_button_pressed:
				PlutoComm.set_control_type("TORQUE")
				_start_assessment()
				_is_button_pressed = false

		AssistState.ASSESS:
			if not _run_once1:
				instruction_label.modulate = Color(0.0, 1.0, 0.31, 0.7)
				_run_once1 = true

			_assess_timer += delta
			if _assess_timer >= UPDATE_INTERVAL:
				_assess_timer = 0.0
				_run_assessment_step()

			if _reached_positive and _reached_negative:
				PlutoComm.set_control_type("NONE")
				if _is_button_pressed:
					_save_and_proceed()
					_is_button_pressed = false

func _start_assessment() -> void:
	_state  = AssistState.ASSESS
	_tmin   = PlutoComm.angle
	_tmax   = PlutoComm.angle
	inst1_label.text = ""

func _run_assessment_step() -> void:
	if _reached_positive and _reached_negative:
		return

	var current_angle = PlutoComm.angle

	if current_angle < _tmin:
		_tmin = current_angle
	if current_angle > _tmax:
		_tmax = current_angle

	var delta_angle   = abs(current_angle - _prev_angle)
	var moving_toward = (
		(current_angle > _prev_angle) if _going_positive
		else (current_angle < _prev_angle)
	)
	if not moving_toward or delta_angle < 3.0:
		_stuck_timer += UPDATE_INTERVAL
	else:
		_stuck_timer = 0.0

	_stop_clock   += UPDATE_INTERVAL
	var time_frac  = clamp(_stop_clock / _trail_duration, 0.0, 1.0)
	var smooth_torq = _smooth_step(0.0, 1.0, time_frac)

	if _going_positive and not _reached_positive:
		_run_positive_step(current_angle, smooth_torq)
	elif not _reached_negative:
		_run_negative_step(current_angle, smooth_torq)

	_prev_angle = current_angle

func _run_positive_step(current_angle: float, smooth_torque: float) -> void:
	if _first_positive_start:
		_trail_duration       = 7.0
		_stop_clock           = 0.0
		_torque               = 0.0
		_once_reached         = false
		_first_positive_start = false
		_positive_timer       = 0.0

	_positive_timer += UPDATE_INTERVAL

	if _is_button_pressed and not _reached_positive:
		_is_button_pressed = false
		_reached_positive  = true
		_max_angle         = current_angle
		_torque            = 0.0
		_stop_clock        = 0.0
		PlutoComm.set_control_target(0.0)
		_going_positive    = false
		return

	if _positive_timer >= MAX_DIR_DURATION:
		_reached_positive = true
		_max_angle        = current_angle
		_torque           = 0.0
		PlutoComm.set_control_target(0.0)
		_stop_clock       = 0.0
		_going_positive   = false
		return

	if current_angle < _target_positive_end - ENDPOINT_TOLERANCE:
		if not _once_reached:
			_torque = smooth_torque
		if _stuck_timer > STUCK_THRESHOLD_TIME and _torque >= 0.99:
			_stuck_timer = 0.0
			_positive_stuck_attempts += 1
			_once_reached = true
		if _positive_stuck_attempts >= MAX_STUCK_ATTEMPTS:
			_reached_positive = true
			_max_angle        = current_angle
			_torque           = 0.0
			PlutoComm.set_control_target(0.0)
			_going_positive   = false
			return
		if _once_reached and current_angle > _prev_angle:
			_torque -= 0.1
		_torque = clamp(_torque, 0.0, 1.0)
		PlutoComm.set_control_target(_torque)
	else:
		_reached_positive = true
		_max_angle        = current_angle
		_stop_clock       = 0.0
		_torque           = 0.0
		PlutoComm.set_control_target(0.0)
		_going_positive   = false

func _run_negative_step(current_angle: float, _smooth_torque: float) -> void:
	if _first_negative_start:
		PlutoComm.set_control_target(0.0)
		_trail_duration       = 7.0
		_stop_clock           = 0.0
		_torque               = 0.0
		_once_reached         = false
		_first_negative_start = false
		_negative_timer       = 0.0

	_negative_timer += UPDATE_INTERVAL

	if _is_button_pressed and not _reached_negative:
		PlutoComm.set_control_type("NONE")
		_is_button_pressed = false
		_reached_negative  = true
		_min_angle         = current_angle
		_torque            = 0.0
		_show_completed()
		return

	if _negative_timer >= MAX_DIR_DURATION:
		PlutoComm.set_control_type("NONE")
		_reached_negative = true
		_min_angle        = current_angle
		_torque           = 0.0
		_show_completed()
		return

	if current_angle > _target_negative_end + ENDPOINT_TOLERANCE:
		var rev_smooth = -_smooth_step(
			0.0, 1.0, clamp(_stop_clock / _trail_duration, 0.0, 1.0)
		)
		if not _once_reached:
			_torque = rev_smooth
		if _stuck_timer > STUCK_THRESHOLD_TIME and _torque <= -0.99:
			_stuck_timer = 0.0
			_negative_stuck_attempts += 1
			_once_reached = true
		if _negative_stuck_attempts >= MAX_STUCK_ATTEMPTS:
			PlutoComm.set_control_type("NONE")
			_reached_negative = true
			_min_angle        = current_angle
			_torque           = 0.0
			_show_completed()
			return
		if _once_reached and current_angle < _prev_angle:
			_torque += 0.1
		_torque = clamp(_torque, -1.0, 0.0)
		PlutoComm.set_control_target(_torque)
	else:
		PlutoComm.set_control_type("NONE")
		_reached_negative = true
		_min_angle        = current_angle
		_torque           = 0.0
		_show_completed()

func _show_completed() -> void:
	instruction_label.modulate = Color(0.2, 0.85, 0.4, 0.8)
	instruction_label.text = (
		"APROM Reached both ends\nMin: %.1f° | Max: %.1f°"
		% [_min_angle, _max_angle]
	)
	inst1_label.text = "Press PLUTO button to move to game"

func _save_and_proceed() -> void:
	PlutoComm.set_control_type("NONE")
	if AppData.selected_mechanism != null:
		AppData.selected_mechanism.set_new_aprom(_min_angle, _max_angle)
		AppData.selected_mechanism.save_assessment_data()
	EventBus.assist_assessed.emit(_min_angle, _max_angle)
	if AppData.is_plan_setup:
		get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")

func _update_curr_cursor(angle: float) -> void:
	var tw = slider_track.size.x
	if tw == 0:
		return
	var t = (angle + _ang_limit) / (_ang_limit * 2.0)
	curr_cursor.position.x = (
		slider_track.position.x + clamp(t, 0.0, 1.0) * tw - curr_cursor.size.x / 2.0
	)

func _update_min_max_cursors() -> void:
	var tw = slider_track.size.x
	if tw == 0:
		return
	var min_t = (_tmin + _ang_limit) / (_ang_limit * 2.0)
	var max_t = (_tmax + _ang_limit) / (_ang_limit * 2.0)
	min_cursor.position.x = (
		slider_track.position.x + clamp(min_t, 0.0, 1.0) * tw - min_cursor.size.x / 2.0
	)
	max_cursor.position.x = (
		slider_track.position.x + clamp(max_t, 0.0, 1.0) * tw - max_cursor.size.x / 2.0
	)

func _setup_labels() -> void:
	var mech_idx = AppData.mechanism_index - 1
	var is_hoc   = AppData.mechanism_name == "HOC"
	if mech_idx >= 0 and mech_idx < DIRECTION_TEXT.size():
		left_label.text  = DIRECTION_TEXT[mech_idx][0]
		right_label.text = DIRECTION_TEXT[mech_idx][1]
	center_label.visible = is_hoc
	center_label.text    = "Closed" if is_hoc else ""

func _get_mech_display_name() -> String:
	var names = {
		"WFE":  "WRIST FLEX/EXTENSION",
		"WURD": "WRIST ULNAR RADIAL DEVIATION",
		"FPS":  "FOREARM PRONATION SUPINATION",
		"HOC":  "HAND OPENING CLOSING",
		"FME1": "FUNCTIONAL MECHANISM 1",
		"FME2": "FUNCTIONAL MECHANISM 2",
	}
	return names.get(AppData.mechanism_name, AppData.mechanism_name)

func _smooth_step(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _exit_tree() -> void:
	PlutoComm.set_control_type("NONE")
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)
	if EventBus.new_sensor_data.is_connected(_on_data):
		EventBus.new_sensor_data.disconnect(_on_data)
