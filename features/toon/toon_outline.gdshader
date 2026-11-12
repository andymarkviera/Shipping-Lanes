shader_type spatial;
// Aesthetics 2: ink outline by inverted hull. Used as the next pass of toon.gdshader.
// The hull grows with distance from the camera so the line keeps a steady
// thickness on screen.
render_mode unshaded, cull_front;

uniform vec4 ink_color: source_color = vec4(0.07, 0.06, 0.12, 1.0);
uniform float thickness: hint_range(0.0, 0.02) = 0.004;
uniform float max_distance_m = 800.0;
// 1.0 for box meshes centred on their origin: push corners out diagonally so
// the hard edges do not open gaps. 0.0 for smooth meshes: push along the normal.
uniform float box_corners: hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float distance_m = clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z, 1.0, max_distance_m);
	vec3 direction = mix(NORMAL, sign(VERTEX), box_corners);
	VERTEX += direction * thickness * distance_m;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
