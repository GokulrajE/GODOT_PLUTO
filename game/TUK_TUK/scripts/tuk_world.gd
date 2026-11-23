extends Control
## The Tuk-Tuk world: a different backdrop (with matching obstacles) for every game, always at night
## with an automatic headlight, and little cameo creatures that wander through the scene.
## Purely visual - it reads the game's state and never changes it.
##
## Layers it inserts (back to front):
##   backdrop -> cameos -> light overlay (multiply) -> moon + stars -> obstacles -> tuk-tuk
##   -> headlight + glow (additive) -> UI

const THEMES := [
	{
		"id": "beach", "name": "Marina Beach",
		"bg": "res://game/TUK_TUK/sprites/Backgrounds/game/beach.png",
		"top": "res://game/TUK_TUK/sprites/Obstacles/cut/beach_top.png",
		"bottom": "res://game/TUK_TUK/sprites/Obstacles/cut/beach_bottom.png",
		"always_night": false,
		"cameos": ["gulls", "kite", "sailboat", "crab"],
	},
	{
		"id": "kerala", "name": "Kerala Backwaters",
		"bg": "res://game/TUK_TUK/sprites/Backgrounds/game/kerala.png",
		"top": "res://game/TUK_TUK/sprites/Obstacles/cut/kerala_top.png",
		"bottom": "res://game/TUK_TUK/sprites/Obstacles/cut/kerala_bottom.png",
		"always_night": false,
		"cameos": ["egret", "fish", "dragonfly"],
	},
	{
		"id": "space", "name": "Deep Space",
		"bg": "res://game/TUK_TUK/sprites/Backgrounds/game/space.png",
		"top": "res://game/TUK_TUK/sprites/Obstacles/cut/space_top.png",
		"bottom": "res://game/TUK_TUK/sprites/Obstacles/cut/space_bottom.png",
		"always_night": true,
		"cameos": ["shooting_star", "ufo", "astronaut", "satellite"],
	},
]

const DESIGN_VIEW := Vector2(1166.0, 656.0)
const BG_SIZE := Vector2(2048.0, 1152.0)
const LIGHT_NIGHT := Color(0.30, 0.36, 0.63)
const LIGHT_SPACE := Color(0.80, 0.83, 0.96)
## Where the front lamp sits on the tuk-tuk picture (the player node's local pixels).
const LAMP := Vector2(139.0, 74.0)
const TAIL := Vector2(8.0, 78.0)
const BEAM_LENGTH := 460.0
const BEAM_HALF_ANGLE := 0.30
const CAMEO_SCALE := 1.4              # cameos are drawn a little larger so they are easy to spot

## Remembered across replays so a game never repeats the previous backdrop.
static var _last_theme := -1
## Strong references to every picture the game can need, so nothing is loaded (or reloaded) mid-game.
static var _kept: Array = []
static var _reveal_shader: Shader = null

const REVEAL_CODE := """
shader_type canvas_item;
uniform vec2 center = vec2(0.2, 0.5);   // where the reveal starts (uv)
uniform float radius = 0.0;             // reveal radius, in uv-height units
uniform float aspect = 1.78;
uniform float feather = 0.06;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length((UV - center) * vec2(aspect, 1.0));
	COLOR = vec4(c.rgb, c.a * smoothstep(radius, radius + feather, d));
}
"""

var game: Control
var cfg: Dictionary = {}
var night := true                  # Tuk-Tuk is always played at night
var _view := DESIGN_VIEW
var _time := 0.0
var _lamp_t := 0.0
var _light: ColorRect
var _sky: Control
var _cameos: Control
var _beam: Control
var _glow: GradientTexture2D
var _stars: Array = []
var _active: Array = []
var _next_cameo := 3.0
var _pulses: Array = []
var _reveal_t := -1.0              # progress of a world change (0..1), -1 when idle
var _reveal_center := Vector2.ZERO
var _reveal_max := 1.0
var _ghost: TextureRect = null
var _rng := RandomNumberGenerator.new()

