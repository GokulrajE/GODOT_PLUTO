extends Control

const MECHS = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]

const MECH_LABELS = {
	"WFE":  "Wrist Flex / Ext",
	"WURD": "Wrist Ulnar / Radial",
	"FPS":  "Forearm Pron / Sup",
	"HOC":  "Hand Open / Close",
	"FME1": "Functional Mech 1",
	"FME2": "Functional Mech 2",
}

const MIN_DURATION = 10
const MAX_PER_MECH = 40
const TOTAL_TIME   = 60
const MIN_MECHS    = 3

# ── Colors — light green clinical theme (matches AssessmentScene) ───────
const CLR_ROW_OFF     = Color(1.000, 1.000, 1.000)
const CLR_ROW_ON      = Color(0.824, 0.929, 0.839)
const CLR_ROW_BORDER  = Color(0.749, 0.878, 0.761)
const CLR_ROW_ON_BDR  = Color(0.153, 0.714, 0.376)
const CLR_DIM         = Color(0.353, 0.510, 0.369)
const CLR_NORMAL      = Color(0.082, 0.157, 0.094)
const CLR_ACCENT      = Color(0.059, 0.502, 0.259)
const CLR_WARN        = Color(0.600, 0.400, 0.050)

@onready var _total_label: Label  = $Root/SummaryPad/SummaryVBox/TotalLabel
@onready var _error_label: Label  = $Root/SummaryPad/SummaryVBox/ErrorLabel
@onready var _confirm_btn: Button = $Root/SummaryPad/SummaryVBox/BtnRow/ConfirmButton

var _checkboxes:     Dictionary = {}
var _sliders:        Dictionary = {}
var _value_labels:   Dictionary = {}
var _row_panels:     Dictionary = {}
var _seg_fills:      Array      = []
var _selected_mechs: Array      = []
var _is_updating:    bool       = false

func _ready() -> void:
	_collect_refs()
	$Root/Header/BtnPad/BackButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
	)
	_confirm_btn.pressed.connect(_on_confirm)
	_load_from_appdata()

func _collect_refs() -> void:
	var track := $Root/AllocBar/AllocVBox/AllocTrack
	var seg_names := ["WFESeg", "WURDSeg", "FPSSeg", "HOCSeg", "FME1Seg", "FME2Seg"]
	_seg_fills.clear()
	for n in seg_names:
		_seg_fills.append(track.get_node(n) as ColorRect)

	var rows_vb := $Root/Scroll/RowPad/RowsVBox
	for mech in MECHS:
		var row := rows_vb.get_node(mech + "Row") as Panel
		_row_panels[mech] = row
		var hbox := row.get_node("RowHBox")
		_checkboxes[mech]   = hbox.get_node("Check") as CheckBox
		_sliders[mech]      = hbox.get_node("Slider") as HSlider
		_value_labels[mech] = hbox.get_node("ValueLabel") as Label

		var has_rom: bool = DataManager.has_rom_data(mech) or mech == "FME1" or mech == "FME2"
		_checkboxes[mech].disabled = not has_rom
		hbox.get_node("NameLabel").add_theme_color_override("font_color",
			CLR_NORMAL if has_rom else CLR_DIM)

		_checkboxes[mech].toggled.connect(func(pressed: bool): _on_mech_toggled(mech, pressed))
		_sliders[mech].value_changed.connect(func(_v: float): _update_ui())

# ── Logic ──────────────────────────────────────────────────────────────

func _load_from_appdata() -> void:
	var saved = {
		"WFE":  AppData.config_wfe,
		"WURD": AppData.config_wurd,
		"FPS":  AppData.config_fps,
		"HOC":  AppData.config_hoc,
		"FME1": AppData.config_fme1,
		"FME2": AppData.config_fme2,
	}

	_selected_mechs.clear()

	for mech in MECHS:
		var val  = saved.get(mech, 0)
		var cb: CheckBox = _checkboxes[mech]
		var sl: HSlider  = _sliders[mech]

		if val > 0 and not cb.disabled:
			_selected_mechs.append(mech)
			cb.set_block_signals(true)
			cb.button_pressed = true
			cb.set_block_signals(false)
			sl.min_value = MIN_DURATION
			sl.max_value = MAX_PER_MECH
			sl.editable  = true
			sl.value     = max(val, MIN_DURATION)
		else:
			cb.set_block_signals(true)
			cb.button_pressed = false
			cb.set_block_signals(false)
			sl.min_value = 0
			sl.max_value = 0
			sl.editable  = false
			sl.value     = 0

	_update_ui()

func _on_mech_toggled(mech: String, is_on: bool) -> void:
	if is_on:
		if _selected_mechs.size() >= MIN_MECHS and not _selected_mechs.has(mech):
			var cb: CheckBox = _checkboxes[mech]
			cb.set_block_signals(true)
			cb.button_pressed = false
			cb.set_block_signals(false)
			return

		if not _selected_mechs.has(mech):
			_selected_mechs.append(mech)
		var sl: HSlider = _sliders[mech]
		sl.editable  = true
		sl.min_value = MIN_DURATION
		sl.max_value = MAX_PER_MECH
		if sl.value < MIN_DURATION:
			sl.value = MIN_DURATION
	else:
		_selected_mechs.erase(mech)
		var sl: HSlider = _sliders[mech]
		sl.editable  = false
		sl.min_value = 0
		sl.max_value = 0
		sl.value     = 0

	_update_ui()

