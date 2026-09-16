extends Control

# ── Node references ────────────────────────────────────────────────────
@onready var mech_label:        Label  = $HeaderPanel/MechLabel
@onready var exit_button:       Button = $HeaderPanel/ExitButton

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

@onready var redo_btn:        Button = $BottomButtons/RedoAromButton
@onready var change_mech_btn: Button = $BottomButtons/ChangeMechButton
@onready var arom_panel:      Panel  = $AromPanel

const DIRECTION_TEXT = [
	["Flexion",    "Extension"],
	["Radial Dev", "Ulnar Dev"],
	["Pronation",  "Supination"],
	["Open",       "Closed"],
	["",           ""],
	["",           ""],
]

const CYCLE_COLORS = [
	Color(1.0, 0.2, 0.2),  # cycle 1 — red
	Color(1.0, 0.6, 0.1),  # cycle 2 — orange
	Color(0.9, 0.9, 0.0),  # cycle 3 — yellow
	Color(0.2, 0.8, 0.3),  # cycle 4 — green
	Color(0.2, 0.5, 1.0),  # cycle 5 — blue
]
const BEST_CYCLE_COLOR = Color(1.0, 0.95, 0.2)  # gold
const MARKER_W: float = 4.0

# ── AROM state machine ────────────────────────────────────────────────
enum AromState { INIT, TRIAL_RUNNING, TRIAL_COMPLETE, ASSESSMENT_COMPLETE }
var _arom_state: AromState = AromState.INIT

# ── PROM state machine ────────────────────────────────────────────────
enum PromState { INIT, ASSESS }
var _prom_state: PromState = PromState.INIT

var _arom_selected: bool = true
var _prom_selected: bool = false
var _is_button_pressed: bool = false

var _ang_limit: float = 78.0

# Cursor display range for AROM
var _arom_tmin: float = 0.0
var _arom_tmax: float = 0.0

# PROM tracking
var _prom_tmin:       float = 0.0
var _prom_tmax:       float = 0.0
var _prom_run_once:   bool  = false
var _prom_restarting: bool  = false

# ── Velocity rolling window ───────────────────────────────────────────
const VEL_WINDOW        = 10
const VEL_DIR_THRESHOLD = 2.0  # deg/s
var _vel_window: Array  = []
var _last_angle: float  = 0.0
var _at_rest:    bool   = false
var _curr_dir:   int    = 0    # +1, -1, 0

# ── Cycle detection constants ─────────────────────────────────────────
const CYCLES_PER_TRIAL       = 5
const REVERSAL_THRESHOLD     = 5.0
const HOC_REVERSAL_THRESHOLD = 5.0
const MIN_AROM_RANGE         = 5.0

# ── Trial state ───────────────────────────────────────────────────────
var _trial_cycles:     Array      = []  # Array of {"lo": float, "hi": float}
var _trial_best:       Dictionary = {"lo": 0.0, "hi": 0.0}
var _completed_cycles: int        = 0
var _cycle_marker_data: Array = []  # [{lo,hi,lo_node,hi_node,badge_node,cycle_idx}]

# ── Non-HOC cycle detection ───────────────────────────────────────────
var _peak_hi:      float = -INF
var _peak_lo:      float = INF
var _was_going_hi: bool  = false
var _was_going_lo: bool  = false
var _hi_arm_angle: float = 0.0
var _lo_arm_angle: float = 0.0
var _hi_finalized: bool  = false
var _lo_finalized: bool  = false
var _finalized_hi: float = 0.0
var _finalized_lo: float = 0.0

# ── HOC cycle detection ───────────────────────────────────────────────
enum HocState { OPENING, CLOSING }
var _hoc_state:           HocState = HocState.OPENING
var _hoc_peak_open:       float    = 0.0
var _hoc_peak_close:      float    = 0.0
var _hoc_open_finalized:  bool     = false
var _hoc_close_finalized: bool     = false

# ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	PlutoComm.set_control_type("NONE")
	_ang_limit = (AppData.calib_angle + 10.0) if AppData.mechanism_name == "HOC" \
				 else (AppData.mech_offset + 10.0)
	_setup_labels()
	_select_arom()

	exit_button.pressed.connect(func():
		var dest = "res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup \
				   else "res://scenes/ChooseMechanism.tscn"
		get_tree().change_scene_to_file(dest)
	)
	change_mech_btn.pressed.connect(func():
		var dest = "res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup \
				   else "res://scenes/ChooseMechanism.tscn"
		get_tree().change_scene_to_file(dest)
	)
	arom_start_btn.pressed.connect(_on_arom_start_click)
	arom_next_btn.pressed.connect(_on_arom_next_click)
	prom_start_btn.pressed.connect(_on_prom_start_click)
	prom_next_btn.pressed.connect(_on_prom_next_click)
	redo_btn.pressed.connect(_on_redo_arom_click)

	EventBus.button_released.connect(_on_pluto_button)
	mech_label.text = _get_mech_display_name()

func _process(delta: float) -> void:
	if not is_node_ready():
		return
	var angle = PlutoComm.angle
	if _arom_selected:
		arom_angle_label.text = "%.1f" % angle
	if _prom_selected:
		prom_angle_label.text = "%.1f" % angle
	_update_curr_cursor(angle)

	if _arom_selected:
		_update_velocity_and_rest(delta)
		_run_arom_state_machine()
		match _arom_state:
			AromState.TRIAL_RUNNING, AromState.TRIAL_COMPLETE, AromState.ASSESSMENT_COMPLETE:
				_update_arom_cursors(_arom_tmin, _arom_tmax)
				_update_cycle_marker_positions()
	elif _prom_selected:
		_run_prom_state_machine()
		if _prom_state == PromState.ASSESS:
			_update_prom_cursors(_prom_tmin, _prom_tmax)

func _on_pluto_button() -> void:
	_is_button_pressed = true

# =========================================================================
# AROM — initialisation & panel selection
# =========================================================================

func _select_arom() -> void:
	_arom_selected   = true
	_prom_selected   = false
	_arom_state      = AromState.INIT
	_arom_tmin       = PlutoComm.angle
	_arom_tmax       = PlutoComm.angle
	_prom_run_once   = false
	_vel_window.clear()
	_last_angle      = PlutoComm.angle

	arom_start_btn.visible   = false
	arom_next_btn.visible    = false
	arom_curr_cursor.visible = true
	prom_start_btn.visible   = false
	prom_next_btn.visible    = false
	prom_curr_cursor.visible = false

	_refresh_arom_init_status()
	prom_status.modulate = Color.WHITE
	prom_status.text     = "Waiting for AROM..."

func _refresh_arom_init_status() -> void:
	var old = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null
	arom_status.modulate = Color.WHITE
	arom_status.text = (
		"AROM Assessment\n%d cycles\n\nPress PLUTO button to start\n[Esc] to bypass"
		% CYCLES_PER_TRIAL
	)
	arom_prev_label.text = _fmt_arom(
		old.arom_min if old != null else 0.0,
		old.arom_max if old != null else 0.0
	)

# =========================================================================
# AROM — state machine
# =========================================================================

func _run_arom_state_machine() -> void:
	match _arom_state:
		AromState.INIT:
			arom_start_btn.visible   = false
			arom_next_btn.visible    = false
			arom_curr_cursor.visible = true
			_refresh_arom_init_status()
			if Input.is_action_just_pressed("ui_cancel"):
				_bypass_assessment()
			elif _is_button_pressed:
				_is_button_pressed = false
				_init_trial()

		AromState.TRIAL_RUNNING:
			arom_start_btn.visible = false
			arom_next_btn.visible  = false
			arom_curr_cursor.visible = true
			if Input.is_action_just_pressed("ui_cancel"):
				_bypass_assessment()
				return
			_update_cycle_detection()
			if _arom_state == AromState.TRIAL_RUNNING:
				_show_trial_running_ui()

		AromState.TRIAL_COMPLETE:
			arom_start_btn.visible = false
			arom_next_btn.visible  = false
			_show_trial_complete_ui()
			if _is_button_pressed:
				_is_button_pressed = false
				_finish_assessment()

		AromState.ASSESSMENT_COMPLETE:
			arom_start_btn.visible = false
			arom_next_btn.visible  = false
			_show_assessment_complete_ui()
			if _is_button_pressed:
				_is_button_pressed = false
				_save_arom_and_select_prom()

# =========================================================================
# AROM — velocity & rest detection
# =========================================================================

