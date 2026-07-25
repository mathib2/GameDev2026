extends CharacterBody2D

## Every toy in the game. One scene, one script, behaviour selected by data.
##
## A new enemy is a .tres plus a spritesheet — see docs/ADDING_CONTENT.md.
## Add a new *movement pattern* by adding a case to _think(); do not add a new
## scene per enemy.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")

@export var data: EnemyData

var health: float = 6.0
var is_dead: bool = false
var player: Node2D = null

var _cooldown: float = 0.0
var _state_timer: float = 0.0
var _phase: StringName = &"idle"
var _dir: Vector2 = Vector2.RIGHT
var _knockback: Vector2 = Vector2.ZERO
var _hurt_flash: float = 0.0
var _idle_noise: float = 0.0
var _home: Vector2
var _charge_dir: Vector2 = Vector2.RIGHT
var _hop_vel: Vector2 = Vector2.ZERO
var _telegraph: Line2D = null
## Champion variants (set by the room): tinted, tougher, always pay out.
var champion: bool = false

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_hit: AudioStream = preload("res://assets/audio/sfx/enemy_hit.wav")
var sfx_die: AudioStream = preload("res://assets/audio/sfx/enemy_death.wav")


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_cooldown = randf() * 1.5
	_idle_noise = randf_range(3.0, 9.0)
	_dir = Vector2.from_angle(randf() * TAU)

	if data == null:
		push_warning("[Enemy] %s has no EnemyData" % name)
		return
	health = data.max_health
	if data.spritesheet != null:
		anim.texture = data.spritesheet
	if not data.animations.is_empty():
		anim.animations = data.animations.duplicate(true)
	anim.position = data.sprite_offset
	var shape: Shape2D = $CollisionShape2D.shape
	if shape is CircleShape2D:
		(shape as CircleShape2D).radius = data.hit_radius
	var hurt: Shape2D = $HurtBox/CollisionShape2D.shape
	if hurt is CircleShape2D:
		(hurt as CircleShape2D).radius = data.hit_radius + 2.0


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	if data == null:
		return
	if player == null or not is_instance_valid(player):
		var ps := get_tree().get_nodes_in_group("player")
		player = ps[0] if not ps.is_empty() else null

	if _cooldown > 0.0: _cooldown -= delta
	if _state_timer > 0.0: _state_timer -= delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		anim.modulate = Color(6, 6, 6) if _hurt_flash > 0.0 else Color.WHITE

	_idle_noise -= delta
	if _idle_noise <= 0.0:
		_idle_noise = randf_range(4.0, 11.0)
		if data.sfx_idle != null and randf() < data.idle_sound_chance:
			AudioManager.play_sfx(data.sfx_idle, 0.15, -6.0)

	_think(delta)

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_touch_player()
	_update_anim()


func _think(delta: float) -> void:
	var to_player := Vector2.ZERO
	var dist := 99999.0
	if player != null:
		to_player = player.global_position - global_position
		dist = to_player.length()
	var dir := to_player.normalized()
	var spd := data.move_speed

	match data.behaviour:
		EnemyData.Behaviour.CHASER:
			velocity = dir * spd

		EnemyData.Behaviour.SPRINTER:
			# bursts then twitches — reads as manic
			if _state_timer <= 0.0:
				if _phase == &"run":
					_phase = &"idle"; _state_timer = randf_range(0.3, 0.7)
				else:
					_phase = &"run"; _state_timer = randf_range(0.7, 1.5)
			velocity = dir * spd * 1.55 if _phase == &"run" else velocity * 0.85

		EnemyData.Behaviour.WANDERER:
			if _state_timer <= 0.0:
				_state_timer = randf_range(0.7, 1.6)
				_dir = Vector2.from_angle(randf() * TAU)
			# drifts, but cheats slightly toward the player so it is not useless
			velocity = (_dir * 0.75 + dir * 0.25).normalized() * spd

		EnemyData.Behaviour.SHOOTER:
			# marches to a preferred range and fires
			if dist > data.attack_range:
				velocity = dir * spd
			elif dist < data.attack_range * 0.55:
				velocity = -dir * spd * 0.7
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			if _cooldown <= 0.0 and dist < data.attack_range * 1.1:
				_cooldown = data.attack_cooldown
				_fire_spread(dir, 1, 0.0)
				_attack_anim()

		EnemyData.Behaviour.SHOCKWAVE:
			velocity = Vector2.ZERO
			if _cooldown <= 0.0:
				_cooldown = data.attack_cooldown
				_fire_ring(data.projectile_count)
				_attack_anim()
				EventBus.screen_shake.emit(2.5, 0.2)

		EnemyData.Behaviour.HOPPER:
			if _state_timer <= 0.0:
				_state_timer = data.attack_cooldown
				_hop_vel = dir * spd * 3.2
				_attack_anim()
			velocity = _hop_vel
			_hop_vel = _hop_vel.move_toward(Vector2.ZERO, spd * 4.0 * delta)

		EnemyData.Behaviour.PATROL:
			# bounces off walls in a straight line; nudges toward you up close
			if _dir == Vector2.ZERO:
				_dir = Vector2.RIGHT
			if dist < 90.0:
				_dir = _dir.lerp(dir, 0.03).normalized()
			velocity = _dir * spd
			if is_on_wall():
				var n := get_wall_normal()
				_dir = _dir.bounce(n).normalized()

		EnemyData.Behaviour.CREEPER:
			# never stops, never hurries
			velocity = velocity.move_toward(dir * spd, 40.0 * delta)

		EnemyData.Behaviour.CHARGER:
			match _phase:
				&"idle":
					velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
					if _cooldown <= 0.0 and dist < data.attack_range:
						_phase = &"wind"
						_state_timer = data.telegraph_time
						_charge_dir = dir
						_attack_anim()
				&"wind":
					velocity = -_charge_dir * 24.0     # pulls back before launching
					_charge_dir = _charge_dir.lerp(dir, 0.04).normalized()
					_show_charge_telegraph(true)
					if _state_timer <= 0.0:
						_phase = &"charge"
						_state_timer = 0.85
						_show_charge_telegraph(false)
						AudioManager.play_sfx(data.sfx_attack, 0.1)
				&"charge":
					velocity = _charge_dir * spd * 4.2
					if is_on_wall() or _state_timer <= 0.0:
						_phase = &"idle"
						_cooldown = data.attack_cooldown
						EventBus.screen_shake.emit(4.0, 0.2)
				_:
					_phase = &"idle"

		EnemyData.Behaviour.BUILDER:
			velocity = Vector2.ZERO
			if _cooldown <= 0.0 and dist < data.attack_range:
				_cooldown = data.attack_cooldown
				_fire_spread(dir, 3, 40.0)
				_attack_anim()


