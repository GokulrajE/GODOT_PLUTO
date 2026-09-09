extends Node

# ── Mechanism constants (from Unity PlutoComm.cs) ──────────────────
const MECHANISMS      = ["NOMECH", "WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]
const CALIB_ANGLE     = [0,        136,   136,    180,   93,    180,    180   ]
const MECH_OFFSET     = [0.0,      68.0,  68.0,   90.0,  0.0,   90.0,   90.0  ]
const HOC_SCALE       = 0.10752  # converts HOC angle to cm

# ── Selected mechanism ──────────────────────────────────────────────
var mechanism_index: int    = 0       # index into MECHANISMS array
var mechanism_name: String  = "NOMECH"
var calib_angle: int        = 0       # expected full ROM angle for this mechanism
var mech_offset: float      = 0.0     # offset for this mechanism

# ── Calibration result ──────────────────────────────────────────────
var is_calibrated: bool = false

# ── ROM Assessment results ──────────────────────────────────────────
var arom_min: float = -30.0    # patient's active ROM minimum (degrees)
var arom_max: float =  30.0    # patient's active ROM maximum (degrees)
var prom_min: float = -45.0    # passive ROM minimum (degrees)
var prom_max: float =  45.0    # passive ROM maximum (degrees)
var is_rom_assessed: bool = false

# ── Assist profile ──────────────────────────────────────────────────
var assist_bound: float = 0.5   # 0.0 = no assist, 1.0 = full assist
var assist_dir: int     = 0     # -1, 0, or 1
var is_assist_set: bool = false
var aprom_min: float = 0.0
var aprom_max: float = 0.0
# ── HOC helper ──────────────────────────────────────────────────────
func hoc_to_cm(angle: float) -> float:
	return HOC_SCALE * abs(angle)

func cm_to_hoc(cm: float) -> float:
	return -cm / HOC_SCALE

# ── Called from ChooseMechanism scene ───────────────────────────────
func set_mechanism(index: int) -> void:
	mechanism_index = index
	mechanism_name  = MECHANISMS[index]
	calib_angle     = CALIB_ANGLE[index]
	mech_offset     = MECH_OFFSET[index]
	is_calibrated   = false
	is_rom_assessed = false
	is_assist_set   = false
	print("GameData: mechanism set to ", mechanism_name)
