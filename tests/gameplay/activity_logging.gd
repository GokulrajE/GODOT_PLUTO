extends "res://tests/gameplay/arcade_integration.gd"
const Activity = preload("res://scripts/data/DailyActivity.gd")
func _run() -> void:
	app = root.get_node("AppData")
	var dm = root.get_node("DataManager")
	initial_data = _data_hashes("res://data", {})
	dm.data_root = "res://.godot/activity-fixtures/" + str(Time.get_ticks_usec()) + "/"
	_check(dm.create_patient("fixture", "2026-01-01", "2027-01-01", "Right", "TEST"), "create isolated fixture")
	_check(dm.load_patient("fixture"), "load isolated fixture")
	app.config_hoc = 1
	app.config_fps = 1
	for mech in ["HOC", "FPS"]:
		app.set_mechanism(app.MECHANISMS.find(mech))
		for game_name in ["HAT-TRICK", "FRUIT-BASKET", "RNR", "TUK-TUK", "PING-PONG"]:
			app.set_game(game_name)
			app.start_new_trial()
			var raw: String = app.trial_raw_file
			_check(FileAccess.file_exists(raw), "raw file created")
			app.record_active_time(12.5)
			_check(is_equal_approx(app.daily_progress().games[game_name], 12.5), "live per-game time")
			app.stop_trial(5, 3, 2)
			var rows := Activity.read_csv(dm.get_session_path() + "sessions.csv")
			var row: Dictionary = rows.back()
			_check(row.Mechanism == mech and row.GameName == game_name, "mechanism/game isolation")
			_check(float(row.MoveTime) == 12.5, "partial trial records active seconds")
			_check(float(row.SuccessRate) == 60.0 and int(row.CurrentHits) == 3, "hit and success fields")
			_check(row.TrialRawDataFile == raw.get_file(), "session/raw link")
			app.stop_trial(5, 3, 2)
			_check(Activity.read_csv(dm.get_session_path() + "sessions.csv").size() == rows.size(), "stop is idempotent")
			_check(is_equal_approx(app.daily_progress().games[game_name], 12.5), "saved time not double-counted")
		_check(app.daily_progress().complete and is_equal_approx(app.daily_progress().seconds, 62.5), "daily threshold across games")
		_check(not app.daily_progress().estimated, "new logs measured")
		var speed = app.speed_data
		var path: String = dm.get_mech_path() + mech + "-mechparams.csv"
		var hash_before := FileAccess.get_sha256(path)
		speed.set_game_speed(speed.game_speed)
		_check(FileAccess.get_sha256(path) == hash_before, "unchanged speed preserves adaptation date")
		speed.set_game_speed(99)
		_check(speed.game_speed == 40, "manual upper speed limit")
		speed.set_game_speed(-1)
		_check(speed.game_speed == 10, "manual lower speed limit")
	# Three completed training days with four training and one catch sample each.
	var today_unix := int(Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T00:00:00"))
	var baseline := Time.get_datetime_string_from_unix_time(today_unix - 3 * 86400)
	var params := FileAccess.open(dm.get_mech_path() + "FPS-mechparams.csv", FileAccess.WRITE)
	params.store_line("DateTime,Mode,Speed")
	params.store_line(baseline + ",DEFAULT,10")
	params.close()
	for day in 3:
		for trial in 5:
			dm.write_session_row({"DateTime": Time.get_datetime_string_from_unix_time(today_unix - (3-day)*86400), "Mechanism": "FPS", "TrialType": "SR85PCCATCH" if trial == 4 else "SR85PCTRAIN", "SuccessRate": 60+day*10, "CurrentControlBound": 0.6-day*0.1})
	var adapted = load("res://scripts/data/MechanismSpeed.gd").new("FPS")
	_check(is_equal_approx(adapted.game_speed, 11.0), "eligible improved days increase speed ten percent")
	var repeated = load("res://scripts/data/MechanismSpeed.gd").new("FPS")
	_check(is_equal_approx(repeated.game_speed, 11.0), "same-day reload cannot adapt twice")
	for mech in ["HOC", "FPS"]:
		app.set_mechanism(app.MECHANISMS.find(mech))
		for id in GAMES:
			await _load_game(id)
			app.set_game({"hat":"HAT-TRICK", "fruit":"FRUIT-BASKET", "garden":"RNR", "tuk":"TUK-TUK", "pong":"PING-PONG"}[id])
			_tap(KEY_SPACE)
			await _step(120, true)
			var elapsed: float = app.trial_active_seconds
			_check(elapsed > 1.8 and elapsed < 2.1, "active countdown time " + mech + id)
			_tap(KEY_SPACE)
			await _step(60)
			_check(is_equal_approx(app.trial_active_seconds, elapsed), "pause excluded " + mech + id)
			var slow: float = game.call("get_target_end_time", 10.0)
			var fast: float = game.call("get_target_end_time", 40.0)
			_check(fast < slow and fast > 0, "higher speed reduces movement time " + mech + id)
			game.call("_on_exit_pressed")
			await process_frame
			var latest: Dictionary = Activity.read_csv(dm.get_session_path() + "sessions.csv").back()
			_check(absf(float(latest.MoveTime)-elapsed) < 0.01, "early exit saves actual time " + mech + id)
	# Demonstrate the actual UI with measured progress, using only fixture data.
	dm._activity_cache_key = ""
	app.set_game("HAT-TRICK")
	change_scene_to_file("res://scenes/ChooseMechanism.tscn")
	await create_timer(0.3).timeout
	await _capture("daily-mechanism-progress")
	_check(initial_data == _data_hashes("res://data", {}), "real patient data unchanged")
	print("ACTIVITY LOG TESTS: ", checks, " checks, ", failures.size(), " failures")
	var report := FileAccess.open("res://.godot/arcade-test/activity-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	quit(0 if failures.is_empty() else 1)
