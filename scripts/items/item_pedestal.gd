extends Area2D

## An item on a plinth. Free in treasure rooms, priced in shops.

@export var item: ItemData
@export var price: int = 0

var _taken: bool = false
var _t: float = 0.0
var _in_range: bool = false

@onready var _icon: Sprite2D = $Icon
@onready var _label: Label = $Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b): if b.is_in_group("player"): _in_range = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _in_range = false)
	if item != null and item.icon != null:
		_icon.texture = item.icon
	_refresh_label()


func _refresh_label() -> void:
	if item == null:
		_label.text = ""
		return
	if price > 0:
		_label.text = "%s — %d¢\n[E]" % [item.display_name, price]
	else:
		_label.text = "%s\n[E]" % item.display_name


func _process(delta: float) -> void:
	_t += delta * 3.0
	_icon.position.y = -18.0 + sin(_t) * 2.0
	_label.visible = _in_range and not _taken
	if price > 0 and not _taken:
		# unaffordable reads red at a glance
		_label.self_modulate = Color(1, 0.5, 0.5) if GameState.coins < price else Color.WHITE
	if _in_range and not _taken and Input.is_action_just_pressed(&"interact"):
		_collect()


func _collect() -> void:
	if item == null:
		return
	if price > 0 and not GameState.spend(price):
		EventBus.toast.emit("NOT ENOUGH COINS", Color(1, 0.5, 0.5))
		return
	_taken = true
	var roll_text := GameState.add_item(item)
	AudioManager.play_sfx(item.sfx_pickup if item.sfx_pickup
		else preload("res://assets/audio/sfx/pickup_item.wav"))
	# Mystery items announce what they rolled instead of their flavour line.
	var line := roll_text if roll_text != "" else item.flavour
	EventBus.toast.emit("%s — %s" % [item.display_name.to_upper(), line],
		Color(1, 0.9, 0.5))
	EventBus.screen_shake.emit(3.0, 0.2)
	Effects.spawn_burst(get_parent(), global_position, Color(1, 0.9, 0.4), 18, 120.0, 3.0)
	_icon.visible = false
	_label.visible = false
