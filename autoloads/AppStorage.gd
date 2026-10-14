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
