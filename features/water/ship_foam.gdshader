shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 foam_color : source_color = vec4(0.83, 0.98, 1.0, 1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (quality > 0) {
		VERTEX.y += 0.18 * sin(world.x * 0.055 + world.z * 0.035 + water_time * 0.65);
		VERTEX.y += 0.09 * sin(world.z * 0.09 - water_time * 0.85);
		if (quality > 1) VERTEX.y += 0.04 * sin(world.x * 0.15 - world.z * 0.11 + water_time);
	}
}
void fragment() {
	ALBEDO = foam_color.rgb;
	ALPHA = COLOR.a;
}
