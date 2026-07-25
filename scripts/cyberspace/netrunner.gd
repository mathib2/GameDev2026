extends CharacterBody3D

## The player's avatar inside a construct.
##
## Third-person, floaty, deliberately not a realistic FPS controller — this is
## a digital abstraction, not a place. Kept separate from the 2D Player so
## Developer A and Developer D never edit the same file.

@export var speed: float = 8.0
@export var accel: float = 40.0
@export var jump_velocity: float = 7.0
@export var mouse_sensitivity: float = 0.0025
@export var gravity_enabled: bool = true

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _gravity: float = 18.0
var _pitch: float = -0.25


func _ready() -> void:
	add_to_group("netrunner")
	collision_layer = 2   # "netrunner"
	collision_mask = 1    # "cyberspace_world"
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_speed(v: float) -> void:
	speed = v


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, -1.2, 0.6)
		_pivot.rotation.x = _pitch
	elif event.is_action_pressed(&"abort_hack"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		HackManager.abort()


func _physics_process(delta: float) -> void:
	if HackManager.state != HackManager.State.ACTIVE:
		return

	if gravity_enabled and not is_on_floor():
		velocity.y -= _gravity * delta
	elif is_on_floor() and Input.is_action_just_pressed(&"ui_advance"):
		velocity.y = jump_velocity

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target_h := dir * speed
	velocity.x = move_toward(velocity.x, target_h.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_h.z, accel * delta)

	if not gravity_enabled:
		velocity.y = move_toward(velocity.y, 0.0, accel * delta)

	move_and_slide()
