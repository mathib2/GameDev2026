extends CharacterBody2D

## THE PORCELAIN CHOIR
##
## She does not chase you. She appears where you are not looking, and she sings.
##
## Built to contrast with the King: he is a wall of mass that walks at you, so
## she never walks at all — she blinks, holds still, and punishes standing in
## open floor. Three phases, each *adding* an attack so the fight escalates
## visibly rather than swapping difficulty around.
##
## The intro is played completely straight. The joke — that this is a doll from
## a nursery — is never acknowledged by the game, which is the only way it lands.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
## She sings scalding vapour.
const SHOT_TEX := preload("res://assets/effects/fx_steam.png")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

@export var base_health: float = 240.0
var floor_index: int = 0

enum State { INTRO, IDLE, SCREAM, SHARDS, MIRROR, BLINK, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.2
var _hurt_flash: float = 0.0
var _blink_to: Vector2 = Vector2.ZERO

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")
var sfx_chatter: AudioStream = preload("res://assets/audio/sfx/rattle_shake.wav")
var sfx_shard: AudioStream = preload("res://assets/audio/sfx/ginger_crunch.wav")


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
	EventBus.boss_spawned.emit(self, "THE PORCELAIN CHOIR")
	EventBus.boss_intro_started.emit("THE PORCELAIN CHOIR", "She Practises in the Steam")
	AudioManager.play_sfx(sfx_roar, 0.0, 2.0)
	EventBus.screen_shake.emit(8.0, 1.3)
	anim.play(&"idle")

	await get_tree().create_timer(1.5).timeout
	# the sound of a hundred hairline cracks, in the silence after the sting
	AudioManager.play_sfx(sfx_chatter, 0.0, 1.0)
	EventBus.flash.emit(Color(0.85, 0.9, 1.0, 0.22), 0.3)
	await get_tree().create_timer(1.05).timeout
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

	match state:
		State.IDLE:
			# drifts, never charges — the threat is the floor, not her body
			velocity = velocity.move_toward(to.normalized() * (14.0 + 6.0 * phase),
				140.0 * delta)
			anim.play(&"walk" if velocity.length() > 8.0 else &"idle")
			if _cooldown <= 0.0:
				_choose_attack()

		State.SCREAM:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				_do_scream()

		State.SHARDS:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				_do_shards()

		State.MIRROR:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_mirror()

