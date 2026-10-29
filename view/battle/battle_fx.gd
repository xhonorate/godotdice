extends Node3D
## Everything in the chamber that happens for a moment: sparks, shards, bolts of light
## crossing the room, shockwaves, shields, coins and dust. Each effect builds its own nodes
## and frees them when it is done, so the chamber holds nothing it is not showing.
##
## Effects are presentation only. They are told where and what color, never what happened.

const Lowpoly = preload("res://view/battle/lowpoly.gd")

## 3 is everything; 2 thins the bursts; 1 is the least that still reads.
var quality: int = 3
## Short-lived lights the lens-flare overlay should dress: {position, color, strength, size, life, age}.
var flares: Array = []

static var _add_material: StandardMaterial3D = null
static var _soft_material: StandardMaterial3D = null
static var _quad: QuadMesh = null
static var _sparkle: ImageTexture = null
static var _stretched: QuadMesh = null
## One particle material of every kind ever made, kept for the life of the game. A particle
## material's shader is shared by every material with the same features and is freed with
## the last of them, so in the quiet between two blows each kind of burst was built and
## compiled again from nothing on the frame it was next needed: several milliseconds for
## each kind, on every hit after a pause. Holding one of each keeps them all compiled.
static var _kept: Dictionary = {}

static func release() -> void:
	## Lets go of every shared material, mesh and ramp before the renderer goes, on quit.
	_add_material = null
	_soft_material = null
	_quad = null
	_sparkle = null
	_stretched = null
	_kept.clear()
	_ramps.clear()
	_shrink = null
	_swell = null
	_twinkle = null
	_fire_ramp = null
	_tongue = null
	_flame_curve = null
	_smoke_ramp = null
	_breath_fire = null
	_breath_grow = null
	_sparkle_quad = null

## The step rate a room's air is filled at before it is first drawn. See `ambient`.
const AMBIENT_FILL_FPS := 6

# --- shared resources ------------------------------------------------------------------------

static func keep(kind: String, material: ParticleProcessMaterial) -> ParticleProcessMaterial:
	## Hands `material` back, and holds the first one of each kind for good. See `_kept`.
	if not _kept.has(kind):
		_kept[kind] = material
	return material

static func glow_material() -> StandardMaterial3D:
	## Additive camera-facing light, tinted by each particle's color.
	if _add_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		## Without this a billboard throws away the particle's own scale and every mote is a metre wide.
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = DeepUi.glow_texture()
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_receive_shadows = true
		_fade_at_lens(m)
		_add_material = m
	return _add_material

static func soft_material() -> StandardMaterial3D:
	## Ordinary blended puffs, for smoke, ash and mist, which darken as well as lighten.
	if _soft_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		## Without this a billboard throws away the particle's own scale and every mote is a metre wide.
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		## A puff's color is sRGB like every Color: read as linear, brown dust came out a white blob.
		m.vertex_color_is_srgb = true
		m.albedo_texture = DeepUi.glow_texture()
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_receive_shadows = true
		_fade_at_lens(m)
		_soft_material = m
	return _soft_material

static func sparkle_texture() -> ImageTexture:
	## A four-pointed glint: a hot core and long thin rays, fainter ones on the diagonals, the
	## shape light makes off a facet. A round glow read as a smudge, not as a star.
	if _sparkle != null:
		return _sparkle
	var span := 64
	var image := Image.create(span, span, false, Image.FORMAT_RGBA8)
	var middle := float(span - 1) * 0.5
	for y in span:
		for x in span:
			var dx: float = (float(x) - middle) / middle
			var dy: float = (float(y) - middle) / middle
			var r2: float = dx * dx + dy * dy
			var core: float = exp(-r2 * 22.0)
			var rays: float = exp(-absf(dx) * 4.2) * exp(-dy * dy * 700.0) + exp(-absf(dy) * 4.2) * exp(-dx * dx * 700.0)
			var u: float = (dx + dy) * 0.7071
			var v: float = (dx - dy) * 0.7071
			var diagonal: float = 0.3 * (exp(-absf(u) * 8.0) * exp(-v * v * 1100.0) + exp(-absf(v) * 8.0) * exp(-u * u * 1100.0))
			var alpha: float = clampf(core + rays + diagonal, 0.0, 1.0) * clampf(1.0 - sqrt(r2), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	image.generate_mipmaps()
	_sparkle = ImageTexture.create_from_image(image)
	return _sparkle

static func _fade_at_lens(m: StandardMaterial3D) -> void:
	## A mote that drifts right up to the eye was a blur the size of a fist, and a walk passes
	## straight through a room's air. Anything this close fades out instead. Bolts leave from
	## further out than this, so nothing the fight throws is touched.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.3
	m.distance_fade_max_distance = 1.2

static func quad(additive: bool = true) -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
		_quad.material = glow_material()
	if not additive:
		var soft := QuadMesh.new()
		soft.size = Vector2.ONE
		soft.material = soft_material()
		return soft
	return _quad

## The ramps and curves bursts are drawn with, made once each and shared: nothing changes one
## after it is handed out. The ramps are kept by color, and let go if they pile up.
static var _ramps: Dictionary = {}
static var _shrink: CurveTexture = null
static var _swell: CurveTexture = null
const RAMPS_KEPT := 256

static func _kept_ramp(key: Array) -> GradientTexture1D:
	if _ramps.size() >= RAMPS_KEPT and not _ramps.has(key):
		_ramps.clear()
	return _ramps.get(key, null)

static func fade_ramp(color: Color, peak: float = 1.0, hold: float = 0.2) -> GradientTexture1D:
	var key: Array = ["fade", color, peak, hold]
	var kept: GradientTexture1D = _kept_ramp(key)
	if kept != null:
		return kept
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(hold, Color(color, peak))
	gradient.add_point(1.0 - hold, Color(color, peak * 0.8))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	_ramps[key] = texture
	return texture

static func burst_ramp(color: Color) -> GradientTexture1D:
	## White-hot at birth, the color through its life, nothing at the end.
	var key: Array = ["burst", color]
	var kept: GradientTexture1D = _kept_ramp(key)
	if kept != null:
		return kept
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.lightened(0.7), 1.0))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(0.25, Color(color, 1.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	_ramps[key] = texture
	return texture

static func shrink_curve() -> CurveTexture:
	if _shrink != null:
		return _shrink
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_shrink = CurveTexture.new()
	_shrink.curve = curve
	return _shrink

static func swell_curve() -> CurveTexture:
	if _swell != null:
		return _swell
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.7))
	_swell = CurveTexture.new()
	_swell.curve = curve
	return _swell

# --- fire ----------------------------------------------------------------------------------------

static var _fire_ramp: GradientTexture1D = null
static var _tongue: QuadMesh = null
static var _flame_curve: CurveTexture = null
static var _smoke_ramp: GradientTexture1D = null

