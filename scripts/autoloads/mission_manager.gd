extends Node
## Loads mission definitions from data/missions/, tracks active missions,
## and drives objective completion via EventBus signals.

# Preload data classes to ensure they are registered in ClassDB before use.
const _MissionDataScript = preload("res://scripts/data/mission_data.gd")
const _ObjectiveDataScript = preload("res://scripts/data/objective_data.gd")

# All missions loaded from disk (templates — never mutated directly).
var available_missions: Dictionary = {}  # id -> MissionData

# Deep-duplicated instances currently being pursued by the player.
var active_missions: Dictionary = {}     # id -> MissionData


func _ready() -> void:
	_load_missions()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.tool_task_completed.connect(_on_tool_task_completed)


# ── Loading ────────────────────────────────────────────────────────────────────

func _load_missions() -> void:
	var dir := DirAccess.open("res://data/missions/")
	if not dir:
		push_warning("MissionManager: could not open res://data/missions/")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var mission := load("res://data/missions/" + file) as MissionData
			if mission and not mission.id.is_empty():
				available_missions[mission.id] = mission
		file = dir.get_next()
	dir.list_dir_end()


# ── Accepting missions ─────────────────────────────────────────────────────────

## Activates a mission by id. Deep-duplicates the resource so objective state
## is isolated per run. Delegates id tracking to GameManager.
func accept_mission(mission_id: String) -> void:
	if not available_missions.has(mission_id):
		push_warning("MissionManager: unknown mission id '%s'" % mission_id)
		return
	if active_missions.has(mission_id):
		return
	# Deep-duplicate so each run starts with fresh objective.completed = false
	var mission: MissionData = available_missions[mission_id].duplicate(true)
	active_missions[mission_id] = mission
	GameManager.accept_mission(mission_id)
	EventBus.log_message.emit("Mission accepted: %s" % mission.title, "info")


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_satisfy_objectives(ObjectiveData.Type.CONNECT_TO, node_id)


func _on_tool_task_completed(tool_name: String, task_id: String, success: bool) -> void:
	if not success:
		return
	if tool_name == "password_cracker":
		_satisfy_objectives(ObjectiveData.Type.CRACK_NODE, task_id)


# ── Objective tracking ─────────────────────────────────────────────────────────

func _satisfy_objectives(type: ObjectiveData.Type, target: String) -> void:
	for mission_id: String in active_missions:
		var mission: MissionData = active_missions[mission_id]
		var changed := false
		for i: int in mission.objectives.size():
			var obj: ObjectiveData = mission.objectives[i]
			if not obj.completed and obj.type == type and obj.target == target:
				obj.completed = true
				changed = true
				EventBus.log_message.emit(
					"[%s] Objective complete: %s" % [mission.title, obj.description], "info"
				)
				EventBus.mission_objective_completed.emit(mission_id, i)
		if changed:
			_check_mission_completion(mission)


func _check_mission_completion(mission: MissionData) -> void:
	for obj: ObjectiveData in mission.objectives:
		if not obj.completed:
			return
	_complete_mission(mission)


func _complete_mission(mission: MissionData) -> void:
	active_missions.erase(mission.id)
	GameManager.add_credits(mission.reward_credits)
	EventBus.mission_completed.emit(mission.id)
	EventBus.log_message.emit(
		"Mission complete: %s  —  +%d credits" % [mission.title, mission.reward_credits], "info"
	)
