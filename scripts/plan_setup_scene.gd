extends Control

const MECHS = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]

const KNOB_IMAGES = [
	"res://Assets/Knobs_PNG/1._Ball_Knob_Big-removebg-preview.png",
	"res://Assets/Knobs_PNG/2._Wing_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/3._Long_Handle-removebg-preview.png",
	"res://Assets/Knobs_PNG/4.1_T_knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/6._Crank_Handle-removebg-preview.png",
	"res://Assets/Knobs_PNG/7._Four_Pointed_Star-removebg-preview.png",
	"res://Assets/Knobs_PNG/8._Rotor_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/9._Small_Knob_-_Big-removebg-preview.png",
	"res://Assets/Knobs_PNG/10._Three_Pointed_Knob-removebg-preview.png",
	"res://Assets/Knobs_PNG/11._Finger_Wheel-removebg-preview.png",
	"res://Assets/Knobs_PNG/12._Poteniometer_Knob-removebg-preview.png",
	"res://Assets/mechanismImages/KNOB.png",
	"res://Assets/mechanismImages/keyknob_outline.png",
]

# ── Colors — light green clinical theme (matches AssessmentScene) ──────
const CLR_CARD_DEFAULT = Color(1.000, 1.000, 1.000)
const CLR_CARD_ASSESSED= Color(0.918, 0.949, 0.922)
const CLR_CARD_READY   = Color(0.824, 0.929, 0.839)
const CLR_ACCENT_OFF   = Color(0.820, 0.850, 0.825)
const CLR_ACCENT_ASSESS= Color(0.153, 0.714, 0.376)
const CLR_ACCENT_READY = Color(0.059, 0.502, 0.259)
const CLR_BORDER_OFF   = Color(0.749, 0.878, 0.761)
const CLR_BORDER_ASSESS= Color(0.153, 0.714, 0.376)
const CLR_BORDER_READY = Color(0.059, 0.502, 0.259)
const CLR_TEXT_DIM     = Color(0.353, 0.510, 0.369)
const CLR_TEXT_NORMAL  = Color(0.082, 0.157, 0.094)
const CLR_BADGE_NONE   = Color(0.820, 0.850, 0.830)
const CLR_BADGE_TIME   = Color(0.153, 0.714, 0.376)
const CLR_BADGE_READY  = Color(0.059, 0.502, 0.259)

@onready var _done_button:        Button        = $Root/Header/BtnPad/DoneButton
@onready var _error_label:        Label         = $Root/Header/ErrorLabel
@onready var _ready_count_label:  Label         = $Root/Header/TitlePad/TitleVBox/ReadyCountLabel
@onready var _knob_popup:         Control       = $KnobPopup
@onready var _popup_title:        Label         = $KnobPopup/PopupPanel/PopupVBox/TitlePad/PopupTitle
@onready var _knob_grid:          GridContainer = $KnobPopup/PopupPanel/PopupVBox/KnobScroll/KnobGrid

var _card_panels:   Dictionary = {}
var _duration_labels: Dictionary = {}
var _status_badges: Dictionary = {}
var _knob_btns:     Dictionary = {}
var _knob_previews: Dictionary = {}
var _popup_buttons: Array      = []
var _selecting_fme: String     = ""

func _ready() -> void:
	AppData.is_plan_setup = true
	_collect_card_refs()
	_build_knob_buttons()
	_done_button.pressed.connect(_on_done_pressed)
	$Root/BottomBar/BottomPad/BottomHBox/SetDurationButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/SetDurationScene.tscn")
	)
	$KnobPopup/PopupPanel/PopupVBox/ClosePad/CloseButton.pressed.connect(func():
		_knob_popup.visible = false
	)
	_refresh_cards()

func _collect_card_refs() -> void:
	var grid := $Root/Scroll/CardPad/MechGrid as GridContainer
	for mech in MECHS:
		var card := grid.get_node(mech + "Card") as Panel
		_card_panels[mech] = card
		var inner := card.get_node("VBox/Content/InnerVBox")
		_status_badges[mech]   = inner.get_node("BadgeRow/DurationBadge") as Panel
		_duration_labels[mech] = inner.get_node("BadgeRow/DurationBadge/DurationLabel") as Label
		var calib_btn := inner.get_node("CalibrateButton") as Button
		if mech == "FME1" or mech == "FME2":
			calib_btn.visible = false
			_knob_btns[mech]    = inner.get_node("KnobButton") as Button
			_knob_previews[mech]= inner.get_node("KnobPreview") as TextureRect
			_knob_btns[mech].pressed.connect(func(): _open_knob_popup(mech))
			var mech_img := inner.get_node_or_null("MechImage") as TextureRect
			if mech_img:
				mech_img.visible = false
		else:
			calib_btn.pressed.connect(func(): _go_calibrate(mech))

