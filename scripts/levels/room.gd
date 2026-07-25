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
# One boss per floor, cycling: Nursery/Attic get the King, Playroom/Toy
# Factory get the General. New bosses just join this list.
const BOSS_SCENES: Array[PackedScene] = [
	preload("res://scenes/bosses/TeddyBearKing.tscn"),
	preload("res://scenes/bosses/GingerbreadGeneral.tscn"),
]

const FLOOR_TEX := preload("res://assets/environment/tiles_floor.png")
const WALL_TEX := preload("res://assets/environment/tiles_wall.png")
const CRATE_TEX := preload("res://assets/environment/prop_crate.png")

var info                       ## FloorGenerator.RoomInfo
var alive_enemies: int = 0
var _doors: Array = []
var _rng := RandomNumberGenerator.new()

signal cleared()


func build(room_info) -> void:
	info = room_info
	_rng.seed = info.seed_value if info.seed_value != 0 else randi()
	_paint_floor()
	_build_walls()
	_scatter_decor()


# ── visuals ───────────────────────────────────────────────────────────────
func _paint_floor() -> void:
	var holder := Node2D.new()
	holder.name = "Floor"
	holder.z_index = -20
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
	area.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player"):
			RunManager.travel(dir))
	_doors.append({"dir": dir, "area": area})


func _scatter_decor() -> void:
	if info.kind == FloorGenerator.RoomKind.BOSS:
		return
	var count := _rng.randi_range(2, 6)
	for i in count:
		var tx := _rng.randi_range(3, COLS - 4)
		var ty := _rng.randi_range(3, ROWS - 4)
		# keep the middle and the door lanes clear
		if absi(tx - COLS / 2) < 3 and absi(ty - ROWS / 2) < 3:
			continue
		if absi(tx - COLS / 2) <= 1 or absi(ty - ROWS / 2) <= 1:
			continue
		var crate := preload("res://scripts/levels/breakable.gd").new()
		crate.position = Vector2(tx * TILE + 16, ty * TILE + 16)
		crate.z_index = 1
		add_child(crate)


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
			# Sometimes the treasure is a whole new weapon.
			if _rng.randf() < 0.4:
				_spawn_weapon_pedestal(Vector2(W * 0.5, H * 0.5))
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
		if difficulty > 1.2:
			e.scale = Vector2(1.25, 1.25)
			e.health = data.max_health * 1.9
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
	add_child(p)
	p.global_position = pos


func _spawn_weapon_pedestal(pos: Vector2, price: int = 0) -> void:
	var current: StringName = GameState.weapon.id if GameState.weapon != null else &""
	var w := ContentDB.random_weapon(current)
	if w == null:
		return
	var p := WEAPON_PEDESTAL.instantiate()
	p.weapon = w
	p.price = price
	add_child(p)
	p.global_position = pos


func _spawn_shop() -> void:
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
		p.global_position = Vector2(W * 0.5 + slots[i], H * 0.5)


func spawn_pickup(kind: String, pos: Vector2) -> void:
	var p := PICKUP_SCENE.instantiate()
	add_child(p)
	p.global_position = pos
	p.kind = kind


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
	# a cleared elite room owes you something
	if info.kind == FloorGenerator.RoomKind.ELITE:
		_spawn_pedestal()
	elif info.kind == FloorGenerator.RoomKind.BOSS:
		_boss_payout()


func _boss_payout() -> void:
	# A multi-phase fight owes you more than a staircase. The exit portal
	# spawns at the centre, so the reward sits just above it.
	var center := Vector2(W * 0.5, H * 0.5)
	if _rng.randf() < 0.5:
		_spawn_pedestal(center + Vector2(0, -70))
	else:
		_spawn_weapon_pedestal(center + Vector2(0, -70))
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
