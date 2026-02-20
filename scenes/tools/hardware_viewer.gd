class_name HardwareViewer
extends ToolWindow
## Hardware Viewer — shows the player's installed hardware as a PCB layout.
## The right panel acts as an inline shop: click a slot to see available upgrades.

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var header_label:    Label         = $ContentArea/Margin/VBox/TopRow/HeaderLabel
@onready var credits_label:   Label         = $ContentArea/Margin/VBox/TopRow/CreditsLabel
@onready var mobo_slot:       Button        = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/MoboSection/MoboSlot
@onready var stack_slot:        Button        = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/StackSection/StackSlot
@onready var stack_usage_label: Label         = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/StackSection/StackUsageLabel
@onready var network_slot:    Button        = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/NetworkSection/NetworkSlot
@onready var ram_label:       Label         = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/RamSection/RamLabel
@onready var ram_slots_vbox:  VBoxContainer = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/RamSection/RamSlots
@onready var security_slot:   Button        = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/SecuritySection/SecuritySlot
@onready var detonate_btn:    Button        = $ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/SecuritySection/DetonateBtn
@onready var shop_header:     Label         = $ContentArea/Margin/VBox/HSplit/ShopPanel/ShopMargin/ShopVBox/ShopHeader
@onready var shop_list:       VBoxContainer = $ContentArea/Margin/VBox/HSplit/ShopPanel/ShopMargin/ShopVBox/ShopScroll/ShopList

# ── State ──────────────────────────────────────────────────────────────────────
var _active_slot_type:    String = ""
var _active_ram_index:    int    = -1
var _nuke_confirm_pending: bool  = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	EventBus.hardware_changed.connect(_refresh)
	EventBus.player_stats_changed.connect(_on_player_stats_changed)

	mobo_slot.pressed.connect(func():    _show_shop_for("mobo", -1))
	stack_slot.pressed.connect(func():   _show_shop_for("stack", -1))
	network_slot.pressed.connect(func(): _show_shop_for("network", -1))
	security_slot.pressed.connect(func(): _show_shop_for("security", -1))
	detonate_btn.pressed.connect(_on_detonate_pressed)

	_setup_theme()
	_refresh()


# ── Board refresh ─────────────────────────────────────────────────────────────

func _refresh() -> void:
	var handle: String = GameManager.player_data.get("handle", "ghost")
	header_label.text  = "HARDWARE — %s's rig" % handle
	credits_label.text = "Credits: %d" % GameManager.player_data.get("credits", 0)

	# Mobo
	var mobo: Dictionary = HardwareManager.installed_mobo
	mobo_slot.text = "%s  [%d slots]" % [mobo.get("name", "?"), mobo.get("ram_slots", 0)]

	# Stack
	var stk: Dictionary = HardwareManager.installed_stack
	stack_slot.text = "%s  [%.1fx]" % [stk.get("name", "?"), stk.get("cpu_speed", 1.0)]
	var hack_count: int = HardwareManager.active_hack_count
	if hack_count > 0:
		stack_usage_label.visible = true
		stack_usage_label.text = "%d hack(s) active  →  %.2fx effective" % [
			hack_count, HardwareManager.effective_stack_speed
		]
	else:
		stack_usage_label.visible = false

	# Network
	var net: Dictionary = HardwareManager.installed_network
	network_slot.text = "%s  [%.1fx trace]" % [net.get("name", "?"), net.get("trace_mult", 1.0)]

	# RAM slots — rebuild dynamically to match mobo's slot count
	for child: Node in ram_slots_vbox.get_children():
		child.queue_free()
	var total_slots: int = HardwareManager.ram_slots_total
	var installed_ram: Array = HardwareManager.installed_ram
	ram_label.text = "RAM SLOTS  [%d/%d]" % [installed_ram.size(), total_slots]
	for i: int in total_slots:
		var btn := Button.new()
		if i < installed_ram.size():
			var r: Dictionary = installed_ram[i]
			btn.text = "%s  [cap %d]" % [r.get("name", "?"), r.get("ram_capacity", 1)]
			btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
		else:
			btn.text = "[ EMPTY SLOT ]"
			btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		var captured_i: int = i
		btn.pressed.connect(func(): _show_shop_for("ram", captured_i))
		ram_slots_vbox.add_child(btn)

	# Security
	var sec: Dictionary = HardwareManager.installed_security
	if sec.is_empty():
		security_slot.text = "[ EMPTY ]"
		security_slot.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		detonate_btn.visible = false
	else:
		security_slot.text = sec.get("name", "?")
		security_slot.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		detonate_btn.visible = sec.get("nuke_mode", "") == "manual"

	# Re-run shop if a slot is already selected
	if not _active_slot_type.is_empty():
		_show_shop_for(_active_slot_type, _active_ram_index)


func _on_player_stats_changed() -> void:
	credits_label.text = "Credits: %d" % GameManager.player_data.get("credits", 0)
	# Also refresh shop cards so affordability colouring updates
	if not _active_slot_type.is_empty():
		_show_shop_for(_active_slot_type, _active_ram_index)


# ── Shop panel ────────────────────────────────────────────────────────────────

