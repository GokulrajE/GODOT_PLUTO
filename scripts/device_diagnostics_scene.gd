extends Control

const CLR_BG      = Color(0.941, 0.969, 0.945, 1)
const CLR_CARD    = Color(1.0,   1.0,   1.0,   1)
const CLR_HDR     = Color(0.824, 0.929, 0.839, 1)
const CLR_BORDER  = Color(0.749, 0.878, 0.761, 1)
const CLR_ACCENT  = Color(0.082, 0.502, 0.212, 1)
const CLR_NORMAL  = Color(0.082, 0.157, 0.094, 1)
const CLR_DIM     = Color(0.353, 0.510, 0.369, 1)
const CLR_WARN    = Color(0.780, 0.129, 0.129, 1)
const CLR_ROW_OFF = Color(0.961, 0.988, 0.965, 1)

const TRACE_SAMPLES := 200

# ── Inner class for custom-draw canvas ───────────────────────────────
class TraceCanvas extends Control:
	var diag: Node

	func _init(owner_diag: Node) -> void:
		diag = owner_diag

	func _draw() -> void:
		diag._draw_trace(self)

# ── Node refs ─────────────────────────────────────────────────────────
var _conn_dot:    ColorRect
var _conn_label:  Label
var _hz_label:    Label
var _val_labels:  Dictionary = {}
var _trace_ctrl:  TraceCanvas
var _trace_data:  PackedFloat32Array

var _mech_label:   Label
var _ctrl_label:   Label
var _btn_label:    Label
var _calib_label:  Label
var _status_label: Label

var _pkt_count: int   = 0
var _hz_timer:  float = 0.0

func _ready() -> void:
	_trace_data = PackedFloat32Array()
	_trace_data.resize(TRACE_SAMPLES)
	_trace_data.fill(0.0)
	_build_ui()
	_refresh_static()
	EventBus.new_sensor_data.connect(_on_sensor_data)

func _exit_tree() -> void:
	if EventBus.new_sensor_data.is_connected(_on_sensor_data):
		EventBus.new_sensor_data.disconnect(_on_sensor_data)

func _process(delta: float) -> void:
	_hz_timer += delta
	if _hz_timer >= 1.0:
		_hz_label.text = "%.0f Hz" % (_pkt_count / _hz_timer)
		_pkt_count = 0
		_hz_timer  = 0.0

# ── Data update ───────────────────────────────────────────────────────

func _on_sensor_data() -> void:
	_pkt_count += 1

	_set_val("angle",   "%.2f°"  % PlutoComm.angle)
	_set_val("torque",  "%.4f"   % PlutoComm.torque)
	_set_val("control", "%.4f"   % PlutoComm.control)
	_set_val("target",  "%.2f"   % PlutoComm.target)
	_set_val("desired", "%.2f"   % PlutoComm.desired)
	_set_val("bound",   "%.0f%%" % (PlutoComm.control_bound * 100.0))
	_set_val("runtime", "%.1f s" % PlutoComm.run_time)
	_set_val("pktno",   str(PlutoComm.packet_number))

	_mech_label.text    = PlutoComm.MECHANISMS[clampi(PlutoComm.mechanism, 0, PlutoComm.MECHANISMS.size() - 1)]
	_ctrl_label.text    = PlutoComm.CONTROL_TYPES[clampi(PlutoComm.control_type, 0, PlutoComm.CONTROL_TYPES.size() - 1)]
	_btn_label.text     = "PRESSED" if PlutoComm.button == 1 else "released"
	_btn_label.modulate = CLR_WARN if PlutoComm.button == 1 else CLR_DIM
	_calib_label.text     = "CALIBRATED" if PlutoComm.calibration == 1 else "uncalibrated"
	_calib_label.modulate = CLR_ACCENT if PlutoComm.calibration == 1 else CLR_DIM
	_status_label.text  = "0x%02X" % PlutoComm.status

	_conn_dot.color  = CLR_ACCENT if PlutoComm.is_connected else CLR_WARN
	_conn_label.text = "Connected" if PlutoComm.is_connected else "Disconnected"

	_trace_data = _trace_data.slice(1)
	_trace_data.append(PlutoComm.angle)
	_trace_ctrl.queue_redraw()

func _refresh_static() -> void:
	_conn_dot.color  = CLR_ACCENT if PlutoComm.is_connected else CLR_WARN
	_conn_label.text = "Connected" if PlutoComm.is_connected else "Disconnected"

func _set_val(key: String, text: String) -> void:
	if _val_labels.has(key):
		_val_labels[key].text = text

# ── Draw callback (called by TraceCanvas._draw) ───────────────────────

func _draw_trace(ctrl: Control) -> void:
	var w := ctrl.size.x
	var h := ctrl.size.y
	if w <= 0 or h <= 0:
		return

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = CLR_ROW_OFF
	bg_sb.set_corner_radius_all(6)
	ctrl.draw_style_box(bg_sb, Rect2(Vector2.ZERO, Vector2(w, h)))

	var zero_y := h * 0.5
	ctrl.draw_line(
		Vector2(0, zero_y), Vector2(w, zero_y),
		Color(CLR_BORDER.r, CLR_BORDER.g, CLR_BORDER.b, 0.6), 1.0)

	var n := _trace_data.size()
	if n < 2:
		return

	var step      := w / float(n - 1)
	var half_range := 180.0
	var prev := Vector2.ZERO
	for i in range(n):
		var v  := clampf(_trace_data[i], -half_range, half_range)
		var px := i * step
		var py := zero_y - (v / half_range) * zero_y * 0.9
		var pt := Vector2(px, py)
		if i > 0:
			ctrl.draw_line(prev, pt, CLR_ACCENT, 1.5)
		prev = pt

