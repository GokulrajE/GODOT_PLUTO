extends SceneTree
var checks := 0
var failures := 0
class FakeSerial extends RefCounted:
	signal data_received(port, data)
	signal port_disconnected(port)
	var sent: Array = []
	var closed := false
	func write(_port, bytes):
		sent.append(bytes)
		return true
	func poll_events(): pass
	func close(_port): closed = true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func packet(kind: int) -> PackedByteArray:
	var raw := PackedByteArray()
	var count := 8 if kind == 2 else 5
	raw.resize(13 + count * 4 + 5)
	raw[3] = kind << 4
	raw[6] = 17
	raw.encode_u16(7, 123)
	raw.encode_u32(9, 1250)
	for i in count: raw.encode_float(13 + i * 4, float(i + 1))
	var tail := 13 + count * 4
	raw[tail] = 128
	raw[tail + 1] = 255
	raw[tail + 2] = 255
	return raw

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 800)
	var comm = root.get_node("PlutoComm")
	var app = root.get_node("AppData")
	app.demo_mode = false
	var serial := FakeSerial.new()
	comm._manager = serial
	comm.is_connected = true
	comm._port_name = "fixture"
	comm.set_process(false)
	comm._parse_packet(packet(0))
	check(comm.angle == 1.0 and comm.desired == 5.0, "sensor stream unchanged")
	comm._parse_packet(packet(2))
	check(comm.control_error == 6.0 and comm.error_diff == 7.0 and comm.error_sum == 8.0, "diagnostic floats")
	check(comm.control_gain == 20.0 and comm.control_dir == -1, "diagnostic state offset")
	check(comm.packet_number == 123 and comm.run_time == 1.25 and comm.actuated, "packet metadata")
	var raw := PackedByteArray([255,255,0,48,0,0,0])
	raw.append_array("PLUTO-TEST,2.1,2026-10-16".to_ascii_buffer())
	raw.append(0)
	comm._parse_packet(raw)
	check(comm.device_id == "PLUTO-TEST" and comm.firmware_version == "2.1", "firmware response")
	comm.set_control_gain(10.5)
	check(serial.sent.back()[3] == 12 and serial.sent.back()[4] == 127 and serial.sent.back().size() == 6, "gain byte matches HOMER protocol")
	change_scene_to_file("res://scenes/DiagnosticsScene.tscn")
	await create_timer(.2).timeout
	var scene = current_scene
	comm._parse_packet(packet(2))
	scene._update_ui()
	check(not scene.get_node("%Enable").button_pressed, "output initially off")
	scene._enable_control(true)
	scene.get_node("%Mode").select(1)
	scene._mode_changed(1)
	check(scene.get_node("%Target").min_value == -68.0 and scene.get_node("%Target").max_value == 68.0, "WFE target limits")
	scene._random_target()
	check(scene.moving and scene.move_end >= -68 and scene.move_end <= 68, "bounded random trajectory")
	scene.stop_output()
	check(not scene.moving and not scene.get_node("%Enable").button_pressed, "stop cancels trajectory")
	comm.mechanism = 4
	scene._update_ui()
	scene._enable_control(true)
	scene.get_node("%Mode").select(1)
	scene._mode_changed(1)
	check(is_equal_approx(scene.get_node("%Target").max_value, app.hoc_to_cm(93.0)), "HOC target uses centimeters")
	scene.get_node("%Target").set_value_no_signal(5.0)
	check(is_equal_approx(scene._target_angle(), app.cm_to_hoc(5.0)), "HOC target converts to negative angle")
	scene.last_data_ms = Time.get_ticks_msec() - 1500
	scene._process(.1)
	check(not scene.get_node("%Enable").button_pressed, "stale telemetry disables output")
	comm._parse_packet(packet(2))
	scene._update_ui()
	scene._begin_calibration()
	scene._calibration_button()
	check(scene.calibration_step == 1, "manual zero calibration")
	comm.angle = 68.0
	scene._calibration_button()
	check(scene.calibration_step == 2 and serial.sent.back()[3] == 13, "calibration limit accepted")
	scene._calibration_button()
	check(scene.calibration_step == -1, "calibration completes")
	scene._record(true)
	comm._parse_packet(packet(2))
	scene._record(false)
	check(scene.logger.rows == 1 and FileAccess.get_file_as_string(scene.logger.path).contains("error_diff"), "diagnostic CSV written")
	scene._enable_control(true)
	comm.error_status = 1
	scene._process(.1)
	check(not scene.get_node("%Enable").button_pressed, "device error stops output")
	comm.error_status = 0
	scene._update_ui()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/diagnostics-preview.png")
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(.2).timeout
	check(serial.closed and not comm.is_connected, "exit releases device")
	print("DIAGNOSTICS: %d checks, %d failures" % [checks, failures])
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
		node.stream = null
	await process_frame
	quit(1 if failures else 0)
