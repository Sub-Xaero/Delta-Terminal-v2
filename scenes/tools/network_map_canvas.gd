class_name NetworkMapCanvas
extends Control
## Draws the world map background (coordinate grid + continent outlines) and
## connection edges between network nodes.
## Node widgets are added as children and positioned by NetworkMap.

# ── Projection constants ─────────────────────────────────────────────────────
const LAT_MIN: float = -55.0
const LAT_MAX: float =  80.0

# ── Colours ──────────────────────────────────────────────────────────────────
const _COL_CONTINENT_FILL    := Color(0.0, 0.88, 1.0, 0.04)
const _COL_CONTINENT_OUTLINE := Color(0.0, 0.88, 1.0, 0.18)
const _COL_GRID              := Color(0.0, 0.88, 1.0, 0.06)
const _COL_EQUATOR           := Color(0.0, 0.88, 1.0, 0.12)

# ── Continent outlines (each point is Vector2(longitude, latitude)) ───────────
var _continent_outlines: Array = [
	# North America
	[
		Vector2(-168, 71), Vector2(-141, 60), Vector2(-124, 49),
		Vector2(-117, 32), Vector2(-105, 23), Vector2(-90,  16),
		Vector2(-83,  10), Vector2(-82,  25), Vector2(-74,  40),
		Vector2(-66,  44), Vector2(-56,  47), Vector2(-60,  52),
		Vector2(-85,  72), Vector2(-140, 73), Vector2(-168, 71),
	],
	# South America
	[
		Vector2(-80,   9), Vector2(-63,  11), Vector2(-35,  -5),
		Vector2(-34, -22), Vector2(-50, -33), Vector2(-65, -55),
		Vector2(-67, -56), Vector2(-71, -52), Vector2(-75, -45),
		Vector2(-71, -30), Vector2(-70, -15), Vector2(-77,  -1),
		Vector2(-80,   9),
	],
	# Europe
	[
		Vector2( -9, 36), Vector2( -9, 44), Vector2( -4, 48),
		Vector2(  2, 51), Vector2(  8, 55), Vector2( 10, 60),
		Vector2( 28, 71), Vector2( 30, 70), Vector2( 24, 59),
		Vector2( 28, 60), Vector2( 30, 60), Vector2( 30, 50),
		Vector2( 28, 42), Vector2( 36, 37), Vector2( 26, 38),
		Vector2( 22, 40), Vector2( 14, 38), Vector2(  3, 37),
		Vector2( -8, 36), Vector2( -9, 36),
	],
	# Africa
	[
		Vector2( -6, 36), Vector2( 10, 37), Vector2( 32, 31),
		Vector2( 43, 12), Vector2( 51, 12), Vector2( 43,-12),
		Vector2( 35,-25), Vector2( 18,-34), Vector2( 12,-28),
		Vector2(  0, -5), Vector2(-17, 15), Vector2( -6, 36),
	],
	# Asia (main body; India, SE Asia, and Arabian Peninsula included in outline)
	[
		Vector2( 26, 38), Vector2( 40, 42), Vector2( 52, 42),
		Vector2( 60, 50), Vector2( 95, 55), Vector2(130, 55),
		Vector2(141, 50), Vector2(145, 43), Vector2(140, 35),
		Vector2(122, 28), Vector2(110, 18), Vector2(100,  1),
		Vector2( 90, 22), Vector2( 80, 10), Vector2( 72, 22),
		Vector2( 60, 25), Vector2( 43, 22), Vector2( 37, 22),
		Vector2( 34, 28), Vector2( 36, 37), Vector2( 26, 38),
	],
	# Australia
	[
		Vector2(113,-22), Vector2(116,-34), Vector2(130,-33),
		Vector2(137,-35), Vector2(145,-38), Vector2(152,-28),
		Vector2(150,-20), Vector2(143,-17), Vector2(135,-13),
		Vector2(128,-14), Vector2(122,-18), Vector2(113,-22),
	],
	# Greenland
	[
		Vector2(-25, 71), Vector2(-18, 77), Vector2(-25, 83),
		Vector2(-38, 83), Vector2(-52, 82), Vector2(-57, 76),
		Vector2(-44, 60), Vector2(-40, 65), Vector2(-25, 71),
	],
]

var _edges: Array = []  # Array of { from:Vector2, to:Vector2, color:Color, width:float }


func update_edges(edges: Array) -> void:
	_edges = edges
	queue_redraw()


func _geo_to_canvas(lon: float, lat: float) -> Vector2:
	return Vector2(
		(lon + 180.0) / 360.0 * size.x,
		(LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * size.y
	)


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_draw_grid()
	_draw_continents()
	for edge in _edges:
		draw_line(edge.from, edge.to, edge.color, edge.width, true)


func _draw_grid() -> void:
	for lat: float in [-30.0, 0.0, 30.0, 60.0]:
		var col := _COL_EQUATOR if lat == 0.0 else _COL_GRID
		draw_line(_geo_to_canvas(-180.0, lat), _geo_to_canvas(180.0, lat), col, 1.0)
	for lon: float in [-150.0, -120.0, -90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0, 120.0, 150.0]:
		draw_line(_geo_to_canvas(lon, LAT_MAX), _geo_to_canvas(lon, LAT_MIN), _COL_GRID, 1.0)


func _draw_continents() -> void:
	for outline: Array in _continent_outlines:
		var pts := PackedVector2Array()
		for p: Vector2 in outline:
			pts.append(_geo_to_canvas(p.x, p.y))
		draw_colored_polygon(pts, _COL_CONTINENT_FILL)
		draw_polyline(pts, _COL_CONTINENT_OUTLINE, 1.0)
