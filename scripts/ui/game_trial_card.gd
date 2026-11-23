extends Control
## Bottom-right HUD card: how much of TODAY's prescribed practice for this mechanism is done.
## Deliberately unlike the round countdown timer (top left): a wide gold pill with a flag, the label
## "TODAY", minutes done / goal, and a flat progress bar - so nobody mistakes it for the trial clock.
const Palette = preload("res://scripts/ui/ui_palette.gd")

const SZ := Vector2(158, 48)
const GOLD := Color("f0b429")
const GOLD_SOFT := Color("f6d98a")
const BAR_RECT := Rect2(46, 36, 100, 5)

var _progress := 0.0
var _complete := false
var _caption: Label
var _value: Label

func _make_label(text: String, size: int, color: Color, pos: Vector2, width: float) -> Label:
	var label := Label.new()
	label.set_meta("arcade_authored_control", true)
	label.set_meta("keep_style", true)
	label.text = text
	label.add_theme_font_override("font", Palette.DISPLAY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	label.size = Vector2(width, float(size) + 6.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	set_meta("arcade_authored_control", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SZ
	size = SZ
	_caption = _make_label("TODAY", 9, GOLD_SOFT, Vector2(46, 3), 100.0)
	_value = _make_label("0m", 15, Color("fff7e0"), Vector2(46, 13), 104.0)
	_value.name = "TrialDone"

func _process(_delta: float) -> void:
	var daily := AppData.daily_progress()
	var goal := float(daily.get("goal", 0))          # seconds
	var secs := float(daily.get("seconds", 0))       # seconds
	_complete = bool(daily.get("complete", false))
	_progress = clampf(secs / goal, 0.0, 1.0) if goal > 0.0 else 0.0
	var done := int(secs / 60.0)
	if goal > 0.0:
		_value.text = "%dm / %dm" % [done, int(round(goal / 60.0))]
	else:
		_value.text = "%dm" % done
	_caption.text = "TODAY  ·  GOAL REACHED" if _complete else "TODAY"
	queue_redraw()

func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.12, 0.05, 0.88)
	bg.set_corner_radius_all(24)
	bg.set_border_width_all(1)
	bg.border_color = Color(GOLD, 0.55)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	# gold badge with a flag (a "goal" symbol - nothing like a clock)
	var badge := Vector2(24, 24)
	draw_circle(badge, 16.0, Color(GOLD, 0.95))
	draw_line(badge + Vector2(-5, 8), badge + Vector2(-5, -9), Color("3a2a05"), 2.2, true)
	draw_colored_polygon(PackedVector2Array([badge + Vector2(-4, -9), badge + Vector2(8, -5), badge + Vector2(-4, -1)]), Color("3a2a05"))
	# flat progress bar
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(3)
	draw_style_box(track, BAR_RECT)
	if _progress > 0.004:
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD if not _complete else Color("7bd88f")
		fill.set_corner_radius_all(3)
		draw_style_box(fill, Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * _progress, BAR_RECT.size.y)))
