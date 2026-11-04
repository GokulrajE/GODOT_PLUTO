extends RefCounted
## Legacy durations are estimates; new ledger rows contain active countdown seconds.
static func read_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return rows
	var header := PackedStringArray()
	while not file.eof_reached():
		var fields := file.get_csv_line()
		if fields.is_empty() or fields[0].is_empty() or fields[0].begins_with(":"): continue
		if header.is_empty():
			header = fields
			continue
		if fields.size() != header.size(): continue
		var row := {}
		for i in header.size(): row[header[i]] = fields[i]
		rows.append(row)
	return rows

static func summarize(session_path: String, date: String) -> Dictionary:
	var result := {}
	var measured := {}
	for row in read_csv(session_path + "active-time.csv"):
		measured[row.TrialRawDataFile] = true
		if row.Date == date: _add(result, row.Mechanism, row.GameName, maxf(0, float(row.ActiveSeconds)), false)
	for row in read_csv(session_path + "sessions.csv"):
		if measured.has(row.TrialRawDataFile) or not str(row.TrialStartTime).begins_with(date): continue
		var wall := float(Time.get_unix_time_from_datetime_string(row.TrialStopTime) - Time.get_unix_time_from_datetime_string(row.TrialStartTime))
		_add(result, row.Mechanism, row.GameName, clampf(float(row.MoveTime), 0, maxf(wall, 0)), true)
	return result

static func _add(result: Dictionary, mech: String, game: String, seconds: float, estimated: bool) -> void:
	if not result.has(mech): result[mech] = {"seconds": 0.0, "estimated": false, "games": {}}
	result[mech].seconds += seconds
	result[mech].estimated = result[mech].estimated or estimated
	result[mech].games[game] = float(result[mech].games.get(game, 0.0)) + seconds

static func clock_text(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

