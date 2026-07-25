extends Area2D

## Hearts and coins. Bobs, gets vacuumed toward the player when close.

@export var kind: String = "coin"

const HEART_TEX := preload("res://assets/items/pickup_heart.png")
const COIN_TEX := preload("res://assets/items/pickup_coin.png")

var _t: float = 0.0
var _base_y: float = 0.0
var _taken: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_base_y = position.y
	_t = randf() * TAU
	_sprite.texture = HEART_TEX if kind == "heart" else COIN_TEX
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta * 4.0
	_sprite.position.y = sin(_t) * 2.5
	if _taken:
		return
	# magnet
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p: Node2D = ps[0]
	var d := global_position.distance_to(p.global_position)
	if d < 52.0:
		global_position = global_position.lerp(p.global_position, delta * 7.0)


func _on_body(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	if kind == "heart":
		if GameState.health >= GameState.max_health():
			return
		GameState.heal(2)
		AudioManager.play_sfx(preload("res://assets/audio/sfx/pickup_heart.wav"))
	else:
		GameState.add_coins(1)
		AudioManager.play_sfx(preload("res://assets/audio/sfx/pickup_coin.wav"))
	_taken = true
	Effects.spawn_burst(get_parent(), global_position,
		Color(0.9, 0.3, 0.3) if kind == "heart" else Color(1, 0.85, 0.3), 8, 70.0, 2.0)
	queue_free()
