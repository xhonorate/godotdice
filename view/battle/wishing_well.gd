extends Node3D
## The wishing well: a brick ring with black water in it, two posts and a crossbeam, and a
## bucket on a rope that never quite stops swinging.
##
## The same node stands in the shaft's well room and beside the lift at every landing, so the
## thing the player throws a stone down is always the same thing. It knows nothing of what
## the well is worth or what it gives back: it is told to swallow something and, a moment
## later, how loudly to answer, from a single bubble to a column of light.

const Lowpoly = preload("res://view/battle/lowpoly.gd")

## Bricks around the ring, and how far across it is.
const BRICKS: int = 16
const RADIUS: float = 1.15
const RIM: float = 0.95

## How loud each rung of the well's ladder is: how many sparks go up, how far, and in what
## colour. Index is the `tier` a result carries, 0 (nothing) to 4 (a jackpot).
const ANSWERS: Array = [
	{"sparks": 10, "reach": 1.4, "light": 0.8, "seconds": 0.5, "tone": Color("6b7a86")},
	{"sparks": 26, "reach": 2.6, "light": 2.0, "seconds": 0.9, "tone": Color("9fd0e8")},
	{"sparks": 55, "reach": 4.2, "light": 3.6, "seconds": 1.3, "tone": Color("8fe0c8")},
	{"sparks": 110, "reach": 6.5, "light": 6.0, "seconds": 1.8, "tone": Color("ffd489")},
	{"sparks": 220, "reach": 10.0, "light": 11.0, "seconds": 2.6, "tone": Color("fff1b8")},
]

var _water: MeshInstance3D
var _water_material: StandardMaterial3D
var _bucket: Node3D
var _glow: OmniLight3D
var _beam: SpotLight3D
var _ripple: float = 0.0
var _clock: float = 0.0
var _rest_light: float = 0.55
var _hot: float = 0.0

func build(seed_value: int, tone: Color = Color("6fb7d8")) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.92
	## The ring: bricks laid round twice, the upper course offset half a brick so the joints
	## do not line up. Each one is jittered, so no two read as the same block.
	for course in range(2):
		var lift: float = 0.16 + float(course) * 0.3
		var turn: float = (PI / float(BRICKS)) * float(course)
		for index in range(BRICKS):
			var angle: float = TAU * float(index) / float(BRICKS) + turn
			var brick := MeshInstance3D.new()
			brick.mesh = Lowpoly.slab(Vector3(0.42, 0.3, 0.3), Lowpoly.shade(Color("7c7369"), rng, 0.16), rng, 0.05)
			brick.material_override = rock
			brick.position = Vector3(cos(angle) * RADIUS, lift, sin(angle) * RADIUS)
			brick.rotation.y = -angle
			add_child(brick)
	## A lip of flatter stone round the top, and the water a little way down inside it.
	var lip := MeshInstance3D.new()
	lip.mesh = Lowpoly.ring(RADIUS + 0.06, 0.34, 40)
	lip.material_override = _plain(Color("8b8277"), 0.85)
	lip.position = Vector3(0, 0.63, 0)
	add_child(lip)
	_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RIM
	disc.bottom_radius = RIM
	disc.height = 0.04
	disc.radial_segments = 24
	_water.mesh = disc
	_water_material = _plain(Color(0.03, 0.06, 0.09), 0.1, 0.0)
	_water_material.emission_enabled = true
	_water_material.emission = tone
	_water_material.emission_energy_multiplier = 0.45
	_water.material_override = _water_material
	_water.position = Vector3(0, 0.34, 0)
	add_child(_water)
	## The frame over it, and the bucket hanging where somebody left it.
	var timber := _plain(Color("6d4a2c"), 0.95)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = Lowpoly.slab(Vector3(0.18, 2.0, 0.18), Color("6d4a2c"), rng, 0.04)
		post.material_override = timber
		post.position = Vector3(side * (RADIUS - 0.1), 1.55, 0)
		add_child(post)
	var beam_node := MeshInstance3D.new()
	beam_node.mesh = Lowpoly.slab(Vector3(2.6, 0.18, 0.2), Color("7a5432"), rng, 0.03)
	beam_node.material_override = timber
	beam_node.position = Vector3(0, 2.6, 0)
	add_child(beam_node)
	## A shallow roof, so it reads as a well from across a dark room and not as a barrel. It
	## is kept narrow and lit a shade lighter than the posts: a wide dark one reads as a slab
	## hanging in the air rather than as a roof.
	for side in [-1.0, 1.0]:
		var slope := MeshInstance3D.new()
		slope.mesh = Lowpoly.slab(Vector3(1.25, 0.09, 1.05), Color("8a6a4a"), rng, 0.03)
		slope.material_override = _plain(Color("8a6a4a"), 0.9)
		slope.position = Vector3(side * 0.5, 2.82, 0)
		slope.rotation.z = -side * 0.62
		add_child(slope)
	var winch := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.13
	barrel.bottom_radius = 0.13
	barrel.height = 1.4
	barrel.radial_segments = 8
	winch.mesh = barrel
	winch.material_override = timber
	winch.rotation = Vector3(0, 0, PI * 0.5)
	winch.position = Vector3(0, 2.42, 0)
	add_child(winch)
	_bucket = Node3D.new()
	_bucket.position = Vector3(0, 1.85, 0)
	add_child(_bucket)
	var rope := MeshInstance3D.new()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.02
	cord.bottom_radius = 0.02
	cord.height = 0.62
	cord.radial_segments = 5
	rope.mesh = cord
	rope.material_override = _plain(Color("c8b48a"), 1.0)
	rope.position = Vector3(0, 0.44, 0)
	_bucket.add_child(rope)
	var pail := MeshInstance3D.new()
	var tub := CylinderMesh.new()
	tub.top_radius = 0.24
	tub.bottom_radius = 0.19
	tub.height = 0.3
	tub.radial_segments = 9
	pail.mesh = tub
	pail.material_override = timber
	_bucket.add_child(pail)
	## Two lights: one in the water, and one hung in front and above so the ring is never
	## just more rock. The shaft is what makes it obvious the thing can be walked up to.
	_glow = OmniLight3D.new()
	_glow.light_color = tone
	_glow.light_energy = _rest_light
	_glow.omni_range = 5.0
	_glow.light_volumetric_fog_energy = 1.6
	_glow.position = Vector3(0, 0.4, 0)
	_glow.shadow_enabled = false
	add_child(_glow)
	_beam = SpotLight3D.new()
	_beam.light_color = tone.lerp(Color.WHITE, 0.45)
	_beam.light_energy = 3.0
	_beam.spot_range = 9.0
	_beam.spot_angle = 26.0
	_beam.spot_angle_attenuation = 1.0
	_beam.light_volumetric_fog_energy = 1.2
	_beam.shadow_enabled = false
	_beam.position = Vector3(0.0, 3.6, 2.6)
	_beam.rotation = Vector3(-0.78, 0.0, 0.0)
	add_child(_beam)

