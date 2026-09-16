class_name PlutoMechanism
extends RefCounted

var name:             String = ""
var side:             String = ""
var prom_completed:   bool   = false
var arom_completed:   bool   = false
var aprom_completed:  bool   = false
var is_cpm:           bool   = false
var old_rom:          ROM    = null
var new_rom:          ROM    = null
var trial_number_day:     int = 0
var trial_number_session: int = 0

var curr_rom: ROM:
	get:
		if new_rom != null and new_rom.is_set:
			return new_rom
		if old_rom != null and old_rom.is_set:
			return old_rom
		return null

var current_arom: Array:
	get:
		var r = curr_rom
		return [] if r == null else [r.arom_min, r.arom_max]

var current_prom: Array:
	get:
		var r = curr_rom
		return [] if r == null else [r.prom_min, r.prom_max]

var current_aprom: Array:
	get:
		var r = curr_rom
		return [] if r == null else [r.aprom_min, r.aprom_max]

func _init(mech_name: String, training_side: String) -> void:
	name    = mech_name.to_upper()
	side    = training_side
	old_rom = ROM.new()
	new_rom = ROM.new()
	new_rom.set_mechanism_name(name)
	_load_old_rom()
	_update_trial_numbers()

func _load_old_rom() -> void:
	old_rom.read_from_file(name)
	is_cpm = old_rom.is_cpm

func next_trial() -> void:
	trial_number_day     += 1
	trial_number_session += 1

func set_new_prom(pmin: float, pmax: float) -> void:
	new_rom.set_prom(pmin, pmax)
	prom_completed = (pmin != 0.0 or pmax != 0.0)

func set_new_arom(amin: float, amax: float) -> void:
	new_rom.set_arom(amin, amax)
	arom_completed = (amin != 0.0 or amax != 0.0)

func set_new_aprom(apmin: float, apmax: float) -> void:
	new_rom.set_aprom(apmin, apmax)
	aprom_completed = (apmin != 0.0 or apmax != 0.0)

func set_arom_cpm(cpm: bool) -> void:
	is_cpm = cpm
	new_rom.set_cpm(cpm)

func save_assessment_data() -> void:
	if prom_completed and arom_completed and aprom_completed:
		new_rom.write_to_file()

func _update_trial_numbers() -> void:
	var result           = DataManager.read_trial_numbers(name, AppData.session_number)
	trial_number_day     = result[0]
	trial_number_session = result[1]
