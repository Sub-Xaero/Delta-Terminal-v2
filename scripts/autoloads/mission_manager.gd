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
	EventBus.credentials_stolen.connect(_on_credentials_stolen)
	EventBus.network_disconnected.connect(_on_network_disconnected_for_missions)
	EventBus.bank_transfer_completed.connect(_on_bank_transfer_completed)
	for mission: MissionData in available_missions.values():
		if mission.auto_deliver_on_start and mission.delivery_method == "email":
			deliver_mission_by_email(mission.id)


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


func _on_credentials_stolen(node_id: String, _count: int) -> void:
	_satisfy_objectives(ObjectiveData.Type.STEAL_CREDENTIALS, node_id)


func _on_network_disconnected_for_missions() -> void:
	_satisfy_objectives(ObjectiveData.Type.DISCONNECT, "")


func _on_bank_transfer_completed(node_id: String, _amount: int) -> void:
	_satisfy_objectives(ObjectiveData.Type.TRANSFER_FUNDS, node_id)


func _on_tool_task_completed(tool_name: String, task_id: String, success: bool) -> void:
	if not success:
		return
	match tool_name:
		"password_cracker":
			_satisfy_objectives(ObjectiveData.Type.CRACK_NODE, task_id)
		"port_scanner":
			_satisfy_objectives(ObjectiveData.Type.SCAN_NODE, task_id)
		"file_browser":
			_satisfy_objectives(ObjectiveData.Type.STEAL_FILE, task_id)
		"log_deleter":
			_satisfy_objectives(ObjectiveData.Type.DELETE_LOG, task_id)
			var sec: int = NetworkSim.get_node_data(task_id).get("security", 1)
			GameManager.add_heat(-sec)
		"record_editor":
			_satisfy_objectives(ObjectiveData.Type.MODIFY_RECORD, task_id)
		"dictionary_hacker":
			_satisfy_objectives(ObjectiveData.Type.CRACK_NODE, task_id)
		"virus_compiler":
			_satisfy_objectives(ObjectiveData.Type.DEPLOY_VIRUS, task_id)


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
	var bonus: int = mission.reward_per_rating_point * GameManager.player_data.get("rating", 1)
	var total_reward: int = mission.reward_credits + bonus
	GameManager.add_credits(total_reward)
	if mission.reward_rating > 0:
		GameManager.add_rating(mission.reward_rating)
	EventBus.mission_completed.emit(mission.id)
	EventBus.log_message.emit(
		"Mission complete: %s  —  +%d credits" % [mission.title, total_reward], "info"
	)
	if not mission.triggers_story_mission.is_empty():
		for next_id: String in mission.triggers_story_mission.split(","):
			var trimmed: String = next_id.strip_edges()
			if not trimmed.is_empty():
				deliver_mission_by_email(trimmed)
	if mission.reward_credits >= 1000:
		var first_target: String = ""
		for obj: ObjectiveData in mission.objectives:
			if obj.type in [ObjectiveData.Type.CRACK_NODE, ObjectiveData.Type.CONNECT_TO]:
				first_target = obj.target
				break
		if not first_target.is_empty():
			var org: String = NetworkSim.get_node_data(first_target).get("organisation", "unknown")
			EventBus.news_headline_added.emit("Security breach reported at %s." % org)


# ── Save / load support ────────────────────────────────────────────────────────

## Re-activates missions by id after a save is loaded.
## Duplicates the mission template so objective state is fresh.
func restore_active_missions(ids: Array) -> void:
	for id in ids:
		if not available_missions.has(id):
			continue
		if active_missions.has(id):
			continue
		active_missions[id] = available_missions[id].duplicate(true)


# ── Email delivery ────────────────────────────────────────────────────────────

func deliver_mission_by_email(mission_id: String) -> void:
	if not available_missions.has(mission_id):
		push_warning("MissionManager: deliver_mission_by_email — unknown id '%s'" % mission_id)
		return
	var mission: MissionData = available_missions[mission_id]
	CommsManager.send_message({
		"from_handle": _faction_contact_name(mission.faction_id),
		"faction_id": mission.faction_id,
		"subject": "Job Offer: %s" % mission.title,
		"body": mission.description + "\n\nReward: ¥%d" % mission.reward_credits,
		"attachments": [{ "type": "mission_offer", "mission_id": mission_id }],
	})


func _faction_contact_name(faction_id: String) -> String:
	match faction_id:
		"ghost_collective": return "GHOST_OPS"
		"nova_corp":        return "NC_RECRUITER"
		"syn_underground":  return "SYN_BROKER"
		_:                  return "ANONYMOUS"
