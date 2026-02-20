extends Node
## Manages faction data and player reputation with each faction.
## Loaded from data/factions/*.tres at startup.

# ── Data ─────────────────────────────────────────────────────────────────────
var factions: Dictionary = {}   # id -> FactionData
var _rep: Dictionary = {}       # id -> int


func _ready() -> void:
	_load_factions()
	_sync_rep()


# ── Public API ───────────────────────────────────────────────────────────────

func get_rep(faction_id: String) -> int:
	return _rep.get(faction_id, 0)


func modify_rep(faction_id: String, delta: int) -> void:
	var current: int = _rep.get(faction_id, 0)
	var new_rep: int = clampi(current + delta, -100, 100)
	_rep[faction_id] = new_rep
	GameManager.player_data["faction_rep"][faction_id] = new_rep
	EventBus.faction_rep_changed.emit(faction_id, new_rep)


func get_faction(faction_id: String) -> FactionData:
	return factions.get(faction_id, null)


# ── Loading ──────────────────────────────────────────────────────────────────

func _load_factions() -> void:
	var dir := DirAccess.open("res://data/factions")
	if not dir:
		push_warning("FactionManager: Could not open res://data/factions — no factions loaded.")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load("res://data/factions/" + file_name)
			if res is FactionData:
				factions[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


func _sync_rep() -> void:
	var saved_rep: Dictionary = GameManager.player_data.get("faction_rep", {})
	for faction_id in factions:
		if saved_rep.has(faction_id):
			_rep[faction_id] = saved_rep[faction_id]
		else:
			_rep[faction_id] = factions[faction_id].starting_rep
			GameManager.player_data["faction_rep"][faction_id] = _rep[faction_id]
