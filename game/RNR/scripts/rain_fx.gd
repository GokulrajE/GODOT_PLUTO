extends Control
## Natural-looking rain for the Rain & Rise cloud (purely visual; it reads the game, never changes it).
##  - drops start under the cloud, speed up under gravity and are nudged by the cloud's movement and a
##    gentle breeze, so the rain leans when the cloud moves
##  - each drop is a small teardrop with a faint streak, in slightly different sizes
##  - drops that hit a plant spatter off its leaves; the rest splash into rings on the soil
##  - the rain eases in and out instead of switching on and off, and the last drops keep falling

const MAX_DROPS := 260
const BASE_RATE := 130.0               # drops per second at full intensity
const GRAVITY := 1500.0
const TERMINAL := 900.0
const DROP_COLOR := Color(0.62, 0.82, 1.0)

const TEAR := [
	Vector2(0, -1.0), Vector2(0.34, -0.5), Vector2(0.62, -0.08), Vector2(0.5, 0.2),
	Vector2(0, 0.32), Vector2(-0.5, 0.2), Vector2(-0.62, -0.08), Vector2(-0.34, -0.5),
]

var game: Control
var intensity := 0.0
var _drops: Array = []
var _splashes: Array = []
var _emit := 0.0
var _last_hit := {}              # slot -> time the rain last reached that plant
var _t := 0.0
var _prev_x := 0.0
var _cloud_vx := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1166, 784)
	set_meta("arcade_authored_control", true)
	if game: _prev_x = float(game.get("_cloud_x"))

func _paused() -> bool:
	return game == null or not is_instance_valid(game) or game.get("_state") == game.State.PAUSED

func _raining() -> bool:
	var state: int = game.get("_state")
	return bool(game.get("_is_raining")) and (state == game.State.MOVE or state == game.State.SUCCESS)

## The cloud never stops raining: a light drizzle all the time, and a proper downpour while it is over
## the plant that needs water.
const DRIZZLE := 0.4

func _target_intensity() -> float:
	if _raining(): return 1.0
	var state: int = game.get("_state")
	return 0.0 if state == game.State.DONE else DRIZZLE

func _process(delta: float) -> void:
	if _paused(): return
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	_t += delta
	var cloud_x := float(game.get("_cloud_x"))
	_cloud_vx = lerpf(_cloud_vx, (cloud_x - _prev_x) / maxf(delta, 0.0001), 1.0 - exp(-10.0 * delta))
	_prev_x = cloud_x
	intensity = move_toward(intensity, _target_intensity(), delta * (5.0 if _raining() else 2.0))

	var cloud := game.get("_cloud") as Control
	var wind := sin(_t * 0.45) * 16.0 + sin(_t * 1.3) * 6.0
	if intensity > 0.01 and cloud != null:
		var base_y: float = cloud.position.y + cloud.size.y * 0.76
		_emit += BASE_RATE * intensity * (0.5 if reduced else 1.0) * delta
		while _emit >= 1.0 and _drops.size() < MAX_DROPS:
			_emit -= 1.0
			var size_k := randf_range(0.7, 1.25)
			_drops.append({
				"pos": Vector2(cloud_x + clampf(randfn(0.0, 30.0), -60.0, 60.0), base_y + randf_range(-6.0, 8.0)),
				"vel": Vector2(_cloud_vx * 0.5 + wind * 0.3 + randf_range(-10.0, 10.0), randf_range(170.0, 280.0)),
				"len": 12.0 * size_k * (0.85 + 0.15 * intensity),
				"w": 2.6 * size_k * (0.85 + 0.15 * intensity),
				"alpha": randf_range(0.65, 0.95) * (0.7 + 0.3 * intensity),
				"age": 0.0,
				"ground": float(game.SEED_Y) + randf_range(-8.0, 10.0),
			})
		_emit = minf(_emit, 1.0)
	else:
		_emit = 0.0

	var alive: Array = []
	for drop in _drops:
		drop.age += delta
		drop.vel.y = minf(drop.vel.y + GRAVITY * delta, TERMINAL)
		drop.vel.x = lerpf(drop.vel.x, wind, 1.0 - exp(-1.4 * delta))     # air drag toward the breeze
		drop.pos += drop.vel * delta
		if _hit_plant(drop) or _hit_ground(drop): continue
		alive.append(drop)
	_drops = alive

	var kept: Array = []
	for splash in _splashes:
		splash.age += delta
		if splash.kind == "bit":
			splash.vel.y += 700.0 * delta
			splash.pos += splash.vel * delta
		if splash.age < splash.life: kept.append(splash)
	_splashes = kept
	queue_redraw()

