class_name BootSequence
extends Control
## Fake OS boot text that plays between the main menu and the desktop.
## Lines appear one by one, then the desktop scene is loaded.

const DESKTOP_SCENE := "res://scenes/desktop/desktop.tscn"

const _C_CYAN  := Color(0.0,  0.88, 1.0)
const _C_AMBER := Color(1.0,  0.75, 0.0)
const _C_MUTED := Color(0.35, 0.35, 0.45)

# ── Node refs ──────────────────────────────────────────────────────────────────
var _text:       RichTextLabel
var _line_timer: Timer
var _line_idx:   int = 0
var _boot_lines: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_boot_lines()
	_build_ui()

	_line_timer = Timer.new()
	_line_timer.wait_time  = 0.08
	_line_timer.autostart  = true
	_line_timer.timeout.connect(_append_next_line)
	add_child(_line_timer)


# ── Boot line data ─────────────────────────────────────────────────────────────

func _build_boot_lines() -> void:
	var handle: String = str(GameManager.player_data.get("handle", "operative")).to_upper()
	_boot_lines = [
		"",
		"  DELTA TERMINAL OS  v2.0.0-release",
		"  Copyright (c) 2049 Ghost Systems LLC — All rights reserved",
		"",
		"  Loading BIOS extensions ................. [  OK  ]",
		"  Probing memory banks (4096 MB) .......... [  OK  ]",
		"  Initialising encrypted volumes .......... [  OK  ]",
		"  Starting network stack .................. [  OK  ]",
		"  Loading kernel daemons .................. [  OK  ]",
		"  Mounting security modules ............... [  OK  ]",
		"  Calibrating entropy generator ........... [  OK  ]",
		"  Establishing secure channel ............. [  OK  ]",
		"  Loading operative profile ............... [  OK  ]",
		"",
		"  ──────────────────────────────────────────────────",
		"  >>  SYSTEM READY  <<",
		"  ──────────────────────────────────────────────────",
		"",
		"  Welcome back,  %s." % handle,
		"",
	]


# ── Build ──────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.01, 0.06)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   60)
	margin.add_theme_constant_override("margin_top",    60)
	margin.add_theme_constant_override("margin_right",  60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	_text = RichTextLabel.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.bbcode_enabled    = true
	_text.scroll_following  = true
	_text.selection_enabled = false
	_text.add_theme_color_override("default_color", _C_CYAN)
	_text.add_theme_font_size_override("normal_font_size", 13)
	margin.add_child(_text)


# ── Line-by-line reveal ────────────────────────────────────────────────────────

func _append_next_line() -> void:
	if _line_idx >= _boot_lines.size():
		_line_timer.stop()
		var t := get_tree().create_timer(0.8)
		t.timeout.connect(_launch_desktop)
		return

	var raw := _boot_lines[_line_idx]
	_line_idx += 1

	if raw.is_empty():
		_text.append_text("\n")
		return

	# Highlight the status tags
	if "[  OK  ]" in raw:
		var parts := raw.split("[  OK  ]")
		_text.append_text("[color=#%s]%s[/color]" % [_C_MUTED.to_html(false), parts[0]])
		_text.append_text("[color=#%s][  OK  ][/color]" % _C_CYAN.to_html(false))
		_text.append_text("\n")
	elif raw.strip_edges().begins_with(">>") or raw.strip_edges().begins_with("──"):
		_text.append_text("[color=#%s]%s[/color]\n" % [_C_AMBER.to_html(false), raw])
	elif raw.strip_edges().begins_with("Welcome"):
		_text.append_text("[color=#%s]%s[/color]\n" % [_C_CYAN.to_html(false), raw])
	else:
		_text.append_text("[color=#%s]%s[/color]\n" % [_C_MUTED.to_html(false), raw])


func _launch_desktop() -> void:
	get_tree().change_scene_to_file(DESKTOP_SCENE)
