extends StaticBody2D

## Destructible cover. The prototype's crates were load-bearing, not
## cosmetic: they block movement and player shots until smashed, then
## sometimes cough up a coin. Builds its own children so rooms can
## spawn it with script.new().

const CRATE_TEX := preload("res://assets/environment/prop_crate.png")

var health: float = 5.0
var _sprite: Sprite2D
var _flash: float = 0.0

var sfx_hit: AudioStream = preload("res://assets/audio/sfx/block_thud.wav")


func _ready() -> void:
	add_to_group("breakable")
	# 1 = wall (bodies collide), 2 = enemy shots, 4 = player shots
	collision_layer = 1 | 2 | 4
	collision_mask = 0

	_sprite = Sprite2D.new()
	_sprite.texture = CRATE_TEX
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	col.shape = rect
	add_child(col)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(4, 4, 4) if _flash > 0.0 else Color.WHITE


func melee_radius() -> float:
	return 9.0


func take_damage(amount: float, _from: Vector2 = Vector2.ZERO,
		_crit: bool = false, _knockback: float = 0.0) -> void:
	health -= amount
	_flash = 0.06
	AudioManager.play_sfx(sfx_hit, 0.2, -8.0)
	if health <= 0.0:
		_break()


## What a smashed crate can cough up.
##
## The rare tail is deliberately thin: a crate that hands out a weapon one time
## in forty is a small thrill every time it happens, while one that does it
## every fifth crate would make the treasure room pointless. The common cases
## still dominate — most crates give you nothing, which is what makes the good
## ones register at all.
const DROPS := [
	{"kind": "weapon", "chance": 0.025},
	{"kind": "item",   "chance": 0.020},
	{"kind": "skill",  "chance": 0.015},
	{"kind": "heart",  "chance": 0.070},
	{"kind": "coin",   "chance": 0.340},
]


func _break() -> void:
	Effects.spawn_burst(get_parent(), global_position, Color(0.62, 0.45, 0.28), 12, 110.0, 3.0)
	var room := get_parent()
	if room != null and is_instance_valid(room) and room.has_method("forget_crate"):
		# record the death before we free ourselves, or the room rebuilds this
		# crate the next time the player walks back in
		room.forget_crate(position)
	if room != null and is_instance_valid(room) and room.has_method("spawn_crate_drop"):
		var roll := randf()
		var acc := 0.0
		for d in DROPS:
			acc += float(d["chance"])
			if roll < acc:
				# Deferred because this runs from a melee sweep or a projectile
				# hit, both mid-physics — and deferred *on the room*, not on
				# self: this crate is about to queue_free(), and Godot silently
				# drops deferred calls to a freed object, so the reward would
				# vanish exactly when it mattered.
				room.spawn_crate_drop.call_deferred(String(d["kind"]), global_position)
				break
	queue_free()
