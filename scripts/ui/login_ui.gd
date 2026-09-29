extends RefCounted
## Login composition is independent from patient authentication.
static func configure(card: Control, title: Label, subtitle: Label) -> void:
	card.anchor_left = 0.28
	card.anchor_right = 0.72
	card.anchor_top = 0.20
	card.anchor_bottom = 0.80
	card.offset_left = 0
	card.offset_right = 0
	card.offset_top = 0
	card.offset_bottom = 0
	title.text = "Welcome to PLUTO"
	subtitle.text = "Your next step toward better movement"
