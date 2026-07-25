extends Node

## Contracts. Autoload: MissionManager
##
## Missions advance purely by watching GameState flags. That means a hack, a
## dialogue line, an item pickup, or a trigger volume can all complete an
## objective without any of them importing this script.

var active: Dictionary = {}     ## StringName -> MissionData
var completed: Dictionary = {}  ## StringName -> true


func _ready() -> void:
	EventBus.flag_set.connect(_on_flag_set)
	# Deferred so ContentDB has finished its scan.
	call_deferred("_start_auto_missions")


func _start_auto_missions() -> void:
	for m in ContentDB.all_missions():
		if m.auto_start and m.is_available():
			start_mission(m.id)


func start_mission(mission_id: StringName) -> bool:
	if mission_id == &"" or active.has(mission_id) or completed.has(mission_id):
		return false
	var m := ContentDB.get_mission(mission_id)
	if m == null:
		push_warning("[Missions] unknown mission '%s'" % mission_id)
		return false
	if not m.is_available():
		return false
	active[mission_id] = m
	EventBus.mission_started.emit(mission_id)
	if not m.hidden:
		EventBus.toast_requested.emit("NEW CONTRACT: %s" % m.title)
	# A mission whose objectives are already satisfied should not linger.
	_evaluate(m)
	return true


func _on_flag_set(_flag: StringName) -> void:
	# Cheap: missions are few and objectives are flag lookups.
	for m in active.values().duplicate():
		_evaluate(m)
	# A newly set flag may also unlock a mission that auto-starts.
	_start_auto_missions()


func _evaluate(m: MissionData) -> void:
	if not active.has(m.id):
		return
	var all_done := true
	for i in m.objectives.size():
		var obj: MissionObjective = m.objectives[i]
		if obj == null:
			continue
		if obj.is_complete():
			continue
		if not obj.optional:
			all_done = false
	if all_done and m.objectives.size() > 0:
		complete_mission(m.id)


func complete_mission(mission_id: StringName) -> void:
	var m: MissionData = active.get(mission_id)
	if m == null:
		return
	active.erase(mission_id)
	completed[mission_id] = true
	GameState.set_flags(m.completion_flags)
	GameState.grant_rewards(m.rewards)
	EventBus.mission_completed.emit(mission_id)
	if m.completion_text != "":
		EventBus.toast_requested.emit(m.completion_text)


func is_active(mission_id: StringName) -> bool:
	return active.has(mission_id)


func is_completed(mission_id: StringName) -> bool:
	return completed.has(mission_id)


func active_missions() -> Array:
	return active.values()


func to_dict() -> Dictionary:
	var a: Array[String] = []
	for k in active: a.append(String(k))
	var c: Array[String] = []
	for k in completed: c.append(String(k))
	return { "active": a, "completed": c }


func from_dict(d: Dictionary) -> void:
	active.clear(); completed.clear()
	for id in d.get("active", []):
		var m := ContentDB.get_mission(StringName(id))
		if m != null:
			active[m.id] = m
	for id in d.get("completed", []):
		completed[StringName(id)] = true
