extends Camera3D
## Smoothed spring-like follow with optional boost shake.
var side_view := false
var boost_strength := 0.0
var shake_strength := 0.0
var time := 0.0
var fixed_rear := false
var rear_offset := Vector3(0, 4.2, 10.5)
var aim := Vector3(0, 1.05, -1.5)

func impulse(amount: float) -> void:
	shake_strength = minf(1.0, shake_strength + amount)

func reset(target: Vector3) -> void:
	position = target + (rear_offset if fixed_rear else Vector3(3.0, 2.9, 7.0))
	if fixed_rear: fov = 58.0
	aim = target + Vector3(0, 1.05, -1.5)
	look_at(aim)

func follow(target: Vector3, steering: float, delta: float, reduced: bool) -> void:
	time += delta
	shake_strength = maxf(0.0, shake_strength - 9.0 * delta)
	if fixed_rear:
		# Centered rear view with a small, bounded translation; never orbit the sprites.
		var offset := rear_offset
		var lateral := 0.0 if reduced else clampf(target.x * .20, -.60, .60)
		var desired := offset + Vector3(lateral, 0, 0)
		position = desired if reduced else position.lerp(desired, 1.0 - exp(-delta * 4.0))
		look_at(position - offset + Vector3(0, 1.05, -1.5))
		fov = 58.0 if reduced else lerpf(fov, 58.0 + boost_strength * 1.5, 1.0 - exp(-delta * 2))
		if shake_strength > 0 and not reduced:
			position += Vector3(sin(time * 71.3) * shake_strength * 0.10, cos(time * 53.7) * shake_strength * 0.06, 0)
		return
	if reduced:
		fov = 58.0
		position = Vector3(0, 5.4, 9.5)
		look_at(Vector3(0, 1, -3))
		return
	var offset := Vector3(7.0, 3.4, 5.0) if side_view else Vector3(3.0, 2.9, 7.0)
	var desired := Vector3(target.x * 0.65, 0, 0) + offset
	# A tiny vertical suspension response, not a head-bob effect.
	desired.y += sin(time * 2.2) * 0.025
	position = position.lerp(desired, 1.0 - exp(-delta * 3.0))
	var desired_aim := Vector3(target.x * 0.8 + steering * 0.25, 1.05, -1.5)
	aim = aim.lerp(desired_aim, 1.0 - exp(-delta * 4.0))
	look_at(aim)
	fov = lerpf(fov, (55.0 if side_view else 58.0) + boost_strength * 3.0, 1.0 - exp(-delta * 2.0))
