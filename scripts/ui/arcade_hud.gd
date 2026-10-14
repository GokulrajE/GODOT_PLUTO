extends Panel
## Arcade HUD presentation; scoring and timers remain owned by each game.
var last_score := -1
var pulse := 0.0
var progress_refresh := 0.0
var animation_time := 0.0
var longest_time := 1.0
@onready var game: Control = _find_game_root()
@onready var score: Label = $ScoreLabel
@onready var timer: Label = $TimerLabel

func _find_game_root() -> Control:
	var node: Node = get_parent()
	while node != null:
		if node.get("_time_left") != null and node.get("n_success") != null:
			return node as Control
		node = node.get_parent()
	return get_tree().current_scene as Control

func _process(delta: float) -> void:
	if not is_instance_valid(game) or game.get("_time_left") == null or game.get("n_success") == null:
		return
	var seconds := maxi(0, ceili(float(game.get("_time_left"))))
	timer.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer.add_theme_color_override("font_color", Color("a63727") if seconds <= 10 else Color("243a54"))
	var hits: int = game.get("n_success")
	if not game.scene_file_path.contains("PING_PONG"):
		score.text = "%02d" % hits
	if hits > last_score and last_score >= 0: pulse = 0.3
	last_score = hits
	pulse = maxf(0, pulse - delta)
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	score.pivot_offset = score.size * 0.5
	score.scale = Vector2.ONE * (1.0 + sin(pulse / 0.3 * PI) * 0.08 if not reduced else 1.0)

	animation_time += delta
	longest_time = maxf(longest_time, float(game.get("_time_left")))
	timer.pivot_offset = timer.size * 0.5
	timer.scale = Vector2.ONE * (1.0 + 0.035 * sin(animation_time * 5.0) if seconds > 0 and seconds <= 10 and not reduced else 1.0)
	queue_redraw()
	progress_refresh -= delta
	if not AppData.demo_mode and AppData.is_patient_loaded and progress_refresh <= 0:
		progress_refresh = 1.0
		var daily := AppData.daily_progress()
		var clock = preload("res://scripts/data/DailyActivity.gd")
		var played := clock.clock_text(float(daily.games.get(AppData.selected_game_name, 0.0)))
		game.get_node("UI/GameHelp").text = "%s  %s  |  This game: %s today" % [AppData.mechanism_name, AppData.daily_progress_text(), played]

func _draw() -> void:
	if not is_instance_valid(game) or game.get("_time_left") == null: return
	var fraction := clampf(float(game.get("_time_left")) / longest_time, 0.0, 1.0)
	var start := Vector2(262, 50)
	draw_line(start, start + Vector2(118, 0), Color("d7bc83"), 3.0, true)
	if fraction > 0:
		draw_line(start, start + Vector2(118 * fraction, 0), Color("bd6431"), 3.0, true)