static func fire(size: float = 1.0, smoke: bool = true) -> Node3D:
	## A fire: tongues of flame that rise, narrow and redden as they go, sparks thrown up out of
	## it on the draught, and a little smoke over it. Each tongue carries far less light than a
	## burst does, so where they pile up the heart of the fire is yellow and not a white blot.
	var node := Node3D.new()
	if _tongue == null:
		_tongue = QuadMesh.new()
		_tongue.size = Vector2(0.62, 1.0)
		var tongue := glow_material().duplicate() as StandardMaterial3D
		tongue.albedo_texture = _tongue_texture()
		_tongue.material = tongue
	if _fire_ramp == null:
		## Brighter than white in the red and green, so it blooms orange: a fire drawn in plain
		## colors either vanishes against a lit floor or, piled up, burns out to white.
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.7, 0.95, 0.4, 0.0))
		gradient.set_color(1, Color(0.3, 0.05, 0.02, 0.0))
		gradient.add_point(0.08, Color(1.9, 0.9, 0.3, 0.7))
		gradient.add_point(0.35, Color(1.7, 0.48, 0.1, 0.55))
		gradient.add_point(0.7, Color(0.9, 0.16, 0.04, 0.28))
		_fire_ramp = GradientTexture1D.new()
		_fire_ramp.use_hdr = true
		_fire_ramp.gradient = gradient
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.55))
		curve.add_point(Vector2(0.18, 1.0))
		curve.add_point(Vector2(1.0, 0.1))
		_flame_curve = CurveTexture.new()
		_flame_curve.curve = curve
		var haze := Gradient.new()
		haze.set_color(0, Color(0.16, 0.13, 0.11, 0.0))
		haze.set_color(1, Color(0.12, 0.11, 0.11, 0.0))
		haze.add_point(0.25, Color(0.16, 0.13, 0.11, 0.22))
		_smoke_ramp = GradientTexture1D.new()
		_smoke_ramp.gradient = haze
	var flame := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2 * size
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.5 * size
	m.initial_velocity_max = 1.1 * size
	m.gravity = Vector3(0, 1.1 * size, 0)
	m.damping_min = 0.3
	m.damping_max = 0.7
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.35
	m.turbulence_noise_scale = 1.4
	m.scale_min = 0.32 * size
	m.scale_max = 0.56 * size
	m.scale_curve = _flame_curve
	m.color_ramp = _fire_ramp
	flame.process_material = keep("fire", m)
	flame.draw_pass_1 = _tongue
	flame.amount = 46
	flame.lifetime = 0.85
	flame.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4) * maxf(size, 1.0))
	node.add_child(flame)
	var sparks := GPUParticles3D.new()
	var e := ParticleProcessMaterial.new()
	e.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.18 * size
	e.direction = Vector3.UP
	e.spread = 22.0
	e.initial_velocity_min = 0.9 * size
	e.initial_velocity_max = 1.9 * size
	e.gravity = Vector3(0, 0.25, 0)
	e.damping_min = 0.6
	e.damping_max = 1.2
	e.turbulence_enabled = true
	e.turbulence_noise_strength = 1.3
	e.turbulence_noise_scale = 2.2
	e.scale_min = 0.025 * size
	e.scale_max = 0.05 * size
	e.scale_curve = shrink_curve()
	e.color_ramp = burst_ramp(Color("ff8a30"))
	sparks.process_material = keep("fire_sparks", e)
	sparks.draw_pass_1 = quad(true)
	sparks.amount = 14
	sparks.lifetime = 1.7
	sparks.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6) * maxf(size, 1.0))
	node.add_child(sparks)
	if smoke:
		var plume := GPUParticles3D.new()
		var s := ParticleProcessMaterial.new()
		s.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = 0.15 * size
		s.direction = Vector3.UP
		s.spread = 10.0
		s.initial_velocity_min = 0.35 * size
		s.initial_velocity_max = 0.6 * size
		s.gravity = Vector3(0, 0.05, 0)
		s.turbulence_enabled = true
		s.turbulence_noise_strength = 0.5
		s.scale_min = 0.4 * size
		s.scale_max = 0.75 * size
		s.scale_curve = swell_curve()
		s.color_ramp = _smoke_ramp
		plume.process_material = keep("fire_smoke", s)
		plume.draw_pass_1 = quad(false)
		plume.amount = 10
		plume.lifetime = 2.6
		plume.position = Vector3(0, 0.55 * size, 0)
		plume.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6) * maxf(size, 1.0))
		node.add_child(plume)
	return node

static func _tongue_texture() -> ImageTexture:
	## One tongue of flame: full and round at its root, drawn out to a point, soft all over.
	var width := 48
	var height := 80
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var v: float = 1.0 - float(y) / float(height - 1)
		var reach: float = 0.92 * pow(1.0 - v, 0.6) * (0.6 + 0.4 * sin(v * PI * 0.85 + 0.35))
		for x in width:
			var u: float = (float(x) / float(width - 1)) * 2.0 - 1.0
			var inside: float = clampf(1.0 - absf(u) / maxf(reach, 0.001), 0.0, 1.0)
			var alpha: float = pow(inside, 1.4) * smoothstep(0.0, 0.16, v) * (1.0 - smoothstep(0.7, 1.0, v))
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

# --- ambient -----------------------------------------------------------------------------------

