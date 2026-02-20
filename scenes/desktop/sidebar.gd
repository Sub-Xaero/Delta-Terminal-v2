class_name Sidebar
extends Panel
## Persistent right-side panel: network minimap + connection status.
## Not a ToolWindow — always visible, never spawned by WindowManager.

@onready var minimap: SidebarMinimap   = $MarginContainer/VBoxContainer/MinimapContainer/NetworkMinimap
@onready var minimap_container: Panel  = $MarginContainer/VBoxContainer/MinimapContainer
@onready var conn_label: Label         = $MarginContainer/VBoxContainer/ConnLabel
@onready var disconnect_btn: Button    = $MarginContainer/VBoxContainer/DisconnectBtn

var _connected_id: String = ""
var _pulse_timer: float = 0.0


func _ready() -> void:
	_apply_theme()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.bounce_chain_updated.connect(_on_bounce_chain_updated)


func _process(delta: float) -> void:
	if _connected_id.is_empty():
		return
	_pulse_timer += delta * 2.2
	conn_label.modulate = Color(1, 1, 1, 0.65 + 0.35 * abs(sin(_pulse_timer)))


func _apply_theme() -> void:
	# Sidebar background — left seam glows cyan
	var style := StyleBoxFlat.new()
	style.bg_color      = Color(0.04, 0.03, 0.10, 0.97)
	style.border_color  = Color(0.0, 0.88, 1.0)
	style.border_width_left = 1
	style.shadow_color  = Color(0.0, 0.88, 1.0, 0.25)
	style.shadow_size   = 10
	add_theme_stylebox_override("panel", style)

	disconnect_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	disconnect_btn.pressed.connect(_on_conn_btn_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	disconnect_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.0, 0.88, 1.0, 0.08)
	disconnect_btn.add_theme_stylebox_override("hover", btn_hover)

	$MarginContainer/VBoxContainer/SectionLabel.text = "// NETWORK //"

	# Minimap container border + glow
	var map_style := StyleBoxFlat.new()
	map_style.bg_color     = Color(0.02, 0.02, 0.06)
	map_style.border_color = Color(0.0, 0.88, 1.0)
	map_style.set_border_width_all(1)
	map_style.shadow_color = Color(0.0, 0.88, 1.0, 0.15)
	map_style.shadow_size  = 3
	minimap_container.add_theme_stylebox_override("panel", map_style)


# ── EventBus reactions ─────────────────────────────────────────────────────────

func _on_conn_btn_pressed() -> void:
	if _connected_id != "":
		NetworkSim.disconnect_from_node()
	else:
		EventBus.open_tool_requested.emit("Network Map")


func _on_network_connected(node_id: String) -> void:
	_connected_id = node_id
	var data := NetworkSim.get_node_data(node_id)
	conn_label.text = data.get("ip", node_id)
	conn_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	disconnect_btn.text = "[ DISCONNECT ]"
	disconnect_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	minimap.connected_id = node_id
	minimap.queue_redraw()


func _on_network_disconnected() -> void:
	_connected_id = ""
	conn_label.text = "OFFLINE"
	conn_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	conn_label.modulate = Color(1, 1, 1, 1)
	_pulse_timer = 0.0
	disconnect_btn.text = "[ CONNECT ]"
	disconnect_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	minimap.connected_id = ""
	minimap.queue_redraw()


func _on_bounce_chain_updated(chain: Array) -> void:
	minimap.bounce_chain = chain
	minimap.queue_redraw()
