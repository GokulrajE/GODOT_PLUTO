shader_type canvas_item;
uniform float phase = 0.0;
void fragment() {
 vec2 uv = UV;
 uv.x = 1.0 - abs(mod(uv.x + phase, 2.0) - 1.0);
 COLOR = texture(TEXTURE, uv);
}
