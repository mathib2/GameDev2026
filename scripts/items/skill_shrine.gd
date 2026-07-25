extends Area2D

## A skill shrine. Walk into it, pay coins, get one permanent level.
##
## Uses the same walk-into-it language as chests and pedestals rather than an
## interact key or a menu, so buying an upgrade never stops the game. Buying
## requires stepping *off* and back on: standing on a shrine with 90 coins
## should not silently drain all of them.
##
## Which skills exist lives in GameState.SKILLS — this script only spends coins
## and draws what it is told.

const TEX := preload("res://assets/environment/prop_shrine.png")

## Colour per skill, so the five shrines are distinguishable at a glance
## without reading the label.
const TINTS := {
	&"vitality": Color(1.0, 0.42, 0.46),
	&"power": Color(1.0, 0.62, 0.28),
	&"reflexes": Color(0.45, 0.85, 1.0),
	&"footwork": Color(0.55, 1.0, 0.62),
	&"focus": Color(1.0, 0.86, 0.35),
}

var skill_id: StringName = &"vitality"

var _armed: bool = true
var _sprite: Sprite2D
var _title: Label
var _sub: Label

var sfx_buy: AudioStream = preload("res://assets/audio/sfx/ui_confirm.wav")
var sfx_deny: AudioStream = preload("res://assets/audio/sfx/ui_select.wav")


func _ready() -> void:
	add_to_group("shrine")
	collision_layer = 0
	collision_mask = 2
	z_index = 1

	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.hframes = 2
	_sprite.frame = 0
	_sprite.modulate = TINTS.get(skill_id, Color.WHITE)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 20)
	col.shape = shape
	add_child(col)

	_title = _make_label(-34, 14)
	_sub = _make_label(-24, 11)
	_sub.position.y = -30
	_title.position.y = -44
	add_child(_title)
	add_child(_sub)
	_refresh()

	body_entered.connect(_on_entered)
	body_exited.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			_armed = true)


func _make_label(x: float, size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _refresh() -> void:
	var def: Dictionary = GameState.SKILLS.get(skill_id, {})
	var lvl := GameState.skill_level(skill_id)
	var tint: Color = TINTS.get(skill_id, Color.WHITE)
	_title.text = "%s %s" % [def.get("name", "SKILL"),
		"●".repeat(lvl) + "○".repeat(GameState.SKILL_MAX - lvl)]
	_title.add_theme_color_override("font_color", tint)
	if GameState.skill_maxed(skill_id):
		_sub.text = "MAXED"
		_sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		_sprite.frame = 1
	else:
		_sub.text = "%d COINS — %s" % [GameState.skill_cost(skill_id),
			def.get("blurb", "")]
		_sub.add_theme_color_override("font_color", Color(1, 0.86, 0.32))


func _on_entered(body: Node) -> void:
	if not _armed or not body.is_in_group("player"):
		return
	_armed = false
	if GameState.skill_maxed(skill_id):
		AudioManager.play_sfx(sfx_deny, 0.0, -6.0)
		return
	var cost := GameState.skill_cost(skill_id)
	if not GameState.upgrade_skill(skill_id):
		AudioManager.play_sfx(sfx_deny, 0.0, -4.0)
		EventBus.toast.emit("NEED %d COINS" % cost, Color(1, 0.5, 0.45))
		return

	var def: Dictionary = GameState.SKILLS.get(skill_id, {})
	AudioManager.play_sfx(sfx_buy, 0.05, 2.0)
	EventBus.toast.emit("%s %d" % [def.get("name", "SKILL"),
		GameState.skill_level(skill_id)], TINTS.get(skill_id, Color.WHITE))
	EventBus.screen_shake.emit(2.5, 0.18)
	Effects.spawn_pop(get_parent(), global_position + Vector2(0, -8), 1.8)
	Effects.spawn_burst(get_parent(), global_position + Vector2(0, -8),
		TINTS.get(skill_id, Color.WHITE), 14, 110.0, 2.4)
	_refresh()

	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.3, 0.8), 0.08)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
