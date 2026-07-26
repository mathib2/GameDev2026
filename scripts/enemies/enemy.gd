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
## Fixed per enemy: which way this one arcs when closing. See CHASER.
var _flank: float = 0.0
## Champion variants (set by the room): tinted, tougher, always pay out.
var champion: bool = false
## Anti-corner bookkeeping: where we were last frame, how long we have been
## pushing without getting anywhere, and how long to beeline once unstuck.
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _unstick: float = 0.0

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_hit: AudioStream = preload("res://assets/audio/sfx/enemy_hit.wav")
var sfx_die: AudioStream = preload("res://assets/audio/sfx/enemy_death.wav")


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	# 16 is the pit-edge layer: pits stop toys the way walls do, so a room
	# with a chasm in it cannot quietly delete its own fight. Only the player
	# can fall.
	collision_mask = 1 | 16
	_home = global_position
	_cooldown = randf() * 1.5
	_idle_noise = randf_range(3.0, 9.0)
	_dir = Vector2.from_angle(randf() * TAU)
	# signed so roughly half a pack swings left and half right
	_flank = deg_to_rad(randf_range(28.0, 62.0)) * (1.0 if randf() < 0.5 else -1.0)

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

	# Steering, applied after the archetype has decided where it wants to go.
	# Without it every chaser walks the same straight line to the player and
	# the pack collapses into one stacked blob you can kill with a single
	# sweep — which is most of why fights read as easy. Separation makes them
	# fan out and surround instead.
	if not _holds_position():
		velocity += _separation() * SEPARATION_FORCE

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()
	_clamp_to_room()
	_detect_stuck(delta)
	_touch_player()
	_update_anim()


## The corner detector. A toy that wants to move but has not actually moved
## for half a second is wedged — usually ground into a corner or a crate
## cluster by its own flanking arc. The cure is a short window of walking
## straight at the player, which slides it out along whatever it is pressed
## against. Without this, chasers could park in a corner for a whole fight.
func _detect_stuck(delta: float) -> void:
	if _unstick > 0.0:
		_unstick -= delta
	var wants := velocity.length() > 20.0
	var moved := global_position.distance_to(_last_pos) > 1.2
	_last_pos = global_position
	if wants and not moved and not _holds_position():
		_stuck_time += delta
		if _stuck_time > 0.5:
			_stuck_time = 0.0
			_unstick = 0.5
	else:
		_stuck_time = 0.0


const SEPARATION_RADIUS := 34.0
const SEPARATION_FORCE := 46.0


## Archetypes that are supposed to stand still stay standing still — shoving a
## stationary turret around would break the read that it is a fixed hazard.
func _holds_position() -> bool:
	return data != null and data.behaviour in [
		EnemyData.Behaviour.SHOCKWAVE, EnemyData.Behaviour.BUILDER]


## Average push away from crowded neighbours, strongest when nearly overlapping.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.get("is_dead") == true:
			continue
		var d: Vector2 = global_position - e.global_position
		var dist := d.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			push += (d / dist) * (1.0 - dist / SEPARATION_RADIUS)
			n += 1
	return push / float(n) if n > 0 else Vector2.ZERO


## Where to aim so a shot and a moving player arrive together.
##
## First-order lead: good enough that standing still and strafing predictably
## gets punished, and cheap enough to run on every shooter every volley. The
## 0.75 factor keeps it deliberately imperfect — a perfect predictor is
## unfun, because it removes strafing as a skill instead of testing it.
func _lead_target(shot_speed: float) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.DOWN
	var to: Vector2 = player.global_position - global_position
	var pv: Vector2 = player.get("velocity") if player.get("velocity") != null else Vector2.ZERO
	if shot_speed <= 1.0:
		return to.normalized()
	var t := to.length() / shot_speed
	return (to + pv * t * 0.75).normalized()


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
			# Arc in rather than walking the straight line. The bias is fixed
			# per enemy and unwinds as it closes, so a pack approaches from a
			# spread of angles and converges only at the end — you cannot back
			# up and hold them all off with one arc of swings.
			#
			# The arc turns off against walls and while unsticking: a flanking
			# vector held against a wall slides the toy INTO the nearest corner
			# and pins it there, which read as "the teddies just stand in the
			# corner". Straight-at-the-player always slides back out.
			var bias: float = _flank * clampf(dist / 220.0, 0.0, 1.0)
			if is_on_wall() or _unstick > 0.0:
				bias = 0.0
			velocity = dir.rotated(bias) * spd

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
				_fire_spread(_lead_target(data.projectile_speed), 1, 0.0)
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
				_fire_spread(_lead_target(data.projectile_speed), 3, 40.0)
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
	# a puff of stuffing out of the wound, thrown away from the hit
	Effects.spawn_stuffing(get_parent(), global_position, 6 if crit else 4,
		95.0 if crit else 65.0, 2.0)
	_squash(1.28, 0.78)
	if from != Vector2.ZERO:
		var push := (global_position - from).normalized() * knockback
		_knockback += push * (1.0 - clampf(data.knockback_resist, 0.0, 0.95))
	if health <= 0.0:
		_die()


## Keep enemies inside the room.
##
## Walls are solid, but the doorways are literal gaps in them — so anything
## that wandered into a door lane simply walked out of the room and kept going,
## and the room could never be cleared. Bosses already clamped themselves;
## ordinary enemies did not. Also unsticks anything the separation push has
## wedged into a corner.
func _clamp_to_room() -> void:
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect"):
		return
	var rect: Rect2 = r.room_rect()
	var margin := 26.0 + (data.hit_radius if data != null else 10.0)
	var before := global_position
	global_position.x = clampf(global_position.x, rect.position.x + margin,
		rect.position.x + rect.size.x - margin)
	global_position.y = clampf(global_position.y, rect.position.y + margin,
		rect.position.y + rect.size.y - margin)
	# If we had to pull it back, kill the velocity component that was driving
	# it out — otherwise it grinds against the boundary forever, which is what
	# "stuck in a corner" looks like.
	if not global_position.is_equal_approx(before):
		if not is_equal_approx(global_position.x, before.x):
			velocity.x = 0.0
			_dir.x = -_dir.x
		if not is_equal_approx(global_position.y, before.y):
			velocity.y = 0.0
			_dir.y = -_dir.y


## How far this body extends from its centre, for melee range checks.
func melee_radius() -> float:
	return data.hit_radius if data != null else 10.0


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
	# the toy bursts: a ring to punctuate the kill, then the stuffing it was
	# made of. No red anywhere — these are soft toys, not people.
	Effects.spawn_pop(get_parent(), global_position, 2.2)
	Effects.spawn_stuffing(get_parent(), global_position, 18, 135.0, 3.0)
	EventBus.screen_shake.emit(2.0, 0.15)
	GameState.kills += 1
	EventBus.enemy_died.emit(self)
	_drop_loot()

	# deflate: pop wide, then collapse and sink as the last of it drifts out
	var t := create_tween()
	t.tween_property(anim, "scale", Vector2(1.35, 0.72), 0.10)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(anim, "rotation", randf_range(-0.5, 0.5), 0.55)
	t.tween_property(anim, "scale", Vector2(0.86, 0.5), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	t.tween_callback(queue_free)


## Quick non-uniform scale punch on the sprite, snapping back. Sells a hit
## landing without touching the body's own scale, which elites and champions
## already use to look bigger.
func _squash(sx: float, sy: float) -> void:
	if anim == null or is_dead:
		return
	var t := create_tween()
	t.tween_property(anim, "scale", Vector2(sx, sy), 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(anim, "scale", Vector2.ONE, 0.11)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
