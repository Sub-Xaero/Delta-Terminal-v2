class_name PasswordCracker
extends ToolWindow
## Password cracker tool. Owns crack progress only — trace display is handled
## by the Trace Tracker tool. Starts a trace via NetworkSim when cracking begins
## and reacts to trace_completed to detect failure.

enum State { IDLE, FIREWALL_LOCKED, READY, CRACKING, SUCCESS, FAILED }
enum Mode  { ONLINE, OFFLINE }

const HEX_CHARS := "0123456789ABCDEF"
const GRID_COLS := 8
const GRID_ROWS := 4

# Plaintext words checked sequentially by the offline wordlist crack.
const COMMON_WORDLIST: Array[String] = [
	"password", "letmein", "qwerty", "admin", "ghost", "delta", "neon", "1234",
	"sunshine", "matrix", "trinity", "synapse", "cipher", "phantom",
]

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label: Label         = $ContentArea/Margin/VBox/StatusLabel
@onready var char_grid:    RichTextLabel = $ContentArea/Margin/VBox/GridPanel/GridMargin/CharGrid
@onready var crack_pct:    Label         = $ContentArea/Margin/VBox/CrackPct
@onready var crack_bar:    ProgressBar   = $ContentArea/Margin/VBox/CrackBar
@onready var action_btn:   Button        = $ContentArea/Margin/VBox/ActionBtn

# ── State ──────────────────────────────────────────────────────────────────────
var _state:          State = State.IDLE
var _mode:           Mode  = Mode.ONLINE
var _crack_progress: float = 0.0
var _crack_duration: float = 0.0
var _crack_elapsed:  float = 0.0
var _offline_node_id: String = ""
var _offline_username: String = ""
var _offline_picker: OptionButton = null
var _mode_btn: Button = null


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.trace_completed.connect(_on_trace_completed)
	EventBus.firewall_bypassed.connect(_on_firewall_bypassed)
	action_btn.pressed.connect(_on_action_pressed)
	_build_mode_controls()
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_update_ui()


func _build_mode_controls() -> void:
	# Drop in an [ONLINE | OFFLINE] toggle + offline target picker at the top.
	var vbox: VBoxContainer = $ContentArea/Margin/VBox
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_mode_btn = Button.new()
	_mode_btn.text = "MODE: ONLINE"
	_mode_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_mode_btn.pressed.connect(_on_mode_toggle)
	row.add_child(_mode_btn)
	_offline_picker = OptionButton.new()
	_offline_picker.visible = false
	_offline_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offline_picker.item_selected.connect(_on_offline_target_selected)
	row.add_child(_offline_picker)
	vbox.add_child(row)
	vbox.move_child(row, 0)


func _on_mode_toggle() -> void:
	_mode = Mode.OFFLINE if _mode == Mode.ONLINE else Mode.ONLINE
	_mode_btn.text = "MODE: %s" % ("OFFLINE" if _mode == Mode.OFFLINE else "ONLINE")
	if _mode == Mode.OFFLINE:
		_populate_offline_targets()
		_offline_picker.visible = true
	else:
		_offline_picker.visible = false
		if NetworkSim.is_connected:
			_on_network_connected(NetworkSim.connected_node_id)
		else:
			_state = State.IDLE
	_update_ui()


func _populate_offline_targets() -> void:
	_offline_picker.clear()
	var entries: Array = []
	for node_id: String in CredentialManager.credentials:
		for cred: Dictionary in CredentialManager.get_credentials(node_id):
			if cred.get("cracked", false):
				continue
			if cred.get("password_hash", "").is_empty():
				continue
			entries.append({ "node_id": node_id, "username": cred.get("username", "?") })
			_offline_picker.add_item("%s @ %s" % [cred.get("username", "?"), NetworkSim.get_node_data(node_id).get("name", node_id)])
	_offline_picker.set_meta("entries", entries)
	if entries.is_empty():
		_state = State.IDLE
	else:
		_on_offline_target_selected(0)


func _on_offline_target_selected(idx: int) -> void:
	var entries: Array = _offline_picker.get_meta("entries", [])
	if idx < 0 or idx >= entries.size():
		return
	_offline_node_id  = entries[idx]["node_id"]
	_offline_username = entries[idx]["username"]
	_state = State.READY
	_update_ui()


func _process(delta: float) -> void:
	_update_char_grid()
	if _state != State.CRACKING:
		return
	_crack_elapsed  += delta * HardwareManager.effective_stack_speed
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
		State.READY:    _start_crack()
		State.CRACKING: _abort_crack()