## Loads every backdrop, pillar and the portal up front (call while the scene is being built, before
## the game is shown), and prepares the reveal shader, so switching worlds later never stalls.
static func preload_all() -> void:
	if _kept.is_empty():
		for entry in THEMES:
			for key in ["bg", "top", "bottom"]:
				var tex := load(String(entry[key])) as Texture2D
				if tex: _kept.append(tex)
		var portal := load("res://game/TUK_TUK/sprites/Obstacles/teleportation_portal.png") as Texture2D
		if portal: _kept.append(portal)
	if _reveal_shader == null:
		_reveal_shader = Shader.new()
		_reveal_shader.code = REVEAL_CODE

## Picks this game's theme (different from the last game). Call before the game loads its obstacles.
static func pick_theme() -> Dictionary:
	var index := randi() % THEMES.size()
	while THEMES.size() > 1 and index == _last_theme:
		index = randi() % THEMES.size()
	_last_theme = index
	return THEMES[index]

func setup(owner_game: Control, chosen: Dictionary) -> void:
	game = owner_game
	cfg = chosen
	_rng.randomize()
	night = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload_all()
	_view = _viewport_size()
	_make_glow()
	_build_layers()
	_seed_stars()
	_warm_up()
	get_viewport().size_changed.connect(_fit_to_window)

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
	layer.size = _view
	layer.set_meta("arcade_authored_control", true)
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = material
	return layer

func _build_layers() -> void:
	var backdrop := game.get_node_or_null("ArcadeGameBackground") as TextureRect
	var base := 0
	if backdrop:
		var tex := load(cfg.bg) as Texture2D
		if tex:
			backdrop.texture = tex
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		base = backdrop.get_index() + 1

	_cameos = _layer(false)
	_cameos.name = "Cameos"
	_cameos.scale = Vector2(CAMEO_SCALE, CAMEO_SCALE)
	_cameos.draw.connect(_draw_cameos)
	game.add_child(_cameos)

	_light = ColorRect.new()
	_light.name = "LightOverlay"
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.size = _view
	_light.set_meta("arcade_authored_control", true)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_light.material = multiply
	_light.color = LIGHT_SPACE if cfg.id == "space" else LIGHT_NIGHT
	game.add_child(_light)

	_sky = _layer(true)
	_sky.name = "SkyLights"
	_sky.draw.connect(_draw_sky)
	game.add_child(_sky)

	game.move_child(_cameos, base)
	game.move_child(_light, base + 1)
	game.move_child(_sky, base + 2)

	_beam = _layer(true)
	_beam.name = "Headlight"
	_beam.draw.connect(_draw_beam)
	game.add_child(_beam)
	var player := game.get_node_or_null("Player")
	if player: game.move_child(_beam, player.get_index() + 1)
	_fit_to_window()

## The whole window (the scene itself is 16:9, but a taller window shows more below it).
func _viewport_size() -> Vector2:
	var size_now := get_viewport().get_visible_rect().size
	return Vector2(maxf(size_now.x, DESIGN_VIEW.x), maxf(size_now.y, DESIGN_VIEW.y))

## Cover the whole window with the picture (scaled up, cropped at the sides, bottom edge kept) so no
## empty strip shows under the play field, and size the lighting layers to match.
func _fit_to_window() -> void:
	if game == null or not is_instance_valid(game): return
	_view = _viewport_size()
	var backdrop := game.get_node_or_null("ArcadeGameBackground") as TextureRect
	if backdrop:
		var k := maxf(_view.x / BG_SIZE.x, _view.y / BG_SIZE.y)
		var w := BG_SIZE.x * k
		var h := BG_SIZE.y * k
		backdrop.size = Vector2(w, h)
		backdrop.position = Vector2((_view.x - w) * 0.5, _view.y - h)
	for layer in [_light, _sky, _cameos, _beam]:
		if layer: (layer as Control).size = _view / ((layer as Control).scale)

func _seed_stars() -> void:
	_stars.clear()
	var count := 30 if cfg.id != "space" else 0
	for i in count:
		_stars.append({
			"pos": Vector2(_rng.randf_range(8, _view.x - 8), _rng.randf_range(6, 250)),
			"phase": _rng.randf() * TAU, "rate": _rng.randf_range(0.8, 2.2), "size": _rng.randf_range(0.9, 2.0),
		})