func _update_velocity_and_rest(delta: float) -> void:
	if _arom_state != AromState.TRIAL_RUNNING:
		return
	var angle = PlutoComm.angle
	if delta > 0.0:
		var v = (angle - _last_angle) / delta
		_vel_window.append(v)
		if _vel_window.size() > VEL_WINDOW:
			_vel_window.pop_front()
	_last_angle = angle

	if _vel_window.size() < VEL_WINDOW:
		_at_rest  = false
		_curr_dir = 0
		return

	var sum = 0.0
	for v in _vel_window:
		sum += v
	var avg = sum / float(VEL_WINDOW)

	_at_rest = abs(avg) < VEL_DIR_THRESHOLD
	if avg > VEL_DIR_THRESHOLD:
		_curr_dir = 1
	elif avg < -VEL_DIR_THRESHOLD:
		_curr_dir = -1
	else:
		_curr_dir = 0

# =========================================================================
# AROM — cycle detection
# =========================================================================

func _update_cycle_detection() -> void:
	if AppData.mechanism_name == "HOC":
		_update_cycle_hoc()
	else:
		_update_cycle_non_hoc()

func _update_cycle_non_hoc() -> void:
	var angle = PlutoComm.angle

	if not _hi_finalized and _curr_dir == 1:
		if not _was_going_hi:
			_was_going_hi = true
			_hi_arm_angle = angle
		if angle > _peak_hi:
			_peak_hi = angle

	if not _lo_finalized and _curr_dir == -1:
		if not _was_going_lo:
			_was_going_lo = true
			_lo_arm_angle = angle
		if angle < _peak_lo:
			_peak_lo = angle

	if not _hi_finalized and _was_going_hi and _curr_dir == -1:
		var hi_extent   = _peak_hi - _hi_arm_angle
		var hi_reversal = _peak_hi - angle
		if hi_extent > REVERSAL_THRESHOLD and hi_reversal > REVERSAL_THRESHOLD:
			_finalized_hi = _peak_hi
			_hi_finalized = true
			_was_going_lo = false
			_peak_lo      = INF

	if not _lo_finalized and _was_going_lo and _curr_dir == 1:
		var lo_extent   = _lo_arm_angle - _peak_lo
		var lo_reversal = angle - _peak_lo
		if lo_extent > REVERSAL_THRESHOLD and lo_reversal > REVERSAL_THRESHOLD:
			_finalized_lo = _peak_lo
			_lo_finalized = true
			_was_going_hi = false
			_peak_hi      = -INF

	if _hi_finalized and _lo_finalized:
		_record_cycle(_finalized_lo, _finalized_hi)

func _update_cycle_hoc() -> void:
	var angle = PlutoComm.angle

	if _hoc_state == HocState.OPENING:
		if not _hoc_open_finalized and angle < _hoc_peak_open:
			_hoc_peak_open = angle
		if not _hoc_open_finalized and _at_rest \
				and (angle - _hoc_peak_open) > HOC_REVERSAL_THRESHOLD:
			_hoc_open_finalized = true
			_finalized_lo       = _hoc_peak_open
			_hoc_state          = HocState.CLOSING
			_hoc_peak_close     = angle
	else:
		if not _hoc_close_finalized and angle > _hoc_peak_close:
			_hoc_peak_close = angle
		if not _hoc_close_finalized and _at_rest \
				and (_hoc_peak_close - angle) > HOC_REVERSAL_THRESHOLD:
			_hoc_close_finalized = true
			_finalized_hi        = _hoc_peak_close

	if _hoc_open_finalized and _hoc_close_finalized:
		_record_cycle(_finalized_lo, _finalized_hi)

# =========================================================================
# AROM — cycle recording & trial management
# =========================================================================

func _init_trial() -> void:
	_completed_cycles = 0
	_trial_cycles.clear()
	_vel_window.clear()
	_last_angle = PlutoComm.angle
	_at_rest    = false
	_arom_tmin  = PlutoComm.angle
	_arom_tmax  = PlutoComm.angle
	_clear_cycle_markers()
	_reset_cycle_state()
	_arom_state = AromState.TRIAL_RUNNING

func _reset_cycle_state() -> void:
	var angle = PlutoComm.angle
	if AppData.mechanism_name == "HOC":
		_hoc_state           = HocState.OPENING
		_hoc_peak_open       = angle
		_hoc_peak_close      = angle
		_hoc_open_finalized  = false
		_hoc_close_finalized = false
	else:
		_peak_hi      = -INF
		_peak_lo      = INF
		_was_going_hi = false
		_was_going_lo = false
		_hi_arm_angle = angle
		_lo_arm_angle = angle
		_hi_finalized = false
		_lo_finalized = false
		_finalized_hi = angle
		_finalized_lo = angle

