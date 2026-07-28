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
## Per-pickup rolled modifiers, aligned with `items` (Mystery Meat).
var item_rolls: Array[Dictionary] = []
var weapon: WeaponData = null
var _stats: Dictionary = {}

## Couch co-op. Health and coins stay shared; items, weapon and skills are
## per player. The unsuffixed vars above remain player 1's, so every 1P call
## site keeps working untouched — accessors take an optional player index.
var two_player: bool = false
var items2: Array[ItemData] = []
var item_rolls2: Array[Dictionary] = []
var weapon2: WeaponData = null
var _stats2: Dictionary = {}

## Skill levels bought at shrines, keyed by skill id.
##
## Items are *found*; skills are *chosen*. That difference is the point — it
## gives a run a spine the player steers, instead of leaving the build entirely
## to what the floor happened to drop. They stack with items through exactly
## the same modifier path, so no stat code knows skills exist.
const SKILLS := {
	&"vitality": {"name": "VITALITY", "blurb": "+1 max health",
		"mods": {&"max_health": 1}},
	&"power": {"name": "POWER", "blurb": "+12% damage",
		"mods": {&"damage_mult": 1.12}},
	&"reflexes": {"name": "REFLEXES", "blurb": "+12% fire rate",
		"mods": {&"fire_rate_mult": 1.12}},
	&"footwork": {"name": "FOOTWORK", "blurb": "faster, quicker dodge",
		"mods": {&"speed_mult": 1.06, &"dodge_cooldown_mult": 0.93}},
	&"focus": {"name": "FOCUS", "blurb": "+5% crit",
		"mods": {&"crit_chance": 0.05}},
}
const SKILL_MAX := 5
## How many *different* skills one run may hold.
##
## All five were reachable, so every long run converged on the same maxed-out
## build and the choice of what to buy stopped mattering. Capping the breadth
## (while leaving depth at SKILL_MAX) turns each shrine into a decision:
## another level in something you have, or the last slot spent on something
## you do not.
const MAX_SKILLS := 4

var skills: Dictionary = {}   ## StringName -> int level
var skills2: Dictionary = {}  ## player 2's, co-op only

## Set from the mod menu (F1). Read by Player.take_damage.
var godmode: bool = false

## What Mystery Meat can turn out to be. Mostly good. Mostly.
const MEAT_ROLLS := [
	{&"damage_mult": 1.3},
	{&"speed_mult": 1.15},
	{&"max_health": 2},
	{&"fire_rate_mult": 1.25},
	{&"crit_chance": 0.12},
	{&"contact_armour": 1},
	{&"damage_mult": 1.5, &"speed_mult": 0.9},
	{&"max_health": 3, &"fire_rate_mult": 0.9},
]


func _ready() -> void:
	reset()


func reset() -> void:
	items.clear()
	item_rolls.clear()
	skills.clear()
	items2.clear()
	item_rolls2.clear()
	skills2.clear()
	weapon2 = null
	godmode = false        # never carries into a fresh run
	coins = 0
	floor_index = 0
	kills = 0
	run_time = 0.0
	weapon = null
	_recompute()
	health = max_health()


func _recompute() -> void:
	_stats = _compute(items, item_rolls, skills)
	_stats2 = _compute(items2, item_rolls2, skills2)
	EventBus.stat_changed.emit()


func _compute(from_items: Array[ItemData], rolls: Array[Dictionary],
		from_skills: Dictionary) -> Dictionary:
	var out: Dictionary = BASE.duplicate()
	for i in from_items.size():
		if from_items[i] == null:
			continue
		_apply_modifiers(out, from_items[i].modifiers)
		if i < rolls.size():
			_apply_modifiers(out, rolls[i])
	# skills ride the same modifier path, applied once per level
	for id in from_skills:
		if not SKILLS.has(id):
			continue
		var mods: Dictionary = SKILLS[id]["mods"]
		for _lvl in int(from_skills[id]):
			_apply_modifiers(out, mods)
	return out


func _apply_modifiers(stats: Dictionary, mods: Dictionary) -> void:
	for k in mods:
		if not stats.has(k):
			stats[k] = 0.0
		# *_mult keys multiply, everything else adds.
		if String(k).ends_with("_mult"):
			stats[k] = float(stats[k]) * float(mods[k])
		else:
			stats[k] = stats[k] + mods[k]


## Dictionaries and Arrays are references, so mutating what these return
## mutates the right player's live state.
func _skills_of(p: int) -> Dictionary:
	return skills2 if p == 1 else skills


func _stats_of(p: int) -> Dictionary:
	return _stats2 if p == 1 else _stats


