class_name TraceTracker
extends ToolWindow
## Passive trace monitor. Displays the active trace progress and bounce chain.
## Any tool that starts a trace (password cracker, firewall bypasser, etc.)
## feeds it automatically via EventBus — this tool owns no game logic.

enum State { INACTIVE, ACTIVE, COMPLETE }

@onready var status_label: Label       = $ContentArea/Margin/VBox/StatusLabel
@onready var trace_pct:    Label       = $ContentArea/Margin/VBox/TracePct
@onready var trace_bar:    ProgressBar = $ContentArea/Margin/VBox/TraceBar
@onready var chain_label:  Label       = $ContentArea/Margin/VBox/ChainLabel

var _state:      State        = State.INACTIVE
var _trace_fill: StyleBoxFlat


func _ready() -> void:
	super._ready()
	EventBus.trace_started.connect(_on_trace_started)
	EventBus.trace_progress.connect(_on_trace_progress)
	EventBus.trace_completed.connect(_on_trace_completed)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.bounce_chain_updated.connect(_on_bounce_chain_updated)
	_setup_theme()
	_update_ui()


func _on_trace_started(_duration: float) -> void:
	_state = State.ACTIVE
	trace_bar.value = 0.0
	trace_pct.text  = "TRACE:  0%"
	_trace_fill.bg_color = Color(0.0, 0.88, 1.0)
	_update_ui()


func _on_trace_progress(p: float) -> void:
	trace_bar.value      = p * 100.0
	trace_pct.text       = "TRACE:  %d%%" % roundi(p * 100.0)
	_trace_fill.bg_color = _trace_colour(p)


func _on_trace_completed() -> void:
	_state = State.COMPLETE
	trace_bar.value      = 100.0
	_trace_fill.bg_color = Color(1.0, 0.08, 0.55)
	_update_ui()


func _on_network_disconnected() -> void:
	_state = State.INACTIVE
	trace_bar.value      = 0.0
	trace_pct.text       = "TRACE:  0%"
	chain_label.text     = "ROUTE:  —"
	_trace_fill.bg_color = Color(0.0, 0.88, 1.0)
	_update_ui()


func _on_bounce_chain_updated(chain: Array) -> void:
	chain_label.text = "ROUTE:  —" if chain.is_empty() \
					else "ROUTE:  " + "  →  ".join(chain)


func _update_ui() -> void:
	match _state:
		State.INACTIVE:
			status_label.text = "TRACE STATUS:  INACTIVE"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		State.ACTIVE:
			status_label.text = "TRACE STATUS:  ACTIVE"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
		State.COMPLETE:
			status_label.text = "TRACE STATUS:  COMPLETE"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))


func _trace_colour(progress: float) -> Color:
	if progress < 0.5:
		return Color(0.0, 0.88, 1.0)
	if progress < 0.8:
		var t: float = (progress - 0.5) / 0.3
		return Color(0.0, 0.88, 1.0).lerp(Color(1.0, 0.75, 0.0), t)
	var t: float = (progress - 0.8) / 0.2
	return Color(1.0, 0.75, 0.0).lerp(Color(1.0, 0.08, 0.55), t)


func _setup_theme() -> void:
	_trace_fill = StyleBoxFlat.new()
	_trace_fill.bg_color = Color(0.0, 0.88, 1.0)
	trace_bar.add_theme_stylebox_override("fill", _trace_fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.12, 0.18)
	trace_bar.add_theme_stylebox_override("background", bg)
	for lbl: Label in [status_label, trace_pct, chain_label]:
		lbl.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
