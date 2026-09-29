extends Node
## Run normal application startup with -- --ui-startup-test (no --script override).
func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var scene := get_tree().current_scene
	var is_game: bool = scene != null and scene.scene_file_path.begins_with("res://game/")
	var expected := "ArcadePresentation" if is_game else "ArcadeBackdrop"
	var ok: bool = scene != null and scene.has_node(expected)
	if scene:
		var count := 0
		for child in scene.get_children():
			if str(child.name).begins_with(expected): count += 1
		ok = ok and count == 1
	if scene and scene.name == "MainScene": ok = ok and scene.has_node("DemoButton")
	if is_game and ok: ok = scene.get_node("ArcadePresentation").kind == scene.scene_file_path
	print("NORMAL STARTUP UI: ", "PASS" if ok else "FAIL", " scene=", scene.scene_file_path if scene else "null")
	if scene:
		print("ROOT CHILDREN: ", scene.get_children().map(func(n): return n.name))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/normal-startup.png")
	# Let the audio mixer release active playback before this short probe exits.
	get_tree().root.get_node("MenuMusic").set_muted(true)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if ok else 1)
