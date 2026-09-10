extends Node

const _PlutoMechanism = preload("res://scripts/data/PlutoMechanism.gd")
const _PlutoGame      = preload("res://scripts/data/PlutoGame.gd")
const _MechanismSpeed = preload("res://scripts/data/MechanismSpeed.gd")
const _DataLogger     = preload("res://scripts/data/DataLogger.gd")
const _HomerTherapy   = preload("res://scripts/data/HomerTherapy.gd")

# ── Mechanism constants ───────────────────────────────────────────────
const MECHANISMS  = ["NOMECH", "WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]
const CALIB_ANGLE = [0,        136,   136,    180,   93,    180,    180   ]
const MECH_OFFSET = [0.0,      68.0,  68.0,   90.0,  0.0,   90.0,   90.0  ]
const HOC_SCALE   = 0.10752

# ── Patient data ──────────────────────────────────────────────────────
var patient_id:            String = ""
var patient_start_date:    String = ""
var patient_end_date:      String = ""
var patient_training_side: String = "Right"
var patient_location:      String = ""
var is_patient_loaded:     bool   = false

# ── Session & trial tracking ─────────────────────────────────────────
var session_number:       int = 1
var trial_number_day:     int = 0
var trial_number_session: int = 0

# ── Selected mechanism ────────────────────────────────────────────────
var mechanism_index: int    = 0
var mechanism_name:  String = "NOMECH"
var calib_angle:     int    = 0
var mech_offset:     float  = 0.0

# ── Calibration ───────────────────────────────────────────────────────
var is_calibrated: bool = false

# ── Assist profile ────────────────────────────────────────────────────
const DEFAULT_CTRL_BOUND: float = 0.6
const MIN_CTRL_BOUND:     float = 0.16
const MAX_CTRL_BOUND:     float = 1.0
const FORGET_FACTOR:      float = 0.9
const ASSIST_FACTOR:      float = 0.01

var assist_bound: float = DEFAULT_CTRL_BOUND
var assist_dir:   int   = 0

# ── Rich data objects ─────────────────────────────────────────────────
var selected_mechanism = null  # PlutoMechanism
var selected_game      = null  # PlutoGame
var speed_data         = null  # MechanismSpeed
var selected_game_name: String = ""

# ── Trial state ───────────────────────────────────────────────────────
var trial_start_time:     String = ""
var trial_raw_file:       String = ""
var desired_success_rate: float  = 85.0
var success_rate:         float  = 0.0
var trial_type:           int    = 0  # _HomerTherapy.TrialType.SR85PCTRAIN
var _trial_raw_logger           = null  # DataLogger
var _last_target:         float  = INF

# ── Game log state (updated by the active game each frame) ─────────────
var log_player_x:  float  = 0.0
var log_player_y:  float  = 0.0
var log_target_x:  float  = 0.0
var log_target_y:  float  = 0.0
var log_game_state: String = ""
var log_aan_target: float  = 0.0
var log_aan_init:   float  = 0.0
var log_aan_state:  String = ""

# ── HOC helpers ───────────────────────────────────────────────────────
func hoc_to_cm(angle: float) -> float:
	return HOC_SCALE * abs(angle)

func cm_to_hoc(cm: float) -> float:
	return -cm / HOC_SCALE

# ── Mechanism selection ───────────────────────────────────────────────
func set_mechanism(index: int) -> void:
	mechanism_index    = index
	mechanism_name     = MECHANISMS[index]
	calib_angle        = CALIB_ANGLE[index]
	mech_offset        = MECH_OFFSET[index]
	is_calibrated      = false
	selected_mechanism = null
	speed_data         = null
	if is_patient_loaded:
		selected_mechanism = _PlutoMechanism.new(mechanism_name, patient_training_side)
		speed_data         = _MechanismSpeed.new(mechanism_name)
		var saved_bound := DataManager.read_control_bound(mechanism_name)
		assist_bound = saved_bound if saved_bound > 0.0 else DEFAULT_CTRL_BOUND
		DataManager.log_info("AppData",
			"Mechanism set: %s — Trial#Day=%d Trial#Sess=%d CtrlBound=%.3f" % [
				mechanism_name,
				selected_mechanism.trial_number_day,
				selected_mechanism.trial_number_session,
				assist_bound])
	EventBus.mechanism_selected.emit(index)

# ── Game selection ────────────────────────────────────────────────────
func set_game(game_name: String) -> void:
	selected_game_name = game_name
	if selected_mechanism == null:
		return
	var cu_scores = DataManager.read_cumulative_scores(game_name, mechanism_name)
	var stars     = DataManager.read_star_counts(game_name, mechanism_name)
	selected_game = _PlutoGame.new(
		game_name, mechanism_name,
		cu_scores[0], cu_scores[1], cu_scores[2],
		stars[0], stars[1])
	DataManager.log_info("AppData", "Game set: " + game_name)

# ── Trial lifecycle ───────────────────────────────────────────────────
func start_new_trial() -> void:
	if selected_mechanism == null:
		return
	trial_start_time = Time.get_datetime_string_from_system()
	selected_mechanism.next_trial()

	var t = _HomerTherapy.get_trial_type_and_success_rate(selected_mechanism.trial_number_day)
	desired_success_rate = t["success_rate"]
	trial_type           = t["trial_type"]

	var type_name = _HomerTherapy.TrialType.keys()[trial_type]
	trial_raw_file    = DataManager.create_raw_file(
		selected_mechanism.trial_number_day,
		selected_game_name,
		mechanism_name,
		type_name)
	_trial_raw_logger = _DataLogger.new(trial_raw_file, "")
	EventBus.new_sensor_data.connect(_on_raw_log)

	DataManager.log_info("AppData",
		"StartTrial | Day=%d Sess=%d Type=%s DesiredSR=%.1f File=%s" % [
			selected_mechanism.trial_number_day,
			selected_mechanism.trial_number_session,
			type_name,
			desired_success_rate,
			trial_raw_file.get_file()])

func stop_trial(targets: int, hits: int, misses: int) -> void:
	if selected_mechanism == null or selected_game == null:
		return
	var n_targets    = max(targets, 1)
	success_rate     = 100.0 * hits / n_targets
	selected_game.update_targets_hits_misses(targets, hits, misses)

	# Adapt control bound (Unity PlutoAANController.AdaptControlBound logic)
	var current_bound := assist_bound
	var next_bound    := current_bound * FORGET_FACTOR \
		+ ASSIST_FACTOR * (desired_success_rate - success_rate)
	next_bound   = clamp(next_bound, MIN_CTRL_BOUND, MAX_CTRL_BOUND)
	assist_bound = next_bound

	var type_name    = _HomerTherapy.TrialType.keys()[trial_type]
	var is_catch     = (trial_type == _HomerTherapy.TrialType.SR85PCCATCH)
	DataManager.write_session_row({
		"SessionNumber":       session_number,
		"DateTime":            Time.get_datetime_string_from_system(),
		"TrialNumberDay":      selected_mechanism.trial_number_day,
		"TrialNumberSession":  selected_mechanism.trial_number_session,
		"TrialType":           type_name,
		"TrialStartTime":      trial_start_time,
		"TrialStopTime":       Time.get_datetime_string_from_system(),
		"TrialRawDataFile":    trial_raw_file.get_file(),
		"Mechanism":           mechanism_name,
		"GameName":            selected_game_name,
		"GameParameter":       speed_data.move_duration if speed_data else 0.0,
		"GameSpeed":           speed_data.game_speed    if speed_data else 0.0,
		"AssistMode":          "ACTIVE" if is_catch else "AAN",
		"DesiredSuccessRate":  "%.3f" % desired_success_rate,
		"SuccessRate":         "%.3f" % success_rate,
		"CurrentControlBound":"%.3f" % current_bound,
		"NextControlBound":    "%.3f" % next_bound,
		"MoveTime":           _HomerTherapy.TRIAL_DURATION,
		"CurrentTargets":     selected_game.current_targets,
		"CurrentHits":        selected_game.current_hits,
		"CurrentMisses":      selected_game.current_misses,
		"CummulativeTargets": selected_game.cumulative_targets,
		"CummulativeHits":    selected_game.cumulative_hits,
		"CummulativeMisses":  selected_game.cumulative_misses,
		"CurrentStar":        selected_game.current_star,
		"CummulativeStars":   selected_game.cumulative_stars,
	})
	DataManager.log_info("AppData",
		"CtrlBound: %.3f → %.3f (SR=%.1f%% desired=%.1f%%)" % [
			current_bound, next_bound, success_rate, desired_success_rate])

	if EventBus.new_sensor_data.is_connected(_on_raw_log):
		EventBus.new_sensor_data.disconnect(_on_raw_log)

	if _trial_raw_logger != null:
		_trial_raw_logger.stop_data_log()
		_trial_raw_logger = null

	selected_game.reset_star_count()
	DataManager.log_info("AppData",
		"StopTrial | SR=%.1f%% Targets=%d Hits=%d Misses=%d" % [
			success_rate, targets, hits, misses])

func _on_raw_log() -> void:
	if _trial_raw_logger == null or not _trial_raw_logger.still_logging:
		return
	var mech_name = PlutoComm.MECHANISMS[PlutoComm.mechanism] \
		if PlutoComm.mechanism < PlutoComm.MECHANISMS.size() else ""
	var ctrl_name = PlutoComm.CONTROL_TYPES[PlutoComm.control_type] \
		if PlutoComm.control_type < PlutoComm.CONTROL_TYPES.size() else ""
	var row = "%s,%d,%d,%d,0,%s,%d,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%.6f,0,0,0,%.3f,%.3f,%.3f,%.3f,%s,%.3f,%.3f,%s,," % [
		"%.6f" % PlutoComm.run_time,
		PlutoComm.packet_number,
		PlutoComm.status,
		PlutoComm.data_type,
		ctrl_name,
		PlutoComm.calibration,
		mech_name,
		PlutoComm.button,
		PlutoComm.angle,
		PlutoComm.torque,
		PlutoComm.desired,
		PlutoComm.control,
		PlutoComm.control_bound,
		PlutoComm.control_dir,
		PlutoComm.target,
		log_player_x,
		log_player_y,
		log_target_x,
		log_target_y,
		log_game_state,
		log_aan_target,
		log_aan_init,
		log_aan_state,
	]
	_trial_raw_logger.log_data(row + "\n")

func log_raw_data(row: String) -> void:
	if _trial_raw_logger != null and _trial_raw_logger.still_logging:
		_trial_raw_logger.log_data(row + "\n")

func get_new_target_position() -> float:
	if selected_mechanism == null or selected_mechanism.curr_rom == null:
		return 0.0
	var prom      = selected_mechanism.current_prom
	var threshold = (prom[1] - prom[0]) * 0.2
	var target    = _HomerTherapy.get_new_target_position(prom[0], prom[1], _last_target, threshold)
	_last_target  = target
	return target
