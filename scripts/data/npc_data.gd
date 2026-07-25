class_name NPCData
extends CharacterData

## Everything an NPC needs. Adding an NPC is: make one of these, assign a
## sprite and dialogue, drop an NPC.tscn in a map, assign the resource.

enum Behaviour { IDLE, WANDER, PATROL, SHOPKEEPER }

@export_group("Behaviour")
@export var behaviour: Behaviour = Behaviour.IDLE
@export var wander_radius: float = 48.0
@export var patrol_points: Array[Vector2] = []
@export var faces_player_when_talking: bool = true

@export_group("Conversation")
## Highest-priority available DialogueData wins. See DialogueData.is_available().
@export var dialogues: Array[DialogueData] = []
## Shown as a floating prompt when the player is in range.
@export var interact_prompt: String = "Talk"

@export_group("Shop")
@export var is_shopkeeper: bool = false
@export var shop_stock: Array[ItemData] = []
@export var shop_markup: float = 1.0


func pick_dialogue() -> DialogueData:
	var best: DialogueData = null
	for d in dialogues:
		if d == null or not d.is_available():
			continue
		if best == null or d.priority > best.priority:
			best = d
	return best
