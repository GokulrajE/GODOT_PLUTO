extends Control

# ── Protocol ──────────────────────────────────────────────────────────────────
const HEADER_IN  = 0xFF
const HEADER_OUT = 0xAA
const BAUD_RATE  = 115200

const CMD_GET_VERSION    = 0x00
const CMD_CALIB_START    = 0x01
const CMD_START_STREAM   = 0x02
const CMD_STOP_STREAM    = 0x03
const CMD_SET_CTRL_TYPE  = 0x04
const CMD_SET_CTRL_TGT   = 0x05
const CMD_SET_CTRL_BOUND = 0x07
const CMD_SET_CTRL_DIR   = 0x09
const CMD_CALIB_END      = 0x0D
const CMD_HEARTBEAT      = 0x80

const MECHANISMS    = ["NOMECH","WFE","WURD","FPS","HOC","FME1","FME2"]
const CONTROL_TYPES = ["NONE","POSITION","RESIST","TORQUE","POSITIONAAN"]

# Angle range for position target slider, indexed by mechanism
# HOC uses negative angles (0 = open, -93 ≈ 10 cm closed)
const MECH_MIN = [ -10.0, -68.0, -68.0, -90.0, -93.0, -90.0, -90.0]
const MECH_MAX = [  10.0,  68.0,  68.0,  90.0,   0.0,  90.0,  90.0]

# ── Config ────────────────────────────────────────────────────────────────────
const PORT_NAME = "COM45"

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _status_lbl:   Label    = $RootLayout/Header/HeaderBox/StatusLabel
@onready var _connect_btn:  Button   = $RootLayout/Header/HeaderBox/ConnectButton
@onready var _stream_btn:   Button   = $RootLayout/Header/HeaderBox/StreamButton
@onready var _port_input:   LineEdit = $RootLayout/Header/HeaderBox/PortInput
@onready var _hb_timer:     Timer    = $HeartbeatTimer

@onready var _sensor_lbl:   Label  = $RootLayout/Main/Left/SensorWrap/SensorLabel
@onready var _raw_lbl:      Label  = $RootLayout/Main/Left/SensorWrap/RawLabel

@onready var _ctrl_btns:    HBoxContainer = $RootLayout/Main/Right/RightInner/CtrlTypeRow
@onready var _target_slider: HSlider = $RootLayout/Main/Right/RightInner/TargetSlider
@onready var _target_lbl:   Label    = $RootLayout/Main/Right/RightInner/TargetRow/ValueLabel
@onready var _target_set:   Button   = $RootLayout/Main/Right/RightInner/TargetRow/SetButton
@onready var _target_zero:  Button   = $RootLayout/Main/Right/RightInner/TargetRow/ZeroButton
@onready var _bound_lbl:    Label  = $RootLayout/Main/Right/RightInner/BoundRow/ValueLabel
@onready var _bound_dec:    Button = $RootLayout/Main/Right/RightInner/BoundRow/DecButton
@onready var _bound_inc:    Button = $RootLayout/Main/Right/RightInner/BoundRow/IncButton
@onready var _calib_title:  Label  = $RootLayout/Main/Right/RightInner/CalibTitle
@onready var _calib_start:  Button = $RootLayout/Main/Right/RightInner/CalibRow/StartButton
@onready var _calib_end:    Button = $RootLayout/Main/Right/RightInner/CalibRow/EndButton
@onready var _dir_btns:     HBoxContainer = $RootLayout/Main/Right/RightInner/DirRow
@onready var _mech_btns:    HBoxContainer = $RootLayout/Main/Right/RightInner/MechRow

# ── State ──────────────────────────────────────────────────────────────────────
var _manager              = null
var _buf: PackedByteArray = PackedByteArray()
var _is_streaming:  bool  = false
var _is_connected:  bool  = false

# Parsed live data
var _angle:        float = 0.0
var _torque:       float = 0.0
var _control:      float = 0.0
var _target:       float = 0.0
var _desired:      float = 0.0
var _ctrl_bound:   float = 0.0
var _ctrl_dir:     int   = 0
var _button:       int   = 0
var _mechanism:    int   = 0
var _calibration:  int   = 0
var _ctrl_type:    int   = 0
var _packet_no:    int   = 0
var _run_time:     float = 0.0
var _packet_count: int   = 0

