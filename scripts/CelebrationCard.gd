extends Control
class_name CelebrationCard
## Reward presentation is independent from scoring and patient persistence.
signal star_reached_header
signal celebration_done
const Assets = preload("res://scripts/ui/arcade_assets.gd")
@export var trophy_texture: Texture2D
@export var score_unit: String = "catches"
@onready var _overlay: ColorRect = $Overlay
@onready var _card: Panel = $Card
@onready var _star: TextureRect = $Card/BodyHBox/ScoreVBox/StarTex
var _animating := false
var confetti: Node2D

func _ready() -> void:
	visible = false
	confetti = preload("res://scripts/effects/game_effects.gd").new()
	add_child(confetti)
	_overlay.show()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.position = size * 0.5 - Vector2(320, 205)
	_card.size = Vector2(640, 410)
	for key in ["Ribbon", "ConfettiBg", "PopperLeft", "PopperRight", "StarTL", "StarTR", "StarBL", "StarBR"]:
		_card.get_node(key).hide()
	var ribbon: Label = $Card/RibbonLabel
	ribbon.text = "STAR EARNED"
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ribbon.position = Vector2(24, 24)
	ribbon.size = Vector2(592, 50)
	ribbon.add_theme_font_size_override("font_size", 32)
	$Card/BodyHBox/Trophy.hide()
	$Card/BodyHBox.offset_top = 90
	$Card/BodyHBox.offset_left = 28
	$Card/BodyHBox.offset_right = -28
	$Card/BodyHBox.offset_bottom = -24
	$Card/BodyHBox/ScoreVBox.add_theme_constant_override("separation", 8)
	for key in ["TitleLabel", "ArrowLabel", "YesterdayLabel", "TodayLabel"]:
		var label: Label = $Card/BodyHBox/ScoreVBox.get_node(key)
		label.add_theme_font_size_override("font_size", 24 if key in ["TitleLabel", "TodayLabel"] else 19)
	$Card/BodyHBox/ScoreVBox/ArrowLabel.text = "A new personal best"
	$Card/BodyHBox/ScoreVBox/TitleLabel.text = "KEEP GROWING!"
	_star.texture = Assets.sprite("star")
	_star.custom_minimum_size = Vector2(64, 64)
	_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func show_celebration(yesterday_hits: int, today_hits: int, header_star_rect: Rect2) -> void:
	if _animating: return
	_animating = true
	$Card/BodyHBox/ScoreVBox/YesterdayLabel.text = "Yesterday: %d %s" % [yesterday_hits, score_unit]
	$Card/BodyHBox/ScoreVBox/TodayLabel.text = "Today: %d %s" % [today_hits, score_unit]
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE if reduced else Vector2(0.94, 0.94)
	_card.modulate = Color.WHITE
	_overlay.color = Color(0.18, 0.28, 0.36, 0.25)
	_star.show()
	show()
	$Audio.volume_db = -14
	$Audio.play()
	if not reduced:
		confetti.burst(size * 0.5 + Vector2(-220, -110), true, false)
		confetti.burst(size * 0.5 + Vector2(220, -110), true, false)
		var entrance := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		entrance.tween_property(_card, "scale", Vector2.ONE, 0.25)
		await entrance.finished
	var hold := create_tween()
	hold.tween_interval(1.6)
	await hold.finished
	if not reduced:
		var fly := TextureRect.new()
		fly.texture = _star.texture
		fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fly)
		fly.size = Vector2(64, 64)
		fly.pivot_offset = Vector2(32, 32)
		fly.global_position = _star.get_global_rect().get_center() - Vector2(32, 32)
		_star.hide()
		var flight := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		flight.tween_property(fly, "global_position", header_star_rect.get_center() - Vector2(32, 32), 0.55)
		flight.parallel().tween_property(fly, "scale", Vector2(0.5, 0.5), 0.55)
		await flight.finished
		fly.queue_free()
	star_reached_header.emit()
	if not reduced:
		var fade := create_tween()
		fade.tween_property(_card, "modulate:a", 0, 0.2)
		fade.parallel().tween_property(_overlay, "color:a", 0, 0.2)
		await fade.finished
	hide()
	_animating = false
	celebration_done.emit()

func _process(delta: float) -> void:
	if confetti and visible: confetti.step(delta, false)
