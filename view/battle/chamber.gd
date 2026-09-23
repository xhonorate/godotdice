extends Node3D
## The room a fight happens in, cut from its biome.
##
## A floor and a vaulted shell of faceted rock, noise-displaced so no two depths share a
## wall; the biome's props scattered where they cannot stand in front of a creature; a light
## rig (the party's lantern, rim lights behind the arc, the props' own lights); drifting
## particles; and ground mist in the volumetric fog. Seeded by mine and depth, so a room is
## the same room if the party is ever back in it and different from the one above.
##
## Coordinates: the camera sits near (0, 2, 5) looking down -Z; creatures stand in an arc
## around (0, 0, -4.5). Nothing tall is placed inside the arena, and nothing at all between
## the camera and the arc.
##
## The room is a place on the way down, not only an arena. The party comes in by a tunnel at
## the near end (z = 9, behind the camera) and leaves by one of the mouths cut through the
## far wall, one for each way on. A trail is worn flat from the arena to every mouth, props
## keep off it, and each mouth already holds the first stretch of its tunnel (a stub), so it
## shows rock rather than nothing. `exits` carries each tunnel's curve and where the room it
## leads to will stand, so the walk can build the rest of it without anything moving.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const Tunnel = preload("res://view/battle/tunnel.gd")

const SHELL_RX := 12.5
const SHELL_RY := 8.0
const Z_NEAR := 9.0
const Z_FAR := -24.0
const ARENA := Vector3(0, 0, -4.5)

var biome: Dictionary = {}
## Lights the lens-flare overlay dresses: {node, color, strength, size}.
var flares: Array = []
var quality: int = 3
## The ways on: {index, x, points (the tunnel's floor curve, room space), origin (where the
## next room stands), seed, drop, stub (the tunnel node built so far)}.
var exits: Array = []
## The party's lantern, faded as the party walks away from its mark.
var lamp: float = 1.0

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _clock: float = 0.0
var _flickers: Array = []
var _floaters: Array = []
var _pulsers: Array = []
var _optional_lights: Array = []
var _ambient: Array = []
var _mist: FogVolume = null
var _key_light: SpotLight3D = null
var _rock: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _seed: int = 0
var _trails: Array = []
var _last_ring: Array = []

static var _water_shader: Shader = null
static var _lava_shader: Shader = null
static var _mist_shader: Shader = null

func build(new_biome: Dictionary, seed_value: int, exit_count: int = 0, drop: float = 2.5) -> void:
	for step in plan(new_biome, seed_value, exit_count, drop):
		(step as Callable).call()

func plan(new_biome: Dictionary, seed_value: int, exit_count: int = 0, drop: float = 2.5) -> Array:
	## The room as a list of steps, so the stage can build it all at once or a slice a frame
	## while the party walks toward it. Either way it comes out the same.
	biome = new_biome
	_seed = seed_value
	_rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.09
	_noise.fractal_octaves = 3
	_detail.seed = seed_value + 17
	_detail.frequency = 0.45
	_rock = StandardMaterial3D.new()
	_rock.vertex_color_use_as_albedo = true
	_rock.roughness = 0.35 if biome.id == "seeps" else 0.9
	_rock.metallic_specular = 0.75 if biome.id == "seeps" else 0.35
	_floor_material = _rock.duplicate()
	exits.clear()
	var places: Array = exit_xs(exit_count)
	for index in range(places.size()):
		var way: Dictionary = exit_path(float(places[index]), drop, seed_value * 31 + index * 7 + 5)
		way.index = index
		exits.append(way)
	_lay_trails()
	var steps: Array = [_floor, _shell, _far_wall, _stubs]
	for prop in biome.get("props", []):
		match str(prop):
			"stalactites": steps.append(_stalactites.bind(18))
			"stalagmites": steps.append(_stalagmites.bind(14))
			"boulders": steps.append(_boulders.bind(12))
			"rubble": steps.append(_rubble.bind(40))
			"timber": steps.append(_timber)
			"rails": steps.append(_rails)
			"pools": steps.append(_pools)
			"moss": steps.append(_moss.bind(46))
			"crystals": steps.append(_crystals.bind(10))
			"shards": steps.append(_shards.bind(36))
			"mushrooms": steps.append(_mushrooms.bind(9))
			"roots": steps.append(_roots.bind(14))
			"lava": steps.append(_lava)
			"basalt": steps.append(_basalt.bind(26))
			"geode": steps.append(_geode.bind(34))
			"gold_veins": steps.append(_veins.bind(16))
			"floating": steps.append(_floating.bind(12))
			"arches": steps.append(_arches)
			"void_crystals": steps.append(_void_crystals.bind(12))
			"pillars": steps.append(_pillars)
			"braziers": steps.append(_braziers)
	steps.append_array([_lights, _particles, _ground_mist, _clearing])
	return steps

# --- the ways in and out -------------------------------------------------------------------------

static func exit_xs(count: int) -> Array:
	## Where the mouths stand across the far wall.
	match count:
		0: return []
		1: return [0.0]
		2: return [-3.6, 3.6]
	return [-4.8, 0.0, 4.8]

static func exit_path(x: float, drop: float, seed_value: int) -> Dictionary:
	## One way on: straight out of the far wall, a long lean to one side and down, straight
	## into the next room's entrance. Side mouths lean away from the middle, so their tunnels
	## never meet. The same seed always makes the same tunnel.
	##
	## One lean, not two. The first pass swung hard out and hard back inside half the
	## tunnel's length, which hid the room behind well enough and threw the view from side to
	## side doing it. This carries the same offset across the whole length and never comes
	## back: the party walks a long curve, the room behind goes out of sight on the way, and
	## the next one comes into it without the horizon ever whipping.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var side: float = signf(x) if absf(x) > 0.1 else (1.0 if rng.randf() > 0.5 else -1.0)
	var bend: float = rng.randf_range(4.6, 5.8)
	var land: float = x + side * bend
	var far: float = Z_FAR - Tunnel.LENGTH
	var long: float = Tunnel.LENGTH
	var points: Array = [Vector3(x, 0.0, Z_FAR + 0.8), Vector3(x, 0.0, Z_FAR - 4.0),
		Vector3(x + side * bend * 0.22, -drop * 0.18, Z_FAR - long * 0.34),
		Vector3(x + side * bend * 0.74, -drop * 0.62, Z_FAR - long * 0.60),
		Vector3(land, -drop, far + 5.0), Vector3(land, -drop, far - 0.8)]
	return {"x": x, "points": points, "origin": Vector3(land, -drop, far - Z_NEAR), "seed": seed_value, "drop": drop, "stub": null}