# ── Frame update ──────────────────────────────────────────────────────────────

func _paused() -> bool:
	return game == null or not is_instance_valid(game) or game.get("_state") == game.State.PAUSED

func _running() -> bool:
	var state: int = game.get("_state")
	var s = game.State
	return state != s.WAITING and state != s.DONE and state != s.STOP

func _process(delta: float) -> void:
	if _paused(): return
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	var calm := 0.4 if reduced else 1.0
	_time += delta * calm
	# the lamp switches itself on with a short flicker as soon as the game begins
	_lamp_t += delta
	_step_cameos(delta * calm)
	_pulses = _pulses.filter(func(p): p.age += delta; return p.age < p.life)
	if _reveal_t >= 0.0:
		_reveal_t += delta / 1.3
		var e := 1.0 - pow(1.0 - clampf(_reveal_t, 0.0, 1.0), 2.4)
		var backdrop := game.get_node_or_null("ArcadeGameBackground") as TextureRect
		if _ghost and is_instance_valid(_ghost) and backdrop:
			(_ghost.material as ShaderMaterial).set_shader_parameter("radius", e * _reveal_max / backdrop.size.y)
		if _reveal_t >= 1.0:
			_reveal_t = -1.0
			if _ghost and is_instance_valid(_ghost): _ghost.queue_free()
			_ghost = null
	_sky.queue_redraw()
	_cameos.queue_redraw()
	_beam.queue_redraw()

## Portal jump: a flash, then a different world (backdrop, lighting, cameos) fades in.
func switch_theme(new_cfg: Dictionary, at: Vector2) -> void:
	var backdrop := game.get_node_or_null("ArcadeGameBackground") as TextureRect
	if backdrop and backdrop.texture:
		if _ghost and is_instance_valid(_ghost): _ghost.queue_free()
		# the old picture sits on top and is cut away by a circle that grows out of the portal,
		# revealing the new world underneath - one continuous transformation, no cut or flash
		_ghost = TextureRect.new()
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.texture = backdrop.texture
		_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ghost.stretch_mode = TextureRect.STRETCH_SCALE
		_ghost.set_meta("arcade_authored_control", true)
		var material := ShaderMaterial.new()
		material.shader = _reveal_shader
		_ghost.material = material
		game.add_child(_ghost)
		game.move_child(_ghost, backdrop.get_index() + 1)
		_ghost.position = backdrop.position
		_ghost.size = backdrop.size
		var local := (at - backdrop.position) / backdrop.size
		material.set_shader_parameter("center", local)
		material.set_shader_parameter("aspect", backdrop.size.x / backdrop.size.y)
		material.set_shader_parameter("radius", 0.0)
		_reveal_center = at
		_reveal_t = 0.0
		var far := 0.0
		for corner in [Vector2.ZERO, Vector2(_view.x, 0.0), Vector2(0.0, _view.y), _view]:
			far = maxf(far, at.distance_to(corner))
		_reveal_max = far + 80.0
	cfg = new_cfg
	var tex := load(cfg.bg) as Texture2D
	if backdrop and tex:
		backdrop.texture = tex
	var target: Color = LIGHT_SPACE if cfg.id == "space" else LIGHT_NIGHT
	var tint := _light.create_tween()
	tint.tween_property(_light, "color", target, 1.2)
	_active.clear()
	_next_cameo = 3.0
	_seed_stars()

## Draws every special material once, off screen, so its first real use does not hitch.
func _warm_up() -> void:
	var probe := TextureRect.new()
	probe.texture = _glow
	probe.size = Vector2(2, 2)
	probe.modulate.a = 0.01
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _reveal_shader
	probe.material = material
	game.add_child(probe)
	probe.get_tree().create_timer(0.3).timeout.connect(probe.queue_free)

## Rings that expand where the tuk-tuk enters / leaves a portal.
func pulse(at: Vector2, color: Color) -> void:
	_pulses.append({"pos": at, "age": 0.0, "life": 0.55, "color": color})

# ── Headlight ─────────────────────────────────────────────────────────────────

func lamp_world() -> Vector2:
	var player := game.get_node("Player") as Control
	return player.position + LAMP

