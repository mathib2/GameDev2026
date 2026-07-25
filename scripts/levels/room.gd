extends Node2D

## A single room. Builds its own walls, doors, decor and spawns from a RoomInfo,
## so there is no hand-authored scene per room and level designers can add
## layouts as data later without touching this.

const TILE := 32
const COLS := 20
const ROWS := 12
const W := COLS * TILE      # 640
const H := ROWS * TILE      # 384

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const PICKUP_SCENE := preload("res://scenes/items/Pickup.tscn")
const ITEM_PEDESTAL := preload("res://scenes/items/ItemPedestal.tscn")
const WEAPON_PEDESTAL := preload("res://scenes/items/WeaponPedestal.tscn")
const CHEST := preload("res://scripts/items/chest.gd")
const SHRINE := preload("res://scripts/items/skill_shrine.gd")
const BOOKS_TEX := preload("res://assets/environment/prop_books.png")
# One boss per floor, indexed by floor. With four bosses and four floors a run
# no longer repeats one, and each is matched to where it lives: the King rules
# the Nursery, the General is baked in the Playroom, the Choir was packed away
# in the Attic, and Jack never left the factory. New bosses just join the list.
const BOSS_SCENES: Array[PackedScene] = [
	preload("res://scenes/bosses/TeddyBearKing.tscn"),
	preload("res://scenes/bosses/GingerbreadGeneral.tscn"),
	preload("res://scenes/bosses/PorcelainChoir.tscn"),
	preload("res://scenes/bosses/Jack.tscn"),
]

const FLOOR_TEX := preload("res://assets/environment/tiles_floor.png")
const WALL_TEX := preload("res://assets/environment/tiles_wall.png")
const CRATE_TEX := preload("res://assets/environment/prop_crate.png")

var info                       ## FloorGenerator.RoomInfo
var alive_enemies: int = 0
var _doors: Array = []
var _rng := RandomNumberGenerator.new()
var _tint: Color = Color.WHITE

## Per-floor ambience tints so the Nursery, Playroom, Attic and Toy
## Factory stop looking identical.
const FLOOR_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.93, 0.96, 1.08),
	Color(1.08, 0.97, 0.88),
	Color(0.88, 0.96, 1.0),
]

## Obstacle layout templates, Isaac-style. Tile coords keep the door
## lanes (x 9-11, y 5-7) and a 2-tile border clear so rooms always path.
const LAYOUT_CORNERS: Array = [
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(14, 3), Vector2i(15, 3), Vector2i(14, 4), Vector2i(15, 4),
	Vector2i(4, 8), Vector2i(5, 8), Vector2i(4, 9), Vector2i(5, 9),
	Vector2i(14, 8), Vector2i(15, 8), Vector2i(14, 9), Vector2i(15, 9),
]
const LAYOUT_PILLARS: Array = [
	Vector2i(5, 3), Vector2i(8, 4), Vector2i(12, 4), Vector2i(15, 3),
	Vector2i(5, 9), Vector2i(8, 8), Vector2i(12, 8), Vector2i(15, 9),
]
const LAYOUT_RAILS: Array = [
	Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(15, 4),
	Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(13, 8), Vector2i(14, 8), Vector2i(15, 8),
]
const LAYOUT_DIAMOND: Array = [
	Vector2i(8, 3), Vector2i(12, 3), Vector2i(6, 4), Vector2i(14, 4),
	Vector2i(6, 8), Vector2i(14, 8), Vector2i(8, 9), Vector2i(12, 9),
]

signal cleared()


func build(room_info) -> void:
	info = room_info
	_rng.seed = info.seed_value if info.seed_value != 0 else randi()
	_tint = FLOOR_TINTS[clampi(GameState.floor_index, 0, FLOOR_TINTS.size() - 1)]
	_paint_floor()
	_build_walls()
	_scatter_decor()


