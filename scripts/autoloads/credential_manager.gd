class_name CredentialManager
extends Node
## Manages stolen/discovered credentials per network node.
## Stored as node_id → Array of credential dicts.

# ── Credential storage ────────────────────────────────────────────────────────
# node_id → Array[{ username: String, password_hash: String, role: String,
#                    cracked: bool, plaintext: String }]
var credentials: Dictionary = {}


func _ready() -> void:
	credentials = GameManager.credentials.duplicate(true)


# ── Public API ────────────────────────────────────────────────────────────────

func add_credentials(node_id: String, creds: Array) -> void:
	if not credentials.has(node_id):
		credentials[node_id] = []
	for cred: Dictionary in creds:
		var entry := {
			"username": cred.get("username", ""),
			"password_hash": cred.get("password_hash", ""),
			"role": cred.get("role", "unknown"),
			"cracked": cred.get("cracked", false),
			"plaintext": cred.get("plaintext", ""),
		}
		# Avoid duplicates by username
		var found := false
		for existing: Dictionary in credentials[node_id]:
			if existing["username"] == entry["username"]:
				found = true
				break
		if not found:
			credentials[node_id].append(entry)
	_sync_to_game_manager()
	EventBus.credentials_stolen.emit(node_id, creds.size())


func get_credentials(node_id: String) -> Array:
	return credentials.get(node_id, [])


func has_credentials(node_id: String) -> bool:
	return credentials.has(node_id) and not credentials[node_id].is_empty()


func mark_cracked(node_id: String, username: String, plaintext: String) -> void:
	if not credentials.has(node_id):
		return
	for cred: Dictionary in credentials[node_id]:
		if cred["username"] == username:
			cred["cracked"] = true
			cred["plaintext"] = plaintext
			break
	_sync_to_game_manager()


# ── Internal ──────────────────────────────────────────────────────────────────

func _sync_to_game_manager() -> void:
	GameManager.credentials = credentials.duplicate(true)
