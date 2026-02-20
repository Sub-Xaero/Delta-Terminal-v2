class_name SoftwareShop
extends ToolWindow
## Darknet software marketplace. Shows purchasable tool executables for the
## connected node. Spawned via desktop service icon on marketplace nodes.

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var node_header:  Label         = $ContentArea/Margin/VBox/NodeHeader
@onready var item_list:    VBoxContainer = $ContentArea/Margin/VBox/Scroll/ItemList
@onready var status_label: Label         = $ContentArea/Margin/VBox/StatusLabel


func _ready() -> void:
	super._ready()
	EventBus.network_connected.connect(_on_connection_changed)
	EventBus.network_disconnected.connect(_on_connection_changed)
	EventBus.player_stats_changed.connect(_refresh)
	_refresh()


func _on_connection_changed(_ignored = null) -> void:
	_refresh()


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	if not NetworkSim.is_connected:
		node_header.text = "MARKETPLACE"
		_set_status("NOT CONNECTED", Color(0.35, 0.35, 0.45))
		return

	var node: Dictionary = NetworkSim.get_node_data(NetworkSim.connected_node_id)
	if "marketplace" not in node.get("services", []):
		node_header.text = "MARKETPLACE"
		_set_status("NO MARKETPLACE ON THIS NODE", Color(1.0, 0.75, 0.0))
		return

	node_header.text = "%s  —  MARKETPLACE" % node.get("name", "UNKNOWN").to_upper()

	var catalogue: Array = node.get("shop_catalogue", [])
	if catalogue.is_empty():
		_set_status("NO ITEMS AVAILABLE", Color(0.35, 0.35, 0.45))
		return

	var credits: int  = GameManager.player_data.get("credits", 0)
	var storage: Array = GameManager.player_data.get("local_storage", [])
	_set_status("BALANCE:  ¥%d" % credits, Color(0.0, 0.88, 1.0))

	for item: Dictionary in catalogue:
		_add_item_row(item, credits, storage)


func _add_item_row(item: Dictionary, credits: int, storage: Array) -> void:
	var exe:   String = item.get("exe", "")
	var name_: String = item.get("name", "Unknown")
	var desc:  String = item.get("description", "")
	var price: int    = item.get("price", 0)
	var owned: bool   = exe in storage

	# ── Info column ───────────────────────────────────────────────────────────
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = name_
	name_lbl.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	info.add_child(name_lbl)
	info.add_child(desc_lbl)

	# ── Price label ───────────────────────────────────────────────────────────
	var price_lbl := Label.new()
	price_lbl.text = "¥%d" % price
	price_lbl.custom_minimum_size.x = 76
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	if owned:
		price_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	elif credits < price:
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	else:
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))

	# ── Buy button ────────────────────────────────────────────────────────────
	var btn := Button.new()
	btn.custom_minimum_size.x = 80
	if owned:
		btn.text     = "OWNED"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	elif credits < price:
		btn.text     = "BUY"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.55, 0.1, 0.1))
	else:
		btn.text     = "BUY"
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		btn.pressed.connect(func() -> void: _buy_item(item))

	# ── Row wrapper ───────────────────────────────────────────────────────────
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(info)
	row.add_child(price_lbl)
	row.add_child(btn)

	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)
	wrapper.add_child(row)
	wrapper.add_child(HSeparator.new())
	item_list.add_child(wrapper)


func _buy_item(item: Dictionary) -> void:
	var exe:   String  = item.get("exe", "")
	var name_: String  = item.get("name", "?")
	var price: int     = item.get("price", 0)
	var storage: Array = GameManager.player_data.get("local_storage", [])
	if exe in storage or GameManager.player_data.get("credits", 0) < price:
		return
	GameManager.add_credits(-price)
	GameManager.player_data["local_storage"].append(exe)
	EventBus.log_message.emit("Purchased %s for ¥%d" % [name_, price], "info")
	_refresh()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
