extends Node

# ── Protocol constants ──────────────────────────────────────────────
const HEADER_IN  = 0xFF
const HEADER_OUT = 0xAA
const BAUD_RATE  = 115200

const CMD_GET_VERSION    = 0x00
const CMD_CALIB_START    = 0x01
const CMD_START_STREAM   = 0x02
const CMD_STOP_STREAM    = 0x03
const CMD_SET_CTRL_TYPE  = 0x04
const CMD_SET_CTRL_TGT   = 0x05
const CMD_SET_DIAG       = 0x06
const CMD_SET_CTRL_BOUND = 0x07
const CMD_RESET_PACKET   = 0x08
const CMD_SET_CTRL_DIR   = 0x09
const CMD_SET_AAN_TGT    = 0x0A
const CMD_RESET_AAN_TGT  = 0x0B
const CMD_SET_CTRL_GAIN  = 0x0C
const CMD_CALIB_END      = 0x0D
const CMD_HEARTBEAT      = 0x80

const MECHANISMS    = ["NOMECH","WFE","WURD","FPS","HOC","FME1","FME2"]
const CONTROL_TYPES = ["NONE","POSITION","RESIST","TORQUE","POSITIONAAN"]

# ── Live data ────────────────────────────────────────────────────────
var angle:         float = 0.0
var torque:        float = 0.0
var control:       float = 0.0
var control_bound: float = 0.0
var control_dir:   int   = 0
var target:        float = 0.0
var desired:       float = 0.0
var button:        int   = 0
var mechanism:     int   = 0
var calibration:   int   = 0
var control_type:  int   = 0
var packet_number: int   = 0
var run_time:      float = 0.0
var is_connected:  bool  = false
var is_streaming:  bool  = false

# ── Internal ──────────────────────────────────────────────────────────
var _manager                  = null
var _port_name:      String   = ""
var _buf:            PackedByteArray = PackedByteArray()
var _prev_button:    int      = 0
var _heartbeat_timer: float   = 0.0
const HEARTBEAT_INTERVAL      = 0.05

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if _manager == null:
		return
	_manager.poll_events()
	if is_connected:
		_heartbeat_timer += delta
		if _heartbeat_timer >= HEARTBEAT_INTERVAL:
			_heartbeat_timer = 0.0
			_send_bytes(PackedByteArray([CMD_HEARTBEAT]))

# ── Connection ────────────────────────────────────────────────────────
func connect_device(port: String) -> bool:
	_port_name = port
	_manager = GdSerialManager.new()
	_manager.data_received.connect(_on_raw_data)
	_manager.port_disconnected.connect(_on_disconnect)
	if _manager.open(_port_name, BAUD_RATE, 250):
		is_connected = true
		print("PlutoComm: Connected on ", _port_name)
		EventBus.device_connected.emit()
		return true
	print("PlutoComm: Failed to connect on ", _port_name)
	_manager = null
	return false

func disconnect_device() -> void:
	if _manager:
		_manager.close(_port_name)
	is_connected = false
	is_streaming = false
	_manager     = null
	EventBus.device_disconnected.emit()

func start_stream() -> void:
	_send_bytes(PackedByteArray([CMD_START_STREAM]))
	is_streaming = true

func stop_stream() -> void:
	_send_bytes(PackedByteArray([CMD_STOP_STREAM]))
	is_streaming = false

# ── Send commands ─────────────────────────────────────────────────────
func send_command(payload: PackedByteArray) -> void:
	_send_bytes(payload)

func set_control_type(type_name: String) -> void:
	var idx = CONTROL_TYPES.find(type_name)
	if idx >= 0:
		_send_bytes(PackedByteArray([CMD_SET_CTRL_TYPE, idx]))

func set_control_bound(bound: float) -> void:
	var b = int(clamp(bound, 0.0, 1.0) * 255)
	_send_bytes(PackedByteArray([CMD_SET_CTRL_BOUND, b]))

func set_control_dir(dir: int) -> void:
	_send_bytes(PackedByteArray([CMD_SET_CTRL_DIR, dir & 0xFF]))

func set_control_gain(gain: float) -> void:
	var buf = PackedFloat32Array([gain]).to_byte_array()
	var payload = PackedByteArray([CMD_SET_CTRL_GAIN])
	payload.append_array(buf)
	_send_bytes(payload)

