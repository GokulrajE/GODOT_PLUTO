extends RefCounted
var file: FileAccess
var path := ""
var rows := 0
var flush_elapsed := 0.0

func start(directory: String, comm: Node) -> Error:
	stop()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	path = directory.path_join("diagnostics-%s-%d.csv" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()])
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_csv_line(PackedStringArray(["Device ID", comm.device_id, "Firmware", comm.firmware_version, "Compiled", comm.compile_date]))
	file.store_csv_line(PackedStringArray(["runtime","packet","status","datatype","error_status","mode","calibration","mechanism","button","angle","torque","control","bound","direction","gain","target","desired","error","error_diff","error_sum"]))
	rows = 0
	return OK

func append(comm: Node) -> void:
	if file == null: return
	var values := [comm.run_time,comm.packet_number,comm.status,comm.data_type,comm.error_status,comm.control_type,comm.calibration,comm.mechanism,comm.button,comm.angle,comm.torque,comm.control,comm.control_bound,comm.control_dir,comm.control_gain,comm.target,comm.desired,comm.control_error,comm.error_diff,comm.error_sum]
	var columns := PackedStringArray()
	for value in values: columns.append(str(value))
	file.store_csv_line(columns)
	rows += 1

func tick(delta: float) -> void:
	flush_elapsed += delta
	if file != null and flush_elapsed >= 1.0:
		file.flush()
		flush_elapsed = 0.0

func stop() -> void:
	if file != null:
		file.flush()
		file.close()
		file = null
