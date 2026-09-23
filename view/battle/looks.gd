extends MeshInstance3D
## One swappable stylization pass over the finished 3D frame: a fullscreen quad drawn last
## inside the stage's viewport, with depth and view normals in hand, so a look can draw ink
## on silhouettes, band the light, grade the palette or throw the far wall out of focus.
##
## This sits under `screen_fx.gd`, which is the gameplay feedback layer (vignette, hurt,
## flashes) and stays on whatever look is picked.
##
## The house style is `ink_crease`: every fold of the low-poly rock drawn in its own colour,
## which is what makes flat shading read as a choice. The settings menu turns it off for the
## frames a second it costs. The rest are kept for the sake of being able to look at them
## again - `tools/look_gallery.gd` shoots the same room in every one of them side by side,
## and F9 walks them in a running game.

## The shared preamble: samplers, the knobs every look answers to, and the helpers.
## `amount` is how far the look is taken (0 is the raw frame); `scale` means whatever the
## look needs a size for - line width, band count, hatch spacing, focus distance.
const HEAD := """shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform float amount = 1.0;
uniform float scale = 1.0;
uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.88, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.70, 0.35, 1.0);
uniform float clock = 0.0;

void vertex() {
	// The quad is thrown over the whole frame whatever it was built as and wherever it sits.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float depth_at(vec2 at, mat4 inv_proj) {
	// Metres in front of the eye. Nothing written means nothing there: read it as very far.
	float raw = texture(depth_tex, at).x;
	if (raw <= 0.0) { return 4096.0; }
	vec4 view = inv_proj * vec4(at * 2.0 - 1.0, raw, 1.0);
	return -view.z / max(view.w, 0.0001);
}

vec3 normal_at(vec2 at) {
	return normalize(texture(normal_tex, at).xyz * 2.0 - 1.0);
}

float bayer(vec2 p) {
	// 4x4 ordered dither: the cheapest way to break a band without looking like noise.
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0;
}

float hatch(vec2 p, float angle, float spacing) {
	// 0 on the line, 1 halfway between two of them.
	vec2 dir = vec2(cos(angle), sin(angle));
	return abs(fract(dot(p, dir) / spacing) - 0.5) * 2.0;
}

vec2 hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract(vec2((q.x + q.y) * q.z, (q.x + q.z) * q.y));
}
"""

# --- the looks -----------------------------------------------------------------------------
##
## Each body is a whole `fragment()`. They all end by writing ALBEDO and ALPHA; the ALPHA is
## what puts the quad in the transparent pass, which is where the normal buffer can be read
## and where drawing last is a promise rather than a hope.

## The ink family's own knobs, appended to the preamble only for those looks. `scale` is the
## line width in pixels; everything else is a preset in LOOKS below.
const INK_KNOBS := """
uniform float depth_gain = 5.0;
uniform float normal_gain = 1.6;
uniform float edge_lo = 0.22;
uniform float edge_hi = 0.60;
uniform int tint_mode = 1;
uniform float darken = 0.35;
uniform float accent_mix = 0.0;
uniform float fade_at = 0.0;
"""

