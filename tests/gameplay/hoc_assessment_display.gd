extends SceneTree
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)
func run() -> void:
	var app = root.get_node("AppData")
	app.enter_demo()
	app.set_mechanism(4)
	var scene = load("res://scenes/AssessmentScene.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	for sample in [[-93.0, 0.0], [-46.5, 0.5], [0.0, 1.0], [-150.0, 0.0], [20.0, 1.0]]:
		check(is_equal_approx(scene._display_fraction(sample[0]), sample[1]), "HOC full-width mapping " + str(sample))
	check(is_finite(scene._display_fraction(NAN)), "invalid sample guarded")
	scene._update_arom_cursors(-93.0, 0.0)
	scene._update_prom_cursors(-93.0, 0.0)
	for prefix in ["arom", "prom"]:
		var track = scene.get(prefix + "_track")
		var lo = scene.get(prefix + "_min_cursor")
		var hi = scene.get(prefix + "_max_cursor")
		check(is_equal_approx(lo.position.x + lo.size.x / 2.0, track.position.x), prefix + " open at left")
		check(is_equal_approx(hi.position.x + hi.size.x / 2.0, track.position.x + track.size.x), prefix + " closed at right")
		check(not scene.get(prefix + "_center_label").visible, prefix + " no misleading centre Closed label")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/arcade-test/hoc-full-width.png")
	scene.set("_arom_selected", true)
	scene.arom_curr_cursor.visible = true
	scene._update_curr_cursor(0.0)
	check(is_equal_approx(scene.arom_curr_cursor.position.x + scene.arom_curr_cursor.size.x / 2.0, scene.arom_track.position.x + scene.arom_track.size.x), "live closed cursor at right")
	scene._update_curr_cursor(-93.0)
	check(is_equal_approx(scene.arom_curr_cursor.position.x + scene.arom_curr_cursor.size.x / 2.0, scene.arom_track.position.x), "live open cursor at left")
	check(scene.get_node("AromPanel/AngleUnitLabel").text == "centimetres", "HOC units")
	app.calib_angle = 0
	check(is_finite(scene._display_fraction(0.0)), "missing calibration guarded")
	app.set_mechanism(3)
	scene.set("_ang_limit", 100.0)
	for sample in [[-100.0, 0.0], [0.0, 0.5], [100.0, 1.0]]:
		check(is_equal_approx(scene._display_fraction(sample[0]), sample[1]), "symmetric mechanism preserved")
	print("HOC DISPLAY: ", checks, " checks, ", failures.size(), " failures")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
