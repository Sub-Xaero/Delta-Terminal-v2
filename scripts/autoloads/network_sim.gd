extends Node
## Simulates the in-game network. Tracks nodes, active connection, and bounce chain.

# ── Node registry ─────────────────────────────────────────────────────────────
# Each node: { id, ip, name, security, files: [], services: [] }
var nodes: Dictionary = {}

# ── Active session ─────────────────────────────────────────────────────────────
var connected_node_id: String = ""
var bounce_chain: Array[String] = []   # ordered list of node ids routed through
var is_connected: bool = false

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


# ── Node data ─────────────────────────────────────────────────────────────────

func register_node(data: Dictionary) -> void:
	nodes[data["id"]] = data


func get_node_data(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


func _register_default_nodes() -> void:
	# Placeholder starting nodes — replace with data-driven loading later.
	register_node({
		"id": "gateway_01",
		"ip": "192.168.0.1",
		"name": "Local Gateway",
		"security": 1,
		"files": [],
		"services": ["shell"],
	})
