// An opaque die (gem_cut.gd builds the shader around this): one lit pass, its pattern worked
// out from where a point is on the solid or on its face, under a clear coat where it has one.
// One pattern a look:
//   OXBLOOD  near-black red marbled with darker veins (blood, shipped November 10 2026); its
//            veins swell and glow by the die's own `pulse` (an instance uniform: one die feeds)
//   DENTS    a polished nugget, softly dented (fool's gold, shipped November 10 2026)
//   GRANITE  angular mineral grains (ROUGHHEWN: unpolished relief)
//   FLAKES   (with any) mirror flakes that glint as it turns: mica
//   STORM    a cloud roiling slowly, lightning flickering through it
render_mode cull_back;

#include "res://view/dice/cuts/cut_common.gdshaderinc"

uniform vec4 body : source_color = vec4(0.36, 0.03, 0.06, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.0, 0.01, 1.0);
uniform vec4 vein : source_color = vec4(0.05, 0.0, 0.0, 1.0);
uniform vec4 fresh : source_color = vec4(0.62, 0.05, 0.1, 1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform float scale = 1.0;
uniform float glow = 0.1;
uniform float rough = 0.3;
uniform float coat = 1.0;
uniform float bump = 0.6;
uniform float spec = 0.5;
uniform float metal = 0.0;
uniform float grain = 22.0;
uniform float dark_share = 0.22;
uniform float quartz_share = 0.3;
uniform float sparkle = 0.0;
uniform float flake_scale = 14.0;
uniform float flake_amount = 0.5;
uniform float sharp = 40.0;

#ifdef OXBLOOD
instance uniform float pulse = 0.0;
#endif

void vertex() {
	CUT_VERTEX
}

void fragment() {
	vec3 p = v_obj * scale;
	float t = fan_t();
	vec3 fn;
	vec3 rad;
	vec3 tng;
	face_frame(fn, rad, tng);
	vec3 col = body.rgb;
	float r = rough;
	float cc = coat;
	float m = metal;
	float h = 0.0;
	vec3 em = vec3(0.0);
#ifdef OXBLOOD
	// Dark clouds swirled through the red, and veins only where a second field lets them
	// through, so they come in runs and not as contour lines all over.
	float ox_m = fbm(p * 1.5 + 4.0);
	float ox_w = fbm(p * 2.1 + vec3(ox_m * 3.2, ox_m * 2.1, -ox_m * 2.7));
	float runs = smoothstep(0.42, 0.62, fbm(p * 1.1 + 20.0));
	float veins = (1.0 - smoothstep(0.0, 0.035 * (1.0 + pulse * 1.2), abs(ox_w - 0.5))) * runs;
	float fine = (1.0 - smoothstep(0.0, 0.018, abs(fbm(p * 3.4 + vec3(ox_m * 1.5) + 9.0) - 0.5))) * (1.0 - runs) * 0.6;
	col = mix(fresh.rgb, body.rgb, smoothstep(0.2, 0.5, ox_m));
	col = mix(col, deep.rgb, smoothstep(0.5, 0.8, ox_w * 0.5 + ox_m * 0.5));
	col = mix(col, vein.rgb, max(veins, fine) * 0.92);
	h = -max(veins, fine) * 0.5;
	// Fed: the veins swell and run bright with fresh blood, and the body warms.
	em += fresh.rgb * (max(veins, fine) * 3.5 + 0.5) * pulse;
#endif
#ifdef DENTS
	h = fbm(p * 3.2 + 1.0);
	col = body.rgb * (0.78 + 0.34 * h) + fresh.rgb * smoothstep(0.85, 0.98, t) * 0.25;
#endif
#ifdef GRANITE
	// Angular mineral grains, each one mineral: dark mica, grey quartz, the rest feldspar.
	vec4 grains = voro(UV * grain, v_face * 1.9 + 3.0);
	float mineral = grains.z;
	col = body.rgb * (0.82 + 0.3 * grains.w);
	col = mix(col, vein.rgb * (0.85 + 0.3 * grains.w), step(dark_share, mineral) * step(mineral, dark_share + quartz_share));
	col = mix(col, deep.rgb, step(mineral, dark_share));
	col *= 0.86 + 0.14 * smoothstep(0.0, 0.05, grains.y);
	col *= 0.92 + 0.16 * vnoise(p * grain * 2.0);
#endif
#ifdef ROUGHHEWN
	h = fbm(p * 6.0) * 0.7 + vnoise(p * 24.0) * 0.3;
	cc = 0.0;
#endif
#ifdef FLAKES
	vec4 fc = voro(UV * flake_scale, v_face * 5.7 + 2.0);
	float flake = (1.0 - smoothstep(0.08, 0.2, fc.x)) * step(fc.z, flake_amount);
	vec3 flake_n = normalize(fn + (rad * (fc.z - 0.5) + tng * (fc.w - 0.5)) * 2.0);
	vec3 fr = reflect(vec3(0.0, 0.0, -1.0), flake_n);
	float glint = pow(max(dot(fr, normalize(LAMP_KEY)), 0.0), sharp) + 0.6 * pow(max(dot(fr, normalize(LAMP_COOL)), 0.0), sharp) + 0.03;
	em += accent.rgb * flake * glint * sparkle;
	col = mix(col, accent.rgb * 0.5, flake * 0.5);
#endif
#ifdef STORM
	float roil = fbm(p * 2.4 + vec3(0.0, TIME * 0.05, 0.0));
	col = mix(deep.rgb, body.rgb, smoothstep(0.3, 0.8, roil));
	float bolt_at = abs(fbm(p * 1.7 + 11.0) - 0.5);
	float reach = smoothstep(0.5, 0.62, fbm(p * 1.1 + 40.0));
	float bolt = (1.0 - smoothstep(0.0, 0.022, bolt_at)) * reach;
	float halo = (1.0 - smoothstep(0.0, 0.14, bolt_at)) * reach;
	// The lightning flickers: never quite out, now and then a full flash.
	float flick = 0.35 + 0.65 * step(0.6, fract(sin(floor(TIME * 7.0) * 12.9898) * 43758.5453));
	em += accent.rgb * (bolt * 3.5 + halo * 0.6) * flick;
	col = mix(col, fresh.rgb, halo * 0.3 * flick);
	h = roil * 0.5;
#endif
	// The pattern's relief, from how it changes across the screen.
	vec3 nrm = fn;
	vec3 dpdx = dFdx(v_pos);
	vec3 dpdy = dFdy(v_pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, nrm);
	vec3 r2 = cross(nrm, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	if (bump > 0.0) {
		nrm = normalize(abs(det) * nrm - grad * bump * 0.02);
	}
	NORMAL = nrm;
	col += tone_shift() * 0.6;
	// Faces turned away mirror less (a grazing face would mirror the studio silver).
	float facing = smoothstep(0.3, 0.92, fn.z);
	ALBEDO = max(col, vec3(0.0));
	EMISSION = col * glow + em;
	ROUGHNESS = r;
	METALLIC = m;
	SPECULAR = spec * mix(facing * facing, 1.0, m);
	CLEARCOAT = cc * facing;
	CLEARCOAT_ROUGHNESS = 0.02;
	RIM = 0.25;
	RIM_TINT = 1.0;
}
