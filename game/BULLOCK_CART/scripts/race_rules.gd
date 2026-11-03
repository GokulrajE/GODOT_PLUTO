extends RefCounted
## Deterministic race simulation, independent of scene nodes and device APIs.
const LENGTH := 480.0
const TIME_LIMIT := 90.0
const BASE_SPEED := 8.0
const BOOST_SPEED := 13.0
const BOOST_SECONDS := 3.0
const BOOST_RARE_SPEED := 14.5
const BOOST_RARE_SECONDS := 5.0
const BOOST_3X_SPEED := 16.0
const BOOST_3X_SECONDS := 9.0

## When true the race ends by elapsed time and winner is highest score.
## Set to false by lane_race (motion preview) which tracks finish position.
var timed_mode := false
var game_duration := 180.0   # seconds; overwritten by UI (60 / 180 / 300)
var racers: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var elapsed := 0.0
var complete := false
var events: Array[Dictionary] = []

func reset() -> void:
	elapsed = 0
	complete = false
	events.clear()
	racers = []
	for i in range(3):
		racers.append({"name": ["You", "Ramasami", "Munusami"][i], "x": [0.0, -2.6, 2.6][i],
				"distance": 0.0, "power": 0, "power_stash": [],
				"boost": 0.0, "boost_speed": BOOST_SPEED,
				"score": 0, "finish": -1.0, "streak": 0, "best_streak": 0,
				"last_pickup": -100.0, "drafting": false})
	pickups.clear()
	var lanes := [0.0, -2.6, 2.6, 0.0, 2.6, -2.6, 0.0]
	for i in range(46):
		var kind := "coin"
		if i % 3 == 0:
			kind = "power"
			if i == 15 or i == 33: kind = "rare"
			elif i == 27: kind = "power3x"
		pickups.append({"id": i, "distance": 15.0 + i * 10, "x": lanes[i % lanes.size()], "kind": kind, "owner": -1})

func activate_boost(index: int) -> bool:
	var racer := racers[index]
	if complete or racer.finish >= 0 or racer.power_stash.is_empty() or racer.boost > 0: return false
	var kind: String = racer.power_stash.pop_front()
	racer.power = racer.power_stash.size()
	match kind:
		"power3x":
			racer.boost = BOOST_3X_SECONDS
			racer.boost_speed = BOOST_3X_SPEED
		"rare":
			racer.boost = BOOST_RARE_SECONDS
			racer.boost_speed = BOOST_RARE_SPEED
		_:
			racer.boost = BOOST_SECONDS
			racer.boost_speed = BOOST_SPEED
	return true

func advance(delta: float, steering: float) -> void:
	events.clear()
	var remaining := clampf(delta, 0.0, 0.25)
	while remaining > 0.00001 and not complete:
		var dt := minf(remaining, 1.0 / 60.0)
		_tick(dt, clampf(steering, -1, 1))
		remaining -= dt

func _tick(dt: float, steering: float) -> void:
	var previous: Array[float] = []
	for racer in racers: previous.append(racer.distance)
	_move_racers(dt, steering, previous)
	for pickup in pickups:
		if pickup.owner >= 0: continue
		var winner := -1
		var first_fraction := 2.0
		for i in racers.size():
			var racer := racers[i]
			if previous[i] < pickup.distance and racer.distance >= pickup.distance and absf(racer.x - pickup.x) <= _pickup_reach():
				var fraction: float = (pickup.distance - previous[i]) / (racer.distance - previous[i])
				if fraction < first_fraction:
					first_fraction = fraction
					winner = i
		if winner >= 0:
			pickup.owner = winner
			_award_pickup(winner, pickup)
	if not timed_mode:
		for i in racers.size():
			var racer := racers[i]
			if racer.finish < 0 and racer.distance >= LENGTH:
				racer.finish = elapsed + dt * (LENGTH - previous[i]) / (racer.distance - previous[i])
				racer.distance = LENGTH
	elapsed += dt
	if timed_mode:
		complete = elapsed >= game_duration
	else:
		complete = racers[0].finish >= 0 or elapsed >= TIME_LIMIT

func _pickup_reach() -> float:
	return .95

