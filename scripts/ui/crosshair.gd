extends Control

## Gungeon-style aiming reticle drawn at the mouse position. The OS
## cursor is hidden during runs (see main.gd); this replaces it.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	visible = not get_tree().paused
	queue_redraw()


func _draw() -> void:
	var pos := get_viewport().get_mouse_position()
	# dark outline pass first so it reads on any floor colour
	draw_arc(pos, 6.0, 0.0, TAU, 20, Color(0, 0, 0, 0.55), 3.0)
	draw_arc(pos, 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.4)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(pos + dir * 4.0, pos + dir * 9.0, Color(0, 0, 0, 0.55), 3.0)
		draw_line(pos + dir * 4.0, pos + dir * 9.0, Color(1, 1, 1, 0.9), 1.4)
	draw_circle(pos, 1.2, Color(1, 1, 1, 0.95))
