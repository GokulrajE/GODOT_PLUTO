extends Control

@onready var patient_id_input: LineEdit = $FormPanel/PatientIDInput
@onready var start_date_input: LineEdit = $FormPanel/StartDateInput
@onready var end_date_input:   LineEdit = $FormPanel/EndDateInput
@onready var left_button:      Button   = $FormPanel/TrainingSideRow/LeftButton
@onready var right_button:     Button   = $FormPanel/TrainingSideRow/RightButton
@onready var location_input:   LineEdit = $FormPanel/LocationInput
@onready var register_button:  Button   = $FormPanel/ButtonsRow/RegisterButton
@onready var back_button:      Button   = $FormPanel/ButtonsRow/BackButton
@onready var status_label:     Label    = $FormPanel/StatusLabel

var _training_side: String = "Right"

# ── Calendar state ─────────────────────────────────────────────────────
var _cal_popup:    Panel    = null
var _cal_target:   LineEdit = null
var _cal_year:     int      = 0
var _cal_month:    int      = 0
var _cal_day_btns: Array    = []
var _cal_header:   Label    = null

func _ready() -> void:
	register_button.disabled  = true
	start_date_input.editable = false
	end_date_input.editable   = false
	start_date_input.text = Time.get_date_string_from_system()
	var end_unix := int(Time.get_unix_time_from_system()) + 30 * 86400
	var end_dict := Time.get_date_dict_from_unix_time(end_unix)
	end_date_input.text = "%04d-%02d-%02d" % [end_dict.year, end_dict.month, end_dict.day]
	_style_date_field(start_date_input)
	_style_date_field(end_date_input)
	_update_side_buttons()
	_build_calendar_popup()

	left_button.pressed.connect(func():
		_training_side = "Left"; _update_side_buttons())
	right_button.pressed.connect(func():
		_training_side = "Right"; _update_side_buttons())

	patient_id_input.text_changed.connect(func(_t): _check_patient_id())
	patient_id_input.focus_exited.connect(_check_patient_id)
	patient_id_input.text_submitted.connect(func(_t): _check_patient_id())

	start_date_input.gui_input.connect(
		func(ev): _on_date_field_input(ev, start_date_input))
	end_date_input.gui_input.connect(
		func(ev): _on_date_field_input(ev, end_date_input))

	register_button.pressed.connect(_on_register_pressed)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn"))

# ── Date field styling ─────────────────────────────────────────────────

func _style_date_field(field: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.8456132, 0.9705917, 0.847429, 1)
	sb.border_color = Color(0.749, 0.878, 0.761, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left   = 14.0
	sb.content_margin_top    = 8.0
	sb.content_margin_right  = 14.0
	sb.content_margin_bottom = 8.0
	field.add_theme_stylebox_override("read_only", sb)
	field.add_theme_color_override("font_uneditable_color", Color(0.059, 0.502, 0.259, 1))

# ── Patient ID check ───────────────────────────────────────────────────

func _check_patient_id() -> void:
	var pid := patient_id_input.text.strip_edges()
	if pid.is_empty():
		status_label.text        = ""
		register_button.disabled = true
		return
	if DataManager.patient_exists(pid):
		_set_status("Patient ID '" + pid + "' already exists. Go back and login instead.", true)
		register_button.disabled = true
	else:
		status_label.text        = ""
		register_button.disabled = false

# ── Side buttons ───────────────────────────────────────────────────────

func _update_side_buttons() -> void:
	left_button.modulate  = Color("#2ecc71") if _training_side == "Left"  else Color.WHITE
	right_button.modulate = Color("#2ecc71") if _training_side == "Right" else Color.WHITE

# ── Register ───────────────────────────────────────────────────────────

func _on_register_pressed() -> void:
	var pid      := patient_id_input.text.strip_edges()
	var start    := start_date_input.text.strip_edges()
	var end_date := end_date_input.text.strip_edges()
	var location := location_input.text.strip_edges()

	if pid.is_empty():
		_set_status("Patient ID is required.", true)
		return
	if DataManager.patient_exists(pid):
		_set_status("Patient ID already exists. Please login instead.", true)
		return
	if start.is_empty():
		start = Time.get_date_string_from_system()
	if not end_date.is_empty() and end_date < start:
		_set_status("End date must be on or after the start date.", true)
		return

	if DataManager.create_patient(pid, start, end_date, _training_side, location):
		_set_status("✓ Patient registered! Returning to login...", false)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
	else:
		_set_status("Failed to create patient data. Check folder permissions.", true)

func _set_status(msg: String, is_error: bool) -> void:
	status_label.text     = msg
	status_label.modulate = Color("#e74c3c") if is_error else Color("#2ecc71")

# ── Calendar popup ─────────────────────────────────────────────────────

func _on_date_field_input(event: InputEvent, field: LineEdit) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_show_calendar(field)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _cal_popup == null or not _cal_popup.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not _cal_popup.get_global_rect().has_point(event.global_position):
			_cal_popup.visible = false
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cal_popup.visible = false
		get_viewport().set_input_as_handled()

func _build_calendar_popup() -> void:
	_cal_popup = Panel.new()

	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(1.0, 1.0, 1.0, 1.0)
	sb.border_color = Color(0.153, 0.714, 0.376, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	sb.shadow_size  = 8
	_cal_popup.add_theme_stylebox_override("panel", sb)
	_cal_popup.custom_minimum_size = Vector2(294, 300)
	_cal_popup.visible             = false
	_cal_popup.z_index             = 100
	add_child(_cal_popup)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left","margin_top","margin_right","margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	_cal_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── Header: prev  Month Year  next ──
	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var prev_btn := _nav_button("‹")
	prev_btn.pressed.connect(_cal_prev_month)
	hdr.add_child(prev_btn)

	_cal_header = Label.new()
	_cal_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cal_header.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_cal_header.add_theme_color_override("font_color", Color(0.082, 0.157, 0.094, 1))
	_cal_header.add_theme_font_size_override("font_size", 15)
	hdr.add_child(_cal_header)

	var next_btn := _nav_button("›")
	next_btn.pressed.connect(_cal_next_month)
	hdr.add_child(next_btn)

	# ── Day-of-week labels ──
	var dow_grid := GridContainer.new()
	dow_grid.columns = 7
	vbox.add_child(dow_grid)
	for name in ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]:
		var lbl := Label.new()
		lbl.text                     = name
		lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size      = Vector2(38, 22)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.353, 0.510, 0.369, 1))
		dow_grid.add_child(lbl)

	# ── Day buttons ──
	var day_grid := GridContainer.new()
	day_grid.columns = 7
	day_grid.add_theme_constant_override("h_separation", 2)
	day_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(day_grid)

	_cal_day_btns = []
	for i in range(42):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(38, 36)
		btn.flat                = true
		btn.add_theme_font_size_override("font_size", 13)
		var idx := i
		btn.pressed.connect(func(): _cal_day_pressed(idx))
		day_grid.add_child(btn)
		_cal_day_btns.append(btn)

