extends Control

## Draws whatever DialogueManager emits. Knows nothing about any specific
## conversation, so writers never touch this file.

@onready var _panel: Control = $Panel
@onready var _speaker: Label = $Panel/Speaker
@onready var _text: RichTextLabel = $Panel/Text
@onready var _portrait: TextureRect = $Panel/Portrait
@onready var _choices: VBoxContainer = $Panel/Choices

var _showing_choices: bool = false


func _ready() -> void:
	_panel.visible = false
	EventBus.dialogue_started.connect(_on_started)
	EventBus.dialogue_line_shown.connect(_on_line)
	EventBus.dialogue_choices_offered.connect(_on_choices)
	EventBus.dialogue_finished.connect(_on_finished)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or _showing_choices:
		return
	if event.is_action_pressed(&"ui_advance") or event.is_action_pressed(&"interact"):
		DialogueManager.advance()
		get_viewport().set_input_as_handled()


func _on_started(_d: DialogueData) -> void:
	_panel.visible = true


func _on_line(line: DialogueLine) -> void:
	_clear_choices()
	_showing_choices = false
	_speaker.text = line.speaker
	_text.text = line.text
	_portrait.texture = line.portrait
	_portrait.visible = line.portrait != null


func _on_choices(choices: Array) -> void:
	_clear_choices()
	_showing_choices = true
	for i in choices.size():
		var c: DialogueChoice = choices[i]
		var b := Button.new()
		b.text = c.text
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_choice_pressed.bind(i))
		_choices.add_child(b)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _on_choice_pressed(index: int) -> void:
	_showing_choices = false
	_clear_choices()
	DialogueManager.choose(index)


func _on_finished(_id: StringName) -> void:
	_clear_choices()
	_showing_choices = false
	_panel.visible = false


func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
