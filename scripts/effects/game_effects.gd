extends Node2D
## Localized, bounded effects. No timers/tweens change gameplay or collision geometry.
const Palette = preload("res://scripts/ui/ui_palette.gd")
const SPARKLE = preload("res://Assets/Arcade/Online/sparkle.png")
const HAT_STAR = preload("res://Assets/Arcade/hat-yellow-star.svg")
var yellow_stars := false
var vivid_feedback := false
var particles: Array[Dictionary] = []
var trail: Array[Vector2] = []
var active := true
var reduced := false
var elapsed := 0.0
var success_audio: AudioStreamPlayer

func _ready() -> void:
	success_audio = AudioStreamPlayer.new()
	success_audio.stream = preload("res://Assets/Arcade/Online/success.ogg")
	success_audio.volume_db = -20
	add_child(success_audio)

var messages: Array[Dictionary] = []

func burst(at: Vector2, success: bool = true, show_message: bool = true) -> void:
	if success and show_message and success_audio and not success_audio.playing: success_audio.play()
	if reduced: return
	var color := (Color("ffed27") if yellow_stars or vivid_feedback else Palette.GOLD) if success else Color("ff708e")
	for i in 14:
		var direction := Vector2.from_angle(float(i) * TAU / 14.0)
		particles.append({"p": at, "v": direction * randf_range(110, 220), "life": 0.95, "color": color if yellow_stars else [Color("00eed0"), Color("ff593e"), Color("9850ff"), Color("ffdb35")][i % 4] if success else color, "star": yellow_stars and success, "size": randf_range(12, 20)})
	while particles.size() > 100: particles.pop_front()
	if show_message: messages.append({"p": at + Vector2(-38, -35), "life": 1.0, "text": "+1" if success else "Try again", "color": color})
	while messages.size() > 4: messages.pop_front()

func step(delta: float, paused: bool, ball: Vector2 = Vector2.INF) -> void:
	active = not paused
	reduced = bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	if paused: return
	elapsed += delta
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].p += particles[i].v * delta
		particles[i].v.y += 150.0 * delta
		if particles[i].life <= 0: particles.remove_at(i)
	for i in range(messages.size() - 1, -1, -1):
		messages[i].life -= delta
		messages[i].p.y -= delta * 35
		if messages[i].life <= 0: messages.remove_at(i)
	if ball != Vector2.INF and not reduced:
		trail.push_front(ball)
		if trail.size() > 12: trail.pop_back()
	else: trail.clear()
	queue_redraw()

func _draw() -> void:
	if reduced: return
	for i in trail.size():
		draw_circle(trail[i], maxf(2, 12 - i * 0.8), Color(0.55, 0.72, 1.0, (1.0 - i / 12.0) * 0.55))
	for p in particles:
		var color: Color = p.color
		color.a = clampf(p.life / (0.25 if vivid_feedback else 0.95), 0, 1)
		draw_circle(p.p, p.size * 1.25, Color(color, color.a * 0.16))
		if vivid_feedback:
			draw_circle(p.p, p.size * 0.65 + 2, Color(0.05, 0.13, 0.23, color.a))
			draw_circle(p.p, p.size * 0.65, color)
			draw_circle(p.p - Vector2(p.size * .18, p.size * .18), p.size * .18, Color(1, 1, 1, color.a))
		else:
			draw_texture_rect(HAT_STAR if p.star else SPARKLE, Rect2(p.p - Vector2.ONE * p.size, Vector2.ONE * p.size * 2), false, Color(1, 1, 1, color.a) if p.star else color)
	for m in messages:
		var color: Color = m.color
		color.a = clampf(m.life / 0.3, 0, 1)
		draw_string_outline(Palette.DISPLAY, m.p, m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 5, Color(0.08, 0.12, 0.22, color.a))
		draw_string(Palette.DISPLAY, m.p, m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