## A faint lane along the charge direction so the toy car reads before
## it commits. Created lazily, reused, hidden outside the wind-up.
func _show_charge_telegraph(show: bool) -> void:
	if show:
		if _telegraph == null:
			_telegraph = Line2D.new()
			_telegraph.width = 3.0
			_telegraph.default_color = Color(1.0, 0.35, 0.3, 0.35)
			_telegraph.z_index = -1
			add_child(_telegraph)
		_telegraph.points = PackedVector2Array([Vector2.ZERO, _charge_dir * 130.0])
		_telegraph.visible = true
	elif _telegraph != null:
		_telegraph.visible = false


func _fire_spread(dir: Vector2, count: int, spread_deg: float) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	for i in count:
		var off := 0.0
		if count > 1:
			off = deg_to_rad(lerp(-spread_deg * 0.5, spread_deg * 0.5, float(i) / float(count - 1)))
		_spawn_shot(dir.rotated(off))
	AudioManager.play_sfx(data.sfx_attack, 0.12)


func _fire_ring(count: int) -> void:
	var base := randf() * TAU
	for i in count:
		_spawn_shot(Vector2.from_angle(base + TAU * float(i) / float(maxi(1, count))))
	AudioManager.play_sfx(data.sfx_attack, 0.12)


func _spawn_shot(dir: Vector2) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 10.0
	p.setup(null, dir * data.projectile_speed, float(data.projectile_damage),
		false, 460.0, 0, false)


func _attack_anim() -> void:
	if anim.has(&"attack"):
		anim.play(&"attack", true)


func _touch_player() -> void:
	if player == null or is_dead or data.contact_damage <= 0:
		return
	var r := data.hit_radius + 12.0
	if global_position.distance_to(player.global_position) < r:
		if player.has_method("take_damage"):
			player.take_damage(data.contact_damage, global_position)


func _update_anim() -> void:
	if is_dead:
		return
	if anim.current == &"attack" and not anim.is_finished():
		return
	# let one-shot reactions finish instead of stomping them next frame
	if anim.current == &"hurt" and not anim.is_finished():
		return
	if anim.current == &"attack" and not anim.is_finished():
		return
	if velocity.length() > 8.0:
		anim.play(&"walk")
		if absf(velocity.x) > 1.0:
			anim.flip_h = velocity.x < 0.0
	else:
		anim.play(&"idle")


## Called by the player's melee and by friendly projectiles.
func take_damage(amount: float, from: Vector2 = Vector2.ZERO,
		crit: bool = false, knockback: float = 150.0) -> void:
	if is_dead:
		return
	health -= amount
	_hurt_flash = 0.09
	anim.play(&"hurt", true)
	AudioManager.play_sfx(data.sfx_hurt if data != null and data.sfx_hurt else sfx_hit, 0.12)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	Effects.spawn_burst(get_parent(), global_position, Color(0.87, 0.82, 0.7), 5, 70.0, 2.0)
	if from != Vector2.ZERO:
		var push := (global_position - from).normalized() * knockback
		_knockback += push * (1.0 - clampf(data.knockback_resist, 0.0, 0.95))
	if health <= 0.0:
		_die()


func knockback_from(from: Vector2, force: float) -> void:
	_knockback += (global_position - from).normalized() * force


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	anim.play(&"death", true)
	AudioManager.play_sfx(data.sfx_death if data != null and data.sfx_death else sfx_die, 0.14)
	Effects.spawn_burst(get_parent(), global_position, Color(0.9, 0.85, 0.72), 16, 130.0, 3.0)
	EventBus.screen_shake.emit(2.0, 0.15)
	GameState.kills += 1
	EventBus.enemy_died.emit(self)
	_drop_loot()
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _drop_loot() -> void:
	var room := get_parent()
	if room == null or not room.has_method("spawn_pickup"):
		return
	if champion:
		room.spawn_pickup("coin", global_position + Vector2(6, 0))
	if randf() < data.heart_chance:
		room.spawn_pickup("heart", global_position)
	elif randf() < data.coin_chance:
		room.spawn_pickup("coin", global_position)
