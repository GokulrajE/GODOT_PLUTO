extends Node
const Palette = preload("res://scripts/ui/ui_palette.gd")
const Motion = preload("res://scripts/ui/ui_motion.gd")
const Assets = preload("res://scripts/ui/arcade_assets.gd")
const Layout = preload("res://scripts/gameplay/playfield_layout.gd")
const GameView = preload("res://scripts/gameplay/game_presentation.gd")
var shared_theme: Theme

func _ready() -> void:
	shared_theme = Palette.theme()
	get_tree().node_added.connect(_on_node_added)
	if "--ui-startup-test" in OS.get_cmdline_user_args():
		var probe := Node.new()
		probe.set_script(load("res://tests/gameplay/normal_startup.gd"))
		add_child.call_deferred(probe)

func _process(_delta: float) -> void:
	# The initial main scene can receive its scene_file_path after node_added.
	# Reconcile once its identity is available; also covers F6 scene launches.
	var scene := get_tree().current_scene
	if scene is Control and not scene.has_meta("arcade_decorated"):
		if scene.scene_file_path.is_empty(): return
		var game := scene.scene_file_path.begins_with("res://game/")
		Layout.configure(get_window(), game)
		_decorate_scene(scene, game)
		_style_tree(scene)

func _style_tree(node: Node) -> void:
	if node is Control: _style(node)
	for child in node.get_children(): _style_tree(child)

func _on_node_added(node: Node) -> void:
	if node is Control:
		if node.get_parent() == get_tree().root and not node.scene_file_path.is_empty():
			var game := node.scene_file_path.begins_with("res://game/")
			Layout.configure(get_window(), game)
			_decorate_if_alive.call_deferred(node.get_instance_id(), game)
		_style_if_alive.call_deferred(node.get_instance_id())

func _style_if_alive(instance_id: int) -> void:
	var node = instance_from_id(instance_id)
	if is_instance_valid(node) and node is Control: _style(node)

func _decorate_if_alive(instance_id: int, game: bool) -> void:
	var node = instance_from_id(instance_id)
	if is_instance_valid(node) and node is Control: _decorate_scene(node, game)

func _decorate_scene(scene: Control, game: bool) -> void:
	if not is_instance_valid(scene) or scene.has_meta("arcade_decorated"): return
	scene.set_meta("arcade_decorated", true)
	if not game:
		_clear_status_badge(scene)
		var backdrop := scene.get_node_or_null("ArcadeBackdrop") as TextureRect
		if backdrop and scene.name != "WelcomeScene":
			backdrop.texture = preload("res://Assets/menu_background_blur.png")
			backdrop.modulate = Color.WHITE
	if scene.has_meta("arcade_authored"):
		if scene.name == "MainScene":
			var music: CheckButton = scene.get_node("MusicToggle")
			music.button_pressed = not MenuMusic.muted
			music.toggled.connect(func(enabled: bool): MenuMusic.set_muted(not enabled))
			var motion: CheckButton = scene.get_node("ReducedMotion")
			motion.button_pressed = bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
			motion.toggled.connect(func(enabled: bool): ProjectSettings.set_setting("pluto/ui/reduced_motion", enabled))
			scene.get_node("DemoButton").pressed.connect(func():
				if AppUpdater.blocks_login(): return
				AppData.enter_demo()
				get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
			)
		return
	if game:
		var view := GameView.new()
		view.name = "ArcadePresentation"
		scene.add_child(view)
		return
	var bg := Control.new()
	bg.set_script(preload("res://scripts/ui/arcade_backdrop.gd"))
	bg.name = "ArcadeBackdrop"
	scene.add_child(bg)
	scene.move_child(bg, 0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if scene.name == "MainScene":
		var motion := CheckButton.new()
		motion.name = "ReducedMotion"
		motion.text = "Reduced motion"
		motion.tooltip_text = "Disables UI animations for a calmer experience"
		motion.button_pressed = bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))
		scene.add_child(motion)
		# Anchor to top-right so it adapts to any window size
		motion.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
		motion.offset_left  = -244
		motion.offset_right = -24
		motion.offset_top   = 20
		motion.offset_bottom = 64
		motion.toggled.connect(func(enabled: bool): ProjectSettings.set_setting("pluto/ui/reduced_motion", enabled))
		var demo := Button.new()
		demo.name = "DemoButton"
		demo.text = "TRY THE GAMES  •  KEYBOARD DEMO"
		demo.set_meta("secondary", true)
		demo.custom_minimum_size = Vector2(480, 48)
		scene.add_child(demo)
		# Anchor to center-bottom; offsets expressed relative to that anchor
		demo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
		demo.offset_left   = -240
		demo.offset_right  =  240
		demo.offset_top    = -68
		demo.offset_bottom = -20
		demo.pressed.connect(func():
			if AppUpdater.blocks_login(): return
			AppData.enter_demo()
			get_tree().change_scene_to_file("res://scenes/ChooseGameScene.tscn")
		)

