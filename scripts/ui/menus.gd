extends Control

## Shared behaviour for the three menu panels. Which one it is comes from
## `mode`, so all three use one script and one set of buttons.

enum Mode { MAIN, PAUSE, GAME_OVER }

@export var mode: Mode = Mode.MAIN

@onready var _title: Label = $Panel/VBox/Title
@onready var _subtitle: Label = $Panel/VBox/Subtitle
@onready var _primary: Button = $Panel/VBox/Primary
@onready var _secondary: Button = $Panel/VBox/Secondary

var sfx_select: AudioStream = preload("res://assets/audio/sfx/ui_select.wav")
var sfx_confirm: AudioStream = preload("res://assets/audio/sfx/ui_confirm.wav")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_primary.pressed.connect(_on_primary)
	_secondary.pressed.connect(_on_secondary)
	for b in [_primary, _secondary]:
		b.mouse_entered.connect(func() -> void: AudioManager.play_sfx(sfx_select, 0.05, -6.0))
	match mode:
		Mode.MAIN:
			_dress_main_menu()
			_title.text = ""          # the logo image carries the name now
			_subtitle.text = "he is the strongest. only if he survives the cursed dungeon"
			if SaveManager.runs > 0:
				_subtitle.text += "\nbest: floor %d · %d toys torn open lifetime" % [
					SaveManager.best_floor, SaveManager.lifetime_kills]
			_primary.text = "START RUN"
			_secondary.text = "QUIT"
			_add_volume_controls()
		Mode.PAUSE:
			_dress_main_menu(false)
			_title.text = "PAUSED!"
			_subtitle.text = ""
			_primary.text = "RESUME"
			_secondary.text = "QUIT TO MENU"
			_style_paper(_title, 20, Color(0.20, 0.19, 0.23))
			_add_volume_controls()
		Mode.GAME_OVER:
			_dress_main_menu(false)
			_primary.text = "RUN IT BACK"
			_secondary.text = "MAIN MENU"
			_style_paper(_title, 20, Color(0.20, 0.19, 0.23))
			_style_paper(_subtitle, 9, Color(0.42, 0.40, 0.44))


## Turns the plain dark panel into the paper-and-pinned-note main menu.
##
## Only the MAIN mode gets this. Pause and game-over share this scene, and they
## are drawn over live gameplay where a full-bleed opaque backdrop would be
## wrong — they stay as the dim overlay they were.
##
## Built in code so Menu.tscn keeps working unchanged for the other two modes.
func _dress_main_menu(full: bool = true) -> void:
	var dim: ColorRect = $Dim
	if full:
		dim.color = Color(0, 0, 0, 0)      # the paper is the background now

		var bg := TextureRect.new()
		bg.texture = load("res://assets/ui/menu_bg.png")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		move_child(bg, 0)                  # behind every other child
	else:
		# Pause and game-over sit over live gameplay, so they keep a dim rather
		# than a full-bleed backdrop — but everything else (the note, the flat
		# paper text) matches the main menu, which is what makes the game feel
		# like one thing instead of two.
		dim.color = Color(0.04, 0.03, 0.06, 0.80)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/menu_logo.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_left = 56
	logo.offset_right = -56
	logo.offset_top = 10
	logo.offset_bottom = 96
	if full:
		add_child(logo)
		move_child(logo, 1)
	else:
		# never parented in this mode; free it or it lingers as an orphan
		logo.queue_free()

	# the note sits behind the buttons; the CenterContainer centres both
	var note := TextureRect.new()
	note.texture = load("res://assets/ui/menu_note.png")
	note.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.offset_top = 104
	add_child(note)
	# Immediately BEHIND the Panel, computed rather than a fixed index: the
	# main menu also inserts a background and a logo first, so a hard-coded 2
	# was correct there and landed *in front of* the Panel for pause and
	# game-over — which drew the note over every button and left the pause
	# screen a blank sheet of paper.
	move_child(note, $Panel.get_index())

	var vbox: VBoxContainer = $Panel/VBox
	vbox.add_theme_constant_override("separation", 2)
	$Panel.offset_top = 112

	_style_paper(_subtitle, 8, Color(0.42, 0.40, 0.44))
	# The pixel font is wide: unwrapped, a long tagline forces the whole
	# panel wider than the paper note and drags the sliders with it.
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(236, 0)
	for b in [_primary, _secondary]:
		_style_paper(b, 13, Color(0.24, 0.23, 0.28))
		b.custom_minimum_size = Vector2(180, 22)
		b.flat = true

	# MY STUFF and MOD MENU sit between the two main actions, as in the
	# reference. Both were previously only reachable by keyboard (F2 / F1),
	# which meant nobody found them.
	_extra_button("MY STUFF", func() -> void:
		var main := get_tree().current_scene
		if main != null and main.get("wiki") != null:
			main.wiki.toggle())
	_extra_button("MOD MENU (F1)", func() -> void:
		var main := get_tree().current_scene
		if main == null:
			return
		for n in main.get_children():
			# untyped: get_script() returns Variant, and `:=` on it is a
			# parse error under this project's warnings-as-errors setting
			var s = n.get_script()
			if s != null and String(s.resource_path).ends_with("mod_menu.gd"):
				for c in n.get_children():
					if c is PanelContainer:
						c.visible = not c.visible
				return)


