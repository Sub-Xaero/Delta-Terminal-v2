extends ToolWindow
## Displays player handle, credits, rating, heat, and faction reputation.

@onready var _handle_label: Label = $ContentArea/Margin/VBox/HandleLabel
@onready var _credits_label: Label = $ContentArea/Margin/VBox/StatsGrid/CreditsValue
@onready var _rating_label: Label = $ContentArea/Margin/VBox/StatsGrid/RatingValue
@onready var _heat_label: Label = $ContentArea/Margin/VBox/HeatRow/HeatValue
@onready var _heat_bar: ProgressBar = $ContentArea/Margin/VBox/HeatBar
@onready var _faction_list: VBoxContainer = $ContentArea/Margin/VBox/FactionScroll/FactionList

var _heat_bar_fill: StyleBoxFlat = null


func _ready() -> void:
	super._ready()
	_apply_profile_theme()
	EventBus.player_stats_changed.connect(_refresh)
	EventBus.player_heat_changed.connect(_on_heat_changed)
	EventBus.faction_rep_changed.connect(_on_faction_rep_changed)
	_refresh()


# ── Theme ─────────────────────────────────────────────────────────────────────

func _apply_profile_theme() -> void:
	_handle_label.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	_handle_label.add_theme_font_size_override("font_size", 18)

	_credits_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_credits_label.add_theme_font_size_override("font_size", 12)
	_rating_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_rating_label.add_theme_font_size_override("font_size", 12)

	_heat_label.add_theme_font_size_override("font_size", 12)

	# Heat bar styles
	_heat_bar_fill = StyleBoxFlat.new()
	_heat_bar_fill.bg_color = Color(0.0, 0.88, 0.4)
	_heat_bar_fill.corner_radius_top_left     = 2
	_heat_bar_fill.corner_radius_top_right    = 2
	_heat_bar_fill.corner_radius_bottom_left  = 2
	_heat_bar_fill.corner_radius_bottom_right = 2
	_heat_bar.add_theme_stylebox_override("fill", _heat_bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color     = Color(0.04, 0.06, 0.10)
	bar_bg.border_color = Color(0.0, 0.88, 1.0, 0.25)
	bar_bg.set_border_width_all(1)
	_heat_bar.add_theme_stylebox_override("background", bar_bg)


# ── Data refresh ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	var pd: Dictionary = GameManager.player_data
	_handle_label.text = pd.get("handle", "ghost").to_upper()
	_credits_label.text = "%d CR" % pd.get("credits", 0)
	_rating_label.text = "%d" % pd.get("rating", 1)
	_update_heat(pd.get("heat", 0))
	_rebuild_factions()


func _update_heat(heat: int) -> void:
	_heat_label.text = "%d" % heat
	_heat_bar.value = heat
	var col: Color = _heat_color(heat)
	_heat_label.add_theme_color_override("font_color", col)
	if _heat_bar_fill:
		_heat_bar_fill.bg_color = col


func _heat_color(heat: int) -> Color:
	if heat < 50:
		return Color(0.0, 0.88, 0.4)    # green
	elif heat < 75:
		return Color(1.0, 0.75, 0.0)    # amber
	else:
		return Color(1.0, 0.08, 0.55)   # red / hot pink


func _rebuild_factions() -> void:
	for child in _faction_list.get_children():
		child.queue_free()

	if not FactionManager.factions.is_empty():
		for faction_id: String in FactionManager.factions:
			var fd: FactionData = FactionManager.factions[faction_id]
			var rep: int = FactionManager.get_rep(faction_id)
			_add_faction_row(fd.name, fd.color, rep)
	else:
		# Fallback: read from player_data directly
		var reps: Dictionary = GameManager.player_data.get("faction_rep", {})
		for faction_id: String in reps:
			var rep: int = reps[faction_id]
			_add_faction_row(faction_id, Color(0.55, 0.65, 0.7), rep)


func _add_faction_row(faction_name: String, col: Color, rep: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = faction_name
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", col)
	hbox.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size   = Vector2(0, 8)
	bar.min_value     = -100.0
	bar.max_value     = 100.0
	bar.value         = rep
	bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.corner_radius_top_left     = 2
	fill.corner_radius_top_right    = 2
	fill.corner_radius_bottom_left  = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.04, 0.06, 0.10)
	bg.border_color = Color(0.0, 0.88, 1.0, 0.2)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.text = "%+d" % rep
	val_lbl.custom_minimum_size = Vector2(32, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.7))
	hbox.add_child(val_lbl)

	_faction_list.add_child(hbox)


# ── Callbacks ─────────────────────────────────────────────────────────────────

func _on_heat_changed(new_heat: int) -> void:
	_update_heat(new_heat)


func _on_faction_rep_changed(_faction_id: String, _new_rep: int) -> void:
	_rebuild_factions()