		State.BLINK:
			velocity = Vector2.ZERO
			# fade out, reappear elsewhere, fade in
			if _timer <= 0.0:
				_do_blink()


func _choose_attack() -> void:
	var options := ["scream", "shards"]
	if phase >= 2:
		options.append("blink")
		options.append("mirror")
	if phase >= 3:
		options.append("scream")
		options.append("blink")
	match options[randi() % options.size()]:
		"scream":
			state = State.SCREAM; _timer = 0.7; anim.play(&"attack", true)
		"shards":
			state = State.SHARDS; _timer = 0.4; anim.play(&"attack", true)
		"mirror":
			state = State.MIRROR; _timer = 0.6; anim.play(&"attack", true)
		"blink":
			state = State.BLINK; _timer = 0.35; anim.play(&"attack", true)
			_pick_blink_target()


## An expanding double ring, offset so there is a gap to stand in — the attack
## is survivable if you read it, which is the difference between hard and cheap.
func _do_scream() -> void:
	AudioManager.play_sfx(sfx_roar, 0.05, 0.0)
	EventBus.screen_shake.emit(7.0, 0.4)
	EventBus.flash.emit(Color(0.9, 0.95, 1.0, 0.18), 0.2)
	Effects.spawn_pop(get_parent(), global_position, 3.4)
	var count := 12 + phase * 3
	var base := randf() * TAU
	for i in count:
		var a := base + TAU * float(i) / float(count)
		_shoot(Vector2.from_angle(a), 96.0)
	if phase >= 3:
		for i in count:
			var a2 := base + TAU * (float(i) + 0.5) / float(count)
			_shoot(Vector2.from_angle(a2), 150.0)
	_end_attack(1.25)


func _do_shards() -> void:
	AudioManager.play_sfx(sfx_shard, 0.08, 1.0)
	var dir := Vector2.DOWN
	if player != null:
		dir = (player.global_position - global_position).normalized()
	var n := 5 + phase
	for i in n:
		var off := deg_to_rad(lerp(-30.0, 30.0, float(i) / float(maxi(1, n - 1))))
		_shoot(dir.rotated(off), 190.0)
	EventBus.screen_shake.emit(2.5, 0.15)
	_end_attack(0.85)


func _do_mirror() -> void:
	AudioManager.play_sfx(sfx_chatter, 0.1, 0.0)
	var doll := ContentDB.get_enemy(&"doll")
	if doll != null:
		var n := 2 if phase == 2 else 3
		for i in n:
			var e := ENEMY_SCENE.instantiate()
			e.data = doll
			get_parent().add_child(e)
			var a := TAU * float(i) / float(n) + randf()
			e.global_position = global_position + Vector2.from_angle(a) * 74.0
			e.scale = Vector2(0.8, 0.8)
			Effects.spawn_stuffing(get_parent(), e.global_position, 8, 90.0, 2.5)
	EventBus.toast.emit("SHE IS NOT ALONE", Color(0.8, 0.85, 1.0))
	_end_attack(1.5)


func _pick_blink_target() -> void:
	# somewhere else in the room, never on top of the player
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect") or player == null:
		_blink_to = global_position
		return
	var rect: Rect2 = r.room_rect()
	for _try in 12:
		var p := Vector2(
			randf_range(rect.position.x + 70.0, rect.position.x + rect.size.x - 70.0),
			randf_range(rect.position.y + 70.0, rect.position.y + rect.size.y - 60.0))
		if p.distance_to(player.global_position) > 90.0:
			_blink_to = p
			return
	_blink_to = global_position


func _do_blink() -> void:
	Effects.spawn_stuffing(get_parent(), global_position, 12, 110.0, 2.5)
	Effects.spawn_pop(get_parent(), global_position, 2.0)
	AudioManager.play_sfx(sfx_chatter, 0.12, 3.0)
	global_position = _blink_to
	Effects.spawn_pop(get_parent(), global_position, 2.0)
	# she always sings the moment she lands, so a blink is never a free reset
	var dir := Vector2.DOWN
	if player != null:
		dir = (player.global_position - global_position).normalized()
	for i in 3:
		_shoot(dir.rotated(deg_to_rad(lerp(-18.0, 18.0, i / 2.0))), 175.0)
	_end_attack(0.65)


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
			player.take_damage(1, global_position)


func melee_radius() -> float:
	return 26.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO,
		crit: bool = false, _knockback: float = 0.0) -> void:
	if state == State.DEAD or state == State.INTRO:
		return
	health -= amount
	_hurt_flash = 0.07
	AudioManager.play_sfx(sfx_hurt, 0.12, -4.0)
	Effects.spawn_damage_number(get_parent(), global_position, amount, crit)
	# porcelain does not shed stuffing; it sheds itself
	Effects.spawn_burst(get_parent(), global_position, Color(0.93, 0.92, 0.95),
		6, 110.0, 2.2)
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
	EventBus.flash.emit(Color(0.85, 0.92, 1.0, 0.3), 0.25)
	Effects.spawn_pop(get_parent(), global_position, 3.0)
	Effects.spawn_burst(get_parent(), global_position, Color(0.93, 0.92, 0.95),
		30, 200.0, 3.4)
	EventBus.toast.emit("A NOTE CRACKS" if p == 2 else "THE CHOIR JOINS IN",
		Color(0.8, 0.86, 1.0))
	_end_attack(0.5)


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	$HurtBox.set_deferred("monitoring", false)
	anim.play(&"death", true)
	AudioManager.play_sfx(sfx_death, 0.0, 2.0)
	AudioManager.stop_music()
	EventBus.screen_shake.emit(13.0, 1.2)
	Effects.spawn_pop(get_parent(), global_position, 4.2)
	Effects.spawn_burst(get_parent(), global_position, Color(0.95, 0.94, 0.97),
		48, 250.0, 4.0)
	EventBus.boss_defeated.emit(self)
	EventBus.toast.emit("THE PORCELAIN CHOIR IS QUIET", Color(0.85, 0.9, 1.0))
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(queue_free)
