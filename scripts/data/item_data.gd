class_name ItemData
extends Resource

## A passive pickup that permanently modifies the run.
##
## Modifiers are a plain dictionary applied to PlayerStats, so a designer can
## invent a new item without touching the player script.
##
## Recognised keys:
##   damage_mult, damage_flat, speed_mult, max_health, fire_rate_mult,
##   knockback_mult, crit_chance, dodge_cooldown_mult, contact_armour

@export var id: StringName = &""
@export var display_name: String = "Mystery Item"
@export_multiline var description: String = ""
## The line that pops up when you grab it. Keep it short and stupid.
@export var flavour: String = ""
@export var icon: Texture2D

@export_group("Effect")
@export var modifiers: Dictionary = {}
## Random effect rolled at pickup instead of fixed modifiers (Mystery Meat).
@export var random_effect: bool = false
## Grants a companion scene that follows the player (Tiny Teddy Bear).
@export_file("*.tscn") var companion_scene: String = ""

@export_group("Rarity")
@export_range(0.0, 1.0) var weight: float = 1.0
@export var unique: bool = true

@export_group("Audio")
@export var sfx_pickup: AudioStream
