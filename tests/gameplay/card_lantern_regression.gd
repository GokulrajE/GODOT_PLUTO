extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("AppData").demo_mode = true
	var picker = load("res://scenes/ChooseGameScene.tscn").instantiate()
	root.add_child(picker)
	await process_frame
	await process_frame
	var grid = picker.get_node("GameGrid")
	assert(grid.get_child_count() == 6)
	for card in grid.get_children():
		assert(card.size.y >= 220)
		assert(picker.get_global_rect().encloses(card.get_global_rect()))
	var race = load("res://game/BULLOCK_CART/scripts/lane_race.gd").new()
	race.reset()
	race.automatic_pickup_recycling = false
	race.timed_mode = true
	race.pickups.clear()
	race.pickups.append({"id":0,"distance":0.1,"x":0.0,"lane":2,"kind":"power","owner":-1})
	race.racers[0].speed = 8
	race.advance(.1,0)
	assert(race.pickups[0].owner == 0)
	assert(is_equal_approx(race.pickups[0].distance,0.1))
	assert(race.racers[0].boost > 0)
	var game = load("res://game/BULLOCK_CART/scenes/BullockMotionPreview.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._mp_begin_game()
	var kinds := {}
	var regions := {}
	for i in 10:
		game._mp_state = game.MPState.SPAWN_TARGET
		game._mp_tick(.016)
		kinds[game.race.pickups[0].kind] = true
		regions[str(game.targets[0].get_node("v_power").texture.region)] = true
		assert(game.targets[0].position.z < 0)
	assert(kinds.size() == 3)
	assert(regions.size() == 4)
	for speed in [10.0,40.0]:
		game._mp_game_speed = speed
		game._mp_recalc_from_speed()
		game._mp_state = game.MPState.SPAWN_TARGET
		game._mp_tick(.01)
		var duration: float = game._mp_move_duration
		for frame in int(round(duration * 100)) - 1: game._mp_tick(.01)
		assert(game._mp_state == game.MPState.MOVE)
		game._mp_tick(.02)
		assert(game._mp_state in [game.MPState.SUCCESS,game.MPState.FAILURE])
		game._mp_tick(.41)
		assert(game._mp_state == game.MPState.SPAWN_TARGET)
		print("Speed ",speed," arrival ",duration," interval ",duration + .4)
	assert(game._mp_lane_indicator == null)
	game.free()
	print("CARD AND LANTERN CHECKS PASSED: six cards, ten spawns, three kinds, four lantern variants")
	picker.free()
	quit()

