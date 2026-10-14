extends "res://tests/gameplay/arcade_integration.gd"
func _run() -> void:
	app = root.get_node("AppData")
	var dm = root.get_node("DataManager")
	var original := _data_hashes("res://data", {})
	dm.data_root = "res://.godot/time-ring-fixtures/" + str(Time.get_ticks_usec()) + "/"
	_check(dm.create_patient("fixture", "2026-01-01", "2027-01-01", "Right", "TEST"), "fixture created")
	_check(dm.load_patient("fixture"), "fixture loaded")
	for mech in ["wfe", "wurd", "fps", "hoc", "fme1", "fme2"]: app.set("config_" + mech, 2)
	var today := Time.get_date_string_from_system()
	dm.write_active_time("hoc-fixture.csv", "HOC", "HAT-TRICK", {today: 90.0})
	dm.write_active_time("fps-fixture.csv", "FPS", "PING-PONG", {today: 150.0})
	change_scene_to_file("res://scenes/ChooseMechanism.tscn")
	await create_timer(0.9).timeout
	for mech in ["WFE", "WURD", "FPS", "HOC", "FME1", "FME2"]:
		var button = current_scene.get_node("MechGrid/" + mech)
		var widget = button.find_child("DailyTime", true, false)
		_check(widget != null, mech + " time widget")
		_check(button.get_global_rect().encloses(widget.get_global_rect()), mech + " time fits card")
		var expected := 1.0 if mech == "FPS" else (0.75 if mech == "HOC" else 0.0)
		_check(is_equal_approx(widget.fraction, expected), mech + " animated ring target")
	var hoc = current_scene.get_node("MechGrid/HOC").find_child("DailyTime", true, false)
	_check(hoc.elapsed == 90.0 and hoc.goal == 120.0, "actual time and target stay exact")
	ProjectSettings.set_setting("pluto/ui/reduced_motion", true)
	hoc.fraction = 0.0
	hoc._update_time()
	_check(hoc.fraction == 0.75, "reduced motion applies target immediately")
	ProjectSettings.set_setting("pluto/ui/reduced_motion", false)
	await _capture("mechanism-3d-time")
	_check(original == _data_hashes("res://data", {}), "patient records unchanged")
	print("TIME RINGS: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
