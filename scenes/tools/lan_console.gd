class_name LanConsole
extends ToolWindow
## LAN sub-network console. Available when connected to a node with lan_nodes.

@onready var _content: Control = $ContentArea

var _output: RichTextLabel = null
var _input: LineEdit = null
var _current_lan_node: Dictionary = {}
var _lan_nodes: Array = []


func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_from_connection()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.custom_minimum_size = Vector2(0, 200)
	_output.add_theme_color_override("default_color", Color(0.65, 0.7, 0.75))
	_output.add_theme_font_size_override("normal_font_size", 11)
	scroll.add_child(_output)
	vbox.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var prompt := Label.new()
	prompt.text = "> "
	prompt.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	prompt.add_theme_font_size_override("font_size", 11)
	hbox.add_child(prompt)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "enter command..."
	_input.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_input.add_theme_font_size_override("font_size", 11)
	_input.text_submitted.connect(_on_command_submitted)
	hbox.add_child(_input)
	vbox.add_child(hbox)

	_content.add_child(vbox)


func _refresh_from_connection() -> void:
	if not NetworkSim.is_connected:
		_print_line("[color=#ff1580]NOT CONNECTED[/color]")
		return
	var node: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	_lan_nodes = node.get("lan_nodes", [])
	if _lan_nodes.is_empty():
		_print_line("[color=#ffbf00]No LAN sub-network on this node.[/color]")
		return
	if NetworkSim.connected_node_id not in NetworkSim.cracked_nodes:
		_print_line("[color=#ff1580]ACCESS DENIED — crack this node first.[/color]")
		return
	_print_line("[color=#00e1ff]LAN CONSOLE — %s[/color]" % node.get("name", "UNKNOWN").to_upper())
	_print_line("Type [color=#00e1ff]ls[/color] to list sub-nodes. Type [color=#00e1ff]help[/color] for commands.")
	_current_lan_node = {}


func _on_command_submitted(text: String) -> void:
	var cmd: String = text.strip_edges()
	_input.clear()
	if cmd.is_empty():
		return
	_print_line("[color=#00e1ff]>[/color] " + cmd)
	EventBus.log_message.emit("[LAN] " + cmd, "info")
	_handle_command(cmd.to_lower())


func _handle_command(cmd: String) -> void:
	var parts: Array = cmd.split(" ", false)
	if parts.is_empty():
		return
	match parts[0]:
		"help":
			_print_line("Commands: [color=#00e1ff]ls[/color]  [color=#00e1ff]connect <ip>[/color]  [color=#00e1ff]scan <ip>[/color]  [color=#00e1ff]logout[/color]  [color=#00e1ff]disable_trace[/color]")
		"ls":
			_cmd_ls()
		"connect":
			_cmd_connect(parts.slice(1))
		"scan":
			_cmd_scan(parts.slice(1))
		"logout":
			_current_lan_node = {}
			_print_line("[color=#ffbf00]Logged out of LAN node.[/color]")
		"disable_trace":
			_cmd_disable_trace()
		_:
			_print_line("[color=#ff1580]Unknown command: %s[/color]" % parts[0])


func _cmd_ls() -> void:
	if _lan_nodes.is_empty():
		_print_line("[color=#ffbf00]No LAN nodes available.[/color]")
		return
	_print_line("[color=#ffbf00]LAN NODES:[/color]")
	for ln: Dictionary in _lan_nodes:
		_print_line("  [color=#00e1ff]%s[/color]  —  %s" % [ln.get("ip", "?"), ln.get("name", "?")])


func _cmd_connect(args: Array) -> void:
	if args.is_empty():
		_print_line("[color=#ff1580]Usage: connect <ip>[/color]")
		return
	var ip: String = args[0]
	for ln: Dictionary in _lan_nodes:
		if ln.get("ip", "") == ip:
			_current_lan_node = ln
			_print_line("[color=#00e1ff]Connected to: %s (%s)[/color]" % [ln.get("name", ip), ip])
			var cmds: Array = ln.get("commands", [])
			if not cmds.is_empty():
				_print_line("Available: " + ", ".join(cmds))
			return
	_print_line("[color=#ff1580]No LAN node found at %s[/color]" % ip)


func _cmd_scan(args: Array) -> void:
	if args.is_empty():
		_print_line("[color=#ff1580]Usage: scan <ip>[/color]")
		return
	var ip: String = args[0]
	for ln: Dictionary in _lan_nodes:
		if ln.get("ip", "") == ip:
			_print_line("[color=#ffbf00]Scanning %s...[/color]" % ip)
			_print_line("  Name:     %s" % ln.get("name", "?"))
			_print_line("  Commands: %s" % ", ".join(ln.get("commands", [])))
			return
	_print_line("[color=#ff1580]No LAN node at %s[/color]" % ip)


func _cmd_disable_trace() -> void:
	if _current_lan_node.is_empty():
		_print_line("[color=#ff1580]Connect to a LAN node first. Use: connect <ip>[/color]")
		return
	var cmds: Array = _current_lan_node.get("commands", [])
	if "disable_trace" not in cmds:
		_print_line("[color=#ff1580]Command not available on this node.[/color]")
		return
	if not NetworkSim.trace_active:
		_print_line("[color=#ffbf00]No active trace.[/color]")
		return
	NetworkSim._trace_elapsed = maxf(0.0, NetworkSim._trace_elapsed - 30.0)
	_print_line("[color=#00e1ff]Trace countermeasure deployed — 30 seconds removed.[/color]")
	EventBus.log_message.emit("LAN: Trace countermeasure deployed.", "warn")


func _print_line(text: String) -> void:
	_output.append_text(text + "\n")


func _on_network_connected(_node_id: String) -> void:
	if _output:
		_output.clear()
	_current_lan_node = {}
	_refresh_from_connection()


func _on_network_disconnected() -> void:
	if _output:
		_output.clear()
	_lan_nodes = []
	_current_lan_node = {}
	_print_line("[color=#ff1580]Connection lost.[/color]")
