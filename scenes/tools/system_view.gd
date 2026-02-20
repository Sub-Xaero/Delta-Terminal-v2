class_name SystemView
extends Control
## Full-screen background view of the currently connected node.
## Sits between the CRT background and the floating tool windows.
## Hidden when not connected; shows public interfaces or a private login screen.

# ── Colour constants ───────────────────────────────────────────────────────────
const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_PINK  := Color(1.0,  0.08, 0.55)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_MUTED := Color(0.35, 0.35, 0.45)
const COL_LIGHT := Color(0.75, 0.92, 1.0)

const PROTECTION_COLOURS: Dictionary = {
	"firewall":   COL_PINK,
	"proxy":      COL_AMBER,
	"encryption": COL_CYAN,
}

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _header:            Panel           = $Header
@onready var _sys_name_label:    Label           = $Header/HBox/SysNameLabel
@onready var _ip_label:          Label           = $Header/HBox/IPLabel
@onready var _public_section:    CenterContainer = $PublicSection
@onready var _interface_flow:    HFlowContainer  = $PublicSection/InterfaceFlow
@onready var _private_section:   CenterContainer = $PrivateSection
@onready var _login_box:         PanelContainer  = $PrivateSection/LoginBox
@onready var _private_label:     Label           = $PrivateSection/LoginBox/Margin/VBox/PrivateLabel
@onready var _auth_label:        Label           = $PrivateSection/LoginBox/Margin/VBox/AuthLabel
@onready var _attempt_btn:       Button          = $PrivateSection/LoginBox/Margin/VBox/AttemptBtn
@onready var _protections_panel: VBoxContainer   = $PrivateSection/LoginBox/Margin/VBox/ProtectionsPanel


func _ready() -> void:
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	_attempt_btn.pressed.connect(_on_attempt_login)
	_apply_theme()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(node_id: String) -> void:
	_populate(node_id)


func _on_network_disconnected() -> void:
	visible = false
	_clear_interfaces()
	_clear_protections()


# ── Populate ───────────────────────────────────────────────────────────────────

func _populate(node_id: String) -> void:
	var data: Dictionary  = NetworkSim.get_node_data(node_id)
	var interfaces: Array = data.get("public_interfaces", [])

	_sys_name_label.text = data.get("name", "Unknown").to_upper()
	_ip_label.text       = data.get("ip",   "0.0.0.0")

	_clear_interfaces()
	_clear_protections()
	_attempt_btn.visible       = true
	_protections_panel.visible = false
	visible                    = true

	if interfaces.is_empty():
		_public_section.visible  = false
		_private_section.visible = true
	else:
		_public_section.visible  = true
		_private_section.visible = false
		for iface: Dictionary in interfaces:
			_add_interface_card(iface, data.get("name", "?"))


# ── Interface cards ────────────────────────────────────────────────────────────

func _add_interface_card(iface: Dictionary, node_name: String) -> void:
	var iface_name: String = iface.get("name",        "Interface")
	var desc:       String = iface.get("description", "")

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 110)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = Color(0.03, 0.05, 0.10, 0.92)
	card_style.border_color = COL_CYAN
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(2)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var icon_lbl := Label.new()
	icon_lbl.text = "[>]"
	icon_lbl.add_theme_color_override("font_color",    COL_CYAN)
	icon_lbl.add_theme_font_size_override("font_size", 18)

	var name_btn := Button.new()
	name_btn.text         = iface_name
	name_btn.flat         = true
	name_btn.alignment    = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_btn.add_theme_color_override("font_color",         COL_CYAN)
	name_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	name_btn.add_theme_color_override("font_pressed_color", COL_LIGHT)

	var cap_name:      String = iface_name
	var cap_node_name: String = node_name
	name_btn.pressed.connect(func() -> void:
		EventBus.log_message.emit(
			"[%s] Public interface accessed: %s" % [cap_node_name, cap_name], "info"
		)
	)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_color_override("font_color", COL_MUTED)
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL

	vbox.add_child(icon_lbl)
	vbox.add_child(name_btn)
	vbox.add_child(desc_lbl)
	card.add_child(vbox)
	_interface_flow.add_child(card)


func _clear_interfaces() -> void:
	for child in _interface_flow.get_children():
		child.queue_free()


# ── Attempt login / protections ────────────────────────────────────────────────

func _on_attempt_login() -> void:
	var node_id: String     = NetworkSim.connected_node_id
	var data:    Dictionary = NetworkSim.get_node_data(node_id)

	_attempt_btn.visible = false

	var player_accounts: Dictionary = GameManager.player_data.get("player_accounts", {})
	if node_id in NetworkSim.cracked_nodes:
		var prots: Array = _build_protections(data, node_id)
		_reveal_protections(prots, node_id)
		EventBus.log_message.emit(
			"[%s] Login attempted — access granted." % data.get("name", "?"), "info"
		)
	elif player_accounts.has(node_id):
		var account: Dictionary = player_accounts[node_id]
		_show_post_login(data, node_id, account)
	else:
		var prots: Array = _build_protections(data, node_id)
		_reveal_protections(prots, node_id)
		EventBus.log_message.emit(
			"[%s] Login attempted — access denied." % data.get("name", "?"), "warn"
		)


