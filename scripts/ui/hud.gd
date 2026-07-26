extends CanvasLayer

## Health, coins, floor, minimap, boss bar, toasts, boss intro card, flash.
## Reads everything from EventBus — holds no references to gameplay nodes.

@onready var _hearts: HBoxContainer = $Root/Top/Hearts
@onready var _coins: Label = $Root/Top/Coins
@onready var _floor: Label = $Root/Top/FloorName
@onready var _items: HBoxContainer = $Root/Top/Items
@onready var _toast: Label = $Root/Toast
@onready var _boss_bar: Control = $Root/BossBar
@onready var _boss_fill: ColorRect = $Root/BossBar/Fill
@onready var _boss_name: Label = $Root/BossBar/Name
@onready var _intro: Control = $Root/BossIntro
@onready var _intro_title: Label = $Root/BossIntro/Title
@onready var _intro_sub: Label = $Root/BossIntro/Subtitle
@onready var _flash: ColorRect = $Root/Flash
@onready var _minimap: Control = $Root/Minimap

const HEART_TEX := preload("res://assets/items/pickup_heart.png")

var _toast_time: float = 0.0
var _weapon_icon: TextureRect = null
var _boss_fill_base: Color


func _ready() -> void:
	_boss_bar.visible = false
	_intro.visible = false
	_toast.visible = false
	_flash.color.a = 0.0
	_boss_fill_base = _boss_fill.color

	# equipped-weapon slot next to the item strip
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(18, 18)
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	$Root/Top.add_child(_weapon_icon)
	EventBus.weapon_equipped.connect(func(w: WeaponData) -> void:
		_weapon_icon.texture = w.icon if w != null else null
		_weapon_icon.tooltip_text = w.display_name if w != null else "")

	# aiming reticle, drawn above everything else on the HUD
	var crosshair: Control = load("res://scripts/ui/crosshair.gd").new()
	$Root.add_child(crosshair)

	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.boss_phase_changed.connect(func(p: int) -> void:
		_boss_fill.color = Color(1, 0.55, 0.25) if p == 2 else Color(1, 0.3, 0.3))

	EventBus.player_damaged.connect(func(_a, _h, _m): _rebuild_hearts())
	EventBus.player_healed.connect(func(_h, _m): _rebuild_hearts())
	EventBus.coins_changed.connect(func(c): _coins.text = "%d ¢" % c)
	EventBus.item_collected.connect(_on_item)
	EventBus.floor_entered.connect(func(_i, n): _floor.text = n)
	EventBus.toast.connect(_on_toast)
	EventBus.flash.connect(_on_flash)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health)
	EventBus.boss_defeated.connect(func(_b): _boss_bar.visible = false)
	# The bar was only ever hidden by killing the boss, so dying to one left it
	# stuck on screen through the death screen and into the next run.
	EventBus.player_died.connect(func(): _boss_bar.visible = false)
	EventBus.run_ended.connect(func(_v: bool): _boss_bar.visible = false)
	EventBus.boss_intro_started.connect(_on_intro)
	EventBus.minimap_dirty.connect(func(): _minimap.queue_redraw())
	_build_extras()
	EventBus.stat_changed.connect(_refresh_skills)
	EventBus.weapon_equipped.connect(func(w: WeaponData) -> void:
		_weapon_name.text = w.display_name.to_upper() if w != null else "")
	EventBus.run_started.connect(func():
		_rebuild_hearts()
		_coins.text = "0 ¢"
		# belt and braces: a fresh run always starts with a clean HUD —
		# including the item strip, whose icons used to survive death and
		# show the previous run's items forever
		for c in _items.get_children():
			c.queue_free()
		_boss_bar.visible = false
		_intro.visible = false)

	_minimap.draw.connect(_draw_minimap)
	_rebuild_hearts()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast.visible = false
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 3.0)


