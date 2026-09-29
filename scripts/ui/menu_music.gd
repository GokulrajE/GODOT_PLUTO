extends AudioStreamPlayer
## One continuous menu soundtrack; gameplay owns its own music.
var muted := false
var menu_active := false
var fade: Tween

func _ready() -> void:
	stream = preload("res://Assets/Arcade/Online/menu-loop.ogg")
	stream.loop = true
	volume_db = -14

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	# Scene replacement leaves current_scene null for a frame. Keep the loop intact.
	if not is_instance_valid(scene): return
	var active := scene.scene_file_path.begins_with("res://scenes/") and scene.name != "CelebrationCard"
	if active != menu_active:
		menu_active = active
		_sync()

func set_muted(value: bool) -> void:
	muted = value
	_sync()

func _exit_tree() -> void:
	if fade and fade.is_valid(): fade.kill()
	stop()
	stream = null

func _sync() -> void:
	if fade and fade.is_valid(): fade.kill()
	if not menu_active or muted:
		stop()
	elif not playing:
		volume_db = -45
		play()
		fade = create_tween()
		fade.tween_property(self, "volume_db", -14.0, 0.8)
