extends CharacterBody2D

## THE GINGERBREAD GENERAL
##
## The other boss. Where the Teddy Bear King is a slow wall of stuffing,
## the General is fast, military, and rhythmic: aimed volleys, rotating
## crumb-spray, conscripted minions, and a multi-dash blitz. Same intro
## contract as the King — played completely straight, then the crunch.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
## He hands out training weights, at speed.
const SHOT_TEX := preload("res://assets/effects/fx_dumbbell.png")

const TITLE := "THE GINGERBREAD GENERAL"
const SUBTITLE := "Drill Sergeant of the Gym"

@export var base_health: float = 190.0
var floor_index: int = 0

enum State { INTRO, IDLE, VOLLEY, SPIRAL, CONSCRIPT, BLITZ, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.0
var _hurt_flash: float = 0.0
var _step: int = 0                  ## sub-counter within an attack
var _blitz_dir: Vector2 = Vector2.RIGHT
var _spiral_angle: float = 0.0

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")
var sfx_crunch: AudioStream = preload("res://assets/audio/sfx/ginger_crunch.wav")
var sfx_shot: AudioStream = preload("res://assets/audio/sfx/soldier_shot.wav")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4 | 1   # wall bit too: nobody walks through a boss
	collision_mask = 1
	max_health = base_health * (1.0 + 0.35 * float(floor_index))
	health = max_health
	_do_intro()


func _do_intro() -> void:
	state = State.INTRO
	EventBus.boss_spawned.emit(self, TITLE)
	EventBus.boss_intro_started.emit(TITLE, SUBTITLE)
	AudioManager.play_sfx(sfx_roar, 0.0, 3.0)
	EventBus.screen_shake.emit(9.0, 1.4)
	anim.play(&"idle")

	# gravity, then the crunch of a biscuit snapping to attention
	await get_tree().create_timer(1.55).timeout
	AudioManager.play_sfx(sfx_crunch, 0.0, 2.0)
	EventBus.screen_shake.emit(1.0, 0.2)
	await get_tree().create_timer(1.1).timeout
	EventBus.boss_intro_finished.emit()
	state = State.IDLE
	_cooldown = 0.7


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return
	if state == State.INTRO:
		return

	if player == null or not is_instance_valid(player):
		var ps := get_tree().get_nodes_in_group("player")
		player = ps[0] if not ps.is_empty() else null

	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		anim.modulate = Color(6, 6, 6) if _hurt_flash > 0.0 else Color.WHITE

	if _timer > 0.0: _timer -= delta
	if _cooldown > 0.0: _cooldown -= delta

	_act(delta)
	move_and_slide()
	_clamp_to_room()
	_touch_player()


func _act(delta: float) -> void:
	var to := Vector2.ZERO
	if player != null:
		to = player.global_position - global_position
	var dir := to.normalized()

	match state:
		State.IDLE:
			# quicker on his feet than the King, and quicker each phase
			velocity = velocity.move_toward(dir * (44.0 + 14.0 * phase), 300.0 * delta)
			anim.play(&"walk" if velocity.length() > 8.0 else &"idle")
			if _cooldown <= 0.0:
				_choose_attack()

		State.VOLLEY:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				_volley_burst(dir)

		State.SPIRAL:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_spiral_step()

		State.CONSCRIPT:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_conscript()

