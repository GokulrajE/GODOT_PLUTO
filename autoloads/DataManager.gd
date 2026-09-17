extends Node

const DATA_ROOT = "res://data/"

const CONFIG_HEADER  = "PatientID,StartDate,EndDate,TotalTime,WFE,WURD,FPS,HOC,FME1,FME2,FME1ID,FME2ID,TrainingSide,Location"
const SESSION_HEADER = "SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,TrialType,TrialStartTime,TrialStopTime,TrialRawDataFile,Mechanism,GameName,GameParameter,GameSpeed,AssistMode,DesiredSuccessRate,SuccessRate,CurrentControlBound,NextControlBound,MoveTime,CurrentTargets,CurrentHits,CurrentMisses,CummulativeTargets,CummulativeHits,CummulativeMisses,CurrentStar,CummulativeStars"
const RAW_HEADER     = "DeviceRunTime,PacketNumber,Status,DataType,ErrorStatus,ControlType,Calibration,Mechanism,Button,Angle,Torque,Desired,Control,ControlBound,ControlDir,Target,Error,ErrorDiff,ErrorSum,GamePlayerX,GamePlayerY,GameTargetX,GameTargetY,GameState,AanTargetPosition,AanInitialPosition,AanState,Annotation,Miscellaneous"

var _log_file_path: String = ""

# ══ Patient ═══════════════════════════════════════════════════════════

func patient_exists(patient_id: String) -> bool:
	return FileAccess.file_exists(DATA_ROOT + patient_id + "/configdata")

func create_patient(patient_id: String, start_date: String, end_date: String, training_side: String, location: String) -> bool:
	var base = DATA_ROOT + patient_id + "/"
	for folder in ["applog", "rawdata", "rom", "mech", "session"]:
		var err = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + folder))
		if err != OK:
			push_error("DataManager: cannot create " + base + folder)
			return false

	var file = FileAccess.open(base + "configdata", FileAccess.WRITE)
	if file == null:
		push_error("DataManager: cannot create configdata")
		return false
	file.store_line(CONFIG_HEADER)
	file.store_line("%s,%s,%s,0,0,0,0,0,0,0,-1,-1,%s,%s" % [
		patient_id, start_date, end_date, training_side, location
	])
	file.close()
	return true

func load_patient(patient_id: String) -> bool:
	var file = FileAccess.open(DATA_ROOT + patient_id + "/configdata", FileAccess.READ)
	if file == null:
		return false
	var _hdr  = file.get_line()
	var data  = file.get_line()
	file.close()

	var p = data.split(",")
	if p.size() < 14:
		return false

	AppData.patient_id            = p[0]
	AppData.patient_start_date    = p[1]
	AppData.patient_end_date      = p[2]
	AppData.config_total_time     = int(p[3])
	AppData.config_wfe            = int(p[4])
	AppData.config_wurd           = int(p[5])
	AppData.config_fps            = int(p[6])
	AppData.config_hoc            = int(p[7])
	AppData.config_fme1           = int(p[8])
	AppData.config_fme2           = int(p[9])
	AppData.config_fme1_id        = int(p[10])
	AppData.config_fme2_id        = int(p[11])
	AppData.patient_training_side = p[12]
	AppData.patient_location      = p[13]
	AppData.is_patient_loaded     = true

	_init_session_file()
	AppData.session_number = _count_session_rows()
	_init_log_file()
	log_info("DataManager", "Patient loaded: " + patient_id + "  session=" + str(AppData.session_number))
	return true

# ══ Session ════════════════════════════════════════════════════════════

func _init_session_file() -> void:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line(":Location: " + AppData.patient_location)
	file.store_line(":Device: PLUTO")
	file.store_line(":User: " + AppData.patient_id)
	file.store_line(SESSION_HEADER)
	file.close()

func _count_session_rows() -> int:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 1
	var count = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.is_empty() and not line.begins_with(":") and line != SESSION_HEADER:
			count += 1
	file.close()
	return count + 1

func write_session_row(row: Dictionary) -> void:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	var cols: PackedStringArray = SESSION_HEADER.split(",")
	var values: Array[String]   = []
	for col in cols:
		values.append(str(row.get(col.strip_edges(), "")))
	file.store_line(",".join(values))
	file.close()

