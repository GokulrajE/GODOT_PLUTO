extends RefCounted
## All game logic uses this canonical coordinate space, independent of window size.
const SIZE := Vector2i(1166, 656)
const MENU_SIZE := Vector2i(1280, 800)
static func configure(window: Window, game: bool) -> void:
	window.content_scale_size = SIZE if game else MENU_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
