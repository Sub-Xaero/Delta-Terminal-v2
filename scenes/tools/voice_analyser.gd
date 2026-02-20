class_name VoiceAnalyser
extends ToolWindow
## Extracts and analyses voice samples from audio files on remote nodes.

const ANALYSE_TIME := 15.0

enum State { IDLE, NO_CONNECTION, NO_AUDIO, READY, ANALYSING, DONE }

@onready var status_label:   Label       = $ContentArea/Margin/VBox/StatusLabel
@onready var file_select:    OptionButton = $ContentArea/Margin/VBox/FileSelect
@onready var analyse_bar:    ProgressBar  = $ContentArea/Margin/VBox/AnalyseBar
@onready var progress_label: Label        = $ContentArea/Margin/VBox/ProgressLabel
@onready var action_btn:     Button       = $ContentArea/Margin/VBox/ActionBtn

var _state: State = State.NO_CONNECTION
var _audio_files: Array = []
var _elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	action_btn.pressed.connect(_on_analyse_pressed)
	_setup_theme()
	if NetworkSim.is_connected:
		_on_network_connected(NetworkSim.connected_node_id)
	else:
		_set_state(State.NO_CONNECTION)


func _process(delta: float) -> void:
	if _state != State.ANALYSING:
		return
	_elapsed += delta * HardwareManager.effective_stack_speed
	var prog := minf(_elapsed / ANALYSE_TIME, 1.0)
	analyse_bar.value = prog * 100.0
	progress_label.text = "ANALYSING:  %d%%" % roundi(prog * 100.0)
	if prog >= 1.0:
		_on_analyse_complete()


func _on_network_connected(node_id: String) -> void:
	_audio_files.clear()
	file_select.clear()
	var data: Dictionary = NetworkSim.get_node_data(node_id)
	for f: Dictionary in data.get("files", []):
		if f.get("type", "") == "audio":
			_audio_files.append(f)
			file_select.add_item(f.get("name", "?"))
	if _audio_files.is_empty():
		_set_state(State.NO_AUDIO)
	else:
		_set_state(State.READY)


func _on_network_disconnected() -> void:
	_audio_files.clear()
	file_select.clear()
	_elapsed = 0.0
	_set_state(State.NO_CONNECTION)


func _on_analyse_pressed() -> void:
	if _state != State.READY:
		return
	_elapsed = 0.0
	_set_state(State.ANALYSING)
	var node_id: String = NetworkSim.connected_node_id
	EventBus.tool_task_started.emit("voice_analyser", node_id)
	EventBus.log_message.emit("Voice analysis started...", "info")


func _on_analyse_complete() -> void:
	_state = State.DONE
	var node_id: String = NetworkSim.connected_node_id
	var idx: int = file_select.selected
	if idx >= 0 and idx < _audio_files.size():
		VoiceManager.store_sample(node_id, _audio_files[idx])
	EventBus.tool_task_completed.emit("voice_analyser", node_id, true)
	_update_ui()


func _set_state(new_state: State) -> void:
	_state = new_state
	_update_ui()


func _update_ui() -> void:
	var node_data: Dictionary = {}
	if NetworkSim.is_connected:
		node_data = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	analyse_bar.visible = (_state == State.ANALYSING)
	progress_label.visible = (_state == State.ANALYSING)
	file_select.visible = _state in [State.READY, State.ANALYSING, State.DONE]
	match _state:
		State.NO_CONNECTION:
			status_label.text = "NOT CONNECTED"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
			action_btn.disabled = true
			action_btn.text = "ANALYSE VOICE SAMPLE"
		State.NO_AUDIO:
			status_label.text = "NO AUDIO FILES ON THIS NODE"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			action_btn.disabled = true
			action_btn.text = "ANALYSE VOICE SAMPLE"
		State.READY:
			status_label.text = "TARGET:  %s  —  %d audio file(s)" % [
				node_data.get("ip", "?"), _audio_files.size()
			]
			status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
			action_btn.disabled = file_select.item_count == 0
			action_btn.text = "ANALYSE VOICE SAMPLE"
		State.ANALYSING:
			status_label.text = "PROCESSING VOICE DATA..."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
			action_btn.disabled = true
		State.DONE:
			status_label.text = "ANALYSIS COMPLETE — sample stored"
			status_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
			action_btn.disabled = true
			action_btn.text = "ANALYSE VOICE SAMPLE"


func _setup_theme() -> void:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.75, 0.0)
	analyse_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.12, 0.18)
	analyse_bar.add_theme_stylebox_override("background", bar_bg)
	progress_label.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	action_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
