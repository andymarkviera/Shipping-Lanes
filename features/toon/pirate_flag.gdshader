shader_type spatial;
// Patch 2.9.1 item 1: flags and pennants that flap. The cloth hangs in the
// ship's fore-and-aft plane and waves sideways; the wave grows from the hoist
// (UV.x = 0) to the fly (UV.x = 1). UV2 = (phase, sideways reach in metres).
// Colours come from the vertices (the Jolly Roger is painted cell by cell).
// Item 3: COLOR.a is the flag's length / 16 m. `stream` is 1 when the flag
// flies straight out (the still look) and near 0 when it hangs in light air;
// `flow` is extra wave phase, so the cloth runs faster with speed.
render_mode cull_disabled, specular_disabled;

uniform float stream = 1.0;
uniform float flow = 0.0;

varying float fold;

void vertex() {
	float along = UV.x;
	float phase = UV2.x;
	float beat = TIME + flow;
	float reach = UV2.y * mix(0.45, 1.0, stream);
	float wave = 0.6 * sin(along * 9.0 - beat * 5.0 + phase) + 0.4 * sin(along * 4.3 - beat * 3.1 + phase * 1.7);
	fold = 0.6 * cos(along * 9.0 - beat * 5.0 + phase) + 0.4 * cos(along * 4.3 - beat * 3.1 + phase * 1.7);
	VERTEX.x += wave * reach * along;
	VERTEX.y += 0.25 * reach * along * sin(along * 6.0 - beat * 4.0 + phase);
	// In light air the fly droops and hangs closer to the hoist.
	float droop = (1.0 - stream) * along * COLOR.a * 16.0;
	VERTEX.y -= droop * along * 0.6;
	VERTEX.z += droop * 0.3;
	NORMAL = normalize(vec3(1.0, 0.0, fold * 0.7 * min(along * 4.0, 1.0)));
}

void fragment() {
	ALBEDO = COLOR.rgb * (0.86 + 0.14 * fold);
	ROUGHNESS = 1.0;
}
