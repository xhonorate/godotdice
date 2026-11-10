// A cut die's inside: its far faces, seen through its near ones (gem_cut.gd builds the shader:
// `shader_type`, then a #define for each feature a look asks for, then this). Each far face is
// broken into facets (a brilliant's pavilion, or none for a smooth die) and each facet throws
// back the light it would catch inside a cut stone, so some go near black and some flash as
// the die turns. Unshaded and opaque: one pass, no lights, nothing behind it to read.
// Features: FIRE (flashes split into rainbow colors), PLAY (an opal's patches of color),
// BANDS (parallel prism bands, each a spectrum: crystal).
// `calm` quiets the middle of each face, behind the numeral seen through it.
render_mode unshaded, cull_front;

#include "res://view/dice/cuts/cut_common.gdshaderinc"

uniform int cut = 0;
uniform vec4 body : source_color = vec4(0.7, 0.05, 0.1, 1.0);
uniform vec4 deep : source_color = vec4(0.2, 0.0, 0.02, 1.0);
uniform vec4 flash : source_color = vec4(1.0, 0.3, 0.45, 1.0);
uniform vec4 pale : source_color = vec4(1.0, 0.8, 0.85, 1.0);
uniform float window = 0.42;
uniform float tilt = 1.0;
uniform float sharp = 16.0;
uniform float flash_gain = 1.4;
uniform float base_lo = 0.05;
uniform float base_hi = 0.9;
uniform float edge_dark = 0.6;
uniform float line_dark = 0.5;
// Facet lines that shine instead of darkening (cut glass's prismatic edges).
uniform float line_glow = 0.0;
uniform float brightness = 1.0;
uniform float fire = 0.0;
uniform float play = 0.0;
uniform float play_scale = 3.0;
uniform float play_sat = 0.8;
uniform float play_fill = 1.0;
uniform float calm = 0.0;
uniform float bands = 0.0;

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
	vec4 f = facet(cut, t, s, k, v_face, false, window);
	float line = facet_line(cut, t, s);
	vec3 n = normalize(fn + (rad * f.x + tng * f.y) * tilt);
	// Straight in through the near face, off this facet from inside, and out towards a lamp.
	vec3 r = reflect(vec3(0.0, 0.0, -1.0), -n);
	float fl = pow(max(dot(r, normalize(LAMP_KEY)), 0.0), sharp)
		+ 0.75 * pow(max(dot(r, normalize(LAMP_COOL)), 0.0), sharp)
		+ 0.5 * pow(max(dot(r, normalize(LAMP_LOW)), 0.0), sharp);
	float rimness = smoothstep(0.45, 1.0, t);
	float quiet = calm > 0.0 ? smoothstep(calm * 0.55, calm, t) : 1.0;
	fl *= mix(0.2, 1.0, quiet);
	vec3 col = mix(deep.rgb, body.rgb, mix(base_lo, base_hi, f.z * f.z)) * mix(0.62, 1.0, quiet);
	col *= 1.0 - edge_dark * rimness;
	vec3 hot = mix(flash.rgb, vec3(1.0), clamp(fl * 0.5 - 0.3, 0.0, 0.8));
#ifdef FIRE
	// Dispersion: each facet throws its flash back split into one color of the spectrum,
	// which slides as the die turns.
	float hue = fract(f.z * 2.7 + dot(n, vec3(0.9, 1.3, 0.4)) * 1.5);
	hot = mix(hot, rainbow(hue) * 1.3, fire * quiet);
#endif
	col += hot * fl * flash_gain;
#ifdef PLAY
	col += play_of_color(UV, v_face, fn, rad, tng, play_scale, play_sat, play_fill, false) * play * mix(0.15, 1.0, quiet);
#endif
#ifdef BANDS
	// Light split by the crystal into parallel bands, each its own little spectrum, sliding
	// across the inside as the face turns.
	float across = dot(v_obj, normalize(vec3(0.55, 0.8, 0.25))) * 3.2 + dot(fn, vec3(0.9, 0.6, 0.3)) * 1.4;
	float within = fract(across);
	float lit_band = step(0.45, fract(floor(across) * 0.618 + 0.2));
	float shape = smoothstep(0.0, 0.18, within) * (1.0 - smoothstep(0.82, 1.0, within));
	col += rainbow(within * 0.85) * shape * lit_band * bands * mix(0.25, 1.0, quiet);
#endif
	col *= 1.0 - line * line_dark;
	col += pale.rgb * line * line_glow;
	col += tone_shift() * 0.6;
	ALBEDO = max(col * brightness, vec3(0.0));
}
