extends Control

# ── Header ────────────────────────────────────────────────────────────
@onready var mech_label:        Label  = $HeaderPanel/MechLabel
@onready var exit_button:       Button = $HeaderPanel/ExitButton

# ── AROM panel ────────────────────────────────────────────────────────
@onready var arom_track:        Control = $AromPanel/SliderContainer/SliderTrack
@onready var arom_min_cursor:   Control = $AromPanel/SliderContainer/MinCursor
@onready var arom_max_cursor:   Control = $AromPanel/SliderContainer/MaxCursor
@onready var arom_curr_cursor:  Control = $AromPanel/SliderContainer/CurrentCursor
@onready var arom_left_label:   Label   = $AromPanel/LeftLabel
@onready var arom_center_label: Label   = $AromPanel/CenterLabel
@onready var arom_right_label:  Label   = $AromPanel/RightLabel
@onready var arom_angle_label:  Label   = $AromPanel/AngleLabel
@onready var arom_status:       Label   = $AromPanel/StatusLabel
@onready var arom_prev_label:   Label   = $AromPanel/PrevAromLabel
@onready var arom_start_btn:    Button  = $AromPanel/StartButton
@onready var arom_next_btn:     Button  = $AromPanel/NextButton

# ── PROM panel ────────────────────────────────────────────────────────
@onready var prom_track:        Control = $PromPanel/SliderContainer/SliderTrack
@onready var prom_min_cursor:   Control = $PromPanel/SliderContainer/MinCursor
@onready var prom_max_cursor:   Control = $PromPanel/SliderContainer/MaxCursor
@onready var prom_curr_cursor:  Control = $PromPanel/SliderContainer/CurrentCursor
@onready var prom_left_label:   Label   = $PromPanel/LeftLabel
@onready var prom_center_label: Label   = $PromPanel/CenterLabel
@onready var prom_right_label:  Label   = $PromPanel/RightLabel
@onready var prom_angle_label:  Label   = $PromPanel/AngleLabel
@onready var prom_status:       Label   = $PromPanel/StatusLabel
@onready var prom_start_btn:    Button  = $PromPanel/StartButton
@onready var prom_next_btn:     Button  = $PromPanel/NextButton

# ── Bottom buttons ─────────────────────────────────────────────────────
@onready var redo_btn:        Button = $BottomButtons/RedoAromButton
@onready var change_mech_btn: Button = $BottomButtons/ChangeMechButton

const DIRECTION_TEXT = [
	["Flexion",    "Extension"],
	["Radial Dev", "Ulnar Dev"],
	["Pronation",  "Supination"],
	["Open",       "Open"],
	["",           ""],
	["",           ""],
]

enum AromState { WAITING, ASSESS }
var _arom_state: AromState = AromState.WAITING

enum PromState { INIT, ASSESS }
var _prom_state: PromState = PromState.INIT

var _arom_selected: bool = true
var _prom_selected: bool = false

var _ang_limit:         float = 78.0
var _is_button_pressed: bool  = false

const MIN_AROM_RANGE:    float = 5.0
const THRESHOLD_MIN:     float = 5.0
const THRESHOLD_MAX:     float = 15.0
const THRESHOLD_PERCENT: float = 0.15

var _arom_tmin:      float = 0.0
var _arom_tmax:      float = 0.0
var _arom_last_angle: float = 0.0
var _forward_limit:  float = 0.0
var _backward_limit: float = 0.0
var _dir_threshold:  float = 2.0

var _prom_tmin:       float = 0.0
var _prom_tmax:       float = 0.0
var _prom_run_once:   bool  = false
var _prom_restarting: bool  = false

func _ready() -> void:
	PlutoComm.set_control_type("NONE")

	if AppData.mechanism_name == "HOC":
		_ang_limit = AppData.calib_angle + 10.0
	else:
		_ang_limit = AppData.mech_offset + 10.0

	_setup_labels()
	_select_arom()

	exit_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")
	)
	change_mech_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")
	)
	arom_start_btn.pressed.connect(_on_arom_start_click)
	arom_next_btn.pressed.connect(_on_arom_next_click)
	prom_start_btn.pressed.connect(_on_prom_start_click)
	prom_next_btn.pressed.connect(_on_prom_next_click)
	redo_btn.pressed.connect(_on_redo_arom_click)

	EventBus.button_released.connect(_on_pluto_button)
	EventBus.new_sensor_data.connect(_on_data)

	mech_label.text = _get_mech_display_name()