func _record_cycle(lo: float, hi: float) -> void:
	_trial_cycles.append({"lo": lo, "hi": hi})
	_completed_cycles += 1

	_add_cycle_markers(lo, hi, _completed_cycles - 1)

	# Show widest range seen so far this trial
	for c in _trial_cycles:
		if c.lo < _arom_tmin: _arom_tmin = c.lo
		if c.hi > _arom_tmax: _arom_tmax = c.hi

	if _completed_cycles >= CYCLES_PER_TRIAL:
		_complete_trial()
		return
	_reset_cycle_state()

func _get_best_cycle(cycles: Array) -> Dictionary:
	var start      = max(0, cycles.size() - 3)
	var best       = cycles[start]
	var best_range = best.hi - best.lo
	for i in range(start + 1, cycles.size()):
		var r = cycles[i].hi - cycles[i].lo
		if r > best_range:
			best_range = r
			best       = cycles[i]
	return best

func _complete_trial() -> void:
	var best   = _get_best_cycle(_trial_cycles)
	_trial_best = best
	_arom_tmin  = best.lo
	_arom_tmax  = best.hi
	_highlight_best_cycle_marker(best.lo, best.hi)
	_arom_state = AromState.TRIAL_COMPLETE

func _finish_assessment() -> void:
	_arom_tmin  = _trial_best.lo
	_arom_tmax  = _trial_best.hi
	_arom_state = AromState.ASSESSMENT_COMPLETE

func _bypass_assessment() -> void:
	var lo: float
	var hi: float
	if AppData.mechanism_name == "HOC":
		lo = _hoc_peak_open
		hi = _hoc_peak_close
	else:
		lo = _peak_lo if _peak_lo != INF  else PlutoComm.angle
		hi = _peak_hi if _peak_hi != -INF else PlutoComm.angle

	if _trial_cycles.size() > 0:
		var best = _get_best_cycle(_trial_cycles)
		if (best.hi - best.lo) > (hi - lo):
			lo = best.lo
			hi = best.hi

	_trial_best = {"lo": lo, "hi": hi}
	_arom_tmin  = lo
	_arom_tmax  = hi
	_arom_state = AromState.ASSESSMENT_COMPLETE

func _save_arom_and_select_prom() -> void:
	var lo = max(_arom_tmin, -_ang_limit)
	var hi = min(_arom_tmax,  _ang_limit)
	if AppData.selected_mechanism != null:
		AppData.selected_mechanism.set_new_arom(lo, hi)
		AppData.selected_mechanism.set_arom_cpm(abs(hi - lo) <= MIN_AROM_RANGE)
	arom_next_btn.visible    = false
	arom_start_btn.visible   = false
	arom_curr_cursor.visible = false
	_mark_arom_panel_complete(lo, hi)
	_select_prom()

func _mark_arom_panel_complete(lo: float, hi: float) -> void:
	# Green tint overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.15, 0.7, 0.25, 0.18)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = -1
	arom_panel.add_child(overlay)

	# Green border via StyleBox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.25, 0.85, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	arom_panel.add_theme_stylebox_override("panel", sb)

	# ✓ badge at top-right corner
	var badge := Panel.new()
	badge.anchor_left   = 1.0; badge.anchor_right  = 1.0
	badge.anchor_top    = 0.0; badge.anchor_bottom = 0.0
	badge.offset_left   = -148.0; badge.offset_right  = -6.0
	badge.offset_top    = 6.0;   badge.offset_bottom = 30.0
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.18, 0.72, 0.28)
	badge_sb.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", badge_sb)
	arom_panel.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.text = "✓  AROM Done"
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(badge_lbl)

	# Freeze angle label to show the saved AROM result
	var is_hoc = AppData.mechanism_name == "HOC"
	if is_hoc:
		arom_angle_label.text = "%.1fcm–%.1fcm" % [AppData.hoc_to_cm(lo), AppData.hoc_to_cm(hi)]
	else:
		arom_angle_label.text = "%d°–%d°" % [int(lo), int(hi)]

# =========================================================================
# AROM — UI display helpers
# =========================================================================

