extends Node
## Tracks installed hardware and exposes derived stats used by other systems.
## RAM capacity limits how many tools can be open simultaneously.
## Stack speed (shared across active hacks) determines how fast operations complete.
## Modem speed multiplier slows trace accumulation.
## Security chips can nuke the entire system to avoid a trace completion penalty.

# ── Catalog ────────────────────────────────────────────────────────────────────
# type: "mobo" | "ram" | "stack" | "network" | "security"
# Motherboard: ram_slots (int)
# RAM:         ram_capacity (int) — number of concurrent tools this stick supports
# Stack:       cpu_speed (float)  — base speed multiplier; shared across active hacks
# Network:     trace_mult (float) — higher = trace accumulates slower
# Security:    nuke_mode (String) — "auto" triggers on trace_completed; "manual" is player-activated
const CATALOG: Array[Dictionary] = [
	# ── Motherboards ──────────────────────────────────────────────────────────
	{
		"id": "mobo_basic", "type": "mobo", "name": "Basic Mobo",
		"desc": "2 RAM slots. Ships with every rig.",
		"ram_slots": 2, "cost": 0,
	},
	{
		"id": "mobo_pro", "type": "mobo", "name": "Pro Mobo",
		"desc": "4 RAM slots. Handles a serious toolkit.",
		"ram_slots": 4, "cost": 2500,
	},
	{
		"id": "mobo_elite", "type": "mobo", "name": "Elite Mobo",
		"desc": "6 RAM slots. Maximum parallel operations.",
		"ram_slots": 6, "cost": 8000,
	},

	# ── RAM ───────────────────────────────────────────────────────────────────
	{
		"id": "ram_256", "type": "ram", "name": "256MB SIMM",
		"desc": "Supports one concurrent tool.",
		"ram_capacity": 1, "cost": 500,
	},
	{
		"id": "ram_512", "type": "ram", "name": "512MB DIMM",
		"desc": "Supports two concurrent tools per slot.",
		"ram_capacity": 2, "cost": 1200,
	},
	{
		"id": "ram_1gb", "type": "ram", "name": "1GB DDR",
		"desc": "High-density. Supports four tools per slot.",
		"ram_capacity": 4, "cost": 3000,
	},

	# ── Stacks ────────────────────────────────────────────────────────────────
	{
		"id": "cpu_z80", "type": "stack", "name": "Solo Stack",
		"desc": "Single processing node. Baseline throughput.",
		"cpu_speed": 1.0, "cost": 0,
	},
	{
		"id": "cpu_dual", "type": "stack", "name": "Dual Stack",
		"desc": "Two parallel nodes. 2x speed, distributed across active hacks.",
		"cpu_speed": 2.0, "cost": 3000,
	},
	{
		"id": "cpu_quad", "type": "stack", "name": "Quad Stack",
		"desc": "Four-node array. 4x base throughput.",
		"cpu_speed": 4.0, "cost": 8000,
	},
	{
		"id": "cpu_quantum", "type": "stack", "name": "Quantum Stack",
		"desc": "Eight entangled nodes. 8x throughput. Experimental.",
		"cpu_speed": 8.0, "cost": 20000,
	},

	# ── Network ───────────────────────────────────────────────────────────────
	{
		"id": "net_56k", "type": "network", "name": "56K Modem",
		"desc": "Standard dialup. No trace reduction.",
		"trace_mult": 1.0, "cost": 0,
	},
	{
		"id": "net_cable", "type": "network", "name": "Cable NIC",
		"desc": "Broadband. Trace accumulates 1.5x slower.",
		"trace_mult": 1.5, "cost": 1000,
	},
	{
		"id": "net_fiber", "type": "network", "name": "Fiber NIC",
		"desc": "Fast link. Trace accumulates 2x slower.",
		"trace_mult": 2.0, "cost": 4000,
	},
	{
		"id": "net_quantum", "type": "network", "name": "Quantum NIC",
		"desc": "Cutting-edge. Trace accumulates 3x slower.",
		"trace_mult": 3.0, "cost": 12000,
	},

	# ── Security ──────────────────────────────────────────────────────────────
	{
		"id": "sec_dead_mans", "type": "security", "name": "Dead Man's Switch",
		"desc": "Auto-nukes when trace completes. No warning.",
		"nuke_mode": "auto", "cost": 5000,
	},
	{
		"id": "sec_kill_sw", "type": "security", "name": "Manual Kill Switch",
		"desc": "DETONATE button in Hardware Viewer. Player-activated only.",
		"nuke_mode": "manual", "cost": 8000,
	},
]

