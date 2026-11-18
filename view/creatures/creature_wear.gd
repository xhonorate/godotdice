extends Node3D
## What a creature wears for what is on it (the Creature Tells pass, October 27, 2026): a
## lasting look on the model for every status the party can put on it, each distinct at a
## glance and able to stand beside the others.
##
## - Poison: the body goes a sickly green, deeper per stack, breathing; drops fall off it.
##   Its tick flashes the whole body bright green (`tick_flash`).
## - Burn: embers rise off it the whole time and an orange glow pulses under it.
## - Curse: violet chain loops around the body, one more per stack, crawling.
## - Marked: a red X scratched across the front of it, flickering.
## - Stun: it goes grey and slumps; stars circle its head, turned to the camera.
## - Strength: red heat cracks in the body, and it bulks up as it gains it (`bulk_up`).
## - Spikes: grey thorns jut out of it. Regeneration: green motes rising.
## - Ward: a thin ring of blue light over its head (November 18, 2026: the bubble round the
##   whole body was too big). It flashes and breaks apart when it takes a debuff for the
##   creature (`pop_ward`), and fades back in if Ward is left.
## - Block wears nothing on the body (November 16, 2026: the grey stone crust that plated it
##   over read as the model fracturing, and the owner had it taken off). Block is the tag's
##   blue chip and the hatch on its health bar, and a soaked blow is the shield flash.
##
## And what it wears for what it is (November 18, 2026): a look for each named trait
## (`set_traits`), there for as long as it has the trait, stronger than any status and able
## to stand beside two more.
##
## - Molten: the body glows orange with white-hot seams; flames and cinders rise off it.
## - Venomous: an acid green body with dark veins, heavy drops, a pool of green mist at its
##   feet.
## - Wrathful: a red body with lit red veins and steam off the top of it; it swells more than
##   Strength alone would.
## - Leeching: a dark crimson body and seams; red motes drawn in toward it.
## - Sturdy: plates of stone over the body, dark between them, and boulders set in it.
## - Jagged: blades of pale blue glass grown out of it, far bigger than Spikes' thorns.
## - Steadfast: iron bands bolted round it.
## - Splits: a pale violet twin of it that slides out of the body and back in on a slow
##   breath.
## - Fallen (a boss on its last point, waiting to get back up): grey and slumped like a stun
##   without the stars, its trait looks dimmed. `rise_burst` is the moment it gets up.
##
## The tints, the seams and the stone are one overlay material drawn over every mesh of the
## body (triplanar masks laid on each mesh as it is, so no creature needs UVs and nothing
## swims as it moves); a creature with two or three tinted traits wears them in bands up its
## body. The rest are meshes and particles of its own. Everything eases toward what is asked
## of it, so a status that ends fades and a trait gained mid-fight grows in.

const BattleFx = preload("res://view/battle/battle_fx.gd")
const Lowpoly = preload("res://view/battle/lowpoly.gd")

const POISON := Color("9ad35a")
const BURN := Color("ff7a2a")
const CURSE := Color("c58bff")
const MARK := Color("ff5a5a")
const STUN := Color("ffe27a")
const STRENGTH := Color("ff7a5a")
const SPIKES := Color("c0c4d0")
const WARD := Color("6fa8ff")
const REGEN := Color("6fe3b0")
## The grey a stunned creature goes, and the darker one of a boss that has fallen.
const STUNNED := Color(0.5, 0.5, 0.56, 0.6)
const FALLEN := Color(0.32, 0.32, 0.38, 0.78)

## The color each named trait is drawn in, here and wherever else the trait is named.
const TRAIT_COLORS: Dictionary = {
	"molten": Color("ff8a2a"),
	"venomous": Color("7fdc3c"),
	"wrathful": Color("ff3a2a"),
	"jagged": Color("a8e4ff"),
	"split_on_big_hit": Color("d2b8ff"),
	"sturdy": Color("9a948c"),
	"steadfast": Color("8c93a6"),
	"leeching": Color("b0122e"),
}
## The traits that tint the body: the tint, the seams lit in it (brighter than white where
## they should bloom) and how far it is stone. Listed from the floor up: a creature with two
## or three of them wears them in bands in this order, so each keeps its own color.
const BANDS: Dictionary = {
	"sturdy": [Color(0.4, 0.39, 0.38, 0.6), Color(0, 0, 0, 0), 1.0],
	"molten": [Color(1.0, 0.2, 0.02, 0.62), Color(2.3, 1.7, 0.6, 1.0), 0.0],
	"venomous": [Color(0.3, 0.86, 0.12, 0.6), Color(0.03, 0.2, 0.02, 0.85), 0.0],
	"leeching": [Color(0.26, 0.0, 0.05, 0.7), Color(1.6, 0.05, 0.16, 0.95), 0.0],
	"wrathful": [Color(0.85, 0.03, 0.03, 0.5), Color(1.7, 0.07, 0.04, 1.0), 0.0],
}
const BAND_ORDER: Array = ["sturdy", "molten", "venomous", "leeching", "wrathful"]
## How strongly each trait lights the floor under the creature.
const AURA: Dictionary = {"molten": 1.0, "venomous": 0.9, "wrathful": 0.8, "leeching": 0.5, "jagged": 0.3, "split_on_big_hit": 0.4}
## The traits with meshes or particles of their own to build.
const BUILT: Array = ["molten", "venomous", "wrathful", "leeching", "sturdy", "jagged", "steadfast"]
## How far over the height it stood at a swelling creature's head may rise, room units: the
## room kept between its head and its tag. Past it, it only grows wider.
const HEAD_ROOM: float = 0.12
## How many points of the body's surface are kept for laying blades, bands and boulders on.
const SURFACE_POINTS: int = 900

const OVERLAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(0.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.48, 0.35, 0.0);
uniform sampler2D cracks : hint_default_black, repeat_enable;
uniform sampler2D seams : hint_default_black, repeat_enable;
uniform sampler2D stone : hint_default_black, repeat_enable;
uniform float tex_scale = 1.1;
uniform vec4 band_a : source_color = vec4(0.0);
uniform vec4 band_b : source_color = vec4(0.0);
uniform vec4 band_c : source_color = vec4(0.0);
uniform vec4 seam_a : source_color = vec4(0.0);
uniform vec4 seam_b : source_color = vec4(0.0);
uniform vec4 seam_c : source_color = vec4(0.0);
uniform vec3 crust = vec3(0.0);
uniform vec2 cuts = vec2(2.0, 2.0);
uniform float foot = 0.0;
uniform float tall = 1.0;
uniform float lit = 1.0;
uniform vec4 sweep : source_color = vec4(0.0);
uniform float sweep_at = 0.0;
varying vec3 opos;
varying vec3 onorm;
varying vec3 wnorm;
varying float height;
void vertex() {
	// Where it is on its own mesh, in the room's sizes: a mask laid there stays put on a
	// part as the creature breathes, rears and swings it.
	opos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	onorm = NORMAL;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = ((MODEL_MATRIX * vec4(VERTEX, 1.0)).y - foot) / tall;
}
float tri(sampler2D t, vec3 p, vec3 n) {
	vec3 b = abs(n);
	b /= max(0.001, b.x + b.y + b.z);
	return texture(t, p.yz).r * b.x + texture(t, p.xz).r * b.y + texture(t, p.xy).r * b.z;
}
vec2 plates(sampler2D t, vec3 p, vec3 n) {
	// One facing wins outright on a flat facet, or three sets of plates show through each other.
	vec3 b = pow(abs(n), vec3(8.0));
	b /= max(0.001, b.x + b.y + b.z);
	return texture(t, p.yz).rg * b.x + texture(t, p.xz).rg * b.y + texture(t, p.xy).rg * b.z;
}
void over(inout vec3 col, inout float a, vec3 top, float top_a) {
	float both = top_a + a * (1.0 - top_a);
	col = (top * top_a + col * a * (1.0 - top_a)) / max(0.001, both);
	a = both;
}
void fragment() {
	vec3 p = opos * tex_scale;
	vec2 cell = plates(stone, p * 2.4, onorm);
	// The bands up the body: which trait this height wears, the edge between two broken up.
	float h = height + (cell.r - 0.5) * 0.14;
	float ub = smoothstep(cuts.x - 0.025, cuts.x + 0.025, h);
	float uc = smoothstep(cuts.y - 0.025, cuts.y + 0.025, h);
	vec4 band = mix(mix(band_a, band_b, ub), band_c, uc);
	vec4 seam = mix(mix(seam_a, seam_b, ub), seam_c, uc);
	float rock = mix(mix(crust.x, crust.y, ub), crust.z, uc);
	vec3 col = band.rgb;
	// A fallen boss's own color fades with its light, so it is grey and not a dull red.
	float a = band.a * (0.3 + 0.7 * lit);
	// Its seams, the light in them creeping up the body.
	float line = smoothstep(0.2, 0.6, tri(seams, p * 0.8 + vec3(0.37, 0.11, 0.53), onorm));
	over(col, a, seam.rgb, seam.a * line * lit * (0.78 + 0.22 * sin(TIME * 3.1 - height * 6.0)));
	// Stone: plates of it lit from above, dark between them, a few missing.
	float light = 0.5 + 0.5 * dot(wnorm, normalize(vec3(-0.35, 0.8, 0.45)));
	vec3 grey = mix(vec3(0.075, 0.072, 0.07), vec3(0.2, 0.19, 0.175), cell.r) * (0.6 + 0.7 * light);
	grey = mix(vec3(0.006, 0.005, 0.005), grey, smoothstep(0.04, 0.14, cell.g));
	over(col, a, grey, rock * smoothstep(0.03, 0.07, cell.r) * 0.97);
	// The trait's own light on its outline.
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	over(col, a, band.rgb * 1.5 + 0.12, edge * band.a * (1.0 - rock) * lit);
	// What the party put on it, over what it is.
	over(col, a, tint.rgb, tint.a * (0.85 + 0.15 * sin(TIME * 2.6)));
	float flicker = 0.75 + 0.25 * sin(TIME * 9.0) * sin(TIME * 5.3);
	over(col, a, crack_color.rgb, crack_color.a * smoothstep(0.3, 0.7, tri(cracks, p, onorm)) * flicker);
	// A boss getting back up: a bar of light climbing it.
	over(col, a, sweep.rgb, sweep.a * smoothstep(0.24, 0.0, abs(height - sweep_at)));
	ALBEDO = col;
	ALPHA = a;
}
"""

## The twin a creature that Splits wears: every mesh of the body drawn once more, stood to
## one side, see-through and lit at its edges.
const TWIN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, world_vertex_coords;
uniform vec3 shift = vec3(0.0);
uniform vec4 color : source_color = vec4(0.82, 0.72, 1.0, 0.5);
uniform float apart = 0.0;
uniform float show = 0.0;
void vertex() {
	VERTEX += shift * apart;
}
void fragment() {
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	ALBEDO = color.rgb * (0.7 + 1.1 * edge);
	ALPHA = color.a * show * smoothstep(0.03, 0.5, apart) * (0.45 + 0.55 * edge);
}
"""

