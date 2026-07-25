extends Control

## Shared behaviour for the three menu panels. Which one it is comes from
## `mode`, so all three use one script and one set of buttons.

enum Mode { MAIN, PAUSE, GAME_OVER }

@export var mode: Mode = Mode.MAIN

@onready var _title: Label = $Panel/VBox/Title
@onready var _subtitle: Label = $Panel/VBox/Subtitle
@onready var _primary: Button = $Panel/VBox/Primary
@onready var _secondary: Button = $Panel/VBox/Secondary

var sfx_select: AudioStream = preload("res://assets/audio/sfx/ui_select.wav")
var sfx_confirm: AudioStream = preload("res://assets/audio/sfx/ui_confirm.wav")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_primary.pressed.connect(_on_primary)
	_secondary.pressed.connect(_on_secondary)
	for b in [_primary, _secondary]:
		b.mouse_entered.connect(func() -> void: AudioManager.play_sfx(sfx_select, 0.05, -6.0))
	match mode:
		Mode.MAIN:
			_title.text = "STUFFED"
			_subtitle.text = "they were always going to come apart"
			if SaveManager.runs > 0:
				_subtitle.text += "\nbest: floor %d · %d toys torn open lifetime" % [
					SaveManager.best_floor, SaveManager.lifetime_kills]
			_primary.text = "START RUN"
			_secondary.text = "QUIT"
			_add_volume_controls()
		Mode.PAUSE:
			_title.text = "PAUSED"
			_subtitle.text = ""
			_primary.text = "RESUME"
			_secondary.text = "QUIT TO MENU"
			_add_volume_controls()
		Mode.GAME_OVER:
			_primary.text = "RUN IT BACK"
			_secondary.text = "MAIN MENU"


func _add_volume_controls() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	for cfg in [["SFX", AudioManager.sfx_volume_db, true],
			["MUSIC", AudioManager.music_volume_db, false]]:
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = cfg[0]
		lab.custom_minimum_size = Vector2(52, 0)
		row.add_child(lab)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.02
		slider.value = db_to_linear(cfg[1])
		slider.custom_minimum_size = Vector2(140, 16)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var is_sfx: bool = cfg[2]
		slider.value_changed.connect(func(v: float) -> void:
			var db := linear_to_db(maxf(v, 0.001)) if v > 0.0 else -80.0
			if is_sfx:
				SaveManager.set_sfx_volume_db(db)
				AudioManager.play_sfx(sfx_select, 0.05, -6.0)
			else:
				SaveManager.set_music_volume_db(db))
		row.add_child(slider)
		vbox.add_child(row)


func setup(victory: bool) -> void:
	if victory:
		_title.text = "THE TOY BOX IS EMPTY"
		_subtitle.text = "nothing is moving. you sit down.\n%d toys torn open · %d coins · %ds" % [
			GameState.kills, GameState.coins, int(GameState.run_time)]
	else:
		_title.text = "STUFFED"
		_subtitle.text = "they got you in %s\n%d toys torn open · %d coins · %ds" % [
			RunManager.floor_name().to_lower(), GameState.kills, GameState.coins,
			int(GameState.run_time)]


func _on_primary() -> void:
	AudioManager.play_sfx(sfx_confirm)
	var main := get_tree().current_scene
	match mode:
		Mode.MAIN, Mode.GAME_OVER:
			main.start_run()
		Mode.PAUSE:
			main._toggle_pause()


func _on_secondary() -> void:
	AudioManager.play_sfx(sfx_confirm)
	var main := get_tree().current_scene
	match mode:
		Mode.MAIN:
			get_tree().quit()
		Mode.PAUSE, Mode.GAME_OVER:
			main.quit_to_menu()
