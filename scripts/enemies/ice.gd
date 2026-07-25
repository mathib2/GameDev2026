extends CharacterBody3D

## ICE — Intrusion Countermeasures Electronics.
##
## Defensive programs patrolling a construct. Touching one adds trace rather
## than dealing damage: the fail state of a hack is being *noticed*, not being
## killed, which suits a game about doing crimes to a vending machine.

@export var data: EnemyData
@export var speed: float = 4.0
@export var detection_radius: float = 14.0
@export var trace_on_contact: float = 0.18
@export var contact_cooldown: float = 1.5

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _target: Node3D = null
var _cooldown: float = 0.0
var _home: Vector3
var _drift: float = 0.0


func _ready() -> void:
	add_to_group("ice")
	collision_layer = 4   # "ice"
	collision_mask = 1    # "cyberspace_world"
	_home = global_position
	_drift = randf() * TAU
	if data != null:
		speed = data.move_speed / 20.0
		detection_radius = data.detection_radius / 10.0
		trace_on_contact = data.trace_contribution / 100.0
		if data.mesh != null:
			_mesh.mesh = data.mesh


func _physics_process(delta: float) -> void:
	if HackManager.state != HackManager.State.ACTIVE:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_drift += delta

	if _target == null:
		var runners := get_tree().get_nodes_in_group("netrunner")
		if not runners.is_empty():
			_target = runners[0]

	if _target != null and global_position.distance_to(_target.global_position) < detection_radius:
		var dir := (_target.global_position - global_position).normalized()
		velocity = dir * speed
		if global_position.distance_to(_target.global_position) < 1.6 and _cooldown <= 0.0:
			_cooldown = contact_cooldown
			HackManager.add_trace(trace_on_contact)
			EventBus.screen_shake_requested.emit(4.0)
	else:
		# idle bob around spawn
		var offset := Vector3(cos(_drift) * 3.0, sin(_drift * 0.7) * 0.5, sin(_drift) * 3.0)
		velocity = (_home + offset - global_position) * 1.5

	move_and_slide()
	rotate_y(delta * 2.0)
