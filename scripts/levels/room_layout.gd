class_name RoomLayout
extends RefCounted

## A room's furniture and its fight, resolved to tile coordinates.
##
## Two ways to get one:
##
##   RoomLayout.from_data(...)   an authored layout out of data/rooms
##   RoomLayout.procedural(...)  one invented from motifs and symmetry
##
## Room asks for a layout, then places crates on `obstacles` and enemies on
## `enemy_spots`. Everything about *what* a layout can contain lives in
## RoomLayoutData; everything about the room's geometry lives here.
##
## Both paths obey the same two rules, by different means: authored grids are
## checked by `check()` and rejected at load, while the generator cannot break
## them — it never writes to a lane, and it draws anchors from the reachable set.
##
##   1. Nothing solid in a door lane. Walls are not breakable and doors are the
##      only way out, so this one is a soft-locked run — the single bug in a
##      roguelike that costs the player the whole session.
##   2. Nothing walled in behind cover. Crates *are* breakable, so this is a
##      quality rule rather than a safety one: an enemy sealed in a box is a
##      cleared room that will not open its doors until the player works out
##      they are supposed to smash their way in.

const COLS := 20
const ROWS := 12

## Room._build_walls() opens a 2-tile gap in the middle of each wall. These two
## columns and two rows are the corridors between those gaps — the only paths
## across the room that are guaranteed to exist. Solid tiles are banned from
## them, which also means every layout is trivially connected: the lanes form a
## plus that touches all four doors.
const LANE_X := [9, 10]
const LANE_Y := [5, 6]
const CENTER := Vector2i(10, 6)

## Interior, walls excluded.
const MIN_X := 1
const MAX_X := COLS - 2
const MIN_Y := 1
const MAX_Y := ROWS - 2

var id: StringName = &"procedural"
var obstacles: Array[Vector2i] = []
## Interior wall blocks: unbreakable, drawn with the wall tileset. These are
## what reshape the rectangle — an L-room or a corridor is a rectangle with
## walls where the missing part would be.
var walls: Array[Vector2i] = []
## Pits: the floor is simply not there. Shots fly over, toys are fenced out
## by the pit-edge layer, and the player falls in — unless mid-dodge, which
## is what turns a chasm into a skill check instead of a fence.
var pits: Array[Vector2i] = []
var props: Array[Vector2i] = []
var enemy_spots: Array[Vector2i] = []
var big_spots: Array[Vector2i] = []
var reward_spots: Array[Vector2i] = []


# ── authored ──────────────────────────────────────────────────────────────
## `data` is a RoomLayoutData, deliberately left untyped: that class calls
## check() below, and two class_name scripts naming each other is a cyclic
## reference GDScript resolves badly. The dependency runs one way — data knows
## about the geometry, the geometry does not know about the resource.
static func from_data(data, rng: RandomNumberGenerator) -> RoomLayout:
	var out := RoomLayout.new()
	out.id = data.id
	# Mirroring is free variety: it maps lane columns onto each other and the
	# interior onto itself, so a layout that validated still validates flipped.
	var flip_h: bool = data.allow_mirror and rng.randf() < 0.5
	var flip_v: bool = data.allow_mirror and rng.randf() < 0.5
	for y in mini(ROWS, data.grid.size()):
		var row: String = data.grid[y]
		for x in mini(COLS, row.length()):
			if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y:
				continue                      # border ring is decoration
			var t := Vector2i(COLS - 1 - x if flip_h else x, ROWS - 1 - y if flip_v else y)
			match row[x]:
				"#": out.obstacles.append(t)
				"o":
					if rng.randf() < 0.5:
						out.obstacles.append(t)
				"W": out.walls.append(t)
				"P": out.pits.append(t)
				"e": out.enemy_spots.append(t)
				"E": out.big_spots.append(t)
				"p": out.props.append(t)
				"r": out.reward_spots.append(t)
	shuffle(out.enemy_spots, rng)
	return out


# ── generated ─────────────────────────────────────────────────────────────
## Motifs are drawn once into an 8×4 quadrant and mirrored outward, which is how
## the authored layouts read too: symmetric rooms look deliberate, and random
## scatter is exactly what this system exists to replace. The lanes are never
## written to, so anything this produces is legal by construction.
const QW := 8      ## quadrant width  — interior columns 1-8 and 18-11
const QH := 4      ## quadrant height — interior rows 1-4 and 10-7

const MOTIFS := ["box", "bar_h", "bar_v", "ell", "comb", "diag", "pillars", "blob", "wedge"]


