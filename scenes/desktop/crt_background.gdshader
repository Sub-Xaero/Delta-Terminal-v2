shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.02, 0.02, 0.07, 1.0);
uniform float grid_size : hint_range(10.0, 200.0) = 40.0;
uniform float line_width : hint_range(0.5, 4.0) = 1.0;
uniform vec4 grid_color : source_color = vec4(0.0, 0.88, 1.0, 1.0);
uniform float grid_alpha : hint_range(0.0, 0.3) = 0.06;
uniform float accent_alpha : hint_range(0.0, 0.5) = 0.12;
uniform float accent_cells : hint_range(2.0, 8.0) = 4.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	// Pixel-space grid (assumes 1280×720 viewport)
	vec2 px = UV * vec2(1280.0, 720.0);

	float gs = grid_size;
	float gx = step(gs - line_width, mod(px.x, gs));
	float gy = step(gs - line_width, mod(px.y, gs));
	float grid_line = max(gx, gy);

	float as_ = gs * accent_cells;
	float ax = step(as_ - line_width, mod(px.x, as_));
	float ay = step(as_ - line_width, mod(px.y, as_));
	float accent_line = max(ax, ay);

	// Primary grid only where accent doesn't draw (accent overrides)
	float primary_only = grid_line * (1.0 - accent_line);

	// Vignette — radial edge darkening, no CRT curvature
	vec2 vig_uv = UV * 2.0 - 1.0;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;

	vec3 col = base_color.rgb;
	col += grid_color.rgb * grid_alpha * primary_only;
	col += grid_color.rgb * accent_alpha * accent_line;
	col *= vignette;

	COLOR = vec4(col, 1.0);
}
