class_name FloorGenerator
extends RefCounted

## Procedural floor layout. Ported and extended from the HTML prototype's
## genFloor(), which random-walks a grid and then promotes dead ends to special
## rooms.
##
## Extensions over the prototype: shop, elite and secret rooms, and a guarantee
## that the boss is always the furthest room from the start.

enum RoomKind { START, COMBAT, TREASURE, SHOP, ELITE, SECRET, BOSS }

const GRID := 11
const MID := 5

class RoomInfo:
	var gx: int
	var gy: int
	var kind: int = RoomKind.COMBAT
	var doors := {"u": false, "d": false, "l": false, "r": false}
	var cleared: bool = false
	var visited: bool = false
	var spawned: bool = false
	var seed_value: int = 0

	func _init(x: int, y: int) -> void:
		gx = x; gy = y

	func key() -> String:
		return "%d,%d" % [gx, gy]

	func door_count() -> int:
		var n := 0
		for d in doors:
			if doors[d]: n += 1
		return n


var rooms: Dictionary = {}      ## "x,y" -> RoomInfo
var order: Array = []
var start_room: RoomInfo
var boss_room: RoomInfo

const OFFSETS := {"u": Vector2i(0, -1), "d": Vector2i(0, 1),
				  "l": Vector2i(-1, 0), "r": Vector2i(1, 0)}
const OPPOSITE := {"u": "d", "d": "u", "l": "r", "r": "l"}


func generate(floor_index: int, rng: RandomNumberGenerator) -> void:
	rooms.clear(); order.clear()
	var target := 8 + floor_index * 2 + rng.randi_range(0, 2)

	start_room = RoomInfo.new(MID, MID)
	start_room.kind = RoomKind.START
	start_room.cleared = true
	start_room.spawned = true
	_put(start_room)

	var guard := 0
	while order.size() < target and guard < 4000:
		guard += 1
		var from: RoomInfo = order[rng.randi_range(0, order.size() - 1)]
		var dir: String = OFFSETS.keys()[rng.randi_range(0, 3)]
		var off: Vector2i = OFFSETS[dir]
		var nx := from.gx + off.x
		var ny := from.gy + off.y
		if nx < 0 or ny < 0 or nx >= GRID or ny >= GRID:
			continue
		if rooms.has("%d,%d" % [nx, ny]):
			continue
		# discourage dense blobs so the map stays branchy and readable
		var neighbours := 0
		for d in OFFSETS:
			var o: Vector2i = OFFSETS[d]
			if rooms.has("%d,%d" % [nx + o.x, ny + o.y]):
				neighbours += 1
		if neighbours > 1 and rng.randf() < 0.75:
			continue
		var nr := RoomInfo.new(nx, ny)
		nr.seed_value = rng.randi()
		_put(nr)
		from.doors[dir] = true
		nr.doors[OPPOSITE[dir]] = true

	_assign_special(floor_index, rng)


func _put(r: RoomInfo) -> void:
	rooms[r.key()] = r
	order.append(r)


func _assign_special(floor_index: int, rng: RandomNumberGenerator) -> void:
	var dead_ends: Array = []
	for r in order:
		if r != start_room and r.door_count() == 1:
			dead_ends.append(r)
	dead_ends.sort_custom(func(a, b):
		return _dist(a) > _dist(b))

	# boss: furthest dead end, or just the furthest room if there are none
	if dead_ends.is_empty():
		var furthest: RoomInfo = start_room
		for r in order:
			if _dist(r) > _dist(furthest):
				furthest = r
		boss_room = furthest
	else:
		boss_room = dead_ends[0]
	boss_room.kind = RoomKind.BOSS

	var remaining: Array = dead_ends.filter(func(r): return r != boss_room)
	var wanted := [RoomKind.TREASURE, RoomKind.SHOP, RoomKind.SECRET]
	for kind in wanted:
		if remaining.is_empty():
			break
		var pick: RoomInfo = remaining.pop_back()
		pick.kind = kind
		if kind != RoomKind.SECRET:
			pick.cleared = true
			pick.spawned = true

	# a couple of elite rooms on deeper floors, chosen from ordinary combat rooms
	var elites := 0 if floor_index == 0 else (1 if floor_index < 3 else 2)
	var combat: Array = order.filter(func(r): return r.kind == RoomKind.COMBAT)
	combat.shuffle()
	for i in mini(elites, combat.size()):
		combat[i].kind = RoomKind.ELITE


func _dist(r: RoomInfo) -> int:
	return absi(r.gx - MID) + absi(r.gy - MID)


func get_room(gx: int, gy: int) -> RoomInfo:
	return rooms.get("%d,%d" % [gx, gy])


func neighbour(r: RoomInfo, dir: String) -> RoomInfo:
	var o: Vector2i = OFFSETS[dir]
	return get_room(r.gx + o.x, r.gy + o.y)
