extends Node
## Manages the player's in-game message inbox.
## Messages arrive from factions, mission contacts, and system notifications.

var inbox: Array = []

var _next_id: int = 0


func _ready() -> void:
	_load_inbox()
	if inbox.is_empty():
		_seed_welcome_message()


# ── Public API ────────────────────────────────────────────────────────────────

func send_message(msg: Dictionary) -> void:
	if not msg.has("id"):
		msg["id"] = _generate_id()
	if not msg.has("timestamp"):
		msg["timestamp"] = Time.get_unix_time_from_system()
	if not msg.has("read"):
		msg["read"] = false
	inbox.push_front(msg)
	_save_inbox()
	EventBus.comms_message_received.emit(msg["id"])


func mark_read(msg_id: String) -> void:
	for msg: Dictionary in inbox:
		if msg.get("id", "") == msg_id:
			msg["read"] = true
			_save_inbox()
			return


func delete_message(msg_id: String) -> void:
	for i in range(inbox.size()):
		if inbox[i].get("id", "") == msg_id:
			inbox.remove_at(i)
			_save_inbox()
			return


func get_unread_count() -> int:
	var count: int = 0
	for msg: Dictionary in inbox:
		if not msg.get("read", true):
			count += 1
	return count


# ── Persistence ───────────────────────────────────────────────────────────────

func _load_inbox() -> void:
	if not SaveManager.has_save():
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	inbox = data.get("comms_inbox", [])


func _save_inbox() -> void:
	# Write inbox into the next save by hooking into SaveManager's data.
	# SaveManager reads this when building save data.
	pass


func _seed_welcome_message() -> void:
	var msg: Dictionary = {
		"id": _generate_id(),
		"from_handle": "SYSTEM",
		"faction_id": "",
		"subject": "Welcome to Delta Terminal",
		"body": "Operator confirmed. Your handle has been registered on the network.\n\nUse the Network Map to connect to remote nodes. Complete missions to earn credits and build your reputation.\n\nWatch your heat level — too much attention from corporate security and they will trace you.\n\nGood luck, ghost.",
		"timestamp": Time.get_unix_time_from_system(),
		"read": false,
		"attachments": [],
	}
	inbox.append(msg)


func _generate_id() -> String:
	_next_id += 1
	return "msg_%d_%d" % [Time.get_ticks_msec(), _next_id]
