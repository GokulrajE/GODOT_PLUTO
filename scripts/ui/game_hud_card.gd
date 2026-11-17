extends Control
## Top-left HUD card: circular trail-progress ring and remaining time.
## Instantiated by game_presentation.gd; no .tscn changes required.

const Palette = preload("res://scripts/ui/ui_palette.gd")

var game_ref: Node
var peak_time := 1.0
var time_lbl: Label

const SZ := Vector2(90, 90)
const RC := Vector2(45, 45)   # ring center within card
const RR := 34.0              # ring outer radius
const RW := 6.0               # ring track width

func _ready() -> void:
	set_meta("arcade_authored_control", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SZ
	size = SZ
	_find_game_ref()
	_build_time_label()

func _find_game_ref() -> void:
	var node := get_parent()
	while node:
		if node.get("_time_left") != null and node.get("n_success") != null:
			game_ref = node
			return
		node = node.get_parent()

func _build_time_label() -> void:
	time_lbl = Label.new()
	time_lbl.set_meta("arcade_authored_control", true)
	time_lbl.name = "HudTime"
	time_lbl.text = "01:00"
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_override("font", Palette.DISPLAY)
	time_lbl.add_theme_font_size_override("font_size", 17)
	time_lbl.add_theme_color_override("font_color", Color("e8f4fc"))
	time_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	time_lbl.position = Vector2(RC.x - 32, RC.y - 11)
	time_lbl.size     = Vector2(64, 22)
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(time_lbl)

func _process(_delta: float) -> void:
	if not is_instance_valid(game_ref): return
	var t   := maxf(0.0, float(game_ref.get("_time_left")))
	peak_time = maxf(peak_time, t)
	var sec := maxi(0, ceili(t))
	@warning_ignore("INTEGER_DIVISION")
	time_lbl.text = "%02d:%02d" % [sec / 60, sec % 60]
	var urgent := sec <= 10 and sec > 0
	time_lbl.add_theme_color_override("font_color",
		Color("e05a2b") if urgent else Color("e8f4fc"))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game_ref): return
	var t    := maxf(0.0, float(game_ref.get("_time_left")))
	var done := clampf(1.0 - t / peak_time, 0.0, 1.0)

	# Card background
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.11, 0.18, 0.84)
	bg.set_corner_radius_all(16)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.08)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	# Dark inner fill so text is readable
	draw_circle(RC, RR - RW - 1.5, Color(0.05, 0.08, 0.14, 0.72))

	# Ring track (dim arc)
	draw_arc(RC, RR, -PI * 0.5, PI * 1.5, 72, Color(1, 1, 1, 0.12), RW, true)

	# Progress arc: teal (0%) → amber (100%)
	if done > 0.004:
		var col := Color("087f83").lerp(Color("e0921a"), done)
		draw_arc(RC, RR, -PI * 0.5, -PI * 0.5 + done * TAU, 80, col, RW + 1.5, true)

	# Dot at progress tip
	if done > 0.01 and done < 0.995:
		var tip_a := -PI * 0.5 + done * TAU
		draw_circle(RC + Vector2(cos(tip_a), sin(tip_a)) * RR, 4.0, Color("e0921a"))

