extends Node3D
## A passage through the rock from one room's far wall to the next room's near end.
##
## One swept tube of faceted rock along a curve. Where it meets a room it is exactly the arch
## every portal in the mine is cut to, so any tunnel fits any room; away from its ends it
## swells and roughens into a cave. The curve runs straight out of the wall, bends hard to one
## side and drops, then runs straight into the next room, so neither room can be seen from
## the other. Its rock and its few props turn from the first room's biome to the second's.
##
## A room builds the first stretch of each of its tunnels as a stub, capped out of sight round
## the bend, so a mouth always shows real rock. The walk builds the rest from the same curve,
## ring for ring, so nothing moves when it does.

const Lowpoly = preload("res://view/battle/lowpoly.gd")

const WIDTH := 3.2
## Where the walls meet the round head, and the top of the arch.
const SPRING := 2.2
const HEIGHT := SPRING + WIDTH * 0.5
## The walls run this far below the floor, so no seam shows at their foot.
const FOOT := -0.4
## Where the walls begin along the curve: just behind the portal in the far wall.
const WALL_GAP := 0.85
## How much of a tunnel a room builds before anyone has chosen it: round the bend.
const STUB := 12.0
const RING_STEP := 0.9
## From one room's far wall to the next room's entrance, along the shaft. Long enough that
## the turn that hides one room from the next is spread over real distance: a shorter tunnel
## with the same offset in it is a corner, and a corner throws the view about as it is walked.
const LENGTH := 27.0

var curve: Curve3D = null
var length: float = 0.0
## The dead end of a stub, hidden once the rest of the tunnel is built past it.
var cap: MeshInstance3D = null

var _from: Dictionary = {}
var _to: Dictionary = {}
var _seed: int = 0
var _noise := FastNoiseLite.new()
var _rock: StandardMaterial3D

# --- shape -------------------------------------------------------------------------------------

static func arch(steps: int = 8) -> PackedVector2Array:
	## A tunnel's ring: from the foot of its left wall, over the round head, to the foot of its
	## right wall. The floor is laid separately.
	var half := WIDTH * 0.5
	var points := PackedVector2Array([Vector2(-half, FOOT), Vector2(-half, SPRING * 0.5), Vector2(-half, SPRING)])
	for i in range(1, steps):
		var angle := PI - PI * float(i) / float(steps)
		points.append(Vector2(cos(angle) * half, SPRING + sin(angle) * half))
	points.append_array(PackedVector2Array([Vector2(half, SPRING), Vector2(half, SPRING * 0.5), Vector2(half, FOOT)]))
	return points

static func outline(centre_x: float, count: int, grow: float = 0.0, bottom: float = -1.2) -> PackedVector2Array:
	## The hole a portal cuts in a wall, closed along a line below the floor, with `count`
	## points spread evenly round it. `grow` pushes it out (a lip) or in (so the wall always
	## overlaps the tube behind it and no sliver of nothing shows at the edge).
	var half := WIDTH * 0.5 + grow
	var dense := PackedVector2Array([Vector2(-half, bottom), Vector2(-half, SPRING)])
	for i in range(1, 32):
		var angle := PI - PI * float(i) / 32.0
		dense.append(Vector2(cos(angle) * half, SPRING + sin(angle) * half))
	dense.append_array(PackedVector2Array([Vector2(half, SPRING), Vector2(half, bottom)]))
	var n: int = dense.size()
	var marks: Array = []
	var total: float = 0.0
	for i in range(n):
		marks.append(total)
		total += dense[i].distance_to(dense[(i + 1) % n])
	var out := PackedVector2Array()
	var index: int = 0
	for k in range(count):
		var goal: float = total * float(k) / float(count)
		while index < n - 1 and float(marks[index + 1]) <= goal:
			index += 1
		var a: Vector2 = dense[index]
		var b: Vector2 = dense[(index + 1) % n]
		var along: float = clampf((goal - float(marks[index])) / maxf(0.0001, a.distance_to(b)), 0.0, 1.0)
		out.append(a.lerp(b, along) + Vector2(centre_x, 0.0))
	return out

