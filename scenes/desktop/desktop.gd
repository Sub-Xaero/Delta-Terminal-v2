class_name Desktop
extends Control
## Root desktop scene — the in-game OS shell.
## Hosts the WindowManager, Taskbar, and right-click context menu.

const SystemLogScene := preload("res://scenes/tools/system_log.tscn")

@onready var window_manager: WindowManager = $WindowLayer
@onready var context_menu: PopupMenu = $ContextMenu


func _ready() -> void:
	GameManager.transition_to(GameManager.State.DESKTOP)
	_setup_context_menu()
	window_manager.spawn_tool_window(SystemLogScene, "System Log")


func _setup_context_menu() -> void:
	context_menu.clear()
	# Stubs — populate with real tool scenes as they are built
	context_menu.add_item("Network Map", 0)
	context_menu.add_separator()
	context_menu.add_item("System Log", 1)
	context_menu.add_item("System Info", 2)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			context_menu.position = Vector2i(get_global_mouse_position())
			context_menu.popup()
			get_viewport().set_input_as_handled()


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			# TODO: load network map scene
			EventBus.log_message.emit("Network Map: not yet implemented", "info")
		1:
			window_manager.spawn_tool_window(SystemLogScene, "System Log")
		2:
			var handle: String = GameManager.player_data.get("handle", "ghost")
			EventBus.log_message.emit(
				"DeltaTerminal v2 — handle: %s  credits: %d  rating: %d" % [
					handle,
					GameManager.player_data.get("credits", 0),
					GameManager.player_data.get("rating", 1),
				],
				"info"
			)