# ── visuals ───────────────────────────────────────────────────────────────
func _paint_floor() -> void:
	var holder := Node2D.new()
	holder.name = "Floor"
	holder.z_index = -20
	holder.modulate = _tint
	add_child(holder)
	for y in ROWS:
		for x in COLS:
			var s := Sprite2D.new()
			s.texture = FLOOR_TEX
			s.hframes = 5
			s.frame = _rng.randi_range(0, 4)
			s.centered = false
			s.position = Vector2(x * TILE, y * TILE)
			s.scale = Vector2(TILE / 16.0, TILE / 16.0)
			holder.add_child(s)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("wall")
	add_child(body)

	var gap := 2                          # door opening, in tiles
	var mid_x := COLS / 2
	var mid_y := ROWS / 2

	# top / bottom
	for x in COLS:
		var in_door_x: bool = x >= mid_x - gap / 2 and x < mid_x + gap / 2
		if not (in_door_x and info.doors["u"]):
			_wall_tile(body, x, 0)
		if not (in_door_x and info.doors["d"]):
			_wall_tile(body, x, ROWS - 1)
	# left / right
	for y in range(1, ROWS - 1):
		var in_door_y: bool = y >= mid_y - gap / 2 and y < mid_y + gap / 2
		if not (in_door_y and info.doors["l"]):
			_wall_tile(body, 0, y)
		if not (in_door_y and info.doors["r"]):
			_wall_tile(body, COLS - 1, y)

	# door triggers
	for dir in ["u", "d", "l", "r"]:
		if info.doors[dir]:
			_make_door(dir)


func _wall_tile(body: StaticBody2D, tx: int, ty: int) -> void:
	var s := Sprite2D.new()
	s.texture = WALL_TEX
	s.hframes = 2
	s.frame = 0 if (tx + ty) % 3 else 1
	s.modulate = _tint
	s.centered = false
	s.position = Vector2(tx * TILE, ty * TILE)
	s.scale = Vector2(TILE / 16.0, TILE / 16.0)
	s.z_index = -10
	add_child(s)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	col.shape = rect
	col.position = Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)
	body.add_child(col)


func _make_door(dir: String) -> void:
	var area := Area2D.new()
	area.name = "Door_" + dir
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = false            # opens when the room is cleared
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 48)
	col.shape = rect
	area.add_child(col)
	match dir:
		"u": area.position = Vector2(W * 0.5, 8)
		"d": area.position = Vector2(W * 0.5, H - 8)
		"l": area.position = Vector2(8, H * 0.5)
		"r": area.position = Vector2(W - 8, H * 0.5)
	add_child(area)
	_doors.append({"dir": dir, "area": area})


func _physics_process(_delta: float) -> void:
	# Doors poll instead of using one-shot body_entered: if the player
	# reaches a door during the brief post-travel lock, the entered event
	# fires once, gets refused, and never fires again while they stand in
	# the trigger — a dead door and a soft-locked run. Polling can't miss.
	for d in _doors:
		var area: Area2D = d["area"]
		if not area.monitoring:
			continue
		for b in area.get_overlapping_bodies():
			if b.is_in_group("player"):
				RunManager.travel(d["dir"])
				return


func _scatter_decor() -> void:
	if info.kind == FloorGenerator.RoomKind.BOSS:
		return
	# special rooms stay clean showrooms
	if info.kind in [FloorGenerator.RoomKind.SHOP, FloorGenerator.RoomKind.TREASURE,
			FloorGenerator.RoomKind.SECRET]:
		return
	# pick a layout template per room (seeded, so re-entry looks the same);
	# an empty pick falls back to the classic random scatter
	var layouts: Array = [[], LAYOUT_CORNERS, LAYOUT_PILLARS, LAYOUT_RAILS, LAYOUT_DIAMOND]
	var pick: Array = layouts[_rng.randi_range(0, layouts.size() - 1)]
	if pick.is_empty():
		_scatter_random()
	else:
		for t in pick:
			_spawn_crate(Vector2(t.x * TILE + 16, t.y * TILE + 16))
	_scatter_props()