const INK := """
void fragment() {
	vec2 px = scale / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float d0 = depth_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec2 taps[4] = vec2[4](vec2(-px.x, 0.0), vec2(px.x, 0.0), vec2(0.0, -px.y), vec2(0.0, px.y));
	// Which of the neighbours is nearest the eye is which solid owns this edge: at a
	// silhouette the pixel straddles two of them, and the line belongs to the one in front.
	float d[4];
	float owner_d = d0;
	vec2 owner_uv = SCREEN_UV;
	for (int i = 0; i < 4; i++) {
		vec2 at = SCREEN_UV + taps[i];
		d[i] = depth_at(at, INV_PROJECTION_MATRIX);
		if (d[i] < owner_d) { owner_d = d[i]; owner_uv = at; }
	}
	// Relative to how far off the surface is, or a wall 30 m back is one long smear.
	float edge_d = (abs(d[0] + d[1] - 2.0 * d0) + abs(d[2] + d[3] - 2.0 * d0)) / max(d0, 0.6);
	vec3 n0 = normal_at(SCREEN_UV);
	float edge_n = (1.0 - dot(n0, normal_at(SCREEN_UV + taps[1])))
		+ (1.0 - dot(n0, normal_at(SCREEN_UV + taps[3])))
		+ (1.0 - dot(n0, normal_at(SCREEN_UV + taps[0] + taps[2])));
	float e = clamp(edge_d * depth_gain + edge_n * normal_gain, 0.0, 1.0);
	e = smoothstep(edge_lo, edge_hi, e);
	if (fade_at > 0.0) {
		// Draw what is close and leave the far end of the room to the fog.
		e *= clamp(1.0 - (min(d0, owner_d) - fade_at) / fade_at, 0.0, 1.0);
	}
	// What the line is drawn in. Only the lit colour of the solid is on hand, never its
	// albedo, so a surface standing in shadow lends a nearly black line and a hot one a
	// bright line - which is mostly what you want anyway.
	vec3 owner = texture(screen_tex, owner_uv).rgb;
	vec3 line = ink.rgb * (0.25 + 0.75 * lum(col));
	if (tint_mode == 0) { line = ink.rgb; }
	else if (tint_mode == 2) { line = owner * darken; }
	else if (tint_mode == 3) { line = max(mix(vec3(lum(owner)), owner, 1.8), vec3(0.0)) * darken; }
	else if (tint_mode == 4) { line = owner + (vec3(1.0) - owner) * darken; }
	if (accent_mix > 0.0) {
		// The hue of the room's accent at the darkness the line already had: colour the ink
		// without lighting it, which in a cave this dark is the whole difference.
		float keep = lum(line);
		line = mix(line, accent.rgb / max(lum(accent.rgb), 0.001) * keep, accent_mix);
	}
	ALBEDO = mix(col, line, e * amount);
	ALPHA = 1.0;
}
"""

const POSTERIZE := """
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float steps = max(2.0, floor(scale));
	float d = (bayer(FRAGCOORD.xy) - 0.5) / steps;
	vec3 banded = floor((col + d) * steps + 0.5) / steps;
	ALBEDO = mix(col, banded, amount);
	ALPHA = 1.0;
}
"""

const DUOTONE := """
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float l = clamp(lum(col) * scale, 0.0, 1.0);
	// Shadow -> the room's own accent -> lamp light: three stops, everything between mixed.
	vec3 ramp = l < 0.5 ? mix(ink.rgb, accent.rgb, l * 2.0) : mix(accent.rgb, paper.rgb, (l - 0.5) * 2.0);
	// A quarter of the frame's own colour kept back, or every gem in the room turns the
	// same shade as the wall behind it.
	ramp = mix(ramp, ramp * 0.55 + col * 0.65, 0.25);
	ALBEDO = mix(col, ramp, amount);
	ALPHA = 1.0;
}
"""

const HATCH := """
void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float l = lum(col);
	vec2 p = FRAGCOORD.xy;
	float spacing = max(2.0, scale);
	// Four passes of the burin, each laid in only where the light has fallen far enough.
	float h = 1.0;
	if (l < 0.62) { h = min(h, hatch(p, 0.79, spacing)); }
	if (l < 0.38) { h = min(h, hatch(p, -0.79, spacing)); }
	if (l < 0.20) { h = min(h, hatch(p + 3.0, 0.0, spacing)); }
	if (l < 0.09) { h = min(h, hatch(p + 7.0, 1.5708, spacing)); }
	float k = smoothstep(0.0, 0.30, h);
	vec3 drawn = mix(ink.rgb, mix(paper.rgb * 0.75, col, 0.6), k);
	ALBEDO = mix(col, drawn, amount);
	ALPHA = 1.0;
}
"""

