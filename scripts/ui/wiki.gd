extends CanvasLayer

## The wiki — "MY STUFF!" in the reference screenshots.
##
## Every artifact and weapon in the game, icon beside a one-line explanation of
## what it actually does. A roguelike that hides its own numbers behind a
## flavour line ("only one. never ask") is charming exactly once; after that the
## player wants to know whether the sock is worth 20 coins.
##
## Content comes straight from ContentDB, so this needs no maintenance — adding
## a .tres adds a wiki entry. The effect line is generated from the modifier
## dictionary rather than written by hand, which means it can never drift out
## of sync with the actual numbers.
##
## Opened from the main menu, or F2 anywhere. Pauses nothing.

const KEY := KEY_F2

## Modifier key -> how to say it. `mult` keys read as percentages.
const READABLE := {
	"damage_mult": ["damage", true],
	"damage_flat": ["flat damage", false],
	"speed_mult": ["move speed", true],
	"max_health": ["max health", false],
	"fire_rate_mult": ["fire rate", true],
	"knockback_mult": ["knockback", true],
	"crit_chance": ["crit chance", false],
	"dodge_cooldown_mult": ["dodge cooldown", true],
	"contact_armour": ["contact armour", false],
}

var _root: Control
var _list: VBoxContainer


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# A flat paper panel rather than the menu note texture: that art has two
	# tacks near the top-middle, which is exactly the region a NinePatch
	# stretches, so at this size they smeared into grey streaks.
	var paper := PanelContainer.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 40; paper.offset_right = -40
	paper.offset_top = 22; paper.offset_bottom = -22
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.933, 0.925, 0.894)
	sb.border_color = Color(0.76, 0.75, 0.71)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	paper.add_theme_stylebox_override("panel", sb)
	_root.add_child(paper)

	var title := Label.new()
	title.text = "MY STUFF!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.22, 0.20, 0.24))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	_root.add_child(title)

	var hint := Label.new()
	hint.text = "F2 or ESC to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.45, 0.43, 0.47))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -30
	_root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60; scroll.offset_right = -60
	scroll.offset_top = 56; scroll.offset_bottom = -36
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)


## Rebuilt on open, so owned-item highlighting is always current.
func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()

	_section("WEAPONS")
	var weapons: Array = ContentDB.weapons.values()
	weapons.sort_custom(func(a, b): return a.display_name < b.display_name)
	for w in weapons:
		_entry(w.icon, w.display_name, _weapon_line(w),
			GameState.weapon != null and GameState.weapon.id == w.id)

	_section("ARTIFACTS")
	var items: Array = ContentDB.items.values()
	items.sort_custom(func(a, b): return a.display_name < b.display_name)
	for it in items:
		_entry(it.icon, it.display_name, _item_line(it), GameState.has_item(it.id))

	_section("SKILLS")
	for id in GameState.SKILLS:
		var def: Dictionary = GameState.SKILLS[id]
		var lvl := GameState.skill_level(id)
		_entry(null, String(def.get("name", "?")),
			"%s · level %d/%d" % [def.get("blurb", ""), lvl, GameState.SKILL_MAX],
			lvl > 0)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.40, 0.34, 0.30))
	_list.add_child(l)


func _entry(icon: Texture2D, name: String, effect: String, owned: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(20, 20)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = icon
	row.add_child(pic)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var n := Label.new()
	n.text = ("● " if owned else "") + name
	n.add_theme_font_size_override("font_size", 11)
	n.add_theme_color_override("font_color",
		Color(0.16, 0.30, 0.18) if owned else Color(0.22, 0.20, 0.24))
	col.add_child(n)

	var e := Label.new()
	e.text = effect
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.add_theme_font_size_override("font_size", 9)
	e.add_theme_color_override("font_color", Color(0.44, 0.42, 0.46))
	col.add_child(e)

	row.add_child(col)
	_list.add_child(row)


## "damage +35%, move speed -10%" — generated, never hand-written, so it cannot
## disagree with the .tres it describes.
func _item_line(it: ItemData) -> String:
	if it.random_effect:
		return "rolls a random effect when picked up"
	var parts: PackedStringArray = []
	for k in it.modifiers:
		var key := String(k)
		var info: Array = READABLE.get(key, [key, key.ends_with("_mult")])
		var v: float = float(it.modifiers[k])
		if bool(info[1]):
			var pct := int(round((v - 1.0) * 100.0))
			parts.append("%s %s%d%%" % [info[0], "+" if pct >= 0 else "", pct])
		else:
			parts.append("%s %s%s" % [info[0], "+" if v >= 0 else "",
				("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")])
	if parts.is_empty():
		return it.description
	return ", ".join(parts)


func _weapon_line(w: WeaponData) -> String:
	var kind := "melee" if w.kind == WeaponData.Kind.MELEE else "ranged"
	var rate := "%.1f/s" % (1.0 / maxf(0.01, w.cooldown))
	var extra := ""
	if w.kind == WeaponData.Kind.RANGED:
		if w.projectiles_per_shot > 1:
			extra += ", %d shots" % w.projectiles_per_shot
		if w.pierce > 0:
			extra += ", pierces %d" % w.pierce
	else:
		extra += ", %d° arc" % int(w.arc_degrees)
	return "%s · %.1f dmg · %s%s" % [kind, w.damage, rate, extra]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code := (event as InputEventKey).keycode
	if code == KEY:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and code == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_populate()
