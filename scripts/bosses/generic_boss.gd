extends CharacterBody2D

## Runs a BossData. One script, many bosses.
##
## Emits exactly the same EventBus signals as the four bespoke bosses, so the
## HUD, RunManager and the smoke test cannot tell the difference — which is the
## whole point. Everything specific to a given boss lives in its .tres.
##
## Structure mirrors the hand-written bosses on purpose: intro, then an
## idle/attack loop where idle picks a pattern off the phase list, and three
## phases that *add* patterns rather than replace them.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

@export var data: BossData
var floor_index: int = 0

enum State { INTRO, IDLE, WINDUP, ACTING, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.2
var _hurt_flash: float = 0.0
var _pattern: int = 0
var _charge_dir: Vector2 = Vector2.RIGHT
var _spiral_angle: float = 0.0
var _spiral_left: int = 0
var _spiral_step: float = 0.0
var _orbit_angle: float = 0.0
var _blink_to: Vector2 = Vector2.ZERO

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt_d: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death_d: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4 | 1
	collision_mask = 1
	# GROUND mode's floor/wall classification has no meaning in a top-down room
	# and catches the body on corners (a diagonal charge can pin against two
	# walls instead of sliding along one). FLOATING is the correct mode here.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if data == null:
		push_warning("[GenericBoss] no BossData")
		queue_free()
		return

	max_health = data.max_health * (1.0 + 0.30 * float(floor_index)) \
		* (2.0 if GameState.two_player else 1.0)
	health = max_health
	if data.spritesheet != null:
		anim.texture = data.spritesheet
	anim.position = data.sprite_offset
	anim.scale = Vector2(data.sprite_scale, data.sprite_scale)
	anim.modulate = data.tint
	var shape: Shape2D = $CollisionShape2D.shape
	if shape is CircleShape2D:
		(shape as CircleShape2D).radius = data.hit_radius
	var hurt: Shape2D = $HurtBox/CollisionShape2D.shape
	if hurt is CircleShape2D:
		(hurt as CircleShape2D).radius = data.hit_radius + 4.0
	_orbit_angle = randf() * TAU
	_do_intro()


func _do_intro() -> void:
	state = State.INTRO
	EventBus.boss_spawned.emit(self, data.display_name)
	EventBus.boss_intro_started.emit(data.display_name, data.subtitle)
	AudioManager.play_sfx(data.sfx_intro if data.sfx_intro else sfx_roar, 0.0, 2.0)
	EventBus.screen_shake.emit(9.0, 1.3)
	anim.play(&"idle")
	await get_tree().create_timer(2.5).timeout
	EventBus.boss_intro_finished.emit()
	state = State.IDLE
	_cooldown = 0.8


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return
	if state == State.INTRO or data == null:
		return

	# re-pick every frame so both co-op players draw aggro; in 1P this
	# returns the same node it always did
	player = RunManager.nearest_player(global_position)

	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		anim.modulate = Color(6, 6, 6) if _hurt_flash > 0.0 else data.tint

	if _timer > 0.0: _timer -= delta
	if _cooldown > 0.0: _cooldown -= delta

	_move(delta)
	_act(delta)
	move_and_slide()
	_clamp_to_room()
	_touch_player()


func _move(delta: float) -> void:
	# a boss mid-charge or mid-spiral is driven by the pattern, not by its gait
	if state == State.ACTING and _pattern in [BossData.Pattern.CHARGE,
			BossData.Pattern.SPIRAL]:
		return
	var to := Vector2.ZERO
	if player != null:
		to = player.global_position - global_position
	var spd := data.move_speed * (1.0 + 0.12 * float(phase - 1))

