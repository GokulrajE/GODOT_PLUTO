extends Control

const PORT = "COM45"

# Chart layout constants (must match ChartContainer custom_minimum_size in scene)
const _CHART_H    := 200.0
const _VAL_H      := 18.0
const _DAY_H      := 20.0
const _BAR_AREA_H := 162.0

const _CLR_FULL  := Color(0.059, 0.502, 0.259, 1.0)
const _CLR_PART  := Color(0.153, 0.714, 0.376, 1.0)
const _CLR_NONE  := Color(0.824, 0.929, 0.839, 1.0)
const _CLR_TODAY := Color(0.039, 0.329, 0.169, 1.0)
const _CLR_TXT_TODAY := Color(0.039, 0.329, 0.169, 1.0)

# ── Shared card (login → connect) ─────────────────────────────────────
@onready var login_card:      Panel         = %LoginCard
@onready var sub_label:       Label         = %SubLabel
@onready var login_content:   VBoxContainer = %LoginContent
@onready var patient_id_input: LineEdit     = %PatientIDInput
@onready var login_button:    Button        = %LoginButton
@onready var register_button: Button        = %RegisterButton
@onready var login_status:    Label         = %LoginStatus

# ── Connect content (shown after login) ───────────────────────────────
@onready var connect_content: VBoxContainer = %ConnectContent
@onready var connect_button:  Button        = %ConnectButton
@onready var connect_status:  Label         = %ConnectStatus

# ── Dashboard card ────────────────────────────────────────────────────
@onready var dash_card:    Panel = %DashCard
@onready var streak_label: Label = %StreakValue
@onready var week_label:   Label = %TotalValue
@onready var goal_label:   Label = %GoalValue

# ── Chart nodes ───────────────────────────────────────────────────────
@onready var _goal_line: Panel         = %GoalLine
@onready var _bars_hbox: HBoxContainer = %BarsHBox

func _ready() -> void:
	login_status.text = ""
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/RegisterScene.tscn")
	)
	connect_button.pressed.connect(_on_connect_pressed)

func _on_login_pressed() -> void:
	var pid := patient_id_input.text.strip_edges()
	if pid.is_empty():
		_set_login_status("Please enter a Patient ID.", true)
		return
	if not DataManager.patient_exists(pid):
		_set_login_status("Patient not found. Please register first.", true)
		return
	if DataManager.load_patient(pid):
		sub_label.text     = "Patient: " + pid
		login_content.visible  = false
		connect_content.visible = true
		connect_status.text    = "Port: " + PORT
		connect_status.modulate = Color.WHITE
		_animate_to_dashboard()
	else:
		_set_login_status("Failed to load patient data.", true)

func _animate_to_dashboard() -> void:
	# Place dash card above the screen (offset shifts the whole node up)
	dash_card.offset_top    = -900.0
	dash_card.offset_bottom = -900.0
	dash_card.visible       = true
	await get_tree().process_frame  # let layout compute before chart populate
	_populate_dashboard()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Slide login card to the right side and shrink height
	tween.tween_property(login_card, "anchor_left",   0.52, 0.45)
	tween.tween_property(login_card, "anchor_right",  0.96, 0.45)
	tween.tween_property(login_card, "anchor_top",    0.05, 0.45)
	tween.tween_property(login_card, "anchor_bottom", 0.65, 0.45)

	# Drop dash card into the left position
	tween.tween_property(dash_card, "offset_top",    0.0, 0.50).set_delay(0.15)
	tween.tween_property(dash_card, "offset_bottom", 0.0, 0.50).set_delay(0.15)

func _on_connect_pressed() -> void:
	connect_button.disabled = true
	connect_status.text     = "Connecting to " + PORT + "..."
	connect_status.modulate = Color("#888888")
	if PlutoComm.connect_device(PORT):
		PlutoComm.start_stream()
		connect_status.text     = "✓ Connected! Press PLUTO button to continue."
		connect_status.modulate = Color("#2ecc71")
		await get_tree().create_timer(0.5).timeout
		EventBus.button_released.connect(_on_pluto_button)
	else:
		connect_status.text     = "✗ Failed. Check port and try again."
		connect_status.modulate = Color("#e74c3c")
		connect_button.disabled = false

