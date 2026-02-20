class_name NodeDirectory
extends ToolWindow
## ISP Node Directory — browse and manage the address book.
## Lists all registered nodes (except local_machine) with ADD/REMOVE controls.
## Closes automatically when the ISP session ends.

# ── Colour constants ───────────────────────────────────────────────────────────
const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_PINK  := Color(1.0,  0.08, 0.55)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_MUTED := Color(0.35, 0.35, 0.45)
const COL_LIGHT := Color(0.75, 0.92, 1.0)

# node_id -> Button (the ADD/REMOVE button in that row)
var _btn_map: Dictionary = {}


func _ready() -> void:
	super._ready()
	title_label.text = "NODE DIRECTORY"
	EventBus.node_discovered.connect(_on_book_changed)
	EventBus.node_removed.connect(_on_book_changed)
	EventBus.network_disconnected.connect(queue_free)
	_build_layout()


# ── Layout ─────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom", 10)
	content_area.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header row
	vbox.add_child(_make_header())
	vbox.add_child(HSeparator.new())

	# Scrollable node list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	# Populate sorted rows
	var ids: Array = NetworkSim.nodes.keys()
	ids = ids.filter(func(id: String) -> bool: return id != "local_machine")
	ids.sort_custom(func(a: String, b: String) -> bool:
		return NetworkSim.nodes[a].get("name", a) < NetworkSim.nodes[b].get("name", b)
	)
	for id: String in ids:
		list.add_child(_make_row(id))


func _make_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for col_def: Array in [
		["IP ADDRESS",    110, true],
		["NAME",          0,   true],
		["ORGANISATION",  0,   true],
		["",              80,  false],
	]:
		var lbl := Label.new()
		lbl.text = col_def[0]
		lbl.add_theme_color_override("font_color", COL_MUTED)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if col_def[2]:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if col_def[1] > 0:
			lbl.custom_minimum_size = Vector2(col_def[1], 0)
		row.add_child(lbl)
	return row


func _make_row(node_id: String) -> HBoxContainer:
	var data: Dictionary = NetworkSim.nodes[node_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var ip_lbl := Label.new()
	ip_lbl.text = data.get("ip", "—")
	ip_lbl.add_theme_color_override("font_color", COL_MUTED)
	ip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_lbl.custom_minimum_size   = Vector2(110, 0)
	row.add_child(ip_lbl)

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "Unknown")
	name_lbl.add_theme_color_override("font_color", COL_LIGHT)
	name_lbl.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_lbl)

	var org_lbl := Label.new()
	org_lbl.text = data.get("organisation", "—")
	org_lbl.add_theme_color_override("font_color", COL_MUTED)
	org_lbl.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	org_lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(org_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(80, 0)
	_set_btn_state(btn, node_id)
	btn.pressed.connect(func() -> void: _on_btn_pressed(node_id))
	row.add_child(btn)

	_btn_map[node_id] = btn
	return row


# ── Button state ───────────────────────────────────────────────────────────────

func _set_btn_state(btn: Button, node_id: String) -> void:
	if node_id in NetworkSim.discovered_nodes:
		btn.text = "[REMOVE]"
		btn.add_theme_color_override("font_color", COL_MUTED)
	else:
		btn.text = "[ADD]"
		btn.add_theme_color_override("font_color", COL_CYAN)


func _on_book_changed(_node_id: String) -> void:
	for id: String in _btn_map:
		_set_btn_state(_btn_map[id], id)


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_btn_pressed(node_id: String) -> void:
	if node_id in NetworkSim.discovered_nodes:
		NetworkSim.remove_node(node_id)
	else:
		NetworkSim.discover_node(node_id)
