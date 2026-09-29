extends SceneTree
var checks := 0
var failures: Array[String] = []
var awards := 0
var completions := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/arcade-test/" + label + ".png")
func _run() -> void:
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(0.4).timeout
	var toggle: CheckButton = current_scene.get_node("ReducedMotion")
	toggle.button_pressed = true
	_check(bool(ProjectSettings.get_setting("pluto/ui/reduced_motion")), "reduced motion control works")
	toggle.button_pressed = false
	await _capture("main-final")
	current_scene.get_node("DemoButton").pressed.emit()
	await create_timer(0.4).timeout
	_check(root.get_node("AppData").demo_mode, "demo entry through opening screen")
	_check(current_scene.scene_file_path.ends_with("ChooseGameScene.tscn"), "demo opens game picker")
	root.get_node("AppData").exit_demo()
	change_scene_to_file("res://scenes/RegisterScene.tscn")
	await create_timer(0.4).timeout
	var field: LineEdit = current_scene.get("start_date_input")
	current_scene.call("_show_calendar", field)
	await create_timer(0.2).timeout
	var calendar: Control = current_scene.get("_cal_popup")
	_check(calendar.visible, "calendar opens")
	_check(Rect2(Vector2.ZERO, current_scene.size).encloses(calendar.get_rect()), "calendar stays within screen")
	current_scene.set("_cal_month", 12)
	current_scene.set("_cal_year", 2026)
	current_scene.call("_cal_next_month")
	_check(current_scene.get("_cal_month") == 1 and current_scene.get("_cal_year") == 2027, "calendar crosses year")
	for day in current_scene.get("_cal_day_btns"):
		if day.visible and not day.text.is_empty(): _check(calendar.get_global_rect().encloses(day.get_global_rect()), "calendar day contained")
	await _capture("calendar-final")
	var days: Array = current_scene.get("_cal_day_btns")
	for i in days.size():
		if days[i].text == "15": current_scene.call("_cal_day_pressed", i)
	_check(field.text == "2027-01-15" and not calendar.visible, "date selection updates field")
	_check(current_scene.call("_days_in_month", 2028, 2) == 29, "leap year calendar")
	var card = load("res://scenes/CelebrationCard.tscn").instantiate()
	current_scene.add_child(card)
	card.star_reached_header.connect(func(): awards += 1)
	card.celebration_done.connect(func(): completions += 1)
	await process_frame
	for reduced in [false, true]:
		ProjectSettings.set_setting("pluto/ui/reduced_motion", reduced)
		var previous := awards
		card.show_celebration(5, 8, Rect2(1030, 25, 38, 38))
		card.show_celebration(5, 8, Rect2(1030, 25, 38, 38))
		await create_timer(0.45).timeout
		_check(card.visible, "reward visible")
		_check(card.get_node("Overlay").visible, "reward dimmer visible")
		_check(Rect2(Vector2.ZERO, current_scene.size).encloses(card.get_node("Card").get_rect()), "reward card contained")
		await _capture("reward-reduced" if reduced else "reward-animated")
		await create_timer(2.5).timeout
		_check(not card.visible and awards == previous + 1 and completions == awards, "reward finishes once")
	ProjectSettings.set_setting("pluto/ui/reduced_motion", false)
	var file := FileAccess.open("res://.godot/arcade-test/ui-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("UI INTERACTIONS: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
