class_name Desktop
extends Control
## Root desktop scene — the in-game OS shell.
## Hosts the WindowManager, Taskbar, and right-click context menu.

const SystemLogScene          := preload("res://scenes/tools/system_log.tscn")
const NetworkMapScene         := preload("res://scenes/tools/network_map.tscn")
const PasswordCrackerScene    := preload("res://scenes/tools/password_cracker.tscn")
const FirewallBypasserScene   := preload("res://scenes/tools/firewall_bypasser.tscn")
const PortScannerScene        := preload("res://scenes/tools/port_scanner.tscn")
const MissionLogScene         := preload("res://scenes/tools/mission_log.tscn")
const FileBrowserScene        := preload("res://scenes/tools/file_browser.tscn")
const EncryptionBreakerScene  := preload("res://scenes/tools/encryption_breaker.tscn")
const HardwareViewerScene     := preload("res://scenes/tools/hardware_viewer.tscn")
const CredentialManagerScene  := preload("res://scenes/tools/credential_manager.tscn")
const LogDeleterScene         := preload("res://scenes/tools/log_deleter.tscn")
const CommsClientScene        := preload("res://scenes/tools/comms_client.tscn")
const PlayerProfileScene      := preload("res://scenes/tools/player_profile.tscn")

# ── Tools-as-files gate ──────────────────────────────────────────────────────
# Maps tool names to the executable file the player must possess in local_storage.
# Tools NOT listed here are always available (ungated).
const TOOL_EXE_REQUIREMENTS: Dictionary = {
	"Password Cracker": "password_cracker.exe",
	"Port Scanner": "port_scanner.exe",
	"Firewall Bypasser": "firewall_bypass.exe",
	"Encryption Breaker": "encryption_breaker.exe",
	"Log Deleter": "log_deleter.exe",
	"Exploit Installer": "exploit_installer.exe",
	"Credential Manager": "credential_manager.exe",
}

@onready var window_manager: WindowManager = $WindowLayer
@onready var context_menu: PopupMenu = $ContextMenu
@onready var _crt_bg: ColorRect = $Background
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	GameManager.transition_to(GameManager.State.DESKTOP)
	EventBus.context_menu_requested.connect(_show_context_menu)
	EventBus.open_tool_requested.connect(_on_open_tool_requested)
	EventBus.system_nuke_triggered.connect(_on_system_nuke)
	EventBus.pause_requested.connect(_pause_menu.toggle)
	SettingsManager.settings_changed.connect(_apply_crt_settings)
	_apply_crt_settings()
	window_manager.spawn_tool_window(SystemLogScene, "System Log")


func _apply_crt_settings() -> void:
	_crt_bg.visible  = SettingsManager.crt_enabled
	_crt_bg.modulate = Color(1.0, 1.0, 1.0, SettingsManager.crt_intensity)


func _setup_context_menu() -> void:
	context_menu.clear()
	context_menu.add_item("Network Map", 0)
	context_menu.add_separator()
	if _has_exe("Port Scanner"):
		context_menu.add_item("Port Scanner", 5)
	if _has_exe("Password Cracker"):
		context_menu.add_item("Password Cracker", 1)
	if _has_exe("Firewall Bypasser"):
		context_menu.add_item("Firewall Bypasser", 9)
	if _has_exe("Encryption Breaker"):
		context_menu.add_item("Encryption Breaker", 10)
	if _has_exe("Log Deleter"):
		context_menu.add_item("Log Deleter", 14)
	context_menu.add_item("File Browser", 7)
	if _has_exe("Credential Manager"):
		context_menu.add_item("Credential Manager", 13)
	context_menu.add_separator()
	context_menu.add_item("Mission Log", 6)
	context_menu.add_separator()
	context_menu.add_item("System Log", 3)
	context_menu.add_item("System Info", 4)
	context_menu.add_item("Hardware Viewer", 11)
	context_menu.add_item("Comms Client", 15)
	context_menu.add_item("Player Profile", 16)
	context_menu.add_separator()
	context_menu.add_item("Save Game", 12)
	if not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel"):
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _show_context_menu(at_position: Vector2) -> void:
	_setup_context_menu()
	context_menu.position = Vector2i(at_position)
	context_menu.popup()


func _has_exe(tool_name: String) -> bool:
	if tool_name not in TOOL_EXE_REQUIREMENTS:
		return true  # ungated tool
	var required: String = TOOL_EXE_REQUIREMENTS[tool_name]
	return required in GameManager.player_data.get("local_storage", [])


func _on_open_tool_requested(tool_name: String) -> void:
	match tool_name:
		"Network Map":
			if window_manager.open_windows.has("Network Map"):
				var w: ToolWindow = window_manager.open_windows["Network Map"]
				EventBus.tool_closed.emit("Network Map")
				w.queue_free()
			else:
				window_manager.spawn_tool_window(NetworkMapScene, "Network Map")
		"Hardware Viewer":
			window_manager.spawn_tool_window(HardwareViewerScene, "Hardware Viewer")


func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			window_manager.spawn_tool_window(NetworkMapScene, "Network Map")
		1:
			if not _has_exe("Password Cracker"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Password Cracker"], "error")
				return
			window_manager.spawn_tool_window(PasswordCrackerScene, "Password Cracker")
		3:
			window_manager.spawn_tool_window(SystemLogScene, "System Log")
		5:
			if not _has_exe("Port Scanner"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Port Scanner"], "error")
				return
			window_manager.spawn_tool_window(PortScannerScene, "Port Scanner")
		6:
			window_manager.spawn_tool_window(MissionLogScene, "Mission Log")
		7:
			window_manager.spawn_tool_window(FileBrowserScene, "File Browser")
		9:
			if not _has_exe("Firewall Bypasser"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Firewall Bypasser"], "error")
				return
			window_manager.spawn_tool_window(FirewallBypasserScene, "Firewall Bypasser")
		10:
			if not _has_exe("Encryption Breaker"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Encryption Breaker"], "error")
				return
			window_manager.spawn_tool_window(EncryptionBreakerScene, "Encryption Breaker")
		11:
			window_manager.spawn_tool_window(HardwareViewerScene, "Hardware Viewer")
		13:
			if not _has_exe("Credential Manager"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Credential Manager"], "error")
				return
			window_manager.spawn_tool_window(CredentialManagerScene, "Credential Manager")
		14:
			if not _has_exe("Log Deleter"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Log Deleter"], "error")
				return
			window_manager.spawn_tool_window(LogDeleterScene, "Log Deleter")
		15:
			window_manager.spawn_tool_window(CommsClientScene, "Comms Client")
		16:
			window_manager.spawn_tool_window(PlayerProfileScene, "Player Profile")
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
		12:
			SaveManager.save_game()


func _on_system_nuke() -> void:
	var to_close: Array = window_manager.open_windows.keys().duplicate()
	for tool_name: String in to_close:
		if tool_name in ["System Log"]:
			continue
		EventBus.tool_closed.emit(tool_name)
		if window_manager.open_windows.has(tool_name):
			window_manager.open_windows[tool_name].queue_free()
