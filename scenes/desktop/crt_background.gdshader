shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.03, 0.02, 0.08, 1.0);
uniform float grid_intensity : hint_range(0.0, 0.15) = 0.035;
uniform float grid_scale_x : hint_range(20.0, 120.0) = 64.0;
uniform float grid_scale_y : hint_range(10.0, 80.0) = 36.0;
uniform float scanline_intensity : hint_range(0.0, 0.15) = 0.04;
uniform float scanline_frequency : hint_range(50.0, 400.0) = 160.0;
uniform float noise_intensity : hint_range(0.0, 0.05) = 0.008;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec3 grid_color : source_color = vec3(0.0, 0.88, 1.0);

void fragment() {
	// Subtle perspective grid — faint cyan lines
	float gx = step(1.0 - (1.0 / grid_scale_x), fract(UV.x * grid_scale_x));
	float gy = step(1.0 - (1.0 / grid_scale_y), fract(UV.y * grid_scale_y));
	float grid = max(gx, gy) * grid_intensity;

	// Very faint horizontal scanlines for depth (not retro-heavy)
	float scanline = sin(UV.y * scanline_frequency * PI) * 0.5 + 0.5;
	float scan = 1.0 - scanline * scanline_intensity;

	// Slow-drifting noise, tinted cyan
	float noise = fract(sin(dot(UV * 200.0 + TIME * 0.07, vec2(12.9898, 78.233))) * 43758.5453);
	float n = (noise - 0.5) * noise_intensity;

	// Vignette
	vec2 vig_uv = UV * 2.0 - 1.0;
	float vignette = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;

	vec3 col = base_color.rgb + vec3(n * 0.2, n * 0.3, n);
	col += grid_color * grid;
	col *= scan * vignette;

	COLOR = vec4(col, 1.0);
}