func _process(_delta: float) -> void:
	if not is_node_ready():
		return
	var angle = PlutoComm.angle
	arom_angle_label.text = "%.1f" % angle
	prom_angle_label.text = "%.1f" % angle
	_update_curr_cursor(angle)
	if _arom_state == AromState.ASSESS:
		_update_arom_cursors(_arom_tmin, _arom_tmax)
	if _prom_state == PromState.ASSESS:
		_update_prom_cursors(_prom_tmin, _prom_tmax)

func _select_arom() -> void:
	_arom_selected   = true
	_prom_selected   = false
	_arom_state      = AromState.WAITING
	_arom_tmin       = PlutoComm.angle
	_arom_tmax       = PlutoComm.angle
	_forward_limit   = PlutoComm.angle
	_backward_limit  = PlutoComm.angle
	_prom_run_once   = false

	arom_start_btn.visible   = true
	arom_next_btn.visible    = false
	arom_curr_cursor.visible = true

	prom_start_btn.visible   = false
	prom_next_btn.visible    = false
	prom_curr_cursor.visible = false

	var _old = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null

	arom_status.modulate = Color.WHITE
	arom_status.text = (
		"Prev PROM: %d : %d (%d°)\n\nPress PLUTO button to start"
		% [int(_old.prom_min if _old != null else 0),
		   int(_old.prom_max if _old != null else 0),
		   int((_old.prom_max - _old.prom_min) if _old != null else 0)]
	)
	prom_status.modulate = Color.WHITE
	prom_status.text     = "Waiting for AROM..."

	arom_prev_label.text = "Prev AROM: %d : %d (%d°)" % [
		int(_old.arom_min if _old != null else 0),
		int(_old.arom_max if _old != null else 0),
		int((_old.arom_max - _old.arom_min) if _old != null else 0),
	]

func _select_prom() -> void:
	_arom_selected   = false
	_prom_selected   = true
	_prom_state      = PromState.INIT
	_prom_run_once   = false
	_prom_restarting = false
	_prom_tmin       = 0.0
	_prom_tmax       = 0.0

	prom_start_btn.visible   = false
	prom_next_btn.visible    = false
	prom_curr_cursor.visible = true
	prom_status.modulate     = Color.WHITE

	var _old = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null
	prom_status.text = (
		"Prev PROM: %d : %d (%d°)\n\nPress PLUTO button to start"
		% [int(_old.prom_min if _old != null else 0),
		   int(_old.prom_max if _old != null else 0),
		   int((_old.prom_max - _old.prom_min) if _old != null else 0)]
	)

func _on_data() -> void:
	if _arom_selected:
		_run_arom_state_machine()
	elif _prom_selected:
		_run_prom_state_machine()

func _on_pluto_button() -> void:
	_is_button_pressed = true

func _run_arom_state_machine() -> void:
	match _arom_state:
		AromState.WAITING:
			arom_curr_cursor.visible = true
			var _old_w = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null
			arom_status.text = (
				"Prev PROM: %d : %d (%d°)\n\nPress PLUTO button to start"
				% [int(_old_w.prom_min if _old_w != null else 0),
				   int(_old_w.prom_max if _old_w != null else 0),
				   int((_old_w.prom_max - _old_w.prom_min) if _old_w != null else 0)]
			)
			if _is_button_pressed:
				_start_arom_assessment()
				_is_button_pressed = false

		AromState.ASSESS:
			arom_curr_cursor.visible = true
			_track_arom()
			_arom_tmin = _backward_limit
			_arom_tmax = _forward_limit
			arom_start_btn.visible = false
			arom_next_btn.visible  = true
			arom_status.text = (
				"Exploring AROM\nMin: %.1f° | Max: %.1f°\nRange: %.1f°\nPress PLUTO button to confirm"
				% [_arom_tmin, _arom_tmax, _arom_tmax - _arom_tmin]
			)
			if _is_button_pressed:
				_on_arom_next_click()
				_is_button_pressed = false

