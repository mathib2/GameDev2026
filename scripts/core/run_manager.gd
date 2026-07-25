extends Node

## Owns a run: floors, rooms, and moving the player between them.
## Autoload: RunManager

const ROOM_SCENE := preload("res://scenes/rooms/Room.tscn")
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")

const FLOOR_NAMES := [
	"THE NURSERY", "THE PLAYROOM", "THE ATTIC", "THE TOY FACTORY",
]

var generator: FloorGenerator
var current_info                       ## FloorGenerator.RoomInfo
var current_room: Node2D
var player: Node2D

var world: Node = null                 ## set by Main
var _rng := RandomNumberGenerator.new()
var _travelling: bool = false
var _run_active: bool = false

var music_game: AudioStream = preload("res://assets/audio/music/16. Feral Amalgamation.wav")
var music_boss: AudioStream = preload("res://assets/audio/music/04. The Filthy Mind (ft. SixteenInMono).wav")
var sfx_door: AudioStream = preload("res://assets/audio/sfx/door_open.wav")
var sfx_descend: AudioStream = preload("res://assets/audio/sfx/floor_descend.wav")


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_ended.connect(func(_victory: bool) -> void: _run_active = false)
	EventBus.player_died.connect(func() -> void: _run_active = false)
	EventBus.item_collected.connect(_on_item_collected)


func _on_item_collected(item: ItemData) -> void:
	if item.companion_scene == "" or world == null or player == null:
		return
	var companion := (load(item.companion_scene) as PackedScene).instantiate()
	world.add_child(companion)
	companion.global_position = player.global_position + Vector2(-20, -8)


func _process(delta: float) -> void:
	# The victory screen shows run_time; someone has to actually tick it.
	# Pausing stops this automatically (default pausable process mode).
	if _run_active:
		GameState.run_time += delta


func start_run() -> void:
	GameState.reset()
	GameFeel.reset()
	var fists := ContentDB.get_weapon(&"fists")
	if fists != null:
		GameState.equip(fists)
	_rng.randomize()
	_run_active = true
	EventBus.run_started.emit()
	_enter_floor(0)
	_place_starter_weapon()


## Puts one gun on a pedestal in the room the run starts in.
##
## The run begins with fists, and every other weapon was gated behind a
## treasure room, a boss payout or a gold chest — so a short session could end
## having never learned that ranged weapons exist at all. This teaches the
## pedestal and the gun inside ten seconds.
##
## It lives here rather than in Room.populate() because FloorGenerator marks the
## start room `spawned = true` up front, so populate() returns early for it and
## any spawn case added there is silently dead code.
func _place_starter_weapon() -> void:
	if current_room == null or not is_instance_valid(current_room):
		return
	if not current_room.has_method("_spawn_weapon_pedestal"):
		return
	current_room._spawn_weapon_pedestal(
		Vector2(current_room.W * 0.5, current_room.H * 0.5 - 62))


func _enter_floor(index: int) -> void:
	GameState.floor_index = index
	generator = FloorGenerator.new()
	generator.generate(index, _rng)
	current_info = generator.start_room
	current_info.visited = true
	_load_room(current_info, "")
	AudioManager.play_music(music_game)
	EventBus.floor_entered.emit(index, floor_name())
	EventBus.toast.emit(floor_name(), Color(1, 0.85, 0.4))


func floor_name() -> String:
	var i := GameState.floor_index
	return FLOOR_NAMES[i] if i < FLOOR_NAMES.size() else "SUB-BASEMENT %d" % (i - 2)


func total_floors() -> int:
	return FLOOR_NAMES.size()


func _load_room(info, from_dir: String) -> void:
	if current_room != null and is_instance_valid(current_room):
		current_room.queue_free()
	current_room = ROOM_SCENE.instantiate()
	world.add_child(current_room)
	current_room.build(info)

	if player == null or not is_instance_valid(player):
		player = PLAYER_SCENE.instantiate()
		world.add_child(player)
	else:
		# keep the player alive across rooms; just move them
		if player.get_parent() != world:
			player.get_parent().remove_child(player)
			world.add_child(player)
	player.global_position = current_room.entry_point(from_dir)
	player.velocity = Vector2.ZERO
	_apply_camera_limits()

	current_room.populate(GameState.floor_index)
	info.visited = true
	EventBus.room_entered.emit(current_room)
	EventBus.minimap_dirty.emit()

	if info.kind == FloorGenerator.RoomKind.BOSS:
		AudioManager.play_music(music_boss)
	elif AudioManager._current_music != music_game:
		AudioManager.play_music(music_game)


func _apply_camera_limits() -> void:
	if player == null:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var r: Rect2 = current_room.room_rect()
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.position.x + r.size.x)
	cam.limit_bottom = int(r.position.y + r.size.y)
	cam.reset_smoothing()


## Called by a room's door trigger.
func travel(dir: String) -> void:
	if _travelling or current_info == null:
		return
	var next = generator.neighbour(current_info, dir)
	if next == null:
		return
	# Set the lock synchronously: door triggers poll every physics frame, so a
	# deferred build would otherwise be queued several times before it runs.
	_travelling = true
	AudioManager.play_sfx(sfx_door)
	current_info = next
	_finish_travel.call_deferred(next, dir)


## Building a room registers hundreds of wall, crate and enemy collision
## shapes. Doors poll from _physics_process and the exit portal fires from
## body_entered, so a direct call does all of that inside a physics flush and
## Godot rejects every single one with "Can't change this state while flushing
## queries". Bouncing to idle once fixes the whole class of error.
func _finish_travel(next, dir: String) -> void:
	_load_room(next, dir)
	# brief lock so you cannot immediately re-trigger the door you arrived at
	await get_tree().create_timer(0.25).timeout
	_travelling = false


func _on_enemy_died(_e: Node) -> void:
	if current_room != null and is_instance_valid(current_room):
		current_room._on_enemy_died()


func _on_boss_defeated(_b: Node) -> void:
	if current_room != null and is_instance_valid(current_room):
		current_room.mark_cleared()
		spawn_exit()


## Public: the room calls this when a cleared boss room is re-entered,
## because the portal dies with the room instance on travel — without the
## respawn the run soft-locks.
func spawn_exit() -> void:
	var exit := Area2D.new()
	exit.collision_layer = 0
	exit.collision_mask = 2
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	exit.add_child(col)

	var s := Sprite2D.new()
	s.texture = preload("res://assets/effects/fx_impact.png")
	s.hframes = 4
	s.frame = 1
	s.scale = Vector2(2.6, 2.6)
	s.modulate = Color(1, 0.85, 0.3)
	exit.add_child(s)

	exit.position = Vector2(current_room.W * 0.5, current_room.H * 0.5)
	# reached from boss_defeated, which fires mid-physics — see _finish_travel
	current_room.add_child.call_deferred(exit)
	exit.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_descend())
	EventBus.toast.emit("THE WAY DOWN OPENS", Color(1, 0.9, 0.5))


func _descend() -> void:
	if _travelling:
		return
	_travelling = true
	AudioManager.play_sfx(sfx_descend)
	var next := GameState.floor_index + 1
	if next >= total_floors():
		EventBus.run_ended.emit(true)
		_travelling = false
		return
	# same reason as _finish_travel: this arrives from the portal's body_entered
	_finish_descend.call_deferred(next)


func _finish_descend(next: int) -> void:
	_enter_floor(next)
	await get_tree().create_timer(0.3).timeout
	_travelling = false


func end_run(victory: bool) -> void:
	EventBus.run_ended.emit(victory)
