class_name Desktop
extends Control
## Root desktop scene — the in-game OS shell.
## Hosts the WindowManager, Taskbar, and right-click context menu.

const SystemLogScene       := preload("res://scenes/tools/system_log.tscn")
const NetworkMapScene      := preload("res://scenes/tools/network_map.tscn")
const PasswordCrackerScene := preload("res://scenes/tools/password_cracker.tscn")
const PortScannerScene     := preload("res://scenes/tools/port_scanner.tscn")
const TraceTrackerScene    := preload("res://scenes/tools/trace_tracker.tscn")
const MissionLogScene      := preload("res://scenes/tools/mission_log.tscn")

@onready var window_manager: WindowManager = $WindowLayer
@onready var context_menu: PopupMenu = $ContextMenu


func _ready() -> void:
	GameManager.transition_to(GameManager.State.DESKTOP)
	_setup_context_menu()
	EventBus.context_menu_requested.connect(_show_context_menu)
	window_manager.spawn_tool_window(SystemLogScene, "System Log")
	window_manager.spawn_tool_window(TraceTrackerScene, "Trace Tracker")


func _setup_context_menu() -> void:
	context_menu.clear()
	# Stubs — populate with real tool scenes as they are built
	context_menu.add_item("Network Map", 0)
	context_menu.add_separator()
	context_menu.add_item("Port Scanner", 5)
	context_menu.add_item("Password Cracker", 1)
	context_menu.add_item("Trace Tracker", 2)
	context_menu.add_separator()
	context_menu.add_item("Mission Log", 6)
	context_menu.add_separator()
	context_menu.add_item("System Log", 3)
	context_menu.add_item("System Info", 4)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _show_context_menu(at_position: Vector2) -> void:
	context_menu.position = Vector2i(at_position)
	context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			window_manager.spawn_tool_window(NetworkMapScene, "Network Map")
		1:
			window_manager.spawn_tool_window(PasswordCrackerScene, "Password Cracker")
		2:
			window_manager.spawn_tool_window(TraceTrackerScene, "Trace Tracker")
		3:
			window_manager.spawn_tool_window(SystemLogScene, "System Log")
		5:
			window_manager.spawn_tool_window(PortScannerScene, "Port Scanner")
		6:
			window_manager.spawn_tool_window(MissionLogScene, "Mission Log")
		4:
			var handle: String = GameManager.player_data.get("handle", "ghost")
			EventBus.log_message.emit(
				"DeltaTerminal v2 — handle: %s  credits: %d  rating: %d" % [
					handle,
					GameManager.player_data.get("credits", 0),
					GameManager.player_data.get("rating", 1),
				],
				"info"
			)
