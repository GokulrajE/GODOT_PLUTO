shader_type canvas_item;
uniform float saturation = 0.78;
uniform float exposure = 0.82;
uniform vec4 atmosphere : source_color = vec4(0.10, 0.23, 0.31, 1.0);
uniform float atmosphere_mix = 0.08;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
 vec3 scenery = mix(vec3(luminance), source.rgb, saturation) * exposure;
 COLOR = vec4(mix(scenery, atmosphere.rgb, atmosphere_mix), source.a);
}
