extends RefCounted
## The rock a raw stone is still half-buried in.
##
## A stone comes out of the wall with its matrix on it: a crust of host rock right round the
## crystal, so that only a window of it shows. Enough to see its color and
## roughly how big it is; not enough to count its facets, trace its girdle for chips, or look
## through it for what is frozen inside. The chunks are knocked off one at a time when it is
## appraised, smallest first, and the last is always the largest, so the stone is seen whole
## only at the very end.
##
## Everything is in the stone's own space, the space `gem_mesh.gd` cuts it in: the girdle
## reaches 1.0 from the centre, the crown rises towards +Z and the pavilion falls towards -Z.
## Chunks are children of whatever turns the stone, so the rock turns with it. Pure geometry:
## nothing here touches the scene tree, and the same stone always gets the same rock.

const GemMesh = preload("res://view/gems/gem_mesh.gd")

## The host rock, warm and dark, so any color of stone reads against it.
const TONE := Color("3e342c")
## The seams a chunk will split along: darker than the rock, and where the light inside the
## stone shows first as it is worked.
const SEAM := Color("1c1713")
## How far each chunk is pulled towards the stone's own hue, as if stained by it.
const STAIN := 0.1
## How the matrix sits on a stone. A ring of chunks goes right round the girdle, close in
## and overlapping, so the rock reads as a crust the stone is grown into rather than three
## boulders stuck to its sides; one more is pressed flat against a face, over the table or
## the pavilion, so the stone cannot be read straight through either; and the bed it grew
## from comes last and largest, over the heart of the crown. Only a window of the stone is
## ever left: enough for its colour and roughly its size, never its facets or its girdle.
## Each chunk is stretched along the girdle and pressed flat on the axis facing the stone.
const RING_DISTANCE := 0.78
const RING_RADIUS := 0.44
## How far the ring's chunks lean in front of the girdle and behind it, turn by turn.
const RING_DEPTH := 0.13
## The chunk laid flat on a face, and the bed: [distance, depth, radius]. The bed sits over
## the middle of the crown rather than off one shoulder: it is the last piece to come away,
## and until it does it should be covering the stone rather than hanging off the side of it.
const FACE_CHUNK: Array = [0.32, 0.34, 0.46]
const BED_CHUNK: Array = [0.13, 0.26, 0.82]
## How a chunk is stretched: out from the stone, along the girdle, and through its depth.
const SQUASH := Vector3(0.78, 1.34, 1.05)

static func ring_count(stone: Dictionary) -> int:
	## How many chunks crust the girdle: enough to close round it with none of them large.
	return 5 if posmod(GemMesh.seed_of(stone), 5) >= 2 else 4

static func chunk_count(stone: Dictionary) -> int:
	## The ring, the one laid flat on a face, and the bed.
	return ring_count(stone) + 2

