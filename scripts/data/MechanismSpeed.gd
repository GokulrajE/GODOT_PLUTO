class_name MechanismSpeed
extends RefCounted

const DEFAULT_SPEEDS: Dictionary = {
	"WFE":  10.0,
	"WURD": 10.0,
	"FPS":  10.0,
	"HOC":  10.0,
	"FME1": 10.0,
	"FME2": 10.0,
}
const SPEED_MODES: Array = ["DEFAULT", "MANUAL", "AUTO"]

var game_speed:    float = -1.0
var move_duration: float = 0.0

var _mech_name:        String = ""
var _mech_params_path: String = ""

func _init(mech_name: String) -> void:
	_mech_name        = mech_name
	_mech_params_path = DataManager.get_mech_path() + mech_name + "-mechparams.csv"
	_evaluate_and_update_speed()

func set_game_speed(speed: float) -> void:
	game_speed = speed
	_write_to_mech_params(speed, SPEED_MODES[1])

func set_move_duration(duration: float) -> void:
	move_duration = duration

func _evaluate_and_update_speed() -> void:
	if not FileAccess.file_exists(_mech_params_path):
		_write_initial_speed()
		return
	_read_last_speed()

func _read_last_speed() -> void:
	var file = FileAccess.open(_mech_params_path, FileAccess.READ)
	if file == null:
		game_speed = DEFAULT_SPEEDS.get(_mech_name, 10.0)
		return
	var last_line = ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.is_empty() and not line.begins_with(":") and not line.begins_with("DateTime"):
			last_line = line
	file.close()
	if last_line.is_empty():
		game_speed = DEFAULT_SPEEDS.get(_mech_name, 10.0)
		return
	var parts = last_line.split(",")
	if parts.size() >= 3:
		game_speed = float(parts[2])
	else:
		game_speed = DEFAULT_SPEEDS.get(_mech_name, 10.0)

func _write_initial_speed() -> void:
	game_speed = DEFAULT_SPEEDS.get(_mech_name, 10.0)
	var file = FileAccess.open(_mech_params_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line(":Location: " + AppData.patient_location)
	file.store_line(":Device: PLUTO")
	file.store_line(":User: " + AppData.patient_id)
	file.store_line("DateTime,Mode,Speed")
	file.store_line("%s,%s,%.3f" % [
		Time.get_datetime_string_from_system(), SPEED_MODES[0], game_speed
	])
	file.close()
	DataManager.log_info("MechanismSpeed",
		"%s — speed initialised to %.1f deg/s" % [_mech_name, game_speed])

func _write_to_mech_params(speed: float, mode: String) -> void:
	var file = FileAccess.open(_mech_params_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s,%s,%.3f" % [
		Time.get_datetime_string_from_system(), mode, speed
	])
	file.close()
	DataManager.log_info("MechanismSpeed",
		"%s — speed updated to %.1f deg/s (%s)" % [_mech_name, speed, mode])
