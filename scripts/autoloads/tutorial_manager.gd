extends Node
## Contextual hint system. Listens to EventBus events and surfaces short
## dismissible toast notifications the first time the player encounters a
## relevant situation. Hints are gated by `tutorial_flags` (persisted in save)
## and the global SettingsManager.tutorials_enabled toggle.

signal hint_fired(hint_id: String, title: String, text: String)

# Each hint: id (unique flag), title, text. Hooks below decide when they fire.
const HINTS: Dictionary = {
	"right_click_desktop": {
		"title": "Tool: right-click",
		"text":  "Right-click the desktop to open the system context menu. Most tools live there.",
	},
	"open_network_map": {
		"title": "Find a target",
		"text":  "Open the Network Map (sidebar) and double-click a node to dial it.",
	},
	"first_connect": {
		"title": "Connection live",
		"text":  "You're connected. Cracking, scanning, and file browsing all act on this node.",
	},
	"first_crack_run": {
		"title": "Trace pressure",
		"text":  "A trace started the moment you cracked. Disconnect before it completes.",
	},
	"missing_exe_attempt": {
		"title": "Tool is a file",
		"text":  "You're missing the .exe for that tool. Pick one up from the Software Shop.",
	},
	"trace_active": {
		"title": "Watch the trace",
		"text":  "The TRACE bar in the sidebar fills while you're hot. Bounce-chain to slow it down.",
	},
	"mission_accepted": {
		"title": "Mission active",
		"text":  "Mission objectives auto-track. Open the Mission Log to review them.",
	},
	"clean_disconnect": {
		"title": "Delete the access log",
		"text":  "Unclean disconnects flag the node HOT and raise heat. Use Log Deleter first.",
	},
}


func _ready() -> void:
	EventBus.context_menu_requested.connect(func(_pos: Vector2): _maybe_fire("right_click_desktop"))
	EventBus.tool_opened.connect(_on_tool_opened)
	EventBus.network_connected.connect(func(_n: String): _maybe_fire("first_connect"))
	EventBus.tool_task_started.connect(_on_task_started)
	EventBus.trace_started.connect(func(_d: float): _maybe_fire("trace_active"))
	EventBus.mission_accepted.connect(func(_id: String): _maybe_fire("mission_accepted"))
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.log_message.connect(_on_log_message)


func reset_all() -> void:
	GameManager.player_data["tutorial_flags"] = {}


## Marks every hint as seen — used by the "Skip tutorial" option at game start.
func skip_all() -> void:
	var flags: Dictionary = GameManager.player_data.get("tutorial_flags", {})
	for hint_id: String in HINTS:
		flags[hint_id] = true
	GameManager.player_data["tutorial_flags"] = flags


func _maybe_fire(hint_id: String) -> void:
	if not SettingsManager.tutorials_enabled:
		return
	if not HINTS.has(hint_id):
		return
	var flags: Dictionary = GameManager.player_data.get("tutorial_flags", {})
	if flags.get(hint_id, false):
		return
	flags[hint_id] = true
	GameManager.player_data["tutorial_flags"] = flags
	var hint: Dictionary = HINTS[hint_id]
	hint_fired.emit(hint_id, hint["title"], hint["text"])


func _on_tool_opened(tool_name: String) -> void:
	if tool_name == "Network Map":
		_maybe_fire("open_network_map")


func _on_task_started(tool_name: String, _task_id: String) -> void:
	if tool_name == "password_cracker":
		_maybe_fire("first_crack_run")


func _on_network_disconnected() -> void:
	# If the sysadmin response flagged any node this session, surface the hint.
	if not NetworkSim.intrusion_flagged_nodes.is_empty():
		_maybe_fire("clean_disconnect")


func _on_log_message(text: String, level: String) -> void:
	if level == "error" and text.begins_with("Missing executable"):
		_maybe_fire("missing_exe_attempt")
