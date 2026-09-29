extends SceneTree
## Isolated integration runner. Uses real input events and game state machines.
const GAMES := {
	"hat": "res://game/HAT_TIRCK/scene/HatrickScene.tscn",
	"fruit": "res://game/FRUIT_BASKET/scene/FruitBasketScene.tscn",
	"garden": "res://game/RNR/scene/RNRScene.tscn",
	"tuk": "res://game/TUK_TUK/scene/TukTukScene.tscn",
	"pong": "res://game/PING_PONG/scene/PingPongScene.tscn"
}
var failures: Array[String] = []
var checks := 0
var results: Dictionary = {}
var game: Control
var view: Node
var kind := ""
var held := 0
var app: Node
var frame_count := 0
var initial_data: Dictionary
var snapshot_dir := "res://.godot/arcade-test"

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(kind + ": " + message)
		printerr("FAIL: ", kind, ": ", message)

func _data_hashes(path: String, result: Dictionary = {}) -> Dictionary:
	var dir := DirAccess.open(path)
	if not dir: return result
	for file in dir.get_files(): result[path + "/" + file] = FileAccess.get_sha256(path + "/" + file)
	for folder in dir.get_directories(): _data_hashes(path + "/" + folder, result)
	return result

func _event(key: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(key: int) -> void:
	_event(key, true)
	_event(key, false)

func _hold(key: int) -> void:
	if held == key: return
	if held: _event(held, false)
	held = key
	if held: _event(held, true)

func _axis_position() -> float:
	match kind:
		"hat": return game.get("_hat_x")
		"fruit": return game.get("_fruit_x")
		"garden": return game.get("_cloud_x")
		_: return game.get("_player_y")

func _pilot(miss: bool = false) -> void:
	var target := 583.0
	match kind:
		"hat":
			var ball: Control = game.get("_current_ball")
			if is_instance_valid(ball): target = ball.position.x + ball.size.x * 0.5
		"fruit": target = float(game.get("_slot_positions")[game.get("_target_slot")])
		"garden":
			var index: int = game.get("_target_seed")
			if index >= 0: target = float(game.get("_slot_positions")[index])
		"tuk": target = float(game.call("_get_next_column").gap_y)
		"pong": target = game.call("_predict_ball_y_at_player")
	var vertical := kind in ["tuk", "pong"]
	if miss: target = (130.0 if target > 355 else 550.0) if vertical else (120.0 if target > 583 else 1045.0)
	var diff := target - _axis_position()
	if absf(diff) < 5.0: _hold(0)
	elif vertical: _hold(KEY_DOWN if diff > 0 else KEY_UP)
	else: _hold(KEY_RIGHT if diff > 0 else KEY_LEFT)

func _step(count: int, pilot: bool = false, miss: bool = false, dt: float = 1.0 / 60.0) -> void:
	for i in count:
		if pilot: _pilot(miss)
		game.call("_process", dt)
		view.call("_process", dt)
		frame_count += 1
		if frame_count % 12 == 0: await process_frame

func _load_game(id: String) -> void:
	_hold(0)
	kind = id
	seed(120 + GAMES.keys().find(id))
	app.set_game(id)
	_check(change_scene_to_file(GAMES[id]) == OK, "scene loads")
	await process_frame
	await process_frame
	await process_frame
	game = current_scene
	view = game.get_node("ArcadePresentation")
	game.set_process(false)
	view.set_process(false)
	var backgrounds := {"hat": "twilight-garden.png", "fruit": "orchard-v2.png", "garden": "garden-v2.png", "tuk": "canyon-v2.png", "pong": "arena-v2.png"}
	_check(game.get_node("ArcadeGameBackground").texture.resource_path.ends_with(backgrounds[id]), "correct game-specific background")
	if kind == "tuk":
		_check(game.get_node("Player").texture.atlas.resource_path.ends_with("sprites-driver-v2.png"), "driver atlas in use")
		_check(view.get("booster").get_parent() == game.get_node("Player"), "booster anchored to vehicle")
		_check(view.get("booster").position.is_equal_approx(Vector2(8, 74)), "booster rear mount aligned")
	_check(root.content_scale_size == Vector2i(1166, 656), "canonical playfield")
	_check(game.size.is_equal_approx(Vector2(1166, 656)), "game fills canonical viewport")
	var header: Control = game.get_node("UI/Header")
	for key in ["GameName", "TimerLabel", "ScoreLabel", "StarDisplay", "ExitButton"]:
		_check(Rect2(Vector2.ZERO, header.size).encloses(header.get_node(key).get_rect()), "HUD item contained: " + key)
	for key in ["WaitPanel", "PausePanel", "GameOverPanel"]:
		_check(Rect2(Vector2.ZERO, game.size).encloses(game.get_node("UI/" + key).get_rect()), "dialog contained: " + key)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(snapshot_dir + "/" + label + ".png")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(snapshot_dir)
	Engine.max_fps = 0
	Input.use_accumulated_input = false
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 800)
	app = root.get_node("AppData")
	initial_data = _data_hashes("res://data", {})
	app.enter_demo()
	_check(app.demo_mode and not app.is_patient_loaded and app.selected_mechanism == null, "demo isolation")
	for id in GAMES:
		await _load_game(id)
		await _capture(id + "-ready")
		_tap(KEY_SPACE)
		await _step(30)
		_check(not game.get_node("UI/WaitPanel").visible, "Space starts gameplay")
		var pos := _axis_position()
		_hold(KEY_DOWN if kind in ["pong", "tuk"] else KEY_RIGHT)
		await _step(12)
		_hold(0)
		var moved := _axis_position()
		_check(moved > pos + 20, "keyboard moves player")
		if kind == "tuk":
			_check(game.get_node("Player").rotation > 0.01 and game.get_node("Player").rotation <= 0.12, "auto tilts down gently while descending")
			_hold(KEY_UP)
			await _step(24)
			_hold(0)
			_check(game.get_node("Player").rotation < -0.01, "auto tilts up while ascending")
			moved = _axis_position()
		await _step(12)
		_check(absf(_axis_position() - moved) < 0.01, "keyboard release holds position")
		# Pause while a key remains held. Time, player and moving target must freeze.
		_tap(KEY_SPACE)
		var time_before: float = game.get("_time_left")
		var pause_pos := _axis_position()
		var booster_time: float = view.get("booster").elapsed if kind == "tuk" else 0.0
		_hold(KEY_LEFT)
		await _step(90)
		_hold(0)
		_check(game.get_node("UI/PausePanel").visible, "pause dialog visible")
		if kind == "tuk": _check(is_equal_approx(view.get("booster").elapsed, booster_time), "booster freezes on pause")
		_check(is_equal_approx(time_before, game.get("_time_left")), "pause freezes timer")
		_check(is_equal_approx(pause_pos, _axis_position()), "pause freezes player")
		_event(KEY_SPACE, true, true)
		_check(game.get_node("UI/PausePanel").visible, "key repeat does not unpause")
		_event(KEY_SPACE, false)
		await create_timer(0.25).timeout
		await _capture(id + "-paused")
		_tap(KEY_SPACE)
		_check(not game.get_node("UI/PausePanel").visible, "resume works")
		view.get("pause_button").pressed.emit()
		_check(game.get_node("UI/PausePanel").visible, "pause button works")
		view.get("pause_button").pressed.emit()
		_check(not game.get_node("UI/PausePanel").visible, "resume button works")
		ProjectSettings.set_setting("pluto/ui/reduced_motion", true)
		await _step(2)
		_check(view.get("effects").reduced, "game effects honor reduced motion")
		if kind == "tuk": _check(is_zero_approx(game.get_node("Player").rotation), "reduced motion keeps auto level")
		if kind == "hat": _check(view.effects.yellow_stars, "Hat uses yellow star effects")
		if kind == "tuk": _check(is_equal_approx(view.get("booster").flame_length, 38.0), "booster reduced motion steady")
		ProjectSettings.set_setting("pluto/ui/reduced_motion", false)

		# Actual deterministic gameplay; steer with arrow-key input, never inject scores.
		await _step(1200, true)
		_hold(0)
		if kind == "tuk": _check(view.get("booster").firing and view.get("booster").elapsed > 1.0, "booster animates during play")
		await _capture(id + "-playing")
		
		await _step(900, true, true)
		_check(int(game.get("n_failure")) > 0, "miss/collision interactions registered")
		await _step(2100, true)
		_hold(0)
		_check(game.get_node("UI/GameOverPanel").visible, "timer reaches results")
		_check(game.get_node("UI/GameOverPanel/OverTitle").text == "GAME OVER", "updated results heading")
		_check(game.get_node("UI/GameOverPanel").reveal_count == 1, "results animation and audio trigger once")
		if kind == "garden":
			_check(game.get("_drop_nodes")[0] is TextureRect, "rain uses water-drop textures")
			_check(game.get("_drop_nodes")[0].size.y >= 23, "rain drops are large and visible")
		if kind == "hat":
			var select_game: Button = game.get_node("UI/GameOverPanel/ExitButton")
			_check(select_game.is_visible_in_tree(), "Hat results Select Game button is visible")
			_check(game.get_node("UI/GameOverPanel").get_global_rect().encloses(select_game.get_global_rect()), "Hat Select Game button stays inside results panel")
		_check(bool(game.get("_game_finished")), "trial completed")
		if kind == "tuk":
			_check(not view.get("booster").firing, "booster stops at session end")
			var bg = game.get_node("ArcadeGameBackground")
			_check(bg.scroll_phase > 0.0, "Tuk scenery scrolls during play")
			var phase: float = bg.scroll_phase
			bg.step(1.0, true, true)
			_check(is_equal_approx(phase, bg.scroll_phase), "Tuk scenery freezes when paused")
			ProjectSettings.set_setting("pluto/ui/reduced_motion", true)
			bg.step(1.0, true, false)
			_check(is_equal_approx(phase, bg.scroll_phase), "Tuk scenery respects reduced motion")
			ProjectSettings.set_setting("pluto/ui/reduced_motion", false)
		if kind == "fruit":
			for i in 5:
				var pile = game.get("_basket_icon_nodes")[i]
				_check(pile.caught == game.get("_basket_counts")[i], "basket pile tracks catch count")
				_check(pile.fruit_texture == game.get("_fruit_textures")[game.get("_slot_fruit_type")[i]], "basket and falling fruit share matching artwork")
		var hits: int = game.get("n_success")
		_check(hits > 0, "successful interactions registered")
		var misses: int = game.get("n_failure")
		var targets: int = game.get("n_targets")
		if kind != "pong": _check(hits + misses == targets, "each target resolves exactly once")
		await _step(120)
		_check(hits == int(game.get("n_success")) and misses == int(game.get("n_failure")), "results do not continue scoring")
		await create_timer(0.25).timeout
		await _capture(id + "-results")
		results[id] = {"hits": hits, "misses": misses, "targets": targets}
		# Actual scene reload via replay input.
		_tap(KEY_SPACE)
		await process_frame
		await process_frame
		await process_frame
		game = current_scene
		view = game.get_node("ArcadePresentation")
		game.set_process(false)
		view.set_process(false)
		_check(game.get_node("UI/WaitPanel").visible and int(game.get("n_success")) == 0, "replay resets game")
		# Maximum/minimum speed and boundary clamping at a different timestep.
		for i in 45: game.call("_increase_speed")
		_check(is_equal_approx(float(game.get("_game_speed")), 40), "maximum speed clamp")
		for i in 45: game.call("_decrease_speed")
		_check(is_equal_approx(float(game.get("_game_speed")), 10), "minimum speed clamp")
		_tap(KEY_SPACE)
		await _step(20)
		_hold(KEY_UP if kind in ["pong", "tuk"] else KEY_LEFT)
		await _step(150, false, false, 1.0 / 30.0)
		_hold(0)
		_check(_axis_position() >= 0, "movement clamped to playfield")
		for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 600)]:
			root.size = resolution
			await process_frame
			await process_frame
			_check(game.size.is_equal_approx(Vector2(1166, 656)), "stable game coordinates at " + str(resolution))
			await _capture(id + "-" + str(resolution.x) + "x" + str(resolution.y))
		root.size = Vector2i(1280, 800)
		game.get_node("UI/GameOverPanel/ExitButton").pressed.emit()
		await process_frame
		await process_frame
		_check(current_scene.scene_file_path == "res://scenes/ChooseGameScene.tscn", "exit returns to picker")
		print("GAME TESTED: ", id, " ", results[id])
	await _capture("game-picker")
	_check(initial_data == _data_hashes("res://data", {}), "patient files unchanged")
	_check(app.trial_raw_file.is_empty(), "no demo raw-data file")
	app.exit_demo()
	_check(not app.demo_mode, "demo exits")
	var report := {"checks": checks, "failures": failures, "games": results, "patient_data_unchanged": initial_data == _data_hashes("res://data", {})}
	var file := FileAccess.open(snapshot_dir + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ARCADE TESTS: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

