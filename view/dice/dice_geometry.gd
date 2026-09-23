extends RefCounted
## Cached polyhedra with separate playable and decorative surfaces. Small solids use
## hull recovery; larger solids are cut by planes, avoiding a brute-force vertex hull.
## Frames place numerals and orient rolls; surface_frames also includes coin rims and
## crystal tips, which have no value and can never be selected by a roll.

const EPSILON := 0.0004

static var _solids: Dictionary = {}

static func solid(shape: String) -> Dictionary:
	var key := shape.to_upper()
	if not DeepDice.SHAPES.has(key):
		key = "D20"
	if _solids.has(key):
		return _solids[key]
	var built: Dictionary
	match key:
		"D2": built = _coin()
		"D24": built = _polar(_snub_cube())
		"D30": built = _polar(_ico_edges(false))
		"D60": built = _polar(_ico_edges(true))
		"D40", "D50", "D100": built = _polar(_sphere_normals(int(DeepDice.SHAPES[key])))
		_:
			var vertices := _vertices(key)
			var faces := _hull_faces(vertices)
			if key == "D3":
				# Three rectangular sides first, then the six unnumbered tip triangles.
				faces = faces.filter(func(f: PackedInt32Array) -> bool: return f.size() == 4) + faces.filter(func(f: PackedInt32Array) -> bool: return f.size() == 3)
			built = {"vertices": vertices, "faces": faces}
	built.shape = key
	built.surface_frames = _frames(built.vertices, built.faces)
	built.frames = built.surface_frames.slice(0, int(DeepDice.SHAPES[key]))
	_solids[key] = built
	return built

static func shape_for_sides(sides: int) -> String:
	for key in DeepDice.TIERS:
		if sides <= int(DeepDice.SHAPES[key]):
			return str(key)
	return str(DeepDice.TIERS.back())

# --- vertex sets --------------------------------------------------------------

static func _vertices(shape: String) -> PackedVector3Array:
	var points := PackedVector3Array()
	match shape:
		"D3":
			for y in [-0.52, 0.52]:
				for i in 3:
					var angle := TAU * float(i) / 3.0
					points.append(Vector3(cos(angle) * 0.72, y, sin(angle) * 0.72))
			points.append(Vector3.UP)
			points.append(Vector3.DOWN)
		"D4":
			for triple in [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]:
				points.append(Vector3(triple[0], triple[1], triple[2]).normalized())
		"D6":
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					for z in [-1.0, 1.0]:
						points.append(Vector3(x, y, z).normalized())
		"D8":
			for axis in 3:
				for sign in [-1.0, 1.0]:
					var v := Vector3.ZERO
					v[axis] = sign
					points.append(v)
		"D10", "D16":
			# Trapezohedra: the alternating band height keeps every kite planar.
			var count: int = int(DeepDice.SHAPES[shape]) / 2
			var apex := 1.0
			var band := apex * (1.0 - cos(PI / count)) / (1.0 + cos(PI / count))
			if shape == "D10":
				band = 0.105
				apex = band * (1.0 + cos(PI / count)) / (1.0 - cos(PI / count))
			points.append(Vector3(0.0, apex, 0.0))
			points.append(Vector3(0.0, -apex, 0.0))
			for i in count:
				var upper := TAU * float(i) / count
				points.append(Vector3(cos(upper), band, sin(upper)))
				var lower := upper + PI / count
				points.append(Vector3(cos(lower), -band, sin(lower)))
		"D12":
			var phi := (1.0 + sqrt(5.0)) * 0.5
			var inv := 1.0 / phi
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					for z in [-1.0, 1.0]:
						points.append(Vector3(x, y, z))
			for a in [-inv, inv]:
				for b in [-phi, phi]:
					points.append(Vector3(0.0, a, b))
					points.append(Vector3(a, b, 0.0))
					points.append(Vector3(b, 0.0, a))
			var scaled := PackedVector3Array()
			for point in points:
				scaled.append(point.normalized())
			points = scaled
		_:
			var golden := (1.0 + sqrt(5.0)) * 0.5
			for a in [-1.0, 1.0]:
				for b in [-golden, golden]:
					points.append(Vector3(0.0, a, b).normalized())
					points.append(Vector3(a, b, 0.0).normalized())
					points.append(Vector3(b, 0.0, a).normalized())
	return points

static func _coin() -> Dictionary:
	# Bevelled 32-sided coin. Only the two broad disks are playable.
	const SEGMENTS := 32
	var points := PackedVector3Array()
	for ring in [Vector2(0.92, 0.14), Vector2(1.0, 0.08), Vector2(1.0, -0.08), Vector2(0.92, -0.14)]:
		for i in SEGMENTS:
			var angle := TAU * float(i) / SEGMENTS
			points.append(Vector3(cos(angle) * ring.x, ring.y, sin(angle) * ring.x))
	var faces: Array = []
	faces.append(_ordered(points, _indices(0, SEGMENTS), Vector3.UP))
	faces.append(_ordered(points, _indices(3 * SEGMENTS, 4 * SEGMENTS), Vector3.DOWN))
	for ring in 3:
		for i in SEGMENTS:
			var next := (i + 1) % SEGMENTS
			var members: Array[int] = [ring * SEGMENTS + i, ring * SEGMENTS + next, (ring + 1) * SEGMENTS + next, (ring + 1) * SEGMENTS + i]
			faces.append(_ordered(points, members, _centroid(points, members).normalized()))
	return {"vertices": points, "faces": faces}

