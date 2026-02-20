extends Node
## Loads, persists, and applies player settings to user://settings.cfg.
## Changes are applied immediately — no restart required.

const CONFIG_PATH := "user://settings.cfg"

# ── Settings values ───────────────────────────────────────────────────────────
var master_volume:   float = 1.0
var sfx_volume:      float = 1.0
var ambient_volume:  float = 1.0
var crt_enabled:     bool  = true
var crt_intensity:   float = 0.8
var fullscreen:      bool  = false
var autosave:        bool  = true

signal settings_changed()


func _ready() -> void:
	load_settings()
	_apply_display()


# ── Persistence ───────────────────────────────────────────────────────────────

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio",    "master_volume",  master_volume)
	config.set_value("audio",    "sfx_volume",     sfx_volume)
	config.set_value("audio",    "ambient_volume", ambient_volume)
	config.set_value("display",  "crt_enabled",    crt_enabled)
	config.set_value("display",  "crt_intensity",  crt_intensity)
	config.set_value("display",  "fullscreen",     fullscreen)
	config.set_value("gameplay", "autosave",       autosave)
	config.save(CONFIG_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return  # Keep defaults
	master_volume  = config.get_value("audio",    "master_volume",  1.0)
	sfx_volume     = config.get_value("audio",    "sfx_volume",     1.0)
	ambient_volume = config.get_value("audio",    "ambient_volume", 1.0)
	crt_enabled    = config.get_value("display",  "crt_enabled",    true)
	crt_intensity  = config.get_value("display",  "crt_intensity",  0.8)
	fullscreen     = config.get_value("display",  "fullscreen",     false)
	autosave       = config.get_value("gameplay", "autosave",       true)


# ── Setters (apply immediately + persist) ─────────────────────────────────────

func set_master_volume(val: float) -> void:
	master_volume = val
	_apply_audio()
	save_settings()


func set_sfx_volume(val: float) -> void:
	sfx_volume = val
	save_settings()


func set_ambient_volume(val: float) -> void:
	ambient_volume = val
	save_settings()


func set_crt_enabled(val: bool) -> void:
	crt_enabled = val
	settings_changed.emit()
	save_settings()


func set_crt_intensity(val: float) -> void:
	crt_intensity = val
	settings_changed.emit()
	save_settings()


func set_fullscreen(val: bool) -> void:
	fullscreen = val
	_apply_display()
	save_settings()


func set_autosave(val: bool) -> void:
	autosave = val
	save_settings()


# ── Internal apply helpers ────────────────────────────────────────────────────

func _apply_audio() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_linear(idx, master_volume)


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
