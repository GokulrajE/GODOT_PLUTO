extends Control
## Rain & Rise atmosphere: a day / night lighting cycle with butterflies roaming in the daylight
## and fireflies roaming at night. Purely visual - it never touches the game state or scoring.
##
## Layers it inserts into the game scene (back to front):
##   background -> light overlay (multiply) -> sun / moon / stars -> cloud + plants -> butterflies
##   -> fireflies -> UI
## `day_amount` is 1.0 in full daylight and 0.0 at full night; set_day() glides between the two.

const LIGHT_DAY := Color(1.0, 0.985, 0.93)
const LIGHT_NIGHT := Color(0.34, 0.40, 0.70)
const WORLD_DAY := Color(1, 1, 1)
const WORLD_NIGHT := Color(0.80, 0.85, 1.0)
const CLOUD_NIGHT := Color(0.72, 0.78, 0.96)

const AREA := Rect2(30, 170, 1106, 400)      # where the critters roam
const BUTTERFLY_COUNT := 7
const FIREFLY_COUNT := 26
const BUTTERFLY_COLORS := [
	Color("f28c28"), Color("f6c83d"), Color("4a90e2"), Color("e86aa6"), Color("8e6bd8"), Color("49b6a2"),
]

var game: Control
var day_amount := 1.0
var _target_day := true
var _light: ColorRect
var _sky: Control                  # sun, moon and stars
var _butterflies: Control
var _fireflies: Control
var _toggle: Button
var _glow: GradientTexture2D
var _time := 0.0
var _flies: Array = []
var _bugs: Array = []
var _stars: Array = []

func setup(owner_game: Control) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_glow()
	_build_layers()
	_seed_critters()
	# every game (1 game = 1 trial; a replay reloads the scene) is randomly day or night
	_target_day = randf() < 0.5
	day_amount = 1.0 if _target_day else 0.0
	_apply_light()

func _make_glow() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128

func _layer(additive := false) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = Vector2(1166, 784)
	layer.set_meta("arcade_authored_control", true)
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = material
	return layer

func _build_layers() -> void:
	# multiply overlay that darkens / warms the background only
	_light = ColorRect.new()
	_light.name = "LightOverlay"
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.size = Vector2(1166, 784)
	_light.set_meta("arcade_authored_control", true)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_light.material = multiply
	game.add_child(_light)

	_sky = _layer(true)
	_sky.name = "SkyLights"
	_sky.draw.connect(_draw_sky)
	game.add_child(_sky)

	var backdrop := game.get_node_or_null("ArcadeGameBackground")
	var base_index: int = (backdrop.get_index() + 1) if backdrop else 0
	var sky_node := game.get_node_or_null("Sky")
	if sky_node: base_index = maxi(base_index, sky_node.get_index() + 1)
	game.move_child(_light, base_index)
	game.move_child(_sky, base_index + 1)

	_butterflies = _layer(false)
	_butterflies.name = "Butterflies"
	_butterflies.draw.connect(_draw_butterflies)
	game.add_child(_butterflies)
	_fireflies = _layer(true)
	_fireflies.name = "Fireflies"
	_fireflies.draw.connect(_draw_fireflies)
	game.add_child(_fireflies)
	var seeds := game.get_node_or_null("SeedContainer")
	var front: int = (seeds.get_index() + 1) if seeds else game.get_child_count()
	game.move_child(_butterflies, front)
	game.move_child(_fireflies, front + 1)

	_toggle = Button.new()
	_toggle.name = "DayNightButton"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.set_meta("arcade_authored_control", true)
	_toggle.custom_minimum_size = Vector2(112, 36)
	_toggle.size = Vector2(112, 36)
	_toggle.position = Vector2(1166.0 - 112.0 - 22.0, 74.0)
	_toggle.add_theme_font_size_override("font_size", 16)
	_toggle.tooltip_text = "Switch between day and night"
	for state in ["normal", "hover", "pressed", "focus"]:
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.09, 0.15, 0.24, 0.88 if state != "hover" else 1.0)
		pill.border_color = Color(1, 1, 1, 0.55)
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(18)
		_toggle.add_theme_stylebox_override(state, pill)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_toggle.add_theme_color_override(state, Color.WHITE)
	_toggle.pressed.connect(func(): set_day(not _target_day, true))
	game.add_child(_toggle)
	_toggle.z_index = 20

