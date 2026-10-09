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

## Where the bucket hangs at rest, where it dips into the water, and where the rope leaves the
## winch, in the well's own space.
const BUCKET_REST: float = 1.85
const BUCKET_DIP: float = 0.42
const ROPE_TOP: float = 2.32
## How the bucket goes down and comes back up, in seconds: the drop, the moment it sits in the
## water while the light gathers in it, and the haul back up. See `draw_up`.
const LOWER_SECONDS: float = 0.85
const STEEP_SECONDS: float = 0.4
const RAISE_SECONDS: float = 0.8

var _water: MeshInstance3D
var _water_material: StandardMaterial3D
var _bucket: Node3D
var _rope: MeshInstance3D
var _winch: MeshInstance3D
var _bucket_light: OmniLight3D
var _glow: OmniLight3D
var _beam: SpotLight3D
var _ripple: float = 0.0
var _clock: float = 0.0
var _rest_light: float = 0.55
var _hot: float = 0.0
var _rest_tone: Color = Color("6fb7d8")
var _sequence: Tween = null

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
	_winch = MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.13
	barrel.bottom_radius = 0.13
	barrel.height = 1.4
	## Eight flats rather than a smooth drum, so it can be seen to turn as the rope pays out.
	barrel.radial_segments = 8
	_winch.mesh = barrel
	_winch.material_override = timber
	_winch.rotation = Vector3(0, 0, PI * 0.5)
	_winch.position = Vector3(0, 2.42, 0)
	add_child(_winch)
	_bucket = Node3D.new()
	_bucket.position = Vector3(0, BUCKET_REST, 0)
	add_child(_bucket)
	## The rope hangs from the winch to the bucket's handle and is as long as that is: it is
	## stretched to fit every frame, so it pays out as the bucket goes down and winds back in.
	_rope = MeshInstance3D.new()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.02
	cord.bottom_radius = 0.02
	cord.height = 1.0
	cord.radial_segments = 5
	_rope.mesh = cord
	_rope.material_override = _plain(Color("c8b48a"), 1.0)
	add_child(_rope)
	var pail := MeshInstance3D.new()
	var tub := CylinderMesh.new()
	tub.top_radius = 0.24
	tub.bottom_radius = 0.19
	tub.height = 0.3
	tub.radial_segments = 9
	pail.mesh = tub
	pail.material_override = timber
	_bucket.add_child(pail)
	## What the well sends back up comes up in the bucket, lit from inside it.
	_bucket_light = OmniLight3D.new()
	_bucket_light.light_energy = 0.0
	_bucket_light.omni_range = 3.6
	_bucket_light.light_volumetric_fog_energy = 2.0
	_bucket_light.position = Vector3(0, 0.25, 0)
	_bucket_light.shadow_enabled = false
	_bucket.add_child(_bucket_light)
	_rest_tone = tone
	_fit_rope()
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