const _STARTING_MOBO_ID:    String = "mobo_basic"
const _STARTING_RAM_IDS:    Array  = ["ram_256", "ram_256"]
const _STARTING_STACK_ID:   String = "cpu_z80"
const _STARTING_NETWORK_ID: String = "net_56k"
const _STARTING_CREDITS:    int    = 1000

# Tools that never consume RAM — always open, never gated.
const PASSIVE_TOOLS: Array[String] = ["System Log", "Trace Tracker", "Network Map", "Mission Log"]


# ── Installed hardware state ────────────────────────────────────────────────────
var installed_mobo:     Dictionary = {}
var installed_ram:      Array[Dictionary] = []
var installed_stack:    Dictionary = {}
var installed_network:  Dictionary = {}
var installed_security: Dictionary = {}

# ── Derived stats ──────────────────────────────────────────────────────────────
var ram_slots_total:        int   = 0
var ram_capacity:           int   = 0
var ram_used:               int   = 0
var modem_trace_multiplier: float = 1.0

# ── Stack ──────────────────────────────────────────────────────────────────────
var active_hack_count: int = 0

var effective_stack_speed: float:
	get: return installed_stack.get("cpu_speed", 1.0) / max(1, active_hack_count)


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_reset_to_starting_config()
	EventBus.tool_opened.connect(_on_tool_opened)
	EventBus.tool_closed.connect(_on_tool_closed)
	EventBus.trace_completed.connect(_on_trace_completed)
	EventBus.tool_task_started.connect(_on_task_started)
	EventBus.tool_task_completed.connect(_on_task_completed)


# ── Public API ────────────────────────────────────────────────────────────────

## Returns false and emits a log error if RAM is at capacity.
## Passive tools always return true.
func can_open_tool(tool_name: String) -> bool:
	if tool_name in PASSIVE_TOOLS:
		return true
	if ram_used >= ram_capacity:
		EventBus.log_message.emit(
			"Insufficient RAM — upgrade hardware. (%d/%d slots used)" % [ram_used, ram_capacity],
			"error"
		)
		return false
	return true


## Deducts credits and installs the item. Returns false if unknown id or insufficient credits.
func purchase_item(item_id: String) -> bool:
	var item: Dictionary = _find_catalog_item(item_id)
	if item.is_empty():
		push_warning("HardwareManager: unknown item id '%s'" % item_id)
		return false
	var cost: int = item.get("cost", 0)
	if GameManager.player_data.get("credits", 0) < cost:
		EventBus.log_message.emit("Insufficient credits.", "error")
		return false
	GameManager.add_credits(-cost)
	_install_item(item)
	EventBus.hardware_changed.emit()
	EventBus.log_message.emit("Hardware installed: %s" % item["name"], "info")
	return true


func get_save_data() -> Dictionary:
	return {
		"mobo_id":     installed_mobo.get("id", _STARTING_MOBO_ID),
		"ram_ids":     installed_ram.map(func(r: Dictionary) -> String: return r.get("id", "")),
		"cpu_id":      installed_stack.get("id", _STARTING_STACK_ID),
		"network_id":  installed_network.get("id", _STARTING_NETWORK_ID),
		"security_id": installed_security.get("id", ""),
	}


