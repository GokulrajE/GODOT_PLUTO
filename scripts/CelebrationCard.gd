extends Control
class_name CelebrationCard

signal star_reached_header
signal celebration_done

@export var trophy_texture: Texture2D
@export var score_unit: String = "catches"

@onready var _overlay:   ColorRect          = $Overlay
@onready var _card:      Panel              = $Card
@onready var _ribbon:    TextureRect        = $Card/Ribbon
@onready var _trophy:    TextureRect        = $Card/BodyHBox/Trophy
@onready var _title_lbl: Label              = $Card/BodyHBox/ScoreVBox/TitleLabel
@onready var _arr_lbl:   Label              = $Card/BodyHBox/ScoreVBox/ArrowLabel
@onready var _yest_lbl:  Label              = $Card/BodyHBox/ScoreVBox/YesterdayLabel
@onready var _today_lbl: Label              = $Card/BodyHBox/ScoreVBox/TodayLabel
@onready var _star_tex:  TextureRect        = $Card/BodyHBox/ScoreVBox/StarTex
@onready var _audio:     AudioStreamPlayer  = $Audio

func _ready() -> void:
	visible = false
	if trophy_texture:
		_trophy.texture = trophy_texture

func show_celebration(yesterday_hits: int, today_hits: int, header_star_rect: Rect2) -> void:
	_yest_lbl.text  = "Yesterday:  %d %s" % [yesterday_hits, score_unit]
	_today_lbl.text = "Today:  %d %s"     % [today_hits, score_unit]

	_overlay.color      = Color(0, 0, 0.08, 0.0)
	_card.modulate      = Color(1, 1, 1, 0)
	_card.scale         = Vector2(0.35, 0.35)
	_ribbon.modulate    = Color(1, 1, 1, 0)
	_trophy.modulate    = Color(1, 1, 1, 0)
	_title_lbl.modulate = Color(1, 1, 1, 0)
	_arr_lbl.modulate   = Color(1, 1, 1, 0)
	_yest_lbl.modulate  = Color(1, 1, 1, 0)
	_today_lbl.modulate = Color(1, 1, 1, 0)
	_star_tex.modulate  = Color(1, 1, 1, 0)
	_star_tex.scale     = Vector2(1, 1)
	_star_tex.visible   = true

	visible = true
	if _audio and _audio.stream:
		_audio.play()

	_animate(header_star_rect)

func _animate(header_star_rect: Rect2) -> void:
	_card.pivot_offset = Vector2(270.0, 230.0)

	# 1. Overlay fade in
	var t1 := create_tween()
	t1.tween_property(_overlay, "color", Color(0, 0, 0.08, 0.72), 0.4)
	await t1.finished

	# 2. Card bounce in
	var t2 := create_tween()
	t2.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t2.tween_property(_card, "scale",   Vector2(1, 1), 0.45)
	t2.parallel().tween_property(_card, "modulate", Color(1, 1, 1, 1), 0.3)
	await t2.finished

	# 3. Ribbon + trophy fade in
	var t3 := create_tween()
	t3.set_parallel(true)
	t3.tween_property(_ribbon, "modulate", Color(1, 1, 1, 1), 0.3)
	t3.tween_property(_trophy, "modulate", Color(1, 1, 1, 1), 0.35)
	await t3.finished

	# 4. Labels stagger
	for lbl: Label in [_title_lbl, _arr_lbl, _yest_lbl, _today_lbl]:
		var t := create_tween()
		t.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.22)
		await t.finished
		await get_tree().create_timer(0.06).timeout

	# 5. Star pop in
	_star_tex.scale       = Vector2(0.1, 0.1)
	_star_tex.pivot_offset = Vector2(36, 36)
	var t5 := create_tween()
	t5.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t5.tween_property(_star_tex, "modulate", Color(1, 1, 1, 1), 0.1)
	t5.parallel().tween_property(_star_tex, "scale", Vector2(1.1, 1.1), 0.35)
	await t5.finished
	var t5b := create_tween()
	t5b.tween_property(_star_tex, "scale", Vector2(1.0, 1.0), 0.1)
	await t5b.finished

	# 6. Pulse 3x
	for _i in 3:
		var tp := create_tween()
		tp.tween_property(_star_tex, "scale", Vector2(1.25, 1.25), 0.18)
		tp.tween_property(_star_tex, "scale", Vector2(1.0,  1.0),  0.15)
		await tp.finished

	# 7. Hold
	await get_tree().create_timer(2.2).timeout

	# 8. Fly star to header
	_fly_star_to_header(header_star_rect)

func _fly_star_to_header(header_star_rect: Rect2) -> void:
	await get_tree().process_frame

	# Center of the card star → center of the header star
	var from_pos := _star_tex.get_global_rect().get_center() - Vector2(36, 36)
	# pivot_offset=(36,36) means the node's center is at position+(36,36),
	# so we subtract (36,36) to land the center on the header star center.
	var to_pos   := header_star_rect.get_center() - Vector2(36, 36)

	var fly := TextureRect.new()
	fly.texture             = _star_tex.texture
	fly.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE   # do NOT grow to texture size
	fly.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.custom_minimum_size = Vector2(72, 72)
	fly.pivot_offset        = Vector2(36, 36)
	fly.position            = from_pos
	get_parent().add_child(fly)
	fly.size = Vector2(72, 72)   # force size after layout pass

	_star_tex.visible = false

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fly, "position", to_pos,               0.75)
	tween.parallel().tween_property(fly, "scale", Vector2(0.42, 0.42), 0.75)
	await tween.finished
	fly.queue_free()

	star_reached_header.emit()

	# Card fade out
	var t_out := create_tween()
	t_out.set_parallel(true)
	t_out.tween_property(_overlay, "color",    Color(0, 0, 0.08, 0.0), 0.4)
	t_out.tween_property(_card,    "modulate", Color(1, 1, 1, 0.0),    0.35)
	await t_out.finished
	visible = false

	celebration_done.emit()
