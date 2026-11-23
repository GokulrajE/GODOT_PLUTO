extends RefCounted
const Motion = preload("res://scripts/ui/ui_motion.gd")

static func open(login: Control, dashboard: Control) -> void:
	dashboard.visible = true
	if not Motion.enabled():
		login.anchor_left = 0.52
		login.anchor_right = 0.96
		return
	dashboard.modulate.a = 0
	var tween := login.create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(login, "anchor_left", 0.52, 0.32)
	tween.tween_property(login, "anchor_right", 0.96, 0.32)
	tween.tween_property(dashboard, "modulate:a", 1.0, 0.28).set_delay(0.18)
