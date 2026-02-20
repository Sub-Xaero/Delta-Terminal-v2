class_name Taskbar
extends Panel
## Taskbar / dock showing open tool buttons and a system clock.
## Reacts to EventBus.tool_opened / tool_closed / hardware_changed.

@onready var task_items: HBoxContainer = $TaskItems
@onready var clock_label: Label = $ClockLabel

# tool_name -> Button
var _task_buttons: Dictionary = {}

# ── Monitor widget refs ────────────────────────────────────────────────────────
var _ram_bar:        ProgressBar    = null
var _ram_val_label:  Label          = null
var _ram_fill_style: StyleBoxFlat   = null
var _cpu_bar:        ProgressBar    = null
var _cpu_val_label:  Label          = null
var _cpu_fill_style: StyleBoxFlat   = null


func _ready() -> void:
	EventBus.tool_opened.connect(_on_tool_opened)
	EventBus.tool_closed.connect(_on_tool_closed)
	EventBus.hardware_changed.connect(_update_monitors)
	_apply_theme()
	_update_clock()
	_add_launch_button()
	_add_pc_button()


func _add_launch_button() -> void:
	var btn := Button.new()
	btn.text = "[ LAUNCH ]"
	_style_button(btn, Color(1.0, 0.08, 0.55))
	btn.pressed.connect(func():
		EventBus.context_menu_requested.emit(btn.global_position + Vector2(0.0, -4.0))
	)
	task_items.add_child(btn)
	# Separator to visually divide launch button from tool buttons
	var sep := VSeparator.new()
	task_items.add_child(sep)


func _style_button(btn: Button, color: Color) -> void:
	btn.add_theme_color_override("font_color", color)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.04, 0.03, 0.10)
	n.border_color = Color(color.r, color.g, color.b, 0.5)
	n.set_border_width_all(1)
	n.set_content_margin_all(4.0)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.0, 0.1, 0.15)
	h.border_color = color
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   n)


func _add_pc_button() -> void:
	var btn := Button.new()
	btn.text = "[ PC ]"
	_style_button(btn, Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func(): EventBus.open_tool_requested.emit("Hardware Viewer"))
	task_items.add_child(btn)

	task_items.add_child(_build_monitor_widget("MEM"))
	task_items.add_child(_build_monitor_widget("CPU"))
	_update_monitors()

	var sep := VSeparator.new()
	task_items.add_child(sep)


## Builds a compact tag + bar + value widget. Stores refs in _ram_* or _cpu_* vars.
func _build_monitor_widget(tag: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	hbox.add_child(tag_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(52, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 1.0
	bar.min_value = 0.0
	bar.show_percentage = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.88, 1.0)
	fill_style.corner_radius_top_left    = 2
	fill_style.corner_radius_top_right   = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.06, 0.10)
	bg_style.border_color = Color(0.0, 0.88, 1.0, 0.25)
	bg_style.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg_style)
	hbox.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	hbox.add_child(val_lbl)

	if tag == "MEM":
		_ram_bar        = bar
		_ram_val_label  = val_lbl
		_ram_fill_style = fill_style
	else:
		_cpu_bar        = bar
		_cpu_val_label  = val_lbl
		_cpu_fill_style = fill_style

	return hbox


func _process(_delta: float) -> void:
	_update_clock()


func _apply_theme() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.10)
	style.border_color = Color(0.0, 0.88, 1.0)
	style.border_width_top = 1
	style.shadow_color = Color(0.0, 0.88, 1.0, 0.25)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)

	clock_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	clock_label.text = "[ %02d:%02d:%02d ]" % [t.hour, t.minute, t.second]


func _update_monitors() -> void:
	if _ram_bar == null:
		return

	# ── RAM ───────────────────────────────────────────────────────────────────
	var ram_used: int = HardwareManager.ram_used
	var ram_cap:  int = HardwareManager.ram_capacity
	var ram_pct: float = float(ram_used) / maxf(1.0, float(ram_cap))
	_ram_fill_style.bg_color = _monitor_color(ram_pct)
	_ram_bar.value           = ram_pct
	_ram_val_label.text      = "%d/%d" % [ram_used, ram_cap]

	# ── CPU ───────────────────────────────────────────────────────────────────
	var cpu_speed:  float = HardwareManager.installed_cpu.get("cpu_speed", 1.0)
	var hack_count: int   = HardwareManager.active_hack_count
	var cpu_load: float   = minf(1.0, float(hack_count) / maxf(1.0, cpu_speed))
	_cpu_fill_style.bg_color = _monitor_color(cpu_load)
	_cpu_bar.value           = cpu_load
	_cpu_val_label.text      = "%.1fx" % HardwareManager.effective_cpu_speed


## Returns cyan / amber / hot-pink depending on load level.
func _monitor_color(pct: float) -> Color:
	if pct < 0.6:
		return Color(0.0, 0.88, 1.0)   # cyan — low load
	elif pct < 0.85:
		return Color(1.0, 0.75, 0.0)   # amber — moderate
	else:
		return Color(1.0, 0.08, 0.55)  # hot pink — critical


func _on_tool_opened(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		return

	var btn := Button.new()
	btn.text = "[ %s ]" % p_tool_name
	_style_button(btn, Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func(): EventBus.tool_focus_requested.emit(p_tool_name))
	task_items.add_child(btn)
	_task_buttons[p_tool_name] = btn
	_update_monitors()


func _on_tool_closed(p_tool_name: String) -> void:
	if _task_buttons.has(p_tool_name):
		_task_buttons[p_tool_name].queue_free()
		_task_buttons.erase(p_tool_name)
	_update_monitors()
