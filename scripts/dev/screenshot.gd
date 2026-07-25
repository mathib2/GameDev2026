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
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--shot-delay" and i + 1 < args.size():
			_delay = float(args[i + 1])
		elif args[i] == "--shot-count" and i + 1 < args.size():
			_count = int(args[i + 1])
		elif args[i] == "--shot-gap" and i + 1 < args.size():
			_gap = float(args[i + 1])
	_next = _delay
	print("[SHOT] writing %d frames to %s" % [_count, OS.get_user_data_dir()])


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
