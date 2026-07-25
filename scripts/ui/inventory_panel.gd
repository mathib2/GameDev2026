extends Control

## Inventory and mission log. Rebuilt from InventoryManager/MissionManager on
## open; no per-item scripting.

@onready var _panel: Control = $Panel
@onready var _items: VBoxContainer = $Panel/Columns/Items/List
@onready var _missions: VBoxContainer = $Panel/Columns/Missions/List


func _ready() -> void:
	_panel.visible = false
	EventBus.item_added.connect(func(_a, _b): _refresh())
	EventBus.item_removed.connect(func(_a, _b): _refresh())
	EventBus.mission_started.connect(func(_a): _refresh())
	EventBus.mission_completed.connect(func(_a): _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory") and not HackManager.is_active():
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for c in _items.get_children():
		c.queue_free()
	for c in _missions.get_children():
		c.queue_free()

	if InventoryManager.contents.is_empty():
		_items.add_child(_line("(empty)", Color(0.5, 0.5, 0.55)))
	for id in InventoryManager.contents:
		var data := ContentDB.get_item(id)
		var label := "%s ×%d" % [
			(data.display_name if data != null else String(id)),
			InventoryManager.contents[id]]
		_items.add_child(_line(label))

	var active := MissionManager.active_missions()
	if active.is_empty():
		_missions.add_child(_line("(no active contracts)", Color(0.5, 0.5, 0.55)))
	for m in active:
		_missions.add_child(_line(m.title, Color(0.6, 1.0, 0.9)))
		for obj in m.objectives:
			if obj == null:
				continue
			var mark := "[x]" if obj.is_complete() else "[ ]"
			_missions.add_child(_line("   %s %s" % [mark, obj.description],
				Color(0.65, 0.65, 0.7)))


func _line(text: String, colour: Color = Color(0.85, 0.85, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = colour
	return l
