shader_type spatial;
// Patch 2.9.1 item 3: toon_outline.gdshader's ink line for the sails. The
// cloth is moved exactly as pirate_cloth.gdshader moves it, then pushed out
// along its normal.
render_mode unshaded, cull_front;

uniform vec4 ink_color: source_color = vec4(0.07, 0.06, 0.12, 1.0);
uniform float thickness: hint_range(0.0, 0.02) = 0.004;
uniform float max_distance_m = 800.0;
uniform float sail_set = 1.0;
uniform float fill = 0.82;
uniform float swing = 0.0;
uniform float flow = 0.0;

void vertex() {
	float open = smoothstep(0.0, 1.0, clamp(sail_set * 1.5 - CUSTOM0.w * 0.5, 0.0, 1.0));
	float beat = TIME * 2.3 + flow;
	float flutter = (0.04 + 0.07 * abs(fill)) * sin(beat * 2.1 + VERTEX.y * 0.9 + VERTEX.z * 0.35) + 0.03 * sin(beat * 3.7 + VERTEX.y * 2.3);
	vec3 set_at = VERTEX + CUSTOM1.xyz * (0.85 * fill - 0.7 + flutter);
	set_at.x += CUSTOM1.w * (swing + 0.2 * abs(fill) * sin(beat * 1.3 + VERTEX.y * 0.4));
	set_at.y -= CUSTOM1.w * abs(swing) * 0.15;
	VERTEX = mix(CUSTOM0.xyz, set_at, open);
	float distance_m = clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 1.0, max_distance_m);
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += NORMAL / max(scale, vec3(1e-4)) * thickness * distance_m;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
