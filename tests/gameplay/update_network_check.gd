extends SceneTree
## Explicit live-network diagnostic; run manually, not in offline regression suites.
func _initialize(): run.call_deferred()
func run():
	var updater = root.get_node("AppUpdater")
	updater.enabled = true
	updater.check_updates()
	while updater.checking: await process_frame
	print("Updater: ", updater.state, " — ", updater.message)
	quit(0 if updater.state in ["current", "required"] else 1)
