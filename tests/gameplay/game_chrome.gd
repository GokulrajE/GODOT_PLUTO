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
