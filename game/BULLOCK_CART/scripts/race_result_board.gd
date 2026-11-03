extends VBoxContainer
## Shows only the player's own result — no rival comparison.
var rows: Array[Dictionary] = []

func show_results(race) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	rows.clear()
	add_theme_constant_override("separation", 8)
	var racer: Dictionary = race.racers[0]
	var dur_min := int(race.game_duration / 60.0)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f8dfa0")
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	for pair in [
		["Score", "%d pts" % racer.score],
		["Duration", "%d min" % dur_min],
		["Lanterns collected", str(racer.boosters)],
	]:
		var row := HBoxContainer.new()
		col.add_child(row)
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color("4a3a1a"))
		lbl.add_theme_font_size_override("font_size", 17)
		row.add_child(lbl)
		var val := Label.new()
		val.text = pair[1]
		val.add_theme_color_override("font_color", Color("203f40"))
		val.add_theme_font_size_override("font_size", 17)
		row.add_child(val)
	rows.append({"name": racer.name, "score": racer.score, "boosters": racer.boosters})
	show()