func _build_knob_buttons() -> void:
	for i in range(KNOB_IMAGES.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		var idx := i
		btn.pressed.connect(func(): _select_knob(idx))

		var sb_normal := StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.96, 0.99, 0.97, 1.0)
		sb_normal.set_border_width_all(1)
		sb_normal.border_color = Color(0.75, 0.88, 0.77, 1.0)
		sb_normal.set_corner_radius_all(8)
		sb_normal.content_margin_left  = 6; sb_normal.content_margin_right  = 6
		sb_normal.content_margin_top   = 6; sb_normal.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", sb_normal)

		var sb_hover := StyleBoxFlat.new()
		sb_hover.bg_color = Color(0.85, 0.97, 0.87, 1.0)
		sb_hover.set_border_width_all(2)
		sb_hover.border_color = Color(0.153, 0.714, 0.376, 1.0)
		sb_hover.set_corner_radius_all(8)
		sb_hover.content_margin_left  = 6; sb_hover.content_margin_right  = 6
		sb_hover.content_margin_top   = 6; sb_hover.content_margin_bottom = 6
		btn.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed := StyleBoxFlat.new()
		sb_pressed.bg_color = Color(0.75, 0.95, 0.78, 1.0)
		sb_pressed.set_border_width_all(2)
		sb_pressed.border_color = Color(0.059, 0.502, 0.259, 1.0)
		sb_pressed.set_corner_radius_all(8)
		sb_pressed.content_margin_left  = 6; sb_pressed.content_margin_right  = 6
		sb_pressed.content_margin_top   = 6; sb_pressed.content_margin_bottom = 6
		btn.add_theme_stylebox_override("pressed", sb_pressed)

		if ResourceLoader.exists(KNOB_IMAGES[i]):
			var knob_img := TextureRect.new()
			knob_img.texture      = load(KNOB_IMAGES[i])
			knob_img.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			knob_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			knob_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			knob_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn.add_child(knob_img)
		var num_lbl := Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.add_theme_font_size_override("font_size", 10)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		num_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		num_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(num_lbl)
		_popup_buttons.append(btn)
		_knob_grid.add_child(btn)

# ── Logic ──────────────────────────────────────────────────────────────

func _refresh_cards() -> void:
	var cfg = _config_dict()
	var ready_count := 0

	for mech in MECHS:
		var has_rom  = _has_rom(mech)
		var time_val = cfg.get(mech, 0)
		var is_ready = has_rom and time_val > 0

		if is_ready:
			ready_count += 1

		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left   = 0
		sb.content_margin_top    = 0
		sb.content_margin_right  = 0
		sb.content_margin_bottom = 0
		sb.set_border_width_all(1)

		if is_ready:
			sb.bg_color     = CLR_CARD_READY
			sb.border_color = CLR_BORDER_READY
		elif has_rom:
			sb.bg_color     = CLR_CARD_ASSESSED
			sb.border_color = CLR_BORDER_ASSESS
		else:
			sb.bg_color     = CLR_CARD_DEFAULT
			sb.border_color = CLR_BORDER_OFF

		_card_panels[mech].add_theme_stylebox_override("panel", sb)

		var stripe: ColorRect = _card_panels[mech].get_node("VBox/Stripe")
		if stripe:
			if is_ready:
				stripe.color = CLR_ACCENT_READY
			elif has_rom:
				stripe.color = CLR_ACCENT_ASSESS
			else:
				stripe.color = CLR_ACCENT_OFF

		var badge: Panel = _status_badges[mech]
		var badge_sb = StyleBoxFlat.new()
		badge_sb.set_corner_radius_all(12)
		badge_sb.content_margin_left  = 8
		badge_sb.content_margin_right = 8

		var dur_lbl: Label = _duration_labels[mech]
		if time_val > 0 and is_ready:
			badge_sb.bg_color = CLR_BADGE_READY
			dur_lbl.text = "✓  %d min" % time_val
			dur_lbl.add_theme_color_override("font_color", Color.WHITE)
		elif time_val > 0:
			badge_sb.bg_color = CLR_BADGE_TIME
			dur_lbl.text = "%d min" % time_val
			dur_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			badge_sb.bg_color = CLR_BADGE_NONE
			dur_lbl.text = "Not prescribed"
			dur_lbl.add_theme_color_override("font_color", CLR_TEXT_DIM)

		badge.add_theme_stylebox_override("panel", badge_sb)

		if mech == "FME1" or mech == "FME2":
			var show_knob = (time_val > 0)
			_knob_btns[mech].visible = show_knob
			var sel_id = AppData.config_fme1_id if mech == "FME1" else AppData.config_fme2_id
			if show_knob and sel_id >= 0 and sel_id < KNOB_IMAGES.size():
				_knob_previews[mech].visible = true
				if ResourceLoader.exists(KNOB_IMAGES[sel_id]):
					_knob_previews[mech].texture = load(KNOB_IMAGES[sel_id])
				_knob_btns[mech].text = "Change Knob"
			else:
				_knob_previews[mech].visible = false
				_knob_btns[mech].text = "Select Knob"

	_ready_count_label.text = "Patient: %s  ·  %d / %d mechanisms ready" % [
		AppData.patient_id, ready_count, MECHS.size()
	]
	_ready_count_label.add_theme_color_override("font_color", CLR_TEXT_DIM)

	_update_done_button()