# ── UI builder ────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = CLR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var card := _make_panel(CLR_CARD, CLR_BORDER, 14)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left   =  24
	card.offset_top    =  16
	card.offset_right  = -24
	card.offset_bottom = -16
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	vbox.add_child(_build_header())

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left","margin_top","margin_right","margin_bottom"]:
		body.add_theme_constant_override(side, 14)
	vbox.add_child(body)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 12)
	body.add_child(body_vbox)

	body_vbox.add_child(_build_connection_row())

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	body_vbox.add_child(cols)

	var readings_panel := _make_panel(CLR_CARD, CLR_BORDER, 8)
	readings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(readings_panel)
	_build_readings(readings_panel)

	var trace_panel := _make_panel(CLR_CARD, CLR_BORDER, 8)
	trace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(trace_panel)
	_build_trace(trace_panel)

	body_vbox.add_child(_build_state_row())

func _build_header() -> Control:
	var hdr := Panel.new()
	hdr.custom_minimum_size = Vector2(0, 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLR_HDR
	sb.corner_radius_top_left  = 14
	sb.corner_radius_top_right = 14
	hdr.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 16
	hbox.offset_right = -16
	hdr.add_child(hbox)

	var back := Button.new()
	back.text = "← Back"
	back.flat = true
	back.add_theme_font_size_override("font_size", 15)
	back.add_theme_color_override("font_color",       CLR_ACCENT)
	back.add_theme_color_override("font_hover_color", CLR_NORMAL)
	back.custom_minimum_size = Vector2(90, 0)
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn"))
	hbox.add_child(back)

	var title := Label.new()
	title.text = "Device Diagnostics"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", CLR_NORMAL)
	hbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(spacer)

	return hdr

func _build_connection_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_conn_dot = ColorRect.new()
	_conn_dot.custom_minimum_size = Vector2(10, 10)
	_conn_dot.color = CLR_DIM
	var dot_wrap := CenterContainer.new()
	dot_wrap.custom_minimum_size = Vector2(20, 32)
	dot_wrap.add_child(_conn_dot)
	row.add_child(dot_wrap)

	_conn_label = Label.new()
	_conn_label.text = "—"
	_conn_label.add_theme_font_size_override("font_size", 15)
	_conn_label.add_theme_color_override("font_color", CLR_NORMAL)
	row.add_child(_conn_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_hz_label = Label.new()
	_hz_label.text = "— Hz"
	_hz_label.add_theme_font_size_override("font_size", 13)
	_hz_label.add_theme_color_override("font_color", CLR_DIM)
	row.add_child(_hz_label)

	return row

func _build_readings(parent: Panel) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 12
	vbox.offset_top    =  8
	vbox.offset_right  = -12
	vbox.offset_bottom =  -8
	vbox.add_theme_constant_override("separation", 6)
	parent.add_child(vbox)

	var cap := Label.new()
	cap.text = "SENSOR READINGS"
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", CLR_DIM)
	vbox.add_child(cap)

	for row_def in [
		["angle",   "Angle"],
		["torque",  "Torque"],
		["control", "Control"],
		["target",  "Target"],
		["desired", "Desired"],
		["bound",   "Control Bound"],
		["runtime", "Run Time"],
		["pktno",   "Packet No."],
	]:
		vbox.add_child(_make_reading_row(row_def[0], row_def[1]))

func _make_reading_row(key: String, label_text: String) -> Control:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CLR_DIM)
	row.add_child(lbl)

	var val := Label.new()
	val.text = "—"
	val.custom_minimum_size = Vector2(90, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", CLR_NORMAL)
	row.add_child(val)
	_val_labels[key] = val

	return row

func _build_trace(parent: Panel) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 12
	vbox.offset_top    =  8
	vbox.offset_right  = -12
	vbox.offset_bottom =  -8
	vbox.add_theme_constant_override("separation", 6)
	parent.add_child(vbox)

	var cap := Label.new()
	cap.text = "ANGLE TRACE  (±180°)"
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", CLR_DIM)
	vbox.add_child(cap)

	_trace_ctrl = TraceCanvas.new(self)
	_trace_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trace_ctrl.clip_contents = true
	vbox.add_child(_trace_ctrl)

func _build_state_row() -> Control:
	var panel := _make_panel(CLR_CARD, CLR_BORDER, 8)
	panel.custom_minimum_size = Vector2(0, 64)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 14
	hbox.offset_right = -14
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	var chips := ["MECHANISM", "CTRL TYPE", "BUTTON", "CALIBRATION", "STATUS BYTE"]
	for i in chips.size():
		if i > 0:
			var div := ColorRect.new()
			div.custom_minimum_size = Vector2(1, 0)
			div.color = CLR_BORDER
			hbox.add_child(div)

		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		chip.add_theme_constant_override("separation", 2)
		hbox.add_child(chip)

		var cap := Label.new()
		cap.text = chips[i]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 10)
		cap.add_theme_color_override("font_color", CLR_DIM)
		chip.add_child(cap)

		var val := Label.new()
		val.text = "—"
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", CLR_NORMAL)
		chip.add_child(val)

		match i:
			0: _mech_label   = val
			1: _ctrl_label   = val
			2: _btn_label    = val
			3: _calib_label  = val
			4: _status_label = val

	return panel

func _make_panel(bg: Color, border: Color, radius: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	return p
