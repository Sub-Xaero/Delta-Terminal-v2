class_name NetworkMap
extends ToolWindow
## Network map tool — shows all known nodes, edges, and the active connection.
## Single-click a node to inspect it; shift-click to add/remove from bounce chain;
## double-click (or press CONNECT) to connect through the current chain.
## Chain lines are drawn in amber while building; they turn cyan once connected.

const NetworkMapNodeScene := preload("res://scenes/tools/network_map_node.tscn")

# ── Node path references ───────────────────────────────────────────────────────
@onready var map_canvas:    NetworkMapCanvas = $ContentArea/HSplit/MapCanvas
@onready var info_name:     Label            = $ContentArea/HSplit/InfoPanel/VBox/NodeName
@onready var info_ip:       Label            = $ContentArea/HSplit/InfoPanel/VBox/NodeIP
@onready var info_security: Label            = $ContentArea/HSplit/InfoPanel/VBox/NodeSecurity
@onready var info_services: Label            = $ContentArea/HSplit/InfoPanel/VBox/NodeServices
@onready var connect_btn:   Button           = $ContentArea/HSplit/InfoPanel/VBox/ConnectBtn
@onready var disconnect_btn: Button          = $ContentArea/HSplit/InfoPanel/VBox/DisconnectBtn

# ── State ──────────────────────────────────────────────────────────────────────
var _node_widgets: Dictionary = {}  # node_id -> NetworkMapNode
var _selected_id:  String     = ""


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.bounce_chain_updated.connect(_on_bounce_chain_updated)
	EventBus.node_discovered.connect(_on_node_discovered)
	EventBus.node_removed.connect(_on_node_removed)
	connect_btn.pressed.connect(_on_connect_pressed)
	disconnect_btn.pressed.connect(NetworkSim.disconnect_from_node)
	_apply_info_panel_theme()
	_populate_map()
	_clear_info_panel()
	# Fullscreen: disable drag and anchor to fill the WindowLayer next frame
	# (deferred so it runs after WindowManager sets the initial position)
	title_bar.gui_input.disconnect(_on_title_bar_input)
	call_deferred("_enforce_fullscreen")


func _enforce_fullscreen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2.ZERO


# ── Map population ─────────────────────────────────────────────────────────────

func _populate_map() -> void:
	for node_id in NetworkSim.nodes:
		_spawn_node_widget(NetworkSim.nodes[node_id])
	_rebuild_edges()


func _spawn_node_widget(data: Dictionary) -> void:
	var widget: NetworkMapNode = NetworkMapNodeScene.instantiate()
	map_canvas.add_child(widget)
	widget.setup(data)
	# Position the widget so its icon centre lands on map_position
	var centre: Vector2 = data.get("map_position", Vector2(100.0, 100.0))
	widget.position = centre - Vector2(NetworkMapNode.ICON_SIZE * 0.5,
									   NetworkMapNode.ICON_SIZE * 0.5)
	widget.node_clicked.connect(_on_node_clicked)
	widget.node_double_clicked.connect(_on_node_double_clicked)
	widget.node_shift_clicked.connect(_on_node_shift_clicked)
	_node_widgets[data["id"]] = widget


func _rebuild_edges() -> void:
	var edges: Array = []
	var local_id := _find_local_node_id()
	var chain    := NetworkSim.bounce_chain
	var active   := NetworkSim.is_connected

	# Build the route path: local → chain hops → target (if connected)
	var path: Array[String] = []
	if local_id != "":
		path.append(local_id)
	path.append_array(chain)
	if active:
		path.append(NetworkSim.connected_node_id)

	# Draw edges between consecutive path nodes.
	# Amber while planning the chain, cyan once the connection is live.
	var col := Color(0.0, 0.88, 1.0, 0.75) if active else Color(1.0, 0.75, 0.0, 0.55)
	var w   := 2.0 if active else 1.5

	for i in range(path.size() - 1):
		var from_id: String = path[i]
		var to_id:   String = path[i + 1]
		if not (NetworkSim.nodes.has(from_id) and NetworkSim.nodes.has(to_id)):
			continue
		edges.append({
			"from":  NetworkSim.nodes[from_id].get("map_position", Vector2.ZERO),
			"to":    NetworkSim.nodes[to_id].get("map_position", Vector2.ZERO),
			"color": col,
			"width": w,
		})

	map_canvas.update_edges(edges)


