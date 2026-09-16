class_name ROM
extends RefCounted

const _DATA_ROOT  = "res://data/"
const _ROM_HEADER = "DateTime,PromMin,PromMax,AromMin,AromMax,APromMin,APromMax,IsCPM"

var mechanism: String = ""
var datetime:  String = ""
var prom_min:  float  = 0.0
var prom_max:  float  = 0.0
var arom_min:  float  = 0.0
var arom_max:  float  = 0.0
var aprom_min: float  = 0.0
var aprom_max: float  = 0.0
var is_cpm:    bool   = false

var is_prom_set: bool:
	get: return prom_min != 0.0 or prom_max != 0.0

var is_arom_set: bool:
	get: return arom_min != 0.0 or arom_max != 0.0

var is_set: bool:
	get: return is_prom_set and is_arom_set

func set_prom(min_val: float, max_val: float) -> void:
	prom_min = min_val
	prom_max = max_val
	datetime = Time.get_datetime_string_from_system()

func set_arom(min_val: float, max_val: float) -> void:
	arom_min = min_val
	arom_max = max_val
	datetime = Time.get_datetime_string_from_system()

func set_cpm(val: bool) -> void:
	is_cpm = val

func set_aprom(min_val: float, max_val: float) -> void:
	aprom_min = min_val
	aprom_max = max_val
	datetime  = Time.get_datetime_string_from_system()

func set_mechanism_name(mech: String) -> void:
	if mechanism.is_empty():
		mechanism = mech

# Read the last row from {patient_id}/rom/{mech}-rom.csv into this ROM.
# Returns true if data was found.
func read_from_file(mech_name: String) -> bool:
	var path = _DATA_ROOT + AppData.patient_id + "/rom/" + mech_name + "-rom.csv"
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var _hdr      = file.get_line()
	var last_line = ""
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.is_empty():
			last_line = line
	file.close()
	if last_line.is_empty():
		return false
	var p = last_line.split(",")
	if p.size() < 7:
		return false
	mechanism = mech_name
	datetime  = p[0]
	prom_min  = float(p[1])
	prom_max  = float(p[2])
	arom_min  = float(p[3])
	arom_max  = float(p[4])
	aprom_min = float(p[5])
	aprom_max = float(p[6])
	is_cpm    = (p.size() >= 8 and p[7].strip_edges().to_lower() == "true")
	return true

# Append this ROM's values to {patient_id}/rom/{mechanism}-rom.csv.
func write_to_file() -> void:
	if mechanism.is_empty():
		push_error("ROM.write_to_file: mechanism not set")
		return
	var path        = _DATA_ROOT + AppData.patient_id + "/rom/" + mechanism + "-rom.csv"
	var needs_header = not FileAccess.file_exists(path)
	var file: FileAccess
	if needs_header:
		file = FileAccess.open(path, FileAccess.WRITE)
	else:
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	if file == null:
		push_error("ROM.write_to_file: cannot open " + path + " — " + str(FileAccess.get_open_error()))
		return
	if needs_header:
		file.store_line(_ROM_HEADER)
	datetime = Time.get_datetime_string_from_system()
	file.store_line("%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s" % [
		datetime, prom_min, prom_max, arom_min, arom_max, aprom_min, aprom_max,
		str(is_cpm)
	])
	file.close()
	DataManager.log_info("ROM",
		"Saved — mech=%s PROM[%.1f,%.1f] AROM[%.1f,%.1f] APROM[%.1f,%.1f] CPM=%s" % [
			mechanism, prom_min, prom_max, arom_min, arom_max, aprom_min, aprom_max,
			str(is_cpm)
		])
