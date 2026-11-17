shader_type spatial;
// Aesthetics 2: ink outline by inverted hull. Used as the next pass of toon.gdshader.
// The hull grows with distance from the camera so the line keeps a steady
// thickness on screen. The push is measured in world metres: it is divided by
// the node's (or MultiMesh instance's) own scale, so a unit box stretched into
// a 30 x 160 m tower gets a thin ink line, not a shell tens of metres wide
// (Patch 2.9 item 1: the translucent boxes round the city skyline and the
// blotchy shadows the inflated shells threw over the desert).
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
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += direction / max(scale, vec3(1e-4)) * thickness * distance_m;
}

#include "res://features/toon/port_horizon.gdshaderinc"

void fragment() {
	port_horizon_clip((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	ALBEDO = ink_color.rgb;
}
