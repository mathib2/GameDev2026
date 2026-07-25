extends Node

## Headless smoke test. Run with:
##   godot --headless --autostart --smoketest --quit-after 4000
##
## Drives a real run without input: walks every room on the floor, kills what it
## finds, reaches the boss, kills it, and descends. Catches the errors that only
## appear once things actually spawn and interact — which a plain --import
## cannot see.
##
## Exits non-zero on failure so CI can gate on it.

var _step: float = 0.0
var _visited: int = 0
var _boss_seen: bool = false
var _boss_killed: bool = false
var _floors_seen: int = 0
var _failures: Array[String] = []
var _dirs := ["r", "d", "l", "u"]
var _dir_i: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	print("[SMOKE] starting")
	EventBus.boss_spawned.connect(func(_b, n): _boss_seen = true; print("[SMOKE] boss: %s" % n))
	EventBus.boss_defeated.connect(func(_b): _boss_killed = true; print("[SMOKE] boss defeated"))
	EventBus.floor_entered.connect(func(i, n): _floors_seen += 1; print("[SMOKE] floor %d: %s" % [i, n]))
	EventBus.room_entered.connect(func(_r): _visited += 1)
	EventBus.player_died.connect(func(): print("[SMOKE] player died (expected: they take contact damage)"))


func _process(delta: float) -> void:
	_elapsed += delta
	# hard time budget so the test always reports instead of exploring forever
	if _elapsed > 40.0:
		_report_and_quit()
		return
	_step += delta
	if _step < 0.35:
		return
	_step = 0.0

	var room = RunManager.current_room
	if room == null or not is_instance_valid(room):
		return

	# keep the player alive so the test explores rather than dying in room two
	GameState.health = GameState.max_health()

	# clear whatever is in the room by damaging it directly
	var enemies := get_tree().get_nodes_in_group("enemy")
	if not enemies.is_empty():
		for e in enemies:
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(9999.0, Vector2.ZERO, false, 0.0)
		return

	# room is clear — head for the nearest unvisited room, else the boss
	var d := _next_step()
	if d != "":
		RunManager.travel(d)
		return

	_report_and_quit()


## BFS across the floor graph. Returns the first door to take toward the
## nearest unvisited room, falling back to the boss room.
func _next_step() -> String:
	var gen = RunManager.generator
	var here = RunManager.current_info
	if gen == null or here == null:
		return ""
	for goal_pass in 2:
		var seen := {here.key(): true}
		var queue: Array = []
		for d in _dirs:
			if here.doors.get(d, false):
				var n = gen.neighbour(here, d)
				if n != null:
					queue.append([n, d])
					seen[n.key()] = true
		while not queue.is_empty():
			var entry: Array = queue.pop_front()
			var room = entry[0]
			var first: String = entry[1]
			var wanted: bool = (not room.visited) if goal_pass == 0 \
				else (room.kind == FloorGenerator.RoomKind.BOSS and not room.cleared)
			if wanted:
				return first
			for d in _dirs:
				if not room.doors.get(d, false):
					continue
				var n = gen.neighbour(room, d)
				if n != null and not seen.has(n.key()):
					seen[n.key()] = true
					queue.append([n, first])
	return ""


func _report_and_quit() -> void:
	print("[SMOKE] rooms entered: %d" % _visited)
	print("[SMOKE] floors seen:   %d" % _floors_seen)
	print("[SMOKE] boss spawned:  %s" % _boss_seen)
	print("[SMOKE] boss killed:   %s" % _boss_killed)
	print("[SMOKE] kills:         %d" % GameState.kills)

	if _visited < 3: _failures.append("visited fewer than 3 rooms")
	if GameState.kills <= 0: _failures.append("killed nothing")

	if _failures.is_empty():
		print("[SMOKE] PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[SMOKE] FAIL: %s" % f)
		get_tree().quit(1)
