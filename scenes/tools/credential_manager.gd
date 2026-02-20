class_name CredentialManagerTool
extends ToolWindow
## Displays stolen credentials organised by network node.
## Left panel lists nodes with credential counts; right panel shows details.

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var node_list: VBoxContainer    = $ContentArea/Margin/VBox/HSplit/NodeListPanel/NodeListMargin/NodeListScroll/NodeList
@onready var detail_header: Label        = $ContentArea/Margin/VBox/HSplit/DetailVBox/DetailHeader
@onready var cred_list: VBoxContainer    = $ContentArea/Margin/VBox/HSplit/DetailVBox/CredScroll/CredList
@onready var status_label: Label         = $ContentArea/Margin/VBox/StatusLabel

# ── State ──────────────────────────────────────────────────────────────────────
var _selected_node_id: String = ""


func _ready() -> void:
	super._ready()
	EventBus.credentials_stolen.connect(_on_credentials_stolen)
	_setup_theme()
	_refresh_node_list()


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_credentials_stolen(_node_id: String, _count: int) -> void:
	_refresh_node_list()
	if _selected_node_id != "":
		_show_credentials(_selected_node_id)


# ── Node list ─────────────────────────────────────────────────────────────────

func _refresh_node_list() -> void:
	for child: Node in node_list.get_children():
		child.queue_free()

	var node_ids: Array = CredentialManager.credentials.keys()
	if node_ids.is_empty():
		status_label.text = "No stolen credentials yet."
		status_label.visible = true
		return

	status_label.visible = false
	for node_id: String in node_ids:
		var creds: Array = CredentialManager.get_credentials(node_id)
		if creds.is_empty():
			continue
		var node_data: Dictionary = NetworkSim.get_node_data(node_id)
		var display_name: String = node_data.get("name", node_id)
		var ip: String = node_data.get("ip", "?.?.?.?")

		var btn := Button.new()
		btn.text = "%s  [%d]" % [display_name, creds.size()]
		btn.tooltip_text = ip
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

		var empty_style := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)

		var captured_id := node_id
		btn.pressed.connect(func(): _show_credentials(captured_id))
		node_list.add_child(btn)


# ── Credential detail ─────────────────────────────────────────────────────────

func _show_credentials(node_id: String) -> void:
	_selected_node_id = node_id
	for child: Node in cred_list.get_children():
		child.queue_free()

	var node_data: Dictionary = NetworkSim.get_node_data(node_id)
	detail_header.text = "%s  —  %s" % [
		node_data.get("ip", "?.?.?.?"),
		node_data.get("name", node_id),
	]

	var creds: Array = CredentialManager.get_credentials(node_id)
	for cred: Dictionary in creds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var user_lbl := Label.new()
		user_lbl.text = cred.get("username", "?")
		user_lbl.custom_minimum_size.x = 120
		user_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		row.add_child(user_lbl)

		var role_lbl := Label.new()
		role_lbl.text = cred.get("role", "?")
		role_lbl.custom_minimum_size.x = 80
		role_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		row.add_child(role_lbl)

		var status_lbl := Label.new()
		if cred.get("cracked", false):
			status_lbl.text = "CRACKED"
			status_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		else:
			status_lbl.text = "HASH ONLY"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
		row.add_child(status_lbl)

		cred_list.add_child(row)


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	detail_header.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	status_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.08)
	panel_style.border_color = Color(0.0, 0.88, 1.0, 0.4)
	panel_style.set_border_width_all(1)
	($ContentArea/Margin/VBox/HSplit/NodeListPanel as PanelContainer).add_theme_stylebox_override(
		"panel", panel_style
	)
