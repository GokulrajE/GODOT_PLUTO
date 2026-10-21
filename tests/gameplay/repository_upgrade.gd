extends SceneTree
var last_state := ""
## Run only in an isolated exported installation/profile. Downloads the real
## repository release, then replaces this disposable installation and exits.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var updater = root.get_node("AppUpdater")
	# Exercise a genuine newer-release response without publishing a test tag.
	ProjectSettings.set_setting("application/config/version", "1.0.5")
	updater.enabled = true
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(0.3).timeout
	updater.changed.connect(func():
		if updater.state != last_state:
			last_state = updater.state
			print("REPOSITORY TEST: ", updater.state, " ", updater.message)
	)
	var deadline := Time.get_ticks_msec() + 30000
	while updater.checking and Time.get_ticks_msec() < deadline:
		await create_timer(0.2).timeout
	if updater.state != "required" or updater.release_asset(updater.release).is_empty():
		printerr("Repository release check failed: ", updater.message)
		quit(1)
		return
	if current_scene.get_node("%LoginButton").disabled:
		printerr("Update unexpectedly blocked login")
		quit(1)
		return
	updater.download_update()
	deadline = Time.get_ticks_msec() + 600000
	while updater.state == "downloading" and Time.get_ticks_msec() < deadline:
		await create_timer(0.5).timeout
	if updater.state != "downloaded" or updater.blocks_login():
		printerr("Download verification or optional-login check failed: ", updater.message)
		quit(1)
		return
	print("REPOSITORY TEST: verified ZIP; login available; explicitly requesting install")
	updater.install_download()
	await create_timer(150).timeout
	printerr("Installer did not close test app: ", updater.message)
	quit(1)
