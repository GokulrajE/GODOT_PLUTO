extends Control

# ── Change this to your port ──────────────────────────────────────
const PORT = "COM45"  # Mac example
# const PORT = "COM3"               # Windows example

@onready var connect_button: Button = $CenterContainer/ConnectButton
@onready var status_label:   Label  = $StatusLabel

func _ready() -> void:
	connect_button.pressed.connect(_on_connect_pressed)
	status_label.text = "Port: " + PORT

func _on_button_released() -> void:
	get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")

func _on_connect_pressed() -> void:
	connect_button.disabled = true
	status_label.text = "Connecting to " + PORT + "..."
	status_label.modulate = Color("#888888")

	if PlutoComm.connect_device(PORT):
		PlutoComm.start_stream()
		status_label.text = "✓ Connected! Press PLUTO button to continue."
		status_label.modulate = Color("#2ecc71")
		await get_tree().create_timer(0.5).timeout
		PlutoComm.button_released.connect(_on_button_released)
	else:
		status_label.text = "✗ Failed. Check port and try again."
		status_label.modulate = Color("#e74c3c")
		connect_button.disabled = false