func _run_prom_state_machine() -> void:
	match _prom_state:
		PromState.INIT:
			prom_start_btn.visible   = false
			prom_next_btn.visible    = false
			prom_curr_cursor.visible = true

			if not _prom_run_once:
				_prom_run_once = true
				_prom_tmin     = 0.0
				_prom_tmax     = 0.0

			if _prom_restarting:
				prom_status.modulate = Color.RED
				prom_status.text = (
					"PROM should not be below the range of AROM\nPlease REDO AROM AGAIN\n\nPress PLUTO button to restart"
				)
			else:
				prom_status.modulate = Color.WHITE
				var _old = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null
				prom_status.text = (
					"Prev PROM: %d : %d (%d°)\n\nPress PLUTO button to start"
					% [int(_old.prom_min if _old != null else 0),
					   int(_old.prom_max if _old != null else 0),
					   int((_old.prom_max - _old.prom_min) if _old != null else 0)]
				)

			if _is_button_pressed:
				_start_prom_assessment()
				_is_button_pressed = false

		PromState.ASSESS:
			prom_start_btn.visible   = false
			prom_next_btn.visible    = false
			prom_curr_cursor.visible = true
			prom_status.modulate     = Color.WHITE

			var angle = PlutoComm.angle
			if angle < _prom_tmin:
				_prom_tmin = angle
			if angle > _prom_tmax:
				_prom_tmax = angle

			prom_status.text = (
				"Min: %.1f° | Max: %.1f°\n\nPress PLUTO button to confirm PROM"
				% [_prom_tmin, _prom_tmax]
			)

			if _is_button_pressed:
				_on_prom_confirm()
				_is_button_pressed = false

func _start_arom_assessment() -> void:
	_arom_state      = AromState.ASSESS
	var start_angle  = PlutoComm.angle
	_forward_limit   = start_angle
	_backward_limit  = start_angle
	_arom_tmin       = start_angle
	_arom_tmax       = start_angle
	_arom_last_angle = start_angle
	_dir_threshold   = 2.0
	arom_start_btn.visible   = false
	arom_next_btn.visible    = true
	arom_curr_cursor.visible = true

func _on_arom_start_click() -> void:
	_start_arom_assessment()

func _on_arom_next_click() -> void:
	_arom_tmin = max(_arom_tmin, -_ang_limit)
	_arom_tmax = min(_arom_tmax,  _ang_limit)
	if AppData.selected_mechanism != null:
		AppData.selected_mechanism.set_new_arom(_arom_tmin, _arom_tmax)
	arom_next_btn.visible    = false
	arom_start_btn.visible   = false
	arom_curr_cursor.visible = false
	arom_status.modulate     = Color.WHITE
	_select_prom()

func _on_prom_start_click() -> void:
	_start_prom_assessment()

func _start_prom_assessment() -> void:
	_prom_state              = PromState.ASSESS
	_prom_tmin               = PlutoComm.angle
	_prom_tmax               = PlutoComm.angle
	prom_start_btn.visible   = false
	prom_next_btn.visible    = false
	prom_curr_cursor.visible = true

func _on_prom_next_click() -> void:
	_on_prom_confirm()

func _on_prom_confirm() -> void:
	_check_prom_limits()

func _check_prom_limits() -> void:
	var is_hoc   = AppData.mechanism_name == "HOC"
	var _new_rom = AppData.selected_mechanism.new_rom if AppData.selected_mechanism != null else null
	var _curr_amin = _new_rom.arom_min if _new_rom != null else 0.0
	var _curr_amax = _new_rom.arom_max if _new_rom != null else 0.0
	var condition: bool
	if is_hoc:
		condition = _prom_tmin > _curr_amin
	else:
		condition = (
			_prom_tmin > (_curr_amin + 5.0) or
			_prom_tmax < (_curr_amax - 5.0)
		)
	if condition:
		_prom_restarting         = true
		_prom_run_once           = false
		_prom_state              = PromState.INIT
		prom_curr_cursor.visible = false
	else:
		if AppData.selected_mechanism != null:
			AppData.selected_mechanism.set_new_prom(_prom_tmin, _prom_tmax)
			var nr = AppData.selected_mechanism.new_rom
			EventBus.rom_assessed.emit(nr.arom_min, nr.arom_max, nr.prom_min, nr.prom_max)
		get_tree().change_scene_to_file("res://scenes/AssistProfileScene.tscn")

