// Shared by the dice drawn with their own shaders (view/dice/gem_cut.gd, November 10 2026).
//
// A cut mesh (GemCut.mesh) is every face fanned out from its middle, and each corner of a fan
// carries where it is: CUSTOM0 = (weight of the sector's first rim corner, of its second,
// which side of the face the sector runs along, how many sides the face has), CUSTOM1 = (the
// face's middle in model space, the face's index). From those a fragment knows `t`, how far
// out it is from the middle (0) to the rim (1) along the face's own outline shrunk, and `s`,
// how far across its side it is (0..1). A brilliant's star and table are drawn from those two
// numbers, so every die shape gets them in its own outline.

varying vec4 v_fan;
varying vec3 v_fn;
varying vec3 v_pos;
varying vec3 v_c;
varying vec3 v_o;
varying vec3 v_obj;
varying vec3 v_tone;
varying float v_face;

uniform vec4 tone_base : source_color = vec4(1.0);

#define CUT_VERTEX v_fan = CUSTOM0; v_face = CUSTOM1.w; v_obj = VERTEX; v_tone = COLOR.rgb; v_fn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); v_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz; v_c = (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz; v_o = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

// The lamps a facet flashes towards, in view space (the camera looks down -z).
const vec3 LAMP_KEY = vec3(-0.5, 0.6, 0.62);
const vec3 LAMP_COOL = vec3(0.66, 0.18, 0.73);
const vec3 LAMP_LOW = vec3(-0.15, -0.62, 0.77);