func _seed_critters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_bugs.clear()
	for i in BUTTERFLY_COUNT:
		_bugs.append({
			"pos": Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y)),
			"angle": rng.randf() * TAU,
			"speed": rng.randf_range(42.0, 78.0),
			"turn": 0.0,
			"turn_goal": rng.randf_range(-2.0, 2.0),
			"retarget": rng.randf_range(0.4, 1.6),
			"phase": rng.randf() * TAU,
			"flap": rng.randf_range(11.0, 16.0),
			"color": BUTTERFLY_COLORS[i % BUTTERFLY_COLORS.size()],
			"size": rng.randf_range(1.05, 1.5),
		})
	_flies.clear()
	for i in FIREFLY_COUNT:
		_flies.append({
			"pos": Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y + 40.0, AREA.end.y + 50.0)),
			"angle": rng.randf() * TAU,
			"speed": rng.randf_range(10.0, 26.0),
			"turn_goal": rng.randf_range(-1.2, 1.2),
			"turn": 0.0,
			"retarget": rng.randf_range(0.8, 2.4),
			"phase": rng.randf() * TAU,
			"rate": rng.randf_range(1.2, 2.6),
			"size": rng.randf_range(0.8, 1.3),
		})
	_stars.clear()
	for i in 46:
		_stars.append({
			"pos": Vector2(rng.randf_range(10, 1156), rng.randf_range(8, 330)),
			"phase": rng.randf() * TAU,
			"rate": rng.randf_range(0.8, 2.2),
			"size": rng.randf_range(0.9, 2.2),
		})

# ── Day / night ───────────────────────────────────────────────────────────────

func set_day(day: bool, _by_player := false) -> void:
	_target_day = day
	_update_toggle_text()

func _update_toggle_text() -> void:
	if _toggle: _toggle.text = "Night mode" if _target_day else "Day mode"

func _apply_light() -> void:
	var t := day_amount
	_light.color = LIGHT_NIGHT.lerp(LIGHT_DAY, t)
	var world := WORLD_NIGHT.lerp(WORLD_DAY, t)
	var seeds := game.get_node_or_null("SeedContainer") as CanvasItem
	if seeds: seeds.modulate = world
	var cloud := game.get_node_or_null("Cloud") as CanvasItem
	if cloud: cloud.modulate = CLOUD_NIGHT.lerp(Color.WHITE, t)
	_update_toggle_text()

func _frozen() -> bool:
	return game == null or not is_instance_valid(game) or (game.get("_state") == game.State.PAUSED)

func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game): return
	var goal := 1.0 if _target_day else 0.0
	if not is_equal_approx(day_amount, goal):
		var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
		day_amount = goal if reduced else move_toward(day_amount, goal, delta / 1.6)
		_apply_light()
	if _frozen(): return
	var calm := 0.35 if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)) else 1.0
	_time += delta * calm
	if day_amount > 0.01: _step_bugs(delta * calm)
	if day_amount < 0.99: _step_flies(delta * calm)
	_sky.queue_redraw()
	_butterflies.visible = day_amount > 0.01
	_fireflies.visible = day_amount < 0.99
	_butterflies.queue_redraw()
	_fireflies.queue_redraw()

func _steer(c: Dictionary, delta: float, margin: float) -> void:
	c.retarget -= delta
	if c.retarget <= 0.0:
		c.retarget = randf_range(0.5, 1.8)
		c.turn_goal = randf_range(-2.2, 2.2)
	c.turn = lerpf(c.turn, c.turn_goal, 1.0 - exp(-2.5 * delta))
	c.angle += c.turn * delta
	# stay inside the play area: turn back toward the centre near the edges
	var p: Vector2 = c.pos
	if p.x < AREA.position.x + margin or p.x > AREA.end.x - margin or p.y < AREA.position.y + margin or p.y > AREA.end.y + 40.0 - margin:
		var home := AREA.get_center() - p
		c.angle = lerp_angle(c.angle, home.angle(), 1.0 - exp(-2.2 * delta))

func _step_bugs(delta: float) -> void:
	for bug in _bugs:
		_steer(bug, delta, 40.0)
		var bob := sin(_time * 3.0 + bug.phase) * 14.0
		bug.pos += Vector2.from_angle(bug.angle) * bug.speed * delta + Vector2(0, bob * delta)

