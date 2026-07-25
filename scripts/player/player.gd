extends CharacterBody2D

## The man himself.
##
## Movement is tuned for *weight without sluggishness*: high acceleration so
## input registers immediately, lower friction so he slides a little when he
## stops, and a dodge roll with i-frames as the skill expression.
##
## He does not own damage, items, or floors — he reads GameState and emits.

const PROJECTILE := preload("res://scenes/player/PlayerProjectile.tscn")

@export var base_speed: float = 132.0
@export var acceleration: float = 1500.0
@export var friction: float = 1050.0
@export var dodge_speed: float = 330.0
@export var dodge_time: float = 0.22
@export var dodge_cooldown: float = 0.75
@export var invuln_time: float = 0.8

enum State { NORMAL, ATTACK, DODGE, HURT, DEAD }

var state: State = State.NORMAL
var facing: Vector2 = Vector2.DOWN
var aim: Vector2 = Vector2.DOWN

var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cd: float = 0.0
var _invuln: float = 0.0
var _hurt_timer: float = 0.0
var _step_timer: float = 0.0
var _dodge_dir: Vector2 = Vector2.RIGHT

@onready var anim: SheetAnimator = $SheetAnimator
@onready var hit_area: Area2D = $HitArea
@onready var camera: Camera2D = $Camera2D

var sfx_punch: AudioStream = preload("res://assets/audio/sfx/player_punch.wav")
var sfx_swing: AudioStream = preload("res://assets/audio/sfx/player_swing.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/player_hurt.wav")
var sfx_dodge: AudioStream = preload("res://assets/audio/sfx/player_dodge.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/player_death.wav")
var sfx_step: AudioStream = preload("res://assets/audio/sfx/player_step.wav")


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	GameFeel.camera = camera
	EventBus.player_died.connect(_on_died)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	match state:
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, friction * 2.0 * delta)
		State.DODGE:
			velocity = _dodge_dir * dodge_speed
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_:
			_handle_move(delta)
			_handle_attack()
			_handle_dodge()
	move_and_slide()
	_update_anim()


func _tick_timers(delta: float) -> void:
	if _invuln > 0.0: _invuln -= delta
	if _dodge_cd > 0.0: _dodge_cd -= delta
	if _attack_timer > 0.0: _attack_timer -= delta
	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0 and state == State.HURT:
			state = State.NORMAL
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0 and state == State.DODGE:
			state = State.NORMAL
	# flicker while invulnerable
	modulate.a = 0.45 if (_invuln > 0.0 and int(_invuln * 20.0) % 2 == 0) else 1.0


func _handle_move(delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var speed := base_speed * GameState.stat("speed_mult")
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, acceleration * delta)
		facing = input.normalized()
		# footstep + dust while actually moving
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.30
			AudioManager.play_sfx(sfx_step, 0.16, -8.0)
			Effects.spawn_dust(get_parent(), global_position + Vector2(0, 6))
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _handle_attack() -> void:
	var w := GameState.weapon
	if w == null or _attack_timer > 0.0:
		return
	if not Input.is_action_pressed(&"attack"):
		return
	aim = _aim_vector()
	_attack_timer = w.cooldown / maxf(0.1, GameState.stat("fire_rate_mult"))
	state = State.ATTACK
	anim.play(&"attack", true)
	AudioManager.play_sfx(w.sfx_use if w.sfx_use else sfx_swing)
	if w.kind == WeaponData.Kind.MELEE:
		_melee(w)
	else:
		_shoot(w)


