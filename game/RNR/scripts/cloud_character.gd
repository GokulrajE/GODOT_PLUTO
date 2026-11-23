extends Control
## The Rain & Rise cloud as a character: it breathes, leans into its movement, looks at the plant it
## has to water and reacts to what happens - eager while searching, joyful while raining, worried when
## time is running out, delighted on a success and sad on a miss. Purely visual: it reads the game's
## state and never changes it. Child of the game's "Cloud" node (which keeps the position).

const E_WAIT := 0
const E_SEEK := 1
const E_RAIN := 2
const E_WORRY := 3
const E_CHEER := 4
const E_SAD := 5
const E_DONE := 6

const INK := Color("22344f")
const CHEEK := Color(1.0, 0.55, 0.62, 0.55)

var game: Control
var texture: Texture2D

var _t := 0.0
var _emotion := E_SEEK
var _prev_state := -1
var _prev_x := 0.0
var _vx := 0.0
var _hop := 0.0               # vertical offset (negative = up)
var _hop_v := 0.0
var _squash := 0.0            # +: taller / thinner, -: wider / flatter
var _squash_v := 0.0
var _blink := 0.0             # 1 = eyes shut
var _blink_in := 2.0
var _look := Vector2.ZERO
# smoothed face parameters
var _smile := 0.5             # -1 frown ... +1 grin
var _open := 0.0              # mouth open amount
var _happy_eyes := 0.0        # 1 = closed happy arcs (^ ^)
var _brow := 0.0              # -1 worried ... +1 raised
var _cheek := 0.5
var _sad_tint := 0.0
var _sparkles: Array = []
var _drips: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("arcade_authored_control", true)
	if game:
		_prev_x = float(game.get("_cloud_x"))

func _paused() -> bool:
	return game == null or not is_instance_valid(game) or game.get("_state") == game.State.PAUSED

func _pick_emotion() -> int:
	var state: int = game.get("_state")
	var s = game.State
	if state == s.WAITING: return E_WAIT
	if state == s.SUCCESS: return E_CHEER
	if state == s.FAILURE: return E_SAD
	if state == s.STOP or state == s.DONE: return E_DONE
	if state == s.MOVE:
		if bool(game.get("_is_raining")): return E_RAIN
		var limit := maxf(float(game.get("_move_duration")), 0.1)
		if float(game.get("_highlight_timer")) / limit > 0.65: return E_WORRY
	return E_SEEK