static var _shader: Shader = null
static var _twin_shader: Shader = null
static var _cracks_texture: ImageTexture = null
static var _stone_texture: ImageTexture = null
static var _seams_texture: ImageTexture = null
static var _x_texture: ImageTexture = null
static var _star_texture: ImageTexture = null
static var _chain_material: StandardMaterial3D = null
static var _thorn_material: StandardMaterial3D = null
static var _glass_material: StandardMaterial3D = null
static var _iron_material: StandardMaterial3D = null
static var _rock_material: StandardMaterial3D = null
static var _tongue: QuadMesh = null
static var _flame_ramp: GradientTexture1D = null
static var _halo_ring: ArrayMesh = null
static var _halo_broken: ArrayMesh = null
static var _wave_ring: ArrayMesh = null

var creature: Node3D
var _body: Node3D
var _meshes: Array = []
var _overlay: ShaderMaterial
## Whether the overlay is on the body's meshes now, and whether anything in it is still
## easing: it is only handed its numbers while something moves.
var _laid: bool = false
var _settling: bool = false
var _clock: float = 0.0
## What is asked of it (the statuses as they stand) and where each look has eased to.
var _want: Dictionary = {}
var _tint_want: Color = Color(0, 0, 0, 0)
var _tint_now: Color = Color(0, 0, 0, 0)
var _crack_want: float = 0.0
var _crack_now: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
## The body's size, in its own units: how tall it stands and how far it reaches sideways.
var _tall: float = 1.0
var _half: Vector2 = Vector2(0.4, 0.4)
var _centre_y: float = 0.5
var _sized: bool = false
## Slump (stun, fallen) and bulk (strength), read by the creature when it lays its body
## each frame. `_rise_cap` is how much taller it may grow (see HEAD_ROOM).
var slump: float = 0.0
var bulk: float = 1.0
var _bulk_pulse: float = 0.0
var _rise_cap: float = 1.1
## The looks that are meshes and particles of their own.
var _embers: GPUParticles3D = null
var _underglow: MeshInstance3D = null
var _underglow_material: StandardMaterial3D = null
var _ember_light: OmniLight3D = null
var _drips: GPUParticles3D = null
var _motes: GPUParticles3D = null
var _chains: Node3D = null
var _chain_loops: Array = []
var _mark: MeshInstance3D = null
var _mark_material: StandardMaterial3D = null
var _stars: Node3D = null
var _star_material: StandardMaterial3D = null
var _thorns: Node3D = null
var _thorn_count: int = 0
## Ward: the ring over its head, the light round it, and the broken ring it leaves as it
## pops. `_ward_now` is under nothing while the pieces fly, so the next ring waits for them.
var _ward: Node3D = null
var _ward_ring: MeshInstance3D = null
var _ward_material: StandardMaterial3D = null
var _ward_glow: MeshInstance3D = null
var _ward_glow_material: StandardMaterial3D = null
var _ward_burst: MeshInstance3D = null
var _ward_burst_material: StandardMaterial3D = null
var _ward_reach: float = 0.3
var _tag_at: float = INF
var _ward_want: float = 0.0
var _ward_now: float = 0.0
var _ward_pop: float = 0.0
## The named traits it has (`set_traits`), whether it is a fallen boss, and whether the
## looks have been laid for them yet.
var _traits: Array = []
var _fallen: bool = false
var _traits_stale: bool = false
## The three bands of the overlay, floor to head: tint, seams and stone, wanted and now.
var _band_want: Array = [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
var _band_now: Array = [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
var _seam_want: Array = [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
var _seam_now: Array = [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
var _crust_want: Vector3 = Vector3.ZERO
var _crust_now: Vector3 = Vector3.ZERO
## How brightly its trait looks burn: dimmed while it is fallen.
var _lit_want: float = 1.0
var _lit_now: float = 1.0
## Each built trait's own nodes, by trait; the ones grown out of the body hang under
## `_follow`, which is moved with the body as it swells, slumps and leans.
var _looks: Dictionary = {}
var _follow: Node3D = null
var _rest_inverse: Transform3D = Transform3D.IDENTITY
var _rest_y: float = 0.0
## Whether the body is down under the floor (burrowed, or not yet risen): what a trait
## throws off the body is put away while it is.
var _sunk: bool = false
var _surface: PackedVector3Array = PackedVector3Array()
var _core: PackedVector3Array = PackedVector3Array()
var _core_box: AABB = AABB()
## The light a trait throws on the floor under it.
var _aura: MeshInstance3D = null
var _aura_material: StandardMaterial3D = null
var _aura_light: OmniLight3D = null
var _aura_want: float = 0.0
## The twin of a creature that Splits.
var _twin: ShaderMaterial = null
var _twin_want: float = 0.0
var _twin_now: float = 0.0
## A boss getting up: how far up the body the bar of light has climbed (under 0: none).
var _sweep: float = -1.0
var _sweep_color: Color = Color.WHITE
## What was last asked for, and whether the looks have been built for it yet: nothing is
## built until the creature stands in the room, so every look is measured against the body
## as it really stands.
var _block_ratio: float = 0.0
var _dirty: bool = false

func _init(owner: Node3D, body: Node3D) -> void:
	creature = owner
	_body = body
	name = "Wear"

func _ready() -> void:
	set_process(true)

# --- what is asked ---------------------------------------------------------------------------

func sync(statuses: Dictionary, block_ratio: float = 0.0) -> void:
	## The statuses on the creature as the rules say they stand. Called whenever the fight is
	## drawn; every look eases toward it. Built once the creature stands in the room (see
	## `_dirty`). `block_ratio` is kept for the callers that still pass it: block wears
	## nothing on the body now.
	_want = statuses
	_block_ratio = block_ratio
	_dirty = true
	if is_inside_tree():
		_apply()

func set_traits(keys: Array, fallen: bool = false) -> void:
	## The named traits it has right now (`DeepCreatures.named_traits`), and whether it is a
	## boss down on its last point waiting to get back up. Called whenever the fight is drawn,
	## like `sync`: nothing happens unless something changed. A trait's look grows in when it
	## is gained, goes when it leaves the list and stands beside the others'.
	if fallen == _fallen and keys == _traits:
		return
	_traits = keys.duplicate()
	_fallen = fallen
	_traits_stale = true
	_dirty = true
	if is_inside_tree():
		_apply()

static func trait_color(key: String) -> Color:
	## The color a named trait is drawn in: its look here, its chip, its light.
	return TRAIT_COLORS.get(key, Color("c8c8d4"))

func _apply() -> void:
	_dirty = false
	var statuses: Dictionary = _want
	_measure()
	var poison: int = int(statuses.get("poison", 0))
	var stun: int = int(statuses.get("stun", 0))
	var strength: int = int(statuses.get("strength", 0))
	## Grey and still outranks the green: a stunned creature reads as stunned first.
	if stun > 0:
		_tint_want = STUNNED
	elif _fallen:
		_tint_want = FALLEN
	elif poison > 0:
		_tint_want = Color(POISON, 0.22 + 0.33 * clampf(float(poison) / 6.0, 0.0, 1.0))
	else:
		_tint_want = Color(_tint_want, 0.0)
	_crack_want = 0.0 if strength <= 0 else 0.55 + 0.35 * clampf(float(strength) / 4.0, 0.0, 1.0)
	## A Wrathful one is swollen before it has any Strength, and swells further with it.
	if _traits.has("wrathful"):
		bulk = 1.05 + 0.025 * float(clampi(strength, 0, 8))
	else:
		bulk = 1.0 + 0.03 * float(clampi(strength, 0, 5))
	slump = 1.0 if stun > 0 or _fallen else 0.0
	_sync_embers(int(statuses.get("burn", 0)))
	_sync_drips(poison)
	_sync_motes(int(statuses.get("regeneration", 0)))
	_sync_chains(int(statuses.get("curse", 0)))
	_sync_mark(int(statuses.get("marked", 0)))
	_sync_stars(stun)
	_sync_thorns(int(statuses.get("spikes", 0)))
	_ward_want = 1.0 if int(statuses.get("ward", 0)) > 0 else 0.0
	if _ward_want > 0.0:
		_ensure_ward()
	if _traits_stale:
		_lay_traits()
	if _overlay != null or _tint_want.a > 0.0 or _crack_want > 0.0 or not _traits.is_empty():
		_ensure_overlay()
		_place_overlay()
		_settling = true

func tick_flash(kind: String) -> void:
	## The beat at a tick: the whole body flashes the poison's green (or the burn's orange).
	_flash_color = Color("e4ffb0") if kind == "poison" else Color("ffd0a0")
	_flash = 1.0
	_ensure_overlay()
	_settling = true

func bulk_up() -> void:
	## Gaining Strength: it swells for a moment and settles a little bigger.
	_bulk_pulse = 1.0

func pop_ward() -> void:
	## The ring flashes and breaks apart as it takes a debuff for the creature; the next one
	## fades in once the pieces have gone, if Ward is left.
	if _ward == null:
		return
	_ward_now = -0.5
	_ward_pop = 1.0
	_ward.visible = true
	_ward_burst.rotation.y = _ward_ring.rotation.y

func rise_burst(color: Color) -> void:
	## A boss getting back up: a ring thrown out across the floor from its feet, a bar of
	## light climbing its body and sparks going up with it, in `color`. All of it frees
	## itself, seen or not.
	if not is_inside_tree():
		return
	_measure()
	var reach: float = maxf(_half.x, _half.y)
	if _wave_ring == null:
		_wave_ring = Lowpoly.ring(1.0, 0.22, 24)
	var ring := MeshInstance3D.new()
	ring.mesh = _wave_ring
	var look := _soft(color.lightened(0.25))
	look.albedo_color.a = 0.9
	ring.material_override = look
	ring.position = Vector3(0, 0.09, 0)
	ring.scale = Vector3.ONE * reach * 0.6
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var wave := ring.create_tween().set_parallel(true)
	wave.tween_property(ring, "scale", Vector3.ONE * (reach * 3.4 + 0.8), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wave.tween_property(look, "albedo_color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wave.chain().tween_callback(ring.queue_free)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 0.9, _tall * 0.2, _half.y * 0.9)
	m.direction = Vector3.UP
	m.spread = 8.0
	m.initial_velocity_min = 1.4 * _tall
	m.initial_velocity_max = 2.6 * _tall
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = 0.04 * _span()
	m.scale_max = 0.09 * _span()
	m.scale_curve = BattleFx.shrink_curve()
	m.color_ramp = BattleFx.burst_ramp(color)
	var sparks := GPUParticles3D.new()
	sparks.process_material = BattleFx.keep("wear_rise", m)
	sparks.draw_pass_1 = BattleFx.quad(true)
	sparks.amount = 28
	sparks.lifetime = 0.8
	sparks.one_shot = true
	sparks.explosiveness = 0.85
	sparks.local_coords = true
	sparks.position = Vector3(0, _tall * 0.25, 0)
	sparks.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	add_child(sparks)
	## Off camera a one-shot never says it has finished: the clock frees it.
	var done := sparks.create_tween()
	done.tween_interval(1.4)
	done.tween_callback(sparks.queue_free)
	_sweep = 0.0
	_sweep_color = color.lightened(0.5)
	_ensure_overlay()
	_place_overlay()
	_settling = true

func centre_local() -> Vector3:
	_measure()
	return Vector3(0, _centre_y, 0)

# --- each frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if _dirty and is_inside_tree():
		_apply()
	_flash = move_toward(_flash, 0.0, delta * 4.5)
	_bulk_pulse = move_toward(_bulk_pulse, 0.0, delta * 2.2)
	if _overlay != null:
		_ease_overlay(delta)
	if not _looks.is_empty():
		if _follow != null:
			_follow.transform = _body.transform * _rest_inverse
		var sunk: bool = _body.position.y < _rest_y - 0.5 * _tall
		if sunk != _sunk:
			_sunk = sunk
			for look in _looks.values():
				(look as Node3D).visible = not sunk
	if _underglow_material != null:
		var want: float = 0.55 + 0.25 * sin(_clock * 4.0) if _embers != null and _embers.emitting else 0.0
		_underglow_material.albedo_color.a = move_toward(_underglow_material.albedo_color.a, want, delta * 2.0)
		_underglow.visible = _underglow_material.albedo_color.a > 0.01
		if _ember_light != null:
			_ember_light.light_energy = _underglow_material.albedo_color.a * 1.2
	if _aura != null:
		var glow: float = 0.0 if _sunk else _aura_want * _lit_now * (0.85 + 0.15 * sin(_clock * 2.3))
		_aura_material.albedo_color.a = move_toward(_aura_material.albedo_color.a, glow, delta * 1.5)
		_aura.visible = _aura_material.albedo_color.a > 0.01
		_aura_light.light_energy = _aura_material.albedo_color.a * 3.2
		_aura_light.visible = _aura.visible
	if _twin != null:
		_twin_now = move_toward(_twin_now, _twin_want * _lit_now, delta * 1.2)
		## A slow breath: out to the side, held there a moment, and back into the body.
		_twin.set_shader_parameter("apart", smoothstep(-0.35, 0.75, sin(_clock * 1.05)))
		_twin.set_shader_parameter("show", _twin_now)
		if _twin_now <= 0.0 and _twin_want <= 0.0:
			_overlay.next_pass = null
			_twin = null
			_settling = true
	if _chains != null:
		for i in range(_chain_loops.size()):
			var loop: Node3D = _chain_loops[i]
			loop.rotation.y += delta * (0.35 if i % 2 == 0 else -0.28)
	if _mark_material != null:
		var want_mark: float = 0.85 if int(_want.get("marked", 0)) > 0 else 0.0
		var flick: float = 0.7 + 0.3 * sin(_clock * 11.0) * sin(_clock * 6.7)
		_mark_material.albedo_color.a = move_toward(_mark_material.albedo_color.a, want_mark * flick, delta * 4.0)
		_mark.visible = _mark_material.albedo_color.a > 0.01
	if _stars != null:
		var want_stars: float = 1.0 if int(_want.get("stun", 0)) > 0 else 0.0
		_star_material.albedo_color.a = move_toward(_star_material.albedo_color.a, want_stars, delta * 3.0)
		_stars.visible = _star_material.albedo_color.a > 0.01
		for i in range(_stars.get_child_count()):
			var star: Node3D = _stars.get_child(i)
			var angle: float = _clock * 1.6 + TAU * float(i) / float(maxi(1, _stars.get_child_count()))
			star.position = Vector3(cos(angle) * _half.x * 0.9, _tall + 0.25 + 0.06 * sin(_clock * 3.0 + float(i)), sin(angle) * _half.y * 0.9)
	if _ward != null and (_ward.visible or _ward_want > 0.0):
		_ward_now = move_toward(_ward_now, _ward_want, delta * 2.5)
		_ward_pop = move_toward(_ward_pop, 0.0, delta * 2.6)
		var shown: float = maxf(0.0, _ward_now) * (0.82 + 0.12 * sin(_clock * 2.2))
		_ward_material.albedo_color.a = shown
		_ward_ring.visible = shown > 0.01
		_ward_ring.rotation.y += delta * 0.6
		_ward_glow_material.albedo_color.a = shown * 0.3 + _ward_pop * _ward_pop * 0.7
		_ward_glow.visible = _ward_glow_material.albedo_color.a > 0.01
		## The broken ring flies outward and fades as it goes.
		_ward_burst.visible = _ward_pop > 0.0
		if _ward_burst.visible:
			_ward_burst.scale = Vector3.ONE * _ward_reach * (1.0 + 1.1 * (1.0 - _ward_pop * _ward_pop))
			_ward_burst_material.albedo_color.a = _ward_pop
		## It keeps over the head as the body swells and slumps.
		_ward.position.y = _ward_height()
		_ward.visible = _ward_ring.visible or _ward_glow.visible or _ward_burst.visible

func _bulk_now() -> float:
	## The body's size now: its settled bulk and the swell of a gain on top.
	return bulk + 0.18 * sin(_bulk_pulse * PI) * _bulk_pulse

func bulk_scale() -> Vector3:
	## How the body is scaled for its bulk: as wide as it has swollen, and no taller than its
	## head room allows, so a tall Warden's head stays under its tag and on the screen.
	var wide: float = _bulk_now()
	return Vector3(wide, minf(wide, _rise_cap), wide)

# --- the overlay: tints, seams, stone and cracks ----------------------------------------------

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY_SHADER
	_overlay = ShaderMaterial.new()
	_overlay.shader = _shader
	_overlay.set_shader_parameter("cracks", _cracks())
	_meshes = _body.find_children("*", "GeometryInstance3D", true, false)

func _place_overlay() -> void:
	## Where the creature stands and how big, for the bands up its body and its masks' size.
	var size: Vector3 = creature.global_basis.get_scale()
	_overlay.set_shader_parameter("tex_scale", 1.1 / maxf(0.5, _tall * size.y))
	_overlay.set_shader_parameter("foot", creature.global_position.y)
	_overlay.set_shader_parameter("tall", maxf(0.2, _tall * size.y))
	if _twin != null:
		## Half a step to one side.
		_twin.set_shader_parameter("shift", creature.global_basis.x.normalized() * _half.x * size.x * 0.38)

func _ease_overlay(delta: float) -> void:
	## Every tint eases toward what is wanted, and the material is handed the new numbers
	## only while one of them is still moving.
	if _sweep >= 0.0:
		_sweep += delta * 2.4
		if _sweep > 1.4:
			_sweep = -1.0
		_settling = true
	if not _settling and _flash <= 0.0:
		return
	var step: float = clampf(delta * 3.0, 0.0, 1.0)
	var moving: bool = _flash > 0.0 or _sweep >= 0.0
	_tint_now = _toward(_tint_now, _tint_want, step)
	_crack_now = move_toward(lerpf(_crack_now, _crack_want, step), _crack_want, 0.002)
	_lit_now = move_toward(lerpf(_lit_now, _lit_want, step), _lit_want, 0.002)
	_crust_now = _crust_now.lerp(_crust_want, step) if _crust_now.distance_squared_to(_crust_want) > 0.00001 else _crust_want
	moving = moving or _tint_now != _tint_want or _crack_now != _crack_want or _lit_now != _lit_want or _crust_now != _crust_want
	var worn: float = 0.0
	for i in range(3):
		_band_now[i] = _toward(_band_now[i], _band_want[i], step)
		_seam_now[i] = _toward(_seam_now[i], _seam_want[i], step)
		moving = moving or _band_now[i] != _band_want[i] or _seam_now[i] != _seam_want[i]
		worn = maxf(worn, maxf(_band_now[i].a, _seam_now[i].a))
	var shown: Color = _tint_now
	if _flash > 0.0:
		shown = shown.lerp(Color(_flash_color, 0.9), _flash)
	_overlay.set_shader_parameter("tint", shown)
	_overlay.set_shader_parameter("crack_color", Color(STRENGTH.lightened(0.1), _crack_now))
	_overlay.set_shader_parameter("band_a", _band_now[0])
	_overlay.set_shader_parameter("band_b", _band_now[1])
	_overlay.set_shader_parameter("band_c", _band_now[2])
	_overlay.set_shader_parameter("seam_a", _seam_now[0])
	_overlay.set_shader_parameter("seam_b", _seam_now[1])
	_overlay.set_shader_parameter("seam_c", _seam_now[2])
	_overlay.set_shader_parameter("crust", _crust_now)
	_overlay.set_shader_parameter("lit", _lit_now)
	_overlay.set_shader_parameter("sweep", Color(_sweep_color, 0.0 if _sweep < 0.0 else 0.85 * clampf((1.4 - _sweep) * 4.0, 0.0, 1.0)))
	_overlay.set_shader_parameter("sweep_at", _sweep)
	_settling = moving
	## Laid on the body only while there is something of it to see.
	var lay: bool = shown.a >= 0.01 or _crack_now >= 0.01 or worn >= 0.01 or _sweep >= 0.0 or _twin != null
	if lay != _laid:
		_laid = lay
		for mesh in _meshes:
			if is_instance_valid(mesh):
				(mesh as GeometryInstance3D).material_overlay = _overlay if lay else null

static func _toward(now: Color, want: Color, step: float) -> Color:
	## A tint eased toward another. One that is not showing takes the new color at once, so
	## a look fades in in its own color and not up out of black.
	if now.a < 0.004:
		now = Color(want, now.a)
	var eased: Color = now.lerp(want, step)
	if absf(eased.r - want.r) + absf(eased.g - want.g) + absf(eased.b - want.b) + absf(eased.a - want.a) < 0.006:
		return want
	return eased

static func _cracks() -> ImageTexture:
	## Heat cracks: a few jagged bright lines on black, tiling.
	if _cracks_texture != null:
		return _cracks_texture
	var size: int = 128
	var image := Image.create(size, size, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for line in range(9):
		var x: float = rng.randf_range(0.0, float(size))
		var y: float = rng.randf_range(0.0, float(size))
		var heading: float = rng.randf_range(0.0, TAU)
		for step in range(26):
			heading += rng.randf_range(-0.9, 0.9)
			x += cos(heading) * 4.0
			y += sin(heading) * 4.0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var px: int = posmod(int(x) + dx, size)
					var py: int = posmod(int(y) + dy, size)
					var bright: float = 1.0 if dx == 0 and dy == 0 else 0.55
					image.set_pixel(px, py, Color(maxf(image.get_pixel(px, py).r, bright), 0, 0))
	_cracks_texture = ImageTexture.create_from_image(image)
	return _cracks_texture

static func _seams() -> ImageTexture:
	## A trait's seams: long cracks in straight runs with sharp turns, branching, unbroken
	## (the Strength cracks above are dotted), tiling.
	if _seams_texture != null:
		return _seams_texture
	var size: int = 160
	var image := Image.create(size, size, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	## Each run: where it starts, its heading, how long, how bright.
	var runs: Array = []
	for crack in range(9):
		var at := Vector2(rng.randf_range(0.0, float(size)), rng.randf_range(0.0, float(size)))
		var heading: float = rng.randf_range(0.0, TAU)
		for run in range(rng.randi_range(4, 7)):
			var length: float = rng.randf_range(9.0, 24.0)
			runs.append([at, heading, length, 1.0])
			at += Vector2.from_angle(heading) * length
			if rng.randf() < 0.4:
				runs.append([at, heading + rng.randf_range(0.7, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(5.0, 12.0), 0.8])
			heading += rng.randf_range(0.45, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	for run in runs:
		var from: Vector2 = run[0]
		var along: Vector2 = Vector2.from_angle(float(run[1]))
		for step in range(int(float(run[2])) + 1):
			var at: Vector2 = from + along * float(step)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var px: int = posmod(int(at.x) + dx, size)
					var py: int = posmod(int(at.y) + dy, size)
					var bright: float = float(run[3]) * (1.0 if dx == 0 and dy == 0 else (0.6 if dx == 0 or dy == 0 else 0.35))
					image.set_pixel(px, py, Color(maxf(image.get_pixel(px, py).r, bright), 0, 0))
	_seams_texture = ImageTexture.create_from_image(image)
	return _seams_texture

static func _stone() -> ImageTexture:
	## Plates of stone, tiling: in red how light each plate is, in green how far a point is
	## from the gap between two plates. Small, and sharpened where it is read.
	if _stone_texture != null:
		return _stone_texture
	var size: int = 56
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var seeds: PackedVector2Array = PackedVector2Array()
	var shades: PackedFloat32Array = PackedFloat32Array()
	for i in range(11):
		seeds.append(Vector2(rng.randf(), rng.randf()))
		shades.append(rng.randf())
	## One plate in eleven is left off, so the body shows through the crust.
	shades[2] = 0.0
	var image := Image.create(size, size, false, Image.FORMAT_RG8)
	for px in range(size):
		for py in range(size):
			var u: float = (float(px) + 0.5) / float(size)
			var v: float = (float(py) + 0.5) / float(size)
			var nearest: float = 9.0
			var second: float = 9.0
			var shade: float = 0.0
			for i in range(seeds.size()):
				var dx: float = absf(u - seeds[i].x)
				var dy: float = absf(v - seeds[i].y)
				dx = minf(dx, 1.0 - dx)
				dy = minf(dy, 1.0 - dy)
				var d: float = dx * dx + dy * dy
				if d < nearest:
					second = nearest
					nearest = d
					shade = shades[i]
				elif d < second:
					second = d
			image.set_pixel(px, py, Color(shade, clampf((sqrt(second) - sqrt(nearest)) * 5.0, 0.0, 1.0), 0))
	_stone_texture = ImageTexture.create_from_image(image)
	return _stone_texture

static func _x_mark() -> ImageTexture:
	if _x_texture != null:
		return _x_texture
	var size: int = 96
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for px in range(size):
		for py in range(size):
			var u: float = float(px) / float(size) - 0.5
			var v: float = float(py) / float(size) - 0.5
			var d: float = minf(absf(u - v), absf(u + v))
			var edge: float = clampf(1.0 - (d - 0.03) / 0.05, 0.0, 1.0)
			var inside: float = clampf(1.0 - (maxf(absf(u), absf(v)) - 0.38) / 0.06, 0.0, 1.0)
			image.set_pixel(px, py, Color(1, 1, 1, edge * inside))
	_x_texture = ImageTexture.create_from_image(image)
	return _x_texture

static func _star() -> ImageTexture:
	if _star_texture != null:
		return _star_texture
	var size: int = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var centre := Vector2(0.5, 0.5)
	for px in range(size):
		for py in range(size):
			var at := Vector2(float(px) / float(size), float(py) / float(size)) - centre
			var angle: float = atan2(at.y, at.x)
			var reach: float = 0.22 + 0.24 * pow(maxf(0.0, cos(angle * 2.5)), 6.0)
			var a: float = clampf(1.0 - (at.length() - reach) / 0.05, 0.0, 1.0)
			image.set_pixel(px, py, Color(1, 1, 1, a))
	_star_texture = ImageTexture.create_from_image(image)
	return _star_texture

func _measure() -> void:
	## How big the body is, from its meshes, once they stand in the room.
	if _sized or _body == null:
		return
	var box: AABB = AABB()
	var found: bool = false
	## Against the body as it rests, not as it is now: as a creature spawns its body rises
	## out of the floor and swells, and a look measured then would sit under the room.
	var rest: Transform3D = creature.get("_body_rest") if creature.get("_body_rest") is Transform3D else _body.transform
	var from_body: Transform3D = _body.global_transform.affine_inverse()
	for mesh in _body.find_children("*", "GeometryInstance3D", true, false):
		var shape: GeometryInstance3D = mesh
		var local: AABB = shape.get_aabb()
		var to_creature: Transform3D = rest * (from_body * shape.global_transform)
		var corners: Array = []
		for i in range(8):
			corners.append(to_creature * local.get_endpoint(i))
		for corner in corners:
			if not found:
				box = AABB(corner, Vector3.ZERO)
				found = true
			else:
				box = box.expand(corner)
	if not found or box.size.y < 0.05:
		var tall: float = float(creature.call("_own_height")) if creature.has_method("_own_height") else 1.0
		box = AABB(Vector3(-tall * 0.35, 0, -tall * 0.35), Vector3(tall * 0.7, tall, tall * 0.7))
	_tall = maxf(0.4, box.end.y)
	_half = Vector2(maxf(0.15, box.size.x * 0.5), maxf(0.15, box.size.z * 0.5))
	_centre_y = box.position.y + box.size.y * 0.5
	_rest_inverse = rest.affine_inverse()
	_rest_y = rest.origin.y
	## The taller it stands in the room, the smaller the share of its height it may gain.
	_rise_cap = 1.0 + HEAD_ROOM / maxf(0.3, _tall * creature.scale.y)
	_sized = is_inside_tree()

func _span() -> float:
	## One size for the body, tall or wide: what its blades, flames and motes are sized by.
	return sqrt(_tall * 2.0 * maxf(_half.x, _half.y))

static func _soft(color: Color, additive: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color, 0.0)
	return m

# --- burn: embers and underglow ----------------------------------------------------------------

func _sync_embers(burn: int) -> void:
	if burn <= 0 and _embers == null:
		return
	if _embers == null:
		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(_half.x * 0.9, 0.08, _half.y * 0.9)
		m.direction = Vector3.UP
		m.spread = 18.0
		m.initial_velocity_min = 0.25 * _tall
		m.initial_velocity_max = 0.55 * _tall
		m.gravity = Vector3(0, 0.3 * _tall, 0)
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 0.6
		m.scale_min = 0.02 * _tall
		m.scale_max = 0.05 * _tall
		m.scale_curve = BattleFx.shrink_curve()
		m.color_ramp = BattleFx.fade_ramp(Color("ff9a3a"), 1.0, 0.3)
		_embers = GPUParticles3D.new()
		_embers.process_material = BattleFx.keep("wear_ember", m)
		_embers.draw_pass_1 = BattleFx.quad(true)
		_embers.amount = 26
		_embers.lifetime = 1.7
		_embers.local_coords = true
		_embers.position = Vector3(0, 0.1, 0)
		_embers.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
		add_child(_embers)
		_underglow = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * maxf(_half.x, _half.y) * 3.2
		quad.orientation = PlaneMesh.FACE_Y
		_underglow.mesh = quad
		_underglow_material = _soft(BURN)
		_underglow_material.albedo_texture = DeepUi.glow_texture()
		_underglow.material_override = _underglow_material
		_underglow.position = Vector3(0, 0.07, 0)
		_underglow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_underglow)
		_ember_light = OmniLight3D.new()
		_ember_light.light_color = BURN
		_ember_light.omni_range = maxf(_half.x, _half.y) * 3.0
		_ember_light.light_energy = 0.0
		_ember_light.shadow_enabled = false
		_ember_light.position = Vector3(0, 0.2, 0)
		add_child(_ember_light)
	_embers.emitting = burn > 0
	_embers.amount_ratio = clampf(0.4 + 0.15 * float(burn), 0.4, 1.0)

# --- poison drips, regeneration motes ---------------------------------------------------------

func _sync_drips(poison: int) -> void:
	if poison <= 0 and _drips == null:
		return
	if _drips == null:
		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(_half.x * 0.8, _tall * 0.3, _half.y * 0.8)
		m.direction = Vector3.DOWN
		m.spread = 4.0
		m.initial_velocity_min = 0.1
		m.initial_velocity_max = 0.3
		m.gravity = Vector3(0, -1.2 * _tall, 0)
		m.scale_min = 0.03 * _tall
		m.scale_max = 0.05 * _tall
		m.color_ramp = BattleFx.fade_ramp(POISON, 1.0, 0.5)
		_drips = GPUParticles3D.new()
		_drips.process_material = BattleFx.keep("wear_drip", m)
		_drips.draw_pass_1 = BattleFx.quad(false)
		_drips.amount = 10
		_drips.lifetime = 1.1
		_drips.local_coords = true
		_drips.position = Vector3(0, _tall * 0.55, 0)
		_drips.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
		add_child(_drips)
	_drips.emitting = poison > 0
	_drips.amount_ratio = clampf(0.3 + 0.12 * float(poison), 0.3, 1.0)

func _sync_motes(regeneration: int) -> void:
	if regeneration <= 0 and _motes == null:
		return
	if _motes == null:
		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(_half.x * 1.1, 0.1, _half.y * 1.1)
		m.direction = Vector3.UP
		m.spread = 10.0
		m.initial_velocity_min = 0.2 * _tall
		m.initial_velocity_max = 0.4 * _tall
		m.gravity = Vector3(0, 0.15 * _tall, 0)
		m.scale_min = 0.025 * _tall
		m.scale_max = 0.055 * _tall
		m.scale_curve = BattleFx.shrink_curve()
		m.color_ramp = BattleFx.fade_ramp(REGEN, 1.0, 0.4)
		_motes = GPUParticles3D.new()
		_motes.process_material = BattleFx.keep("wear_mote", m)
		_motes.draw_pass_1 = BattleFx.quad(true)
		_motes.amount = 16
		_motes.lifetime = 2.0
		_motes.local_coords = true
		_motes.position = Vector3(0, 0.15, 0)
		_motes.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
		add_child(_motes)
	_motes.emitting = regeneration > 0

# --- curse: chain loops ----------------------------------------------------------------------

func _sync_chains(curse: int) -> void:
	var loops: int = clampi(curse, 0, 3)
	if loops <= 0 and _chains == null:
		return
	if _chains == null:
		_chains = Node3D.new()
		add_child(_chains)
	while _chain_loops.size() < loops:
		var index: int = _chain_loops.size()
		var loop := Node3D.new()
		var rx: float = _half.x * 1.12 + 0.06
		var rz: float = _half.y * 1.12 + 0.06
		var links: int = clampi(int((rx + rz) / maxf(0.05, 0.05 * _tall)), 10, 26)
		for i in range(links):
			var angle: float = TAU * float(i) / float(links)
			var link := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.012 * _tall
			torus.outer_radius = 0.03 * _tall
			torus.rings = 10
			torus.ring_segments = 6
			link.mesh = torus
			link.material_override = _chain_look()
			link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			link.position = Vector3(cos(angle) * rx, 0, sin(angle) * rz)
			## Links lie flat and stand up by turns, the way a chain hangs.
			link.rotation = Vector3(PI * 0.5 if i % 2 == 0 else 0.0, -angle, 0.0)
			loop.add_child(link)
		loop.position = Vector3(0, _tall * (0.3 + 0.2 * float(index)), 0)
		loop.rotation.x = 0.14 * (1.0 if index % 2 == 0 else -1.0)
		loop.scale = Vector3.ONE * 0.01
		_chains.add_child(loop)
		_chain_loops.append(loop)
		var grow := loop.create_tween()
		grow.tween_property(loop, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	while _chain_loops.size() > loops:
		var gone: Node3D = _chain_loops.pop_back()
		var shrink := gone.create_tween()
		shrink.tween_property(gone, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_SINE)
		shrink.tween_callback(gone.queue_free)

static func _chain_look() -> StandardMaterial3D:
	if _chain_material == null:
		_chain_material = StandardMaterial3D.new()
		_chain_material.albedo_color = CURSE.darkened(0.35)
		_chain_material.metallic = 0.7
		_chain_material.roughness = 0.35
		_chain_material.emission_enabled = true
		_chain_material.emission = CURSE
		_chain_material.emission_energy_multiplier = 0.9
	return _chain_material

# --- marked: a red X scratched across the front -----------------------------------------------

func _sync_mark(marked: int) -> void:
	if marked <= 0 and _mark == null:
		return
	if _mark == null:
		_mark = MeshInstance3D.new()
		var quad := QuadMesh.new()
		var reach: float = maxf(_tall * 0.7, maxf(_half.x, _half.y) * 1.6)
		quad.size = Vector2.ONE * reach
		_mark.mesh = quad
		_mark_material = _soft(MARK)
		_mark_material.albedo_texture = _x_mark()
		_mark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.material_override = _mark_material
		_mark.position = Vector3(0, _centre_y, _half.y + 0.12)
		_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mark)

# --- stun: stars round its head ---------------------------------------------------------------

func _sync_stars(stun: int) -> void:
	if stun <= 0 and _stars == null:
		return
	if _stars == null:
		_stars = Node3D.new()
		_star_material = _soft(STUN)
		_star_material.albedo_texture = _star()
		_star_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		for i in range(3):
			var star := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * maxf(0.2, 0.09 * _tall)
			star.mesh = quad
			star.material_override = _star_material
			star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_stars.add_child(star)
		add_child(_stars)

# --- spikes: thorns ---------------------------------------------------------------------------

func _sync_thorns(spikes: int) -> void:
	var count: int = 0 if spikes <= 0 else clampi(3 + spikes, 4, 10)
	if count == _thorn_count:
		return
	if _thorns != null:
		_thorns.queue_free()
		_thorns = null
	_thorn_count = count
	if count <= 0:
		return
	_thorns = Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + 0.3
		var thorn := MeshInstance3D.new()
		thorn.mesh = Lowpoly.spike(rng, SPIKES, 4, 0.03 * _tall, 0.14 * _tall, 0.08, Color("e8ecf4"))
		thorn.material_override = _thorn_look()
		thorn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var out := Vector3(cos(angle) * _half.x, 0, sin(angle) * _half.y)
		var height: float = _tall * (0.35 + 0.3 * rng.randf())
		thorn.position = out * 0.85 + Vector3(0, height, 0)
		## The spike's own up turned to point out of the body.
		var dir: Vector3 = (out.normalized() + Vector3(0, 0.25, 0)).normalized()
		thorn.transform.basis = Basis(Quaternion(Vector3.UP, dir))
		thorn.scale = Vector3.ONE * 0.01
		_thorns.add_child(thorn)
		var grow := thorn.create_tween()
		grow.tween_property(thorn, "scale", Vector3.ONE, 0.3).set_delay(0.03 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	add_child(_thorns)

static func _thorn_look() -> StandardMaterial3D:
	if _thorn_material == null:
		_thorn_material = StandardMaterial3D.new()
		_thorn_material.vertex_color_use_as_albedo = true
		_thorn_material.roughness = 0.5
		_thorn_material.metallic = 0.4
	return _thorn_material

# --- ward: the ring over its head -------------------------------------------------------------

func _ensure_ward() -> void:
	## One thin faceted ring of light in the gap between its head and its tag, small enough
	## for that on a Warden and big enough to see on a rat: sized in the room's units, not
	## the creature's own.
	if _ward != null:
		return
	var own: float = 1.0 / maxf(0.01, creature.scale.y)
	_ward_reach = clampf(maxf(_half.x, _half.y) * creature.scale.x * 0.3, 0.17, 0.4) * own
	if _halo_ring == null:
		_halo_ring = _ring_of(12, 0.085, 0.0)
		_halo_broken = _ring_of(12, 0.085, 0.16)
	var marker := creature.get_node_or_null("Anchor") as Node3D
	if marker != null:
		_tag_at = marker.position.y
	if _tag_at < _tall:
		## Its head stands up into its tag, so the ring goes round the head: as wide as the
		## head is there, and no wider than a ring can be and still be a small thing.
		_ward_reach = clampf(_width_at(_ward_height()) * 1.12, _ward_reach, 1.0 * own)
	_ward = Node3D.new()
	## Tipped toward the party, so it is a ring to them and not a line.
	_ward.rotation.x = 0.3
	_ward_ring = MeshInstance3D.new()
	_ward_ring.mesh = _halo_ring
	## The ring itself is not additive: in an orange room that washed its blue out to white.
	_ward_material = _soft(WARD.lightened(0.45), false)
	_ward_ring.material_override = _ward_material
	_ward_ring.scale = Vector3.ONE * _ward_reach
	_ward_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward.add_child(_ward_ring)
	_ward_burst = MeshInstance3D.new()
	_ward_burst.mesh = _halo_broken
	_ward_burst_material = _soft(Color("d8e8ff"))
	_ward_burst.material_override = _ward_burst_material
	_ward_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward_burst.visible = false
	_ward.add_child(_ward_burst)
	_ward_glow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * _ward_reach * 2.8
	_ward_glow.mesh = quad
	_ward_glow_material = _soft(WARD)
	_ward_glow_material.albedo_texture = DeepUi.glow_texture()
	_ward_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ward_glow.material_override = _ward_glow_material
	_ward_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward.add_child(_ward_glow)
	_ward.position = Vector3(0, _ward_height(), 0)
	add_child(_ward)

func _ward_height() -> float:
	## Just over the head, wherever the head is now. A crown or horns that stand up past
	## where its tag hangs (its Anchor) would carry the ring up behind the tag: there it
	## rings them instead, just under the tag.
	var own: float = 1.0 / maxf(0.01, creature.scale.y)
	var head: float = _tall * minf(_bulk_now(), _rise_cap) * (1.0 - 0.07 * slump)
	if _tag_at < head:
		head = _tag_at - 0.2 * own
	return head + _ward_reach * 0.3 + 0.04 * own

func _width_at(level: float) -> float:
	## How far from its middle the body reaches at one height, going by the boxes round the
	## parts that stand there. The widest few are left out: a raised arm, a blade held up.
	var rest: Transform3D = _rest_inverse.affine_inverse()
	var from_body: Transform3D = _body.global_transform.affine_inverse()
	var reaches: PackedFloat32Array = PackedFloat32Array()
	for mesh in _body_meshes():
		var shape: GeometryInstance3D = mesh
		var local: AABB = shape.get_aabb()
		var to_creature: Transform3D = rest * (from_body * shape.global_transform)
		var low: float = INF
		var high: float = -INF
		var reach: float = 0.0
		for i in range(8):
			var corner: Vector3 = to_creature * local.get_endpoint(i)
			low = minf(low, corner.y)
			high = maxf(high, corner.y)
			reach += Vector2(corner.x, corner.z).length() / 8.0
		if low <= level and high >= level:
			reaches.append(reach)
	if reaches.is_empty():
		return 0.0
	reaches.sort()
	return reaches[int(float(reaches.size() - 1) * 0.8)]

static func _ring_of(sides: int, thick: float, broken: float) -> ArrayMesh:
	## A ring of radius one in the XZ plane with a diamond for its section, so it is seen
	## from any height. `broken` pulls every other pair of its sides out of line and leaves
	## gaps: the pieces of one that has burst.
	var surface := Lowpoly.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var pieces: int = sides / 2 if broken > 0.0 else 1
	var per: int = sides / pieces
	for piece in range(pieces):
		var push: float = broken * rng.randf_range(0.5, 1.5)
		var lift: float = broken * rng.randf_range(-1.0, 1.0)
		var turn: float = broken * rng.randf_range(-1.6, 1.6)
		var first: float = TAU * float(piece * per) / float(sides)
		var last: float = TAU * float((piece + 1) * per) / float(sides)
		if broken > 0.0:
			first += 0.09
			last -= 0.09
		var middle: float = (first + last) * 0.5
		var out := Vector3(cos(middle), 0, sin(middle))
		var basis := Basis(out, turn)
		for i in range(per):
			var a0: float = lerpf(first, last, float(i) / float(per))
			var a1: float = lerpf(first, last, float(i + 1) / float(per))
			var section: Array = []
			for angle in [a0, a1]:
				var spoke := Vector3(cos(angle), 0, sin(angle))
				for corner in [spoke * (1.0 + thick), spoke + Vector3(0, thick, 0), spoke * (1.0 - thick), spoke - Vector3(0, thick, 0)]:
					section.append(basis * (corner - out) + out * (1.0 + push) + Vector3(0, lift, 0))
			for k in range(4):
				var l: int = (k + 1) % 4
				Lowpoly.quad(surface, section[k], section[l], section[4 + l], section[4 + k], Color.WHITE)
	return surface.commit()

# --- named traits ----------------------------------------------------------------------------

func _lay_traits() -> void:
	## The looks for the traits it has now: the bands of the overlay, the built looks that
	## are new or gone, the light on the floor, and all of it dimmed if it is fallen.
	_traits_stale = false
	var bands: Array = BAND_ORDER.filter(func(key: String) -> bool: return _traits.has(key))
	if bands.size() > 3:
		bands.resize(3)
	for i in range(3):
		if bands.is_empty():
			_band_want[i] = Color(_band_want[i], 0.0)
			_seam_want[i] = Color(_seam_want[i], 0.0)
			_crust_want[i] = 0.0
		else:
			var look: Array = BANDS[bands[mini(i, bands.size() - 1)]]
			_band_want[i] = look[0]
			_seam_want[i] = look[1]
			_crust_want[i] = float(look[2])
	if bands.size() > 1 or _traits.has("sturdy"):
		_ensure_overlay()
		_overlay.set_shader_parameter("stone", _stone())
	if not bands.is_empty():
		_ensure_overlay()
		_overlay.set_shader_parameter("seams", _seams())
		_overlay.set_shader_parameter("cuts", Vector2(2.0, 2.0) if bands.size() == 1 else (Vector2(0.52, 2.0) if bands.size() == 2 else Vector2(0.36, 0.68)))
	for key in BUILT:
		if _traits.has(key) and not _looks.has(key):
			_looks[key] = _build(key)
		elif _looks.has(key) and not _traits.has(key):
			_shed(_looks[key])
			_looks.erase(key)
	## Splits: its twin, one more pass after the overlay.
	_twin_want = 1.0 if _traits.has("split_on_big_hit") else 0.0
	if _twin_want > 0.0 and _twin == null:
		_ensure_overlay()
		if _twin_shader == null:
			_twin_shader = Shader.new()
			_twin_shader.code = TWIN_SHADER
		_twin = ShaderMaterial.new()
		_twin.shader = _twin_shader
		_overlay.next_pass = _twin
	## The light on the floor: the lit traits' colors together, as strong as the strongest.
	var glow := Color(0, 0, 0, 0)
	var weight: float = 0.0
	_aura_want = 0.0
	for key in _traits:
		var share: float = float(AURA.get(key, 0.0))
		if share <= 0.0:
			continue
		var tone: Color = trait_color(key)
		glow = Color(glow.r + tone.r * share, glow.g + tone.g * share, glow.b + tone.b * share)
		weight += share
		_aura_want = maxf(_aura_want, share * 0.8)
	if weight > 0.0:
		_ensure_aura()
		var tone := Color(glow.r / weight, glow.g / weight, glow.b / weight)
		_aura_material.albedo_color = Color(tone, _aura_material.albedo_color.a)
		_aura_light.light_color = tone
	_lit_want = 0.25 if _fallen else 1.0
	for key in _looks:
		for child in (_looks[key] as Node3D).get_children():
			if child is GPUParticles3D:
				(child as GPUParticles3D).emitting = not _fallen

func _build(key: String) -> Node3D:
	## One trait's own meshes and particles, under one node so they go together.
	var look := Node3D.new()
	look.name = key.capitalize().replace(" ", "")
	match key:
		"molten":
			look.add_child(_flames())
			look.add_child(_cinders())
			add_child(look)
		"venomous":
			look.add_child(_mist())
			look.add_child(_venom())
			add_child(look)
		"wrathful":
			look.add_child(_steam())
			add_child(look)
		"leeching":
			look.add_child(_drawn_in())
			add_child(look)
		_:
			## Grown out of the body, so moved with it.
			if _follow == null:
				_follow = Node3D.new()
				_follow.name = "Follow"
				add_child(_follow)
			var grown := MeshInstance3D.new()
			match key:
				"jagged":
					grown.mesh = _blades()
					grown.material_override = _glass_look()
				"steadfast":
					grown.mesh = _bands()
					grown.material_override = _iron_look()
				"sturdy":
					grown.mesh = _boulders()
					grown.material_override = _rock_look()
			grown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			## Lit by the room's creature lights, as the body is.
			if not _body_meshes().is_empty():
				grown.layers = (_body_meshes()[0] as GeometryInstance3D).layers
			## It grows out from the middle of the body.
			var middle := Vector3(0, _centre_y, 0)
			grown.position = middle * 0.45
			grown.scale = Vector3.ONE * 0.55
			look.add_child(grown)
			_follow.add_child(look)
			var grow := grown.create_tween().set_parallel(true)
			grow.tween_property(grown, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			grow.tween_property(grown, "position", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return look

func _shed(look: Node3D) -> void:
	## A trait it no longer has: its particles stop and its meshes draw back into the body,
	## then the lot is freed.
	for child in look.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
		elif child is Node3D:
			var shrink := child.create_tween()
			shrink.tween_property(child, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_SINE)
	var gone := look.create_tween()
	gone.tween_interval(3.0)
	gone.tween_callback(look.queue_free)

func _body_meshes() -> Array:
	if _meshes.is_empty():
		_meshes = _body.find_children("*", "GeometryInstance3D", true, false)
	return _meshes

func _ensure_aura() -> void:
	if _aura != null:
		return
	var reach: float = maxf(_half.x, _half.y)
	_aura = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * reach * 4.2
	quad.orientation = PlaneMesh.FACE_Y
	_aura.mesh = quad
	_aura_material = _soft(Color.WHITE)
	_aura_material.albedo_texture = DeepUi.glow_texture()
	_aura.material_override = _aura_material
	_aura.position = Vector3(0, 0.065, 0)
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_aura_light = OmniLight3D.new()
	_aura_light.omni_range = reach * 4.0
	_aura_light.light_energy = 0.0
	_aura_light.shadow_enabled = false
	_aura_light.position = Vector3(0, _tall * 0.45, 0.3)
	add_child(_aura_light)

func _puffs(kind: String, m: ParticleProcessMaterial, amount: int, life: float, at: float, additive: bool = true) -> GPUParticles3D:
	## A trait's particles, standing with the creature at a share of its height.
	var p := GPUParticles3D.new()
	p.process_material = BattleFx.keep(kind, m)
	p.draw_pass_1 = BattleFx.quad(additive)
	p.amount = amount
	p.lifetime = life
	p.local_coords = true
	p.position = Vector3(0, _tall * at, 0)
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 14, 12))
	return p

# --- molten: flames and cinders ---------------------------------------------------------------

func _flames() -> GPUParticles3D:
	## Tongues of flame off its back and shoulders, hotter than a fire's so they show in a
	## room that is orange already.
	if _tongue == null:
		_tongue = QuadMesh.new()
		_tongue.size = Vector2(0.62, 1.0)
		var look := BattleFx.glow_material().duplicate() as StandardMaterial3D
		look.albedo_texture = BattleFx._tongue_texture()
		_tongue.material = look
		var gradient := Gradient.new()
		gradient.set_color(0, Color(2.2, 1.5, 0.5, 0.0))
		gradient.set_color(1, Color(0.4, 0.05, 0.02, 0.0))
		gradient.add_point(0.1, Color(2.1, 1.3, 0.35, 0.55))
		gradient.add_point(0.4, Color(1.8, 0.6, 0.1, 0.45))
		gradient.add_point(0.75, Color(1.0, 0.16, 0.03, 0.22))
		_flame_ramp = GradientTexture1D.new()
		_flame_ramp.use_hdr = true
		_flame_ramp.gradient = gradient
	var span: float = _span()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 0.7, _tall * 0.22, _half.y * 0.5)
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 0.15 * span
	m.initial_velocity_max = 0.4 * span
	m.gravity = Vector3(0, 0.5 * span, 0)
	m.damping_min = 0.3
	m.damping_max = 0.7
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.3
	m.turbulence_noise_scale = 1.4
	m.scale_min = 0.2 * span
	m.scale_max = 0.36 * span
	m.scale_curve = BattleFx.shrink_curve()
	m.color_ramp = _flame_ramp
	var p := _puffs("wear_flame", m, 64, 0.8, 0.5)
	p.draw_pass_1 = _tongue
	return p

func _cinders() -> GPUParticles3D:
	var span: float = _span()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 0.9, _tall * 0.3, _half.y * 0.9)
	m.direction = Vector3.UP
	m.spread = 20.0
	m.initial_velocity_min = 0.5 * span
	m.initial_velocity_max = 1.2 * span
	m.gravity = Vector3(0, 0.3 * span, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.0
	m.turbulence_noise_scale = 2.0
	m.scale_min = 0.025 * span
	m.scale_max = 0.06 * span
	m.scale_curve = BattleFx.shrink_curve()
	m.color_ramp = BattleFx.burst_ramp(Color("ffb040"))
	return _puffs("wear_cinder", m, 24, 1.6, 0.4)

# --- venomous: mist and drops -----------------------------------------------------------------

func _mist() -> GPUParticles3D:
	## A low pool of green mist round its feet, creeping outward.
	var span: float = _span()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 1.15, 0.03, _half.y * 1.0)
	m.direction = Vector3.UP
	m.spread = 180.0
	m.flatness = 1.0
	m.initial_velocity_min = 0.03 * span
	m.initial_velocity_max = 0.14 * span
	m.gravity = Vector3.ZERO
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.2
	m.scale_min = 0.45 * span
	m.scale_max = 0.8 * span
	m.scale_curve = BattleFx.swell_curve()
	m.color_ramp = BattleFx.fade_ramp(Color("8fe04a"), 0.2, 0.3)
	var p := _puffs("wear_mist", m, 18, 2.8, 0.0)
	p.position.y = 0.12 * span
	return p

func _venom() -> GPUParticles3D:
	## Heavy bright drops off the body: more and bigger than a poisoning's.
	var span: float = _span()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 0.85, _tall * 0.12, _half.y * 0.85)
	m.direction = Vector3.DOWN
	m.spread = 4.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.3
	m.gravity = Vector3(0, -1.6 * _tall, 0)
	m.scale_min = 0.04 * span
	m.scale_max = 0.075 * span
	m.color_ramp = BattleFx.fade_ramp(Color("c8ff7a"), 1.0, 0.15)
	return _puffs("wear_venom", m, 26, 0.9, 0.6)

# --- wrathful: steam --------------------------------------------------------------------------

func _steam() -> GPUParticles3D:
	var span: float = _span()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_half.x * 0.45, _tall * 0.08, _half.y * 0.45)
	m.direction = Vector3.UP
	m.spread = 14.0
	m.initial_velocity_min = 0.45 * span
	m.initial_velocity_max = 0.9 * span
	m.gravity = Vector3(0, 0.2 * span, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	m.scale_min = 0.16 * span
	m.scale_max = 0.34 * span
	m.scale_curve = BattleFx.swell_curve()
	m.color_ramp = BattleFx.fade_ramp(Color("ffd8d0"), 0.3, 0.2)
	return _puffs("wear_steam", m, 22, 1.3, 0.95)

# --- leeching: motes drawn in -----------------------------------------------------------------

func _drawn_in() -> GPUParticles3D:
	## Red motes that start in a ring out from the body and fall into it.
	var span: float = _span()
	var reach: float = maxf(_half.x, _half.y) * 1.25 + 0.3 * span
	var life: float = 1.2
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	m.emission_sphere_radius = reach
	m.emission_shape_scale = Vector3(1.0, clampf(_tall * 0.55 / reach, 0.3, 1.0), 0.7)
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.05
	m.gravity = Vector3.ZERO
	## Fast enough to reach the middle as it dies.
	m.radial_accel_min = -1.6 * reach / (life * life)
	m.radial_accel_max = -2.0 * reach / (life * life)
	m.scale_min = 0.04 * span
	m.scale_max = 0.085 * span
	m.scale_curve = BattleFx.swell_curve()
	m.color_ramp = BattleFx.fade_ramp(Color(1.6, 0.12, 0.22), 1.0, 0.25)
	return _puffs("wear_leech", m, 30, life, 0.5)

# --- the body's surface, for what grows out of it ---------------------------------------------

func _read_body() -> void:
	## Points on the body's real surface as it rests, in the creature's own space, read from
	## its meshes once: `_surface` a share of the corners of every part of any size (not its
	## legs, feelers or what it holds), `_core` every face of its trunk alone. What grows out
	## of the body is laid on these, so it stands on the body whatever shape that is.
	if not _surface.is_empty():
		return
	var rest: Transform3D = _rest_inverse.affine_inverse()
	var from_body: Transform3D = _body.global_transform.affine_inverse()
	## Each part: its corners, how much surface it has, the box round it.
	var parts: Array = []
	var biggest: int = -1
	for shape in _body.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (shape as MeshInstance3D).mesh
		if mesh == null:
			continue
		var faces: PackedVector3Array = mesh.get_faces()
		if faces.size() < 3:
			continue
		var to_creature: Transform3D = rest * (from_body * (shape as MeshInstance3D).global_transform)
		var area: float = 0.0
		var box := AABB(to_creature * faces[0], Vector3.ZERO)
		for i in range(faces.size()):
			faces[i] = to_creature * faces[i]
			box = box.expand(faces[i])
			if i % 3 == 2:
				area += (faces[i - 1] - faces[i - 2]).cross(faces[i] - faces[i - 2]).length()
		parts.append([faces, area, box])
		if biggest < 0 or area > float(parts[biggest][1]):
			biggest = parts.size() - 1
	if biggest < 0:
		## Nothing to read: the corners of the box it was measured as.
		for x in [-1.0, 1.0]:
			for y in [0.1, 1.0]:
				for z in [-1.0, 1.0]:
					_surface.append(Vector3(x * _half.x, y * _tall, z * _half.y))
		_core = _surface
		_core_box = AABB(Vector3(-_half.x, 0.1 * _tall, -_half.y), Vector3(_half.x * 2.0, _tall * 0.9, _half.y * 2.0))
		return
	## The trunk: its biggest part, and any other big part standing on or against it.
	var most: float = float(parts[biggest][1])
	var trunk: Array = [biggest]
	_core_box = parts[biggest][2]
	for sweep in range(3):
		for index in range(parts.size()):
			if trunk.has(index) or float(parts[index][1]) < most * 0.35:
				continue
			var box: AABB = parts[index][2]
			var middle: Vector3 = box.get_center()
			var reach := Vector2(_core_box.size.x, _core_box.size.z) * 0.6
			var off := Vector2(middle.x - _core_box.get_center().x, middle.z - _core_box.get_center().z).abs()
			if off.x <= reach.x and off.y <= reach.y and _core_box.grow(0.05 * _tall).intersects(box):
				trunk.append(index)
				_core_box = _core_box.merge(box)
	var kept: int = 0
	for index in range(parts.size()):
		if float(parts[index][1]) >= most * 0.05:
			kept += (parts[index][0] as PackedVector3Array).size()
	var stride: int = maxi(1, kept / SURFACE_POINTS)
	for index in range(parts.size()):
		var faces: PackedVector3Array = parts[index][0]
		if float(parts[index][1]) >= most * 0.05:
			for i in range(0, faces.size(), stride):
				_surface.append(faces[i])
		## The trunk is kept whole, three corners a face, so it can be cut across.
		if trunk.has(index):
			_core.append_array(faces)

func _outward(dir: Vector3, taken: Array = [], apart: float = 0.0) -> Vector3:
	## The point of the body's surface furthest out along `dir` from its middle, looking
	## only at what lies that way. `dir` is given for a body squeezed into a ball, so a wide
	## flat creature is covered as evenly as a round one. Points within `apart` of one
	## already `taken` are passed over, so what is laid spreads over the body.
	_read_body()
	var size := Vector3(_half.x, _tall * 0.5, _half.y)
	var middle := Vector3(0, _centre_y, 0)
	var best: Vector3 = middle + dir * size
	var best_reach: float = -1.0
	var fallback: float = -INF
	for point in _surface:
		var squeezed: Vector3 = (point - middle) / size
		var along: float = squeezed.dot(dir)
		var reach: float = squeezed.length()
		if reach > 0.01 and along / reach > 0.86:
			if reach > best_reach and not taken.any(func(other: Vector3) -> bool: return other.distance_squared_to(point) < apart * apart):
				best_reach = reach
				best = point
		elif best_reach < 0.0 and along > fallback:
			fallback = along
			best = point
	return best

# --- jagged: blades of glass ------------------------------------------------------------------

func _blades() -> ArrayMesh:
	## Blades of crystal grown out of the body all over its top and sides, each with a
	## smaller one or two at its root: one mesh, so one draw.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var span: float = _span()
	var size := Vector3(_half.x, _tall * 0.5, _half.y)
	var middle := Vector3(0, _centre_y, 0)
	var surface := Lowpoly.begin()
	var count: int = 16
	var roots: Array = []
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + rng.randf_range(-0.15, 0.15)
		var rise: float = rng.randf_range(0.2, 1.25)
		var dir := Vector3(cos(angle) * cos(rise), sin(rise), sin(angle) * cos(rise))
		var root: Vector3 = _outward(dir, roots, 0.13 * span)
		roots.append(root)
		## Out of the body the way its surface faces there, and never down.
		var out: Vector3 = ((root - middle) / (size * size)).normalized()
		out = (out + (root - middle).normalized() * 0.6 + Vector3(0, 0.25, 0)).normalized()
		out.y = maxf(out.y, 0.1)
		out = out.normalized()
		var length: float = rng.randf_range(0.2, 0.36) * span
		for n in range(1 + rng.randi_range(1, 2)):
			var lean: Vector3 = out if n == 0 else (out + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.6, 0.6))).normalized()
			var long: float = length if n == 0 else length * rng.randf_range(0.4, 0.62)
			var blade: ArrayMesh = Lowpoly.crystal(rng, Color("8fd8ff"), long * rng.randf_range(0.085, 0.12), long, 4)
			## Flat like a blade, turned any way round its own length, rooted a little inside.
			var basis := Basis(Quaternion(Vector3.UP, lean)) * Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(1.0, 1.0, 0.45))
			surface.append_from(blade, 0, Transform3D(basis, root - lean * long * 0.14))
	return surface.commit()

static func _glass_look() -> StandardMaterial3D:
	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.vertex_color_use_as_albedo = true
		_glass_material.vertex_color_is_srgb = true
		_glass_material.roughness = 0.08
		_glass_material.metallic = 0.3
		_glass_material.emission_enabled = true
		_glass_material.emission = Color("7fd4ff")
		_glass_material.emission_energy_multiplier = 0.7
		_glass_material.rim_enabled = true
		_glass_material.rim = 1.0
		_glass_material.rim_tint = 0.3
	return _glass_material

# --- steadfast: iron bands --------------------------------------------------------------------

func _bands() -> ArrayMesh:
	## Two iron bands bolted round its trunk, each as wide as the trunk really is where it
	## sits. A trunk taller than it is wide is hooped like a barrel; a wide one is strapped
	## over its back, either side of its middle.
	_read_body()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var surface := Lowpoly.begin()
	var wide: bool = _core_box.size.x > _core_box.size.y * 1.3
	var strap: float = clampf(0.09 * (_core_box.size.x if wide else _core_box.size.y), 0.035 * _span(), 0.08 * _span())
	var low: float = _core_box.position.x if wide else _core_box.position.y
	var run: float = _core_box.size.x if wide else _core_box.size.y
	for at in ([0.26, 0.74] if wide else [0.3, 0.68]):
		## Where the trunk's faces cross the band's plane: the outline it has to hug.
		var level: float = low + run * float(at)
		var u0: float = INF
		var u1: float = -INF
		var v0: float = INF
		var v1: float = -INF
		for i in range(0, _core.size() - 2, 3):
			for k in range(3):
				var p: Vector3 = _core[i + k]
				var q: Vector3 = _core[i + (k + 1) % 3]
				var p_off: float = (p.x if wide else p.y) - level
				var q_off: float = (q.x if wide else q.y) - level
				if (p_off < 0.0) == (q_off < 0.0):
					continue
				var cut: Vector3 = p.lerp(q, p_off / (p_off - q_off))
				u0 = minf(u0, cut.z)
				u1 = maxf(u1, cut.z)
				v0 = minf(v0, cut.y if wide else cut.x)
				v1 = maxf(v1, cut.y if wide else cut.x)
		if is_inf(u0):
			u0 = _core_box.position.z
			u1 = _core_box.end.z
			v0 = _core_box.position.y if wide else _core_box.position.x
			v1 = _core_box.end.y if wide else _core_box.end.x
		var a: float = maxf(0.05, (u1 - u0) * 0.5) + strap * 0.15
		var b: float = maxf(0.05, (v1 - v0) * 0.5) + strap * 0.15
		var centre := Vector3(level, (v0 + v1) * 0.5, (u0 + u1) * 0.5) if wide else Vector3((v0 + v1) * 0.5, level, (u0 + u1) * 0.5)
		## The band's own plane (u, v) and the way it runs across it (w).
		var u_axis := Vector3(0, 0, 1)
		var v_axis := Vector3(0, 1, 0) if wide else Vector3(1, 0, 0)
		var w_axis := Vector3(1, 0, 0) if wide else Vector3(0, 1, 0)
		_hoop(surface, rng, centre, u_axis, v_axis, w_axis, a, b, strap)
	return surface.commit()

static func _hoop(surface: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, u_axis: Vector3, v_axis: Vector3, w_axis: Vector3, a: float, b: float, strap: float) -> void:
	## One band: a rectangle with its corners cut, `strap` wide, a bolt at each corner.
	var thick: float = strap * 0.28
	var cut: float = 0.55
	var corners: Array = [Vector2(1, cut), Vector2(cut, 1), Vector2(-cut, 1), Vector2(-1, cut), Vector2(-1, -cut), Vector2(-cut, -1), Vector2(cut, -1), Vector2(1, -cut)]
	var inner: Array = []
	var outer: Array = []
	for corner in corners:
		inner.append(centre + u_axis * corner.x * a + v_axis * corner.y * b)
		outer.append(centre + u_axis * corner.x * (a + thick) + v_axis * corner.y * (b + thick))
	var half := w_axis * strap * 0.5
	var steel := Color("5d6373")
	for i in range(8):
		var j: int = (i + 1) % 8
		var out: Vector3 = ((outer[i] + outer[j]) * 0.5 - centre).normalized()
		Lowpoly.quad(surface, outer[i] - half, outer[j] - half, outer[j] + half, outer[i] + half, Lowpoly.shade(steel, rng, 0.1), out)
		Lowpoly.quad(surface, inner[i] - half, inner[j] - half, inner[j] + half, inner[i] + half, steel.darkened(0.45), -out)
		Lowpoly.quad(surface, inner[i] + half, inner[j] + half, outer[j] + half, outer[i] + half, steel.lightened(0.25), w_axis)
		Lowpoly.quad(surface, inner[i] - half, inner[j] - half, outer[j] - half, outer[i] - half, steel.darkened(0.2), -w_axis)
		## The bolt: a square stud standing off the corner.
		var stud: ArrayMesh = Lowpoly.spike(rng, Color("aeb6c8"), 4, strap * 0.26, strap * 0.34, 0.0, Color("e6ebf6"))
		var up: Vector3 = (outer[i] - centre).normalized()
		surface.append_from(stud, 0, Transform3D(Basis(Quaternion(Vector3.UP, up)), outer[i] - up * thick * 0.3))

static func _iron_look() -> StandardMaterial3D:
	if _iron_material == null:
		_iron_material = StandardMaterial3D.new()
		_iron_material.vertex_color_use_as_albedo = true
		_iron_material.vertex_color_is_srgb = true
		_iron_material.roughness = 0.42
		_iron_material.metallic = 0.7
		_iron_material.emission_enabled = true
		_iron_material.emission = Color("8c93a6")
		_iron_material.emission_energy_multiplier = 0.22
	return _iron_material

# --- sturdy: boulders set in the stone --------------------------------------------------------

func _boulders() -> ArrayMesh:
	## Lumps of rock set into its back and shoulders, half sunk in the crust.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var span: float = _span()
	var surface := Lowpoly.begin()
	var count: int = 7
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var rise: float = rng.randf_range(0.25, 1.0)
		var root: Vector3 = _outward(Vector3(cos(angle) * cos(rise), sin(rise), sin(angle) * cos(rise)))
		var out: Vector3 = (root - Vector3(0, _centre_y, 0)).normalized()
		var lump: ArrayMesh = Lowpoly.rock(rng, Color("77736e"), 0.3, Vector3(1.0, 0.6, 1.0))
		var basis := Basis(Quaternion(Vector3.UP, out)) * Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3.ONE * span * rng.randf_range(0.05, 0.085))
		surface.append_from(lump, 0, Transform3D(basis, root - out * span * 0.02))
	return surface.commit()

static func _rock_look() -> StandardMaterial3D:
	if _rock_material == null:
		_rock_material = StandardMaterial3D.new()
		_rock_material.vertex_color_use_as_albedo = true
		_rock_material.vertex_color_is_srgb = true
		## Unlit, like the crust they sit in: their facets carry their own light and dark.
		_rock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _rock_material