func _lamp_power() -> float:
	if not night: return 0.0
	var t := _lamp_t
	if t < 0.55:
		# warm-up flicker: on, off, on, then steady
		return 0.9 if sin(t * 34.0) > -0.2 else 0.25
	return 1.0 + sin(_time * 7.0) * 0.015

func _draw_beam() -> void:
	var player := game.get_node("Player") as Control
	if not player.visible and not _beam.visible: return
	var power := _lamp_power()
	if _reveal_t >= 0.0:
		# glowing rim of the expanding circle
		var e := 1.0 - pow(1.0 - clampf(_reveal_t, 0.0, 1.0), 2.4)
		var r := e * _reveal_max
		var fade := 1.0 - clampf(_reveal_t, 0.0, 1.0)
		_beam.draw_arc(_reveal_center, r, 0.0, TAU, 96, Color(0.7, 0.88, 1.0, 0.85 * fade), 7.0 * fade + 2.0, true)
		_beam.draw_arc(_reveal_center, r, 0.0, TAU, 96, Color(0.85, 0.7, 1.0, 0.35 * fade), 18.0 * fade + 4.0, true)
	for pulse_item in _pulses:
		var u: float = pulse_item.age / pulse_item.life
		var c: Color = pulse_item.color
		c.a = (1.0 - u) * 0.9
		_beam.draw_arc(pulse_item.pos, 14.0 + u * 70.0, 0.0, TAU, 40, c, 4.0 * (1.0 - u) + 1.0, true)
		_beam.draw_texture_rect(_glow, Rect2(pulse_item.pos - Vector2(60, 60), Vector2(120, 120)), false, Color(c, c.a * 0.5))
	if power <= 0.01 or not player.visible: return
	var origin := lamp_world()
	var tilt: float = player.rotation
	# soft cone of light: wide and faint outside, narrow and bright in the middle
	for layer in [[1.0, 0.10], [0.85, 0.10], [0.70, 0.10], [0.55, 0.11], [0.40, 0.12], [0.26, 0.14]]:
		var spread: float = BEAM_HALF_ANGLE * layer[0]
		var pts := PackedVector2Array([origin])
		var cols := PackedColorArray([Color(1.0, 0.95, 0.68, layer[1] * power)])
		for i in 7:
			var a := tilt + lerpf(-spread, spread, float(i) / 6.0) + 0.05
			pts.append(origin + Vector2.from_angle(a) * BEAM_LENGTH * (0.7 + 0.3 * layer[0]))
			cols.append(Color(1.0, 0.95, 0.68, 0.0))
		_beam.draw_polygon(pts, cols)
	# lamp bulb glow and a little tail light
	_beam.draw_texture_rect(_glow, Rect2(origin - Vector2(46, 46), Vector2(92, 92)), false, Color(1.0, 0.95, 0.7, 0.85 * power))
	_beam.draw_circle(origin, 4.0, Color(1, 1, 0.9, power))
	var tail: Vector2 = player.position + TAIL
	_beam.draw_texture_rect(_glow, Rect2(tail - Vector2(20, 20), Vector2(40, 40)), false, Color(1.0, 0.2, 0.15, 0.6 * power))

# ── Sky: moon and stars at night ──────────────────────────────────────────────

func _draw_sky() -> void:
	if not night or cfg.id == "space": return
	var moon := Vector2(840, 96)
	_sky.draw_texture_rect(_glow, Rect2(moon - Vector2(140, 140), Vector2(280, 280)), false, Color(0.7, 0.8, 1.0, 0.42))
	_sky.draw_circle(moon, 28.0, Color(0.96, 0.97, 1.0, 0.95))
	for star in _stars:
		var twinkle := 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * star.rate + star.phase))
		_sky.draw_circle(star.pos, star.size, Color(1, 1, 1, twinkle))

# ── Cameos ────────────────────────────────────────────────────────────────────

