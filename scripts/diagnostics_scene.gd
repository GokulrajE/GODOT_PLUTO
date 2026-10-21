extends Control
const Log = preload("res://scripts/diagnostics_log.gd")
var logger := Log.new()
var calibration_step := -1
var moving := false
var move_elapsed := 0.0
var move_start := 0.0
var move_end := 0.0
var refresh := 0.0
var send_elapsed := 0.0
var packet_count := 0
var rate_elapsed := 0.0
var packet_hz := 0.0
var previous_mechanism := -1
var last_data_ms := 0
var configuring_target := false

func _ready() -> void:
	%Port.text = AppStorage.device_port()
	for mechanism in PlutoComm.MECHANISMS.slice(1): %Mechanism.add_item(mechanism)
	for mode in PlutoComm.CONTROL_TYPES: %Mode.add_item(mode)
	%Connect.pressed.connect(_connect_device)
	%Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainScene.tscn"))
	%Stop.pressed.connect(stop_output)
	%Calibrate.pressed.connect(_begin_calibration)
	%CancelCalibration.pressed.connect(_cancel_calibration)
	%Enable.toggled.connect(_enable_control)
	%Mode.item_selected.connect(_mode_changed)
	%Target.value_changed.connect(_target_changed)
	%Bound.value_changed.connect(func(value):
		if _can_control() and %Mode.selected in [1, 4]: PlutoComm.set_control_bound(value))
	%Gain.value_changed.connect(func(value):
		if _can_control() and %Mode.selected in [1, 4]: PlutoComm.set_control_gain(value))
	%RandomTarget.pressed.connect(_random_target)
	%Record.toggled.connect(_record)
	EventBus.new_sensor_data.connect(_received)
	EventBus.device_disconnected.connect(_disconnected)
	EventBus.button_released.connect(_calibration_button)
	if PlutoComm.is_connected: _start_diagnostics()
	_update_ui()

func _connect_device() -> void:
	if PlutoComm.is_connected:
		stop_output()
		PlutoComm.disconnect_device()
		return
	if %Port.text.strip_edges().is_empty():
		%Notice.text = "Enter the serial port from device.cfg."
		return
	if PlutoComm.connect_device(%Port.text.strip_edges()): _start_diagnostics()
	else: %Notice.text = "Connection failed. Check the port and device."
	_update_ui()

func _start_diagnostics() -> void:
	stop_output()
	packet_count = 0
	last_data_ms = 0
	PlutoComm.get_version()
	PlutoComm.set_diagnostic_mode()
	PlutoComm.is_streaming = true
	%Notice.text = "Diagnostics connected. Control output is off."

func _received() -> void:
	packet_count += 1
	last_data_ms = Time.get_ticks_msec()
	if PlutoComm.data_type == 2: logger.append(PlutoComm)

func _process(delta: float) -> void:
	logger.tick(delta)
	rate_elapsed += delta
	if rate_elapsed >= 1.0:
		packet_hz = packet_count / rate_elapsed
		packet_count = 0
		rate_elapsed = 0.0
	if %Enable.button_pressed and (PlutoComm.error_status != 0 or last_data_ms == 0 or Time.get_ticks_msec() - last_data_ms > 1000):
		stop_output()
		%Notice.text = "Control stopped: device error or telemetry unavailable."
	if moving and _can_control():
		move_elapsed += delta
		send_elapsed += delta
		if send_elapsed >= 0.05:
			send_elapsed = 0.0
			var t := clampf(move_elapsed / %Duration.value, 0.0, 1.0)
			var value := lerpf(move_start, move_end, t*t*t*(10.0 - 15.0*t + 6.0*t*t))
			PlutoComm.set_control_target(value)
			%Target.set_value_no_signal(AppData.hoc_to_cm(value) if PlutoComm.mechanism == 4 else value)
			moving = t < 1.0
	refresh += delta
	if refresh >= 0.1:
		refresh = 0.0
		_update_ui()

func _can_control() -> bool:
	return PlutoComm.is_connected and %Enable.button_pressed and calibration_step == -1 and PlutoComm.mechanism in range(1, 7) and PlutoComm.error_status == 0 and last_data_ms > 0 and Time.get_ticks_msec() - last_data_ms <= 1000

