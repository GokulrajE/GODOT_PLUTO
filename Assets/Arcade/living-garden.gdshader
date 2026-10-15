shader_type canvas_item;
render_mode unshaded;
uniform float phase = 0.0;

void fragment() {
	// Overscan prevents exposed edges during the gentle camera drift.
	vec2 drift = vec2(sin(phase * 0.09), sin(phase * 0.065)) * 0.008;
	vec2 uv = (UV - 0.5) * 0.96 + 0.5 + drift;
	vec3 garden = texture(TEXTURE, uv).rgb;
	float sunlight = 0.5 + 0.5 * sin(UV.x * 7.0 + UV.y * 3.0 - phase * 0.22);
	garden = mix(garden, vec3(1.0, 0.95, 0.78), sunlight * 0.07);
	// Stable light backing protects headings, forms and footer text.
	float center = 1.0 - smoothstep(0.28, 0.5, abs(UV.x - 0.5));
	float edges_y = max(1.0 - smoothstep(0.19, 0.24, UV.y), smoothstep(0.78, 0.85, UV.y));
	float veil = max(center * 0.62, edges_y * 0.88);
	COLOR = vec4(mix(garden, vec3(0.96, 0.985, 0.98), veil), 1.0);
}
