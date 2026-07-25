extends Area2D

## Shared projectile for both sides. `friendly` decides who it can hurt.
##
## Damage is delivered by calling take_damage() on the target. Enemies and the
## player expose different signatures (enemies care about crits and knockback,
## the player does not), so the branch is explicit rather than duck-typed.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 1.0
var friendly: bool = true
var pierce: int = 0
var crit: bool = false
var max_distance: float = 320.0
var knockback: float = 120.0

## Degrees per second the sprite tumbles. Bullets point where they are going
## (0); a thrown ball or a sawblade wants to spin.
var spin_speed: float = 0.0

var _travelled: float = 0.0
var _hit: Array = []
var _dead: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func setup(p_texture: Texture2D, p_velocity: Vector2, p_damage: float,
		p_friendly: bool, p_range: float, p_pierce: int = 0, p_crit: bool = false) -> void:
	velocity = p_velocity
	damage = p_damage
	friendly = p_friendly
	max_distance = p_range
	pierce = p_pierce
	crit = p_crit
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D")
	if _sprite != null:
		if p_texture != null:
			_sprite.texture = p_texture
		# Callers add_child() first and setup() second, so _ready() has already
		# run by now with velocity still zero — orienting there pointed every
		# shot due east. Orient here, where the direction is actually known.
		if spin_speed == 0.0 and velocity != Vector2.ZERO:
			_sprite.rotation = velocity.angle()
	# _ready() has also already fixed the mask from the default `friendly`;
	# redo it in case the caller flipped the side.
	_apply_mask()


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	_apply_mask()
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


## Layer 1 is walls and cover, 2 the player, 4 enemies. Shots used to omit
## layer 1 entirely, so every projectile sailed through the room wall and
## expired somewhere out in the void.
func _apply_mask() -> void:
	collision_mask = (1 | 4) if friendly else (1 | 2)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if _sprite != null and spin_speed != 0.0:
		_sprite.rotation += delta * spin_speed
	if _travelled >= max_distance:
		_expire()


func _on_hit(node: Node) -> void:
	if node == null or _dead or node in _hit:
		return
	# a room wall eats the shot from either side
	if node.is_in_group("wall"):
		_expire()
		return
	# cover stops shots from either side, and breaks doing it
	if node.is_in_group("breakable"):
		_hit.append(node)
		if node.has_method("take_damage"):
			node.take_damage(damage, global_position, false, 0.0)
		_expire()
		return
	if friendly:
		if not node.is_in_group("enemy"):
			return
		_hit.append(node)
		if node.has_method("take_damage"):
			node.take_damage(damage, global_position, crit, knockback)
	else:
		if not node.is_in_group("player"):
			return
		_hit.append(node)
		if node.has_method("take_damage"):
			node.take_damage(maxi(1, int(round(damage))), global_position)
	if pierce > 0:
		pierce -= 1
	else:
		_expire()


func _expire() -> void:
	# reaching max range on the same frame as a hit would otherwise free twice
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	Effects.spawn_impact(get_parent(), global_position)
	queue_free()
