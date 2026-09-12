extends CanvasLayer

var _packet_count: int   = 0
var _hz_timer:     float = 0.0
var _dot_lbl:      Label = null
var _hz_lbl:       Label = null

func _ready() -> void:
	layer        = 100
	visible      = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.device_connected.connect(_on_connected)
	EventBus.device_disconnected.connect(_on_disconnected)
	EventBus.new_sensor_data.connect(_on_packet)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := Panel.new()
	panel.anchor_left    = 1.0
	panel.anchor_right   = 1.0
	panel.anchor_top     = 0.0
	panel.anchor_bottom  = 0.0
	panel.offset_left    = -110.0
	panel.offset_right   = -12.0
	panel.offset_top     = 6.0
	panel.offset_bottom  = 34.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter   = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color             = Color(0.04, 0.05, 0.12, 0.88)
	sb.border_width_left    = 1
	sb.border_width_top     = 1
	sb.border_width_right   = 1
	sb.border_width_bottom  = 1
	sb.border_color         = Color(0.2, 0.3, 0.6, 0.5)
	sb.corner_radius_top_left    = 13
	sb.corner_radius_top_right   = 13
	sb.corner_radius_bottom_right = 13
	sb.corner_radius_bottom_left  = 13
	sb.content_margin_left  = 8.0
	sb.content_margin_right = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 5)
	panel.add_child(hbox)

	_dot_lbl = Label.new()
	_dot_lbl.text = "●"
	_dot_lbl.add_theme_font_size_override("font_size", 9)
	_dot_lbl.add_theme_color_override("font_color", Color(0.15, 0.9, 0.4, 1))
	_dot_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_dot_lbl)

	_hz_lbl = Label.new()
	_hz_lbl.text = "-- Hz"
	_hz_lbl.custom_minimum_size = Vector2(50, 0)
	_hz_lbl.add_theme_font_size_override("font_size", 11)
	_hz_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1))
	_hz_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_hz_lbl)

func _process(delta: float) -> void:
	if not visible: return
	_hz_timer += delta
	if _hz_timer >= 1.0:
		var hz: float = _packet_count / _hz_timer
		_packet_count = 0
		_hz_timer     = 0.0
		_hz_lbl.text  = "%d Hz" % int(hz)
		var col: Color
		if   hz >= 18: col = Color(0.4, 0.85, 1.0, 1)
		elif hz >= 10: col = Color(1.0, 0.85, 0.2, 1)
		else:          col = Color(1.0, 0.35, 0.35, 1)
		_hz_lbl.add_theme_color_override("font_color", col)

func _on_packet() -> void:
	_packet_count += 1

func _on_connected() -> void:
	visible = true
	_dot_lbl.add_theme_color_override("font_color", Color(0.15, 0.95, 0.4, 1))

func _on_disconnected() -> void:
	_dot_lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1))
	_hz_lbl.text  = "-- Hz"
	_packet_count = 0