static func _indices(first: int, end: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(first, end):
		result.append(i)
	return result

static func _snub_cube() -> PackedVector3Array:
	# Dual of the snub cube: 24 congruent pentagons (pentagonal icositetrahedron).
	# t is the tribonacci constant, t^3 = t^2 + t + 1. Permutation parity and
	# sign parity together select one chirality, rather than both mirrored solids.
	var t := 1.839286755214161
	var base := Vector3(1.0, 1.0 / t, t)
	var points := PackedVector3Array()
	var permutations := [[0, 1, 2], [1, 2, 0], [2, 0, 1], [1, 0, 2], [0, 2, 1], [2, 1, 0]]
	for i in permutations.size():
		var p: Array = permutations[i]
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					if x * y * z == (1.0 if i < 3 else -1.0):
						points.append(Vector3(base[p[0]] * x, base[p[1]] * y, base[p[2]] * z).normalized())
	return points

static func _ico_edges(truncated: bool) -> PackedVector3Array:
	# Edge midpoints form the icosidodecahedron, whose dual is the rhombic
	# triacontahedron. Edge thirds form the truncated icosahedron; its dual is
	# the pentakis dodecahedron. Keep their common radius to get true Catalan solids.
	var ico := _vertices("D20")
	var edge := INF
	for j in range(1, ico.size()):
		edge = minf(edge, ico[0].distance_squared_to(ico[j]))
	var points := PackedVector3Array()
	for i in ico.size():
		for j in range(i + 1, ico.size()):
			if absf(ico[i].distance_squared_to(ico[j]) - edge) < EPSILON:
				if truncated:
					points.append(ico[i].lerp(ico[j], 1.0 / 3.0))
					points.append(ico[j].lerp(ico[i], 1.0 / 3.0))
				else:
					points.append((ico[i] + ico[j]) * 0.5)
	return points

static func _sphere_normals(count: int) -> PackedVector3Array:
	# Antipodal Fibonacci samples cut an approximately spherical die into exactly
	# count flat faces. Simulation chooses faces uniformly, not physical tumbling.
	var points := PackedVector3Array()
	var half: int = count / 2
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for i in half:
		var y := (float(i) + 0.5) / half
		var radius := sqrt(1.0 - y * y)
		var angle := golden_angle * i
		var point := Vector3(cos(angle) * radius, y, sin(angle) * radius)
		points.append(point)
		points.append(-point)
	return points

static func _polar(planes: PackedVector3Array) -> Dictionary:
	# Intersect n.dot(p) <= 1 by clipping a small polygon shell. This also constructs
	# the polar dual of a vertex cloud, without recovering a hull of up to 196 vertices.
	var cube := _vertices("D6")
	for i in cube.size():
		cube[i] *= 8.0
	var polygons: Array = []
	for face in _hull_faces(cube):
		var polygon := PackedVector3Array()
		for index in face:
			polygon.append(cube[index])
		polygons.append(polygon)
	for normal in planes:
		var clipped: Array = []
		var cap := PackedVector3Array()
		for polygon in polygons:
			var kept := PackedVector3Array()
			for i in polygon.size():
				var a: Vector3 = polygon[i]
				var b: Vector3 = polygon[(i + 1) % polygon.size()]
				var da := normal.dot(a) - 1.0
				var db := normal.dot(b) - 1.0
				# Symmetric solids often cut exactly through an existing vertex. Include
				# those vertices in the cap, with a tighter tolerance than hull grouping.
				if absf(da) < 0.000001:
					da = 0.0
				if absf(db) < 0.000001:
					db = 0.0
				if da <= 0.0:
					_append_unique(kept, a)
				if da == 0.0:
					_append_unique(cap, a)
				if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
					var cut := a.lerp(b, da / (da - db))
					_append_unique(kept, cut)
					_append_unique(cap, cut)
			if kept.size() >= 3:
				clipped.append(kept)
		if cap.size() >= 3:
			var ordered := PackedVector3Array()
			for index in _ordered(cap, _indices(0, cap.size()), normal):
				ordered.append(cap[index])
			clipped.append(ordered)
		polygons = clipped
	var points := PackedVector3Array()
	var faces: Array = []
	var radius := 0.0
	for polygon in polygons:
		var members := PackedInt32Array()
		for point in polygon:
			members.append(_append_unique(points, point))
			radius = maxf(radius, point.length())
		faces.append(members)
	for i in points.size():
		points[i] /= radius
	return {"vertices": points, "faces": faces}

static func _append_unique(points: PackedVector3Array, point: Vector3) -> int:
	for i in points.size():
		if points[i].distance_squared_to(point) < 0.00000001:
			return i
	points.append(point)
	return points.size() - 1

# --- convex hull face recovery ------------------------------------------------

static func _hull_faces(points: PackedVector3Array) -> Array:
	var planes: Array = []
	var count := points.size()
	for i in range(count):
		for j in range(i + 1, count):
			for k in range(j + 1, count):
				var normal := (points[j] - points[i]).cross(points[k] - points[i])
				if normal.length() < 0.0001:
					continue
				normal = normal.normalized()
				var offset := normal.dot(points[i])
				if offset < 0.0:
					normal = -normal
					offset = -offset
				if offset < 0.0001:
					continue
				var outside := false
				for index in range(count):
					if normal.dot(points[index]) > offset + EPSILON:
						outside = true
						break
				if outside:
					continue
				var duplicate := false
				for plane in planes:
					if plane.normal.dot(normal) > 0.999 and absf(float(plane.offset) - offset) < 0.001:
						duplicate = true
						break
				if duplicate:
					continue
				planes.append({"normal": normal, "offset": offset})
	var faces: Array = []
	for plane in planes:
		var members: Array[int] = []
		for index in range(count):
			if absf(plane.normal.dot(points[index]) - plane.offset) <= EPSILON * 4.0:
				members.append(index)
		if members.size() < 3:
			continue
		faces.append(_ordered(points, members, plane.normal))
	faces.sort_custom(func(a, b) -> bool:
		var ca := _centroid(points, a)
		var cb := _centroid(points, b)
		if absf(ca.y - cb.y) > 0.001:
			return ca.y > cb.y
		return atan2(ca.z, ca.x) < atan2(cb.z, cb.x))
	return faces

static func _ordered(points: PackedVector3Array, members: Array[int], normal: Vector3) -> PackedInt32Array:
	var centre := _centroid(points, members)
	var axis := normal.cross(Vector3.UP)
	if axis.length() < 0.05:
		axis = normal.cross(Vector3.FORWARD)
	axis = axis.normalized()
	var other := normal.cross(axis).normalized()
	var sorted := members.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var pa := points[a] - centre
		var pb := points[b] - centre
		return atan2(pa.dot(other), pa.dot(axis)) < atan2(pb.dot(other), pb.dot(axis)))
	var result := PackedInt32Array()
	for index in sorted:
		result.append(index)
	# Wind counter-clockwise when seen from outside.
	if (points[result[1]] - points[result[0]]).cross(points[result[2]] - points[result[0]]).dot(normal) < 0.0:
		result.reverse()
	return result

