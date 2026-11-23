extends CanvasLayer
## Global, read-only status overlay; visible across scene transitions.
var badge: Button
var last_state := ""
func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	badge = Button.new()
	badge.set_meta("arcade_authored_control",true)
	root.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -62
	badge.offset_right = -14
	badge.offset_top = 16
	badge.offset_bottom = 64
	badge.mouse_default_cursor_shape = Control.CURSOR_HELP
	for state in ["normal","hover","pressed","focus"]:
		badge.add_theme_stylebox_override(state,preload("res://scripts/ui/ui_palette.gd").button(Color("1a2e44")))
func _process(_delta: float) -> void:
	var state := "demo" if AppData.demo_mode else ("connected" if PlutoComm.is_connected else "disconnected")
	if state == last_state: return
	last_state = state
	# connected is already shown by the green dot beside the Hz reading, so no tick badge then
	badge.visible = false      # the dot + Hz pill (StatusOverlay) now shows every state, so no icon badge
	badge.icon = load("res://Assets/UI/compact/%s.svg" % state)
	badge.tooltip_text = {"demo":"Keyboard demo — device input inactive", "connected":"PLUTO connected", "disconnected":"PLUTO disconnected"}[state]
	badge.accessibility_name = badge.tooltip_text
	badge.add_theme_color_override("icon_normal_color",Color("b8f3d0") if state == "connected" else Color("ffe0a0"))