func _show_post_login(data: Dictionary, _node_id: String, account: Dictionary) -> void:
	_clear_protections()
	_protections_panel.visible = true

	var username: String = account.get("username", "unknown")
	var role:     String = account.get("role",     "user")

	var header_lbl := Label.new()
	header_lbl.text = "── ACCESS GRANTED ──"
	header_lbl.add_theme_color_override("font_color", COL_CYAN)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_protections_panel.add_child(header_lbl)

	var identity_lbl := Label.new()
	identity_lbl.text = "LOGGED IN AS: %s [%s]" % [username.to_upper(), role.to_upper()]
	identity_lbl.add_theme_color_override("font_color", COL_MUTED)
	identity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_protections_panel.add_child(identity_lbl)

	_protections_panel.add_child(HSeparator.new())

	var services: Array = data.get("services", [])
	if "job_board" in services:
		_protections_panel.add_child(_make_service_button(
			"JOB BOARD", "[JOB BOARD]",
			func() -> void: EventBus.open_tool_requested.emit("Faction Job Board")
		))
	if "banking" in services:
		_protections_panel.add_child(_make_service_button(
			"BANK TERMINAL", "[BANK TERMINAL]",
			func() -> void: EventBus.open_tool_requested.emit("Bank Terminal")
		))

	EventBus.log_message.emit(
		"[%s] Logged in as %s [%s]" % [data.get("name", "?"), username, role.to_upper()],
		"info"
	)


func _build_protections(data: Dictionary, node_id: String) -> Array:
	var prots:    Array = []
	var security: int   = data.get("security", 0)
	var services: Array = data.get("services", [])

	if data.get("has_firewall", false) or security >= 3:
		var bypassed: bool = node_id in NetworkSim.bypassed_nodes
		prots.append({ "type": "firewall", "level": security, "cleared": bypassed })
	if "relay" in services:
		prots.append({ "type": "proxy", "level": security, "cleared": false })
	if data.get("encrypted", false):
		var broken: bool = node_id in NetworkSim.encryption_broken_nodes
		prots.append({ "type": "encryption", "level": security, "cleared": broken })

	return prots


func _reveal_protections(prots: Array, node_id: String) -> void:
	_clear_protections()
	_protections_panel.visible = true

	var is_cracked: bool = node_id in NetworkSim.cracked_nodes
	var header_lbl := Label.new()
	if is_cracked:
		header_lbl.text = "── ACCESS GRANTED ──"
		header_lbl.add_theme_color_override("font_color", COL_CYAN)
	else:
		header_lbl.text = "── ACCESS DENIED ──"
		header_lbl.add_theme_color_override("font_color", COL_PINK)
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_protections_panel.add_child(header_lbl)

	var section_lbl := Label.new()
	section_lbl.text = "SECURITY STATUS"
	section_lbl.add_theme_color_override("font_color", COL_MUTED)
	_protections_panel.add_child(section_lbl)

	if prots.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "  (no protections detected)"
		none_lbl.add_theme_color_override("font_color", COL_MUTED)
		_protections_panel.add_child(none_lbl)
		return

	for prot: Dictionary in prots:
		var prot_type:  String = prot.get("type",  "unknown")
		var prot_level: int    = prot.get("level", 1)
		var cleared:    bool   = prot.get("cleared", false)
		var col: Color         = PROTECTION_COLOURS.get(prot_type, COL_LIGHT)

		var row := HBoxContainer.new()

		var type_lbl := Label.new()
		type_lbl.text = prot_type.to_upper().rpad(12)
		type_lbl.add_theme_color_override("font_color", col)
		type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var level_lbl := Label.new()
		level_lbl.text = "LVL %d" % prot_level
		level_lbl.add_theme_color_override("font_color", col)

		var status_lbl := Label.new()
		if cleared:
			status_lbl.text = "  [CLEARED]"
			status_lbl.add_theme_color_override("font_color", COL_MUTED)
		else:
			status_lbl.text = "  [ACTIVE]"
			status_lbl.add_theme_color_override("font_color", col)

		row.add_child(type_lbl)
		row.add_child(level_lbl)
		row.add_child(status_lbl)
		_protections_panel.add_child(row)


func _make_service_button(label_text: String, btn_text: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()

	var svc_lbl := Label.new()
	svc_lbl.text = label_text
	svc_lbl.add_theme_color_override("font_color", COL_MUTED)
	svc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(svc_lbl)

	var btn := Button.new()
	btn.text = btn_text
	btn.flat = true
	btn.add_theme_color_override("font_color", COL_AMBER)
	btn.pressed.connect(callback)
	row.add_child(btn)
	return row


func _clear_protections() -> void:
	for child in _protections_panel.get_children():
		child.queue_free()


# ── Theme ──────────────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	var header_style := StyleBoxFlat.new()
	header_style.bg_color             = Color(0.04, 0.03, 0.12, 0.92)
	header_style.border_color         = COL_CYAN
	header_style.border_width_bottom  = 1
	_header.add_theme_stylebox_override("panel", header_style)

	var login_style := StyleBoxFlat.new()
	login_style.bg_color     = Color(0.04, 0.03, 0.10, 0.96)
	login_style.border_color = COL_PINK
	login_style.set_border_width_all(1)
	login_style.set_content_margin_all(0)
	_login_box.add_theme_stylebox_override("panel", login_style)

	_sys_name_label.add_theme_color_override("font_color",    COL_CYAN)
	_sys_name_label.add_theme_font_size_override("font_size", 16)
	_ip_label.add_theme_color_override("font_color",          COL_MUTED)
	_private_label.add_theme_color_override("font_color",     COL_PINK)
	_private_label.add_theme_font_size_override("font_size",  15)
	_auth_label.add_theme_color_override("font_color",        COL_MUTED)
	_attempt_btn.add_theme_color_override("font_color",       COL_AMBER)
