shader_type canvas_item;
// Patch 2.7 item 2: the menu ship's big toon wake, drawn in screen space under
// the 3D ship like Andy's mockup (docs/reference/main_menu/menu_ship_arrives.png):
// a wide foam fan trailing left from the bow, light-blue body with sea showing
// through in streaks, white rims and curled swirl foam along the edges.
// Lengths are in screen heights, measured from the screen centre.

uniform float aspect = 1.7778;
uniform vec2 bow = vec2(0.8, 0.07);
uniform float half_width = 0.06;
// How far the water has slid left under the ship (screen heights).
uniform float water_shift = 0.0;
uniform float reveal = 1.0;
uniform vec4 light_foam : source_color = vec4(0.36, 0.78, 0.95, 1.0);
uniform vec4 white_foam : source_color = vec4(0.96, 0.99, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.03 + 7.1) + 0.15 * noise(p * 4.1 + 3.7);
}

// Half width of the foam fan this far behind the bow: hugs the hull near the
// bow, then spreads like the mockup (about 0.28 screen heights at the far left).
float envelope(float along) {
	float hull = half_width * 1.3 * sqrt(clamp((along + 0.015) / 0.14, 0.0, 1.0));
	return hull + max(along - 0.1, 0.0) * 0.13;
}

// One curled swirl: a short spiral of white foam, radius r in screen heights.
float swirl(vec2 q, float r) {
	float d = length(q) / r;
	if (d > 1.0) return 0.0;
	float turn = fract(d * 1.1 - atan(q.y, q.x) / 6.2831853);
	return step(turn, 0.42) * step(0.12, d);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	float along = bow.x - p.x;
	float across = p.y - bow.y;
	float width = envelope(along);
	vec4 colour = vec4(0.0);
	if (along > -0.02 && abs(across) < width * 1.45 + 0.05) {
		// Water-frame position, so foam slides away to the left.
		float u = p.x + water_shift;
		float side = sign(across);
		float ragged = fbm(vec2(u * 7.0, side * 5.0 + 1.3));
		float edge = width * (0.72 + 0.5 * ragged);
		float d = abs(across) / max(edge, 0.0001);
		if (d < 1.0) {
			// Body: light-blue foam in long tongues, sea showing between them.
			float streak = fbm(vec2(u * 2.6, across * 9.0 / max(width, 0.06)));
			float body = step(0.50 - 0.3 * smoothstep(0.6, 0.95, d) - 0.25 * (1.0 - smoothstep(0.0, 0.35, along)), streak);
			colour = light_foam * body;
			// White foam caps on the tongues and a broken white rim outside.
			float cap = fbm(vec2(u * 5.0 + 3.0, across * 22.0 / max(width, 0.06)));
			if (body > 0.5 && cap > 0.66) colour = white_foam;
			if (d > 0.84 + 0.12 * cap) colour = white_foam;
		}
		// Curled swirls riding the outer edge, every so often on each side.
		float cell = 0.21;
		float k = floor((u + side * 0.07) / cell);
		float jitter = hash(vec2(k, side));
		if (jitter > 0.25) {
			float cx = (k + 0.5) * cell - side * 0.07 - water_shift + (jitter - 0.5) * 0.08;
			float ca = bow.x - cx;
			if (ca > 0.05) {
				float r = 0.02 + 0.018 * jitter + 0.014 * min(ca, 1.0);
				float cy = bow.y + side * envelope(ca) * 0.95;
				vec2 q = vec2(p.x - cx, p.y - cy);
				q.y *= side;
				if (swirl(q, r) > 0.5) colour = white_foam;
				else if (length(q) < r && colour.a < 0.5) colour = light_foam;
			}
		}
	}
	COLOR = vec4(colour.rgb, colour.a * reveal);
}
