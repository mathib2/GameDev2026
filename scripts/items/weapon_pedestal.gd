extends Area2D

## A weapon on a plinth. Taking it is a swap — your old weapon stays
## behind on the pedestal, so the choice is never a loss.

@export var weapon: WeaponData
@export var price: int = 0

var _t: float = 0.0
## The player standing at the plinth — in co-op, who the swap belongs to.
var _shopper: Node2D = null

@onready var _icon: Sprite2D = $Icon
@onready var _glow: Sprite2D = $Icon/Glow
@onready var _label: Label = $Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 10)
	col.shape = rect
	solid.add_child(col)
	add_child(solid)
	body_entered.connect(func(b): if b.is_in_group("player"): _shopper = b)
	body_exited.connect(func(b):
		if b != _shopper:
			return
		_shopper = null
		for other in get_overlapping_bodies():
			if other.is_in_group("player"):
				_shopper = other)
	_refresh()

	# soft breathing halo, so the weapon reads as pickable rather than as scenery
	var glow_t := create_tween().set_loops()
	glow_t.tween_property(_glow, "modulate:a", 0.65, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_t.tween_property(_glow, "modulate:a", 0.3, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _refresh() -> void:
	if weapon == null:
		_icon.visible = false
		_label.text = ""
		return
	_icon.visible = true
	if weapon.icon != null:
		_icon.texture = weapon.icon
	if price > 0:
		_label.text = "%s — %d¢\n[E] swap" % [weapon.display_name, price]
	else:
		_label.text = "%s\n[E] swap" % weapon.display_name


func _process(delta: float) -> void:
	_t += delta * 3.0
	_icon.position.y = -18.0 + sin(_t) * 2.0
	_label.visible = _shopper != null and weapon != null
	if _shopper != null and weapon != null \
			and Input.is_action_just_pressed(_shopper.interact_action()):
		_collect()


func _collect() -> void:
	if price > 0 and not GameState.spend(price):
		EventBus.toast.emit("NOT ENOUGH COINS", Color(1, 0.5, 0.5))
		return
	price = 0    # once bought, the leftover swap is free to take back
	var buyer: int = _shopper.player_index if _shopper != null else 0
	var old: WeaponData = GameState.weapon_of(buyer)
	GameState.equip(weapon, buyer)
	AudioManager.play_sfx(weapon.sfx_use if weapon.sfx_use
		else preload("res://assets/audio/sfx/pickup_item.wav"))
	EventBus.toast.emit("%s EQUIPPED" % weapon.display_name.to_upper(), Color(0.7, 0.9, 1.0))
	EventBus.screen_shake.emit(3.0, 0.2)
	Effects.spawn_burst(get_parent(), global_position, Color(0.7, 0.9, 1.0), 18, 120.0, 3.0)
	# leave the old weapon on the plinth so it reads as a swap
	weapon = old if (old != null and old.id != &"fists") else null
	_refresh()
