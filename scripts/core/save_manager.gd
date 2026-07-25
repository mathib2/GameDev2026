extends Node

## Settings and lifetime stats on disk. Autoload: SaveManager
##
## A ConfigFile in user:// — volumes persist across sessions, and the run
## record (best floor, lifetime kills, victories) survives for the main
## menu to brag about.

const PATH := "user://stuffed.cfg"

var best_floor: int = 0        ## deepest floor reached, 1-based
var lifetime_kills: int = 0
var runs: int = 0
var victories: int = 0

var _recorded: bool = false    ## guards double-counting a run's end


func _ready() -> void:
	_load()
	AudioManager.set_sfx_volume_db(AudioManager.sfx_volume_db)
	AudioManager.set_music_volume_db(AudioManager.music_volume_db)
	EventBus.run_started.connect(func() -> void: _recorded = false)
	EventBus.player_died.connect(func() -> void: _record_run(false))
	EventBus.run_ended.connect(func(victory: bool) -> void: _record_run(victory))


func _record_run(victory: bool) -> void:
	if _recorded:
		return
	_recorded = true
	runs += 1
	lifetime_kills += GameState.kills
	best_floor = maxi(best_floor, GameState.floor_index + 1)
	if victory:
		victories += 1
	save()


func set_sfx_volume_db(db: float) -> void:
	AudioManager.set_sfx_volume_db(db)
	save()


func set_music_volume_db(db: float) -> void:
	AudioManager.set_music_volume_db(db)
	save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	AudioManager.sfx_volume_db = cfg.get_value("audio", "sfx_db", AudioManager.sfx_volume_db)
	AudioManager.music_volume_db = cfg.get_value("audio", "music_db", AudioManager.music_volume_db)
	best_floor = cfg.get_value("meta", "best_floor", 0)
	lifetime_kills = cfg.get_value("meta", "lifetime_kills", 0)
	runs = cfg.get_value("meta", "runs", 0)
	victories = cfg.get_value("meta", "victories", 0)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_db", AudioManager.sfx_volume_db)
	cfg.set_value("audio", "music_db", AudioManager.music_volume_db)
	cfg.set_value("meta", "best_floor", best_floor)
	cfg.set_value("meta", "lifetime_kills", lifetime_kills)
	cfg.set_value("meta", "runs", runs)
	cfg.set_value("meta", "victories", victories)
	cfg.save(PATH)