static func make_curve(points: Array) -> Curve3D:
	## Straight out of the first wall and straight into the next room, smooth in between: the
	## first and last two points get handles along the shaft, the middle ones Catmull-Rom.
	var made := Curve3D.new()
	made.bake_interval = 0.2
	var count: int = points.size()
	for i in range(count):
		var p: Vector3 = points[i]
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 1, count - 1)]
		var back := Vector3.ZERO
		var ahead := Vector3.ZERO
		if i <= 1 or i >= count - 2:
			back = Vector3(0, 0, absf(p.z - before.z) * 0.4)
			ahead = Vector3(0, 0, -absf(after.z - p.z) * 0.4)
		else:
			ahead = (after - before) / 6.0
			back = - ahead
		made.add_point(p, back, ahead)
	return made

static func ring_distances(total: float) -> Array:
	## Where the rings stand along a tunnel of this length. The stub's last ring is always one
	## of them, so a stub and the rest of its tunnel share it exactly.
	var out: Array = []
	var s: float = WALL_GAP
	var stub_end: float = minf(STUB, total - WALL_GAP)
	while s < stub_end - 0.2:
		out.append(s)
		s += RING_STEP
	out.append(stub_end)
	## At the far end the walls run a hair into the next room, so no gap shows where they meet.
	var end: float = total - WALL_GAP + 0.1
	s = stub_end + RING_STEP
	while s < end - 0.2:
		out.append(s)
		s += RING_STEP
	if end > stub_end + 0.01:
		out.append(end)
	return out

# --- building ----------------------------------------------------------------------------------

func build(from_biome: Dictionary, to_biome: Dictionary, points: Array, seed_value: int, from_s: float, to_s: float, capped: bool) -> void:
	## Builds the stretch of the tunnel between two distances along its curve.
	_from = from_biome
	_to = to_biome if not to_biome.is_empty() else from_biome
	_seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.35
	_noise.fractal_octaves = 2
	_rock = StandardMaterial3D.new()
	_rock.vertex_color_use_as_albedo = true
	_rock.roughness = 0.4 if str(_from.get("id", "")) == "seeps" else 0.88
	_rock.metallic_specular = 0.6 if str(_from.get("id", "")) == "seeps" else 0.35
	curve = make_curve(points)
	length = curve.get_baked_length()
	var rings: Array = []
	for s in ring_distances(length):
		if float(s) >= from_s - 0.01 and float(s) <= to_s + 0.01:
			rings.append(float(s))
	if rings.size() < 2:
		return
	_tube(rings)
	if capped:
		_cap(rings.back())
	_rubble(from_s, to_s)
	_accents(from_s, to_s)
	if not capped:
		_lamps(from_s, to_s)

func point_at(s: float) -> Vector3:
	## The middle of the floor, this far along.
	return curve.sample_baked(clampf(s, 0.0, length)) if curve != null else Vector3.ZERO

func heading_at(s: float) -> Vector3:
	var ahead: Vector3 = point_at(s + 0.3)
	var behind: Vector3 = point_at(s - 0.3)
	var way: Vector3 = ahead - behind
	return way.normalized() if way.length() > 0.001 else Vector3.FORWARD

func _right_at(s: float) -> Vector3:
	var way: Vector3 = heading_at(s)
	var flat := Vector3(-way.z, 0.0, way.x)
	return flat.normalized() if flat.length() > 0.001 else Vector3.RIGHT

func _swell(s: float) -> float:
	## Zero at both portals, one in the body of the tunnel.
	return smoothstep(WALL_GAP, 3.6, s) * smoothstep(WALL_GAP, 3.6, length - s)

func _blend(s: float) -> float:
	## How far this stretch has turned from the first room's biome to the second's.
	return smoothstep(0.5, 0.85, s / maxf(1.0, length))

func _biome_at(s: float) -> Dictionary:
	return _from if s < length * 0.55 else _to

