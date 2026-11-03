extends Control
## Compact racing instruments drawn independently of the game controller.
var auto_boost := false
var timed_mode := false
var live_rows: Array[Dictionary] = []
var racer_count := 3
var place := 1
var seconds := 0.0
var score := 0
var remaining := 480
var power := 0
var boost := 0.0
var streak := 0
var progress_values := PackedFloat32Array([0, 0, 0])
var font: Font

func _ready() -> void:
	font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 92)

func update_race(race) -> void:
	timed_mode = race.timed_mode
	place = race.player_place()
	live_rows.clear()
	var ordered: Array[int] = race.order()
	racer_count = ordered.size()
	var lead: Dictionary = race.racers[ordered[0]]
	for rank in ordered.size():
		var racer: Dictionary = race.racers[ordered[rank]]
		var status: String
		if timed_mode:
			status = "LEADING" if rank == 0 else "%d pts behind" % maxi(0, lead.score - racer.score)
			if racer.boost > 0: status += "  •  BOOST"
		else:
			status = "LEADING" if rank == 0 else "%.0f m behind" % maxf(0, lead.distance - racer.distance)
			if racer.finish >= 0: status = "%.2f s  •  FINISHED" % racer.finish
			elif race.complete: status = "Not finished"
			elif racer.boost > 0: status += "  •  BOOST"
		live_rows.append({"name": racer.name, "rank": rank + 1, "status": status, "player": ordered[rank] == 0})
	seconds = race.elapsed
	score = race.racers[0].score
	if timed_mode:
		remaining = maxi(0, int(race.game_duration - race.elapsed))
	else:
		remaining = maxi(0, int(race.LENGTH - race.racers[0].distance))
	power = race.racers[0].power
	boost = race.racers[0].boost
	streak = race.racers[0].streak
	if timed_mode:
		var max_score := 1
		for r in race.racers: max_score = maxi(max_score, r.score)
		for i in range(3): progress_values[i] = float(race.racers[i].score) / float(max_score)
	else:
		for i in range(3): progress_values[i] = race.racers[i].distance / race.LENGTH
	queue_redraw()

func _card(rect: Rect2, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)

func _draw() -> void:
	var ink := Color("f9ebc9")
	var gold := Color("ffd071")
	var width := maxf(560, size.x)
	_card(Rect2(0, 0, width, 86), Color(.08, .18, .19, .94), Color("a68143"))
	_card(Rect2(6, 6, 93, 74), Color("dbab4d"), Color("ffe1a1"))
	draw_string(font, Vector2(18, 27), "POSITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3c3021"))
	draw_string(font, Vector2(22, 66), str(place), HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("222f2a"))
	draw_string(font, Vector2(54, 64), "/ %d" % racer_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("4d442e"))
	var column := (width - 120) / 3
	var names: Array[String]
	var values: Array[String]
	var sec_m := int(seconds / 60.0)
	var sec_s := int(seconds) % 60
	if auto_boost:
		names = ["RACE TIME", "TO FINISH", "BLUE BOOST"]
		values = ["%02d:%02d" % [sec_m, sec_s], "%d m" % remaining, "%.1f s" % boost if boost > 0 else "Collect!"]
	elif timed_mode:
		var rem_m := int(remaining / 60.0)
		var rem_s := remaining % 60
		names = ["RACE TIME", "POINTS", "TIME LEFT"]
		values = ["%02d:%02d" % [sec_m, sec_s], str(score), "%02d:%02d" % [rem_m, rem_s]]
	else:
		names = ["RACE TIME", "POINTS", "TO FINISH"]
		values = ["%02d:%02d" % [sec_m, sec_s], str(score), "%d m" % remaining]
	for i in range(3):
		var x := 116 + column * i
		draw_string(font, Vector2(x, 27), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, gold)
		draw_string(font, Vector2(x, 61), values[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 27, ink)
		if i < 2: draw_line(Vector2(x + column - 14, 18), Vector2(x + column - 14, 68), Color("47605b"), 1)
	# Progress ribbon: racer positions along track (distance mode) or relative score (timed mode).
	draw_line(Vector2(8, 101), Vector2(width - 8, 101), Color("254c48"), 6, true)
	draw_line(Vector2(8, 101), Vector2(8 + (width - 16) * progress_values[0], 101), gold, 4, true)
	var colors := [gold, Color("ed996a"), Color("bda8ff")]
	for i in [1, 2, 0]:
		var x: float = 8 + (width - 16) * progress_values[i]
		draw_circle(Vector2(x, 101 + (i - 1) * 5), 5 if i == 0 else 3, colors[i])
	if auto_boost:
		if boost > 0:
			draw_line(Vector2(116, 74), Vector2(116 + (width - 132) * clampf(boost / 3.0, 0, 1), 74), Color("69e3ed"), 4, true)
		var row_width: float = width / maxi(1, live_rows.size())
		for i in live_rows.size():
			var row: Dictionary = live_rows[i]
			var x := i * row_width
			_card(Rect2(x, 114, row_width - 6, 54), Color("204e4c") if row.player else Color("233a3c"), Color("e9c16b") if row.player else Color("5f7971"))
			draw_string(font, Vector2(x + 10, 136), "%d  %s" % [row.rank, row.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, gold if row.player else ink)
			draw_string(font, Vector2(x + 10, 156), row.status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		return
	# Charge diamonds and boost bar for manual-boost (regular) mode.
	_card(Rect2(0, 115, width, 31), Color(.08, .18, .19, .94), Color("47605b"))
	for i in range(3):
		var x := 15.0 + i * 24
		draw_colored_polygon(PackedVector2Array([Vector2(x, 119), Vector2(x + 8, 129), Vector2(x, 139), Vector2(x - 8, 129)]), Color("69e3ce") if i < power else Color("46635c"))
	draw_string(font, Vector2(92, 136), "BOOST %.1f s" % boost if boost > 0 else "SPACE  •  BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)
	if streak > 0: draw_string(font, Vector2(width - 150, 136), "STREAK  %d" % streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, gold)
