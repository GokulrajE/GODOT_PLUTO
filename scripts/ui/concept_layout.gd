extends RefCounted
const P = preload("res://scripts/ui/ui_palette.gd")
## Assessment panel: a horizontal range bar on top, the live reading and the per-cycle list below.
static func assessment_bar_layout(panel: Control, is_arom: bool) -> void:
	var bar = panel.get_node("SliderContainer")
	rect(bar,Rect2(.05,.19,.90,.20))
	var track = bar.get_node("SliderTrack") as Control
	track.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	track.anchor_right = 1.0
	track.anchor_top = .50
	track.anchor_bottom = .70
	track.offset_left = 0; track.offset_right = 0; track.offset_top = 0; track.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d3e6e8")
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("9fc3c6")
	track.add_theme_stylebox_override("panel",style)
	for path in ["LeftLabel","RightLabel"]:
		var label = panel.get_node_or_null(path)
		if label:
			label.add_theme_font_size_override("font_size",15)
			label.add_theme_color_override("font_color",P.MUTED)
	rect(panel.get_node("LeftLabel"),Rect2(.05,.40,.3,.05))
	rect(panel.get_node("RightLabel"),Rect2(.65,.40,.3,.05))
	panel.get_node("CenterLabel").hide()
	var reading = panel.get_node("AngleLabel") as Label
	reading.add_theme_font_size_override("font_size",44)
	reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rect(reading,Rect2(.04,.47,.44,.12))
	rect(panel.get_node("AngleUnitLabel"),Rect2(.04,.59,.44,.05))
	rect(panel.get_node("StatusLabel"),Rect2(.04,.66,.44,.30))
	if is_arom:
		rect(panel.get_node("PrevAromLabel"),Rect2(.52,.92,.44,.06))
		var cycles := RichTextLabel.new()
		cycles.name = "CycleList"
		cycles.bbcode_enabled = true
		cycles.scroll_active = false
		cycles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cycles.add_theme_font_size_override("normal_font_size",17)
		cycles.add_theme_font_size_override("bold_font_size",17)
		cycles.add_theme_color_override("default_color",P.INK)
		cycles.set_meta("arcade_authored_control",true)
		panel.add_child(cycles)
		rect(cycles,Rect2(.52,.47,.44,.34))
	for button_path in ["StartButton","NextButton"]:
		var button = panel.get_node_or_null(button_path)
		if button:
			var left: bool = button_path == "StartButton"
			rect(button,Rect2(.52 if left else .76,.82,.21,.08))

