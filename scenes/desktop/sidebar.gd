class_name Sidebar
extends Panel
## Persistent right-side panel: network minimap + connection status + hardware monitors + trace.
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

# ── Heat indicator refs ────────────────────────────────────────────────────────
var _heat_val_label:  Label        = null
var _heat_bar:        ProgressBar  = null
var _heat_bar_fill:   StyleBoxFlat = null

# ── Trace monitor refs ─────────────────────────────────────────────────────────
enum TraceState { INACTIVE, ACTIVE, COMPLETE }
var _trace_state:      TraceState   = TraceState.INACTIVE
var _trace_status_lbl: Label        = null
var _trace_bar:        ProgressBar  = null
var _trace_bar_fill:   StyleBoxFlat = null
var _trace_route_lbl:  Label        = null
var _trace_flicker:    float        = 0.0

# ── Faction rep refs ──────────────────────────────────────────────────────────
var _faction_rows: Dictionary = {}   # faction_id -> { label: Label, bar: ProgressBar, fill: StyleBoxFlat, val: Label }


func _ready() -> void:
	_apply_theme()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	EventBus.bounce_chain_updated.connect(_on_bounce_chain_updated)
	EventBus.hardware_changed.connect(_update_monitors)
	EventBus.tool_opened.connect(func(_n: String): _update_monitors())
	EventBus.tool_closed.connect(func(_n: String): _update_monitors())
	EventBus.trace_started.connect(_on_trace_started)
	EventBus.trace_progress.connect(_on_trace_progress)
	EventBus.trace_completed.connect(_on_trace_completed)
	EventBus.faction_rep_changed.connect(_on_faction_rep_changed)
	EventBus.player_heat_changed.connect(_on_heat_changed)
	_build_hardware_section()
	_build_heat_section()
	_build_trace_section()
	_build_faction_section()


func _process(delta: float) -> void:
	if not _connected_id.is_empty():
		_pulse_timer += delta * 2.2
		conn_label.modulate = Color(1, 1, 1, 0.65 + 0.35 * abs(sin(_pulse_timer)))
	if _trace_state == TraceState.ACTIVE and _trace_status_lbl != null:
		_trace_flicker += delta * 3.5
		_trace_status_lbl.modulate = Color(1, 1, 1, 0.55 + 0.45 * abs(sin(_trace_flicker)))


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
	_widget_slots.add_child(_build_monitor_row("STK"))
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
	else:  # STK
		_cpu_bar        = bar
		_cpu_val_label  = val_lbl
		_cpu_fill_style = fill_style

	return hbox


# ── Heat indicator ────────────────────────────────────────────────────────────

