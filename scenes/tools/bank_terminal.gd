class_name BankTerminal
extends ToolWindow
## Bank terminal. Provides access to banking services on the connected node.
## Spawned via desktop service icon when connected to a banking node.

enum State { DISCONNECTED, NO_BANK, NO_ACCESS, LOGIN, USER, ADMIN }

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var node_header:   Label         = $ContentArea/Margin/VBox/NodeHeader
@onready var login_panel:   VBoxContainer = $ContentArea/Margin/VBox/LoginPanel
@onready var user_dropdown: OptionButton  = $ContentArea/Margin/VBox/LoginPanel/UserDropdown
@onready var login_btn:     Button        = $ContentArea/Margin/VBox/LoginPanel/LoginBtn
@onready var account_panel: VBoxContainer = $ContentArea/Margin/VBox/AccountPanel
@onready var account_list:  VBoxContainer = $ContentArea/Margin/VBox/AccountPanel/AccountScroll/AccountList
@onready var steal_panel:   VBoxContainer = $ContentArea/Margin/VBox/AccountPanel/StealPanel
@onready var amount_spin:   SpinBox       = $ContentArea/Margin/VBox/AccountPanel/StealPanel/AmountSpin
@onready var execute_btn:   Button        = $ContentArea/Margin/VBox/AccountPanel/StealPanel/ExecuteBtn
@onready var status_label:  Label         = $ContentArea/Margin/VBox/StatusLabel

# ── State ──────────────────────────────────────────────────────────────────────
var _state: State = State.DISCONNECTED
var _logged_in_role: String = ""


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_network_connected)
	EventBus.network_disconnected.connect(_on_network_disconnected)
	login_btn.pressed.connect(_on_login_pressed)
	execute_btn.pressed.connect(_on_execute_steal)
	_setup_theme()
	_evaluate_state()


# ── EventBus handlers ──────────────────────────────────────────────────────────

func _on_network_connected(_node_id: String) -> void:
	_logged_in_role = ""
	_evaluate_state()


func _on_network_disconnected() -> void:
	_logged_in_role = ""
	_evaluate_state()


# ── State logic ────────────────────────────────────────────────────────────────

func _evaluate_state() -> void:
	if not NetworkSim.is_connected:
		_state = State.DISCONNECTED
		_update_ui()
		return

	var node: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	if "banking" not in node.get("services", []):
		_state = State.NO_BANK
		_update_ui()
		return

	if _logged_in_role != "":
		_state = State.ADMIN if _logged_in_role == "admin" else State.USER
		_update_ui()
		return

	var node_id: String  = NetworkSim.connected_node_id
	var cracked: bool    = node_id in NetworkSim.cracked_nodes
	var has_creds: bool  = CredentialManager.has_credentials(node_id)
	_state = State.LOGIN if (cracked or has_creds) else State.NO_ACCESS
	_update_ui()


func _on_login_pressed() -> void:
	var selected: int = user_dropdown.selected
	if selected < 0:
		return
	var node_id: String      = NetworkSim.connected_node_id
	var node_cracked: bool   = node_id in NetworkSim.cracked_nodes
	var creds: Array         = CredentialManager.get_credentials(node_id)
	var usable: Array        = creds.filter(_is_usable_credential)
	var role: String = "user"
	if node_cracked and selected == usable.size():
		role = "admin"
	elif selected < usable.size():
		var cred_role: String = usable[selected].get("role", "user")
		role = "admin" if cred_role == "admin" else "user"
	_logged_in_role = role
	_state = State.ADMIN if role == "admin" else State.USER
	EventBus.log_message.emit("Logged into bank terminal as [%s]" % role, "info")
	_update_ui()


func _on_execute_steal() -> void:
	var amount: int     = int(amount_spin.value)
	var node_id: String = NetworkSim.connected_node_id
	GameManager.add_credits(amount)
	# Append to transfer_log.log so the mutation persists via SaveManager
	for file: Dictionary in NetworkSim.nodes[node_id].get("files", []):
		if file.get("name", "") == "transfer_log.log":
			var ts: String = Time.get_datetime_string_from_system()
			file["content"] = file.get("content", "") \
				+ "\n[%s] TRANSFER -> ANON  ¥%d  STATUS:OK" % [ts, amount]
			break
	EventBus.log_message.emit("Transferred ¥%d from bank terminal." % amount, "warn")
	_refresh_account_list()
	_set_status("TRANSFER COMPLETE:  +¥%d" % amount, Color(0.0, 0.88, 1.0))


