shader_type spatial;
// Patch 2.9.1 item 1: the ink outline of toon_outline.gdshader for meshes that
// merge many parts into one (the pirate galleon). Each vertex carries its own
// push direction in CUSTOM0 (box corners diagonal, rods radial), scaled per
// part so thin parts get a thin line. Same steady on-screen thickness.
render_mode unshaded, cull_front;

uniform vec4 ink_color: source_color = vec4(0.07, 0.06, 0.12, 1.0);
uniform float thickness: hint_range(0.0, 0.02) = 0.004;
uniform float max_distance_m = 800.0;

void vertex() {
	float distance_m = clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 1.0, max_distance_m);
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += CUSTOM0.xyz / max(scale, vec3(1e-4)) * thickness * distance_m;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