func stop_output() -> void:
	moving = false
	%Enable.set_pressed_no_signal(false)
	%Mode.select(0)
	PlutoComm.set_control_type("NONE")
	PlutoComm.set_control_target(0.0)
	_update_ui()

func _enable_control(enabled: bool) -> void:
	stop_output()
	if enabled and PlutoComm.is_connected and calibration_step == -1 and last_data_ms > 0:
		%Enable.set_pressed_no_signal(true)
		%Notice.text = "Select a control mode. Stop output disables control immediately."
	_update_ui()

func _mode_changed(index: int) -> void:
	if not _can_control(): return
	moving = false
	PlutoComm.set_control_type("NONE")
	_configure_target(index)
	PlutoComm.set_control_target(_target_angle())
	if index in [1, 4]:
		PlutoComm.set_control_bound(%Bound.value)
		PlutoComm.set_control_gain(%Gain.value)
	PlutoComm.set_control_type(PlutoComm.CONTROL_TYPES[index])
	_update_ui()

func _configure_target(mode: int) -> void:
	configuring_target = true
	var mech := clampi(PlutoComm.mechanism, 0, 6)
	if mode == 3:
		%Target.min_value = -1.0
		%Target.max_value = 1.0
		%Target.step = 0.01
		%Target.suffix = "Nm"
		%Target.set_value_no_signal(0.0)
	else:
		%Target.min_value = 0.0 if mech == 4 else -AppData.MECH_OFFSET[mech]
		%Target.max_value = AppData.hoc_to_cm(AppData.CALIB_ANGLE[mech]) if mech == 4 else AppData.CALIB_ANGLE[mech] - AppData.MECH_OFFSET[mech]
		%Target.step = 0.1
		%Target.suffix = "cm" if mech == 4 else "deg"
		%Target.set_value_no_signal(AppData.hoc_to_cm(PlutoComm.angle) if mech == 4 else PlutoComm.angle)

	configuring_target = false

func _target_angle() -> float:
	return AppData.cm_to_hoc(%Target.value) if PlutoComm.mechanism == 4 and %Mode.selected in [1, 4] else %Target.value

func _target_changed(_value: float) -> void:
	if not configuring_target and _can_control() and %Mode.selected in [1, 3, 4]:
		moving = false
		PlutoComm.set_control_target(_target_angle())

func _random_target() -> void:
	if not _can_control() or %Mode.selected not in [1, 4]: return
	move_start = PlutoComm.angle
	var chosen := randf_range(%Target.min_value, %Target.max_value)
	move_end = AppData.cm_to_hoc(chosen) if PlutoComm.mechanism == 4 else chosen
	move_elapsed = 0.0
	send_elapsed = 0.0
	if %Mode.selected == 4:
		PlutoComm.set_aan_target(move_start, -0.1, move_end, %Duration.value)
	else: moving = true

func _begin_calibration() -> void:
	if not PlutoComm.is_connected: return
	stop_output()
	calibration_step = 0
	PlutoComm.calibrate_start("NOMECH")
	%CalibrationStatus.text = "Move to zero. Press the PLUTO button to set zero."
	_update_ui()

func _calibration_button() -> void:
	if not PlutoComm.is_connected or calibration_step < 0: return
	var mech: int = %Mechanism.selected + 1
	if calibration_step == 0:
		if PlutoComm.calibration != 0: return
		PlutoComm.calibrate_start(PlutoComm.MECHANISMS[mech])
		calibration_step = 1
		%CalibrationStatus.text = "Zero set. Move to the other limit, then press the PLUTO button."
	elif calibration_step == 1:
		var span := absf(PlutoComm.angle + AppData.MECH_OFFSET[mech])
		if span >= 0.9 * AppData.CALIB_ANGLE[mech] and span <= 1.1 * AppData.CALIB_ANGLE[mech]:
			PlutoComm.calibrate_end(PlutoComm.MECHANISMS[mech])
			%CalibrationStatus.text = "Calibration complete. Press the PLUTO button to finish."
		else:
			PlutoComm.calibrate_start("NOMECH")
			%CalibrationStatus.text = "Range outside tolerance. Press the PLUTO button, then retry."
		calibration_step = 2
	else:
		calibration_step = -1
		%CalibrationStatus.text = "Calibration finished. Choose a mechanism to calibrate again."
	_update_ui()

