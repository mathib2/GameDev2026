class_name DialogueData
extends Resource

## A dialogue tree, authored entirely in the inspector.
##
## Writers add lines and branches here; DialogueManager walks the tree and
## never needs to know what any particular conversation contains.

@export var id: StringName = &""
@export var lines: Array[DialogueLine] = []

## Optional: only offered if every flag here is set on GameState.
@export var required_flags: Array[StringName] = []
## Optional: never offered if any flag here is set.
@export var blocked_by_flags: Array[StringName] = []
## Higher priority dialogue is chosen first when an NPC has several available.
@export var priority: int = 0


func is_available() -> bool:
	for f in required_flags:
		if not GameState.has_flag(f):
			return false
	for f in blocked_by_flags:
		if GameState.has_flag(f):
			return false
	return true
