class_name RoomLayoutData
extends Resource

## One room layout: where the cover stands, and where the fight starts.
##
## Isaac and Gungeon both build rooms from a library of authored layouts rather
## than scattering obstacles at random. The point is that the cover and the
## enemies are designed *together* — a room reads as a fight with a shape,
## instead of a box with junk in it and toys standing wherever they landed.
##
## This is that library, as data. Adding a layout is a .tres with an ASCII grid
## in it; ContentDB finds it at boot like everything else, so core code still
## holds no content. When the library has nothing that fits — or now and then
## even when it does — `RoomLayout.procedural()` invents one, so a long run
## never runs out of new rooms.
##
## The grid is 12 rows of 20 characters: the room's full tile size, border
## included. The border ring and its door gaps are drawn for readability and
## ignored on parse — Room builds its own walls and doors.
##
## [codeblock]
## #########..#########
## #..................#
## #..##..##..##..##..#
## #..#.e..#..#..e.#..#
## ...
## [/codeblock]
##
## [code].[/code] or space — empty floor[br]
## [code]#[/code] — crate: breakable cover, blocks movement and shots[br]
## [code]o[/code] — optional crate, there about half the time[br]
## [code]e[/code] — enemy spawn anchor[br]
## [code]E[/code] — anchor for the big one: the room spawns a champion on it[br]
## [code]p[/code] — cosmetic prop, no collision[br]
## [code]r[/code] — reward anchor: where a pedestal or chest goes[br]
##
## Columns 9-10 and rows 5-6 are the door lanes. Anything solid in them can wall
## the player in, so `validate()` refuses the layout and ContentDB skips it with
## a warning rather than shipping a room that soft-locks a run.

@export var id: StringName = &""
@export var display_name: String = ""

## 12 rows × 20 chars. See the class docs for the legend.
@export var grid: PackedStringArray = PackedStringArray()

@export_group("Where it may appear")
## Room kinds this suits, lowercase: start combat treasure shop elite secret.
## Boss rooms never take a layout — an arena has to stay an arena.
@export var kinds: PackedStringArray = PackedStringArray(["combat", "elite"])
## First floor index this may appear on (0 = the Playground).
@export var min_floor: int = 0
## Last floor index, or -1 for no cap. Use it to retire the gentle layouts.
@export var max_floor: int = -1
## Relative pick chance against the other layouts valid for the same room.
@export var weight: float = 1.0
## Flip horizontally and/or vertically at build time. Mirroring maps the door
## lanes onto each other, so a valid layout stays valid — turn it off only when
## a layout is deliberately asymmetric in a way that reads as a mistake flipped.
@export var allow_mirror: bool = true


func suits(kind_name: String, floor_index: int) -> bool:
	if not kinds.has(kind_name):
		return false
	if floor_index < min_floor:
		return false
	if max_floor >= 0 and floor_index > max_floor:
		return false
	return true


## Empty means the layout is sound. Anything else is a reason it was skipped.
func validate() -> PackedStringArray:
	return RoomLayout.check(grid)


func is_valid() -> bool:
	return id != &"" and validate().is_empty()
