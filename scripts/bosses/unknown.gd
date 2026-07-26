extends CharacterBody2D

## ?????
##
## The fifth floor's boss. The floor has no name and the boss has no face —
## a pair of pale wings behind a censor bar, and the bar is not covering the
## sprite: the bar is what the place lets you see.
##
## It does not walk. It is somewhere, and then it is somewhere else — every
## repositioning is a fade you can watch, so the player is never hit by
## something that arrived without travelling *at* them first. Three phases,
## each adding an attack, same as every boss before it. Played straight,
## same as everything.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
## What censorship is made of.
const SHOT_STATIC := preload("res://assets/effects/fx_static.png")
## Pieces of wing, thrown hard enough to matter.
const SHOT_FEATHER := preload("res://assets/effects/fx_feather.png")

const TITLE := "?????"
const SUBTITLE := "Even the Place Looks Away"

@export var base_health: float = 340.0
var floor_index: int = 0

enum State { INTRO, IDLE, BLINK, RING, RAZORS, BAR, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.2
var _hurt_flash: float = 0.0
var _step: int = 0
var _blink_cd: float = 2.0
var _blink_to: Vector2 = Vector2.ZERO

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")
var sfx_blink: AudioStream = preload("res://assets/audio/sfx/windup_click.wav")
var sfx_burst: AudioStream = preload("res://assets/audio/sfx/rattle_shake.wav")


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
	EventBus.boss_spawned.emit(self, TITLE)
	EventBus.boss_intro_started.emit(TITLE, SUBTITLE)
	# The other bosses announce themselves. This one gets announced AT: a
	# white flash, a roar with the volume wrong, and then nothing happens
	# for slightly too long.
	EventBus.flash.emit(Color(1, 1, 1, 0.5), 0.3)
	AudioManager.play_sfx(sfx_roar, 0.0, -10.0)
	EventBus.screen_shake.emit(4.0, 0.8)
	anim.play(&"idle")
	await get_tree().create_timer(2.6).timeout
	EventBus.boss_intro_finished.emit()
	state = State.IDLE
	_cooldown = 0.8


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
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
	if _blink_cd > 0.0: _blink_cd -= delta

	_act(delta)
	move_and_slide()
	_clamp_to_room()
	_touch_player()


func _act(delta: float) -> void:
	var dir := Vector2.ZERO
	if player != null:
		dir = (player.global_position - global_position).normalized()

	match state:
		State.IDLE:
			# it drifts, barely — the stillness is the point
			velocity = velocity.move_toward(dir * 14.0, 120.0 * delta)
			anim.play(&"idle")
			if _blink_cd <= 0.0:
				_start_blink()
			elif _cooldown <= 0.0:
				_choose_attack()

		State.BLINK:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_finish_blink()

		State.RING:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_ring()

		State.RAZORS:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_razor_burst(dir)

		State.BAR:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_bar(dir)


func _choose_attack() -> void:
	var options := ["ring"]
	if phase >= 2:
		options.append("razors")
		options.append("razors")
	if phase >= 3:
		options.append("bar")
		options.append("bar")
	match options[randi() % options.size()]:
		"ring":
			state = State.RING; _timer = 0.6
			anim.play(&"attack", true)
		"razors":
			state = State.RAZORS; _timer = 0.45; _step = 3
			anim.play(&"attack", true)
		"bar":
			state = State.BAR; _timer = 0.7
			anim.play(&"attack", true)


## Somewhere else, watchably. The fade-out is the telegraph.
func _start_blink() -> void:
	state = State.BLINK
	_timer = 0.24
	AudioManager.play_sfx(sfx_blink, 0.1, -6.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.08, 0.2)
	_blink_to = global_position
	if player != null:
		var a := randf() * TAU
		_blink_to = player.global_position + Vector2.from_angle(a) * 150.0
	var r: Node = get_parent()
	if r != null and r.has_method("room_rect"):
		var rect: Rect2 = r.room_rect()
		_blink_to.x = clampf(_blink_to.x, rect.position.x + 70.0,
			rect.position.x + rect.size.x - 70.0)
		_blink_to.y = clampf(_blink_to.y, rect.position.y + 70.0,
			rect.position.y + rect.size.y - 60.0)


func _finish_blink() -> void:
	global_position = _blink_to
	Effects.spawn_pop(get_parent(), global_position, 1.6)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.16)
	_blink_cd = 3.4 - 0.5 * float(phase)
	state = State.IDLE
	# arriving next to the player owes them a beat before anything fires
	_cooldown = maxf(_cooldown, 0.45)


