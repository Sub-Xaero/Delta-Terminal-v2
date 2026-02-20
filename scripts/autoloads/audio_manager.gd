class_name AudioManager
extends Node
## Foundational audio layer.
## Manages SFX pool, ambient loop, audio buses, and EventBus-driven playback.
## All named sounds load from res://assets/sounds/ if present, otherwise fall
## back to synthesised sine-wave tones so every cue works without audio files.

const BUS_SFX     := "SFX"
const BUS_AMBIENT := "Ambient"
const _SFX_POOL_SIZE := 8

# ── Internal nodes ─────────────────────────────────────────────────────────────
var _sfx_pool:       Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer

# ── Synthesised tone cache (name → AudioStreamWAV) ────────────────────────────
var _synth_cache: Dictionary = {}

# ── Trace alert state ─────────────────────────────────────────────────────────
var _trace_amber_played: bool = false
var _trace_red_played:   bool = false


func _ready() -> void:
	_setup_buses()
	_create_players()
	_apply_volumes()
	_connect_signals()
	_start_ambient()


# ── Bus setup ─────────────────────────────────────────────────────────────────

func _setup_buses() -> void:
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")

	if AudioServer.get_bus_index(BUS_AMBIENT) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_AMBIENT)
		AudioServer.set_bus_send(idx, "Master")


# ── Player creation ───────────────────────────────────────────────────────────

func _create_players() -> void:
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = BUS_AMBIENT
	add_child(_ambient_player)


# ── Volume ────────────────────────────────────────────────────────────────────

func _apply_volumes() -> void:
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	var amb_idx := AudioServer.get_bus_index(BUS_AMBIENT)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_linear(sfx_idx, SettingsManager.sfx_volume)
	if amb_idx >= 0:
		AudioServer.set_bus_volume_linear(amb_idx, SettingsManager.ambient_volume)


# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	SettingsManager.settings_changed.connect(_apply_volumes)

	EventBus.ui_button_pressed.connect(func(): play_sfx("ui_click"))
	EventBus.tool_opened.connect(func(_n: String): play_sfx("ui_window_open"))
	EventBus.tool_closed.connect(func(_n: String): play_sfx("ui_window_close"))
	EventBus.tool_task_started.connect(func(_t: String, _id: String): play_sfx("tool_start"))
	EventBus.tool_task_completed.connect(
		func(_t: String, _id: String, success: bool):
			play_sfx("tool_complete" if success else "tool_fail")
	)
	EventBus.network_connected.connect(func(_id: String): play_sfx("network_connect"))
	EventBus.network_disconnected.connect(func(): play_sfx("network_disconnect"))
	EventBus.trace_started.connect(_on_trace_started)
	EventBus.trace_progress.connect(_on_trace_progress)
	EventBus.trace_completed.connect(func(): play_sfx("trace_busted"))


# ── Trace alert escalation ────────────────────────────────────────────────────

func _on_trace_started(_duration: float) -> void:
	_trace_amber_played = false
	_trace_red_played   = false


func _on_trace_progress(p: float) -> void:
	if not _trace_amber_played and p >= 0.5:
		_trace_amber_played = true
		play_sfx("trace_warn")
	if not _trace_red_played and p >= 0.8:
		_trace_red_played = true
		play_sfx("trace_critical")


# ── Public API ────────────────────────────────────────────────────────────────

## Play a one-shot SFX by name. Finds a free pool player; interrupts the oldest
## if all 8 are busy. Silently skips unknown names.
func play_sfx(sound_name: String) -> void:
	var stream := _get_stream(sound_name)
	if stream == null:
		return
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# All busy — interrupt first player
	_sfx_pool[0].stream = stream
	_sfx_pool[0].play()


## Play a looping ambient track by name. Silently skips if file not found.
func play_ambient(sound_name: String) -> void:
	var stream := _get_stream(sound_name)
	if stream == null:
		return
	_ambient_player.stream = stream
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()


## Convenience alias for shell tool keystroke sounds.
func play_keystroke() -> void:
	play_sfx("keystroke")


# ── Sound loading ─────────────────────────────────────────────────────────────

func _start_ambient() -> void:
	play_ambient("ambient_drone")


func _get_stream(sound_name: String) -> AudioStream:
	if _synth_cache.has(sound_name):
		return _synth_cache[sound_name]

	# Try loading from assets/sounds/ (swap-in point for real audio)
	for ext: String in ["ogg", "wav", "mp3"]:
		var path := "res://assets/sounds/%s.%s" % [sound_name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream

	# Fall back to synthesised tone
	return _synth_tone(sound_name)


# ── Procedural tone synthesis ─────────────────────────────────────────────────

func _synth_tone(sound_name: String) -> AudioStreamWAV:
	var freq:   float
	var dur:    float
	var volume: float = 0.3

	match sound_name:
		"ui_click":          freq = 800.0;  dur = 0.05
		"ui_window_open":    freq = 600.0;  dur = 0.12
		"ui_window_close":   freq = 400.0;  dur = 0.10
		"tool_start":        freq = 700.0;  dur = 0.15
		"tool_complete":     freq = 900.0;  dur = 0.20
		"tool_fail":         freq = 300.0;  dur = 0.25
		"network_connect":   freq = 750.0;  dur = 0.18
		"network_disconnect":freq = 250.0;  dur = 0.20
		"trace_warn":        freq = 1000.0; dur = 0.30; volume = 0.5
		"trace_critical":    freq = 1400.0; dur = 0.40; volume = 0.6
		"trace_busted":      freq = 200.0;  dur = 0.80; volume = 0.7
		"keystroke":         freq = 1200.0; dur = 0.03; volume = 0.2
		_:
			return null   # ambient_drone and unknowns: skip gracefully

	var stream := _generate_beep(freq, dur, volume)
	_synth_cache[sound_name] = stream
	return stream


func _generate_beep(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 44100
	var samples := int(SAMPLE_RATE * duration)
	var data    := PackedByteArray()
	data.resize(samples * 2)   # 16-bit mono

	for i in samples:
		var t        := float(i) / float(SAMPLE_RATE)
		var envelope := 1.0 - (float(i) / float(samples))   # linear fade-out
		var sample   := int(sin(TAU * frequency * t) * envelope * volume * 32767.0)
		data.encode_s16(i * 2, clampi(sample, -32768, 32767))

	var stream         := AudioStreamWAV.new()
	stream.format      = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo      = false
	stream.mix_rate    = SAMPLE_RATE
	stream.data        = data
	return stream