static func ambient(kind: String, biome: Dictionary, scale: float = 1.0) -> GPUParticles3D:
	## The air of a biome: what drifts through the light whether anything is happening or not.
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	## Kept back from the lens: a mote a metre from the camera is a blur the size of a fist.
	m.emission_box_extents = Vector3(11, 4.2, 7)
	p.position = Vector3(0, 3.6, -7.5)
	p.visibility_aabb = AABB(Vector3(-16, -8, -14), Vector3(32, 16, 28))
	var mesh: Mesh = quad(true)
	p.local_coords = true
	var key: Color = biome.get("key", Color.WHITE)
	var accent: Color = biome.get("accent", Color.WHITE)
	var lights: Array = biome.get("lights", [accent])
	var amount := 60
	var lifetime := 8.0
	match kind:
		"dust":
			amount = 150
			lifetime = 12.0
			m.direction = Vector3(0.3, 0.2, 0)
			m.spread = 180.0
			m.initial_velocity_min = 0.02
			m.initial_velocity_max = 0.12
			m.gravity = Vector3(0, -0.015, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.4
			m.turbulence_noise_scale = 5.0
			m.scale_min = 0.015
			m.scale_max = 0.035
			m.color_ramp = fade_ramp(Color(key * 0.8, 1.0), 0.4)
		"motes":
			amount = 36
			lifetime = 9.0
			m.direction = Vector3(0, 1, 0)
			m.spread = 60.0
			m.initial_velocity_min = 0.05
			m.initial_velocity_max = 0.2
			m.gravity = Vector3(0, 0.01, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.6
			m.scale_min = 0.04
			m.scale_max = 0.1
			m.color_ramp = fade_ramp(Color(accent, 1.0), 0.3, 0.3)
		"drips":
			amount = 50
			lifetime = 1.4
			p.position = Vector3(0, 7.4, -7.5)
			m.emission_box_extents = Vector3(11, 0.2, 7)
			m.direction = Vector3.DOWN
			m.spread = 2.0
			m.initial_velocity_min = 1.0
			m.initial_velocity_max = 2.0
			m.gravity = Vector3(0, -9.8, 0)
			m.scale_min = 0.03
			m.scale_max = 0.05
			m.color_ramp = fade_ramp(Color("bfe8ff"), 0.9, 0.05)
			mesh = _stretched_quad()
		"sparkles":
			amount = 90
			lifetime = 3.0
			m.direction = Vector3.UP
			m.spread = 180.0
			m.initial_velocity_min = 0.0
			m.initial_velocity_max = 0.05
			m.gravity = Vector3.ZERO
			m.scale_min = 0.04
			m.scale_max = 0.1
			m.scale_curve = _twinkle_curve()
			var gradient := Gradient.new()
			gradient.set_color(0, Color(lights[0], 1.0))
			gradient.set_color(1, Color(accent.lightened(0.4), 1.0))
			if lights.size() > 1:
				gradient.add_point(0.5, Color(lights[1], 1.0))
			var ramp := GradientTexture1D.new()
			ramp.gradient = gradient
			m.color_initial_ramp = ramp
		"spores":
			amount = 110
			lifetime = 10.0
			m.direction = Vector3.UP
			m.spread = 40.0
			m.initial_velocity_min = 0.08
			m.initial_velocity_max = 0.25
			m.gravity = Vector3(0, 0.02, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 1.0
			m.turbulence_noise_scale = 3.0
			m.scale_min = 0.04
			m.scale_max = 0.1
			m.color_ramp = fade_ramp(Color(accent, 1.0), 0.8, 0.25)
			p.position = Vector3(0, 2.2, -7.5)
		"embers":
			amount = 120
			lifetime = 4.5
			p.position = Vector3(0, 0.6, -8.0)
			m.emission_box_extents = Vector3(11, 0.6, 6)
			m.direction = Vector3.UP
			m.spread = 25.0
			m.initial_velocity_min = 0.6
			m.initial_velocity_max = 1.6
			m.gravity = Vector3(0, 0.15, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 1.4
			m.turbulence_noise_scale = 2.5
			m.scale_min = 0.03
			m.scale_max = 0.07
			m.scale_curve = shrink_curve()
			m.color_ramp = burst_ramp(Color("ff7a2a"))
		"ash":
			amount = 70
			lifetime = 9.0
			p.position = Vector3(0, 7.0, -7.5)
			m.direction = Vector3.DOWN
			m.spread = 30.0
			m.initial_velocity_min = 0.1
			m.initial_velocity_max = 0.3
			m.gravity = Vector3(0, -0.08, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.8
			m.scale_min = 0.04
			m.scale_max = 0.08
			m.color_ramp = fade_ramp(Color("3a3230"), 0.8)
			mesh = quad(false)
		"void":
			amount = 100
			lifetime = 7.0
			m.direction = Vector3.UP
			m.spread = 180.0
			m.initial_velocity_min = 0.1
			m.initial_velocity_max = 0.3
			m.gravity = Vector3(0, 0.05, 0)
			m.orbit_velocity_min = 0.01
			m.orbit_velocity_max = 0.03
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.8
			m.scale_min = 0.03
			m.scale_max = 0.12
			m.color_ramp = fade_ramp(Color(accent, 1.0), 0.7, 0.3)
	p.amount = maxi(4, int(float(amount) * scale))
	p.lifetime = lifetime
	p.preprocess = lifetime
	## The air is full before it is first seen because `preprocess` seconds of it are run in
	## one frame, a pass for every tick of `fixed_fps`: twelve seconds of dust at the usual
	## thirty a second was 360 passes and fifteen milliseconds of GPU, in the middle of a
	## walk. The fill runs coarse, and the usual rate comes back a few frames later, once the
	## fill has had a frame to run in.
	p.fixed_fps = AMBIENT_FILL_FPS
	_after_frames(3, p.set.bind("fixed_fps", 30))
	p.process_material = keep("ambient:" + kind, m)
	## Set the process material first: assigning a material-bearing mesh first leaks a
	## shader in Godot 4.7.2 (reproduced by tools/repro_particle_shader.gd).
	p.draw_pass_1 = mesh
	return p

static func _after_frames(frames: int, work: Callable) -> void:
	## Runs `work` once this many more frames have gone by, if what it acts on is still there.
	## Counted on the scene tree rather than the rendering server: a wait still pending when
	## the game quits goes with the tree, while one left on the server outlived the script it
	## was written in and brought the engine down on its way out.
	if frames <= 0:
		if work.is_valid():
			work.call()
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		if work.is_valid():
			work.call()
		return
	tree.process_frame.connect(func() -> void: _after_frames(frames - 1, work), CONNECT_ONE_SHOT)

static func _stretched_quad() -> QuadMesh:
	if _stretched == null:
		_stretched = QuadMesh.new()
		_stretched.size = Vector2(0.4, 3.0)
		_stretched.material = glow_material()
	return _stretched

static var _twinkle: CurveTexture = null

static func _twinkle_curve() -> CurveTexture:
	if _twinkle != null:
		return _twinkle
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.3, 0.1))
	curve.add_point(Vector2(0.55, 0.9))
	curve.add_point(Vector2(0.75, 0.05))
	curve.add_point(Vector2(1, 0))
	_twinkle = CurveTexture.new()
	_twinkle.curve = curve
	return _twinkle

# --- the heartbeat -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	for flare in flares.duplicate():
		flare.age = float(flare.age) + delta
		if float(flare.age) >= float(flare.life):
			flares.erase(flare)

func add_flare(at: Vector3, color: Color, strength: float = 1.0, size: float = 1.0, life: float = 0.5) -> void:
	flares.append({"position": at, "color": color, "strength": strength, "size": size, "life": life, "age": 0.0})

func _amount(count: int) -> int:
	## Never more than a few thousand motes, however big the number a burst was sized from.
	return clampi(int(float(mini(count, 3000)) * [0.35, 0.35, 0.65, 1.0][clampi(quality, 0, 3)]), 1, 3000)

func _burst(at: Vector3, amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.94
	p.amount = _amount(amount)
	p.lifetime = lifetime
	p.process_material = process
	p.draw_pass_1 = mesh
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	## `finished` only comes once the renderer has run the burst to its end, and a burst the
	## camera never looked at (behind it, off to one side, under a page) is never run: those
	## used to pile up by the hundred over a long session, each holding its GPU buffers, until
	## the card ran short and dice, stones and whole passes stopped drawing. A clock frees
	## every burst whether or not it was seen.
	var tree := get_tree()
	if tree != null:
		tree.create_timer(lifetime + 1.0, false).timeout.connect(p.queue_free)
	return p

# --- bursts ------------------------------------------------------------------------------------

func sparks(at: Vector3, color: Color, amount: int = 40, speed: float = 5.0, lifetime: float = 0.6, size: float = 0.06) -> void:
	## A spray of hot points thrown out from a hit and pulled down.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	m.direction = Vector3(0, 0.4, 1)
	m.spread = 180.0
	m.initial_velocity_min = speed * 0.4
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -7.0, 0)
	m.damping_min = 1.0
	m.damping_max = 3.0
	m.scale_min = size * 0.6
	m.scale_max = size * 1.4
	m.scale_curve = shrink_curve()
	m.color_ramp = burst_ramp(color)
	_burst(at, amount, lifetime, keep("sparks", m), _stretched_quad() if speed > 4.0 else quad(true))

func glow_burst(at: Vector3, color: Color, size: float = 1.6, seconds: float = 0.35) -> void:
	## A single bloom of light where something landed.
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.0
	m.scale_min = size
	m.scale_max = size
	m.scale_curve = swell_curve()
	m.color_ramp = burst_ramp(color)
	_burst(at, 2, seconds, keep("glow", m), quad(true))

func puff(at: Vector3, color: Color, amount: int = 14, size: float = 0.7, lifetime: float = 1.2, rise: float = 0.4, additive: bool = false) -> void:
	## A cloud: poison, dust thrown up, smoke off a spent gem.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.4
	m.direction = Vector3.UP
	m.spread = 90.0
	m.initial_velocity_min = rise * 0.3
	m.initial_velocity_max = rise
	m.gravity = Vector3(0, 0.2, 0)
	m.damping_min = 0.5
	m.damping_max = 1.0
	m.scale_min = size * 0.6
	m.scale_max = size * 1.2
	m.scale_curve = swell_curve()
	m.color_ramp = fade_ramp(color, 0.7 if not additive else 0.9, 0.15)
	_burst(at, amount, lifetime, keep("puff", m), quad(additive))

func rise(at: Vector3, color: Color, amount: int = 28, spread: float = 1.2, lifetime: float = 1.4) -> void:
	## Motes of light floating upward: healing, cleansing, a gem's blessing.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(spread, 0.2, spread * 0.6)
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 2.0
	m.gravity = Vector3(0, 0.6, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	m.scale_min = 0.06
	m.scale_max = 0.16
	m.scale_curve = shrink_curve()
	m.color_ramp = burst_ramp(color)
	var p := _burst(at, amount, lifetime, keep("rise", m), quad(true))
	p.explosiveness = 0.4

func dust_fall(amount: int = 60, width: float = 9.0) -> void:
	## The ceiling sheds grit when something heavy lands.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(width, 0.2, 5.0)
	m.direction = Vector3.DOWN
	m.spread = 8.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0, -6.0, 0)
	m.scale_min = 0.03
	m.scale_max = 0.08
	m.color_ramp = fade_ramp(Color("8a7a66"), 0.9, 0.05)
	var p := _burst(Vector3(0, 7.2, -4.0), amount, 1.6, keep("dust_fall", m), quad(false))
	p.explosiveness = 0.5

func ring_wave(at: Vector3, color: Color, radius: float = 3.0, seconds: float = 0.55, width: float = 0.35) -> void:
	## A shockwave rolling out across the floor.
	var node := MeshInstance3D.new()
	node.mesh = Lowpoly.ring(1.0, width / maxf(radius, 0.1))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.3), 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at + Vector3(0, 0.05, 0)
	node.scale = Vector3.ONE * 0.2
	add_child(node)
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * radius, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(m, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(node.queue_free)

func flash(at: Vector3, color: Color, energy: float = 6.0, reach: float = 7.0, seconds: float = 0.35, flare: float = 1.0) -> void:
	## A light that blazes and dies: the room lit for a moment by what just happened.
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 2.0
	light.position = at
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(light.queue_free)
	if flare > 0.0:
		add_flare(at, color, flare, 1.0, seconds * 1.2)

func shards(at: Vector3, color: Color, count: int = 14, speed: float = 4.0, size: float = 0.14, seconds: float = 1.1) -> void:
	## Real faceted splinters thrown in arcs, tumbling and landing. What a creature leaves.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.2
	m.metallic = 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.2
	m.rim_enabled = true
	for i in range(_amount(count)):
		var piece := MeshInstance3D.new()
		piece.mesh = Lowpoly.shard(rng, color.lightened(0.2), size * rng.randf_range(0.6, 1.4))
		piece.material_override = m
		piece.position = at
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		var heading := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.4), rng.randf_range(-0.6, 1.0)).normalized() * speed * rng.randf_range(0.5, 1.0)
		var spin := Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		var start := at
		var life: float = seconds * rng.randf_range(0.8, 1.2)
		var tween := piece.create_tween()
		tween.tween_method(func(t: float) -> void:
			if not is_instance_valid(piece):
				return
			var s: float = t * life
			var p := start + heading * s + Vector3(0, -9.0, 0) * s * s * 0.5
			if p.y < 0.03:
				p.y = 0.03
			piece.position = p
			piece.rotation = spin * s * (1.0 - t * 0.6)
			piece.scale = Vector3.ONE * clampf(1.4 - t * 1.4, 0.0, 1.0), 0.0, 1.0, life)
		tween.tween_callback(piece.queue_free)
	var tween := create_tween()
	tween.tween_property(m, "emission_energy_multiplier", 0.0, seconds)

func projectile(from: Vector3, to: Vector3, color: Color, seconds: float = 0.28, size: float = 0.14, arrive: Callable = Callable(), arc: float = 0.8, halo_scale: float = 7.0) -> void:
	## A bolt of the gem's own light from the setting to its target: a hot core, a halo, a
	## light that sweeps the walls as it passes, and a trail of embers. A creature's throw at
	## the party passes a smaller `halo_scale`: it ends just before the lens, where a full halo
	## would cover the screen.
	var bolt := Node3D.new()
	bolt.position = from
	add_child(bolt)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size * 0.5
	sphere.height = size
	sphere.radial_segments = 8
	sphere.rings = 4
	core.mesh = sphere
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = color.lightened(0.75)
	core.material_override = hot
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(core)
	var halo := MeshInstance3D.new()
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2.ONE * size * halo_scale
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.albedo_texture = DeepUi.glow_texture()
	halo_material.albedo_color = Color(color, 0.95)
	halo_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	halo_quad.material = halo_material
	halo.mesh = halo_quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.5
	light.omni_range = 4.0
	light.light_volumetric_fog_energy = 3.0
	bolt.add_child(light)
	var trail := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.3
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.4
	m.gravity = Vector3(0, -0.5, 0)
	m.scale_min = size * 0.8
	m.scale_max = size * 1.8
	m.scale_curve = shrink_curve()
	m.color_ramp = burst_ramp(color)
	trail.process_material = keep("trail", m)
	trail.draw_pass_1 = quad(true)
	trail.amount = _amount(48)
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	bolt.add_child(trail)
	trail.emitting = true
	var control := (from + to) * 0.5 + Vector3(0, arc, 0)
	var tween := bolt.create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(bolt):
			var a := from.lerp(control, t)
			var b := control.lerp(to, t)
			bolt.position = a.lerp(b, t), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		core.visible = false
		halo.visible = false
		light.visible = false
		trail.emitting = false
		if arrive.is_valid():
			arrive.call())
	tween.tween_interval(0.5)
	tween.tween_callback(bolt.queue_free)

