extends Node
## Central music/SFX routing (design spec §5.1).
##
## The project deliberately ships no audio files yet, so every call here accepts
## a null or missing stream and quietly does nothing. Drop real streams in and
## the game gets sound without touching this script or any caller.

const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"
const SFX_VOICES := 8

var _music: AudioStreamPlayer
var _sfx_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = BGM_BUS
	add_child(_music)

	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % i
		voice.bus = SFX_BUS
		add_child(voice)
		_sfx_voices.append(voice)

	set_bus_volume(BGM_BUS, float(SaveManager.get_setting("bgm_volume", 1.0)))
	set_bus_volume(SFX_BUS, float(SaveManager.get_setting("sfx_volume", 1.0)))


## Starts looping background music. Re-calling with the same stream is a no-op.
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


## Plays a one-shot effect on the next free voice, so overlaps do not cut each
## other off.
func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null or _sfx_voices.is_empty():
		return
	var voice := _sfx_voices[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_voices.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.play()


## 0.0 mutes the bus instead of pushing it to -inf dB, so it can be restored.
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("AudioManager: no audio bus named '%s' (check default_bus_layout.tres)." % bus_name)
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(bus, is_zero_approx(linear))
	if linear > 0.0:
		AudioServer.set_bus_volume_linear(bus, linear)


## §3.5 Settings: separate sliders for music and effects. Both are persisted.
func set_bgm_volume(linear: float) -> void:
	set_bus_volume(BGM_BUS, linear)
	SaveManager.set_setting("bgm_volume", clampf(linear, 0.0, 1.0))


func set_sfx_volume(linear: float) -> void:
	set_bus_volume(SFX_BUS, linear)
	SaveManager.set_setting("sfx_volume", clampf(linear, 0.0, 1.0))
