extends RefCounted
## The native manager documents write() as thread-safe. Only byte writes run here;
## scene access, packet parsing and signals stay on the main thread.
const MAX_PENDING := 128
var _thread := Thread.new()
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _pending: Array[PackedByteArray] = []
var _heartbeat := PackedByteArray()
var _stopping := false
var _failed := false
var _peak_ms := 0.0
var _manager
var _port := ""

func start(manager, port: String) -> Error:
	_manager = manager
	_port = port
	return _thread.start(_run)

func enqueue(packet: PackedByteArray, heartbeat: bool = false) -> bool:
	_mutex.lock()
	var accepted := not _stopping and not _failed
	if accepted:
		if heartbeat:
			_heartbeat = packet
		elif _pending.size() < MAX_PENDING:
			_pending.append(packet)
		else:
			_failed = true
			accepted = false
	_mutex.unlock()
	if accepted: _wake.post()
	return accepted

func status() -> Vector2:
	_mutex.lock()
	var result := Vector2(_peak_ms, 1.0 if _failed else 0.0)
	_peak_ms = 0.0
	_mutex.unlock()
	return result

func stop() -> void:
	_mutex.lock()
	_stopping = true
	_pending.clear()
	_heartbeat.clear()
	_mutex.unlock()
	_wake.post()
	if _thread.is_started(): _thread.wait_to_finish()

func _run() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		if _stopping or _failed:
			_mutex.unlock()
			return
		var bytes := PackedByteArray()
		# Preserve command order and checksum framing, with one native flush per batch.
		for packet in _pending: bytes.append_array(packet)
		_pending.clear()
		bytes.append_array(_heartbeat)
		_heartbeat.clear()
		_mutex.unlock()
		if bytes.is_empty(): continue
		var started := Time.get_ticks_usec()
		var ok: bool = _manager.write(_port, bytes)
		var duration := float(Time.get_ticks_usec() - started) / 1000.0
		_mutex.lock()
		_peak_ms = maxf(_peak_ms, duration)
		_failed = not ok
		_mutex.unlock()
		if not ok: return
