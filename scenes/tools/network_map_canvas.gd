class_name NetworkMapCanvas
extends Control
## Draws connection edges between network nodes.
## Node widgets are added as children and positioned by NetworkMap.

var _edges: Array = []  # Array of { from:Vector2, to:Vector2, color:Color, width:float }


func update_edges(edges: Array) -> void:
	_edges = edges
	queue_redraw()


func _draw() -> void:
	for edge in _edges:
		draw_line(edge.from, edge.to, edge.color, edge.width, true)