func _tone(field: String, s: float) -> Color:
	return Color(_from.get(field, Color.GRAY)).lerp(Color(_to.get(field, Color.GRAY)), _blend(s))

func _ring(s: float) -> Array:
	var centre: Vector3 = point_at(s)
	var right: Vector3 = _right_at(s)
	var swell: float = _swell(s)
	var wide: float = 1.0 + swell * (0.35 + 0.25 * _noise.get_noise_1d(s * 0.7 + 11.0))
	var tall: float = 1.0 + swell * (0.18 + 0.2 * _noise.get_noise_1d(s * 0.6 + 40.0))
	var axis: Vector3 = centre + Vector3.UP * 1.4
	var out: Array = []
	for p in arch():
		var at: Vector3 = centre + right * p.x * wide + Vector3.UP * p.y * tall
		var push: float = swell * _noise.get_noise_3d(at.x * 0.6, at.y * 0.6, at.z * 0.6) * 0.55 * smoothstep(FOOT, 0.9, p.y)
		out.append(at + (at - axis).normalized() * push)
	return out

func _tube(rings: Array) -> void:
	var walls := Lowpoly.begin()
	var footing := Lowpoly.begin()
	var shade := RandomNumberGenerator.new()
	shade.seed = _seed + int(float(rings[0]) * 10.0)
	var built: Array = []
	for s in rings:
		built.append(_ring(float(s)))
	for k in range(rings.size() - 1):
		var s0: float = rings[k]
		var s1: float = rings[k + 1]
		var a_ring: Array = built[k]
		var b_ring: Array = built[k + 1]
		var middle: Vector3 = (point_at(s0) + point_at(s1)) * 0.5 + Vector3.UP * 1.4
		var rock: Color = _tone("rock", s0)
		var dark: Color = _tone("rock_dark", s0)
		for j in range(a_ring.size() - 1):
			var a: Vector3 = a_ring[j]
			var b: Vector3 = a_ring[j + 1]
			var c: Vector3 = b_ring[j + 1]
			var d: Vector3 = b_ring[j]
			var centre: Vector3 = (a + b + c + d) * 0.25
			var height: float = clampf((centre.y - point_at(s0).y) / HEIGHT, 0.0, 1.0)
			var tone: Color = rock.lerp(dark, 0.25 + height * 0.6)
			var strata: float = sin(centre.y * 2.6 + _noise.get_noise_2d(centre.x, centre.z) * 3.0)
			tone = tone.lightened(0.05 * strata) if strata > 0.0 else tone.darkened(-0.06 * strata)
			var inward: Vector3 = middle - centre
			Lowpoly.tri(walls, a, b, c, Lowpoly.shade(tone, shade, 0.06), inward)
			Lowpoly.tri(walls, a, c, d, Lowpoly.shade(tone, shade, 0.06), inward)
		## The floor: flat underfoot, rubble heaped against the walls. At a portal it sits a
		## hair under the room's own floor, which lies over it for the first stride.
		var across: Array = [-1.3, -0.7, -0.25, 0.25, 0.7, 1.3]
		var rows: Array = []
		for s in [s0, s1]:
			var centre_s: Vector3 = point_at(s)
			var right: Vector3 = _right_at(s)
			var swell: float = _swell(s)
			var wide: float = (1.0 + swell * (0.35 + 0.25 * _noise.get_noise_1d(s * 0.7 + 11.0))) * WIDTH * 0.5
			var row: Array = []
			for u in across:
				var edge: float = maxf(0.0, absf(float(u)) - 0.5)
				var lift: float = swell * (_noise.get_noise_2d(s * 1.3, float(u) * 3.0) * 0.06 + edge * (0.5 + 0.4 * _noise.get_noise_2d(s * 0.9 + 7.0, float(u) * 5.0)))
				row.append(centre_s + right * float(u) * wide + Vector3.UP * (lift - 0.03))
			rows.append(row)
		var ground: Color = _tone("floor", s0)
		for j in range(across.size() - 1):
			var tone: Color = Lowpoly.shade(ground.lerp(rock, 0.25 if j in [0, across.size() - 2] else 0.0), shade, 0.07)
			Lowpoly.quad(footing, rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j], tone, Vector3.UP)
	_place(walls.commit(), false)
	_place(footing.commit(), true)

