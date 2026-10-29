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
## - Spikes: grey thorns jut out of it. Ward: a blue bubble round it that pops when it takes a
##   debuff for it (`pop_ward`). Regeneration: green motes rising.
## - Block: grey stone plates crust over the body in proportion to block against health;
##   a soaked blow chips plates off (`chip_crust`).
##
## The tint, the cracks and the crust are one overlay material drawn over every mesh of
## the body (triplanar masks, so no creature needs UVs); the rest are meshes and particles
## of its own. Everything eases toward what is asked of it, so a status that ends fades.

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
const CRUST := Color("9aa0b4")
## How much of its health in block fills the crust: plates cover it whole at half its health.
const CRUST_FULL: float = 0.5

const OVERLAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(0.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.48, 0.35, 0.0);
uniform sampler2D cracks : hint_default_black;
uniform vec4 crust_color : source_color = vec4(0.6, 0.63, 0.7, 0.0);
uniform sampler2D plates : hint_default_black;
uniform float crust_cut = 1.0;
uniform float tex_scale = 1.1;
uniform float flicker = 1.0;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float tri(sampler2D t, vec3 p, vec3 n) {
	vec3 b = abs(n);
	b /= max(0.001, b.x + b.y + b.z);
	return texture(t, p.yz).r * b.x + texture(t, p.xz).r * b.y + texture(t, p.xy).r * b.z;
}
void fragment() {
	vec3 p = wpos * tex_scale;
	float c = tri(cracks, p, wnorm);
	float k = tri(plates, p, wnorm);
	vec3 col = tint.rgb;
	float a = tint.a;
	float ca = crack_color.a * smoothstep(0.3, 0.7, c) * flicker;
	col = mix(col, crack_color.rgb, ca);
	a = a + ca * (1.0 - a);
	float ka = crust_color.a * step(0.03, k) * step(k, crust_cut);
	col = mix(col, crust_color.rgb * (0.85 + 0.3 * k), ka);
	a = a + ka * (1.0 - a);
	ALBEDO = col;
	ALPHA = a;
}
"""

static var _shader: Shader = null
static var _cracks_texture: ImageTexture = null
static var _plates_texture: ImageTexture = null
static var _x_texture: ImageTexture = null
static var _star_texture: ImageTexture = null
static var _chain_material: StandardMaterial3D = null
static var _thorn_material: StandardMaterial3D = null

var creature: Node3D
var _body: Node3D
var _meshes: Array = []
var _overlay: ShaderMaterial
var _clock: float = 0.0
## What is asked of it (the statuses as they stand) and where each look has eased to.
var _want: Dictionary = {}
var _tint_want: Color = Color(0, 0, 0, 0)
var _tint_now: Color = Color(0, 0, 0, 0)
var _crack_want: float = 0.0
var _crack_now: float = 0.0
var _crust_want: float = 0.0
var _crust_now: float = 0.0
var _crust_cut: float = 1.0
var _crust_cut_now: float = 1.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
## The body's size, in its own units: how tall it stands and how far it reaches sideways.
var _tall: float = 1.0
var _half: Vector2 = Vector2(0.4, 0.4)
var _centre_y: float = 0.5
var _sized: bool = false
## Slump (stun) and bulk (strength), read by the creature when it lays its body each frame.
var slump: float = 0.0
var bulk: float = 1.0
var _bulk_pulse: float = 0.0
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
var _ward: MeshInstance3D = null
var _ward_material: StandardMaterial3D = null
var _ward_ring: MeshInstance3D = null
var _ward_want: float = 0.0
var _ward_now: float = 0.0
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

func sync(statuses: Dictionary, block_ratio: float) -> void:
	## The statuses on the creature as the rules say they stand, and its block as a share of
	## its health. Called whenever the fight is drawn; every look eases toward it. Built once
	## the creature stands in the room (see `_dirty`).
	_want = statuses
	_block_ratio = block_ratio
	_dirty = true
	if is_inside_tree():
		_apply()

func _apply() -> void:
	_dirty = false
	var statuses: Dictionary = _want
	var block_ratio: float = _block_ratio
	_measure()
	var poison: int = int(statuses.get("poison", 0))
	var stun: int = int(statuses.get("stun", 0))
	var strength: int = int(statuses.get("strength", 0))
	## Grey and still outranks the green: a stunned creature reads as stunned first.
	if stun > 0:
		_tint_want = Color(0.5, 0.5, 0.56, 0.6)
	elif poison > 0:
		_tint_want = Color(POISON, 0.22 + 0.33 * clampf(float(poison) / 6.0, 0.0, 1.0))
	else:
		_tint_want = Color(_tint_want, 0.0)
	_crack_want = 0.0 if strength <= 0 else 0.55 + 0.35 * clampf(float(strength) / 4.0, 0.0, 1.0)
	bulk = 1.0 + 0.03 * float(clampi(strength, 0, 5))
	slump = 1.0 if stun > 0 else 0.0
	_crust_want = 0.85 if block_ratio > 0.0 else 0.0
	_crust_cut = clampf(block_ratio / CRUST_FULL, 0.08, 1.0) if block_ratio > 0.0 else 1.0
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
	_ensure_overlay()

func tick_flash(kind: String) -> void:
	## The beat at a tick: the whole body flashes the poison's green (or the burn's orange).
	_flash_color = Color("e4ffb0") if kind == "poison" else Color("ffd0a0")
	_flash = 1.0
	_ensure_overlay()

func bulk_up() -> void:
	## Gaining Strength: it swells for a moment and settles a little bigger.
	_bulk_pulse = 1.0

func pop_ward() -> void:
	## The bubble bursts as it takes a debuff for the creature; it is back if Ward is left.
	_ward_now = 0.0
	if _ward != null:
		_ward.scale = Vector3.ONE * 1.3

func chip_crust() -> void:
	## A soaked blow: the crust flashes; the plates it loses go with the next `sync`.
	_flash_color = Color("dfe6ff")
	_flash = maxf(_flash, 0.5)

func crusted() -> bool:
	return _crust_now > 0.2

func centre_local() -> Vector3:
	_measure()
	return Vector3(0, _centre_y, 0)

# --- each frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if _dirty and is_inside_tree():
		_apply()
	var ease: float = clampf(delta * 3.0, 0.0, 1.0)
	_tint_now = _tint_now.lerp(_tint_want, ease)
	_crack_now = lerpf(_crack_now, _crack_want, ease)
	_crust_now = lerpf(_crust_now, _crust_want, ease)
	_crust_cut_now = lerpf(_crust_cut_now, _crust_cut, clampf(delta * 4.0, 0.0, 1.0))
	_flash = move_toward(_flash, 0.0, delta * 4.5)
	_bulk_pulse = move_toward(_bulk_pulse, 0.0, delta * 2.2)
	if _overlay != null:
		var breathe: float = 0.85 + 0.15 * sin(_clock * 2.6)
		var shown: Color = Color(_tint_now, _tint_now.a * breathe)
		if _flash > 0.0:
			shown = shown.lerp(Color(_flash_color, 0.9), _flash)
		_overlay.set_shader_parameter("tint", shown)
		_overlay.set_shader_parameter("crack_color", Color(STRENGTH.lightened(0.1), _crack_now))
		_overlay.set_shader_parameter("flicker", 0.75 + 0.25 * sin(_clock * 9.0) * sin(_clock * 5.3))
		_overlay.set_shader_parameter("crust_color", Color(CRUST, _crust_now))
		_overlay.set_shader_parameter("crust_cut", _crust_cut_now)
		var idle: bool = shown.a < 0.01 and _crack_now < 0.01 and _crust_now < 0.01
		for mesh in _meshes:
			if is_instance_valid(mesh):
				(mesh as GeometryInstance3D).material_overlay = null if idle else _overlay
	if _underglow_material != null:
		var want: float = 0.55 + 0.25 * sin(_clock * 4.0) if _embers != null and _embers.emitting else 0.0
		_underglow_material.albedo_color.a = move_toward(_underglow_material.albedo_color.a, want, delta * 2.0)
		_underglow.visible = _underglow_material.albedo_color.a > 0.01
		if _ember_light != null:
			_ember_light.light_energy = _underglow_material.albedo_color.a * 1.2
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
	if _ward != null:
		_ward_now = move_toward(_ward_now, _ward_want, delta * 2.5)
		_ward_material.albedo_color.a = _ward_now * (0.06 + 0.025 * sin(_clock * 2.2))
		_ward.visible = _ward_now > 0.01
		_ward_ring.visible = _ward.visible
		_ward.scale = _ward.scale.lerp(Vector3.ONE * (1.0 + 0.04 * sin(_clock * 2.2)), clampf(delta * 5.0, 0.0, 1.0))
		_ward_ring.rotation.y += delta * 0.5

func _bulk_now() -> float:
	## The body's size now: its settled bulk and the swell of a gain on top.
	return bulk + 0.18 * sin(_bulk_pulse * PI) * _bulk_pulse

# --- the overlay: tint, cracks and crust ------------------------------------------------------

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY_SHADER
	_overlay = ShaderMaterial.new()
	_overlay.shader = _shader
	_overlay.set_shader_parameter("cracks", _cracks())
	_overlay.set_shader_parameter("plates", _plates())
	_overlay.set_shader_parameter("tex_scale", 1.1 / maxf(0.5, _tall))
	_meshes = _body.find_children("*", "GeometryInstance3D", true, false)

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

static func _plates() -> ImageTexture:
	## Stone plates: cells of one value each, with dark seams between them, tiling. The value
	## is which plates stay as the block wears down.
	if _plates_texture != null:
		return _plates_texture
	var size: int = 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seeds: Array = []
	for i in range(14):
		seeds.append([Vector2(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0)), 0.06 + 0.9 * float(i) / 13.0])
	var image := Image.create(size, size, false, Image.FORMAT_R8)
	for px in range(size):
		for py in range(size):
			var at := Vector2(float(px) / float(size), float(py) / float(size))
			var best: float = 9.0
			var second: float = 9.0
			var value: float = 0.0
			for seed_entry in seeds:
				for ox in [-1.0, 0.0, 1.0]:
					for oy in [-1.0, 0.0, 1.0]:
						var d: float = at.distance_to(seed_entry[0] + Vector2(ox, oy))
						if d < best:
							second = best
							best = d
							value = float(seed_entry[1])
						elif d < second:
							second = d
			var seam: bool = second - best < 0.03
			image.set_pixel(px, py, Color(0.0 if seam else value, 0, 0))
	_plates_texture = ImageTexture.create_from_image(image)
	return _plates_texture

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
	_sized = is_inside_tree()

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

# --- ward: the bubble -------------------------------------------------------------------------

func _ensure_ward() -> void:
	if _ward != null:
		return
	_ward = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var reach: float = maxf(maxf(_half.x, _half.y) * 1.35, _tall * 0.55) + 0.1
	sphere.radius = reach
	sphere.height = reach * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	_ward.mesh = sphere
	_ward_material = _soft(WARD)
	_ward.material_override = _ward_material
	_ward.position = Vector3(0, _centre_y, 0)
	_ward.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ward)
	_ward_ring = MeshInstance3D.new()
	_ward_ring.mesh = Lowpoly.ring(reach * 1.02, 0.04, 36)
	var rim := _soft(WARD.lightened(0.3))
	rim.albedo_color.a = 0.7
	_ward_ring.material_override = rim
	_ward_ring.position = Vector3(0, _centre_y, 0)
	_ward_ring.rotation.x = 0.35
	_ward_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ward_ring)
