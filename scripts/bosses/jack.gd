extends CharacterBody2D

## JACK
##
## The last thing the factory made. It is still being wound.
##
## Where the King walks and the Choir teleports, Jack *bounces* — he is only
## dangerous while the spring is loaded, and the whole fight is about reading
## the crank. Every attack is preceded by an audible wind-up, so a death is
## always the player's fault and never the game's.
##
## Three phases, each adding an attack. Played dead straight, as always.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
## The champion throws hands. Literally.
const SHOT_TEX := preload("res://assets/effects/fx_glove.png")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

@export var base_health: float = 280.0
var floor_index: int = 0

enum State { INTRO, IDLE, CRANK, LUNGE, SPIRAL, POP, COMBO, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.2
var _hurt_flash: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunges_left: int = 0
var _spiral_angle: float = 0.0
var _spiral_shots: int = 0
var _spiral_step: float = 0.0
var _combo_left: int = 0

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")
var sfx_crank: AudioStream = preload("res://assets/audio/sfx/windup_click.wav")
var sfx_pop: AudioStream = preload("res://assets/audio/sfx/car_horn.wav")
var sfx_land: AudioStream = preload("res://assets/audio/sfx/impact_heavy.wav")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4 | 1
	collision_mask = 1
	max_health = base_health * (1.0 + 0.35 * float(floor_index))
	health = max_health
	_do_intro()


func _do_intro() -> void:
	state = State.INTRO
	EventBus.boss_spawned.emit(self, "JACK")
	EventBus.boss_intro_started.emit("JACK", "Undefeated. Underground.")
	AudioManager.play_sfx(sfx_roar, 0.0, 3.0)
	EventBus.screen_shake.emit(9.0, 1.4)
	anim.play(&"idle")

	# four slow cranks in the dark, then the horn. Nobody is laughing.
	for i in 4:
		await get_tree().create_timer(0.34).timeout
		AudioManager.play_sfx(sfx_crank, 0.0, float(i))
		EventBus.screen_shake.emit(1.4, 0.12)
	await get_tree().create_timer(0.4).timeout
	AudioManager.play_sfx(sfx_pop, 0.0, 4.0)
	EventBus.flash.emit(Color(1.0, 0.85, 0.4, 0.3), 0.25)
	EventBus.screen_shake.emit(6.0, 0.4)
	await get_tree().create_timer(0.8).timeout
	EventBus.boss_intro_finished.emit()
	state = State.IDLE
	_cooldown = 0.8


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

	match state:
		State.IDLE:
			velocity = velocity.move_toward(to.normalized() * (22.0 + 8.0 * phase),
				180.0 * delta)
			anim.play(&"walk" if velocity.length() > 8.0 else &"idle")
			if _cooldown <= 0.0:
				_choose_attack()

		State.CRANK:
			# compress: pull back and hold, the tell for everything he does
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if _timer <= 0.0:
				_fire_after_crank()

		State.LUNGE:
			if _timer > 0.0:
				velocity = _lunge_dir * 400.0
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
				if velocity.length() < 30.0:
					_lunges_left -= 1
					if _lunges_left > 0:
						_start_lunge()
					else:
						AudioManager.play_sfx(sfx_land, 0.05, 0.0)
						EventBus.screen_shake.emit(5.0, 0.25)
						_end_attack(1.15)

		State.SPIRAL:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			_spiral_step -= delta
			if _spiral_step <= 0.0:
				_spiral_step = 0.075
				_spiral_angle += 0.55
				_shoot(Vector2.from_angle(_spiral_angle), 150.0)
				if phase >= 3:
					_shoot(Vector2.from_angle(_spiral_angle + PI), 150.0)
				_spiral_shots -= 1
				if _spiral_shots <= 0:
					_end_attack(1.0)

		State.POP:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_pop()

