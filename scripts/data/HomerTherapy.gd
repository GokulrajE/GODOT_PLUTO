class_name HomerTherapy
extends RefCounted

const SUCCESS_RATE_THRESHOLD: float = 0.9
const TRIAL_DURATION:         float = 60.0
const MAX_SPEED:              float = 40.0
const MIN_SPEED:              float = 10.0

const GAME_SPEED_INCREMENTS: Dictionary = {
	"PING-PONG": 0.5,
	"TUK-TUK":   0.2,
	"HAT-TRICK": 1.0,
	"FRUITCH":   1.0,
	"RNR":       1.0,
}
static var max_duration_of_mech_fps_and_fme: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[3], MIN_SPEED)

static var min_duration_of_mech_fps_and_fme: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[3], MAX_SPEED)

static var max_duration_of_mech_wfe_and_wurd: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[1], MIN_SPEED)

static var min_duration_of_mech_wfe_and_wurd: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[1], MAX_SPEED)

static var max_duration_of_mech_hoc: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[4], MIN_SPEED)

static var min_duration_of_mech_hoc: float:
	get:
		return calculate_mech_duration(AppData.CALIB_ANGLE[4], MAX_SPEED)


static func calculate_mech_duration(max_angle: float, speed: float) -> float:
	return max_angle / speed
	
enum TrialType { SR85PCTRAIN, SR85PCCATCH, TRAIN }

const SUCCESS_RATE_FOR_TRIALS: Array = [
	85, 85, 85, 85, 85,
	90, 90, 90, 87, 84,
	79, 79, 79, 79, 79,
	81, 83, 85, 90, 90,
]

const TRIAL_TYPE_FOR_TRIALS: Array = [
	TrialType.SR85PCTRAIN, TrialType.SR85PCTRAIN, TrialType.SR85PCTRAIN, TrialType.SR85PCTRAIN, TrialType.SR85PCCATCH,
	TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN,
	TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN,
	TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN, TrialType.TRAIN,
]

static func get_trial_type_and_success_rate(trial_no: int) -> Dictionary:
	var idx   = (trial_no - 1) % 20
	var srate = float(SUCCESS_RATE_FOR_TRIALS[idx])
	var ttype: int = TRIAL_TYPE_FOR_TRIALS[idx]
	if ttype == TrialType.TRAIN:
		srate += float(randi_range(-4, 4))
	return { "success_rate": srate, "trial_type": ttype }

static func get_new_target_position(prom_min: float, prom_max: float, last_target: float, threshold: float) -> float:
	var target := 0.0
	var attempts := 0
	while attempts < 20:
		target = randf_range(prom_min, prom_max)
		if last_target == INF or abs(last_target - target) >= threshold:
			break
		attempts += 1
	return target
