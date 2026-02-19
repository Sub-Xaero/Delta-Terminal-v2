shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.02, 0.06, 0.02, 1.0);
uniform float scanline_intensity : hint_range(0.0, 0.3) = 0.08;
uniform float scanline_frequency : hint_range(50.0, 600.0) = 300.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.015;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// Scanlines
	float scanline = sin(UV.y * scanline_frequency * PI) * 0.5 + 0.5;
	float scan = 1.0 - scanline * scanline_intensity;

	// Animated static noise
	float noise = fract(sin(dot(UV * 300.0 + TIME * 0.3, vec2(12.9898, 78.233))) * 43758.5453);
	float n = (noise - 0.5) * noise_intensity;

	// Vignette
	vec2 vig = UV * 2.0 - 1.0;
	float vignette = 1.0 - dot(vig, vig) * vignette_strength;

	vec3 col = (base_color.rgb + vec3(0.0, n, 0.0)) * scan * vignette;
	COLOR = vec4(col, 1.0);
}
