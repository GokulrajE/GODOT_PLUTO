extends Node
## Public GitHub Releases updater; source/editor sessions never replace themselves.
signal changed
const REPOSITORY := "GokulrajE/GODOT_PLUTO"
const ASSET_NAME := "PLUTO-windows-x86_64.zip"
var cache_path := "user://updates/"
var state := "idle"
var message := ""
var release: Dictionary = {}
var request: HTTPRequest
var downloaded := 0
var total := 0
var enabled := false
var stage := ""
var checking := false
var check_attempt := 0

func _ready() -> void:
	enabled = not OS.has_feature("editor") and not asset_name().is_empty()
	for arg in OS.get_cmdline_args():
		if "tests/" in arg or "tests\\" in arg: enabled = false
	DirAccess.make_dir_recursive_absolute(cache_path)

func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))

func asset_name() -> String:
	if OS.get_name() == "Windows" and OS.has_feature("x86_64"): return ASSET_NAME
	if OS.get_name() == "Linux":
		if OS.has_feature("arm64"): return "PLUTO-linux-arm64.zip"
		if OS.has_feature("x86_64"): return "PLUTO-linux-x86_64.zip"
	return ""

static func parts(value: String) -> PackedInt32Array:
	var regex := RegEx.new()
	regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
	var found := regex.search(value)
	if found == null: return PackedInt32Array()
	return PackedInt32Array([int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))])

static func newer(candidate: String, installed: String) -> bool:
	var a := parts(candidate)
	var b := parts(installed)
	if a.size() != 3 or b.size() != 3: return false
	for i in 3:
		if a[i] != b[i]: return a[i] > b[i]
	return false

func blocks_login() -> bool:
	return enabled and state == "installing"

func _set_state(value: String, text: String) -> void:
	state = value
	message = text
	changed.emit()

func release_asset(data: Dictionary) -> Dictionary:
	for item in data.get("assets", []):
		if not item is Dictionary: continue
		if item.get("name", "") == asset_name():
			var url := str(item.get("browser_download_url", ""))
			var digest := str(item.get("digest", ""))
			var hash_regex := RegEx.new()
			hash_regex.compile("^sha256:[a-fA-F0-9]{64}$")
			if url.begins_with("https://github.com/" + REPOSITORY + "/releases/download/") and hash_regex.search(digest) and int(item.get("size", 0)) > 0 and int(item.get("size", 0)) <= 2147483648:
				return item
	return {}

func accept_release(data: Dictionary) -> void:
	if data.get("draft", false) or data.get("prerelease", false) or parts(str(data.get("tag_name", ""))).size() != 3:
		_unavailable("The release version is invalid. Try checking again.")
		return
	if newer(str(data.tag_name), version()):
		release = data
		var cache := FileAccess.open(cache_path + "required.json", FileAccess.WRITE)
		if cache: cache.store_string(JSON.stringify(release))
		var asset := release_asset(data)
		_set_state("required", "Version %s is available." % data.tag_name if not asset.is_empty() else "Update package for this device is not available yet.")
	elif not release.is_empty() and newer(str(release.get("tag_name", "")), version()):
		_unavailable("A newer version is available.")
	else:
		release = {}
		_set_state("current", "PLUTO v%s is up to date." % version())

func check_updates() -> void:
	if not enabled:
		_set_state("current", "PLUTO v%s • Updates run in supported exported applications." % version())
		return
	if checking or state in ["downloading", "downloaded", "installing"]: return
	if release.is_empty() and FileAccess.file_exists(cache_path + "required.json"):
		var cached = JSON.parse_string(FileAccess.get_file_as_string(cache_path + "required.json"))
		if cached is Dictionary and newer(str(cached.get("tag_name", "")), version()): release = cached
	checking = true
	check_attempt = 0
	_set_state("checking", "Checking GitHub for updates…")
	_send_release_check()

func _send_release_check() -> void:
	check_attempt += 1
	request = HTTPRequest.new()
	request.timeout = 25
	request.body_size_limit = 2097152
	add_child(request)
	request.request_completed.connect(_checked)
	var error := request.request("https://api.github.com/repos/" + REPOSITORY + "/releases/latest", ["Accept: application/vnd.github+json", "User-Agent: PLUTO-Updater"])
	if error != OK:
		checking = false
		request.queue_free()
		_unavailable("Could not check for updates. You can retry.")

func _checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request.queue_free()
	var log := FileAccess.open(cache_path + "release-check.json", FileAccess.WRITE)
	if log:
		log.store_string(JSON.stringify({"time":Time.get_datetime_string_from_system(), "transport_result":result, "http_status":code, "attempt":check_attempt, "version":version()}))
		log.close()
	if result != HTTPRequest.RESULT_SUCCESS and check_attempt < 2:
		_set_state("checking", "Connection interrupted. Retrying GitHub…")
		await get_tree().create_timer(1.0).timeout
		_send_release_check()
		return
	checking = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_unavailable(check_error(result, code))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_unavailable("GitHub returned an invalid release response.")
		return
	accept_release(data)

func _unavailable(text: String) -> void:
	var status_path := cache_path + "updater-status.json"
	if FileAccess.file_exists(status_path):
		var status = JSON.parse_string(FileAccess.get_file_as_string(status_path))
		if status is Dictionary and status.get("state", "") == "failed" and newer(str(status.get("version", "")), version()):
			text += "\nThe update to %s previously failed. Retry the update." % str(status.get("version", ""))
	if not release.is_empty() and newer(str(release.get("tag_name", "")), version()):
		_set_state("required", text + " You can update later.")
	else:
		_set_state("unavailable", text + "\nYou may continue with the installed version.")

