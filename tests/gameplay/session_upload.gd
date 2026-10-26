extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var listener := TCPServer.new()
	assert(listener.listen(19879, "127.0.0.1") == OK)
	var folder := "user://test-storage/native-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var source := folder.path_join("sessions.csv")
	var f := FileAccess.open(source, FileAccess.WRITE)
	f.store_string("synthetic session")
	f.close()
	var upload = load("res://scripts/network/session_upload.gd").new()
	root.add_child(upload)
	upload.setup(folder, {"server_host":"127.0.0.1", "server_port":19879, "client_id":"TEST"})
	upload.held_patient = "TEST_UPLOAD"
	upload.retry_seconds = 0.1
	assert(upload.enqueue("TEST_UPLOAD", source))
	assert(upload.enqueue("TEST_UPLOAD", source, "configdata.csv"))
	var connection: StreamPeerTCP
	var bytes := PackedByteArray()
	var attempts := 0
	var limit := Time.get_ticks_msec() + 10000
	while upload.confirmed < 2 and Time.get_ticks_msec() < limit:
		await process_frame
		if listener.is_connection_available():
			connection = listener.take_connection()
			bytes.clear()
			attempts += 1
		if connection == null: continue
		connection.poll()
		if connection.get_available_bytes() > 0: bytes.append_array(connection.get_data(connection.get_available_bytes())[1])
		if bytes.size() < 4: continue
		var buffer := StreamPeerBuffer.new()
		buffer.big_endian = true
		buffer.data_array = bytes
		var size := buffer.get_u32()
		if bytes.size() < size + 4: continue
		var header = JSON.parse_string(bytes.slice(4, size+4).get_string_from_utf8())
		if bytes.size() < size + 4 + header.file_size: continue
		assert(header.filename == ("configdata.csv" if attempts == 3 else "sessions.csv"))
		assert(bytes.slice(size+4).get_string_from_utf8() == "synthetic session")
		if attempts == 1: connection.disconnect_from_host()
		else: connection.put_data('{"success":true}'.to_utf8_buffer())
		connection = null
	assert(upload.confirmed == 2 and attempts == 3)
	assert(DirAccess.get_files_at(upload.directory) == PackedStringArray(["last-upload.json"]))
	assert(FileAccess.get_file_as_string(source) == "synthetic session")
	upload.queue_free()
	listener.stop()
	await process_frame
	print("NATIVE UPLOAD: retry, acknowledgement and source preservation passed")
	quit()
