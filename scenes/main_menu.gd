class_name MainMenu
extends Control
## Entry point scene — the in-game OS shell is entered through here.
## Shows New Game / Continue / Settings / Quit with a live scrolling
## terminal log as atmosphere behind the menu.

const BootSequenceScene := "res://scenes/ui/boot_sequence.tscn"
const SettingsScene     := preload("res://scenes/ui/settings.tscn")

const _C_CYAN   := Color(0.0,  0.88, 1.0)
const _C_PINK   := Color(1.0,  0.08, 0.55)
const _C_AMBER  := Color(1.0,  0.75, 0.0)
const _C_MUTED  := Color(0.35, 0.35, 0.45)
const _C_TEXT   := Color(0.75, 0.92, 1.0)
const _C_BG     := Color(0.04, 0.03, 0.10, 0.96)
const _C_TITLE  := Color(0.06, 0.04, 0.14)

const _LOG_LINES: Array[String] = [
	"SYS  Kernel 5.15.0-delta initialised",
	"NET  Interface eth0 bound to 10.0.0.1",
	"SEC  Firewall rule-set v3 loaded — 1024 rules",
	"SYS  Entropy pool seeded — 512 bits available",
	"NET  Peer 81.14.22.1 heartbeat acknowledged",
	"MEM  Heap: 2.1 GB allocated / 4.0 GB total",
	"AUTH Certificate chain validated — 256-bit ECC",
	"NET  Broadcast scan: no hostile probes detected",
	"SYS  Clock synchronised — delta 0.003 ms",
	"SEC  IDS: anomaly threshold nominal",
	"NET  Routing table updated — 18 entries",
	"SYS  Daemon watchdog cycle 0x7F2A — OK",
	"MEM  GC pass complete — 48 MB reclaimed",
	"NET  Peer 193.62.18.5 latency 22 ms",
	"SEC  Port scan blocked from 104.21.8.3",
	"SYS  Swap usage: 0 MB",
	"AUTH Session token refreshed",
	"NET  DNS cache flushed — 64 entries cleared",
	"SYS  Temperature nominal — 41°C",
	"SEC  Intrusion attempt logged from 5.188.62.41",
	"NET  Peer 84.23.119.41 connection refused",
	"SYS  Virtual memory pages: 0 faulted",
	"AUTH Challenge-response handshake accepted",
	"NET  Packet loss < 0.01%% — link healthy",
]

# ── Node refs ──────────────────────────────────────────────────────────────────
var _log_label:      RichTextLabel
var _menu_box:       VBoxContainer
var _handle_box:     VBoxContainer
var _handle_input:   LineEdit
var _continue_btn:   Button
var _log_timer:      Timer
var _log_idx:        int = 0
var _settings_win:   ToolWindow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_scrolling_log()
	_build_menu()
	_continue_btn.disabled = not SaveManager.has_save()
	_start_log()


# ── Build ──────────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var crt := ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/desktop/crt_background.gdshader")
	crt.material = mat
	add_child(crt)


func _build_scrolling_log() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_log_label = RichTextLabel.new()
	_log_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_label.offset_left   = 24.0
	_log_label.offset_top    = 24.0
	_log_label.offset_right  = -24.0
	_log_label.offset_bottom = -24.0
	_log_label.bbcode_enabled   = true
	_log_label.scroll_following = true
	_log_label.selection_enabled = false
	_log_label.modulate = Color(1.0, 1.0, 1.0, 0.14)
	_log_label.add_theme_font_size_override("normal_font_size", 11)
	_log_label.add_theme_color_override("default_color", _C_CYAN)
	overlay.add_child(_log_label)