func beam(from: Vector3, to: Vector3, color: Color, seconds: float = 0.4, width: float = 0.18) -> void:
	## A lance of light, for the heaviest blows.
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(width, width, length)
	node.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.4), 1.0)
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.look_at_from_position((from + to) * 0.5, to, _up_for(to - from))
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector3(0.05, 0.05, 1.0), seconds).set_ease(Tween.EASE_IN)
	tween.tween_property(m, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(node.queue_free)

static func _up_for(facing: Vector3) -> Vector3:
	## look_at's up, kept off the line it looks along: a beam straight up (the well's) or a ward
	## facing the sky would warn that the two are colinear. Along that line it is the side
	## Godot's own fallback would have picked, so nothing on screen turns.
	if not Vector3.UP.cross(facing.normalized()).is_zero_approx():
		return Vector3.UP
	return Vector3.RIGHT if facing.y > 0.0 else Vector3.LEFT

func shield(at: Vector3, facing: Vector3, color: Color, radius: float = 0.9, seconds: float = 0.55, alpha: float = 0.55, glow: float = 3.0) -> void:
	## A hexagonal ward flaring and dissolving: block taken. `alpha` is its outer shell's
	## opacity (the inner two are fainter); one raised before the lens keeps it low enough to
	## read the creatures and their plates through. `glow` is the light it throws on the room.
	for i in range(3):
		var node := MeshInstance3D.new()
		node.mesh = Lowpoly.hex_dome(radius * (1.0 - 0.2 * float(i)))
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(color, alpha * (1.0 - 0.22 * float(i)))
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.look_at_from_position(at, at + facing, _up_for(facing))
		node.rotate_object_local(Vector3.UP, PI)
		node.scale = Vector3.ONE * 0.5
		var tween := node.create_tween().set_parallel(true)
		tween.tween_property(node, "scale", Vector3.ONE * (1.15 + 0.1 * float(i)), seconds).set_delay(0.05 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(m, "albedo_color:a", 0.0, seconds * 0.8).set_delay(seconds * 0.3 + 0.05 * float(i))
		tween.chain().tween_callback(node.queue_free)
	if glow > 0.0:
		flash(at, color, glow, 4.0, seconds, 0.6 * glow / 3.0)

func coins(at: Vector3, to: Vector3, count: int = 8) -> void:
	## Ore thrown up in glinting discs and pulled home to the party.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffcf5a")
	m.metallic = 0.9
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color("ffb030")
	m.emission_energy_multiplier = 0.8
	var disc := CylinderMesh.new()
	disc.top_radius = 0.08
	disc.bottom_radius = 0.08
	disc.height = 0.02
	disc.radial_segments = 8
	disc.rings = 1
	for i in range(_amount(count)):
		var coin := MeshInstance3D.new()
		coin.mesh = disc
		coin.material_override = m
		coin.position = at
		add_child(coin)
		var peak := at + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(1.0, 2.2), rng.randf_range(-0.4, 0.8))
		var spin := Vector3(rng.randf_range(4, 12), rng.randf_range(2, 8), 0)
		var delay := 0.03 * float(i)
		var tween := coin.create_tween()
		tween.tween_interval(delay)
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(coin):
				var a := at.lerp(peak, t)
				var b := peak.lerp(to, t)
				coin.position = a.lerp(b, t)
				coin.rotation = spin * t * 3.0
				coin.scale = Vector3.ONE * (1.0 - 0.6 * t), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(coin.queue_free)

func stars(at: Vector3, color: Color = Color("ffe27a"), seconds: float = 1.3, radius: float = 0.55) -> void:
	## Stun: a ring of little stars wheeling over the head.
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = sparkle_texture()
	mat.albedo_color = Color(color.lightened(0.25), 1.0)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.34
	mesh.material = mat
	var tween := pivot.create_tween().set_parallel(true)
	for i in range(5):
		var star := MeshInstance3D.new()
		star.mesh = mesh
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(i) / 5.0
		star.position = Vector3(cos(angle), 0, sin(angle)) * radius
		star.scale = Vector3.ONE * 0.2
		pivot.add_child(star)
		## Each one winks on in turn and pulses as it goes round.
		var beat: float = 0.06 * float(i)
		tween.tween_property(star, "scale", Vector3.ONE * 1.25, 0.16).set_delay(beat).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector3.ONE * 0.8, seconds * 0.3).set_delay(beat + 0.16).set_trans(Tween.TRANS_SINE)
		tween.tween_property(star, "scale", Vector3.ONE * 1.1, seconds * 0.3).set_delay(beat + 0.16 + seconds * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation:y", TAU * 1.5, seconds)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
	tween.chain().tween_callback(pivot.queue_free)

func sigil(at: Vector3, color: Color, radius: float = 1.1, seconds: float = 0.9) -> void:
	## A mark burned into the floor under a target: curses and hexes.
	var node := MeshInstance3D.new()
	node.mesh = Lowpoly.ring(1.0, 0.12, 6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.0)
	node.material_override = m
	node.position = at + Vector3(0, 0.06, 0)
	node.scale = Vector3.ONE * radius
	add_child(node)
	var tween := node.create_tween()
	tween.tween_property(m, "albedo_color:a", 1.0, seconds * 0.2)
	tween.parallel().tween_property(node, "rotation:y", PI, seconds)
	tween.tween_property(m, "albedo_color:a", 0.0, seconds * 0.5)
	tween.tween_callback(node.queue_free)

# --- what creatures do (docs/BESTIARY.md) -----------------------------------------------------

func flames(at: Vector3, size: float = 0.6, seconds: float = 0.9) -> void:
	## A lick of fire that catches, burns for a moment and goes out: Burn landing, Burn biting.
	var fire_node: Node3D = fire(size, false)
	fire_node.position = at
	add_child(fire_node)
	flash(at, Color("ff8a30"), 3.0 + 3.0 * size, 5.0, seconds * 0.6, 0.7)
	var tree := get_tree()
	if tree == null:
		fire_node.queue_free()
		return
	var held: WeakRef = weakref(fire_node)
	tree.create_timer(seconds, false).timeout.connect(func() -> void:
		var still: Node3D = held.get_ref() as Node3D
		if still != null:
			for child in still.get_children():
				if child is GPUParticles3D:
					(child as GPUParticles3D).emitting = false)
	## The flames already in the air burn out before it goes; freed on the clock all the same,
	## seen or not (a particle node the camera never ran would wait for ever otherwise).
	tree.create_timer(seconds + 1.8, false).timeout.connect(fire_node.queue_free)

func bubbles(at: Vector3, color: Color, amount: int = 24, spread: float = 0.8, lifetime: float = 1.3) -> void:
	## Bubbles welling up and bursting: poison taking hold.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(spread, 0.15, spread * 0.5)
	m.direction = Vector3.UP
	m.spread = 18.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0, 0.5, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.9
	m.turbulence_noise_scale = 2.0
	m.scale_min = 0.03
	m.scale_max = 0.09
	m.scale_curve = swell_curve()
	m.color_ramp = fade_ramp(color.lightened(0.2), 0.95, 0.1)
	var p := _burst(at, amount, lifetime, keep("bubbles", m), quad(true))
	p.explosiveness = 0.3

func splash(at: Vector3, color: Color = Color("8fd0e8"), amount: int = 40, speed: float = 4.0, lifetime: float = 1.0) -> void:
	## Water thrown up and falling back: the sluice opening, a drowned thing rising.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.4
	m.direction = Vector3(0, 1, 0.3)
	m.spread = 50.0
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -9.0, 0)
	m.scale_min = 0.03
	m.scale_max = 0.07
	m.color_ramp = fade_ramp(color.lightened(0.35), 0.95, 0.05)
	_burst(at, amount, lifetime, keep("splash", m), _stretched_quad())
	puff(at, Color(color, 0.6), 10, 0.9, 0.9, 0.6, true)

