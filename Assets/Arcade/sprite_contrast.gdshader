shader_type canvas_item;
uniform vec4 rim : source_color = vec4(1.0, 0.96, 0.75, 1.0);
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
 float edge = max(max(texture(TEXTURE, UV+vec2(step_uv.x,0)).a, texture(TEXTURE, UV-vec2(step_uv.x,0)).a), max(texture(TEXTURE, UV+vec2(0,step_uv.y)).a, texture(TEXTURE, UV-vec2(0,step_uv.y)).a));
 vec3 vivid = clamp(source.rgb * 1.13, vec3(0.0), vec3(1.0));
 COLOR = vec4(mix(rim.rgb, vivid, source.a), max(source.a, edge * 0.9));
}
