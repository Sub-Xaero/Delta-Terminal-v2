extends Node
## Simulates the in-game network. Tracks nodes, active connection, and bounce chain.

# ── Node registry ─────────────────────────────────────────────────────────────
# Each node: { id, ip, name, security, files: [], services: [], public_interfaces: [], protections: [] }
var nodes: Dictionary = {}

# ── Active session ─────────────────────────────────────────────────────────────
var connected_node_id: String = ""
var bounce_chain: Array[String] = []   # ordered list of node ids routed through
var is_connected: bool = false
var cracked_nodes: Array[String] = []
var bypassed_nodes: Array[String] = []
var encryption_broken_nodes: Array[String] = []
var discovered_nodes: Array = ["local_machine", "isp_gateway"]
var exploits_installed: Dictionary = {}   # node_id -> Array[String] of exploit types

# ── Trace state ───────────────────────────────────────────────────────────────
var trace_active: bool = false
var trace_progress: float = 0.0        # 0.0 – 1.0
var _trace_duration: float = 0.0
var _trace_elapsed: float = 0.0


func _ready() -> void:
	_load_nodes_from_data()


func _process(delta: float) -> void:
	if trace_active:
		_trace_elapsed += delta / HardwareManager.modem_trace_multiplier
		trace_progress = clampf(_trace_elapsed / _trace_duration, 0.0, 1.0)
		EventBus.trace_progress.emit(trace_progress)
		if trace_progress >= 1.0:
			_complete_trace()


# ── Connection ────────────────────────────────────────────────────────────────

func connect_to_node(node_id: String) -> bool:
	if not nodes.has(node_id):
		EventBus.log_message.emit("Unknown host: %s" % node_id, "error")
		return false
	connected_node_id = node_id
	is_connected = true
	EventBus.network_connected.emit(node_id)
	EventBus.log_message.emit("Connected to %s" % nodes[node_id]["ip"], "info")
	return true


func disconnect_from_node() -> void:
	if not is_connected:
		return
	EventBus.log_message.emit("Disconnected from %s" % nodes[connected_node_id]["ip"], "info")
	is_connected = false
	connected_node_id = ""
	bounce_chain.clear()
	if trace_active:
		trace_active = false
	EventBus.network_disconnected.emit()
	EventBus.bounce_chain_updated.emit(bounce_chain)


func add_to_bounce_chain(node_id: String) -> void:
	if node_id not in bounce_chain:
		bounce_chain.append(node_id)
		EventBus.bounce_chain_updated.emit(bounce_chain)


# ── Trace ─────────────────────────────────────────────────────────────────────

func start_trace(duration: float) -> void:
	trace_active = true
	_trace_duration = duration
	_trace_elapsed = 0.0
	trace_progress = 0.0
	EventBus.trace_started.emit(duration)


func _complete_trace() -> void:
	trace_active = false
	EventBus.trace_completed.emit()


# ── Cracking ──────────────────────────────────────────────────────────────────

func crack_node(node_id: String) -> void:
	if node_id in cracked_nodes:
		return
	cracked_nodes.append(node_id)
	EventBus.log_message.emit(
		"Access granted: %s  [%s]" % [nodes[node_id]["ip"], nodes[node_id]["name"]], "info"
	)


func bypass_node(node_id: String) -> void:
	if node_id in bypassed_nodes:
		return
	bypassed_nodes.append(node_id)
	EventBus.firewall_bypassed.emit(node_id)
	EventBus.log_message.emit(
		"Firewall bypassed: %s  [%s]" % [nodes[node_id]["ip"], nodes[node_id]["name"]], "warn"
	)


func node_requires_bypass(node_id: String) -> bool:
	var data: Dictionary = get_node_data(node_id)
	return data.get("security", 0) >= 3 or data.get("has_firewall", false)


func break_encryption(node_id: String) -> void:
	if node_id in encryption_broken_nodes:
		return
	encryption_broken_nodes.append(node_id)
	EventBus.log_message.emit(
		"Encryption broken: %s  [%s]" % [nodes[node_id]["ip"], nodes[node_id]["name"]], "info"
	)


# ── Discovery ────────────────────────────────────────────────────────────────

func discover_node(node_id: String) -> void:
	if node_id in discovered_nodes:
		return
	discovered_nodes.append(node_id)
	EventBus.node_discovered.emit(node_id)
	if nodes.has(node_id):
		EventBus.log_message.emit(
			"Node discovered: %s  [%s]" % [nodes[node_id]["ip"], nodes[node_id]["name"]], "info"
		)


# ── Node data ─────────────────────────────────────────────────────────────────

func register_node(data: Dictionary) -> void:
	nodes[data["id"]] = data


func get_node_data(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


func delete_file_from_node(node_id: String, file_id: String) -> bool:
	if not nodes.has(node_id):
		return false
	var files: Array = nodes[node_id].get("files", [])
	for i: int in files.size():
		if files[i].get("id", "") == file_id:
			files.remove_at(i)
			EventBus.log_message.emit(
				"File deleted from %s." % nodes[node_id]["ip"], "warn"
			)
			return true
	return false


func _load_nodes_from_data() -> void:
	var dir := DirAccess.open("res://data/nodes")
	if not dir:
		push_warning("NetworkSim: Could not open res://data/nodes — no nodes loaded.")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load("res://data/nodes/" + file_name)
			if res is NodeData:
				var data: Dictionary = {
					"id": res.id,
					"ip": res.ip,
					"name": res.name,
					"organisation": res.organisation,
					"security": res.security,
					"map_position": res.map_position,
					"files": res.files,
					"services": res.services,
					"connections": res.connections,
					"users": res.users,
					"faction_id": res.faction_id,
					"shop_catalogue": res.shop_catalogue,
				}
				register_node(data)
		file_name = dir.get_next()
	dir.list_dir_end()