const DIORAMA := """
void fragment() {
	// Depth of field off the real depth buffer: the chamber reads as a model on a table.
	float d = depth_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	float blur = clamp(abs(d - scale) / (scale * 0.9), 0.0, 1.0);
	blur = pow(blur, 1.4);
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	vec3 col = mix(sharp, textureLod(screen_tex, SCREEN_UV, blur * 4.0).rgb, amount);
	// Toys are saturated. A little more punch sells the size.
	float l = lum(col);
	ALBEDO = clamp(mix(vec3(l), col, 1.0 + 0.3 * amount), vec3(0.0), vec3(8.0));
	ALPHA = 1.0;
}
"""

const KUWAHARA := """
void fragment() {
	// Painterly: each pixel takes the flattest of the four squares around it, so shading
	// collapses into brush-shaped patches and still keeps its edges.
	vec2 px = scale / VIEWPORT_SIZE;
	vec3 raw = texture(screen_tex, SCREEN_UV).rgb;
	vec3 best = raw;
	float least = 1e9;
	for (int q = 0; q < 4; q++) {
		vec2 side = vec2(q == 0 || q == 3 ? 1.0 : -1.0, q < 2 ? 1.0 : -1.0);
		vec3 sum = vec3(0.0);
		vec3 sum2 = vec3(0.0);
		for (int y = 0; y <= 3; y++) {
			for (int x = 0; x <= 3; x++) {
				vec3 s = texture(screen_tex, SCREEN_UV + side * vec2(float(x), float(y)) * px).rgb;
				sum += s;
				sum2 += s * s;
			}
		}
		vec3 mean = sum / 16.0;
		vec3 spread = abs(sum2 / 16.0 - mean * mean);
		float v = spread.r + spread.g + spread.b;
		if (v < least) { least = v; best = mean; }
	}
	ALBEDO = mix(raw, best, amount);
	ALPHA = 1.0;
}
"""

const FACETS := """
void fragment() {
	// The whole frame seen through a cut stone: screen-space cells, each refracting a
	// little off its own centre, with light caught along the seams between them.
	vec2 aspect = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float cells = max(4.0, scale);
	vec2 grid = SCREEN_UV * aspect * cells;
	vec2 cell = floor(grid);
	vec2 within = fract(grid);
	vec2 nearest = vec2(0.0);
	float best = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 over = vec2(float(x), float(y));
			vec2 point = over + hash2(cell + over);
			float d = length(point - within);
			if (d < best) { second = best; best = d; nearest = point + cell; }
			else if (d < second) { second = d; }
		}
	}
	// Toward the facet's own centre: a flat pane bends the room behind it one way all over.
	vec2 bend = (nearest - grid) / (aspect * cells);
	vec3 col = texture(screen_tex, SCREEN_UV + bend * amount * 0.55).rgb;
	float seam = smoothstep(0.0, 0.06, second - best);
	col = mix(col + accent.rgb * 0.35, col, seam);
	col *= 0.92 + 0.16 * hash2(nearest).x;
	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, col, amount);
	ALPHA = 1.0;
}
"""

const PIXEL := """
void fragment() {
	vec2 grid = VIEWPORT_SIZE / max(2.0, scale);
	vec2 snapped = (floor(SCREEN_UV * grid) + 0.5) / grid;
	vec3 col = texture(screen_tex, snapped).rgb;
	float steps = 10.0;
	float d = (bayer(floor(SCREEN_UV * grid)) - 0.5) / steps;
	col = floor((col + d) * steps + 0.5) / steps;
	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, col, amount);
	ALPHA = 1.0;
}
"""

