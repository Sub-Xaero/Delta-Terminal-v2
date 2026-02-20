class_name FileBrowser
extends ToolWindow
## File Browser — inspect, view, copy, and delete files on cracked nodes.

enum State { IDLE, LOCKED, BROWSING }

const TYPE_PREFIX: Dictionary = {
	"log":    "[LOG]",
	"data":   "[DAT]",
	"exe":    "[EXE]",
	"config": "[CFG]",
	"doc":    "[DOC]",
}

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var header_label:   Label           = $ContentArea/Margin/VBox/HeaderLabel
@onready var hsplit:         HSplitContainer = $ContentArea/Margin/VBox/HSplit
@onready var file_list:      VBoxContainer   = $ContentArea/Margin/VBox/HSplit/FileListPanel/FileListMargin/FileListScroll/FileList
@onready var filename_label: Label           = $ContentArea/Margin/VBox/HSplit/DetailVBox/FilenameLabel
@onready var file_info:      Label           = $ContentArea/Margin/VBox/HSplit/DetailVBox/FileInfoLabel
@onready var view_btn:       Button          = $ContentArea/Margin/VBox/HSplit/DetailVBox/ActionRow/ViewBtn
@onready var copy_btn:       Button          = $ContentArea/Margin/VBox/HSplit/DetailVBox/ActionRow/CopyBtn
@onready var delete_btn:     Button          = $ContentArea/Margin/VBox/HSplit/DetailVBox/ActionRow/DeleteBtn
@onready var content_scroll: ScrollContainer = $ContentArea/Margin/VBox/HSplit/DetailVBox/ContentScroll
@onready var content_label:  RichTextLabel   = $ContentArea/Margin/VBox/HSplit/DetailVBox/ContentScroll/ContentLabel
@onready var status_label:   Label           = $ContentArea/Margin/VBox/StatusLabel

# ── State ──────────────────────────────────────────────────────────────────────
var _state:         State      = State.IDLE
var _selected_file: Dictionary = {}


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_changed)
	EventBus.network_disconnected.connect(_on_network_changed)
	view_btn.pressed.connect(_on_view_pressed)
	copy_btn.pressed.connect(_on_copy_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	_setup_theme()
	_refresh()


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_selected_file = {}
	_clear_detail()

	if not NetworkSim.is_connected:
		_show_status(State.IDLE, "NO ACTIVE CONNECTION")
		return

	var node_id: String = NetworkSim.connected_node_id
	if node_id not in NetworkSim.cracked_nodes:
		_show_status(State.LOCKED, "ACCESS DENIED — CRACK REQUIRED")
		return

	_state = State.BROWSING
	status_label.visible = false
	hsplit.visible = true

	var data: Dictionary = NetworkSim.get_node_data(node_id)
	var ip:   String     = data.get("ip", node_id)
	var name: String     = data.get("name", "Unknown")
	header_label.text    = "%s  [%s]" % [ip, name]
	_populate_file_list(node_id)


func _show_status(new_state: State, message: String) -> void:
	_state = new_state
	hsplit.visible = false
	status_label.visible = true
	status_label.text = message
	if new_state == State.IDLE:
		header_label.text = "FILE BROWSER"
	else:
		var node_id: String = NetworkSim.connected_node_id
		var data:    Dictionary = NetworkSim.get_node_data(node_id)
		header_label.text = "%s  [%s]" % [data.get("ip", ""), data.get("name", "")]


# ── File list ──────────────────────────────────────────────────────────────────

func _populate_file_list(node_id: String) -> void:
	for child in file_list.get_children():
		child.queue_free()

	var data:  Dictionary = NetworkSim.get_node_data(node_id)
	var files: Array      = data.get("files", [])

	if files.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(no files)"
		empty_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		file_list.add_child(empty_lbl)
		return

	for file: Dictionary in files:
		var prefix: String = TYPE_PREFIX.get(file.get("type", ""), "[???]")
		var size_str: String = _format_size(file.get("size", 0))
		var btn := Button.new()
		btn.text = "%s %s   %s" % [prefix, file.get("name", "?"), size_str]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.92, 1.0))
		var captured: Dictionary = file.duplicate()
		btn.pressed.connect(func() -> void: _on_file_selected(captured))
		file_list.add_child(btn)


func _on_file_selected(file: Dictionary) -> void:
	_selected_file = file
	content_scroll.visible = false
	filename_label.text = file.get("name", "?")
	var type_label: String = TYPE_PREFIX.get(file.get("type", ""), "[???]")
	file_info.text = "%s   %s" % [type_label, _format_size(file.get("size", 0))]
	view_btn.disabled   = false
	copy_btn.disabled   = false
	delete_btn.disabled = false


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_view_pressed() -> void:
	if _selected_file.is_empty():
		return
	if content_scroll.visible:
		content_scroll.visible = false
		return
	var text: String = _selected_file.get("content", "(empty)")
	content_label.text = "[color=#00E1FF]%s[/color]" % text
	content_scroll.visible = true


func _on_copy_pressed() -> void:
	if _selected_file.is_empty():
		return
	GameManager.copy_file_to_local(_selected_file)
	EventBus.tool_task_completed.emit("file_browser", _selected_file.get("name", ""), true)


func _on_delete_pressed() -> void:
	if _selected_file.is_empty():
		return
	var node_id: String  = NetworkSim.connected_node_id
	var file_id: String  = _selected_file.get("id", "")
	var success:  bool   = NetworkSim.delete_file_from_node(node_id, file_id)
	if success:
		_clear_detail()
		_populate_file_list(node_id)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _clear_detail() -> void:
	_selected_file = {}
	filename_label.text    = "—"
	file_info.text         = ""
	content_scroll.visible = false
	content_label.text     = ""
	view_btn.disabled      = true
	copy_btn.disabled      = true
	delete_btn.disabled    = true


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	return "%.1f KB" % (float(bytes) / 1024.0)


func _on_network_changed(_arg = null) -> void:
	_refresh()


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	# File list panel — dark bg with cyan border
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color            = Color(0.02, 0.06, 0.10)
	panel_bg.border_color        = Color(0.0, 0.88, 1.0)
	panel_bg.set_border_width_all(1)
	panel_bg.set_content_margin_all(0)
	var file_panel: PanelContainer = $ContentArea/Margin/VBox/HSplit/FileListPanel
	file_panel.add_theme_stylebox_override("panel", panel_bg)

	# Action buttons
	view_btn.add_theme_color_override("font_color",          Color(0.0, 0.88, 1.0))
	view_btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.45))
	copy_btn.add_theme_color_override("font_color",          Color(0.0, 0.88, 1.0))
	copy_btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.45))
	delete_btn.add_theme_color_override("font_color",          Color(1.0, 0.08, 0.55))
	delete_btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.45))

	# Detail labels
	header_label.add_theme_color_override("font_color",  Color(0.0, 0.88, 1.0))
	filename_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	file_info.add_theme_color_override("font_color",      Color(0.35, 0.35, 0.45))
	status_label.add_theme_color_override("font_color",   Color(0.35, 0.35, 0.45))
