extends SceneTree
## One-time migration: saves the approved runtime composition as authored scenes.
const SCENES = preload("res://scripts/ui/preview_ui.gd").SCENES
func _initialize() -> void:
	_run.call_deferred()
func _own_tree(node: Node, scene: Node) -> void:
	if node != scene: node.owner = scene
	for child in node.get_children(): _own_tree(child, scene)
func _clean(node: Node) -> void:
	for key in node.get_meta_list():
		if str(key).begins_with("ui_") or key == "arcade_decorated": node.remove_meta(key)
	if node is Control and node.owner != null: node.set_meta("arcade_authored_control", true)
	for child in node.get_children(): _clean(child)
func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.get_node("AppData").enter_demo()
	var theme: Theme = root.get_node("UIManager").shared_theme
	ResourceSaver.save(theme, "res://Assets/Arcade/arcade_theme.tres")
	theme.take_over_path("res://Assets/Arcade/arcade_theme.tres")
	var paths: Array = ["res://scenes/CelebrationCard.tscn"]
	paths.append_array(SCENES)
	for path in paths:
		if change_scene_to_file(path) != OK: quit(1); return
		await create_timer(0.35).timeout
		var scene: Control = current_scene
		if scene.has_meta("arcade_authored"):
			print("ALREADY AUTHORED: ", path)
			continue
		var game: bool = path.begins_with("res://game/")
		# Retain only deliberate scene composition, not runtime particles, timers or trials.
		for key in ["ArcadeBackdrop", "ReducedMotion", "DemoButton", "ArcadeGameBackground", "ArcadePresentation"]:
			var node := scene.get_node_or_null(key)
			if node: _own_tree(node, scene)
		if game:
			for key in ["UI/Header", "UI/WaitPanel", "UI/PausePanel", "UI/GameOverPanel", "UI/SessionProgress", "UI/GameHelp"]:
				_own_tree(scene.get_node(key), scene)
			var booster := scene.get_node_or_null("Player/ArcadeBooster")
			if booster: _own_tree(booster, scene)
			scene.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			scene.size = Vector2(1166, 656)
		else:
			if scene.name == "ChooseGameScene": _own_tree(scene.get_node("GameGrid"), scene)
			if scene.name == "ChooseMechanismScene": _own_tree(scene.get_node("MechGrid"), scene)
		if scene.name == "CelebrationCard":
			scene.show()
			var backdrop := scene.get_node_or_null("ArcadeBackdrop")
			if backdrop:
				scene.remove_child(backdrop)
				backdrop.queue_free()
		if scene.name == "ChooseGameScene":
			scene.get_node("BackButton").text = "← Choose Mechanism"
			scene.get_node("Header/StatusLabel").text = "Choose a game to begin your session"
			scene.get_node("Header/MechLabel").text = "Five ways to move. One brighter day."
		if game: scene.get_node("UI/GameHelp").text = "ARROW KEYS  Move     •     SPACE  Start / pause     •     CTRL + G  Speed"
		_clean(scene)
		scene.set_meta("arcade_authored", true)
		scene.set_meta("arcade_authored_control", true)
		var packed := PackedScene.new()
		var error := packed.pack(scene)
		if error == OK: error = ResourceSaver.save(packed, path)
		if error != OK:
			push_error("Scene save failed: " + path)
			quit(1); return
		print("AUTHORED: ", path)
	quit()
