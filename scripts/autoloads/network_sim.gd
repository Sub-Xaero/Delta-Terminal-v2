extends Node
## Simulates the in-game network. Tracks nodes, active connection, and bounce chain.

# ── Node registry ─────────────────────────────────────────────────────────────
# Each node: { id, ip, name, security, files: [], services: [] }
var nodes: Dictionary = {}

# ── Active session ─────────────────────────────────────────────────────────────
var connected_node_id: String = ""
var bounce_chain: Array[String] = []   # ordered list of node ids routed through
var is_connected: bool = false
var cracked_nodes: Array[String] = []

# ── Trace state ───────────────────────────────────────────────────────────────
var trace_active: bool = false
var trace_progress: float = 0.0        # 0.0 – 1.0
var _trace_duration: float = 0.0
var _trace_elapsed: float = 0.0


func _ready() -> void:
	_register_default_nodes()


func _process(delta: float) -> void:
	if trace_active:
		_trace_elapsed += delta
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


# ── Node data ─────────────────────────────────────────────────────────────────

func register_node(data: Dictionary) -> void:
	nodes[data["id"]] = data


func get_node_data(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


func _register_default_nodes() -> void:
	# Starting network — replace with data-driven loading later.
	# map_position: pixel coords on the NetworkMapCanvas (~490 × 420 visible area)
	# connections: array of node IDs this node has a known route to

	register_node({
		"id": "local_01",
		"ip": "127.0.0.1",
		"name": "Local Machine",
		"security": 0,
		"map_position": Vector2(70, 200),
		"files": [],
		"services": [],
		"connections": ["isp_01", "isp_02"],
	})
	register_node({
		"id": "isp_01",
		"ip": "81.14.22.1",
		"name": "Sentinel ISP",
		"security": 1,
		"map_position": Vector2(210, 110),
		"files": [],
		"services": ["relay"],
		"connections": ["univ_01", "corp_01"],
	})
	register_node({
		"id": "isp_02",
		"ip": "81.14.22.2",
		"name": "Sentinel ISP (Backup)",
		"security": 1,
		"map_position": Vector2(210, 300),
		"files": [],
		"services": ["relay"],
		"connections": ["corp_01", "darknet_01"],
	})
	register_node({
		"id": "univ_01",
		"ip": "193.62.18.5",
		"name": "NeoTech University",
		"security": 2,
		"map_position": Vector2(370, 60),
		"files": [],
		"services": [],
		"connections": ["corp_01"],
	})
	register_node({
		"id": "corp_01",
		"ip": "84.23.119.41",
		"name": "ArcTech Systems",
		"security": 3,
		"map_position": Vector2(370, 200),
		"files": [],
		"services": [],
		"connections": [],
	})
	register_node({
		"id": "darknet_01",
		"ip": "10.0.13.37",
		"name": "Darknet Relay",
		"security": 2,
		"map_position": Vector2(370, 350),
		"files": [],
		"services": ["relay"],
		"connections": ["corp_01"],
	})
