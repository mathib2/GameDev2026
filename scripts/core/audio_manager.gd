extends Node

## Sound. Autoload: AudioManager
##
## Pooled SFX players plus a music track with crossfade. Passing null is always
## safe, so content can ship before its audio exists.

const VOICES := 16

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _current_music: AudioStream = null

var sfx_volume_db: float = -4.0
var music_volume_db: float = -12.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the music leans in slightly as a boss loses composure
	EventBus.boss_phase_changed.connect(func(p: int) -> void:
		_music.pitch_scale = 1.0 + 0.05 * float(p - 1))
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume_db
	add_child(_music)
	_music.finished.connect(func() -> void:
		# manual loop; generated WAVs have no loop metadata
		if _music.stream != null:
			_music.play())
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_pool.append(p)


func play_sfx(stream: AudioStream, pitch_variance: float = 0.08, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	p.volume_db = sfx_volume_db + volume_db
	p.play()


func play_music(stream: AudioStream, restart_if_same: bool = false) -> void:
	if stream == _current_music and not restart_if_same:
		return
	_current_music = stream
	if stream == null:
		_music.stop()
		return
	_music.stream = stream
	_music.volume_db = music_volume_db
	_music.pitch_scale = 1.0
	_music.play()


func stop_music() -> void:
	_current_music = null
	_music.stop()


func duck_music(db: float = -18.0) -> void:
	_music.volume_db = db


func restore_music() -> void:
	_music.volume_db = music_volume_db


func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db


func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	if _music != null:
		_music.volume_db = db
