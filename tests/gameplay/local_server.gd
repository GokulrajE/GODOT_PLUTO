extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var server = root.get_node("LocalServer")
	server.set_process(false)
	check(not server.enabled, "tests do not contact agent")
	server.settings.patients_file = ""
	check(server.patients_path() == "C:/NeuroDash/patients.json", "existing Windows sender path")
	server.patients = [
		{"user_id":"A101", "status":"active", "devices":["PLUTO"]},
		{"user_id":"a102", "status":"active", "assessment_devices":["PLUTO"]},
		{"user_id":"A103", "status":"active", "devices":["MARS"]},
		{"user_id":"A104", "status":"paused", "devices":["PLUTO"]}]
	check(server.suggestions("A", "devices") == ["A101"], "A matches training IDs only")
	check(server.suggestions("A", "assessment_devices") == ["a102"], "A matches lowercase assessment ID")
	server.enabled = true
	change_scene_to_file("res://scenes/MainScene.tscn")
	await create_timer(.2).timeout
	current_scene.get_node("%PatientIDInput").text = "A"
	current_scene._refresh_patient_matches()
	check(current_scene.get_node("%PatientMatches").get_item_text(0) == "A101", "typing A renders suggestion")
	check(current_scene.get_node_or_null("%PatientGroup") == null, "assessment selector removed")
	check(not await server.start_patient("a102", "assessment_devices"), "assessment-only login rejected before agent call")
	check(current_scene.get_node("%RefreshPatients").visible, "refresh control visible")
	var matches = current_scene.get_node("%PatientMatches")
	check(matches.get_theme_color("font_hovered_color").r < 0.2, "hover text stays dark")
	check(matches.get_theme_stylebox("hovered").bg_color.r < 0.9, "hover background is teal rather than white")
	server.settings.sender_path = "user://missing-sender.py"
	check(not await server.refresh_patients(), "missing sender handled without a process")
	check(not server.refreshing_patients, "failed refresh remains retryable")
	server.settings.erase("sender_path")
	var manager = root.get_node("DataManager")
	var local_id := "LOCAL_TEST_%d" % Time.get_ticks_usec()
	check(manager.create_patient(local_id, "2026-10-22", "", "Right", "Test"), "local registration saved")
	check(local_id in server.suggestions("LOCAL_TEST_", "devices"), "local ID appears in suggestions")
	check(await server.start_patient(local_id, "devices"), "local login succeeds without agent")
	check(server.local_session, "local session identified")
	check(manager.load_patient(local_id), "local patient record loads")
	var original := FileAccess.get_file_as_string(manager.data_root + local_id + "/configdata")
	var exported: String = manager.export_server_config(local_id)
	check(not exported.is_empty(), "configdata CSV exported")
	var config := FileAccess.open(exported, FileAccess.READ)
	var columns := config.get_csv_line()
	var values := config.get_csv_line()
	config.close()
	check(columns[-1] == "HomerID" and values[-1] == local_id, "server patient routing preserved")
	check(FileAccess.get_file_as_string(manager.data_root + local_id + "/configdata") == original, "local config unchanged")
	server.load_patients()
	print("Existing JSON: %d matching training IDs and %d assessment IDs for prefix A" % [server.suggestions("A", "devices").size(), server.suggestions("A", "assessment_devices").size()])
	server.enabled = false
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
		node.stream = null
	await process_frame
	print("PATIENT JSON: 20 checks, %d failures" % failures)
	quit(1 if failures else 0)

