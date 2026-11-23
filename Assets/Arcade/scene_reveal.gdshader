shader_type canvas_item;
// Cinematic scene change: a soft circle of light opens from `origin` and reveals the new screen.
// The old screen drifts into a slow zoom, softens into a frosted blur toward the light, and the
// edge carries a thin bright rim with a gentle halo and a hint of lens colour fringing.
uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 = old screen intact, 1 = fully revealed
uniform vec2 origin = vec2(0.5, 0.5);
uniform float aspect = 1.78;
uniform vec3 rim_color : source_color = vec3(0.80, 0.96, 1.0);
uniform vec3 halo_color : source_color = vec3(0.03, 0.55, 0.58);

void fragment() {
	float p = progress;
	vec2 to_px = vec2(aspect, 1.0);
	float far = length(max(origin, vec2(1.0) - origin) * to_px);          // distance to the farthest corner
	float dist = length((UV - origin) * to_px) / far;                     // 0 at the origin .. 1 at the far corner
	float front = p * 1.18;                                                // where the light has reached
	float gap = dist - front;                                              // < 0: already revealed

	// the old screen: slow zoom toward the origin, blur that grows toward the light front
	vec2 zoomed = origin + (UV - origin) * (1.0 - 0.07 * p);
	float near_front = smoothstep(0.45, 0.0, gap) * smoothstep(0.0, 0.25, p);
	float lod = (0.8 + 3.2 * near_front) * smoothstep(0.0, 0.2, p);
	vec2 dir = normalize(UV - origin + vec2(0.0001)) * (0.004 * near_front);
	vec3 old_col;
	old_col.r = textureLod(TEXTURE, zoomed + dir, lod).r;
	old_col.g = textureLod(TEXTURE, zoomed, lod).g;
	old_col.b = textureLod(TEXTURE, zoomed - dir, lod).b;
	old_col *= 1.0 + 0.10 * near_front;                                    // a touch brighter in the light

	// soft-edged reveal
	float cover = smoothstep(-0.015, 0.075, gap);

	// glowing rim + wide halo
	float rim = exp(-pow(gap / 0.014, 2.0));
	float halo = exp(-pow(gap / 0.10, 2.0));
	float glow = clamp(rim * 1.0 + halo * 0.28, 0.0, 1.0);

	float fade_out = 1.0 - smoothstep(0.90, 1.0, p);                       // everything melts away at the end
	vec3 col = old_col + rim_color * rim * 0.9 + halo_color * halo * 0.5;
	float a = clamp(cover + glow * (1.0 - cover), 0.0, 1.0) * fade_out;
	vec3 glow_rgb = rim_color * rim + halo_color * halo * 1.6;
	vec3 rgb = (col * cover + glow_rgb * (1.0 - cover)) / max(cover + (1.0 - cover) * glow, 0.0001);
	COLOR = vec4(rgb, a);
}
