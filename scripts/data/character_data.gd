class_name CharacterData
extends Resource

## Shared identity for anyone who appears in the world — player, NPC, enemy.
## Subclassed by NPCData and EnemyData rather than duplicated.

@export var id: StringName = &""
@export var display_name: String = "Unnamed"
@export_multiline var bio: String = ""

@export_group("Appearance")
@export var sprite: Texture2D
@export var portrait: Texture2D
## Optional SpriteFrames for animated characters. Artists can swap this without
## touching any script.
@export var sprite_frames: SpriteFrames
@export var sprite_scale: Vector2 = Vector2.ONE

@export_group("Stats")
@export var max_integrity: int = 100
@export var move_speed: float = 90.0

@export_group("Audio")
@export var voice_blip: AudioStream
