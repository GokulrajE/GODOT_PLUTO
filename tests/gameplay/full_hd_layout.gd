extends SceneTree
var failures := 0
func _initialize(): run.call_deferred()
func run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	var manager = root.get_node("UIManager")
	manager.set_process(false)
	node_added.disconnect(Callable(manager, "_on_node_added"))
	for path in preload("res://scripts/ui/preview_ui.gd").SCENES:
		var scene = load(path).instantiate()
		strip_runtime(scene)
		preload("res://scripts/gameplay/playfield_layout.gd").configure(root, path.begins_with("res://game/"))
		root.add_child(scene)
		await process_frame
		await process_frame
		var bg = scene.get_node_or_null("ArcadeGameBackground" if path.begins_with("res://game/") else "ArcadeBackdrop")
		var viewport := root.get_visible_rect()
		if not bg is Control or bg.get_global_rect().size.x < viewport.size.x - 1 or bg.get_global_rect().size.y < viewport.size.y - 1:
			printerr("Background does not fill screen: ", path)
			failures += 1
		if DisplayServer.get_name() != "headless" and scene.name == "MainScene":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/full-hd-login.png")
		root.remove_child(scene)
		scene.queue_free()
	print("FULL HD: 15 scene backgrounds checked; failures=", failures)
	quit(1 if failures else 0)
func strip_runtime(node):
	var script = node.get_script()
	if script and not script.is_tool(): node.set_script(null)
	for child in node.get_children(): strip_runtime(child)
