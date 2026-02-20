class_name FirewallBypasser
extends ToolWindow
## Firewall bypass tool. Required before the Password Cracker on hardened nodes
## (security >= 3). Runs a probe animation and a dedicated trace — trace advances
## faster here than during cracking to add pressure. On success the node is added
## to NetworkSim.bypassed_nodes, unlocking the Password Cracker.

enum State { IDLE, NO_FIREWALL, READY, BYPASSING, SUCCESS, FAILED }

const RULE_CHARS := "0123456789ABCDEF"
const PROBE_COLS := 8
const PROBE_ROWS := 3

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label: Label         = $ContentArea/Margin/VBox/StatusLabel
@onready var rule_grid:    RichTextLabel = $ContentArea/Margin/VBox/ProbePanel/ProbeMargin/RuleGrid
@onready var bypass_pct:   Label         = $ContentArea/Margin/VBox/BypassPct
@onready var bypass_bar:   ProgressBar   = $ContentArea/Margin/VBox/BypassBar
@onready var action_btn:   Button        = $ContentArea/Margin/VBox/ActionBtn

# ── State ──────────────────────────────────────────────────────────────────────
var _state:            State = State.IDLE
var _bypass_progress:  float = 0.0
var _bypass_duration:  float = 0.0
var _bypass_elapsed:   float = 0.0


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.trace_completed.connect(_on_trace_completed)
	action_btn.pressed.connect(_on_action_pressed)
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_update_ui()


func _process(delta: float) -> void:
	_update_rule_grid()
	if _state != State.BYPASSING:
		return
	_bypass_elapsed   += delta
	_bypass_progress   = minf(_bypass_elapsed / _bypass_duration, 1.0)
	bypass_bar.value   = _bypass_progress * 100.0
	bypass_pct.text    = "BYPASS:  %d%%" % roundi(_bypass_progress * 100.0)
	if _bypass_progress >= 1.0:
		_on_bypass_complete()


# ── Rule grid animation ─────────────────────────────────────────────────────────
# Bypassed rules: cyan.  Active probe rule: flashing amber.  Pending: dark/muted.

func _update_rule_grid() -> void:
	var total:      int = PROBE_COLS * PROBE_ROWS
	var locked_cnt: int = int(_bypass_progress * float(total))
	var t:          int = Time.get_ticks_msec()
	var bb := ""
	for i in total:
		if i > 0 and i % PROBE_COLS == 0:
			bb += "\n"
		var ch: String
		if i < locked_cnt:
			# Bypassed rule — locked cyan
			ch = RULE_CHARS[(i * 7 + 13) % RULE_CHARS.length()]
			bb += "[color=#00E1FF]" + ch + "[/color] "
		elif i == locked_cnt and _state == State.BYPASSING:
			# Active probe — flashing amber
			var flash: bool = (t / 150) % 2 == 0
			ch = RULE_CHARS[(t / 60 + i * 5) % RULE_CHARS.length()]
			var col: String = "#FFBF00" if flash else "#FF1580"
			bb += "[color=" + col + "]" + ch + "[/color] "
		else:
			# Pending rule — dark muted
			ch = RULE_CHARS[(t / 100 + i * 3) % RULE_CHARS.length()]
			bb += "[color=#1A0D26]" + ch + "[/color] "
	rule_grid.text = bb


# ── Actions ─────────────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	match _state:
		State.READY:    _start_bypass()
		State.BYPASSING: _abort_bypass()


func _start_bypass() -> void:
	var data:     Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	var security: int        = data.get("security", 1)
	_bypass_duration  = _bypass_time(security)
	_bypass_elapsed   = 0.0
	_bypass_progress  = 0.0
	_state = State.BYPASSING
	NetworkSim.start_trace(_trace_time(security))
	EventBus.log_message.emit(
		"Firewall probe initiated on %s" % data.get("ip", "?"), "warn"
	)
	_update_ui()


func _abort_bypass() -> void:
	_state           = State.READY
	_bypass_progress = 0.0
	_bypass_elapsed  = 0.0
	bypass_bar.value = 0.0
	bypass_pct.text  = "BYPASS:  0%"
	EventBus.log_message.emit("Bypass aborted.", "warn")
	_update_ui()


func _on_bypass_complete() -> void:
	_state = State.SUCCESS
	var node_id := NetworkSim.connected_node_id
	NetworkSim.bypass_node(node_id)
	EventBus.tool_task_completed.emit("firewall_bypasser", node_id, true)
	_update_ui()


# ── EventBus handlers ───────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_bypass_progress = 0.0
	_bypass_elapsed  = 0.0
	bypass_bar.value = 0.0
	if not NetworkSim.node_requires_bypass(node_id):
		_state = State.NO_FIREWALL
	elif node_id in NetworkSim.bypassed_nodes:
		_state = State.SUCCESS
	else:
		_state = State.READY
	_update_ui()


func _on_network_disconnected() -> void:
	_state           = State.IDLE
	_bypass_progress = 0.0
	_bypass_elapsed  = 0.0
	bypass_bar.value = 0.0
	bypass_pct.text  = "BYPASS:  0%"
	_update_ui()


func _on_trace_completed() -> void:
	if _state != State.BYPASSING:
		return
	_state = State.FAILED
	EventBus.log_message.emit("Trace complete — firewall locked out connection.", "error")
	NetworkSim.disconnect_from_node()
	_update_ui()


# ── UI update ───────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	match _state:
		State.IDLE:
			status_label.text = "NO ACTIVE CONNECTION"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			action_btn.text     = "INITIATE BYPASS"
			action_btn.disabled = true
		State.NO_FIREWALL:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "NO FIREWALL DETECTED:  %s" % data.get("ip", "?")
			status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
			action_btn.text     = "NOT REQUIRED"
			action_btn.disabled = true
		State.READY:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "FIREWALL ACTIVE:  %s  —  %s" % [
				data.get("ip", "?"), data.get("name", "?")
			]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			action_btn.text     = "INITIATE BYPASS"
			action_btn.disabled = false
		State.BYPASSING:
			action_btn.text     = "ABORT"
			action_btn.disabled = false
		State.SUCCESS:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "FIREWALL BYPASSED:  %s" % data.get("ip", "?")
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
			action_btn.text     = "ALREADY BYPASSED"
			action_btn.disabled = true
		State.FAILED:
			status_label.text = "TRACE COMPLETE — DISCONNECTED"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			action_btn.text     = "INITIATE BYPASS"
			action_btn.disabled = true


# ── Theme ───────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var bypass_fill := StyleBoxFlat.new()
	bypass_fill.bg_color = Color(1.0, 0.75, 0.0)
	bypass_bar.add_theme_stylebox_override("fill", bypass_fill)
	var bypass_bg := StyleBoxFlat.new()
	bypass_bg.bg_color = Color(0.08, 0.06, 0.02)
	bypass_bar.add_theme_stylebox_override("background", bypass_bg)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.02, 0.08)
	panel_style.border_color = Color(1.0, 0.08, 0.55)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/ProbePanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)

	bypass_pct.add_theme_color_override("font_color", Color(0.65, 0.55, 0.25))
	action_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))


func _bypass_time(security: int) -> float:
	return maxf(8.0, float(security) * 10.0)


func _trace_time(security: int) -> float:
	return maxf(5.0, float(security) * 8.0)
