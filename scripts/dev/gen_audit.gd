extends Node

## Statistical audit of floor generation and the loot economy.
##
##   godot --headless --genaudit [--audit-runs 400]
##
## The smoke test walks one run and tells you it did not crash. It cannot tell
## you that a shop appears on only half of floor 1, because a single run that
## happens to have four dead ends looks perfectly fine. Rarity bugs need
## counting, not playing.

var _runs: int = 400


func _ready() -> void:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--audit-runs" and i + 1 < args.size():
			_runs = int(args[i + 1])
	call_deferred("_run")


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	print("[AUDIT] %d floors per index\n" % _runs)
	print("floor | rooms | deadends |  shop | treasure | secret | elite")
	print("------+-------+----------+-------+----------+--------+------")

	var total_missing_shop := 0
	for fi in RunManager.total_floors():
		var rooms := 0.0
		var deads := 0.0
		var counts := {FloorGenerator.RoomKind.SHOP: 0,
			FloorGenerator.RoomKind.TREASURE: 0,
			FloorGenerator.RoomKind.SECRET: 0,
			FloorGenerator.RoomKind.ELITE: 0}
		for i in _runs:
			var g := FloorGenerator.new()
			g.generate(fi, rng)
			rooms += g.order.size()
			var d := 0
			var seen := {}
			for r in g.order:
				if r != g.start_room and r.door_count() == 1:
					d += 1
				if counts.has(r.kind):
					seen[r.kind] = true
			deads += d
			for k in seen:
				counts[k] += 1
		var shop_pct := 100.0 * float(counts[FloorGenerator.RoomKind.SHOP]) / float(_runs)
		total_missing_shop += _runs - counts[FloorGenerator.RoomKind.SHOP]
		print("  %d   | %5.1f | %8.1f | %4.0f%% | %7.0f%% | %5.0f%% | %4.0f%%" % [
			fi, rooms / _runs, deads / _runs, shop_pct,
			100.0 * float(counts[FloorGenerator.RoomKind.TREASURE]) / float(_runs),
			100.0 * float(counts[FloorGenerator.RoomKind.SECRET]) / float(_runs),
			100.0 * float(counts[FloorGenerator.RoomKind.ELITE]) / float(_runs)])

	print("\n[AUDIT] floors with NO shop at all: %d of %d"
		% [total_missing_shop, _runs * RunManager.total_floors()])

	# How many weapons does a run actually get offered? Model the drop sites.
	# Regression guard. Treasure and shop rooms used to be marked
	# `spawned = true` at generation, which is the flag Room.populate() reads
	# to decide it has already filled the room — so they returned early on the
	# first visit and were permanently empty. Every shop in the game was a bare
	# room, and nothing caught it because the smoke test never looks inside one.
	var bad := 0
	var checked := 0
	for fi in RunManager.total_floors():
		for i in 60:
			var g := FloorGenerator.new()
			g.generate(fi, rng)
			for r in g.order:
				if r.kind in [FloorGenerator.RoomKind.SHOP,
						FloorGenerator.RoomKind.TREASURE,
						FloorGenerator.RoomKind.SECRET]:
					checked += 1
					if r.spawned:
						bad += 1
	if bad > 0:
		printerr("[AUDIT] FAIL: %d of %d special rooms pre-marked spawned "
			% [bad, checked] + "(they will populate as empty)")
	else:
		print("\n[AUDIT] %d special rooms, none pre-marked spawned — they fill"
			% checked)

	print("\n[AUDIT] weapons in ContentDB: %d" % ContentDB.weapons.size())
	var got := 0
	for i in _runs:
		var offers := 0
		for fi in RunManager.total_floors():
			# treasure room: 30% weapon pedestal, 25% gold chest -> 45% weapon
			if rng.randf() < 0.30: offers += 1
			elif rng.randf() < 0.25 and rng.randf() < 0.45: offers += 1
			# boss payout: 50% weapon
			if rng.randf() < 0.50: offers += 1
		if offers > 0:
			got += 1
	print("[AUDIT] runs offered >=1 weapon: %.0f%%" % (100.0 * float(got) / float(_runs)))

	_audit_layouts(rng)
	get_tree().quit(0)


## Room layouts: what the library covers, and whether the generator keeps its
## promises over enough rooms to be trusted.
##
## The authored library is already validated at load — ContentDB refuses a
## layout that blocks a door lane — so what is left worth counting is coverage
## (a room kind with no layouts quietly falls back to a bare room) and the
## generator, which is safe *by construction* rather than by check(), and so is
## exactly the kind of claim that deserves to be counted rather than believed.
func _audit_layouts(rng: RandomNumberGenerator) -> void:
	print("\n[AUDIT] room layouts indexed: %d" % ContentDB.layouts.size())
	var deepest := RunManager.total_floors() - 1
	for kind in FloorGenerator.KIND_NAMES:
		if kind == "boss":
			continue                  # a boss arena never takes a layout
		var early := ContentDB.layouts_for(kind, 0).size()
		var late := ContentDB.layouts_for(kind, deepest).size()
		var note := "" if early > 0 else "   <- none on floor 0"
		print("  %-9s %2d on floor 0, %2d on floor %d%s" % [kind, early, late, deepest, note])

	_audit_enemy_pools()

	var trials := 600
	var crates := 0
	var lane_blocked := 0
	var no_anchors := 0
	for i in trials:
		var l := RoomLayout.procedural(rng, i % RunManager.total_floors())
		crates += l.obstacles.size()
		if l.enemy_spots.is_empty() and l.big_spots.is_empty():
			no_anchors += 1
		for t in l.obstacles:
			if RoomLayout.is_lane(t):
				lane_blocked += 1
				break
	print("[AUDIT] %d generated rooms: %.1f crates avg, %d blocked a door lane, "
		% [trials, float(crates) / float(trials), lane_blocked]
		+ "%d had nowhere to spawn" % no_anchors)
	if lane_blocked > 0 or no_anchors > 0:
		printerr("[AUDIT] FAIL: the room generator produced an unplayable room")


## Which toys each floor can actually field. Floor-native enemies are gated by
## min_floor == max_floor in data — the thing most worth counting is that a
## native never leaks onto another floor, and that every floor HAS natives.
func _audit_enemy_pools() -> void:
	print("\n[AUDIT] enemy pool by floor (* = native to that floor only)")
	for fi in RunManager.total_floors():
		var pool: Array = ContentDB.enemies_for_floor(fi)
		var names := PackedStringArray()
		var natives := 0
		for e in pool:
			if e.max_floor >= 0 and e.min_floor == e.max_floor:
				names.append("*" + String(e.id))
				natives += 1
			else:
				names.append(String(e.id))
		names.sort()
		print("  floor %d: %2d toys, %d native  [%s]" % [fi, pool.size(), natives,
			", ".join(names)])
		for e in pool:
			if e.max_floor >= 0 and (fi < e.min_floor or fi > e.max_floor):
				printerr("[AUDIT] FAIL: %s leaked onto floor %d" % [e.id, fi])