func _on_redo_arom_click() -> void:
	get_tree().reload_current_scene()

func _track_arom() -> void:
	var current = PlutoComm.angle
	var delta   = current - _arom_last_angle
	if abs(delta) < _dir_threshold:
		return
	if delta > 0 and current > _forward_limit:
		_forward_limit = current
	elif delta < 0 and current < _backward_limit:
		_backward_limit = current
	_arom_last_angle = current
	var range = _forward_limit - _backward_limit
	_dir_threshold = clamp(range * THRESHOLD_PERCENT, THRESHOLD_MIN, THRESHOLD_MAX)

func _update_arom_cursors(min_val: float, max_val: float) -> void:
	var tw = arom_track.size.x
	if tw == 0:
		return
	var min_t = (min_val + _ang_limit) / (_ang_limit * 2.0)
	var max_t = (max_val + _ang_limit) / (_ang_limit * 2.0)
	arom_min_cursor.position.x = (
		arom_track.position.x + clamp(min_t, 0.0, 1.0) * tw - arom_min_cursor.size.x / 2.0
	)
	arom_max_cursor.position.x = (
		arom_track.position.x + clamp(max_t, 0.0, 1.0) * tw - arom_max_cursor.size.x / 2.0
	)

func _update_prom_cursors(min_val: float, max_val: float) -> void:
	var tw = prom_track.size.x
	if tw == 0:
		return
	var min_t = (min_val + _ang_limit) / (_ang_limit * 2.0)
	var max_t = (max_val + _ang_limit) / (_ang_limit * 2.0)
	prom_min_cursor.position.x = (
		prom_track.position.x + clamp(min_t, 0.0, 1.0) * tw - prom_min_cursor.size.x / 2.0
	)
	prom_max_cursor.position.x = (
		prom_track.position.x + clamp(max_t, 0.0, 1.0) * tw - prom_max_cursor.size.x / 2.0
	)

func _update_curr_cursor(angle: float) -> void:
	if _arom_selected and arom_curr_cursor.visible:
		var tw = arom_track.size.x
		if tw == 0:
			return
		var t = (angle + _ang_limit) / (_ang_limit * 2.0)
		arom_curr_cursor.position.x = (
			arom_track.position.x + clamp(t, 0.0, 1.0) * tw - arom_curr_cursor.size.x / 2.0
		)
	if _prom_selected and prom_curr_cursor.visible:
		var tw = prom_track.size.x
		if tw == 0:
			return
		var t = (angle + _ang_limit) / (_ang_limit * 2.0)
		prom_curr_cursor.position.x = (
			prom_track.position.x + clamp(t, 0.0, 1.0) * tw - prom_curr_cursor.size.x / 2.0
		)

func _setup_labels() -> void:
	var mech_idx = AppData.mechanism_index - 1
	var is_hoc   = AppData.mechanism_name == "HOC"
	if mech_idx >= 0 and mech_idx < DIRECTION_TEXT.size():
		arom_left_label.text  = DIRECTION_TEXT[mech_idx][0]
		arom_right_label.text = DIRECTION_TEXT[mech_idx][1]
		prom_left_label.text  = DIRECTION_TEXT[mech_idx][0]
		prom_right_label.text = DIRECTION_TEXT[mech_idx][1]
	arom_center_label.visible = is_hoc
	prom_center_label.visible = is_hoc
	arom_center_label.text    = "Closed" if is_hoc else ""
	prom_center_label.text    = "Closed" if is_hoc else ""

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

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)
	if EventBus.new_sensor_data.is_connected(_on_data):
		EventBus.new_sensor_data.disconnect(_on_data)
