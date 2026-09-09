extends Control

const PORT = "COM45"

# ── Login panel ───────────────────────────────────────────────────────
@onready var login_panel:      VBoxContainer = $LoginPanel
@onready var patient_id_input: LineEdit      = $LoginPanel/PatientIDInput
@onready var login_button:     Button        = $LoginPanel/LoginButton
@onready var register_button:  Button        = $LoginPanel/RegisterButton
@onready var login_status:     Label         = $LoginPanel/LoginStatus

# ── Connect panel (shown after login) ─────────────────────────────────
@onready var connect_panel:    VBoxContainer = $ConnectPanel
@onready var patient_label:    Label         = $ConnectPanel/PatientLabel
@onready var connect_button:   Button        = $ConnectPanel/ConnectButton
@onready var connect_status:   Label         = $ConnectPanel/ConnectStatus

func _ready() -> void:
	connect_panel.visible = false
	login_status.text     = ""

	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/RegisterScene.tscn")
	)
	connect_button.pressed.connect(_on_connect_pressed)

func _on_login_pressed() -> void:
	var pid = patient_id_input.text.strip_edges()
	if pid.is_empty():
		_set_login_status("Please enter a Patient ID.", true)
		return

	if not DataManager.patient_exists(pid):
		_set_login_status("Patient not found. Please register first.", true)
		return

	if DataManager.load_patient(pid):
		login_panel.visible   = false
		connect_panel.visible = true
		patient_label.text    = "Patient: " + pid
		connect_status.text   = "Port: " + PORT
		connect_status.modulate = Color.WHITE
	else:
		_set_login_status("Failed to load patient data.", true)

func _on_connect_pressed() -> void:
	connect_button.disabled = true
	connect_status.text     = "Connecting to " + PORT + "..."
	connect_status.modulate = Color("#888888")

	if PlutoComm.connect_device(PORT):
		PlutoComm.start_stream()
		connect_status.text    = "✓ Connected! Press PLUTO button to continue."
		connect_status.modulate = Color("#2ecc71")
		await get_tree().create_timer(0.5).timeout
		EventBus.button_released.connect(_on_pluto_button)
	else:
		connect_status.text    = "✗ Failed. Check port and try again."
		connect_status.modulate = Color("#e74c3c")
		connect_button.disabled = false

func _on_pluto_button() -> void:
	get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")

func _set_login_status(msg: String, is_error: bool) -> void:
	login_status.text     = msg
	login_status.modulate = Color("#e74c3c") if is_error else Color("#2ecc71")
