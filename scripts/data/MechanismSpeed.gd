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

func update_game_speed_from_game(speed: float) -> void:
	game_speed = speed
	_write_to_mech_params(speed, SPEED_MODES[1])

func set_move_duration(duration: float) -> void:
	move_duration = duration

func _evaluate_and_update_speed() -> void:
	if not FileAccess.file_exists(_mech_params_path):
		_write_initial_speed()
		return
	_read_last_speed()
	_try_auto_update()

func _try_auto_update() -> void:
	var last_update_date := _get_last_mech_params_date()
	if last_update_date.is_empty():
		return
	var today := Time.get_date_string_from_system()
	if _days_between(last_update_date, today) < 2:
		return

	var data      := _read_session_rows_for_mech()
	var rows: Array      = data["rows"]
	var col_map: Dictionary = data["col_map"]
	if rows.is_empty() or col_map.is_empty():
		return

	var by_date := _group_by_date(rows, col_map)
	var dates   := by_date.keys()
	dates.sort()

	# Require >=2 session dates that fall between the last mechparams update and today
	var dates_since: Array = []
	for d in dates:
		if d > last_update_date and d < today:
			dates_since.append(d)
	if dates_since.size() < 2:
		return

	# Need at least 3 total distinct dates for day1/day3 comparison
	if dates.size() < 3:
		return

	var day1_rows: Array = by_date[dates[0]]
	var day3_rows: Array = by_date[dates[2]]

	var train_sr_d1 := _get_avg_success_rate(day1_rows, "SR85PCTRAIN", col_map)
	var train_sr_d3 := _get_avg_success_rate(day3_rows, "SR85PCTRAIN", col_map)
	var catch_sr_d1 := _get_catch_success_rate(day1_rows, col_map)
	var catch_sr_d3 := _get_catch_success_rate(day3_rows, col_map)
	var cb_d1       := _get_avg_control_bound(day1_rows, "SR85PCTRAIN", col_map)
	var cb_d3       := _get_avg_control_bound(day3_rows, "SR85PCTRAIN", col_map)

	DataManager.log_info("MechanismSpeed", "%s — day1 trainSR=%.1f catchSR=%.1f CB=%.3f | day3 trainSR=%.1f catchSR=%.1f CB=%.3f" % [
		_mech_name, train_sr_d1, catch_sr_d1, cb_d1, train_sr_d3, catch_sr_d3, cb_d3])

	if train_sr_d3 > train_sr_d1 and catch_sr_d3 > catch_sr_d1 and cb_d3 < cb_d1:
		game_speed = minf(game_speed * 1.1, HomerTherapy.MAX_SPEED)
		_write_to_mech_params(game_speed, SPEED_MODES[2])
		DataManager.log_info("MechanismSpeed",
			"%s — auto speed increased to %.1f deg/s" % [_mech_name, game_speed])

func _read_session_rows_for_mech() -> Dictionary:
	var path  := DataManager.get_session_path() + "sessions.csv"
	var rows: Array      = []
	var col_map: Dictionary = {}
	var file  := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"rows": rows, "col_map": col_map}
	var header_found := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		if not header_found:
			var cols := line.split(",")
			for i in cols.size():
				col_map[cols[i]] = i
			header_found = true
			continue
		var parts    := line.split(",")
		var mech_idx: int = col_map.get("Mechanism", -1)
		if mech_idx < 0 or parts.size() <= mech_idx or parts[mech_idx] != _mech_name:
			continue
		rows.append(parts)
	file.close()
	return {"rows": rows, "col_map": col_map}

func _group_by_date(rows: Array, col_map: Dictionary) -> Dictionary:
	var by_date: Dictionary = {}
	var dt_idx: int = col_map.get("DateTime", 1)
	for row in rows:
		if row.size() <= dt_idx:
			continue
		var date := (row[dt_idx] as String).substr(0, 10)
		if not by_date.has(date):
			by_date[date] = []
		by_date[date].append(row)
	return by_date

func _get_avg_success_rate(rows: Array, trial_type: String, col_map: Dictionary) -> float:
	var tt_idx: int = col_map.get("TrialType", 4)
	var sr_idx: int = col_map.get("SuccessRate", 14)
	var total := 0.0
	var count := 0
	for row in rows:
		if count >= 4:
			break
		if row.size() <= maxi(tt_idx, sr_idx):
			continue
		if row[tt_idx] == trial_type:
			total += float(row[sr_idx])
			count += 1
	return total / count if count > 0 else 0.0

func _get_catch_success_rate(rows: Array, col_map: Dictionary) -> float:
	var tt_idx: int = col_map.get("TrialType", 4)
	var sr_idx: int = col_map.get("SuccessRate", 14)
	for row in rows:
		if row.size() <= maxi(tt_idx, sr_idx):
			continue
		if row[tt_idx] == "SR85PCCATCH":
			return float(row[sr_idx])
	return 0.0

func _get_avg_control_bound(rows: Array, trial_type: String, col_map: Dictionary) -> float:
	var tt_idx: int = col_map.get("TrialType", 4)
	var cb_idx: int = col_map.get("CurrentControlBound", 15)
	var total := 0.0
	var count := 0
	for row in rows:
		if count >= 4:
			break
		if row.size() <= maxi(tt_idx, cb_idx):
			continue
		if row[tt_idx] == trial_type:
			total += float(row[cb_idx])
			count += 1
	return total / count if count > 0 else 0.0

func _get_last_mech_params_date() -> String:
	var file := FileAccess.open(_mech_params_path, FileAccess.READ)
	if file == null:
		return ""
	var last_line := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty() and not line.begins_with(":") and not line.begins_with("DateTime"):
			last_line = line
	file.close()
	if last_line.is_empty():
		return ""
	var parts := last_line.split(",")
	if parts.size() >= 1:
		return (parts[0] as String).substr(0, 10)
	return ""

func _days_between(date_a: String, date_b: String) -> int:
	var unix_a := _date_to_unix(date_a)
	var unix_b := _date_to_unix(date_b)
	return int(abs(unix_b - unix_a) / 86400)

func _date_to_unix(date_str: String) -> int:
	var parts := date_str.split("-")
	if parts.size() < 3:
		return 0
	return Time.get_unix_time_from_datetime_dict({
		"year":   int(parts[0]),
		"month":  int(parts[1]),
		"day":    int(parts[2]),
		"hour":   0,
		"minute": 0,
		"second": 0,
	})

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