func _lay_trails() -> void:
	## A path worn flat from the entrance to the arena and on to every mouth.
	_trails = [[Vector2(0.0, Z_NEAR + 3.0), Vector2(0.0, 1.0)]]
	for way in exits:
		var x: float = float(way.x)
		_trails.append([Vector2(x * 0.25, -5.5), Vector2(x, Z_FAR + 1.5)])
		_trails.append([Vector2(x, Z_FAR + 1.5), Vector2(x, Z_FAR - 4.0)])

func trail_distance(x: float, z: float) -> float:
	var at := Vector2(x, z)
	var best: float = INF
	for trail in _trails:
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, trail[0], trail[1])))
	return best

func _stubs() -> void:
	## The first stretch of every way on, bent out of sight and capped.
	for way in exits:
		var stub: Node3D = Tunnel.new()
		stub.name = "Stub%d" % int(way.index)
		add_child(stub)
		stub.build(biome, {}, way.points, int(way.seed), Tunnel.WALL_GAP, Tunnel.STUB, true)
		way.stub = stub

func mouth(index: int) -> Vector3:
	## The foot of a mouth in the far wall, in room space.
	if index < 0 or index >= exits.size():
		return Vector3(0, 0, Z_FAR)
	return Vector3(float(exits[index].x), 0.0, Z_FAR)

func rock_material() -> StandardMaterial3D:
	return _rock

# --- ground ------------------------------------------------------------------------------------

func ground(x: float, z: float) -> float:
	## Floor height: nearly level where the creatures stand, heaving up into rubble toward
	## the walls and the far end.
	var side: float = smoothstep(5.5, 11.5, absf(x))
	## The far end heaps up with fallen rock toward the walls, and stays open in the middle
	## where the ways on are.
	var back: float = smoothstep(-10.0, -20.0, z) * lerpf(0.2, 1.0, smoothstep(3.0, 9.0, absf(x)))
	var edge: float = maxf(side, back * 0.8)
	var n: float = _noise.get_noise_2d(x * 1.3, z * 1.3)
	var d: float = _detail.get_noise_2d(x, z)
	var height: float = n * (0.1 + 1.6 * edge) + d * 0.05 + edge * edge * 2.4
	## The trails: worn flat and level with the tunnels they lead into.
	var near: float = trail_distance(x, z)
	if near < 3.4:
		height = lerpf(height, 0.0, 1.0 - smoothstep(1.4, 3.4, near))
	return height

func _floor() -> void:
	var surface := Lowpoly.begin()
	var nx := 44
	var nz := 35
	var xs := [-22.0, 22.0]
	var zs := [Z_FAR - 2.0, Z_NEAR + 2.0]
	var points: Array = []
	for j in range(nz + 1):
		var row: Array = []
		for i in range(nx + 1):
			var x: float = lerpf(xs[0], xs[1], float(i) / float(nx)) + _rng.randf_range(-0.18, 0.18)
			var z: float = lerpf(zs[0], zs[1], float(j) / float(nz)) + _rng.randf_range(-0.18, 0.18)
			row.append(Vector3(x, ground(x, z), z))
		points.append(row)
	var floor_tone: Color = biome.floor
	var moss: Color = biome.moss
	var wants_moss: bool = biome.get("props", []).has("moss") or biome.id in ["fungal", "seeps"]
	for j in range(nz):
		for i in range(nx):
			var a: Vector3 = points[j][i]
			var b: Vector3 = points[j][i + 1]
			var c: Vector3 = points[j + 1][i + 1]
			var d: Vector3 = points[j + 1][i]
			for triangle in [[a, b, c], [a, c, d]]:
				var centre: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
				var tone: Color = floor_tone.lerp(biome.rock, clampf(centre.y * 0.35, 0.0, 1.0))
				tone = Lowpoly.shade(tone, _rng, 0.07)
				var patch: float = _detail.get_noise_2d(centre.x * 0.4, centre.z * 0.4)
				if wants_moss and patch > 0.25:
					tone = tone.lerp(moss.darkened(0.35), clampf((patch - 0.25) * 2.0, 0.0, 0.6))
				Lowpoly.tri(surface, triangle[0], triangle[1], triangle[2], tone, Vector3.UP)
	_place(surface.commit(), _floor_material, Transform3D.IDENTITY, true)

func _shell_point(u: float, z: float) -> Vector3:
	var bulge: float = 1.0 + 0.28 * exp(-pow((z - ARENA.z) / 9.0, 2.0))
	var narrow: float = 1.0 - 0.18 * smoothstep(-12.0, Z_FAR, z)
	var rx: float = SHELL_RX * bulge * narrow
	var ry: float = SHELL_RY * bulge * narrow
	var base := Vector3(cos(u) * rx, sin(u) * ry, z)
	var n: float = _noise.get_noise_3d(base.x * 0.7, base.y * 0.7, base.z * 0.7)
	var d: float = _detail.get_noise_3d(base.x, base.y, base.z)
	var push: float = 1.0 + n * 0.22 + d * 0.05
	return Vector3(base.x * push, base.y * push, z + d * 0.4)

func _shell() -> void:
	## The vault: a tunnel of faceted rock, wider where the fight is, closed at the far end.
	var surface := Lowpoly.begin()
	var nu := 30
	var nz := 30
	var u0 := -0.28
	var u1 := PI + 0.28
	var rings: Array = []
	for j in range(nz + 1):
		var z: float = lerpf(Z_NEAR, Z_FAR, float(j) / float(nz))
		var ring: Array = []
		for i in range(nu + 1):
			ring.append(_shell_point(lerpf(u0, u1, float(i) / float(nu)), z))
		rings.append(ring)
	var rock: Color = biome.rock
	var dark: Color = biome.rock_dark
	for j in range(nz):
		for i in range(nu):
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][i + 1]
			var c: Vector3 = rings[j + 1][i + 1]
			var d: Vector3 = rings[j + 1][i]
			for triangle in [[a, b, c], [a, c, d]]:
				var centre: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
				var height: float = clampf(centre.y / SHELL_RY, 0.0, 1.0)
				var tone: Color = rock.lerp(dark, height * 0.85)
				var strata: float = sin(centre.y * 2.6 + _noise.get_noise_2d(centre.x, centre.z) * 3.0)
				tone = tone.lightened(0.05 * strata) if strata > 0.0 else tone.darkened(-0.06 * strata)
				tone = Lowpoly.shade(tone, _rng, 0.06)
				var inward := Vector3(0, SHELL_RY * 0.3, centre.z) - centre
				Lowpoly.tri(surface, triangle[0], triangle[1], triangle[2], tone, inward)
	_last_ring = rings[nz]
	_place(surface.commit(), _rock, Transform3D.IDENTITY, false)

