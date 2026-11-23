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
	Color(0.62, 0.42, 0.92),  # cycle 3 — purple
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
	preload("res://scripts/ui/rehab_refinement.gd").apply.call_deferred(self)
	PlutoComm.set_control_type("NONE")
	_ang_limit = (AppData.calib_angle + 10.0) if AppData.mechanism_name == "HOC" \
				 else (AppData.mech_offset + 10.0)
	_setup_labels()
	_select_arom()
	_build_widgets_when_laid_out.call_deferred()

	exit_button.pressed.connect(func():
		var dest = "res://scenes/ChooseGameScene.tscn" if AppData.assess_from_games else ("res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup else "res://scenes/ChooseMechanism.tscn")
		AppData.assess_from_games = false
		get_tree().change_scene_to_file(dest)
	)
	change_mech_btn.pressed.connect(func():
		var dest = "res://scenes/ChooseGameScene.tscn" if AppData.assess_from_games else ("res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup else "res://scenes/ChooseMechanism.tscn")
		AppData.assess_from_games = false
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
	_refresh_state_ui()
	var angle = PlutoComm.angle
	if _arom_selected:
		arom_angle_label.text = "%.1f" % (AppData.hoc_to_cm(angle) if AppData.mechanism_name == "HOC" else angle)
	if _prom_selected:
		prom_angle_label.text = "%.1f" % (AppData.hoc_to_cm(angle) if AppData.mechanism_name == "HOC" else angle)
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
	_highlight_prompts()

# ── Attention: the line that asks the user to act ("Press PLUTO button ...") and the result colour ──

var _prompts := {}
var _prompt_t := 0.0

## Lifts the "Press PLUTO button ..." instruction out of the status text into a bold amber banner that
## gently pulses, and colours the rest of the status by what is happening (amber while measuring,
## green when done), so the important line cannot be missed.
func _highlight_prompts() -> void:
	_prompt_t += get_process_delta_time()
	for pair in [[arom_status, arom_panel, true], [prom_status, $PromPanel, false]]:
		var status: Label = pair[0]
		var panel: Control = pair[1]
		var lines: PackedStringArray = status.text.split("
")
		var kept: PackedStringArray = []
		var prompt := ""
		for line in lines:
			if line.strip_edges().to_lower().begins_with("press "):
				prompt = line.strip_edges()
			else:
				kept.append(line)
		# drop blank lines left behind at the end
		while kept.size() > 0 and kept[kept.size() - 1].strip_edges() == "":
			kept.remove_at(kept.size() - 1)
		var holder: PanelContainer = _prompts.get(panel)
		if holder == null:
			holder = _make_prompt(panel, status)
			_prompts[panel] = holder
		var label := holder.get_child(0) as Label
		status.text = "
".join(kept)
		holder.visible = prompt != "" and panel.is_inside_tree()
		if prompt != "":
			label.text = "▶  " + prompt.trim_prefix("Press ").capitalize() if false else "▶  " + prompt
			var pulse := 0.5 + 0.5 * sin(_prompt_t * 4.0)
			holder.self_modulate = Color(1, 1, 1, 1)
			var sb := holder.get_theme_stylebox("panel") as StyleBoxFlat
			sb.bg_color = Color("ffbf3c").lerp(Color("ffd978"), pulse)
		# status body colour follows the state
		var done: bool = (pair[2] and (_arom_state == AromState.TRIAL_COMPLETE or _arom_state == AromState.ASSESSMENT_COMPLETE)) 				or (not pair[2] and _prom_state == PromState.ASSESS and false)
		var measuring: bool = (pair[2] and _arom_state == AromState.TRIAL_RUNNING) or (not pair[2] and _prom_selected and _prom_state == PromState.ASSESS)
		status.add_theme_color_override("font_color", Color("0b7a3d") if done else (Color("8a5300") if measuring else Color("1a2e44")))
		status.add_theme_font_size_override("font_size", 17)

func _make_prompt(panel: Control, status: Label) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.set_meta("arcade_authored_control", true)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffbf3c")
	sb.border_color = Color("c98400")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	holder.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.set_meta("arcade_authored_control", true)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("3a2400"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 250
	holder.add_child(label)
	panel.add_child(holder)
	holder.anchor_left = .04; holder.anchor_right = .48
	holder.anchor_top = .83; holder.anchor_bottom = .95
	holder.offset_left = 0; holder.offset_right = 0; holder.offset_top = 0; holder.offset_bottom = 0
	return holder

## The panels are laid out (and globally restyled) a moment after _ready, so the widgets that depend
## on the final sizes are built, and the per-state look applied, a little later.
func _build_widgets_when_laid_out() -> void:
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	_build_bar_widgets()
	_state_sig = ""
	_update_cycle_marker_positions()

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
	_refresh_cycle_list()

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
	_refresh_cycle_list()
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
	# The look of a finished AROM (solid green card, green header, "AROM DONE" chip) comes from
	# _refresh_state_ui(); here we only freeze the saved result in the reading.
	var is_hoc = AppData.mechanism_name == "HOC"
	if is_hoc:
		arom_angle_label.text = "%.1fcm–%.1fcm" % [AppData.hoc_to_cm(lo), AppData.hoc_to_cm(hi)]
	else:
		arom_angle_label.text = "%d°–%d°" % [int(lo), int(hi)]
	_state_sig = ""

# =========================================================================
# AROM — UI display helpers
# =========================================================================

# =========================================================================
# Range bar: knob, reached-range fill, MIN / MAX tabs, cycle flags and per-state look
# =========================================================================

const KNOB_W := 16.0
const TAB_W := 40.0
const TAB_H := 18.0
const SLATE := Color("1f3a5f")

var _flags: Control = null
var _arom_reach: Panel = null
var _prom_reach: Panel = null
var _chips := {}
var _state_sig := ""

func _flat(fill: Color, border: Color, radius: int, border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

func _build_bar_widgets() -> void:
	var arom_box := arom_track.get_parent() as Control
	_arom_reach = _make_reach(arom_box, arom_track)
	_prom_reach = _make_reach(prom_track.get_parent() as Control, prom_track)
	for pair in [[arom_min_cursor, "MIN"], [arom_max_cursor, "MAX"], [prom_min_cursor, "MIN"], [prom_max_cursor, "MAX"]]:
		_style_tab(pair[0], pair[1])
	for knob in [arom_curr_cursor, prom_curr_cursor]:
		var sb := _flat(Color.WHITE, Color("087f83"), 8, 3)
		sb.shadow_color = Color(0.05, 0.2, 0.3, 0.35)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 2)
		knob.add_theme_stylebox_override("panel", sb)
		knob.size.x = KNOB_W
	_flags = preload("res://scripts/ui/cycle_flags.gd").new()
	_flags.name = "CycleFlags"
	arom_box.add_child(_flags)
	_flags.size = arom_box.size
	arom_box.resized.connect(func(): _flags.size = arom_box.size)
	_build_chips()

func _make_reach(box: Control, track: Control) -> Panel:
	var reach := Panel.new()
	reach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reach.set_meta("arcade_authored_control", true)
	reach.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.5, 0.52, 0.55), Color(0, 0, 0, 0), 9))
	box.add_child(reach)
	box.move_child(reach, track.get_index() + 1)
	reach.visible = false
	return reach

func _style_tab(tab: Panel, text: String) -> void:
	tab.add_theme_stylebox_override("panel", _flat(SLATE, Color(1, 1, 1, 0.9), 9, 1))
	tab.size = Vector2(TAB_W, TAB_H)
	tab.visible = false          # shown once there is a range to mark
	tab.set_meta("arcade_authored_control", true)
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_meta("arcade_authored_control", true)
	tab.add_child(label)

func _place_knob(track: Control, knob: Control, angle: float) -> void:
	var tw: float = track.size.x
	if tw == 0.0:
		return
	knob.size = Vector2(KNOB_W, track.size.y + 12.0)
	knob.position = Vector2(
		track.position.x + clampf(_display_fraction(angle), 0.0, 1.0) * tw - KNOB_W * 0.5,
		track.position.y - 6.0)

func _place_reach(track: Control, min_tab: Control, max_tab: Control, reach: Panel, min_val: float, max_val: float) -> void:
	var tw: float = track.size.x
	if tw == 0.0 or reach == null:
		return
	var x0: float = track.position.x + clampf(_display_fraction(min_val), 0.0, 1.0) * tw
	var x1: float = track.position.x + clampf(_display_fraction(max_val), 0.0, 1.0) * tw
	reach.visible = true
	min_tab.visible = true
	max_tab.visible = true
	reach.position = Vector2(x0, track.position.y)
	reach.size = Vector2(maxf(x1 - x0, 2.0), track.size.y)
	var y: float = track.position.y + track.size.y + 4.0
	var lo_x := clampf(x0 - TAB_W * 0.5, track.position.x - 6.0, track.position.x + tw - TAB_W + 6.0)
	var hi_x := clampf(x1 - TAB_W * 0.5, track.position.x - 6.0, track.position.x + tw - TAB_W + 6.0)
	# keep the two tabs from sitting on top of each other when the range is tiny
	if hi_x - lo_x < TAB_W + 2.0:
		var mid := (lo_x + hi_x) * 0.5
		lo_x = mid - TAB_W - 1.0
		hi_x = mid + 1.0
	min_tab.position = Vector2(lo_x, y)
	max_tab.position = Vector2(hi_x, y)

func _build_chips() -> void:
	for pair in [[arom_panel, "AromHeaderBar"], [$PromPanel, "PromHeaderBar"]]:
		var panel: Control = pair[0]
		var chip := Label.new()
		chip.name = "StateChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_meta("arcade_authored_control", true)
		chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		chip.offset_left = -236.0
		chip.offset_right = -16.0
		chip.offset_top = 12.0
		chip.offset_bottom = 42.0
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", 14)
		chip.z_index = 2
		panel.add_child(chip)
		_chips[panel] = chip

## What each panel is doing right now, shown as a coloured chip in its header, a card colour and
## border, and a dimmed look for the panel that is not active yet.
func _panel_look(is_arom: bool) -> Dictionary:
	var slate := {"chip_bg": Color("e4edf3"), "chip_fg": Color("3d556b")}
	var amber := {"chip_bg": Color("ffe7b0"), "chip_fg": Color("7a4a00")}
	var teal := {"chip_bg": Color("c6ebec"), "chip_fg": Color("075c60")}
	var blue := {"chip_bg": Color("d7e4fb"), "chip_fg": Color("1f3f8a")}
	var done := {"chip_bg": Color("1f9d55"), "chip_fg": Color.WHITE}
	var look: Dictionary
	if is_arom:
		if _arom_state == AromState.ASSESSMENT_COMPLETE and not _arom_selected:
			look = done.duplicate(); look.text = "AROM DONE  ✓"; look.mode = "done"
		elif _arom_state == AromState.ASSESSMENT_COMPLETE:
			look = blue.duplicate(); look.text = "REVIEW RESULT"; look.mode = "active"
		elif _arom_state == AromState.TRIAL_COMPLETE:
			look = teal.duplicate(); look.text = "TRIAL COMPLETE"; look.mode = "active"
		elif _arom_state == AromState.TRIAL_RUNNING:
			look = amber.duplicate(); look.text = "MEASURING  %d / %d" % [mini(_completed_cycles + 1, CYCLES_PER_TRIAL), CYCLES_PER_TRIAL]; look.mode = "active"
		else:
			look = slate.duplicate(); look.text = "READY"; look.mode = "active"
	else:
		if not _prom_selected:
			look = slate.duplicate(); look.text = "WAITING FOR AROM"; look.mode = "idle"
		elif _prom_state == PromState.ASSESS:
			look = amber.duplicate(); look.text = "MEASURING"; look.mode = "active"
		else:
			look = slate.duplicate(); look.text = "READY"; look.mode = "active"
	return look

func _refresh_state_ui() -> void:
	if _chips.is_empty():
		return
	var sig := "%d|%d|%d|%d|%d" % [_arom_state, _prom_state, int(_arom_selected), int(_prom_selected), _completed_cycles]
	if sig == _state_sig:
		return
	_state_sig = sig
	for pair in [[arom_panel, true, "AromHeaderBar", "AromTitle"], [$PromPanel, false, "PromHeaderBar", "PromTitle"]]:
		var panel: Panel = pair[0]
		var look := _panel_look(pair[1])
		var chip: Label = _chips[panel]
		chip.text = look.text
		chip.add_theme_color_override("font_color", look.chip_fg)
		chip.add_theme_stylebox_override("normal", _flat(look.chip_bg, look.chip_fg.darkened(0.1) if look.mode == "done" else Color(look.chip_fg, 0.25), 14, 1))
		var card: StyleBoxFlat
		var header_fill := Color("fbfdfe")
		var title_color := Color("1a2e44")
		match look.mode:
			"done":
				card = _flat(Color("e2f4e8"), Color("1f9d55"), 18, 3)
				header_fill = Color("1f9d55")
				title_color = Color.WHITE
			"active":
				card = _flat(Color("fbfdfef2"), Color("087f83"), 18, 3)
			_:
				card = _flat(Color("eef3f6e6"), Color("c4d4da"), 18, 1)
		card.shadow_color = Color(0.1, 0.25, 0.3, 0.14)
		card.shadow_size = 8
		panel.add_theme_stylebox_override("panel", card)
		panel.modulate = Color(1, 1, 1, 0.82) if look.mode == "idle" else Color.WHITE
		var header := panel.get_node_or_null(pair[2]) as Panel
		if header:
			header.add_theme_stylebox_override("panel", _flat(header_fill, Color(0, 0, 0, 0), 14))
		var title := panel.get_node_or_null(pair[3]) as Label
		if title:
			title.add_theme_color_override("font_color", title_color)

# =========================================================================
# AROM — cycle marker UI helpers
# =========================================================================

func _add_cycle_markers(lo: float, hi: float, cycle_idx: int) -> void:
	_cycle_marker_data.append({"lo": lo, "hi": hi, "cycle_idx": cycle_idx, "best": false})
	_update_cycle_marker_positions()

func _highlight_best_cycle_marker(best_lo: float, best_hi: float) -> void:
	for m in _cycle_marker_data:
		m.best = abs(m.lo - best_lo) < 0.1 and abs(m.hi - best_hi) < 0.1
	_update_cycle_marker_positions()

func _clear_cycle_markers() -> void:
	_cycle_marker_data.clear()
	_update_cycle_marker_positions()
	_refresh_cycle_list()

## One line per completed cycle ("1  -32.0° → 41.0°  (73.0°)"), in the same colour as that cycle's
## markers on the bar; the best cycle of the trial is starred.
func _refresh_cycle_list() -> void:
	var list := arom_panel.get_node_or_null("CycleList") as RichTextLabel
	if list == null:
		return
	var is_hoc := AppData.mechanism_name == "HOC"
	var best := {}
	if _arom_state == AromState.TRIAL_COMPLETE or _arom_state == AromState.ASSESSMENT_COMPLETE:
		best = _trial_best
	var text := "[b]Cycle ranges[/b]" + "\n"
	for i in _trial_cycles.size():
		var c: Dictionary = _trial_cycles[i]
		var color: Color = CYCLE_COLORS[i % CYCLE_COLORS.size()]
		var is_best: bool = not best.is_empty() and absf(c.lo - best.lo) < 0.1 and absf(c.hi - best.hi) < 0.1
		var range_text: String
		if is_hoc:
			range_text = "%.1f → %.1f cm  (%.1f)" % [AppData.hoc_to_cm(c.lo), AppData.hoc_to_cm(c.hi), absf(AppData.hoc_to_cm(c.hi) - AppData.hoc_to_cm(c.lo))]
		else:
			range_text = "%.1f° → %.1f°  (%.1f°)" % [c.lo, c.hi, c.hi - c.lo]
		text += "[color=#%s]●[/color] [b]%d[/b]   %s%s" % [color.to_html(false), i + 1, range_text, "  [color=#b07a00]★ best[/color]" if is_best else ""] + "\n"
	list.text = text

func _update_cycle_marker_positions() -> void:
	if _flags == null:
		return
	var tw: float = arom_track.size.x
	var lows := []
	var highs := []
	for m in _cycle_marker_data:
		var color: Color = BEST_CYCLE_COLOR if m.best else CYCLE_COLORS[m.cycle_idx % CYCLE_COLORS.size()]
		var base := {"color": color, "label": str(int(m.cycle_idx) + 1), "best": m.best}
		var lo_item: Dictionary = base.duplicate()
		lo_item.x = arom_track.position.x + clampf(_display_fraction(m.lo), 0.0, 1.0) * tw
		lo_item.side = 1.0
		var hi_item: Dictionary = base.duplicate()
		hi_item.x = arom_track.position.x + clampf(_display_fraction(m.hi), 0.0, 1.0) * tw
		hi_item.side = -1.0
		lows.append(lo_item)
		highs.append(hi_item)
	# poles that are close together get different heights (three levels), so every flag stays readable
	var items := []
	for group in [lows, highs]:
		group.sort_custom(func(a, b): return a.x < b.x)
		for i in group.size():
			group[i].level = i % 3
			items.append(group[i])
	_flags.set_items(items, arom_track.position.y, arom_track.position.y + arom_track.size.y)

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
	_place_reach(arom_track, arom_min_cursor, arom_max_cursor, _arom_reach, min_val, max_val)

func _update_prom_cursors(min_val: float, max_val: float) -> void:
	_place_reach(prom_track, prom_min_cursor, prom_max_cursor, _prom_reach, min_val, max_val)

func _update_curr_cursor(angle: float) -> void:
	if _arom_selected and arom_curr_cursor.visible:
		_place_knob(arom_track, arom_curr_cursor, angle)
	if _prom_selected and prom_curr_cursor.visible:
		_place_knob(prom_track, prom_curr_cursor, angle)

func _setup_labels() -> void:
	$AromPanel/AngleUnitLabel.text = "centimetres" if AppData.mechanism_name == "HOC" else "degrees"
	$PromPanel/AngleUnitLabel.text = "centimetres" if AppData.mechanism_name == "HOC" else "degrees"
	var mech_idx = AppData.mechanism_index - 1
	var is_hoc   = AppData.mechanism_name == "HOC"
	if mech_idx >= 0 and mech_idx < DIRECTION_TEXT.size():
		arom_left_label.text  = DIRECTION_TEXT[mech_idx][0]
		arom_right_label.text = DIRECTION_TEXT[mech_idx][1]
		prom_left_label.text  = DIRECTION_TEXT[mech_idx][0]
		prom_right_label.text = DIRECTION_TEXT[mech_idx][1]
	arom_center_label.visible = false
	prom_center_label.visible = false
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

# HOC is one-sided: opening is negative and fully closed is zero.
# Only presentation is normalized; assessment values stay in sensor units.
func _display_fraction(angle: float) -> float:
	if not is_finite(angle): return 0.0
	if AppData.mechanism_name == "HOC":
		var span := maxf(1.0, float(AppData.calib_angle))
		return clampf((angle + span) / span, 0.0, 1.0)
	var span := maxf(1.0, absf(_ang_limit))
	return clampf((angle + span) / (span * 2.0), 0.0, 1.0)
