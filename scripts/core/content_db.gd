extends Node

## Content index. Autoload: ContentDB
##
## Scans res://data at boot and indexes every Resource by id. Content is
## discovered, not registered — drop a .tres in the right folder and it is in
## the game. No manifest for teammates to conflict on.

const DATA_ROOT := "res://data"

var enemies: Dictionary = {}   ## StringName -> EnemyData
var weapons: Dictionary = {}   ## StringName -> WeaponData
var items: Dictionary = {}     ## StringName -> ItemData
var bosses: Dictionary = {}    ## StringName -> BossData
var layouts: Dictionary = {}   ## StringName -> RoomLayoutData

var _errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	enemies.clear(); weapons.clear(); items.clear(); bosses.clear()
	layouts.clear(); _errors.clear()
	_scan(DATA_ROOT)
	for e in _errors:
		push_warning("[ContentDB] %s" % e)
	print("[ContentDB] %d enemies, %d weapons, %d items, %d data-bosses, %d room layouts"
		% [enemies.size(), weapons.size(), items.size(), bosses.size(), layouts.size()])


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	var seen := {}
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(path.path_join(entry))
		else:
			# In an exported build Godot converts text resources to binary and
			# leaves a `<name>.tres.remap` stub in the PCK, so a naive
			# `.ends_with(".tres")` scan finds NOTHING once exported and the
			# game ships with no content. Strip the suffix and load the
			# original path — ResourceLoader follows the remap.
			var name := entry
			if name.ends_with(".remap"):
				name = name.trim_suffix(".remap")
			if name.ends_with(".tres") or name.ends_with(".res"):
				var full := path.path_join(name)
				if not seen.has(full):
					seen[full] = true
					_index(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _index(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		_errors.append("could not load %s" % path)
		return
	var raw = res.get(&"id")
	if raw == null or StringName(raw) == &"":
		_errors.append("%s has no id; skipped" % path)
		return
	var id := StringName(raw)
	var bucket: Dictionary = {}
	if res is EnemyData: bucket = enemies
	elif res is WeaponData: bucket = weapons
	elif res is ItemData: bucket = items
	elif res is BossData: bucket = bosses
	elif res is RoomLayoutData:
		# A layout that blocks a door lane or strands an enemy behind cover
		# soft-locks the run it turns up in, so it is refused at the door
		# rather than shipped. The room falls back to a generated layout.
		var layout := res as RoomLayoutData
		var problems := layout.validate()
		if not problems.is_empty():
			_errors.append("%s is not a usable layout: %s" % [path, ", ".join(problems)])
			return
		bucket = layouts
	else:
		_errors.append("%s has an unrecognised type; skipped" % path)
		return
	if bucket.has(id):
		_errors.append("duplicate id '%s' (%s)" % [id, path])
	bucket[id] = res


func get_enemy(id: StringName) -> EnemyData: return enemies.get(id)
func get_weapon(id: StringName) -> WeaponData: return weapons.get(id)
func get_item(id: StringName) -> ItemData: return items.get(id)


## Weighted random item the player does not already own. `exclude_ids`
## lets a shop avoid stocking the same item twice.
func random_item(exclude_owned: bool = true, exclude_ids: Array = []) -> ItemData:
	var pool: Array = []
	var total := 0.0
	for it in items.values():
		if exclude_owned and it.unique and GameState.has_item(it.id):
			continue
		if exclude_ids.has(it.id):
			continue
		pool.append(it)
		total += maxf(0.01, it.weight)
	if pool.is_empty():
		return null
	var roll := randf() * total
	for it in pool:
		roll -= maxf(0.01, it.weight)
		if roll <= 0.0:
			return it
	return pool.back()


## Random equippable weapon, excluding fists and (optionally) one id —
## usually whatever the player is already holding.
func random_weapon(exclude: StringName = &"") -> WeaponData:
	var pool: Array = []
	for w in weapons.values():
		if w.id == &"fists" or w.id == exclude:
			continue
		pool.append(w)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## Every authored layout that fits this room kind and depth. Kind names are the
## lowercase RoomKind names — see FloorGenerator.kind_name().
func layouts_for(kind_name: String, floor_index: int) -> Array:
	var pool: Array = []
	for l in layouts.values():
		if l.suits(kind_name, floor_index):
			pool.append(l)
	return pool


## Weighted pick, drawn from the room's own RNG so walking back into a room
## rebuilds the same furniture. Null when the library has nothing to offer,
## which is the generator's cue to invent something.
func random_layout(kind_name: String, floor_index: int, rng: RandomNumberGenerator) -> RoomLayoutData:
	var pool := layouts_for(kind_name, floor_index)
	if pool.is_empty():
		return null
	var total := 0.0
	for l in pool:
		total += maxf(0.01, l.weight)
	var roll := rng.randf() * total
	for l in pool:
		roll -= maxf(0.01, l.weight)
		if roll <= 0.0:
			return l
	return pool.back()


func enemies_for_floor(index: int) -> Array:
	# Each enemy declares its own min_floor/max_floor in data; core keeps no
	# content lists. A toy with min == max is native to exactly that floor.
	var pool: Array = []
	for e in enemies.values():
		if e.min_floor <= index and (e.max_floor < 0 or index <= e.max_floor):
			pool.append(e)
	return pool if not pool.is_empty() else enemies.values()