func _rebuild_hearts() -> void:
	for c in _hearts.get_children():
		c.queue_free()
	var full := GameState.health / 2
	var half := GameState.health % 2
	var total := int(ceil(GameState.max_health() / 2.0))
	for i in total:
		var t := TextureRect.new()
		t.texture = HEART_TEX
		t.custom_minimum_size = Vector2(18, 18)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if i < full:
			t.modulate = Color(1, 1, 1)
		elif i == full and half == 1:
			t.modulate = Color(1, 0.55, 0.55, 0.85)
		else:
			t.modulate = Color(0.25, 0.18, 0.18, 0.85)
		_hearts.add_child(t)


func _on_item(item: ItemData) -> void:
	if item.icon == null:
		return
	var t := TextureRect.new()
	t.texture = item.icon
	t.custom_minimum_size = Vector2(16, 16)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.tooltip_text = item.display_name
	_items.add_child(t)


func _on_toast(text: String, colour: Color) -> void:
	_toast.text = text
	_toast.modulate = colour
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_time = 4.1


func _on_flash(colour: Color, _duration: float) -> void:
	_flash.color = colour


func _on_room_cleared(room: Node) -> void:
	# bosses have their own fanfare
	if room.info != null and room.info.kind != FloorGenerator.RoomKind.BOSS:
		_on_toast("CLEAR", Color(0.7, 1, 0.75))
		_toast_time = 1.2


func _on_boss_spawned(_b: Node, display_name: String) -> void:
	_boss_bar.visible = true
	_boss_name.text = display_name
	_boss_fill.scale.x = 1.0
	_boss_fill.color = _boss_fill_base


func _on_boss_health(fraction: float) -> void:
	_boss_fill.scale.x = clampf(fraction, 0.0, 1.0)


func _on_intro(display_name: String, subtitle: String) -> void:
	_intro_title.text = display_name
	_intro_sub.text = subtitle
	_intro.visible = true
	_intro.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_intro, "modulate:a", 1.0, 0.35)
	t.tween_interval(1.9)
	t.tween_property(_intro, "modulate:a", 0.0, 0.45)
	t.tween_callback(func() -> void: _intro.visible = false)


# ── skills strip, weapon name, map legend ─────────────────────────────────
## Built in code rather than in HUD.tscn so the whole block can be added, moved
## or removed in one place. All of it is read-only display — nothing here owns
## state, it just renders GameState.

var _skills_row: HBoxContainer
var _weapon_name: Label
var _legend: HBoxContainer


func _build_extras() -> void:
	_weapon_name = Label.new()
	_weapon_name.position = Vector2(8, 22)
	_weapon_name.add_theme_font_size_override("font_size", 10)
	_weapon_name.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	_weapon_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_weapon_name.add_theme_constant_override("outline_size", 4)
	var w := GameState.weapon
	_weapon_name.text = w.display_name.to_upper() if w != null else ""
	$Root.add_child(_weapon_name)

	# skills you own, bottom-left, so a build is visible without opening a menu
	_skills_row = HBoxContainer.new()
	_skills_row.position = Vector2(8, 356)
	_skills_row.add_theme_constant_override("separation", 8)
	$Root.add_child(_skills_row)
	_refresh_skills()

	# map legend: the colours are meaningless until you are told what they mean
	_legend = HBoxContainer.new()
	# tucked directly under the minimap (which spans x 536..632, y 30..118) so
	# it reads as part of it rather than floating in the middle of the floor
	# x accounts for the pixel font's width — at 536 the BOSS chip ran off
	# the right edge of the screen
	_legend.position = Vector2(514, 120)
	_legend.add_theme_constant_override("separation", 4)
	$Root.add_child(_legend)
	for pair in [[FloorGenerator.RoomKind.SHOP, "SHOP"],
			[FloorGenerator.RoomKind.TREASURE, "LOOT"],
			[FloorGenerator.RoomKind.BOSS, "BOSS"]]:
		var chip := Label.new()
		chip.text = String(pair[1])
		chip.add_theme_font_size_override("font_size", 8)
		chip.add_theme_color_override("font_color", MAP_COLOURS[pair[0]])
		chip.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		chip.add_theme_constant_override("outline_size", 3)
		_legend.add_child(chip)


