extends RefCounted
const Assets = preload("res://scripts/ui/arcade_assets.gd")
const Palette = preload("res://scripts/ui/ui_palette.gd")
const TITLES := ["HAT-TRICK", "FRUIT BASKET", "R-N-R", "TUK-TUK", "PING-PONG"]
const DESCRIPTIONS := ["Catch the falling balls", "Match fruit to its basket", "Water your growing garden", "Navigate the rocky gaps", "Keep the rally going"]
const ICONS := ["hat", "basket", "cloud", "tuk", "pong"]

static func configure(grid: GridContainer) -> void:
	if grid.get_parent().has_meta("arcade_authored"): return
	grid.columns = 5
	grid.offset_left = 28
	grid.offset_right = -28
	grid.offset_top = 180
	grid.offset_bottom = -145
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var index := 0
	for child in grid.get_children():
		if child is not Button: continue
		child.icon = null
		child.text = ""
		child.clip_contents = true
		var scenery := TextureRect.new()
		scenery.name = "WorldPreview"
		scenery.texture = Assets.background(ICONS[index])
		scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(scenery)
		scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scenery.offset_left = 12
		scenery.offset_right = -12
		scenery.offset_top = 12
		scenery.offset_bottom = -200
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = 14
		stack.offset_right = -14
		stack.offset_top = 26
		stack.offset_bottom = -24
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 18)
		var art := TextureRect.new()
		art.texture = Assets.sprite(ICONS[index])
		art.custom_minimum_size = Vector2(0, 200)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(art)
		var title := Label.new()
		title.text = TITLES[index]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", Palette.DISPLAY)
		title.add_theme_font_size_override("font_size", 23)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(title)
		var desc := Label.new()
		desc.name = "Description"
		desc.text = DESCRIPTIONS[index]
		desc.custom_minimum_size.y = 50
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 15)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(desc)
		var play := Label.new()
		play.name = "PlayLabel"
		play.text = "PLAY  ›"
		play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.add_theme_font_override("font", Palette.DISPLAY)
		play.add_theme_font_size_override("font_size", 24)
		play.add_theme_color_override("font_color", Palette.ACCENT)
		play.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(play)
		index += 1
