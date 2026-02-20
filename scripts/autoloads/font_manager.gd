extends Node
## Applies the Rajdhani project font at runtime, bypassing .tres loading quirks.
## Registered as an autoload so it runs before any scene.

func _ready() -> void:
	var font: Font = load("res://assets/fonts/Rajdhani-Regular.ttf")
	if not font:
		push_warning("FontManager: failed to load Rajdhani-Regular.ttf")
		return

	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 14

	# Window.theme propagates to all Controls in the scene tree
	get_tree().get_root().theme = t