func _build_menu() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	# Outer panel ──────────────────────────────────────────────────────────────
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = _C_BG
	bg_style.border_color = _C_CYAN
	bg_style.set_border_width_all(1)
	bg_style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", bg_style)
	centre.add_child(panel)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	# Title ────────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "DELTA TERMINAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", _C_CYAN)
	outer.add_child(title)

	var sub := Label.new()
	sub.text = "v2.0  //  OPERATIVE CONSOLE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", _C_MUTED)
	outer.add_child(sub)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(_C_CYAN, 0.4))
	outer.add_child(sep)
	outer.add_child(_spacer(4))

	# Menu buttons ─────────────────────────────────────────────────────────────
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	outer.add_child(_menu_box)

	var new_btn := _make_btn("[ NEW GAME ]", _C_CYAN)
	new_btn.pressed.connect(_on_new_game_pressed)
	_menu_box.add_child(new_btn)

	_continue_btn = _make_btn("[ CONTINUE ]", _C_CYAN)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_menu_box.add_child(_continue_btn)

	var settings_btn := _make_btn("[ SETTINGS ]", _C_TEXT)
	settings_btn.pressed.connect(_on_settings_pressed)
	_menu_box.add_child(settings_btn)

	var quit_btn := _make_btn("[ QUIT ]", _C_PINK)
	quit_btn.pressed.connect(_on_quit_pressed)
	_menu_box.add_child(quit_btn)

	# Handle input form (hidden until New Game) ─────────────────────────────────
	_handle_box = VBoxContainer.new()
	_handle_box.add_theme_constant_override("separation", 8)
	_handle_box.visible = false
	outer.add_child(_handle_box)

	var lbl := Label.new()
	lbl.text = "ENTER OPERATIVE HANDLE:"
	lbl.add_theme_color_override("font_color", _C_TEXT)
	lbl.add_theme_font_size_override("font_size", 12)
	_handle_box.add_child(lbl)

	_handle_input = LineEdit.new()
	_handle_input.placeholder_text = "e.g.  ghost  ·  cipher  ·  null"
	_handle_input.max_length = 24
	_handle_input.add_theme_color_override("font_color", _C_CYAN)
	_handle_input.add_theme_color_override("font_placeholder_color", _C_MUTED)
	var inp_style := StyleBoxFlat.new()
	inp_style.bg_color = _C_TITLE
	inp_style.border_color = _C_CYAN
	inp_style.set_border_width_all(1)
	inp_style.set_content_margin_all(6.0)
	_handle_input.add_theme_stylebox_override("normal", inp_style)
	_handle_input.add_theme_stylebox_override("focus",  inp_style)
	_handle_input.text_submitted.connect(func(_t): _confirm_handle())
	_handle_box.add_child(_handle_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_handle_box.add_child(row)

	var confirm_btn := _make_btn("[ CONFIRM ]", _C_CYAN)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(_confirm_handle)
	row.add_child(confirm_btn)

	var back_btn := _make_btn("[ BACK ]", _C_MUTED)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_show_main_buttons)
	row.add_child(back_btn)

	outer.add_child(_spacer(4))

	# Version footer ───────────────────────────────────────────────────────────
	var ver := Label.new()
	ver.text = "build 2049.02"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color(_C_MUTED, 0.6))
	outer.add_child(ver)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_btn(label_text: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color",       col)
	btn.add_theme_color_override("font_hover_color", Color(col.r, col.g, col.b, 0.75))
	var n_style := StyleBoxFlat.new()
	n_style.bg_color = _C_TITLE
	n_style.border_color = col
	n_style.set_border_width_all(1)
	n_style.set_content_margin_all(8.0)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(col.r * 0.18, col.g * 0.18, col.b * 0.18)
	h_style.border_color = col
	h_style.set_border_width_all(1)
	h_style.set_content_margin_all(8.0)
	var d_style := n_style.duplicate()
	d_style.border_color = _C_MUTED
	btn.add_theme_stylebox_override("normal",   n_style)
	btn.add_theme_stylebox_override("hover",    h_style)
	btn.add_theme_stylebox_override("pressed",  h_style)
	btn.add_theme_stylebox_override("focus",    n_style)
	btn.add_theme_stylebox_override("disabled", d_style)
	return btn


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


# ── Scrolling log ──────────────────────────────────────────────────────────────

func _start_log() -> void:
	# Seed a few lines immediately so the background isn't empty
	for _i in 8:
		_add_log_line()
	_log_timer = Timer.new()
	_log_timer.wait_time = 0.7
	_log_timer.autostart = true
	_log_timer.timeout.connect(_add_log_line)
	add_child(_log_timer)


func _add_log_line() -> void:
	var ts := Time.get_time_string_from_system()
	var line := _LOG_LINES[_log_idx % _LOG_LINES.size()]
	_log_idx += 1
	_log_label.append_text("[color=#%s][%s]  %s[/color]\n" % [
		_C_CYAN.to_html(false), ts, line
	])


# ── Button handlers ────────────────────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	_menu_box.visible = false
	_handle_box.visible = true
	_handle_input.text = ""
	_handle_input.grab_focus()


func _show_main_buttons() -> void:
	_handle_box.visible = false
	_menu_box.visible = true


func _confirm_handle() -> void:
	var handle := _handle_input.text.strip_edges()
	if handle.is_empty():
		handle = "ghost"
	_start_new_game(handle)


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		_transition_to_boot()


func _on_settings_pressed() -> void:
	if _settings_win and is_instance_valid(_settings_win):
		return
	_settings_win = SettingsScene.instantiate()
	add_child(_settings_win)
	_settings_win.position = (size - _settings_win.custom_minimum_size) * 0.5


func _on_quit_pressed() -> void:
	get_tree().quit()


# ── Transitions ────────────────────────────────────────────────────────────────

func _start_new_game(handle: String) -> void:
	SaveManager.delete_save()
	GameManager.player_data["handle"]  = handle
	GameManager.player_data["credits"] = 1000
	GameManager.player_data["rating"]  = 1
	GameManager.active_missions.clear()
	GameManager.completed_missions.clear()
	_transition_to_boot()


func _transition_to_boot() -> void:
	get_tree().change_scene_to_file(BootSequenceScene)
