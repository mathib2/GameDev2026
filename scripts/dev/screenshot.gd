extends Node

## Grabs frames from a live run and writes them to PNG, then quits.
##
##   godot --autostart --screenshot [--shot-delay 6] [--shot-count 3]
##
## The smoke test proves the game does not crash; it cannot tell you the floor
## reads too dark or the vignette is inverted. This is the cheap way to look at
## the thing without sitting in front of it, and unlike --headless it needs a
## real window, because there is nothing to capture otherwise.
##
## Frames land in user:// (see OS.get_user_data_dir()) as shot_0.png, shot_1.png…

var _delay: float = 6.0
var _count: int = 3
var _gap: float = 2.5

var _elapsed: float = 0.0
var _taken: int = 0
var _next: float = 0.0


func _ready() -> void:
	# Must keep ticking while the tree is paused, or --shot-pause deadlocks:
	# pausing stops this node's _process, so the capture never happens and the
	# run never quits.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--shot-delay" and i + 1 < args.size():
			_delay = float(args[i + 1])
		elif args[i] == "--shot-count" and i + 1 < args.size():
			_count = int(args[i + 1])
		elif args[i] == "--shot-gap" and i + 1 < args.size():
			_gap = float(args[i + 1])
	_next = _delay
	# --shot-wiki opens the MY STUFF panel before capturing. Screenshots cannot
	# press keys, and a panel that only opens on F2 is otherwise unverifiable
	# without a human.
	if args.has("--shot-wiki"):
		_open_wiki.call_deferred()
	if args.has("--shot-mod"):
		_open_mod.call_deferred()
	if args.has("--shot-pause"):
		# the pause screen is only reachable by keypress, same problem as the
		# wiki and mod panel
		_open_pause.call_deferred()
	print("[SHOT] writing %d frames to %s" % [_count, OS.get_user_data_dir()])


func _open_pause() -> void:
	var main := get_parent()
	if main != null and main.has_method("_toggle_pause"):
		main._toggle_pause()


func _open_wiki() -> void:
	var main := get_parent()
	if main != null and main.get("wiki") != null:
		main.wiki.toggle()


## The mod panel only opens on F1, and a screenshot cannot press keys.
func _open_mod() -> void:
	for n in get_parent().get_children():
		if n.get_script() == null:
			continue
		if String(n.get_script().resource_path).ends_with("mod_menu.gd"):
			for c in n.get_children():
				if c is PanelContainer:
					c.visible = true
			return


func _process(delta: float) -> void:
	_elapsed += delta
	# keep the run alive long enough to photograph it
	GameState.health = GameState.max_health()
	if _elapsed < _next or _taken >= _count:
		return
	_next = _elapsed + _gap
	_grab()
	if _taken >= _count:
		print("[SHOT] done")
		get_tree().quit(0)


func _grab() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "user://shot_%d.png" % _taken
	var err := img.save_png(path)
	if err != OK:
		printerr("[SHOT] failed to write %s (%d)" % [path, err])
	else:
		print("[SHOT] %s  %dx%d" % [path, img.get_width(), img.get_height()])
	_taken += 1
