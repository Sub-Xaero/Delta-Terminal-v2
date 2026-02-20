extends ToolWindow
## In-game email client. Left panel lists messages; right panel shows detail.

@onready var _inbox_list: ItemList = $ContentArea/Margin/HSplit/LeftPanel/InboxList
@onready var _detail_from: Label = $ContentArea/Margin/HSplit/RightPanel/DetailScroll/DetailVBox/FromLabel
@onready var _detail_subject: Label = $ContentArea/Margin/HSplit/RightPanel/DetailScroll/DetailVBox/SubjectLabel
@onready var _detail_time: Label = $ContentArea/Margin/HSplit/RightPanel/DetailScroll/DetailVBox/TimeLabel
@onready var _detail_body: RichTextLabel = $ContentArea/Margin/HSplit/RightPanel/DetailScroll/DetailVBox/BodyText
@onready var _btn_delete: Button = $ContentArea/Margin/HSplit/RightPanel/BtnRow/DeleteBtn
@onready var _unread_label: Label = $ContentArea/Margin/HSplit/LeftPanel/UnreadLabel
@onready var _empty_label: Label = $ContentArea/Margin/HSplit/RightPanel/DetailScroll/DetailVBox/EmptyLabel

var _selected_id: String = ""
var _attachment_container: VBoxContainer = null


func _ready() -> void:
	super._ready()
	_apply_comms_theme()
	_inbox_list.item_selected.connect(_on_item_selected)
	_btn_delete.pressed.connect(_on_delete_pressed)
	EventBus.comms_message_received.connect(_on_message_received)
	_refresh_inbox()


# ── Theme ─────────────────────────────────────────────────────────────────────

func _apply_comms_theme() -> void:
	_inbox_list.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	_inbox_list.add_theme_color_override("font_selected_color", Color(0.0, 0.88, 1.0))
	_inbox_list.add_theme_font_size_override("font_size", 11)

	var list_bg := StyleBoxFlat.new()
	list_bg.bg_color = Color(0.03, 0.02, 0.08, 0.9)
	list_bg.border_color = Color(0.0, 0.88, 1.0, 0.2)
	list_bg.border_width_right = 1
	_inbox_list.add_theme_stylebox_override("panel", list_bg)

	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = Color(0.0, 0.88, 1.0, 0.12)
	_inbox_list.add_theme_stylebox_override("selected", sel_style)
	_inbox_list.add_theme_stylebox_override("selected_focus", sel_style)

	_detail_from.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_detail_from.add_theme_font_size_override("font_size", 12)
	_detail_subject.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_detail_subject.add_theme_font_size_override("font_size", 13)
	_detail_time.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	_detail_time.add_theme_font_size_override("font_size", 9)
	_detail_body.add_theme_color_override("default_color", Color(0.65, 0.7, 0.75))
	_detail_body.add_theme_font_size_override("normal_font_size", 11)

	_unread_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.0))
	_unread_label.add_theme_font_size_override("font_size", 9)

	_empty_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	_empty_label.add_theme_font_size_override("font_size", 11)

	_btn_delete.add_theme_color_override("font_color", Color(1.0, 0.08, 0.55))
	_btn_delete.add_theme_font_size_override("font_size", 10)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	btn_style.border_color = Color(1.0, 0.08, 0.55, 0.4)
	btn_style.set_border_width_all(1)
	_btn_delete.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(1.0, 0.08, 0.55, 0.1)
	_btn_delete.add_theme_stylebox_override("hover", btn_hover)


# ── Inbox management ─────────────────────────────────────────────────────────

func _refresh_inbox() -> void:
	_inbox_list.clear()
	for msg: Dictionary in CommsManager.inbox:
		var prefix: String = "● " if not msg.get("read", true) else "  "
		var display: String = prefix + msg.get("from_handle", "???") + " — " + msg.get("subject", "(no subject)")
		_inbox_list.add_item(display)
	_update_unread_label()
	_update_detail()


func _update_unread_label() -> void:
	var count: int = CommsManager.get_unread_count()
	_unread_label.text = "%d UNREAD" % count if count > 0 else ""


func _update_detail() -> void:
	if _selected_id.is_empty():
		_detail_from.text = ""
		_detail_subject.text = ""
		_detail_time.text = ""
		_detail_body.text = ""
		_empty_label.visible = true
		_btn_delete.visible = false
		return
	var msg: Dictionary = _find_message(_selected_id)
	if msg.is_empty():
		_selected_id = ""
		_update_detail()
		return
	_empty_label.visible = false
	_btn_delete.visible = true
	_detail_from.text = "FROM: " + msg.get("from_handle", "???")
	_detail_subject.text = msg.get("subject", "(no subject)")
	_detail_time.text = _format_timestamp(msg.get("timestamp", 0.0))
	_detail_body.text = msg.get("body", "")
	# Clear previous attachment UI
	if _attachment_container and is_instance_valid(_attachment_container):
		_attachment_container.queue_free()
		_attachment_container = null
	# Render mission_offer attachments
	var attachments: Array = msg.get("attachments", [])
	for att: Dictionary in attachments:
		if att.get("type", "") == "mission_offer":
			var mission_id: String = att.get("mission_id", "")
			if not MissionManager.active_missions.has(mission_id) \
					and not GameManager.completed_missions.has(mission_id):
				if _attachment_container == null:
					_attachment_container = VBoxContainer.new()
					_attachment_container.add_theme_constant_override("separation", 4)
					_detail_body.get_parent().add_child(_attachment_container)
				var sep := HSeparator.new()
				_attachment_container.add_child(sep)
				_attachment_container.add_child(_make_accept_button(mission_id))


func _find_message(msg_id: String) -> Dictionary:
	for msg: Dictionary in CommsManager.inbox:
		if msg.get("id", "") == msg_id:
			return msg
	return {}


func _format_timestamp(ts: float) -> String:
	if ts <= 0.0:
		return ""
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(ts))
	return "%04d-%02d-%02d  %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= CommsManager.inbox.size():
		return
	var msg: Dictionary = CommsManager.inbox[index]
	_selected_id = msg.get("id", "")
	if not msg.get("read", true):
		CommsManager.mark_read(_selected_id)
		_refresh_inbox()
		_inbox_list.select(index)
	_update_detail()


func _on_delete_pressed() -> void:
	if _selected_id.is_empty():
		return
	CommsManager.delete_message(_selected_id)
	_selected_id = ""
	EventBus.log_message.emit("Message deleted.", "info")
	_refresh_inbox()


func _on_message_received(_msg_id: String) -> void:
	_refresh_inbox()


func _make_accept_button(mission_id: String) -> Button:
	var btn := Button.new()
	var mission: MissionData = MissionManager.available_missions.get(mission_id)
	btn.text = "[ ACCEPT MISSION: %s ]" % (mission.title if mission else mission_id)
	btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	btn.add_theme_font_size_override("font_size", 11)
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.0, 0.88, 1.0, 0.08)
	sn.border_color = Color(0.0, 0.88, 1.0, 0.5)
	sn.set_border_width_all(1)
	sn.content_margin_top    = 6
	sn.content_margin_bottom = 6
	sn.content_margin_left   = 10
	sn.content_margin_right  = 10
	btn.add_theme_stylebox_override("normal", sn)
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.0, 0.88, 1.0, 0.2)
	btn.add_theme_stylebox_override("hover", sh)
	btn.pressed.connect(func() -> void:
		MissionManager.accept_mission(mission_id)
		_update_detail()
	)
	return btn
