extends CanvasLayer

## Screen-edge darkening, built in code so there is no scene to hand-author.
##
## Sits on layer 0 — above the world (a plain Node2D under Main, so the default
## canvas) and below the HUD on layer 1, which must stay crisp and undimmed.
##
## Per-floor colour comes from floor_entered: the Nursery is close to neutral,
## and it gets colder and heavier as you descend. Cheap way to make four floors
## built from the same tiles feel like four different places.

const SHADER := preload("res://assets/shaders/vignette.gdshader")

## floor index -> (tint, strength). Past the end of the list, the last entry
## is reused, so extra floors stay dark rather than resetting to bright.
const MOODS: Array = [
	[Color(0.03, 0.02, 0.05), 0.50],   # nursery — nearly neutral
	[Color(0.04, 0.02, 0.02), 0.56],   # playroom — warm and dusty
	[Color(0.02, 0.02, 0.05), 0.64],   # attic — cold, darker
	[Color(0.05, 0.01, 0.02), 0.72],   # toy factory — red and close
]

var _rect: ColorRect


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# never eat a click meant for the game underneath
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	add_child(_rect)
	_apply(0)
	EventBus.floor_entered.connect(func(index: int, _n: String) -> void: _apply(index))


func _apply(floor_index: int) -> void:
	var mood: Array = MOODS[clampi(floor_index, 0, MOODS.size() - 1)]
	var mat: ShaderMaterial = _rect.material
	mat.set_shader_parameter(&"tint", mood[0])
	mat.set_shader_parameter(&"strength", mood[1])
