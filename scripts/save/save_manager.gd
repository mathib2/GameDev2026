extends Node

## Persistence. Autoload: SaveManager
##
## Saves ids and flags, never Resources. A save file stays valid when designers
## rebalance content, because it only ever refers to content by id.

const SAVE_PATH := "user://rogue_protocol_save.json"
const SAVE_VERSION := 1


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"state": GameState.to_dict(),
		"inventory": InventoryManager.to_dict(),
		"missions": MissionManager.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Save] cannot write %s" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	EventBus.toast_requested.emit("Saved.")
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Save] corrupt save file")
		return false
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("[Save] version mismatch; ignoring save")
		return false

	GameState.from_dict(parsed.get("state", {}))
	InventoryManager.from_dict(parsed.get("inventory", {}))
	MissionManager.from_dict(parsed.get("missions", {}))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
