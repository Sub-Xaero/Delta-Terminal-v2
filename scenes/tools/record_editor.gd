class_name RecordEditor
extends ToolWindow
## Record Editor — modify .dat records on database nodes.
## Only available on nodes with "database" in services and cracked status.

enum State { DISCONNECTED, NO_DATABASE, LOCKED, NO_FILES, IDLE, MODIFYING, DONE }

const MODIFY_TIME := 10.0

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label:  Label         = $ContentArea/Margin/VBox/StatusLabel
@onready var file_select:   OptionButton  = $ContentArea/Margin/VBox/FileRow/FileSelect
@onready var record_list:   VBoxContainer = $ContentArea/Margin/VBox/RecordScroll/RecordList
@onready var progress_bar:  ProgressBar   = $ContentArea/Margin/VBox/ProgressBar
@onready var progress_label: Label        = $ContentArea/Margin/VBox/ProgressLabel
@onready var modify_btn:    Button        = $ContentArea/Margin/VBox/BtnRow/ModifyBtn
@onready var cancel_btn:    Button        = $ContentArea/Margin/VBox/BtnRow/CancelBtn
@onready var file_row:      HBoxContainer = $ContentArea/Margin/VBox/FileRow

# ── State ──────────────────────────────────────────────────────────────────────
var _state: State = State.DISCONNECTED
var _node_id: String = ""
var _dat_files: Array = []
var _selected_file_idx: int = 0
var _selected_row: int = -1
var _modify_elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	file_select.item_selected.connect(_on_file_selected)
	modify_btn.pressed.connect(_on_modify_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_set_state(State.DISCONNECTED)


func _process(delta: float) -> void:
	if _state != State.MODIFYING:
		return
	_modify_elapsed += delta * HardwareManager.effective_stack_speed
	var prog := minf(_modify_elapsed / MODIFY_TIME, 1.0)
	progress_bar.value = prog * 100.0
	progress_label.text = "MODIFYING:  %d%%" % roundi(prog * 100.0)
	if prog >= 1.0:
		_on_modify_complete()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_node_id = node_id
	_selected_row = -1
	var data: Dictionary = NetworkSim.get_node_data(node_id)
	var services: Array = data.get("services", [])
	if "database" not in services:
		_set_state(State.NO_DATABASE)
		return
	if node_id not in NetworkSim.cracked_nodes:
		_set_state(State.LOCKED)
		return
	_load_dat_files()


func _on_network_disconnected() -> void:
	_node_id = ""
	_dat_files.clear()
	_selected_row = -1
	_set_state(State.DISCONNECTED)


# ── File loading ───────────────────────────────────────────────────────────────

func _load_dat_files() -> void:
	var data: Dictionary = NetworkSim.get_node_data(_node_id)
	var files: Array = data.get("files", [])
	_dat_files.clear()
	file_select.clear()
	for f: Dictionary in files:
		if f.get("type", "") == "data":
			_dat_files.append(f)
			file_select.add_item(f.get("name", "?"))
	if _dat_files.is_empty():
		_set_state(State.NO_FILES)
	else:
		_selected_file_idx = 0
		_set_state(State.IDLE)
		_rebuild_record_list()


# ── Record display ─────────────────────────────────────────────────────────────

func _rebuild_record_list() -> void:
	for child in record_list.get_children():
		child.queue_free()
	_selected_row = -1

	if _dat_files.is_empty() or _selected_file_idx >= _dat_files.size():
		return

	var content: String = _dat_files[_selected_file_idx].get("content", "")
	var lines: Array = content.split("\n", false)
	var row_idx := 0
	for line: String in lines:
		if line.strip_edges().is_empty() or line.begins_with("---") or line.begins_with("==="):
			var sep := Label.new()
			sep.text = line
			sep.add_theme_color_override("font_color", Color(0.25, 0.35, 0.4))
			record_list.add_child(sep)
			continue
		var captured_idx := row_idx
		var btn := Button.new()
		btn.text = line
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_color_override("font_color", Color(0.55, 0.75, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(0.75, 0.92, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.75, 0.0))
		btn.pressed.connect(func() -> void: _on_row_selected(captured_idx))
		record_list.add_child(btn)
		row_idx += 1
	_update_buttons()


func _on_row_selected(idx: int) -> void:
	_selected_row = idx
	_update_buttons()
	EventBus.log_message.emit("Record row %d selected." % idx, "info")


# ── Modify action ──────────────────────────────────────────────────────────────

func _on_modify_pressed() -> void:
	if _state != State.IDLE or _selected_row < 0:
		return
	_modify_elapsed = 0.0
	_set_state(State.MODIFYING)

	if not NetworkSim.trace_active:
		var data: Dictionary = NetworkSim.get_node_data(_node_id)
		var sec: int = data.get("security", 1)
		NetworkSim.start_trace(maxf(20.0, float(sec) * 25.0))

	EventBus.tool_task_started.emit("record_editor", _node_id)
	EventBus.log_message.emit("Record modification in progress...", "warn")


func _on_modify_complete() -> void:
	_set_state(State.DONE)
	EventBus.tool_task_completed.emit("record_editor", _node_id, true)
	EventBus.log_message.emit("Record modified successfully.", "info")


func _on_cancel_pressed() -> void:
	if _state == State.MODIFYING:
		_modify_elapsed = 0.0
		_set_state(State.IDLE)
		EventBus.log_message.emit("Record modification cancelled.", "warn")


func _on_file_selected(idx: int) -> void:
	_selected_file_idx = idx
	_rebuild_record_list()


# ── UI state ──────────────────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	_state = new_state
	_update_status()
	_update_buttons()
	var show_file_row := _state in [State.IDLE, State.DONE, State.MODIFYING]
	file_row.visible = show_file_row
	progress_bar.visible = (_state == State.MODIFYING)
	progress_label.visible = (_state == State.MODIFYING)


func _update_status() -> void:
	match _state:
		State.DISCONNECTED:
			status_label.text = "Connect to a database node."
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		State.NO_DATABASE:
			status_label.text = "No database service on this node."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
		State.LOCKED:
			status_label.text = "ACCESS DENIED — crack the node first."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		State.NO_FILES:
			var data: Dictionary = NetworkSim.get_node_data(_node_id)
			status_label.text = "No .dat files on %s." % data.get("ip", "this node")
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
		State.IDLE:
			var data: Dictionary = NetworkSim.get_node_data(_node_id)
			var node_type: String = data.get("node_type", "standard")
			match node_type:
				"criminal_db":
					status_label.text = "CRIMINAL DATABASE  —  %s  —  Modify STATUS / CHARGES" % data.get("ip", "?")
					status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
				"academic_db":
					status_label.text = "ACADEMIC DATABASE  —  %s  —  Modify DEGREE / GPA" % data.get("ip", "?")
					status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
				_:
					status_label.text = "TARGET:  %s  —  %s" % [data.get("ip", "?"), data.get("name", "?")]
					status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
		State.MODIFYING:
			status_label.text = "MODIFYING RECORD..."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		State.DONE:
			status_label.text = "MODIFICATION COMPLETE"
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _update_buttons() -> void:
	match _state:
		State.DISCONNECTED, State.NO_DATABASE, State.LOCKED, State.NO_FILES:
			modify_btn.disabled = true
			cancel_btn.disabled = true
		State.IDLE:
			modify_btn.disabled = _selected_row < 0
			cancel_btn.disabled = true
		State.MODIFYING:
			modify_btn.disabled = true
			cancel_btn.disabled = false
		State.DONE:
			modify_btn.disabled = true
			cancel_btn.disabled = true


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.75, 0.0)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.12, 0.18)
	progress_bar.add_theme_stylebox_override("background", bar_bg)
	progress_label.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	modify_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	cancel_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
