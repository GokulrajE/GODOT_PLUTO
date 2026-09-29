extends RefCounted
## Device input is authoritative when connected; keyboard fallback holds its last position.
static func horizontal(current: float, sensor: float, delta: float, speed: float = 400.0) -> float:
	if PlutoComm.is_connected and not AppData.demo_mode:
		return sensor
	var direction := float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_LEFT))
	return current + direction * speed * delta

static func vertical(current: float, sensor: float, delta: float, speed: float = 400.0) -> float:
	if PlutoComm.is_connected and not AppData.demo_mode:
		return sensor
	var direction := float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_UP))
	return current + direction * speed * delta
