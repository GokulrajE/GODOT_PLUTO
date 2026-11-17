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
	if panel is Panel:
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

static func welcome(screen: Control) -> void:
	var login = screen.get_node_or_null("LoginCard")
	if login == null: return
	login.anchor_left = .48
	login.anchor_right = .94
	var art := TextureRect.new()
	art.texture = sprite(3)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.anchor_left = .05
	art.anchor_right = .44
	art.anchor_top = .30
	art.anchor_bottom = .78
	art.visible = login.visible
	login.visibility_changed.connect(func(): art.visible = login.visible)
	var dash := screen.get_node_or_null("DashCard")
	if dash:
		dash.visibility_changed.connect(func(): if dash.visible: art.visible = false)
