shader_type spatial;
// Patch 2.9.1 item 1: flags and pennants that flap. The cloth hangs in the
// ship's fore-and-aft plane and waves sideways; the wave grows from the hoist
// (UV.x = 0) to the fly (UV.x = 1). UV2 = (phase, sideways reach in metres).
// Colours come from the vertices (the Jolly Roger is painted cell by cell).
render_mode cull_disabled, specular_disabled;

varying float fold;

void vertex() {
	float along = UV.x;
	float phase = UV2.x;
	float wave = 0.6 * sin(along * 9.0 - TIME * 5.0 + phase) + 0.4 * sin(along * 4.3 - TIME * 3.1 + phase * 1.7);
	fold = 0.6 * cos(along * 9.0 - TIME * 5.0 + phase) + 0.4 * cos(along * 4.3 - TIME * 3.1 + phase * 1.7);
	VERTEX.x += wave * UV2.y * along;
	VERTEX.y += 0.25 * UV2.y * along * sin(along * 6.0 - TIME * 4.0 + phase);
	NORMAL = normalize(vec3(1.0, 0.0, fold * 0.7 * min(along * 4.0, 1.0)));
}

void fragment() {
	ALBEDO = COLOR.rgb * (0.86 + 0.14 * fold);
	ROUGHNESS = 1.0;
}
