extends Node

## Run state and player stats. Autoload: GameState
##
## Stats are computed from a base plus every collected item's modifiers, so
## items never mutate the player directly and can be recomputed or removed
## cleanly.

const BASE := {
	"max_health": 6,
	"damage_mult": 1.0,
	"damage_flat": 0.0,
	"speed_mult": 1.0,
	"fire_rate_mult": 1.0,
	"knockback_mult": 1.0,
	"crit_chance": 0.0,
	"dodge_cooldown_mult": 1.0,
	"contact_armour": 0,
}

var health: int = 6
var coins: int = 0
var floor_index: int = 0
var kills: int = 0
var run_time: float = 0.0
var items: Array[ItemData] = []
var weapon: WeaponData = null
var _stats: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	items.clear()
	coins = 0
	floor_index = 0
	kills = 0
	run_time = 0.0
	weapon = null
	_recompute()
	health = max_health()


func _recompute() -> void:
	_stats = BASE.duplicate()
	for item in items:
		if item == null:
			continue
		for k in item.modifiers:
			if not _stats.has(k):
				_stats[k] = 0.0
			# *_mult keys multiply, everything else adds.
			if String(k).ends_with("_mult"):
				_stats[k] = float(_stats[k]) * float(item.modifiers[k])
			else:
				_stats[k] = _stats[k] + item.modifiers[k]
	EventBus.stat_changed.emit()


func stat(key: String) -> float:
	return float(_stats.get(key, 0.0))


func max_health() -> int:
	return int(_stats.get("max_health", 6))


func add_item(item: ItemData) -> void:
	if item == null:
		return
	var before := max_health()
	items.append(item)
	_recompute()
	# gaining max health also grants the new hearts, or it feels like a downgrade
	var gained := max_health() - before
	if gained > 0:
		health += gained
	health = clampi(health, 0, max_health())
	EventBus.item_collected.emit(item)


func equip(w: WeaponData) -> void:
	weapon = w
	EventBus.weapon_equipped.emit(w)


func damage(amount: int) -> void:
	var armour := int(stat("contact_armour"))
	var taken := maxi(1, amount - armour) if amount > 0 else 0
	health = clampi(health - taken, 0, max_health())
	EventBus.player_damaged.emit(taken, health, max_health())
	if health <= 0:
		EventBus.player_died.emit()


func heal(amount: int) -> void:
	health = clampi(health + amount, 0, max_health())
	EventBus.player_healed.emit(health, max_health())


func add_coins(n: int) -> void:
	coins = maxi(0, coins + n)
	EventBus.coins_changed.emit(coins)


func spend(n: int) -> bool:
	if coins < n:
		return false
	add_coins(-n)
	return true


func has_item(id: StringName) -> bool:
	for i in items:
		if i != null and i.id == id:
			return true
	return false
