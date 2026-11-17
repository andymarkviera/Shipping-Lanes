shader_type spatial;
render_mode unshaded;
#include "res://features/toon/port_horizon.gdshaderinc"
uniform vec4 albedo : source_color = vec4(1.0);
void fragment() {
	port_horizon_clip((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	ALBEDO = albedo.rgb;
}