## Every look, in the order the cycle key walks them. `amount` and `scale` are the defaults
## the gallery shoots at; both are meant to be dialled.
const LOOKS: Dictionary = {
	"off": {"name": "No pass", "body": "", "amount": 0.0, "scale": 1.0, "note": "the frame as the renderer leaves it"},
	## The ink family: one shader, nine settings of it. `tint_mode` is what the line is
	## drawn in - 0 flat, 1 the room's dark, 2 the solid's own lit colour, 3 the solid's hue
	## at a darkness of our choosing, 4 chalk (light lines).
	"ink": {"name": "Ink · baseline", "body": INK, "knobs": INK_KNOBS, "amount": 0.85, "scale": 1.2,
		"note": "depth and normal edges, drawn in the room's own dark"},
	"ink_fine": {"name": "Ink · fine silhouette", "body": INK, "knobs": INK_KNOBS, "amount": 0.9, "scale": 1.0,
		"uniforms": {"depth_gain": 7.0, "normal_gain": 0.45, "edge_lo": 0.30, "edge_hi": 0.52},
		"note": "one clean line where the solid ends; creases left alone"},
	"ink_bold": {"name": "Ink · bold", "body": INK, "knobs": INK_KNOBS, "amount": 1.0, "scale": 2.2,
		"uniforms": {"depth_gain": 5.0, "normal_gain": 1.2, "edge_lo": 0.16, "edge_hi": 0.44, "tint_mode": 0},
		"note": "thick and flat, the same near-black everywhere"},
	"ink_own": {"name": "Ink · the solid's colour", "body": INK, "knobs": INK_KNOBS, "amount": 0.9, "scale": 1.2,
		"uniforms": {"tint_mode": 2, "darken": 0.35},
		"note": "the line is the lit colour of whatever it is drawn around, taken down a third"},
	"ink_hue": {"name": "Ink · the solid's hue", "body": INK, "knobs": INK_KNOBS, "amount": 0.9, "scale": 1.2,
		"uniforms": {"tint_mode": 3, "darken": 0.30},
		"note": "same hue as the solid but our darkness, so a shadowed face still gets a line"},
	"ink_chalk": {"name": "Ink · chalk", "body": INK, "knobs": INK_KNOBS, "amount": 0.7, "scale": 1.2,
		"uniforms": {"tint_mode": 4, "darken": 0.55},
		"note": "light lines instead of dark: the room drawn on slate"},
	"ink_crease": {"name": "Ink · every facet", "body": INK, "knobs": INK_KNOBS, "amount": 0.8, "scale": 1.1,
		"uniforms": {"depth_gain": 2.0, "normal_gain": 3.2, "edge_lo": 0.14, "edge_hi": 0.55, "tint_mode": 3, "darken": 0.30},
		"note": "normals lead: every fold of the low-poly rock is drawn, not only its edge"},
	"ink_near": {"name": "Ink · near only", "body": INK, "knobs": INK_KNOBS, "amount": 0.95, "scale": 1.4,
		"uniforms": {"tint_mode": 2, "darken": 0.35, "fade_at": 14.0},
		"note": "the arc and the creatures inked, the far wall left to the fog"},
	"ink_accent": {"name": "Ink · coloured", "body": INK, "knobs": INK_KNOBS, "amount": 0.85, "scale": 1.2,
		"uniforms": {"tint_mode": 3, "darken": 0.34, "accent_mix": 0.6},
		"note": "the solid's hue pulled most of the way to the biome's accent"},
	"posterize": {"name": "Banded + dither", "body": POSTERIZE, "amount": 0.9, "scale": 6.0, "note": "light quantised to a few stops, seams broken with a 4x4 dither"},
	"duotone": {"name": "Biome gradient map", "body": DUOTONE, "amount": 0.7, "scale": 1.15, "note": "luminance remapped onto shadow -> biome accent -> lamp light"},
	"hatch": {"name": "Cross-hatch", "body": HATCH, "amount": 0.8, "scale": 5.0, "note": "woodcut: four burin passes laid into the dark"},
	"diorama": {"name": "Diorama focus", "body": DIORAMA, "amount": 0.9, "scale": 9.0, "note": "depth of field around the arc, saturation up: the room reads as a model"},
	"kuwahara": {"name": "Painterly", "body": KUWAHARA, "amount": 0.85, "scale": 2.0, "note": "shading flattened into brush patches, edges kept; the dear one"},
	"facets": {"name": "Cut stone", "body": FACETS, "amount": 0.5, "scale": 14.0, "note": "the frame seen through a gem: cell refraction, light on the seams"},
	"pixel": {"name": "Pixelate", "body": PIXEL, "amount": 1.0, "scale": 3.0, "note": "downsampled and palette-stepped"},
}

