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
			_primary.text = "START RUN"
			_secondary.text = "QUIT"
		Mode.PAUSE:
			_title.text = "PAUSED"
			_subtitle.text = ""
			_primary.text = "RESUME"
			_secondary.text = "QUIT TO MENU"
		Mode.GAME_OVER:
			_primary.text = "RUN IT BACK"
			_secondary.text = "MAIN MENU"


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
