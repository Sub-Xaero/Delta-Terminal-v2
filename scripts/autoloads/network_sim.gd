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


func _register_default_nodes() -> void:
	# Starting network — replace with data-driven loading later.
	# map_position: pixel coords on the NetworkMapCanvas, equirectangular projection.
	#   x = (lon + 180) / 360 * canvas_w   (canvas_w ≈ 700)
	#   y = (80 - lat)  / 135 * canvas_h   (canvas_h ≈ 510, lat range −55 to +80)
	# connections: array of node IDs this node has a known route to

	register_node({
		"id": "local_01",
		"ip": "127.0.0.1",
		"name": "Local Machine",
		"security": 0,
		"map_position": Vector2(334, 102),  # Ireland / West UK  (53°N, 8°W)
		"files": [],
		"services": [],
		"connections": ["isp_01", "isp_02"],
	})
	register_node({
		"id": "isp_01",
		"ip": "81.14.22.1",
		"name": "Sentinel ISP",
		"security": 1,
		"map_position": Vector2(399, 68),   # Scandinavia / Sweden  (62°N, 25°E)
		"files": [
			{
				"id": "isp01_f1",
				"name": "routing.cfg",
				"type": "config",
				"size": 512,
				"content": "# Sentinel ISP Routing Config\ngateway=81.14.22.254\ndns_primary=81.14.0.1\ndns_secondary=81.14.0.2\nmax_hops=16\nlog_level=warn",
			},
		],
		"services": ["relay"],
		"connections": ["univ_01", "corp_01"],
	})
	register_node({
		"id": "isp_02",
		"ip": "81.14.22.2",
		"name": "Sentinel ISP (Asia-Pacific)",
		"security": 1,
		"map_position": Vector2(552, 297),  # Singapore  (1°N, 104°E)
		"files": [],
		"services": ["relay"],
		"connections": ["corp_01", "darknet_01"],
	})
	register_node({
		"id": "univ_01",
		"ip": "193.62.18.5",
		"name": "NeoTech University",
		"security": 2,
		"map_position": Vector2(621, 167),  # Tokyo, Japan  (36°N, 140°E)
		"files": [
			{
				"id": "univ01_f1",
				"name": "research_data.dat",
				"type": "data",
				"size": 6144,
				"content": "PROJECT: HELIX-7\nClassification: RESTRICTED\n\nSubject trials 001-048 complete. Cognitive augmentation index nominal.\nAnomaly detected in subject 023 — elevated neural binding ratio.\nRecommend further isolation and extended observation.\n\nData checksum: 0xAF3C91B2",
			},
			{
				"id": "univ01_f2",
				"name": "access.log",
				"type": "log",
				"size": 1024,
				"content": "[2057-11-03 02:14:08] LOGIN  admin       193.62.18.1  OK\n[2057-11-03 03:41:22] LOGIN  r.nakamura   10.0.0.44    OK\n[2057-11-03 04:02:55] LOGIN  UNKNOWN      81.14.22.1   FAIL\n[2057-11-03 04:02:57] LOGIN  UNKNOWN      81.14.22.1   FAIL\n[2057-11-03 04:02:59] ALERT  Brute-force detected — IP flagged",
			},
		],
		"services": [],
		"connections": ["corp_01"],
	})
	register_node({
		"id": "corp_01",
		"ip": "84.23.119.41",
		"name": "ArcTech Systems",
		"security": 3,
		"map_position": Vector2(206, 148),  # New York, USA  (41°N, 74°W)
		"files": [
			{
				"id": "corp01_f1",
				"name": "employee_records.dat",
				"type": "data",
				"size": 14336,
				"content": "ID     | NAME                  | DEPT         | CLEARANCE\n-------|----------------------|--------------|----------\n00041  | Vasquez, Elena        | R&D          | L3\n00042  | Okafor, James         | Security     | L4\n00043  | Tanaka, Yui           | Executive    | L5\n00044  | Mercer, Dorian        | Finance      | L2\n00045  | [REDACTED]            | Black Ops    | L6\n\n[RECORD ACCESS LOGGED]",
			},
			{
				"id": "corp01_f2",
				"name": "Q3_financials.doc",
				"type": "doc",
				"size": 8192,
				"content": "ARCTECH SYSTEMS — Q3 FINANCIAL SUMMARY\n\nRevenue:      ¥ 4,820,000,000\nOperating:    ¥ 3,110,000,000\nNet Margin:   35.5%\n\nNOTE: Project HYDRA budget allocation concealed under 'Infrastructure'.\nActual spend: ¥ 890,000,000  (off-ledger, Board-eyes-only)\n\nDo not distribute.",
			},
			{
				"id": "corp01_f3",
				"name": "security_audit.log",
				"type": "log",
				"size": 3072,
				"content": "[2057-10-31 09:00:00] AUDIT START  -- ArcTech perimeter sweep\n[2057-10-31 09:14:32] Port 443 — TLS cert expiry warning (14 days)\n[2057-10-31 09:22:11] Firewall rule anomaly detected on DMZ-3\n[2057-10-31 09:22:45] ALERT: Unregistered MAC on internal VLAN 12\n[2057-10-31 09:23:01] Auto-quarantine triggered\n[2057-10-31 09:41:00] AUDIT END    -- 3 issues flagged",
			},
		],
		"services": [],
		"connections": [],
	})
	register_node({
		"id": "darknet_01",
		"ip": "10.0.13.37",
		"name": "Darknet Relay",
		"security": 2,
		"map_position": Vector2(535, 83),   # Siberia, Russia  (58°N, 95°E)
		"files": [
			{
				"id": "dark01_f1",
				"name": "relay_log.log",
				"type": "log",
				"size": 2048,
				"content": "[RELAY NODE — ENCRYPTED TRAFFIC LOG]\n\n2057-11-01 00:00:00  IN  84.23.119.41 -> [MASKED]   412 KB\n2057-11-01 00:00:03  IN  193.62.18.5  -> [MASKED]   88 KB\n2057-11-01 00:00:07  OUT [MASKED]     -> [MASKED]   500 KB\n\n[entries continue — 4,812 total this session]\n\n-- Operator: no-log policy enforced --",
			},
		],
		"services": ["relay"],
		"connections": ["corp_01"],
	})