func _far_wall() -> void:
	## The end of the vault, with a mouth cut through it for every way on. A scatter of
	## points is triangulated and pushed back into a shallow bowl; two rings round each mouth
	## hold its edge to the portal's own arch (drawn a hair small, so the wall always overlaps
	## the tunnel behind it) and give it a lip.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 5
	var outer := PackedVector2Array()
	var flat := PackedVector2Array()
	var points: Array = []
	for p in _last_ring:
		outer.append(Vector2(p.x, p.y))
		flat.append(Vector2(p.x, p.y))
		points.append(p)
	var holes: Array = []
	var guards: Array = []
	for way in exits:
		var x: float = float(way.x)
		var hole: PackedVector2Array = Tunnel.outline(x, 30, -0.06)
		holes.append(hole)
		guards.append(Tunnel.outline(x, 24, 1.3))
		for q in hole:
			flat.append(q)
			points.append(Vector3(q.x, q.y, Z_FAR))
		for q in Tunnel.outline(x, 24, 0.6):
			flat.append(q)
			points.append(Vector3(q.x, q.y, Z_FAR + absf(_detail.get_noise_2d(q.x * 2.0, q.y * 2.0)) * 0.3))
	var bounds := Rect2(outer[0], Vector2.ZERO)
	for q in outer:
		bounds = bounds.expand(q)
	var step: float = 1.25
	var y: float = bounds.position.y + step * 0.5
	while y < bounds.end.y:
		var x: float = bounds.position.x + step * 0.5
		while x < bounds.end.x:
			var q := Vector2(x + rng.randf_range(-0.4, 0.4), y + rng.randf_range(-0.4, 0.4))
			x += step
			if not Geometry2D.is_point_in_polygon(q, outer) or _edge_gap(q, outer) < 0.6:
				continue
			if guards.any(func(guard: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(q, guard)):
				continue
			var across: float = clampf(q.x / maxf(1.0, bounds.size.x * 0.5), -1.0, 1.0)
			var up: float = clampf(q.y / maxf(1.0, bounds.end.y), 0.0, 1.0)
			var bowl: float = 1.4 * (1.0 - across * across) * (1.0 - 0.5 * up)
			flat.append(q)
			points.append(Vector3(q.x, q.y, Z_FAR - bowl + _noise.get_noise_2d(q.x * 1.7, q.y * 1.7) * 0.6))
		y += step
	var surface := Lowpoly.begin()
	var tris: PackedInt32Array = Geometry2D.triangulate_delaunay(flat)
	var rock: Color = biome.rock
	var dark: Color = biome.rock_dark
	for i in range(0, tris.size(), 3):
		var centre: Vector2 = (flat[tris[i]] + flat[tris[i + 1]] + flat[tris[i + 2]]) / 3.0
		if not Geometry2D.is_point_in_polygon(centre, outer):
			continue
		if holes.any(func(hole: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(centre, hole)):
			continue
		var height: float = clampf(centre.y / SHELL_RY, 0.0, 1.0)
		var tone: Color = Lowpoly.shade(rock.lerp(dark, 0.45 + height * 0.45), rng, 0.06)
		Lowpoly.tri(surface, points[tris[i]], points[tris[i + 1]], points[tris[i + 2]], tone, Vector3(0, 0, 1))
	_place(surface.commit(), _rock, Transform3D.IDENTITY, false)

static func _edge_gap(q: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	for i in range(poly.size()):
		best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()])))
	return best

func _on_wall(u: float, z: float, inset: float = 0.3) -> Dictionary:
	## A point on the vault and the way into the room from it.
	var point := _shell_point(u, z)
	var inward := (Vector3(0, SHELL_RY * 0.3, z) - point).normalized()
	return {"point": point + inward * inset, "normal": inward}

func _free_spot(min_side: float = 5.5, min_back: float = -8.5) -> Vector2:
	## Somewhere on the floor away from the arena and the line of sight to it.
	for _try in range(40):
		var x := _rng.randf_range(-12.0, 12.0)
		var z := _rng.randf_range(Z_FAR + 3.0, 3.0)
		if (absf(x) > min_side or z < min_back) and trail_distance(x, z) > 2.8:
			if absf(x) < 10.5 or z < -14.0:
				return Vector2(x, z)
	return Vector2(8.0, -12.0)

# --- placing -----------------------------------------------------------------------------------

func _place(mesh: Mesh, material: Material, at: Transform3D, shadows: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.transform = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _multi(mesh: Mesh, transforms: Array, material: Material, shadows: bool = false) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _glowing(color: Color, energy: float = 1.6, roughness: float = 0.15) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color.lightened(0.1)
	m.roughness = roughness
	m.metallic = 0.2
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.rim_enabled = true
	m.rim = 0.4
	return m

func _light(at: Vector3, color: Color, energy: float, reach: float, flicker: float = 0.0, flare: float = 0.0, optional: bool = true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 1.4
	light.shadow_enabled = false
	light.position = at
	add_child(light)
	if flicker > 0.0:
		_flickers.append({"light": light, "base": energy, "amount": flicker, "speed": _rng.randf_range(6.0, 11.0), "phase": _rng.randf_range(0.0, 100.0)})
	if flare > 0.0:
		flares.append({"node": light, "color": color, "strength": flare, "size": 1.0})
	if optional:
		_optional_lights.append(light)
	return light

func _pulse(material: StandardMaterial3D, amount: float = 0.35, speed: float = 1.2) -> void:
	_pulsers.append({"material": material, "base": material.emission_energy_multiplier, "amount": amount, "speed": speed, "phase": _rng.randf_range(0, TAU)})

# --- props -------------------------------------------------------------------------------------

func _stalactites(count: int) -> void:
	var variants: Array = []
	for _v in range(4):
		variants.append(Lowpoly.spike(_rng, biome.rock_dark.lightened(0.08), 6, _rng.randf_range(0.25, 0.45), _rng.randf_range(1.2, 3.2), 0.06))
	var groups: Array = [[], [], [], []]
	for _i in range(count):
		var u := _rng.randf_range(0.3 * PI, 0.7 * PI)
		var z := _rng.randf_range(Z_FAR + 2.0, 4.0)
		var spot := _on_wall(u, z, 0.2)
		var scale := _rng.randf_range(0.6, 1.4)
		var basis := Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * scale)
		basis = Basis(Vector3.UP, _rng.randf_range(0, TAU)) * basis
		groups[_rng.randi() % 4].append(Transform3D(basis, spot.point + Vector3(0, 0.4, 0)))
	for i in range(4):
		_multi(variants[i], groups[i], _rock)

func _stalagmites(count: int) -> void:
	var variants: Array = []
	for _v in range(3):
		variants.append(Lowpoly.spike(_rng, biome.rock.darkened(0.1), 6, _rng.randf_range(0.35, 0.6), _rng.randf_range(1.2, 3.4), 0.08, biome.rock.lightened(0.1)))
	var groups: Array = [[], [], []]
	for _i in range(count):
		var spot := _free_spot(6.0, -9.5)
		var scale := _rng.randf_range(0.5, 1.3)
		var basis := Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale)
		groups[_rng.randi() % 3].append(Transform3D(basis, Vector3(spot.x, ground(spot.x, spot.y) - 0.1, spot.y)))
	for i in range(3):
		_multi(variants[i], groups[i], _rock, true)

