extends RefCounted
## Decorative assets and interaction polish; no therapy state is modified.
const P = preload("res://scripts/ui/ui_palette.gd")
const Motion = preload("res://scripts/ui/ui_motion.gd")
const ATLAS_PATH = "res://Assets/Arcade/pluto-ui-emblems.png"
static func sprite(index: int) -> Texture2D:
	var sheet = load(ATLAS_PATH) as Texture2D
	if sheet == null: return null
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var cell := Vector2(sheet.get_width(),sheet.get_height()) / 2
	texture.region = Rect2(Vector2(index % 2,index >> 1) * cell,cell)
	return texture
static func decorate(panel: Control, emblem := -1) -> void:
	if panel.has_meta("premium_finish"): return
	panel.set_meta("premium_finish",true)
	var style := P.surface(Color("f8fcfd"),22,Color("bfd9df"))
	style.shadow_size = 12
	style.shadow_color = Color(0.06,0.16,0.23,.16)
	style.border_width_bottom = 3
	if panel is PanelContainer:
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,24)
	panel.add_theme_stylebox_override("panel",style)
	if panel is Panel and panel.name != "LoginCard":
		var accent := ColorRect.new()
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent.color = P.ACCENT
		panel.add_child(accent)
		accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		accent.offset_left = 24
		accent.offset_right = -24
		accent.offset_top = 1
		accent.offset_bottom = 4
	if emblem >= 0 and panel is Panel:
		var art := TextureRect.new()
		art.name = "PremiumEmblem"
		art.texture = sprite(emblem)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(art)
		art.position = Vector2(18,18)
		art.size = Vector2(72,72)
	Motion.bind_modal(panel)
static func enrich(root: Node) -> void:
	for child in root.get_children(): enrich(child)
	if root is Button:
		Motion.bind(root)
		var normal = root.get_theme_stylebox("normal").duplicate()
		if normal is StyleBoxFlat:
			normal.border_width_bottom = 4
			normal.shadow_size = 5
			root.add_theme_stylebox_override("normal",normal)
		var pressed = root.get_theme_stylebox("pressed").duplicate()
		if pressed is StyleBoxFlat:
			pressed.border_width_bottom = 1
			pressed.shadow_size = 0
			root.add_theme_stylebox_override("pressed",pressed)
	if root is TextureRect and str(root.name) in ["StarImg","StarTex","ResultStar"]:
		root.texture = sprite(2 if root.name == "ResultStar" else 0)
	if root is Panel or root is PanelContainer:
		var name := str(root.name)
		if name in ["LoginCard","MainCard","AromPanel","PromPanel"]: decorate(root)
		elif name in ["PausePanel","PremiumPause"]: decorate(root,1)
		elif name in ["GameOverPanel","PremiumResults","Card"]: decorate(root)
		elif name in ["WaitPanel","PremiumStart","SpeedPanel","PremiumSpeed"]: decorate(root)

## Login only: a white wash over the backdrop so the scene reads light and clean.
static func _brighten_backdrop(screen: Control) -> void:
	var backdrop := screen.get_node_or_null("ArcadeBackdrop")
	if backdrop == null: return
	var wash := ColorRect.new()
	wash.name = "LoginWash"
	wash.color = Color(1, 1, 1, 0.62)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.move_child(wash, backdrop.get_index() + 1)

## Login only: tighten the vertical rhythm and size the card to its content, centred on screen.
static func _compact_login(login: Control) -> void:
	var content := login.get_node_or_null("LoginCardVBox/LoginBodyPad/LoginBodyVBox/LoginContent") as BoxContainer
	if content:
		content.add_theme_constant_override("separation", 10)
		var status := content.get_node_or_null("LoginStatus") as Control
		if status: status.custom_minimum_size.y = 0
	var pad := login.get_node_or_null("LoginCardVBox/LoginBodyPad") as MarginContainer
	if pad:
		pad.add_theme_constant_override("margin_top", 16)
		pad.add_theme_constant_override("margin_bottom", 4)
	var dash := login.get_parent().get_node_or_null("DashCard") as Control
	var fit := func():
		if not is_instance_valid(login) or not login.is_inside_tree(): return
		var box := login.get_node("LoginCardVBox") as Control
		var h := box.get_combined_minimum_size().y
		var dash_h := maxf(h, 400.0) if dash and dash.visible else h
		var top := -dash_h * .5 - 14.0
		login.anchor_top = .5
		login.anchor_bottom = .5
		login.offset_top = top
		login.offset_bottom = top + h
		if dash and dash.visible:
			dash.anchor_top = .5
			dash.anchor_bottom = .5
			dash.offset_top = top
			dash.offset_bottom = top + dash_h
	var refit := func():
		if is_instance_valid(login) and login.is_inside_tree():
			if not login.get_tree().process_frame.is_connected(fit):
				login.get_tree().process_frame.connect(fit, CONNECT_ONE_SHOT)
	refit.call()
	(login.get_node("LoginCardVBox") as Control).minimum_size_changed.connect(refit)
	if dash: dash.visibility_changed.connect(refit)

static func welcome(screen: Control) -> void:
	var login = screen.get_node_or_null("LoginCard")
	if login == null: return
	login.anchor_left = .48
	login.anchor_right = .94
	_brighten_backdrop(screen)
	_compact_login(login)
	# The PLUTO device: floats gently, and lifts / tilts toward the pointer (Hover3D) on hover.
	var hero := Control.new()
	hero.name = "PlutoHero"
	hero.mouse_filter = Control.MOUSE_FILTER_PASS
	hero.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	screen.add_child(hero)
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.anchor_left = .0
	hero.anchor_right = .48
	hero.anchor_top = .10
	hero.anchor_bottom = .90
	var pic := TextureRect.new()
	pic.texture = load("res://Assets/mechanismImages/ProductionPluto.png") as Texture2D
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero.add_child(pic)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preload("res://scripts/ui/hover_3d.gd").attach(hero, pic, 18.0).shadow_strength = 0.10
	if not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)):
		var drift := func(v: float): hero.offset_top = v; hero.offset_bottom = v
		var bob := hero.create_tween().set_loops()
		bob.tween_method(drift, -9.0, 9.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_method(drift, 9.0, -9.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var art: Control = hero
	art.visible = login.visible
	login.visibility_changed.connect(func(): art.visible = login.visible)
	var dash := screen.get_node_or_null("DashCard")
	if dash:
		dash.visibility_changed.connect(func(): if dash.visible: art.visible = false)
