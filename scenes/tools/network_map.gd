class_name NetworkMap
extends ToolWindow
## Network map tool — shows all known nodes, edges, and the active connection.
## Single-click a node to inspect it; double-click (or press CONNECT) to connect.

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
	connect_btn.pressed.connect(_on_connect_pressed)
	disconnect_btn.pressed.connect(NetworkSim.disconnect_from_node)
	_apply_info_panel_theme()
	_populate_map()
	_clear_info_panel()


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
	_node_widgets[data["id"]] = widget


func _rebuild_edges() -> void:
	var edges: Array = []
	var in_chain := NetworkSim.bounce_chain

	for node_id in NetworkSim.nodes:
		var data: Dictionary = NetworkSim.nodes[node_id]
		var from: Vector2 = data.get("map_position", Vector2.ZERO)

		for target_id in data.get("connections", []):
			if not NetworkSim.nodes.has(target_id):
				continue
			var to: Vector2 = NetworkSim.nodes[target_id].get("map_position", Vector2.ZERO)
			var chained: bool = node_id in in_chain and target_id in in_chain
			var active:  bool = node_id == NetworkSim.connected_node_id \
						or target_id == NetworkSim.connected_node_id

			edges.append({
				"from":  from,
				"to":    to,
				"color": Color(0.0, 0.88, 1.0, 0.7 if (chained or active) else 0.18),
				"width": 2.0 if (chained or active) else 1.0,
			})

	map_canvas.update_edges(edges)


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
	_rebuild_edges()
	if _selected_id != "":
		_update_info_panel(_selected_id)


func _on_bounce_chain_updated(_chain: Array) -> void:
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
