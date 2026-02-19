class_name Taskbar
extends Panel
## Taskbar / dock showing open tool buttons and a system clock.
## Reacts to EventBus.tool_opened / tool_closed.

@onready var task_items: HBoxContainer = $TaskItems
@onready var clock_label: Label = $ClockLabel

# tool_name -> Button
var _task_buttons: Dictionary = {}


func _ready() -> void:
	EventBus.tool_opened.connect(_on_tool_opened)
	EventBus.tool_closed.connect(_on_tool_closed)
	_apply_theme()
	_update_clock()


func _process(_delta: float) -> void:
	_update_clock()


func _apply_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.10)
	style.border_color = Color(0.0, 0.88, 1.0)
	style.border_width_top = 1
	add_theme_stylebox_override("panel", style)

	clock_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	clock_label.text = "%02d:%02d:%02d" % [t.hour, t.minute, t.second]


func _on_tool_opened(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		return

	var btn := Button.new()
	btn.text = "[ %s ]" % p_tool_name
	btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func(): EventBus.tool_focus_requested.emit(p_tool_name))
	task_items.add_child(btn)
	_task_buttons[p_tool_name] = btn


func _on_tool_closed(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		_task_buttons[p_tool_name].queue_free()
		_task_buttons.erase(p_tool_name)
