extends Node

## Scene transitions. Autoload: SceneRouter
##
## Owns the 2D world <-> 3D cyberspace handoff, which is the one flow that
## genuinely needs a central coordinator. Maps do not know about each other and
## cyberspace scenes do not know what launched them.
##
## The 2D world is *suspended*, not unloaded, so returning from a hack restores
## the player exactly where they stood.

var world_container: Node = null      ## set by Main
var overlay_container: Node = null    ## set by Main

var _current_world: Node = null
var _current_cyberspace: Node = null
var _suspended_world: Node = null


func _ready() -> void:
	EventBus.cyberspace_exited.connect(_on_cyberspace_exited)


## Loads a 2D location by LocationData id, replacing the current one.
func goto_location(location_id: StringName) -> bool:
	var loc := ContentDB.get_location(location_id)
	if loc == null:
		push_error("[SceneRouter] unknown location '%s'" % location_id)
		return false
	if not loc.is_accessible():
		EventBus.toast_requested.emit("That area is locked.")
		return false
	if not ResourceLoader.exists(loc.scene_path):
		push_error("[SceneRouter] location '%s' points at a missing scene: %s"
			% [location_id, loc.scene_path])
		return false

	var packed: PackedScene = load(loc.scene_path)
	var inst := packed.instantiate()
	if _current_world != null:
		_current_world.queue_free()
	_current_world = inst
	world_container.add_child(inst)

	GameState.current_location = location_id
	AudioManager.play_music(loc.music)
	AudioManager.play_ambience(loc.ambience)
	EventBus.location_changed.emit(location_id)
	return true


## Suspends the 2D world and instances the 3D construct for `target`.
func enter_cyberspace(target: HackTargetData) -> bool:
	if target == null or target.cyberspace == null:
		push_error("[SceneRouter] hack target has no cyberspace assigned")
		return false
	var cs := target.cyberspace
	if not ResourceLoader.exists(cs.scene_path):
		push_error("[SceneRouter] construct '%s' points at a missing scene: %s"
			% [cs.id, cs.scene_path])
		return false

	# Suspend rather than free — we need the exact world state back afterwards.
	if _current_world != null:
		_suspended_world = _current_world
		_suspended_world.process_mode = Node.PROCESS_MODE_DISABLED
		_suspended_world.visible = false

	var packed: PackedScene = load(cs.scene_path)
	_current_cyberspace = packed.instantiate()
	world_container.add_child(_current_cyberspace)

	if _current_cyberspace.has_method("configure"):
		_current_cyberspace.configure(target)

	AudioManager.play_music(cs.music)
	AudioManager.play_ambience(cs.ambience)
	EventBus.cyberspace_entered.emit(target)
	return true


func _on_cyberspace_exited(_target: HackTargetData, _success: bool) -> void:
	if _current_cyberspace != null:
		_current_cyberspace.queue_free()
		_current_cyberspace = null
	if _suspended_world != null:
		_suspended_world.process_mode = Node.PROCESS_MODE_INHERIT
		_suspended_world.visible = true
		_current_world = _suspended_world
		_suspended_world = null
		var loc := ContentDB.get_location(GameState.current_location)
		if loc != null:
			AudioManager.play_music(loc.music)
			AudioManager.play_ambience(loc.ambience)


func current_world() -> Node:
	return _current_world


func in_cyberspace() -> bool:
	return _current_cyberspace != null
