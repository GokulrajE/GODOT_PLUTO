class_name DataLogger
extends RefCounted

var curr_file_name: String = ""
var _buffer:        PackedStringArray = PackedStringArray()

var still_logging: bool:
	get: return not curr_file_name.is_empty()

func _init(file_name: String, header: String) -> void:
	curr_file_name = file_name
	_buffer.append(header)

func log_data(data: String) -> void:
	if still_logging:
		_buffer.append(data)

func stop_data_log() -> void:
	if not still_logging:
		return
	var file = FileAccess.open(curr_file_name, FileAccess.READ_WRITE)
	if file != null:
		file.seek_end()
		for line in _buffer:
			file.store_string(line)
		file.close()
	curr_file_name = ""
	_buffer.clear()
