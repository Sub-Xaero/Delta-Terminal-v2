extends Node
## Top-level game state machine. Coordinates between desktop, network, and missions.

enum State { MAIN_MENU, DESKTOP, CONNECTING, HACKING }

var state: State = State.MAIN_MENU

# Player progression
var player_data: Dictionary = {
	"handle": "ghost",
	"credits": 1000,
	"rating": 1,
	"heat": 0,
	"faction_rep": {},
	"local_storage": ["password_cracker.exe", "port_scanner.exe"],
}

# Stolen/discovered credentials per node: node_id → Array of credential dicts
var credentials: Dictionary = {}

var active_missions: Array[String] = []
var completed_missions: Array[String] = []
var local_storage: Array[Dictionary] = []


func _ready() -> void:
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.mission_failed.connect(_on_mission_failed)


func transition_to(new_state: State) -> void:
	state = new_state


func accept_mission(mission_id: String) -> void:
	if mission_id in active_missions:
		return
	active_missions.append(mission_id)
	EventBus.mission_accepted.emit(mission_id)


func add_credits(amount: int) -> void:
	player_data["credits"] += amount
	EventBus.player_stats_changed.emit()


func copy_file_to_local(file: Dictionary) -> void:
	for f: Dictionary in local_storage:
		if f.get("id", "") == file.get("id", ""):
			EventBus.log_message.emit("File '%s' already in local storage." % file["name"], "warn")
			return
	local_storage.append(file.duplicate())
	EventBus.log_message.emit("File '%s' saved to local storage." % file["name"], "info")


func _on_mission_completed(mission_id: String) -> void:
	active_missions.erase(mission_id)
	if mission_id not in completed_missions:
		completed_missions.append(mission_id)


func _on_mission_failed(mission_id: String, _reason: String) -> void:
	active_missions.erase(mission_id)
