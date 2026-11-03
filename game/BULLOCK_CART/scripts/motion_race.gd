extends "res://game/BULLOCK_CART/scripts/race_rules.gd"
## Preview handling: bounded steering acceleration and gentle, non-bouncing contacts.
const SIDE_SPEED := 3.8
const SIDE_ACCEL := 16.0
const SIDE_BRAKE := 22.0
const CONTACT_WIDTH := 2.25
const CONTACT_LENGTH := 4.8
var contacts: Dictionary = {}
var contact_count := 0
var road_limit := 2.8

func activate_boost(index: int) -> bool:
	var racer := racers[index]
	if complete or racer.finish >= 0 or racer.power <= 0 or racer.boost > 0: return false
	var kind: String = racer.power_stash.pop_front() if not racer.power_stash.is_empty() else "power"
	racer.power = maxi(0, racer.power - 1)
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

func reset() -> void:
	super.reset()
	contacts.clear()
	contact_count = 0
	for racer in racers:
		racer.speed = 0.0
		racer.lateral_speed = 0.0
		racer.contact_time = 0.0

func _move_racers(dt: float, steering: float, previous: Array[float]) -> void:
	var prior_x: Array[float] = []
	for racer in racers: prior_x.append(racer.x)
	for i in racers.size():
		var racer: Dictionary = racers[i]
		if racer.finish >= 0: continue
		if elapsed - racer.last_pickup > 8.0: racer.streak = 0
		var desired_lateral := steering * SIDE_SPEED
		if i > 0:
			var aim: float = _target_lane(i)
			for j in racers.size():
				if j != i and absf(previous[j] - previous[i]) < CONTACT_LENGTH + .5 and absf(prior_x[j] - aim) < CONTACT_WIDTH + .15:
					aim = racer.x
					break
			desired_lateral = clampf((aim - racer.x) * 5.0, -2.2, 2.2)
			activate_boost(i)
		var braking: bool = is_zero_approx(desired_lateral) or desired_lateral * racer.lateral_speed < 0
		racer.lateral_speed = move_toward(racer.lateral_speed, desired_lateral, (SIDE_BRAKE if braking else SIDE_ACCEL) * dt)
		racer.x = clampf(racer.x + racer.lateral_speed * dt, -road_limit, road_limit)
		if absf(racer.x) >= road_limit and racer.x * racer.lateral_speed > 0: racer.lateral_speed = 0.0
		racer.drafting = false
		for j in racers.size():
			var gap: float = previous[j] - previous[i]
			if j != i and racers[j].finish < 0 and gap > 3 and gap < 12 and absf(prior_x[j] - prior_x[i]) < .8:
				racer.drafting = true
		racer.contact_time = maxf(0, racer.contact_time - dt)
		var target: float = BOOST_SPEED if racer.boost > 0 else BASE_SPEED + (.75 if racer.drafting else 0.0)
		if racer.contact_time > 0: target *= .84
		var acceleration := 8.0 if target < racer.speed else (10.0 if racer.speed < BASE_SPEED else 5.5)
		racer.speed = move_toward(racer.speed, target, acceleration * dt)
		racer.distance += racer.speed * dt
		racer.boost = maxf(0, racer.boost - dt)
	_resolve_contacts(previous)

func _resolve_contacts(previous: Array[float]) -> void:
	var touching: Dictionary = {}
	# Two relaxation passes handle a cart squeezed between both rivals.
	for pass_index in range(2):
		for i in racers.size():
			for j in range(i + 1, racers.size()):
				var a: Dictionary = racers[i]
				var b: Dictionary = racers[j]
				if a.finish >= 0 or b.finish >= 0: continue
				var dx: float = b.x - a.x
				var dz: float = b.distance - a.distance
				var key := Vector2i(i, j)
				# Hysteresis prevents repeating the slowdown while carts remain alongside.
				if absf(dx) < CONTACT_WIDTH + .08 and absf(dz) < CONTACT_LENGTH + .08 and contacts.has(key): touching[key] = true
				if absf(dx) >= CONTACT_WIDTH or absf(dz) >= CONTACT_LENGTH: continue
				touching[key] = true
				if pass_index == 0 and not contacts.has(key):
					contact_count += 1
					for racer in [a, b]:
						racer.speed *= .92
						racer.contact_time = .45
				if absf(previous[j] - previous[i]) >= CONTACT_LENGTH - .1:
					# Rear contact: keep the following cart behind, never pull it backwards.
					var rear := i if dz > 0 else j
					var front := j if dz > 0 else i
					racers[rear].distance = maxf(previous[rear], minf(racers[rear].distance, racers[front].distance - CONTACT_LENGTH))
					racers[rear].speed = minf(racers[rear].speed, racers[front].speed)
				else:
					# Side contact: share separation; the road edge absorbs no extra motion.
					var left := i if dx >= 0 else j
					var right := j if dx >= 0 else i
					var overlap: float = CONTACT_WIDTH - absf(dx) + .001
					var left_move := minf(overlap * .5, racers[left].x + road_limit)
					var right_move := minf(overlap - left_move, road_limit - racers[right].x)
					left_move = minf(overlap - right_move, racers[left].x + road_limit)
					racers[left].x -= left_move
					racers[right].x += right_move
					racers[left].lateral_speed = minf(0, racers[left].lateral_speed)
					racers[right].lateral_speed = maxf(0, racers[right].lateral_speed)
	contacts = touching