# =========================================================================
# AROM — cycle marker UI helpers
# =========================================================================

func _add_cycle_markers(lo: float, hi: float, cycle_idx: int) -> void:
	if not is_node_ready():
		return
	var color: Color = CYCLE_COLORS[cycle_idx % CYCLE_COLORS.size()]
	var container: Node = arom_track.get_parent()
	var track_h: float  = max(arom_track.size.y, 20.0)

	var lo_node := ColorRect.new()
	lo_node.color = color
	lo_node.size  = Vector2(MARKER_W, track_h)
	container.add_child(lo_node)

	var hi_node := ColorRect.new()
	hi_node.color = color
	hi_node.size  = Vector2(MARKER_W, track_h)
	container.add_child(hi_node)

	var lo_badge := Label.new()
	lo_badge.text = str(cycle_idx + 1)
	lo_badge.add_theme_font_size_override("font_size", 10)
	lo_badge.add_theme_color_override("font_color", color)
	lo_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lo_badge.custom_minimum_size  = Vector2(16, 0)
	container.add_child(lo_badge)

	var hi_badge := Label.new()
	hi_badge.text = str(cycle_idx + 1)
	hi_badge.add_theme_font_size_override("font_size", 10)
	hi_badge.add_theme_color_override("font_color", color)
	hi_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hi_badge.custom_minimum_size  = Vector2(16, 0)
	container.add_child(hi_badge)

	_cycle_marker_data.append({
		"lo": lo, "hi": hi,
		"lo_node": lo_node, "hi_node": hi_node,
		"lo_badge": lo_badge, "hi_badge": hi_badge,
		"cycle_idx": cycle_idx
	})
	_update_cycle_marker_positions()

func _highlight_best_cycle_marker(best_lo: float, best_hi: float) -> void:
	for m in _cycle_marker_data:
		if abs(m.lo - best_lo) < 0.1 and abs(m.hi - best_hi) < 0.1:
			m.lo_node.color = BEST_CYCLE_COLOR
			m.hi_node.color = BEST_CYCLE_COLOR
			m.lo_badge.add_theme_color_override("font_color", BEST_CYCLE_COLOR)
			m.hi_badge.add_theme_color_override("font_color", BEST_CYCLE_COLOR)

func _clear_cycle_markers() -> void:
	for m in _cycle_marker_data:
		if is_instance_valid(m.lo_node):  m.lo_node.queue_free()
		if is_instance_valid(m.hi_node):  m.hi_node.queue_free()
		if is_instance_valid(m.lo_badge): m.lo_badge.queue_free()
		if is_instance_valid(m.hi_badge): m.hi_badge.queue_free()
	_cycle_marker_data.clear()

func _update_cycle_marker_positions() -> void:
	if _cycle_marker_data.is_empty():
		return
	var tw: float = arom_track.size.x
	if tw == 0.0:
		return
	var track_h: float = arom_track.size.y
	var tx: float      = arom_track.position.x
	var ty: float      = arom_track.position.y
	for m in _cycle_marker_data:
		var lo_t: float = (m.lo + _ang_limit) / (_ang_limit * 2.0)
		var hi_t: float = (m.hi + _ang_limit) / (_ang_limit * 2.0)
		var lo_x: float = tx + clamp(lo_t, 0.0, 1.0) * tw - MARKER_W * 0.5
		var hi_x: float = tx + clamp(hi_t, 0.0, 1.0) * tw - MARKER_W * 0.5
		m.lo_node.position = Vector2(lo_x, ty)
		m.hi_node.position = Vector2(hi_x, ty)
		m.lo_node.size.y    = track_h
		m.hi_node.size.y    = track_h
		m.lo_badge.position = Vector2(lo_x - 8.0 + MARKER_W * 0.5, ty - 16.0)
		m.hi_badge.position = Vector2(hi_x - 8.0 + MARKER_W * 0.5, ty - 16.0)

