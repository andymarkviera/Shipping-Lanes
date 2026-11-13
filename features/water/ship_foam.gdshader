shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (quality > 0) {
		// Same numbers as OceanPresentation.swell_height.
		VERTEX.y += 0.55 * sin(world.x * 0.040 + world.z * 0.026 + water_time * 0.55);
		VERTEX.y += 0.28 * sin(world.z * 0.070 - world.x * 0.018 - water_time * 0.80);
		if (quality > 1) VERTEX.y += 0.10 * sin(world.x * 0.11 - world.z * 0.08 + water_time * 1.1);
	}
}
void fragment() {
	ALBEDO = foam_color.rgb;
	// Toon wake: solid white for most of its life, then a short fade.
	ALPHA = smoothstep(0.04, 0.45, COLOR.a);
}
