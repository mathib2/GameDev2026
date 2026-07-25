extends CharacterBody2D

## The player character in the 2D world.
##
## Owns movement and "what am I looking at". It does not own dialogue, hacking,
## or inventory — it emits an interaction request and the relevant system
## responds. Developer A can retune this file without breaking anyone else.

@export var data: CharacterData
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

var _speed: float = 90.0
var _focused: Interactable = null
var _input_locked: bool = false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2   # "player"
	collision_mask = 1    # collides with "world"

	if data != null:
		_speed = data.move_speed
		if data.sprite_frames != null:
			_anim.sprite_frames = data.sprite_frames
			_anim.visible = true
			_sprite.visible = false
		elif data.sprite != null:
			_sprite.texture = data.sprite
			_sprite.visible = true
			_anim.visible = false
		_sprite.scale = data.sprite_scale

	EventBus.interactable_focused.connect(_on_focus)
	EventBus.interactable_unfocused.connect(_on_unfocus)
	EventBus.dialogue_started.connect(func(_d): _input_locked = true)
	EventBus.dialogue_finished.connect(func(_id): _input_locked = false)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not _input_locked and not HackManager.is_active():
		dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * _speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_update_visuals(dir)


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked or HackManager.is_active():
		return
	if event.is_action_pressed(&"interact") and _focused != null and _focused.is_player_in_range():
		EventBus.interaction_requested.emit(_focused)
		_focused.interact()
		get_viewport().set_input_as_handled()


func _update_visuals(dir: Vector2) -> void:
	if dir.x != 0.0:
		_sprite.flip_h = dir.x < 0.0
		if _anim.visible:
			_anim.flip_h = dir.x < 0.0
	if not _anim.visible:
		return
	var wanted := "walk" if dir != Vector2.ZERO else "idle"
	if _anim.sprite_frames != null and _anim.sprite_frames.has_animation(wanted):
		if _anim.animation != wanted:
			_anim.play(wanted)


func _on_focus(interactable: Node, _prompt: String) -> void:
	if interactable is Interactable:
		_focused = interactable


func _on_unfocus(interactable: Node) -> void:
	if interactable == _focused:
		_focused = null
