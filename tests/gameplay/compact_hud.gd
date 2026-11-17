extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("AppData").demo_mode = true
	var paths := ["HAT_TIRCK/scene/HatrickScene", "FRUIT_BASKET/scene/FruitBasketScene", "RNR/scene/RNRScene", "TUK_TUK/scene/TukTukScene", "PING_PONG/scene/PingPongScene", "BULLOCK_CART/scenes/BullockMotionPreview"]
	for index in paths.size():
		var game = load("res://game/" + paths[index] + ".tscn").instantiate()
		root.add_child(game)
		await process_frame
		await process_frame
		game.set_process(false)
		var overlay = game.get_node("GameUI/Interface/CompactGameHUD" if index == 5 else "UI/CompactGameHUD")
		assert(overlay.score_value.text == "0")
		assert(overlay.remaining_value.text == "01:00")
		assert(overlay.elapsed_value.text == "00:00")
		assert(overlay.trials_value.text == "0")
		assert(overlay.pause_button.icon != null and overlay.exit_button.icon != null)
		assert(root.get_node("DeviceStatusOverlay").badge.text.is_empty())
		game.call("_mp_begin_game" if index == 5 else "_begin_game")
		if index < 5: game._state = game.State.START
		overlay.pause_button.pressed.emit()
		assert(game._mp_pause_panel.visible if index == 5 else game.get_node("UI/PausePanel").visible)
		overlay.pause_button.pressed.emit()
		assert(not game._mp_pause_panel.visible if index == 5 else not game.get_node("UI/PausePanel").visible)
		game.set("_mp_time_left" if index == 5 else "_time_left",42.0)
		game.set("_mp_n_success" if index == 5 else "n_success",3)
		game.set("_mp_n_failure" if index == 5 else "n_failure",2)
		overlay._process(0)
		assert(overlay.score_value.text == "3")
		assert(overlay.trials_value.text == "5")
		assert(overlay.elapsed_value.text == "00:18")
		assert(overlay.remaining_value.text == "00:42")
		game.call("_mp_begin_game" if index == 5 else "_begin_game")
		for state in ["start","pause","results","speed"]:
			if index < 5:
				game.get_node("UI/WaitPanel").visible = state == "start"
				game.get_node("UI/PausePanel").visible = state == "pause"
				game.get_node("UI/GameOverPanel").visible = state == "results"
			else:
				game._mp_wait_panel.visible = state == "start"
				game._mp_pause_panel.visible = state == "pause"
				game._mp_over_panel.visible = state == "results"
				game.mini_hud.show()
			if index < 5: game.get_node("UI/SpeedPanel").visible = state == "speed"
			else: game._mp_speed_panel.visible = state == "speed"
			await create_timer(.3).timeout
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/game-ui-%d-%s.png" % [index,state])
		game.queue_free()
		await process_frame
		print("GAME UI VERIFIED: ",paths[index])
	quit()
