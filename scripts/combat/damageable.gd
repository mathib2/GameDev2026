class_name Damageable
extends Node

## Attach to anything that can be hurt. Keeps damage handling in one place so
## the player, enemies and bosses all take hits identically.

signal damaged(amount: float, from: Vector2, crit: bool)
signal died()

@export var max_health: float = 10.0
@export var invulnerable_time: float = 0.0

var health: float
var _invuln: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	health = max_health


func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta


func can_be_hit() -> bool:
	return not is_dead and _invuln <= 0.0


func apply(amount: float, from: Vector2 = Vector2.ZERO, crit: bool = false) -> bool:
	if not can_be_hit():
		return false
	health -= amount
	_invuln = invulnerable_time
	damaged.emit(amount, from, crit)
	if health <= 0.0:
		health = 0.0
		is_dead = true
		died.emit()
	return true


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)


func fraction() -> float:
	return health / maxf(0.001, max_health)
