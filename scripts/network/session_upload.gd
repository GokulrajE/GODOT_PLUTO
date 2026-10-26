extends Node
## Nonblocking native uploads using the server address read from the external sender.
signal status_changed(message: String)
var settings: Dictionary = {}
var directory := ""
var held_patient := ""
var input: FileAccess
var current := ""
var header: Dictionary = {}
var phase := "idle"
var retry_at := 0
var retry_seconds := 30.0
var confirmed := 0

func setup(root: String, config: Dictionary) -> void:
	settings = config
	directory = root.path_join("session-uploads")
	DirAccess.make_dir_recursive_absolute(directory)
	process_mode = Node.PROCESS_MODE_ALWAYS

func enqueue(patient: String, source: String, filename: String = "sessions.csv") -> bool:
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		status_changed.emit("Session saved locally, but its upload file could not be opened.")
		return false
	var metadata := {"device_id":settings.get("device_id", "PLUTO"),
		"client_id":settings.get("client_id", ""), "user_id":patient,
		"filename":filename, "file_size":file.get_length()}
	var name := "%020d-%012d.job" % [int(Time.get_unix_time_from_system()*1000000), Time.get_ticks_usec()]
	var path := directory.path_join(name)
	var output := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if output == null: return false
	output.big_endian = true
	var bytes := JSON.stringify(metadata).to_utf8_buffer()
	output.store_32(bytes.size())
	output.store_buffer(bytes)
	while file.get_position() < file.get_length():
		output.store_buffer(file.get_buffer(65536))
	file.close()
	output.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return false
	status_changed.emit("Session saved; uploading to server…")
	return true

var peer: StreamPeerTCP
var pending := PackedByteArray()
var response := PackedByteArray()
var deadline := 0
var timeout_seconds := 30.0

func _process(_delta: float) -> void:
	if directory.is_empty(): return
	if phase == "idle":
		if Time.get_ticks_msec() < retry_at: return
		var jobs := DirAccess.get_files_at(directory)
		jobs.sort()
		for name in jobs:
			if name.ends_with(".job"):
				_begin(directory.path_join(name))
				break
		return
	peer.poll()
	if Time.get_ticks_msec() > deadline:
		_fail("Server acknowledgement timed out")
		return
	var state := peer.get_status()
	if state == StreamPeerTCP.STATUS_ERROR:
		_fail("Cannot connect to server")
		return
	if phase == "connect":
		if state == StreamPeerTCP.STATUS_CONNECTED: phase = "send"
		elif state == StreamPeerTCP.STATUS_NONE: _fail("Server connection closed")
		return
	if phase == "send":
		if state != StreamPeerTCP.STATUS_CONNECTED:
			_fail("Server disconnected during upload")
			return
		if pending.is_empty() and input.get_position() < input.get_length(): pending = input.get_buffer(65536)
		if not pending.is_empty():
			var result := peer.put_partial_data(pending)
			if result[0] != OK:
				_fail("Session transfer failed")
				return
			pending = pending.slice(int(result[1]))
			if int(result[1]) > 0: deadline = Time.get_ticks_msec() + int(timeout_seconds * 1000)
		else:
			input.close()
			input = null
			phase = "ack"
		return
	if phase == "ack":
		var count := peer.get_available_bytes()
		if count > 0:
			var result := peer.get_partial_data(mini(count, 65536))
			if result[0] != OK:
				_fail("Could not read acknowledgement")
				return
			response.append_array(result[1])
			if response.size() > 65536:
				_fail("Invalid acknowledgement")
				return
			var payload := response
			if header.has("action"):
				if response.size() < 4: return
				var buffer := StreamPeerBuffer.new()
				buffer.big_endian = true
				buffer.data_array = response
				var length := buffer.get_u32()
				if response.size() < 4 + length: return
				payload = response.slice(4, 4 + length)
			var json := JSON.new()
			if json.parse(payload.get_string_from_utf8()) == OK and json.data is Dictionary:
				if json.data.get("success", false): _success()
				else: _fail(str(json.data.get("message", "Server rejected upload")))
				return
		if state == StreamPeerTCP.STATUS_NONE: _fail("Server closed without confirming receipt")

func _begin(path: String) -> void:
	current = path
	input = FileAccess.open(path, FileAccess.READ)
	if input == null:
		_fail("Cannot read queued session")
		return
	input.big_endian = true
	var length := input.get_32()
	if length > 65536 or length > input.get_length() - 4:
		_fail("Invalid queued session")
		return
	var parsed = JSON.parse_string(input.get_buffer(length).get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Invalid queued metadata")
		return
	header = parsed
	if header.has("action") and str(header.get("user_id", "")) == held_patient:
		input.close()
		input = null
		DirAccess.remove_absolute(current)
		return
	input.seek(0)
	pending.clear()
	response.clear()
	peer = StreamPeerTCP.new()
	deadline = Time.get_ticks_msec() + int(timeout_seconds * 1000)
	phase = "connect"
	if str(settings.get("server_host", "")).is_empty():
		_fail("Server address unavailable in sender.py")
	elif peer.connect_to_host(str(settings.server_host), int(settings.get("server_port", 5000))) != OK:
		_fail("Cannot reach configured server")

func _success() -> void:
	peer.disconnect_from_host()
	if not header.has("action"):
		confirmed += 1
		# Uploads renew server presence. Release a finished patient's upload claim.
		if held_patient != str(header.get("user_id", "")):
			var release := {"action":"release", "device_id":header.device_id,
				"client_id":header.client_id, "user_id":header.user_id}
			var file := FileAccess.open(current + "-release.job", FileAccess.WRITE)
			if file:
				file.big_endian = true
				var bytes := JSON.stringify(release).to_utf8_buffer()
				file.store_32(bytes.size())
				file.store_buffer(bytes)
				file.close()
		status_changed.emit("Session upload confirmed by server.")
		var receipt := FileAccess.open(directory.path_join("last-upload.json"), FileAccess.WRITE)
		if receipt:
			receipt.store_string(JSON.stringify({"state":"sent", "patient":header.user_id, "time":Time.get_datetime_string_from_system()}))
			receipt.close()
	DirAccess.remove_absolute(current)
	current = ""
	phase = "idle"

func _fail(reason: String) -> void:
	if peer: peer.disconnect_from_host()
	if input:
		input.close()
		input = null
	phase = "idle"
	retry_at = Time.get_ticks_msec() + int(retry_seconds * 1000)
	status_changed.emit("Session upload pending: %s. Retrying automatically." % reason)

func _exit_tree() -> void:
	if peer: peer.disconnect_from_host()
	if input: input.close()
