class_name MissionData
extends Resource

## A contract. Missions are pure data: objectives are satisfied by flags, which
## every other system already knows how to set.

@export var id: StringName = &""
@export var title: String = "Untitled Contract"
@export_multiline var summary: String = ""
@export var giver_id: StringName = &""

@export_group("Availability")
@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []
@export var auto_start: bool = false
## Optional easter-egg missions are hidden from the log until discovered.
@export var hidden: bool = false

@export_group("Objectives")
@export var objectives: Array[MissionObjective] = []

@export_group("Completion")
@export var rewards: Array[RewardData] = []
@export var completion_flags: Array[StringName] = []
@export_multiline var completion_text: String = ""


func is_available() -> bool:
	for f in required_flags:
		if not GameState.has_flag(f):
			return false
	for f in blocked_by_flags:
		if GameState.has_flag(f):
			return false
	return true
