class_name VoiceManagerClass
extends Node
## Manages voice samples extracted from nodes and voice-based authentication.

var voice_samples: Dictionary = {}      # node_id -> Array[Dictionary] of audio file metadata
var authenticated_nodes: Array = []     # node IDs authenticated via voice comms


func _ready() -> void:
	pass


# ── Public API ────────────────────────────────────────────────────────────────

func store_sample(node_id: String, file_dict: Dictionary) -> void:
	if not voice_samples.has(node_id):
		voice_samples[node_id] = []
	var existing: Array = voice_samples[node_id]
	for existing_sample: Dictionary in existing:
		if existing_sample.get("name", "") == file_dict.get("name", ""):
			return  # already stored
	existing.append(file_dict.duplicate())
	voice_samples[node_id] = existing
	EventBus.log_message.emit(
		"Voice sample stored: %s from %s" % [file_dict.get("name", "?"), node_id], "info"
	)


func has_sample_for(node_id: String) -> bool:
	return voice_samples.has(node_id) and not voice_samples[node_id].is_empty()


func authenticate_node(node_id: String) -> bool:
	if not has_sample_for(node_id):
		EventBus.log_message.emit("No voice sample for %s — authentication failed." % node_id, "error")
		return false
	if node_id not in authenticated_nodes:
		authenticated_nodes.append(node_id)
	EventBus.voip_authentication_granted.emit(node_id)
	EventBus.log_message.emit("Voice authentication granted for %s." % node_id, "info")
	return true


func get_all_samples() -> Dictionary:
	return voice_samples.duplicate(true)


func get_save_data() -> Dictionary:
	return {
		"voice_samples": voice_samples.duplicate(true),
		"authenticated_nodes": authenticated_nodes.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	voice_samples = data.get("voice_samples", {})
	authenticated_nodes.assign(data.get("authenticated_nodes", []))