func _show_trial_running_ui() -> void:
	var is_hoc = AppData.mechanism_name == "HOC"
	arom_status.modulate = Color.WHITE

	if is_hoc:
		var disp_lo  = _finalized_lo if _hoc_open_finalized  else _hoc_peak_open
		var disp_hi  = _finalized_hi if _hoc_close_finalized else _hoc_peak_close
		_arom_tmin   = disp_lo
		_arom_tmax   = disp_hi
		var open_cm  = AppData.hoc_to_cm(_finalized_lo  if _hoc_open_finalized  else _hoc_peak_open)
		var close_cm = AppData.hoc_to_cm(_finalized_hi  if _hoc_close_finalized else _hoc_peak_close)
		var open_str  = ("%.2fcm✓" % open_cm)  if _hoc_open_finalized  else ("%.2fcm" % open_cm)
		var close_str = ("%.2fcm✓" % close_cm) if _hoc_close_finalized else ("%.2fcm" % close_cm)
		var state_str = "←OPEN" if _hoc_state == HocState.OPENING else "CLOSE→"
		var rest_str  = "REST"   if _at_rest                       else "MOVING"
		arom_status.text = (
			"Cycle %d/%d\nOpen: %s   Close: %s\n%s  [%s]"
			% [_completed_cycles + 1, CYCLES_PER_TRIAL,
			   open_str, close_str, state_str, rest_str]
		)
	else:
		var hi_str: String
		var lo_str: String
		if _hi_finalized:
			hi_str = "%.1f°✓" % _finalized_hi
		elif _was_going_hi and _peak_hi != -INF:
			hi_str = "%.1f°" % _peak_hi
		else:
			hi_str = "–"

		if _lo_finalized:
			lo_str = "%.1f°✓" % _finalized_lo
		elif _was_going_lo and _peak_lo != INF:
			lo_str = "%.1f°" % _peak_lo
		else:
			lo_str = "–"

		var disp_lo = _peak_lo if (_was_going_lo and _peak_lo != INF)  else PlutoComm.angle
		var disp_hi = _peak_hi if (_was_going_hi and _peak_hi != -INF) else PlutoComm.angle
		_arom_tmin = disp_lo
		_arom_tmax = disp_hi

		var dir_str  = "→" if _curr_dir == 1 else ("←" if _curr_dir == -1 else "·")
		var rest_str = "[REST]" if _at_rest else "[MOVING]"
		arom_status.text = (
			"Cycle %d/%d\nHI: %s   LO: %s\n%s %s"
			% [_completed_cycles + 1, CYCLES_PER_TRIAL,
			   hi_str, lo_str, dir_str, rest_str]
		)

func _show_trial_complete_ui() -> void:
	var is_hoc = AppData.mechanism_name == "HOC"
	var lo     = AppData.hoc_to_cm(_trial_best.lo) if is_hoc else _trial_best.lo
	var hi     = AppData.hoc_to_cm(_trial_best.hi) if is_hoc else _trial_best.hi
	var unit   = "cm" if is_hoc else "°"
	arom_status.modulate = Color.WHITE
	arom_status.text = (
		"Trial Complete!\nBest: %.1f%s to %.1f%s  (%.1f%s)\n\nPress PLUTO button to finish assessment"
		% [lo, unit, hi, unit, abs(hi - lo), unit]
	)

func _show_assessment_complete_ui() -> void:
	var is_hoc = AppData.mechanism_name == "HOC"
	var lo     = AppData.hoc_to_cm(_arom_tmin) if is_hoc else _arom_tmin
	var hi     = AppData.hoc_to_cm(_arom_tmax) if is_hoc else _arom_tmax
	var unit   = "cm" if is_hoc else "°"
	arom_status.modulate = Color.WHITE
	arom_status.text = (
		"Assessment Complete!\nAROM: %.1f%s to %.1f%s  (%.1f%s)\n\nPress PLUTO button to continue to PROM"
		% [lo, unit, hi, unit, abs(hi - lo), unit]
	)

# =========================================================================
# AROM — button handlers
# =========================================================================

func _on_arom_start_click() -> void:
	_init_trial()

func _on_arom_next_click() -> void:
	_save_arom_and_select_prom()

func _on_redo_arom_click() -> void:
	get_tree().reload_current_scene()

