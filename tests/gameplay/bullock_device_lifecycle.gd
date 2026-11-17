extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app = root.get_node("AppData")
	var dm = root.get_node("DataManager")
	var comm = root.get_node("PlutoComm")
	var bus = root.get_node("EventBus")
	dm.data_root = "res://.godot/bullock-fixtures/" + str(Time.get_ticks_usec()) + "/"
	check(dm.create_patient("fixture", "2026-01-01", "2027-01-01", "Right", "TEST"), "fixture")
	dm.load_patient("fixture")
	app.set_mechanism(1)
	app.selected_mechanism.set_new_prom(-45,45)
	app.selected_mechanism.set_new_arom(-30,30)
	app.selected_mechanism.set_new_aprom(-45,45)
	comm.is_connected = true
	comm.is_streaming = true
	var game = load("res://game/BULLOCK_CART/scenes/BullockMotionPreview.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_ride(false)
	check(app.selected_game_name == "BULLOCK-CART", "game identity")
	check(game.aan_enabled, "AAN enabled")
	game.step(.1,0)
	check(game.aan.target_position != 0, "collectible mapped to angle")
	var raw: String = app.trial_raw_file
	bus.new_sensor_data.emit()
	var elapsed: float = app.trial_active_seconds
	bus.button_released.emit()
	check(game.paused and app.log_game_state == "PAUSED", "device pause")
	game._pause()
	check(game.paused, "repeated pause remains paused")
	game.step(.1,0)
	check(app.trial_active_seconds == elapsed, "pause excludes active time")
	bus.new_sensor_data.emit()
	bus.button_released.emit()
	check(not game.paused, "device resume")
	game.step(.1,0)
	check(app.trial_active_seconds > elapsed, "resume time")
	comm.is_connected = false
	game.step(.1,0)
	check(game.paused, "disconnect pauses")
	game._play()
	check(game.paused, "disconnected resume blocked")
	comm.is_connected = true
	game._play()
	game.step(.1,0)
	for kind in ["power", "rare", "power3x"]:
		game.race._award_pickup(0,{"kind":kind,"id":0})
		check(game.race.racers[0].boost > 0, "automatic boost " + kind)
	# Cross a real collectible at its lane and verify counts and automatic boost.
	var pickup: Dictionary = game.race.pickups[0]
	game.race.racers[0].distance = pickup.distance - .05
	game.race.racers[0].x = pickup.x
	game.race.racers[0].lane = pickup.lane
	game.race.racers[0].speed = 8.0
	game.step(.1, 0)
	check(game.hits == 1 and game.encountered.size() == 1, "collection counted once")
	check(game.race.racers[0].boost > 0, "collection activates boost")
	game.finish_ride()
	check(app.trial_start_time.is_empty(), "finish closes trial")
	var csv := FileAccess.get_file_as_string(raw)
	check(csv.contains("PAUSED") and csv.contains("MOVE"), "raw lifecycle rows")
	game.start_ride(false)
	check(game.hits == 0 and game.encountered.is_empty(), "replay resets counts")
	game.step(.1,0)
	game._pause()
	game.free()
	check(app.trial_start_time.is_empty(), "paused exit closes trial")
	app.set_game("HAT-TRICK")
	var hat = load("res://game/HAT_TIRCK/scene/HatrickScene.tscn").instantiate()
	root.add_child(hat)
	hat.set_process(false)
	hat._begin_game()
	hat._state = hat.State.MOVE
	hat._toggle_pause()
	check(app.log_game_state == "PAUSED", "hat pause log")
	hat._toggle_pause()
	check(hat._state == hat.State.MOVE, "hat resume state")
	hat.free()
	check(app.trial_start_time.is_empty(), "hat unexpected exit closes trial")
	# Exercise AAN target classifications, CPM, boundary and voluntary stall.
	var aan = load("res://scripts/PlutoAAN.gd").new()
	aan.arom = [-30.0,30.0]
	aan.prom = [-45.0,45.0]
	for pair in [[0.0,20.0],[40.0,20.0],[0.0,40.0],[40.0,-40.0],[40.0,42.0]]:
		aan.reset_trial()
		aan.set_new_trial_details(pair[0],pair[1],4.0,10.0)
		aan.update(pair[0],.1,false)
		check(aan.state != aan.State.NEW_TRIAL_TARGET_SET, "target classification " + str(pair))
	aan.reset_trial()
	aan.set_new_trial_details(0,40,4,10)
	aan.update(0,.1,false)
	aan.update(0,.1,false)
	for i in 20: aan.update(16,.1,false)
	check(aan.state == aan.State.ASSIST_TO_TARGET_IN_BOUNDARY, "voluntary stall assists")
	aan.arom = [0.0,0.0]
	aan.reset_trial()
	aan.set_new_trial_details(0,40,4,10)
	aan.update(0,.1,false)
	check(aan.state == aan.State.ASSIST_TO_TARGET_AT_BOUNDARY, "CPM assists")
	aan.update(40,.1,true)
	check(aan.state == aan.State.IDLE, "CPM completes")
	comm.is_connected = false
	comm.is_streaming = false
	print("DEVICE LIFECYCLE: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