## The silhouettes a generated room can take, weighted toward the plain box
## early and away from it with depth. This is the Gungeon/Isaac trick: the
## ROOM is a shape first and furniture second — an L-room, a letterbox
## corridor, a vaulted chamber, an island ringed by nothing. Every shape is
## carved out of the rectangle with walls or pits, and every carve skips the
## door lanes, so any silhouette is connected by construction.
const SILHOUETTES := ["l_cut", "twin_cut", "cross_cut", "corridor_h",
	"corridor_v", "vault", "moat", "shore"]


static func procedural(rng: RandomNumberGenerator, floor_index: int) -> RoomLayout:
	var out := RoomLayout.new()
	out.id = &"procedural"

	# ── 1. the shape of the room itself ──
	var walls := {}
	var pits := {}
	var shaped_chance := 0.35 if floor_index == 0 else 0.65
	var silhouette := ""
	if rng.randf() < shaped_chance:
		silhouette = SILHOUETTES[rng.randi_range(0, SILHOUETTES.size() - 1)]
		_carve(silhouette, walls, pits, rng, floor_index)

	# ── 2. crates, in whatever floor is left ──
	var top := _quadrant(rng, floor_index)
	# Half the time the bottom repeats the top (four-fold symmetry, calm and
	# arena-like); otherwise it gets its own motif and the room has a near half
	# and a far half, which is more interesting to fight across.
	var bottom: Array = top if rng.randf() < 0.5 else _quadrant(rng, floor_index)
	var solid := {}
	for q in top:
		_stamp(solid, q.x, q.y, true)
	for q in bottom:
		_stamp(solid, q.x, q.y, false)

	# A plain box can still grow one mirrored feature motif, as before. Shaped
	# rooms skip it — the silhouette IS their feature, and stacking both walls
	# the fight in.
	if silhouette == "" and floor_index >= 1 and rng.randf() < 0.45:
		var feature_is_pit: bool = floor_index >= 2 and rng.randf() < 0.5
		for c in _motif(["bar_h", "bar_v", "box", "ell"][rng.randi_range(0, 3)], rng):
			if c.x >= 0 and c.x < QW and c.y >= 0 and c.y < QH:
				_stamp(pits if feature_is_pit else walls, c.x, c.y, true)
				_stamp(pits if feature_is_pit else walls, c.x, c.y, false)

	# the shape always wins where furniture overlaps it
	for k in walls:
		solid.erase(k)
	for k in pits:
		solid.erase(k)
	for k in solid:
		out.obstacles.append(k)
	for k in walls:
		out.walls.append(k)
	for k in pits:
		out.pits.append(k)

	# Anchors dodge everything that blocks walking, shape included.
	var blocked := solid.duplicate()
	for k in walls:
		blocked[k] = true
	for k in pits:
		blocked[k] = true
	out.enemy_spots = _pick_anchors(blocked, rng, 4 + mini(floor_index, 4))
	if not out.enemy_spots.is_empty() and rng.randf() < 0.6:
		out.big_spots.append(out.enemy_spots.pop_back())
	return out


## Fill a rectangle of interior tiles into `dict`, skipping door lanes.
static func _fill(dict: Dictionary, x0: int, x1: int, y0: int, y1: int) -> void:
	for y in range(maxi(y0, MIN_Y), mini(y1, MAX_Y) + 1):
		for x in range(maxi(x0, MIN_X), mini(x1, MAX_X) + 1):
			var t := Vector2i(x, y)
			if not is_lane(t):
				dict[t] = true