func download_update() -> void:
	if not enabled or state != "required": return
	var asset := release_asset(release)
	if asset.is_empty():
		check_updates()
		return
	stage = cache_path + "package-" + str(Time.get_ticks_usec()) + ".zip"
	downloaded = 0
	total = int(asset.size)
	request = HTTPRequest.new()
	request.timeout = 600
	request.body_size_limit = 2147483648
	request.download_file = stage
	add_child(request)
	request.request_completed.connect(_downloaded)
	_set_state("downloading", "Downloading %s…" % release.tag_name)
	var error := request.request(str(asset.browser_download_url), ["User-Agent: PLUTO-Updater"])
	if error != OK:
		request.queue_free()
		_set_state("required", "Download could not start. Retry download.")

func _process(_delta: float) -> void:
	if state == "downloading" and is_instance_valid(request):
		downloaded = request.get_downloaded_bytes()
		changed.emit()

func _downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_state("required", "Download interrupted. Retry download to continue.")
		return
	var asset := release_asset(release)
	var expected := str(asset.digest).trim_prefix("sha256:").to_lower()
	if FileAccess.get_sha256(stage).to_lower() != expected:
		_set_state("required", "Download verification failed. Retry download.")
		return
	_set_state("downloaded", "Update downloaded. Restart when you are ready.")

func install_download() -> void:
	if state != "downloaded" or AppData.is_patient_loaded: return
	var asset := release_asset(release)
	if asset.is_empty(): return
	var digest := str(asset.digest).trim_prefix("sha256:").to_lower()
	if FileAccess.get_sha256(stage).to_lower() != digest:
		_set_state("required", "Download verification failed. Retry download.")
		return
	_launch_installer(digest)

func _launch_installer(digest: String) -> void:
	var linux := OS.get_name() == "Linux"
	var helper_name := "install-update.py" if linux else "PLUTOUpdater.exe"
	if linux and OS.execute("python3", ["--version"]) != 0:
		_set_state("required", "Python 3 is required for Linux updates. Install python3 and retry.")
		return
	var helper := FileAccess.open(cache_path + helper_name, FileAccess.WRITE)
	if helper == null:
		_set_state("required", "Cannot prepare updater. Check disk space and retry.")
		return
	var source := FileAccess.get_file_as_bytes("res://tools/update/" + (helper_name if linux else "bin/" + helper_name))
	if source.is_empty():
		_set_state("required", "This build is missing its updater helper.")
		return
	helper.store_buffer(source)
	helper.close()
	var token := str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(OS.get_process_id())
	var job := {"pid": OS.get_process_id(), "target": OS.get_executable_path().get_base_dir(), "executable": OS.get_executable_path().get_file(), "package": ProjectSettings.globalize_path(stage), "sha256": digest, "version": str(release.tag_name).trim_prefix("v"), "token": token, "cache": ProjectSettings.globalize_path(cache_path)}
	job["platform"] = asset_name().trim_prefix("PLUTO-").trim_suffix(".zip")
	var job_path := cache_path + "job-" + token + ".json"
	var file := FileAccess.open(job_path, FileAccess.WRITE)
	if file == null:
		_set_state("required", "Cannot save update job. Retry.")
		return
	file.store_string(JSON.stringify(job))
	file.close()
	var process_id: int
	if linux:
		process_id = OS.create_process("python3", [ProjectSettings.globalize_path(cache_path + helper_name), ProjectSettings.globalize_path(job_path)], false)
	else:
		process_id = OS.create_process(ProjectSettings.globalize_path(cache_path + helper_name), [ProjectSettings.globalize_path(job_path)], false)
	if process_id <= 0:
		_set_state("required", "Could not start the updater. Retry.")
		return
	_set_state("installing", "Installing update and restarting…")
	# Wait for the helper to validate and stage the package before closing.
	for i in 1200:
		await get_tree().create_timer(0.1).timeout
		if FileAccess.file_exists(cache_path + "ready-" + token):
			PlutoComm.disconnect_device()
			get_tree().quit()
			return
		if not OS.is_process_running(process_id):
			_set_state("required", "Update preparation failed. See updater-status.json in the update cache, then retry.")
			return
	OS.kill(process_id)
	_set_state("required", "Update preparation timed out. Retry.")

func confirm_startup() -> void:
	if not enabled: return
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--pluto-update-token":
			var token := args[i + 1]
			if not token.is_valid_filename() or token.contains("."): return
			var file := FileAccess.open(cache_path + "ack-" + token, FileAccess.WRITE)
			if file: file.store_string(version())

static func check_error(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_RESOLVE: return "Cannot resolve api.github.com. Check this device's DNS or Internet connection."
			HTTPRequest.RESULT_CANT_CONNECT: return "Cannot connect to GitHub. Check Internet access, proxy or firewall settings."
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "GitHub secure connection failed. Check the device clock and trusted certificates."
			HTTPRequest.RESULT_TIMEOUT: return "GitHub update check timed out. Try again when the connection is stable."
			HTTPRequest.RESULT_CONNECTION_ERROR: return "Connection to GitHub was interrupted. Check Internet access and retry."
			_: return "GitHub request failed (network result %d). Retry; details are in release-check.json." % result
	if code == 403 or code == 429: return "GitHub limited or refused the update request (HTTP %d). Try again later." % code
	if code == 404: return "GitHub release not found (HTTP 404). Check repository access."
	return "Release check unavailable (HTTP %d). Try again later." % code
