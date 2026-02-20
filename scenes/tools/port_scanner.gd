class_name PortScanner
extends ToolWindow
## Recon tool — discovers open ports and services on a target node.
## Scan duration scales with node security. Results are stored on the node
## in NetworkSim so other tools can gate behaviour on discovered services.

enum State { IDLE, SCANNING, DONE }

# Maps service names (used in node data) to port numbers and display labels.
const SERVICE_PORTS: Dictionary = {
	"shell":  { "port": 22,   "label": "SSH / Shell" },
	"ftp":    { "port": 21,   "label": "FTP" },
	"http":   { "port": 80,   "label": "HTTP" },
	"https":  { "port": 443,  "label": "HTTPS" },
	"relay":  { "port": 1080, "label": "Proxy Relay" },
	"smtp":   { "port": 25,   "label": "SMTP Mail" },
	"telnet": { "port": 23,   "label": "Telnet" },
	"db":     { "port": 3306, "label": "Database" },
}

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var ip_input: LineEdit        = $ContentArea/Margin/VBox/InputRow/IPInput
@onready var scan_btn: Button          = $ContentArea/Margin/VBox/InputRow/ScanBtn
@onready var scan_bar: ProgressBar     = $ContentArea/Margin/VBox/ScanBar
@onready var scroll:   ScrollContainer = $ContentArea/Margin/VBox/Scroll
@onready var output:   VBoxContainer   = $ContentArea/Margin/VBox/Scroll/Output

# ── State ──────────────────────────────────────────────────────────────────────
var _state:          State  = State.IDLE
var _scan_elapsed:   float  = 0.0
var _scan_duration:  float  = 0.0
var _pending_lines:  Array  = []
var _line_interval:  float  = 0.0
var _line_timer:     float  = 0.0
var _target_node_id: String = ""


func _ready() -> void:
	super._ready()
	scan_btn.pressed.connect(_on_scan_pressed)
	ip_input.text_submitted.connect(func(_t: String) -> void: _on_scan_pressed())
	scan_bar.visible = false
	_setup_theme()
	# Pre-fill with connected node IP for convenience
	if NetworkSim.is_connected:
		ip_input.text = NetworkSim.get_node_data(NetworkSim.connected_node_id).get("ip", "")


func _process(delta: float) -> void:
	if _state != State.SCANNING:
		return
	var stk_speed: float = HardwareManager.effective_stack_speed
	_scan_elapsed += delta * stk_speed
	scan_bar.value  = minf(_scan_elapsed / _scan_duration, 1.0) * 100.0
	_line_timer    -= delta * stk_speed
	if _line_timer <= 0.0 and not _pending_lines.is_empty():
		_reveal_next_line()
		_line_timer = _line_interval
	if _scan_elapsed >= _scan_duration and _pending_lines.is_empty():
		_finish_scan()


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_scan_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty() or _state == State.SCANNING:
		return
	_target_node_id = _find_node_by_ip(ip)
	if _target_node_id.is_empty():
		_clear_output()
		_add_line("ERROR: Host %s not found." % ip, Color(1.0, 0.08, 0.55))
		_state = State.IDLE
		return
	_start_scan(_target_node_id)