func stat(key: String, p: int = 0) -> float:
	return float(_stats_of(p).get(key, 0.0))


func skill_level(id: StringName, p: int = 0) -> int:
	return int(_skills_of(p).get(id, 0))


## Rises steeply so that maxing one skill costs about what spreading the same
## coins across three would, and neither is the obvious play.
func skill_cost(id: StringName, p: int = 0) -> int:
	var lvl := skill_level(id, p)
	return 14 + lvl * 11 + floor_index * 3


func skill_maxed(id: StringName, p: int = 0) -> bool:
	return skill_level(id, p) >= SKILL_MAX


## True when this skill is new AND every slot is already spoken for.
func skill_blocked(id: StringName, p: int = 0) -> bool:
	return skill_level(id, p) == 0 and _skills_of(p).size() >= MAX_SKILLS


## Buys one level. Returns false (and spends nothing) if maxed or too poor.
func upgrade_skill(id: StringName, p: int = 0) -> bool:
	if not SKILLS.has(id) or skill_maxed(id, p) or skill_blocked(id, p):
		return false
	var cost := skill_cost(id, p)
	if coins < cost or not spend(cost):
		return false
	return grant_skill(id, p)


## Adds a level without charging for it — what a lucky crate hands out.
## Returns false if the skill is unknown or already maxed.
func grant_skill(id: StringName, p: int = 0) -> bool:
	if not SKILLS.has(id) or skill_maxed(id, p) or skill_blocked(id, p):
		return false
	_skills_of(p)[id] = skill_level(id, p) + 1
	var before := max_health()
	_recompute()
	# a max_health skill should hand over the health it just promised, not
	# leave the player to go and find it
	var gained := max_health() - before
	if gained > 0:
		health = mini(max_health(), health + gained)
		EventBus.player_healed.emit(health, max_health())
	return true


## A skill the player has not maxed yet, or &"" if they all are.
func random_unmaxed_skill(p: int = 0) -> StringName:
	var pool: Array = []
	for id in SKILLS:
		# a crate must not hand out a skill the player has no slot for
		if not skill_maxed(id, p) and not skill_blocked(id, p):
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[randi() % pool.size()]


## The one shared pool both players draw from. Max health bonuses from either
## player's items and skills stack onto it; in 1P this is exactly P1's stat.
func max_health() -> int:
	var m := int(_stats.get("max_health", BASE["max_health"]))
	if two_player:
		m += int(_stats2.get("max_health", BASE["max_health"])) - int(BASE["max_health"])
	return m


## Returns a human-readable description of any rolled effect ("" if fixed),
## so the pickup toast can tell the player what the mystery turned out to be.
func add_item(item: ItemData, p: int = 0) -> String:
	if item == null:
		return ""
	var before := max_health()
	var roll: Dictionary = {}
	if item.random_effect:
		roll = MEAT_ROLLS[randi() % MEAT_ROLLS.size()].duplicate()
	if p == 1:
		items2.append(item)
		item_rolls2.append(roll)
	else:
		items.append(item)
		item_rolls.append(roll)
	_recompute()
	# gaining max health also grants the new hearts, or it feels like a downgrade
	var gained := max_health() - before
	if gained > 0:
		health += gained
	health = clampi(health, 0, max_health())
	EventBus.item_collected.emit(item, p)
	return describe_modifiers(roll)


static func describe_modifiers(mods: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in mods:
		var key := String(k)
		var v: float = float(mods[k])
		if key.ends_with("_mult"):
			parts.append("%+d%% %s" % [int(round((v - 1.0) * 100.0)),
				key.trim_suffix("_mult").replace("_", " ")])
		elif key == "crit_chance":
			parts.append("%+d%% crit" % int(round(v * 100.0)))
		else:
			parts.append("%+d %s" % [int(v), key.replace("_", " ")])
	return ", ".join(parts)


func equip(w: WeaponData, p: int = 0) -> void:
	if p == 1:
		weapon2 = w
	else:
		weapon = w
	EventBus.weapon_equipped.emit(w, p)


func weapon_of(p: int = 0) -> WeaponData:
	return weapon2 if p == 1 else weapon


## `p` is the player who was hit — their armour, everyone's health.
func damage(amount: int, p: int = 0) -> void:
	var armour := int(stat("contact_armour", p))
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


## Default -1 means "owned by anyone" — right for unique-item gating and the
## collection log. Pass 0 or 1 to ask about one player.
func has_item(id: StringName, p: int = -1) -> bool:
	if p != 1:
		for i in items:
			if i != null and i.id == id:
				return true
	if p != 0:
		for i in items2:
			if i != null and i.id == id:
				return true
	return false