## Carve one silhouette. Pit-based shapes need the third floor's depth — on
## earlier floors they fall back to their walled cousins, so the shape
## vocabulary grows as the run descends.
static func _carve(kind: String, walls: Dictionary, pits: Dictionary,
		rng: RandomNumberGenerator, floor_index: int) -> void:
	var pit_ok := floor_index >= 2
	match kind:
		"l_cut":
			# one corner of the rectangle is not part of the room
			var w := rng.randi_range(5, 8)
			var h := rng.randi_range(3, 4)
			var left := rng.randf() < 0.5
			var top_side := rng.randf() < 0.5
			_fill(walls, 1 if left else COLS - 1 - w, w if left else MAX_X,
				1 if top_side else ROWS - 1 - h, h if top_side else MAX_Y)
		"twin_cut":
			# two opposite corners gone: the room is a fat Z
			var w := rng.randi_range(5, 7)
			var h := 3
			var flip := rng.randf() < 0.5
			_fill(walls, 1, w, 1 if flip else MAX_Y - h + 1,
				h if flip else MAX_Y)
			_fill(walls, COLS - 1 - w, MAX_X, MAX_Y - h + 1 if flip else 1,
				MAX_Y if flip else h)
		"cross_cut":
			# all four corners gone: a plus-shaped arena
			var w := rng.randi_range(4, 6)
			var h := 3
			_fill(walls, 1, w, 1, h)
			_fill(walls, COLS - 1 - w, MAX_X, 1, h)
			_fill(walls, 1, w, MAX_Y - h + 1, MAX_Y)
			_fill(walls, COLS - 1 - w, MAX_X, MAX_Y - h + 1, MAX_Y)
		"corridor_h":
			# the room is a wide letterbox
			_fill(walls, 1, MAX_X, 1, rng.randi_range(2, 3))
			_fill(walls, 1, MAX_X, ROWS - 1 - rng.randi_range(2, 3), MAX_Y)
		"corridor_v":
			# the room is a tall slot; the lane rows tunnel through the sides
			var w := rng.randi_range(3, 5)
			_fill(walls, 1, w, 1, MAX_Y)
			_fill(walls, COLS - 1 - w, MAX_X, 1, MAX_Y)
		"vault":
			# a chamber within the room, gated where the lanes cross it
			_fill(walls, 4, 15, 2, 2)
			_fill(walls, 4, 15, 9, 9)
			_fill(walls, 4, 4, 3, 8)
			_fill(walls, 15, 15, 3, 8)
		"moat":
			# an island arena, bridged only at the lanes
			var band := pits if pit_ok else walls
			_fill(band, 3, 16, 2, 2)
			_fill(band, 3, 16, 9, 9)
			_fill(band, 3, 4, 3, 8)
			_fill(band, 15, 16, 3, 8)
		"shore":
			# the floor simply ends along one side of the room
			var band := pits if pit_ok else walls
			var w := rng.randi_range(3, 5)
			if rng.randf() < 0.5:
				_fill(band, 1, w, 1, MAX_Y)
			else:
				_fill(band, COLS - 1 - w, MAX_X, 1, MAX_Y)


## One quadrant's worth of solid cells, in local coords (0-7, 0-3).
static func _quadrant(rng: RandomNumberGenerator, floor_index: int) -> Array:
	var cells := {}
	var motifs := 1 if rng.randf() < 0.55 else 2
	if floor_index >= 3 and rng.randf() < 0.35:
		motifs += 1                      # deeper floors get busier rooms
	for i in motifs:
		for c in _motif(MOTIFS[rng.randi_range(0, MOTIFS.size() - 1)], rng):
			if c.x >= 0 and c.x < QW and c.y >= 0 and c.y < QH:
				cells[c] = true
	# Every cell here becomes four crates once it is mirrored outward, so the cap
	# is what keeps a generated room inside the same density band the authored
	# ones sit in — roughly 8 to 32 crates. Overshooting it is not just ugly:
	# crates pay out coins, so a wall-to-wall room would quietly print money.
	var cap := 6 + mini(floor_index, 3)
	var out: Array = cells.keys()
	if out.size() > cap:
		shuffle(out, rng)
		out.resize(cap)
	return out


static func _motif(kind: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	match kind:
		"box":
			var ox := rng.randi_range(0, QW - 2)
			var oy := rng.randi_range(0, QH - 2)
			for dx in 2:
				for dy in 2:
					out.append(Vector2i(ox + dx, oy + dy))
		"bar_h":
			var y := rng.randi_range(0, QH - 1)
			var x0 := rng.randi_range(0, 3)
			for i in rng.randi_range(3, 5):
				out.append(Vector2i(x0 + i, y))
		"bar_v":
			var x := rng.randi_range(0, QW - 1)
			var y0 := rng.randi_range(0, 1)
			for i in rng.randi_range(2, 3):
				out.append(Vector2i(x, y0 + i))
		"ell":
			var ox := rng.randi_range(0, QW - 3)
			var oy := rng.randi_range(0, QH - 3)
			for i in 3:
				out.append(Vector2i(ox + i, oy))
			for i in range(1, 3):
				out.append(Vector2i(ox, oy + i))
		"comb":
			var y0 := rng.randi_range(0, QH - 2)
			for x in range(rng.randi_range(0, 1), QW, 3):
				out.append(Vector2i(x, y0))
				out.append(Vector2i(x, y0 + 1))
		"diag":
			var ox := rng.randi_range(0, QW - 3)
			var oy := rng.randi_range(0, QH - 3)
			for i in 3:
				out.append(Vector2i(ox + i, oy + i))
		"pillars":
			var oy := rng.randi_range(0, QH - 1)
			for x in range(rng.randi_range(1, 2), QW, rng.randi_range(2, 3)):
				out.append(Vector2i(x, oy))
		"blob":
			var c := Vector2i(rng.randi_range(1, QW - 2), rng.randi_range(0, QH - 2))
			out.append(c)
			for i in rng.randi_range(2, 4):
				var n: Vector2i = out[rng.randi_range(0, out.size() - 1)]
				out.append(n + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP,
					Vector2i.DOWN][rng.randi_range(0, 3)])
		"wedge":
			var ox := rng.randi_range(0, QW - 3)
			var oy := rng.randi_range(0, QH - 2)
			for i in 3:
				out.append(Vector2i(ox + i, oy))
			out.append(Vector2i(ox + 1, oy + 1))
	return out


