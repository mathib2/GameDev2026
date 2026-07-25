extends Area2D

## A weapon on a plinth. Taking it is a swap — your old weapon stays
## behind on the pedestal, so the choice is never a loss.

@export var weapon: WeaponData
@export var price: int = 0

var _t: float = 0.0
var _in_range: bool = false

@onready var _icon: Sprite2D = $Icon
@onready var _label: Label = $Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b.is_in_group("player"): _in_range = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _in_range = false)
	_refresh()


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
	_label.visible = _in_range and weapon != null
	if _in_range and weapon != null and Input.is_action_just_pressed(&"interact"):
		_collect()


func _collect() -> void:
	if price > 0 and not GameState.spend(price):
		EventBus.toast.emit("NOT ENOUGH COINS", Color(1, 0.5, 0.5))
		return
	price = 0    # once bought, the leftover swap is free to take back
	var old: WeaponData = GameState.weapon
	GameState.equip(weapon)
	AudioManager.play_sfx(weapon.sfx_use if weapon.sfx_use
		else preload("res://assets/audio/sfx/pickup_item.wav"))
	EventBus.toast.emit("%s EQUIPPED" % weapon.display_name.to_upper(), Color(0.7, 0.9, 1.0))
	EventBus.screen_shake.emit(3.0, 0.2)
	Effects.spawn_burst(get_parent(), global_position, Color(0.7, 0.9, 1.0), 18, 120.0, 3.0)
	# leave the old weapon on the plinth so it reads as a swap
	weapon = old if (old != null and old.id != &"fists") else null
	_refresh()
