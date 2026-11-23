extends Control
## First screen: full-bleed Welcome.png; moves on by itself after AUTO_ADVANCE_SECONDS (a key or click skips).

const NEXT_SCENE := "res://scenes/MainScene.tscn"
const AUTO_ADVANCE_SECONDS := 0.5

var _leaving := false
var _fade: ColorRect

func _ready() -> void:
	var art := TextureRect.new()
	art.texture = load("res://Assets/mechanismImages/Welcome.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_meta("full_color", true)   # keep UiManager from turning it into a flat silhouette
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().create_timer(AUTO_ADVANCE_SECONDS).timeout.connect(_continue)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_continue()
	elif event is InputEventMouseButton and event.pressed:
		_continue()

func _continue() -> void:
	if _leaving: return
	_leaving = true
	# the light opens from the PLUTO logo (just above the centre of the screen)
	MagicTransition.go(self, NEXT_SCENE, get_viewport_rect().size * Vector2(0.5, 0.42))
