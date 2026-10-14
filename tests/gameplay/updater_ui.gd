extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: ", label)
func run() -> void:
	var updater = root.get_node("AppUpdater")
	updater.cache_path = "res://.godot/update-fixtures/" + str(Time.get_ticks_usec()) + "/"
	DirAccess.make_dir_recursive_absolute(updater.cache_path)
	check(updater.newer("v1.0.1", "1.0.0"), "patch version")
	check(updater.newer("1.10.0", "1.9.9"), "numeric comparison")
	check(not updater.newer("1.0.0", "1.0.0"), "same version")
	check(not updater.newer("0.9.9", "1.0.0"), "no downgrade")
	check(not updater.newer("1.1.0-beta", "1.0.0"), "no beta version")
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(.3).timeout
	updater.enabled = true
	updater._set_state("checking", "Checking…")
	check(current_scene.get_node("%LoginButton").disabled, "login disabled while checking")
	check(current_scene.get_node("DemoButton").disabled, "demo cannot bypass gate")
	updater._unavailable("Offline")
	check(not updater.blocks_login(), "offline allowed before update detected")
	var release := {"tag_name":"v1.0.1", "assets":[{"name":"PLUTO-windows-x86_64.zip", "browser_download_url":"https://github.com/GokulrajE/GODOT_PLUTO/releases/download/v1.0.1/PLUTO-windows-x86_64.zip", "size":1024, "digest":"sha256:" + "a".repeat(64)}]}
	check(not updater.release_asset(release).is_empty(), "valid Windows asset")
	var invalid := release.duplicate(true)
	invalid.assets[0].browser_download_url = "https://example.com/package.zip"
	check(updater.release_asset(invalid).is_empty(), "reject unrelated download host")
	invalid = release.duplicate(true)
	invalid.assets[0].digest = ""
	check(updater.release_asset(invalid).is_empty(), "checksum required")
	updater.accept_release(release)
	check(updater.blocks_login(), "new version blocks login")
	check(FileAccess.file_exists(updater.cache_path + "required.json"), "required update persisted")
	updater._unavailable("Offline")
	check(updater.blocks_login(), "offline cannot bypass known update")
	updater._set_state("downloading", "Downloading…")
	updater.total = 100
	updater.downloaded = 50
	updater.changed.emit()
	check(current_scene.get_node("UpdatePanel/UpdateProgress").value == 50, "download progress")
	check(current_scene.get_node("%RegisterButton").disabled, "registration gated")
	updater._set_state("required", "Update v1.0.1 is required before login.\nDownload, install and restart to continue.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arcade-test/update-required.png")
	updater.request = HTTPRequest.new()
	updater.add_child(updater.request)
	updater._downloaded(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(updater.blocks_login(), "download interruption stays gated")
	updater.stage = updater.cache_path + "corrupt.zip"
	var corrupt := FileAccess.open(updater.stage, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	updater.request = HTTPRequest.new()
	updater.add_child(updater.request)
	updater._downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	check(updater.blocks_login() and updater.message.contains("verification failed"), "checksum failure stays gated")
	updater.release = {}
	updater.accept_release({"tag_name":"v1.0.0", "assets":[]})
	check(not updater.blocks_login(), "current version enables login")
	updater.enabled = false
	print("UPDATER UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
