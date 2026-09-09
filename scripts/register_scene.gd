extends Control

@onready var patient_id_input:  LineEdit      = $FormPanel/PatientIDInput
@onready var start_date_input:  LineEdit      = $FormPanel/StartDateInput
@onready var end_date_input:    LineEdit      = $FormPanel/EndDateInput
@onready var left_button:       Button        = $FormPanel/TrainingSideRow/LeftButton
@onready var right_button:      Button        = $FormPanel/TrainingSideRow/RightButton
@onready var location_input:    LineEdit      = $FormPanel/LocationInput
@onready var register_button:   Button        = $FormPanel/ButtonsRow/RegisterButton
@onready var back_button:       Button        = $FormPanel/ButtonsRow/BackButton
@onready var status_label:      Label         = $FormPanel/StatusLabel

var _training_side: String = "Right"

func _ready() -> void:
	start_date_input.text = Time.get_date_string_from_system()
	_update_side_buttons()

	left_button.pressed.connect(func():
		_training_side = "Left"
		_update_side_buttons()
	)
	right_button.pressed.connect(func():
		_training_side = "Right"
		_update_side_buttons()
	)
	patient_id_input.focus_exited.connect(_check_patient_id)
	patient_id_input.text_submitted.connect(func(_t): _check_patient_id())

	register_button.pressed.connect(_on_register_pressed)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
	)

func _check_patient_id() -> void:
	var pid = patient_id_input.text.strip_edges()
	if pid.is_empty():
		return
	if DataManager.patient_exists(pid):
		_set_status("Patient ID '" + pid + "' already exists. Go back and login instead.", true)
		register_button.disabled = true
	else:
		status_label.text = ""
		register_button.disabled = false

func _update_side_buttons() -> void:
	left_button.modulate  = Color("#2ecc71") if _training_side == "Left"  else Color.WHITE
	right_button.modulate = Color("#2ecc71") if _training_side == "Right" else Color.WHITE

func _on_register_pressed() -> void:
	var pid      = patient_id_input.text.strip_edges()
	var start    = start_date_input.text.strip_edges()
	var end_date = end_date_input.text.strip_edges()
	var location = location_input.text.strip_edges()

	if pid.is_empty():
		_set_status("Patient ID is required.", true)
		return

	if DataManager.patient_exists(pid):
		_set_status("Patient ID already exists. Please login instead.", true)
		return

	if start.is_empty():
		start = Time.get_date_string_from_system()

	if DataManager.create_patient(pid, start, end_date, _training_side, location):
		_set_status("✓ Patient registered! Returning to login...", false)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
	else:
		_set_status("Failed to create patient data. Check folder permissions.", true)

func _set_status(msg: String, is_error: bool) -> void:
	status_label.text     = msg
	status_label.modulate = Color("#e74c3c") if is_error else Color("#2ecc71")
