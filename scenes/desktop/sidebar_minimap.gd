class_name SidebarMinimap
extends Control
## Miniature network map drawn in the sidebar.
## Mirrors network_map.gd behaviour: only discovered nodes shown, only route edges drawn.
## Click to open / focus the full Network Map tool window.

const _PAD         := 8.0
const _NODE_RADIUS := 3.0

var connected_id: String = ""
var bounce_chain: Array  = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _draw() -> void:
	var discovered: Array = NetworkSim.discovered_nodes
	if discovered.is_empty():
		return

	# Collect positions for discovered nodes only (drives bounding box)
	var positions: Array[Vector2] = []
	for id: String in discovered:
		if NetworkSim.nodes.has(id):
			positions.append(NetworkSim.nodes[id].get("map_position", Vector2.ZERO))

	if positions.is_empty():
		return

	# Bounding box
	var bmin := positions[0]
	var bmax := positions[0]
	for p: Vector2 in positions:
		bmin.x = minf(bmin.x, p.x)
		bmin.y = minf(bmin.y, p.y)
		bmax.x = maxf(bmax.x, p.x)
		bmax.y = maxf(bmax.y, p.y)

	var map_size  := bmax - bmin
	var draw_area := size - Vector2(_PAD * 2.0, _PAD * 2.0)
	var scale_x   := draw_area.x / maxf(map_size.x, 1.0)
	var scale_y   := draw_area.y / maxf(map_size.y, 1.0)
	var sc        := minf(scale_x, scale_y)  # uniform scale

	# Build route path and draw edges
	var local_id := _find_local_node_id()
	var path: Array[String] = []
	if local_id != "":
		path.append(local_id)
	path.append_array(bounce_chain)
	if connected_id != "":
		path.append(connected_id)

	var active := connected_id != ""
	var edge_col := Color(0.0, 0.88, 1.0, 0.75) if active else Color(1.0, 0.75, 0.0, 0.55)

	for i in range(path.size() - 1):
		var from_id: String = path[i]
		var to_id:   String = path[i + 1]
		if not (NetworkSim.nodes.has(from_id) and NetworkSim.nodes.has(to_id)):
			continue
		draw_line(
			_to_px(NetworkSim.nodes[from_id].get("map_position", Vector2.ZERO), bmin, sc),
			_to_px(NetworkSim.nodes[to_id].get("map_position", Vector2.ZERO), bmin, sc),
			edge_col, 1.0, true
		)

	# Draw discovered nodes on top of edges
	for id: String in discovered:
		if not NetworkSim.nodes.has(id):
			continue
		var data: Dictionary = NetworkSim.nodes[id]
		var pt := _to_px(data.get("map_position", Vector2.ZERO), bmin, sc)
		draw_circle(pt, _NODE_RADIUS, _node_color(data, id))


func _find_local_node_id() -> String:
	for id in NetworkSim.nodes:
		if NetworkSim.nodes[id].get("security", -1) == 0:
			return id
	return ""


func _to_px(map_pos: Vector2, bmin: Vector2, sc: float) -> Vector2:
	return (map_pos - bmin) * sc + Vector2(_PAD, _PAD)


func _node_color(data: Dictionary, node_id: String) -> Color:
	if node_id == connected_id:
		return Color(0.0, 0.88, 1.0)          # cyan — active connection
	if node_id in bounce_chain:
		return Color(1.0, 0.75, 0.0)          # amber — in bounce chain
	var sec: int = data.get("security", 1)
	if sec == 0:
		return Color(0.35, 0.35, 0.45)        # grey — own machine
	if sec <= 2:
		return Color(0.0, 0.88, 1.0)          # cyan — low security
	if sec <= 4:
		return Color(1.0, 0.75, 0.0)          # amber — medium security
	return Color(1.0, 0.08, 0.55)             # hot pink — high / critical


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			EventBus.open_tool_requested.emit("Network Map")
			accept_event()
