class_name TutorialToast
extends Panel
## Bottom-right toast layer rendering tutorial hints from TutorialManager.
## Toasts auto-dismiss after 6 seconds, do not block interaction, and stack
## vertically when multiple hints fire in quick succession.

const TOAST_LIFETIME := 6.0
const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_BG    := Color(0.04, 0.03, 0.10, 0.96)

@onready var _stack: VBoxContainer = $Margin/Stack


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_theme()
	TutorialManager.hint_fired.connect(_on_hint)


func _on_hint(_id: String, title: String, text: String) -> void:
	var toast := _build_toast(title, text)
	_stack.add_child(toast)
	var timer := get_tree().create_timer(TOAST_LIFETIME)
	timer.timeout.connect(toast.queue_free)


func _build_toast(title: String, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.border_color = COL_AMBER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(1.0, 0.75, 0.0, 0.20)
	style.shadow_size = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title.to_upper()
	title_lbl.add_theme_color_override("font_color", COL_AMBER)
	title_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title_lbl)

	var text_lbl := Label.new()
	text_lbl.text = text
	text_lbl.add_theme_color_override("font_color", COL_CYAN)
	text_lbl.add_theme_font_size_override("font_size", 10)
	text_lbl.custom_minimum_size = Vector2(280, 0)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_lbl)

	return panel


func _apply_theme() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
