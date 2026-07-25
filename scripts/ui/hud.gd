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


func _ready() -> void:
	_boss_bar.visible = false
	_intro.visible = false
	_toast.visible = false
	_flash.color.a = 0.0

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
	EventBus.boss_intro_started.connect(_on_intro)
	EventBus.minimap_dirty.connect(func(): _minimap.queue_redraw())
	EventBus.run_started.connect(func(): _rebuild_hearts(); _coins.text = "0 ¢")

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
	_toast_time = 2.6


func _on_flash(colour: Color, _duration: float) -> void:
	_flash.color = colour


func _on_boss_spawned(_b: Node, display_name: String) -> void:
	_boss_bar.visible = true
	_boss_name.text = display_name
	_boss_fill.scale.x = 1.0


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


# ── minimap ───────────────────────────────────────────────────────────────
func _draw_minimap() -> void:
	var gen = RunManager.generator
	if gen == null:
		return
	var cell := 9.0
	var gap := 2.0
	var cur = RunManager.current_info
	for r in gen.order:
		if not r.visited and not _adjacent_visited(gen, r):
			continue
		var pos := Vector2((r.gx - 5) * (cell + gap), (r.gy - 5) * (cell + gap)) \
			+ _minimap.size * 0.5
		var col := Color(0.22, 0.20, 0.24)
		if r == cur:
			col = Color(1, 0.9, 0.5)
		elif r.visited:
			col = Color(0.55, 0.52, 0.5)
		if r.visited or r == cur:
			match r.kind:
				FloorGenerator.RoomKind.BOSS: col = Color(0.8, 0.25, 0.25)
				FloorGenerator.RoomKind.TREASURE: col = Color(0.9, 0.75, 0.3)
				FloorGenerator.RoomKind.SHOP: col = Color(0.4, 0.75, 0.9)
				FloorGenerator.RoomKind.ELITE: col = Color(0.7, 0.4, 0.85)
				_: pass
			if r == cur:
				col = Color(1, 1, 1)
		_minimap.draw_rect(Rect2(pos, Vector2(cell, cell)), col)


func _adjacent_visited(gen, r) -> bool:
	for d in ["u", "d", "l", "r"]:
		var n = gen.neighbour(r, d)
		if n != null and n.visited:
			return true
	return false
