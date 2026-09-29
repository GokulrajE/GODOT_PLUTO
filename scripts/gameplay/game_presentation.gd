extends Node2D
## Scene presentation only: artwork, HUD, dialogs and event-driven feedback.
const Assets = preload("res://scripts/ui/arcade_assets.gd")
const Palette = preload("res://scripts/ui/ui_palette.gd")
const Effects = preload("res://scripts/effects/game_effects.gd")
var game: Control
var effects: Node2D
var kind := ""
var last_hits := 0
var last_misses := 0
var timer_bar: ProgressBar
var footer: Label
var pause_button: Button
var motion_time := 0.0
var last_ball_vx := 0.0
var last_ball_vy := 0.0
var last_hat_x := 583.0
var booster: Node2D

func _ready() -> void:
	game = get_parent()
	if not game.is_node_ready(): await game.ready
	kind = game.scene_file_path
	effects = Effects.new()
	effects.yellow_stars = kind.contains("HAT_TIRCK")
	effects.vivid_feedback = kind.contains("FRUIT_BASKET") or kind.contains("RNR")
	game.add_child(effects)
	_setup_art()
	_setup_hud()
	_setup_dialogs()

func _setup_art() -> void:
	if game.has_node("ArcadeGameBackground"):
		booster = game.get_node_or_null("Player/ArcadeBooster")
		queue_redraw()
		return
	for key in ["Sky", "Grass", "Ground", "Background"]:
		var old := game.get_node_or_null(key)
		if old is CanvasItem: old.hide()
	var bg := TextureRect.new()
	bg.name = "ArcadeGameBackground"
	bg.texture = Assets.background(_icon_key())
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(1166, 784 if _icon_key() in ["basket", "cloud"] else (716 if _icon_key() == "hat" else 656))
	game.add_child(bg)
	game.move_child(bg, 0)
	if kind.contains("PING_PONG"):
		bg.modulate = Color(0.85, 0.85, 0.95)
		game.get_node("PlayerPaddle").modulate = Color("abf34d")
		game.get_node("EnemyPaddle").modulate = Color("e977bc")
		game.get_node("Ball").texture = load("res://Assets/Arcade/ball.svg")
		game.get_node("Ball").modulate = Color.WHITE
	if kind.contains("HAT_TIRCK"):
		var hat: TextureRect = game.get_node("HatBack")
		hat.texture = Assets.sprite("hat")
		hat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hat.stretch_mode = TextureRect.STRETCH_SCALE
		hat.scale = Vector2.ONE
		hat.size = Vector2(180, 139)
		hat.position = Vector2(game.get("_hat_x") - 90, 490)
		game.get_node("HatFront").hide()
	if kind.contains("RNR"):
		var cloud: TextureRect = game.get_node("Cloud")
		cloud.texture = Assets.sprite("cloud")
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cloud.size = Vector2(160, 116)
		cloud.position.y = 90
	if kind.contains("TUK_TUK"):
		for key in ["_bg1", "_bg2"]:
			var old: TextureRect = game.get(key)
			if old: old.hide()
		var player: TextureRect = game.get_node("Player")
		player.texture = Assets.sprite("tuk")
		player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		player.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		booster = preload("res://scripts/effects/tuk_booster.gd").new()
		booster.name = "ArcadeBooster"
		player.add_child(booster)
		for key in ["wheel1", "wheel2", "face", "booster"]:
			player.get_node(key).hide()
	queue_redraw()

func _icon_key() -> String:
	if kind.contains("HAT_TIRCK"): return "hat"
	if kind.contains("FRUIT_BASKET"): return "basket"
	if kind.contains("RNR"): return "cloud"
	if kind.contains("TUK_TUK"): return "tuk"
	return "pong"

func _rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

