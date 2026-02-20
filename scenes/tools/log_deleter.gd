class_name LogDeleter
extends ToolWindow
## Reads access.log from the connected node and lets the player queue
## individual lines for deletion, adding trace pressure while deleting.

enum State { DISCONNECTED, NO_LOG, IDLE, DELETING, DONE }

const DELETE_TIME_PER_LINE := 3.0   # seconds per queued line

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label: Label       = $ContentArea/Margin/VBox/StatusLabel
@onready var log_scroll: ScrollContainer = $ContentArea/Margin/VBox/LogPanel/LogMargin/LogScroll
@onready var log_list: VBoxContainer   = $ContentArea/Margin/VBox/LogPanel/LogMargin/LogScroll/LogList
@onready var queue_btn: Button         = $ContentArea/Margin/VBox/BtnRow/QueueBtn
@onready var delete_btn: Button        = $ContentArea/Margin/VBox/BtnRow/DeleteBtn
@onready var progress_bar: ProgressBar = $ContentArea/Margin/VBox/ProgressBar
@onready var progress_label: Label     = $ContentArea/Margin/VBox/ProgressLabel

# ── State ──────────────────────────────────────────────────────────────────────
var _state: State = State.DISCONNECTED
var _log_lines: Array[String] = []
var _selected_indices: Dictionary = {}   # line index → bool
var _queued_indices: Array[int] = []
var _delete_elapsed: float = 0.0
var _delete_total: float = 0.0
var _current_delete_idx: int = 0
var _node_id: String = ""
var _log_file_index: int = -1   # index in node's files array


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	queue_btn.pressed.connect(_on_queue_pressed)
	delete_btn.pressed.connect(_on_delete_pressed)
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_set_state(State.DISCONNECTED)


func _process(delta: float) -> void:
	if _state != State.DELETING:
		return
	_delete_elapsed += delta * HardwareManager.effective_stack_speed
	var total_progress := _delete_elapsed / _delete_total
	progress_bar.value = total_progress * 100.0
	progress_label.text = "DELETING:  %d%%" % roundi(total_progress * 100.0)

	# Check if current line is done
	var per_line := DELETE_TIME_PER_LINE
	var lines_done := int(_delete_elapsed / per_line)
	if lines_done > _current_delete_idx:
		_current_delete_idx = mini(lines_done, _queued_indices.size())

	if total_progress >= 1.0:
		_on_delete_complete()


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_node_id = node_id
	_selected_indices.clear()
	_queued_indices.clear()
	_load_access_log()


func _on_network_disconnected() -> void:
	_node_id = ""
	_log_lines.clear()
	_selected_indices.clear()
	_queued_indices.clear()
	_set_state(State.DISCONNECTED)


# ── Log loading ───────────────────────────────────────────────────────────────

func _load_access_log() -> void:
	var data: Dictionary = NetworkSim.get_node_data(_node_id)
	var files: Array = data.get("files", [])
	_log_file_index = -1
	_log_lines.clear()

	for i: int in files.size():
		var f: Dictionary = files[i]
		var fname: String = f.get("name", "")
		if fname == "access.log" or fname.ends_with(".log") and f.get("type", "") == "log":
			_log_file_index = i
			var content: String = f.get("content", "")
			if not content.is_empty():
				for line: String in content.split("\n", false):
					_log_lines.append(line)
			break

	if _log_file_index == -1 or _log_lines.is_empty():
		_set_state(State.NO_LOG)
	else:
		_set_state(State.IDLE)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_queue_pressed() -> void:
	if _state != State.IDLE:
		return
	# Toggle: if all selected are already queued, unqueue them
	for idx: int in _selected_indices:
		if _selected_indices[idx]:
			if idx not in _queued_indices:
				_queued_indices.append(idx)
	_selected_indices.clear()
	_rebuild_log_list()
	_update_buttons()


func _on_delete_pressed() -> void:
	if _state != State.IDLE or _queued_indices.is_empty():
		return
	_queued_indices.sort()
	_delete_total = float(_queued_indices.size()) * DELETE_TIME_PER_LINE
	_delete_elapsed = 0.0
	_current_delete_idx = 0
	_set_state(State.DELETING)

	# Start or intensify trace
	if not NetworkSim.trace_active:
		var data: Dictionary = NetworkSim.get_node_data(_node_id)
		var sec: int = data.get("security", 1)
		NetworkSim.start_trace(maxf(15.0, float(sec) * 20.0))

	EventBus.tool_task_started.emit("log_deleter", "delete")
	EventBus.log_message.emit(
		"Log deletion started — %d entries queued." % _queued_indices.size(), "warn"
	)


