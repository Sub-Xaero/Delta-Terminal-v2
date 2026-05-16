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
	"player_accounts": {
		"ghost_collective_darknet": { "username": "g_h0st", "role": "user" },
		"novacorp_bank":            { "username": "g_h0st", "role": "customer" }
	},
	"tutorial_flags": {},
}

# Stolen/discovered credentials per node: node_id → Array of credential dicts
var credentials: Dictionary = {}

var active_missions: Array[String] = []
var completed_missions: Array[String] = []
var local_storage: Array[Dictionary] = []

# In-game time accumulates while the desktop runs. 60 real seconds = 1 in-game day.
const SECONDS_PER_INGAME_DAY: float = 60.0
var _day_accumulator: float = 0.0
var _last_warrant_headline_day: int = -1
var in_game_day: int = 0


func _ready() -> void:
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.mission_failed.connect(_on_mission_failed)
	EventBus.bank_transfer_completed.connect(_on_bank_transfer_completed)
	EventBus.trace_completed.connect(_on_trace_completed)


func _process(delta: float) -> void:
	if state != State.DESKTOP:
		return
	_day_accumulator += delta
	if _day_accumulator >= SECONDS_PER_INGAME_DAY:
		_day_accumulator -= SECONDS_PER_INGAME_DAY
		in_game_day += 1
		_on_day_passed()


func _on_day_passed() -> void:
	# Heat decays −1 per in-game day (issue #23)
	var heat: int = player_data.get("heat", 0)
	if heat > 0:
		add_heat(-1)
	# Surface a warrant headline once per day while the player is hot
	var new_heat: int = player_data.get("heat", 0)
	if new_heat >= 90 and in_game_day != _last_warrant_headline_day:
		_last_warrant_headline_day = in_game_day
		EventBus.news_headline_added.emit(
			"INTERPOL flags unknown hacker '%s' for high-value cyber crimes." %
				player_data.get("handle", "ghost")
		)


func _on_bank_transfer_completed(_node_id: String, _amount: int) -> void:
	add_heat(20)


func _on_trace_completed() -> void:
	# NetworkSim adds +20 already; surface a milestone headline when heat is high.
	var heat: int = player_data.get("heat", 0)
	if heat >= 75:
		EventBus.news_headline_added.emit("Cyber Division opens a major investigation.")


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


func add_rating(amount: int) -> void:
	player_data["rating"] = maxi(1, player_data.get("rating", 1) + amount)
	EventBus.player_stats_changed.emit()


func add_heat(delta: int) -> void:
	player_data["heat"] = clampi(player_data.get("heat", 0) + delta, 0, 100)
	EventBus.player_heat_changed.emit(player_data["heat"])


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