func _boulders(count: int) -> void:
	var variants: Array = []
	for _v in range(3):
		variants.append(Lowpoly.rock(_rng, biome.rock.lightened(0.04), 0.3, Vector3(1.0, 0.7, 1.0)))
	var groups: Array = [[], [], []]
	for _i in range(count):
		var spot := _free_spot(5.8, -9.0)
		var scale := _rng.randf_range(0.4, 1.7)
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0, TAU), _rng.randf_range(-0.3, 0.3))).scaled(Vector3.ONE * scale)
		groups[_rng.randi() % 3].append(Transform3D(basis, Vector3(spot.x, ground(spot.x, spot.y) + scale * 0.25, spot.y)))
	for i in range(3):
		_multi(variants[i], groups[i], _rock, true)

func _rubble(count: int) -> void:
	var mesh := Lowpoly.rock(_rng, biome.rock.lightened(0.1), 0.35)
	var transforms: Array = []
	for _i in range(count):
		var x := _rng.randf_range(-9.0, 9.0)
		var z := _rng.randf_range(-12.0, 3.5)
		var scale := _rng.randf_range(0.06, 0.24)
		if (absf(x) < 4.2 and z > -6.5 and z < -2.5) or trail_distance(x, z) < 1.1:
			continue
		transforms.append(Transform3D(Basis.from_euler(Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())).scaled(Vector3.ONE * scale), Vector3(x, ground(x, z) + scale * 0.3, z)))
	_multi(mesh, transforms, _rock)

func _timber() -> void:
	## Pit props: posts and crossbeams holding the gallery up, with a lantern on each.
	var wood := Color("6a4428")
	var wood_material := StandardMaterial3D.new()
	wood_material.vertex_color_use_as_albedo = true
	wood_material.roughness = 0.95
	var post := Lowpoly.slab(Vector3(0.38, 6.2, 0.38), wood, _rng, 0.03)
	var beam := Lowpoly.slab(Vector3(15.6, 0.42, 0.44), wood.darkened(0.1), _rng, 0.05)
	var brace := Lowpoly.slab(Vector3(0.24, 2.4, 0.24), wood.darkened(0.05), _rng, 0.02)
	var posts: Array = []
	var beams: Array = []
	var braces: Array = []
	for z in [1.5, -7.0, -15.0, -21.5]:
		for side in [-1.0, 1.0]:
			var x: float = side * 7.4
			var tilt := Basis(Vector3(0, 0, 1), _rng.randf_range(-0.04, 0.04))
			posts.append(Transform3D(tilt, Vector3(x, ground(x, z) + 3.0, z)))
			braces.append(Transform3D(Basis(Vector3(0, 0, 1), -side * 0.75), Vector3(x - side * 0.7, 5.3, z)))
		beams.append(Transform3D(Basis(Vector3(0, 0, 1), _rng.randf_range(-0.02, 0.02)), Vector3(0, 6.1, z)))
		## A lantern hangs from each beam, off to one side so it never sits in front of a creature.
		var lantern_at := Vector3(_rng.randf_range(3.5, 5.5) * (1.0 if _rng.randf() > 0.5 else -1.0), 5.2, z)
		_lantern(lantern_at)
	_multi(post, posts, wood_material, true)
	_multi(beam, beams, wood_material, true)
	_multi(brace, braces, wood_material)

func _lantern(at: Vector3) -> void:
	var glass := _glowing(Color("ffb060"), 3.0, 0.3)
	glass.vertex_color_use_as_albedo = false
	var body := BoxMesh.new()
	body.size = Vector3(0.22, 0.3, 0.22)
	_place(body, glass, Transform3D(Basis.IDENTITY, at))
	var cord := BoxMesh.new()
	cord.size = Vector3(0.03, 0.8, 0.03)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1a1410")
	_place(cord, dark, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.55, 0)))
	_light(at, Color("ffab5a"), 2.6, 9.0, float(biome.get("flicker", 0.2)), 0.8)

func _rails() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("5a5e66")
	steel.metallic = 0.8
	steel.roughness = 0.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("4a3020")
	wood.roughness = 0.95
	var rail := BoxMesh.new()
	rail.size = Vector3(0.08, 0.1, Z_NEAR - Z_FAR - 2.0)
	var tie := BoxMesh.new()
	tie.size = Vector3(1.4, 0.08, 0.22)
	var x := 6.8
	for offset in [-0.5, 0.5]:
		_place(rail, steel, Transform3D(Basis.IDENTITY, Vector3(x + offset, ground(x, -5.0) + 0.1, (Z_NEAR + Z_FAR) * 0.5 - 1.0)))
	var ties: Array = []
	var z := 8.0
	while z > Z_FAR + 1.0:
		ties.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.06, 0.06)), Vector3(x, ground(x, z) + 0.04, z)))
		z -= 0.8
	_multi(tie, ties, wood)
	## A mine cart left where it stopped.
	var cart := Lowpoly.slab(Vector3(1.2, 0.8, 1.7), Color("5a4a3e"), _rng, 0.04)
	var iron := StandardMaterial3D.new()
	iron.vertex_color_use_as_albedo = true
	iron.metallic = 0.6
	iron.roughness = 0.6
	_place(cart, iron, Transform3D(Basis(Vector3.UP, 0.05), Vector3(x, ground(x, -13.0) + 0.6, -13.0)), true)
	var ore := Lowpoly.rock(_rng, Color("c9a26b"), 0.4)
	var lumps: Array = []
	for _i in range(5):
		lumps.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.18, 0.3)), Vector3(x + _rng.randf_range(-0.35, 0.35), ground(x, -13.0) + 1.05, -13.0 + _rng.randf_range(-0.5, 0.5))))
	_multi(ore, lumps, _glowing(Color("e2b23a"), 0.4, 0.4))

