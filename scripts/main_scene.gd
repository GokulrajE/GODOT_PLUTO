extends Control

var PORT: String:
	get: return AppStorage.device_port()

# Chart layout constants (must match ChartContainer custom_minimum_size in scene)
const _CHART_H    := 200.0
const _VAL_H      := 18.0
const _DAY_H      := 20.0
const _BAR_AREA_H := 162.0

const _CLR_FULL  := Color("a6ee32")
const _CLR_PART  := Color("9b79ed")
const _CLR_NONE  := Color("4e4b70")
const _CLR_TODAY := Color("087f83")
const _CLR_TXT_TODAY := Color("087f83")

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

var _diag_button: Button = null
var _login_pending := false

# ── Dashboard card ────────────────────────────────────────────────────
@onready var dash_card:    Panel = %DashCard
@onready var streak_label: Label = %StreakValue
@onready var week_label:   Label = %TotalValue
@onready var goal_label:   Label = %GoalValue

# ── Chart nodes ───────────────────────────────────────────────────────
@onready var _goal_line: Panel         = %GoalLine
@onready var _bars_hbox: HBoxContainer = %BarsHBox

func _ready() -> void:
	%PatientMatches.visible = LocalServer.enabled
	%ServerStatus.visible = LocalServer.enabled
	%RefreshPatients.visible = LocalServer.enabled
	%RefreshPatients.pressed.connect(func():
		%RefreshPatients.disabled = true
		%RefreshPatients.text = "Refreshing…"
		await LocalServer.refresh_patients()
		if not is_inside_tree(): return
		%RefreshPatients.disabled = false
		%RefreshPatients.text = "↻  Refresh IDs")
	patient_id_input.text_changed.connect(func(_text): _refresh_patient_matches())
	%PatientMatches.item_selected.connect(func(index):
		patient_id_input.text = %PatientMatches.get_item_text(index)
		_refresh_patient_matches())
	LocalServer.patients_changed.connect(_refresh_patient_matches)
	LocalServer.message_changed.connect(func(): %ServerStatus.text = LocalServer.message)
	_refresh_patient_matches()
	$DiagnosticsButton.pressed.connect(func():
		if AppUpdater.blocks_login() or AppData.is_patient_loaded: return
		get_tree().change_scene_to_file("res://scenes/DiagnosticsScene.tscn"))
	if not has_meta("arcade_authored"): preload("res://scripts/ui/login_ui.gd").configure(login_card, $LoginCard/LoginCardVBox/LoginCardHeader/HeaderVBox/AppLabel, sub_label)
	login_status.text = AppStorage.error_message
	login_button.disabled = not AppStorage.error_message.is_empty()
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(func():
		if AppUpdater.blocks_login(): return
		get_tree().change_scene_to_file("res://scenes/RegisterScene.tscn")
	)
	connect_button.pressed.connect(_on_connect_pressed)
	_diag_button = Button.new()
	_diag_button.text = "Device Diagnostics"
	_diag_button.custom_minimum_size = Vector2(0, 44)
	_diag_button.pressed.connect(func():
		if AppUpdater.blocks_login(): return
		get_tree().change_scene_to_file("res://scenes/DiagnosticsScene.tscn"))
	connect_content.add_child(_diag_button)
	$VersionLabel.text = "PLUTO v" + AppUpdater.version()
	AppUpdater.changed.connect(_update_gate)
	$UpdatePanel/UpdateAction.pressed.connect(func():
		if AppUpdater.state == "required": AppUpdater.download_update()
		elif AppUpdater.state == "downloaded": AppUpdater.install_download()
		else: AppUpdater.check_updates()
	)
	AppUpdater.confirm_startup()
	AppUpdater.check_updates()
	_update_gate()