func _process(delta: float) -> void:
	if _paused():
		return
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	_t += delta * (0.4 if reduced else 1.0)
	var cloud_x := float(game.get("_cloud_x"))
	_vx = lerpf(_vx, (cloud_x - _prev_x) / maxf(delta, 0.0001), 1.0 - exp(-12.0 * delta))
	_prev_x = cloud_x

	var emotion := _pick_emotion()
	if emotion != _emotion:
		_on_emotion_change(_emotion, emotion)
		_emotion = emotion

	# where the cloud is looking: toward the plant it has to water
	var look_goal := Vector2.ZERO
	var target: int = int(game.get("_target_seed"))
	var slots: Array = game.get("_slot_positions")
	if target >= 0 and target < slots.size() and _emotion in [E_SEEK, E_WORRY, E_RAIN]:
		look_goal.x = clampf((float(slots[target]) - cloud_x) / 220.0, -1.0, 1.0)
		look_goal.y = 0.7 if _emotion != E_RAIN else 0.9      # down toward the ground
	elif absf(_vx) > 30.0:
		look_goal.x = clampf(_vx / 400.0, -1.0, 1.0)
	_look = _look.lerp(look_goal, 1.0 - exp(-9.0 * delta))

	# blinking
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 1.0
		_blink_in = randf_range(2.2, 4.8)
	_blink = maxf(0.0, _blink - delta * 7.0)

	# face targets per emotion
	var smile := 0.5
	var open := 0.0
	var happy := 0.0
	var brow := 0.0
	var cheek := 0.5
	match _emotion:
		E_WAIT:
			smile = 0.35
		E_SEEK:
			smile = 0.55; brow = 0.35
		E_RAIN:
			var pct := clampf(float(game.get("_rain_timer")) / maxf(float(game.get("_rain_duration_to_grow")), 0.05), 0.0, 1.0)
			smile = 0.8; open = 0.35 + 0.35 * pct; happy = 1.0; cheek = 0.9
		E_WORRY:
			smile = -0.15; brow = -0.9; open = 0.15
		E_CHEER:
			smile = 1.0; open = 0.9; happy = 0.0; cheek = 1.0; brow = 0.8
		E_SAD:
			smile = -0.9; brow = -1.0; cheek = 0.2
		E_DONE:
			smile = 0.9; open = 0.25; happy = 0.6; cheek = 0.9
	var k := 1.0 - exp(-10.0 * delta)
	_smile = lerpf(_smile, smile, k)
	_open = lerpf(_open, open, k)
	_happy_eyes = lerpf(_happy_eyes, happy, k)
	_brow = lerpf(_brow, brow, k)
	_cheek = lerpf(_cheek, cheek, k)
	_sad_tint = lerpf(_sad_tint, 1.0 if _emotion == E_SAD else 0.0, 1.0 - exp(-5.0 * delta))

	# body springs: hop on a success, squash on events
	_hop_v += 1500.0 * delta
	_hop += _hop_v * delta
	if _hop > 0.0:
		_hop = 0.0
		if _hop_v > 120.0: _squash_v = -3.0        # landing squish
		_hop_v = 0.0
	_squash_v += (-60.0 * _squash - 9.0 * _squash_v) * delta
	_squash += _squash_v * delta

	# sparkles when cheering, a falling tear when sad
	if _emotion == E_CHEER and randf() < delta * 18.0:
		_sparkles.append({"pos": Vector2(randf_range(0.1, 0.9) * size.x, randf_range(-0.1, 0.5) * size.y), "age": 0.0, "life": randf_range(0.5, 0.9), "size": randf_range(4.0, 8.0)})
	if _emotion == E_SAD and randf() < delta * 2.2:
		_drips.append({"pos": Vector2(0.64 * size.x, 0.6 * size.y), "v": 0.0})
	for sparkle in _sparkles: sparkle.age += delta
	_sparkles = _sparkles.filter(func(s): return s.age < s.life)
	for drip in _drips:
		drip.v += 260.0 * delta
		drip.pos.y += drip.v * delta
	_drips = _drips.filter(func(d): return d.pos.y < size.y * 1.4)
	queue_redraw()

func _on_emotion_change(_from: int, to: int) -> void:
	if to == E_CHEER:
		_hop_v = -330.0
		_squash_v = 2.5
	elif to == E_SAD:
		_squash_v = -2.5
	elif to == E_RAIN:
		_squash_v = 1.8

# ── Drawing ───────────────────────────────────────────────────────────────────