	match data.movement:
		BossData.Movement.STALK:
			velocity = velocity.move_toward(to.normalized() * spd, 220.0 * delta)
		BossData.Movement.DRIFT:
			velocity = velocity.move_toward(
				(to.normalized() * 0.4 + Vector2.from_angle(_orbit_angle) * 0.6) * spd,
				150.0 * delta)
			_orbit_angle += delta * 0.7
		BossData.Movement.ORBIT:
			# hold a ring around the player: tangential, plus a nudge in or out
			var radius := 120.0
			var err := to.length() - radius
			var tangent := to.normalized().orthogonal()
			velocity = velocity.move_toward(
				(tangent * 1.0 + to.normalized() * signf(err) * 0.55).normalized() * spd,
				200.0 * delta)
		BossData.Movement.ANCHOR:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		BossData.Movement.HOP:
			if _timer <= 0.0 and state == State.IDLE:
				velocity = to.normalized() * spd * 4.0
			else:
				velocity = velocity.move_toward(Vector2.ZERO, spd * 3.0 * delta)
	if state == State.IDLE:
		anim.play(&"walk" if velocity.length() > 10.0 else &"idle")


func _act(delta: float) -> void:
	match state:
		State.IDLE:
			if _cooldown <= 0.0:
				_begin_attack()
		State.WINDUP:
			if _timer <= 0.0:
				_fire()
		State.ACTING:
			_tick_pattern(delta)


func _begin_attack() -> void:
	var options: Array = data.patterns_for(phase)
	if options.is_empty():
		_cooldown = 1.0
		return
	_pattern = int(options[randi() % options.size()])
	state = State.WINDUP
	# Every attack telegraphs. The research is unanimous that a boss which
	# hits without a tell reads as unfair rather than hard, so the wind-up is
	# not optional and does not shrink to nothing at phase 3.
	_timer = maxf(0.28, 0.5 - 0.06 * float(phase - 1))
	anim.play(&"attack", true)
	if _pattern == BossData.Pattern.CHARGE and player != null:
		_charge_dir = (player.global_position - global_position).normalized()
	elif _pattern == BossData.Pattern.BLINK:
		_pick_blink()
	EventBus.screen_shake.emit(1.8, 0.18)


func _fire() -> void:
	AudioManager.play_sfx(data.sfx_attack if data.sfx_attack else sfx_roar, 0.1)
	match _pattern:
		BossData.Pattern.RING:
			var base := randf() * TAU
			var n := data.projectile_count + phase * 2
			for i in n:
				_shoot(Vector2.from_angle(base + TAU * float(i) / float(n)),
					data.projectile_speed)
			_end(1.2)
		BossData.Pattern.SPREAD:
			var dir := _lead(data.projectile_speed * 1.4)
			var n2 := 4 + phase
			for i in n2:
				var off := deg_to_rad(lerp(-28.0, 28.0, float(i) / float(maxi(1, n2 - 1))))
				_shoot(dir.rotated(off), data.projectile_speed * 1.4)
			_end(0.85)
		BossData.Pattern.SPIRAL:
			state = State.ACTING
			_spiral_left = 12 + phase * 5
			_spiral_step = 0.0
			_spiral_angle = randf() * TAU
		BossData.Pattern.WALL:
			_wall()
			_end(1.5)
		BossData.Pattern.CHARGE:
			state = State.ACTING
			_timer = 0.75
		BossData.Pattern.SUMMON:
			_summon()
			_end(1.4)
		BossData.Pattern.BLINK:
			_blink()
			_end(0.7)
		BossData.Pattern.LOB:
			var d2 := _lead(data.projectile_speed * 0.8)
			for i in 3:
				_shoot(d2.rotated(deg_to_rad(randf_range(-14.0, 14.0))),
					data.projectile_speed * randf_range(0.6, 0.9))
			_end(0.9)
		BossData.Pattern.AURA:
			EventBus.screen_shake.emit(6.0, 0.3)
			Effects.spawn_pop(get_parent(), global_position, 3.2)
			var n3 := 14
			for i in n3:
				_shoot(Vector2.from_angle(TAU * float(i) / float(n3)),
					data.projectile_speed * 0.7)
			if player != null and global_position.distance_to(player.global_position) < 70.0:
				if player.has_method("take_damage"):
					player.take_damage(1, global_position)
			_end(1.3)
		_:
			_end(1.0)


func _tick_pattern(delta: float) -> void:
	match _pattern:
		BossData.Pattern.SPIRAL:
			_spiral_step -= delta
			if _spiral_step <= 0.0:
				_spiral_step = 0.08
				_spiral_angle += 0.5
				_shoot(Vector2.from_angle(_spiral_angle), data.projectile_speed)
				if phase >= 3:
					_shoot(Vector2.from_angle(_spiral_angle + PI), data.projectile_speed)
				_spiral_left -= 1
				if _spiral_left <= 0:
					_end(1.1)
		BossData.Pattern.CHARGE:
			velocity = _charge_dir * 360.0
			if is_on_wall() or _timer <= 0.0:
				EventBus.screen_shake.emit(5.0, 0.25)
				_end(1.2)


## A line across the room with a gap, placed away from the player. The one
## answer to standing in a far corner and waiting the fight out.
func _wall() -> void:
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect"):
		return
	var rect: Rect2 = r.room_rect()
	const INSET := 40.0
	var inner := Rect2(rect.position + Vector2(INSET, INSET),
		rect.size - Vector2(INSET * 2.0, INSET * 2.0))
	var to := Vector2.ZERO
	if player != null:
		to = player.global_position - global_position
	var vertical := absf(to.x) > absf(to.y)
	var slots := 11
	var gap := randi() % slots
	if player != null:
		var along: float = (player.global_position.y - inner.position.y) / inner.size.y \
			if vertical else (player.global_position.x - inner.position.x) / inner.size.x
		gap = (clampi(int(along * float(slots)), 0, slots - 1) + slots / 2) % slots
	for i in slots:
		if i == gap or i == gap + 1:
			continue
		var t := (float(i) + 0.5) / float(slots)
		var from: Vector2
		var dir: Vector2
		if vertical:
			var right := to.x > 0.0
			from = Vector2(inner.position.x if right else inner.end.x,
				inner.position.y + inner.size.y * t)
			dir = Vector2.RIGHT if right else Vector2.LEFT
		else:
			var down := to.y > 0.0
			from = Vector2(inner.position.x + inner.size.x * t,
				inner.position.y if down else inner.end.y)
			dir = Vector2.DOWN if down else Vector2.UP
		var p := PROJECTILE.instantiate()
		get_parent().add_child(p)
		p.global_position = from
		p.setup(null, dir * (90.0 + 12.0 * float(phase)), 1.0, false, 900.0, 0, false)
	EventBus.toast.emit("GET BEHIND SOMETHING", Color(1, 0.7, 0.55))


func _summon() -> void:
	if data.minion_id == &"":
		return
	var d := ContentDB.get_enemy(data.minion_id)
	if d == null:
		return
	var n := 2 + (1 if phase >= 3 else 0)
	for i in n:
		var e := ENEMY_SCENE.instantiate()
		e.data = d
		get_parent().add_child(e)
		var a := TAU * float(i) / float(n) + randf()
		e.global_position = global_position + Vector2.from_angle(a) * 72.0
		e.scale = Vector2(0.8, 0.8)
		Effects.spawn_stuffing(get_parent(), e.global_position, 8, 90.0, 2.5)


func _pick_blink() -> void:
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect") or player == null:
		_blink_to = global_position
		return
	var rect: Rect2 = r.room_rect()
	for _try in 12:
		var p := Vector2(
			randf_range(rect.position.x + 70.0, rect.end.x - 70.0),
			randf_range(rect.position.y + 70.0, rect.end.y - 60.0))
		if p.distance_to(player.global_position) > 90.0:
			_blink_to = p
			return
	_blink_to = global_position


func _blink() -> void:
	Effects.spawn_pop(get_parent(), global_position, 2.0)
	Effects.spawn_burst(get_parent(), global_position, data.debris, 12, 110.0, 2.5)
	global_position = _blink_to
	Effects.spawn_pop(get_parent(), global_position, 2.0)
	var dir := _lead(data.projectile_speed)
	for i in 3:
		_shoot(dir.rotated(deg_to_rad(lerp(-18.0, 18.0, i / 2.0))), data.projectile_speed)


func _lead(speed: float) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.DOWN
	var to: Vector2 = player.global_position - global_position
	var pv: Vector2 = player.get("velocity") if player.get("velocity") != null else Vector2.ZERO
	if speed <= 1.0:
		return to.normalized()
	return (to + pv * (to.length() / speed) * 0.7).normalized()


func _shoot(dir: Vector2, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * (data.hit_radius + 4.0)
	p.setup(null, dir * speed, 1.0, false, 560.0, 0, false)


func _end(cool: float) -> void:
	state = State.IDLE
	_cooldown = cool * data.cooldown / (1.0 + 0.22 * float(phase - 1))
	anim.play(&"idle", true)


func _clamp_to_room() -> void:
	var r: Node = get_parent()
	if r != null and r.has_method("room_rect"):
		var rect: Rect2 = r.room_rect()
		global_position.x = clampf(global_position.x, rect.position.x + 60.0,
			rect.end.x - 60.0)
		global_position.y = clampf(global_position.y, rect.position.y + 60.0,
			rect.end.y - 50.0)


func _touch_player() -> void:
	if player == null or state in [State.DEAD, State.INTRO] or data.contact_damage <= 0:
		return
	if global_position.distance_to(player.global_position) < data.hit_radius + 18.0:
		if player.has_method("take_damage"):
			player.take_damage(data.contact_damage, global_position)


func melee_radius() -> float:
	return data.hit_radius if data != null else 26.0


func take_damage(amount: float, _from: Vector2 = Vector2.ZERO,
		crit: bool = false, _knockback: float = 0.0) -> void:
	if state in [State.DEAD, State.INTRO]:
		return
	health -= amount
	_hurt_flash = 0.07
	AudioManager.play_sfx(data.sfx_hurt if data.sfx_hurt else sfx_hurt_d, 0.12, -4.0)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	Effects.spawn_burst(get_parent(), global_position, data.debris, 6, 100.0, 2.4)
	EventBus.boss_health_changed.emit(clampf(health / max_health, 0.0, 1.0))

	var f := health / max_health
	if f <= 0.66 and phase < 2: _advance(2)
	if f <= 0.33 and phase < 3: _advance(3)
	if health <= 0.0:
		_die()


func _advance(p: int) -> void:
	phase = p
	EventBus.boss_phase_changed.emit(p)
	AudioManager.play_sfx(data.sfx_intro if data.sfx_intro else sfx_roar, 0.0, 1.0)
	EventBus.screen_shake.emit(10.0, 0.7)
	EventBus.flash.emit(Color(data.tint.r, data.tint.g, data.tint.b, 0.28), 0.25)
	Effects.spawn_pop(get_parent(), global_position, 3.0)
	Effects.spawn_burst(get_parent(), global_position, data.debris, 28, 200.0, 3.4)
	var line: String = data.phase2_line if p == 2 else data.phase3_line
	if line != "":
		EventBus.toast.emit(line, data.tint)
	_end(0.5)


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	anim.play(&"death", true)
	AudioManager.play_sfx(data.sfx_death if data.sfx_death else sfx_death_d, 0.0, 2.0)
	AudioManager.stop_music()
	EventBus.screen_shake.emit(13.0, 1.2)
	Effects.spawn_pop(get_parent(), global_position, 4.2)
	Effects.spawn_burst(get_parent(), global_position, data.debris, 46, 240.0, 4.0)
	EventBus.boss_defeated.emit(self)
	if data.defeat_line != "":
		EventBus.toast.emit(data.defeat_line, data.tint)
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(queue_free)