## Purely cosmetic clutter — no collision, no pickup, nothing to shoot. Rooms
## built from one tileset read as the same room over and over; a few pieces of
## junk against the walls is the cheapest fix for that. Kept out of the middle
## and out of the door lanes so it never reads as something you can interact
## with or get stuck on.
func _scatter_props() -> void:
	# Build the list of legal tiles first and sample from it, rather than
	# guessing and rejecting: the room is only 8 tiles tall inside its walls, so
	# reject-sampling threw away most candidates and usually placed nothing.
	var spots: Array = []
	for ty in range(1, ROWS - 1):
		for tx in range(1, COLS - 1):
			# hug the walls — clutter in open floor reads as something you can
			# pick up, and gets in the way of a dodge
			var edge: bool = tx <= 2 or tx >= COLS - 3 or ty <= 1 or ty >= ROWS - 2
			if not edge:
				continue
			# never in a door lane
			if absi(tx - COLS / 2) <= 1 or absi(ty - ROWS / 2) <= 1:
				continue
			spots.append(Vector2i(tx, ty))
	spots.shuffle()

	for i in mini(_rng.randi_range(3, 6), spots.size()):
		var t: Vector2i = spots[i]
		var s := Sprite2D.new()
		s.texture = BOOKS_TEX
		s.position = Vector2(t.x * TILE + 16, t.y * TILE + 20)
		# knocked back and dimmed so it sits behind the action instead of
		# competing with the crates, which are actually interactive
		s.modulate = _tint * Color(0.62, 0.6, 0.66, 1.0)
		s.flip_h = _rng.randf() < 0.5
		s.z_index = -5
		add_child(s)


func _scatter_random() -> void:
	var count := _rng.randi_range(2, 6)
	for i in count:
		var tx := _rng.randi_range(3, COLS - 4)
		var ty := _rng.randi_range(3, ROWS - 4)
		# keep the middle and the door lanes clear
		if absi(tx - COLS / 2) < 3 and absi(ty - ROWS / 2) < 3:
			continue
		if absi(tx - COLS / 2) <= 1 or absi(ty - ROWS / 2) <= 1:
			continue
		_spawn_crate(Vector2(tx * TILE + 16, ty * TILE + 16))


func _spawn_crate(pos: Vector2) -> void:
	# a crate smashed on a previous visit stays smashed
	if info != null and info.broken_crates.has(crate_key(pos)):
		return
	var crate := preload("res://scripts/levels/breakable.gd").new()
	crate.position = pos
	crate.z_index = 1
	add_child(crate)


## Stable id for a crate slot. Rounded, because the position round-trips
## through float maths on every rebuild.
func crate_key(pos: Vector2) -> String:
	return "%d,%d" % [roundi(pos.x), roundi(pos.y)]


## Called by a crate as it breaks, so it does not come back on re-entry.
func forget_crate(pos: Vector2) -> void:
	if info != null:
		info.broken_crates[crate_key(pos)] = true


# ── population ────────────────────────────────────────────────────────────
func populate(floor_index: int) -> void:
	if info.spawned:
		_open_doors()
		# The exit portal died with the previous room instance; without this
		# a player who leaves after the boss kill can never descend.
		if info.kind == FloorGenerator.RoomKind.BOSS and info.cleared:
			RunManager.spawn_exit()
		return
	info.spawned = true

	match info.kind:
		FloorGenerator.RoomKind.BOSS:
			_spawn_boss(floor_index)
		FloorGenerator.RoomKind.TREASURE:
			# Sometimes the treasure is a whole new weapon, sometimes a chest
			# you have to walk into to find out what is in it.
			var roll := _rng.randf()
			if roll < 0.45:
				_spawn_weapon_pedestal(Vector2(W * 0.5, H * 0.5))
			elif roll < 0.65:
				_spawn_chest(Vector2(W * 0.5, H * 0.5), true, 0)
			else:
				_spawn_pedestal()
			_open_doors()
		FloorGenerator.RoomKind.SHOP:
			_spawn_shop()
			_open_doors()
		FloorGenerator.RoomKind.SECRET:
			spawn_pickup("heart", Vector2(W * 0.5, H * 0.5 - 40))
			spawn_pickup("coin", Vector2(W * 0.5 - 40, H * 0.5))
			spawn_pickup("coin", Vector2(W * 0.5 + 40, H * 0.5))
			_open_doors()
		FloorGenerator.RoomKind.ELITE:
			_spawn_enemies(floor_index, 1.6)
		FloorGenerator.RoomKind.COMBAT:
			_spawn_enemies(floor_index, 1.0)
		_:
			_open_doors()