func reticle(at: Vector3, facing: Vector3, color: Color, size: float = 0.9, seconds: float = 1.0) -> void:
	## Crosshairs closing on a target: Marked.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.look_at_from_position(at, at + facing, _up_for(facing))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color, 0.0)
	var ring := MeshInstance3D.new()
	ring.mesh = Lowpoly.ring(1.0, 0.08, 32)
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	ring.material_override = m
	pivot.add_child(ring)
	for i in range(4):
		var tick := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.06, 0.4, 0.02)
		tick.mesh = bar
		tick.material_override = m
		var angle: float = TAU * float(i) / 4.0
		tick.position = Vector3(cos(angle), sin(angle), 0) * 1.1
		tick.rotation = Vector3(0, 0, angle + PI * 0.5)
		pivot.add_child(tick)
	pivot.scale = Vector3.ONE * size * 2.2
	var tween := pivot.create_tween().set_parallel(true)
	tween.tween_property(pivot, "scale", Vector3.ONE * size, seconds * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(m, "albedo_color:a", 1.0, seconds * 0.2)
	tween.tween_property(pivot, "rotation:z", PI * 0.25, seconds * 0.35)
	tween.chain().tween_property(m, "albedo_color:a", 0.0, seconds * 0.5).set_delay(seconds * 0.15)
	tween.chain().tween_callback(pivot.queue_free)

func spiral_in(at: Vector3, color: Color, radius: float = 2.2, amount: int = 40, lifetime: float = 1.0) -> void:
	## Light pulled in from all round and swallowed: a copy taken, a blow bent into a Collapsar.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0, 0, 1)
	m.emission_ring_radius = radius
	m.emission_ring_inner_radius = radius * 0.8
	m.emission_ring_height = 0.2
	m.gravity = Vector3.ZERO
	m.radial_accel_min = -radius * 3.5
	m.radial_accel_max = -radius * 2.5
	m.orbit_velocity_min = 0.3
	m.orbit_velocity_max = 0.6
	m.scale_min = 0.05
	m.scale_max = 0.12
	m.scale_curve = shrink_curve()
	m.color_ramp = burst_ramp(color)
	var p := _burst(at, amount, lifetime, keep("spiral_in", m), quad(true))
	p.explosiveness = 0.6

func claw(at: Vector3, facing: Vector3, color: Color, seconds: float = 0.45) -> void:
	## Two pincers snapping shut on something: a die taken in a claw.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.look_at_from_position(at, at + facing, _up_for(facing))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color.lightened(0.3), 0.95)
	var tween := pivot.create_tween().set_parallel(true)
	for side in [-1.0, 1.0]:
		var pincer := MeshInstance3D.new()
		pincer.mesh = Lowpoly.ring(0.5, 0.18, 12)
		pincer.material_override = m
		pincer.rotation = Vector3(PI * 0.5, 0, 0)
		pincer.position = Vector3(side * 0.9, 0, 0)
		pivot.add_child(pincer)
		tween.tween_property(pincer, "position:x", side * 0.22, seconds * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(m, "albedo_color:a", 0.0, seconds * 0.6)
	tween.chain().tween_callback(pivot.queue_free)
	shards(at, color, 6, 2.5, 0.08, 0.6)

# --- what a creature's own move throws (creature_moves.gd) -------------------------------------

static var _breath_fire: GradientTexture1D = null
static var _breath_grow: CurveTexture = null
static var _sparkle_quad: QuadMesh = null

static func _breath_curve() -> CurveTexture:
	## Small at the mouth, spreading as it goes.
	if _breath_grow == null:
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.42))
		curve.add_point(Vector2(0.55, 0.9))
		curve.add_point(Vector2(1.0, 1.0))
		_breath_grow = CurveTexture.new()
		_breath_grow.curve = curve
	return _breath_grow

