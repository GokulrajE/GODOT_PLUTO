extends Control
## Bottom-right HUD card: circular session progress ring.
## Shows daily session time vs prescribed goal.
const Palette = preload("res://scripts/ui/ui_palette.gd")

const SZ := Vector2(90, 90)
const RC := Vector2(45, 45)
const RR := 34.0
const RW := 6.0

var _progress := 0.0
var _time_lbl: Label
var _done_lbl: Label

func _ready() -> void:
	set_meta("arcade_authored_control", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SZ
	size = SZ

	_time_lbl = Label.new()
	_time_lbl.set_meta("arcade_authored_control", true)
	_time_lbl.name = "TrialTime"
	_time_lbl.add_theme_font_override("font", Palette.DISPLAY)
	_time_lbl.add_theme_font_size_override("font_size", 17)
	_time_lbl.add_theme_color_override("font_color", Color("e8f4fc"))
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_time_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_time_lbl.position = Vector2(RC.x - 24, RC.y - 16)
	_time_lbl.size = Vector2(48, 20)
	_time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_time_lbl)

	_done_lbl = Label.new()
	_done_lbl.set_meta("arcade_authored_control", true)
	_done_lbl.name = "TrialDone"
	_done_lbl.add_theme_font_size_override("font_size", 9)
	_done_lbl.add_theme_color_override("font_color", Color("a6ee32"))
	_done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_done_lbl.position = Vector2(RC.x - 22, RC.y + 7)
	_done_lbl.size = Vector2(44, 13)
	_done_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_done_lbl)

func _process(_delta: float) -> void:
	var daily := AppData.daily_progress()
	var goal  := float(daily.get("goal", 0))
	var secs  := float(daily.get("seconds", 0))
	_progress = clampf(secs / maxf(goal * 60.0, 1.0), 0.0, 1.0) if goal > 0 else 0.0
	var mins := int(secs / 60.0)
	_time_lbl.text = "%dm" % mins
	_done_lbl.text = "done"
	queue_redraw()

func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.11, 0.18, 0.84)
	bg.set_corner_radius_all(16)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.08)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	draw_circle(RC, RR - RW - 1.5, Color(0.05, 0.08, 0.14, 0.72))
	draw_arc(RC, RR, -PI * 0.5, PI * 1.5, 72, Color(1, 1, 1, 0.12), RW, true)

	if _progress > 0.004:
		var col := Color("7c3aed").lerp(Color("a6ee32"), _progress)
		draw_arc(RC, RR, -PI * 0.5, -PI * 0.5 + _progress * TAU, 80, col, RW + 1.5, true)

	if _progress > 0.01 and _progress < 0.995:
		var tip_a := -PI * 0.5 + _progress * TAU
		draw_circle(RC + Vector2(cos(tip_a), sin(tip_a)) * RR, 4.0, Color("a6ee32"))
