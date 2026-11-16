shader_type spatial;
// Patch 2.9.1 item 3: living sails and rigging. toon.gdshader's cel shading
// (vertex colours) on cloth and rope that move. Per vertex:
// CUSTOM0 = where the cloth sits when furled (xyz) and its place in the
// unfurling order (w); CUSTOM1 = its belly (xyz) and how far it swings (w).
// Ropes only carry CUSTOM1.w, and sail_set stays 1 for them.
// pirate_cloth_outline.gdshader repeats vertex() for the ink line.
render_mode cull_back, specular_disabled;

uniform float saturation: hint_range(0.0, 2.0) = 1.3;
uniform float mid_threshold: hint_range(0.0, 1.0) = 0.12;
uniform float lit_threshold: hint_range(0.0, 1.0) = 0.55;
uniform float mid_level: hint_range(0.0, 1.0) = 0.55;
uniform float band_softness: hint_range(0.001, 0.2) = 0.015;
// 0 furled on the yards, 1 set. The defaults are the still, set look.
uniform float sail_set = 1.0;
// Share of top speed, signed: the belly fills ahead and backs astern.
uniform float fill = 0.82;
// Sideways swing of cloth and rope behind the hull's roll.
uniform float swing = 0.0;
// Extra flutter phase: it runs on faster with speed.
uniform float flow = 0.0;

void vertex() {
	float open = smoothstep(0.0, 1.0, clamp(sail_set * 1.5 - CUSTOM0.w * 0.5, 0.0, 1.0));
	float beat = TIME * 2.3 + flow;
	float flutter = (0.04 + 0.07 * abs(fill)) * sin(beat * 2.1 + VERTEX.y * 0.9 + VERTEX.z * 0.35) + 0.03 * sin(beat * 3.7 + VERTEX.y * 2.3);
	vec3 set_at = VERTEX + CUSTOM1.xyz * (0.85 * fill - 0.7 + flutter);
	set_at.x += CUSTOM1.w * (swing + 0.2 * abs(fill) * sin(beat * 1.3 + VERTEX.y * 0.4));
	set_at.y -= CUSTOM1.w * abs(swing) * 0.15;
	VERTEX = mix(CUSTOM0.xyz, set_at, open);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(mix(vec3(grey), base, saturation), 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = mid_level * smoothstep(mid_threshold - band_softness, mid_threshold + band_softness, lit);
	band += (1.0 - mid_level) * smoothstep(lit_threshold - band_softness, lit_threshold + band_softness, lit);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