float h1(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h1(i), h1(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h1(i + vec3(0.0, 1.0, 0.0)), h1(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h1(i + vec3(0.0, 0.0, 1.0)), h1(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h1(i + vec3(0.0, 1.0, 1.0)), h1(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	return (0.5 * vnoise(p) + 0.25 * vnoise(p * 2.03 + 1.7) + 0.125 * vnoise(p * 4.01 + 3.1)) / 0.875;
}

// Cells over a face: (distance to the nearest point, gap to the second nearest, two numbers
// for the nearest cell).
vec4 voro(vec2 p, float seed) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(h1(vec3(i + g, seed)), h1(vec3(i + g, seed + 7.3)));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(sqrt(d1), sqrt(d2) - sqrt(d1), h1(vec3(best, seed + 3.7)), h1(vec3(best, seed + 9.1)));
}

float fan_t() {
	return clamp(v_fan.x + v_fan.y, 0.0, 1.0);
}

float fan_s() {
	return clamp(v_fan.y / max(v_fan.x + v_fan.y, 0.0001), 0.0, 1.0);
}

// Which facet a point of a face is on, and how that facet is tipped: (lean outward, lean
// sideways, the facet's own number 0..1, which ring it is in, 0 for the flat middle).
// cut 0 brilliant, 3 none (smooth).
vec4 facet(int cut, float t, float s, float k, float face, bool crown, float window) {
	vec2 tl = vec2(0.0);
	float region = 0.0;
	float sub = 0.0;
	float ds = abs(s - 0.5) * 2.0;
	float side = s < 0.5 ? -1.0 : 1.0;
	if (cut == 0) {
		if (crown) {
			float star = window + 0.3 * (1.0 - ds);
			if (t < window) {
				region = 0.0;
			} else if (t < star) {
				region = 1.0;
				tl = vec2(0.3, 0.0);
			} else if (t < 0.84) {
				region = 2.0;
				sub = side;
				tl = vec2(0.55, 0.3 * side);
			} else {
				region = 3.0;
				sub = floor(s * 4.0);
				tl = vec2(0.85, (fract(s * 2.0) - 0.5) * 0.8);
			}
		} else {
			float main_to = 0.5 + 0.38 * (1.0 - ds);
			float star_in = 0.22 + 0.1 * ds;
			if (t < star_in) {
				region = 1.0;
				sub = floor(s * 2.0);
				tl = vec2(0.3, 0.2 * side);
			} else if (t < main_to) {
				region = 2.0;
				sub = side;
				tl = vec2(0.55, 0.25 * side);
			} else {
				region = 3.0;
				sub = floor(s * 4.0);
				tl = vec2(0.85, (fract(s * 2.0) - 0.5) * 0.9);
			}
		}
	}
	vec3 key = vec3(face * 1.7 + 0.31, k * 9.0 + sub + 4.0, region * 3.1 + (crown ? 0.0 : 50.0));
	float id = h1(key);
	if (region > 0.0) {
		tl += (vec2(h1(key + 1.37), h1(key + 2.71)) - 0.5) * 0.3;
	}
	return vec4(tl, id, region);
}

// How much a point sits on a line between two facets, about a pixel wide whatever the die's
// size: worked out from the same boundaries `facet` draws, so the lines run unbroken.
float facet_line(int cut, float t, float s) {
	float wt = max(fwidth(t), 0.0005) * 1.2;
	float ws = wt / max(2.0 * t, 0.08);
	float ds = abs(s - 0.5) * 2.0;
	float seam = 1.0 - smoothstep(0.0, ws, min(s, 1.0 - s));
	float line = 0.0;
	if (cut == 0) {
		float main_to = 0.5 + 0.38 * (1.0 - ds);
		float star_in = 0.22 + 0.1 * ds;
		line = max(line, 1.0 - smoothstep(0.0, wt, abs(t - main_to)));
		line = max(line, 1.0 - smoothstep(0.0, wt, abs(t - star_in)));
		line = max(line, (1.0 - smoothstep(0.0, ws, abs(s - 0.5))) * step(t, main_to));
		float quarter = min(abs(s - 0.25), abs(s - 0.75));
		line = max(line, (1.0 - smoothstep(0.0, ws, quarter)) * step(main_to, t));
		line = max(line, seam);
	}
	return line;
}

// The face's own directions at a fragment: its normal, outward from its middle, and across.
void face_frame(out vec3 fn, out vec3 rad, out vec3 tng) {
	fn = normalize(v_fn);
	rad = v_pos - v_c;
	rad -= fn * dot(rad, fn);
	rad = rad / max(length(rad), 0.0001);
	tng = cross(fn, rad);
}

// A fully saturated hue (0..1 round the wheel).
vec3 rainbow(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// An opal's play of color: patches across a face, each a little tipped mirror of one hue,
// the hue sliding and the patch flaring as the die turns. `crown` for the near faces.
// `fill` is the share of patches lit; the rest show the body between them.
vec3 play_of_color(vec2 uv, float face, vec3 fn, vec3 rad, vec3 tng, float scale, float sat, float fill, bool crown) {
	vec4 c = voro(uv * scale, face * 3.1 + (crown ? 5.0 : 61.0));
	vec3 pn = normalize(fn + (rad * (c.z - 0.5) + tng * (c.w - 0.5)) * 1.4);
	float hue = fract(c.z * 1.7 + c.w * 0.6 + dot(pn, vec3(0.8, 1.1, 0.5)) * 0.9);
	vec3 r = crown ? reflect(vec3(0.0, 0.0, -1.0), pn) : reflect(vec3(0.0, 0.0, -1.0), -pn);
	float flare = 0.25 + 1.4 * pow(max(dot(r, normalize(LAMP_KEY)), 0.0), 4.0) + 0.9 * pow(max(dot(r, normalize(LAMP_COOL)), 0.0), 4.0);
	float seam = smoothstep(0.0, 0.08, c.y);
	float lit = step(fract(c.z * 7.13 + c.w * 3.7), fill);
	return mix(vec3(1.0), rainbow(hue), sat) * flare * seam * lit;
}

vec3 lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

// A face tinted away from the die's own color (an etched face, a changed number) keeps that
// tint on top of the cut.
vec3 tone_shift() {
	return lin(v_tone) - tone_base.rgb;
}
