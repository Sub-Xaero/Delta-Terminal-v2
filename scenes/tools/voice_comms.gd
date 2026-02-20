class_name VoiceComms
extends ToolWindow
## Voice Comms — authenticates into voice_auth-protected nodes using stored voice samples.

const DIAL_TIME := 5.0

enum State { OFFLINE, NO_VOICE_AUTH, NO_SAMPLES, READY, DIALLING, AUTHENTICATED, FAILED }

@onready var status_label:  Label        = $ContentArea/Margin/VBox/StatusLabel
@onready var node_label:    Label        = $ContentArea/Margin/VBox/NodeLabel
@onready var sample_select: OptionButton = $ContentArea/Margin/VBox/SampleSelect
@onready var dial_bar:      ProgressBar  = $ContentArea/Margin/VBox/DialBar
@onready var dial_label:    Label        = $ContentArea/Margin/VBox/DialLabel
@onready var dial_btn:      Button       = $ContentArea/Margin/VBox/DialBtn

var _state: State = State.OFFLINE
var _elapsed: float = 0.0
var _current_node_id: String = ""


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	dial_btn.pressed.connect(_on_dial_pressed)
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_set_state(State.OFFLINE)


func _process(delta: float) -> void:
	if _state != State.DIALLING:
		return
	_elapsed += delta
	var prog := minf(_elapsed / DIAL_TIME, 1.0)
	dial_bar.value = prog * 100.0
	dial_label.text = "DIALLING:  %d%%" % roundi(prog * 100.0)
	if prog >= 1.0:
		_on_dial_complete()


func _on_network_connected(node_id: String) -> void:
	_current_node_id = node_id
	var data: Dictionary = NetworkSim.get_node_data(node_id)
	node_label.text = "NODE:  %s  —  %s" % [data.get("ip", "?"), data.get("name", "?")]
	var services: Array = data.get("services", [])
	if "voice_auth" not in services:
		_set_state(State.NO_VOICE_AUTH)
		return
	if node_id in NetworkSim.cracked_nodes or node_id in VoiceManager.authenticated_nodes:
		_set_state(State.AUTHENTICATED)
		return
	_populate_sample_select(node_id)


func _populate_sample_select(node_id: String) -> void:
	sample_select.clear()
	var all_samples: Dictionary = VoiceManager.get_all_samples()
	# Show all samples (player may have samples from any node)
	for src_id: String in all_samples:
		for sample: Dictionary in all_samples[src_id]:
			sample_select.add_item("%s (from %s)" % [sample.get("name", "?"), src_id])
	if sample_select.item_count == 0:
		_set_state(State.NO_SAMPLES)
	else:
		_set_state(State.READY)


func _on_network_disconnected() -> void:
	_current_node_id = ""
	_elapsed = 0.0
	node_label.text = "No voice-auth node targeted"
	sample_select.clear()
	_set_state(State.OFFLINE)


func _on_dial_pressed() -> void:
	if _state != State.READY:
		return
	_elapsed = 0.0
	_set_state(State.DIALLING)
	EventBus.log_message.emit("Voice authentication dialling %s..." % _current_node_id, "info")


func _on_dial_complete() -> void:
	var success: bool = VoiceManager.authenticate_node(_current_node_id)
	if success:
		_set_state(State.AUTHENTICATED)
	else:
		_set_state(State.FAILED)


func _set_state(new_state: State) -> void:
	_state = new_state
	_update_ui()


func _update_ui() -> void:
	dial_bar.visible    = (_state == State.DIALLING)
	dial_label.visible  = (_state == State.DIALLING)
	sample_select.visible = _state in [State.READY, State.DIALLING]
	match _state:
		State.OFFLINE:
			status_label.text = "NOT CONNECTED"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			dial_btn.disabled = true
		State.NO_VOICE_AUTH:
			status_label.text = "NO VOICE AUTH ON THIS NODE"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			dial_btn.disabled = true
		State.NO_SAMPLES:
			status_label.text = "NO VOICE SAMPLES — analyse audio files first"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			dial_btn.disabled = true
		State.READY:
			status_label.text = "READY — select voice sample and authenticate"
			status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
			dial_btn.disabled = false
			dial_btn.text = "INITIATE VOICE AUTH"
		State.DIALLING:
			status_label.text = "DIALLING..."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			dial_btn.disabled = true
		State.AUTHENTICATED:
			status_label.text = "VOICE AUTHENTICATION GRANTED"
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
			dial_btn.disabled = true
			dial_btn.text = "AUTHENTICATED"
		State.FAILED:
			status_label.text = "AUTHENTICATION FAILED"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
			dial_btn.disabled = false
			dial_btn.text = "RETRY"


func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.0, 0.88, 1.0)
	dial_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.12, 0.18)
	dial_bar.add_theme_stylebox_override("background", bar_bg)
	dial_label.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	dial_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	node_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
