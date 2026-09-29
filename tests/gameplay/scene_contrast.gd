extends SceneTree
const SCENES = preload("res://scripts/ui/preview_ui.gd").SCENES
var findings: Array = []
var checked := 0
var phase := ""
func _initialize(): run.call_deferred()
func linear(v: float) -> float:
	return v / 12.92 if v <= .04045 else pow((v + .055) / 1.055, 2.4)
func luminance(c: Color) -> float:
	return linear(c.r) * .2126 + linear(c.g) * .7152 + linear(c.b) * .0722
func color_of(style: StyleBox) -> Color:
	if style is StyleBoxFlat: return style.bg_color
	if style is StyleBoxTexture and style.texture:
		var img: Image = style.texture.get_image()
		if img: return img.get_pixel(img.get_width() / 2, img.get_height() / 2) * style.modulate_color
	return Color.TRANSPARENT
func background(control: Control) -> Color:
	var node: Node = control
	while node is Control:
		var style: StyleBox
		if node is Button: style = node.get_theme_stylebox("normal")
		elif node is Label and node.has_theme_stylebox_override("normal"): style = node.get_theme_stylebox("normal")
		elif node is LineEdit: style = node.get_theme_stylebox("normal")
		elif node is Panel or node is PanelContainer: style = node.get_theme_stylebox("panel")
		if style and (node == control or node.get_global_rect().has_point(control.get_global_rect().get_center())):
			var color := color_of(style)
			if color.a > .95: return color
		node = node.get_parent()
	return Color("f1f8fc")
func inspect(node: Node):
	if (node is Label or node is Button or node is LineEdit) and node.is_visible_in_tree():
		if not node.text.is_empty() and not (node is BaseButton and node.disabled):
			var bg := background(node)
			var fg: Color = node.get_theme_color("font_color") * node.self_modulate
			var parent: Node = node
			while parent is CanvasItem:
				fg *= parent.modulate
				parent = parent.get_parent()
			fg = bg.blend(fg)
			var ratio := (maxf(luminance(bg), luminance(fg)) + .05) / (minf(luminance(bg), luminance(fg)) + .05)
			checked += 1
			if ratio < (3.0 if node.get_theme_font_size("font_size") >= 24 else 4.5):
				findings.append({"scene": current_scene.name, "phase": phase, "node": str(current_scene.get_path_to(node)), "ratio": snappedf(ratio,.01), "fg": fg.to_html(), "bg": bg.to_html()})
	for child in node.get_children(): inspect(child)
func capture():
	await create_timer(.3).timeout
	inspect(current_scene)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/contrast/" + str(current_scene.name) + "-" + phase + ".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://.godot/contrast")
	var app = root.get_node("AppData")
	app.enter_demo()
	var configs := [app.config_fme1, app.config_fme2]
	var paths: Array = SCENES.duplicate()
	paths.append("res://scenes/CelebrationCard.tscn")
	for path in paths:
		change_scene_to_file(path)
		await create_timer(.4).timeout
		phase = "default"
		if current_scene.name == "CelebrationCard": current_scene.show()
		await capture()
		if current_scene.name == "MainScene":
			current_scene.get_node("LoginCard").hide()
			current_scene.get_node("DashCard").show()
			phase = "dashboard"
			await capture()
		if current_scene.name == "PlanSetupScene":
			app.config_fme1 = 10
			current_scene._refresh_cards()
			phase = "ready"
			await capture()
			current_scene._open_knob_popup("FME1")
			phase = "knob-popup"
			await capture()
		if current_scene.name == "SetDurationScene":
			current_scene._checkboxes["FME1"].button_pressed = true
			current_scene._checkboxes["FME2"].button_pressed = true
			phase = "selected"
			await capture()
		if path.begins_with("res://game/"):
			current_scene.set_process(false)
			current_scene.get_node("ArcadePresentation").set_process(false)
			current_scene.get_node("UI/WaitPanel").hide()
			for panel in ["PausePanel", "GameOverPanel", "SpeedPanel"]:
				current_scene.get_node("UI/" + panel).show()
				phase = panel
				await capture()
				current_scene.get_node("UI/" + panel).hide()
	app.config_fme1 = configs[0]
	app.config_fme2 = configs[1]
	app.exit_demo()
	root.get_node("MenuMusic").set_muted(true)
	var file := FileAccess.open("res://.godot/contrast/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checked":checked,"findings":findings}, "\t"))
	print("CONTRAST: ", checked, " text checks; ", findings.size(), " findings")
	quit(0 if findings.is_empty() else 1)
