extends Control

const MECH_NAMES = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]

const MECH_LABELS = {
	"WFE":  "Wrist Flex / Extension",
	"WURD": "Wrist Ulnar Radial Dev",
	"FPS":  "Forearm Pronation Sup",
	"HOC":  "Hand Opening / Closing",
	"FME1": "Functional Mechanism 1",
	"FME2": "Functional Mechanism 2",
}

const MECH_IMAGES = {
	"WFE":  "res://Assets/mechanismImages/FE.png",
	"WURD": "res://Assets/mechanismImages/ulnar_radial_out2.png",
	"FPS":  "res://Assets/mechanismImages/Pron_supin_out.png",
	"HOC":  "res://Assets/mechanismImages/hoc.png",
}

const KNOB_IMAGES = [
	"res://Assets/Knobs_PNG/1._Ball_Knob_Big-removebg-preview.png",
	"res://Assets/Knobs_PNG/2._Wing_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/3._Long_Handle-removebg-preview.png",
	"res://Assets/Knobs_PNG/4.1_T_knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/6._Crank_Handle-removebg-preview.png",
	"res://Assets/Knobs_PNG/7._Four_Pointed_Star-removebg-preview.png",
	"res://Assets/Knobs_PNG/8._Rotor_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/9._Small_Knob_-_Big-removebg-preview.png",
	"res://Assets/Knobs_PNG/10._Three_Pointed_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/11._Finger_Wheel-removebg-preview.png",
	"res://Assets/Knobs_PNG/12._Poteniometer_Knob-removebg-preview.png",
	"res://Assets/mechanismImages/KNOB.png",
	"res://Assets/mechanismImages/keyknob_outline.png",
]

func _ready() -> void:
	PlutoComm.calibrate_start("NOMECH")
	PlutoComm.set_control_gain(1.0)

	$HeaderPanel/SummaryButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/SummaryScene.tscn"))

	var config: Dictionary = {
		"WFE":  AppData.config_wfe,
		"WURD": AppData.config_wurd,
		"FPS":  AppData.config_fps,
		"HOC":  AppData.config_hoc,
		"FME1": AppData.config_fme1,
		"FME2": AppData.config_fme2,
	}
	var total_prescribed: int = 0
	for v in config.values():
		total_prescribed += v

	for mech in MECH_NAMES:
		var btn: Button = $MechGrid.get_node(mech)
		var is_prescribed: bool = (total_prescribed == 0) or (config.get(mech, 0) > 0)
		btn.visible = is_prescribed
		if not is_prescribed:
			continue
		_populate_button(btn, mech, config.get(mech, 0))
		btn.pressed.connect(_on_mech_selected.bind(mech))

func _populate_button(btn: Button, mech: String, time_val: int) -> void:
	btn.text = ""

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var img_path := ""
	if mech == "FME1":
		var kid := AppData.config_fme1_id
		img_path = KNOB_IMAGES[kid] if kid >= 0 and kid < KNOB_IMAGES.size() else ""
	elif mech == "FME2":
		var kid := AppData.config_fme2_id
		img_path = KNOB_IMAGES[kid] if kid >= 0 and kid < KNOB_IMAGES.size() else ""
	elif MECH_IMAGES.has(mech):
		img_path = MECH_IMAGES[mech]

	if img_path != "" and ResourceLoader.exists(img_path):
		var tex := TextureRect.new()
		tex.texture       = load(img_path)
		tex.custom_minimum_size  = Vector2(72, 72)
		tex.expand_mode   = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if mech != "FME1" and mech != "FME2":
			tex.modulate = Color(0, 0, 0, 1)
		tex.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tex)

	var name_lbl := Label.new()
	name_lbl.text = mech
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.082, 0.157, 0.094))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var full_lbl := Label.new()
	full_lbl.text = MECH_LABELS.get(mech, "")
	full_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	full_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	full_lbl.add_theme_font_size_override("font_size", 13)
	full_lbl.add_theme_color_override("font_color", Color(0.353, 0.510, 0.369))
	full_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(full_lbl)

	if time_val > 0:
		var time_lbl := Label.new()
		time_lbl.text = "%d min" % time_val
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_lbl.add_theme_font_size_override("font_size", 14)
		time_lbl.add_theme_color_override("font_color", Color(0.059, 0.502, 0.259))
		time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(time_lbl)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_X \
			and event.ctrl_pressed and event.shift_pressed:
		AppData.is_plan_setup = true
		get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")

func _on_mech_selected(mech_name: String) -> void:
	var index = AppData.MECHANISMS.find(mech_name)
	AppData.set_mechanism(index)
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/CalibrationScene.tscn")
