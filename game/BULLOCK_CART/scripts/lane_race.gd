extends "res://game/BULLOCK_CART/scripts/motion_race.gd"
## Five-lane catch-and-overtake race. All carts share movement and pickup rules.
const LANE_WIDTH := 2.8
const ROAD_WIDTH := LANE_WIDTH * 5
const LEVELS := ["Practice", "Easy race", "Standard race", "Challenge"]
const LEVEL_HELP := [
	"3 lanes • No rivals • Plenty of time to steer",
	"3 lanes • Slower rivals • Generous booster reach",
	"5 lanes • Balanced rivals • New routes every race",
	"5 lanes • Quicker rival decisions • More route choices",
]
var difficulty := 2
var layout_seed := 0
var actual_seed := 0
var rng := RandomNumberGenerator.new()
var lane_min := 0
var lane_max := 4
var input_direction := 0

func section_name(distance: float) -> String:
	if distance < 140: return "FIND YOUR RHYTHM"
	if distance < 330: return "CHASE & OVERTAKE"
	return "FINAL SPRINT"

func lane_x(lane: int) -> float:
	return (clampi(lane, 0, 4) - 2) * LANE_WIDTH

func reset() -> void:
	super.reset()
	difficulty = clampi(difficulty, 0, 3)
	lane_min = 1 if difficulty <= 1 else 0
	lane_max = 3 if difficulty <= 1 else 4
	road_limit = lane_x(lane_max)
	if layout_seed == 0: rng.randomize()
	else: rng.seed = layout_seed
	actual_seed = rng.seed
	input_direction = 0
	# Rivals shadow the player: they track the player's position and adjust speed
	# proportionally. rival_max caps how fast they can go — player must use boosts to escape.
	const RIVAL_MAX: Array = [
		[0.0, 0.0],
		[8.5, 9.0],     # easy   — slightly above base speed
		[10.5, 11.0],   # standard — player needs one boost to pull clear
		[12.0, 12.8],   # challenge — only rare/3x fully escapes
	]
	const RIVAL_MIN: Array = [
		[0.0, 0.0],
		[5.5, 5.5],
		[6.0, 6.0],
		[6.5, 6.5],
	]
	for i in racers.size():
		var racer: Dictionary = racers[i]
		racer.lane = [2, 1, 3][i]
		racer.x = lane_x(racer.lane)
		racer.distance = [0.0, 10.0, 5.0][i]
		racer.think_time = [.0, .65, .9][i]
		racer.boosters = 0
		racer.draft_charge = 0.0
		racer.draft_lane = racer.lane
		racer.slingshot = 0.0
		racer.rival_max = RIVAL_MAX[difficulty][maxi(0, i - 1)] if i > 0 else 0.0
		racer.rival_min = RIVAL_MIN[difficulty][maxi(0, i - 1)] if i > 0 else 0.0
		if difficulty == 0 and i > 0:
			racer.finish = 0.0
			racer.distance = 0.0
	pickups.clear()
	var lane := 2
	var distance := 32.0
	var row := 0
	var spacing: float = [40.0, 36.0, 30.0, 26.0][difficulty]
	# Rare/3x slots: row 5 and 15 → rare; row 10 → power3x
	while distance < LENGTH - 12:
		# Pick any lane except the one just used — spreads across all lanes without repeating
		var choices: Array[int] = []
		for l in range(lane_min, lane_max + 1):
			if l != lane: choices.append(l)
		lane = choices[rng.randi() % choices.size()]
		var kind := "power"
		if row == 5 or row == 15: kind = "rare"
		elif row == 10: kind = "power3x"
		_add_pickup(distance, lane, kind)
		pickups[-1].primary = true
		var breathing_room := 12.0 if distance >= 140 and distance < 330 and row % 3 == 2 else (2.0 if distance < 140 else 0.0)
		distance += spacing + breathing_room + rng.randf_range(0, 4)
		row += 1

func order() -> Array[int]:
	if difficulty == 0: return [0]
	# Score-based when timed; finish-time when distance race (timed_mode=false fallback)
	var indices: Array[int] = [0, 1, 2]
	if timed_mode:
		indices.sort_custom(func(a: int, b: int):
			if racers[a].score != racers[b].score: return racers[a].score > racers[b].score
			return racers[a].distance > racers[b].distance)
	else:
		indices.sort_custom(func(a: int, b: int):
			if racers[a].finish >= 0 and racers[b].finish >= 0: return racers[a].finish < racers[b].finish
			if racers[a].finish >= 0: return true
			if racers[b].finish >= 0: return false
			return racers[a].distance > racers[b].distance)
	return indices

