shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 deep_color : source_color = vec4(0.0, 0.42, 0.69, 1.0);
uniform vec4 surface_color : source_color = vec4(0.0, 0.55, 0.80, 1.0);
uniform vec4 foam_color : source_color = vec4(0.83, 0.98, 1.0, 1.0);
uniform float water_time = 0.0;
uniform int quality = 1;
varying vec3 world_position;

vec2 cell_point(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (quality > 0) {
		VERTEX.y += 0.18 * sin(world.x * 0.055 + world.z * 0.035 + water_time * 0.65);
		VERTEX.y += 0.09 * sin(world.z * 0.09 - water_time * 0.85);
		if (quality > 1) VERTEX.y += 0.04 * sin(world.x * 0.15 - world.z * 0.11 + water_time);
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz / 26.0 + vec2(water_time * 0.018, water_time * 0.011);
	float warp_time = quality > 0 ? water_time * 0.18 : 0.0;
	uv += 0.38 * vec2(sin(uv.y * 2.7 + warp_time), cos(uv.x * 2.2 - warp_time));
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
	float aa = max(fwidth(edge), 0.006);
	float foam = 1.0 - smoothstep(0.075 - aa, 0.075 + aa, edge);
	float distance_to_eye = length(world_position - CAMERA_POSITION_WORLD);
	// Fade distant lines before they become sub-pixel sparkle.
	foam *= 1.0 - smoothstep(180.0, 650.0, distance_to_eye);
	float wash = 0.5 + 0.5 * sin(world_position.x * 0.027 + world_position.z * 0.037 + water_time * 0.3);
	wash = mix(wash, 0.5, smoothstep(180.0, 750.0, distance_to_eye));
	vec3 water = mix(deep_color.rgb, surface_color.rgb, wash * 0.6);
	water = mix(water, surface_color.rgb, smoothstep(400.0, 1800.0, distance_to_eye) * 0.4);
	ALBEDO = mix(water, foam_color.rgb, foam * 0.94);
}