static func _fire_breath_ramp() -> GradientTexture1D:
	## White-hot at the lips, yellow, orange, a dull red and gone: brighter than white in the red
	## and green, so it blooms rather than reading as paint.
	if _breath_fire == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(2.2, 1.8, 1.1, 0.0))
		gradient.set_color(1, Color(0.35, 0.06, 0.02, 0.0))
		gradient.add_point(0.06, Color(2.2, 1.6, 0.8, 0.9))
		gradient.add_point(0.3, Color(1.9, 0.8, 0.2, 0.75))
		gradient.add_point(0.65, Color(1.1, 0.28, 0.06, 0.45))
		_breath_fire = GradientTexture1D.new()
		_breath_fire.use_hdr = true
		_breath_fire.gradient = gradient
	return _breath_fire

static func sparkle_quad() -> QuadMesh:
	## A camera-facing glint for splinters of light.
	if _sparkle_quad == null:
		var m := glow_material().duplicate() as StandardMaterial3D
		m.albedo_texture = sparkle_texture()
		_sparkle_quad = QuadMesh.new()
		_sparkle_quad.size = Vector2.ONE
		_sparkle_quad.material = m
	return _sparkle_quad

func breath(from: Vector3, to: Vector3, kind: String, color: Color, seconds: float = 0.5, size: float = 1.0) -> Node3D:
	## A stream poured from a mouth at the party: fire, splinters of crystal, fog, spores, water,
	## steam, light. The node can be turned to follow the mouth as the head moves; what has
	## already left it flies on (world space).
	var node := Node3D.new()
	add_child(node)
	if from.distance_to(to) > 0.01:
		node.look_at_from_position(from, to, _up_for(to - from))
	else:
		node.position = from
	var reach: float = maxf(1.0, from.distance_to(to))
	var life: float = {"fog": 0.75, "spores": 0.8, "steam": 0.7, "water": 0.5}.get(kind, 0.62)
	var speed: float = reach / life
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.05 * size
	m.direction = Vector3(0, 0, -1)
	m.spread = {"fog": 13.0, "spores": 14.0, "steam": 12.0, "water": 6.0}.get(kind, 8.0)
	m.initial_velocity_min = speed * 0.8
	m.initial_velocity_max = speed * 1.1
	m.gravity = Vector3(0, -6.0, 0) if kind == "water" else Vector3.ZERO
	var big: float = {"fog": 1.6, "spores": 1.3, "steam": 1.4, "water": 0.35, "crystal": 0.9, "light": 0.8}.get(kind, 1.0)
	m.scale_min = 0.32 * size * big
	m.scale_max = 0.55 * size * big
	m.scale_curve = _breath_curve()
	if kind in ["fog", "spores"]:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 0.6
		m.turbulence_noise_scale = 1.6
	var mesh: Mesh = quad(true)
	match kind:
		"fire":
			m.color_ramp = _fire_breath_ramp()
		"crystal", "light":
			## A stream of the creature's own light; a crystal breath glints with splinters too.
			m.color_ramp = burst_ramp(color.lightened(0.15))
		"water":
			m.color_ramp = fade_ramp(color.lightened(0.3), 0.9, 0.05)
			mesh = _stretched_quad()
		_:
			## Fog, spores, steam, smoke: soft clouds that darken as well as lighten.
			m.color_ramp = fade_ramp(color, 0.55 if kind != "spores" else 0.7, 0.12)
			mesh = quad(false)
	var p := GPUParticles3D.new()
	p.process_material = keep("breath_" + kind, m)
	p.draw_pass_1 = mesh
	p.amount = _amount(int({"fog": 36, "spores": 40, "steam": 34, "water": 60, "crystal": 70, "light": 50}.get(kind, 100) * clampf(seconds / 0.5, 0.6, 1.6)))
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -reach - 3.0), Vector3(8, 8, reach + 6.0))
	node.add_child(p)
	p.emitting = true
	if kind == "fire":
		## Embers thrown off the stream, and the light it casts on the room as it pours.
		var e := ParticleProcessMaterial.new()
		e.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.08 * size
		e.direction = Vector3(0, 0, -1)
		e.spread = 16.0
		e.initial_velocity_min = speed * 0.5
		e.initial_velocity_max = speed * 0.9
		e.gravity = Vector3(0, -2.0, 0)
		e.scale_min = 0.03 * size
		e.scale_max = 0.06 * size
		e.scale_curve = shrink_curve()
		e.color_ramp = burst_ramp(Color("ff9a40"))
		var embers := GPUParticles3D.new()
		embers.process_material = keep("breath_embers", e)
		embers.draw_pass_1 = quad(true)
		embers.amount = _amount(24)
		embers.lifetime = life * 1.3
		embers.local_coords = false
		embers.visibility_aabb = p.visibility_aabb
		node.add_child(embers)
		embers.emitting = true
	if kind == "crystal":
		## Glints riding the stream.
		var g := ParticleProcessMaterial.new()
		g.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		g.emission_sphere_radius = 0.1 * size
		g.direction = Vector3(0, 0, -1)
		g.spread = 12.0
		g.initial_velocity_min = speed * 0.7
		g.initial_velocity_max = speed * 1.05
		g.gravity = Vector3.ZERO
		g.angle_min = 0.0
		g.angle_max = 90.0
		g.scale_min = 0.22 * size
		g.scale_max = 0.4 * size
		g.scale_curve = _twinkle_curve()
		g.color_ramp = burst_ramp(color.lightened(0.5))
		var glints := GPUParticles3D.new()
		glints.process_material = keep("breath_glints", g)
		glints.draw_pass_1 = sparkle_quad()
		glints.amount = _amount(40)
		glints.lifetime = life
		glints.local_coords = false
		glints.visibility_aabb = p.visibility_aabb
		node.add_child(glints)
		glints.emitting = true
	if kind in ["fire", "crystal", "light"]:
		var light := OmniLight3D.new()
		light.light_color = Color("ff9a40") if kind == "fire" else color
		light.light_energy = 3.5
		light.omni_range = 4.0 * size
		light.shadow_enabled = false
		light.position = Vector3(0, 0, -0.6)
		node.add_child(light)
		var glow := light.create_tween()
		glow.tween_property(light, "light_energy", 0.0, seconds + 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if kind == "crystal":
		_splinters(from, to, color, int(8 * clampf(size, 0.6, 1.6)), seconds)
	var tree := get_tree()
	if tree != null:
		var held: WeakRef = weakref(node)
		tree.create_timer(seconds, false).timeout.connect(func() -> void:
			var still: Node3D = held.get_ref() as Node3D
			if still != null:
				for child in still.get_children():
					if child is GPUParticles3D:
						(child as GPUParticles3D).emitting = false)
		## Freed on the clock, seen or not.
		tree.create_timer(seconds + life * 1.4 + 1.0, false).timeout.connect(node.queue_free)
	return node

func _splinters(from: Vector3, to: Vector3, color: Color, count: int, seconds: float) -> void:
	## Real faceted splinters flying down a crystal breath, turning as they go.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.15
	m.metallic = 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	m.rim_enabled = true
	var across: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for i in range(_amount(count)):
		var piece := MeshInstance3D.new()
		piece.mesh = Lowpoly.shard(rng, color.lightened(0.3), rng.randf_range(0.07, 0.14))
		piece.material_override = m
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.position = from
		add_child(piece)
		var miss: Vector3 = across * rng.randf_range(-0.7, 0.7) + Vector3(0, rng.randf_range(-0.4, 0.4), 0)
		var spin := Vector3(rng.randf_range(-14, 14), rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		var start: float = rng.randf_range(0.0, maxf(0.05, seconds - 0.2))
		var flight: float = rng.randf_range(0.28, 0.4)
		var tween := piece.create_tween()
		piece.visible = false
		tween.tween_interval(start)
		tween.tween_callback(func() -> void: piece.visible = true)
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(piece):
				piece.position = from.lerp(to + miss, t)
				piece.rotation = spin * t
				piece.scale = Vector3.ONE * (0.6 + 0.6 * t) * (1.0 - smoothstep(0.85, 1.0, t)), 0.0, 1.0, flight)
		tween.tween_callback(piece.queue_free)
	var fade := create_tween()
	fade.tween_interval(seconds + 0.5)
	fade.tween_property(m, "emission_energy_multiplier", 0.0, 0.2)

func splat(at: Vector3, color: Color, kind: String = "glob") -> void:
	## Where a spat glob lands: a burst of it, in its own kind.
	match kind:
		"fire", "molten":
			sparks(at, Color("ff9a40"), 30, 4.0, 0.6, 0.06)
			glow_burst(at, Color("ff8a30"), 0.45, 0.3)
		"web":
			puff(at, Color("e8e4dc"), 10, 0.6, 0.8, 0.2, true)
		_:
			puff(at, color, 10, 0.55, 0.8, 0.3, true)
			bubbles(at, color, 12, 0.4, 0.8)

func zap(from: Vector3, to: Vector3, color: Color, seconds: float = 0.35) -> void:
	## A bolt of lightning: a jagged line that crackles into new shapes as it holds.
	var node := Node3D.new()
	add_child(node)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.5), 1.0)
	var steps: int = 8
	var pieces: Array = []
	for i in range(steps):
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.0)
		piece.mesh = box
		piece.material_override = m
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(piece)
		pieces.append(piece)
	var across: Vector3 = (to - from).cross(Vector3.UP).normalized()
	var lay := func() -> void:
		var points: Array = [from]
		for i in range(1, steps):
			var k: float = float(i) / float(steps)
			var swing: float = 0.35 * sin(k * PI)
			points.append(from.lerp(to, k) + across * randf_range(-swing, swing) + Vector3(0, randf_range(-swing, swing), 0))
		points.append(to)
		for i in range(steps):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var piece: MeshInstance3D = pieces[i]
			if is_instance_valid(piece) and a.distance_to(b) > 0.001:
				piece.look_at_from_position((a + b) * 0.5, b, _up_for(b - a))
				piece.scale = Vector3(1, 1, a.distance_to(b))
	lay.call()
	var tween := node.create_tween()
	for i in range(3):
		tween.tween_interval(seconds / 4.0)
		tween.tween_callback(lay)
	tween.tween_property(m, "albedo_color:a", 0.0, seconds / 4.0)
	tween.tween_callback(node.queue_free)
	flash(from, color, 4.0, 4.0, seconds, 0.8)
	glow_burst(to, color, 0.45, 0.25)

