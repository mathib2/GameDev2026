class_name EnemyData
extends Resource

## One enemy definition. Adding an enemy = one .tres + one spritesheet.
##
## Behaviour is picked from a fixed set of archetypes rather than a bespoke
## script per enemy, so designers can build a new toy out of existing parts.
## If a genuinely new movement pattern is needed, add an archetype to
## scripts/enemies/enemy.gd — not a whole new scene.

enum Behaviour {
	CHASER,      ## walks straight at you (teddy bear)
	SPRINTER,    ## bursts of speed, pauses (gingerbread man)
	WANDERER,    ## drifts randomly, squeaks (rubber duck)
	SHOOTER,     ## keeps distance, fires (toy soldier)
	SHOCKWAVE,   ## stationary, radial bursts (baby rattle)
	HOPPER,      ## leaps toward you (stuffed bunny)
	PATROL,      ## predictable bouncing path (wind-up toy)
	CREEPER,     ## slow, relentless, unsettling (doll)
	CHARGER,     ## telegraphs then rockets in a line (toy car)
	BUILDER,     ## stationary, spawns obstacles (building block)
}

@export var id: StringName = &""
@export var display_name: String = "Toy"

@export_group("Appearance")
@export var spritesheet: Texture2D
@export var frame_size: Vector2i = Vector2i(32, 32)
## Leave empty to use SheetAnimator.DEFAULT_ROWS.
@export var animations: Dictionary = {}
@export var sprite_offset: Vector2 = Vector2(0, -16)
@export var hit_radius: float = 10.0

@export_group("Stats")
@export var max_health: float = 6.0
@export var move_speed: float = 42.0
@export var contact_damage: int = 1
@export var knockback_resist: float = 0.0   ## 0 = shoved easily, 1 = immovable
@export var score: int = 1

@export_group("Behaviour")
@export var behaviour: Behaviour = Behaviour.CHASER
## Seconds between attacks / bursts / hops. Meaning depends on archetype.
@export var attack_cooldown: float = 2.0
@export var attack_range: float = 220.0
@export var telegraph_time: float = 0.55
@export var projectile_count: int = 6
@export var projectile_speed: float = 90.0
@export var projectile_damage: int = 1

@export_group("Drops")
@export var coin_chance: float = 0.35
@export var heart_chance: float = 0.10

@export_group("Audio")
@export var sfx_attack: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_death: AudioStream
## Occasional idle noise — this is where most of the comedy lives.
@export var sfx_idle: AudioStream
@export var idle_sound_chance: float = 0.0


func is_valid() -> bool:
	return id != &"" and spritesheet != null