# Command state
var _cmd_target:    float = 0.0
var _cmd_bound:     float = 0.6
var _cmd_ctrl_idx:  int   = 0   # index into CONTROL_TYPES
var _selected_mech: int   = 1   # default WFE; used by Calib START/END

func _ready() -> void:
	_connect_btn.pressed.connect(_on_connect_pressed)
	_stream_btn.pressed.connect(_on_stream_pressed)
	_stream_btn.disabled = true
	_hb_timer.timeout.connect(_send_heartbeat)

	_target_slider.value_changed.connect(_on_target_slider_changed)
	_target_set.pressed.connect(func(): _send_target())
	_target_zero.pressed.connect(func(): _target_slider.value = 0.0; _send_target())
	_bound_dec.pressed.connect(func(): _adjust_bound(-0.05))
	_bound_inc.pressed.connect(func(): _adjust_bound( 0.05))
	_calib_start.pressed.connect(_on_calib_start)
	_calib_end.pressed.connect(_on_calib_end)

	# Control-type buttons
	for i in CONTROL_TYPES.size():
		var b := Button.new()
		b.text = CONTROL_TYPES[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 28)
		b.pressed.connect(_on_ctrl_type_pressed.bind(i))
		_ctrl_btns.add_child(b)

	# Direction buttons
	for label in ["Both", "Pos", "Neg"]:
		var b := Button.new()
		b.text = label
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 28)
		var dir_val = [0, 1, 255][_dir_btns.get_child_count()]
		b.pressed.connect(_on_dir_pressed.bind(dir_val))
		_dir_btns.add_child(b)

	# Mechanism buttons
	for i in MECHANISMS.size():
		var b := Button.new()
		b.text = MECHANISMS[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 28)
		b.pressed.connect(_on_mech_calib.bind(i))
		_mech_btns.add_child(b)

	_refresh_cmd_labels()
	_set_controls_enabled(false)

	# List ports
	if ClassDB.class_exists("GdSerialManager"):
		var tmp = GdSerialManager.new()
		var ports = tmp.list_ports()
		var names: Array = []
		for i in ports:
			names.append(str(ports[i]["port_name"]))
		_status_lbl.text = "Ports: " + ", ".join(names) if names.size() > 0 else "No ports found"
	else:
		_status_lbl.text = "ERROR: GdSerial plugin not found"

func _process(_delta: float) -> void:
	if _manager:
		_manager.poll_events()

# ── Connection ────────────────────────────────────────────────────────────────

func _on_connect_pressed() -> void:
	if _is_connected:
		_manager.close(PORT_NAME)
		_is_connected   = false
		_is_streaming   = false
		_manager        = null
		_connect_btn.text = "Connect"
		_stream_btn.disabled = true
		_status_lbl.text = "Disconnected"
		_set_controls_enabled(false)
		return

	var port = _port_input.text.strip_edges()
	if port.is_empty():
		port = PORT_NAME

	if not ClassDB.class_exists("GdSerialManager"):
		_status_lbl.text = "ERROR: GdSerial plugin not found"
		return

	_manager = GdSerialManager.new()
	_manager.data_received.connect(_on_raw_data)
	_manager.port_disconnected.connect(_on_disconnect)

	if _manager.open(port, BAUD_RATE, 250):
		_is_connected = true
		_connect_btn.text = "Disconnect"
		_stream_btn.disabled = false
		_status_lbl.text = "Connected: " + port
		_set_controls_enabled(true)
	else:
		_manager = null
		_status_lbl.text = "FAILED to open " + port

func _on_disconnect(_port: String) -> void:
	_hb_timer.stop()
	_is_connected = false
	_is_streaming = false
	_manager      = null
	_connect_btn.text = "Connect"
	_stream_btn.text  = "Start Stream"
	_stream_btn.disabled = true
	_status_lbl.text = "Disconnected from " + _port
	_set_controls_enabled(false)

func _on_stream_pressed() -> void:
	if _is_streaming:
		_send_bytes(PackedByteArray([CMD_STOP_STREAM]))
		_hb_timer.stop()
		_is_streaming    = false
		_stream_btn.text = "Start Stream"
		_status_lbl.text = "Stream stopped"
	else:
		_send_bytes(PackedByteArray([CMD_START_STREAM]))
		_hb_timer.start()
		_is_streaming    = true
		_stream_btn.text = "Stop Stream"
		_status_lbl.text = "Streaming…"

