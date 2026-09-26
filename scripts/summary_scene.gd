extends Control

const GAMES      = ["FRUIT-BASKET", "HAT-TRICK", "PING-PONG", "RNR", "TUK-TUK"]
const MECH_NAMES = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]

const CLR_STAR_ON  = Color(1.0,  0.78, 0.0,  1.0)
const CLR_STAR_OFF = Color(0.75, 0.75, 0.75, 1.0)

@onready var _patient_label: Label   = %PatientLabel
@onready var _today_value:   Label   = %TodayValue
@onready var _prev_value:    Label   = %PrevValue
@onready var _done_button:   Button  = %DoneButton
@onready var _line_graph:    Control = %LineGraph

func _ready() -> void:
	_done_button.pressed.connect(_on_done_pressed)

	_patient_label.text = "Patient: " + AppData.patient_id

	var summary := DataManager.read_summary_stars()
	_today_value.text = "★  %d" % summary.get("today_total",    0)
	_prev_value.text  = "★  %d" % summary.get("previous_total", 0)

	_populate_mech_cards(summary.get("mech_game", {}))
	_populate_graph()

func _populate_mech_cards(mech_game: Dictionary) -> void:
	var config := {
		"WFE":  AppData.config_wfe,  "WURD": AppData.config_wurd,
		"FPS":  AppData.config_fps,  "HOC":  AppData.config_hoc,
		"FME1": AppData.config_fme1, "FME2": AppData.config_fme2,
	}
	var total_prescribed := 0
	for v in config.values():
		total_prescribed += v

	for mech in MECH_NAMES:
		var card: Panel = get_node("%" + mech + "Card")
		if card == null:
			continue
		var is_prescribed = (total_prescribed == 0) or (config.get(mech, 0) > 0)
		card.visible = is_prescribed
		if not is_prescribed:
			continue
		var mech_data: Dictionary = mech_game.get(mech, {})
		for i in range(GAMES.size()):
			var slot: Control = card.get_node("MechMargin/HBox/Stars/Star%d" % (i + 1))
			if slot == null:
				continue
			var today_stars: int = mech_data.get(GAMES[i], {}).get("today", 0)
			slot.visible = today_stars > 0
			if today_stars > 0:
				var star_lbl: Label = slot.get_node("S")
				if star_lbl:
					star_lbl.add_theme_color_override("font_color", CLR_STAR_ON)

func _on_done_pressed() -> void:
	PlutoComm.disconnect_device()
	AppData.is_patient_loaded    = false
	AppData.patient_id           = ""
	AppData.patient_start_date   = ""
	AppData.patient_end_date     = ""
	AppData.session_number       = 1
	AppData.trial_number_day     = 0
	AppData.trial_number_session = 0
	AppData.mechanism_index      = 0
	AppData.mechanism_name       = "NOMECH"
	AppData.is_calibrated        = false
	AppData.is_plan_setup        = false
	AppData.selected_mechanism   = null
	AppData.selected_game        = null
	get_tree().change_scene_to_file("res://scenes/MainScene.tscn")

func _populate_graph() -> void:
	var start := AppData.patient_start_date
	var end_d  := AppData.patient_end_date
	var usage: Dictionary
	if start != "":
		usage = DataManager.read_daily_usage(0, start, end_d)
	else:
		usage = DataManager.read_daily_usage(30)

	var dates := usage.keys()
	dates.sort()
	var labels: Array = []
	var vals:   Array = []
	for d in dates:
		labels.append(d)
		vals.append(usage[d] / 60.0)

	_line_graph.date_labels = labels
	_line_graph.values      = vals
	_line_graph.queue_redraw()
