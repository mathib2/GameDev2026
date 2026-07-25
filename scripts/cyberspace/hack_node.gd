extends Area3D

## A capturable node inside a construct. Stand in it to break it.
##
## Level designers place these by hand or let CyberspaceScene scatter them.
## Capturing enough of them (HackTargetData.required_nodes) wins the intrusion.

@export var capture_time: float = 2.0
@export var label_text: String = "NODE"

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _progress: float = 0.0
var _captured: bool = false
var _occupied: bool = false


func _ready() -> void:
	add_to_group("hack_node")
	collision_layer = 1
	collision_mask = 2   # "netrunner"
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _process(delta: float) -> void:
	if _captured:
		rotate_y(delta * 0.5)
		return
	rotate_y(delta * 1.5)
	if not _occupied:
		_progress = maxf(0.0, _progress - delta * 0.5)
		_refresh()
		return
	_progress += delta
	_refresh()
	if _progress >= capture_time:
		_capture()


func _refresh() -> void:
	if _mesh == null:
		return
	var f: float = clampf(_progress / maxf(0.01, capture_time), 0.0, 1.0)
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).emission_energy_multiplier = 1.0 + f * 5.0


func _capture() -> void:
	if _captured:
		return
	_captured = true
	_occupied = false
	scale = Vector3.ONE * 0.6
	HackManager.capture_node()


func _on_enter(body: Node3D) -> void:
	if _captured:
		return
	if body.is_in_group("netrunner"):
		_occupied = true


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("netrunner"):
		_occupied = false


func is_captured() -> bool:
	return _captured
