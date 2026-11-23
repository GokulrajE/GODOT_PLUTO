extends RefCounted
## Shared presentation for the six game UIs. No gameplay or device state changes.
const P = preload("res://scripts/ui/ui_palette.gd")
static func apply(ui: Node) -> void:
	if str(ui.name) == "UI":
		preload("res://scripts/ui/premium_finish.gd").enrich.call_deferred(ui)
		preload("res://scripts/ui/reference_game_layout.gd").apply.call_deferred(ui)
	if ui is Label and not ui.has_meta("keep_style"):     # HUD widgets with their own colours opt out
		ui.add_theme_font_override("font", P.DISPLAY)
		ui.add_theme_color_override("font_color", P.INK)
		ui.add_theme_constant_override("outline_size", 0)
		if ui.get_theme_font_size("font_size") < 16: ui.add_theme_font_size_override("font_size", 16)
	if (ui is Panel or ui is PanelContainer) and not ui.has_meta("keep_style"):
		var surface := P.surface(P.SURFACE, 16)
		if ui is PanelContainer:
			for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: surface.set_content_margin(side,20)
		ui.add_theme_stylebox_override("panel",surface)
	if ui is Button:
		var primary: bool = str(ui.name) in ["PlayButton","ReplayButton","ResumeButton"] or ui.text.to_lower().begins_with("play") or ui.text.to_lower().begins_with("resume") or ui.text.to_lower().begins_with("start")
		for state in ["normal","hover","pressed","hover_pressed"]:
			var fill: Color = (P.ACCENT if state == "normal" else Color("06666a")) if primary else (P.SURFACE if state == "normal" else Color("e1f2ef"))
			ui.add_theme_stylebox_override(state,P.button(fill))
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
			ui.add_theme_color_override(state,Color.WHITE if primary else P.INK)
		ui.add_theme_color_override("icon_normal_color", Color.WHITE if primary else P.INK)
		ui.add_theme_color_override("icon_hover_color", Color.WHITE if primary else P.INK)
		ui.add_theme_font_override("font",P.DISPLAY)
		ui.add_theme_font_size_override("font_size",18)
		ui.custom_minimum_size.y = maxf(44,ui.custom_minimum_size.y)
		var focus := P.surface(Color.TRANSPARENT,14,P.ACCENT)
		focus.set_border_width_all(3)
		focus.shadow_size = 0
		ui.add_theme_stylebox_override("focus",focus)
		ui.add_theme_stylebox_override("disabled",P.button(Color("e5ebef")))
		ui.add_theme_color_override("font_disabled_color",P.MUTED)
	for child in ui.get_children(): apply(child)

static func bullock(game: Node) -> void:
	game._mp_wait_panel.name = "PremiumStart"
	game._mp_pause_panel.name = "PremiumPause"
	game._mp_over_panel.name = "PremiumResults"
	game._mp_speed_panel.name = "PremiumSpeed"
	apply(game.get_node("GameUI/Interface"))
	preload("res://scripts/ui/premium_finish.gd").enrich.call_deferred(game.get_node("GameUI/Interface"))
	var overlay = preload("res://scripts/ui/compact_game_hud.gd").new()
	overlay.game = game
	overlay.bullock = true
	game.get_node("GameUI/Interface").add_child(overlay)