func _spawn_enemies(floor_index: int, difficulty: float) -> void:
	var pool := ContentDB.enemies_for_floor(floor_index)
	if pool.is_empty():
		_open_doors()
		return
	var count := int(round((3 + floor_index) * difficulty)) + _rng.randi_range(0, 2)
	var placed := 0
	var guard := 0
	while placed < count and guard < 200:
		guard += 1
		var pos := Vector2(
			_rng.randf_range(TILE * 2.5, W - TILE * 2.5),
			_rng.randf_range(TILE * 2.5, H - TILE * 2.5))
		if pos.distance_to(Vector2(W * 0.5, H * 0.5)) < 90.0:
			continue     # never spawn on top of the player's entry point
		var data: EnemyData = pool[_rng.randi_range(0, pool.size() - 1)]
		var e := ENEMY_SCENE.instantiate()
		e.data = data
		add_child(e)
		e.global_position = pos
		# Depth scaling. Without this a Toy Factory toy had exactly the same
		# health as a Nursery one and only the *count* rose, so later floors got
		# longer rather than harder — and the player's items and skills had
		# outgrown them by floor two.
		var depth := 1.0 + 0.18 * float(floor_index)
		e.health = data.max_health * depth
		if difficulty > 1.2:
			e.scale = Vector2(1.25, 1.25)
			e.health = data.max_health * 1.9 * depth
		elif _rng.randf() < 0.08 + 0.03 * floor_index:
			# champion variant: tinted, tougher, always pays out a coin
			e.champion = true
			e.modulate = Color(1.3, 0.75, 0.8)
			e.scale = Vector2(1.18, 1.18)
			e.health = data.max_health * 1.9 * depth
		placed += 1
	alive_enemies = placed
	if placed == 0:
		_open_doors()
	else:
		_close_doors()


func _spawn_boss(floor_index: int) -> void:
	_close_doors()
	var b := BOSS_SCENES[floor_index % BOSS_SCENES.size()].instantiate()
	add_child(b)
	b.global_position = Vector2(W * 0.5, H * 0.35)
	b.floor_index = floor_index
	alive_enemies = 1


func _spawn_pedestal(pos: Vector2 = Vector2(W * 0.5, H * 0.5)) -> void:
	var item := ContentDB.random_item()
	if item == null:
		return
	var p := ITEM_PEDESTAL.instantiate()
	# fields before add_child: _ready() is what paints the icon and label
	p.item = item
	p.position = pos
	# mark_cleared() and _boss_payout() both run from enemy_died, mid-physics
	add_child.call_deferred(p)


func _spawn_weapon_pedestal(pos: Vector2, price: int = 0) -> void:
	var current: StringName = GameState.weapon.id if GameState.weapon != null else &""
	var w := ContentDB.random_weapon(current)
	if w == null:
		return
	var p := WEAPON_PEDESTAL.instantiate()
	p.weapon = w
	p.price = price
	p.position = pos
	add_child.call_deferred(p)


## Wooden chests are free consumables; gold ones cost coins and pay out
## something that changes the run. `price` of 0 makes a gold chest free, which
## is what a treasure room uses.
func _spawn_chest(pos: Vector2, gold: bool = false, price: int = 0) -> void:
	var c := CHEST.new()
	c.gold = gold
	c.price = price
	c.position = pos
	# mark_cleared() runs from enemy_died, i.e. mid-physics
	add_child.call_deferred(c)


func _spawn_shop() -> void:
	# Three rows, front to back: items you can buy now, skills you invest in,
	# and a chest at the back you probably cannot afford yet.
	var slots := [-80.0, 0.0, 80.0]
	var stocked: Array = []
	for i in slots.size():
		var item := ContentDB.random_item(true, stocked)
		if item == null:
			continue
		stocked.append(item.id)
		var p := ITEM_PEDESTAL.instantiate()
		p.item = item
		p.price = 12 + i * 4 + GameState.floor_index * 5
		add_child(p)
		p.global_position = Vector2(W * 0.5 + slots[i], H * 0.5 + 42)

	# two of the five skills, picked per shop so no single run can max
	# everything at one stall
	var ids: Array = GameState.SKILLS.keys()
	ids.shuffle()
	for i in mini(2, ids.size()):
		_spawn_shrine(Vector2(W * 0.5 + (-96.0 if i == 0 else 96.0), H * 0.5 - 30),
			ids[i])

	_spawn_chest(Vector2(W * 0.5, H * 0.5 - 52), true,
		18 + GameState.floor_index * 6)


func _spawn_shrine(pos: Vector2, id: StringName) -> void:
	var s := SHRINE.new()
	s.skill_id = id
	s.position = pos
	add_child.call_deferred(s)


