extends Control
## Pause/exit overlay for all game modes (bullock and arcade).
## For arcade games: hides the legacy Header each frame; pause/exit emit its hidden signals.
const P = preload("res://scripts/ui/ui_palette.gd")
var game: Node
var legacy_ui: Node
var bullock := false
var pause_button: Button
var exit_button: Button

func icon(key: String) -> Texture2D:
	return load("res://Assets/UI/compact/%s.svg" % key)

func _ready() -> void:
	name = "CompactGameHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button = action("pause", "Pause or resume", -190)
	exit_button  = action("exit",  "Exit to game selection", -130)
	pause_button.pressed.connect(_pause)
	exit_button.pressed.connect(_exit)

func action(symbol: String, hint: String, left: float) -> Button:
	var button := Button.new()
	button.set_meta("arcade_authored_control", true)
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left   = left
	button.offset_right  = left + 48
	button.offset_top    = 16
	button.offset_bottom = 64
	button.icon = icon(symbol)
	button.tooltip_text = hint
	button.accessibility_name = hint
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, P.button(P.INK if state == "normal" else P.ACCENT))
		button.add_theme_color_override("icon_" + state + "_color", Color.WHITE)
	var focus := P.surface(Color.TRANSPARENT, 14, Color("efbc46"))
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _process(_delta: float) -> void:
	if bullock:
		var paused: bool = game._mp_pause_panel.visible
		pause_button.disabled = not game.mini_hud.visible and not paused
		for element in [game.top_bar, game.mini_hud, game.feedback, game.race_hint,
				game.section_banner, game.boost_label, game.hud]:
			element.modulate.a = 0
			if element is Control: element.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.mini_pause_btn.hide()
		game.top_bar.hide()
		pause_button.icon = icon("play" if paused else "pause")
		pause_button.tooltip_text = "Resume" if paused else "Pause"
		pause_button.accessibility_name = pause_button.tooltip_text
	else:
		if not is_instance_valid(legacy_ui): return
		var hdr := legacy_ui.get_node_or_null("Header")
		if hdr: hdr.visible = false
		var pause_panel := legacy_ui.get_node_or_null("PausePanel")
		var wait_panel  := legacy_ui.get_node_or_null("WaitPanel")
		var over_panel  := legacy_ui.get_node_or_null("GameOverPanel")
		var paused:  bool = pause_panel != null and pause_panel.visible
		var waiting: bool = wait_panel  != null and wait_panel.visible
		var done:    bool = over_panel  != null and over_panel.visible
		pause_button.disabled = waiting or done
		pause_button.icon = icon("play" if paused else "pause")
		pause_button.tooltip_text = "Resume" if paused else "Pause"
		pause_button.accessibility_name = pause_button.tooltip_text

func _pause() -> void:
	if bullock:
		if game._mp_pause_panel.visible: game._mp_resume()
		else: game._mp_pause()
	else:
		legacy_ui.get_node("Header/PauseButton").pressed.emit()

func _exit() -> void:
	if bullock:
		for button in game._mp_pause_panel.find_children("*", "Button", true, false):
			if button.text == "Choose game":
				button.pressed.emit()
				return
	else:
		legacy_ui.get_node("Header/ExitButton").pressed.emit()
