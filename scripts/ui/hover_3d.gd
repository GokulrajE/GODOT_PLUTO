class_name Hover3D
extends Node
## Gives a button's picture a lifted, tilting "3D" hover: it grows, floats above a soft
## shadow and perspective-tilts toward the mouse. Attach with Hover3D.attach(button, picture).

const SHADER := preload("res://Assets/Arcade/tilt3d.gdshader")

var button: Control
var picture: TextureRect
var shadow: TextureRect
var shadow_strength := 0.30
var _hover := false
var _amount := 0.0
var _tilt := Vector2.ZERO
var _target := Vector2.ZERO

static func attach(btn: Control, pic: TextureRect, lift: float = 8.0) -> Hover3D:
	var h := Hover3D.new()
	h.button = btn
	h.picture = pic
	h.name = "Hover3D"
	btn.add_child(h)
	h._setup(lift)
	return h

var _lift := 8.0
var _in_container := false
var _base_top := 0.0
var _base_bottom := 0.0

func _setup(lift: float) -> void:
	_lift = lift
	picture.material = ShaderMaterial.new()
	picture.material.shader = SHADER
	picture.set_meta("full_color", true)
	_in_container = picture.get_parent() is Container     # container owns position: tilt + scale only
	if _in_container:
		picture.pivot_offset = picture.size * 0.5
		picture.resized.connect(func(): picture.pivot_offset = picture.size * 0.5)
		button.mouse_entered.connect(func(): _hover = true)
		button.mouse_exited.connect(func(): _hover = false; _target = Vector2.ZERO)
		button.gui_input.connect(_on_gui_input)
		return
	# soft drop shadow: same silhouette, black, drawn behind the picture
	shadow = TextureRect.new()
	shadow.texture = picture.texture
	shadow.expand_mode = picture.expand_mode
	shadow.stretch_mode = picture.stretch_mode
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_meta("full_color", true)
	shadow.self_modulate = Color(0, 0, 0, 0)
	for side in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]:
		shadow.set(side, picture.get(side))
	_base_top = picture.offset_top
	_base_bottom = picture.offset_bottom
	var parent := picture.get_parent()
	parent.add_child(shadow)
	parent.move_child(shadow, picture.get_index())
	for c in [picture, shadow]:
		(c as Control).pivot_offset = (c as Control).size * 0.5
		(c as Control).resized.connect(func(): (c as Control).pivot_offset = (c as Control).size * 0.5)
	button.mouse_entered.connect(func(): _hover = true)
	button.mouse_exited.connect(func(): _hover = false; _target = Vector2.ZERO)
	button.gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and button.size.x > 0.0 and button.size.y > 0.0:
		_target = ((event.position / button.size) - Vector2(0.5, 0.5)) * 2.0
		_target = _target.limit_length(1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(picture): return
	var reduced := bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
	var goal := 1.0 if _hover else 0.0
	_amount = goal if reduced else move_toward(_amount, goal, delta * 6.0)
	_tilt = _target if reduced else _tilt.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
	var m := picture.material as ShaderMaterial
	m.set_shader_parameter("tilt", _tilt)
	m.set_shader_parameter("amount", _amount)
	var e := ease(_amount, -2.0)               # ease-out curve
	var s := 1.0 + 0.20 * e
	picture.scale = Vector2(s, s)
	if _in_container:
		button.z_index = 1 if _amount > 0.01 else 0
		return
	picture.offset_top = _base_top - _lift * e
	picture.offset_bottom = _base_bottom - _lift * e
	shadow.scale = Vector2(s * 0.94, s * 0.94)
	shadow.offset_top = _base_top + _lift * 0.9 * e
	shadow.offset_bottom = _base_bottom + _lift * 0.9 * e
	shadow.self_modulate = Color(0, 0, 0, shadow_strength * e)
	button.z_index = 1 if _amount > 0.01 else 0
