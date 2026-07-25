extends Area2D

## A toy chest. Walk into it and it coughs up loot.
##
## Isaac's chests are a reward you *walk into*, not a prompt you answer, so
## there is no interact key here — touching it is the whole interaction.
## Builds its own children so rooms can spawn it with script.new(), the same
## way breakable.gd does.

const TEX := preload("res://assets/environment/prop_chest.png")
const TEX_GOLD := preload("res://assets/environment/prop_chest_gold.png")

## Gold chests cost coins and pay out an item or a weapon; wooden ones are
## free and pay out consumables.
var gold: bool = false
var price: int = 0

var _opened: bool = false
var _sprite: Sprite2D
var _label: Label

var sfx_open: AudioStream = preload("res://assets/audio/sfx/door_open.wav")
var sfx_deny: AudioStream = preload("res://assets/audio/sfx/ui_select.wav")


func _ready() -> void:
	add_to_group("chest")
	collision_layer = 0
	collision_mask = 2                      # the player only
	z_index = 1

	_sprite = Sprite2D.new()
	_sprite.texture = TEX_GOLD if gold else TEX
	_sprite.hframes = 2
	_sprite.frame = 0
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 18)
	col.shape = shape
	add_child(col)

	if price > 0:
		_label = Label.new()
		_label.text = "%d" % price
		_label.position = Vector2(-8, -30)
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", Color(1, 0.86, 0.32))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 4)
		add_child(_label)

	# idle bob, so a closed chest reads as interactive rather than as scenery
	var t := create_tween().set_loops()
	t.tween_property(_sprite, "position:y", -2.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_sprite, "position:y", 0.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_entered.connect(_on_touched)


func _on_touched(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	if price > 0:
		if GameState.coins < price:
			AudioManager.play_sfx(sfx_deny, 0.0, -4.0)
			EventBus.toast.emit("NEED %d COINS" % price, Color(1, 0.5, 0.45))
			return
		GameState.spend(price)
	_open()


func _open() -> void:
	_opened = true
	_sprite.frame = 1
	if _label != null:
		_label.queue_free()
	AudioManager.play_sfx(sfx_open, 0.1)
	EventBus.screen_shake.emit(2.0, 0.15)
	Effects.spawn_burst(get_parent(), global_position + Vector2(0, -6),
		Color(1.0, 0.9, 0.55), 14, 120.0, 2.5)
	set_deferred("monitoring", false)
	# body_entered fires mid-physics; spawning loot bodies there trips
	# "Can't change this state while flushing queries" — see run_manager.
	_spill.call_deferred()


func _spill() -> void:
	var room := get_parent()
	if room == null or not is_instance_valid(room):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if gold:
		# a paid chest owes you something that changes the run
		if rng.randf() < 0.45 and room.has_method("_spawn_weapon_pedestal"):
			room._spawn_weapon_pedestal(global_position + Vector2(0, 26))
		elif room.has_method("_spawn_pedestal"):
			room._spawn_pedestal(global_position + Vector2(0, 26))
		for i in rng.randi_range(3, 6):
			_toss(room, "coin", rng)
		return

	for i in rng.randi_range(2, 5):
		_toss(room, "coin", rng)
	if rng.randf() < 0.3:
		_toss(room, "heart", rng)


func _toss(room: Node, kind: String, rng: RandomNumberGenerator) -> void:
	if not room.has_method("spawn_pickup"):
		return
	var ang := rng.randf_range(0.0, TAU)
	room.spawn_pickup(kind, global_position
		+ Vector2.from_angle(ang) * rng.randf_range(14.0, 30.0) + Vector2(0, 6))