func _pools() -> void:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = _water_shader
	material.set_shader_parameter("tint", Color(biome.fog).lightened(0.1))
	material.set_shader_parameter("glow", Color(biome.accent))
	for spot in [Vector2(-7.5, -3.0), Vector2(7.8, -9.0), Vector2(-4.0, -13.5), Vector2(3.5, 1.5)]:
		if trail_distance(spot.x, spot.y) < 2.8:
			continue
		var pool := PlaneMesh.new()
		pool.size = Vector2(_rng.randf_range(3.5, 6.0), _rng.randf_range(2.5, 4.5))
		pool.subdivide_width = 8
		pool.subdivide_depth = 8
		var y := ground(spot.x, spot.y) + 0.04
		_place(pool, material, Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)), Vector3(spot.x, maxf(y, 0.05), spot.y)))

func _moss(count: int) -> void:
	var glow := _glowing(biome.moss, 1.4, 0.8)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.32
	mesh.height = 0.04
	mesh.radial_segments = 6
	mesh.rings = 1
	var transforms: Array = []
	for _i in range(count):
		if _rng.randf() < 0.5:
			var spot := _free_spot(4.8, -7.5)
			transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, 1, 1) * _rng.randf_range(0.5, 1.6)), Vector3(spot.x, ground(spot.x, spot.y) + 0.03, spot.y)))
		else:
			var wall := _on_wall(_rng.randf_range(0.05, 0.9) * (1.0 if _rng.randf() > 0.5 else -1.0) + (0.0 if _rng.randf() > 0.5 else PI), _rng.randf_range(-24, 3), 0.05)
			var basis := Basis(Quaternion(Vector3.UP, wall.normal))
			transforms.append(Transform3D(basis.scaled(Vector3.ONE * _rng.randf_range(0.6, 1.8)), wall.point))
	_multi(mesh, transforms, glow)
	_pulse(glow, 0.3, 0.8)

func _crystals(count: int) -> void:
	var lights: Array = biome.get("lights", [biome.accent])
	for i in range(count):
		var color: Color = lights[i % lights.size()]
		var spot := _free_spot(5.2, -8.5)
		var big: bool = i < 3
		var scale: float = _rng.randf_range(1.6, 2.6) if big else _rng.randf_range(0.6, 1.3)
		var mesh := Lowpoly.cluster(_rng, color, 5 if big else 4, scale)
		var material := _glowing(color, 1.2 if big else 0.9)
		var at := Vector3(spot.x, ground(spot.x, spot.y) - 0.05, spot.y)
		_place(mesh, material, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at), big)
		_pulse(material, 0.4, _rng.randf_range(0.6, 1.4))
		if big:
			_light(at + Vector3(0, scale * 0.8, 0), color, 2.4, 7.0, 0.05, 0.7)
	## And a few hanging from the walls.
	for i in range(6):
		var color: Color = lights[(i + 1) % lights.size()]
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var wall := _on_wall(PI * 0.5 - side * _rng.randf_range(0.6, 1.2), _rng.randf_range(-20.0, 0.0), 0.1)
		var mesh := Lowpoly.cluster(_rng, color, 4, _rng.randf_range(0.8, 1.5))
		var basis := Basis(Quaternion(Vector3.UP, wall.normal))
		_place(mesh, _glowing(color, 1.1), Transform3D(basis, wall.point))

func _shards(count: int) -> void:
	var lights: Array = biome.get("lights", [biome.accent])
	for color_index in range(mini(2, lights.size())):
		var color: Color = lights[color_index]
		var mesh := Lowpoly.crystal(_rng, color, 0.06, 0.3)
		var transforms: Array = []
		for _i in range(count / 2):
			var x := _rng.randf_range(-10.0, 10.0)
			var z := _rng.randf_range(-16.0, 3.0)
			if absf(x) < 4.5 and z > -7.0 and z < -2.0:
				continue
			transforms.append(Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf() * TAU, _rng.randf_range(-0.8, 0.8))).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.8)), Vector3(x, ground(x, z), z)))
		_multi(mesh, transforms, _glowing(color, 1.4))

func _mushrooms(count: int) -> void:
	var stem_tone := Color("c8c0a0")
	var lights: Array = biome.get("lights", [biome.accent])
	var stem_material := StandardMaterial3D.new()
	stem_material.vertex_color_use_as_albedo = true
	stem_material.roughness = 0.8
	for i in range(count):
		var spot := _free_spot(6.0, -9.5)
		var height := _rng.randf_range(1.4, 4.5)
		var at := Vector3(spot.x, ground(spot.x, spot.y) - 0.05, spot.y)
		var lean := Basis.from_euler(Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, _rng.randf_range(-0.15, 0.15)))
		_place(Lowpoly.column(_rng, stem_tone, 7, 0.12 + height * 0.05, height), stem_material, Transform3D(lean, at), true)
		var color: Color = lights[i % lights.size()]
		var cap_material := _glowing(color, 0.9, 0.6)
		var cap_mesh := Lowpoly.cap(_rng, color.darkened(0.35), color.lightened(0.3), 0.5 + height * 0.3, 0.3 + height * 0.08)
		_place(cap_mesh, cap_material, Transform3D(lean, at + lean * Vector3(0, height, 0)), true)
		_pulse(cap_material, 0.5, _rng.randf_range(0.5, 1.2))
		if height > 3.0:
			_light(at + lean * Vector3(0, height - 0.4, 0), color, 1.8, 6.0, 0.04, 0.5)

func _roots(count: int) -> void:
	var wood := Color("4a3a26")
	var variants: Array = []
	for _v in range(3):
		variants.append(Lowpoly.spike(_rng, wood, 5, 0.12, _rng.randf_range(3.0, 6.0), 0.35))
	var groups: Array = [[], [], []]
	for _i in range(count):
		var wall := _on_wall(_rng.randf_range(0.35, 0.65) * PI, _rng.randf_range(-22.0, 2.0), 0.0)
		var basis := Basis(Quaternion(Vector3.UP, (wall.normal + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.4, 0.4))).normalized()))
		groups[_rng.randi() % 3].append(Transform3D(basis, wall.point))
	for i in range(3):
		_multi(variants[i], groups[i], _rock)