func _start_scan(node_id: String) -> void:
	var data:     Dictionary = NetworkSim.get_node_data(node_id)
	var security: int        = data.get("security", 1)
	_scan_duration = maxf(4.0, float(security) * 6.0)
	_scan_elapsed  = 0.0
	_state         = State.SCANNING
	scan_bar.visible  = true
	scan_bar.value    = 0.0
	scan_btn.disabled = true
	_clear_output()

	var ip:       String = data.get("ip", node_id)
	var services: Array  = data.get("services", [])

	# Resolve open ports from the node's service list
	var open_ports: Array = []
	for svc: String in services:
		if SERVICE_PORTS.has(svc):
			var entry: Dictionary = SERVICE_PORTS[svc]
			open_ports.append({ "port": entry["port"], "service": svc, "label": entry["label"] })

	# Store results on the node immediately so other tools can use them
	NetworkSim.nodes[node_id]["scanned_ports"] = open_ports

	# Build the lines to reveal progressively during the scan
	_pending_lines = []
	_pending_lines.append({ "text": "Scanning %s ..." % ip,         "color": Color(0.75, 0.92, 1.0) })
	_pending_lines.append({ "text": _row("PORT", "STATE", "SERVICE"), "color": Color(0.45, 0.6, 0.65) })
	_pending_lines.append({ "text": _row("------", "-----", "-------"), "color": Color(0.45, 0.6, 0.65) })

	for p: Dictionary in open_ports:
		_pending_lines.append({
			"text":  _row(str(p["port"]) + "/tcp", "open", p["label"]),
			"color": Color(0.0, 0.88, 1.0),
		})

	if open_ports.is_empty():
		_pending_lines.append({ "text": "  (no open ports detected)", "color": Color(0.45, 0.6, 0.65) })

	_pending_lines.append({ "text": "", "color": Color.WHITE })  # blank line before summary

	# Space lines evenly across 85% of the scan window; summary is appended on finish
	_line_interval = (_scan_duration * 0.85) / maxf(float(_pending_lines.size()), 1.0)
	_line_timer    = 0.1  # Short delay before first line appears

	EventBus.tool_task_started.emit("port_scanner", node_id)
	EventBus.log_message.emit("Port scan initiated on %s" % ip, "info")


func _finish_scan() -> void:
	_state = State.DONE
	var data:     Dictionary = NetworkSim.get_node_data(_target_node_id)
	var ip:       String     = data.get("ip", _target_node_id)
	var port_cnt: int        = (data.get("scanned_ports", []) as Array).size()

	_add_line(
		"Scan complete — %d open port(s) found." % port_cnt,
		Color(0.0, 0.88, 1.0) if port_cnt > 0 else Color(1.0, 0.75, 0.0),
	)

	# ── Node discovery ────────────────────────────────────────────────────────
	var discovered_count: int = _discover_adjacent_nodes(data)
	if discovered_count > 0:
		_add_line(
			"[Discovery] %d new node(s) found in routing table" % discovered_count,
			Color(1.0, 0.75, 0.0),
		)

	scan_bar.visible  = false
	scan_btn.disabled = false

	EventBus.tool_task_completed.emit("port_scanner", _target_node_id, true)
	EventBus.log_message.emit(
		"Scan complete: %d open port(s) found on %s" % [port_cnt, ip], "info"
	)


# ── Discovery ─────────────────────────────────────────────────────────────────

func _discover_adjacent_nodes(node_data: Dictionary) -> int:
	if not NetworkSim.has_method("discover_node"):
		# TODO: NetworkSim.discover_node() — see Task #1
		return 0
	var connections: Array = node_data.get("connections", [])
	var count: int = 0
	for conn_id: String in connections:
		if conn_id not in NetworkSim.discovered_nodes:
			NetworkSim.discover_node(conn_id)
			count += 1
	return count


# ── Output helpers ─────────────────────────────────────────────────────────────

func _reveal_next_line() -> void:
	if _pending_lines.is_empty():
		return
	var entry: Dictionary = _pending_lines.pop_front()
	_add_line(entry.get("text", ""), entry.get("color", Color(0.75, 0.92, 1.0)))


func _add_line(text: String, color: Color = Color(0.75, 0.92, 1.0)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	output.add_child(lbl)
	_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _clear_output() -> void:
	for child in output.get_children():
		child.queue_free()


# ── Network helpers ────────────────────────────────────────────────────────────

func _find_node_by_ip(ip: String) -> String:
	for node_id: String in NetworkSim.nodes:
		if NetworkSim.nodes[node_id].get("ip", "") == ip:
			return node_id
	return ""


func _row(col1: String, col2: String, col3: String) -> String:
	return col1.rpad(10) + col2.rpad(8) + col3


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.0, 0.88, 1.0)
	scan_bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.12, 0.18)
	scan_bar.add_theme_stylebox_override("background", bar_bg)

	scan_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	ip_input.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
