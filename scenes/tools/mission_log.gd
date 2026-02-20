class_name MissionLog
extends ToolWindow
## Mission list UI. Shows active missions with objective status and
## available missions with an Accept button.

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var active_list:  VBoxContainer = $ContentArea/Margin/VBox/ActiveScroll/ActiveList
@onready var avail_list:   VBoxContainer = $ContentArea/Margin/VBox/AvailScroll/AvailList
@onready var empty_active: Label         = $ContentArea/Margin/VBox/ActiveScroll/ActiveList/EmptyActive
@onready var empty_avail:  Label         = $ContentArea/Margin/VBox/AvailScroll/AvailList/EmptyAvail


func _ready() -> void:
	super._ready()
	EventBus.mission_accepted.connect(func(_id: String) -> void: _refresh())
	EventBus.mission_completed.connect(func(_id: String) -> void: _refresh())
	EventBus.mission_objective_completed.connect(
		func(_id: String, _idx: int) -> void: _refresh()
	)
	_setup_theme()
	_refresh()


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_rebuild_active()
	_rebuild_available()


func _rebuild_active() -> void:
	for child in active_list.get_children():
		if child != empty_active:
			child.queue_free()

	var missions: Dictionary = MissionManager.active_missions
	empty_active.visible = missions.is_empty()

	for mission_id: String in missions:
		_add_active_entry(missions[mission_id])


func _rebuild_available() -> void:
	for child in avail_list.get_children():
		if child != empty_avail:
			child.queue_free()

	var available := MissionManager.available_missions
	var has_any := false
	for mission_id: String in available:
		if not MissionManager.active_missions.has(mission_id) \
				and not GameManager.completed_missions.has(mission_id):
			_add_available_entry(available[mission_id])
			has_any = true

	empty_avail.visible = not has_any


# ── Entry builders ─────────────────────────────────────────────────────────────

func _add_active_entry(mission: MissionData) -> void:
	var title := _make_label("▶  " + mission.title, Color(0.0, 0.88, 1.0))
	active_list.add_child(title)

	for obj: ObjectiveData in mission.objectives:
		var prefix := "  [x]  " if obj.completed else "  [ ]  "
		var color  := Color(0.0, 0.88, 1.0) if obj.completed else Color(0.75, 0.92, 1.0)
		active_list.add_child(_make_label(prefix + obj.description, color))

	active_list.add_child(
		_make_label("  Reward: %d credits" % mission.reward_credits, Color(1.0, 0.75, 0.0))
	)
	active_list.add_child(HSeparator.new())


func _add_available_entry(mission: MissionData) -> void:
	var row := HBoxContainer.new()

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_make_label(mission.title, Color(0.75, 0.92, 1.0)))
	var desc := _make_label(mission.description, Color(0.45, 0.6, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(desc)
	info.add_child(_make_label("+%d credits" % mission.reward_credits, Color(1.0, 0.75, 0.0)))
	row.add_child(info)

	var btn := Button.new()
	btn.text = "ACCEPT"
	btn.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	btn.pressed.connect(func() -> void: MissionManager.accept_mission(mission.id))
	row.add_child(btn)

	avail_list.add_child(row)
	avail_list.add_child(HSeparator.new())


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _setup_theme() -> void:
	var header_color := Color(0.45, 0.6, 0.65)
	($ContentArea/Margin/VBox/ActiveHeader as Label).add_theme_color_override("font_color", header_color)
	($ContentArea/Margin/VBox/AvailHeader  as Label).add_theme_color_override("font_color", header_color)
	empty_active.add_theme_color_override("font_color", header_color)
	empty_avail.add_theme_color_override("font_color", header_color)
