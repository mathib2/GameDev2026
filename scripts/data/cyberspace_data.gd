class_name CyberspaceData
extends Resource

## Describes one 3D cyberspace environment.
##
## Decoupling this from HackTargetData means the 3D team can build and tune
## environments independently, and several hack targets can reuse one
## environment with different tuning.

@export var id: StringName = &""
@export var display_name: String = "Unnamed Construct"

## The 3D scene to instance. Must have a root extending CyberspaceScene.
## Examples: a vending machine -> digital factory, a camera -> surveillance
## network, a car -> digital highway, a server -> digital skyscraper.
@export_file("*.tscn") var scene_path: String = ""

@export_group("Look and feel")
@export var fog_color: Color = Color(0.05, 0.0, 0.12)
@export var grid_color: Color = Color(0.0, 1.0, 0.85)
@export var ambient_energy: float = 0.4

@export_group("Audio")
@export var music: AudioStream
@export var ambience: AudioStream

@export_group("Tuning")
## Movement speed of the netrunner avatar in this construct.
@export var runner_speed: float = 8.0
@export var gravity_enabled: bool = true


func is_valid() -> bool:
	return scene_path != "" and ResourceLoader.exists(scene_path)
