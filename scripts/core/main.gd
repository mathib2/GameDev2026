extends Node

## Root scene. Owns a World container, the HUD, and the menu/pause flow.
## Deliberately thin — no gameplay lives here.

@onready var world: Node = $World
@onready var hud: CanvasLayer = $HUD
@onready var menu: Control = $Menus/MainMenu
@onready var pause: Control = $Menus/PauseMenu
@onready var over: Control = $Menus/GameOver

var _running: bool = false
var wiki: CanvasLayer = null    ## the MY STUFF panel; the menu opens it

var music_menu: AudioStream = preload("res://assets/audio/music/09. Treasures Within the Abomination.wav")
var music_victory: AudioStream = preload("res://assets/audio/music/music_victory.wav")
var music_death: AudioStream = preload("res://assets/audio/music/music_death.wav")


func _ready() -> void:
	RunManager.world = world
	# added in code rather than in Main.tscn so the layer ordering against the
	# HUD is stated where it is explained
	add_child(load("res://scripts/ui/vignette.gd").new())
	add_child(load("res://scripts/ui/story.gd").new())
	add_child(load("res://scripts/ui/mod_menu.gd").new())
	wiki = load("res://scripts/ui/wiki.gd").new()
	add_child(wiki)
	hud.visible = false
	pause.visible = false
	over.visible = false
	menu.visible = true
	AudioManager.play_music(music_menu)

	EventBus.player_died.connect(_on_player_died)
	EventBus.run_ended.connect(_on_run_ended)
	get_tree().paused = false

	# --autostart skips the menu. Used by the headless smoke test in CI and by
	# anyone iterating on combat who does not want to click through the menu.
	if OS.get_cmdline_args().has("--autostart"):
		call_deferred("start_run")
	if OS.get_cmdline_args().has("--smoketest"):
		add_child(load("res://scripts/dev/smoke_test.gd").new())
	if OS.get_cmdline_args().has("--walktest"):
		add_child(load("res://scripts/dev/walk_test.gd").new())
	if OS.get_cmdline_args().has("--screenshot"):
		add_child(load("res://scripts/dev/screenshot.gd").new())
	if OS.get_cmdline_args().has("--genaudit"):
		add_child(load("res://scripts/dev/gen_audit.gd").new())


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed(&"pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func start_run(two_player: bool = false) -> void:
	_running = true
	menu.visible = false
	over.visible = false
	hud.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN   # the HUD crosshair takes over
	RunManager.start_run(two_player)


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_HIDDEN
	if p:
		AudioManager.duck_music()
	else:
		AudioManager.restore_music()


func _on_player_died() -> void:
	if not _running:
		return
	_running = false
	AudioManager.play_music(music_death)
	await get_tree().create_timer(1.4).timeout
	_show_over(false)


func _on_run_ended(victory: bool) -> void:
	if not _running:
		return
	_running = false
	AudioManager.play_music(music_victory if victory else music_death)
	await get_tree().create_timer(0.8).timeout
	_show_over(victory)


func _show_over(victory: bool) -> void:
	GameFeel.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	over.visible = true
	over.setup(victory)
	hud.visible = false


func quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_running = false
	for c in world.get_children():
		c.queue_free()
	RunManager.current_room = null
	RunManager.player = null
	RunManager.player2 = null
	over.visible = false
	pause.visible = false
	hud.visible = false
	menu.visible = true
	AudioManager.play_music(music_menu)