func _build_heat_section() -> void:
	_widget_slots.add_child(HSeparator.new())

	var section_lbl := Label.new()
	section_lbl.text = "// HEAT //"
	section_lbl.add_theme_font_size_override("font_size", 9)
	section_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_widget_slots.add_child(section_lbl)

	_widget_slots.add_child(HSeparator.new())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var tag_lbl := Label.new()
	tag_lbl.text = "HEAT"
	tag_lbl.custom_minimum_size = Vector2(28, 0)
	tag_lbl.add_theme_font_size_override("font_size", 9)
	tag_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	hbox.add_child(tag_lbl)

	_heat_bar = ProgressBar.new()
	_heat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heat_bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_heat_bar.custom_minimum_size   = Vector2(0, 6)
	_heat_bar.max_value     = 100.0
	_heat_bar.min_value     = 0.0
	_heat_bar.show_percentage = false

	_heat_bar_fill = StyleBoxFlat.new()
	_heat_bar_fill.bg_color = Color(0.0, 0.88, 0.4)
	_heat_bar_fill.corner_radius_top_left     = 2
	_heat_bar_fill.corner_radius_top_right    = 2
	_heat_bar_fill.corner_radius_bottom_left  = 2
	_heat_bar_fill.corner_radius_bottom_right = 2
	_heat_bar.add_theme_stylebox_override("fill", _heat_bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color     = Color(0.04, 0.06, 0.10)
	bar_bg.border_color = Color(0.0, 0.88, 1.0, 0.25)
	bar_bg.set_border_width_all(1)
	_heat_bar.add_theme_stylebox_override("background", bar_bg)
	hbox.add_child(_heat_bar)

	_heat_val_label = Label.new()
	_heat_val_label.add_theme_font_size_override("font_size", 9)
	_heat_val_label.add_theme_color_override("font_color", Color(0.0, 0.88, 0.4))
	hbox.add_child(_heat_val_label)

	_widget_slots.add_child(hbox)
	_update_heat_display(GameManager.player_data.get("heat", 0))


func _update_heat_display(heat: int) -> void:
	if _heat_bar == null:
		return
	_heat_bar.value = heat
	_heat_val_label.text = "%d" % heat
	var col: Color
	if heat < 50:
		col = Color(0.0, 0.88, 0.4)     # green
	elif heat < 75:
		col = Color(1.0, 0.75, 0.0)     # amber
	else:
		col = Color(1.0, 0.08, 0.55)    # hot pink
	_heat_bar_fill.bg_color = col
	_heat_val_label.add_theme_color_override("font_color", col)


func _on_heat_changed(new_heat: int) -> void:
	_update_heat_display(new_heat)


func _build_trace_section() -> void:
	_widget_slots.add_child(HSeparator.new())

	var section_lbl := Label.new()
	section_lbl.text = "// TRACE //"
	section_lbl.add_theme_font_size_override("font_size", 9)
	section_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_widget_slots.add_child(section_lbl)

	_widget_slots.add_child(HSeparator.new())

	_trace_status_lbl = Label.new()
	_trace_status_lbl.text = "STATUS:  INACTIVE"
	_trace_status_lbl.add_theme_font_size_override("font_size", 9)
	_trace_status_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	_widget_slots.add_child(_trace_status_lbl)

	_trace_bar = ProgressBar.new()
	_trace_bar.custom_minimum_size = Vector2(0, 6)
	_trace_bar.max_value = 100.0
	_trace_bar.show_percentage = false

	_trace_bar_fill = StyleBoxFlat.new()
	_trace_bar_fill.bg_color = Color(0.0, 0.88, 1.0)
	_trace_bar_fill.corner_radius_top_left     = 2
	_trace_bar_fill.corner_radius_top_right    = 2
	_trace_bar_fill.corner_radius_bottom_left  = 2
	_trace_bar_fill.corner_radius_bottom_right = 2
	_trace_bar.add_theme_stylebox_override("fill", _trace_bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color     = Color(0.04, 0.06, 0.10)
	bar_bg.border_color = Color(0.0, 0.88, 1.0, 0.25)
	bar_bg.set_border_width_all(1)
	_trace_bar.add_theme_stylebox_override("background", bar_bg)
	_widget_slots.add_child(_trace_bar)

	_trace_route_lbl = Label.new()
	_trace_route_lbl.text = "ROUTE:  —"
	_trace_route_lbl.add_theme_font_size_override("font_size", 8)
	_trace_route_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	_trace_route_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_widget_slots.add_child(_trace_route_lbl)


# ── Faction rep widget ────────────────────────────────────────────────────────

func _build_faction_section() -> void:
	_widget_slots.add_child(HSeparator.new())

	var section_lbl := Label.new()
	section_lbl.text = "// FACTIONS //"
	section_lbl.add_theme_font_size_override("font_size", 9)
	section_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_widget_slots.add_child(section_lbl)

	_widget_slots.add_child(HSeparator.new())

	for faction_id in FactionManager.factions:
		var faction: FactionData = FactionManager.factions[faction_id]
		var row := _build_faction_row(faction)
		_widget_slots.add_child(row)

	_update_faction_rows()


func _build_faction_row(faction: FactionData) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	# Colour dot
	var dot := Label.new()
	dot.text = "\u25CF"
	dot.add_theme_font_size_override("font_size", 8)
	dot.add_theme_color_override("font_color", faction.color)
	dot.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(dot)

	# Faction name
	var name_lbl := Label.new()
	name_lbl.text = faction.name
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	hbox.add_child(name_lbl)

	# Rep value label
	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 8)
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	val_lbl.custom_minimum_size = Vector2(28, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	_faction_rows[faction.id] = { "label": name_lbl, "val": val_lbl }
	return hbox


func _update_faction_rows() -> void:
	for faction_id in _faction_rows:
		var rep: int = FactionManager.get_rep(faction_id)
		var row_data: Dictionary = _faction_rows[faction_id]
		var val_lbl: Label = row_data["val"]
		val_lbl.text = "%+d" % rep
		if rep > 0:
			val_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		elif rep < 0:
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		else:
			val_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))