func _extra_button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	_style_paper(b, 12, Color(0.24, 0.23, 0.28))
	b.custom_minimum_size = Vector2(180, 20)
	b.flat = true
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx(sfx_confirm, 0.0, -2.0)
		action.call())
	b.mouse_entered.connect(func() -> void:
		AudioManager.play_sfx(sfx_select, 0.05, -6.0))
	var vb: VBoxContainer = $Panel/VBox
	vb.add_child(b)
	vb.move_child(b, _secondary.get_index())


## Menu text on paper: dark ink, no button chrome, and a light hover tint —
## the reference has no boxes around anything, just words on the page.
func _style_paper(c: Control, size: int, colour: Color) -> void:
	c.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		c.add_theme_color_override(state,
			colour.lightened(0.35) if state == "font_hover_color" else colour)
	if c is Button:
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			c.add_theme_stylebox_override(s, empty)


func _add_volume_controls() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	for cfg in [["SFX", AudioManager.sfx_volume_db, true],
			["MUSIC", AudioManager.music_volume_db, false]]:
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = cfg[0]
		lab.custom_minimum_size = Vector2(52, 0)
		row.add_child(lab)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.02
		slider.value = db_to_linear(cfg[1])
		slider.custom_minimum_size = Vector2(140, 16)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var is_sfx: bool = cfg[2]
		slider.value_changed.connect(func(v: float) -> void:
			var db := linear_to_db(maxf(v, 0.001)) if v > 0.0 else -80.0
			if is_sfx:
				SaveManager.set_sfx_volume_db(db)
				AudioManager.play_sfx(sfx_select, 0.05, -6.0)
			else:
				SaveManager.set_music_volume_db(db))
		row.add_child(slider)
		vbox.add_child(row)


func setup(victory: bool) -> void:
	if victory:
		_title.text = "THE STRONGEST"
		_subtitle.text = "nothing else steps forward. you walk home.\n%d slimed · %d coins · %ds" % [
			GameState.kills, GameState.coins, int(GameState.run_time)]
	else:
		_title.text = "NOT STRONG ENOUGH"
		_subtitle.text = "Fell in %s\n%d enemies slimed · %d coins · %ds" % [
			RunManager.floor_name().to_lower(), GameState.kills, GameState.coins,
			int(GameState.run_time)]


func _on_primary() -> void:
	AudioManager.play_sfx(sfx_confirm)
	var main := get_tree().current_scene
	match mode:
		Mode.MAIN, Mode.GAME_OVER:
			main.start_run()
		Mode.PAUSE:
			main._toggle_pause()


func _on_secondary() -> void:
	AudioManager.play_sfx(sfx_confirm)
	var main := get_tree().current_scene
	match mode:
		Mode.MAIN:
			get_tree().quit()
		Mode.PAUSE, Mode.GAME_OVER:
			main.quit_to_menu()