func _refresh_skills() -> void:
	if _skills_row == null:
		return
	for c in _skills_row.get_children():
		c.queue_free()
	for id in GameState.SKILLS:
		var lvl := GameState.skill_level(id)
		if lvl <= 0:
			continue                      # only show what has been invested in
		var def: Dictionary = GameState.SKILLS[id]
		var l := Label.new()
		l.text = "%s %d" % [String(def.get("name", "?")).substr(0, 3), lvl]
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color",
			load("res://scripts/items/skill_shrine.gd").TINTS.get(id, Color.WHITE))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		_skills_row.add_child(l)


# ── minimap ───────────────────────────────────────────────────────────────
## Colour per room kind. A room announces what it is the moment it appears on
## the map, not once you have already walked into it — a shop you can only
## identify by standing in it may as well not be on the map at all, which is
## exactly how it played.
const MAP_COLOURS := {
	FloorGenerator.RoomKind.BOSS: Color(0.86, 0.26, 0.26),
	FloorGenerator.RoomKind.TREASURE: Color(0.95, 0.78, 0.30),
	FloorGenerator.RoomKind.SHOP: Color(0.38, 0.78, 0.95),
	FloorGenerator.RoomKind.ELITE: Color(0.72, 0.42, 0.88),
	FloorGenerator.RoomKind.SECRET: Color(0.55, 0.85, 0.60),
}


func _draw_minimap() -> void:
	var gen = RunManager.generator
	if gen == null:
		return
	var cur = RunManager.current_info

	# Collect what is on the map first. The grid is 11x11 and the control is
	# only 96x88, so a fixed cell size drew later floors outside their own box
	# and over the rest of the HUD. Fit to the rooms that actually exist.
	var shown: Array = []
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for r in gen.order:
		if not r.visited and not _adjacent_visited(gen, r):
			continue
		shown.append(r)
		lo.x = mini(lo.x, r.gx); lo.y = mini(lo.y, r.gy)
		hi.x = maxi(hi.x, r.gx); hi.y = maxi(hi.y, r.gy)
	if shown.is_empty():
		return

	var span := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
	var gap := 2.0
	var cell: float = minf(
		(_minimap.size.x - gap * (span.x - 1)) / span.x,
		(_minimap.size.y - gap * (span.y - 1)) / span.y)
	cell = clampf(floorf(cell), 4.0, 11.0)
	var step := cell + gap
	# centre the drawn cluster inside the control
	var origin := (_minimap.size - Vector2(span.x * step - gap, span.y * step - gap)) * 0.5

	# door connectors first, so rooms sit on top of them
	for r in shown:
		var p := origin + Vector2((r.gx - lo.x) * step, (r.gy - lo.y) * step)
		for d in ["r", "d"]:                      # each door drawn once
			if not r.doors[d]:
				continue
			var n = gen.neighbour(r, d)
			if n == null or not (n in shown):
				continue
			var a := p + Vector2(cell, cell * 0.5) if d == "r" \
				else p + Vector2(cell * 0.5, cell)
			var b := a + (Vector2(gap, 0) if d == "r" else Vector2(0, gap))
			_minimap.draw_line(a, b, Color(0.42, 0.40, 0.46), 2.0)

	for r in shown:
		var pos := origin + Vector2((r.gx - lo.x) * step, (r.gy - lo.y) * step)
		var col: Color = MAP_COLOURS.get(r.kind, Color(0.55, 0.52, 0.5))
		if not MAP_COLOURS.has(r.kind):
			col = Color(0.55, 0.52, 0.5) if r.visited else Color(0.30, 0.28, 0.33)
		# known-but-unvisited stays dimmer, so the map still shows progress
		if not r.visited and r != cur:
			col = col.darkened(0.45)
		_minimap.draw_rect(Rect2(pos, Vector2(cell, cell)), col)
		if r == cur:
			_minimap.draw_rect(Rect2(pos, Vector2(cell, cell)), Color(1, 1, 1), false, 2.0)


func _adjacent_visited(gen, r) -> bool:
	for d in ["u", "d", "l", "r"]:
		var n = gen.neighbour(r, d)
		if n != null and n.visited:
			return true
	return false