const ORDER: Array = ["off", "ink", "ink_fine", "ink_bold", "ink_own", "ink_hue", "ink_chalk", "ink_crease",
	"ink_near", "ink_accent", "posterize", "duotone", "hatch", "diorama", "kuwahara", "facets", "pixel"]

## What every stage built from now on wears, and what `apply_look()` puts on the one already
## standing. The settings menu, the gallery and the cycle key all write this.
static var pref: String = "ink_crease"
## The look the outline setting turns back on, so the switch never lands on someone else's
## experiment left behind by F9.
const HOUSE: String = "ink_crease"

var look: String = "off"
var amount: float = 1.0
var size: float = 1.0

## One material per look. Uniform values live on the material and outlast a shader swap, so
## a shared one would have every preset wearing the leftovers of the last preset that set a
## knob it does not mention itself.
var _material: ShaderMaterial = null
var _materials: Dictionary = {}
## The current preset's own settings, and anything `tune()` has written over them since.
var _knobs: Dictionary = {}
var _biome: Dictionary = {}
var _clock: float = 0.0

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	## The quad covers whatever the camera points at, so it must never be culled for sitting
	## behind the eye.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_look(pref)

func _process(delta: float) -> void:
	if _material == null or look == "off":
		return
	_clock += delta
	_material.set_shader_parameter("clock", _clock)

func set_look(id: String) -> void:
	## Swap the pass. Each shader is compiled once and kept, so cycling is instant after the
	## first look at each.
	look = id if LOOKS.has(id) else "off"
	var entry: Dictionary = LOOKS[look]
	amount = float(entry.amount)
	size = float(entry.scale)
	visible = look != "off"
	if look == "off":
		_material = null
		material_override = null
		return
	_knobs = (entry.get("uniforms", {}) as Dictionary).duplicate()
	if not _materials.has(look):
		var shader := Shader.new()
		shader.code = HEAD + str(entry.get("knobs", "")) + str(entry.body)
		var made := ShaderMaterial.new()
		made.shader = shader
		## First of the transparent queue, not last. The pass rebuilds the frame out of depth
		## and normals, and nothing transparent writes either: drawn last it painted over
		## every stone on a counter, every price over it and every mark above a tunnel mouth
		## and left them gone. Drawn first it inks the rock, and everything that stands in
		## the room is drawn over the top of that, crisp.
		made.render_priority = -128
		_materials[look] = made
	_material = _materials[look]
	material_override = _material
	_apply()

func dial(new_amount: float = -1.0, new_size: float = -1.0) -> void:
	## Turn the two knobs without changing look, for a gallery shooting a sweep.
	if new_amount >= 0.0:
		amount = new_amount
	if new_size >= 0.0:
		size = new_size
	_apply()

func cycle(by: int = 1) -> String:
	var at: int = ORDER.find(look)
	set_look(str(ORDER[posmod(at + by, ORDER.size())]))
	return look

func tint(biome: Dictionary) -> void:
	## The three colours a look grades with, taken from the room it stands in, so the same
	## pass reads as the Galleries down one shaft and the Rift down another.
	_biome = biome
	_apply()

func tune(knobs: Dictionary) -> void:
	## One knob of the current preset moved, for a gallery shooting a sweep of a look.
	for key in knobs:
		_knobs[key] = knobs[key]
	_apply()

func _apply() -> void:
	if _material == null or _material.shader == null:
		return
	_material.set_shader_parameter("amount", amount)
	_material.set_shader_parameter("scale", size)
	for key in _knobs:
		_material.set_shader_parameter(str(key), _knobs[key])
	_material.set_shader_parameter("ink", _color("rock_dark", Color(0.03, 0.03, 0.05)).darkened(0.45))
	_material.set_shader_parameter("accent", _color("accent", Color(1.0, 0.70, 0.35)))
	_material.set_shader_parameter("paper", _color("key", Color(0.95, 0.93, 0.88)).lightened(0.15))

func _color(field: String, fallback: Color) -> Color:
	var value: Variant = _biome.get(field, null)
	if value is Color:
		return value
	if value is String:
		return Color(str(value))
	return fallback
