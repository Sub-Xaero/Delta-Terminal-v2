class_name Taskbar
extends Panel
## Taskbar / dock showing open tool buttons and a system clock.
## Reacts to EventBus.tool_opened / tool_closed.

# Gated tools — only shown when the player has the exe in local_storage.
const _GATED_TOOLS: Array = [
	{"name": "Password Cracker",   "exe": "password_cracker.exe"},
	{"name": "Port Scanner",       "exe": "port_scanner.exe"},
	{"name": "Firewall Bypasser",  "exe": "firewall_bypass.exe"},
	{"name": "Encryption Breaker", "exe": "encryption_breaker.exe"},
	{"name": "Log Deleter",        "exe": "log_deleter.exe"},
	{"name": "Credential Manager", "exe": "credential_manager.exe"},
]
# Always-available tools (no exe required).
const _FREE_TOOLS: Array = [
	"Network Map",
	"File Browser",
	"Mission Log",
	"System Log",
]
# Pinned tools — have dedicated taskbar buttons; excluded from TOOLS menu and dynamic buttons.
const _PINNED_TOOLS: Array = ["Hardware Viewer", "Comms Client", "Player Profile"]

@onready var task_items: HBoxContainer = $TaskItems
@onready var clock_label: Label = $ClockLabel

# tool_name -> Button
var _task_buttons: Dictionary = {}
var _tools_menu: PopupMenu = null
var _tools_btn: Button = null


func _ready() -> void:
	EventBus.tool_opened.connect(_on_tool_opened)
	EventBus.tool_closed.connect(_on_tool_closed)
	_apply_theme()
	_update_clock()
	_add_tools_button()
	_add_pinned_button("[ PC ]",      "Hardware Viewer", Color(0.0, 0.88, 1.0))
	_add_pinned_button("[ COMMS ]",   "Comms Client",    Color(0.0, 0.88, 1.0))
	_add_pinned_button("[ PROFILE ]", "Player Profile",  Color(0.0, 0.88, 1.0))


func _add_tools_button() -> void:
	_tools_btn = Button.new()
	_tools_btn.text = "[ TOOLS ]"
	_style_button(_tools_btn, Color(1.0, 0.08, 0.55))

	_tools_menu = PopupMenu.new()
	_tools_btn.add_child(_tools_menu)
	_tools_menu.id_pressed.connect(_on_tools_menu_id_pressed)

	_tools_btn.pressed.connect(_open_tools_menu)
	task_items.add_child(_tools_btn)

	var sep := VSeparator.new()
	task_items.add_child(sep)


func _open_tools_menu() -> void:
	_tools_menu.clear()
	var storage: Array = GameManager.player_data.get("local_storage", [])
	var idx: int = 0
	for tool: Dictionary in _GATED_TOOLS:
		if tool["exe"] in storage:
			_tools_menu.add_item(tool["name"], idx)
		idx += 1
	if _tools_menu.item_count > 0:
		_tools_menu.add_separator()
	for tool_name: String in _FREE_TOOLS:
		_tools_menu.add_item(tool_name, idx)
		idx += 1
	_tools_menu.reset_size()
	var pos := _tools_btn.global_position
	pos.y -= _tools_menu.size.y
	_tools_menu.position = Vector2i(pos)
	_tools_menu.popup()


func _on_tools_menu_id_pressed(id: int) -> void:
	# Resolve id back to tool name
	var all_tools: Array = []
	for tool: Dictionary in _GATED_TOOLS:
		all_tools.append(tool["name"])
	for tool_name: String in _FREE_TOOLS:
		all_tools.append(tool_name)
	if id < all_tools.size():
		EventBus.open_tool_requested.emit(all_tools[id])


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


func _add_pinned_button(label: String, tool_name: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = label
	_style_button(btn, color)
	btn.pressed.connect(func(): EventBus.open_tool_requested.emit(tool_name))
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
	clock_label.mouse_filter = Control.MOUSE_FILTER_STOP
	clock_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clock_label.gui_input.connect(_on_clock_gui_input)


func _on_clock_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		EventBus.pause_requested.emit()


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	clock_label.text = "[ %02d:%02d:%02d ]" % [t.hour, t.minute, t.second]


func _on_tool_opened(p_tool_name: String) -> void:
	if p_tool_name in _PINNED_TOOLS:
		return
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
