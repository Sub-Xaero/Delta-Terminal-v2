class_name SidebarMinimap
extends Control
## Miniature network map drawn in the sidebar.
## Click to open / focus the full Network Map tool window.

const _PAD         := 12.0
const _NODE_RADIUS := 4.0

var connected_id: String = ""
var bounce_chain: Array  = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _draw() -> void:
	if NetworkSim.nodes.is_empty():
		return

	# Collect map-space positions
	var positions: Array[Vector2] = []
	for id in NetworkSim.nodes:
		positions.append(NetworkSim.nodes[id].get("map_position", Vector2.ZERO))

	# Bounding box
	var bmin := positions[0]
	var bmax := positions[0]
	for p in positions:
		bmin.x = minf(bmin.x, p.x)
		bmin.y = minf(bmin.y, p.y)
		bmax.x = maxf(bmax.x, p.x)
		bmax.y = maxf(bmax.y, p.y)

	var map_size := bmax - bmin
	var draw_area := size - Vector2(_PAD * 2.0, _PAD * 2.0)
	var scale_x := draw_area.x / maxf(map_size.x, 1.0)
	var scale_y := draw_area.y / maxf(map_size.y, 1.0)
	var sc := minf(scale_x, scale_y)  # uniform scale

	# Draw edges first
	for node_id in NetworkSim.nodes:
		var data: Dictionary = NetworkSim.nodes[node_id]
		var from_px := _to_px(data.get("map_position", Vector2.ZERO), bmin, sc)

		for target_id in data.get("connections", []):
			if not NetworkSim.nodes.has(target_id):
				continue
			var to_px := _to_px(
				NetworkSim.nodes[target_id].get("map_position", Vector2.ZERO), bmin, sc
			)
			var lit: bool = (node_id in bounce_chain and target_id in bounce_chain) \
					or node_id == connected_id or target_id == connected_id
			draw_line(from_px, to_px, Color(0.0, 0.88, 1.0, 0.85 if lit else 0.18), 1.0, true)

	# Draw nodes on top of edges
	for node_id in NetworkSim.nodes:
		var data: Dictionary = NetworkSim.nodes[node_id]
		var pt := _to_px(data.get("map_position", Vector2.ZERO), bmin, sc)
		draw_circle(pt, _NODE_RADIUS, _node_color(data, node_id))


func _to_px(map_pos: Vector2, bmin: Vector2, sc: float) -> Vector2:
	return (map_pos - bmin) * sc + Vector2(_PAD, _PAD)


func _node_color(data: Dictionary, node_id: String) -> Color:
	if node_id == connected_id:
		return Color(0.0, 0.88, 1.0)
	var sec: int = data.get("security", 1)
	if sec == 0:
		return Color(0.35, 0.35, 0.45)
	if sec <= 2:
		return Color(0.0, 0.88, 1.0)
	if sec <= 4:
		return Color(1.0, 0.75, 0.0)
	return Color(1.0, 0.08, 0.55)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			EventBus.open_tool_requested.emit("Network Map")
			accept_event()
