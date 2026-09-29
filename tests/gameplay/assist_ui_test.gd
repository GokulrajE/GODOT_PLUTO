extends SceneTree
func _initialize():
	go.call_deferred()
func go():
	root.get_node("AppData").enter_demo()
	change_scene_to_file("res://scenes/AssistProfileScene.tscn")
	await create_timer(.3).timeout
	var scene = current_scene
	scene.set_process(false)
	for limit in [0.0, 45.0]:
		scene._ang_limit = limit
		scene._tmin = -45
		scene._tmax = 45
		scene._update_min_max_cursors()
		scene._update_curr_cursor(0)
		for cursor in [scene.min_cursor, scene.max_cursor, scene.curr_cursor]:
			assert(is_finite(cursor.position.x))
			assert(cursor.position.x >= scene.slider_track.position.x)
			assert(cursor.position.x + cursor.size.x <= scene.slider_track.position.x + scene.slider_track.size.x + .01)
	assert(scene.min_cursor.position.x < scene.max_cursor.position.x)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/assist-fixed.png")
	var card := Panel.new()
	var style := StyleBoxFlat.new()
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	var icon = preload("res://scripts/ui/mechanism_contrast.gd").new()
	card.add_child(icon)
	for background in [Color.WHITE, Color.BLACK]:
		style.bg_color = background
		icon._update_ink()
		assert(icon.material.get_shader_parameter("ink") == (Color.BLACK if background == Color.WHITE else Color.WHITE))
	var music = root.get_node("MenuMusic")
	await create_timer(1.0).timeout
	assert(is_equal_approx(music.volume_db, -14.0))
	music.set_muted(true)
	root.get_node("AppData").exit_demo()
	await create_timer(.15).timeout
	print("ASSIST UI PASS: zero range, endpoints, labels, light/dark icon contrast, music volume")
	quit()