## Time on this layer's clock; lets the game ask "has rain reached this plant since then?".
func clock() -> float:
	return _t

func rain_reached(slot: int, since: float) -> bool:
	return float(_last_hit.get(slot, -1.0)) >= since

func _note_hit(x: float) -> void:
	var slots: Array = game.get("_slot_positions")
	for i in slots.size():
		if absf(x - float(slots[i])) < 70.0:
			_last_hit[i] = _t

func _hit_plant(drop: Dictionary) -> bool:
	var nodes: Array = game.get("_seed_nodes")
	var stages: Array = game.get("_seed_stage")
	for i in nodes.size():
		if int(stages[i]) < 1: continue
		var plant := nodes[i] as Control
		var width: float = plant.size.x * plant.scale.x
		var height: float = plant.size.y * plant.scale.y
		var left: float = plant.position.x + width * 0.18
		var right: float = plant.position.x + width * 0.82
		var top: float = plant.position.y + height * 0.22
		if drop.pos.x > left and drop.pos.x < right and drop.pos.y > top and drop.pos.y < plant.position.y + height * 0.8:
			_note_hit(drop.pos.x)
			if randf() < 0.55:               # some drops run through the foliage, some spatter
				_spatter(drop.pos, 3, 80.0, 0.0)
				return true
	return false

func _hit_ground(drop: Dictionary) -> bool:
	if drop.pos.y < drop.ground: return false
	_note_hit(drop.pos.x)
	_splashes.append({"kind": "ring", "pos": Vector2(drop.pos.x, drop.ground), "age": 0.0, "life": 0.42, "r": randf_range(7.0, 12.0)})
	_spatter(Vector2(drop.pos.x, drop.ground), 2, 110.0, 0.0)
	return true

func _spatter(at: Vector2, count: int, speed: float, _unused: float) -> void:
	for i in count:
		_splashes.append({
			"kind": "bit", "pos": at,
			"vel": Vector2(randf_range(-speed, speed) * 0.6, -randf_range(0.35, 1.0) * speed),
			"age": 0.0, "life": randf_range(0.22, 0.4), "r": randf_range(1.2, 2.0),
		})

func _draw() -> void:
	for drop in _drops:
		var fade := clampf(drop.age / 0.12, 0.0, 1.0)                 # drops fade in just under the cloud
		var speed: float = drop.vel.length()
		var stretch := clampf(speed / 380.0, 0.7, 1.5)
		var angle: float = drop.vel.angle() - PI * 0.5
		var color := DROP_COLOR
		color.a = drop.alpha * fade
		# faint motion streak behind the drop, then the teardrop itself
		var back: Vector2 = Vector2.from_angle(drop.vel.angle() + PI) * drop.len * 1.5 * stretch
		draw_line(drop.pos, drop.pos + back, Color(color, color.a * 0.35), maxf(1.0, drop.w * 0.55), true)
		draw_set_transform(drop.pos, angle, Vector2(drop.w, drop.len * stretch))
		draw_colored_polygon(PackedVector2Array(TEAR), color)
		draw_set_transform(Vector2.ZERO)
		draw_circle(drop.pos + Vector2(-drop.w * 0.25, -drop.len * 0.15), drop.w * 0.28, Color(1, 1, 1, 0.6 * fade))
	for splash in _splashes:
		var u: float = clampf(splash.age / splash.life, 0.0, 1.0)
		if splash.kind == "ring":
			var r: float = splash.r * (0.3 + u)
			var alpha := (1.0 - u) * 0.55
			draw_set_transform(splash.pos, 0.0, Vector2(1.0, 0.32))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0.85, 0.94, 1.0, alpha), 1.6, true)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(splash.pos, splash.r, Color(0.78, 0.9, 1.0, (1.0 - u) * 0.85))
