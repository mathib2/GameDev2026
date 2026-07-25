class_name HackTargetData
extends Resource

## The signature data type of Rogue Protocol.
##
## A HackTarget binds a mundane object in the 2D world to an absurdly
## over-engineered 3D cyberspace intrusion. Adding a new hackable object is:
##
##   1. Create a HackTargetData .tres in res://data/hack_targets/
##   2. Point `cyberspace` at a CyberspaceData resource
##   3. Fill in rewards / consequences / audio
##   4. Drop a HackableObject scene in a map and assign this resource
##
## No core system changes. That is the whole point.

enum Difficulty { TRIVIAL, LOW, MODERATE, HIGH, MILITARY, ABSURD }

@export var id: StringName = &""
@export var display_name: String = "Unnamed Device"
@export_multiline var description: String = ""

@export_group("The Joke")
## What a normal person would do. Shown in the pre-hack confirmation panel.
@export var mundane_solution: String = "Just use it normally."
## What the player is about to do instead.
@export var absurd_solution: String = "Breach its network stack."
## Deadpan security briefing text shown during the transition.
@export_multiline var threat_assessment: String = ""

@export_group("Security")
@export var difficulty: Difficulty = Difficulty.MODERATE
## Seconds before the intrusion is traced and fails. 0 = untimed.
@export var trace_time: float = 60.0
## Number of nodes the player must capture in cyberspace to succeed.
@export var required_nodes: int = 3
## ICE (defensive programs) spawned in cyberspace.
@export var ice_count: int = 2
## Netrunner skill required to even attempt. See GameState.get_stat("intrusion").
@export var required_skill: int = 0

@export_group("Cyberspace")
## Which 3D environment this target drops the player into.
@export var cyberspace: CyberspaceData

@export_group("Consequences")
@export var rewards: Array[RewardData] = []
## Flags set on success.
@export var success_flags: Array[StringName] = []
## Flags set on failure.
@export var failure_flags: Array[StringName] = []
## Can this target be hacked more than once?
@export var repeatable: bool = false
## Heat added to the player's wanted level on failure.
@export var failure_heat: int = 1

@export_group("Audio")
@export var hack_start_sfx: AudioStream
@export var success_sfx: AudioStream
@export var failure_sfx: AudioStream


func difficulty_label() -> String:
	return ["TRIVIAL", "LOW", "MODERATE", "HIGH", "MILITARY-GRADE", "ABSURD"][difficulty]


func is_valid() -> bool:
	return id != &"" and cyberspace != null
