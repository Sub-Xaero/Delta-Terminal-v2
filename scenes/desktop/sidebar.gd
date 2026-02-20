class_name Sidebar
extends Panel
## Persistent right-side panel: network minimap + connection status + hardware monitors.
## Not a ToolWindow — always visible, never spawned by WindowManager.

@onready var minimap: SidebarMinimap   = $MarginContainer/VBoxContainer/MinimapContainer/NetworkMinimap
@onready var minimap_container: Panel  = $MarginContainer/VBoxContainer/MinimapContainer
@onready var conn_label: Label         = $MarginContainer/VBoxContainer/ConnLabel
@onready var disconnect_btn: Button    = $MarginContainer/VBoxContainer/DisconnectBtn
@onready var _widget_slots: VBoxContainer = $MarginContainer/VBoxContainer/WidgetSlots

var _connected_id: String = ""
var _pulse_timer: float = 0.0

# ── Hardware monitor refs ──────────────────────────────────────────────────────
var _ram_bar:        ProgressBar  = null
var _ram_val_label:  Label        = null
var _ram_fill_style: StyleBoxFlat = null
var _cpu_bar:        ProgressBar  = null
var _cpu_val_label:  Label        = null
var _cpu_fill_style: StyleBoxFlat = null


func _ready() -> void:
	_apply_theme()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.bounce_chain_updated.connect(_on_bounce_chain_updated)
	EventBus.hardware_changed.connect(_update_monitors)
	EventBus.tool_opened.connect(func(_n: String): _update_monitors())
	EventBus.tool_closed.connect(func(_n: String): _update_monitors())
	_build_hardware_section()


func _process(delta: float) -> void:
	if _connected_id.is_empty():
		return
	_pulse_timer += delta * 2.2
	conn_label.modulate = Color(1, 1, 1, 0.65 + 0.35 * abs(sin(_pulse_timer)))


func _apply_theme() -> void:
	# Sidebar background — left seam glows cyan
	var style := StyleBoxFlat.new()
	style.bg_color      = Color(0.04, 0.03, 0.10, 0.97)
	style.border_color  = Color(0.0, 0.88, 1.0)
	style.border_width_left = 1
	style.shadow_color  = Color(0.0, 0.88, 1.0, 0.25)
	style.shadow_size   = 10
	add_theme_stylebox_override("panel", style)

	disconnect_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	disconnect_btn.pressed.connect(_on_conn_btn_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	disconnect_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.0, 0.88, 1.0, 0.08)
	disconnect_btn.add_theme_stylebox_override("hover", btn_hover)

	$MarginContainer/VBoxContainer/SectionLabel.text = "// NETWORK //"

	# Minimap container border + glow
	var map_style := StyleBoxFlat.new()
	map_style.bg_color     = Color(0.02, 0.02, 0.06)
	map_style.border_color = Color(0.0, 0.88, 1.0)
	map_style.set_border_width_all(1)
	map_style.shadow_color = Color(0.0, 0.88, 1.0, 0.15)
	map_style.shadow_size  = 3
	minimap_container.add_theme_stylebox_override("panel", map_style)


# ── Hardware monitors ─────────────────────────────────────────────────────────

func _build_hardware_section() -> void:
	var section_lbl := Label.new()
	section_lbl.text = "// HARDWARE //"
	section_lbl.add_theme_font_size_override("font_size", 9)
	section_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_widget_slots.add_child(section_lbl)

	var sep := HSeparator.new()
	_widget_slots.add_child(sep)

	_widget_slots.add_child(_build_monitor_row("MEM"))
	_widget_slots.add_child(_build_monitor_row("CPU"))
	_update_monitors()


func _build_monitor_row(tag: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.custom_minimum_size = Vector2(28, 0)
	tag_lbl.add_theme_font_size_override("font_size", 9)
	tag_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	hbox.add_child(tag_lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size   = Vector2(0, 6)
	bar.max_value     = 1.0
	bar.min_value     = 0.0
	bar.show_percentage = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.88, 1.0)
	fill_style.corner_radius_top_left     = 2
	fill_style.corner_radius_top_right    = 2
	fill_style.corner_radius_bottom_left  = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color     = Color(0.04, 0.06, 0.10)
	bg_style.border_color = Color(0.0, 0.88, 1.0, 0.25)
	bg_style.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg_style)
	hbox.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_lbl.add_theme_font_size_override("font_size", 9)
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


func _update_monitors() -> void:
	if _ram_bar == null:
		return

	# ── RAM ───────────────────────────────────────────────────────────────────
	var ram_used: int  = HardwareManager.ram_used
	var ram_cap:  int  = HardwareManager.ram_capacity
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


func _monitor_color(pct: float) -> Color:
	if pct < 0.6:
		return Color(0.0, 0.88, 1.0)   # cyan — low load
	elif pct < 0.85:
		return Color(1.0, 0.75, 0.0)   # amber — moderate
	else:
		return Color(1.0, 0.08, 0.55)  # hot pink — critical


# ── EventBus reactions ─────────────────────────────────────────────────────────

func _on_conn_btn_pressed() -> void:
	if _connected_id != "":
		NetworkSim.disconnect_from_node()
	else:
		EventBus.open_tool_requested.emit("Network Map")


func _on_network_connected(node_id: String) -> void:
	_connected_id = node_id
	var data := NetworkSim.get_node_data(node_id)
	conn_label.text = data.get("ip", node_id)
	conn_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	disconnect_btn.text = "[ DISCONNECT ]"
	disconnect_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	minimap.connected_id = node_id
	minimap.queue_redraw()


func _on_network_disconnected() -> void:
	_connected_id = ""
	conn_label.text = "OFFLINE"
	conn_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	conn_label.modulate = Color(1, 1, 1, 1)
	_pulse_timer = 0.0
	disconnect_btn.text = "[ CONNECT ]"
	disconnect_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	minimap.connected_id = ""
	minimap.queue_redraw()


func _on_bounce_chain_updated(chain: Array) -> void:
	minimap.bounce_chain = chain
	minimap.queue_redraw()
