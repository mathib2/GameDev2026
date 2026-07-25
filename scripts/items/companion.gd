extends Node2D

## The Tiny Teddy Bear: a defected toy that trots after the player and
## plinks at the nearest enemy. Spawned by RunManager when an item with
## a companion_scene is collected; despawns when a new run starts.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")

const FOLLOW_OFFSET := Vector2(-20.0, -8.0)
const FIRE_COOLDOWN := 1.15
const FIRE_RANGE := 230.0
const BASE_DAMAGE := 1.5

var _cd: float = 0.6

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_shot: AudioStream = preload("res://assets/audio/sfx/teddy_squeak.wav")


func _ready() -> void:
	add_to_group("companion")
	EventBus.run_started.connect(func() -> void: queue_free())


func _physics_process(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	var target: Vector2 = player.global_position + FOLLOW_OFFSET
	var dist := global_position.distance_to(target)
	if dist > 300.0:
		global_position = target       # teleport when left behind on room change
	else:
		global_position = global_position.lerp(target, minf(1.0, 6.0 * delta))
	anim.play(&"walk" if dist > 6.0 else &"idle")
	anim.flip_h = target.x < global_position.x

	_cd -= delta
	if _cd <= 0.0:
		_try_shoot()


func _player() -> Node2D:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] if not ps.is_empty() else null


func _try_shoot() -> void:
	var best: Node2D = null
	var best_d := FIRE_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	_cd = FIRE_COOLDOWN
	anim.play(&"attack", true)
	AudioManager.play_sfx(sfx_shot, 0.2, -10.0)
	var dir := (best.global_position - global_position).normalized()
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 12.0
	p.setup(null, dir * 300.0, BASE_DAMAGE * GameState.stat("damage_mult"),
		true, 320.0, 0, false)