func _step_flies(delta: float) -> void:
	for fly in _flies:
		_steer(fly, delta, 30.0)
		fly.pos += Vector2.from_angle(fly.angle) * fly.speed * delta + Vector2(0, sin(_time * 1.3 + fly.phase) * 6.0 * delta)

# ── Drawing ───────────────────────────────────────────────────────────────────

func _ellipse(center: Vector2, rx: float, ry: float, count := 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

func _draw_butterflies() -> void:
	if day_amount <= 0.01: return
	for bug in _bugs:
		var flap := 0.22 + 0.78 * absf(sin(_time * bug.flap + bug.phase))
		var scale_f: float = bug.size
		var color: Color = bug.color
		color.a = day_amount
		var dark := color.darkened(0.35)
		dark.a = day_amount
		var ink := Color(0.16, 0.12, 0.12, day_amount)
		_butterflies.draw_set_transform(bug.pos, bug.angle, Vector2(scale_f, scale_f))
		for side in [-1.0, 1.0]:
			_butterflies.draw_colored_polygon(_ellipse(Vector2(3, side * 7.5 * flap), 9.5, 8.0 * flap), color)
			_butterflies.draw_colored_polygon(_ellipse(Vector2(-6, side * 5.5 * flap), 6.5, 5.5 * flap), dark)
			_butterflies.draw_circle(Vector2(3, side * 8.5 * flap), 1.8 * flap, Color(1, 1, 1, 0.75 * day_amount))
		_butterflies.draw_line(Vector2(-9, 0), Vector2(9, 0), ink, 2.4, true)
		_butterflies.draw_line(Vector2(9, 0), Vector2(14, -3), ink, 1.0, true)
		_butterflies.draw_line(Vector2(9, 0), Vector2(14, 3), ink, 1.0, true)
	_butterflies.draw_set_transform(Vector2.ZERO)

func _draw_fireflies() -> void:
	var night := 1.0 - day_amount
	if night <= 0.01: return
	for fly in _flies:
		var pulse := pow(maxf(0.0, sin(_time * fly.rate + fly.phase)), 2.0)
		var glow := (0.30 + 0.70 * pulse) * night
		var radius: float = 20.0 * fly.size
		_fireflies.draw_texture_rect(_glow, Rect2(fly.pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(0.85, 1.0, 0.35, 0.55 * glow))
		_fireflies.draw_circle(fly.pos, 2.4 * fly.size, Color(1.0, 1.0, 0.75, glow))

func _draw_sky() -> void:
	var sun_alpha := day_amount
	var moon_alpha := 1.0 - day_amount
	if sun_alpha > 0.01:
		var sun := Vector2(330, 128)
		_sky.draw_texture_rect(_glow, Rect2(sun - Vector2(190, 190), Vector2(380, 380)), false, Color(1.0, 0.92, 0.6, 0.28 * sun_alpha))
		_sky.draw_circle(sun, 34.0, Color(1.0, 0.95, 0.7, 0.9 * sun_alpha))
		var rays := 12
		for i in rays:
			var a := TAU * float(i) / float(rays) + _time * 0.08
			_sky.draw_line(sun + Vector2.from_angle(a) * 46.0, sun + Vector2.from_angle(a) * 68.0, Color(1.0, 0.93, 0.62, 0.55 * sun_alpha), 3.0, true)
	if moon_alpha > 0.01:
		var moon := Vector2(1010, 140)
		_sky.draw_texture_rect(_glow, Rect2(moon - Vector2(330, 128), Vector2(300, 300)), false, Color(0.7, 0.8, 1.0, 0.5 * moon_alpha))
		_sky.draw_circle(moon, 30.0, Color(0.96, 0.97, 1.0, 0.95 * moon_alpha))
		_sky.draw_circle(moon + Vector2(-9, -6), 6.0, Color(0.78, 0.82, 0.92, 0.55 * moon_alpha))
		_sky.draw_circle(moon + Vector2(8, 9), 4.5, Color(0.78, 0.82, 0.92, 0.5 * moon_alpha))
		for star in _stars:
			var twinkle := 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * star.rate + star.phase))
			_sky.draw_circle(star.pos, star.size, Color(1, 1, 1, twinkle * moon_alpha))