func _award_pickup(winner: int, pickup: Dictionary) -> void:
	var collector := racers[winner]
	collector.streak += 1
	collector.best_streak = maxi(collector.best_streak, collector.streak)
	collector.last_pickup = elapsed
	var points := 10 * mini(3, 1 + int((collector.streak - 1) / 3))
	if pickup.kind == "rare": points = maxi(points, 30)
	elif pickup.kind == "power3x": points = maxi(points, 50)
	collector.score += points
	if pickup.kind in ["power", "rare", "power3x"] and collector.power_stash.size() < 3:
		collector.power_stash.append(pickup.kind)
		collector.power = collector.power_stash.size()
	var bonus: bool = collector.streak % 3 == 0 and collector.power_stash.size() < 3
	if bonus:
		collector.power_stash.append("power")
		collector.power = collector.power_stash.size()
	events.append({"racer": winner, "kind": pickup.kind, "id": pickup.id, "points": points, "streak": collector.streak, "bonus": bonus})

func _move_racers(dt: float, steering: float, previous: Array[float]) -> void:
	for i in racers.size():
		var racer := racers[i]
		if racer.finish >= 0: continue
		if elapsed - racer.last_pickup > 8.0: racer.streak = 0
		if i == 0:
			racer.x = clampf(racer.x + steering * dt * 5, -2.8, 2.8)
		else:
			var aim: float = _target_lane(i)
			for j in racers.size():
				if j != i and absf(racers[j].distance - racer.distance) < 5 and absf(racers[j].x - aim) < 2.1:
					aim = racer.x
					break
			# Light blocking: very slight lean toward player when racing alongside
			var player := racers[0]
			if absf(racer.distance - player.distance) < 3.0 and racer.boost <= 0:
				aim = lerpf(aim, player.x, 0.07)
			racer.x = move_toward(racer.x, aim, dt * 2.5)
			# Smart boost: hold until meaningfully behind player or near a rare/3x pickup
			var gap_to_player: float = player.distance - racer.distance
			if gap_to_player > 28.0 or _near_good_pickup(i):
				activate_boost(i)
		racer.drafting = false
		for j in racers.size():
			var gap: float = previous[j] - previous[i]
			if j != i and racers[j].finish < 0 and gap > 3 and gap < 12 and absf(racers[j].x - racer.x) < 0.8:
				racer.drafting = true
		var boosted_time := minf(dt, racer.boost)
		# Rubber-band catch-up: mild bonus to keep rivals visible, not dominant
		var base := BASE_SPEED
		if i > 0:
			var gap: float = racers[0].distance - racer.distance
			if gap > 30.0: base += 0.6
			elif gap > 15.0: base += 0.3
		racer.distance += base * dt + (racer.boost_speed - base) * boosted_time + (0.75 * (dt - boosted_time) if racer.drafting else 0.0)
		racer.boost = maxf(0, racer.boost - dt)

func _near_good_pickup(index: int) -> bool:
	var racer := racers[index]
	for pickup in pickups:
		if pickup.owner >= 0: continue
		var ahead: float = pickup.distance - racer.distance
		if ahead <= 0 or ahead > 25: continue
		if pickup.kind in ["rare", "power3x"] and absf(pickup.x - racer.x) < 1.5:
			return true
	return false

func _target_lane(index: int) -> float:
	var racer := racers[index]
	var best := INF
	var lane: float = racer.x
	for pickup in pickups:
		var ahead: float = pickup.distance - racer.distance
		if pickup.owner >= 0 or ahead <= 0 or ahead > 36: continue
		var travel: float = maxf(0, absf(pickup.x - racer.x) - 0.7) / 2.2
		if travel > ahead / (racer.boost_speed if racer.boost > 0 else BASE_SPEED): continue
		var cost: float = ahead + absf(pickup.x - racer.x) * 2.0
		if pickup.kind == "power" and racer.power < 2: cost -= 5.0
		if pickup.kind == "rare": cost -= 12.0
		if pickup.kind == "power3x": cost -= 20.0
		for j in racers.size():
			if j != index and racers[j].distance > racer.distance and racers[j].distance < pickup.distance and absf(racers[j].x - pickup.x) < 0.9:
				cost += 18.0
		if cost < best:
			best = cost
			lane = pickup.x
	return lane

func order() -> Array[int]:
	var indices: Array[int] = [0, 1, 2]
	if timed_mode:
		indices.sort_custom(func(a: int, b: int): return racers[a].score > racers[b].score)
	else:
		indices.sort_custom(func(a: int, b: int):
			if racers[a].finish >= 0 and racers[b].finish >= 0: return racers[a].finish < racers[b].finish
			if racers[a].finish >= 0: return true
			if racers[b].finish >= 0: return false
			return racers[a].distance > racers[b].distance)
	return indices

func player_place() -> int:
	return order().find(0) + 1