func _has_rom(mech: String) -> bool:
	if mech == "FME1" or mech == "FME2":
		return true
	return DataManager.has_rom_data(mech)

func _config_dict() -> Dictionary:
	return {
		"WFE":  AppData.config_wfe,
		"WURD": AppData.config_wurd,
		"FPS":  AppData.config_fps,
		"HOC":  AppData.config_hoc,
		"FME1": AppData.config_fme1,
		"FME2": AppData.config_fme2,
	}

func _update_done_button() -> void:
	var total   = AppData.config_wfe + AppData.config_wurd + AppData.config_fps \
	            + AppData.config_hoc + AppData.config_fme1 + AppData.config_fme2
	var fme1_ok = AppData.config_fme1 == 0 or AppData.config_fme1_id >= 0
	var fme2_ok = AppData.config_fme2 == 0 or AppData.config_fme2_id >= 0
	var fme_diff = (AppData.config_fme1_id < 0 or AppData.config_fme2_id < 0) \
	             or (AppData.config_fme1_id != AppData.config_fme2_id)

	var valid = (total == 60 and fme1_ok and fme2_ok and fme_diff)
	_done_button.disabled = not valid

	if total == 0:
		_error_label.text = "Assess each mechanism first, then set the duration."
	elif total != 60:
		_error_label.text = "Total duration must be 60 min (currently %d min)." % total
	elif not fme1_ok:
		_error_label.text = "FME1 has time allocated — select a knob."
	elif not fme2_ok:
		_error_label.text = "FME2 has time allocated — select a knob."
	elif not fme_diff:
		_error_label.text = "FME1 and FME2 must use different knobs."
	else:
		_error_label.text = ""

func _go_calibrate(mech: String) -> void:
	var mech_idx = AppData.MECHANISMS.find(mech)
	if mech_idx < 0:
		return
	AppData.set_mechanism(mech_idx)
	get_tree().change_scene_to_file("res://scenes/CalibrationScene.tscn")

func _open_knob_popup(fme: String) -> void:
	_selecting_fme = fme
	_popup_title.text = "Select Knob for " + fme
	_update_popup_buttons()
	_knob_popup.visible = true

func _update_popup_buttons() -> void:
	var other_id = AppData.config_fme2_id if _selecting_fme == "FME1" else AppData.config_fme1_id
	var this_id  = AppData.config_fme1_id if _selecting_fme == "FME1" else AppData.config_fme2_id
	for i in range(_popup_buttons.size()):
		var btn: Button = _popup_buttons[i]
		btn.disabled = (i == other_id)
		btn.modulate = Color(0.6, 0.6, 0.6, 1.0) if btn.disabled else Color.WHITE
		if i == this_id:
			var sb_sel := StyleBoxFlat.new()
			sb_sel.bg_color = Color(0.059, 0.502, 0.259, 1.0)
			sb_sel.set_border_width_all(2)
			sb_sel.border_color = Color(0.039, 0.329, 0.169, 1.0)
			sb_sel.set_corner_radius_all(8)
			sb_sel.content_margin_left  = 6; sb_sel.content_margin_right  = 6
			sb_sel.content_margin_top   = 6; sb_sel.content_margin_bottom = 6
			btn.add_theme_stylebox_override("normal", sb_sel)
		else:
			var sb_normal := StyleBoxFlat.new()
			sb_normal.bg_color = Color(0.96, 0.99, 0.97, 1.0)
			sb_normal.set_border_width_all(1)
			sb_normal.border_color = Color(0.75, 0.88, 0.77, 1.0)
			sb_normal.set_corner_radius_all(8)
			sb_normal.content_margin_left  = 6; sb_normal.content_margin_right  = 6
			sb_normal.content_margin_top   = 6; sb_normal.content_margin_bottom = 6
			btn.add_theme_stylebox_override("normal", sb_normal)

func _select_knob(index: int) -> void:
	if _selecting_fme == "FME1":
		AppData.config_fme1_id = index
	elif _selecting_fme == "FME2":
		AppData.config_fme2_id = index
	DataManager.save_config()
	_knob_popup.visible = false
	_refresh_cards()

func _on_done_pressed() -> void:
	AppData.is_plan_setup = false
	get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")
