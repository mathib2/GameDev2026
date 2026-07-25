extends Node

## Runtime player/world state. Autoload: GameState
##
## The single source of truth for "what has happened so far". Everything that
## gates content — dialogue, missions, locations, hack targets — asks this.
##
## Deliberately tiny and serialisable: SaveManager just snapshots these fields.

var flags: Dictionary = {}          ## StringName -> true
var stats: Dictionary = {
	&"intrusion": 1,                ## drives which hack targets are attemptable
	&"stealth": 1,
	&"hardware": 1,
}
var credits: int = 250
var heat: int = 0                   ## wanted level; rises on failed hacks
var integrity: int = 100            ## the player's "health"
var max_integrity: int = 100
var current_location: StringName = &""
var hacked_targets: Dictionary = {} ## StringName -> true, for non-repeatables


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName) -> void:
	if flag == &"" or flags.has(flag):
		return
	flags[flag] = true
	EventBus.flag_set.emit(flag)


func set_flags(list: Array) -> void:
	for f in list:
		set_flag(f)


func get_stat(stat: StringName) -> int:
	var base: int = stats.get(stat, 0)
	return base + InventoryManager.get_stat_bonus(stat)


func add_stat(stat: StringName, amount: int) -> void:
	stats[stat] = stats.get(stat, 0) + amount
	EventBus.stat_changed.emit(stat, stats[stat])


func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	EventBus.credits_changed.emit(credits)


func can_afford(amount: int) -> bool:
	return credits >= amount


func add_heat(amount: int) -> void:
	heat = clampi(heat + amount, 0, 5)
	EventBus.heat_changed.emit(heat)


func damage_integrity(amount: int) -> void:
	integrity = clampi(integrity - amount, 0, max_integrity)


func heal(amount: int) -> void:
	integrity = clampi(integrity + amount, 0, max_integrity)


func mark_hacked(target_id: StringName) -> void:
	hacked_targets[target_id] = true


func was_hacked(target_id: StringName) -> bool:
	return hacked_targets.get(target_id, false)


## Applies any RewardData from any system. Missions and hacks share this path.
func grant_reward(reward: RewardData) -> void:
	if reward == null:
		return
	match reward.kind:
		RewardData.Kind.ITEM:
			InventoryManager.add_item(reward.id, maxi(1, reward.amount))
		RewardData.Kind.CREDITS:
			add_credits(reward.amount)
		RewardData.Kind.FLAG:
			set_flag(reward.id)
		RewardData.Kind.XP:
			add_stat(&"intrusion", reward.amount)
		RewardData.Kind.UNLOCK_MISSION:
			MissionManager.start_mission(reward.id)
		RewardData.Kind.HEAL:
			heal(reward.amount)
	EventBus.reward_granted.emit(reward)
	var line := reward.describe()
	if line != "":
		EventBus.toast_requested.emit(line)


func grant_rewards(list: Array) -> void:
	for r in list:
		grant_reward(r)


func to_dict() -> Dictionary:
	return {
		"flags": flags,
		"stats": stats,
		"credits": credits,
		"heat": heat,
		"integrity": integrity,
		"current_location": String(current_location),
		"hacked_targets": hacked_targets,
	}


func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {})
	stats = d.get("stats", stats)
	credits = d.get("credits", 250)
	heat = d.get("heat", 0)
	integrity = d.get("integrity", 100)
	current_location = StringName(d.get("current_location", ""))
	hacked_targets = d.get("hacked_targets", {})
