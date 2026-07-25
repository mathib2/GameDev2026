extends Node

## Visual effects. Autoload: Effects
##
## Small pooled/one-shot visuals spawned from anywhere. Keeping them here means
## combat code says "spawn an impact" without owning any particle setup.

const IMPACT_TEX := preload("res://assets/effects/fx_impact.png")

var _font: Font = ThemeDB.fallback_font


## Cartoon burst of stuffing / crumbs.
func spawn_burst(parent: Node, pos: Vector2, colour: Color, count: int = 10,
		speed: float = 90.0, size: float = 3.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.55
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.6
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.color = colour
	parent.add_child(p)
	# A tween owned by the node dies with it. A SceneTreeTimer lambda capturing
	# the node does NOT, and spams "Lambda capture was freed" once the room it
	# lives in is unloaded mid-flight.
	var t := p.create_tween()
	t.tween_interval(1.2)
	t.tween_callback(p.queue_free)


## White stuffing — what comes out of a toy instead of blood.
##
## Deliberately floatier than spawn_burst: low gravity and heavy damping so the
## wadding hangs in the air and drifts down, rather than arcing like debris.
## This is the single most important visual in the game, because it is what
## sells "these are toys" every time something dies.
func spawn_stuffing(parent: Node, pos: Vector2, count: int = 10,
		speed: float = 80.0, size: float = 3.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = count
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 48)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.8
	p.damping_min = 70.0
	p.damping_max = 130.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.color = Color(1, 1, 1)
	# fade the wadding out rather than letting it vanish mid-air
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(0.94, 0.94, 0.9, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	var t := p.create_tween()
	t.tween_interval(1.5)
	t.tween_callback(p.queue_free)


## Expanding white ring. Punctuates a kill so it reads even in a crowd.
func spawn_pop(parent: Node, pos: Vector2, size: float = 2.4) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var s := Sprite2D.new()
	s.texture = IMPACT_TEX
	s.hframes = 4
	s.frame = 1
	s.position = pos
	s.z_index = 45
	s.scale = Vector2(0.4, 0.4)
	s.modulate = Color(1, 1, 1, 0.95)
	parent.add_child(s)
	var t := s.create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(size, size), 0.28)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.28)
	t.chain().tween_callback(s.queue_free)


func spawn_impact(parent: Node, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var s := Sprite2D.new()
	s.texture = IMPACT_TEX
	s.hframes = 4
	s.position = pos
	s.z_index = 40
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "frame", 3, 0.16).from(0)
	t.tween_callback(s.queue_free)


## Floating damage number. Crits are bigger and yellow.
func spawn_damage_number(parent: Node, pos: Vector2, amount: float, crit: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var l := Label.new()
	l.text = str(int(round(amount)))
	l.z_index = 60
	l.position = pos + Vector2(randf_range(-6, 6), -10)
	l.add_theme_font_size_override("font_size", 16 if crit else 11)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.25) if crit else Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position", l.position + Vector2(0, -22), 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.15)
	t.chain().tween_callback(l.queue_free)


func spawn_dust(parent: Node, pos: Vector2) -> void:
	spawn_burst(parent, pos, Color(0.72, 0.66, 0.55, 0.7), 5, 45.0, 2.0)
