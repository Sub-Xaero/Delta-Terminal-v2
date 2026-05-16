class_name NewsTicker
extends Panel
## Scrolling horizontal news ticker. Listens to EventBus.news_headline_added,
## interleaves background lore from data/news_lore.json, and keeps a bounded
## history of up to 50 headlines.

const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_PINK  := Color(1.0,  0.08, 0.55)
const LORE_PATH := "res://data/news_lore.json"
const MAX_HISTORY := 50
const PIXELS_PER_SECOND := 60.0
const PADDING_PX := 240.0

@onready var clip:  Control = $Clip
@onready var label: Label   = $Clip/Label

var _queue: Array[String] = []
var _history: Array[String] = []
var _lore: Array[String] = []
var _lore_index: int = 0
var _current_text: String = ""
var _scroll_offset: float = 0.0


func _ready() -> void:
	_load_lore()
	_apply_theme()
	EventBus.news_headline_added.connect(_on_headline)
	_advance_to_next()


func _process(delta: float) -> void:
	if _current_text.is_empty():
		return
	_scroll_offset -= PIXELS_PER_SECOND * delta
	label.position.x = clip.size.x + _scroll_offset
	if label.position.x + label.size.x < 0.0:
		_advance_to_next()


func _on_headline(text: String) -> void:
	_history.push_back(text)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	_queue.push_back(text)


func _advance_to_next() -> void:
	var next_text: String
	if not _queue.is_empty():
		next_text = _queue.pop_front()
		label.add_theme_color_override("font_color", COL_AMBER)
	elif not _lore.is_empty():
		next_text = _lore[_lore_index % _lore.size()]
		_lore_index += 1
		label.add_theme_color_override("font_color", COL_CYAN)
	else:
		next_text = ""
	_current_text = next_text
	label.text = next_text
	label.position.x = clip.size.x
	label.size.x = max(800.0, label.get_minimum_size().x + PADDING_PX)
	_scroll_offset = 0.0


func _load_lore() -> void:
	var f := FileAccess.open(LORE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for entry in parsed:
			if entry is String:
				_lore.append(entry)


func _apply_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.06, 0.92)
	style.border_color = COL_CYAN
	style.border_width_top = 1
	style.border_width_bottom = 1
	add_theme_stylebox_override("panel", style)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COL_CYAN)


func get_history() -> Array[String]:
	return _history.duplicate()
