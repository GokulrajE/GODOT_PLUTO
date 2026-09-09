extends Control

@onready var mech_label:   Label  = $Card/Header/MechLabel
@onready var status_label: Label  = $Card/StatusLabel

func _ready() -> void:
	mech_label.text = _get_mech_display_name()
	status_label.text = "Press PLUTO button or select a game below"

	$Card/HatTrickButton.pressed.connect(_on_hat_trick_pressed)
	EventBus.button_released.connect(_on_pluto_button)

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)

func _on_pluto_button() -> void:
	_on_hat_trick_pressed()

func _on_hat_trick_pressed() -> void:
	AppData.set_game("HAT-TRICK")
	get_tree().change_scene_to_file("res://scenes/HatrickScene.tscn")

func _get_mech_display_name() -> String:
	var names := {
		"WFE":  "WRIST FLEX/EXTENSION",
		"WURD": "WRIST ULNAR RADIAL DEVIATION",
		"FPS":  "FOREARM PRONATION SUPINATION",
		"HOC":  "HAND OPENING CLOSING",
		"FME1": "FUNCTIONAL MECHANISM 1",
		"FME2": "FUNCTIONAL MECHANISM 2",
	}
	return names.get(AppData.mechanism_name, AppData.mechanism_name)
