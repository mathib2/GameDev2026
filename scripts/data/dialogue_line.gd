class_name DialogueLine
extends Resource

## One beat of a conversation: a speaker, some text, and optionally choices.

@export var speaker: String = ""
@export var portrait: Texture2D
@export_multiline var text: String = ""
@export var voice_clip: AudioStream

@export_group("Branching")
## Player-facing options. Empty means "press advance to continue".
@export var choices: Array[DialogueChoice] = []

@export_group("Side effects")
## Flags set on GameState when this line is shown.
@export var sets_flags: Array[StringName] = []
## Mission started when this line is shown, if any.
@export var starts_mission: StringName = &""
## Item granted when this line is shown, if any.
@export var grants_item: StringName = &""
