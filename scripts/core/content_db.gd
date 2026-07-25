extends Node

## Content index. Autoload: ContentDB
##
## Scans res://data at boot and indexes every Resource by its `id`. This is the
## mechanism that makes the project data-driven: to add content you drop a .tres
## in the right folder and it is picked up automatically. Nothing registers
## anything by hand, and no core script contains a list of NPCs, items, or
## missions.
##
## Lookup is by StringName id, so data can reference other data loosely (an
## ItemData id in a reward, a mission id in a dialogue line) without hard
## resource links and the merge conflicts those cause.

const DATA_ROOT := "res://data"

var items: Dictionary = {}          ## StringName -> ItemData
var npcs: Dictionary = {}           ## StringName -> NPCData
var missions: Dictionary = {}       ## StringName -> MissionData
var hack_targets: Dictionary = {}   ## StringName -> HackTargetData
var locations: Dictionary = {}      ## StringName -> LocationData
var cyberspaces: Dictionary = {}    ## StringName -> CyberspaceData
var enemies: Dictionary = {}        ## StringName -> EnemyData

var _load_errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	items.clear(); npcs.clear(); missions.clear()
	hack_targets.clear(); locations.clear(); cyberspaces.clear(); enemies.clear()
	_load_errors.clear()
	_scan(DATA_ROOT)
	if _load_errors.size() > 0:
		for e in _load_errors:
			push_warning("[ContentDB] %s" % e)
	print("[ContentDB] %d items, %d npcs, %d missions, %d hack targets, %d locations, %d constructs"
		% [items.size(), npcs.size(), missions.size(), hack_targets.size(),
		locations.size(), cyberspaces.size()])


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan(full)
		elif name.ends_with(".tres") or name.ends_with(".res"):
			_index(full)
		name = dir.get_next()
	dir.list_dir_end()


func _index(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		_load_errors.append("could not load %s" % path)
		return
	# Object.get() returns null for a property that does not exist, which is a
	# safer existence check than `in` across Resource subclasses.
	var raw_id = res.get(&"id")
	if raw_id == null:
		_load_errors.append("%s has no `id` field; skipped" % path)
		return
	var id := StringName(raw_id)
	if id == &"":
		_load_errors.append("%s has an empty id; skipped" % path)
		return

	var bucket := _bucket_for(res)
	if bucket == null:
		_load_errors.append("%s has an unrecognised type; skipped" % path)
		return
	if bucket.has(id):
		_load_errors.append("duplicate id '%s' (%s) — later file wins" % [id, path])
	bucket[id] = res


func _bucket_for(res: Resource) -> Dictionary:
	# Order matters: NPCData and EnemyData both extend CharacterData.
	if res is NPCData: return npcs
	if res is EnemyData: return enemies
	if res is ItemData: return items
	if res is MissionData: return missions
	if res is HackTargetData: return hack_targets
	if res is LocationData: return locations
	if res is CyberspaceData: return cyberspaces
	return {}


# ── Lookup helpers ────────────────────────────────────────────────────────
func get_item(id: StringName) -> ItemData: return items.get(id)
func get_npc(id: StringName) -> NPCData: return npcs.get(id)
func get_mission(id: StringName) -> MissionData: return missions.get(id)
func get_hack_target(id: StringName) -> HackTargetData: return hack_targets.get(id)
func get_location(id: StringName) -> LocationData: return locations.get(id)
func get_cyberspace(id: StringName) -> CyberspaceData: return cyberspaces.get(id)
func get_enemy(id: StringName) -> EnemyData: return enemies.get(id)

func all_missions() -> Array:
	return missions.values()

func load_errors() -> Array[String]:
	return _load_errors
