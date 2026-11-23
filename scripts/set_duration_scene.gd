extends Control
## Set Duration: how many minutes each mechanism runs per session.
## There is no fixed cap. Optionally the clinician can switch on a total session limit; the
## per-mechanism minutes then have to fit inside it. Minutes can be typed or dragged.

const MECHS = ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]
const MECH_LABELS = {
	"WFE":  "Wrist Flex / Ext",
	"WURD": "Wrist Ulnar / Radial",
	"FPS":  "Forearm Pron / Sup",
	"HOC":  "Hand Open / Close",
	"FME1": "Functional Mech 1",
	"FME2": "Functional Mech 2",
}
const MECH_ICONS = {
	"WFE":  "res://Assets/mechanismImages/icons/wfe.png",
	"WURD": "res://Assets/mechanismImages/icons/wurd.png",
	"FPS":  "res://Assets/mechanismImages/icons/fps.png",
	"HOC":  "res://Assets/mechanismImages/icons/hoc.png",
}
const MECH_COLORS = {
	"WFE":  Color("3a7bd5"),
	"WURD": Color("e08a1e"),
	"FPS":  Color("d1495b"),
	"HOC":  Color("2f9e6d"),
	"FME1": Color("8450c8"),
	"FME2": Color("b08a12"),
}

const DEFAULT_MINUTES := 10
const DEFAULT_LIMIT := 60
const QUICK_LIMITS := [30, 45, 60, 90]
const SLIDER_MAX := 60
const ENTRY_MAX := 240

const INK := Color("1a2e44")
const MUTED := Color("4d6478")
const ACCENT := Color("087f83")
const WARN := Color("9a5a00")
const BAD := Color("c0273a")

var _limit_check: CheckButton
var _limit_spin: SpinBox
var _limit_chips: HBoxContainer
var _summary: Label
var _bar: Control
var _error: Label
var _confirm: Button
var _even_btn: Button

var _checks := {}
var _sliders := {}
var _spins := {}
var _cards := {}
var _updating := false

func _ready() -> void:
	_build()
	_load_from_appdata()
	_refresh()

# ── UI construction ─────────────────────────────────────────────────────────────

func _panel_style(fill: Color, border: Color, radius := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.1, 0.25, 0.3, 0.12)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

func _label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.set_meta("arcade_authored_control", true)
	return l

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# header
	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	titles.add_child(_label("Set Duration", 32))
	titles.add_child(_label("Choose how long each mechanism runs in a session.", 17, MUTED))
	var back := Button.new()
	back.text = "Back"
	back.icon = load("res://Assets/Arcade/Online/Icons/arrow-left.svg")
	back.custom_minimum_size = Vector2(130, 46)
	back.set_meta("secondary", true)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn"))
	header.add_child(back)
	var badge_gap := Control.new()          # keeps the button clear of the device badge
	badge_gap.custom_minimum_size = Vector2(70, 0)
	header.add_child(badge_gap)

	# total-time card
	var total_card := PanelContainer.new()
	total_card.add_theme_stylebox_override("panel", _panel_style(Color("fbfdfef2"), Color("c4dcdf")))
	total_card.set_meta("arcade_authored_control", true)
	root.add_child(total_card)
	var total_pad := MarginContainer.new()
	for side in ["margin_left", "margin_right"]: total_pad.add_theme_constant_override(side, 20)
	for side in ["margin_top", "margin_bottom"]: total_pad.add_theme_constant_override(side, 14)
	total_card.add_child(total_pad)
	var total_box := VBoxContainer.new()
	total_box.add_theme_constant_override("separation", 12)
	total_pad.add_child(total_box)

	var limit_row := HBoxContainer.new()
	limit_row.add_theme_constant_override("separation", 16)
	total_box.add_child(limit_row)
	_limit_check = CheckButton.new()
	_limit_check.text = "Limit total session time"
	_limit_check.add_theme_font_size_override("font_size", 20)
	_limit_check.toggled.connect(func(_on: bool): _refresh())
	limit_row.add_child(_limit_check)
	var hint := _label("Off: choose any time per mechanism.   On: the minutes below must fit inside the limit.", 15, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limit_row.add_child(hint)
	_summary = _label("", 24)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	limit_row.add_child(_summary)

	var limit_controls := HBoxContainer.new()
	limit_controls.add_theme_constant_override("separation", 12)
	total_box.add_child(limit_controls)
	_limit_chips = limit_controls
	limit_controls.add_child(_label("Session limit", 17, MUTED))
	_limit_spin = _make_spin(1, 600)
	_limit_spin.value_changed.connect(func(_v: float): _refresh())
	limit_controls.add_child(_limit_spin)
	for minutes in QUICK_LIMITS:
		var chip := Button.new()
		chip.text = "%d min" % minutes
		chip.custom_minimum_size = Vector2(86, 40)
		chip.set_meta("secondary", true)
		chip.pressed.connect(func(): _limit_spin.value = minutes)
		limit_controls.add_child(chip)
	_even_btn = Button.new()
	_even_btn.text = "Split evenly"
	_even_btn.custom_minimum_size = Vector2(140, 40)
	_even_btn.set_meta("secondary", true)
	_even_btn.pressed.connect(_split_evenly)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	limit_controls.add_child(spacer)
	limit_controls.add_child(_even_btn)

	# allocation bar
	_bar = Control.new()
	_bar.set_script(preload("res://scripts/ui/alloc_bar.gd"))
	_bar.custom_minimum_size = Vector2(0, 30)
	_bar.set_meta("arcade_authored_control", true)
	root.add_child(_bar)

	# mechanism cards, two columns so everything is visible without scrolling
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	for mech in MECHS:
		grid.add_child(_build_card(mech))

	# footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_error = _label("", 17, BAD)
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_error)
	_confirm = Button.new()
	_confirm.text = "Confirm & Save"
	_confirm.icon = load("res://Assets/Arcade/Online/Icons/check.svg")
	_confirm.custom_minimum_size = Vector2(240, 52)
	_confirm.pressed.connect(_on_confirm)
	footer.add_child(_confirm)

