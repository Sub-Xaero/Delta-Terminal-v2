class_name SystemLinks
extends ToolWindow
## Shows the connected node's outgoing links with ADD / IN BOOK / REMOVE controls.
## Closes automatically on disconnect.

# ── Colour constants ───────────────────────────────────────────────────────────
const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_MUTED := Color(0.35, 0.35, 0.45)
const COL_LIGHT := Color(0.75, 0.92, 1.0)

# node_id -> Button
var _btn_map: Dictionary = {}


func _ready() -> void:
	super._ready()
	title_label.text = "SYSTEM LINKS"
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

	var node_id: String     = NetworkSim.connected_node_id
	var data:    Dictionary = NetworkSim.get_node_data(node_id)
	var connections: Array  = data.get("connections", [])

	var origin_lbl := Label.new()
	origin_lbl.text = "LINKS FROM: %s" % data.get("name", node_id).to_upper()
	origin_lbl.add_theme_color_override("font_color", COL_MUTED)
	origin_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(origin_lbl)

	vbox.add_child(_make_header())
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	if connections.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(no linked systems)"
		empty_lbl.add_theme_color_override("font_color", COL_MUTED)
		list.add_child(empty_lbl)
	else:
		for conn_id: String in connections:
			if NetworkSim.nodes.has(conn_id):
				list.add_child(_make_row(conn_id))


func _make_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for col_def: Array in [
		["IP ADDRESS", 110, true],
		["NAME",       0,   true],
		["",           90,  false],
	]:
		var lbl := Label.new()
		lbl.text = col_def[0]
		lbl.add_theme_color_override("font_color", COL_MUTED)
		lbl.add_theme_font_size_override("font_size", 10)
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
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(90, 0)
	_set_btn_state(btn, node_id)
	btn.pressed.connect(func() -> void: _on_btn_pressed(node_id, btn))
	row.add_child(btn)

	_btn_map[node_id] = btn
	return row


# ── Button state ───────────────────────────────────────────────────────────────

func _set_btn_state(btn: Button, node_id: String) -> void:
	var is_protected: bool = node_id in NetworkSim._PROTECTED_NODES
	if node_id in NetworkSim.discovered_nodes:
		if is_protected:
			btn.text     = "[IN BOOK]"
			btn.disabled = true
			btn.add_theme_color_override("font_color", COL_MUTED)
		else:
			btn.text     = "[REMOVE]"
			btn.disabled = false
			btn.add_theme_color_override("font_color", COL_MUTED)
	else:
		btn.text     = "[ADD]"
		btn.disabled = false
		btn.add_theme_color_override("font_color", COL_CYAN)


func _on_book_changed(_node_id: String) -> void:
	for id: String in _btn_map:
		_set_btn_state(_btn_map[id], id)


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_btn_pressed(node_id: String, _btn: Button) -> void:
	if node_id in NetworkSim.discovered_nodes:
		NetworkSim.remove_node(node_id)
	else:
		NetworkSim.discover_node(node_id)
