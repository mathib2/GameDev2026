class_name BossData
extends Resource

## A boss, defined as data.
##
## The first four bosses each got their own script, and at four that was the
## right call — they are the ones players meet most and they earn bespoke code.
## At fourteen it stops being right: ten more hand-written state machines is ten
## more places for the same bug, and it breaks the rule the rest of this project
## follows (core systems hold no content, adding content means adding a .tres).
##
## So a boss is a *composition*: a movement style, a list of attack patterns it
## may use, and per-phase gates on those patterns. `generic_boss.gd` runs it.
## The patterns are the vocabulary; the .tres is the sentence.
##
## Both models coexist deliberately — TeddyBearKing and the rest keep their
## bespoke scripts, because a boss with a unique *mechanic* still deserves one.
## This is for bosses whose identity is their pattern mix, their art and their
## numbers, which is most of them.

enum Movement {
	STALK,      ## walks steadily at the player
	DRIFT,      ## wanders, only loosely interested in you
	ORBIT,      ## circles at a preferred radius
	ANCHOR,     ## barely moves; a fixed hazard
	HOP,        ## bounds in arcs
}

enum Pattern {
	RING,       ## radial burst in every direction
	SPREAD,     ## aimed fan, led onto the player
	SPIRAL,     ## sustained rotating stream
	WALL,       ## a line across the room with one gap — punishes camping
	CHARGE,     ## telegraph, then rocket in a straight line
	SUMMON,     ## spawn minions
	BLINK,      ## teleport, then immediately attack
	LOB,        ## slow arcing shots that land where you are going
	AURA,       ## short-range shockwave, punishes hugging
}

@export var id: StringName = &""
@export var display_name: String = "SOMETHING"
## Shown under the name on the intro card. Played straight — never a joke.
@export var subtitle: String = ""
@export var spritesheet: Texture2D
@export var sprite_scale: float = 1.0
@export var sprite_offset: Vector2 = Vector2(0, -30)

@export_group("Body")
@export var max_health: float = 240.0
@export var hit_radius: float = 26.0
@export var contact_damage: int = 1
@export var move_speed: float = 26.0
@export var movement: Movement = Movement.STALK

@export_group("Attacks")
## Patterns available from phase 1. Phase 2 and 3 add theirs on top, so the
## fight escalates by *gaining* options rather than swapping them.
@export var phase1: Array[int] = []
@export var phase2: Array[int] = []
@export var phase3: Array[int] = []
## Seconds between attacks at phase 1. Each phase shortens it.
@export var cooldown: float = 1.2
@export var projectile_count: int = 12
@export var projectile_speed: float = 110.0
@export var minion_id: StringName = &""

@export_group("Feel")
@export var tint: Color = Color(1, 1, 1)
@export var phase2_line: String = ""
@export var phase3_line: String = ""
@export var defeat_line: String = ""
## White stuffing suits soft toys; a tin robot or a biscuit sheds something
## else, so the burst colour is per boss.
@export var debris: Color = Color(1, 1, 1)

@export_group("Audio")
@export var sfx_intro: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_death: AudioStream
@export var sfx_attack: AudioStream


## Patterns legal at a given phase.
func patterns_for(phase: int) -> Array:
	var out: Array = []
	out.append_array(phase1)
	if phase >= 2:
		out.append_array(phase2)
	if phase >= 3:
		out.append_array(phase3)
	return out