func draw_up(fx: Node3D, tier: int) -> float:
	## Something has gone down it, and the well answers in its own time: the winch turns and the
	## bucket goes down into the water, the light gathers in it in the colour of the answer,
	## and it is hauled back up glowing, to break over the rim in sparks and light as loud as
	## the rung it landed on (see `answer`). Returns how long until it breaks, so whatever
	## shows the answer in words can wait for it.
	var entry: Dictionary = ANSWERS[clampi(tier, 0, ANSWERS.size() - 1)]
	var tone: Color = entry.tone
	var grow: float = _span()
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_hot = 0.0
	_ripple = 1.0
	if fx != null and is_instance_valid(fx) and fx.has_method("sparks"):
		fx.sparks(_water_point(), Color("4d7f99"), 14, 1.2 * grow, 0.5, 0.05)
	if _bucket == null or not is_inside_tree():
		answer(fx, tier)
		return 0.0
	_sequence = create_tween()
	## Down, the winch paying out rope.
	_sequence.tween_property(_bucket, "position:y", BUCKET_DIP, LOWER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sequence.tween_callback(func() -> void:
		_ripple = 1.0
		DeepAudio.play("gem_fizzle", {"volume": 0.45, "pitch": 0.7})
		if fx != null and is_instance_valid(fx) and fx.has_method("sparks"):
			fx.sparks(_water_point(), Color("7fb2ff"), 22, 1.6 * grow, 0.55, 0.04)
			fx.ring_wave(_water_point(), tone, 1.1 * grow, 0.6, 0.12 * grow))
	## In the water: the light gathers in the bucket, and the water takes the answer's colour.
	_sequence.tween_method(func(t: float) -> void:
		if _water_material != null:
			_water_material.emission = _rest_tone.lerp(tone, t)
		if _glow != null:
			_glow.light_color = _rest_tone.lerp(tone, t)
		_bucket_light.light_color = tone
		_bucket_light.light_energy = t * (1.2 + 0.6 * float(entry.light)), 0.0, 1.0, STEEP_SECONDS)
	## Up, the light in it climbing as it comes, with a few motes trailing it out of the dark.
	_sequence.tween_callback(func() -> void:
		if fx != null and is_instance_valid(fx) and fx.has_method("rise"):
			fx.rise(_water_point(), tone.lightened(0.3), 12 + 10 * tier, 0.6 * grow, RAISE_SECONDS + 0.6))
	_sequence.tween_property(_bucket, "position:y", BUCKET_REST + 0.12, RAISE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sequence.parallel().tween_property(_bucket_light, "light_energy", 2.5 + 1.2 * float(entry.light), RAISE_SECONDS)
	## Over the rim: the answer.
	_sequence.tween_callback(func() -> void: answer(fx, tier))
	_sequence.tween_property(_bucket, "position:y", BUCKET_REST, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sequence.parallel().tween_property(_bucket_light, "light_energy", 0.0, 1.6)
	return LOWER_SECONDS + STEEP_SECONDS + RAISE_SECONDS

func answer(fx: Node3D, tier: int) -> void:
	## What came back up, said in light, out of the bucket at the top of its haul. A poor rung
	## is a bubble and a shrug; the best is a column of light that goes most of the way to the
	## ceiling, and keeps coming in waves after it seems to have stopped.
	var entry: Dictionary = ANSWERS[clampi(tier, 0, ANSWERS.size() - 1)]
	var tone: Color = entry.tone
	var grow: float = _span()
	_ripple = 1.0
	_hot = float(entry.light)
	if _water_material != null:
		_water_material.emission = tone
	if _glow != null:
		_glow.light_color = tone
	if fx == null or not is_instance_valid(fx) or not fx.has_method("sparks"):
		return
	var at: Vector3 = _bucket_point()
	## Sparks sized for the eye, not the well: a landing's small well is seen from across the room.
	fx.sparks(at, tone, int(entry.sparks) + 12, float(entry.reach) * maxf(grow, 0.8), float(entry.seconds) + 0.2, 0.045)
	if fx.has_method("glow_burst"):
		fx.glow_burst(at, tone.lightened(0.2), (1.2 + 0.6 * float(tier)) * maxf(grow, 0.8), 0.55)
	if fx.has_method("rise"):
		fx.rise(at, tone.lightened(0.35), 14 + 12 * tier, 0.5 * maxf(grow, 0.8), 1.2 + 0.2 * float(tier))
	if fx.has_method("flash"):
		fx.flash(at, tone, 1.5 + 1.6 * float(tier), (3.0 + 1.5 * float(tier)) * grow, 0.45, 0.6 + 0.3 * float(tier))
	if tier >= 2 and fx.has_method("stars"):
		fx.stars(at + Vector3(0, 0.4 * grow, 0), tone.lightened(0.4), 1.2 + 0.2 * float(tier), 0.5 * grow)
	if tier >= 3 and fx.has_method("beam"):
		## A column of light straight up out of the shaft.
		fx.beam(at, at + Vector3(0, (4.0 + 3.0 * float(tier - 3)) * grow, 0), tone.lightened(0.35), 0.9, 0.22 * grow)
	if tier >= 3 and fx.has_method("ring_wave"):
		fx.ring_wave(_water_point() - Vector3(0, 0.3 * grow, 0), tone, (2.2 + float(tier)) * grow, 0.8, 0.3 * grow)
	if not is_inside_tree():
		return
	## Above the first rungs it comes up in waves rather than one puff, which is what makes a
	## jackpot feel like one: it keeps going after you think it has stopped.
	for wave in range(clampi(tier, 0, 4)):
		var when: float = 0.18 * float(wave + 1)
		get_tree().create_timer(when).timeout.connect(func() -> void:
			if not is_instance_valid(self) or fx == null or not is_instance_valid(fx):
				return
			fx.sparks(_bucket_point(), tone.lightened(0.15 * float(wave)),
				int(entry.sparks) / 2, float(entry.reach) * maxf(grow, 0.8) * (0.7 + 0.2 * float(wave)), float(entry.seconds), 0.045))

func _span() -> float:
	## How big the well stands in the room: a landing's is small, the well room's is large.
	return global_transform.basis.get_scale().x if is_inside_tree() else 1.0

func _water_point() -> Vector3:
	return to_global(Vector3(0, 0.36, 0)) if is_inside_tree() else global_position

func _bucket_point() -> Vector3:
	return _bucket.to_global(Vector3(0, 0.2, 0)) if _bucket != null and _bucket.is_inside_tree() else _water_point()

func _fit_rope() -> void:
	## From the winch down to the bucket's handle, however far down the bucket is.
	if _rope == null or _bucket == null:
		return
	var bottom: float = _bucket.position.y + 0.15
	var length: float = maxf(0.05, ROPE_TOP - bottom)
	_rope.scale = Vector3(1.0, length, 1.0)
	_rope.position = Vector3(_bucket.position.x, bottom + length * 0.5, _bucket.position.z)

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
		## Once the answer has gone out of it, the water slowly comes back to its own colour.
		if _hot <= 0.0 and (_sequence == null or not _sequence.is_running()):
			_water_material.emission = _water_material.emission.lerp(_rest_tone, minf(1.0, delta * 0.8))
	if _bucket != null:
		## It sways on its rope, more the further down it hangs.
		var hang: float = clampf((BUCKET_REST - _bucket.position.y) / (BUCKET_REST - BUCKET_DIP), 0.0, 1.0)
		_bucket.rotation.z = (0.05 + 0.03 * hang) * sin(_clock * 1.1)
		_fit_rope()
	if _winch != null and _bucket != null:
		## The drum turns with the rope it pays out or takes in.
		_winch.rotation = Vector3((BUCKET_REST - _bucket.position.y) * 4.6, 0.0, PI * 0.5)
	if _glow != null:
		_glow.light_energy = _rest_light + 1.4 * _ripple + _hot
		if _hot <= 0.0 and (_sequence == null or not _sequence.is_running()):
			_glow.light_color = _glow.light_color.lerp(_rest_tone, minf(1.0, delta * 0.8))
	if _beam != null:
		_beam.light_energy = 3.0 * (1.0 + 0.07 * sin(_clock * 1.6)) + _hot * 0.6