func _show_shop_for(slot_type: String, ram_index: int) -> void:
	_active_slot_type = slot_type
	_active_ram_index = ram_index

	for child: Node in shop_list.get_children():
		child.queue_free()

	var type_labels: Dictionary = {
		"mobo":     "MOTHERBOARD",
		"ram":      "RAM MODULE",
		"stack":    "COMPUTE STACK",
		"network":  "NETWORK CARD",
		"security": "SECURITY CHIP",
	}
	shop_header.text = "UPGRADES — %s" % type_labels.get(slot_type, slot_type.to_upper())

	for item: Dictionary in HardwareManager.CATALOG:
		if item.get("type", "") != slot_type:
			continue
		shop_list.add_child(_build_shop_card(item))


func _build_shop_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.02, 0.04, 0.08)
	card_style.border_color = Color(0.0, 0.88, 1.0, 0.35)
	card_style.set_border_width_all(1)
	card_style.content_margin_left   = 8.0
	card_style.content_margin_right  = 8.0
	card_style.content_margin_top    = 6.0
	card_style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	vbox.add_child(desc_lbl)

	var cost: int       = item.get("cost", 0)
	var installed: bool = _is_item_installed(item)
	var buy_btn         := Button.new()

	if installed:
		buy_btn.text     = "INSTALLED"
		buy_btn.disabled = true
		buy_btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	elif cost == 0:
		buy_btn.text     = "FREE"
		buy_btn.disabled = true
		buy_btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	else:
		var can_afford: bool = GameManager.player_data.get("credits", 0) >= cost
		buy_btn.text = "BUY  %d cr" % cost
		buy_btn.add_theme_color_override(
			"font_color",
			Color(0.0, 0.88, 1.0) if can_afford else Color(1.0, 0.75, 0.0)
		)
		var captured: Dictionary = item.duplicate()
		buy_btn.pressed.connect(func(): _on_buy_pressed(captured))

	vbox.add_child(buy_btn)
	return card


func _is_item_installed(item: Dictionary) -> bool:
	var id: String = item.get("id", "")
	match item.get("type", ""):
		"mobo":     return HardwareManager.installed_mobo.get("id", "") == id
		"stack":    return HardwareManager.installed_stack.get("id", "") == id
		"network":  return HardwareManager.installed_network.get("id", "") == id
		"security": return HardwareManager.installed_security.get("id", "") == id
		"ram":
			for r: Dictionary in HardwareManager.installed_ram:
				if r.get("id", "") == id:
					return true
	return false


func _on_buy_pressed(item: Dictionary) -> void:
	HardwareManager.purchase_item(item.get("id", ""))
	# _refresh is triggered automatically via hardware_changed signal


# ── Nuke confirmation ─────────────────────────────────────────────────────────

func _on_detonate_pressed() -> void:
	if not _nuke_confirm_pending:
		_nuke_confirm_pending = true
		detonate_btn.text = "CONFIRM DETONATE?"
		detonate_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
		# Auto-cancel if player doesn't confirm within 5 seconds
		await get_tree().create_timer(5.0).timeout
		if _nuke_confirm_pending:
			_nuke_confirm_pending = false
			detonate_btn.text = "[ DETONATE ]"
			detonate_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	else:
		_nuke_confirm_pending = false
		HardwareManager.trigger_nuke()
		# Window will be closed by desktop._on_system_nuke


# ── Theme ──────────────────────────────────────────────────────────────────────

func _setup_theme() -> void:
	# PCB-style board panel — set via script since we build it in code
	var board_style := StyleBoxFlat.new()
	board_style.bg_color     = Color(0.01, 0.05, 0.03)
	board_style.border_color = Color(0.0, 0.88, 1.0, 0.6)
	board_style.set_border_width_all(1)
	board_style.content_margin_left   = 10.0
	board_style.content_margin_right  = 10.0
	board_style.content_margin_top    = 10.0
	board_style.content_margin_bottom = 10.0
	($ContentArea/Margin/VBox/HSplit/BoardPanel as PanelContainer).add_theme_stylebox_override(
		"panel", board_style
	)

	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color     = Color(0.02, 0.03, 0.07)
	shop_style.border_color = Color(0.0, 0.88, 1.0, 0.25)
	shop_style.set_border_width_all(1)
	shop_style.content_margin_left   = 10.0
	shop_style.content_margin_right  = 10.0
	shop_style.content_margin_top    = 10.0
	shop_style.content_margin_bottom = 10.0
	($ContentArea/Margin/VBox/HSplit/ShopPanel as PanelContainer).add_theme_stylebox_override(
		"panel", shop_style
	)

	header_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	ram_label.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))
	stack_usage_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	shop_header.add_theme_color_override("font_color", Color(0.45, 0.6, 0.65))

	detonate_btn.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))

	# Section header labels — slot buttons colour overrides set in _refresh
	_style_section_label($ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/MoboSection/MoboLabel as Label)
	_style_section_label($ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/StackSection/StackLabel as Label)
	_style_section_label($ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/NetworkSection/NetworkLabel as Label)
	_style_section_label($ContentArea/Margin/VBox/HSplit/BoardPanel/BoardMargin/BoardVBox/SecuritySection/SecurityLabel as Label)
	# RamLabel styled above via @onready reference


func _style_section_label(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
