class_name WindowManager
extends Control
## Manages spawning, layering (z-index), dragging, and closing of tool windows.
## Lives as a child of the Desktop scene; tool windows are added as children here.

# tool_name -> ToolWindow node
var open_windows: Dictionary = {}


func _ready() -> void:
	EventBus.tool_closed.connect(_on_tool_closed)
	EventBus.tool_focus_requested.connect(focus_tool_window)


func focus_tool_window(p_tool_name: String) -> void:
	if open_windows.has(p_tool_name):
		_focus_window(open_windows[p_tool_name])


## Spawns a new tool window from a PackedScene, or focuses it if already open.
## Emits EventBus.tool_opened on success.
func spawn_tool_window(tool_scene: PackedScene, p_tool_name: String) -> ToolWindow:
	if open_windows.has(p_tool_name):
		_focus_window(open_windows[p_tool_name])
		return open_windows[p_tool_name]

	var window: ToolWindow = tool_scene.instantiate()
	window.set_tool_name(p_tool_name)
	add_child(window)

	# Cascade position so multiple windows don't stack exactly
	var screen_size := get_viewport_rect().size
	var cascade := Vector2(30.0, 30.0) * float(open_windows.size() % 8)
	window.position = (screen_size / 2.0 - window.custom_minimum_size / 2.0) + cascade

	window.window_focused.connect(_on_window_focused)

	open_windows[p_tool_name] = window
	_focus_window(window)
	EventBus.tool_opened.emit(p_tool_name)
	return window


func _focus_window(window: ToolWindow) -> void:
	if not is_instance_valid(window):
		return
	move_child(window, get_child_count() - 1)


func _on_window_focused(p_tool_name: String) -> void:
	if open_windows.has(p_tool_name):
		_focus_window(open_windows[p_tool_name])


func _on_tool_closed(p_tool_name: String) -> void:
	open_windows.erase(p_tool_name)


func get_open_tool_names() -> Array:
	return open_windows.keys()