func load_save_data(data: Dictionary) -> void:
	installed_mobo    = _find_catalog_item(data.get("mobo_id", _STARTING_MOBO_ID))
	installed_ram.clear()
	for rid: String in data.get("ram_ids", []):
		var r: Dictionary = _find_catalog_item(rid)
		if not r.is_empty():
			installed_ram.append(r)
	installed_stack   = _find_catalog_item(data.get("cpu_id", _STARTING_STACK_ID))
	installed_network = _find_catalog_item(data.get("network_id", _STARTING_NETWORK_ID))
	var sec_id: String = data.get("security_id", "")
	installed_security = {} if sec_id.is_empty() else _find_catalog_item(sec_id)
	_recalculate_derived()
	EventBus.hardware_changed.emit()


func trigger_nuke() -> void:
	EventBus.log_message.emit(">>> DEAD MAN'S SWITCH TRIGGERED <<<", "error")
	EventBus.log_message.emit("Purging all data...", "error")
	NetworkSim.disconnect_from_node()
	SaveManager.delete_save()
	_reset_to_starting_config()
	GameManager.player_data = {
		"handle":  GameManager.player_data.get("handle", "ghost"),
		"credits": _STARTING_CREDITS,
		"rating":  1,
	}
	GameManager.active_missions.clear()
	GameManager.completed_missions.clear()
	NetworkSim.cracked_nodes.clear()
	ram_used = 0
	active_hack_count = 0
	EventBus.log_message.emit("SYSTEM DESTROYED — hardware reset to factory defaults.", "error")
	EventBus.system_nuke_triggered.emit()


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_tool_opened(tool_name: String) -> void:
	if tool_name in PASSIVE_TOOLS:
		return
	ram_used += 1


func _on_tool_closed(tool_name: String) -> void:
	if tool_name in PASSIVE_TOOLS:
		return
	ram_used = maxi(0, ram_used - 1)


func _on_trace_completed() -> void:
	if installed_security.get("nuke_mode", "") == "auto":
		trigger_nuke()


func _on_task_started(_tool_name: String, _task_id: String) -> void:
	active_hack_count += 1
	EventBus.hardware_changed.emit()


func _on_task_completed(_tool_name: String, _task_id: String, _success: bool) -> void:
	active_hack_count = maxi(0, active_hack_count - 1)
	EventBus.hardware_changed.emit()


# ── Internal helpers ──────────────────────────────────────────────────────────

func _install_item(item: Dictionary) -> void:
	match item.get("type", ""):
		"mobo":
			installed_mobo = item
		"ram":
			if installed_ram.size() < ram_slots_total:
				installed_ram.append(item)
			else:
				EventBus.log_message.emit(
					"No free RAM slots — upgrade your motherboard first.", "warn"
				)
				GameManager.add_credits(item.get("cost", 0))
				return
		"stack":
			installed_stack = item
		"network":
			installed_network = item
		"security":
			installed_security = item
	_recalculate_derived()


func _recalculate_derived() -> void:
	ram_slots_total        = installed_mobo.get("ram_slots", 2)
	ram_capacity           = 0
	for r: Dictionary in installed_ram:
		ram_capacity += r.get("ram_capacity", 1)
	modem_trace_multiplier = installed_network.get("trace_mult", 1.0)


func _reset_to_starting_config() -> void:
	installed_mobo     = _find_catalog_item(_STARTING_MOBO_ID)
	installed_ram.clear()
	for rid: String in _STARTING_RAM_IDS:
		installed_ram.append(_find_catalog_item(rid))
	installed_stack    = _find_catalog_item(_STARTING_STACK_ID)
	installed_network  = _find_catalog_item(_STARTING_NETWORK_ID)
	installed_security = {}
	active_hack_count  = 0
	_recalculate_derived()


func _find_catalog_item(item_id: String) -> Dictionary:
	for item: Dictionary in CATALOG:
		if item.get("id", "") == item_id:
			return item
	return {}
