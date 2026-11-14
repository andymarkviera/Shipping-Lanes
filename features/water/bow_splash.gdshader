shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.75, 0.9, 0.97, 1.0);
void fragment() {
	// Flat two-tone toon: faces turned to the sky are white, the rest a pale blue,
	// so the spray reads as solid chunks and not as a flat white patch.
	vec3 flat_normal = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	// The screen-space derivative sign differs between OpenGL and Vulkan/Metal,
	// so always use the side facing the camera (view space looks down -Z).
	if (dot(flat_normal, VERTEX) > 0.0) flat_normal = -flat_normal;
	float up = (INV_VIEW_MATRIX * vec4(flat_normal, 0.0)).y;
	ALBEDO = mix(shade_color.rgb, foam_color.rgb, step(-0.15, up));
}
