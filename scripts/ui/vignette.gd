extends CanvasLayer

## Screen-edge darkening, built in code so there is no scene to hand-author.
##
## Sits on layer 0 — above the world (a plain Node2D under Main, so the default
## canvas) and below the HUD on layer 1, which must stay crisp and undimmed.
##
## Per-floor colour comes from floor_entered: the Playground is close to
## neutral, and it gets heavier and closer as you descend toward the Arena.
## Layered on top of the per-floor tilesheets and tints.

const SHADER := preload("res://assets/shaders/vignette.gdshader")

## floor index -> (tint, strength). Past the end of the list, the last entry
## is reused, so extra floors stay dark rather than resetting to bright.
const MOODS: Array = [
	[Color(0.03, 0.02, 0.05), 0.50],   # playground — nearly neutral, open sky
	[Color(0.04, 0.02, 0.02), 0.56],   # gym — warm and dusty
	[Color(0.02, 0.04, 0.04), 0.64],   # steam room — teal, air you can feel
	[Color(0.05, 0.01, 0.02), 0.72],   # underground arena — red and close
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