func _lava() -> void:
	if _lava_shader == null:
		_lava_shader = Shader.new()
		_lava_shader.code = LAVA_SHADER
	var material := ShaderMaterial.new()
	material.shader = _lava_shader
	for spot in [Vector3(-8.6, 0, -6.0), Vector3(8.8, 0, -3.0), Vector3(0.0, 0, -15.5), Vector3(-6.0, 0, -18.0), Vector3(7.0, 0, -16.0)]:
		if trail_distance(spot.x, spot.z) < 3.2:
			continue
		var plane := PlaneMesh.new()
		plane.size = Vector2(_rng.randf_range(2.8, 5.5), _rng.randf_range(2.2, 4.0))
		var y := ground(spot.x, spot.z)
		_place(plane, material, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(spot.x, y + 0.08, spot.z)))
		_light(Vector3(spot.x, y + 0.9, spot.z), Color("ff6a1a"), 3.2, 8.0, float(biome.get("flicker", 0.3)), 0.9)
	## Glowing seams across the floor.
	var seam := _glowing(Color("ff5a10"), 3.5, 0.6)
	seam.vertex_color_use_as_albedo = false
	var crack := BoxMesh.new()
	crack.size = Vector3(0.08, 0.04, 2.4)
	var transforms: Array = []
	for _i in range(26):
		var x := _rng.randf_range(-9.0, 9.0)
		var z := _rng.randf_range(-14.0, 3.0)
		if (absf(x) < 4.0 and z > -7.0 and z < -2.0) or trail_distance(x, z) < 1.4:
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, 1, _rng.randf_range(0.4, 1.4))), Vector3(x, ground(x, z) + 0.02, z)))
	_multi(crack, transforms, seam)
	_pulse(seam, 0.6, 1.8)

func _basalt(count: int) -> void:
	var tone: Color = biome.rock_dark.lightened(0.05)
	var variants: Array = []
	for _v in range(4):
		variants.append(Lowpoly.column(_rng, tone, 6, 0.42, 1.0))
	var groups: Array = [[], [], [], []]
	for _i in range(count):
		var spot := _free_spot(6.2, -10.0)
		var height := _rng.randf_range(0.8, 5.5)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.0, height, 1.0))
		groups[_rng.randi() % 4].append(Transform3D(basis, Vector3(spot.x, ground(spot.x, spot.y) - 0.2, spot.y)))
	for i in range(4):
		_multi(variants[i], groups[i], _rock, true)

func _geode(count: int) -> void:
	## The walls grow inward in great crystals: the inside of a stone the size of a hall.
	var lights: Array = biome.get("lights", [biome.accent])
	for color_index in range(lights.size()):
		var color: Color = lights[color_index]
		var mesh := Lowpoly.crystal(_rng, color, 0.35, 2.6)
		var transforms: Array = []
		for _i in range(count / lights.size()):
			var u := _rng.randf_range(-0.1, PI + 0.1)
			var z := _rng.randf_range(Z_FAR + 1.0, 4.0)
			var wall := _on_wall(u, z, -0.2)
			var tilt: Vector3 = (wall.normal + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.3), _rng.randf_range(-0.3, 0.3))).normalized()
			var basis := Basis(Quaternion(Vector3.UP, tilt)).scaled(Vector3.ONE * _rng.randf_range(0.5, 1.6))
			transforms.append(Transform3D(basis, wall.point))
		var material := _glowing(color, 0.8, 0.1)
		_multi(mesh, transforms, material)
		_pulse(material, 0.35, 0.7 + 0.3 * color_index)

func _veins(count: int) -> void:
	var gold := _glowing(Color("ffc84a"), 2.2, 0.3)
	gold.vertex_color_use_as_albedo = false
	gold.metallic = 0.9
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.05, 3.0)
	var transforms: Array = []
	for _i in range(count):
		var wall := _on_wall(_rng.randf_range(0.0, PI), _rng.randf_range(-24.0, 3.0), 0.02)
		var basis := Basis(Quaternion(Vector3.UP, wall.normal)) * Basis(Vector3.UP, _rng.randf() * TAU)
		transforms.append(Transform3D(basis.scaled(Vector3(1, 1, _rng.randf_range(0.5, 1.5))), wall.point))
	_multi(mesh, transforms, gold)
	_pulse(gold, 0.4, 0.9)

func _floating(count: int) -> void:
	for i in range(count):
		var x := _rng.randf_range(-10.0, 10.0)
		var z := _rng.randf_range(-22.0, -6.0)
		if absf(x) < 5.0 and z > -9.0:
			x = 6.0 * signf(x + 0.01)
		var y := _rng.randf_range(2.0, 7.0)
		var scale := _rng.randf_range(0.4, 1.4)
		var node := _place(Lowpoly.rock(_rng, biome.rock.lightened(0.08), 0.35, Vector3(1.0, 0.8, 1.0)), _rock, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3(x, y, z)), false)
		_floaters.append({"node": node, "base": node.position, "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.3, 0.8), "amp": _rng.randf_range(0.15, 0.45), "spin": _rng.randf_range(-0.3, 0.3)})
		if i % 3 == 0:
			var shard := Lowpoly.crystal(_rng, biome.accent, 0.12 * scale, 0.9 * scale)
			var glow := _glowing(biome.accent, 1.8)
			var crystal := MeshInstance3D.new()
			crystal.mesh = shard
			crystal.material_override = glow
			crystal.position = Vector3(0, 0.5, 0)
			node.add_child(crystal)
			_pulse(glow, 0.5, 1.4)

func _arches() -> void:
	var stone: Color = biome.rock.lightened(0.12)
	for spot in [Vector3(0.0, 0, -16.0), Vector3(-8.5, 0, -11.0)]:
		var rot := Basis(Vector3.UP, 0.0 if spot.x == 0.0 else 1.1)
		## An arch stands over a trail or clear of it, never with a column in the way.
		var feet: Array = [spot + rot * Vector3(-2.4, 0, 0), spot + rot * Vector3(2.4, 0, 0)]
		if feet.any(func(f: Vector3) -> bool: return trail_distance(f.x, f.z) < 2.2):
			continue
		var y := ground(spot.x, spot.z)
		for side in [-1.0, 1.0]:
			_place(Lowpoly.column(_rng, stone, 5, 0.55, 5.0), _rock, Transform3D(rot, Vector3(spot.x, y - 0.2, spot.z) + rot * Vector3(side * 2.4, 0, 0)), true)
		_place(Lowpoly.slab(Vector3(6.2, 0.8, 1.0), stone, _rng, 0.12), _rock, Transform3D(rot * Basis(Vector3(0, 0, 1), _rng.randf_range(-0.08, 0.08)), Vector3(spot.x, y + 5.2, spot.z)), true)

func _void_crystals(count: int) -> void:
	for i in range(count):
		var spot := _free_spot(5.5, -9.0)
		var color: Color = biome.get("lights", [biome.accent])[i % 3]
		var mesh := Lowpoly.cluster(_rng, Color("1a1428"), 4, _rng.randf_range(0.8, 1.8))
		var material := _glowing(color, 0.7, 0.05)
		material.albedo_color = Color("2a2040")
		material.rim = 1.0
		material.rim_tint = 1.0
		_place(mesh, material, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(spot.x, ground(spot.x, spot.y), spot.y)))
		_pulse(material, 0.8, _rng.randf_range(0.8, 2.0))

func _pillars() -> void:
	## A Warden's hall is built, not dug: two ranks of carved columns frame the arena.
	var stone: Color = biome.rock.lightened(0.18)
	var band := _glowing(Color("ff4a3a"), 2.0, 0.4)
	band.vertex_color_use_as_albedo = false
	for z in [0.5, -4.5, -9.5, -14.5]:
		for side in [-1.0, 1.0]:
			var x: float = side * 8.2
			var y := ground(x, z)
			_place(Lowpoly.column(_rng, stone, 8, 0.75, 8.0), _rock, Transform3D(Basis.IDENTITY, Vector3(x, y - 0.3, z)), true)
			var ring := CylinderMesh.new()
			ring.top_radius = 0.82
			ring.bottom_radius = 0.82
			ring.height = 0.16
			ring.radial_segments = 8
			ring.rings = 1
			_place(ring, band, Transform3D(Basis.IDENTITY, Vector3(x, y + 2.6, z)))
	_pulse(band, 0.7, 1.6)

func _braziers() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2a2624")
	iron.metallic = 0.7
	iron.roughness = 0.5
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 5.6, ground(side * 5.6, -6.5), -6.5)
		_place(Lowpoly.column(_rng, Color("3a3430"), 6, 0.14, 1.3), iron, Transform3D(Basis.IDENTITY, at), true)
		var bowl := Lowpoly.cap(_rng, Color("3a3430"), Color("1a1410"), 0.5, 0.3, 8)
		_place(bowl, iron, Transform3D(Basis(Vector3.RIGHT, PI), at + Vector3(0, 1.55, 0)), true)
		var flame := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 0.25
		m.direction = Vector3.UP
		m.spread = 10.0
		m.initial_velocity_min = 0.8
		m.initial_velocity_max = 1.6
		m.gravity = Vector3(0, 0.8, 0)
		m.scale_min = 0.25
		m.scale_max = 0.5
		m.scale_curve = BattleFx.shrink_curve()
		m.color_ramp = BattleFx.burst_ramp(Color("ff6a1a"))
		flame.process_material = m
		flame.draw_pass_1 = BattleFx.quad(true)
		flame.amount = 40
		flame.lifetime = 0.8
		flame.position = at + Vector3(0, 1.6, 0)
		add_child(flame)
		_ambient.append(flame)
		_light(at + Vector3(0, 2.2, 0), Color("ff7a2a"), 4.0, 9.0, 0.35, 1.0, false)