		State.COMBO:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				_combo_punch()


func _choose_attack() -> void:
	var options := ["lunge", "spiral"]
	if phase >= 2:
		options.append("pop")
		options.append("lunge")
	if phase >= 3:
		# the champion's phase: a boxing combination — jab, jab, cross
		options.append("combo")
		options.append("combo")
		options.append("lunge")
	# everything except the summon goes through a visible, audible crank first
	var pick: String = options[randi() % options.size()]
	if pick == "pop":
		state = State.POP
		_timer = 0.55
		anim.play(&"attack", true)
		return
	state = State.CRANK
	_timer = 0.5
	set_meta(&"next", pick)
	anim.play(&"attack", true)
	AudioManager.play_sfx(sfx_crank, 0.0, 2.0)
	EventBus.screen_shake.emit(1.6, 0.2)


func _fire_after_crank() -> void:
	AudioManager.play_sfx(sfx_pop, 0.05, 2.0)
	match String(get_meta(&"next", "lunge")):
		"spiral":
			state = State.SPIRAL
			_spiral_shots = 14 + phase * 5
			_spiral_step = 0.0
			_spiral_angle = randf() * TAU
		"combo":
			state = State.COMBO
			_combo_left = 3
			_timer = 0.0
		_:
			_lunges_left = 1 + phase          # more bounces the angrier he gets
			_start_lunge()


## Jab, jab, cross: two quick paired gloves, then a wide five-glove cross.
## Every punch is aimed at where you are NOW, so standing still through the
## combination is what gets you hit — keep moving and it whiffs behind you.
func _combo_punch() -> void:
	var dir := Vector2.RIGHT
	if player != null:
		dir = (player.global_position - global_position).normalized()
	if _combo_left > 1:
		AudioManager.play_sfx(sfx_land, 0.1, -4.0)
		for off in [-5.0, 5.0]:
			_shoot(dir.rotated(deg_to_rad(off)), 260.0)
		_timer = 0.26
	else:
		AudioManager.play_sfx(sfx_pop, 0.05, 1.0)
		for i in 5:
			_shoot(dir.rotated(deg_to_rad(lerp(-16.0, 16.0, i / 4.0))), 230.0)
		EventBus.screen_shake.emit(3.5, 0.2)
	_combo_left -= 1
	if _combo_left <= 0:
		_end_attack(1.2)


func _start_lunge() -> void:
	state = State.LUNGE
	_timer = 0.34
	if player != null:
		_lunge_dir = (player.global_position - global_position).normalized()
	if _lunge_dir == Vector2.ZERO:
		_lunge_dir = Vector2.RIGHT
	anim.play(&"attack", true)
	Effects.spawn_dust(get_parent(), global_position + Vector2(0, 14))


func _do_pop() -> void:
	AudioManager.play_sfx(sfx_pop, 0.1, 0.0)
	var windup := ContentDB.get_enemy(&"windup")
	if windup != null:
		var n := 2 if phase == 2 else 3
		for i in n:
			var e := ENEMY_SCENE.instantiate()
			e.data = windup
			get_parent().add_child(e)
			var a := TAU * float(i) / float(n) + randf()
			e.global_position = global_position + Vector2.from_angle(a) * 72.0
			e.scale = Vector2(0.8, 0.8)
			Effects.spawn_stuffing(get_parent(), e.global_position, 8, 90.0, 2.5)
	EventBus.toast.emit("THE LINE IS STILL RUNNING", Color(1, 0.8, 0.45))
	_end_attack(1.4)


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
	if global_position.distance_to(player.global_position) < 44.0:
		if player.has_method("take_damage"):
			player.take_damage(2 if state == State.LUNGE else 1, global_position)


func melee_radius() -> float:
	return 30.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO,
		crit: bool = false, _knockback: float = 0.0) -> void:
	if state == State.DEAD or state == State.INTRO:
		return
	health -= amount
	_hurt_flash = 0.07
	AudioManager.play_sfx(sfx_hurt, 0.12, -4.0)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	Effects.spawn_stuffing(get_parent(), global_position, 6, 90.0, 2.5)
	EventBus.boss_health_changed.emit(clampf(health / max_health, 0.0, 1.0))

	var f := health / max_health
	if f <= 0.66 and phase < 2: _advance_phase(2)
	if f <= 0.33 and phase < 3: _advance_phase(3)
	if health <= 0.0:
		_die()


func _advance_phase(p: int) -> void:
	phase = p
	EventBus.boss_phase_changed.emit(p)
	AudioManager.play_sfx(sfx_roar, 0.0, 1.0)
	EventBus.screen_shake.emit(10.0, 0.7)
	EventBus.flash.emit(Color(1, 0.8, 0.35, 0.3), 0.25)
	Effects.spawn_pop(get_parent(), global_position, 3.0)
	Effects.spawn_stuffing(get_parent(), global_position, 30, 200.0, 4.0)
	EventBus.toast.emit("THE SPRING GOES" if p == 2 else "SOMETHING IN HIM SNAPS",
		Color(1, 0.75, 0.4))
	_end_attack(0.5)


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	anim.play(&"death", true)
	AudioManager.play_sfx(sfx_death, 0.0, 3.0)
	AudioManager.stop_music()
	EventBus.screen_shake.emit(13.0, 1.2)
	Effects.spawn_pop(get_parent(), global_position, 4.2)
	Effects.spawn_stuffing(get_parent(), global_position, 46, 240.0, 5.0)
	EventBus.boss_defeated.emit(self)
	EventBus.toast.emit("JACK IS BACK IN HIS BOX", Color(1, 0.85, 0.45))
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(queue_free)
