class_name SheetAnimator
extends Sprite2D

## Plays animations from a grid spritesheet: rows = animations, columns = frames.
##
## Every character sheet in this project follows the same layout, so an artist
## can replace any PNG with their own and nothing else changes as long as the
## grid matches. No SpriteFrames resources to hand-author, no AnimationPlayer
## per character.
##
## Default row order (see docs/ART_PIPELINE.md):
##   0 idle | 1 walk | 2 attack | 3 hurt | 4 death | 5 extra (player: dodge)

signal animation_finished(anim: StringName)

const DEFAULT_ROWS := {
	&"idle":   {"row": 0, "frames": 4, "fps": 6.0,  "loop": true},
	&"walk":   {"row": 1, "frames": 4, "fps": 10.0, "loop": true},
	&"attack": {"row": 2, "frames": 4, "fps": 14.0, "loop": false},
	&"hurt":   {"row": 3, "frames": 2, "fps": 12.0, "loop": false},
	&"death":  {"row": 4, "frames": 5, "fps": 9.0,  "loop": false},
}

## Override per character when the sheet differs (the player has 6 walk frames
## and a dodge row).
@export var animations: Dictionary = {}
@export var columns: int = 0   ## 0 = derive from the widest animation
@export var rows: int = 0      ## 0 = derive from the animation table
@export var autoplay: StringName = &"idle"

var current: StringName = &""
var _frame_index: int = 0
var _time: float = 0.0
var _finished: bool = false


func _ready() -> void:
	if animations.is_empty():
		animations = DEFAULT_ROWS.duplicate(true)
	_apply_grid()
	if autoplay != &"":
		play(autoplay)


func _apply_grid() -> void:
	var max_frames := 1
	var max_row := 0
	for k in animations:
		max_frames = maxi(max_frames, int(animations[k]["frames"]))
		max_row = maxi(max_row, int(animations[k]["row"]))
	hframes = columns if columns > 0 else max_frames
	vframes = rows if rows > 0 else max_row + 1


func _process(delta: float) -> void:
	if current == &"" or _finished:
		return
	var def: Dictionary = animations[current]
	var count := int(def["frames"])
	if count <= 1:
		return
	_time += delta
	var step := 1.0 / maxf(0.001, float(def["fps"]))
	while _time >= step:
		_time -= step
		_frame_index += 1
		if _frame_index >= count:
			if bool(def.get("loop", true)):
				_frame_index = 0
			else:
				_frame_index = count - 1
				_finished = true
				animation_finished.emit(current)
				break
	_refresh()


## Starts an animation. Re-playing the current one is a no-op unless `force`.
func play(anim: StringName, force: bool = false) -> void:
	if not animations.has(anim):
		return
	if anim == current and not force and not _finished:
		return
	current = anim
	_frame_index = 0
	_time = 0.0
	_finished = false
	_refresh()


func _refresh() -> void:
	if current == &"":
		return
	var def: Dictionary = animations[current]
	frame = int(def["row"]) * hframes + _frame_index


func is_finished() -> bool:
	return _finished


func has(anim: StringName) -> bool:
	return animations.has(anim)
