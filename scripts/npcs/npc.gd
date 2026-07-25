extends Interactable

## A data-driven NPC. One scene, any number of characters.
##
## To add an NPC: create an NPCData .tres, drop NPC.tscn into a map, assign the
## resource in the inspector. No scripts change, and two people adding two NPCs
## to two different maps cannot conflict.

@export var data: NPCData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

var _home: Vector2
var _wander_target: Vector2
var _wander_timer: float = 0.0
var _patrol_index: int = 0
var _talking: bool = false


func _ready() -> void:
	super._ready()
	_home = global_position
	_wander_target = _home
	add_to_group("npc")

	if data == null:
		push_warning("[NPC] %s has no NPCData assigned" % name)
		return

	prompt = data.interact_prompt
	if data.sprite_frames != null:
		_anim.sprite_frames = data.sprite_frames
		_anim.visible = true
		_sprite.visible = false
		if data.sprite_frames.has_animation("idle"):
			_anim.play("idle")
	elif data.sprite != null:
		_sprite.texture = data.sprite
	_sprite.scale = data.sprite_scale

	EventBus.dialogue_finished.connect(_on_dialogue_finished)


func _process(delta: float) -> void:
	if data == null or _talking:
		return
	match data.behaviour:
		NPCData.Behaviour.WANDER:
			_do_wander(delta)
		NPCData.Behaviour.PATROL:
			_do_patrol(delta)
		_:
			pass


func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.5, 4.0)
		var angle := randf() * TAU
		_wander_target = _home + Vector2(cos(angle), sin(angle)) * randf() * data.wander_radius
	global_position = global_position.move_toward(_wander_target, data.move_speed * 0.4 * delta)


func _do_patrol(delta: float) -> void:
	if data.patrol_points.is_empty():
		return
	var target: Vector2 = _home + data.patrol_points[_patrol_index]
	global_position = global_position.move_toward(target, data.move_speed * 0.5 * delta)
	if global_position.distance_to(target) < 2.0:
		_patrol_index = (_patrol_index + 1) % data.patrol_points.size()


func get_prompt() -> String:
	if data == null:
		return prompt
	return "Trade" if data.is_shopkeeper else data.interact_prompt


func interact() -> void:
	if data == null:
		return
	if data.is_shopkeeper:
		EventBus.shop_opened.emit(data)
		return
	var dialogue := data.pick_dialogue()
	if dialogue == null:
		EventBus.toast_requested.emit("%s has nothing to say." % data.display_name)
		return
	_talking = true
	if data.faces_player_when_talking:
		_face_player()
	DialogueManager.start(dialogue)


func _face_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node2D = players[0]
	var facing_left: bool = p.global_position.x < global_position.x
	_sprite.flip_h = facing_left
	if _anim.visible:
		_anim.flip_h = facing_left


func _on_dialogue_finished(_id: StringName) -> void:
	_talking = false
