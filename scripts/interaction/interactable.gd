class_name Interactable
extends Area2D

## Base class for anything the player can walk up to and press E on.
##
## NPCs, hackable objects, doors and pickups all extend this. The player never
## type-checks any of them — it just calls interact(). New interactable kinds
## need no change to the player, the HUD, or any manager.

@export var prompt: String = "Interact"
@export var enabled: bool = true

var _player_in_range: bool = false


func _ready() -> void:
	collision_layer = 8   # "interactable"
	collision_mask = 2    # detects "player"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not enabled or not body.is_in_group("player"):
		return
	_player_in_range = true
	EventBus.interactable_focused.emit(self, get_prompt())


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	EventBus.interactable_unfocused.emit(self)


func is_player_in_range() -> bool:
	return _player_in_range and enabled


## Override in subclasses. Called when the player presses interact.
func interact() -> void:
	pass


## Override to change the prompt based on state (e.g. "Hacked" vs "Hack").
func get_prompt() -> String:
	return prompt
