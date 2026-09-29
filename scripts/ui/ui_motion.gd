extends RefCounted
## Short, interruptible motion that never changes container geometry.

static func enabled() -> bool:
	return not bool(ProjectSettings.get_setting("pluto/ui/reduced_motion", false))

static func reveal(control: Control) -> void:
	if not enabled() or not control.is_visible_in_tree():
		return
	control.self_modulate.a = 0.0
	var tween := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "self_modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func bind(button: BaseButton) -> void:
	if button.has_meta("ui_motion"):
		return
	button.set_meta("ui_motion", true)
	var audio_root := button.get_tree().root
	button.pressed.connect(func():
		var audio := AudioStreamPlayer.new()
		audio.stream = preload("res://Assets/Arcade/Online/click.ogg")
		audio.volume_db = -18
		audio_root.add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
	)
	button.mouse_entered.connect(func(): _feedback(button, 1.035))
	button.mouse_exited.connect(func(): _feedback(button, 1.0))
	button.focus_entered.connect(func(): _feedback(button, 1.035))
	button.focus_exited.connect(func(): _feedback(button, 1.0))
	button.button_down.connect(func(): _feedback(button, 0.95))
	button.button_up.connect(func(): _feedback(button, 1.0))

static func bind_modal(panel: Control) -> void:
	if panel.has_meta("ui_modal_motion"):
		return
	panel.set_meta("ui_modal_motion", true)
	panel.visibility_changed.connect(func():
		if not panel.visible or not enabled():
			return
		var previous: Tween = panel.get_meta("ui_modal_tween") if panel.has_meta("ui_modal_tween") else null
		if previous and previous.is_valid(): previous.kill()
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.97, 0.97)
		panel.modulate.a = 0.0
		var tween := panel.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		panel.set_meta("ui_modal_tween", tween)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	)

static func _feedback(button: BaseButton, brightness: float) -> void:
	if button.disabled or not enabled():
		return
	var previous: Tween = button.get_meta("ui_feedback_tween") if button.has_meta("ui_feedback_tween") else null
	if previous and previous.is_valid():
		previous.kill()
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	button.set_meta("ui_feedback_tween", tween)
	tween.tween_property(button, "self_modulate", Color(brightness, brightness, brightness), 0.12)