## Pays out whatever a smashed crate rolled. Lives here rather than on the
## crate because the crate frees itself the moment it breaks — see breakable.gd.
func spawn_crate_drop(kind: String, pos: Vector2) -> void:
	match kind:
		"coin", "heart":
			spawn_pickup(kind, pos)
		"weapon":
			_spawn_weapon_pedestal(pos)
			_announce_drop("SOMETHING WAS IN THERE", Color(0.7, 0.9, 1.0), pos)
		"item":
			_spawn_pedestal(pos)
			_announce_drop("SOMETHING WAS IN THERE", Color(1, 0.9, 0.4), pos)
		"skill":
			var id := GameState.random_unmaxed_skill()
			if id != &"" and GameState.grant_skill(id):
				var def: Dictionary = GameState.SKILLS.get(id, {})
				_announce_drop("%s %d" % [def.get("name", "SKILL"),
					GameState.skill_level(id)], Color(0.6, 1.0, 0.7), pos)
			else:
				spawn_pickup("coin", pos)   # every skill maxed: pay out instead


func _announce_drop(text: String, colour: Color, pos: Vector2) -> void:
	EventBus.toast.emit(text, colour)
	EventBus.screen_shake.emit(3.0, 0.2)
	Effects.spawn_pop(self, pos, 2.4)


func spawn_pickup(kind: String, pos: Vector2) -> void:
	var p := PICKUP_SCENE.instantiate()
	# Fields BEFORE the node enters the tree. Pickup._ready() chooses its
	# texture from `kind` and caches position.y for the bob, so assigning them
	# after add_child() meant every heart drew the coin sprite (it still healed
	# — it just lied about what it was).
	p.kind = kind
	p.position = pos
	# Deferred because loot drops from enemy._die(), which runs inside the
	# physics flush whenever the killing blow came from a projectile.
	add_child.call_deferred(p)


# ── clearing ──────────────────────────────────────────────────────────────
func _on_enemy_died() -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	if alive_enemies == 0:
		mark_cleared()


func mark_cleared() -> void:
	if info.cleared:
		return
	info.cleared = true
	_open_doors()
	AudioManager.play_sfx(preload("res://assets/audio/sfx/room_clear.wav"))
	EventBus.room_cleared.emit(self)
	EventBus.minimap_dirty.emit()
	cleared.emit()
	# a cleared elite room owes you something — off-lane so the solid
	# plinth never blocks the path between doors
	if info.kind == FloorGenerator.RoomKind.ELITE:
		_spawn_pedestal(Vector2(W * 0.5 + 60, H * 0.5 - 50))
	elif info.kind == FloorGenerator.RoomKind.BOSS:
		_boss_payout()
	elif info.kind == FloorGenerator.RoomKind.COMBAT and _rng.randf() < 0.22:
		# an ordinary fight occasionally leaves a chest behind, so clearing a
		# room you did not have to clear is sometimes worth it
		_spawn_chest(Vector2(W * 0.5, H * 0.5 - 46))


func _boss_payout() -> void:
	# A multi-phase fight owes you more than a staircase. The exit portal
	# spawns at the centre; the reward sits diagonally off it so the solid
	# plinth never blocks the walking lanes to the portal.
	var center := Vector2(W * 0.5, H * 0.5)
	if _rng.randf() < 0.5:
		_spawn_pedestal(center + Vector2(60, -50))
	else:
		_spawn_weapon_pedestal(center + Vector2(60, -50))
	var coin_count := 6 + GameState.floor_index * 2
	for i in coin_count:
		var ang := TAU * float(i) / float(coin_count)
		spawn_pickup("coin", center + Vector2.from_angle(ang) * _rng.randf_range(50.0, 90.0))


func _open_doors() -> void:
	for d in _doors:
		d["area"].set_deferred("monitoring", true)
	if info != null and not info.cleared:
		info.cleared = true


func _close_doors() -> void:
	for d in _doors:
		d["area"].set_deferred("monitoring", false)


func room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(W, H))


func entry_point(from_dir: String) -> Vector2:
	# arriving through a door puts you just inside the opposite wall
	match from_dir:
		"u": return Vector2(W * 0.5, H - TILE * 2.0)
		"d": return Vector2(W * 0.5, TILE * 2.0)
		"l": return Vector2(W - TILE * 2.0, H * 0.5)
		"r": return Vector2(TILE * 2.0, H * 0.5)
	return Vector2(W * 0.5, H * 0.5)
