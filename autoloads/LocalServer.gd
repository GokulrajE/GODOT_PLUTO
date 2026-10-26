extends Node
## Local NeuroDash agent API; all network and upload work is asynchronous.
signal patients_changed
signal message_changed
signal claim_lost

var enabled := false
var settings: Dictionary = {}
var patients: Array = []
var message := ""
var held_patient := ""
var login_group := "devices"
var local_session := false
var available := false
var _starting := false
var _poll := 0.0
var _polling := false
var _closing := false
var uploader: Node
var upload_message := ""
var refresh_diagnostic := ""

func initialize_uploads() -> void:
	if uploader != null: return
	uploader = load("res://scripts/network/session_upload.gd").new()
	add_child(uploader)
	uploader.setup(AppStorage.root_path, settings)
	uploader.status_changed.connect(func(value: String):
		upload_message = value
		_set_message(value))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path := AppStorage.root_path + "server.json"
	settings = {"enabled": true, "sender_path": "C:/sender.py",
		"device_id": "PLUTO", "agent_port": 5055, "python": "python" if OS.get_name() == "Windows" else "python3",
		"patients_file": "", "assessment_timepoint": "A0"}
	# Automated tests must not contact the real clinic or claim real patients.
	if "test-storage" in AppStorage.root_path: return
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary: settings.merge(data, true)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(settings, "\t"))
	enabled = bool(settings.get("enabled", false))
	if not enabled: return
	get_tree().auto_accept_quit = false
	read_sender_address()
	initialize_uploads()
	load_patients()
	ensure_agent.call_deferred()

func _set_message(value: String) -> void:
	message = value
	message_changed.emit()