static func _plane_normal(points: PackedVector3Array, face: PackedInt32Array, centre: Vector3) -> Vector3:
	## Newell's method: correct for any planar polygon, including the kite faces of a d10.
	var normal := Vector3.ZERO
	for i in range(face.size()):
		var a := points[face[i]]
		var b := points[face[(i + 1) % face.size()]]
		normal += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	if normal.length() < 0.0001:
		return centre.normalized()
	normal = normal.normalized()
	return normal if normal.dot(centre) > 0.0 else -normal

static func _centroid(points: PackedVector3Array, members: Variant) -> Vector3:
	var total := Vector3.ZERO
	for index in members:
		total += points[index]
	return total / maxf(1.0, float(members.size()))

# --- frames and mesh ----------------------------------------------------------

static func _frames(points: PackedVector3Array, faces: Array) -> Array:
	var frames: Array = []
	for face in faces:
		var centre := _centroid(points, face)
		var normal := _plane_normal(points, face, centre)
		var up := Vector3.UP
		if absf(normal.dot(up)) > 0.94:
			up = Vector3.FORWARD
		var plane_up := (up - normal * normal.dot(up)).normalized()
		var plane_right := plane_up.cross(normal).normalized()
		var inradius := INF
		for i in range(face.size()):
			var a := points[face[i]]
			var b := points[face[(i + 1) % face.size()]]
			var edge := b - a
			if edge.length() < 0.0001:
				continue
			inradius = minf(inradius, ((a - centre) - edge.normalized() * (a - centre).dot(edge.normalized())).length())
		frames.append({
			"centre": centre, "normal": normal, "right": plane_right, "up": plane_up,
			"inradius": 0.9 if is_inf(inradius) else inradius, "sides": face.size()})
	return frames

static func mesh(shape: String, colors: PackedColorArray) -> ArrayMesh:
	var built := solid(shape)
	var points: PackedVector3Array = built.vertices
	var faces: Array = built.faces
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(faces.size()):
		var face: PackedInt32Array = faces[index]
		var frame: Dictionary = built.surface_frames[index]
		var color: Color = colors[index % colors.size()] if colors.size() > 0 else Color.WHITE
		for corner in range(1, face.size() - 1):
			# Godot treats clockwise-from-the-front triangles as front facing.
			for offset in [0, corner + 1, corner]:
				surface.set_normal(frame.normal)
				surface.set_color(color)
				var point := points[face[offset]]
				surface.set_uv(Vector2((point - frame.centre).dot(frame.right), (point - frame.centre).dot(frame.up)) * 0.5 + Vector2(0.5, 0.5))
				surface.add_vertex(point)
	surface.index()
	return surface.commit()
