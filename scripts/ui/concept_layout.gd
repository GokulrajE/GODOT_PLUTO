extends RefCounted
const P = preload("res://scripts/ui/ui_palette.gd")
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
	footer.visible = screen.get_node_or_null("BackButton") == null and screen.get_node_or_null("AromPanel") == null
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
			var source = panel.get_node("SliderContainer")
			source.modulate.a = 0.0
			var gauge = preload("res://scripts/ui/assessment_gauge.gd").new()
			gauge.source = source
			panel.add_child(gauge)
			rect(gauge,Rect2(.10,.18,.60,.25))
			for path in ["LeftLabel","CenterLabel","RightLabel"]:
				var label = panel.get_node_or_null(path)
				if label: label.add_theme_font_size_override("font_size",14)
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
		var names := ["Wrist flexion", "Wrist deviation", "Forearm rotation", "Hand opening", "Functional movement 1", "Functional movement 2"]
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
			card.add_child(illustration)
			rect(illustration,Rect2(.03,.10,.36,.80))
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

static func movement_sprite(index: int) -> Texture2D:
	var sheet = load("res://Assets/Arcade/pluto-movements.png") as Texture2D
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var cell := Vector2(sheet.get_width() / 3.0,sheet.get_height() / 2.0)
	texture.region = Rect2(Vector2(index % 3,floori(index / 3.0)) * cell,cell)
	return texture