## Writes one quadrant cell into all the quadrants that mirror it.
static func _stamp(solid: Dictionary, qx: int, qy: int, top: bool) -> void:
	var xs := [MIN_X + qx, MAX_X - qx]
	var y := (MIN_Y + qy) if top else (MAX_Y - qy)
	for x in xs:
		var t := Vector2i(x, y)
		if is_lane(t):
			continue
		solid[t] = true


## Spread enemy anchors over the open floor: two tiles apart so they do not
## stack, off the centre so nothing spawns in the player's lap, and never
## walled in.
static func _pick_anchors(solid: Dictionary, rng: RandomNumberGenerator, want: int) -> Array[Vector2i]:
	var reach := _reachable(solid)
	var pool: Array[Vector2i] = []
	for t in reach:
		if t.distance_squared_to(CENTER) < 9:
			continue
		if t.x <= MIN_X or t.x >= MAX_X or t.y <= MIN_Y or t.y >= MAX_Y:
			continue          # hard against a wall looks like a spawn bug
		pool.append(t)
	shuffle(pool, rng)

	var out: Array[Vector2i] = []
	for t in pool:
		if out.size() >= want:
			break
		var ok := true
		for a in out:
			if absi(a.x - t.x) < 2 and absi(a.y - t.y) < 2:
				ok = false
				break
		if ok:
			out.append(t)
	return out


# ── validation ────────────────────────────────────────────────────────────
## Empty return means the grid is sound. ContentDB refuses anything else, and
## the procedural path asserts against the same rules — a soft-locked run is
## the one bug in a roguelike that costs the whole session.
static func check(grid: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	if grid.size() != ROWS:
		errors.append("grid is %d rows, expected %d" % [grid.size(), ROWS])
		return errors

	var solid := {}
	var anchors: Array[Vector2i] = []
	for y in ROWS:
		var row: String = grid[y]
		if row.length() != COLS:
			errors.append("row %d is %d chars, expected %d" % [y, row.length(), COLS])
			continue
		for x in COLS:
			var c: String = row[x]
			if not " .#oeEprWP".contains(c):
				errors.append("row %d col %d: unknown character '%s'" % [y, x, c])
				continue
			if x < MIN_X or x > MAX_X or y < MIN_Y or y > MAX_Y:
				continue
			var t := Vector2i(x, y)
			# Crates, walls and pits all block walking for validation purposes.
			# Crates can at least be smashed through; a wall or a pit cannot, so
			# an anchor sealed behind those is not "quality", it is a fists-only
			# player staring at an unclearable room.
			if c == "#" or c == "o" or c == "W" or c == "P":
				if is_lane(t):
					errors.append("solid tile in a door lane at %d,%d" % [x, y])
				solid[t] = true
			elif c == "e" or c == "E" or c == "r":
				anchors.append(t)
	if not errors.is_empty():
		return errors

	var reach := _reachable(solid)
	for a in anchors:
		if not reach.has(a):
			errors.append("anchor at %d,%d is walled in" % [a.x, a.y])
	return errors


static func is_lane(t: Vector2i) -> bool:
	return LANE_X.has(t.x) or LANE_Y.has(t.y)


## Every open interior tile the player can walk to from the middle of the room.
static func _reachable(solid: Dictionary) -> Dictionary:
	var seen := {CENTER: true}
	var queue: Array[Vector2i] = [CENTER]
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = t + d
			if n.x < MIN_X or n.x > MAX_X or n.y < MIN_Y or n.y > MAX_Y:
				continue
			if seen.has(n) or solid.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


# ── helpers ───────────────────────────────────────────────────────────────
## Array.shuffle() draws from the global RNG, which would make a room rebuild
## differently every time the player walked back into it.
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
