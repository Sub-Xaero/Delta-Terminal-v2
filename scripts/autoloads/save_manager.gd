extends Node
## Handles serialising and restoring game state to/from user://save.json.

const SAVE_PATH := "user://save.json"


# ── Public API ────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"player_data":       GameManager.player_data.duplicate(),
		"active_missions":   GameManager.active_missions.duplicate(),
		"completed_missions":GameManager.completed_missions.duplicate(),
		"cracked_nodes":     NetworkSim.cracked_nodes.duplicate(),
		"hardware":          HardwareManager.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		EventBus.log_message.emit("Game saved.", "info")
	else:
		EventBus.log_message.emit("Save failed — could not write file.", "error")


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		EventBus.log_message.emit("Save data corrupt — could not parse.", "error")
		return false
	var data: Dictionary = json.data
	GameManager.player_data = data.get("player_data", GameManager.player_data.duplicate())
	GameManager.active_missions.assign(data.get("active_missions", []))
	GameManager.completed_missions.assign(data.get("completed_missions", []))
	NetworkSim.cracked_nodes.assign(data.get("cracked_nodes", []))
	if data.has("hardware"):
		HardwareManager.load_save_data(data["hardware"])
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
