extends Node

## Inventory and economy. Autoload: InventoryManager
##
## Stores ids and counts only — never ItemData instances — so saves stay small
## and content can be rebalanced without invalidating a save file.

var contents: Dictionary = {}   ## StringName -> int


func add_item(item_id: StringName, count: int = 1) -> bool:
	var data := ContentDB.get_item(item_id)
	if data == null:
		push_warning("[Inventory] unknown item '%s'" % item_id)
		return false
	var current: int = contents.get(item_id, 0)
	var limit: int = data.max_stack if data.stackable else 1
	contents[item_id] = mini(current + count, limit)
	AudioManager.play_sfx(data.pickup_sfx)
	EventBus.item_added.emit(item_id, count)
	return true


func remove_item(item_id: StringName, count: int = 1) -> bool:
	var current: int = contents.get(item_id, 0)
	if current < count:
		return false
	if current == count:
		contents.erase(item_id)
	else:
		contents[item_id] = current - count
	EventBus.item_removed.emit(item_id, count)
	return true


func has_item(item_id: StringName, count: int = 1) -> bool:
	return contents.get(item_id, 0) >= count


func count_of(item_id: StringName) -> int:
	return contents.get(item_id, 0)


func use_item(item_id: StringName) -> bool:
	var data := ContentDB.get_item(item_id)
	if data == null or not has_item(item_id):
		return false
	GameState.set_flags(data.sets_flags)
	AudioManager.play_sfx(data.use_sfx)
	if data.consumed_on_use:
		remove_item(item_id, 1)
	return true


## Summed stat_modifiers across everything held. Drives GameState.get_stat().
func get_stat_bonus(stat: StringName) -> int:
	var total := 0
	for id in contents:
		var data := ContentDB.get_item(id)
		if data == null:
			continue
		total += int(data.stat_modifiers.get(stat, 0))
	return total


func buy(item_id: StringName, markup: float = 1.0) -> bool:
	var data := ContentDB.get_item(item_id)
	if data == null:
		return false
	var price := int(round(data.value * markup))
	if not GameState.can_afford(price):
		EventBus.toast_requested.emit("Not enough credits.")
		return false
	GameState.add_credits(-price)
	add_item(item_id, 1)
	return true


func sell(item_id: StringName) -> bool:
	var data := ContentDB.get_item(item_id)
	if data == null or not data.sellable or not has_item(item_id):
		return false
	remove_item(item_id, 1)
	GameState.add_credits(int(round(data.value * 0.5)))
	return true


func to_dict() -> Dictionary:
	var out := {}
	for k in contents:
		out[String(k)] = contents[k]
	return out


func from_dict(d: Dictionary) -> void:
	contents.clear()
	for k in d:
		contents[StringName(k)] = int(d[k])