		State.BLITZ:
			if _timer > 0.0:
				# telegraph: heels together, slight recoil
				velocity = -_blitz_dir * 46.0
				_blitz_dir = _blitz_dir.lerp(dir, 0.08).normalized()
			else:
				velocity = _blitz_dir * 400.0
				if _timer < -0.32:
					_step -= 1
					if _step <= 0:
						_end_attack(0.9)
					else:
						_timer = 0.3   # next telegraph
						anim.play(&"attack", true)


func _choose_attack() -> void:
	var options := ["volley", "blitz"]
	if phase >= 2:
		options.append("spiral")
		options.append("conscript")
	if phase >= 3:
		options.append("spiral")
		options.append("blitz")
	match options[randi() % options.size()]:
		"volley":
			state = State.VOLLEY; _timer = 0.45; _step = 3
			anim.play(&"attack", true)
		"spiral":
			state = State.SPIRAL; _timer = 0.5; _step = 14 + phase * 6
			_spiral_angle = randf() * TAU
			anim.play(&"attack", true)
		"conscript":
			state = State.CONSCRIPT; _timer = 0.6
			anim.play(&"attack", true)
		"blitz":
			state = State.BLITZ; _timer = 0.42; _step = 1 + phase
			_blitz_dir = (player.global_position - global_position).normalized() \
				if player != null else Vector2.RIGHT
			anim.play(&"attack", true)


func _volley_burst(dir: Vector2) -> void:
	# three aimed three-round bursts, drum-tight
	AudioManager.play_sfx(sfx_shot, 0.06, 0.0)
	for i in 3:
		_shoot(dir.rotated(deg_to_rad(lerp(-9.0, 9.0, i / 2.0))), 170.0)
	EventBus.screen_shake.emit(2.0, 0.12)
	_step -= 1
	if _step <= 0:
		_end_attack(0.9)
	else:
		_timer = 0.28


func _spiral_step() -> void:
	# rotating crumb-spray; phase 3 adds a counter-rotating second stream
	_shoot(Vector2.from_angle(_spiral_angle), 120.0)
	if phase >= 3:
		_shoot(Vector2.from_angle(-_spiral_angle + PI), 120.0)
	_spiral_angle += deg_to_rad(27.0)
	_step -= 1
	if _step <= 0:
		_end_attack(1.2)
	else:
		_timer = 0.09


func _do_conscript() -> void:
	AudioManager.play_sfx(sfx_crunch, 0.15, 1.0)
	var recruits: Array[StringName] = [&"ginger", &"ginger"]
	if phase >= 3:
		recruits.append(&"soldier")
	for i in recruits.size():
		var data := ContentDB.get_enemy(recruits[i])
		if data == null:
			continue
		var e := ENEMY_SCENE.instantiate()
		e.data = data
		get_parent().add_child(e)
		var a := TAU * float(i) / float(recruits.size()) + randf()
		e.global_position = global_position + Vector2.from_angle(a) * 70.0
		e.scale = Vector2(0.75, 0.75)
		Effects.spawn_burst(get_parent(), e.global_position,
			Color(0.85, 0.6, 0.35), 8, 90.0, 2.5)
	EventBus.toast.emit("FRESH FROM THE OVEN", Color(1, 0.6, 0.6))
	_end_attack(1.3)


func _shoot(dir: Vector2, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 24.0
	p.setup(SHOT_TEX, dir * speed, 1.0, false, 520.0, 0, false)


func _end_attack(cool: float) -> void:
	state = State.IDLE
	_cooldown = cool / (1.0 + 0.22 * float(phase - 1))
	anim.play(&"idle", true)


func _clamp_to_room() -> void:
	var r: Node = get_parent()
	if r != null and r.has_method("room_rect"):
		var rect: Rect2 = r.room_rect()
		global_position.x = clampf(global_position.x, rect.position.x + 60.0,
			rect.position.x + rect.size.x - 60.0)
		global_position.y = clampf(global_position.y, rect.position.y + 60.0,
			rect.position.y + rect.size.y - 50.0)


func _touch_player() -> void:
	if player == null or state == State.DEAD or state == State.INTRO:
		return
	if global_position.distance_to(player.global_position) < 40.0:
		if player.has_method("take_damage"):
			player.take_damage(2 if state == State.BLITZ else 1, global_position)


func melee_radius() -> float:
	return 24.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO,
		crit: bool = false, _knockback: float = 0.0) -> void:
	if state == State.DEAD or state == State.INTRO:
		return
	health -= amount
	_hurt_flash = 0.07
	AudioManager.play_sfx(sfx_hurt, 0.12, -4.0)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	Effects.spawn_burst(get_parent(), global_position, Color(0.85, 0.62, 0.36), 6, 90.0, 2.5)
	EventBus.boss_health_changed.emit(clampf(health / max_health, 0.0, 1.0))

	var f := health / max_health
	if f <= 0.66 and phase < 2: _advance_phase(2)
	if f <= 0.33 and phase < 3: _advance_phase(3)
	if health <= 0.0:
		_die()


func _advance_phase(p: int) -> void:
	phase = p
	EventBus.boss_phase_changed.emit(p)
	AudioManager.play_sfx(sfx_roar, 0.0, 0.0)
	EventBus.screen_shake.emit(10.0, 0.7)
	EventBus.flash.emit(Color(1, 0.8, 0.5, 0.30), 0.25)
	Effects.spawn_burst(get_parent(), global_position, Color(0.85, 0.62, 0.36), 30, 200.0, 4.0)
	EventBus.toast.emit("HE SMELLS OF CINNAMON AND WAR" if p == 2 else "HE CRUMBLES, BUT WILL NOT YIELD",
		Color(1, 0.55, 0.5))
	_end_attack(0.5)


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	anim.play(&"death", true)
	AudioManager.play_sfx(sfx_death, 0.0, 3.0)
	AudioManager.stop_music()
	EventBus.screen_shake.emit(13.0, 1.2)
	Effects.spawn_burst(get_parent(), global_position, Color(0.85, 0.62, 0.36), 46, 240.0, 5.0)
	EventBus.boss_defeated.emit(self)
	EventBus.toast.emit("THE GENERAL IS CRUMBS", Color(1, 0.9, 0.5))
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(queue_free)
