class_name ItemData
extends Resource

## A single item definition.
##
## Content, not code. To add an item, create a new .tres in res://data/items/
## and fill it in — no script anywhere needs to change.

enum Category { MISC, CONSUMABLE, SOFTWARE, HARDWARE, KEY, JUNK }

@export var id: StringName = &""
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.MISC

@export_group("Economy")
@export var value: int = 0
@export var sellable: bool = true
@export var stackable: bool = true
@export var max_stack: int = 99

@export_group("Effects")
## Flags set on GameState when this item is used. Lets designers wire an item
## into progression without touching the inventory system.
@export var sets_flags: Array[StringName] = []
## Netrunner stat modifiers applied while held. See GameState.get_stat().
@export var stat_modifiers: Dictionary = {}
@export var consumed_on_use: bool = false

@export_group("Audio")
@export var pickup_sfx: AudioStream
@export var use_sfx: AudioStream


func is_valid() -> bool:
	return id != &"" and display_name != ""
