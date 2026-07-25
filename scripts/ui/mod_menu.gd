extends CanvasLayer

## Developer / mod menu. F1 toggles it.
##
## Exists so a run can be steered instead of played: jump to the floor you want
## to look at, clear a room you have already proved you can clear, hand
## yourself the item you are trying to test. Playtesting a roguelike otherwise
## means grinding back to the interesting bit every single time.
##
## Deliberately not gated behind a build flag — this is a jam project and being
## able to reach floor four in two clicks is worth more than hiding it. It
## pauses nothing and holds no state of its own; every button is a one-line
## call into the systems that already exist.

const KEY := KEY_F1

var _panel: PanelContainer
var _rows: VBoxContainer
var _status: Label


func _ready() -> void:
	layer = 6                      # above the menus (5), so it is never buried
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 40)
	_panel.custom_minimum_size = Vector2(196, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10, 0.94)
	style.border_color = Color(0.55, 0.85, 1.0, 0.85)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	_panel.add_child(_rows)

	_header("MOD MENU  ·  F1")
	_button("Kill all mobs", _kill_all)
	_button("Clear room (open doors)", _clear_room)
	_button("Next floor", func(): _jump(1))
	_button("Previous floor", func(): _jump(-1))
	_button("Spawn boss here", _spawn_boss)
	_header("GIVE")
	_button("+100 coins", func():
		GameState.add_coins(100); _say("+100 coins"))
	_button("Random weapon", _give_weapon)
	_button("Random item", _give_item)
	_button("+1 random skill", _give_skill)
	_button("Full heal", func():
		GameState.heal(99); _say("healed"))
	_header("TOGGLES")
	_button("God mode: OFF", _toggle_god)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 9)
	_status.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	_rows.add_child(_status)


func _header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_rows.add_child(l)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 10)
	b.custom_minimum_size = Vector2(0, 18)
	b.pressed.connect(action)
	_rows.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _say(msg: String) -> void:
	if _status != null:
		_status.text = msg


# ── actions ───────────────────────────────────────────────────────────────
func _kill_all() -> void:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(999999.0, Vector2.ZERO, false, 0.0)
			n += 1
	_say("killed %d" % n)


func _clear_room() -> void:
	var room = RunManager.current_room
	if room != null and is_instance_valid(room) and room.has_method("mark_cleared"):
		room.mark_cleared()
		_say("room cleared")


func _jump(delta: int) -> void:
	var target: int = clampi(GameState.floor_index + delta, 0,
		RunManager.total_floors() - 1)
	if target == GameState.floor_index:
		_say("no such floor")
		return
	# _enter_floor rebuilds the whole floor, and this is fired from a button
	# press (idle), so it is safe to call directly — unlike the door and portal
	# paths, which run inside the physics flush.
	RunManager._enter_floor(target)
	_say("floor %d" % target)


func _spawn_boss() -> void:
	var room = RunManager.current_room
	if room == null or not is_instance_valid(room):
		return
	room._spawn_boss(GameState.floor_index)
	_say("boss spawned")


func _give_weapon() -> void:
	var current: StringName = GameState.weapon.id if GameState.weapon != null else &""
	var w := ContentDB.random_weapon(current)
	if w != null:
		GameState.equip(w)
		_say(w.display_name)


func _give_item() -> void:
	var it := ContentDB.random_item()
	if it != null:
		GameState.add_item(it)
		_say(it.display_name)


func _give_skill() -> void:
	var id := GameState.random_unmaxed_skill()
	if id == &"" or not GameState.grant_skill(id):
		_say("no slot free")
		return
	_say("%s %d" % [GameState.SKILLS[id].get("name", "?"), GameState.skill_level(id)])


func _toggle_god() -> void:
	GameState.godmode = not GameState.godmode
	for c in _rows.get_children():
		if c is Button and String((c as Button).text).begins_with("God mode"):
			(c as Button).text = "God mode: %s" % ("ON" if GameState.godmode else "OFF")
	_say("god %s" % ("on" if GameState.godmode else "off"))
