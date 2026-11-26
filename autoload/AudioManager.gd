extends Node

const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"
const SFX_VOICES := 8
const FADE_OUT_DB := -36.0

var _music: AudioStreamPlayer
var _sfx_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _loop_music := true
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = BGM_BUS
	_music.finished.connect(_on_music_finished)
	add_child(_music)

	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % i
		voice.bus = SFX_BUS
		add_child(voice)
		_sfx_voices.append(voice)

	set_bus_volume(BGM_BUS, float(SaveManager.get_setting("bgm_volume", 1.0)))
	set_bus_volume(SFX_BUS, float(SaveManager.get_setting("sfx_volume", 1.0)))

func play_music(stream: AudioStream, fade_seconds: float = 0.25, loop: bool = true) -> void:
	if stream == null:
		return
	_loop_music = loop
	if _music.stream == stream and _music.playing:
		return
	_kill_music_tween()
	_music.stream = stream
	if fade_seconds > 0.0:
		_music.volume_db = FADE_OUT_DB
		_music.play()
		_music_tween = create_tween()
		_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_music_tween.tween_property(_music, "volume_db", 0.0, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_music.volume_db = 0.0
		_music.play()

func play_music_path(path: String, fade_seconds: float = 0.25, loop: bool = true) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	play_music(stream, fade_seconds, loop)

func stop_music(fade_seconds: float = 0.0) -> void:
	_loop_music = false
	_kill_music_tween()
	if not _music.playing:
		return
	if fade_seconds > 0.0:
		_music_tween = create_tween()
		_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_music_tween.tween_property(_music, "volume_db", FADE_OUT_DB, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.tween_callback(func() -> void:
			_music.stop()
			_music.volume_db = 0.0
		)
	else:
		_music.stop()
		_music.volume_db = 0.0

func _on_music_finished() -> void:
	if _loop_music and _music.stream != null:
		_music.play()

func _kill_music_tween() -> void:
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null

func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null or _sfx_voices.is_empty():
		return
	var voice := _sfx_voices[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_voices.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.play()

func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("AudioManager: no audio bus named '%s' (check default_bus_layout.tres)." % bus_name)
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(bus, is_zero_approx(linear))
	if linear > 0.0:
		AudioServer.set_bus_volume_linear(bus, linear)

func set_bgm_volume(linear: float) -> void:
	set_bus_volume(BGM_BUS, linear)
	SaveManager.set_setting("bgm_volume", clampf(linear, 0.0, 1.0))

func set_sfx_volume(linear: float) -> void:
	set_bus_volume(SFX_BUS, linear)
	SaveManager.set_setting("sfx_volume", clampf(linear, 0.0, 1.0))