static func rect(control: Control, box: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = box.position.x
	control.anchor_top = box.position.y
	control.anchor_right = box.end.x
	control.anchor_bottom = box.end.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0
static func apply(screen: Control) -> void:
	var footer := Label.new()
	footer.text = "PLUTO   |   Rehabilitation through play"
	footer.visible = screen.get_node_or_null("BackButton") == null and screen.get_node_or_null("AromPanel") == null and screen.get_node_or_null("DiagnosticsButton") == null
	footer.add_theme_font_size_override("font_size",14)
	footer.add_theme_color_override("font_color",P.MUTED)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(footer)
	rect(footer,Rect2(.03,.955,.65,.035))
	var title = screen.get_node_or_null("HeaderPanel/TitleLabel")
	if title == null: title = screen.get_node_or_null("Header/TitleLabel")
	if title:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rect(title,Rect2(.20,.50,.60,.45))
		var bar := ColorRect.new()
		bar.color = Color("e9b638")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		bar.offset_left = -24
		bar.offset_right = 24
		bar.offset_top = -2
		bar.offset_bottom = 1
	for header_path in ["HeaderPanel","Header"]:
		var old_header = screen.get_node_or_null(header_path)
		if old_header:
			rect(old_header,Rect2(0,0,1,.19))
			old_header.self_modulate.a = 0.0
			for item in old_header.get_children():
				if item is Label and item != title: item.hide()
				elif item is Button:
					item.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
					item.offset_left = -150
					item.offset_right = -24
					item.offset_top = 58
					item.offset_bottom = 106
	for panel_name in ["AromPanel","PromPanel"]:
		var panel = screen.get_node_or_null(panel_name)
		if panel:
			rect(panel,Rect2(.04 if panel_name == "AromPanel" else .515,.25,.445,.62))
			if title: title.text = "Explore your movement"
			assessment_bar_layout(panel, panel_name == "AromPanel")
	var bottom = screen.get_node_or_null("BottomButtons")
	if bottom and screen.get_node_or_null("AromPanel"):
		rect(bottom,Rect2(.04,.915,.445,.07))
		bottom.add_theme_constant_override("separation",16)
	var calibration = screen.get_node_or_null("InstructionLabel")
	if calibration:
		title.text = "Let’s get ready"
		rect(calibration,Rect2(.16,.22,.68,.09))
		rect(screen.get_node("MainCard"),Rect2(.08,.38,.84,.40))
		rect(screen.get_node("MechLabel"),Rect2(.12,.48,.22,.08))
		rect(screen.get_node("AngleTitleLabel"),Rect2(.39,.42,.22,.06))
		rect(screen.get_node("AngleBoxBG"),Rect2(.40,.49,.20,.20))
		rect(screen.get_node("AngleLabel"),Rect2(.40,.49,.20,.20))
		rect(screen.get_node("AngleUnitLabel"),Rect2(.40,.70,.20,.05))
		screen.get_node("AngleLabel").add_theme_font_size_override("font_size",52)
		var hint := Label.new()
		hint.text = "Follow the instruction above.\nKeep the device in view."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color",P.MUTED)
		hint.add_theme_font_size_override("font_size",18)
		screen.add_child(hint)
		rect(hint,Rect2(.65,.50,.22,.16))
	var grid = screen.get_node_or_null("MechGrid")
	if grid:
		title.text = "Choose your movement"
		rect(grid,Rect2(.06,.26,.88,.55))
		var names := ["Wrist flexion", "Wrist deviation", "Forearm rotation", "Hand opening", "Functional 1", "Functional 2"]
		var index := 0
		for card in grid.get_children():
			for stack in card.get_children():
				if stack is VBoxContainer:
					rect(stack,Rect2(.43,.14,.53,.76))
					for child in stack.get_children():
						if child is TextureRect: child.hide()
						if child is Label:
							child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
							if child.text == str(card.name): child.text = names[index]
			var illustration := TextureRect.new()
			illustration.texture = movement_sprite(index)
			illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
			illustration.set_meta("full_color", true)   # keep the real colours (no ink-silhouette shader)
			card.add_child(illustration)
			rect(illustration,Rect2(.03,.10,.36,.80))
			Hover3D.attach(card, illustration)
			index += 1
	var games = screen.get_node_or_null("GameGrid")
	if games:
		title.text = "Choose your game"
		rect(games,Rect2(.06,.26,.88,.55))
		for card in games.get_children():
			var background = card.get_node_or_null("WorldPreview")
			if background: rect(background,Rect2(.025,.06,.36,.88))
			for child in card.get_children():
				if child is VBoxContainer:
					rect(child,Rect2(.42,.09,.55,.84))
					for item in child.get_children():
						if item is TextureRect:
							item.reparent(card)
							rect(item,Rect2(.06,.15,.29,.65))
							item.custom_minimum_size = Vector2.ZERO
						elif item is Label:
							item.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
							item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
							item.add_theme_font_size_override("font_size",18 if item.name != "Description" else 16)

const MECH_ICONS := [
	"res://Assets/mechanismImages/icons/wfe.png",    # 0 WFE
	"res://Assets/mechanismImages/icons/wurd.png",   # 1 WURD
	"res://Assets/mechanismImages/icons/fps.png",    # 2 FPS
	"res://Assets/mechanismImages/icons/hoc.png",    # 3 HOC
]

static func movement_sprite(index: int) -> Texture2D:
	if index >= 0 and index < MECH_ICONS.size() and ResourceLoader.exists(MECH_ICONS[index]):
		return load(MECH_ICONS[index])
	if index == 4 or index == 5:
		# FME1 / FME2 show the knob picked in the plan (falls back to the atlas art).
		var knob_id: int = AppData.config_fme1_id if index == 4 else AppData.config_fme2_id
		var knobs: Array = preload("res://scripts/choose_mechanism_scene.gd").KNOB_IMAGES
		if knob_id >= 0 and knob_id < knobs.size() and ResourceLoader.exists(knobs[knob_id]):
			return load(knobs[knob_id])
	var sheet = load("res://Assets/Arcade/pluto-movements.png") as Texture2D
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var cell := Vector2(sheet.get_width() / 3.0,sheet.get_height() / 2.0)
	texture.region = Rect2(Vector2(index % 3,floori(index / 3.0)) * cell,cell)
	return texture