# =========================================================================
# PROM section
# =========================================================================

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

	var old = AppData.selected_mechanism.old_rom if AppData.selected_mechanism != null else null
	prom_status.text = (
		"%s\n\nPress PLUTO button to start"
		% _fmt_prom(old.prom_min if old != null else 0.0,
					old.prom_max if old != null else 0.0)
	)

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
					"PROM should not be below the range of AROM\n"
					+ "Please REDO AROM\n\nPress PLUTO button to restart"
				)
			else:
				prom_status.modulate = Color.WHITE
				var old = AppData.selected_mechanism.old_rom \
						  if AppData.selected_mechanism != null else null
				prom_status.text = (
					"%s\n\nPress PLUTO button to start"
					% _fmt_prom(old.prom_min if old != null else 0.0,
								old.prom_max if old != null else 0.0)
				)

			if _is_button_pressed:
				_is_button_pressed = false
				_start_prom_assessment()

		PromState.ASSESS:
			prom_start_btn.visible   = false
			prom_next_btn.visible    = false
			prom_curr_cursor.visible = true
			prom_status.modulate     = Color.WHITE

			var angle = PlutoComm.angle
			if angle < _prom_tmin: _prom_tmin = angle
			if angle > _prom_tmax: _prom_tmax = angle

			var old = AppData.selected_mechanism.old_rom \
					  if AppData.selected_mechanism != null else null
			prom_status.text = (
				"%s\nCurrent PROM: %s\n\nPress PLUTO button to confirm PROM"
				% [
					_fmt_prom(old.prom_min if old != null else 0.0,
							  old.prom_max if old != null else 0.0),
					_fmt_range(_prom_tmin, _prom_tmax)
				]
			)

			if _is_button_pressed:
				_is_button_pressed = false
				_on_prom_confirm()

func _start_prom_assessment() -> void:
	_prom_state              = PromState.ASSESS
	_prom_tmin               = PlutoComm.angle
	_prom_tmax               = PlutoComm.angle
	prom_start_btn.visible   = false
	prom_next_btn.visible    = false
	prom_curr_cursor.visible = true

func _on_prom_start_click() -> void:
	_start_prom_assessment()

func _on_prom_next_click() -> void:
	_on_prom_confirm()

func _on_prom_confirm() -> void:
	_check_prom_limits()

func _check_prom_limits() -> void:
	var new_rom  = AppData.selected_mechanism.new_rom if AppData.selected_mechanism != null else null
	var arom_min = new_rom.arom_min if new_rom != null else 0.0
	var arom_max = new_rom.arom_max if new_rom != null else 0.0
	# PROM must encompass AROM — no tolerance margin
	var failed = _prom_tmin > arom_min or _prom_tmax < arom_max
	if failed:
		_prom_restarting         = true
		_prom_run_once           = false
		_prom_state              = PromState.INIT
		prom_curr_cursor.visible = false
	else:
		if AppData.selected_mechanism != null:
			AppData.selected_mechanism.set_new_prom(_prom_tmin, _prom_tmax)
			AppData.selected_mechanism.set_new_aprom(_prom_tmin, _prom_tmax)
			var nr = AppData.selected_mechanism.new_rom
			EventBus.rom_assessed.emit(nr.arom_min, nr.arom_max, nr.prom_min, nr.prom_max)
		get_tree().change_scene_to_file("res://scenes/AssistProfileScene.tscn")

# =========================================================================
# Cursor & label helpers
# =========================================================================

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

func _fmt_arom(amin: float, amax: float) -> String:
	if AppData.mechanism_name == "HOC":
		return "Prev AROM: %.1fcm : %.1fcm (%.1fcm)" % [
			AppData.hoc_to_cm(amin), AppData.hoc_to_cm(amax),
			AppData.hoc_to_cm(amax - amin)
		]
	return "Prev AROM: %d° : %d° (%d°)" % [int(amin), int(amax), int(amax - amin)]

func _fmt_prom(pmin: float, pmax: float) -> String:
	if AppData.mechanism_name == "HOC":
		return "Prev PROM: %.1fcm : %.1fcm (%.1fcm)" % [
			AppData.hoc_to_cm(pmin), AppData.hoc_to_cm(pmax),
			AppData.hoc_to_cm(pmax - pmin)
		]
	return "Prev PROM: %d° : %d° (%d°)" % [int(pmin), int(pmax), int(pmax - pmin)]

func _fmt_range(lo: float, hi: float) -> String:
	if AppData.mechanism_name == "HOC":
		return "%.1fcm : %.1fcm (%.1fcm)" % [
			AppData.hoc_to_cm(lo), AppData.hoc_to_cm(hi),
			AppData.hoc_to_cm(hi - lo)
		]
	return "%d° : %d° (%d°)" % [int(lo), int(hi), int(hi - lo)]

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
