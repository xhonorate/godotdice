extends Node3D
## A landing, and the shaft head: four things to walk up to, spread across the room so that
## none of them stands behind another and each is turned to face where the party comes in. A
## campfire to rest by, a workbench with a lamp and a lens to read a stone at, a grinding
## wheel to cut one again on, and the lift in its cage, its cable running up into a warm
## light. The cage is one of the four, not a step after them. The way down is the mouths in
## the far wall, as in any room.
##
## In room space (it sits at the room's origin). It shows what it is told: which respite is
## taken, what is pointed at, and when the cage goes up.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")

## The four things a landing offers, set out so that from where the party stands none of them
## is behind another: the fire away to the left, the bench deeper and a little right of the
## lane the party walks, the wheel well right and much nearer, and the cage furthest left and
## deepest of all. Each is a good many degrees off its neighbours across the view.
const CAGE := Vector3(-7.0, 0.0, -12.0)
const CAMPFIRE := Vector3(-3.6, 0.0, -2.0)
const BENCH := Vector3(2.4, 0.0, -5.2)
const WHEEL := Vector3(4.8, 0.0, -1.6)
const SHAFT_TOP := 9.5

## Where each thing is, to point at: name -> node.
var parts: Dictionary = {}
var cage: Node3D
var _fire_light: OmniLight3D
var _flame: GPUParticles3D
var _bench_lamp: OmniLight3D
var _wheel_stone: Node3D
var _sky: SpotLight3D
var _glows: Dictionary = {}
## The shaft of light over each thing that can be used, so it is never just more rock.
var _beams: Dictionary = {}
var _labels: Dictionary = {}
var _hover: String = ""
var _taken: String = ""
## What can be done here now: their names show faintly without pointing at them.
var _offered: Array = []
var _respites: bool = true
var _clock: float = 0.0
var _spin: float = 0.0

func build(biome: Dictionary, seed_value: int, respites: bool, daylight: bool, ground: Callable) -> void:
	_respites = respites
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_cage(rng, daylight, ground)
	if respites:
		_build_campfire(rng, biome, ground)
		_build_bench(rng, ground)
		_build_wheel(rng, ground)

