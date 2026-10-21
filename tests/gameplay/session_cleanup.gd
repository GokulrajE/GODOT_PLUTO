extends SceneTree

class FakeSerial extends RefCounted:
	signal data_received(port, data)
	signal port_disconnected(port)
	var closed := 0
	var sent: Array = []
	func write(_port, packet):
		sent.append(packet)
		return true
	func close(port):
		closed += 1
		port_disconnected.emit(port)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var comm = root.get_node("PlutoComm")
	var app = root.get_node("AppData")
	app.demo_mode = false
	for cycle in 3:
		var serial := FakeSerial.new()
		serial.data_received.connect(comm._on_raw_data)
		serial.port_disconnected.connect(comm._on_disconnect)
		comm._manager = serial
		comm._port_name = "fake"
		comm.is_connected = true
		comm.is_streaming = true
		comm._buf = PackedByteArray([255, 255, 20])
		comm._prev_button = 1
		comm._heartbeat_timer = 0.04
		comm.disconnect_device()
		assert(serial.closed == 1 and serial.sent.size() == 1)
		assert(serial.sent[0][3] == comm.CMD_STOP_STREAM)
		assert(comm._manager == null and comm._buf.is_empty())
		assert(comm._prev_button == 0 and comm._heartbeat_timer == 0.0)
		assert(not comm.is_connected and not comm.is_streaming)
		assert(serial.data_received.get_connections().is_empty())
		comm.disconnect_device()
		assert(serial.closed == 1)
	var events = root.get_node("EventBus")
	events.new_sensor_data.connect(app._on_raw_log)
	app.close_session_logging()
	assert(not events.new_sensor_data.is_connected(app._on_raw_log))
	app.close_session_logging()
	print("SESSION CLEANUP: three connection cycles and idempotent logger cleanup passed")
	quit()
