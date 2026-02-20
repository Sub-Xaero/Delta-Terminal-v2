class_name SystemLog
extends ToolWindow
## Read-only activity feed. Listens to EventBus.log_message and displays
## timestamped, colour-coded entries. Opened by default on the desktop.

const MAX_ENTRIES := 200

const COLOUR_INFO  := Color(0.0,  0.88, 1.0)   # cyan
const COLOUR_WARN  := Color(1.0,  0.75, 0.0)   # amber
const COLOUR_ERROR := Color(1.0,  0.08, 0.55)  # hot pink

@onready var scroll: ScrollContainer = $ContentArea/ScrollContainer
@onready var log_container: VBoxContainer = $ContentArea/ScrollContainer/LogContainer

var _at_bottom: bool = true


func _ready() -> void:
	super._ready()
	EventBus.log_message.connect(_on_log_message)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	EventBus.log_message.emit("System Log online.", "info")


func _on_log_message(text: String, level: String) -> void:
	var colour := COLOUR_INFO
	match level:
		"warn":  colour = COLOUR_WARN
		"error": colour = COLOUR_ERROR

	var prefix := "  "
	match level:
		"warn":  prefix = "▲ "
		"error": prefix = "✕ "

	var t := Time.get_time_dict_from_system()
	var label := Label.new()
	label.text = "[%02d:%02d:%02d]  %s%s" % [t.hour, t.minute, t.second, prefix, text]
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if level == "error":
		var wrapper := PanelContainer.new()
		var ws := StyleBoxFlat.new()
		ws.bg_color = Color(1.0, 0.08, 0.55, 0.05)
		ws.set_border_width_all(0)
		ws.border_width_left = 2
		ws.border_color = Color(1.0, 0.08, 0.55)
		wrapper.add_theme_stylebox_override("panel", ws)
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.add_child(label)
		log_container.add_child(wrapper)
	else:
		log_container.add_child(label)

	# Prune oldest entries to stay under cap
	while log_container.get_child_count() > MAX_ENTRIES:
		log_container.get_child(0).queue_free()

	if _at_bottom:
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _on_scroll_changed(value: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	_at_bottom = value >= bar.max_value - bar.page
