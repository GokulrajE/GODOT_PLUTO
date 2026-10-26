extends SceneTree
func _initialize(): run.call_deferred()
func run():
	assert(ProjectSettings.get_setting("application/config/version") == "1.0.8")
	assert(ProjectSettings.get_setting("display/window/size/mode") == 3)
	assert(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand")
	assert(FileAccess.get_file_as_bytes("res://tools/update/bin/PLUTOUpdater.exe").size() > 1000000)
	assert(change_scene_to_file("res://scenes/MainScene.tscn") == OK)
	await create_timer(.5).timeout
	assert(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND)
	print("EXPORTED FULL HD STARTUP: PASS; version 1.0.8, fullscreen, expand, updater present")
	quit()