# --- light and air -----------------------------------------------------------------------------

func _lights() -> void:
	## The party's lantern: the one light that throws shadows, and the beam you see in the fog.
	_key_light = SpotLight3D.new()
	_key_light.light_color = biome.key
	_key_light.light_energy = float(biome.get("key_energy", 5.0))
	_key_light.spot_range = 26.0
	_key_light.spot_angle = 34.0
	_key_light.spot_angle_attenuation = 1.4
	_key_light.shadow_enabled = true
	_key_light.shadow_blur = 1.5
	_key_light.light_volumetric_fog_energy = 1.2
	add_child(_key_light)
	_key_light.look_at_from_position(Vector3(1.2, 4.6, 6.0), ARENA + Vector3(0, 0.6, 0), Vector3.UP)
	_flickers.append({"light": _key_light, "base": _key_light.light_energy, "amount": float(biome.get("flicker", 0.1)) * 0.25, "speed": 5.0, "phase": 3.0})
	## Rim lights behind the arc: they outline the creatures and glow through the fog.
	var colors: Array = biome.get("lights", [biome.accent])
	var energy: float = float(biome.get("light_energy", 3.0))
	var spots: Array = [Vector3(-5.0, 2.8, -10.5), Vector3(5.2, 3.2, -11.0), Vector3(0.0, 5.5, -14.0), Vector3(-9.0, 4.0, -3.0), Vector3(9.0, 4.0, -2.0)]
	for i in range(mini(colors.size() + 1, spots.size())):
		var color: Color = colors[i % colors.size()]
		## No flares on these: they stand behind the arc, and a bloom behind a creature is a
		## creature nobody can see. Their haze in the fog is kept low for the same reason.
		var rim := _light(spots[i], color, energy * (1.2 if i < 2 else 0.8), 13.0, float(biome.get("flicker", 0.1)), 0.0, i >= 2)
		rim.light_volumetric_fog_energy = 0.45
	## Shafts of light from cracks in the ceiling, drawn out by the fog.
	if biome.id in ["galleries", "geode", "crystal", "fungal"] or bool(biome.get("warden", false)):
		for x in [-3.2, 3.8]:
			var shaft := SpotLight3D.new()
			shaft.light_color = Color(biome.key).lerp(Color(biome.accent), 0.3)
			shaft.light_energy = 2.5
			shaft.spot_range = 12.0
			shaft.spot_angle = 9.0
			shaft.light_volumetric_fog_energy = 6.0
			shaft.shadow_enabled = false
			add_child(shaft)
			shaft.look_at_from_position(Vector3(x, 9.5, -7.5 - absf(x)), Vector3(x * 0.7, 0, -6.0), Vector3.UP)
			_optional_lights.append(shaft)

func _particles() -> void:
	var scale: float = 1.0 * clampf(float(biome.get("intensity", 1.0)), 0.7, 1.4)
	for kind in biome.get("particles", []):
		var p := BattleFx.ambient(str(kind), biome, scale)
		add_child(p)
		_ambient.append(p)

func _clearing() -> void:
	## Air thinned out between the party and the arc, so the volumetric fog that makes the
	## room gives the creatures a haze at most, never a curtain.
	var material := FogMaterial.new()
	material.density = - (float(biome.get("vol_density", 0.03)) * 0.85 + float(biome.get("ground_mist", 0.3)) * 0.9)
	material.edge_fade = 0.45
	var clearing := FogVolume.new()
	clearing.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	clearing.size = Vector3(17.0, 9.0, 15.0)
	clearing.position = Vector3(0.0, 3.5, -1.8)
	clearing.material = material
	add_child(clearing)

func _ground_mist() -> void:
	var density: float = float(biome.get("ground_mist", 0.3))
	if density <= 0.0:
		return
	if _mist_shader == null:
		_mist_shader = Shader.new()
		_mist_shader.code = MIST_SHADER
	var material := ShaderMaterial.new()
	material.shader = _mist_shader
	material.set_shader_parameter("density", density * 1.6)
	material.set_shader_parameter("albedo", Color(biome.vol_albedo))
	material.set_shader_parameter("emission", Color(biome.accent) * 0.06)
	_mist = FogVolume.new()
	_mist.size = Vector3(34, 2.4, 34)
	_mist.position = Vector3(0, 0.6, -8.0)
	_mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_mist.material = material
	add_child(_mist)