func _on_login_pressed() -> void:
	if AppUpdater.blocks_login() or _login_pending: return
	if not AppStorage.error_message.is_empty():
		_set_login_status(AppStorage.error_message, true)
		return
	var pid := patient_id_input.text.strip_edges()
	if pid.is_empty():
		_set_login_status("Please enter a Patient ID.", true)
		return
	if not LocalServer.valid_id(pid):
		_set_login_status("Use 1–40 letters, numbers, underscores or hyphens for the ID.", true)
		return
	if LocalServer.enabled:
		_login_pending = true
		_update_gate()
		var started := await LocalServer.start_patient(pid, _patient_group())
		_login_pending = false
		_update_gate()
		if not started:
			_set_login_status(LocalServer.message, true)
			return
		if not DataManager.patient_exists(pid):
			var entry := LocalServer.patient_entry(pid)
			var side: String = str(entry.get("side", ""))
			if side not in ["left", "right"]:
				await LocalServer.stop_patient()
				_set_login_status("Register this assigned ID and choose the training side first.", true)
				return
			if not DataManager.create_patient(pid, Time.get_date_string_from_system(), "", side.capitalize(), ""):
				await LocalServer.stop_patient()
				_set_login_status("Could not create the local patient record.", true)
				return
	if not DataManager.patient_exists(pid):
		_set_login_status("Patient not found. Please register first.", true)
		return
	if DataManager.load_patient(pid):
		sub_label.text     = "Patient: " + pid
		login_content.visible  = false
		connect_content.visible = true
		$UpdatePanel.hide()
		connect_status.text    = "Port: " + PORT
		connect_status.modulate = Color.WHITE
		_animate_to_dashboard()
	else:
		await LocalServer.stop_patient()
		_set_login_status("Failed to load patient data.", true)

func _animate_to_dashboard() -> void:
	preload("res://scripts/ui/dashboard_motion.gd").open(login_card, dash_card)
	await get_tree().process_frame
	_populate_dashboard()

func _on_connect_pressed() -> void:
	if PORT.is_empty():
		connect_status.text = "Set [serial] port in Documents/PLUTO/device.cfg, then retry."
		return
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

func _update_gate() -> void:
	var blocked := AppUpdater.blocks_login()
	login_button.disabled = _login_pending or blocked or not AppStorage.error_message.is_empty()
	register_button.disabled = _login_pending or blocked or not AppStorage.error_message.is_empty()
	$DemoButton.disabled = blocked or _login_pending
	$DiagnosticsButton.disabled = blocked or _login_pending or AppData.is_patient_loaded
	patient_id_input.editable = not _login_pending
	$UpdatePanel.visible = AppUpdater.enabled and login_content.visible
	$UpdatePanel/UpdateStatus.text = AppUpdater.message.get_slice("\n", 0)
	$UpdatePanel/UpdateStatus.tooltip_text = AppUpdater.message
	$UpdatePanel/UpdateProgress.visible = false
	$UpdatePanel/UpdateProgress.value = 100.0 * AppUpdater.downloaded / maxf(1.0, AppUpdater.total)
	$UpdatePanel/UpdateAction.disabled = _login_pending or AppUpdater.state in ["checking", "downloading", "installing"]
	$UpdatePanel/UpdateAction.text = "Update" if AppUpdater.state == "required" else "Check updates"
	if AppUpdater.state == "downloaded": $UpdatePanel/UpdateAction.text = "Restart & install"
	if AppUpdater.state == "downloading": $UpdatePanel/UpdateAction.text = "Downloading %d%%" % $UpdatePanel/UpdateProgress.value
	if AppUpdater.state == "installing": $UpdatePanel/UpdateAction.text = "Restarting…"
	$UpdatePanel/UpdateProgress.tooltip_text = "%.1f / %.1f MB" % [AppUpdater.downloaded / 1048576.0, AppUpdater.total / 1048576.0]

func _patient_group() -> String:
	return "devices"

func _refresh_patient_matches() -> void:
	if not LocalServer.enabled: return
	%PatientMatches.clear()
	for pid in LocalServer.suggestions(patient_id_input.text, _patient_group()):
		%PatientMatches.add_item(pid)
	%PatientMatches.visible = %PatientMatches.item_count > 0
	%ServerStatus.text = LocalServer.message if %PatientMatches.item_count > 0 else "No matching IDs. Register a new local ID or refresh the server list."
