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
# The bar spans the passive range of motion (PROM) of this mechanism.
var _bar_lo:                 float = -1.0
var _bar_hi:                 float = 1.0
var _reach_fill:             Panel = null
var _range_info:             Label = null

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

	_build_bar()
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

	# bar range = passive range of motion (falls back to the whole mechanism range when none is saved)
	_bar_lo = -absf(_ang_limit)
	_bar_hi = absf(_ang_limit)
	if _rom != null and _rom.is_prom_set and _rom.prom_max - _rom.prom_min > 1.0:
		_bar_lo = _rom.prom_min
		_bar_hi = _rom.prom_max

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
	_refresh_state_look(delta)
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

# ── State indication: chip + card colour + attention banner ────────────────────────────────────────

var _chip: Label
var _chip_sig := ""
var _banner_t := 0.0

func _flat(fill: Color, border: Color, radius: int, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

## READY (grey) -> ASSESSING with the two ends ticked off (amber) -> COMPLETE (solid green card).
func _refresh_state_look(delta: float) -> void:
	var panel := $MainPanel as Control
	if _chip == null:
		_chip = Label.new()
		_chip.set_meta("arcade_authored_control", true)
		_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_chip.offset_left = -330.0; _chip.offset_right = -20.0
		_chip.offset_top = 16.0; _chip.offset_bottom = 50.0
		_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_chip.add_theme_font_size_override("font_size", 16)
		_chip.z_index = 2
		panel.add_child(_chip)
	var mode := "ready"
	var text := "READY"
	if _state == AssistState.ASSESS:
		if _reached_positive and _reached_negative:
			mode = "done"; text = "AAN COMPLETE  ✓"
		else:
			mode = "busy"
			text = "ASSESSING   max %s   min %s" % ["✓" if _reached_positive else "…", "✓" if _reached_negative else "…"]
	var sig := mode + text
	if sig != _chip_sig:
		_chip_sig = sig
		var colors: Array = {
			"ready": [Color("e4edf3"), Color("3d556b"), Color("c4d4da")],
			"busy": [Color("ffe7b0"), Color("7a4a00"), Color("e3b04a")],
			"done": [Color("1f9d55"), Color.WHITE, Color("167a41")],
		}[mode]
		_chip.text = text
		_chip.add_theme_color_override("font_color", colors[1])
		_chip.add_theme_stylebox_override("normal", _flat(colors[0], colors[2], 17, 1))
		var card := _flat(Color("e2f4e8") if mode == "done" else Color("fbfdfef2"), Color("1f9d55") if mode == "done" else (Color("087f83") if mode == "busy" else Color("c4dcdf")), 18, 3 if mode != "ready" else 1)
		card.shadow_color = Color(0.1, 0.25, 0.3, 0.14)
		card.shadow_size = 8
		panel.add_theme_stylebox_override("panel", card)
		instruction_label.add_theme_color_override("font_color", Color("0b7a3d") if mode == "done" else (Color("8a5300") if mode == "busy" else Color("1a2e44")))
		instruction_label.modulate = Color.WHITE
	# the "Press PLUTO button ..." line becomes a pulsing amber banner
	_banner_t += delta
	var has_prompt := inst1_label.text.strip_edges() != ""
	if has_prompt:
		var pulse := 0.5 + 0.5 * sin(_banner_t * 4.0)
		var banner := _flat(Color("ffbf3c").lerp(Color("ffd978"), pulse), Color("c98400"), 14, 2)
		banner.content_margin_top = 4; banner.content_margin_bottom = 4
		inst1_label.add_theme_stylebox_override("normal", banner)
		inst1_label.add_theme_color_override("font_color", Color("3a2400"))
		inst1_label.add_theme_font_size_override("font_size", 19)
	else:
		inst1_label.remove_theme_stylebox_override("normal")

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
	AppData.assess_from_games = false
	if AppData.is_plan_setup:
		get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")

func _bar_fraction(angle: float) -> float:
	# A missing/zero range must never produce NaN scene coordinates.
	var span := _bar_hi - _bar_lo
	if is_finite(span) and span > 0.001 and is_finite(angle):
		return clampf((angle - _bar_lo) / span, 0.0, 1.0)
	return 0.5

func _cursor_x(angle: float, width: float) -> float:
	return slider_track.position.x + _bar_fraction(angle) * maxf(0, slider_track.size.x - width)

func _update_curr_cursor(angle: float) -> void:
	curr_cursor.position.x = _cursor_x(angle, curr_cursor.size.x)

func _update_min_max_cursors() -> void:
	if _reach_fill:
		var x0 := slider_track.position.x + _bar_fraction(_tmin) * slider_track.size.x
		var x1 := slider_track.position.x + _bar_fraction(_tmax) * slider_track.size.x
		_reach_fill.position = Vector2(x0, slider_track.position.y)
		_reach_fill.size = Vector2(maxf(x1 - x0, 0.0), slider_track.size.y)
	min_cursor.position.x = _cursor_x(_tmin, min_cursor.size.x)
	max_cursor.position.x = _cursor_x(_tmax, max_cursor.size.x)
	min_cursor.get_node("Value").text = "MIN %.0f°" % _tmin
	max_cursor.get_node("Value").text = "MAX %.0f°" % _tmax
	for cursor in [min_cursor, max_cursor]:
		var label: Label = cursor.get_node("Value")
		label.position.x = clampf(cursor.position.x + 18, 0, slider_track.size.x - label.size.x) - cursor.position.x

func _setup_labels() -> void:
	var mech_idx = AppData.mechanism_index - 1
	var is_hoc   = AppData.mechanism_name == "HOC"
	if mech_idx >= 0 and mech_idx < DIRECTION_TEXT.size():
		left_label.text  = DIRECTION_TEXT[mech_idx][0]
		right_label.text = DIRECTION_TEXT[mech_idx][1]
	center_label.visible = false
	center_label.text    = ""
	# the end labels give the passive range the bar covers
	var unit := "cm" if is_hoc else "°"
	var lo_v := AppData.hoc_to_cm(_bar_lo) if is_hoc else _bar_lo
	var hi_v := AppData.hoc_to_cm(_bar_hi) if is_hoc else _bar_hi
	left_label.text  = "%s  %.0f%s" % [left_label.text, lo_v, unit]
	right_label.text = "%.0f%s  %s" % [hi_v, unit, right_label.text]
	if _range_info:
		_range_info.text = "Passive range of motion:  %.0f%s  to  %.0f%s   (%.0f%s)" % [lo_v, unit, hi_v, unit, hi_v - lo_v, unit]

## Lay the bar out across the panel, style it, and add the "reached" fill and the passive-range caption.
func _build_bar() -> void:
	var panel := $MainPanel as Control
	var bar := slider_track.get_parent() as Control
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bar.anchor_left = .04; bar.anchor_right = .96
	bar.anchor_top = .36; bar.anchor_bottom = .36
	bar.offset_left = 0; bar.offset_right = 0; bar.offset_top = 0; bar.offset_bottom = 80
	slider_track.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	slider_track.anchor_right = 1.0
	slider_track.offset_left = 0; slider_track.offset_right = 0
	slider_track.offset_top = 28; slider_track.offset_bottom = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d3e6e8")
	style.set_corner_radius_all(11)
	style.set_border_width_all(1)
	style.border_color = Color("9fc3c6")
	slider_track.add_theme_stylebox_override("panel", style)
	_reach_fill = Panel.new()
	_reach_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reach_fill.set_meta("arcade_authored_control", true)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.03, 0.5, 0.52, 0.55)
	fill.set_corner_radius_all(11)
	_reach_fill.add_theme_stylebox_override("panel", fill)
	bar.add_child(_reach_fill)
	bar.move_child(_reach_fill, slider_track.get_index() + 1)
	for label in [left_label, right_label]:
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		label.anchor_top = .36; label.anchor_bottom = .36
		label.offset_top = 90; label.offset_bottom = 118
		label.add_theme_font_size_override("font_size", 16)
	left_label.anchor_left = .04; left_label.anchor_right = .40
	left_label.offset_left = 0; left_label.offset_right = 0
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right_label.anchor_left = .60; right_label.anchor_right = .96
	right_label.offset_left = 0; right_label.offset_right = 0
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_range_info = Label.new()
	_range_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_range_info.anchor_left = .04; _range_info.anchor_right = .96
	_range_info.anchor_top = .36; _range_info.anchor_bottom = .36
	_range_info.offset_top = 132; _range_info.offset_bottom = 164
	_range_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_info.add_theme_font_size_override("font_size", 20)
	_range_info.set_meta("arcade_authored_control", true)
	panel.add_child(_range_info)
	inst1_label.anchor_top = .24; inst1_label.anchor_bottom = .24
	inst1_label.offset_top = 0; inst1_label.offset_bottom = 32
	inst1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reading := angle_label
	reading.anchor_top = .62; reading.anchor_bottom = .62
	reading.offset_top = 0; reading.offset_bottom = 90
	var unit_label := panel.get_node_or_null("AngleUnitLabel") as Control
	if unit_label:
		unit_label.anchor_top = .62; unit_label.anchor_bottom = .62
		unit_label.offset_top = 94; unit_label.offset_bottom = 118
	# keep the button clear of the device-status badge in the top-right corner
	assess_button.offset_left = -200
	assess_button.offset_right = -76

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