func _on_delete_complete() -> void:
	# Remove lines from the log (reverse order to preserve indices)
	_queued_indices.sort()
	_queued_indices.reverse()
	for idx: int in _queued_indices:
		if idx >= 0 and idx < _log_lines.size():
			_log_lines.remove_at(idx)
	_queued_indices.clear()

	# Write back to node data
	_write_log_back()

	_set_state(State.DONE)
	var sec: int = NetworkSim.get_node_data(_node_id).get("security", 1)
	GameManager.add_heat(-sec)
	NetworkSim.clear_intrusion_log(_node_id)
	EventBus.tool_task_completed.emit("log_deleter", _node_id, true)
	EventBus.log_message.emit("Log entries deleted successfully.", "info")

	# After a moment, go back to idle if still connected
	if not _log_lines.is_empty():
		_set_state(State.IDLE)


func _write_log_back() -> void:
	if _node_id.is_empty() or _log_file_index == -1:
		return
	var data: Dictionary = NetworkSim.get_node_data(_node_id)
	var files: Array = data.get("files", [])
	if _log_file_index >= files.size():
		return
	var new_content := "\n".join(_log_lines)
	files[_log_file_index]["content"] = new_content


# ── UI ────────────────────────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	_state = new_state
	_rebuild_log_list()
	_update_buttons()
	_update_status()


func _update_status() -> void:
	match _state:
		State.DISCONNECTED:
			status_label.text = "Connect to a node first."
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			progress_bar.visible = false
			progress_label.visible = false
		State.NO_LOG:
			var data: Dictionary = NetworkSim.get_node_data(_node_id)
			status_label.text = "No log file found on %s." % data.get("ip", "this node")
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			progress_bar.visible = false
			progress_label.visible = false
		State.IDLE:
			var data: Dictionary = NetworkSim.get_node_data(_node_id)
			status_label.text = "TARGET:  %s  —  %s  (%d lines)" % [
				data.get("ip", "?"), data.get("name", "?"), _log_lines.size()
			]
			status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
			progress_bar.visible = false
			progress_label.visible = false
		State.DELETING:
			status_label.text = "DELETING LOG ENTRIES..."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			progress_bar.visible = true
			progress_label.visible = true
			progress_bar.value = 0.0
		State.DONE:
			status_label.text = "DELETION COMPLETE"
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
			progress_bar.visible = false
			progress_label.visible = false


func _update_buttons() -> void:
	match _state:
		State.DISCONNECTED, State.NO_LOG, State.DONE:
			queue_btn.disabled = true
			delete_btn.disabled = true
		State.IDLE:
			queue_btn.disabled = _selected_indices.is_empty()
			delete_btn.disabled = _queued_indices.is_empty()
		State.DELETING:
			queue_btn.disabled = true
			delete_btn.disabled = true


func _rebuild_log_list() -> void:
	for child: Node in log_list.get_children():
		child.queue_free()

	if _state == State.DISCONNECTED or _state == State.NO_LOG:
		return

	for i: int in _log_lines.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var cb := CheckBox.new()
		cb.disabled = _state == State.DELETING
		var is_queued := i in _queued_indices
		if is_queued:
			cb.button_pressed = true
			cb.disabled = true
		var captured_i := i
		cb.toggled.connect(func(on: bool): _on_line_toggled(captured_i, on))
		row.add_child(cb)

		var lbl := Label.new()
		lbl.text = _log_lines[i]
		lbl.clip_text = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_queued:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		else:
			lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
		row.add_child(lbl)

		log_list.add_child(row)


func _on_line_toggled(index: int, on: bool) -> void:
	if on:
		_selected_indices[index] = true
	else:
		_selected_indices.erase(index)
	_update_buttons()


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.08, 0.55)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.12, 0.18)
	progress_bar.add_theme_stylebox_override("background", bar_bg)
	progress_label.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.08)
	panel_style.border_color = Color(0.0, 0.88, 1.0, 0.4)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/LogPanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)

	queue_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