func _recycle_pickups() -> void:
	var leader: float = 0.0
	for racer in racers: leader = maxf(leader, racer.distance)
	var player_dist: float = racers[0].distance
	# Start the recycled chain at least 200 m ahead of the leader.
	var furthest: float = leader + 200.0
	for p in pickups:
		if p.owner < 0 and p.distance > player_dist - 10.0:
			furthest = maxf(furthest, p.distance)
	for pickup in pickups:
		# Only recycle once the player has passed it — rivals passing through must not trigger this
		var player_passed: bool = pickup.distance < player_dist - 10.0
		var player_collected: bool = pickup.owner == 0
		if player_passed or player_collected:
			furthest += rng.randf_range(22.0, 38.0)
			pickup.distance = furthest
			pickup.owner = -1

func _tick(dt: float, steering: float) -> void:
	super._tick(dt, steering)
	if timed_mode:
		complete = elapsed >= game_duration
		if not complete: _recycle_pickups()
	else:
		complete = elapsed >= TIME_LIMIT
		var all_finished := true
		for index in order():
			if racers[index].finish < 0: all_finished = false
			else:
				racers[index].boost = 0.0
				racers[index].speed = 0.0
				racers[index].draft_charge = 0.0
				racers[index].slingshot = 0.0
				racers[index].drafting = false
		complete = complete or all_finished

func _pickup_reach() -> float:
	return 1.25 if difficulty <= 1 else .95

func _add_pickup(distance: float, lane: int, kind: String) -> void:
	pickups.append({"id": pickups.size(), "distance": distance, "x": lane_x(lane), "lane": lane, "kind": kind, "owner": -1})

func advance(delta: float, steering: float) -> void:
	if complete or delta <= 0: return
	var direction := int(signf(steering))
	if direction != 0 and direction != input_direction and racers[0].finish < 0:
		racers[0].lane = clampi(racers[0].lane + direction, lane_min, lane_max)
	input_direction = direction
	super.advance(delta, 0)

func activate_boost(_index: int) -> bool:
	return false

func _award_pickup(winner: int, pickup: Dictionary) -> void:
	# Rivals don't collect — reset pickup so the player can still grab it
	if winner > 0:
		pickup.owner = -1
		return
	var racer: Dictionary = racers[winner]
	if pickup.kind not in ["power", "rare", "power3x"]: return
	match pickup.kind:
		"power3x": racer.boost = BOOST_3X_SECONDS
		"rare":    racer.boost = BOOST_RARE_SECONDS
		_:         racer.boost = BOOST_SECONDS
	racer.boosters += 1
	racer.last_pickup = elapsed
	var points := 10 if pickup.kind == "power" else (30 if pickup.kind == "rare" else 50)
	racer.score += points
	events.append({"racer": winner, "kind": pickup.kind, "id": pickup.id, "points": points, "streak": 0, "bonus": false})

func _lane_clear(index: int, lane: int) -> bool:
	for j in racers.size():
		if j == index or racers[j].finish >= 0: continue
		var gap: float = racers[j].distance - racers[index].distance
		if absf(gap) < CONTACT_LENGTH + 2.0 and (absf(racers[j].x - lane_x(lane)) < CONTACT_WIDTH or racers[j].lane == lane):
			return false
	return true

func _choose_ai_lane(index: int) -> int:
	var racer: Dictionary = racers[index]
	var best_lane: int = racer.lane
	var best_cost := INF
	for lane in range(maxi(lane_min, racer.lane - 1), mini(lane_max, racer.lane + 1) + 1):
		if not _lane_clear(index, lane): continue
		# Rivals just keep a comfortable gap from other racers — no pickup chasing
		var cost := 50.0 + absf(lane_x(lane) - racer.x) * 2.0
		for j in racers.size():
			var gap: float = racers[j].distance - racer.distance
			if j != index and racers[j].lane == lane and gap > 0 and gap < 12: cost += 28.0
		if cost < best_cost:
			best_cost = cost
			best_lane = lane
	return best_lane

