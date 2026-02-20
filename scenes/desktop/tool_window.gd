class_name ToolWindow
extends Panel
## Base draggable tool window. Instantiate this scene (or a scene inheriting it)
## via WindowManager.spawn_tool_window(). Never add directly to the scene tree.

signal window_closed(tool_name: String)
signal window_focused(tool_name: String)

@export var tool_name: String = "Tool"

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _close_hovered: bool = false

const _CORNER_CUT   := 10.0
const _BORDER_COLOR := Color(0.0, 0.88, 1.0, 0.9)

@onready var title_bar: Panel = $TitleBar
@onready var title_label: Label = $TitleBar/TitleLabel
@onready var close_button: Button = $TitleBar/CloseButton
@onready var content_area: Control = $ContentArea


func _ready() -> void:
	title_label.text = tool_name
	close_button.pressed.connect(_on_close_pressed)
	title_bar.gui_input.connect(_on_title_bar_input)
	gui_input.connect(_on_self_input)
	_apply_theme()


func _apply_theme() -> void:
	# TitleBar: transparent — its region is drawn as a polygon in _draw()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0, 0, 0, 0)
	title_bar.add_theme_stylebox_override("panel", title_style)

	# Panel StyleBox: transparent bg (fill drawn as polygon in _draw) + glow shadow
	var window_style := StyleBoxFlat.new()
	window_style.bg_color     = Color(0, 0, 0, 0)
	window_style.shadow_color = Color(0.0, 0.88, 1.0, 0.30)
	window_style.shadow_size  = 14
	add_theme_stylebox_override("panel", window_style)

	title_label.add_theme_color_override("font_color", Color(0.05, 0.02, 0.12))

	# Close button: transparent bg — polygon drawn in _draw(); ✕ drawn by widget
	var close_empty := StyleBoxEmpty.new()
	close_button.add_theme_stylebox_override("normal",  close_empty)
	close_button.add_theme_stylebox_override("hover",   close_empty)
	close_button.add_theme_stylebox_override("pressed", close_empty)
	close_button.add_theme_stylebox_override("focus",   close_empty)
	close_button.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.mouse_entered.connect(func(): _close_hovered = true;  queue_redraw())
	close_button.mouse_exited.connect( func(): _close_hovered = false; queue_redraw())


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := _CORNER_CUT
	if w < c * 2.0 or h < c * 2.0:
		return
	const TB := 28.0  # title bar height

	# Full window chamfered background
	var body_pts := PackedVector2Array([
		Vector2(c, 0), Vector2(w - c, 0),
		Vector2(w, c), Vector2(w, h - c),
		Vector2(w - c, h), Vector2(c, h),
		Vector2(0, h - c), Vector2(0, c),
	])
	draw_polygon(body_pts, PackedColorArray([Color(0.04, 0.03, 0.10, 0.95)]))

	# Title bar — hot pink, right edge follows close button's bottom-left chamfer
	var title_pts := PackedVector2Array([
		Vector2(c, 0),           Vector2(w - TB, 0),
		Vector2(w - TB, TB - c), Vector2(w - c, TB),
		Vector2(0, TB),          Vector2(0, c),
	])
	draw_polygon(title_pts, PackedColorArray([Color(1.0, 0.08, 0.55)]))

	# Close button — contrasting dark navy, cyan border; brightens on hover
	var btn_bg := Color(0.08, 0.12, 0.20) if _close_hovered else Color(0.04, 0.03, 0.10)
	var btn_pts := PackedVector2Array([
		Vector2(w - TB, 0),
		Vector2(w - c,  0),
		Vector2(w,      c),
		Vector2(w,      TB),
		Vector2(w - c,  TB),
		Vector2(w - TB, TB - c),
	])
	draw_polygon(btn_pts, PackedColorArray([btn_bg]))
	var btn_border := PackedVector2Array(btn_pts)
	btn_border.append(btn_pts[0])
	draw_polyline(btn_border, Color(0.0, 0.88, 1.0, 0.8), 1.0, true)

	# Chamfered border outline
	var border_pts := PackedVector2Array(body_pts)
	border_pts.append(body_pts[0])
	draw_polyline(border_pts, _BORDER_COLOR, 1.5, true)

	# Cyan left accent stripe on content area (below title bar)
	draw_rect(Rect2(0, TB, 3, h - TB - c), Color(0.0, 0.88, 1.0, 0.6))
	queue_redraw()


func _on_self_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.context_menu_requested.emit(get_global_mouse_position())
		window_focused.emit(tool_name)


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				window_focused.emit(tool_name)
			else:
				_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_screen()
		get_viewport().set_input_as_handled()


func _clamp_to_screen() -> void:
	var screen_size := get_viewport_rect().size
	global_position.x = clamp(global_position.x, 0.0, screen_size.x - size.x)
	global_position.y = clamp(global_position.y, 0.0, screen_size.y - size.y)


func set_tool_name(name: String) -> void:
	tool_name = name
	if is_node_ready() and title_label:
		title_label.text = name


func _on_close_pressed() -> void:
	window_closed.emit(tool_name)
	EventBus.tool_closed.emit(tool_name)
	queue_free()