func environment() -> Environment:
	## The air of the room: its fog, its bloom, its grade.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = biome.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = biome.ambient
	env.ambient_light_energy = float(biome.ambient_energy)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	## Only what is really hot blooms: emissive crystals, lava, bolts and flashes. A lower
	## threshold turned every mote of dust in the lantern light into a blur.
	env.glow_intensity = 0.55 * float(biome.get("glow", 0.8))
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.25
	env.glow_hdr_scale = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.35)
	env.set_glow_level(5, 0.0)
	env.fog_enabled = true
	env.fog_light_color = biome.fog
	## Depth fog that starts behind the creatures: the far walls sink into the dark, the arc
	## stays sharp.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 44.0
	env.fog_depth_curve = 1.4
	env.fog_density = 1.0
	env.fog_aerial_perspective = 0.2
	env.volumetric_fog_enabled = quality >= 2
	env.volumetric_fog_density = float(biome.vol_density)
	env.volumetric_fog_albedo = biome.vol_albedo
	env.volumetric_fog_emission = biome.vol_emission
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.3
	env.ssao_enabled = quality >= 3
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = float(biome.get("saturation", 1.0))
	env.adjustment_contrast = float(biome.get("contrast", 1.0))
	return env

func set_quality(level: int, env: Environment) -> void:
	## Steps the room down when the frame rate cannot keep up: first the contact shadows,
	## then the volumetric air and half the lights and particles.
	quality = level
	if env != null:
		env.ssao_enabled = level >= 3
		env.volumetric_fog_enabled = level >= 2
		env.fog_depth_begin = 12.0 if level >= 2 else 9.0
	if _mist != null:
		_mist.visible = level >= 2
	if _key_light != null:
		_key_light.shadow_enabled = level >= 2
	for i in range(_optional_lights.size()):
		var light: Light3D = _optional_lights[i]
		if is_instance_valid(light):
			light.visible = level >= 2 or i % 2 == 0
	for p in _ambient:
		if is_instance_valid(p):
			(p as GPUParticles3D).amount_ratio = 1.0 if level >= 2 else 0.5

# --- life --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	for f in _flickers:
		var light: Light3D = f.light
		if not is_instance_valid(light):
			continue
		var t: float = _clock * float(f.speed) + float(f.phase)
		var wobble: float = sin(t) * 0.5 + sin(t * 2.3 + 1.1) * 0.3 + sin(t * 5.7) * 0.2
		light.light_energy = float(f.base) * (1.0 + float(f.amount) * wobble) * (lamp if light == _key_light else 1.0)
	for f in _floaters:
		var node: Node3D = f.node
		if not is_instance_valid(node):
			continue
		node.position = f.base + Vector3(0, sin(_clock * float(f.speed) + float(f.phase)) * float(f.amp), 0)
		node.rotation.y += float(f.spin) * delta
	for p in _pulsers:
		var material: StandardMaterial3D = p.material
		material.emission_energy_multiplier = float(p.base) * (1.0 + float(p.amount) * sin(_clock * float(p.speed) + float(p.phase)))

func rest_lights(on: bool) -> void:
	## Once the party is well down a tunnel, a room it has left keeps only the lights a
	## glance back could need: none of the optional ones.
	for light in _optional_lights:
		if is_instance_valid(light):
			(light as Light3D).visible = on and (quality >= 2 or _optional_lights.find(light) % 2 == 0)

func surge(color: Color, amount: float = 1.0) -> void:
	## Every light in the room leaps for a moment: a heavy blow, a Warden's roar.
	for f in _flickers:
		var light: Light3D = f.light
		if is_instance_valid(light):
			var tween := light.create_tween()
			tween.tween_property(light, "light_energy", float(f.base) * (1.0 + 0.8 * amount), 0.05)
			tween.tween_property(light, "light_energy", float(f.base), 0.4)

# --- shaders -----------------------------------------------------------------------------------

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.05, 0.12, 0.15, 1.0);
uniform vec4 glow : source_color = vec4(0.3, 0.9, 0.8, 1.0);
float wave(vec2 p, float t) {
	return sin(p.x * 3.1 + t * 1.3) * 0.5 + sin(p.y * 2.3 - t * 1.1) * 0.5 + sin((p.x + p.y) * 4.7 + t * 1.9) * 0.25;
}
void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz;
	float t = TIME;
	float e = 0.05;
	float h = wave(p, t);
	vec3 n = normalize(vec3(wave(p + vec2(e, 0.0), t) - h, 6.0, wave(p + vec2(0.0, e), t) - h));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = tint.rgb * 0.35;
	ROUGHNESS = 0.04;
	METALLIC = 0.1;
	SPECULAR = 1.0;
	float caustic = pow(max(0.0, sin(p.x * 5.0 + t) * sin(p.y * 4.0 - t * 1.2)), 6.0);
	EMISSION = glow.rgb * (0.05 + caustic * 0.35);
	vec2 uv = UV - 0.5;
	ALPHA = smoothstep(0.5, 0.36, length(uv * vec2(1.0, 1.0))) * 0.92;
}
"""

const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz * 0.9;
	float t = TIME * 0.25;
	float n = noise(p + vec2(t, t * 0.6)) * 0.6 + noise(p * 2.3 - vec2(t * 1.4, 0.0)) * 0.3 + noise(p * 5.0 + t) * 0.1;
	float crust = smoothstep(0.52, 0.62, n);
	vec3 hot = mix(vec3(1.0, 0.85, 0.35), vec3(1.0, 0.35, 0.05), n);
	vec3 col = mix(hot * 4.0, vec3(0.08, 0.03, 0.02), crust);
	ALBEDO = col;
	vec2 uv = UV - 0.5;
	float edge = smoothstep(0.5, 0.3, length(uv));
	ALPHA = edge;
}
"""

const MIST_SHADER := """
shader_type fog;
uniform float density = 0.5;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), u.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), u.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}
void fog() {
	vec3 p = WORLD_POSITION * 0.35 + vec3(TIME * 0.06, 0.0, TIME * 0.04);
	float n = noise(p) * 0.65 + noise(p * 2.1 + 3.0) * 0.35;
	float low = 1.0 - clamp(UVW.y, 0.0, 1.0);
	DENSITY = density * smoothstep(0.3, 0.8, n) * low * low;
	ALBEDO = albedo.rgb;
	EMISSION = emission.rgb;
}
"""
