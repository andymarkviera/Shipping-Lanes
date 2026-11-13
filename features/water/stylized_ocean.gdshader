shader_type spatial;
render_mode unshaded, cull_back;
// Aesthetics 1: flat saturated ocean, three soft tone bands, broken white swirl lines.
uniform vec4 deep_color : source_color = vec4(0.0, 0.38, 0.72, 1.0);
uniform vec4 surface_color : source_color = vec4(0.04, 0.62, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
// Slides the swirl lines only. Zero unless the world has wrapped round.
uniform vec2 swirl_origin = vec2(0.0);
varying vec3 world_position;

vec2 cell_point(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (quality > 0) {
		// Same numbers as OceanPresentation.swell_height.
		VERTEX.y += 0.55 * sin(world.x * 0.040 + world.z * 0.026 + water_time * 0.55);
		VERTEX.y += 0.28 * sin(world.z * 0.070 - world.x * 0.018 - water_time * 0.80);
		if (quality > 1) VERTEX.y += 0.10 * sin(world.x * 0.11 - world.z * 0.08 + water_time * 1.1);
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float distance_to_eye = length(world_position - CAMERA_POSITION_WORLD);

	// Tone bands: a slow, wide field cut into deep, middle and surface colour.
	vec2 p = world_position.xz;
	float tone = 0.5
		+ 0.25 * sin(p.x * 0.011 + p.y * 0.007 + water_time * 0.05 + 1.7 * sin(p.y * 0.006))
		+ 0.25 * sin(p.y * 0.017 - p.x * 0.009 - water_time * 0.04);
	float band = 0.5 * smoothstep(0.30, 0.36, tone) + 0.5 * smoothstep(0.62, 0.68, tone);
	// Far water settles on the middle tone so the bands cannot shimmer at the horizon.
	band = mix(band, 0.5, smoothstep(700.0, 1900.0, distance_to_eye));
	vec3 water = mix(deep_color.rgb, surface_color.rgb, band);
	// Rolling swells: a lighter flat band rides each crest so the swell reads
	// on unshaded water. It fades out before the horizon.
	float swell = 0.66 * sin(p.x * 0.040 + p.y * 0.026 + water_time * 0.55)
		+ 0.34 * sin(p.y * 0.070 - p.x * 0.018 - water_time * 0.80);
	float swell_aa = max(fwidth(swell), 0.004);
	float crest = smoothstep(0.42 - swell_aa, 0.42 + swell_aa, swell) * (1.0 - smoothstep(350.0, 1100.0, distance_to_eye));
	water = mix(water, mix(surface_color.rgb, foam_color.rgb, 0.3), 0.3 * crest);

	// Swirl lines: cell borders, drawn only where a drifting mask allows, so they
	// read as separate curved strokes that taper to a point.
	vec2 uv = (p - swirl_origin) / 32.0 + vec2(water_time * 0.016, water_time * 0.010);
	float warp_time = quality > 0 ? water_time * 0.18 : 0.0;
	uv += 0.42 * vec2(sin(uv.y * 2.7 + warp_time), cos(uv.x * 2.2 - warp_time));
	vec2 base = floor(uv);
	vec2 local = fract(uv);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 delta = neighbor + 0.2 + 0.6 * cell_point(base + neighbor) - local;
			float d = dot(delta, delta);
			if (d < nearest) { second = nearest; nearest = d; }
			else { second = min(second, d); }
		}
	}
	float edge = second - nearest;
	float mask = sin(uv.x * 1.3 + 1.5 * sin(uv.y * 0.9) + warp_time * 0.5) * sin(uv.y * 1.1 - 1.2 * sin(uv.x * 0.7));
	float stroke = smoothstep(0.05, 0.55, mask);
	float width = 0.085 * stroke;
	float aa = max(fwidth(edge), 0.006);
	float foam = (1.0 - smoothstep(width - aa, width + aa, edge)) * smoothstep(0.0, 0.2, stroke);
	// Fade distant lines before they become sub-pixel sparkle.
	foam *= 1.0 - smoothstep(220.0, 800.0, distance_to_eye);
	ALBEDO = mix(water, foam_color.rgb, foam);
}