# ── UI update ──────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	if NetworkSim.is_connected:
		var node: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
		node_header.text = "%s  —  BANK TERMINAL" % node.get("name", "UNKNOWN").to_upper()
	else:
		node_header.text = "BANK TERMINAL"

	login_panel.visible   = false
	account_panel.visible = false
	steal_panel.visible   = false

	match _state:
		State.DISCONNECTED:
			_set_status("NOT CONNECTED", Color(0.35, 0.35, 0.45))
		State.NO_BANK:
			_set_status("NO BANKING SERVICE ON THIS NODE", Color(1.0, 0.75, 0.0))
		State.NO_ACCESS:
			_set_status("ACCESS DENIED — obtain credentials or crack this node",
				Color(1.0, 0.08, 0.55))
		State.LOGIN:
			_populate_login_dropdown()
			login_panel.visible = true
			_set_status("AUTHENTICATE TO CONTINUE", Color(0.75, 0.92, 1.0))
		State.USER:
			account_panel.visible = true
			_refresh_account_list()
			_set_status("LOGGED IN AS USER", Color(0.0, 0.88, 1.0))
		State.ADMIN:
			account_panel.visible = true
			steal_panel.visible   = true
			_refresh_account_list()
			_set_status("ADMIN ACCESS GRANTED", Color(1.0, 0.75, 0.0))


func _populate_login_dropdown() -> void:
	user_dropdown.clear()
	var node_id: String    = NetworkSim.connected_node_id
	var node_cracked: bool = node_id in NetworkSim.cracked_nodes
	var creds: Array       = CredentialManager.get_credentials(node_id)
	for cred: Dictionary in creds.filter(_is_usable_credential):
		var label: String = "%s  [%s]" % [cred.get("username", "?"), cred.get("role", "?")]
		if cred.get("type", "") == "organic":
			label += "  ★"
		user_dropdown.add_item(label)
	if node_cracked:
		user_dropdown.add_item("ADMIN OVERRIDE  [admin]")
	login_btn.disabled = user_dropdown.item_count == 0


func _refresh_account_list() -> void:
	for child in account_list.get_children():
		child.queue_free()
	var node_id: String  = NetworkSim.connected_node_id
	var node: Dictionary = NetworkSim.get_node_data(node_id)
	var handle: String   = GameManager.player_data.get("handle", "ghost")
	if _state == State.USER:
		_add_account_line("YOUR ACCOUNT", Color(0.45, 0.6, 0.65))
		_add_account_line("Holder:   %s" % handle, Color(0.75, 0.92, 1.0))
		_add_account_line(
			"Balance:  ¥%d" % GameManager.player_data.get("credits", 0),
			Color(0.0, 0.88, 1.0)
		)
	elif _state == State.ADMIN:
		for file: Dictionary in node.get("files", []):
			if file.get("name", "") == "accounts_db.dat":
				_add_account_line("REMOTE ACCOUNTS", Color(1.0, 0.75, 0.0))
				for line: String in (file.get("content", "") as String).split("\n"):
					if not line.strip_edges().is_empty():
						_add_account_line(line, Color(0.65, 0.7, 0.75))
				break
		_add_account_line("", Color.WHITE)
		_add_account_line(
			"LOCAL BALANCE:  ¥%d" % GameManager.player_data.get("credits", 0),
			Color(0.0, 0.88, 1.0)
		)


func _add_account_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	account_list.add_child(lbl)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


# Returns true if a credential can be used to log in — either the player
# legitimately owns it ("organic") or its hash has been cracked/stolen.
func _is_usable_credential(c: Dictionary) -> bool:
	return c.get("type", "") == "organic" or c.get("cracked", false)


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	login_btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	execute_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
