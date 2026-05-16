class_name NetworkMapNode
extends Control
## Single node icon on the network map.
## Draws a circle whose border colour reflects security level and connection state.

signal node_clicked(node_id: String)
signal node_double_clicked(node_id: String)
signal node_shift_clicked(node_id: String)

const ICON_SIZE  := 32.0   # widget width; circle fills this square area
const RADIUS     := 10.0
const LABEL_H    := 12.0   # height reserved below circle for the name label

var node_id:   String     = ""
var node_data: Dictionary = {}

var _selected:     bool = false
var _connected:    bool = false
var _hovered:      bool = false
var _undiscovered: bool = false
var _chain_pos:    int  = -1   # -1 = not in chain; 0+ = hop index

@onready var ip_label: Label = $IPLabel


func _ready() -> void:
	mouse_entered.connect(func(): _hovered = true;  queue_redraw())
	mouse_exited.connect(func():  _hovered = false; queue_redraw())
	EventBus.intrusion_logged.connect(_on_intrusion_logged)
	EventBus.exploit_installed.connect(_on_exploit_installed)


func _on_intrusion_logged(_node_id: String) -> void:
	queue_redraw()


func _on_exploit_installed(_node_id: String, _kind: String) -> void:
	queue_redraw()


func setup(data: Dictionary) -> void:
	node_id   = data["id"]
	node_data = data
	_undiscovered = node_id not in NetworkSim.discovered_nodes
	ip_label.text = data.get("name", "") if not _undiscovered else ""
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE + LABEL_H)
	if _undiscovered:
		hide()
	queue_redraw()


func set_undiscovered(val: bool) -> void:
	_undiscovered = val
	ip_label.text = node_data.get("name", "") if not _undiscovered else ""
	if _undiscovered:
		hide()
	else:
		show()
	queue_redraw()


func set_selected(sel: bool) -> void:
	_selected = sel
	queue_redraw()


func set_connected(active: bool) -> void:
	_connected = active
	queue_redraw()


func set_chain_position(pos: int) -> void:
	_chain_pos = pos
	queue_redraw()


func _draw() -> void:
	var center := Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	var border := _border_colour()
	var fill   := Color(0.04, 0.03, 0.10)

	draw_circle(center, RADIUS, fill)
	draw_arc(center, RADIUS, 0.0, TAU, 64, border, 2.0, true)

	# Outer glow ring on selection / active connection / hover
	if _selected or _connected or _hovered:
		var glow := Color(border.r, border.g, border.b, 0.22)
		draw_arc(center, RADIUS + 3.0, 0.0, TAU, 64, glow, 3.0, true)

	# Filled centre dot when connected
	if _connected:
		draw_circle(center, 3.0, border)

	# Amber hop number badge at top-right when in bounce chain
	if _chain_pos >= 0:
		var font      := ThemeDB.fallback_font
		var font_size := 8
		var label     := str(_chain_pos + 1)
		var badge_col := Color(1.0, 0.75, 0.0)          # amber
		var badge_pos := Vector2(ICON_SIZE - 2.0, 6.0)  # top-right corner
		draw_string(font, badge_pos, label,
				HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, badge_col)

	# Red HOT badge at bottom-right when the sysadmin has flagged this node
	if NetworkSim.is_node_flagged(node_id):
		var font2     := ThemeDB.fallback_font
		var hot_col   := Color(1.0, 0.08, 0.55)
		var hot_pos   := Vector2(ICON_SIZE - 2.0, ICON_SIZE - 1.0)
		draw_string(font2, hot_pos, "HOT",
				HORIZONTAL_ALIGNMENT_RIGHT, -1, 7, hot_col)

	# Amber tint + exploit icon when the player has an installed exploit here
	if NetworkSim.exploits_installed.has(node_id) and not NetworkSim.exploits_installed[node_id].is_empty():
		var amber := Color(1.0, 0.75, 0.0, 0.18)
		draw_circle(center, RADIUS - 2.0, amber)
		var font3 := ThemeDB.fallback_font
		draw_string(font3, Vector2(0.0, ICON_SIZE - 1.0), "X",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.75, 0.0))


func _border_colour() -> Color:
	if _connected:
		return Color(0.0, 0.88, 1.0)    # cyan — active
	if _chain_pos >= 0:
		return Color(1.0, 0.75, 0.0)    # amber — in bounce chain
	if _selected:
		return Color(0.75, 0.92, 1.0)   # near-white — selected
	var sec: int = node_data.get("security", 1)
	if sec == 0:
		return Color(0.35, 0.35, 0.45)  # grey — own machine
	if sec <= 2:
		return Color(0.0, 0.88, 1.0)    # cyan — low
	if sec <= 4:
		return Color(1.0, 0.75, 0.0)    # amber — medium
	return Color(1.0, 0.08, 0.55)       # hot pink — high / critical


func _gui_input(event: InputEvent) -> void:
	if _undiscovered:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			node_double_clicked.emit(node_id)
		elif event.shift_pressed:
			node_shift_clicked.emit(node_id)
		else:
			node_clicked.emit(node_id)
		accept_event()
