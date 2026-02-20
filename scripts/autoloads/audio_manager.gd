class_name AudioManagerClass
extends Node
## Event-driven audio system. Manages SFX pool, ambient loop, bus volumes,
## and auto-wires UI buttons. Reads volumes from SettingsManager.

# ── Constants & streams ───────────────────────────────────────────────────────

const _SOUNDS_DIR := "res://assets/sounds/"
const _POOL_SIZE   := 4

const _SFX_MAP: Dictionary = {
	"network_connect":    "network_connect.wav",
	"network_disconnect": "network_disconnect.wav",
	"trace_start":        "trace_start.wav",
	"trace_complete":     "trace_complete.wav",
	"task_success":       "task_success.wav",
	"task_fail":          "task_fail.wav",
	"error_log":          "error_log.wav",
	"node_discovered":    "node_discovered.wav",
	"comms_received":     "comms_received.wav",
	"ui_click":           "ui_click.wav",
	"ui_hover":           "ui_hover.wav",
	"ambient_drone":      "ambient_drone.wav",
}

# ── Private state ─────────────────────────────────────────────────────────────

var _streams:      Dictionary = {}   # key → AudioStream (or null)
var _sfx_pool:     Array      = []   # Array[AudioStreamPlayer]
var _ambient:      AudioStreamPlayer
var _pool_index:   int  = 0
var _muted:        bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_buses()
	_build_pool()
	_load_streams()
	_connect_event_bus()
	get_tree().node_added.connect(_on_node_added)
	SettingsManager.settings_changed.connect(_apply_all_volumes)
	_apply_all_volumes()


# ── Public API ────────────────────────────────────────────────────────────────

func play_sfx(key: String) -> void:
	if _muted:
		return
	var stream: AudioStream = _streams.get(key, null)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_pool_index]
	player.stream = stream
	player.play()
	_pool_index = (_pool_index + 1) % _POOL_SIZE


func set_ambient(key: String) -> void:
	var stream: AudioStream = _streams.get(key, null)
	if stream == null:
		return
	_ambient.stream = stream
	_ambient.play()


func toggle_mute() -> void:
	_muted = not _muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)


# ── Bus management ────────────────────────────────────────────────────────────

func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus()
		var amb_idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(amb_idx, "Ambient")
		AudioServer.set_bus_send(amb_idx, "Master")


func _apply_all_volumes() -> void:
	var master_idx  := AudioServer.get_bus_index("Master")
	var sfx_idx     := AudioServer.get_bus_index("SFX")
	var ambient_idx := AudioServer.get_bus_index("Ambient")
	if master_idx  >= 0:
		AudioServer.set_bus_volume_linear(master_idx,  SettingsManager.master_volume)
	if sfx_idx     >= 0:
		AudioServer.set_bus_volume_linear(sfx_idx,     SettingsManager.sfx_volume)
	if ambient_idx >= 0:
		AudioServer.set_bus_volume_linear(ambient_idx, SettingsManager.ambient_volume)


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	EventBus.network_connected.connect(func(_id: String) -> void: play_sfx("network_connect"))
	EventBus.network_disconnected.connect(func() -> void: play_sfx("network_disconnect"))
	EventBus.trace_started.connect(func(_dur: float) -> void: play_sfx("trace_start"))
	EventBus.trace_completed.connect(func() -> void: play_sfx("trace_complete"))
	EventBus.tool_task_completed.connect(_on_tool_task_completed)
	EventBus.log_message.connect(_on_log_message)
	EventBus.node_discovered.connect(func(_id: String) -> void: play_sfx("node_discovered"))
	EventBus.comms_message_received.connect(func(_id: String) -> void: play_sfx("comms_received"))


func _on_tool_task_completed(_tool_name: String, _task_id: String, success: bool) -> void:
	play_sfx("task_success" if success else "task_fail")


func _on_log_message(_text: String, level: String) -> void:
	if level == "error":
		play_sfx("error_log")


# ── UI auto-wiring ────────────────────────────────────────────────────────────

func _on_node_added(node: Node) -> void:
	if node is Button:
		if not node.pressed.is_connected(_on_ui_click):
			node.pressed.connect(_on_ui_click)
		if not node.mouse_entered.is_connected(_on_ui_hover):
			node.mouse_entered.connect(_on_ui_hover)
	if node is OptionButton:
		if not node.item_selected.is_connected(_on_ui_item_selected):
			node.item_selected.connect(_on_ui_item_selected)


func _on_ui_click() -> void:
	play_sfx("ui_click")


func _on_ui_hover() -> void:
	play_sfx("ui_hover")


func _on_ui_item_selected(_index: int) -> void:
	play_sfx("ui_click")


# ── Internal helpers ──────────────────────────────────────────────────────────

func _build_pool() -> void:
	for i: int in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	_ambient.finished.connect(func() -> void:
		if _ambient.stream != null:
			_ambient.play()
	)
	add_child(_ambient)


func _load_streams() -> void:
	for key: String in _SFX_MAP:
		_streams[key] = _load_stream(_SFX_MAP[key])


func _load_stream(filename: String) -> AudioStream:
	var path := _SOUNDS_DIR + filename
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