static func layout(stone: Dictionary) -> Array:
	## Where each chunk sits, as {position, radius, rotation, tone, seed}, in the order they are
	## knocked off: the ring first, smallest to largest, then the face, then the bed. Cheap:
	## no geometry, so a flat picture of the clump can be drawn from it.
	var rng := RandomNumberGenerator.new()
	rng.seed = GemMesh.seed_of(stone) + 7349
	var turn: float = rng.randf_range(0.0, TAU)
	var tone: Color = TONE.lerp(GemMesh.tint(stone), STAIN)
	var shade: Callable = func() -> Color: return tone.lightened(rng.randf_range(-0.05, 0.05))
	var ring: int = ring_count(stone)
	var out: Array = []
	for index in range(ring):
		## Evenly round the girdle, leaning alternately toward the crown and the pavilion, so
		## the crust wraps the stone's waist instead of banding it.
		var angle: float = turn + TAU * float(index) / float(ring) + deg_to_rad(rng.randf_range(-9.0, 9.0))
		var depth: float = (RING_DEPTH if index % 2 == 0 else -RING_DEPTH) + rng.randf_range(-0.04, 0.04)
		var distance: float = RING_DISTANCE + rng.randf_range(-0.05, 0.05)
		out.append({"position": Vector3(cos(angle) * distance, sin(angle) * distance, depth),
			"radius": RING_RADIUS * rng.randf_range(0.92, 1.1),
			"rotation": Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22), angle + rng.randf_range(-0.2, 0.2)),
			"tone": shade.call(), "seed": rng.randi()})
	## One flat against a face: on the crown it hides the table, on the pavilion the culet.
	var crown: bool = rng.randf() < 0.5
	var face_angle: float = turn + rng.randf_range(0.0, TAU)
	var face_distance: float = float(FACE_CHUNK[0]) * rng.randf_range(0.8, 1.2)
	out.append({"position": Vector3(cos(face_angle) * face_distance, sin(face_angle) * face_distance, float(FACE_CHUNK[1]) * (1.0 if crown else -1.0)),
		"radius": float(FACE_CHUNK[2]) * rng.randf_range(0.94, 1.08),
		"rotation": Vector3(0.0, (-PI * 0.5 if crown else PI * 0.5) + rng.randf_range(-0.18, 0.18), rng.randf_range(-0.3, 0.3)),
		"tone": shade.call(), "seed": rng.randi()})
	## The bed it grew from, last and largest, pressed flat over the heart of the crown so
	## the stone is covered to the end and is seen whole only when it splits away.
	var bed_angle: float = turn + PI + rng.randf_range(-0.4, 0.4)
	out.append({"position": Vector3(cos(bed_angle) * float(BED_CHUNK[0]), sin(bed_angle) * float(BED_CHUNK[0]), float(BED_CHUNK[1])),
		"radius": float(BED_CHUNK[2]) * rng.randf_range(0.94, 1.06),
		"rotation": Vector3(0.0, -PI * 0.5 + rng.randf_range(-0.12, 0.12), bed_angle + rng.randf_range(-0.2, 0.2)),
		"tone": shade.call(), "seed": rng.randi()})
	return out

static func chunks(stone: Dictionary) -> Array:
	## The layout with a lump of rock cut for each chunk: adds {mesh, reach}, where `reach` is
	## how far the chunk's furthest point lies from the stone's centre.
	var out: Array = []
	for placed in layout(stone):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(placed.seed)
		var built: Dictionary = boulder(rng, float(placed.radius), placed.tone)
		var chunk: Dictionary = placed.duplicate()
		chunk.mesh = built.mesh
		chunk.reach = (placed.position as Vector3).length() + float(built.reach)
		out.append(chunk)
	return out

static func reach(built: Array) -> float:
	## How far the whole clump reaches from the stone's centre, in girdle radii: never less
	## than the stone itself. A bare layout has no lumps yet, so its reach is the most any
	## lump could have.
	var furthest: float = 1.0
	for chunk in built:
		var own: float = float(chunk.reach) if chunk.has("reach") else (chunk.position as Vector3).length() + float(chunk.radius) * SQUASH.y * 1.2
		furthest = maxf(furthest, own)
	return furthest