func _make_spin(min_value: int, max_value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.suffix = "min"
	spin.custom_minimum_size = Vector2(130, 44)
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spin.select_all_on_focus = true
	var edit := spin.get_line_edit()
	edit.add_theme_font_size_override("font_size", 20)
	edit.add_theme_color_override("font_color", INK)
	edit.add_theme_color_override("font_uneditable_color", MUTED)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size.y = 0
	var field := StyleBoxFlat.new()
	field.bg_color = Color.WHITE
	field.border_color = Color("9fc3c6")
	field.set_border_width_all(1)
	field.set_corner_radius_all(10)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	for state in ["normal", "read_only", "focus"]:
		edit.add_theme_stylebox_override(state, field)
	edit.set_meta("arcade_authored_control", true)
	spin.set_meta("arcade_authored_control", true)
	return spin

func _build_card(mech: String) -> Control:
	var has_rom: bool = DataManager.has_rom_data(mech) or mech == "FME1" or mech == "FME2"
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.set_meta("arcade_authored_control", true)
	_cards[mech] = card
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right"]: pad.add_theme_constant_override(side, 14)
	for side in ["margin_top", "margin_bottom"]: pad.add_theme_constant_override(side, 8)
	card.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(row)

	var stripe := ColorRect.new()
	stripe.color = MECH_COLORS[mech]
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.set_meta("arcade_authored_control", true)
	row.add_child(stripe)

	var check := CheckBox.new()
	check.custom_minimum_size = Vector2(34, 34)
	check.set_meta("arcade_authored_control", true)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	check.disabled = not has_rom
	check.toggled.connect(func(on: bool): _on_mech_toggled(mech, on))
	row.add_child(check)
	_checks[mech] = check

	var icon_path: String = MECH_ICONS.get(mech, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(46, 46)
		icon.set_meta("full_color", true)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var names := VBoxContainer.new()
	names.custom_minimum_size = Vector2(150, 0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	names.add_child(_label(MECH_LABELS[mech], 19, INK if has_rom else MUTED))
	if not has_rom:
		names.add_child(_label("Assess first", 14, MUTED))

	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = SLIDER_MAX
	slider.step = 1
	slider.value = DEFAULT_MINUTES
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 28)
	slider.value_changed.connect(func(v: float): _on_slider(mech, v))
	row.add_child(slider)
	_sliders[mech] = slider

	var spin := _make_spin(1, ENTRY_MAX)
	spin.value = DEFAULT_MINUTES
	spin.value_changed.connect(func(v: float): _on_spin(mech, v))
	row.add_child(spin)
	_spins[mech] = spin
	return card

# ── State ───────────────────────────────────────────────────────────────────────

func _saved_minutes() -> Dictionary:
	return {
		"WFE": AppData.config_wfe, "WURD": AppData.config_wurd, "FPS": AppData.config_fps,
		"HOC": AppData.config_hoc, "FME1": AppData.config_fme1, "FME2": AppData.config_fme2,
	}

func _load_from_appdata() -> void:
	_updating = true
	var saved := _saved_minutes()
	for mech in MECHS:
		var minutes := int(saved.get(mech, 0))
		var check: CheckBox = _checks[mech]
		var on := minutes > 0 and not check.disabled
		check.button_pressed = on
		var shown := minutes if minutes > 0 else DEFAULT_MINUTES
		_sliders[mech].value = shown
		_spins[mech].value = shown
	_limit_check.button_pressed = AppData.config_limit_total
	_limit_spin.value = AppData.config_total_time if AppData.config_limit_total and AppData.config_total_time > 0 else DEFAULT_LIMIT
	_updating = false

func _selected() -> Array:
	var chosen := []
	for mech in MECHS:
		if (_checks[mech] as CheckBox).button_pressed: chosen.append(mech)
	return chosen

func _minutes(mech: String) -> int:
	return int((_spins[mech] as SpinBox).value)

func _total() -> int:
	var total := 0
	for mech in _selected(): total += _minutes(mech)
	return total

func _limit() -> int:
	return int(_limit_spin.value) if _limit_check.button_pressed else 0

func _on_mech_toggled(_mech: String, _on: bool) -> void:
	_refresh()

func _on_slider(mech: String, value: float) -> void:
	if _updating: return
	_updating = true
	(_spins[mech] as SpinBox).value = value
	_updating = false
	_refresh()

func _on_spin(mech: String, value: float) -> void:
	if _updating: return
	_updating = true
	(_sliders[mech] as HSlider).value = minf(value, SLIDER_MAX)
	_updating = false
	_refresh()

func _split_evenly() -> void:
	var chosen := _selected()
	if chosen.is_empty() or _limit() <= 0: return
	var each := maxi(1, _limit() / chosen.size())
	_updating = true
	for mech in chosen:
		(_spins[mech] as SpinBox).value = each
		(_sliders[mech] as HSlider).value = minf(each, SLIDER_MAX)
	_updating = false
	_refresh()

func _validation() -> String:
	var chosen := _selected()
	if chosen.is_empty(): return "Select at least one mechanism."
	var limit := _limit()
	if limit > 0 and _total() > limit:
		return "%d min is over the %d min session limit." % [_total(), limit]
	return ""

func _refresh() -> void:
	if _bar == null: return
	var limit := _limit()
	var total := _total()
	_limit_chips.visible = _limit_check.button_pressed
	_even_btn.visible = _limit_check.button_pressed

	var segments := []
	for mech in MECHS:
		var on: bool = (_checks[mech] as CheckBox).button_pressed
		(_sliders[mech] as HSlider).editable = on
		(_spins[mech] as SpinBox).editable = on
		(_cards[mech] as PanelContainer).add_theme_stylebox_override("panel",
			_panel_style(Color("e3f5f1f2") if on else Color("f5f9fbd8"), ACCENT if on else Color("c4d4da"), 14))
		if on: segments.append({"minutes": _minutes(mech), "color": MECH_COLORS[mech]})

	var over := limit > 0 and total > limit
	_bar.set_data(segments, float(limit), over)
	if limit > 0:
		var left := limit - total
		if over:
			_summary.text = "%d / %d min  ·  %d over" % [total, limit, -left]
			_summary.add_theme_color_override("font_color", BAD)
		elif left == 0:
			_summary.text = "%d / %d min  ✓" % [total, limit]
			_summary.add_theme_color_override("font_color", ACCENT)
		else:
			_summary.text = "%d / %d min  ·  %d left" % [total, limit, left]
			_summary.add_theme_color_override("font_color", INK)
	else:
		_summary.text = "Total  %d min" % total
		_summary.add_theme_color_override("font_color", INK)

	var message := _validation()
	_error.text = message
	_confirm.disabled = message != ""

# ── Save ────────────────────────────────────────────────────────────────────────

func _on_confirm() -> void:
	if _validation() != "": return
	var chosen := _selected()
	var total := _total()
	AppData.config_limit_total = _limit_check.button_pressed
	AppData.config_total_time = _limit() if _limit() > 0 else total
	AppData.config_wfe  = _minutes("WFE")  if chosen.has("WFE")  else 0
	AppData.config_wurd = _minutes("WURD") if chosen.has("WURD") else 0
	AppData.config_fps  = _minutes("FPS")  if chosen.has("FPS")  else 0
	AppData.config_hoc  = _minutes("HOC")  if chosen.has("HOC")  else 0
	AppData.config_fme1 = _minutes("FME1") if chosen.has("FME1") else 0
	AppData.config_fme2 = _minutes("FME2") if chosen.has("FME2") else 0
	if AppData.config_fme1 == 0: AppData.config_fme1_id = -1
	if AppData.config_fme2 == 0: AppData.config_fme2_id = -1
	DataManager.save_config()
	get_tree().change_scene_to_file("res://scenes/PlanSetupScene.tscn")
