class_name FactionJobBoard
extends ToolWindow
## Per-faction job board. Shows available and active missions for the
## currently connected node's faction. Closes automatically on disconnect.

# ── Colour constants ───────────────────────────────────────────────────────────
const COL_CYAN  := Color(0.0,  0.88, 1.0)
const COL_AMBER := Color(1.0,  0.75, 0.0)
const COL_MUTED := Color(0.35, 0.35, 0.45)
const COL_LIGHT := Color(0.75, 0.92, 1.0)

var _faction_id:   String = ""
var _faction_name: String = ""
var _active_list:  VBoxContainer
var _avail_list:   VBoxContainer
var _empty_active: Label
var _empty_avail:  Label


func _ready() -> void:
	super._ready()
	var node_id: String     = NetworkSim.connected_node_id
	var data:    Dictionary = NetworkSim.get_node_data(node_id)
	_faction_id   = data.get("faction_id",   "")
	_faction_name = data.get("organisation", data.get("name", "Unknown"))
	title_label.text = "JOB BOARD — %s" % _faction_name.to_upper()

	_setup_layout()

	EventBus.network_disconnected.connect(queue_free)
	EventBus.mission_accepted.connect(func(_id: String) -> void: _refresh())
	EventBus.mission_completed.connect(func(_id: String) -> void: _refresh())
	EventBus.mission_objective_completed.connect(
		func(_id: String, _idx: int) -> void: _refresh()
	)
	_refresh()


# ── Layout ─────────────────────────────────────────────────────────────────────

func _setup_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom", 10)
	content_area.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var active_header := _make_label("ACTIVE MISSIONS", COL_MUTED)
	vbox.add_child(active_header)

	var active_scroll := ScrollContainer.new()
	active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(active_scroll)

	_active_list = VBoxContainer.new()
	_active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_list.add_theme_constant_override("separation", 4)
	active_scroll.add_child(_active_list)

	_empty_active = _make_label("No active missions.", COL_MUTED)
	_active_list.add_child(_empty_active)

	vbox.add_child(HSeparator.new())

	var avail_header := _make_label("AVAILABLE", COL_MUTED)
	vbox.add_child(avail_header)

	var avail_scroll := ScrollContainer.new()
	avail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avail_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(avail_scroll)

	_avail_list = VBoxContainer.new()
	_avail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avail_list.add_theme_constant_override("separation", 4)
	avail_scroll.add_child(_avail_list)

	_empty_avail = _make_label("No missions available.", COL_MUTED)
	_avail_list.add_child(_empty_avail)


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_rebuild_active()
	_rebuild_available()


func _rebuild_active() -> void:
	for child in _active_list.get_children():
		if child != _empty_active:
			child.queue_free()

	var missions: Dictionary = MissionManager.active_missions
	var has_any := false
	for mission_id: String in missions:
		var mission: MissionData = missions[mission_id]
		if mission.faction_id == _faction_id:
			_add_active_entry(mission)
			has_any = true
	_empty_active.visible = not has_any


func _rebuild_available() -> void:
	for child in _avail_list.get_children():
		if child != _empty_avail:
			child.queue_free()

	var available := MissionManager.available_missions
	var rating: int = GameManager.player_data.get("rating", 1)
	var has_any := false
	for mission_id: String in available:
		var mission: MissionData = available[mission_id]
		if mission.faction_id != _faction_id:
			continue
		if mission.min_rep > rating:
			continue
		if MissionManager.active_missions.has(mission_id):
			continue
		if GameManager.completed_missions.has(mission_id):
			continue
		_add_available_entry(mission)
		has_any = true
	_empty_avail.visible = not has_any


# ── Entry builders ─────────────────────────────────────────────────────────────

func _add_active_entry(mission: MissionData) -> void:
	_active_list.add_child(_make_label("▶  " + mission.title, COL_CYAN))

	for obj: ObjectiveData in mission.objectives:
		var prefix := "  [x]  " if obj.completed else "  [ ]  "
		var color  := COL_CYAN if obj.completed else COL_LIGHT
		_active_list.add_child(_make_label(prefix + obj.description, color))

	_active_list.add_child(
		_make_label("  Reward: %d credits" % mission.reward_credits, COL_AMBER)
	)
	_active_list.add_child(HSeparator.new())


func _add_available_entry(mission: MissionData) -> void:
	var row := HBoxContainer.new()

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_make_label(mission.title, COL_LIGHT))
	var desc := _make_label(mission.description, Color(0.45, 0.6, 0.65))
	desc.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(desc)
	info.add_child(_make_label("+%d credits" % mission.reward_credits, COL_AMBER))
	row.add_child(info)

	var btn := Button.new()
	btn.text = "ACCEPT"
	btn.add_theme_color_override("font_color", COL_CYAN)
	btn.pressed.connect(func() -> void: MissionManager.accept_mission(mission.id))
	row.add_child(btn)

	_avail_list.add_child(row)
	_avail_list.add_child(HSeparator.new())


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl
