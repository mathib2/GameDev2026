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
##
## The fight is a bullet hell. Two pressures run the whole time, on top of
## whatever the state machine is doing: censor-bar WALLS sweep in from the
## room's edges on a clock, each with one gap to thread, faster and paired as
## the phases stack — and its own attacks favour slow dense SPIRALS over
## aimed shots, the Touhou trade: nothing is fast, everything is everywhere.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
## What censorship is made of.
const SHOT_STATIC := preload("res://assets/effects/fx_static.png")
## Pieces of wing, thrown hard enough to matter.
const SHOT_FEATHER := preload("res://assets/effects/fx_feather.png")

const TITLE := "?????"
const SUBTITLE := "How disgusting"

## Highest base in the roster on the deepest floor: with the shared
## (1 + 0.35 * floor_index) multiplier this lands at well over twice Jack's
## effective health. The last fight is meant to be the wall — and by phase
## three, chaos: paired censor bars, departure bursts, static pouring out of
## every blink, and the room's own natives crawling in.
@export var base_health: float = 420.0
var floor_index: int = 0

enum State { INTRO, IDLE, BLINK, RING, RAZORS, BAR, SPIRAL, DEAD }

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
## The ambient wall clock, ticking from the moment the intro ends.
var _wall_cd: float = 4.0
## Spiral bookkeeping: time left, tick accumulator, arm angle, spin sign.
var _spiral_t: float = 0.0
var _spiral_tick: float = 0.0
var _spiral_angle: float = 0.0
var _spiral_spin: float = 1.0

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

	# The room attacks on its own schedule, whatever the boss is doing.
	_wall_cd -= delta
	if _wall_cd <= 0.0:
		_wall_cd = [5.0, 3.6, 2.6][clampi(phase - 1, 0, 2)]
		_spawn_wall()
		if phase >= 3:
			_spawn_wall()   # paired walls: two edges, two gaps, one player

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

		State.SPIRAL:
			velocity = Vector2.ZERO
			_run_spiral(delta)


func _choose_attack() -> void:
	var options := ["ring", "spiral"]
	if phase >= 2:
		options.append("razors")
		options.append("spiral")
	if phase >= 3:
		options.append("bar")
		options.append("spiral")
	match options[randi() % options.size()]:
		"ring":
			state = State.RING; _timer = 0.6
			anim.play(&"attack", true)
		"razors":
			state = State.RAZORS; _timer = 0.45; _step = 3 + (1 if phase >= 3 else 0)
			anim.play(&"attack", true)
		"bar":
			state = State.BAR; _timer = 0.7
			anim.play(&"attack", true)
		"spiral":
			state = State.SPIRAL
			_spiral_t = 2.4 + 0.5 * float(phase)
			_spiral_tick = 0.0
			_spiral_angle = randf() * TAU
			_spiral_spin = 1.0 if randf() < 0.5 else -1.0
			anim.play(&"attack", true)


## Somewhere else, watchably. The fade-out is the telegraph.
func _start_blink() -> void:
	state = State.BLINK
	_timer = 0.24
	AudioManager.play_sfx(sfx_blink, 0.1, -6.0)
	# from phase 2, leaving a place means salting it: chasing the fade gets
	# you a face full of static
	if phase >= 2:
		var base := randf() * TAU
		for i in 6:
			_shoot(SHOT_STATIC, Vector2.from_angle(base + TAU * i / 6.0), 90.0)
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
	_blink_cd = 2.8 - 0.55 * float(phase)
	state = State.IDLE
	# arriving next to the player owes them a beat before anything fires
	_cooldown = maxf(_cooldown, 0.45)


func _do_ring() -> void:
	AudioManager.play_sfx(sfx_burst, 0.05, -2.0)
	var count := 12 + phase * 3
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
	var rows := 2 if phase >= 3 else 1
	for r in rows:
		# the second bar trails the first, so the dodge has to be TWO dodges
		var lead := dir * (30.0 - 46.0 * float(r))
		for i in 9:
			var off := perp * (float(i) - 4.0) * 18.0
			var p := PROJECTILE.instantiate()
			get_parent().add_child(p)
			p.global_position = global_position + lead + off
			p.setup(SHOT_STATIC, dir * 145.0, 1.0, false, 620.0, 0, false)
	EventBus.screen_shake.emit(4.0, 0.25)
	_end_attack(1.4)


## Touhou rules: slow bullets, many arms, constant angular step. The pattern
## hangs in the air and the player reads the whole room, not one shot. Phase 3
## adds a counter-rotating second spiral, which is where the chaos lives —
## the two lattices drift through each other and safe lanes keep moving.
func _run_spiral(delta: float) -> void:
	_spiral_t -= delta
	_spiral_tick -= delta
	if _spiral_tick <= 0.0:
		_spiral_tick = 0.085
		var arms := 3 + (1 if phase >= 2 else 0)
		for i in arms:
			var a := _spiral_angle + TAU * float(i) / float(arms)
			_shoot(SHOT_STATIC, Vector2.from_angle(a), 88.0)
			if phase >= 3:
				_shoot(SHOT_FEATHER, Vector2.from_angle(-a + PI * 0.5), 74.0)
		_spiral_angle += 0.42 * _spiral_spin
	if _spiral_t <= 0.0:
		_end_attack(1.3)


## One censor bar, arriving from outside: a row of static spanning the room
## save for a single gap. The gap is the whole conversation — find it, be in
## it. Spawned just inside the walls so every shot is visible from birth.
func _spawn_wall() -> void:
	if state == State.INTRO or state == State.DEAD:
		return
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect"):
		return
	var rect: Rect2 = r.room_rect()
	AudioManager.play_sfx(sfx_blink, 0.0, -4.0)
	var horizontal := randf() < 0.5          # wall spans left-right, sweeps up/down
	var from_low := randf() < 0.5
	var speed := 92.0 + 10.0 * float(phase)
	var slots := 15
	var gap_at := randi_range(1, slots - 4)  # gap never flush with a wall
	var gap_w := 3
	for i in slots:
		if i >= gap_at and i < gap_at + gap_w:
			continue
		var frac := (float(i) + 0.5) / float(slots)
		var p := PROJECTILE.instantiate()
		get_parent().add_child(p)
		var pos: Vector2
		var vel: Vector2
		if horizontal:
			pos = Vector2(rect.position.x + rect.size.x * frac,
				rect.position.y + (rect.size.y - 44.0 if from_low else 44.0))
			vel = Vector2(0, -speed if from_low else speed)
		else:
			pos = Vector2(rect.position.x + (rect.size.x - 44.0 if from_low else 44.0),
				rect.position.y + rect.size.y * frac)
			vel = Vector2(-speed if from_low else speed, 0)
		p.global_position = pos
		p.setup(SHOT_STATIC, vel, 1.0, false, 700.0, 0, false)


func _shoot(tex: Texture2D, dir: Vector2, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 26.0
	p.setup(tex, dir * speed, 1.0, false, 520.0, 0, false)


func _end_attack(cool: float) -> void:
	state = State.IDLE
	_cooldown = cool / (1.0 + 0.34 * float(phase - 1))
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
			player.take_damage(2 if phase >= 3 else 1, global_position)


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
	EventBus.toast.emit("SUCH A CREATURE SHOULD NOT EXIST" if p == 2 else "CLEANSE IT",
		Color(0.92, 0.92, 0.95))
	# the floor sends help. Safe now that boss rooms only clear through
	# boss_defeated — a dead mite can no longer open the doors early.
	var mite := ContentDB.get_enemy(&"static_mite")
	if mite != null:
		for i in p:
			var e := ENEMY_SCENE.instantiate()
			e.data = mite
			get_parent().add_child(e)
			var a := TAU * float(i) / float(p) + randf()
			e.global_position = global_position + Vector2.from_angle(a) * 80.0
			e.scale = Vector2(0.85, 0.85)
			Effects.spawn_burst(get_parent(), e.global_position,
				Color(0.92, 0.92, 0.95), 8, 90.0, 2.5)
	_end_attack(0.4)


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
	EventBus.toast.emit("*&$^%*&#$%*&^%#*#%*&", Color(0.92, 0.92, 0.95))
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	t.tween_callback(queue_free)
