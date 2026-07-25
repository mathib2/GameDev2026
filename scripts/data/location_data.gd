class_name LocationData
extends Resource

## A place in the 2D world. Maps are separate scenes; this is the metadata that
## lets the router move between them without any map knowing about any other.

@export var id: StringName = &""
@export var display_name: String = "Unknown Sector"
@export_file("*.tscn") var scene_path: String = ""

@export_group("Presentation")
@export var music: AudioStream
@export var ambience: AudioStream
@export var ambient_light: Color = Color(1, 1, 1, 1)

@export_group("Access")
@export var required_flags: Array[StringName] = []
@export var discovered_by_default: bool = false


func is_accessible() -> bool:
	for f in required_flags:
		if not GameState.has_flag(f):
			return false
	return true
