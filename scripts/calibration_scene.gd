extends Control

@onready var mech_label:        Label  = $MechLabel
@onready var instruction_label: Label  = $InstructionLabel
@onready var angle_label:       Label  = $AngleLabel
@onready var back_button:       Button = $HeaderPanel/BackButton

var is_calibrating:    bool = false
var done_calibration:  bool = false
var start_calibration: bool = false

func _ready() -> void:
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

	instruction_label.text = "Press the PLUTO button to calibrate."

func _on_data() -> void:
	angle_label.text = "%.3f" % PlutoComm.angle

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
	instruction_label.modulate = Color.WHITE

	PlutoComm.set_control_type("TORQUE")
	PlutoComm.set_control_target(torque_ccw)
	await get_tree().create_timer(1.5).timeout

	PlutoComm.calibrate_start(AppData.mechanism_name)
	await get_tree().create_timer(0.5).timeout

	PlutoComm.set_control_target(torque_cw)
	await get_tree().create_timer(1.5).timeout

	var angle_val  = PlutoComm.angle + AppData.mech_offset
	is_calibrating = false

	if abs(angle_val) < 0.9 * AppData.calib_angle or abs(angle_val) > 1.1 * AppData.calib_angle:
		PlutoComm.set_control_target(0.0)
		PlutoComm.set_control_type("NONE")
		instruction_label.text     = "Try Again."
		instruction_label.modulate = Color.RED
		done_calibration  = false
		is_calibrating    = false
		start_calibration = false
		return

	PlutoComm.calibrate_end(AppData.mechanism_name)
	await get_tree().create_timer(0.5).timeout

	if is_hoc:
		PlutoComm.calibrate_start(AppData.mechanism_name)
		await get_tree().create_timer(0.5).timeout
		PlutoComm.calibrate_end(AppData.mechanism_name)

	PlutoComm.set_control_target(0.0)
	PlutoComm.set_control_type("NONE")
	await get_tree().create_timer(1.5).timeout

	AppData.is_calibrated = true
	done_calibration      = true
	instruction_label.text     = "Calibration Done"
	instruction_label.modulate = Color(0.24, 0.84, 0.44)
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