func _cancel_calibration() -> void:
	if calibration_step in [0, 1]: PlutoComm.calibrate_start("NOMECH")
	calibration_step = -1
	%CalibrationStatus.text = "Choose a mechanism to calibrate manually."
	stop_output()

func _record(enabled: bool) -> void:
	if enabled:
		if not PlutoComm.is_connected or logger.start(AppStorage.root_path + "diagnostics", PlutoComm) != OK:
			%Record.set_pressed_no_signal(false)
			%Notice.text = "Could not start recording. Check connection and storage."
		else: %Notice.text = "Recording: " + logger.path
	else:
		logger.stop()
		%Notice.text = "Saved %d diagnostic rows to %s" % [logger.rows, logger.path]

func _disconnected() -> void:
	logger.stop()
	%Record.set_pressed_no_signal(false)
	calibration_step = -1
	stop_output()
	%Notice.text = "Device disconnected. Output and recording stopped."

func _update_ui() -> void:
	if not is_node_ready(): return
	var connected := PlutoComm.is_connected
	%Connect.text = "Disconnect" if connected else "Connect"
	%Port.editable = not connected
	%Connection.text = "%s  •  %.0f packets/s  •  %d FPS" % ["Connected" if connected else "Disconnected", packet_hz if connected else 0.0, Engine.get_frames_per_second()]
	if previous_mechanism != PlutoComm.mechanism:
		previous_mechanism = PlutoComm.mechanism
		if %Enable.button_pressed: stop_output()
		_configure_target(0)
	%Enable.disabled = not connected or calibration_step >= 0 or PlutoComm.mechanism not in range(1, 7) or PlutoComm.error_status != 0
	%Mode.disabled = not _can_control()
	for node in [%Target, %Bound, %Gain, %Duration]: node.editable = _can_control()
	%Target.editable = _can_control() and %Mode.selected in [1, 3, 4] and not moving
	%Bound.editable = _can_control() and %Mode.selected in [1, 4]
	%Gain.editable = %Bound.editable
	%Duration.editable = %Bound.editable
	%RandomTarget.disabled = not %Bound.editable or moving
	%Calibrate.disabled = not connected or %Enable.button_pressed or calibration_step >= 0
	%Mechanism.disabled = calibration_step >= 0
	%CancelCalibration.disabled = calibration_step < 0
	%Record.disabled = not connected
	var mech: String = PlutoComm.MECHANISMS[PlutoComm.mechanism] if PlutoComm.mechanism in range(7) else "Unknown"
	var mode: String = PlutoComm.CONTROL_TYPES[PlutoComm.control_type] if PlutoComm.control_type in range(5) else "Unknown"
	%Telemetry.text = "Device: %s\nFirmware: %s\nCompiled: %s\n\nMechanism: %s   |   Mode: %s\nCalibrated: %s   |   Actuated: %s\nPacket: %d   |   Runtime: %.2f s\nButton: %d   |   Error bits: 0x%04X\n\nAngle: %.2f deg   |   HOC: %.2f cm\nTorque: %.3f Nm\nControl: %.3f   |   Target: %.3f\nDesired: %.3f\nBound: %.3f   |   Direction: %d\nGain: %.2f\n\nError: %.3f\nError difference: %.3f\nError sum: %.3f\n\nRecorded rows: %d" % [PlutoComm.device_id, PlutoComm.firmware_version, PlutoComm.compile_date, mech, mode, PlutoComm.calibration == 1, PlutoComm.actuated, PlutoComm.packet_number, PlutoComm.run_time, PlutoComm.button, PlutoComm.error_status, PlutoComm.angle, AppData.hoc_to_cm(PlutoComm.angle), PlutoComm.torque, PlutoComm.control, PlutoComm.target, PlutoComm.desired, PlutoComm.control_bound, PlutoComm.control_dir, PlutoComm.control_gain, PlutoComm.control_error, PlutoComm.error_diff, PlutoComm.error_sum, logger.rows]

func _exit_tree() -> void:
	logger.stop()
	if PlutoComm.is_connected:
		_cancel_calibration()
		PlutoComm.disconnect_device()
