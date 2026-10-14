extends "res://tests/gameplay/arcade_integration.gd"
## Rendered frame sampling, separate from accelerated gameplay checks.
func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 800)
	app = root.get_node("AppData")
	app.enter_demo()
	var timings := {}
	for id in GAMES:
		await _load_game(id)
		_tap(KEY_SPACE)
		await _step(120, true)
		var samples: Array[float] = []
		var last := Time.get_ticks_usec()
		for frame in 240:
			_pilot()
			game.call("_process", 1.0 / 60.0)
			view.call("_process", 1.0 / 60.0)
			await process_frame
			var now := Time.get_ticks_usec()
			if frame >= 60: samples.append(float(now - last) / 1000.0)
			last = now
			if id == "hat" and is_instance_valid(game.get("_current_ball")):
				_check(game.get("_current_ball").size.is_equal_approx(Vector2(80, 80)), "consistent medium ball")
		if id == "garden":
			game.set("_state", 3)
			game.set("_is_raining", true)
			game.set("_rain_emit_clock", 0.0)
			for drop in game.get("_drop_nodes"): drop.hide()
			game.call("_animate_visuals", 0.03)
			var visible := 0
			for drop in game.get("_drop_nodes"):
				if drop.visible: visible += 1
			_check(visible == 1, "rain begins with one drop, not whole column")
			game.call("_animate_visuals", 0.03)
			var ys: Array[float] = []
			for drop in game.get("_drop_nodes"):
				if drop.visible: ys.append(drop.position.y)
			_check(ys.size() == 2 and absf(ys[0] - ys[1]) > 10, "drops descend at staggered heights")
			game.set("_state", 4)
			for frame in 24: game.call("_animate_visuals", 1.0 / 60.0)
			var rain_count := 0
			for drop in game.get("_drop_nodes"):
				if drop.visible: rain_count += 1
			_check(rain_count >= 12 and rain_count < 48, "dense staggered shower continues during growth feedback")

		samples.sort()
		var over_budget := 0
		for ms in samples:
			if ms > 25.0: over_budget += 1
		timings[id] = {"median_ms": samples[samples.size()/2], "p95_ms": samples[int(samples.size()*0.95)], "max_ms": samples.back(), "frames_over_25ms": over_budget, "sample_count": samples.size()}
		print("FRAME PACING ", id, ": ", timings[id])
		await _capture(id + "-motion-review")
	var file := FileAccess.open("res://.godot/arcade-test/frame-pacing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"timings": timings, "failures": failures, "checks": checks}, "\t"))
	root.get_node("MenuMusic").set_process(false)
	print("MOTION CHECKS: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