static func boulder(rng: RandomNumberGenerator, radius: float, tone: Color) -> Dictionary:
	## A broken lump of rock: a twice-cut icosahedron knocked about, stretched along the
	## girdle, then sheared flat on two or three faces where it split from the rest of the
	## matrix. Flat-shaded, one tone per facet. Two surfaces: the rock, and the seams it will
	## split along, which take a material of their own so they can glow.
	var built: Array = _sphere()
	var points: Array = built[0]
	for index in range(points.size()):
		points[index] = (points[index] as Vector3) * SQUASH * radius * (1.0 + rng.randf_range(-0.2, 0.2))
	## Where it broke: planes that cut the lump flat, so it reads as a fragment, not a pebble.
	for _cut in range(rng.randi_range(2, 3)):
		var normal := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var depth: float = radius * rng.randf_range(0.5, 0.74)
		for index in range(points.size()):
			var p: Vector3 = points[index]
			var over: float = p.dot(normal) - depth
			if over > 0.0:
				points[index] = p - normal * over
	var furthest: float = 0.0
	for p in points:
		furthest = maxf(furthest, (p as Vector3).length())
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seams := SurfaceTool.new()
	seams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = built[1]
	var seamed: int = 0
	for index in range(faces.size()):
		var face: Array = faces[index]
		var a: Vector3 = points[face[0]]
		var b: Vector3 = points[face[1]]
		var c: Vector3 = points[face[2]]
		## About one facet in nine is a seam; the last is one regardless if none has been,
		## so that surface is never empty.
		if rng.randf() < 0.11 or (seamed == 0 and index == faces.size() - 1):
			_facet(seams, a, b, c, SEAM)
			seamed += 1
			continue
		var shade: float = rng.randf_range(-0.16, 0.16)
		var facet: Color = tone.lightened(shade) if shade >= 0.0 else tone.darkened(-shade)
		## Now and then a fleck of quartz in the matrix.
		if rng.randf() < 0.05:
			facet = facet.lerp(Color("b9b1a2"), 0.45)
		_facet(rock, a, b, c, facet)
	var mesh: ArrayMesh = rock.commit()
	seams.commit(mesh)
	return {"mesh": mesh, "reach": furthest}

static func material() -> StandardMaterial3D:
	## Rough, unpolished and opaque, so the crystal behind it is simply gone.
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	## The tones are written as they should look. Read as linear, the way the stone's own
	## facets are, the gem lights bleach them to chalk.
	made.vertex_color_is_srgb = true
	made.roughness = 0.93
	made.metallic_specular = 0.15
	return made

static func seam_material(glow: Color) -> StandardMaterial3D:
	## The seams: dark until the rock is worked, then lit from behind by the stone's own hue,
	## as the light inside finds the cracks.
	var made := material()
	made.emission_enabled = true
	made.emission = glow
	made.emission_energy_multiplier = 0.0
	return made

static func dress(piece: MeshInstance3D, rock: Material, seams: Material) -> void:
	## Rock on the rock, seams on the seams.
	piece.set_surface_override_material(0, rock)
	if piece.mesh != null and piece.mesh.get_surface_count() > 1:
		piece.set_surface_override_material(1, seams)

static func _facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	normal = normal.normalized()
	## Every lump is convex about its own centre, so outward is away from it.
	if normal.dot(a + b + c) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = - normal
	for point in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(tone)
		surface.add_vertex(point)

static var _unit: Array = []

static func _sphere() -> Array:
	## An icosahedron with every face cut into four, points pushed out onto the unit sphere.
	## Shared corners, so knocking the points about keeps the lump closed.
	if not _unit.is_empty():
		return [(_unit[0] as Array).duplicate(), _unit[1]]
	var t: float = 1.618034
	var points: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for index in range(points.size()):
		points[index] = (points[index] as Vector3).normalized()
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var middles: Dictionary = {}
	var split: Array = []
	for face in faces:
		var mid: Array = []
		for pair in [[face[0], face[1]], [face[1], face[2]], [face[2], face[0]]]:
			var key: String = "%d_%d" % [mini(pair[0], pair[1]), maxi(pair[0], pair[1])]
			if not middles.has(key):
				points.append(((points[pair[0]] as Vector3) + (points[pair[1]] as Vector3)).normalized())
				middles[key] = points.size() - 1
			mid.append(middles[key])
		split.append([face[0], mid[0], mid[2]])
		split.append([face[1], mid[1], mid[0]])
		split.append([face[2], mid[2], mid[1]])
		split.append([mid[0], mid[1], mid[2]])
	_unit = [points, split]
	return [points.duplicate(), split]
