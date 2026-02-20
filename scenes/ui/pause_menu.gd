class_name PauseMenu
extends Control
## Full-screen modal pause overlay.
## process_mode is ALWAYS so input is received while the scene tree is paused.

const SettingsScene := preload("res://scenes/ui/settings.tscn")

const _C_CYAN  := Color(0.0,  0.88, 1.0)
const _C_PINK  := Color(1.0,  0.08, 0.55)
const _C_MUTED := Color(0.35, 0.35, 0.45)
const _C_TEXT  := Color(0.75, 0.92, 1.0)
const _C_BG    := Color(0.04, 0.03, 0.10, 0.97)
const _C_TITLE := Color(0.06, 0.04, 0.14)

var _save_label:   Label
var _settings_win: ToolWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_build_ui()


# ── Build ──────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Centred container
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	# Panel
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = _C_BG
	bg_style.border_color = _C_CYAN
	bg_style.set_border_width_all(1)
	bg_style.set_content_margin_all(28.0)
	bg_style.shadow_color = Color(_C_CYAN, 0.18)
	bg_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", bg_style)
	centre.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "// PAUSED //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", _C_CYAN)
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(_C_CYAN, 0.4))
	vbox.add_child(sep)

	vbox.add_child(_spacer(4))

	# Buttons
	var resume_btn := _make_btn("[ RESUME ]", _C_CYAN)
	resume_btn.pressed.connect(_resume)
	vbox.add_child(resume_btn)

	var save_btn := _make_btn("[ SAVE GAME ]", _C_CYAN)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	var settings_btn := _make_btn("[ SETTINGS ]", _C_MUTED)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	var quit_btn := _make_btn("[ QUIT TO MENU ]", _C_PINK)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# Save confirmation label (hidden by default)
	_save_label = Label.new()
	_save_label.text = "Game saved."
	_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_label.add_theme_font_size_override("font_size", 11)
	_save_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	_save_label.visible = false
	vbox.add_child(_save_label)


# ── Toggle ─────────────────────────────────────────────────────────────────────

func toggle() -> void:
	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	show()
	get_tree().paused = true


func _resume() -> void:
	hide()
	get_tree().paused = false


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()


# ── Button handlers ────────────────────────────────────────────────────────────

func _on_save_pressed() -> void:
	SaveManager.save_game()
	EventBus.log_message.emit("Game saved.", "info")
	_save_label.visible = true
	_save_label.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_save_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _save_label.visible = false)


func _on_settings_pressed() -> void:
	if _settings_win and is_instance_valid(_settings_win):
		return
	_settings_win = SettingsScene.instantiate()
	add_child(_settings_win)
	_settings_win.position = (size - _settings_win.custom_minimum_size) * 0.5


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_btn(label_text: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", Color(col.r, col.g, col.b, 0.75))
	var n_style := StyleBoxFlat.new()
	n_style.bg_color = _C_TITLE
	n_style.border_color = col
	n_style.set_border_width_all(1)
	n_style.set_content_margin_all(8.0)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(col.r * 0.18, col.g * 0.18, col.b * 0.18)
	h_style.border_color = col
	h_style.set_border_width_all(1)
	h_style.set_content_margin_all(8.0)
	var d_style := n_style.duplicate()
	d_style.border_color = _C_MUTED
	btn.add_theme_stylebox_override("normal",   n_style)
	btn.add_theme_stylebox_override("hover",    h_style)
	btn.add_theme_stylebox_override("pressed",  h_style)
	btn.add_theme_stylebox_override("focus",    n_style)
	btn.add_theme_stylebox_override("disabled", d_style)
	return btn


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
