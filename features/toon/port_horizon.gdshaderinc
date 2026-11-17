// Patch 3.0 B: port scenery fades with the captain's distance, not camera zoom.
// Opaque ordered coverage: no transparent sorting, extra pass or physics change.
global uniform vec3 port_viewer_world;
uniform bool port_distance_fade = false;

void port_horizon_clip(vec3 world_position, vec2 pixel) {
	if (port_distance_fade) {
		vec2 delta = world_position.xz - port_viewer_world.xz;
		const float wrap_m = 12566.370614359;
		delta = mod(delta + vec2(wrap_m * 0.5), vec2(wrap_m)) - vec2(wrap_m * 0.5);
		float gone = smoothstep(1600.0, 2200.0, length(delta));
		// Stable screen-space coverage; no animated noise or alpha blending.
		float coverage = fract(dot(floor(pixel), vec2(0.754877666, 0.569840296)));
		if (gone > 0.0 && coverage < gone) { discard; }
	}
}