func _update_ui() -> void:
	if _is_updating:
		return
	_is_updating = true

	var total := 0
	for mech in MECHS:
		var val  := int(_sliders[mech].value)
		var is_on := _selected_mechs.has(mech)
		if is_on:
			total += val
			_value_labels[mech].text = "%d min" % val
			_value_labels[mech].add_theme_color_override("font_color", CLR_NORMAL)
		else:
			_value_labels[mech].text = "— min"
			_value_labels[mech].add_theme_color_override("font_color", CLR_DIM)

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.content_margin_left   = 12
		sb.content_margin_right  = 12
		sb.content_margin_top    = 0
		sb.content_margin_bottom = 0
		if is_on:
			sb.bg_color     = CLR_ROW_ON
			sb.border_color = CLR_ROW_ON_BDR
		else:
			sb.bg_color     = CLR_ROW_OFF
			sb.border_color = CLR_ROW_BORDER
		_row_panels[mech].add_theme_stylebox_override("panel", sb)

	var remaining := TOTAL_TIME - total
	if total == TOTAL_TIME:
		_total_label.text = "Total: %d / %d min  ✓" % [total, TOTAL_TIME]
		_total_label.add_theme_color_override("font_color", CLR_ACCENT)
	elif total < TOTAL_TIME:
		_total_label.text = "Total: %d / %d min  (%d min remaining)" % [total, TOTAL_TIME, remaining]
		_total_label.add_theme_color_override("font_color", CLR_WARN)
	else:
		_total_label.text = "Total: %d / %d min  (%d min over)" % [total, TOTAL_TIME, -remaining]
		_total_label.add_theme_color_override("font_color", Color(0.78, 0.129, 0.129))

	_update_alloc_bar(total)

	var valid := _validate(total)
	_confirm_btn.disabled = not valid

	_is_updating = false

func _update_alloc_bar(total: int) -> void:
	if _seg_fills.is_empty():
		return
	call_deferred("_apply_alloc_bar_positions", total)

func _apply_alloc_bar_positions(_total: int) -> void:
	if _seg_fills.is_empty():
		return
	var track: Control = _seg_fills[0].get_parent()
	var tw: float = track.size.x
	if tw <= 0.0:
		return
	var offset_x: float = 0.0
	for i in range(MECHS.size()):
		var seg: ColorRect = _seg_fills[i]
		var mech: String   = MECHS[i]
		var val: int       = int(_sliders[mech].value) if _selected_mechs.has(mech) else 0
		if val <= 0:
			seg.visible = false
			continue
		var w: float = (float(val) / float(TOTAL_TIME)) * tw
		seg.position = Vector2(offset_x, 0)
		seg.size     = Vector2(w, track.size.y)
		seg.visible  = true
		offset_x    += w

func _validate(total: int) -> bool:
	if _selected_mechs.size() < MIN_MECHS:
		_set_error("Select exactly %d mechanisms. Currently: %d" % [MIN_MECHS, _selected_mechs.size()])
		return false

	for mech in _selected_mechs:
		var val := int(_sliders[mech].value)
		if val <= 0:
			_set_error("%s must have time > 0 min." % mech)
			return false
		if val > MAX_PER_MECH:
			_set_error("%s maximum is %d min." % [mech, MAX_PER_MECH])
			return false

	if total != TOTAL_TIME:
		_set_error("Total must be exactly %d min. Currently: %d min." % [TOTAL_TIME, total])
		return false

	_set_error("")
	return true

func _set_error(msg: String) -> void:
	_error_label.text = msg

func _on_confirm() -> void:
	var total := 0
	for mech in _selected_mechs:
		total += int(_sliders[mech].value)

	if not _validate(total):
		return

	AppData.config_total_time = TOTAL_TIME
	AppData.config_wfe  = int(_sliders["WFE"].value)  if _selected_mechs.has("WFE")  else 0
	AppData.config_wurd = int(_sliders["WURD"].value) if _selected_mechs.has("WURD") else 0
	AppData.config_fps  = int(_sliders["FPS"].value)  if _selected_mechs.has("FPS")  else 0
	AppData.config_hoc  = int(_sliders["HOC"].value)  if _selected_mechs.has("HOC")  else 0
	AppData.config_fme1 = int(_sliders["FME1"].value) if _selected_mechs.has("FME1") else 0
	AppData.config_fme2 = int(_sliders["FME2"].value) if _selected_mechs.has("FME2") else 0

	if AppData.config_fme1 == 0:
		AppData.config_fme1_id = -1
	if AppData.config_fme2 == 0:
		AppData.config_fme2_id = -1

	DataManager.save_config()
	get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
