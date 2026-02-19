class_name ToolWindow
extends Control
## Base draggable tool window. Instantiate this scene (or a scene inheriting it)
## via WindowManager.spawn_tool_window(). Never add directly to the scene tree.

signal window_closed(tool_name: String)
signal window_focused(tool_name: String)

@export var tool_name: String = "Tool"

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@onready var title_bar: Panel = $TitleBar
@onready var title_label: Label = $TitleBar/TitleLabel
@onready var close_button: Button = $TitleBar/CloseButton
@onready var content_area: Control = $ContentArea


func _ready() -> void:
	title_label.text = tool_name
	close_button.pressed.connect(_on_close_pressed)
	title_bar.gui_input.connect(_on_title_bar_input)
	gui_input.connect(_on_self_input)
	_apply_theme()


func _apply_theme() -> void:
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.04, 0.12, 0.04)
	title_style.border_color = Color(0.0, 0.8, 0.3)
	title_style.set_border_width_all(1)
	title_bar.add_theme_stylebox_override("panel", title_style)

	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.02, 0.06, 0.02, 0.95)
	window_style.border_color = Color(0.0, 0.8, 0.3)
	window_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", window_style)

	title_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
	close_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _on_self_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		window_focused.emit(tool_name)


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				window_focused.emit(tool_name)
			else:
				_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_screen()
		get_viewport().set_input_as_handled()


func _clamp_to_screen() -> void:
	var screen_size := get_viewport_rect().size
	global_position.x = clamp(global_position.x, 0.0, screen_size.x - size.x)
	global_position.y = clamp(global_position.y, 0.0, screen_size.y - size.y)


func set_tool_name(name: String) -> void:
	tool_name = name
	if is_node_ready() and title_label:
		title_label.text = name


func _on_close_pressed() -> void:
	window_closed.emit(tool_name)
	EventBus.tool_closed.emit(tool_name)
	queue_free()
