extends Control

@onready var mech_label:        Label  = $MechLabel
@onready var instruction_label: Label  = $InstructionLabel
@onready var angle_label:       Label  = $AngleLabel
@onready var back_button:       Button = $HeaderPanel/BackButton

var is_calibrating:    bool = false
var done_calibration:  bool = false
var start_calibration: bool = false

# Light glass look, matching the other menu scenes
const INK    := Color("1a2e44")
const MUTED  := Color("4d6478")
const ACCENT := Color("087f83")
const GLASS  := Color("fbfdfef2")
const EDGE   := Color("c4dcdf")

var gauge:        AngleGauge
var progress_bar: ProgressBar
var step_label:   Label
var _tween:       Tween

func _ready() -> void:
	_apply_dark_design()
	mech_label.text = AppData.mechanism_name

	back_button.pressed.connect(func():
		PlutoComm.set_control_type("NONE")
		var dest = "res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup else "res://scenes/ChooseMechanism.tscn"
		get_tree().change_scene_to_file(dest)
	)

	EventBus.button_released.connect(_on_button_released)
	EventBus.new_sensor_data.connect(_on_data)

	PlutoComm.calibrate_start(AppData.mechanism_name)
	PlutoComm.calibrate_end(AppData.mechanism_name)

	_build_gauge()
	_build_progress_ui()
	instruction_label.text = "Press the PLUTO button to calibrate."

func _on_data() -> void:
	angle_label.text = "%.3f" % PlutoComm.angle
	if gauge: gauge.set_value(PlutoComm.angle)

# -- Dark forest design ---------------------------------------------------------
func _glass(radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.1, 0.25, 0.3, 0.16)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	return sb

func _place(c: Control, box: Rect2) -> void:
	c.anchor_left = box.position.x;  c.anchor_top = box.position.y
	c.anchor_right = box.end.x;      c.anchor_bottom = box.end.y
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0

func _apply_dark_design() -> void:
	var backdrop := get_node_or_null("ArcadeBackdrop") as TextureRect
	if backdrop:
		backdrop.texture = load("res://Assets/menu_background_blur.png")
		backdrop.modulate = Color.WHITE
	for n in ["MainCard", "AngleBoxBG"]:
		(get_node(n) as Panel).add_theme_stylebox_override("panel", _glass(20 if n == "MainCard" else 16))
	var header := $HeaderPanel as Panel
	header.add_theme_stylebox_override("panel", _glass(18))
	back_button.text = back_button.text.trim_prefix("← ")     # the icon already shows the arrow
	back_button.offset_left = -214      # clear of the device-status badge in the top-right corner
	back_button.offset_right = -80
	$HeaderPanel/TitleLabel.add_theme_color_override("font_color", INK)
	$HeaderPanel/HeaderSubLabel.add_theme_color_override("font_color", INK)
	mech_label.add_theme_color_override("font_color", ACCENT)
	mech_label.add_theme_font_size_override("font_size", 18)
	for lbl in [$AngleTitleLabel, $AngleUnitLabel]:
		lbl.add_theme_color_override("font_color", MUTED)
	angle_label.add_theme_color_override("font_color", INK)
	angle_label.add_theme_font_size_override("font_size", 64)
	instruction_label.add_theme_color_override("font_color", INK)
	instruction_label.add_theme_font_size_override("font_size", 22)
	# Layout (fractions of the screen): card > name, angle box, dial, instruction, progress
	_place($MainCard,        Rect2(0.27, 0.15, 0.46, 0.76))
	_place(mech_label,       Rect2(0.27, 0.17, 0.46, 0.05))
	_place($AngleTitleLabel, Rect2(0.27, 0.285, 0.46, 0.04))
	_place($AngleBoxBG,      Rect2(0.34, 0.33, 0.32, 0.14))
	_place(angle_label,      Rect2(0.34, 0.33, 0.32, 0.14))
	_place($AngleUnitLabel,  Rect2(0.27, 0.475, 0.46, 0.04))
	_place(instruction_label, Rect2(0.29, 0.775, 0.42, 0.06))

func _build_gauge() -> void:
	gauge = AngleGauge.new()
	gauge.set_meta("arcade_authored_control", true)
	add_child(gauge)
	_place(gauge, Rect2(0.30, 0.52, 0.40, 0.25))
	# The mechanism spans angles -offset .. (calib_angle - offset). Calibration is accepted
	# when |angle + offset| is 90-110 % of calib_angle, so the target zone is the top 10 %.
	var lo := -AppData.mech_offset
	var hi := float(AppData.calib_angle) - AppData.mech_offset
	var unit := "" if AppData.mechanism_name == "HOC" else "°"
	gauge.configure(lo, hi, 0.9 * AppData.calib_angle - AppData.mech_offset, unit)
	if AppData.mechanism_name == "HOC":
		$AngleUnitLabel.text = "HOC units"

# -- Progress UI --------------------------------------------------------------
func _build_progress_ui() -> void:
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.visible = false
	var track := StyleBoxFlat.new(); track.bg_color = Color("d3e6e8"); track.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new();  fill.bg_color = Color("087f83");  fill.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	add_child(progress_bar)
	_place(progress_bar, Rect2(0.32, 0.845, 0.36, 0.0))
	progress_bar.offset_bottom = 12

	step_label = Label.new()
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 15)
	step_label.add_theme_color_override("font_color", MUTED)
	step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_label.visible = false
	step_label.set_meta("arcade_authored_control", true)   # keep the global restyler off these
	progress_bar.set_meta("arcade_authored_control", true)
	add_child(step_label)
	_place(step_label, Rect2(0.27, 0.865, 0.46, 0.04))

