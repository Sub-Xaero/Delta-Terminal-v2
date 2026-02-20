extends Node
## Handles serialising and restoring game state to/from user://save.json.

const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 1


func _ready() -> void:
	EventBus.network_disconnected.connect(_autosave)
	EventBus.mission_accepted.connect(_autosave_on_mission)
	EventBus.mission_completed.connect(_autosave_on_mission)


# ── Auto-save ──────────────────────────────────────────────────────────────────

func _autosave() -> void:
	if SettingsManager.autosave:
		save_game()


func _autosave_on_mission(_mission_id: String) -> void:
	if SettingsManager.autosave:
		save_game()


# ── Public API ────────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version":            SAVE_VERSION,
		"player_data":        GameManager.player_data.duplicate(),
		"active_missions":    GameManager.active_missions.duplicate(),
		"completed_missions": GameManager.completed_missions.duplicate(),
		"local_storage":      _serialize_local_storage(),
		"cracked_nodes":      NetworkSim.cracked_nodes.duplicate(),
		"node_state":         _collect_node_state(),
		"hardware":           HardwareManager.get_save_data(),
		"credentials":        GameManager.credentials.duplicate(),
		"comms_inbox":        CommsManager.inbox.duplicate(true),
		"exploits_installed": {},
		"discovered_nodes":   NetworkSim.cracked_nodes.duplicate(),
		"tutorial_flags":     {},
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
	if not _check_version(data):
		return false
	GameManager.player_data = data.get("player_data", GameManager.player_data.duplicate())
	# Ensure new player_data keys exist when loading old saves
	if not GameManager.player_data.has("heat"):
		GameManager.player_data["heat"] = 0
	if not GameManager.player_data.has("faction_rep"):
		GameManager.player_data["faction_rep"] = {}
	if not GameManager.player_data.has("local_storage"):
		GameManager.player_data["local_storage"] = ["password_cracker.exe", "port_scanner.exe"]
	GameManager.active_missions.assign(data.get("active_missions", []))
	GameManager.completed_missions.assign(data.get("completed_missions", []))
	GameManager.local_storage = _deserialize_local_storage(data.get("local_storage", []))
	NetworkSim.cracked_nodes.assign(data.get("cracked_nodes", []))
	GameManager.credentials = data.get("credentials", {})
	_restore_node_state(data.get("node_state", {}))
	if data.has("hardware"):
		HardwareManager.load_save_data(data["hardware"])
	CommsManager.inbox = data.get("comms_inbox", [])
	MissionManager.restore_active_missions(GameManager.active_missions)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


# ── Serialisation helpers ──────────────────────────────────────────────────────

func _serialize_local_storage() -> Array:
	var result: Array = []
	for f: Dictionary in GameManager.local_storage:
		result.append(f.duplicate())
	return result


func _deserialize_local_storage(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in raw:
		if entry is Dictionary:
			result.append(entry)
	return result


## Captures per-node state that may have changed during a session:
## file list (deletions) and scanned port results.
func _collect_node_state() -> Dictionary:
	var state: Dictionary = {}
	for node_id: String in NetworkSim.nodes:
		var node: Dictionary = NetworkSim.nodes[node_id]
		var entry: Dictionary = {}
		if node.has("files"):
			var files: Array = []
			for f: Dictionary in node["files"]:
				files.append(f.duplicate())
			entry["files"] = files
		var ports: Array = node.get("scanned_ports", [])
		if not ports.is_empty():
			entry["scanned_ports"] = ports.duplicate()
		if not entry.is_empty():
			state[node_id] = entry
	return state


## Applies saved per-node state over the freshly-registered default nodes.
func _restore_node_state(state: Dictionary) -> void:
	for node_id: String in state:
		if not NetworkSim.nodes.has(node_id):
			continue
		var entry: Dictionary = state[node_id]
		if entry.has("files"):
			NetworkSim.nodes[node_id]["files"] = entry["files"]
		if entry.has("scanned_ports"):
			NetworkSim.nodes[node_id]["scanned_ports"] = entry["scanned_ports"]


func _check_version(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if version == 0:
		# Legacy save without version field — attempt to load anyway.
		push_warning("SaveManager: legacy save format detected, attempting load.")
		return true
	if version > SAVE_VERSION:
		EventBus.log_message.emit(
			"Save file is from a newer game version — cannot load.", "error"
		)
		return false
	return true
