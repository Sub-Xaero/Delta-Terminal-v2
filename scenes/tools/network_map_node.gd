class_name NetworkMapNode
extends Control
## Single node icon on the network map.
## Draws a circle whose border colour reflects security level and connection state.

signal node_clicked(node_id: String)
signal node_double_clicked(node_id: String)

const ICON_SIZE  := 56.0   # widget width; circle fills this square area
const RADIUS     := 22.0
const LABEL_H    := 18.0   # height reserved below circle for the IP label

var node_id:   String     = ""
var node_data: Dictionary = {}

var _selected:   bool = false
var _connected:  bool = false
var _hovered:    bool = false

@onready var ip_label: Label = $IPLabel


func _ready() -> void:
	mouse_entered.connect(func(): _hovered = true;  queue_redraw())
	mouse_exited.connect(func():  _hovered = false; queue_redraw())


func setup(data: Dictionary) -> void:
	node_id   = data["id"]
	node_data = data
	ip_label.text = data.get("ip", "")
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE + LABEL_H)
	queue_redraw()


func set_selected(sel: bool) -> void:
	_selected = sel
	queue_redraw()


func set_connected(active: bool) -> void:
	_connected = active
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
		draw_arc(center, RADIUS + 6.0, 0.0, TAU, 64, glow, 4.0, true)

	# Filled centre dot when connected
	if _connected:
		draw_circle(center, 5.0, border)


func _border_colour() -> Color:
	if _connected:
		return Color(0.0, 0.88, 1.0)    # cyan — active
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			node_double_clicked.emit(node_id)
		else:
			node_clicked.emit(node_id)
		accept_event()