func _nav_button(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.flat = true
	btn.custom_minimum_size = Vector2(32, 32)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color",       Color(0.082, 0.502, 0.212, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.059, 0.329, 0.169, 1))
	return btn

func _show_calendar(field: LineEdit) -> void:
	_cal_target = field
	var txt := field.text.strip_edges()
	if txt.length() == 10:
		var p := txt.split("-")
		if p.size() == 3:
			_cal_year  = int(p[0])
			_cal_month = int(p[1])
	if _cal_year == 0:
		var now := Time.get_date_dict_from_system()
		_cal_year  = now.year
		_cal_month = now.month

	_cal_refresh()
	await get_tree().process_frame

	var rect    := field.get_global_rect()
	var pop_sz  := _cal_popup.get_combined_minimum_size()
	var win_sz  := get_viewport_rect().size
	var px: float = rect.position.x
	var py: float = rect.position.y + rect.size.y + 4
	if px + pop_sz.x > win_sz.x:
		px = win_sz.x - pop_sz.x - 4
	if py + pop_sz.y > win_sz.y:
		py = rect.position.y - pop_sz.y - 4
	_cal_popup.position = Vector2(px, py)
	_cal_popup.visible  = true

func _cal_refresh() -> void:
	const MONTH_NAMES := ["January","February","March","April","May","June",
		"July","August","September","October","November","December"]
	_cal_header.text = "%s  %d" % [MONTH_NAMES[_cal_month - 1], _cal_year]

	var d := {"year": _cal_year, "month": _cal_month, "day": 1,
			  "hour": 0, "minute": 0, "second": 0, "dst": false}
	var unix    := Time.get_unix_time_from_datetime_dict(d)
	var wday: int = Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0)
	var dim     := _days_in_month(_cal_year, _cal_month)

	var today   := Time.get_date_dict_from_system()
	var sel_txt := _cal_target.text.strip_edges() if _cal_target else ""

	for i in range(42):
		var btn: Button = _cal_day_btns[i]
		var day := i - wday + 1
		if day < 1 or day > dim:
			btn.text     = ""
			btn.disabled = true
			_cal_clear_style(btn)
			btn.modulate = Color(1, 1, 1, 0)
		else:
			btn.text     = str(day)
			btn.disabled = false
			btn.modulate = Color.WHITE
			var date_str := "%04d-%02d-%02d" % [_cal_year, _cal_month, day]
			var is_sel   := sel_txt == date_str
			var is_today := (day == int(today.day)
				and _cal_month == int(today.month)
				and _cal_year  == int(today.year))
			if is_sel:
				_cal_set_style(btn, Color(0.082, 0.502, 0.212, 1), Color.WHITE)
			elif is_today:
				_cal_set_style(btn, Color(0.824, 0.929, 0.839, 1), Color(0.059, 0.502, 0.259, 1))
			else:
				_cal_clear_style(btn)

func _cal_set_style(btn: Button, bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color",       fg)
	btn.add_theme_color_override("font_hover_color", fg)

func _cal_clear_style(btn: Button) -> void:
	btn.remove_theme_stylebox_override("normal")
	btn.remove_theme_stylebox_override("hover")
	btn.remove_theme_stylebox_override("pressed")
	btn.add_theme_color_override("font_color",       Color(0.082, 0.157, 0.094, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.153, 0.714, 0.376, 1))

func _cal_day_pressed(idx: int) -> void:
	var btn: Button = _cal_day_btns[idx]
	if btn.text.is_empty() or btn.disabled:
		return
	if _cal_target != null:
		_cal_target.text = "%04d-%02d-%02d" % [_cal_year, _cal_month, int(btn.text)]
	_cal_popup.visible = false

func _cal_prev_month() -> void:
	_cal_month -= 1
	if _cal_month < 1:
		_cal_month = 12
		_cal_year -= 1
	_cal_refresh()

func _cal_next_month() -> void:
	_cal_month += 1
	if _cal_month > 12:
		_cal_month = 1
		_cal_year += 1
	_cal_refresh()

func _days_in_month(y: int, m: int) -> int:
	var dims := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if m == 2 and ((y % 4 == 0 and y % 100 != 0) or y % 400 == 0):
		return 29
	return dims[m - 1]
