class_name EncryptionBreaker
extends ToolWindow
## Encryption breaker tool. Decrypts protected nodes before the password cracker
## can run. Only activates on nodes with "encrypted": true. Advances trace faster
## than the password cracker — less slack time, higher risk.

enum State { IDLE, READY, BREAKING, SUCCESS, FAILED }

const CIPHER_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*<>[]"
const GRID_COLS    := 8
const GRID_ROWS    := 4

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var status_label:   Label         = $ContentArea/Margin/VBox/StatusLabel
@onready var cipher_display: RichTextLabel = $ContentArea/Margin/VBox/CipherPanel/CipherMargin/CipherDisplay
@onready var decrypt_pct:    Label         = $ContentArea/Margin/VBox/DecryptPct
@onready var decrypt_bar:    ProgressBar   = $ContentArea/Margin/VBox/DecryptBar
@onready var action_btn:     Button        = $ContentArea/Margin/VBox/ActionBtn

# ── State ──────────────────────────────────────────────────────────────────────
var _state:            State = State.IDLE
var _decrypt_progress: float = 0.0
var _decrypt_duration: float = 0.0
var _decrypt_elapsed:  float = 0.0


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
	_update_cipher_display()
	if _state != State.BREAKING:
		return
	_decrypt_elapsed  += delta
	_decrypt_progress  = minf(_decrypt_elapsed / _decrypt_duration, 1.0)
	decrypt_bar.value  = _decrypt_progress * 100.0
	decrypt_pct.text   = "DECRYPT:  %d%%" % roundi(_decrypt_progress * 100.0)
	if _decrypt_progress >= 1.0:
		_on_decrypt_complete()


# ── Cipher display animation ───────────────────────────────────────────────────

func _update_cipher_display() -> void:
	var total:      int = GRID_COLS * GRID_ROWS
	var locked_cnt: int = int(_decrypt_progress * float(total))
	var t:          int = Time.get_ticks_msec()
	var bb := ""
	for i in total:
		if i > 0 and i % GRID_COLS == 0:
			bb += "\n"
		var ch: String
		if i < locked_cnt:
			# Locked slot — stable decoded character in amber
			ch = CIPHER_CHARS[(i * 11 + 7) % CIPHER_CHARS.length()]
			bb += "[color=#FFBF00]" + ch + "[/color] "
		else:
			# Cycling slot — dim amber
			ch = CIPHER_CHARS[(t / 55 + i * 7) % CIPHER_CHARS.length()]
			bb += "[color=#3D2E00]" + ch + "[/color] "
	cipher_display.text = bb


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_action_pressed() -> void:
	match _state:
		State.READY:    _start_decrypt()
		State.BREAKING: _abort_decrypt()


func _start_decrypt() -> void:
	var data:     Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	var security: int        = data.get("security", 1)
	_decrypt_duration = _decrypt_time(security)
	_decrypt_elapsed  = 0.0
	_decrypt_progress = 0.0
	_state = State.BREAKING
	NetworkSim.start_trace(_trace_time(security))
	EventBus.log_message.emit(
		"Encryption breaker initiated on %s" % data.get("ip", "?"), "info"
	)
	_update_ui()


func _abort_decrypt() -> void:
	_state            = State.READY
	_decrypt_progress = 0.0
	_decrypt_elapsed  = 0.0
	decrypt_bar.value = 0.0
	decrypt_pct.text  = "DECRYPT:  0%"
	EventBus.log_message.emit("Decryption aborted.", "warn")
	_update_ui()


func _on_decrypt_complete() -> void:
	_state = State.SUCCESS
	var node_id := NetworkSim.connected_node_id
	NetworkSim.break_encryption(node_id)
	EventBus.tool_task_completed.emit("encryption_breaker", node_id, true)
	_update_ui()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	var data: Dictionary = NetworkSim.get_node_data(node_id)
	if not data.get("encrypted", false):
		_state            = State.IDLE
		_decrypt_progress = 0.0
		_decrypt_elapsed  = 0.0
		decrypt_bar.value = 0.0
		_update_ui()
		return
	_state            = State.SUCCESS if node_id in NetworkSim.encryption_broken_nodes else State.READY
	_decrypt_progress = 0.0
	_decrypt_elapsed  = 0.0
	decrypt_bar.value = 0.0
	_update_ui()


func _on_network_disconnected() -> void:
	_state            = State.IDLE
	_decrypt_progress = 0.0
	_decrypt_elapsed  = 0.0
	decrypt_bar.value = 0.0
	decrypt_pct.text  = "DECRYPT:  0%"
	_update_ui()


func _on_trace_completed() -> void:
	if _state != State.BREAKING:
		return
	_state = State.FAILED
	EventBus.log_message.emit("Trace complete — connection terminated.", "error")
	NetworkSim.disconnect_from_node()
	_update_ui()


# ── UI update ──────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	match _state:
		State.IDLE:
			status_label.text = "NO ENCRYPTED TARGET"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			action_btn.text     = "INITIATE DECRYPT"
			action_btn.disabled = true
		State.READY:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "TARGET:  %s  —  %s" % [
				data.get("ip", "?"), data.get("name", "?")
			]
			status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
			action_btn.text     = "INITIATE DECRYPT"
			action_btn.disabled = false
		State.BREAKING:
			action_btn.text     = "ABORT"
			action_btn.disabled = false
		State.SUCCESS:
			var data: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
			status_label.text = "DECRYPTED:  %s" % data.get("ip", "?")
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			action_btn.text     = "ALREADY DECRYPTED"
			action_btn.disabled = true
		State.FAILED:
			status_label.text = "TRACE COMPLETE — DISCONNECTED"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			action_btn.text     = "INITIATE DECRYPT"
			action_btn.disabled = true


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.75, 0.0)
	decrypt_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.09, 0.0)
	decrypt_bar.add_theme_stylebox_override("background", bar_bg)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color    = Color(0.06, 0.04, 0.0)
	panel_style.border_color = Color(1.0, 0.75, 0.0)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/CipherPanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)

	decrypt_pct.add_theme_color_override("font_color", Color(0.65, 0.55, 0.25))
	action_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))


# ── Timing ─────────────────────────────────────────────────────────────────────

func _decrypt_time(security: int) -> float:
	return maxf(8.0, float(security) * 12.0)


func _trace_time(security: int) -> float:
	# Tighter window than password cracker — encryption breaking triggers faster tracing
	return maxf(10.0, float(security) * 14.0)
