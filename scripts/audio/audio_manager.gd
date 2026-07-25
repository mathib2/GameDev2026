extends Node

## Sound. Autoload: AudioManager
##
## Owns the buses and a small SFX pool. Every other system passes an
## AudioStream that came from a data Resource, so the audio team can swap any
## sound by editing a .tres — no code changes, no merge conflicts.
##
## Passing null is always safe and does nothing. That lets content ship with
## sounds unassigned while audio is still being made.

const SFX_VOICES := 12

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0

var _current_music: AudioStream = null


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -8.0
	add_child(_music)

	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Master"
	_ambience.volume_db = -14.0
	add_child(_ambience)

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)


func play_music(stream: AudioStream) -> void:
	if stream == _current_music:
		return
	_current_music = stream
	if stream == null:
		_music.stop()
		return
	_music.stream = stream
	_music.play()


func play_ambience(stream: AudioStream) -> void:
	if stream == null:
		_ambience.stop()
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.play()


func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


func stop_all() -> void:
	_music.stop()
	_ambience.stop()
	for p in _sfx_pool:
		p.stop()
