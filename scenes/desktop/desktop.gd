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
const SoftwareShopScene       := preload("res://scenes/tools/software_shop.tscn")
const BankTerminalScene       := preload("res://scenes/tools/bank_terminal.tscn")
const FactionJobBoardScene    := preload("res://scenes/tools/faction_job_board.tscn")
const NodeDirectoryScene      := preload("res://scenes/tools/node_directory.tscn")
const SystemLinksScene        := preload("res://scenes/tools/system_links.tscn")
const RecordEditorScene       := preload("res://scenes/tools/record_editor.tscn")
const StockTerminalScene      := preload("res://scenes/tools/stock_terminal.tscn")
const LanConsoleScene         := preload("res://scenes/tools/lan_console.tscn")
const DictionaryHackerScene   := preload("res://scenes/tools/dictionary_hacker.tscn")
const VoiceAnalyserScene      := preload("res://scenes/tools/voice_analyser.tscn")
const VoiceCommsScene         := preload("res://scenes/tools/voice_comms.tscn")

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
	"Record Editor": "record_editor.exe",
	"Stock Terminal": "stock_terminal.exe",
	"Dictionary Hacker": "dictionary_hacker.exe",
	"Voice Analyser": "voice_analyser.exe",
	"Voice Comms": "voice_comms.exe",
}

@onready var window_manager: WindowManager = $WindowLayer
@onready var context_menu: PopupMenu = $ContextMenu
@onready var _crt_bg: ColorRect = $Background
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _desktop_icons_layer: Control = $DesktopIconsLayer


func _ready() -> void:
	GameManager.transition_to(GameManager.State.DESKTOP)
	EventBus.context_menu_requested.connect(_show_context_menu)
	EventBus.open_tool_requested.connect(_on_open_tool_requested)
	EventBus.system_nuke_triggered.connect(_on_system_nuke)
	EventBus.pause_requested.connect(_pause_menu.toggle)
	EventBus.network_connected.connect(_on_node_connected)
	EventBus.network_disconnected.connect(_on_node_disconnected)
	SettingsManager.settings_changed.connect(_apply_crt_settings)
	_apply_crt_settings()
	window_manager.spawn_tool_window(SystemLogScene, "System Log")


func _apply_crt_settings() -> void:
	_crt_bg.visible  = SettingsManager.crt_enabled
	_crt_bg.modulate = Color(1.0, 1.0, 1.0, SettingsManager.crt_intensity)


func _setup_context_menu() -> void:
	context_menu.clear()
	context_menu.add_item("System Info", 4)
	context_menu.add_separator()
	context_menu.add_item("Save Game", 12)
	context_menu.add_separator()
	context_menu.add_item("Dictionary Hacker", 17)
	context_menu.add_item("Voice Analyser", 18)
	context_menu.add_item("Voice Comms", 19)
	if not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			AudioManager.toggle_mute()
			get_viewport().set_input_as_handled()
			return
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


