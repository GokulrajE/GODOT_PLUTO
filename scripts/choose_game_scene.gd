extends Control

@onready var mech_label:   Label = $Header/MechLabel
@onready var status_label: Label = $Header/StatusLabel

func _ready() -> void:
	preload("res://scripts/ui/rehab_refinement.gd").apply.call_deferred(self)
	preload("res://scripts/ui/game_picker_ui.gd").configure($GameGrid)
	mech_label.text   = "SIX WAYS TO MOVE. ONE BRIGHTER DAY." if AppData.demo_mode else _get_mech_display_name()
	status_label.text = "Keyboard demo • no patient data recorded" if AppData.demo_mode else AppData.daily_progress_text()

	$GameGrid/HatTrickButton.pressed.connect(_on_hat_trick_pressed)
	$GameGrid/FruitBasketButton.pressed.connect(_on_fruit_basket_pressed)
	$GameGrid/RNRButton.pressed.connect(_on_rnr_pressed)
	$GameGrid/TukTukButton.pressed.connect(_on_tuk_tuk_pressed)
	$GameGrid/PingPongButton.pressed.connect(_on_ping_pong_pressed)
	if AppData.demo_mode: $BackButton.text = "← Back to home"
	$BackButton.pressed.connect(_on_back_pressed)
	$GameGrid/BullockCartButton.pressed.connect(_on_bullock_cart_pressed)
	EventBus.button_released.connect(_on_pluto_button)

func _exit_tree() -> void:
	if EventBus.button_released.is_connected(_on_pluto_button):
		EventBus.button_released.disconnect(_on_pluto_button)

## Ctrl+Shift+X: re-assess the current mechanism (assessment, then assist profile) and return here.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X 			and event.ctrl_pressed and event.shift_pressed:
		if AppData.demo_mode or AppData.selected_mechanism == null: return
		get_viewport().set_input_as_handled()
		AppData.is_plan_setup = false
		AppData.assess_from_games = true
		get_tree().change_scene_to_file("res://scenes/AssessmentScene.tscn")

func _on_pluto_button() -> void:
	_on_hat_trick_pressed()

func _on_hat_trick_pressed() -> void:
	AppData.set_game("HAT-TRICK")
	get_tree().change_scene_to_file("res://game/HAT_TIRCK/scene/HatrickScene.tscn")

func _on_fruit_basket_pressed() -> void:
	AppData.set_game("FRUIT-BASKET")
	get_tree().change_scene_to_file("res://game/FRUIT_BASKET/scene/FruitBasketScene.tscn")

func _on_rnr_pressed() -> void:
	AppData.set_game("RNR")
	get_tree().change_scene_to_file("res://game/RNR/scene/RNRScene.tscn")

func _on_tuk_tuk_pressed() -> void:
	AppData.set_game("TUK-TUK")
	get_tree().change_scene_to_file("res://game/TUK_TUK/scene/TukTukScene.tscn")

func _on_bullock_cart_pressed() -> void:
	AppData.set_game("BULLOCK-CART")
	get_tree().change_scene_to_file("res://game/BULLOCK_CART/scenes/BullockMotionPreview.tscn")

func _on_ping_pong_pressed() -> void:
	AppData.set_game("PING-PONG")
	get_tree().change_scene_to_file("res://game/PING_PONG/scene/PingPongScene.tscn")

func _on_back_pressed() -> void:
	if AppData.demo_mode:
		AppData.exit_demo()
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/ChooseMechanism.tscn")

func _get_mech_display_name() -> String:
	var names := {
		"WFE":  "WRIST FLEX / EXTENSION",
		"WURD": "WRIST ULNAR RADIAL DEVIATION",
		"FPS":  "FOREARM PRONATION SUPINATION",
		"HOC":  "HAND OPENING CLOSING",
		"FME1": "FUNCTIONAL MECHANISM 1",
		"FME2": "FUNCTIONAL MECHANISM 2",
	}
	return names.get(AppData.mechanism_name, AppData.mechanism_name)
