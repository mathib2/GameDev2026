class_name RewardData
extends Resource

## A consequence of finishing something: a hack, a mission, a conversation.
##
## Deliberately generic so missions and hacks share one reward pipeline.

enum Kind { ITEM, CREDITS, FLAG, XP, UNLOCK_MISSION, HEAL }

@export var kind: Kind = Kind.CREDITS
## Meaning depends on `kind`: item id, flag name, or mission id.
@export var id: StringName = &""
@export var amount: int = 0
## Shown in the reward toast. Leave blank for an auto-generated line.
@export var display_override: String = ""


func describe() -> String:
	if display_override != "":
		return display_override
	match kind:
		Kind.ITEM: return "Acquired: %s" % id
		Kind.CREDITS: return "+%d credits" % amount
		Kind.XP: return "+%d XP" % amount
		Kind.FLAG: return ""
		Kind.UNLOCK_MISSION: return "New contract available"
		Kind.HEAL: return "+%d integrity" % amount
	return ""