func _material(color: Color, roughness: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	return m

func _slab(parent: Node3D, size: Vector3, color: Color, at: Vector3, material: Material, rng: RandomNumberGenerator, jitter: float = 0.02) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Lowpoly.slab(size, color, rng, jitter)
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _label(parent: Node3D, key: String, text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = DeepUi.display_font()
	label.font_size = 44
	label.pixel_size = 0.0045
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.modulate = Color(color, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	parent.add_child(label)
	_labels[key] = label

func _glow(parent: Node3D, key: String, color: Color, at: Vector3, reach: float = 2.4) -> void:
	## Two lights on everything that can be used: a lamp in it, and a shaft from above that
	## picks it out of the dark whether or not the pointer is anywhere near. A thing that
	## cannot be told from the rock beside it is a thing nobody knows they may use.
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = reach
	light.position = at
	light.shadow_enabled = false
	parent.add_child(light)
	_glows[key] = light
	## Hung in front of the thing and above it, not straight over it: a light from the ceiling
	## grazes a flat face and leaves it as black as the rock. This one is in the hall's own
	## space, so whichever way the thing under it has been turned makes no difference.
	var beam := SpotLight3D.new()
	beam.light_color = color.lerp(Color.WHITE, 0.4)
	beam.light_energy = 0.0
	beam.spot_range = 9.0
	beam.spot_angle = 27.0
	beam.spot_angle_attenuation = 1.0
	beam.light_volumetric_fog_energy = 1.2
	beam.shadow_enabled = false
	beam.position = parent.position + Vector3(0.0, 3.3, 2.7)
	beam.rotation = Vector3(-0.72, 0.0, 0.0)
	add_child(beam)
	_beams[key] = beam

# --- the lift ------------------------------------------------------------------------------------

func _build_cage(rng: RandomNumberGenerator, daylight: bool, ground: Callable) -> void:
	var foot: float = float(ground.call(CAGE.x, CAGE.z)) if ground.is_valid() else 0.0
	var iron := _material(Color("4a4c52"), 0.5, 0.75)
	iron.vertex_color_use_as_albedo = true
	var timber := _material(Color("6a4428"), 0.95)
	timber.vertex_color_use_as_albedo = true
	## The shaft: guide rails and cross timbers up into the dark, and the light at the top.
	var shaft := Node3D.new()
	shaft.position = Vector3(CAGE.x, foot, CAGE.z)
	add_child(shaft)
	for side in [-1.0, 1.0]:
		_slab(shaft, Vector3(0.18, SHAFT_TOP, 0.18), Color("5a3a22"), Vector3(side * 1.45, SHAFT_TOP * 0.5, -1.35), timber, rng)
		_slab(shaft, Vector3(0.18, SHAFT_TOP, 0.18), Color("5a3a22"), Vector3(side * 1.45, SHAFT_TOP * 0.5, 1.35), timber, rng)
	for y in [3.6, 6.2, 8.8]:
		_slab(shaft, Vector3(3.1, 0.16, 0.16), Color("4a3020"), Vector3(0, y, -1.35), timber, rng)
		_slab(shaft, Vector3(0.16, 0.16, 2.9), Color("4a3020"), Vector3(-1.45, y, 0), timber, rng)
	_sky = SpotLight3D.new()
	_sky.light_color = Color("fff4dc") if daylight else Color("ffd49a")
	_sky.light_energy = 7.0 if daylight else 4.0
	_sky.spot_range = SHAFT_TOP + 3.0
	_sky.spot_angle = 26.0
	_sky.light_volumetric_fog_energy = 5.0 if daylight else 3.0
	_sky.shadow_enabled = false
	_sky.position = Vector3(0, SHAFT_TOP + 0.5, 0)
	_sky.rotation = Vector3(-PI * 0.5, 0, 0)
	shaft.add_child(_sky)
	var glare := Sprite3D.new()
	glare.texture = DeepUi.glow_texture()
	glare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glare.shaded = false
	glare.pixel_size = 3.2 / 64.0
	glare.modulate = Color(_sky.light_color, 0.75)
	glare.position = Vector3(0, SHAFT_TOP - 0.3, 0)
	shaft.add_child(glare)
	## The cage.
	cage = Node3D.new()
	cage.position = Vector3(CAGE.x, foot, CAGE.z)
	add_child(cage)
	_slab(cage, Vector3(2.5, 0.16, 2.5), Color("3a3430"), Vector3(0, 0.08, 0), iron, rng)
	_slab(cage, Vector3(2.5, 0.12, 2.5), Color("3a3430"), Vector3(0, 2.9, 0), iron, rng)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_slab(cage, Vector3(0.1, 2.85, 0.1), Color("5a5c62"), Vector3(corner.x * 1.2, 1.48, corner.y * 1.2), iron, rng, 0.0)
	## Bars on three sides; the side facing the room is the gate, open.
	for i in range(1, 6):
		var t: float = -1.2 + 2.4 * float(i) / 6.0
		_slab(cage, Vector3(0.04, 2.8, 0.04), Color("5a5c62"), Vector3(t, 1.48, -1.2), iron, rng, 0.0)
		_slab(cage, Vector3(0.04, 2.8, 0.04), Color("5a5c62"), Vector3(-1.2, 1.48, t), iron, rng, 0.0)
		_slab(cage, Vector3(0.04, 2.8, 0.04), Color("5a5c62"), Vector3(t, 1.48, 1.2), iron, rng, 0.0)
	_slab(cage, Vector3(2.5, 0.06, 0.06), Color("5a5c62"), Vector3(0, 1.4, -1.2), iron, rng, 0.0)
	_slab(cage, Vector3(0.06, 0.06, 2.5), Color("5a5c62"), Vector3(-1.2, 1.4, 0), iron, rng, 0.0)
	var cable := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.035
	line.bottom_radius = 0.035
	line.height = SHAFT_TOP
	line.radial_segments = 6
	cable.mesh = line
	cable.material_override = _material(Color("8a8f98"), 0.4, 0.8)
	cable.position = Vector3(0, 2.96 + SHAFT_TOP * 0.5, 0)
	cage.add_child(cable)
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.28, 0.2)
	lamp.mesh = box
	var glass := _material(Color("ffb060"), 0.3)
	glass.emission_enabled = true
	glass.emission = Color("ffb060")
	glass.emission_energy_multiplier = 3.0
	lamp.material_override = glass
	lamp.position = Vector3(0.9, 2.6, 0.9)
	cage.add_child(lamp)
	var inside := OmniLight3D.new()
	inside.light_color = Color("ffc890")
	inside.light_energy = 1.4
	inside.omni_range = 4.0
	inside.position = Vector3(0.6, 2.3, 0.6)
	inside.shadow_enabled = false
	cage.add_child(inside)
	_glow(cage, "up", Color("ffe0a0"), Vector3(1.6, 1.6, 0.6), 4.0)
	_label(cage, "up", "Up: the lift", Vector3(0, 3.5, 0.4), Color("ffe0a0"))
	parts["up"] = cage

# --- the respites --------------------------------------------------------------------------------

func _build_campfire(rng: RandomNumberGenerator, biome: Dictionary, ground: Callable) -> void:
	var fire := Node3D.new()
	fire.position = CAMPFIRE + Vector3(0, float(ground.call(CAMPFIRE.x, CAMPFIRE.z)) if ground.is_valid() else 0.0, 0)
	add_child(fire)
	var stone := _material(Color("6a625a"), 0.9)
	stone.vertex_color_use_as_albedo = true
	for i in range(9):
		var angle: float = TAU * float(i) / 9.0
		var rock := MeshInstance3D.new()
		rock.mesh = Lowpoly.rock(rng, Color(biome.get("rock", Color("6a625a"))).lightened(0.15), 0.3, Vector3(1.0, 0.7, 1.0))
		rock.material_override = stone
		rock.scale = Vector3.ONE * rng.randf_range(0.16, 0.22)
		rock.position = Vector3(cos(angle) * 0.62, 0.1, sin(angle) * 0.62)
		fire.add_child(rock)
	var wood := _material(Color("4a3020"), 0.95)
	wood.vertex_color_use_as_albedo = true
	for i in range(3):
		var log_node := _slab(fire, Vector3(0.12, 0.12, 0.9), Color("5a3a22"), Vector3(0, 0.12, 0), wood, rng)
		log_node.rotation = Vector3(0.25, TAU * float(i) / 3.0, 0)
	_flame = GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.22
	m.direction = Vector3.UP
	m.spread = 12.0
	m.initial_velocity_min = 0.7
	m.initial_velocity_max = 1.4
	m.gravity = Vector3(0, 0.9, 0)
	m.scale_min = 0.25
	m.scale_max = 0.5
	m.scale_curve = BattleFx.shrink_curve()
	m.color_ramp = BattleFx.burst_ramp(Color("ff7a2a"))
	_flame.process_material = m
	_flame.draw_pass_1 = BattleFx.quad(true)
	_flame.amount = 44
	_flame.lifetime = 0.9
	_flame.position = Vector3(0, 0.25, 0)
	fire.add_child(_flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("ff9a4a")
	_fire_light.light_energy = 2.2
	_fire_light.omni_range = 6.0
	_fire_light.light_volumetric_fog_energy = 1.2
	_fire_light.position = Vector3(0, 0.9, 0)
	_fire_light.shadow_enabled = false
	fire.add_child(_fire_light)
	_glow(fire, "rest", Color("ffb066"), Vector3(0, 0.8, 0.5), 3.0)
	_label(fire, "rest", "Rest", Vector3(0, 1.35, 0), DeepUi.GOOD)
	parts["rest"] = fire

func _build_bench(rng: RandomNumberGenerator, ground: Callable) -> void:
	var bench := Node3D.new()
	bench.position = BENCH + Vector3(0, float(ground.call(BENCH.x, BENCH.z)) if ground.is_valid() else 0.0, 0)
	## Turned to face where the party stands, so the lamp, the lens and the stone under them
	## are all on the side the party sees.
	bench.rotation.y = -0.23
	add_child(bench)
	var wood := _material(Color("7a5030"), 0.9)
	wood.vertex_color_use_as_albedo = true
	_slab(bench, Vector3(1.9, 0.1, 0.9), Color("8a5c36"), Vector3(0, 0.95, 0), wood, rng)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_slab(bench, Vector3(0.1, 0.92, 0.1), Color("5a3a22"), Vector3(corner.x * 0.82, 0.46, corner.y * 0.36), wood, rng)
	## A lamp on a crook, a lens on a stand, and a rough stone waiting under them.
	var post := _slab(bench, Vector3(0.06, 1.0, 0.06), Color("3a3430"), Vector3(-0.6, 1.5, -0.3), _material(Color("3a3430"), 0.5, 0.6), rng, 0.0)
	post.rotation.z = 0.1
	var lamp := MeshInstance3D.new()
	var shade := CylinderMesh.new()
	shade.top_radius = 0.06
	shade.bottom_radius = 0.18
	shade.height = 0.16
	shade.radial_segments = 8
	lamp.mesh = shade
	var brass := _material(Color("c9a26b"), 0.35, 0.8)
	lamp.material_override = brass
	lamp.position = Vector3(-0.35, 1.98, -0.25)
	bench.add_child(lamp)
	_bench_lamp = OmniLight3D.new()
	_bench_lamp.light_color = Color("fff0d0")
	_bench_lamp.light_energy = 1.6
	_bench_lamp.omni_range = 3.2
	_bench_lamp.position = Vector3(-0.3, 1.75, -0.15)
	_bench_lamp.shadow_enabled = false
	bench.add_child(_bench_lamp)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.13
	torus.rings = 14
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = brass
	ring.position = Vector3(0.35, 1.3, 0.05)
	ring.rotation = Vector3(PI * 0.5 - 0.4, 0, 0)
	bench.add_child(ring)
	var rough := MeshInstance3D.new()
	rough.mesh = Lowpoly.rock(rng, Color("8d8479"), 0.3)
	rough.material_override = _material(Color.WHITE, 0.6)
	(rough.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	rough.scale = Vector3.ONE * 0.11
	rough.position = Vector3(0.35, 1.06, 0.05)
	bench.add_child(rough)
	_glow(bench, "appraise", DeepUi.INFO, Vector3(0.2, 1.6, 0.7))
	_label(bench, "appraise", "Appraise", Vector3(0, 2.25, 0), DeepUi.INFO)
	parts["appraise"] = bench

func _build_wheel(rng: RandomNumberGenerator, ground: Callable) -> void:
	var frame := Node3D.new()
	frame.position = WHEEL + Vector3(0, float(ground.call(WHEEL.x, WHEEL.z)) if ground.is_valid() else 0.0, 0)
	## The same: turned until the face of the grinding stone, not its edge, is toward the party.
	frame.rotation.y = 0.96
	add_child(frame)
	var wood := _material(Color("8a5c34"), 0.9)
	wood.vertex_color_use_as_albedo = true
	for side in [-1.0, 1.0]:
		var leg := _slab(frame, Vector3(0.12, 1.3, 0.12), Color("7a4c2c"), Vector3(side * 0.28, 0.62, 0.22), wood, rng)
		leg.rotation.x = 0.3
		var back := _slab(frame, Vector3(0.12, 1.3, 0.12), Color("7a4c2c"), Vector3(side * 0.28, 0.62, -0.22), wood, rng)
		back.rotation.x = -0.3
	_slab(frame, Vector3(0.8, 0.3, 0.6), Color("6a5648"), Vector3(0, 0.15, 0), _material(Color("6a5648"), 0.9), rng)
	_wheel_stone = Node3D.new()
	_wheel_stone.position = Vector3(0, 1.12, 0)
	frame.add_child(_wheel_stone)
	var disc := MeshInstance3D.new()
	var stone := CylinderMesh.new()
	stone.top_radius = 0.55
	stone.bottom_radius = 0.55
	stone.height = 0.2
	stone.radial_segments = 14
	disc.mesh = stone
	disc.material_override = _material(Color("c4bdae"), 0.7)
	disc.rotation = Vector3(0, 0, PI * 0.5)
	_wheel_stone.add_child(disc)
	var axle := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.04
	rod.bottom_radius = 0.04
	rod.height = 0.8
	axle.mesh = rod
	axle.material_override = _material(Color("5a5c62"), 0.4, 0.8)
	axle.rotation = Vector3(0, 0, PI * 0.5)
	_wheel_stone.add_child(axle)
	_glow(frame, "polish", DeepUi.ACCENT, Vector3(0, 1.4, 0.9))
	_label(frame, "polish", "Cut again", Vector3(0, 2.2, 0), DeepUi.ACCENT)
	parts["polish"] = frame

# --- what the room is told -----------------------------------------------------------------------

func set_hover(key: String) -> void:
	_hover = key

func set_offered(keys: Array) -> void:
	_offered = keys

func set_taken(choice: String) -> void:
	## The respite taken: that one stays warm; the others go quiet.
	_taken = choice

func spark_wheel(fx: Node3D) -> void:
	if fx != null and parts.has("polish"):
		fx.sparks(parts.polish.global_position + Vector3(0, 1.1, 0.3), Color("ffd08a"), 40, 4.0, 0.6, 0.05)

func _process(delta: float) -> void:
	_clock += delta
	if _fire_light != null:
		var flicker: float = sin(_clock * 9.0) * 0.5 + sin(_clock * 13.7) * 0.3 + sin(_clock * 23.0) * 0.2
		_fire_light.light_energy = (2.2 if _taken in ["", "rest"] else 1.4) * (1.0 + 0.18 * flicker) * (1.3 if _hover == "rest" else 1.0)
	if _bench_lamp != null:
		_bench_lamp.light_energy = (2.4 if _hover == "appraise" else 1.6) * (1.0 if _taken in ["", "appraise"] else 0.5)
	if _wheel_stone != null:
		_spin = move_toward(_spin, 9.0 if _hover == "polish" else (0.6 if _taken in ["", "polish"] else 0.0), delta * 12.0)
		_wheel_stone.rotation.x += delta * _spin
	for key in _glows:
		var light: OmniLight3D = _glows[key]
		var on: bool = key == _hover
		light.light_energy = move_toward(light.light_energy, 2.4 if on else (0.9 if _offered.has(key) else 0.15), delta * 10.0)
	for key in _beams:
		var beam: SpotLight3D = _beams[key]
		var lit: float = 7.0 if key == _hover else (4.2 if _offered.has(key) else 0.8)
		## A breath in it, so a thing waiting to be used is never quite still.
		beam.light_energy = move_toward(beam.light_energy, lit * (1.0 + 0.06 * sin(_clock * 1.7 + float(key.length()))), delta * 6.0)
	for key in _labels:
		var label: Label3D = _labels[key]
		var shown: float = 1.0 if key == _hover else (0.5 if _offered.has(key) else 0.0)
		label.modulate.a = move_toward(label.modulate.a, shown, delta * 6.0)
		label.outline_modulate = Color(0, 0, 0, 0.85 * label.modulate.a)
