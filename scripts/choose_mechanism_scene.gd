extends Control

const MECH_NAMES = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]

func _ready() -> void:
	PlutoComm.calibrate_start("NOMECH")
	PlutoComm.set_control_gain(1.0)

	for mech in MECH_NAMES:
		var btn = $MechGrid.get_node(mech)
		btn.pressed.connect(_on_mech_selected.bind(mech))

func _on_mech_selected(mech_name: String) -> void:
	var index = AppData.MECHANISMS.find(mech_name)
	AppData.set_mechanism(index)

	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/CalibrationScene.tscn")
