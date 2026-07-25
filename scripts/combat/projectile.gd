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

var _travelled: float = 0.0
var _hit: Array = []

@onready var _sprite: Sprite2D = $Sprite2D


func setup(p_texture: Texture2D, p_velocity: Vector2, p_damage: float,
		p_friendly: bool, p_range: float, p_pierce: int = 0, p_crit: bool = false) -> void:
	velocity = p_velocity
	damage = p_damage
	friendly = p_friendly
	max_distance = p_range
	pierce = p_pierce
	crit = p_crit
	if p_texture != null:
		if _sprite == null:
			_sprite = get_node_or_null("Sprite2D")
		if _sprite != null:
			_sprite.texture = p_texture


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	# friendly shots look for enemies (layer 4), enemy shots for the player (2)
	collision_mask = 4 if friendly else 2
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	if _sprite != null:
		_sprite.rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if friendly and _sprite != null:
		_sprite.rotation += delta * 16.0
	if _travelled >= max_distance:
		_expire()


func _on_hit(node: Node) -> void:
	if node == null or node in _hit:
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
	Effects.spawn_impact(get_parent(), global_position)
	queue_free()
