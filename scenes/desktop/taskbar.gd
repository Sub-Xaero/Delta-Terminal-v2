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
	_add_launch_button()
	_add_pc_button()


func _add_launch_button() -> void:
	var btn := Button.new()
	btn.text = "[ LAUNCH ]"
	_style_button(btn, Color(1.0, 0.08, 0.55))
	btn.pressed.connect(func():
		EventBus.context_menu_requested.emit(btn.global_position + Vector2(0.0, -4.0))
	)
	task_items.add_child(btn)
	# Separator to visually divide launch button from tool buttons
	var sep := VSeparator.new()
	task_items.add_child(sep)


func _style_button(btn: Button, color: Color) -> void:
	btn.add_theme_color_override("font_color", color)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.04, 0.03, 0.10)
	n.border_color = Color(color.r, color.g, color.b, 0.5)
	n.set_border_width_all(1)
	n.set_content_margin_all(4.0)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.0, 0.1, 0.15)
	h.border_color = color
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   n)


func _add_pc_button() -> void:
	var btn := Button.new()
	btn.text = "[ PC ]"
	_style_button(btn, Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func(): EventBus.open_tool_requested.emit("Hardware Viewer"))
	task_items.add_child(btn)

	var sep := VSeparator.new()
	task_items.add_child(sep)


func _process(_delta: float) -> void:
	_update_clock()


func _apply_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.10)
	style.border_color = Color(0.0, 0.88, 1.0)
	style.border_width_top = 1
	style.shadow_color = Color(0.0, 0.88, 1.0, 0.25)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)

	clock_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	clock_label.text = "[ %02d:%02d:%02d ]" % [t.hour, t.minute, t.second]


func _on_tool_opened(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		return

	var btn := Button.new()
	btn.text = "[ %s ]" % p_tool_name
	_style_button(btn, Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func(): EventBus.tool_focus_requested.emit(p_tool_name))
	task_items.add_child(btn)
	_task_buttons[p_tool_name] = btn


func _on_tool_closed(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		_task_buttons[p_tool_name].queue_free()
		_task_buttons.erase(p_tool_name)
