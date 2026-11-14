shader_type sky;
// Aesthetics 3: bright cartoon sky. A blue gradient, flat two-tone puffy clouds
// built from circles, and a flat sun disc. Works in GL Compatibility.

uniform vec3 top_color: source_color = vec3(0.05, 0.33, 0.87);
uniform vec3 horizon_color: source_color = vec3(0.70, 0.93, 0.98);
uniform vec3 cloud_color: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color: source_color = vec3(0.76, 0.88, 0.99);
uniform vec3 sun_color: source_color = vec3(1.0, 0.97, 0.80);
uniform float cloud_cover: hint_range(0.0, 1.0) = 0.6;
uniform float drift_speed = 0.0012; // turns of the sky per second, very slow

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One ring of clouds around the horizon. p.x runs 0..cells around the compass,
// p.y is height above the cloud base in the same units. Returns x = inside a
// cloud, y = inside its bright top.
vec2 cloud_ring(vec2 p, float cells, float seed, float cover) {
	float cell = floor(p.x);
	float inside = 0.0;
	float bright = 0.0;
	for (int i = -1; i <= 1; i++) {
		float c = cell + float(i);
		float id = mod(c, cells);
		if (hash(vec2(id, seed)) > cover) {
			continue;
		}
		float size = 0.7 + 0.5 * hash(vec2(id, seed + 3.0));
		for (int k = 0; k < 5; k++) {
			float fk = float(k);
			float jitter = hash(vec2(id, seed + 7.0 + fk)) - 0.5;
			// Big puffs in the middle of the cloud, small ones at the ends.
			float middle = 1.0 - abs(fk - 2.0) * 0.5;
			float radius = size * (0.10 + 0.13 * middle + 0.05 * jitter);
			vec2 centre = vec2(c + 0.5 + size * (fk - 2.0) * 0.17 + jitter * 0.06, radius * 0.55);
			float d = length(p - centre);
			inside = max(inside, 1.0 - smoothstep(radius - 0.006, radius, d));
			float d_top = length(p - centre - vec2(0.02, radius * 0.30));
			bright = max(bright, 1.0 - smoothstep(radius * 0.78 - 0.006, radius * 0.78, d_top));
		}
	}
	// Flat cloud base.
	inside *= smoothstep(0.0, 0.006, p.y);
	return vec2(inside, bright * inside);
}

void sky() {
	float height = clamp(EYEDIR.y, 0.0, 1.0);
	float rise = 1.0 - height;
	vec3 color = mix(horizon_color, top_color, 1.0 - rise * rise * rise);

	if (LIGHT0_ENABLED) {
		float facing = dot(EYEDIR, LIGHT0_DIRECTION);
		color = mix(color, mix(color, sun_color, 0.35), step(0.9955, facing));
		color = mix(color, sun_color, step(0.9978, facing));
	}

	float turn = atan(EYEDIR.x, EYEDIR.z + (abs(EYEDIR.x) + abs(EYEDIR.z) < 1e-6 ? 1e-6 : 0.0)) / TAU + 0.5 + TIME * drift_speed;
	float lift = asin(clamp(EYEDIR.y, -1.0, 1.0)) / TAU;
	// Small high clouds first, then the big bank that sits on the horizon.
	vec2 high = cloud_ring(vec2(fract(turn * 0.7 + 0.31) * 18.0, (lift - 0.055) * 18.0), 18.0, 41.0, cloud_cover * 0.6);
	color = mix(color, mix(cloud_shade_color, cloud_color, high.y), high.x);
	vec2 low = cloud_ring(vec2(fract(turn) * 9.0, (lift - 0.006) * 9.0), 9.0, 11.0, cloud_cover);
	color = mix(color, mix(cloud_shade_color, cloud_color, low.y), low.x);

	// Haze: everything melts into the horizon colour right at the waterline.
	color = mix(horizon_color, color, smoothstep(0.0, 0.05, EYEDIR.y));
	COLOR = color;
}
