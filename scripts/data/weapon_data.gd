class_name WeaponData
extends Resource

## A weapon. Data-driven so a new one needs no code.
##
## MELEE sweeps an arc in front of the player; RANGED spawns projectiles.
## The comedy is in the mismatch — a nail gun against a rubber duck.

enum Kind { MELEE, RANGED }

@export var id: StringName = &""
@export var display_name: String = "Fists"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: Kind = Kind.MELEE

@export_group("Damage")
@export var damage: float = 3.0
@export var crit_chance: float = 0.08
@export var crit_multiplier: float = 2.0
@export var knockback: float = 190.0
## Seconds between swings/shots.
@export var cooldown: float = 0.34

@export_group("Melee")
@export var arc_degrees: float = 110.0
@export var reach: float = 46.0

@export_group("Ranged")
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 420.0
@export var projectile_range: float = 300.0
@export var projectiles_per_shot: int = 1
@export var spread_degrees: float = 0.0
@export var pierce: int = 0

@export_group("Feel")
## Tuned per weapon — a hammer should stop time longer than a toy gun.
@export var shake: float = 3.0
@export var hitstop: float = 0.05

@export_group("Audio")
@export var sfx_use: AudioStream
@export var sfx_hit: AudioStream


func roll_damage() -> Array:
	var crit := randf() < crit_chance
	return [damage * (crit_multiplier if crit else 1.0), crit]