func _step_cameos(delta: float) -> void:
	if not _running():
		return
	_next_cameo -= delta
	if _next_cameo <= 0.0 and _active.size() < 2:
		_next_cameo = _rng.randf_range(4.0, 9.0)
		_spawn_cameo(String(cfg.cameos[_rng.randi() % cfg.cameos.size()]))
	var alive: Array = []
	for c in _active:
		c.age += delta
		c.pos += c.vel * delta
		if c.kind == "fish":
			c.vel.y += 640.0 * delta / CAMEO_SCALE        # jumping fish follow an arc
		if c.age < c.life and c.pos.x > -160.0 and c.pos.x < _view.x / CAMEO_SCALE + 160.0 and c.pos.y < _view.y / CAMEO_SCALE + 80.0:
			alive.append(c)
	_active = alive

func _spawn_cameo(kind: String) -> void:
	var from_left := _rng.randf() < 0.5
	var dir := 1.0 if from_left else -1.0
	var x := -90.0 if from_left else _view.x / CAMEO_SCALE + 90.0
	var c := {"kind": kind, "age": 0.0, "life": 14.0, "dir": dir, "phase": _rng.randf() * TAU, "pos": Vector2(x, 100.0), "vel": Vector2.ZERO, "s": 1.0}
	match kind:
		"gulls":
			c.pos.y = _rng.randf_range(70.0, 190.0); c.vel = Vector2(dir * _rng.randf_range(60.0, 90.0), _rng.randf_range(-6.0, 6.0))
		"kite":
			c.pos = Vector2(_rng.randf_range(200.0, 900.0), 40.0); c.vel = Vector2(dir * 18.0, 14.0); c.life = 11.0
		"sailboat":
			c.pos.y = _rng.randf_range(232.0, 290.0); c.vel = Vector2(dir * 22.0, 0.0); c.life = 60.0
		"crab":
			c.pos = Vector2(0.0, 616.0 / CAMEO_SCALE); c.pos.x = -50.0 if from_left else _view.x / CAMEO_SCALE + 50.0
			c.vel = Vector2(dir * 34.0, 0.0); c.life = 40.0
		"egret":
			c.pos.y = _rng.randf_range(90.0, 220.0); c.vel = Vector2(dir * _rng.randf_range(70.0, 95.0), _rng.randf_range(-8.0, 4.0))
		"fish":
			c.pos = Vector2(_rng.randf_range(300.0, 880.0), 470.0); c.vel = Vector2(dir * 60.0, -330.0); c.life = 2.0
		"dragonfly":
			c.pos.y = _rng.randf_range(260.0, 440.0); c.vel = Vector2(dir * 55.0, 0.0); c.life = 20.0
		"shooting_star":
			c.pos = Vector2(_rng.randf_range(300.0, 1100.0), _rng.randf_range(10.0, 120.0)); c.vel = Vector2(-380.0, 200.0); c.life = 1.5
		"ufo":
			c.pos.y = _rng.randf_range(90.0, 210.0); c.vel = Vector2(dir * 85.0, 0.0)
		"astronaut":
			c.pos.y = _rng.randf_range(90.0, 460.0); c.vel = Vector2(dir * 24.0, _rng.randf_range(-6.0, 6.0)); c.life = 40.0
		"satellite":
			c.pos.y = _rng.randf_range(60.0, 160.0); c.vel = Vector2(dir * 34.0, 3.0); c.life = 40.0
	# the layer is drawn at CAMEO_SCALE, so positions and speeds are kept in its own units
	c.pos /= CAMEO_SCALE
	c.vel /= CAMEO_SCALE
	_active.append(c)

func _draw_cameos() -> void:
	for c in _active:
		var t: float = c.age
		var p: Vector2 = c.pos
		var d: float = c.dir
		match c.kind:
			"gulls": for i in 3: _gull(p + Vector2(-d * i * 46.0, i * 18.0 - (i % 2) * 34.0), t + float(i) * 0.7, d)
			"kite": _kite(p, t)
			"sailboat": _sailboat(p, t, d)
			"crab": _crab(p, t, d)
			"egret": _egret(p, t, d)
			"fish": _fish(c)
			"dragonfly": _dragonfly(p, t, d)
			"shooting_star": _shooting_star(p, t)
			"ufo": _ufo(p, t)
			"astronaut": _astronaut(p, t)
			"satellite": _satellite(p, t)