func _on_faction_rep_changed(_faction_id: String, _new_rep: int) -> void:
	_update_faction_rows()


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
	var stk_speed:  float = HardwareManager.installed_stack.get("cpu_speed", 1.0)
	var hack_count: int   = HardwareManager.active_hack_count
	var stk_load: float   = minf(1.0, float(hack_count) / maxf(1.0, stk_speed))
	_cpu_fill_style.bg_color = _monitor_color(stk_load)
	_cpu_bar.value           = stk_load
	_cpu_val_label.text      = "%.1fx" % HardwareManager.effective_stack_speed


func _trace_colour(progress: float) -> Color:
	if progress < 0.5:
		return Color(0.0, 0.88, 1.0)
	if progress < 0.8:
		var t: float = (progress - 0.5) / 0.3
		return Color(0.0, 0.88, 1.0).lerp(Color(1.0, 0.75, 0.0), t)
	var t: float = (progress - 0.8) / 0.2
	return Color(1.0, 0.75, 0.0).lerp(Color(1.0, 0.08, 0.55), t)


func _monitor_color(pct: float) -> Color:
	if pct < 0.6:
		return Color(0.0, 0.88, 1.0)   # cyan — low load
	elif pct < 0.85:
		return Color(1.0, 0.75, 0.0)   # amber — moderate
	else:
		return Color(1.0, 0.08, 0.55)  # hot pink — critical


# ── Trace reactions ───────────────────────────────────────────────────────────

func _on_trace_started(_duration: float) -> void:
	_trace_state = TraceState.ACTIVE
	_trace_flicker = 0.0
	_trace_bar.value = 0.0
	_trace_bar_fill.bg_color = Color(0.0, 0.88, 1.0)
	_trace_status_lbl.modulate = Color(1, 1, 1, 1)
	_trace_status_lbl.text = "STATUS:  ACTIVE"
	_trace_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))


func _on_trace_progress(p: float) -> void:
	_trace_bar.value = p * 100.0
	_trace_bar_fill.bg_color = _trace_colour(p)


func _on_trace_completed() -> void:
	_trace_state = TraceState.COMPLETE
	_trace_bar.value = 100.0
	_trace_bar_fill.bg_color = Color(1.0, 0.08, 0.55)
	_trace_status_lbl.modulate = Color(1, 1, 1, 1)
	_trace_status_lbl.text = "STATUS:  COMPLETE"
	_trace_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))


# ── EventBus reactions ─────────────────────────────────────────────────────────

func _on_conn_btn_pressed() -> void:
	if _connected_id != "":
		NetworkSim.disconnect_from_node()
	else:
		EventBus.open_tool_requested.emit("Network Map")


func _on_network_connected(node_id: String) -> void:
	_connected_id = node_id
	var data := NetworkSim.get_node_data(node_id)
	conn_label.text = data.get("name", node_id)
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
	if _trace_status_lbl != null:
		_trace_state = TraceState.INACTIVE
		_trace_bar.value = 0.0
		_trace_bar_fill.bg_color = Color(0.0, 0.88, 1.0)
		_trace_status_lbl.modulate = Color(1, 1, 1, 1)
		_trace_status_lbl.text = "STATUS:  INACTIVE"
		_trace_status_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		_trace_route_lbl.text = "ROUTE:  —"


func _on_bounce_chain_updated(chain: Array) -> void:
	minimap.bounce_chain = chain
	minimap.queue_redraw()
	if _trace_route_lbl != null:
		if chain.is_empty():
			_trace_route_lbl.text = "ROUTE:  —"
		else:
			var names: Array[String] = []
			for id: String in chain:
				names.append(NetworkSim.get_node_data(id).get("name", id))
			_trace_route_lbl.text = "ROUTE:  " + "  →  ".join(names)
