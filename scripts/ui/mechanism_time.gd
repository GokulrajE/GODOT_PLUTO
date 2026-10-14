@tool
extends Control
## Animated daily activity; the numeric time always reports the actual saved value.
@export var mechanism := "HOC"
const FACE = preload("res://Assets/Arcade/Online/Outfit-Semibold.tres")
var fraction := 0.0
var elapsed := 0.0
var goal := 0.0
var estimated := false
var refresh := 0.0
var fill_tween: Tween
func _ready() -> void:
	custom_minimum_size = Vector2(260, 86)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("arcade_authored_control", true)
	resized.connect(queue_redraw)
	_update_time()
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	refresh += delta
	if refresh >= 1.0:
		refresh = 0.0
		_update_time()
func _update_time() -> void:
	if not Engine.is_editor_hint():
		var app = get_node_or_null("/root/AppData")
		if app:
			var data: Dictionary = app.daily_progress(mechanism)
			elapsed = float(data.get("seconds", 0.0))
			goal = float(data.get("goal", 0.0))
			estimated = bool(data.get("estimated", false))
	var target := clampf(elapsed / goal, 0.0, 1.0) if goal > 0 else 0.0
	if fill_tween and fill_tween.is_valid(): fill_tween.kill()
	if not Engine.is_editor_hint() and not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)) and not is_equal_approx(fraction, target):
		fill_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fill_tween.tween_method(func(value: float): fraction = value; queue_redraw(), fraction, target, 0.75)
	else: fraction = target
	queue_redraw()
func _draw() -> void:
	var done := goal > 0 and elapsed >= goal
	var accent := Color("177d72") if done else Color("6655b3")
	var left := (size.x - 252.0) * 0.5
	var center := Vector2(left + 30, 39)
	draw_circle(center, 29, Color("f0edf9"))
	draw_arc(center, 25, -PI / 2, TAU - PI / 2, 64, Color("ddd8ef"), 5, true)
	if fraction > 0:
		draw_arc(center, 25, -PI / 2, TAU * fraction - PI / 2, 64, accent, 5, true)
	# A clear clock face remains recognizable even with zero progress.
	draw_arc(center, 11, 0, TAU, 32, accent, 1.5, true)
	draw_line(center, center + Vector2(0, -7), accent, 2, true)
	draw_line(center, center + Vector2(5, 3), accent, 2, true)
	var value := ("~" if estimated else "") + preload("res://scripts/data/DailyActivity.gd").clock_text(elapsed)
	draw_string(FACE, Vector2(left + 72, 29), value + " today", HORIZONTAL_ALIGNMENT_LEFT, 180, 22, accent)
	var subtitle := "Goal reached" if done else ("of %s planned" % preload("res://scripts/data/DailyActivity.gd").clock_text(goal) if goal > 0 else "No daily target")
	draw_string(FACE, Vector2(left + 72, 50), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("465774"))
	if done: draw_string(FACE, Vector2(left + 72, 70), "Try another movement", HORIZONTAL_ALIGNMENT_LEFT, 180, 13, accent)
