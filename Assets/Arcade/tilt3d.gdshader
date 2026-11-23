shader_type canvas_item;
// Fake 3D tilt: perspective-warps the texture toward the pointer and adds a glossy highlight.
uniform vec2 tilt = vec2(0.0);      // pointer direction, -1..1 (x right, y down)
uniform float amount : hint_range(0.0, 1.0) = 0.0; // hover blend

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float pad = mix(1.0, 0.93, amount);               // leave room so the lifted knob isn't clipped
	vec2 q = p / (pad * (1.0 + 0.32 * amount * dot(p, tilt)));
	vec2 uv = q * 0.5 + 0.5;
	vec4 c = texture(TEXTURE, clamp(uv, 0.0, 1.0));
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) c.a = 0.0;
	float far_side = max(dot(q, -tilt), 0.0);
	c.rgb *= 1.0 - 0.18 * amount * far_side;          // shade the side pushed away
	float gloss = smoothstep(1.0, 0.0, length(q - tilt * 0.55));
	c.rgb += vec3(0.20) * gloss * amount * c.a;       // highlight on the side nearest the pointer
	COLOR = c;
}
