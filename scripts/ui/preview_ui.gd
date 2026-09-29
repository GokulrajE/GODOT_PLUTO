extends SceneTree
## Run with --script res://scripts/ui/preview_ui.gd to capture UI without a device.
const SCENES := [
	"res://scenes/MainScene.tscn", "res://scenes/RegisterScene.tscn",
	"res://scenes/ConnectScene.tscn", "res://scenes/PlanSetupScene.tscn",
	"res://scenes/ChooseMechanism.tscn", "res://scenes/CalibrationScene.tscn",
	"res://scenes/AssessmentScene.tscn", "res://scenes/AssistProfileScene.tscn",
	"res://scenes/SetDurationScene.tscn", "res://scenes/SummaryScene.tscn",
	"res://scenes/ChooseGameScene.tscn", "res://game/PING_PONG/scene/PingPongScene.tscn",
	"res://game/HAT_TIRCK/scene/HatrickScene.tscn", "res://game/FRUIT_BASKET/scene/FruitBasketScene.tscn",
	"res://game/RNR/scene/RNRScene.tscn", "res://game/TUK_TUK/scene/TukTukScene.tscn"
]

func _initialize() -> void:
	_preview.call_deferred()

func _preview() -> void:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute("res://.godot/ui-preview")
	for path in SCENES:
		if change_scene_to_file(path) != OK:
			push_error("Could not load UI scene: " + path)
			quit(1)
			return
		await create_timer(0.8).timeout
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/ui-preview/ui-" + path.get_file().get_basename() + ".png")
		print("UI preview OK: ", path)
	quit()