func jet(at: Vector3, color: Color, amount: int = 30, speed: float = 5.0, spread: float = 20.0, lifetime: float = 0.9, size: float = 0.07) -> void:
	## Hot points thrown straight up and falling back: a crater spitting.
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = Vector3.UP
	m.spread = spread
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -7.0, 0)
	m.scale_min = size * 0.6
	m.scale_max = size * 1.4
	m.scale_curve = shrink_curve()
	m.color_ramp = burst_ramp(color)
	_burst(at, amount, lifetime, keep("jet", m), quad(true))

func erupt(at: Vector3, color: Color = Color("ff7a2a"), size: float = 1.0) -> void:
	## A volcano going off: fire out of the crater, molten points and rock thrown high, smoke.
	flames(at, 1.1 * size, 1.1)
	flames(at + Vector3(0, 0.6 * size, 0), 0.8 * size, 0.9)
	jet(at, color, 90, 5.0 * size, 22.0, 1.3, 0.13 * size)
	jet(at, Color("ffd080"), 50, 3.2 * size, 35.0, 1.0, 0.08 * size)
	shards(at, Color("3a2420"), 14, 5.0 * size, 0.13 * size, 1.2)
	glow_burst(at, color, 1.6 * size, 0.5)
	flash(at, color, 9.0, 10.0, 0.7, 1.6)
	puff(at + Vector3(0, 0.7 * size, 0), Color(0.18, 0.15, 0.14), 18, 1.2 * size, 2.0, 1.6)

