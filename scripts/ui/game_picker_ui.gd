extends RefCounted
const Assets = preload("res://scripts/ui/arcade_assets.gd")
const Palette = preload("res://scripts/ui/ui_palette.gd")
const TITLES       := ["HAT-TRICK", "FRUIT BASKET", "R-N-R", "TUK-TUK", "PING-PONG", "BULLOCK TRAIL"]
const DESCRIPTIONS := ["Catch the falling balls", "Match fruit to its basket", "Water your growing garden", "Navigate the rocky gaps", "Keep the rally going", "Steer toward the lanterns"]
const ICONS        := ["hat", "basket", "cloud", "tuk", "pong", "star"]
# the same scenery the games are played in, so each card previews its world
const SCENERY := [
	"res://game/HAT_TIRCK/assets/backgrounds/sunset.png",
	"res://Assets/Arcade/orchard-v2.png",
	"res://Assets/Arcade/garden-v2.png",
	"res://game/TUK_TUK/sprites/Backgrounds/game/kerala.png",
	"res://Assets/Arcade/arena-v2.png",
	"res://Assets/Arcade/forest-soft.png",
]

# Per-game accent stripe colors (3 px bottom border inside each card)
const GAME_ACCENTS := [
	Color("E05A2B"),  # HAT-TRICK      warm orange
	Color("2E9E5B"),  # FRUIT BASKET   fresh green
	Color("7A4FC4"),  # R-N-R          gentle purple
	Color("E0921A"),  # TUK-TUK        amber
	Color("2176AE"),  # PING-PONG      sky blue
	Color("087f83"),  # BULLOCK TRAIL  teal (matches ACCENT)
]

static func configure(grid: GridContainer) -> void:
	grid.columns = 3
	grid.offset_left = 28
	grid.offset_right = -28
	grid.offset_top = 145
	grid.offset_bottom = -85
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	var index := 0
	for child in grid.get_children():
		if child is not Button: continue
		for old in child.get_children():
			child.remove_child(old)
			old.queue_free()
		child.icon = null
		child.text = ""
		child.clip_contents = true

		# Background scenery image
		# rounded frame that clips the picture (concept_layout positions this "WorldPreview" node)
		var scenery := Panel.new()
		scenery.name = "WorldPreview"
		scenery.set_meta("arcade_authored_control", true)
		scenery.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var round_frame := Palette.surface(Color.WHITE, 16, Color.TRANSPARENT)
		round_frame.shadow_size = 0
		scenery.add_theme_stylebox_override("panel", round_frame)
		var pic := TextureRect.new()
		var scene_path: String = SCENERY[index]
		pic.texture = (load(scene_path) as Texture2D) if ResourceLoader.exists(scene_path) else Assets.background(ICONS[index])
		pic.set_meta("full_color", true)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scenery.add_child(pic)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		child.add_child(scenery)
		scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scenery.offset_left   =  12
		scenery.offset_right  = -12
		scenery.offset_top    =  12
		scenery.anchor_bottom = 0.0
		scenery.offset_bottom = 104

		# Content stack
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left   = 14
		stack.offset_right  = -14
		stack.offset_top    = 14
		stack.offset_bottom = -16
		stack.alignment     = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 12)

		# Game sprite art
		var art := TextureRect.new()
		art.texture = load("res://game/BULLOCK_CART/assets/generated/cart-centered-player.png") if index == 5 else Assets.sprite(ICONS[index])
		if index == 5:
			var sheet := art.texture
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(0, 0, sheet.get_width() / 4.0, sheet.get_height() / 4.0)
			art.texture = frame
		art.custom_minimum_size = Vector2(0, 96)
		art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(art)

		# Game title
		var title := Label.new()
		title.text = TITLES[index]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", Palette.DISPLAY)
		title.add_theme_font_size_override("font_size", Palette.SIZE_MD)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(title)

		# PLAY CTA with a subtle tinted pill background
		var play_panel := PanelContainer.new()
		play_panel.name = "PlayBadge"
		play_panel.set_meta("arcade_authored_control", true)  # skip ui_manager full styling
		play_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var accent: Color = GAME_ACCENTS[index]
		var pill_style := Palette.surface(Color(accent.r, accent.g, accent.b, 0.14), 10, Color.TRANSPARENT)
		pill_style.shadow_size = 0
		pill_style.content_margin_left   = Palette.GAP_LG
		pill_style.content_margin_right  = Palette.GAP_LG
		pill_style.content_margin_top    = Palette.GAP_SM
		pill_style.content_margin_bottom = Palette.GAP_SM
		play_panel.add_theme_stylebox_override("panel", pill_style)
		stack.add_child(play_panel)

		var play := Label.new()
		play.name = "PlayLabel"
		play.text = "PLAY  ›"
		play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.add_theme_font_override("font", Palette.DISPLAY)
		play.add_theme_font_size_override("font_size", Palette.SIZE_MD)
		play.add_theme_color_override("font_color", Palette.ACCENT)
		play.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_panel.add_child(play)

		# Per-game accent stripe at bottom of card (4 px)
		var stripe := ColorRect.new()
		stripe.name = "GameAccentStripe"
		stripe.color = accent
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(stripe)
		stripe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		stripe.custom_minimum_size = Vector2(0, 4)
		stripe.offset_top    = -4
		stripe.offset_bottom =  0

		index += 1
