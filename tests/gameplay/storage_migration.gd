extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var storage = root.get_node("AppStorage")
	assert(storage.error_message.is_empty())
	if OS.get_name() == "Windows":
		assert(storage.local_documents_root() == OS.get_environment("USERPROFILE").path_join("Documents/PLUTO") + "/")
	var base := "res://.godot/storage-fixture/" + str(Time.get_ticks_usec()) + "/"
	DirAccess.make_dir_recursive_absolute(base + "old/patient")
	var f := FileAccess.open(base + "old/patient/configdata", FileAccess.WRITE)
	f.store_string("original")
	f.close()
	assert(storage.copy_missing(base + "old", base + "new"))
	assert(FileAccess.get_file_as_string(base + "new/patient/configdata") == "original")
	f = FileAccess.open(base + "new/patient/configdata", FileAccess.WRITE)
	f.store_string("newer")
	f.close()
	assert(storage.copy_missing(base + "old", base + "new"))
	assert(FileAccess.get_file_as_string(base + "new/patient/configdata") == "newer")
	assert(FileAccess.get_file_as_string(base + "old/patient/configdata") == "original")
	assert(root.get_node("DataManager").data_root == storage.root_path + "data/")
	assert(root.get_node("AppData").SETTINGS_PATH == storage.settings_path())
	var previous: String = storage.root_path
	storage.root_path = base
	var cfg := ConfigFile.new()
	cfg.set_value("serial", "port", "COM7")
	assert(cfg.save(base + "device.cfg") == OK)
	assert(storage.device_port() == "COM7")
	cfg.set_value("serial", "port", "COM12")
	cfg.save(base + "device.cfg")
	assert(storage.device_port() == "COM12")
	storage.root_path = previous
	assert(not ResourceLoader.exists("res://scenes/ConnectScene.tscn"))
	assert(ProjectSettings.get_setting("application/config/version") == "1.0.0")
	print("STORAGE: 14 checks passed")
	quit()