func swipe(centre: Vector3, axis: Vector3, start: Vector3, radius: float, sweep: float, color: Color, seconds: float = 0.28) -> void:
	## The arc a claw or a blade cut through the air: bright at its leading end, trailing off.
	var normal: Vector3 = axis.normalized()
	var from_dir: Vector3 = (start - normal * start.dot(normal)).normalized()
	if from_dir.is_zero_approx():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 20
	var width: float = radius * 0.22
	var rows: Array = []
	for i in range(steps + 1):
		var k: float = float(i) / float(steps)
		var dir: Vector3 = from_dir.rotated(normal, deg_to_rad(sweep) * k)
		var w: float = width * sin(k * PI) * (0.4 + 0.6 * k)
		rows.append([centre + dir * (radius - w * 0.5), centre + dir * (radius + w * 0.5), Color(color.lightened(0.5), k * k)])
	for i in range(steps):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for corner in [[a[0], a[2]], [a[1], a[2]], [b[1], b[2]], [a[0], a[2]], [b[1], b[2]], [b[0], b[2]]]:
			surface.set_color(corner[1])
			surface.add_vertex(corner[0])
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var tween := node.create_tween()
	tween.tween_property(m, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)

func ripple(at: Vector3, facing: Vector3, color: Color, radius: float = 1.4, seconds: float = 0.6) -> void:
	## A ring of sound or force rolling out toward the party: a wail, a song, a hum.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.look_at_from_position(at, at + facing, _up_for(facing))
	var ring := MeshInstance3D.new()
	ring.mesh = Lowpoly.ring(1.0, 0.07, 40)
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color.lightened(0.3), 0.9)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(ring)
	pivot.scale = Vector3.ONE * 0.2 * radius
	var tween := pivot.create_tween().set_parallel(true)
	tween.tween_property(pivot, "scale", Vector3.ONE * radius, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "position", at + facing.normalized() * radius * 0.8, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(m, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pivot.queue_free)

static func haze(kind: String, color: Color, size: float = 1.0) -> GPUParticles3D:
	## What hangs about a creature all the time, following it: a clouder's fog, the smoke off a
	## dragon's nostrils, the lava bubbling in a crater, the sparks crawling on an eel.
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	var mesh: Mesh = quad(true)
	match kind:
		"fog":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.75 * size
			m.direction = Vector3.UP
			m.spread = 180.0
			m.initial_velocity_min = 0.03
			m.initial_velocity_max = 0.15
			m.gravity = Vector3(0, -0.02, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.25
			m.turbulence_noise_scale = 1.2
			m.scale_min = 0.55 * size
			m.scale_max = 1.0 * size
			m.scale_curve = swell_curve()
			m.color_ramp = fade_ramp(color, 0.3, 0.25)
			mesh = quad(false)
			p.amount = 26
			p.lifetime = 3.0
			p.local_coords = true
			p.preprocess = 1.5
		"smoke":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.05 * size
			m.direction = Vector3.UP
			m.spread = 14.0
			m.initial_velocity_min = 0.25 * size
			m.initial_velocity_max = 0.5 * size
			m.gravity = Vector3(0, 0.08, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.3
			m.scale_min = 0.12 * size
			m.scale_max = 0.24 * size
			m.scale_curve = swell_curve()
			m.color_ramp = fade_ramp(color, 0.4, 0.2)
			mesh = quad(false)
			p.amount = 10
			p.lifetime = 2.0
			p.local_coords = false
		"bubbling":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.2 * size
			m.direction = Vector3.UP
			m.spread = 28.0
			m.initial_velocity_min = 0.9 * size
			m.initial_velocity_max = 1.9 * size
			m.gravity = Vector3(0, -5.0, 0)
			m.scale_min = 0.05 * size
			m.scale_max = 0.12 * size
			m.scale_curve = swell_curve()
			m.color_ramp = burst_ramp(color)
			p.amount = 12
			p.lifetime = 0.8
			p.local_coords = false
		"crackle":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.1 * size
			m.direction = Vector3.UP
			m.spread = 180.0
			m.initial_velocity_min = 0.4
			m.initial_velocity_max = 1.4
			m.gravity = Vector3.ZERO
			m.damping_min = 2.0
			m.damping_max = 4.0
			m.scale_min = 0.03 * size
			m.scale_max = 0.07 * size
			m.scale_curve = shrink_curve()
			m.color_ramp = burst_ramp(color)
			mesh = _stretched_quad()
			p.amount = 8
			p.lifetime = 0.28
			p.randomness = 1.0
			p.local_coords = false
		"embers":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.15 * size
			m.direction = Vector3.UP
			m.spread = 20.0
			m.initial_velocity_min = 0.4 * size
			m.initial_velocity_max = 0.9 * size
			m.gravity = Vector3(0, 0.3, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.8
			m.scale_min = 0.03 * size
			m.scale_max = 0.06 * size
			m.scale_curve = shrink_curve()
			m.color_ramp = burst_ramp(color)
			p.amount = 10
			p.lifetime = 1.4
			p.local_coords = false
		"spores":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = 0.4 * size
			m.direction = Vector3.UP
			m.spread = 60.0
			m.initial_velocity_min = 0.08
			m.initial_velocity_max = 0.25
			m.gravity = Vector3(0, 0.05, 0)
			m.turbulence_enabled = true
			m.turbulence_noise_strength = 0.4
			m.scale_min = 0.03 * size
			m.scale_max = 0.06 * size
			m.color_ramp = fade_ramp(color, 0.9, 0.2)
			p.amount = 12
			p.lifetime = 2.4
			p.local_coords = false
		_:
			return null
	p.process_material = keep("haze_" + kind, m)
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-3, -2, -3) * maxf(size, 1.0), Vector3(6, 6, 6) * maxf(size, 1.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true
	return p