# ══ Raw data ═══════════════════════════════════════════════════════════

# Creates a raw data file for one trial and returns its path.
# Naming: raw-sess{SS}-trial{TTT}-{game}-{mech}.csv
func create_raw_file(trial_no: int, game: String, mech: String, trial_type: String) -> String:
	var sess = AppData.session_number
	var path = DATA_ROOT + AppData.patient_id + "/rawdata/raw-sess%02d-trial%03d-%s-%s.csv" % [
		sess, trial_no, game, mech
	]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DataManager: cannot create raw file")
		return ""
	file.store_line(":Device: PLUTO")
	file.store_line(":Location: " + AppData.patient_location)
	file.store_line(":User: " + AppData.patient_id)
	file.store_line(":Mechanism: " + mech)
	file.store_line(":Game: " + game)
	file.store_line(":TrialType: " + trial_type)
	file.store_line(":TrialStartTime: " + Time.get_datetime_string_from_system())
	file.store_line(":TrialNumberDay: " + str(trial_no))
	var _cr = AppData.selected_mechanism.curr_rom if AppData.selected_mechanism != null else null
	file.store_line(":AROM: [%.2f,%.2f]"  % [_cr.arom_min  if _cr else 0.0, _cr.arom_max  if _cr else 0.0])
	file.store_line(":PROM: [%.2f,%.2f]"  % [_cr.prom_min  if _cr else 0.0, _cr.prom_max  if _cr else 0.0])
	file.store_line(":APROM: [%.2f,%.2f]" % [_cr.aprom_min if _cr else 0.0, _cr.aprom_max if _cr else 0.0])
	file.store_line(RAW_HEADER)
	file.close()
	return path

func append_raw_row(file_path: String, row: Dictionary) -> void:
	if file_path.is_empty():
		return
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	var cols: PackedStringArray = RAW_HEADER.split(",")
	var values: Array[String]   = []
	for col in cols:
		values.append(str(row.get(col.strip_edges(), "")))
	file.store_line(",".join(values))
	file.close()

# ══ App logger ══════════════════════════════════════════════════════════

func _init_log_file() -> void:
	var dt = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "-")
	_log_file_path = DATA_ROOT + AppData.patient_id + "/applog/" + dt + "-application.log"
	var file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if file:
		file.store_line("[%s] INFO    [%s] >> Application started" % [
			Time.get_datetime_string_from_system(), AppData.patient_id
		])
		file.close()

func log_info(scene: String, msg: String) -> void:
	_write_log("INFO   ", scene, msg)

func log_warning(scene: String, msg: String) -> void:
	_write_log("WARNING", scene, msg)

func log_error(scene: String, msg: String) -> void:
	_write_log("ERROR  ", scene, msg)

func _write_log(level: String, scene: String, msg: String) -> void:
	var line = "[%s] %s [%s] [%-16s] >> %s" % [
		Time.get_datetime_string_from_system(),
		level,
		AppData.patient_id if AppData.is_patient_loaded else "-------",
		scene, msg
	]
	print(line)
	if _log_file_path.is_empty():
		return
	var file = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(line)
		file.close()

# ══ Session query helpers ═══════════════════════════════════════════════

# Returns [trial_number_day, trial_number_session] for a mechanism today.
func read_trial_numbers(mech: String, sess_no: int) -> Array:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if not FileAccess.file_exists(path):
		return [0, 0]
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [0, 0]
	var today = Time.get_date_string_from_system()
	var max_day  := 0
	var max_sess := 0
	var _hdr = file.get_line()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		var p = line.split(",")
		if p.size() < 4:
			continue
		if p[1].begins_with(today) and p[8].strip_edges() == mech:
			var tday  = int(p[2])
			var tsess = int(p[3])
			if tday  > max_day:  max_day  = tday
			if p[0].strip_edges() == str(sess_no) and tsess > max_sess:
				max_sess = tsess
	file.close()
	return [max_day, max_sess]