func _start_crack() -> void:
	if _mode == Mode.OFFLINE:
		_start_offline_crack()
		return
	var data:     Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	var security: int        = NetworkSim.effective_security(NetworkSim.connected_node_id)
	if security <= 0:
		security = data.get("security", 1)
	_crack_duration = _crack_time(security)
	_crack_elapsed  = 0.0
	_crack_progress = 0.0
	_state = State.CRACKING
	NetworkSim.start_trace(_trace_time(security))
	EventBus.tool_task_started.emit("password_cracker", NetworkSim.connected_node_id)
	EventBus.log_message.emit(
		"Password cracker initiated on %s" % data.get("ip", "?"), "info"
	)
	_update_ui()


func _start_offline_crack() -> void:
	if _offline_node_id.is_empty():
		return
	var sec: int = NetworkSim.get_node_data(_offline_node_id).get("security", 1)
	_crack_duration = maxf(6.0, float(sec) * 6.0)
	_crack_elapsed  = 0.0
	_crack_progress = 0.0
	_state = State.CRACKING
	# Offline mode is local — no trace, no remote signal.
	EventBus.tool_task_started.emit("password_cracker", "%s:%s" % [_offline_node_id, _offline_username])
	EventBus.log_message.emit(
		"Offline wordlist attack: %s @ %s" % [_offline_username, _offline_node_id], "info"
	)
	_update_ui()


func _abort_crack() -> void:
	_state          = State.READY
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	crack_pct.text  = "CRACK:  0%"
	EventBus.tool_task_completed.emit("password_cracker", NetworkSim.connected_node_id, false)
	EventBus.log_message.emit("Crack aborted.", "warn")
	_update_ui()


func _on_crack_complete() -> void:
	if _mode == Mode.OFFLINE:
		_on_offline_complete()
		return
	_state = State.SUCCESS
	var node_id := NetworkSim.connected_node_id
	NetworkSim.crack_node(node_id)
	EventBus.tool_task_completed.emit("password_cracker", node_id, true)
	_update_ui()


func _on_offline_complete() -> void:
	# Pick a plausible plaintext from the wordlist. High-security nodes only
	# yield a result some of the time — the player is meant to upgrade lists.
	var sec: int = NetworkSim.get_node_data(_offline_node_id).get("security", 1)
	var success_chance: float = clampf(1.0 - (float(sec) - 1.0) * 0.18, 0.15, 1.0)
	var plaintext: String = ""
	if randf() < success_chance:
		plaintext = COMMON_WORDLIST[randi() % COMMON_WORDLIST.size()]
		CredentialManager.mark_cracked(_offline_node_id, _offline_username, plaintext)
		EventBus.log_message.emit(
			"Hash cracked: %s -> %s" % [_offline_username, plaintext], "info"
		)
		_state = State.SUCCESS
	else:
		EventBus.log_message.emit(
			"Wordlist exhausted — upgrade required to crack %s" % _offline_username, "warn"
		)
		_state = State.FAILED
	EventBus.tool_task_completed.emit("password_cracker", "%s:%s" % [_offline_node_id, _offline_username], _state == State.SUCCESS)
	_update_ui()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	if _mode == Mode.OFFLINE:
		return
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	if node_id in NetworkSim.cracked_nodes:
		_state = State.SUCCESS
	elif NetworkSim.node_requires_bypass(node_id) and node_id not in NetworkSim.bypassed_nodes:
		_state = State.FIREWALL_LOCKED
	else:
		_state = State.READY
	_update_ui()


func _on_firewall_bypassed(node_id: String) -> void:
	if _state != State.FIREWALL_LOCKED:
		return
	if node_id != NetworkSim.connected_node_id:
		return
	_state = State.READY
	_update_ui()


func _on_network_disconnected() -> void:
	if _mode == Mode.OFFLINE:
		return
	_state          = State.IDLE
	_crack_progress = 0.0
	_crack_elapsed  = 0.0
	crack_bar.value = 0.0
	crack_pct.text  = "CRACK:  0%"
	_update_ui()


func _on_trace_completed() -> void:
	if _state != State.CRACKING:
		return
	_state = State.FAILED
	EventBus.tool_task_completed.emit("password_cracker", NetworkSim.connected_node_id, false)
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
		State.FIREWALL_LOCKED:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "FIREWALL ACTIVE:  %s  —  bypass required" % data.get("ip", "?")
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			action_btn.text     = "FIREWALL LOCKED"
			action_btn.disabled = true
		State.READY:
			if _mode == Mode.OFFLINE:
				status_label.text = "OFFLINE TARGET:  %s @ %s" % [_offline_username, _offline_node_id]
				status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
				action_btn.text     = "START WORDLIST"
				action_btn.disabled = false
			else:
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

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.08)
	panel_style.border_color = Color(0.0, 0.88, 1.0)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/GridPanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)

	crack_pct.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	action_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _crack_time(security: int) -> float:
	return maxf(5.0, float(security) * 10.0)


func _trace_time(security: int) -> float:
	return maxf(8.0, float(security) * 18.0)