func _on_pluto_button() -> void:
	if AppData.config_total_time == 0:
		AppData.is_plan_setup = true
		get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")

# ── Dashboard ─────────────────────────────────────────────────────────

func _populate_dashboard() -> void:
	var usage  := DataManager.read_daily_usage(7)
	var dates  := usage.keys()
	dates.sort()

	var labels: PackedStringArray = []
	var values: Array             = []
	var total_sec := 0.0
	for date in dates:
		labels.append(_date_abbr(date))
		var mins: float = float(usage[date]) / 60.0
		values.append(mins)
		total_sec += float(usage[date])

	var goal := float(AppData.config_total_time) if AppData.config_total_time > 0 else 60.0
	_update_chart(labels, values, goal)

	streak_label.text = str(_calc_streak(usage, dates)) + "d"
	week_label.text   = "%dm" % int(total_sec / 60.0)
	goal_label.text   = ("%d min" % AppData.config_total_time) if AppData.config_total_time > 0 else "—"

func _update_chart(labels: PackedStringArray, values: Array, goal: float) -> void:
	var max_val: float = max(goal * 1.2, 5.0)
	var n := _bars_hbox.get_child_count()

	for i in range(n):
		var slot      := _bars_hbox.get_child(i)
		var val: float = float(values[i]) if i < values.size() else 0.0
		var is_today: bool = (i == n - 1)

		var bar     := slot.get_node("Bar") as Panel
		var val_lbl := slot.get_node("Val") as Label
		var day_lbl := slot.get_node("Day") as Label

		var bh: float = _BAR_AREA_H * clamp(val / max_val, 0.0, 1.0)
		bar.custom_minimum_size = Vector2(0.0, bh)

		if is_today:
			bar.modulate = _CLR_TODAY
		elif val >= goal and val > 0.0:
			bar.modulate = _CLR_FULL
		elif val > 0.0:
			bar.modulate = _CLR_PART
		else:
			bar.modulate = _CLR_NONE

		val_lbl.text = ("%dm" % int(val)) if val > 0.0 else ""
		day_lbl.text = labels[i] if i < labels.size() else "—"

		if is_today:
			day_lbl.add_theme_color_override("font_color", _CLR_TXT_TODAY)
		else:
			day_lbl.add_theme_color_override("font_color", Color(0.353, 0.510, 0.369, 1.0))

	var goal_frac:   float = clamp(goal / max_val, 0.0, 1.0)
	var goal_y:      float = _VAL_H + _BAR_AREA_H * (1.0 - goal_frac)
	var goal_anchor: float = goal_y / _CHART_H
	_goal_line.anchor_top    = goal_anchor
	_goal_line.anchor_bottom = goal_anchor

# ── Helpers ───────────────────────────────────────────────────────────

func _date_abbr(date_str: String) -> String:
	var p    := date_str.split("-")
	var d    := {"year": int(p[0]), "month": int(p[1]), "day": int(p[2]),
				 "hour": 0, "minute": 0, "second": 0, "dst": false}
	var unix := Time.get_unix_time_from_datetime_dict(d)
	var wday: int = int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))
	return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][wday]

func _calc_streak(usage: Dictionary, dates: Array) -> int:
	var i := dates.size() - 1
	if i >= 0 and float(usage[dates[i]]) <= 0.0:
		i -= 1
	var streak := 0
	while i >= 0 and float(usage[dates[i]]) > 0.0:
		streak += 1
		i -= 1
	return streak

func _set_login_status(msg: String, is_error: bool) -> void:
	login_status.text     = msg
	login_status.modulate = Color("#e74c3c") if is_error else Color("#2ecc71")
