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
	get_tree().quit(0)
