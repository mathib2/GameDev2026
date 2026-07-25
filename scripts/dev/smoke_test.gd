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
var _bosses_killed: int = 0
var _floors_seen: int = 0
var _failures: Array[String] = []
var _dirs := ["r", "d", "l", "u"]
var _dir_i: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	print("[SMOKE] starting")
	EventBus.boss_spawned.connect(func(_b, n): _boss_seen = true; print("[SMOKE] boss: %s" % n))
	EventBus.boss_defeated.connect(func(_b):
		_boss_killed = true
		_bosses_killed += 1
		print("[SMOKE] boss defeated"))
	EventBus.floor_entered.connect(func(i, n): _floors_seen += 1; print("[SMOKE] floor %d: %s" % [i, n]))
	EventBus.room_entered.connect(func(_r): _visited += 1)
	EventBus.player_died.connect(func(): print("[SMOKE] player died (expected: they take contact damage)"))


func _process(delta: float) -> void:
	_elapsed += delta
	# hard time budget so the test always reports instead of exploring forever.
	# Scales with the floor count — a four-floor run needs roughly twice the
	# wall clock a two-floor one did.
	if _elapsed > 45.0 * float(RunManager.total_floors()):
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

	# Floor exhausted — walk back to the boss room and ride the exit portal
	# down, repeating until the run is out of floors. There is one boss per
	# floor, so descending all of them is the only way every boss script
	# actually gets executed; stopping at two silently skipped the rest.
	if _bosses_killed >= 1 and _floors_seen < RunManager.total_floors():
		var here = RunManager.current_info
		if here != null and here.kind == FloorGenerator.RoomKind.BOSS:
			if RunManager.player != null:
				RunManager.player.global_position = Vector2(room.W * 0.5, room.H * 0.5)
		else:
			var back := _bfs_step(func(r): return r.kind == FloorGenerator.RoomKind.BOSS)
			if back != "":
				RunManager.travel(back)
		return

	_report_and_quit()


## BFS across the floor graph. Returns the first door to take toward the
## nearest unvisited room, falling back to the boss room.
func _next_step() -> String:
	var d := _bfs_step(func(r): return not r.visited)
	if d != "":
		return d
	return _bfs_step(func(r): return r.kind == FloorGenerator.RoomKind.BOSS and not r.cleared)


## First door to take toward the nearest room matching `want`.
func _bfs_step(want: Callable) -> String:
	var gen = RunManager.generator
	var here = RunManager.current_info
	if gen == null or here == null:
		return ""
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
		if want.call(room):
			return first
		for d in _dirs:
			if not room.doors.get(d, false):
				continue
			var n = gen.neighbour(room, d)
			if n != null and not seen.has(n.key()):
				seen[n.key()] = true
				queue.append([n, first])
	return ""


## Skills are bought by walking into a shrine, which this test never does — it
## clears rooms by calling take_damage() directly. So exercise the economy
## here instead: it is pure state, and a silent break in it would otherwise
## ship unnoticed.
func _check_skills() -> void:
	var before_dmg := GameState.stat("damage_mult")
	var cost := GameState.skill_cost(&"power")
	GameState.coins = cost
	if not GameState.upgrade_skill(&"power"):
		_failures.append("could not buy POWER with exactly its cost in coins")
		return
	if GameState.skill_level(&"power") != 1:
		_failures.append("POWER did not reach level 1 after purchase")
	if GameState.stat("damage_mult") <= before_dmg:
		_failures.append("POWER did not raise damage_mult")
	if GameState.coins != 0:
		_failures.append("skill purchase did not spend the coins")
	# and the guard: no coins, no level
	if GameState.upgrade_skill(&"power"):
		_failures.append("bought a skill level with 0 coins")
	print("[SMOKE] skills:        power lvl %d, damage_mult %.2f -> %.2f"
		% [GameState.skill_level(&"power"), before_dmg,
		   GameState.stat("damage_mult")])


func _report_and_quit() -> void:
	print("[SMOKE] rooms entered: %d" % _visited)
	print("[SMOKE] floors seen:   %d" % _floors_seen)
	print("[SMOKE] boss spawned:  %s" % _boss_seen)
	print("[SMOKE] bosses killed: %d" % _bosses_killed)
	print("[SMOKE] kills:         %d" % GameState.kills)

	_check_skills()

	var want := RunManager.total_floors()
	if _visited < 3: _failures.append("visited fewer than 3 rooms")
	if GameState.kills <= 0: _failures.append("killed nothing")
	# Every floor has its own boss script, and a boss script is the easiest
	# thing in this project to break without noticing, so the gate is "all of
	# them ran" rather than a fixed number.
	if _floors_seen < want:
		_failures.append("only reached floor %d of %d" % [_floors_seen, want])
	if _bosses_killed < want:
		_failures.append("only killed %d of %d bosses" % [_bosses_killed, want])

	if _failures.is_empty():
		print("[SMOKE] PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[SMOKE] FAIL: %s" % f)
		get_tree().quit(1)