func _toggle_tool(scene: PackedScene, tool_name: String) -> void:
	if window_manager.open_windows.has(tool_name):
		var w: ToolWindow = window_manager.open_windows[tool_name]
		EventBus.tool_closed.emit(tool_name)
		w.queue_free()
	else:
		window_manager.spawn_tool_window(scene, tool_name)


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
		"Password Cracker":
			window_manager.spawn_tool_window(PasswordCrackerScene, "Password Cracker")
		"Port Scanner":
			window_manager.spawn_tool_window(PortScannerScene, "Port Scanner")
		"Firewall Bypasser":
			window_manager.spawn_tool_window(FirewallBypasserScene, "Firewall Bypasser")
		"Encryption Breaker":
			window_manager.spawn_tool_window(EncryptionBreakerScene, "Encryption Breaker")
		"Log Deleter":
			window_manager.spawn_tool_window(LogDeleterScene, "Log Deleter")
		"Credential Manager":
			window_manager.spawn_tool_window(CredentialManagerScene, "Credential Manager")
		"File Browser":
			window_manager.spawn_tool_window(FileBrowserScene, "File Browser")
		"Mission Log":
			window_manager.spawn_tool_window(MissionLogScene, "Mission Log")
		"System Log":
			window_manager.spawn_tool_window(SystemLogScene, "System Log")
		"Hardware Viewer":
			_toggle_tool(HardwareViewerScene, "Hardware Viewer")
		"Comms Client":
			_toggle_tool(CommsClientScene, "Comms Client")
		"Player Profile":
			_toggle_tool(PlayerProfileScene, "Player Profile")
		"Bank Terminal":
			window_manager.spawn_tool_window(BankTerminalScene, "Bank Terminal")
		"Faction Job Board":
			window_manager.spawn_tool_window(FactionJobBoardScene, "Faction Job Board")
		"Node Directory":
			window_manager.spawn_tool_window(NodeDirectoryScene, "Node Directory")
		"System Links":
			window_manager.spawn_tool_window(SystemLinksScene, "System Links")
		"Record Editor":
			if not _has_exe("Record Editor"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Record Editor"], "error")
				return
			window_manager.spawn_tool_window(RecordEditorScene, "Record Editor")
		"Stock Terminal":
			if not _has_exe("Stock Terminal"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Stock Terminal"], "error")
				return
			window_manager.spawn_tool_window(StockTerminalScene, "Stock Terminal")
		"LAN Console":
			window_manager.spawn_tool_window(LanConsoleScene, "LAN Console")
		"Dictionary Hacker":
			if not _has_exe("Dictionary Hacker"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Dictionary Hacker"], "error")
				return
			window_manager.spawn_tool_window(DictionaryHackerScene, "Dictionary Hacker")
		"Voice Analyser":
			if not _has_exe("Voice Analyser"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Voice Analyser"], "error")
				return
			window_manager.spawn_tool_window(VoiceAnalyserScene, "Voice Analyser")
		"Voice Comms":
			if not _has_exe("Voice Comms"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Voice Comms"], "error")
				return
			window_manager.spawn_tool_window(VoiceCommsScene, "Voice Comms")


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
		17:
			if not _has_exe("Dictionary Hacker"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Dictionary Hacker"], "error")
				return
			window_manager.spawn_tool_window(DictionaryHackerScene, "Dictionary Hacker")
		18:
			if not _has_exe("Voice Analyser"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Voice Analyser"], "error")
				return
			window_manager.spawn_tool_window(VoiceAnalyserScene, "Voice Analyser")
		19:
			if not _has_exe("Voice Comms"):
				EventBus.log_message.emit("Missing executable: %s" % TOOL_EXE_REQUIREMENTS["Voice Comms"], "error")
				return
			window_manager.spawn_tool_window(VoiceCommsScene, "Voice Comms")


# ── Desktop service icons ─────────────────────────────────────────────────────

func _on_node_connected(_node_id: String) -> void:
	_refresh_desktop_icons()


func _on_node_disconnected() -> void:
	_refresh_desktop_icons()


func _refresh_desktop_icons() -> void:
	for child in _desktop_icons_layer.get_children():
		child.queue_free()
	if not NetworkSim.is_connected:
		return
	var node: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	var services: Array  = node.get("services", [])
	var container := HBoxContainer.new()
	container.position = Vector2(12, 62)
	container.add_theme_constant_override("separation", 8)
	if "marketplace" in services:
		container.add_child(_create_desktop_icon(
			"SOFTWARE\nSHOP",
			func() -> void: window_manager.spawn_tool_window(SoftwareShopScene, "Software Shop")
		))
	if "banking" in services:
		container.add_child(_create_desktop_icon(
			"BANK\nTERMINAL",
			func() -> void: window_manager.spawn_tool_window(BankTerminalScene, "Bank Terminal")
		))
	if "job_board" in services:
		container.add_child(_create_desktop_icon(
			"JOB\nBOARD",
			func() -> void: window_manager.spawn_tool_window(FactionJobBoardScene, "Faction Job Board")
		))
	if "node_directory" in services:
		container.add_child(_create_desktop_icon(
			"NODE\nDIRECTORY",
			func() -> void: window_manager.spawn_tool_window(NodeDirectoryScene, "Node Directory")
		))
	if "database" in services and NetworkSim.connected_node_id in NetworkSim.cracked_nodes:
		container.add_child(_create_desktop_icon(
			"RECORD\nEDITOR",
			func() -> void: window_manager.spawn_tool_window(RecordEditorScene, "Record Editor")
		))
	var lan_nodes_data: Array = node.get("lan_nodes", [])
	if not lan_nodes_data.is_empty() and NetworkSim.connected_node_id in NetworkSim.cracked_nodes:
		container.add_child(_create_desktop_icon(
			"LAN\nCONSOLE",
			func() -> void: window_manager.spawn_tool_window(LanConsoleScene, "LAN Console")
		))
	if container.get_child_count() > 0:
		_desktop_icons_layer.add_child(container)


func _create_desktop_icon(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(84, 72)
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.04, 0.03, 0.12, 0.88)
	sn.border_color = Color(0.0, 0.88, 1.0, 0.55)
	sn.set_border_width_all(1)
	sn.corner_radius_top_right   = 8
	sn.corner_radius_bottom_left = 8
	sn.corner_detail = 1
	sn.content_margin_top    = 8
	sn.content_margin_bottom = 8
	sn.content_margin_left   = 6
	sn.content_margin_right  = 6
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color    = Color(0.08, 0.06, 0.18, 0.95)
	sh.border_color = Color(0.0, 0.88, 1.0)
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate() as StyleBoxFlat
	sp.bg_color    = Color(0.0, 0.12, 0.2)
	sp.border_color = Color(0.0, 0.88, 1.0)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.4, 0.95, 1.0))
	btn.pressed.connect(callback)
	return btn


func _on_system_nuke() -> void:
	var to_close: Array = window_manager.open_windows.keys().duplicate()
	for tool_name: String in to_close:
		if tool_name in ["System Log"]:
			continue
		EventBus.tool_closed.emit(tool_name)
		if window_manager.open_windows.has(tool_name):
			window_manager.open_windows[tool_name].queue_free()
