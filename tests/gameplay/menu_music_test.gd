extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func run() -> void:
	root.get_node("AppData").enter_demo()
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(0.4).timeout
	var music := root.get_node("MenuMusic")
	check(music.playing and music.stream.loop, "menu music plays and loops")
	check(music.stream.get_length() > 10, "music is a full loop, not a click or jingle")
	current_scene.get_node("MusicToggle").button_pressed = false
	check(not music.playing and music.muted, "music toggle mutes")
	current_scene.get_node("MusicToggle").button_pressed = true
	check(music.playing and not music.muted, "music toggle unmutes")
	await create_timer(0.3).timeout
	var position: float = music.get_playback_position()
	change_scene_to_file("res://scenes/ChooseGameScene.tscn")
	await create_timer(0.3).timeout
	check(music.playing and music.get_playback_position() > position, "menu transitions do not restart music")
	change_scene_to_file("res://game/HAT_TIRCK/scene/HatrickScene.tscn")
	await create_timer(0.3).timeout
	check(not music.playing, "menu music stops in gameplay")
	var effects = current_scene.get_node("ArcadePresentation").effects
	effects.burst(Vector2(583, 350))
	check(effects.particles.size() == 14 and effects.particles[0].size >= 12, "larger bounded success particles")
	effects.step(0.1, false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arcade-test/brighter-effects.png")
	ProjectSettings.set_setting("pluto/ui/reduced_motion", true)
	effects.step(0.01, false)
	var count: int = effects.particles.size()
	effects.burst(Vector2(583, 350))
	check(effects.particles.size() == count, "reduced motion suppresses bigger bursts")
	ProjectSettings.set_setting("pluto/ui/reduced_motion", false)
	current_scene.get_node("UI/GameOverPanel/ExitButton").pressed.emit()
	await create_timer(0.3).timeout
	check(current_scene.name == "ChooseGameScene" and music.playing, "return button selects game and resumes menu music")
	root.get_node("AppData").exit_demo()
	var report := FileAccess.open("res://.godot/arcade-test/menu-music-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("MENU MUSIC / EFFECTS: ", checks, " checks; failures: ", failures)
	quit(0 if failures.is_empty() else 1)