# ── Commands ──────────────────────────────────────────────────────────────────

func _on_ctrl_type_pressed(idx: int) -> void:
	_cmd_ctrl_idx = idx
	_send_bytes(PackedByteArray([CMD_SET_CTRL_TYPE, idx]))
	_refresh_cmd_labels()

func _on_target_slider_changed(val: float) -> void:
	_cmd_target = val
	var unit = "cm" if _selected_mech == 4 else "°"
	_target_lbl.text = "Target: %.3f %s" % [val, unit]

func _send_target() -> void:
	_cmd_target = _target_slider.value
	var buf = PackedFloat32Array([_cmd_target]).to_byte_array()
	var payload = PackedByteArray([CMD_SET_CTRL_TGT])
	payload.append_array(buf)
	_send_bytes(payload)
	_refresh_cmd_labels()

func _adjust_bound(delta: float) -> void:
	_cmd_bound = clamp(_cmd_bound + delta, 0.0, 1.0)
	var b = int(_cmd_bound * 255)
	_send_bytes(PackedByteArray([CMD_SET_CTRL_BOUND, b]))
	_refresh_cmd_labels()

func _on_dir_pressed(dir: int) -> void:
	_send_bytes(PackedByteArray([CMD_SET_CTRL_DIR, dir & 0xFF]))

func _on_calib_start() -> void:
	_send_bytes(PackedByteArray([CMD_CALIB_START, _selected_mech]))
	_status_lbl.text = "Calib START sent for %s" % MECHANISMS[_selected_mech]

func _on_calib_end() -> void:
	_send_bytes(PackedByteArray([CMD_CALIB_END, _selected_mech]))
	_status_lbl.text = "Calib END sent for %s" % MECHANISMS[_selected_mech]

func _on_mech_calib(idx: int) -> void:
	_selected_mech = idx
	_send_bytes(PackedByteArray([CMD_CALIB_START, idx]))
	_send_bytes(PackedByteArray([CMD_CALIB_END, idx]))
	_status_lbl.text = "Calib START+END → %s" % MECHANISMS[idx]
	_calib_title.text = "Calibrate: %s" % MECHANISMS[_selected_mech]
	_update_target_slider_range()

func _update_target_slider_range() -> void:
	var idx = _selected_mech
	_target_slider.min_value = MECH_MIN[idx]
	_target_slider.max_value = MECH_MAX[idx]
	_target_slider.step      = 0.5
	_target_slider.value     = 0.0
	_cmd_target = 0.0
	var unit = "cm" if idx == 4 else "°"
	_target_lbl.text = "Target: 0.000 %s" % unit
	$RootLayout/Main/Right/RightInner/TargetTitle.text = \
		"CONTROL TARGET  (%.0f to %.0f%s)" % [MECH_MIN[idx], MECH_MAX[idx], unit]

func _refresh_cmd_labels() -> void:
	var unit = "cm" if _selected_mech == 4 else "°"
	_target_lbl.text  = "Target: %.3f %s" % [_cmd_target, unit]
	_bound_lbl.text   = "Bound:  %.3f" % _cmd_bound
	_calib_title.text = "Calibrate: %s" % MECHANISMS[_selected_mech]

func _set_controls_enabled(on: bool) -> void:
	_stream_btn.disabled   = not on
	_calib_start.disabled  = not on
	_calib_end.disabled    = not on
	_target_slider.editable = on
	_target_set.disabled   = not on
	_target_zero.disabled  = not on
	_bound_dec.disabled    = not on
	_bound_inc.disabled    = not on
	for b in _ctrl_btns.get_children():
		b.disabled = not on
	for b in _dir_btns.get_children():
		b.disabled = not on
	for b in _mech_btns.get_children():
		b.disabled = not on

# ── JEDI send ─────────────────────────────────────────────────────────────────