func _cap(s: float) -> void:
	## The dead end of a stub: out of sight round the bend, and dark.
	var surface := Lowpoly.begin()
	var ring: Array = _ring(s)
	var way: Vector3 = heading_at(s)
	var hub: Vector3 = point_at(s) + Vector3.UP * 1.3 + way * 1.4
	var dark: Color = Color(_from.get("rock_dark", Color.BLACK)).darkened(0.35)
	for j in range(ring.size() - 1):
		Lowpoly.tri(surface, ring[j], ring[j + 1], hub, dark, -way)
	## Close the floor's end as well.
	var centre: Vector3 = point_at(s)
	var right: Vector3 = _right_at(s)
	Lowpoly.quad(surface, centre + right * WIDTH * 0.8 + Vector3.UP * -0.03, centre - right * WIDTH * 0.8 + Vector3.UP * -0.03,
		centre - right * WIDTH * 0.8 + Vector3.UP * FOOT, centre + right * WIDTH * 0.8 + Vector3.UP * FOOT, dark, -way)
	cap = _place(surface.commit(), false)

func _place(mesh: Mesh, shadows: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _rock
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

# --- dressing ----------------------------------------------------------------------------------

func _steps(from_s: float, to_s: float, spacing: float, offset: float = 0.0) -> Array:
	## Fixed places along the whole tunnel, so a stub and the rest of it never double up.
	var out: Array = []
	var s: float = WALL_GAP + 1.5 + offset
	while s < length - WALL_GAP - 1.0:
		if s >= from_s and s < to_s:
			out.append(s)
		s += spacing
	return out

func _rng_at(s: float, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 131 + int(s * 10.0) * 7 + salt
	return rng

func _floor_spot(s: float, u: float) -> Vector3:
	## A point on the floor across the tunnel (u from -1 at the left wall to 1 at the right).
	var swell: float = _swell(s)
	var wide: float = (1.0 + swell * (0.35 + 0.25 * _noise.get_noise_1d(s * 0.7 + 11.0))) * WIDTH * 0.5
	var edge: float = maxf(0.0, absf(u) - 0.5)
	var lift: float = swell * (_noise.get_noise_2d(s * 1.3, u * 3.0) * 0.06 + edge * (0.5 + 0.4 * _noise.get_noise_2d(s * 0.9 + 7.0, u * 5.0)))
	return point_at(s) + _right_at(s) * u * wide + Vector3.UP * (lift - 0.03)

func _rubble(from_s: float, to_s: float) -> void:
	var spots: Array = _steps(from_s, to_s, 1.1)
	if spots.is_empty():
		return
	var rng := _rng_at(from_s, 1)
	var mesh := Lowpoly.rock(rng, _tone("rock", (from_s + to_s) * 0.5).lightened(0.08), 0.35)
	var transforms: Array = []
	for s in spots:
		var local := _rng_at(float(s), 2)
		for side in [-1.0, 1.0]:
			var at: Vector3 = _floor_spot(float(s), side * local.randf_range(0.65, 0.95))
			var scale: float = local.randf_range(0.12, 0.34) * (0.4 + _swell(float(s)))
			transforms.append(Transform3D(Basis.from_euler(Vector3(local.randf(), local.randf() * TAU, local.randf())).scaled(Vector3.ONE * scale), at + Vector3.UP * scale * 0.3))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = _rock
	add_child(node)

func _glowing(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color.lightened(0.1)
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _accents(from_s: float, to_s: float) -> void:
	## A few of each biome's own things leaning in: timber in the galleries, crystal where
	## the rock is crystal, a glow of moss in the wet, seams in the magma.
	for s in _steps(from_s, to_s, 5.5, 1.0):
		var biome: Dictionary = _biome_at(float(s))
		var rng := _rng_at(float(s), 3)
		var lights: Array = biome.get("lights", [biome.get("accent", Color.WHITE)])
		var color: Color = lights[rng.randi() % lights.size()]
		match str(biome.get("id", "")):
			"galleries":
				_timber_frame(float(s), rng)
			"crystal", "geode", "rift":
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.7:
						var at: Vector3 = _floor_spot(float(s) + rng.randf_range(-1.0, 1.0), side * 0.92)
						var node := MeshInstance3D.new()
						node.mesh = Lowpoly.cluster(rng, color, 4, rng.randf_range(0.5, 0.9))
						node.material_override = _glowing(color, 1.1)
						node.position = at
						node.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, side * 0.35)
						add_child(node)
			"seeps", "fungal":
				for i in range(3):
					var side: float = -1.0 if i % 2 == 0 else 1.0
					var at: Vector3 = _floor_spot(float(s) + float(i) * 1.4, side * 0.98) + Vector3.UP * rng.randf_range(0.3, 1.6)
					var patch := MeshInstance3D.new()
					var disc := CylinderMesh.new()
					disc.top_radius = rng.randf_range(0.2, 0.4)
					disc.bottom_radius = disc.top_radius * 1.1
					disc.height = 0.04
					disc.radial_segments = 6
					disc.rings = 1
					patch.mesh = disc
					patch.material_override = _glowing(Color(biome.get("moss", color)), 1.5)
					patch.position = at
					patch.basis = Basis(Quaternion(Vector3.UP, (-_right_at(float(s)) * side).normalized()))
					add_child(patch)
			"magma":
				var seam := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.08, 0.04, rng.randf_range(1.4, 2.6))
				seam.mesh = box
				var hot := _glowing(Color("ff5a10"), 3.2)
				hot.vertex_color_use_as_albedo = false
				seam.material_override = hot
				seam.position = _floor_spot(float(s), rng.randf_range(-0.4, 0.4)) + Vector3.UP * 0.04
				seam.rotation.y = atan2(heading_at(float(s)).x, heading_at(float(s)).z) + rng.randf_range(-0.5, 0.5)
				add_child(seam)

func _timber_frame(s: float, rng: RandomNumberGenerator) -> void:
	var wood := StandardMaterial3D.new()
	wood.vertex_color_use_as_albedo = true
	wood.roughness = 0.95
	var right: Vector3 = _right_at(s)
	var centre: Vector3 = point_at(s)
	var facing := Basis.looking_at(heading_at(s), Vector3.UP)
	var reach: float = WIDTH * 0.5 - 0.3
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = Lowpoly.slab(Vector3(0.26, 2.7, 0.26), Color("6a4428"), rng, 0.02)
		post.material_override = wood
		post.basis = facing
		post.position = centre + right * side * reach + Vector3.UP * 1.2
		add_child(post)
	var beam := MeshInstance3D.new()
	beam.mesh = Lowpoly.slab(Vector3(WIDTH - 0.3, 0.3, 0.32), Color("5a3a22"), rng, 0.03)
	beam.material_override = wood
	beam.basis = facing
	beam.position = centre + Vector3.UP * 2.6
	add_child(beam)

func _lamps(from_s: float, to_s: float) -> void:
	## A little of each biome's own light, so the dark between rooms is not only the lantern's.
	for s in _steps(from_s, to_s, 8.0, 2.5):
		var biome: Dictionary = _biome_at(float(s))
		var lights: Array = biome.get("lights", [biome.get("accent", Color.WHITE)])
		var light := OmniLight3D.new()
		light.light_color = lights[0]
		light.light_energy = 0.9
		light.omni_range = 6.5
		light.omni_attenuation = 1.3
		light.light_volumetric_fog_energy = 0.8
		light.shadow_enabled = false
		light.position = point_at(float(s)) + Vector3.UP * 2.7 + _right_at(float(s)) * 0.8
		add_child(light)
