extends RefCounted
const P = preload("res://scripts/ui/ui_palette.gd")
static func apply(screen: Control) -> void:
	var bg = screen.get_node_or_null("ArcadeBackdrop")
	if bg:
		bg.texture = load("res://Assets/Arcade/pluto-botanical-background.png")
		bg.modulate = Color.WHITE
	preload("res://scripts/ui/premium_finish.gd").welcome.call_deferred(screen)
	style(screen)
	preload("res://scripts/ui/concept_layout.gd").apply.call_deferred(screen)
	preload("res://scripts/ui/premium_finish.gd").enrich.call_deferred(screen)
	for path in ["Header/TitleLabel", "HeaderPanel/TitleLabel"]:
		var title = screen.get_node_or_null(path)
		if title: title.add_theme_font_size_override("font_size",30)
	var instruction = screen.get_node_or_null("InstructionLabel")
	if instruction: instruction.add_theme_font_size_override("font_size",24)
static func style(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font",P.DISPLAY)
		if node.get_theme_font_size("font_size") < 16: node.add_theme_font_size_override("font_size",16)
		if not "Status" in str(node.name): node.add_theme_color_override("font_color",P.INK)
	if node is Panel and str(node.name) in ["Header","HeaderPanel","LoginCard","MainCard","AromPanel","PromPanel","AngleBoxBG"]:
		node.add_theme_stylebox_override("panel",P.surface(Color("e7f5f3") if node.name == "AromPanel" else P.SURFACE,16))
	if node is Button:
		if node.icon != null: node.text = node.text.trim_prefix("← ")
		var primary: bool = node.name in ["LoginButton","ConnectButton","ContinueButton"] or node.text.begins_with("Start ")
		for state in ["normal","hover","pressed","hover_pressed"]:
			node.add_theme_stylebox_override(state,P.button(P.ACCENT if primary else (P.SURFACE if state == "normal" else Color("e1f2ef"))))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			node.add_theme_color_override(state,Color.WHITE if primary else P.INK)
		var focus := P.surface(Color.TRANSPARENT,14,P.ACCENT)
		focus.set_border_width_all(3)
		focus.shadow_size = 0
		node.add_theme_stylebox_override("focus",focus)
		node.add_theme_stylebox_override("disabled",P.button(Color("e5ebef")))
		node.add_theme_font_override("font",P.DISPLAY)
		node.add_theme_font_size_override("font_size",18)
		if not node.text.is_empty(): node.custom_minimum_size.y = maxf(48,node.custom_minimum_size.y)
	if node is LineEdit:
		node.add_theme_stylebox_override("normal",P.button(P.SURFACE))
		node.add_theme_stylebox_override("focus",P.button(P.SURFACE,P.ACCENT))
		node.add_theme_font_size_override("font_size",20)
		node.custom_minimum_size.y = 52
	for child in node.get_children(): style(child)
