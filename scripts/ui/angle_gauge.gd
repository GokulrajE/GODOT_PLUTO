class_name AngleGauge
extends Control
## Semicircular angle dial. Shows the mechanism's full range (min..max), a bright
## "target zone" at the far end of the range, and a needle that follows the live angle.


var min_value := -90.0
var max_value := 90.0
## Start of the zone the user must reach (drawn bright). Set equal to max_value to hide it.
var target_from := 90.0
var unit := "°"
## Colours (defaults suit the dark forest cards).
var ink := Color("1a2e44")
var accent := Color("087f83")
var value := 0.0
var _shown := 0.0
## Extra room (fraction of span) drawn beyond each end so overshoot stays visible.
const PAD := 0.08

func configure(min_v: float, max_v: float, target_start: float, unit_suffix: String = "°") -> void:
	min_value = min_v
	max_value = max_v
	target_from = target_start
	unit = unit_suffix
	queue_redraw()

func set_value(v: float) -> void:
	value = v

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	var next := value if reduced else lerpf(_shown, value, clampf(delta * 14.0, 0.0, 1.0))
	if absf(next - _shown) > 0.001:
		_shown = next
		queue_redraw()

# value -> position on the dial (angle PI = left end, TAU = right end, through the top)
func _theta(v: float) -> float:
	var span := maxf(max_value - min_value, 0.001)
	var t := (v - min_value) / span
	t = clampf(t, -PAD, 1.0 + PAD)
	return PI + (t + PAD) / (1.0 + 2.0 * PAD) * PI

func _draw() -> void:
	var font := get_theme_default_font()
	var c := Vector2(size.x * 0.5, size.y - 26.0)
	var r := minf(size.x * 0.5 - 40.0, size.y - 56.0)
	if r < 20.0:
		return
	var teal_dim := Color(accent, 0.35)
	var line_col := Color(ink, 0.55)

	# outer scale arc
	draw_arc(c, r, _theta(min_value - (max_value - min_value) * PAD), _theta(max_value + (max_value - min_value) * PAD), 96, Color(ink, 0.28), 2.0, true)

	# inner range band: whole mechanism range, then the target zone brighter
	var rb := r * 0.80
	draw_arc(c, rb, _theta(min_value), _theta(max_value), 96, teal_dim, 7.0, true)
	if target_from < max_value:
		draw_arc(c, rb, _theta(target_from), _theta(max_value), 48, accent, 7.0, true)

	# ticks: minor every 5 units, major every 20 (and at the ends)
	var tick := ceilf(min_value / 5.0) * 5.0
	while tick <= max_value + 0.001:
		var major := is_equal_approx(fmod(absf(tick), 20.0), 0.0)
		var a := _theta(tick)
		var dir := Vector2(cos(a), sin(a))
		var tick_len := 14.0 if major else 7.0
		draw_line(c + dir * (r - tick_len), c + dir * r, line_col if major else Color(line_col, 0.5), 2.0 if major else 1.2, true)
		tick += 5.0

	# labels: min, 0 (when inside the range) and max
	var labels: Array = [min_value, max_value]
	if min_value < -0.5 and max_value > 0.5:
		labels.append(0.0)
	for v in labels:
		var txt := _fmt(v)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var p: Vector2
		if is_zero_approx(v):
			var a0 := _theta(0.0)
			p = c + Vector2(cos(a0), sin(a0)) * (r + 20.0) - Vector2(w * 0.5, 0.0)
		elif v == min_value:
			p = Vector2(c.x - r - w * 0.5, c.y + 20.0)
		else:
			p = Vector2(c.x + r - w * 0.5, c.y + 20.0)
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ink, 0.9))

	# needle + glowing tip
	var an := _theta(_shown)
	var nd := Vector2(cos(an), sin(an))
	var tip := c + nd * rb
	draw_line(c + nd * (rb * 0.35), tip, Color(accent, 0.9), 3.0, true)
	draw_circle(tip, 13.0, Color(accent, 0.18))
	draw_circle(tip, 8.0, Color(accent, 0.35))
	draw_circle(tip, 5.0, accent)
	draw_circle(c, 5.0, Color(ink, 0.7))

func _fmt(v: float) -> String:
	var s := "%d" % int(round(v))
	if v > 0.5: s = "+" + s
	return s + unit
