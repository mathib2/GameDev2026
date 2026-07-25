class_name CyberspaceScene
extends Node3D

## Base class for every 3D construct.
##
## The 3D team subclasses this (or just instances it and builds geometry as
## children). SceneRouter calls configure() with the HackTargetData that opened
## it; everything after that is local to the construct.
##
## Contract for a construct scene:
##   - root extends CyberspaceScene
##   - contains a Netrunner (the player avatar) or lets this class spawn one
##   - contains HackNode children marked with the "hack_node" group
##
## Spawn points, node counts and ICE counts are driven by HackTargetData, so
## one construct can serve several targets at different difficulties.

const NETRUNNER_SCENE := preload("res://scenes/cyberspace/Netrunner.tscn")
const HACK_NODE_SCENE := preload("res://scenes/cyberspace/HackNode.tscn")
const ICE_SCENE := preload("res://scenes/cyberspace/ICE.tscn")

@export var node_spawn_root: NodePath
@export var ice_spawn_root: NodePath
@export var runner_spawn: NodePath

var target: HackTargetData
var _runner: Node3D


func configure(t: HackTargetData) -> void:
	target = t
	_apply_look()
	_spawn_runner()
	_spawn_nodes()
	_spawn_ice()


func _apply_look() -> void:
	if target == null or target.cyberspace == null:
		return
	var cs := target.cyberspace
	var env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env != null and env.environment != null:
		env.environment.fog_light_color = cs.fog_color
		env.environment.ambient_light_energy = cs.ambient_energy


func _spawn_runner() -> void:
	if _runner != null:
		return
	_runner = NETRUNNER_SCENE.instantiate()
	add_child(_runner)
	var sp := get_node_or_null(runner_spawn) as Node3D
	if sp != null:
		_runner.global_position = sp.global_position
	if target != null and target.cyberspace != null and _runner.has_method("set_speed"):
		_runner.set_speed(target.cyberspace.runner_speed)


## Uses hand-placed markers if the level author provided them, otherwise falls
## back to a ring. Level designers can ignore this entirely and just place
## HackNode scenes by hand — those are picked up by group.
func _spawn_nodes() -> void:
	var existing := get_tree().get_nodes_in_group("hack_node")
	var needed: int = target.required_nodes if target != null else 3
	if existing.size() >= needed:
		return
	var root := get_node_or_null(node_spawn_root) as Node3D
	var markers: Array = []
	if root != null:
		for c in root.get_children():
			if c is Node3D:
				markers.append(c)
	for i in range(existing.size(), needed):
		var n := HACK_NODE_SCENE.instantiate()
		add_child(n)
		if i < markers.size():
			n.global_position = markers[i].global_position
		else:
			var a := TAU * float(i) / float(maxi(1, needed))
			n.global_position = Vector3(cos(a) * 14.0, 1.5, sin(a) * 14.0)


func _spawn_ice() -> void:
	if target == null or target.ice_count <= 0:
		return
	var root := get_node_or_null(ice_spawn_root) as Node3D
	var markers: Array = []
	if root != null:
		for c in root.get_children():
			if c is Node3D:
				markers.append(c)
	for i in target.ice_count:
		var ice := ICE_SCENE.instantiate()
		add_child(ice)
		if i < markers.size():
			ice.global_position = markers[i].global_position
		else:
			var a := TAU * float(i) / float(target.ice_count) + 0.5
			ice.global_position = Vector3(cos(a) * 9.0, 1.0, sin(a) * 9.0)


func runner() -> Node3D:
	return _runner
