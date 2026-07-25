extends Node

## Root scene. Deliberately almost empty.
##
## Main owns two containers and hands them to SceneRouter. It contains no
## gameplay, no NPCs, no maps, and no hack logic — which is what stops six
## people from having to edit it. If you find yourself adding game code here,
## it belongs in a system or a scene instead.

@export var starting_location: StringName = &"neon_district"

@onready var world: Node = $World
@onready var overlay: CanvasLayer = $UI


func _ready() -> void:
	SceneRouter.world_container = world
	SceneRouter.overlay_container = overlay
	EventBus.game_started.emit()

	if not SceneRouter.goto_location(starting_location):
		push_error("[Main] could not load starting location '%s'. "
			% starting_location
			+ "Check that a LocationData with that id exists in res://data/locations/.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not HackManager.is_active():
		# Placeholder for a pause menu — scenes/menus/PauseMenu.tscn.
		pass
