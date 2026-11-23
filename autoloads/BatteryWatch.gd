extends CanvasLayer
## Warns when the laptop battery runs low: an amber banner at 30 % and a red one at 15 %, only while
## unplugged. Checked once a minute (and once at start-up). Never pauses or blocks the game.

const CHECK_SECONDS := 60.0
const WARN_LEVEL := 30
const CRITICAL_LEVEL := 15
const SHOW_SECONDS := 8.0

var _panel: PanelContainer
var _label: Label
var _hide_timer: SceneTreeTimer
var _last_level := -1          # 0 = none shown yet, 1 = warning shown, 2 = critical shown

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var timer := Timer.new()
	timer.wait_time = CHECK_SECONDS
	timer.autostart = true
	timer.timeout.connect(_check)
	add_child(timer)
	_check.call_deferred()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_panel.offset_top = 14
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_meta("arcade_authored_control", true)
	_panel.set_meta("arcade_authored_control", true)
	_panel.add_child(_label)

func _style(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", sb)

var _thread: Thread = null

## Godot 4 has no battery API, so Windows is asked through PowerShell (in a background thread, so the
## game never stutters). Desktops without a battery return nothing and stay silent.
func _check() -> void:
	if OS.get_name() != "Windows" or (_thread != null and _thread.is_alive()):
		return
	if _thread != null:
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_read_battery)

func _read_battery() -> void:
	var output := []
	var command := "$b = Get-CimInstance Win32_Battery | Select-Object -First 1; if ($b) { \"$($b.EstimatedChargeRemaining),$($b.BatteryStatus)\" }"
	OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", command], output, false, false)
	_on_battery_read.call_deferred(String(output[0]).strip_edges() if output.size() > 0 else "")

func _on_battery_read(text: String) -> void:
	var parts := text.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int():
		_last_level = 0
		return
	var percent := int(parts[0])
	var status := int(parts[1])       # 1 = discharging; 2 = on AC; 3-9 = charging / full
	if status != 1 and status != 4 and status != 5:      # on the charger: nothing to warn about
		_last_level = 0
		return
	report(percent)

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()

## Shows the right banner for a battery level (separate so it can be tested).
func report(percent: int) -> void:
	var level := 2 if percent <= CRITICAL_LEVEL else (1 if percent <= WARN_LEVEL else 0)
	if level == 0:
		_last_level = 0
		return
	if level <= _last_level:
		return                     # already warned at this level
	_last_level = level
	if level == 2:
		_label.text = "Battery %d%% – plug in the charger now" % percent
		_style(Color("c0273a"))
	else:
		_label.text = "Battery %d%% – please plug in the charger" % percent
		_style(Color("c77a0a"))
	_panel.visible = true
	_panel.reset_size()
	var tween := create_tween()
	_panel.modulate.a = 0.0
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	_hide_timer = get_tree().create_timer(SHOW_SECONDS)
	_hide_timer.timeout.connect(func(): if is_instance_valid(_panel): _panel.visible = false)