func _melee(w: WeaponData) -> void:
	var hit_any := false
	for body in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("breakable"):
		if not is_instance_valid(body) or not (body is Node2D):
			continue
		var to: Vector2 = body.global_position - global_position
		if to.length() > w.reach + 16.0:
			continue
		if rad_to_deg(absf(to.angle_to(aim))) > w.arc_degrees * 0.5:
			continue
		var dmg_roll := w.roll_damage()
		var dmg: float = dmg_roll[0] * GameState.stat("damage_mult") + GameState.stat("damage_flat")
		var crit: bool = dmg_roll[1] or randf() < GameState.stat("crit_chance")
		if body.has_method("take_damage"):
			body.take_damage(dmg, global_position, crit,
				w.knockback * GameState.stat("knockback_mult"))
			hit_any = true
	if hit_any:
		EventBus.hit_stop.emit(w.hitstop)
		EventBus.screen_shake.emit(w.shake, 0.18)
		AudioManager.play_sfx(w.sfx_hit if w.sfx_hit else sfx_punch)
	# swing arc puff so a miss still reads
	Effects.spawn_dust(get_parent(), global_position + aim * w.reach * 0.6)


func _shoot(w: WeaponData) -> void:
	var n := maxi(1, w.projectiles_per_shot)
	for i in n:
		var spread := deg_to_rad(w.spread_degrees)
		var offset: float = 0.0
		if n > 1:
			offset = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(n - 1))
		var dir := aim.rotated(offset)
		var p := PROJECTILE.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position + dir * 14.0
		var roll := w.roll_damage()
		var dmg: float = roll[0] * GameState.stat("damage_mult") + GameState.stat("damage_flat")
		var crit: bool = roll[1] or randf() < GameState.stat("crit_chance")
		p.setup(w.projectile_texture, dir * w.projectile_speed, dmg, true,
			w.projectile_range, w.pierce, crit)
		p.knockback = w.knockback * GameState.stat("knockback_mult")
	EventBus.screen_shake.emit(w.shake * 0.5, 0.1)


func _handle_dodge() -> void:
	if _dodge_cd > 0.0 or not Input.is_action_just_pressed(&"dodge"):
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_dodge_dir = input.normalized() if input != Vector2.ZERO else facing
	state = State.DODGE
	_dodge_timer = dodge_time
	_dodge_cd = dodge_cooldown * GameState.stat("dodge_cooldown_mult")
	_invuln = maxf(_invuln, dodge_time + 0.06)
	anim.play(&"dodge", true)
	AudioManager.play_sfx(sfx_dodge)
	Effects.spawn_dust(get_parent(), global_position + Vector2(0, 6))


func _aim_vector() -> Vector2:
	var stick := Vector2(
		Input.get_axis(&"aim_left", &"aim_right"),
		Input.get_axis(&"aim_up", &"aim_down"))
	if stick.length() > 0.3:
		return stick.normalized()
	var to_mouse := get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 4.0 else facing


func _update_anim() -> void:
	if state == State.DEAD:
		return
	anim.flip_h = (aim.x < 0.0) if state == State.ATTACK else (facing.x < 0.0 and velocity.x < -1.0)
	match state:
		State.DODGE:
			pass
		State.HURT:
			pass
		State.ATTACK:
			if anim.is_finished():
				state = State.NORMAL
		_:
			anim.play(&"walk" if velocity.length() > 12.0 else &"idle")


## Called by enemies and enemy projectiles.
func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or _invuln > 0.0 or state == State.DODGE:
		return
	GameState.damage(amount)
	if GameState.health <= 0:
		return
	_invuln = invuln_time
	state = State.HURT
	_hurt_timer = 0.22
	anim.play(&"hurt", true)
	AudioManager.play_sfx(sfx_hurt)
	EventBus.screen_shake.emit(7.0, 0.3)
	EventBus.hit_stop.emit(0.06)
	EventBus.flash.emit(Color(0.75, 0.1, 0.1, 0.35), 0.18)
	if from != Vector2.ZERO:
		velocity = (global_position - from).normalized() * 210.0


func _on_died() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	anim.play(&"death", true)
	AudioManager.play_sfx(sfx_death)
	EventBus.screen_shake.emit(11.0, 0.6)
	set_physics_process(true)
