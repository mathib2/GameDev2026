extends Node

## Conversations. Autoload: DialogueManager
##
## Walks a DialogueData tree and emits what to show. It owns no UI — the
## DialogueBox scene listens on EventBus and draws whatever arrives, so the UI
## team and the writing team never touch the same file.

var current: DialogueData = null
var line_index: int = -1
var is_running: bool = false


func start(dialogue: DialogueData) -> bool:
	if is_running or dialogue == null or dialogue.lines.is_empty():
		return false
	current = dialogue
	line_index = -1
	is_running = true
	EventBus.dialogue_started.emit(dialogue)
	advance()
	return true


## Advances to the next line. Ignored while choices are pending — the UI must
## call choose() instead.
func advance() -> void:
	if not is_running:
		return
	var line := current_line()
	if line != null and _available_choices(line).size() > 0:
		return

	line_index += 1
	if line_index >= current.lines.size():
		finish()
		return

	var next := current.lines[line_index]
	if next == null:
		finish()
		return

	_apply_side_effects(next)
	EventBus.dialogue_line_shown.emit(next)

	var choices := _available_choices(next)
	if choices.size() > 0:
		EventBus.dialogue_choices_offered.emit(choices)


func choose(choice_index: int) -> void:
	if not is_running:
		return
	var line := current_line()
	if line == null:
		return
	var choices := _available_choices(line)
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: DialogueChoice = choices[choice_index]
	GameState.set_flags(choice.sets_flags)

	if choice.goto_line < 0 or choice.goto_line >= current.lines.size():
		finish()
		return
	# -1 because advance() increments first.
	line_index = choice.goto_line - 1
	advance()


func finish() -> void:
	if not is_running:
		return
	var id := current.id if current != null else &""
	is_running = false
	current = null
	line_index = -1
	EventBus.dialogue_finished.emit(id)


func current_line() -> DialogueLine:
	if current == null or line_index < 0 or line_index >= current.lines.size():
		return null
	return current.lines[line_index]


func _available_choices(line: DialogueLine) -> Array:
	var out: Array = []
	for c in line.choices:
		if c != null and c.is_available():
			out.append(c)
	return out


func _apply_side_effects(line: DialogueLine) -> void:
	GameState.set_flags(line.sets_flags)
	if line.starts_mission != &"":
		MissionManager.start_mission(line.starts_mission)
	if line.grants_item != &"":
		InventoryManager.add_item(line.grants_item, 1)
	AudioManager.play_sfx(line.voice_clip)
