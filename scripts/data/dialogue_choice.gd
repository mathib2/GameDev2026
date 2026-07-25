class_name DialogueChoice
extends Resource

## A selectable reply. Jumps to another line index, or ends the conversation.

@export var text: String = ""
## Index into DialogueData.lines. -1 ends the conversation.
@export var goto_line: int = -1
## Only shown if every flag here is set.
@export var required_flags: Array[StringName] = []
## Only shown if the player holds this item.
@export var required_item: StringName = &""
@export var sets_flags: Array[StringName] = []


func is_available() -> bool:
	for f in required_flags:
		if not GameState.has_flag(f):
			return false
	if required_item != &"" and not InventoryManager.has_item(required_item):
		return false
	return true
