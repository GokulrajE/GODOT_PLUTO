extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("AppData").demo_mode = true
	for path in ["MainScene", "ChooseMechanism", "CalibrationScene", "AssessmentScene", "ChooseGameScene"]:
		var scene = load("res://scenes/" + path + ".tscn").instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/refinement-" + path + ".png")
		print("REFINEMENT LOADED: ", path)
		scene.queue_free()
		await process_frame
	print("FIVE SCREEN SMOKE CHECK COMPLETE")
	quit()