func _wing(from: Vector2, flap: float, length: float, dir: float, color: Color, width := 3.0) -> void:
	var tip := from + Vector2(dir * length * 0.8, -flap * length)
	var mid := from + Vector2(dir * length * 0.4, -flap * length * 0.7 - 4.0)
	_cameos.draw_polyline(PackedVector2Array([from, mid, tip]), color, width, true)

func _gull(p: Vector2, t: float, dir: float) -> void:
	var flap := sin(t * 7.0) * 0.55
	var c := Color(0.97, 0.97, 1.0)
	_wing(p, flap, 22.0, 1.0, c)
	_wing(p, flap, 22.0, -1.0, c)
	_cameos.draw_circle(p, 3.2, c)
	_cameos.draw_circle(p + Vector2(dir * 3.6, -0.5), 1.8, Color(1.0, 0.75, 0.2))

func _kite(p: Vector2, t: float) -> void:
	var sway := sin(t * 1.6) * 0.18
	_cameos.draw_set_transform(p, sway, Vector2.ONE)
	var body := PackedVector2Array([Vector2(0, -26), Vector2(18, 0), Vector2(0, 30), Vector2(-18, 0)])
	_cameos.draw_colored_polygon(body, Color("e8483d"))
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(0, -26), Vector2(18, 0), Vector2(0, 0)]), Color("f6c83d"))
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(0, 30), Vector2(-18, 0), Vector2(0, 0)]), Color("3f7fd6"))
	var prev := Vector2(0, 30)
	for i in 6:
		var q := Vector2(sin(t * 3.0 + i) * 7.0, 30 + (i + 1) * 12.0)
		_cameos.draw_line(prev, q, Color("fff0d0"), 1.6, true)
		_cameos.draw_circle(q, 3.0, Color("e8483d") if i % 2 == 0 else Color("f6c83d"))
		prev = q
	_cameos.draw_set_transform(Vector2.ZERO)

func _sailboat(p: Vector2, t: float, dir: float) -> void:
	var bob := sin(t * 1.4) * 2.0
	_cameos.draw_set_transform(p + Vector2(0, bob), sin(t * 1.1) * 0.03, Vector2(dir, 1.0))
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(28, 0), Vector2(20, 10), Vector2(-18, 10)]), Color("7a4b2a"))
	_cameos.draw_line(Vector2(0, 0), Vector2(0, -44), Color("4a3320"), 2.0, true)
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(2, -42), Vector2(24, -4), Vector2(2, -4)]), Color("fffaf0"))
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(-2, -36), Vector2(-18, -4), Vector2(-2, -4)]), Color("f2c14e"))
	_cameos.draw_set_transform(Vector2.ZERO)

func _crab(p: Vector2, t: float, dir: float) -> void:
	var red := Color("e2553b")
	var wobble := sin(t * 14.0) * 1.5
	_cameos.draw_set_transform(p + Vector2(0, wobble * 0.3), 0.0, Vector2.ONE)
	for side in [-1.0, 1.0]:
		for i in 3:
			var knee := Vector2(side * (9.0 + i * 4.0), 3.0 + sin(t * 14.0 + i + side) * 2.0)
			_cameos.draw_polyline(PackedVector2Array([Vector2(side * 5.0, 2.0), knee, knee + Vector2(side * 4.0, 6.0)]), red.darkened(0.2), 1.6, true)
		var claw := Vector2(side * 13.0, -8.0 - absf(sin(t * 4.0 + side)) * 4.0)
		_cameos.draw_line(Vector2(side * 7.0, -2.0), claw, red, 2.2, true)
		_cameos.draw_circle(claw, 3.6, red)
	_cameos.draw_colored_polygon(_ellipse(Vector2.ZERO, 9.0, 6.0), red)
	for side in [-1.0, 1.0]:
		_cameos.draw_line(Vector2(side * 3.0, -4.0), Vector2(side * 3.0, -9.0), red, 1.4)
		_cameos.draw_circle(Vector2(side * 3.0, -10.0), 2.0, Color.WHITE)
		_cameos.draw_circle(Vector2(side * 3.0, -10.0), 0.9, Color("1d2b3a"))
	_cameos.draw_set_transform(Vector2.ZERO)