func _arc_points(center: Vector2, rx: float, ry: float, from_a: float, to_a: float, count := 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count + 1:
		var a := lerpf(from_a, to_a, float(i) / float(count))
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

func _draw() -> void:
	var center := size * 0.5
	var breathe := sin(_t * 2.2) * 0.025
	var effort := 0.0
	if _emotion == E_RAIN: effort = sin(_t * 30.0) * 1.2          # a little shake while raining
	var stretch_x := 1.0 + clampf(absf(_vx) / 2600.0, 0.0, 0.10) - _squash * 0.06
	var stretch_y := 1.0 + breathe + _squash * 0.10 - clampf(absf(_vx) / 5200.0, 0.0, 0.05)
	if _emotion == E_SAD: stretch_y *= 0.94
	var lean := clampf(_vx / 5200.0, -0.13, 0.13)
	var bob := sin(_t * 1.7) * 3.0
	var origin := center + Vector2(effort, _hop + bob)
	draw_set_transform(origin, lean, Vector2(stretch_x, stretch_y))

	_draw_body(center)
	_draw_face(center)
	draw_set_transform(Vector2.ZERO)
	_draw_extras(center, origin)

# The puffy body is drawn from circles so the face can be animated freely: outline, soft fill with a
# darker belly and a bright top highlight.
const PUFFS := [
	[-0.30, 0.10, 0.20], [-0.10, -0.14, 0.26], [0.16, -0.20, 0.28], [0.34, 0.02, 0.22], [0.0, 0.10, 0.28],
]

func _draw_body(center: Vector2) -> void:
	var u := size.x
	var fill := Color(0.80, 0.93, 1.0).lerp(Color(0.66, 0.74, 0.86), _sad_tint)
	var belly := Color(0.62, 0.82, 0.97).lerp(Color(0.55, 0.62, 0.76), _sad_tint)
	var outline := Color(0.22, 0.46, 0.72)
	var base := Rect2(Vector2(-u * 0.40, u * 0.04) , Vector2(u * 0.80, u * 0.24))
	# outline pass
	for puff in PUFFS:
		draw_circle(Vector2(puff[0], puff[1] + 0.02) * u, puff[2] * u + 3.0, outline)
	draw_rect(base.grow(3.0), outline)
	draw_circle(base.position + Vector2(0, base.size.y * 0.5), base.size.y * 0.5 + 3.0, outline)
	draw_circle(base.end - Vector2(0, base.size.y * 0.5), base.size.y * 0.5 + 3.0, outline)
	# belly (darker) then fill
	for puff in PUFFS:
		draw_circle(Vector2(puff[0], puff[1] + 0.02) * u, puff[2] * u, belly)
	draw_rect(base, belly)
	draw_circle(base.position + Vector2(0, base.size.y * 0.5), base.size.y * 0.5, belly)
	draw_circle(base.end - Vector2(0, base.size.y * 0.5), base.size.y * 0.5, belly)
	for puff in PUFFS:
		draw_circle(Vector2(puff[0], puff[1] - 0.025) * u, puff[2] * u * 0.94, fill)
	draw_rect(Rect2(base.position + Vector2(0, -2), Vector2(base.size.x, base.size.y * 0.55)), fill)
	# highlight on the upper left of the top puff
	draw_arc(Vector2(-0.12, -0.17) * u, 0.20 * u, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.9), 3.0, true)
	draw_arc(Vector2(-0.31, 0.07) * u, 0.15 * u, PI * 1.0, PI * 1.35, 8, Color(1, 1, 1, 0.7), 2.5, true)

func _draw_face(center: Vector2) -> void:
	var w := size.x
	var h := size.y
	var eye_y := h * 0.04
	var eye_dx := w * 0.135
	var eye_open := (1.0 - _blink) * (1.0 - _happy_eyes)
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * eye_dx, eye_y)
		# eyebrows (raised when excited, tilted up toward the middle when worried)
		if absf(_brow) > 0.05:
			var lift := -h * (0.105 + 0.045 * _brow)
			var tilt := (-_brow * 3.2) if _brow < 0.0 else 0.0       # worried: inner ends rise
			draw_line(eye + Vector2(side * 6.0, lift + tilt), eye + Vector2(-side * 6.0, lift - tilt), INK, 2.2, true)
		if _happy_eyes > 0.5:
			# closed, laughing eyes: ^ ^
			draw_polyline(_arc_points(eye + Vector2(0, 2.5), 6.5, 6.0, PI * 1.12, PI * 1.88, 10), INK, 2.8, true)
		elif eye_open < 0.15:
			draw_line(eye + Vector2(-6, 0), eye + Vector2(6, 0), INK, 2.6, true)
		else:
			var ry := 8.5 * eye_open
			var pupil_shift := Vector2(_look.x * 2.6, _look.y * 2.2)
			draw_colored_polygon(_ellipse(eye, 6.2, ry), INK)
			draw_circle(eye + pupil_shift + Vector2(1.8, -2.4 * eye_open), 2.3 * eye_open, Color.WHITE)
			draw_circle(eye + pupil_shift + Vector2(-1.8, 2.6 * eye_open), 1.1 * eye_open, Color(1, 1, 1, 0.85))
	# cheeks
	for side in [-1.0, 1.0]:
		var cheek := CHEEK
		cheek.a *= _cheek
		draw_colored_polygon(_ellipse(Vector2(side * w * 0.215, h * 0.135), 7.5, 4.6), cheek)
	_draw_mouth(h)