func request(endpoint: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var error := http.request("http://127.0.0.1:%d/%s" % [int(settings.get("agent_port", 5055)), endpoint])
	if error != OK:
		http.queue_free()
		return {"code": 0}
	var response: Array = await http.request_completed
	http.queue_free()
	var parser := JSON.new()
	var parsed = parser.data if parser.parse(response[3].get_string_from_utf8()) == OK else {}
	return {"code": int(response[1]), "body": parsed if parsed is Dictionary else {}}

func ensure_agent() -> bool:
	if not enabled or _starting: return available
	_starting = true
	var result := await request("status")
	available = result.code == 200 and result.get("body", {}).has("patient")
	if available:
		settings["client_id"] = str(result.body.get("client", settings.get("client_id", "")))
	_starting = false
	_set_message("Background agent connected." if available else "Background agent unavailable on port %d." % int(settings.get("agent_port", 5055)))
	return available

func patients_path() -> String:
	var configured := str(settings.get("patients_file", "")).strip_edges()
	if not configured.is_empty(): return configured
	if OS.get_name() == "Windows": return "C:/NeuroDash/patients.json"
	return OS.get_environment("HOME").path_join("NeuroDash/patients.json")

func valid_id(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_-]{1,40}$")
	return regex.search(value) != null

func load_patients() -> void:
	var path := patients_path()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	patients = data.get("patients", []) if data is Dictionary and data.get("patients", []) is Array else []
	patients_changed.emit()

func assigned(entry: Dictionary, group: String) -> bool:
	if entry.get("status", "") != "active": return false
	var values = entry.get(group, [])
	if not values is Array: return false
	for device in values:
		if str(device).to_upper() == str(settings.get("device_id", "PLUTO")).to_upper(): return true
	return false

func suggestions(query: String, group: String) -> Array[String]:
	var matches: Array[String] = []
	for entry in patients:
		if not entry is Dictionary: continue
		var pid: String = str(entry.get("user_id", ""))
		if valid_id(pid) and assigned(entry, group) and pid.to_lower().begins_with(query.strip_edges().to_lower()) and pid not in matches:
			matches.append(pid)
	if group == "devices":
		for pid in DirAccess.get_directories_at(DataManager.data_root):
			if valid_id(pid) and DataManager.patient_exists(pid) and patient_entry(pid).is_empty() and pid.to_lower().begins_with(query.strip_edges().to_lower()) and pid not in matches:
				matches.append(pid)
	matches.sort()
	return matches

func patient_entry(pid: String) -> Dictionary:
	for entry in patients:
		if entry is Dictionary and str(entry.get("user_id", "")) == pid: return entry
	return {}

func start_patient(pid: String, group: String) -> bool:
	if not enabled: return true
	load_patients()
	local_session = false
	if group == "devices" and valid_id(pid) and patient_entry(pid).is_empty() and DataManager.patient_exists(pid):
		local_session = true
		_set_message("Local patient session started.")
		return true
	if group != "devices" or not valid_id(pid) or not assigned(patient_entry(pid), "devices"):
		_set_message("This ID is not in the selected PLUTO assignment list.")
		return false
	if not available and not await ensure_agent(): return false
	var result := await request("start?patient=" + pid.uri_encode())
	if result.code != 200 or not result.get("body", {}).get("ok", false):
		_set_message(str(result.get("body", {}).get("message", "Could not start the patient session. Retry the local agent.")))
		return false
	held_patient = pid
	if uploader: uploader.held_patient = pid
	login_group = group
	_set_message("Session started." if result.body.get("server_reachable", true) else "Server offline: using cached assignments.")
	return true

func stop_patient() -> void:
	if not enabled or held_patient.is_empty(): return
	await request("stop?patient=" + held_patient.uri_encode())
	held_patient = ""
	if uploader: uploader.held_patient = ""

func trial_ended() -> void:
	if not enabled or AppData.demo_mode or local_session: return
	initialize_uploads()
	if valid_id(AppData.patient_id):
		uploader.enqueue(AppData.patient_id, DataManager.get_session_path() + "sessions.csv")
	config_updated()
	if held_patient.is_empty(): return
	var result := await request("trial-ended")
	_check_lost(result.get("body", {}))

func assessment_finished(_rom: Dictionary) -> void:
	# Notify the agent and queue the saved session for the native uploader.
	trial_ended()

func _process(delta: float) -> void:
	if not enabled or _polling: return
	_poll += delta
	if _poll < 3.0: return
	_poll = 0.0
	_polling = true
	read_sender_address()
	load_patients()
	if available:
		var result := await request("status")
		_check_lost(result.get("body", {}))
		if result.code == 200:
			var uploads: Dictionary = result.get("body", {}).get("uploads", {})
			if int(uploads.get("pending", 0)) > 0: _set_message(str(uploads.get("message", "Upload pending")))
		elif result.code == 0:
			available = false
			_set_message("Background agent unavailable. Check the existing agent process.")
	_polling = false

func _check_lost(body: Dictionary) -> void:
	if body.has("lost") and body.lost != null and not held_patient.is_empty():
		held_patient = ""
		if uploader: uploader.held_patient = ""
		PlutoComm.set_control_type("NONE")
		PlutoComm.disconnect_device()
		AppData.close_session_logging()
		_set_message("Patient session moved to another device. End this session before continuing.")
		claim_lost.emit()
		get_tree().change_scene_to_file("res://scenes/SummaryScene.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and enabled and not _closing:
		_closing = true
		PlutoComm.disconnect_device()
		AppData.close_session_logging()
		await stop_patient()
		get_tree().quit()

var refreshing_patients := false

func sender_path() -> String:
	var configured := str(settings.get("sender_path", "")).strip_edges()
	if not configured.is_empty(): return configured
	return "C:/sender.py"

static func _run_patient_sender(python: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var code := OS.execute(python, arguments, output, true, false)
	return {"code": code, "output": "\n".join(output)}

func refresh_patients() -> bool:
	if refreshing_patients: return false
	var path := sender_path()
	if not FileAccess.file_exists(path):
		_set_message("Sender not found. Set sender_path in Documents/PLUTO/server.json.")
		return false
	read_sender_address()
	refreshing_patients = true
	_set_message("Refreshing patient IDs…")
	# The external sender owns server address, device identity and patient cache.
	var arguments := PackedStringArray(["-X", "utf8", path, "--login"])
	var worker := Thread.new()
	var error := worker.start(_run_patient_sender.bind(str(settings.get("python", "python" if OS.get_name() == "Windows" else "python3")), arguments))
	if error != OK:
		refreshing_patients = false
		_set_message("Could not start patient refresh. Check the Python setting.")
		return false
	while worker.is_alive(): await get_tree().create_timer(0.1).timeout
	var result: Dictionary = worker.wait_to_finish()
	refreshing_patients = false
	refresh_diagnostic = "Exit %s: %s" % [result.code, str(result.output).strip_edges()]
	var diagnostic_file := FileAccess.open(AppStorage.root_path.path_join("patient-refresh.log"), FileAccess.WRITE)
	if diagnostic_file:
		diagnostic_file.store_string(Time.get_datetime_string_from_system() + "\nSender: " + path + "\n" + refresh_diagnostic)
		diagnostic_file.close()
	var success: bool = result.code == 0 and ("Patients updated:" in result.output or "Patients up to date" in result.output)
	load_patients()
	if success:
		_set_message("Patient list refreshed.")
	else:
		var detail := str(result.output).strip_edges()
		if detail.is_empty():
			detail = "Could not run Python (exit %s). Check the python path in server.json." % result.code
		else:
			detail = detail.split("\n")[-1].strip_edges().left(240)
		_set_message("Refresh failed: " + detail + " Saved IDs remain available. See patient-refresh.log.")
	return success

func read_sender_address() -> bool:
	var path := sender_path()
	if not FileAccess.file_exists(path): return false
	var source := FileAccess.get_file_as_string(path)
	var host_pattern := RegEx.new()
	host_pattern.compile("(?m)^SERVER_IP\\s*=\\s*[\"']([^\"'\\r\\n]+)[\"']")
	var port_pattern := RegEx.new()
	port_pattern.compile("(?m)^SERVER_PORT\\s*=\\s*([0-9]+)\\s*(?:#.*)?$")
	var host_match := host_pattern.search(source)
	var port_match := port_pattern.search(source)
	if host_match == null or port_match == null: return false
	var port := int(port_match.get_string(1))
	if port < 1 or port > 65535: return false
	settings["server_host"] = host_match.get_string(1)
	settings["server_port"] = port
	return true

func config_updated() -> void:
	if not enabled or AppData.demo_mode or local_session or not valid_id(AppData.patient_id): return
	if not assigned(patient_entry(AppData.patient_id), "devices"): return
	var path := DataManager.export_server_config(AppData.patient_id)
	if path.is_empty():
		_set_message("Could not prepare configdata.csv for upload.")
		return
	initialize_uploads()
	uploader.enqueue(AppData.patient_id, path, "configdata.csv")
