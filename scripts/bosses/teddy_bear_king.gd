extends CharacterBody2D

## THE TEDDY BEAR KING
##
## Three phases, each adding an attack rather than replacing one, so the fight
## escalates visibly. The intro plays it completely straight — screen shake,
## enormous orchestral-ish sting, title card — and then he squeaks. The game
## never acknowledges the joke, which is what makes it work.

const PROJECTILE := preload("res://scenes/enemies/EnemyProjectile.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

@export var base_health: float = 220.0
var floor_index: int = 0

enum State { INTRO, IDLE, SLAM, BARRAGE, SUMMON, CHARGE, SWEEP, DEAD }

var state: State = State.INTRO
var phase: int = 1
var health: float
var max_health: float
var player: Node2D = null

var _timer: float = 0.0
var _cooldown: float = 1.2
var _hurt_flash: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _minions: int = 0

@onready var anim: SheetAnimator = $SheetAnimator

var sfx_roar: AudioStream = preload("res://assets/audio/sfx/boss_roar.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/sfx/boss_hurt.wav")
var sfx_death: AudioStream = preload("res://assets/audio/sfx/boss_death.wav")
var sfx_squeak: AudioStream = preload("res://assets/audio/sfx/teddy_squeak.wav")
var sfx_slam: AudioStream = preload("res://assets/audio/sfx/impact_heavy.wav")


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
	EventBus.boss_spawned.emit(self, "THE TEDDY BEAR KING")
	EventBus.boss_intro_started.emit("THE TEDDY BEAR KING", "Sovereign of the Nursery")
	AudioManager.play_sfx(sfx_roar, 0.0, 3.0)
	EventBus.screen_shake.emit(9.0, 1.4)
	anim.play(&"idle")

	# 1.5s of pure gravity, then the squeak lands in the silence
	await get_tree().create_timer(1.55).timeout
	AudioManager.play_sfx(sfx_squeak, 0.0, 2.0)
	EventBus.screen_shake.emit(1.0, 0.2)
	await get_tree().create_timer(1.1).timeout
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
	var dir := to.normalized()

	match state:
		State.IDLE:
			velocity = velocity.move_toward(dir * (26.0 + 10.0 * phase), 220.0 * delta)
			anim.play(&"walk" if velocity.length() > 8.0 else &"idle")
			if _cooldown <= 0.0:
				_choose_attack(to.length())

		State.SLAM:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if _timer <= 0.0:
				_do_slam()

		State.BARRAGE:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if _timer <= 0.0:
				_do_barrage()

		State.SUMMON:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_do_summon()

		State.SWEEP:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _timer <= 0.0:
				_do_sweep()

		State.CHARGE:
			if _timer > 0.0:
				# telegraph: pull back, tracking slowly
				velocity = -_charge_dir * 40.0
				_charge_dir = _charge_dir.lerp(dir, 0.05).normalized()
			else:
				velocity = _charge_dir * 330.0
				if _timer < -0.9:
					_end_attack(1.0)


## Aim where the player will be, not where they are.
##
## Every boss shot used to fly at the player's current position, so walking in
## a straight line dodged the entire fight. Deliberately under-corrected (0.7)
## so strafing still beats it — the goal is to punish standing still, not to
## make movement pointless.
func _lead(speed: float) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.DOWN
	var to: Vector2 = player.global_position - global_position
	var pv: Vector2 = player.get("velocity") if player.get("velocity") != null else Vector2.ZERO
	if speed <= 1.0:
		return to.normalized()
	return (to + pv * (to.length() / speed) * 0.7).normalized()


func _choose_attack(dist: float) -> void:
	var options := ["slam", "barrage"]
	if phase >= 2:
		options.append("summon")
		options.append("charge")
		options.append("sweep")
	if phase >= 3:
		options.append("barrage")
		options.append("charge")
		options.append("sweep")
	# camping the far corner beat the whole fight: at range he closes with a
	# charge or reaches you with a sweep rather than milling about
	if dist > 210.0:
		options.append("charge")
		options.append("sweep")
	var pick: String = options[randi() % options.size()]
	match pick:
		"slam":
			state = State.SLAM; _timer = 0.55; anim.play(&"attack", true)
		"barrage":
			state = State.BARRAGE; _timer = 0.45; anim.play(&"attack", true)
		"summon":
			state = State.SUMMON; _timer = 0.6; anim.play(&"attack", true)
		"charge":
			state = State.CHARGE; _timer = 0.7
			_charge_dir = (player.global_position - global_position).normalized() \
				if player != null else Vector2.RIGHT
			anim.play(&"attack", true)
		"sweep":
			state = State.SWEEP; _timer = 0.6; anim.play(&"attack", true)


func _do_slam() -> void:
	AudioManager.play_sfx(sfx_slam, 0.05, 2.0)
	EventBus.screen_shake.emit(8.0, 0.45)
	Effects.spawn_burst(get_parent(), global_position + Vector2(0, 16),
		Color(0.75, 0.66, 0.5), 22, 190.0, 4.0)
	var count := 10 + phase * 4
	var base := randf() * TAU
	for i in count:
		_shoot(Vector2.from_angle(base + TAU * float(i) / float(count)), 105.0)
	_end_attack(1.1)


func _do_barrage() -> void:
	AudioManager.play_sfx(sfx_squeak, 0.1, 0.0)
	var dir := _lead(150.0)
	for i in 5:
		_shoot(dir.rotated(deg_to_rad(lerp(-26.0, 26.0, i / 4.0))), 150.0)
	EventBus.screen_shake.emit(2.5, 0.15)
	_end_attack(0.75 if phase >= 3 else 1.0)


## A wall of shots crossing the whole room, with one gap in it.
##
## This is the anti-camping answer the fight was missing: slam and barrage are
## both dodged by simply standing far away in a corner, but a wall has to be
## walked through. The gap is placed away from the player, so it demands a
## commitment to move rather than being a free hit — "clear telegraph, punish
## the mistake", which is the whole point of the pattern.
func _do_sweep() -> void:
	AudioManager.play_sfx(sfx_slam, 0.05, 0.0)
	EventBus.screen_shake.emit(5.0, 0.3)
	var r: Node = get_parent()
	if r == null or not r.has_method("room_rect"):
		_end_attack(1.0)
		return
	var rect: Rect2 = r.room_rect()

	# horizontal wall if the player is above/below us, vertical otherwise
	var to := Vector2.ZERO
	if player != null:
		to = player.global_position - global_position
	var vertical := absf(to.x) > absf(to.y)

	var slots := 11
	var gap := randi() % slots
	if player != null:
		# put the gap somewhere that is NOT where the player already stands
		var along: float = (player.global_position.y - rect.position.y) / rect.size.y \
			if vertical else (player.global_position.x - rect.position.x) / rect.size.x
		var here := clampi(int(along * float(slots)), 0, slots - 1)
		gap = (here + slots / 2 + (randi() % 3) - 1) % slots

	# Spawn inside the playable floor, not on the wall tiles: projectiles
	# collide with layer 1 now, so a shot born in the wall dies instantly.
	const INSET := 40.0
	var inner := Rect2(rect.position + Vector2(INSET, INSET),
		rect.size - Vector2(INSET * 2.0, INSET * 2.0))

	for i in slots:
		if i == gap or i == gap + 1:
			continue
		var t := (float(i) + 0.5) / float(slots)
		var from: Vector2
		var dir: Vector2
		if vertical:
			var go_right := to.x > 0.0
			from = Vector2(inner.position.x if go_right else inner.end.x,
				inner.position.y + inner.size.y * t)
			dir = Vector2.RIGHT if go_right else Vector2.LEFT
		else:
			var go_down := to.y > 0.0
			from = Vector2(inner.position.x + inner.size.x * t,
				inner.position.y if go_down else inner.end.y)
			dir = Vector2.DOWN if go_down else Vector2.UP
		var p := PROJECTILE.instantiate()
		get_parent().add_child(p)
		p.global_position = from
		p.setup(null, dir * (95.0 + 12.0 * float(phase)), 1.0, false, 900.0, 0, false)
	EventBus.toast.emit("GET BEHIND SOMETHING", Color(1, 0.7, 0.55))
	_end_attack(1.5)


func _do_summon() -> void:
	AudioManager.play_sfx(sfx_squeak, 0.2, 1.0)
	var teddy := ContentDB.get_enemy(&"teddy")
	if teddy != null:
		var n := 2 if phase == 2 else 3
		for i in n:
			var e := ENEMY_SCENE.instantiate()
			e.data = teddy
			get_parent().add_child(e)
			var a := TAU * float(i) / float(n) + randf()
			e.global_position = global_position + Vector2.from_angle(a) * 70.0
			e.scale = Vector2(0.75, 0.75)
			_minions += 1
			Effects.spawn_burst(get_parent(), e.global_position,
				Color(0.9, 0.85, 0.7), 8, 90.0, 2.5)
	EventBus.toast.emit("HE CALLS FOR HIS SUBJECTS", Color(1, 0.6, 0.6))
	_end_attack(1.4)


func _shoot(dir: Vector2, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + dir * 26.0
	p.setup(null, dir * speed, 1.0, false, 520.0, 0, false)


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
	if global_position.distance_to(player.global_position) < 46.0:
		if player.has_method("take_damage"):
			player.take_damage(2 if state == State.CHARGE else 1, global_position)


## He is the size of a car; melee should connect at his fur, not his heart.
func melee_radius() -> float:
	return 32.0


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
	AudioManager.play_sfx(sfx_roar, 0.0, 0.0)
	EventBus.screen_shake.emit(10.0, 0.7)
	EventBus.flash.emit(Color(1, 0.9, 0.6, 0.30), 0.25)
	Effects.spawn_pop(get_parent(), global_position, 3.0)
	Effects.spawn_stuffing(get_parent(), global_position, 30, 200.0, 4.0)
	EventBus.toast.emit("THE CROWN SLIPS" if p == 2 else "HE IS COMING APART",
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
	Effects.spawn_pop(get_parent(), global_position, 4.2)
	Effects.spawn_stuffing(get_parent(), global_position, 46, 240.0, 5.0)
	EventBus.boss_defeated.emit(self)
	EventBus.toast.emit("THE TEDDY BEAR KING IS STUFFING", Color(1, 0.9, 0.5))
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "modulate:a", 0.0, 0.7)
	t.tween_callback(queue_free)
