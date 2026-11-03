extends Panel
## One-shot results celebration; never changes score or trial state.
var sound: AudioStreamPlayer
var reveal_count := 0
func _ready() -> void:
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://Assets/Arcade/Online/game-over.ogg")
	sound.volume_db = -6
	add_child(sound)
	visibility_changed.connect(_reveal)

func _reveal() -> void:
	if not visible: return
	reveal_count += 1
	sound.play()
	if bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false)): return
	var star := get_node_or_null("ResultStar") as Control
	if star:
		star.pivot_offset = star.size * 0.5
		star.scale = Vector2(0.85, 0.85)
		create_tween().tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