func _plain(color: Color, roughness: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	return m

func rest_light(energy: float) -> void:
	## How brightly it sits when nothing is happening to it.
	_rest_light = energy

func swallow(fx: Node3D) -> void:
	## Something has gone in: the water takes it, the surface breaks, and the bucket jumps on
	## its rope. Nothing here says what it was or what it will be worth.
	_ripple = 1.0
	if _bucket != null:
		var jolt := _bucket.create_tween()
		jolt.tween_property(_bucket, "position:y", 1.72, 0.12).set_trans(Tween.TRANS_QUAD)
		jolt.tween_property(_bucket, "position:y", 1.85, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if fx != null and fx.has_method("sparks"):
		fx.sparks(global_position + Vector3(0, 0.3, 0), Color("4d7f99"), 14, 1.2, 0.5, 0.05)

func answer(fx: Node3D, tier: int) -> void:
	## What came back up, said in light. A poor rung is a bubble and a shrug; the best is a
	## column out of the shaft that goes most of the way to the ceiling.
	var entry: Dictionary = ANSWERS[clampi(tier, 0, ANSWERS.size() - 1)]
	var tone: Color = entry.tone
	_ripple = 1.0
	_hot = float(entry.light)
	if _water_material != null:
		_water_material.emission = tone
	if _glow != null:
		_glow.light_color = tone
	if fx == null or not fx.has_method("sparks"):
		return
	fx.sparks(global_position + Vector3(0, 0.35, 0), tone, int(entry.sparks), float(entry.reach), float(entry.seconds), 0.02)
	## Above the first rungs it comes up in waves rather than one puff, which is what makes a
	## jackpot feel like one: it keeps going after you think it has stopped.
	for wave in range(clampi(tier, 0, 4)):
		var when: float = 0.18 * float(wave + 1)
		var delay := get_tree().create_timer(when) if get_tree() != null else null
		if delay == null:
			break
		delay.timeout.connect(func() -> void:
			if not is_instance_valid(self) or fx == null or not is_instance_valid(fx):
				return
			fx.sparks(global_position + Vector3(0, 0.35, 0), tone.lightened(0.15 * float(wave)),
				int(entry.sparks) / 2, float(entry.reach) * (0.7 + 0.2 * float(wave)), float(entry.seconds), 0.02))

func _process(delta: float) -> void:
	_clock += delta
	_ripple = maxf(0.0, _ripple - delta * 1.1)
	_hot = maxf(0.0, _hot - delta * 2.2)
	if _water != null:
		## The surface never settles: it breathes, and it heaves when something has gone in.
		var swell: float = 1.0 + 0.02 * sin(_clock * 1.4) + 0.06 * _ripple * sin(_clock * 22.0)
		_water.scale = Vector3(swell, 1.0, swell)
		_water.position.y = 0.34 - 0.05 * _ripple
	if _water_material != null:
		_water_material.emission_energy_multiplier = 0.45 + 0.6 * _ripple + _hot * 0.35
	if _bucket != null:
		_bucket.rotation.z = 0.05 * sin(_clock * 1.1)
	if _glow != null:
		_glow.light_energy = _rest_light + 1.4 * _ripple + _hot
	if _beam != null:
		_beam.light_energy = 3.0 * (1.0 + 0.07 * sin(_clock * 1.6)) + _hot * 0.6