func _do_ring() -> void:
	AudioManager.play_sfx(sfx_burst, 0.05, -2.0)
	var count := 10 + phase * 3
	var base := randf() * TAU
	for i in count:
		_shoot(SHOT_STATIC, Vector2.from_angle(base + TAU * float(i) / float(count)), 105.0)
	EventBus.screen_shake.emit(3.0, 0.2)
	_end_attack(1.1)


func _razor_burst(dir: Vector2) -> void:
	AudioManager.play_sfx(sfx_burst, 0.1, -4.0)
	for i in 3:
		_shoot(SHOT_FEATHER, dir.rotated(deg_to_rad(lerp(-10.0, 10.0, i / 2.0))), 220.0)
	_step -= 1
	if _step <= 0:
		_end_attack(1.0)
	else:
		_timer = 0.3


## A censor bar, thrown: a row of static travelling together. Reads as a wall
## coming at you, dodged by crossing it where you are ready to, not by luck.
func _do_bar(dir: Vector2) -> void:
	AudioManager.play_sfx(sfx_burst, 0.0, 0.0)
	var perp := dir.orthogonal()
	for i in 9:
		var off := perp * (float(i) - 4.0) * 18.0
		var p := PROJECTILE.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position + dir * 30.0 + off
		p.setup(SHOT_STATIC, dir * 130.0, 1.0, false, 620.0, 0, false)
	EventBus.screen_shake.emit(4.0, 0.25)
	_end_attack(1.5)


func _shoot(tex: Texture2D, dir: Vector2, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 26.0
	p.setup(tex, dir * speed, 1.0, false, 520.0, 0, false)


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
			player.take_damage(1, global_position)


func melee_radius() -> float:
	return 28.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO,
		crit: bool = false, _knockback: float = 0.0) -> void:
	if state == State.DEAD or state == State.INTRO:
		return
	health -= amount
	_hurt_flash = 0.07
	AudioManager.play_sfx(sfx_hurt, 0.12, -6.0)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	Effects.spawn_burst(get_parent(), global_position, Color(0.92, 0.92, 0.95), 6, 90.0, 2.5)
	EventBus.boss_health_changed.emit(clampf(health / max_health, 0.0, 1.0))

	var f := health / max_health
	if f <= 0.66 and phase < 2: _advance_phase(2)
	if f <= 0.33 and phase < 3: _advance_phase(3)
	if health <= 0.0:
		_die()


func _advance_phase(p: int) -> void:
	phase = p
	EventBus.boss_phase_changed.emit(p)
	AudioManager.play_sfx(sfx_roar, 0.0, -8.0)
	EventBus.screen_shake.emit(8.0, 0.6)
	EventBus.flash.emit(Color(1, 1, 1, 0.35), 0.2)
	Effects.spawn_burst(get_parent(), global_position, Color(0.92, 0.92, 0.95), 26, 190.0, 4.0)
	EventBus.toast.emit("IT IS CLOSER THAN IT WAS" if p == 2 else "STOP LOOKING",
		Color(0.92, 0.92, 0.95))
	_end_attack(0.5)


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	modulate.a = 1.0
	anim.play(&"death", true)
	AudioManager.play_sfx(sfx_death, 0.0, -2.0)
	AudioManager.stop_music()
	EventBus.screen_shake.emit(11.0, 1.0)
	Effects.spawn_burst(get_parent(), global_position, Color(0.92, 0.92, 0.95), 40, 220.0, 5.0)
	EventBus.boss_defeated.emit(self)
	EventBus.toast.emit("IT IS GONE. PROBABLY.", Color(0.92, 0.92, 0.95))
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	t.tween_callback(queue_free)
