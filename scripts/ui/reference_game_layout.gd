extends RefCounted
const Layout = preload("res://scripts/ui/concept_layout.gd")
static func apply(ui: Node) -> void:
	var overlay = preload("res://scripts/ui/compact_game_hud.gd").new()
	overlay.game = ui.get_parent()
	overlay.legacy_ui = ui
	ui.add_child(overlay)
	for name in ["PausePanel","GameOverPanel"]:
		var panel = ui.get_node_or_null(name)
		if panel:
			var title = panel.get_node_or_null("PauseTitle" if name == "PausePanel" else "OverTitle")
			if title: title.text = "Paused" if name == "PausePanel" else "Session complete"
	var speed = ui.get_node_or_null("SpeedPanel")
	if speed:
		var heading = speed.get_node_or_null("TitleLabel")
		if heading: heading.text = "Game speed"

static func floating_surface(control: Control) -> void:
	var pill := Panel.new()
	pill.name = "FloatingSurface"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.show_behind_parent = true
	if control is Container:
		control.get_parent().add_child(pill)
		pill.position = control.position - Vector2(8,0)
		pill.size = control.size + Vector2(16,0)
		pill.add_theme_stylebox_override("panel",preload("res://scripts/ui/ui_palette.gd").surface(Color("f8fcfd"),14))
		return
	control.add_child(pill)
	pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill.offset_left = -8
	pill.offset_right = 8
	pill.add_theme_stylebox_override("panel",preload("res://scripts/ui/ui_palette.gd").surface(Color("f8fcfd"),14))
