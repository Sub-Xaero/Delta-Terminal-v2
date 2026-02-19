class_name PasswordCracker
extends ToolWindow
## Password cracker tool. Runs a timed crack against the connected node while
## the trace closes in. Crack faster than the trace to gain access.

enum State { IDLE, READY, CRACKING, SUCCESS, FAILED }

const HEX_CHARS := "0123456789ABCDEF"
const GRID_COLS := 8
const GRID_ROWS := 4

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label: Label         = $ContentArea/Margin/VBox/StatusLabel
@onready var char_grid:    RichTextLabel = $ContentArea/Margin/VBox/GridPanel/GridMargin/CharGrid
@onready var crack_pct:    Label         = $ContentArea/Margin/VBox/CrackPct
@onready var crack_bar:    ProgressBar   = $ContentArea/Margin/VBox/CrackBar
@onready var trace_pct:    Label         = $ContentArea/Margin/VBox/TracePct
@onready var trace_bar:    ProgressBar   = $ContentArea/Margin/VBox/TraceBar
@onready var action_btn:   Button        = $ContentArea/Margin/VBox/ActionBtn

# ── State ──────────────────────────────────────────────────────────────────────
var _state:          State = State.IDLE
var _crack_progress: float = 0.0
var _crack_duration: float = 0.0
var _crack_elapsed:  float = 0.0
var _trace_fill:     StyleBoxFlat        # kept by reference so we can mutate its colour


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.trace_progress.connect(_on_trace_progress)
	EventBus.trace_completed.connect(_on_trace_completed)
	action_btn.pressed.connect(_on_action_pressed)
	_setup_theme()
	_update_ui()


func _process(delta: float) -> void:
	_update_char_grid()
	if _state != State.CRACKING:
		return
	_crack_elapsed  += delta
	_crack_progress  = minf(_crack_elapsed / _crack_duration, 1.0)
	crack_bar.value  = _crack_progress * 100.0
	crack_pct.text   = "CRACK:  %d%%" % roundi(_crack_progress * 100.0)
	if _crack_progress >= 1.0:
		_on_crack_complete()


# ── Char grid animation ────────────────────────────────────────────────────────

func _update_char_grid() -> void:
	var total:      int = GRID_COLS * GRID_ROWS
	var locked_cnt: int = int(_crack_progress * float(total))
	var t:          int = Time.get_ticks_msec()
	var bb := ""
	for i in total:
		if i > 0 and i % GRID_COLS == 0:
			bb += "\n"
		var ch: String
		if i < locked_cnt:
			ch = HEX_CHARS[(i * 7 + 13) % HEX_CHARS.length()]
			bb += "[color=#00E1FF]" + ch + "[/color] "
		else:
			ch = HEX_CHARS[(t / 80 + i * 3) % HEX_CHARS.length()]
			bb += "[color=#0D3340]" + ch + "[/color] "
	char_grid.text = bb


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	match _state:
		State.READY:   _start_crack()
		State.CRACKING: _abort_crack()


func _start_crack() -> void:
	var data:     Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	var security: int        = data.get("security", 1)
	_crack_duration = _crack_time(security)
	_crack_elapsed  = 0.0
	_crack_progress = 0.0
	_state = State.CRACKING
	NetworkSim.start_trace(_trace_time(security))
	EventBus.log_message.emit(
		"Password cracker initiated on %s" % data.get("ip", "?"), "info"
	)
	_update_ui()


func _abort_crack() -> void:
	_state          = State.READY
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	crack_pct.text  = "CRACK:  0%"
	EventBus.log_message.emit("Crack aborted.", "warn")
	_update_ui()


func _on_crack_complete() -> void:
	_state = State.SUCCESS
	var node_id := NetworkSim.connected_node_id
	NetworkSim.crack_node(node_id)
	EventBus.tool_task_completed.emit("password_cracker", node_id, true)
	_update_ui()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_state          = State.SUCCESS if node_id in NetworkSim.cracked_nodes else State.READY
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	trace_bar.value = 0.0
	_update_ui()


func _on_network_disconnected() -> void:
	if _state == State.CRACKING:
		NetworkSim.disconnect_from_node()  # stop trace
	_state          = State.IDLE
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	trace_bar.value = 0.0
	crack_pct.text  = "CRACK:  0%"
	trace_pct.text  = "TRACE:  0%"
	_update_ui()


func _on_trace_progress(p: float) -> void:
	if _state != State.CRACKING:
		return
	trace_bar.value    = p * 100.0
	trace_pct.text     = "TRACE:  %d%%" % roundi(p * 100.0)
	_trace_fill.bg_color = _trace_colour(p)


func _on_trace_completed() -> void:
	if _state != State.CRACKING:
		return
	_state = State.FAILED
	EventBus.log_message.emit("Trace complete — connection terminated.", "error")
	NetworkSim.disconnect_from_node()
	_update_ui()


# ── UI update ──────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	match _state:
		State.IDLE:
			status_label.text = "NO ACTIVE CONNECTION"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			action_btn.text     = "INITIATE CRACK"
			action_btn.disabled = true
		State.READY:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "TARGET:  %s  —  %s" % [
				data.get("ip", "?"), data.get("name", "?")
			]
			status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
			action_btn.text     = "INITIATE CRACK"
			action_btn.disabled = false
		State.CRACKING:
			action_btn.text     = "ABORT"
			action_btn.disabled = false
		State.SUCCESS:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "ACCESS GRANTED:  %s" % data.get("ip", "?")
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
			action_btn.text     = "ALREADY CRACKED"
			action_btn.disabled = true
		State.FAILED:
			status_label.text = "TRACE COMPLETE — DISCONNECTED"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			action_btn.text     = "INITIATE CRACK"
			action_btn.disabled = true


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var crack_fill := StyleBoxFlat.new()
	crack_fill.bg_color = Color(0.0, 0.88, 1.0)
	crack_bar.add_theme_stylebox_override("fill", crack_fill)
	var crack_bg := StyleBoxFlat.new()
	crack_bg.bg_color = Color(0.04, 0.12, 0.18)
	crack_bar.add_theme_stylebox_override("background", crack_bg)

	_trace_fill = StyleBoxFlat.new()
	_trace_fill.bg_color = Color(0.0, 0.88, 1.0)
	trace_bar.add_theme_stylebox_override("fill", _trace_fill)
	var trace_bg := StyleBoxFlat.new()
	trace_bg.bg_color = Color(0.04, 0.12, 0.18)
	trace_bar.add_theme_stylebox_override("background", trace_bg)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.08)
	panel_style.border_color = Color(0.0, 0.88, 1.0)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/GridPanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)

	for lbl: Label in [crack_pct, trace_pct]:
		lbl.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	action_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _trace_colour(progress: float) -> Color:
	if progress < 0.5:
		return Color(0.0, 0.88, 1.0)
	if progress < 0.8:
		var t: float = (progress - 0.5) / 0.3
		return Color(0.0, 0.88, 1.0).lerp(Color(1.0, 0.75, 0.0), t)
	var t: float = (progress - 0.8) / 0.2
	return Color(1.0, 0.75, 0.0).lerp(Color(1.0, 0.08, 0.55), t)


func _crack_time(security: int) -> float:
	return maxf(5.0, float(security) * 10.0)


func _trace_time(security: int) -> float:
	return maxf(8.0, float(security) * 18.0)
