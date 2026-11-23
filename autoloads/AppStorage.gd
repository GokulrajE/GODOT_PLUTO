extends Node
## Durable patient files and device settings outside the application ZIP.
var root_path := ""
var error_message := ""
func _ready() -> void:
	# Test runners must never migrate real records or write Documents.
	var testing := false
	for arg in OS.get_cmdline_args():
		if "tests/" in arg or "tests\\" in arg or "preview_ui.gd" in arg: testing = true
	root_path = ("user://test-storage/" if testing else local_documents_root())
	if DirAccess.make_dir_recursive_absolute(root_path + "data") != OK:
		error_message = "Cannot open PLUTO storage in Documents. Check folder permissions."
		return
	if not testing:
		var local_marker := root_path + "migration-local-documents.complete"
		if not FileAccess.file_exists(local_marker):
			var previous_root := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("PLUTO") + "/"
			if previous_root.replace("\\", "/").to_lower() != root_path.replace("\\", "/").to_lower():
				if not copy_missing(previous_root + "data", root_path + "data"):
					error_message = "Could not copy records from redirected Documents. Originals are unchanged."
					return
				for name in ["device.cfg", "settings.cfg"]:
					if FileAccess.file_exists(previous_root + name) and not FileAccess.file_exists(root_path + name):
						if DirAccess.copy_absolute(previous_root + name, root_path + name) != OK:
							error_message = "Could not migrate " + name
							return
			var migrated := FileAccess.open(local_marker, FileAccess.WRITE)
			if migrated == null:
				error_message = "Cannot save the Documents migration marker."
				return
			migrated.store_line(Time.get_datetime_string_from_system())
			migrated.close()
		var marker := root_path + "migration-v1.complete"
		if not FileAccess.file_exists(marker):
			if not copy_missing("res://data", root_path + "data"):
				error_message = "Patient data migration failed. Original files are unchanged."
				return
			var done := FileAccess.open(marker, FileAccess.WRITE)
			if done: done.store_line(Time.get_datetime_string_from_system())
		if not FileAccess.file_exists(settings_path()) and FileAccess.file_exists("user://game_settings.cfg"):
			if DirAccess.copy_absolute("user://game_settings.cfg", settings_path()) != OK:
				error_message = "Could not migrate application settings."
	var config := ConfigFile.new()
	if not FileAccess.file_exists(root_path + "device.cfg"):
		config.set_value("serial", "port", "COM45")
		if config.save(root_path + "device.cfg") != OK: error_message = "Cannot save device.cfg."
func settings_path() -> String: return root_path + "settings.cfg"
func device_port() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(root_path + "device.cfg") != OK: return ""
	return str(cfg.get_value("serial", "port", "")).strip_edges()
## Developer settings shared with the sender and any other linked program, all in Documents/PLUTO/device.cfg:
##   [serial] port = "COM45"
##   [server] host = "192.168.0.101"   port = 5000
##   [device] id = "PLUTO"             client_id = "" (empty = this computer's name)
func dev_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var found := cfg.load(root_path + "device.cfg") == OK
	return {
		"port": str(cfg.get_value("serial", "port", "")).strip_edges() if found else "",
		"host": str(cfg.get_value("server", "host", "")).strip_edges() if found else "",
		"server_port": int(cfg.get_value("server", "port", 0)) if found else 0,
		"device_id": str(cfg.get_value("device", "id", "")).strip_edges() if found else "",
		"client_id": str(cfg.get_value("device", "client_id", "")).strip_edges() if found else "",
	}

## Each group is validated and saved on its own, so changing one never touches the others
## (other sections and keys in device.cfg are always kept). Returns "" or an error message.
func save_dev_section(section: String, values: Dictionary) -> String:
	var cfg := ConfigFile.new()
	var path := root_path + "device.cfg"
	if FileAccess.file_exists(path) and cfg.load(path) != OK: return "Could not read device.cfg."
	match section:
		"serial":
			var port := str(values.get("port", "")).strip_edges()
			if port.is_empty(): return "Enter a COM port, for example COM45."
			cfg.set_value("serial", "port", port)
		"server":
			var host := str(values.get("host", "")).strip_edges()
			var server_port := int(values.get("server_port", 0))
			if host.is_empty() or host.contains(" "): return "Enter the server IP address or host name."
			if server_port < 1 or server_port > 65535: return "Server port must be 1 - 65535."
			cfg.set_value("server", "host", host)
			cfg.set_value("server", "port", server_port)
		"device":
			var device_id := str(values.get("device_id", "")).strip_edges()
			if device_id.is_empty(): return "Enter a device name, for example PLUTO."
			cfg.set_value("device", "id", device_id)
			cfg.set_value("device", "client_id", str(values.get("client_id", "")).strip_edges())
		_:
			return "Unknown settings group."
	if cfg.save(path) != OK: return "Could not save device.cfg."
	return ""
func set_device_port(port: String) -> String:
	return save_dev_section("serial", {"port": port})
func copy_missing(source: String, destination: String) -> bool:
	if not DirAccess.dir_exists_absolute(source): return true
	if DirAccess.make_dir_recursive_absolute(destination) != OK: return false
	var dir := DirAccess.open(source)
	if dir == null: return false
	for name in dir.get_directories():
		if not copy_missing(source.path_join(name), destination.path_join(name)): return false
	for name in dir.get_files():
		# Godot-generated import/translation sidecars are not patient records.
		if name.ends_with(".import") or name.ends_with(".translation"): continue
		var dest := destination.path_join(name)
		if FileAccess.file_exists(dest): continue
		if DirAccess.copy_absolute(source.path_join(name), dest) != OK: return false
		if FileAccess.get_sha256(source.path_join(name)) != FileAccess.get_sha256(dest): return false
	return true

func local_documents_root() -> String:
	# Windows Known Folder Documents may point into OneDrive. Use the profile
	# directory explicitly so the application's records remain local.
	if OS.get_name() == "Windows":
		var profile := OS.get_environment("USERPROFILE")
		if not profile.is_empty(): return profile.path_join("Documents/PLUTO") + "/"
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("PLUTO") + "/"
