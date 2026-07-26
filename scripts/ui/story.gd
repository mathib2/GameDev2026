extends CanvasLayer

## The story, told in cards between the fighting.
##
## Patrick is sixteen and has never lost at anything. Somewhere below the town
## is a cursed place that replicates real rooms almost correctly — a playground,
## a gym, a steam room, an arena — and whoever walks out of the bottom of it is
## the strongest. So he walked in. The toys are what the place uses for
## opponents; it does not understand what people fight, only that they do.
##
## Tone rule, inherited from the boss intros and kept religiously: **the game
## never acknowledges the joke.** It is a game about a teddy bear that squeaks
## when it hits you, and it delivers every line of its own story completely
## straight. The moment the writing winks, the bear stops being frightening and
## the whole thing collapses into parody.
##
## So: no exclamation marks, no jokes, no narrator. Short declarative
## sentences, past tense for what happened, present tense for what is still
## happening. The wrongness is entirely in what is left unsaid.
##
## Cards never pause the game and never take input. They fade in over the top
## of play and fade out on a timer, so the story can be read or completely
## ignored — which is how a roguelike has to do it, because by run nine the
## player has read all of this already.

const FADE_IN := 0.6
const FADE_OUT := 0.9

## Shown once, when a run starts.
const OPENING: Array[String] = [
	"PATRICK IS A YOUNG MAN.",
	"HE WAS TOLD HE IS NOT THE STRONGEST,",
	"HE WILL PROVE THEM WRONG",
]

## One per floor, keyed by index. Past the end, the deep floors get nothing —
## silence is better than filler.
const FLOORS: Array = [
	["THE PLAYGROUND", "Where you first show your strength."],
	["THE GYM", "Build your muscles."],
	["THE STEAM ROOM", "It's getting hot in here."],
	["THE UNDERGROUND ARENA", "The final test."],
	["????", "?-?"],
]

const VICTORY: Array[String] = [
	"THERE IS NO BEINGS LEFT",
	"Patrick has proved his strength",
	"...",
]

const DEFEAT: Array[String] = [
	"PATRICK DOES NOT LOSE",
	"HE DOES NOT REST, HE GOES AGAIN",
]

var _root: Control
var _title: Label
var _body: Label
var _queue: Array = []
var _showing: bool = false
## The opening and floor 0's card fire on the same frame — run_started is
## immediately followed by _enter_floor(0). Swallow the duplicate.
var _skip_next_floor: bool = false


func _ready() -> void:
	layer = 3                     # above the HUD (1), below the menus (5)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# sit above centre: the player and most of the danger live in the middle
	box.position = Vector2(-260, -120)
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 6)
	_root.add_child(box)

	_title = _label(20, Color(1, 0.93, 0.78))
	_body = _label(13, Color(0.82, 0.80, 0.86))
	box.add_child(_title)
	box.add_child(_body)

	EventBus.run_started.connect(_on_run_started)
	EventBus.floor_entered.connect(_on_floor_entered)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.player_died.connect(func() -> void: _show(DEFEAT[0], DEFEAT[1], 3.4))


func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _on_run_started() -> void:
	_queue.clear()
	_skip_next_floor = true
	_show(OPENING[0], OPENING[1] + "\n" + OPENING[2], 4.2)


func _on_floor_entered(index: int, fallback: String) -> void:
	if _skip_next_floor:
		_skip_next_floor = false
		return
	if index < FLOORS.size():
		_show(FLOORS[index][0], FLOORS[index][1], 4.7)
	else:
		# deeper than the written floors: name it, say nothing about it
		_show(fallback, "", 2.4)


func _on_run_ended(victory: bool) -> void:
	if victory:
		_show(VICTORY[0], VICTORY[1] + "\n" + VICTORY[2], 5.0)


## Queues a card. Cards never interrupt each other — a boss dying into a floor
## transition would otherwise cut its own epigraph off mid-fade.
func _show(title: String, body: String, hold: float) -> void:
	_queue.append([title, body, hold])
	if not _showing:
		_pump()


func _pump() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var card: Array = _queue.pop_front()
	_title.text = card[0]
	_body.text = card[1]
	_body.visible = card[1] != ""

	var t := create_tween()
	t.tween_property(_root, "modulate:a", 1.0, FADE_IN)
	t.tween_interval(card[2])
	t.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	t.tween_callback(_pump)