# Returns [cumulative_targets, cumulative_hits, cumulative_misses] for a game+mech pair.
func read_cumulative_scores(game_name: String, mech: String) -> Array:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if not FileAccess.file_exists(path):
		return [0, 0, 0]
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [0, 0, 0]
	var last_p: PackedStringArray = PackedStringArray()
	var _hdr = file.get_line()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		var p = line.split(",")
		if p.size() < 25:
			continue
		if p[9].strip_edges() == game_name and p[8].strip_edges() == mech:
			last_p = p
	file.close()
	if last_p.is_empty():
		return [0, 0, 0]
	return [int(last_p[21]), int(last_p[22]), int(last_p[23])]

# Returns [cumulative_stars, today_stars] for a game+mech pair.
func read_star_counts(game_name: String, mech: String) -> Array:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if not FileAccess.file_exists(path):
		return [0, 0]
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [0, 0]
	var today       = Time.get_date_string_from_system()
	var today_stars := 0
	var last_cu     := 0
	var _hdr = file.get_line()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		var p = line.split(",")
		if p.size() < 26:
			continue
		if p[9].strip_edges() == game_name and p[8].strip_edges() == mech:
			last_cu = int(p[25])
			if p[1].begins_with(today):
				today_stars += int(p[24])
	file.close()
	return [last_cu, today_stars]

# Returns the NextControlBound from the last session row for this mechanism,
# or -1.0 if none exists (caller should use the default then).
func read_control_bound(mech: String) -> float:
	var path = DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if not FileAccess.file_exists(path):
		return -1.0
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1.0
	var last_bound := -1.0
	var _hdr = file.get_line()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		var p = line.split(",")
		if p.size() < 17:
			continue
		if p[8].strip_edges() == mech:
			var val := float(p[16])
			if val > 0.0:
				last_bound = val
	file.close()
	return last_bound

# Returns {date_string → total_move_seconds} for the past `days` calendar days.
func read_daily_usage(days: int) -> Dictionary:
	var result := {}
	var today_unix := int(Time.get_unix_time_from_system())
	for i in range(days - 1, -1, -1):
		var date := Time.get_date_string_from_unix_time(today_unix - i * 86400)
		result[date] = 0.0

	if not AppData.is_patient_loaded:
		return result
	var path := DATA_ROOT + AppData.patient_id + "/session/sessions.csv"
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(":"):
			continue
		var p := line.split(",")
		if p.size() < 18 or not p[0].strip_edges().is_valid_int():
			continue
		var date_str := p[1].strip_edges().left(10)
		if result.has(date_str):
			result[date_str] += float(p[17].strip_edges())
	file.close()
	return result

# ══ Path helpers ════════════════════════════════════════════════════════

func save_config() -> void:
	var path = DATA_ROOT + AppData.patient_id + "/configdata"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DataManager: cannot write configdata")
		return
	file.store_line(CONFIG_HEADER)
	file.store_line("%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s" % [
		AppData.patient_id,
		AppData.patient_start_date,
		AppData.patient_end_date,
		AppData.config_total_time,
		AppData.config_wfe,
		AppData.config_wurd,
		AppData.config_fps,
		AppData.config_hoc,
		AppData.config_fme1,
		AppData.config_fme2,
		AppData.config_fme1_id,
		AppData.config_fme2_id,
		AppData.patient_training_side,
		AppData.patient_location,
	])
	file.close()
	log_info("DataManager", "Config saved for " + AppData.patient_id)

func has_rom_data(mech_name: String) -> bool:
	var path = DATA_ROOT + AppData.patient_id + "/rom/" + mech_name + "-rom.csv"
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var _hdr = file.get_line()
	var last_line = ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.is_empty():
			last_line = line
	file.close()
	if last_line.is_empty():
		return false
	var p = last_line.split(",")
	if p.size() < 5:
		return false
	return float(p[3]) != 0.0 or float(p[4]) != 0.0

func get_patient_path() -> String: return DATA_ROOT + AppData.patient_id + "/"
func get_rom_path()     -> String: return DATA_ROOT + AppData.patient_id + "/rom/"
func get_mech_path()    -> String: return DATA_ROOT + AppData.patient_id + "/mech/"
func get_raw_path()     -> String: return DATA_ROOT + AppData.patient_id + "/rawdata/"
func get_session_path() -> String: return DATA_ROOT + AppData.patient_id + "/session/"
func get_log_path()     -> String: return DATA_ROOT + AppData.patient_id + "/applog/"
