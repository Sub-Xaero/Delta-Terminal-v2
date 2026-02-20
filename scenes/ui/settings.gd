class_name Settings
extends ToolWindow
## In-game settings panel. Extends ToolWindow so it docks naturally on the
## desktop via WindowManager, and can also be shown as a free overlay from
## the main menu.
##
## Audio / Display / Gameplay tabs. All changes apply immediately and are
## persisted to user://settings.cfg via SettingsManager.

const _C_CYAN  := Color(0.0,  0.88, 1.0)
const _C_MUTED := Color(0.35, 0.35, 0.45)
const _C_TEXT  := Color(0.75, 0.92, 1.0)
const _C_BG    := Color(0.04, 0.03, 0.10, 0.95)
const _C_TITLE := Color(0.06, 0.04, 0.14)


func _ready() -> void:
	tool_name = "Settings"
	super._ready()
	_build_content()


# ── Build ──────────────────────────────────────────────────────────────────────

func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom", 10)
	content_area.add_child(margin)

	var tabs := TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_theme_color_override("font_selected_color",   _C_CYAN)
	tabs.add_theme_color_override("font_unselected_color", _C_MUTED)
	margin.add_child(tabs)

	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_display_tab())
	tabs.add_child(_build_gameplay_tab())


func _build_audio_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "Audio"
	vbox.add_theme_constant_override("separation", 12)
	var m := _wrap_margin(vbox)

	_add_slider(m, "Master Volume",  SettingsManager.master_volume,
		func(v: float): SettingsManager.set_master_volume(v))
	_add_slider(m, "SFX Volume",     SettingsManager.sfx_volume,
		func(v: float): SettingsManager.set_sfx_volume(v))
	_add_slider(m, "Ambient Volume", SettingsManager.ambient_volume,
		func(v: float): SettingsManager.set_ambient_volume(v))

	return m


func _build_display_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "Display"
	vbox.add_theme_constant_override("separation", 12)
	var m := _wrap_margin(vbox)

	_add_checkbox(m, "CRT Shader",   SettingsManager.crt_enabled,
		func(v: bool): SettingsManager.set_crt_enabled(v))
	_add_slider(m,   "CRT Intensity", SettingsManager.crt_intensity,
		func(v: float): SettingsManager.set_crt_intensity(v))
	_add_checkbox(m, "Fullscreen",   SettingsManager.fullscreen,
		func(v: bool): SettingsManager.set_fullscreen(v))

	return m


func _build_gameplay_tab() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.name = "Gameplay"
	vbox.add_theme_constant_override("separation", 12)
	var m := _wrap_margin(vbox)

	_add_checkbox(m, "Autosave", SettingsManager.autosave,
		func(v: bool): SettingsManager.set_autosave(v))

	return m


# ── Widget helpers ─────────────────────────────────────────────────────────────

func _wrap_margin(inner: VBoxContainer) -> VBoxContainer:
	inner.add_theme_constant_override("margin_left",   12)
	inner.add_theme_constant_override("margin_top",    12)
	inner.add_theme_constant_override("margin_right",  12)
	inner.add_theme_constant_override("margin_bottom", 12)
	return inner


func _add_slider(parent: VBoxContainer, label_text: String, init_val: float,
		callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", _C_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value  = 0.0
	slider.max_value  = 1.0
	slider.step       = 0.05
	slider.value      = init_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(callback)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.0f%%" % (init_val * 100)
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_color_override("font_color", _C_MUTED)
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)

	# Keep the percentage label in sync
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.0f%%" % (v * 100))


func _add_checkbox(parent: VBoxContainer, label_text: String, init_val: bool,
		callback: Callable) -> void:
	var check := CheckBox.new()
	check.text            = label_text
	check.button_pressed  = init_val
	check.add_theme_color_override("font_color", _C_TEXT)
	check.add_theme_font_size_override("font_size", 12)
	check.toggled.connect(callback)
	parent.add_child(check)