## Smoothly fills the bar to `pct` over `duration` seconds and shows the step name.
func _set_progress(pct: float, duration: float, step: String) -> void:
	progress_bar.visible = true
	step_label.visible = true
	step_label.text = step
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(progress_bar, "value", pct, duration)

func _reset_progress() -> void:
	if _tween: _tween.kill()
	progress_bar.value = 0.0
	progress_bar.visible = false
	step_label.visible = false

func _on_button_released() -> void:
	if not done_calibration and not is_calibrating and not start_calibration:
		start_calibration = true
		_auto_calibrate()

func _auto_calibrate() -> void:
	is_calibrating    = true
	start_calibration = false

	var is_hoc     = AppData.mechanism_name == "HOC"
	var torque_ccw = -0.11 if is_hoc else -0.09
	var torque_cw  =  0.11 if is_hoc else  0.09

	instruction_label.text     = "Calibrating..."
	instruction_label.add_theme_color_override("font_color", INK)

	# Progress weights = seconds of waiting: 1.5 + 0.5 + 1.5 + 0.5 (+1.0 HOC) + 1.5
	var total := 6.5 if is_hoc else 5.5
	var done := 0.0
	progress_bar.value = 0.0

	PlutoComm.set_control_type("TORQUE")
	PlutoComm.set_control_target(torque_ccw)
	done += 1.5
	_set_progress(done / total * 100.0, 1.5, "Step 1: moving to first limit...")
	await get_tree().create_timer(1.5).timeout

	PlutoComm.calibrate_start(AppData.mechanism_name)
	done += 0.5
	_set_progress(done / total * 100.0, 0.5, "Step 2: marking zero...")
	await get_tree().create_timer(0.5).timeout

	PlutoComm.set_control_target(torque_cw)
	done += 1.5
	_set_progress(done / total * 100.0, 1.5, "Step 3: moving to opposite limit...")
	await get_tree().create_timer(1.5).timeout

	var angle_val  = PlutoComm.angle + AppData.mech_offset
	is_calibrating = false

	if abs(angle_val) < 0.9 * AppData.calib_angle or abs(angle_val) > 1.1 * AppData.calib_angle:
		PlutoComm.set_control_target(0.0)
		PlutoComm.set_control_type("NONE")
		_reset_progress()
		instruction_label.text     = "Try Again. Press the PLUTO button to retry."
		instruction_label.add_theme_color_override("font_color", Color("c0273a"))
		done_calibration  = false
		is_calibrating    = false
		start_calibration = false
		return

	PlutoComm.calibrate_end(AppData.mechanism_name)
	done += 0.5
	_set_progress(done / total * 100.0, 0.5, "Step 4: saving calibration...")
	await get_tree().create_timer(0.5).timeout

	if is_hoc:
		done += 1.0
		_set_progress(done / total * 100.0, 1.0, "Step 4b: finalising HOC...")
		PlutoComm.calibrate_start(AppData.mechanism_name)
		await get_tree().create_timer(0.5).timeout
		PlutoComm.calibrate_end(AppData.mechanism_name)

	PlutoComm.set_control_target(0.0)
	PlutoComm.set_control_type("NONE")
	_set_progress(100.0, 1.5, "Releasing motor...")
	await get_tree().create_timer(1.5).timeout
	step_label.text = "Complete"

	AppData.is_calibrated = true
	done_calibration      = true
	instruction_label.text     = "Calibration Done"
	instruction_label.add_theme_color_override("font_color", Color("0b7a3d"))
	EventBus.calibration_done.emit()

	await get_tree().create_timer(0.4).timeout
	var is_fme := AppData.mechanism_name == "FME1" or AppData.mechanism_name == "FME2"
	if is_fme:
		if AppData.selected_mechanism != null:
			AppData.selected_mechanism.set_new_prom(-90.0, 90.0)
			AppData.selected_mechanism.set_new_arom(-90.0, 90.0)
			AppData.selected_mechanism.set_new_aprom(-90.0, 90.0)
		var dest := "res://scenes/PlanSetupScene.tscn" if AppData.is_plan_setup \
			else "res://scenes/ChooseGameScene.tscn"
		get_tree().change_scene_to_file(dest)
	elif AppData.is_plan_setup:
		get_tree().change_scene_to_file("res://scenes/AssessmentScene.tscn")
	elif _has_prior_full_assessment():
		get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/AssessmentScene.tscn")

func _has_prior_full_assessment() -> bool:
	var mech = AppData.selected_mechanism
	if mech == null or mech.old_rom == null:
		return false
	var r = mech.old_rom
	return r.is_set and (r.aprom_min != 0.0 or r.aprom_max != 0.0)

func _exit_tree() -> void:
	PlutoComm.set_control_type("NONE")
	if EventBus.button_released.is_connected(_on_button_released):
		EventBus.button_released.disconnect(_on_button_released)
	if EventBus.new_sensor_data.is_connected(_on_data):
		EventBus.new_sensor_data.disconnect(_on_data)