func _find_local_node_id() -> String:
	for id in NetworkSim.nodes:
		if NetworkSim.nodes[id].get("security", -1) == 0:
			return id
	return ""


# ── Node interaction ───────────────────────────────────────────────────────────

func _on_node_clicked(node_id: String) -> void:
	if _selected_id != "" and _node_widgets.has(_selected_id):
		_node_widgets[_selected_id].set_selected(false)
	_selected_id = node_id
	_node_widgets[node_id].set_selected(true)
	_update_info_panel(node_id)


func _on_node_double_clicked(node_id: String) -> void:
	_on_node_clicked(node_id)
	if node_id != NetworkSim.connected_node_id:
		NetworkSim.connect_to_node(node_id)


func _on_node_shift_clicked(node_id: String) -> void:
	if node_id in NetworkSim.bounce_chain:
		NetworkSim.remove_from_bounce_chain(node_id)
	else:
		NetworkSim.add_to_bounce_chain(node_id)


func _on_connect_pressed() -> void:
	if _selected_id != "" and _selected_id != NetworkSim.connected_node_id:
		NetworkSim.connect_to_node(_selected_id)


# ── Info panel ─────────────────────────────────────────────────────────────────

func _update_info_panel(node_id: String) -> void:
	var data := NetworkSim.get_node_data(node_id)
	info_name.text     = data.get("name", "Unknown")
	info_ip.text       = "IP:       %s"  % data.get("ip", "—")
	info_security.text = "Security: %s"  % _security_label(data.get("security", 1))
	var svcs: Array    = data.get("services", [])
	info_services.text = "Services:\n  %s" % (
		", ".join(svcs) if not svcs.is_empty() else "Unknown — run port scan"
	)
	var is_own:    bool = data.get("security", 1) == 0
	var is_active: bool = node_id == NetworkSim.connected_node_id
	connect_btn.text     = "CONNECTED" if is_active else "CONNECT"
	connect_btn.disabled = is_active or is_own
	disconnect_btn.visible = is_active


func _clear_info_panel() -> void:
	info_name.text     = "— No target selected —"
	info_ip.text       = ""
	info_security.text = ""
	info_services.text = ""
	connect_btn.text     = "CONNECT"
	connect_btn.disabled = true
	disconnect_btn.visible = false


func _security_label(level: int) -> String:
	match level:
		0: return "0 — Local"
		1: return "1 — Minimal"
		2: return "2 — Low"
		3: return "3 — Moderate"
		4: return "4 — High"
		_: return "%d — Critical" % level


# ── EventBus reactions ─────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	for id in _node_widgets:
		_node_widgets[id].set_connected(id == node_id)
	_rebuild_edges()
	if _selected_id == node_id:
		_update_info_panel(node_id)


func _on_network_disconnected() -> void:
	for id in _node_widgets:
		_node_widgets[id].set_connected(false)
		_node_widgets[id].set_chain_position(-1)
	_rebuild_edges()
	if _selected_id != "":
		_update_info_panel(_selected_id)


func _on_bounce_chain_updated(chain: Array) -> void:
	for id in _node_widgets:
		_node_widgets[id].set_chain_position(chain.find(id))
	_rebuild_edges()


func _on_node_discovered(node_id: String) -> void:
	if _node_widgets.has(node_id):
		_node_widgets[node_id].set_undiscovered(false)
	_rebuild_edges()


func _on_node_removed(node_id: String) -> void:
	if _node_widgets.has(node_id):
		_node_widgets[node_id].set_undiscovered(true)
	_rebuild_edges()


# ── Theme ──────────────────────────────────────────────────────────────────────

func _apply_info_panel_theme() -> void:
	var panel := $ContentArea/HSplit/InfoPanel as Panel
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.05, 0.04, 0.12)
	style.border_color = Color(0.0, 0.88, 1.0)
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel", style)

	for lbl in [info_name, info_ip, info_security, info_services]:
		lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))

	connect_btn.add_theme_color_override("font_color",    Color(0.0, 0.88, 1.0))
	disconnect_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