func _move_racers(dt: float, _steering: float, previous: Array[float]) -> void:
	var prior_x: Array[float] = []
	for racer in racers: prior_x.append(racer.x)
	for i in [1, 2]:
		var racer: Dictionary = racers[i]
		if racer.finish >= 0: continue
		racer.think_time -= dt
		if racer.think_time <= 0 and absf(racer.x - lane_x(racer.lane)) < .15:
			var miss_chance: float = [1.0, .45, .25, .10][difficulty]
			if rng.randf() >= miss_chance: racer.lane = _choose_ai_lane(i)
			racer.think_time = [1.4, 1.45, 1.05, .70][difficulty] + (.15 if i == 2 else 0.0)
	for index in racers.size():
		var racer: Dictionary = racers[index]
		if racer.finish >= 0: continue
		var error: float = lane_x(racer.lane) - racer.x
		var desired := clampf(error * 5.0, -SIDE_SPEED, SIDE_SPEED)
		var braking: bool = absf(desired) < absf(racer.lateral_speed) or desired * racer.lateral_speed < 0
		racer.lateral_speed = move_toward(racer.lateral_speed, desired, (SIDE_BRAKE if braking else SIDE_ACCEL) * dt)
		var movement: float = racer.lateral_speed * dt
		if absf(movement) >= absf(error) and movement * error >= 0:
			racer.x = lane_x(racer.lane)
			racer.lateral_speed = 0.0
		else: racer.x = clampf(racer.x + movement, -road_limit, road_limit)
		if absf(error) < .002:
			racer.x = lane_x(racer.lane)
			racer.lateral_speed = 0.0
		racer.drafting = false
		for other in racers.size():
			var gap: float = previous[other] - previous[index]
			if other != index and racers[other].finish < 0 and gap > CONTACT_LENGTH + .5 and gap < 15.0 and absf(prior_x[other] - prior_x[index]) < .8:
				racer.drafting = true
		racer.slingshot = maxf(0, racer.slingshot - dt)
		if racer.contact_time > 0:
			racer.draft_charge = 0.0
			racer.slingshot = 0.0
		elif racer.drafting:
			if racer.draft_charge == 0: racer.draft_lane = racer.lane
			racer.draft_charge = minf(1.2, racer.draft_charge + dt)
		elif racer.draft_charge >= 1.2 and racer.lane != racer.draft_lane:
			racer.slingshot = 2.0
			racer.draft_charge = 0.0
		else:
			racer.draft_charge = maxf(0, racer.draft_charge - dt * 2)
		racer.contact_time = maxf(0, racer.contact_time - dt)
		var target: float
		if index == 0:
			# Player speed driven by boost
			target = BOOST_SPEED if racer.boost > 0 else BASE_SPEED
			if racer.boost <= 0 and racer.slingshot > 0: target += 2.0
		else:
			# Rivals shadow the player: they close the gap when behind but don't push ahead.
			var gap: float = racers[0].distance - racer.distance  # positive = rival is behind
			var desired_gap := 8.0  # rivals aim to stay 8m behind the player
			var correction: float = clampf((gap - desired_gap) * 0.40, -2.0, 3.0)
			target = clampf(racers[0].speed + correction, racer.rival_min, racer.rival_max)
		if racer.contact_time > 0: target *= .84
		var acceleration := 8.0 if target < racer.speed else (10.0 if racer.speed < BASE_SPEED else 5.5)
		racer.speed = move_toward(racer.speed, target, acceleration * dt)
		racer.distance += racer.speed * dt
		racer.boost = maxf(0, racer.boost - dt)
	_resolve_contacts(previous)
	# When player is boosting into a rival, push the rival to an adjacent lane
	# instead of blocking the player — player keeps most of their speed.
	var player := racers[0]
	if player.boost > 0 and player.contact_time > 0:
		for j in [1, 2]:
			var rival: Dictionary = racers[j]
			if rival.finish >= 0: continue
			if absf(player.x - rival.x) >= CONTACT_WIDTH or absf(player.distance - rival.distance) >= CONTACT_LENGTH: continue
			var push: int = signi(int(rival.x - player.x))
			if push == 0: push = 1 if rival.lane < lane_max else -1
			var new_lane := clampi(rival.lane + push, lane_min, lane_max)
			if new_lane == rival.lane: new_lane = clampi(rival.lane - push, lane_min, lane_max)
			rival.lane = new_lane
			rival.contact_time = maxf(rival.contact_time, 0.4)
			player.speed = minf(BOOST_SPEED, player.speed + 0.7)
			player.contact_time = minf(player.contact_time, 0.08)