func set_control_target(target_val: float) -> void:
	var buf = PackedFloat32Array([target_val]).to_byte_array()
	var payload = PackedByteArray([CMD_SET_CTRL_TGT])
	payload.append_array(buf)
	_send_bytes(payload)

func set_aan_target(t0: float, t0_time: float, tgt: float, duration: float) -> void:
	var payload = PackedByteArray([CMD_SET_AAN_TGT])
	for f in [t0, t0_time, tgt, duration]:
		payload.append_array(PackedFloat32Array([f]).to_byte_array())
	_send_bytes(payload)

func reset_aan_target() -> void:
	_send_bytes(PackedByteArray([CMD_RESET_AAN_TGT]))

func calibrate_start(mech_name: String) -> void:
	var idx = MECHANISMS.find(mech_name)
	if idx >= 0:
		_send_bytes(PackedByteArray([CMD_CALIB_START, idx]))

func calibrate_end(mech_name: String) -> void:
	var idx = MECHANISMS.find(mech_name)
	if idx >= 0:
		_send_bytes(PackedByteArray([CMD_CALIB_END, idx]))

func get_version() -> void:
	_send_bytes(PackedByteArray([CMD_GET_VERSION]))

func set_diagnostic_mode() -> void:
	_send_bytes(PackedByteArray([CMD_SET_DIAG]))

# ── JEDI frame builder ────────────────────────────────────────────────
func _send_bytes(payload: PackedByteArray) -> void:
	if _manager == null or not is_connected:
		return
	var out = PackedByteArray()
	out.append(HEADER_OUT)
	out.append(HEADER_OUT)
	out.append(payload.size() + 1)
	out.append_array(payload)
	var checksum = 0
	for b in out:
		checksum = (checksum + b) & 0xFF
	out.append(checksum)
	_manager.write(_port_name, out)

# ── Raw data received ─────────────────────────────────────────────────
func _on_raw_data(_port: String, data: PackedByteArray) -> void:
	_buf.append_array(data)
	_try_parse()

func _on_disconnect(_port: String) -> void:
	print("PlutoComm: Disconnected from ", _port)
	is_connected = false
	is_streaming = false
	EventBus.device_disconnected.emit()

# ── JEDI packet parser ────────────────────────────────────────────────
func _try_parse() -> void:
	while _buf.size() >= 4:
		var start = -1
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

		var chksum = 0
		for i in range(total - 1):
			chksum = (chksum + _buf[i]) & 0xFF

		if chksum == _buf[total - 1]:
			_parse_packet(_buf.slice(0, total))

		_buf = _buf.slice(total)

# ── Parse a complete validated packet ────────────────────────────────
func _parse_packet(raw: PackedByteArray) -> void:
	if raw.size() < 6:
		return

	var status_byte = raw[3]
	var data_type   = (status_byte >> 4) & 0x0F

	if data_type != 0:
		return

	if raw.size() < 15:
		return

	var prev_mech = mechanism
	var prev_ctrl = control_type
	mechanism    = (raw[6] >> 4) & 0x0F
	calibration  = status_byte & 0x01
	control_type = (status_byte & 0x0E) >> 1

	packet_number = raw[7] | (raw[8] << 8)
	run_time = (raw[9] | (raw[10] << 8) | (raw[11] << 16) | (raw[12] << 24)) * 0.001

	if raw.size() < 13 + 5 * 4 + 4:
		return

	angle   = raw.slice(13, 17).to_float32_array()[0]
	torque  = raw.slice(17, 21).to_float32_array()[0]
	control = raw.slice(21, 25).to_float32_array()[0]
	target  = raw.slice(25, 29).to_float32_array()[0]
	desired = raw.slice(29, 33).to_float32_array()[0]

	if raw.size() > 34:
		control_bound = raw[33] / 255.0
		control_dir   = raw[34]

	if raw.size() > 36:
		button = raw[36]
		if _prev_button == 0 and button == 1:
			print("PlutoComm: button pressed")
			EventBus.button_released.emit()
		_prev_button = button

	EventBus.new_sensor_data.emit()

	if prev_ctrl != control_type:
		EventBus.control_mode_changed.emit()
	if prev_mech != mechanism:
		EventBus.mechanism_changed.emit()
