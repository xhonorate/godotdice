// A cut die's near faces (gem_cut.gd builds the shader around this): a thin colored skin,
// deeper towards each face's rim, over the lit inside (cut_far). The skin is cut too: its
// facets tip the face's normal so the studio it mirrors breaks into the cut's own pattern of
// reflections, and a facet that turns square to a lamp flashes white. Premultiplied, as the
// clear dice are.
// Features: FIRE (sparkles split into rainbow colors), PLAY (an opal's patches of color in
// the skin). `calm` quiets the middle of each face, where the
// numeral sits: no sparkle or color there and a slightly darker skin, so a white numeral reads.
render_mode blend_premul_alpha, cull_back, depth_draw_opaque;

#include "res://view/dice/cuts/cut_common.gdshaderinc"

uniform int cut = 0;
uniform vec4 body : source_color = vec4(0.7, 0.05, 0.1, 1.0);
uniform vec4 deep : source_color = vec4(0.2, 0.0, 0.02, 1.0);
uniform vec4 flash : source_color = vec4(1.0, 0.3, 0.45, 1.0);
uniform vec4 pale : source_color = vec4(1.0, 0.8, 0.85, 1.0);
uniform float window = 0.42;
uniform float tilt = 1.0;
uniform float alpha_mid = 0.4;
uniform float alpha_rim = 0.8;
uniform float edge_dark = 0.6;
uniform float diffuse = 0.3;
uniform float glow = 0.4;
uniform float sparkle = 2.0;
uniform float sharp = 40.0;
uniform float rough = 0.03;
uniform float metal = 0.2;
uniform float spec = 0.5;
uniform float coat = 1.0;
uniform float rim = 0.4;
uniform float fire = 0.0;
uniform float play = 0.0;
uniform float play_scale = 3.0;
uniform float play_sat = 0.8;
uniform float play_fill = 1.0;
uniform float calm = 0.0;

void vertex() {
	CUT_VERTEX
}

void fragment() {
	float t = fan_t();
	float s = fan_s();
	float k = floor(v_fan.z + 0.5);
	vec3 fn;
	vec3 rad;
	vec3 tng;
	face_frame(fn, rad, tng);
	vec4 f = facet(cut, t, s, k, v_face, true, window);
	vec3 n = normalize(fn + (rad * f.x + tng * f.y) * tilt);
	NORMAL = n;
	float rimness = smoothstep(0.5, 1.0, t);
	// 0 in the middle of the face where the numeral sits, 1 beyond it.
	float quiet = calm > 0.0 ? smoothstep(calm * 0.55, calm, t) : 1.0;
	vec3 col = mix(body.rgb, deep.rgb, rimness * edge_dark) * mix(0.82, 1.0, quiet);
	float a = mix(alpha_mid, alpha_rim, rimness);
	col += tone_shift() * 0.6;
	vec3 rv = reflect(-VIEW, n);
	float tipped = step(0.5, f.w);
	float sp = pow(max(dot(rv, normalize(LAMP_KEY)), 0.0), sharp)
		+ 0.6 * pow(max(dot(rv, normalize(LAMP_COOL)), 0.0), sharp);
	sp *= tipped * (0.35 + 0.65 * f.z) * quiet;
	vec3 spark = mix(flash.rgb, vec3(1.0), 0.65);
#ifdef FIRE
	spark = mix(spark, rainbow(fract(f.z * 2.3 + dot(n, vec3(1.1, 0.7, 0.4)) * 1.7)) * 1.4 + 0.25, fire);
#endif
	vec3 extra = vec3(0.0);
#ifdef PLAY
	extra += play_of_color(UV, v_face, fn, rad, tng, play_scale, play_sat, play_fill, true) * play * a * mix(0.15, 1.0, quiet);
#endif
	// Faces turned away from the reader mirror less: at a grazing angle a clear coat and the
	// studio would wash a side face out white, where a gem's sides go dark and rich.
	float facing = smoothstep(0.35, 0.92, fn.z);
	ALBEDO = col * a * diffuse;
	ALPHA = clamp(a, 0.0, 1.0);
	EMISSION = col * a * glow + spark * sp * sparkle + extra;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec * facing * facing;
	CLEARCOAT = coat * facing;
	CLEARCOAT_ROUGHNESS = 0.0;
	RIM = rim;
	RIM_TINT = 1.0;
}
