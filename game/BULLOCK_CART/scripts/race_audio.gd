extends Node
## Local audio assets only. No network, external process, or speech service at runtime.
var music: AudioStreamPlayer
var crowd: AudioStreamPlayer
var voice: AudioStreamPlayer
var cheer: AudioStreamPlayer
var effect: AudioStreamPlayer
var music_level := 0.55
var crowd_level := 0.65
var effects_level := 0.65
var speech_cooldown := 0.0
var is_paused := false
var race_active := false
var voices: Dictionary = {}
const SETTINGS := "user://bullock-audio.cfg"
const BGM_TRACKS = [
	preload("res://game/BULLOCK_CART/assets/audio/bgm1.mp3"),
	preload("res://game/BULLOCK_CART/assets/audio/bgm2.mp3"),
]
var music_index := 0
var races_started := 0

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		music_level = clampf(float(config.get_value("audio", "music", music_level)), 0, 1)
		crowd_level = clampf(float(config.get_value("audio", "crowd", crowd_level)), 0, 1)
		effects_level = clampf(float(config.get_value("audio", "effects", effects_level)), 0, 1)
	music = _player(BGM_TRACKS[0])
	# Individual tracks must end so the playlist can advance.
	music.stream.loop = false
	music.finished.connect(_next_music)
	crowd = _player(preload("res://game/BULLOCK_CART/assets/audio/crowd-bed.ogg"), true)
	cheer = _player(preload("res://game/BULLOCK_CART/assets/audio/crowd-cheer.ogg"))
	voice = _player(null)
	effect = _player(_chime())
	voices = {
		"collect": preload("res://game/BULLOCK_CART/assets/audio/tamil-collect.mp3"),
		"streak": preload("res://game/BULLOCK_CART/assets/audio/tamil-streak.mp3"),
		"overtake": preload("res://game/BULLOCK_CART/assets/audio/tamil-overtake.mp3"),
		"finish": preload("res://game/BULLOCK_CART/assets/audio/tamil-finish.mp3")}
	_update_levels()
	music.play()
	sync_music_mute()

func _next_music() -> void:
	music_index = (music_index + 1) % BGM_TRACKS.size()
	music.stream = BGM_TRACKS[music_index].duplicate()
	music.stream.loop = false
	music.play()
	sync_music_mute()

func sync_music_mute() -> void:
	# Pause instead of restarting the song when the music checkbox is toggled.
	music.stream_paused = is_paused or MenuMusic.muted

func _player(stream: AudioStream, loop := false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	if stream:
		player.stream = stream.duplicate()
		if loop: player.stream.loop = true
	add_child(player)
	return player

func _chime() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(15436)
	for i in range(7718):
		var t := float(i) / 22050
		var note := 660.0 if t < .11 else (880.0 if t < .22 else 1100.0)
		var envelope := sin(PI * fposmod(t, .11) / .11) * exp(-t * 5)
		data.encode_s16(i * 2, int(sin(TAU * note * t) * envelope * 9000))
	wav.data = data
	return wav

func start_race() -> void:
	race_active = true
	if races_started > 0: _next_music()
	races_started += 1
	set_paused(false)
	voice.stop()
	cheer.stop()
	speech_cooldown = 0
	if crowd_level > 0: crowd.play()
	if not music.playing: music.play()
	sync_music_mute()

func celebrate(kind: String, force := false) -> bool:
	if is_paused: return false
	if kind in ["collect", "streak", "boost"] and effects_level > 0:
		effect.pitch_scale = 1.15 if kind == "boost" else (1.08 if kind == "streak" else 1.0)
		effect.play()
	if crowd_level <= 0 or (not force and (speech_cooldown > 0 or voice.playing)): return false
	var key := "streak" if kind == "boost" else kind
	if not voices.has(key): return false
	voice.stream = voices[key]
	voice.play()
	if kind != "collect": cheer.play()
	speech_cooldown = 5.0
	return true

func finish_race() -> void:
	race_active = false
	crowd.stop()
	celebrate("finish", true)

func advance(delta: float) -> void:
	if is_paused: return
	speech_cooldown = maxf(0, speech_cooldown - delta)
	# Leave space for intelligible Tamil encouragement.
	var target := _db(music_level, -10) - (7.0 if voice.playing else 0.0)
	music.volume_db = move_toward(music.volume_db, target, delta * 30)

func set_paused(value: bool) -> void:
	is_paused = value
	for player in [music, crowd, voice, cheer, effect]: player.stream_paused = value
	sync_music_mute()

func set_level(channel: String, value: float) -> void:
	value = clampf(value, 0, 1)
	match channel:
		"music": music_level = value
		"crowd": crowd_level = value
		"effects": effects_level = value
	_update_levels()
	if crowd_level > 0 and race_active and not crowd.playing:
		crowd.play()
		crowd.stream_paused = is_paused
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_level)
	config.set_value("audio", "crowd", crowd_level)
	config.set_value("audio", "effects", effects_level)
	config.save(SETTINGS)

func _db(value: float, base: float) -> float:
	return -80.0 if value <= 0 else linear_to_db(value) + base

func _update_levels() -> void:
	music.volume_db = _db(music_level, -10)
	crowd.volume_db = _db(crowd_level, -23)
	cheer.volume_db = _db(crowd_level, -12)
	voice.volume_db = _db(crowd_level, -3)
	effect.volume_db = _db(effects_level, -7)
	if crowd_level <= 0:
		voice.stop()
		cheer.stop()
