extends Node

## Physical walkthrough test. Run with:
##   godot --headless --autostart --walktest --quit-after 40000
##
## Unlike the smoke test (which teleports via RunManager.travel), this bot
## steers the player with real input actions through real door triggers and
## real collision. It exists to catch what teleporting cannot: doors that
## never re-arm, triggers that don't fire, geometry the player gets stuck on.
##
## Exits non-zero on failure so CI can gate on it.

const SPEED_UP := 4.0
const STUCK_LIMIT := 6.0        ## sim-seconds without progress before logging

var _failures: Array[String] = []
var _rooms: int = 0
var _floors: int = 0
var _bosses: int = 0
var _won: bool = false
var _elapsed: float = 0.0
var _stuck: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _done: bool = false
var _debug_timer: float = 0.0

var _actions := [&"move_left", &"move_right", &"move_up", &"move_down"]


func _ready() -> void:
	print("[WALK] starting")
	EventBus.floor_entered.connect(func(i, n): _floors += 1; print("[WALK] floor %d: %s" % [i, n]))
	EventBus.room_entered.connect(func(_r): _rooms += 1; _stuck = 0.0)
	EventBus.boss_defeated.connect(func(_b): _bosses += 1; print("[WALK] boss down"))
	EventBus.run_ended.connect(func(v: bool) -> void:
		_won = v
		print("[WALK] run ended, victory=%s" % v)
		_report_and_quit())


func _physics_process(delta: float) -> void:
	if _done:
		return
	if Engine.time_scale < SPEED_UP:
		Engine.time_scale = SPEED_UP
	_elapsed += delta
	if _elapsed > 600.0:
		_failures.append("timed out before finishing the run")
		_report_and_quit()
		return

	var player = RunManager.player
	var room = RunManager.current_room
	if player == null or room == null or not is_instance_valid(room):
		return
	GameState.health = GameState.max_health()

	# clear combat instantly — travel physics is what we are testing
	var enemies := get_tree().get_nodes_in_group("enemy")
	if not enemies.is_empty():
		_release_all()
		for e in enemies:
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(9999.0, Vector2.ZERO, false, 0.0)
		return

	var target := _current_target(room)
	_debug_timer += delta
	if _debug_timer > 10.0:
		_debug_timer = 0.0
		var info = RunManager.current_info
		print("[WALK] at=%s target=%s dir=%s kind=%d vel=%s" % [
			player.global_position.round(), target.round(), _next_dir(),
			info.kind if info else -1, player.velocity.round()])
	if target == Vector2.INF:
		return

	# stuck detection: the whole point of this harness
	if player.global_position.distance_to(_last_pos) < 2.0 * delta * 60.0:
		_stuck += delta
	else:
		_stuck = 0.0
	_last_pos = player.global_position
	if _stuck > STUCK_LIMIT:
		var info = RunManager.current_info
		_failures.append("STUCK at %s heading for %s in room kind=%d floor=%d" % [
			player.global_position, target, info.kind if info else -1, GameState.floor_index])
		print("[WALK] FAIL: ", _failures.back())
		_stuck = 0.0
		# hard-recover so the rest of the run still gets tested
		var d := _next_dir()
		if d != "":
			RunManager.travel(d)
		return

	_steer(player.global_position, target)


## Where should the bot be walking right now?
func _current_target(room) -> Vector2:
	var d := _next_dir()
	if d != "":
		# waypoint: mid-lane first so crates never block the approach
		var door := _door_pos(room, d)
		var center := Vector2(room.W * 0.5, room.H * 0.5)
		var player = RunManager.player
		var on_lane: bool = (absf(player.global_position.x - center.x) < 26.0) \
			if (d == "u" or d == "d") else (absf(player.global_position.y - center.y) < 26.0)
		return door if on_lane else center
	# floor exhausted: ride the exit portal at the centre
	if _bosses > 0:
		return Vector2(room.W * 0.5, room.H * 0.5)
	return Vector2.INF


func _door_pos(room, dir: String) -> Vector2:
	match dir:
		"u": return Vector2(room.W * 0.5, 4.0)
		"d": return Vector2(room.W * 0.5, room.H - 4.0)
		"l": return Vector2(4.0, room.H * 0.5)
		"r": return Vector2(room.W - 4.0, room.H * 0.5)
	return Vector2(room.W * 0.5, room.H * 0.5)


func _steer(from: Vector2, to: Vector2) -> void:
	var d := to - from
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	if d.x < -3.0: Input.action_press(&"move_left")
	elif d.x > 3.0: Input.action_press(&"move_right")
	if d.y < -3.0: Input.action_press(&"move_up")
	elif d.y > 3.0: Input.action_press(&"move_down")


func _release_all() -> void:
	for a in _actions:
		Input.action_release(a)


func _next_dir() -> String:
	var gen = RunManager.generator
	var here = RunManager.current_info
	if gen == null or here == null:
		return ""
	var d := _bfs_step(gen, here, func(r): return not r.visited)
	if d != "":
		return d
	d = _bfs_step(gen, here, func(r): return r.kind == FloorGenerator.RoomKind.BOSS and not r.cleared)
	if d != "":
		return d
	# everything done — head back to the boss room, where the exit portal is
	if _bosses > 0 and here.kind != FloorGenerator.RoomKind.BOSS:
		return _bfs_step(gen, here, func(r): return r.kind == FloorGenerator.RoomKind.BOSS)
	return ""


func _bfs_step(gen, here, want: Callable) -> String:
	var seen := {here.key(): true}
	var queue: Array = []
	for d in ["u", "d", "l", "r"]:
		if here.doors.get(d, false):
			var n = gen.neighbour(here, d)
			if n != null:
				queue.append([n, d])
				seen[n.key()] = true
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var r = entry[0]
		var first: String = entry[1]
		if want.call(r):
			return first
		for d in ["u", "d", "l", "r"]:
			if not r.doors.get(d, false):
				continue
			var n = gen.neighbour(r, d)
			if n != null and not seen.has(n.key()):
				seen[n.key()] = true
				queue.append([n, first])
	return ""


func _report_and_quit() -> void:
	if _done:
		return
	_done = true
	_release_all()
	Engine.time_scale = 1.0
	print("[WALK] rooms entered: %d" % _rooms)
	print("[WALK] floors seen:   %d" % _floors)
	print("[WALK] bosses killed: %d" % _bosses)
	print("[WALK] victory:       %s" % _won)
	if not _won:
		_failures.append("never reached victory")
	if _failures.is_empty():
		print("[WALK] PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[WALK] FAIL: %s" % f)
		get_tree().quit(1)