func _ellipse(center: Vector2, rx: float, ry: float, count := 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

func _draw_mouth(h: float) -> void:
	var base := Vector2(0, h * 0.145)
	var width := 7.0 + 4.0 * clampf(_smile, 0.0, 1.0) + 3.0 * _open
	if _open > 0.12 and _smile > -0.1:
		# open smile: a D-shaped mouth with a tongue
		var depth := 3.0 + 9.0 * _open
		var points := PackedVector2Array([base + Vector2(-width, 0), base + Vector2(width, 0)])
		for p in _arc_points(base, width, depth, 0.0, PI, 12): points.append(p)
		draw_colored_polygon(points, INK)
		var tongue := _arc_points(base + Vector2(0, depth * 0.55), width * 0.5, depth * 0.45, 0.0, PI, 8)
		var tongue_poly := PackedVector2Array()
		tongue_poly.append(base + Vector2(-width * 0.5, depth * 0.55))
		tongue_poly.append(base + Vector2(width * 0.5, depth * 0.55))
		for p in tongue: tongue_poly.append(p)
		draw_colored_polygon(tongue_poly, Color("ff7c8f"))
	elif _open > 0.12:
		# small worried "o"
		draw_colored_polygon(_ellipse(base + Vector2(0, 3), 3.6, 4.6 * (0.6 + _open)), INK)
	else:
		# smile or frown curve
		var curve := clampf(_smile, -1.0, 1.0)
		var points := PackedVector2Array()
		for i in 11:
			var u := float(i) / 10.0
			var x := lerpf(-width, width, u)
			var y := (1.0 - pow(2.0 * u - 1.0, 2.0)) * 5.5 * curve
			points.append(base + Vector2(x, y - 1.0))
		draw_polyline(points, INK, 2.6, true)

func _star(center: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		var radius := r if i % 2 == 0 else r * 0.38
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)

func _draw_extras(center: Vector2, origin: Vector2) -> void:
	for sparkle in _sparkles:
		var life: float = clampf(sparkle.age / sparkle.life, 0.0, 1.0)
		var alpha := 1.0 - life
		_star(sparkle.pos + Vector2(0, -life * 18.0), sparkle.size * (1.0 - life * 0.4), Color(1.0, 0.93, 0.45, alpha))
	for drip in _drips:
		var alpha := clampf(1.0 - (drip.pos.y - size.y * 0.6) / (size.y * 0.8), 0.0, 1.0)
		draw_colored_polygon(_ellipse(drip.pos, 2.6, 4.2, 10), Color(0.55, 0.78, 1.0, alpha))
	if _emotion == E_WAIT:
		# sleepy Zs while the game has not started
		for i in 3:
			var phase := fmod(_t * 0.5 + float(i) / 3.0, 1.0)
			var pos := Vector2(size.x * 0.78 + phase * 18.0, size.y * 0.1 - phase * 34.0)
			var font := get_theme_default_font()
			draw_string(font, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 + phase * 10), Color(0.2, 0.3, 0.5, 1.0 - phase))
	if _emotion == E_WORRY:
		# a nervous sweat drop that wobbles
		var drop := Vector2(size.x * 0.76, size.y * 0.22 + sin(_t * 8.0) * 1.5)
		draw_colored_polygon(_ellipse(drop + Vector2(0, 3), 3.0, 4.2, 10), Color(0.6, 0.82, 1.0, 0.95))
		draw_colored_polygon(PackedVector2Array([drop + Vector2(-2.4, 1.5), drop + Vector2(2.4, 1.5), drop + Vector2(0, -6)]), Color(0.6, 0.82, 1.0, 0.95))
