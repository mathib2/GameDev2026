extends Node

## Game feel. Autoload: GameFeel
##
## Screen shake and hit stop. Both are deliberately short and punchy — the brief
## prioritises "the player should immediately feel when they hit an enemy", and
## the cheapest way to get that is a few frames of frozen time plus a shove of
## the camera.
##
## Runs with PROCESS_MODE_ALWAYS so hit stop (which sets time_scale to ~0) can
## still tick itself back down.

var _shake_amount: float = 0.0
var _shake_decay: float = 12.0
var _hitstop_left: float = 0.0

var camera: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.screen_shake.connect(shake)
	EventBus.hit_stop.connect(stop)


func _process(delta: float) -> void:
	# hit stop uses unscaled time or it would never expire
	var real := delta / maxf(0.0001, Engine.time_scale)
	if _hitstop_left > 0.0:
		_hitstop_left -= real
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0

	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - _shake_decay * real)
		if camera != null and is_instance_valid(camera):
			camera.offset = Vector2(
				randf_range(-_shake_amount, _shake_amount),
				randf_range(-_shake_amount, _shake_amount))
	elif camera != null and is_instance_valid(camera):
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.35)


## Additive so several hits in a frame stack, capped so it stays readable.
func shake(strength: float, duration: float = 0.0) -> void:
	_shake_amount = minf(14.0, _shake_amount + strength)
	if duration > 0.0:
		_shake_decay = strength / maxf(0.01, duration)
	else:
		_shake_decay = 12.0


func stop(duration: float) -> void:
	if duration <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	Engine.time_scale = 0.02


func reset() -> void:
	_shake_amount = 0.0
	_hitstop_left = 0.0
	Engine.time_scale = 1.0
	if camera != null and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