## The device-status badge sits in the top-right corner; nudge any button that would overlap it.
func _clear_status_badge(scene: Control) -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return
	var win := Vector2(scene.get_viewport_rect().size)
	var badge := Rect2(win.x - 70.0, 8.0, 64.0, 64.0)
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children(): stack.append(child)
		var button := node as BaseButton
		if button == null or not button.is_visible_in_tree() or button.name == "ReducedMotion": continue
		if button.get_script() == preload("res://scripts/ui/reference_frame.gd") : continue
		var rect := button.get_global_rect()
		if not rect.intersects(badge) or rect.size.x > win.x * 0.5: continue
		var dx := rect.end.x - badge.position.x + 12.0
		if button.anchor_left >= 0.9:
			button.offset_left -= dx
			button.offset_right -= dx
		else:
			button.position.x -= dx

func _style(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	var control := node as Control
	var key := str(control.name).to_lower()
	if control is TextureRect and control.texture and control.texture.resource_path.contains("mechanismImages") and not control.has_meta("full_color"):
		if not control.get_script(): control.set_script(preload("res://scripts/ui/mechanism_contrast.gd")); control._ready()
	if control.has_meta("arcade_authored_control"):
		if control is BaseButton: Motion.bind(control)
		if key in ["waitpanel", "pausepanel", "gameoverpanel", "speedpanel"]: Motion.bind_modal(control)
		return
	var game := false
	var ancestor: Node = node
	var in_hud := false
	while ancestor:
		if ancestor.name == "UI": in_hud = true
		if ancestor.scene_file_path.begins_with("res://game/"): game = true
		ancestor = ancestor.get_parent()
	control.theme = shared_theme
	if control is Button:
		var secondary: bool = control.get_meta("secondary", false) or key.contains("back") or key.contains("exit") or key.contains("demo") or key == "registerbutton" or control.toggle_mode or control.get_parent().name in ["GameGrid", "MechGrid"]
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var variant := "frame-blue" if secondary else "button-lime"
			if state in ["pressed", "hover_pressed"] and secondary: variant = "button-purple"
			if state == "disabled": variant = "field-blue"
			var style := Palette.chrome(variant)
			if state == "hover": style.modulate_color = Color(1.15, 1.15, 1.15)
			control.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			control.add_theme_color_override(state, Palette.INK if secondary else Color("123f47"))
		control.add_theme_color_override("font_disabled_color", Color("7b8fa2"))
		var focus := Palette.surface(Color.TRANSPARENT, 14, Palette.GOLD)
		focus.draw_center = false
		focus.shadow_size = 0
		focus.set_border_width_all(3)  # thicker ring for keyboard visibility
		control.add_theme_stylebox_override("focus", focus)
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		Motion.bind(control)
	elif control is LineEdit:
		for state in ["normal", "read_only", "focus"]:
			control.add_theme_stylebox_override(state, Palette.chrome("frame-blue" if state == "focus" else "field-blue"))
		for state in ["font_color", "font_uneditable_color", "caret_color"]:
			control.add_theme_color_override(state, Palette.INK)
		control.add_theme_color_override("font_placeholder_color", Color("a3b3c2"))
		control.add_theme_color_override("selection_color", Color("7244be"))
	elif control is Label:
		if key == "readycountlabel": control.modulate = Color.WHITE
		var old := control.get_theme_color("font_color")
		var text_color := Palette.INK
		if key == "playlabel": text_color = Palette.ACCENT
		elif key.contains("starcount") or key.contains("value"): text_color = Palette.GOLD
		elif key == "loginstatus": text_color = Palette.MUTED
		elif old.r > old.g * 1.5 and old.r > 0.5: text_color = Color("bd3653")
		elif key.contains("desc") or key.contains("sub") or key.contains("hint"): text_color = Palette.MUTED
		control.add_theme_color_override("font_color", text_color)
		if control.get_theme_font_size("font_size") >= 24 and not key.contains("angle"):
			control.add_theme_font_override("font", Palette.DISPLAY)
			control.add_theme_constant_override("outline_size", 0)
			control.add_theme_color_override("font_outline_color", Palette.INK)
	elif control is Panel or control is PanelContainer:
		# Gameplay rings/bars own their colors and are deliberately excluded.
		if game and not in_hud: return
		if key in ["bar", "goalline"] or key.contains("cursor") or key.contains("track") or key.contains("badge"): return
		if control.get_parent().name == "MechGrid": control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := Palette.chrome("frame-blue")
		var old := control.get_theme_stylebox("panel")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, old.get_content_margin(side))
		control.add_theme_stylebox_override("panel", style)
		if key in ["waitpanel", "pausepanel", "gameoverpanel", "speedpanel"]: Motion.bind_modal(control)
	elif control is ColorRect and not game and key in ["background", "bg", "bgcolor", "backgroundcolor", "backgroundtint", "headerbg", "footerbg"]:
		control.color = Color.TRANSPARENT
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif control is TextureRect and not game and control.texture and control.texture.resource_path.contains("mechanismImages") and not control.has_meta("full_color"):
		control.modulate = Color.WHITE
	elif control is TextureRect and not game and key == "backgroundimage":
		control.visible = false