func _egret(p: Vector2, t: float, dir: float) -> void:
	var flap := sin(t * 4.2) * 0.7
	var white := Color("fbfbf6")
	_cameos.draw_set_transform(p, 0.0, Vector2(dir, 1.0))
	# long legs trailing, neck in an S-curve, beak
	_cameos.draw_line(Vector2(-12, 3), Vector2(-34, 9), Color("4a4a3a"), 1.6, true)
	_cameos.draw_line(Vector2(-12, 4), Vector2(-33, 14), Color("4a4a3a"), 1.6, true)
	_cameos.draw_colored_polygon(_ellipse(Vector2.ZERO, 16.0, 6.0), white)
	_cameos.draw_polyline(PackedVector2Array([Vector2(12, -2), Vector2(20, -9), Vector2(24, -4), Vector2(27, -12)]), white, 3.4, true)
	_cameos.draw_circle(Vector2(28, -13), 3.4, white)
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(30, -14), Vector2(40, -12), Vector2(30, -11)]), Color("f1b330"))
	for sign_ in [-1.0, 1.0]:
		var base := Vector2(-2, -2)
		var tip := base + Vector2(-8.0 * sign_, -flap * 34.0 - 8.0)
		_cameos.draw_colored_polygon(PackedVector2Array([base + Vector2(-8, 0), base + Vector2(10, 0), tip]), Color(white, 0.95))
	_cameos.draw_set_transform(Vector2.ZERO)

func _fish(c: Dictionary) -> void:
	var p: Vector2 = c.pos
	var angle: float = c.vel.angle()
	_cameos.draw_set_transform(p, angle, Vector2.ONE)
	_cameos.draw_colored_polygon(_ellipse(Vector2.ZERO, 14.0, 5.5), Color("f0a35a"))
	_cameos.draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-22, -7), Vector2(-22, 7)]), Color("e2793a"))
	_cameos.draw_circle(Vector2(8, -1.5), 1.5, Color("1d2b3a"))
	_cameos.draw_set_transform(Vector2.ZERO)
	# the splash where it left the water
	var u := clampf(float(c.age) / 0.9, 0.0, 1.0)
	_cameos.draw_set_transform(Vector2(float(c.pos.x) - float(c.vel.x) * float(c.age), 478.0 / CAMEO_SCALE), 0.0, Vector2(1.0, 0.3))
	_cameos.draw_arc(Vector2.ZERO, 8.0 + u * 34.0, 0.0, TAU, 24, Color(1, 1, 1, 0.65 * (1.0 - u)), 2.0, true)
	_cameos.draw_set_transform(Vector2.ZERO)

func _dragonfly(p: Vector2, t: float, dir: float) -> void:
	var hover := Vector2(sin(t * 2.3) * 14.0, sin(t * 3.1) * 10.0)
	var q := p + hover
	var body := Color("1d8fc4")
	var shimmer := 0.35 + 0.25 * sin(t * 60.0)
	_cameos.draw_set_transform(q, sin(t * 2.3) * 0.15, Vector2(dir, 1.0))
	for k in 2:
		for sign_ in [-1.0, 1.0]:
			_cameos.draw_colored_polygon(_ellipse(Vector2(2 - k * 7, sign_ * 8), 9.0, 2.6), Color(0.85, 0.95, 1.0, shimmer))
	_cameos.draw_line(Vector2(-16, 0), Vector2(10, 0), body, 2.6, true)
	_cameos.draw_circle(Vector2(12, 0), 3.0, Color("e0562f"))
	_cameos.draw_set_transform(Vector2.ZERO)

func _shooting_star(p: Vector2, t: float) -> void:
	var fade := clampf(1.0 - t / 1.5, 0.0, 1.0)
	var tail := Vector2(120.0, -63.0)
	for i in 10:
		var u := float(i) / 10.0
		_cameos.draw_line(p + tail * u, p + tail * (u + 0.1), Color(1.0, 1.0, 1.0, (1.0 - u) * 0.8 * fade), 3.0 * (1.0 - u) + 0.6, true)
	_cameos.draw_circle(p, 3.0, Color(1, 1, 1, fade))

