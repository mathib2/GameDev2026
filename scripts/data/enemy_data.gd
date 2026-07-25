class_name EnemyData
extends CharacterData

## Hostile entities. Used by ICE in cyberspace and by street hostiles in 2D.

enum AIKind { SENTRY, PATROL, CHASER, TURRET }

@export_group("Combat")
@export var ai_kind: AIKind = AIKind.CHASER
@export var damage: int = 10
@export var detection_radius: float = 160.0
@export var attack_cooldown: float = 1.2
@export var projectile_speed: float = 180.0

@export_group("Cyberspace")
## ICE uses a 3D mesh instead of a sprite when spawned inside a construct.
@export var mesh: Mesh
@export var trace_contribution: float = 5.0

@export_group("Drops")
@export var drops: Array[RewardData] = []
