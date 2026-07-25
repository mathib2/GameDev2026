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

var _errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	enemies.clear(); weapons.clear(); items.clear(); _errors.clear()
	_scan(DATA_ROOT)
	for e in _errors:
		push_warning("[ContentDB] %s" % e)
	print("[ContentDB] %d enemies, %d weapons, %d items"
		% [enemies.size(), weapons.size(), items.size()])


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


func enemies_for_floor(index: int) -> Array:
	# Each enemy declares its own min_floor in data; core keeps no content lists.
	var pool: Array = []
	for e in enemies.values():
		if e.min_floor <= index:
			pool.append(e)
	return pool if not pool.is_empty() else enemies.values()
