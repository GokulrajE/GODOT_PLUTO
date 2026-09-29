extends Panel
## One-shot results celebration; never changes score or trial state.
var effects: Node2D
var sound: AudioStreamPlayer
var reveal_count := 0
func _ready() -> void:
	effects = preload("res://scripts/effects/game_effects.gd").new()
	add_child(effects)
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://Assets/Arcade/Online/celebration.ogg")
	sound.volume_db = -16
	add_child(sound)
	visibility_changed.connect(_reveal)

func _reveal() -> void:
	if not visible: return
	reveal_count += 1
	sound.play()
	if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)): return
	effects.burst(Vector2(50, 65), true, false)
	effects.burst(Vector2(size.x - 50, 65), true, false)

func _process(delta: float) -> void:
	if visible and effects: effects.step(delta, false)
