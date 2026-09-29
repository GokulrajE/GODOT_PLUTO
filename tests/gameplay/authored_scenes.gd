extends SceneTree
## Verify saved scenes with gameplay and UIManager scripts disabled, like editor display.
const SCENES = preload("res://scripts/ui/preview_ui.gd").SCENES
var checks := 0
var failures: Array[String] = []
func _initialize():
	go.call_deferred()
func strip_runtime(node: Node) -> void:
	var script = node.get_script()
	if script and not script.is_tool(): node.set_script(null)
	for child in node.get_children(): strip_runtime(child)
func go():
	var manager = root.get_node("UIManager")
	manager.set_process(false)
	node_added.disconnect(Callable(manager, "_on_node_added"))
	DirAccess.make_dir_recursive_absolute("res://.godot/authored-preview")
	var paths: Array = SCENES.duplicate()
	paths.append("res://scenes/CelebrationCard.tscn")
	for path in paths:
		var packed: PackedScene = load(path)
		var scene: Control = packed.instantiate()
		var game: bool = path.begins_with("res://game/")
		preload("res://scripts/gameplay/playfield_layout.gd").configure(root, game)
		strip_runtime(scene)
		root.add_child(scene)
		await create_timer(.15).timeout
		checks += 1
		var expected: String = "ArcadeGameBackground" if game else "ArcadeBackdrop"
		var ok := scene.has_meta("arcade_authored") and (scene.has_node(expected) or scene.name == "CelebrationCard")
		if not game and scene.name != "CelebrationCard":
			var backdrop = scene.get_node("ArcadeBackdrop")
			ok = ok and backdrop is TextureRect and backdrop.texture != null and backdrop.get_script() == null
		if not ok: failures.append(path)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/authored-preview/" + path.get_file().get_basename() + ".png")
		print("SAVED SCENE ", "PASS: " if ok else "FAIL: ", path, " (", packed.get_state().get_node_count(), " nodes)")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	var report := FileAccess.open("res://.godot/authored-preview/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "runtime_styling_disabled": true}, "\t"))
	quit(0 if failures.is_empty() else 1)