func _send_bytes(payload: PackedByteArray) -> void:
	if _manager == null or not _is_connected:
		return
	var out := PackedByteArray()
	out.append(HEADER_OUT)
	out.append(HEADER_OUT)
	out.append(payload.size() + 1)
	out.append_array(payload)
	var chk := 0
	for b in out:
		chk = (chk + b) & 0xFF
	out.append(chk)
	var port = _port_input.text.strip_edges()
	if port.is_empty():
		port = PORT_NAME
	_manager.write(port, out)

# ── Heartbeat (called by Timer) ───────────────────────────────────────────────

func _send_heartbeat() -> void:
	_send_bytes(PackedByteArray([CMD_HEARTBEAT]))

# ── Receive / parse ───────────────────────────────────────────────────────────

func _on_raw_data(_port: String, data: PackedByteArray) -> void:
	_buf.append_array(data)
	_try_parse()

func _try_parse() -> void:
	while _buf.size() >= 4:
		var start := -1
		for i in range(_buf.size() - 1):
			if _buf[i] == HEADER_IN and _buf[i + 1] == HEADER_IN:
				start = i
				break
		if start == -1:
			_buf.clear()
			return
		if start > 0:
			_buf = _buf.slice(start)
		if _buf.size() < 4:
			return
		var pkt_len = _buf[2]
		var total   = 2 + 1 + pkt_len
		if _buf.size() < total:
			return
		var chk := 0
		for i in range(total - 1):
			chk = (chk + _buf[i]) & 0xFF
		if chk == _buf[total - 1]:
			_parse_packet(_buf.slice(0, total))
		_buf = _buf.slice(total)

func _parse_packet(raw: PackedByteArray) -> void:
	if raw.size() < 6:
		return
	var status_byte = raw[3]
	var data_type   = (status_byte >> 4) & 0x0F
	if data_type != 0:
		return
	if raw.size() < 15:
		return

	_last_status_byte = status_byte
	_last_mech_byte   = raw[6]
	_mechanism   = (raw[6] >> 4) & 0x0F
	_calibration = status_byte & 0x01
	_ctrl_type   = (status_byte & 0x0E) >> 1
	_packet_no   = raw[7] | (raw[8] << 8)
	_run_time    = (raw[9] | (raw[10] << 8) | (raw[11] << 16) | (raw[12] << 24)) * 0.001

	if raw.size() < 13 + 5 * 4 + 4:
		return

	_angle   = raw.slice(13, 17).to_float32_array()[0]
	_torque  = raw.slice(17, 21).to_float32_array()[0]
	_control = raw.slice(21, 25).to_float32_array()[0]
	_target  = raw.slice(25, 29).to_float32_array()[0]
	_desired = raw.slice(29, 33).to_float32_array()[0]

	if raw.size() > 34:
		_ctrl_bound = raw[33] / 255.0
		_ctrl_dir   = raw[34]
	if raw.size() > 36:
		_button = raw[36]

	_packet_count += 1
	_update_sensor_display()

func _update_sensor_display() -> void:
	var mech_str = MECHANISMS[_mechanism] if _mechanism < MECHANISMS.size() else "?"
	var ctrl_str = CONTROL_TYPES[_ctrl_type] if _ctrl_type < CONTROL_TYPES.size() else "?"

	_sensor_lbl.text = (
		"── Live Sensor Data ──────────────────\n"
		+ "Packets  : %d\n"         % _packet_count
		+ "Packet # : %d\n"         % _packet_no
		+ "Runtime  : %.2f s\n\n"   % _run_time
		+ "Angle    : %8.3f °\n"    % _angle
		+ "Torque   : %8.3f\n"      % _torque
		+ "Control  : %8.3f\n"      % _control
		+ "Target   : %8.3f\n"      % _target
		+ "Desired  : %8.3f\n\n"    % _desired
		+ "Ctrl Bound: %.3f\n"      % _ctrl_bound
		+ "Ctrl Dir  : %d\n\n"      % _ctrl_dir
		+ "Button    : %d\n"        % _button
		+ "Mechanism : %d (%s)\n"   % [_mechanism, mech_str]
		+ "Ctrl Type : %d (%s)\n"   % [_ctrl_type, ctrl_str]
		+ "Calibrated: %d"          % _calibration
	)

	_raw_lbl.text = "raw[3]=0x%02X  raw[6]=0x%02X" % [_last_status_byte, _last_mech_byte]

var _last_status_byte := 0
var _last_mech_byte   := 0