func _setup_hud() -> void:
	if game.has_node("UI/SessionProgress"):
		timer_bar = game.get_node("UI/SessionProgress")
		footer = game.get_node("UI/GameHelp")
		pause_button = game.get_node("UI/Header/PauseButton")
		pause_button.pressed.connect(func(): game.call("_on_pluto_button"))
		footer.text = "ARROW KEYS  Move     •     SPACE  Start / pause     •     CTRL + G  Speed" if not PlutoComm.is_connected else "PLUTO connected  •  Press device button to start / pause"
		if AppData.demo_mode: footer.text += "     •     DEMO — not recorded"
		return
	var header: Panel = game.get_node("UI/Header")
	_rect(header, Rect2(12, 8, 1142, 58))
	var title := Label.new()
	title.name = "GameName"
	title.text = {"hat": "HAT-TRICK", "basket": "FRUIT BASKET", "cloud": "RAIN & RISE", "tuk": "TUK-TUK", "pong": "PING-PONG"}[_icon_key()]
	title.add_theme_font_override("font", Palette.DISPLAY)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_stylebox_override("normal", Palette.chrome("field-blue"))
	header.add_child(title)
	_rect(title, Rect2(14, 8, 190, 40))
	for key in ["TimerLabel", "ScoreLabel"]:
		var label: Label = header.get_node(key)
		label.add_theme_font_size_override("font_size", 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var chip := Palette.chrome("field-blue")
		chip.content_margin_top = 4
		chip.content_margin_bottom = 4
		label.add_theme_stylebox_override("normal", chip)
		label.add_theme_font_override("font", Palette.DISPLAY)

	_rect(header.get_node("TimerLabel"), Rect2(214, 8, 180, 40))
	_rect(header.get_node("ScoreLabel"), Rect2(414, 8, 354, 40))
	header.get_node("TimerLabel").vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.get_node("ScoreLabel").vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rect(header.get_node("StarDisplay"), Rect2(790, 5, 110, 44))
	var star: TextureRect = header.get_node("StarDisplay/StarImg")
	star.texture = Assets.sprite("star")
	star.custom_minimum_size = Vector2(38, 38)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var count: Label = header.get_node("StarDisplay/StarCountLabel")
	count.add_theme_font_size_override("font_size", 28)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rect.call_deferred(header.get_node("StarDisplay"), Rect2(790, 7, 110, 44))
	_rect(header.get_node("ExitButton"), Rect2(1020, 8, 100, 40))
	pause_button = _button(header, "Pause", Rect2(916, 8, 94, 40), func(): game.call("_on_pluto_button"))
	pause_button.set_meta("secondary", true)
	timer_bar = ProgressBar.new()
	timer_bar.name = "SessionProgress"
	timer_bar.show_percentage = false
	timer_bar.max_value = 60
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI").add_child(timer_bar)
	_rect(timer_bar, Rect2(28, 71, 1110, 7))
	footer = Label.new()
	footer.name = "GameHelp"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_stylebox_override("normal", Palette.surface(Color("242448"), 8, Color.TRANSPARENT))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text = "ARROW KEYS  Move     •     SPACE  Start / pause     •     CTRL + G  Speed" if not PlutoComm.is_connected else "PLUTO connected  •  Press device button to start / pause"
	if AppData.demo_mode: footer.text += "     •     DEMO — not recorded"
	game.get_node("UI").add_child(footer)
	_rect(footer, Rect2(20, 632, 1126, 20))

func _button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.name = {"Pause": "PauseButton", "PLAY": "PlayButton", "RESUME": "ResumeButton", "PLAY AGAIN": "ReplayButton"}.get(text, "ArcadeButton")
	parent.add_child(button)
	_rect(button, rect)
	button.pressed.connect(action)
	# Space is a game action, so click focus must not consume it on a hidden button.
	button.focus_mode = Control.FOCUS_NONE
	return button

func _setup_dialogs() -> void:
	if game.has_node("UI/WaitPanel/PlayButton"):
		for path in ["UI/WaitPanel/PlayButton", "UI/PausePanel/ResumeButton", "UI/GameOverPanel/ReplayButton"]:
			game.get_node(path).pressed.connect(func(): game.call("_on_pluto_button"))
		game.get_node("UI/WaitPanel/HintLabel").text = "Press SPACE or choose Play" if not PlutoComm.is_connected else "Press the PLUTO button or choose Play"
		return
	var wait: Panel = game.get_node("UI/WaitPanel")
	_rect(wait, Rect2(303, 135, 560, 390))
	_rect(wait.get_node("GameTitle"), Rect2(24, 144, 512, 54))
	wait.get_node("GameTitle").add_theme_font_size_override("font_size", 38)
	_rect(wait.get_node("SubTitle"), Rect2(28, 202, 504, 44))
	wait.get_node("SubTitle").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rect(wait.get_node("HintLabel"), Rect2(28, 255, 504, 32))
	wait.get_node("HintLabel").text = "Press SPACE or choose Play" if not PlutoComm.is_connected else "Press the PLUTO button or choose Play"
	var icon := TextureRect.new()
	icon.name = "GameArtwork"
	icon.texture = Assets.sprite(_icon_key())
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait.add_child(icon)
	_rect(icon, Rect2(200, 22, 160, 118))
	_button(wait, "PLAY", Rect2(170, 306, 220, 52), func(): game.call("_on_pluto_button"))
	var pause: Panel = game.get_node("UI/PausePanel")
	_rect(pause, Rect2(333, 185, 500, 275))
	_rect(pause.get_node("PauseTitle"), Rect2(25, 35, 450, 60))
	_rect(pause.get_node("PauseHint"), Rect2(25, 104, 450, 55))
	pause.get_node("PauseHint").text = "Take your time. Your session is paused."
	_button(pause, "RESUME", Rect2(140, 185, 220, 52), func(): game.call("_on_pluto_button"))
	var over: Panel = game.get_node("UI/GameOverPanel")
	_rect(over, Rect2(303, 150, 560, 360))
	_rect(over.get_node("OverTitle"), Rect2(24, 36, 512, 55))
	over.get_node("OverTitle").text = "GAME OVER"
	over.get_node("OverTitle").add_theme_font_size_override("font_size", 32)
	_rect(over.get_node("ScoreLabel"), Rect2(24, 115, 512, 100))
	var caught := over.get_node_or_null("CaughtLabel")
	if caught: caught.hide()
	_rect(over.get_node("ExitButton"), Rect2(295, 263, 215, 52))
	_button(over, "PLAY AGAIN", Rect2(50, 263, 215, 52), func(): game.call("_on_pluto_button"))
	var speed: Panel = game.get_node("UI/SpeedPanel")
	speed.z_index = 20
	# Existing speed panel uses its own internal control layout.

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var paused: bool = game.get_node("UI/PausePanel").visible
	var waiting: bool = game.get_node("UI/WaitPanel").visible
	var done: bool = game.get_node("UI/GameOverPanel").visible
	if booster: booster.step(delta, not waiting and not done, paused)
	var backdrop := game.get_node_or_null("ArcadeGameBackground")
	if backdrop and backdrop.has_method("step"): backdrop.step(delta, not waiting and not done, paused)
	pause_button.disabled = waiting or done
	pause_button.text = "Resume" if paused else "Pause"
	timer_bar.value = maxf(0, float(game.get("_time_left")))
	var hits: int = game.get("n_success")
	var misses: int = game.get("n_failure")
	var at := Vector2(AppData.log_player_x, AppData.log_player_y)
	if kind.contains("FRUIT_BASKET") or kind.contains("RNR"):
		at = Vector2(AppData.log_target_x, 520)
	if hits > last_hits: effects.burst(at, true)
	if misses > last_misses: effects.burst(at, false)
	last_hits = hits
	last_misses = misses
	var trail_at := Vector2.INF
	if kind.contains("PING_PONG") and not waiting and not done:
		trail_at = Vector2(game.get("_ball_x"), game.get("_ball_y"))
		var vx: float = game.get("_ball_vx")
		var vy: float = game.get("_ball_vy")
		if (vx * last_ball_vx < 0 or vy * last_ball_vy < 0) and not paused: effects.burst(trail_at, true, false)
		last_ball_vx = vx
		last_ball_vy = vy
	effects.step(delta, paused, trail_at)
	if not paused and not waiting and not done:
		if not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
			motion_time += delta
			if kind.contains("RNR"): game.get_node("Cloud").position.y = 90 + sin(motion_time * 1.8) * 3
			if kind.contains("HAT_TIRCK"):
				var hat: TextureRect = game.get_node("HatBack")
				hat.pivot_offset = Vector2(90, 25)
				var x: float = game.get("_hat_x")
				hat.rotation = lerpf(hat.rotation, clampf((x - last_hat_x) * 0.006, -0.035, 0.035), 1.0 - exp(-12.0 * delta))
				last_hat_x = x
				var ball: Control = game.get("_current_ball")
				if is_instance_valid(ball):
					ball.pivot_offset = ball.size * 0.5
					ball.rotation += delta * 0.35
			if kind.contains("FRUIT_BASKET"):
				var fruit: Control = game.get("_current_fruit")
				if is_instance_valid(fruit):
					fruit.pivot_offset = fruit.size * 0.5
					fruit.rotation = sin(motion_time * 2.0) * 0.07
	queue_redraw()

func _draw() -> void:
	if kind.contains("TUK_TUK"):
		draw_line(Vector2(0, 562), Vector2(1166, 562), Color(0.7, 0.7, 1, 0.25), 2)
		var player: TextureRect = game.get_node("Player")
		if player.visible:
			for offset in [Vector2(26, 95), Vector2(132, 95)]:
				var center: Vector2 = to_local(player.get_global_transform() * offset)
				for spoke in 4:
					var direction := Vector2.from_angle(motion_time * 7 + spoke * PI / 2)
					draw_line(center, center + direction * 7, Color("b7c4e6"), 1.5, true)
	if kind.contains("PING_PONG") and not game.has_node("PongCourt"):
		var court := Palette.surface(Color.TRANSPARENT, 18, Color("8a79d8"))
		court.draw_center = false
		court.shadow_size = 0
		draw_style_box(court, Rect2(24, 86, 1118, 538))
		draw_arc(Vector2(583, 355), 62, 0, TAU, 64, Color(0.58, 0.52, 0.88, 0.45), 2, true)

