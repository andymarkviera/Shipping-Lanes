shader_type spatial;
// Aesthetics 2: cel shading. Three hard light bands (shadow, mid, lit) and a
// saturation lift. Works in GL Compatibility. Outline is toon_outline.gdshader.
render_mode cull_back, specular_disabled;

uniform vec4 albedo: source_color = vec4(1.0);
uniform sampler2D albedo_texture: source_color, hint_default_white;
uniform bool use_vertex_color = false;
uniform float saturation: hint_range(0.0, 2.0) = 1.3;
uniform float mid_threshold: hint_range(0.0, 1.0) = 0.12;
uniform float lit_threshold: hint_range(0.0, 1.0) = 0.55;
uniform float mid_level: hint_range(0.0, 1.0) = 0.55;
uniform float band_softness: hint_range(0.001, 0.2) = 0.015;

#include "res://features/toon/port_horizon.gdshaderinc"

void fragment() {
	port_horizon_clip((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy);
	vec3 base = albedo.rgb * texture(albedo_texture, UV).rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
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
