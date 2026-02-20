class_name BlinkingCursor
extends Node
## Utility that appends a blinking cursor character to a target Label.
## Add as a child node, call set_target() and set_base_text() to activate.

@export var blink_rate: float = 0.53
@export var cursor_char: String = "█"

var _label: Label
var _base_text: String = ""
var _visible_cursor: bool = true
var _timer: float = 0.0


func set_target(label: Label) -> void:
	_label = label
	_base_text = label.text


func set_base_text(text: String) -> void:
	_base_text = text
	_refresh()


func _process(delta: float) -> void:
	if not _label:
		return
	_timer += delta
	if _timer >= blink_rate:
		_timer = fmod(_timer, blink_rate)
		_visible_cursor = not _visible_cursor
		_refresh()


func _refresh() -> void:
	_label.text = _base_text + (cursor_char if _visible_cursor else " ")