func _ufo(p: Vector2, t: float) -> void:
	var wobble := sin(t * 2.0) * 6.0
	_cameos.draw_set_transform(p + Vector2(0, wobble), sin(t * 2.0) * 0.06, Vector2.ONE)
	_cameos.draw_colored_polygon(_ellipse(Vector2(0, -8), 13.0, 11.0), Color(0.6, 0.9, 1.0, 0.8))
	_cameos.draw_colored_polygon(_ellipse(Vector2.ZERO, 32.0, 9.0), Color("aab6c9"))
	_cameos.draw_colored_polygon(_ellipse(Vector2(0, 3), 26.0, 5.0), Color("6d7a92"))
	for i in 5:
		var on := int(t * 4.0 + i) % 3 != 0
		_cameos.draw_circle(Vector2(-20 + i * 10, 2.0), 2.4, Color("ffd24a") if on else Color("8a6b1c"))
	if fmod(t, 4.0) > 2.6:
		_cameos.draw_colored_polygon(PackedVector2Array([Vector2(-10, 8), Vector2(10, 8), Vector2(26, 70), Vector2(-26, 70)]), Color(0.7, 1.0, 0.8, 0.22))
	_cameos.draw_set_transform(Vector2.ZERO)

func _astronaut(p: Vector2, t: float) -> void:
	_cameos.draw_set_transform(p, t * 0.5, Vector2.ONE)
	var suit := Color("f3f5fa")
	for sign_ in [-1.0, 1.0]:
		_cameos.draw_line(Vector2(sign_ * 6, 6), Vector2(sign_ * 10 + sin(t * 2.0) * 2.0, 20), suit, 5.0, true)   # legs
		_cameos.draw_line(Vector2(sign_ * 9, -2), Vector2(sign_ * 17, 5 + sin(t * 1.5 + sign_) * 4.0), suit, 4.4, true)  # arms
	_cameos.draw_colored_polygon(_ellipse(Vector2(0, 3), 10.0, 12.0), suit)
	_cameos.draw_colored_polygon(_ellipse(Vector2(0, 3), 6.0, 7.0), Color("d6dbe8"))
	_cameos.draw_circle(Vector2(0, -12), 9.0, suit)
	_cameos.draw_colored_polygon(_ellipse(Vector2(1, -12), 6.0, 5.0), Color("2b3a63"))
	_cameos.draw_circle(Vector2(-1, -14), 1.6, Color(1, 1, 1, 0.8))
	_cameos.draw_set_transform(Vector2.ZERO)
	# the tether line floating behind
	_cameos.draw_polyline(PackedVector2Array([p + Vector2(-10, 4), p + Vector2(-26, 10), p + Vector2(-44, 4)]), Color(1, 1, 1, 0.35), 1.2, true)

func _satellite(p: Vector2, t: float) -> void:
	_cameos.draw_set_transform(p, t * 0.25, Vector2.ONE)
	for sign_ in [-1.0, 1.0]:
		_cameos.draw_rect(Rect2(Vector2(sign_ * 10 - (0 if sign_ > 0 else 24), -6), Vector2(24, 12)), Color("3a63c8"))
		for i in 3:
			_cameos.draw_line(Vector2(sign_ * (10 + i * 8) - (0 if sign_ > 0 else 24) + 8 * (1 if sign_ > 0 else 0), -6), Vector2(sign_ * (10 + i * 8) - (0 if sign_ > 0 else 24) + 8 * (1 if sign_ > 0 else 0), 6), Color("9fb8ff"), 1.0)
	_cameos.draw_rect(Rect2(Vector2(-8, -8), Vector2(16, 16)), Color("c9d1e2"))
	_cameos.draw_circle(Vector2(0, 0), 3.0, Color("ff4d4d") if fmod(t, 1.2) < 0.5 else Color("6b2323"))
	_cameos.draw_line(Vector2(0, -8), Vector2(0, -16), Color("c9d1e2"), 1.4)
	_cameos.draw_set_transform(Vector2.ZERO)

func _ellipse(center: Vector2, rx: float, ry: float, count := 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points
