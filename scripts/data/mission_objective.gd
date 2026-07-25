class_name MissionObjective
extends Resource

## One step of a mission. Completion is always expressed as a flag, so any
## system that can set a flag can advance a mission without knowing missions
## exist.

@export var description: String = ""
## The mission step is done once this flag is set on GameState.
@export var completed_when_flag: StringName = &""
## Hidden objectives are not listed until a prior objective completes.
@export var hidden_until_active: bool = false
@export var optional: bool = false


func is_complete() -> bool:
	return completed_when_flag != &"" and GameState.has_flag(completed_when_flag)
