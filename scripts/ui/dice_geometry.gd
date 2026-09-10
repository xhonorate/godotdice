extends RefCounted
## Generates real polyhedra for every die shape: tetrahedron, cube, octahedron,
## pentagonal trapezohedron, dodecahedron and icosahedron.
##
## Faces are recovered from the vertex cloud by convex-hull plane grouping, so a new
## shape only needs its vertices. Each face carries a frame (centre, outward normal,
## in-plane axes and inradius) that the die view uses to place a numeral on it.

const EPSILON := 0.0004

static var _solids: Dictionary = {}

static func solid(shape: String) -> Dictionary:
	var key := shape.to_upper()
	if _solids.has(key):
		return _solids[key]
	var vertices := _vertices(key)
	var faces := _hull_faces(vertices)
	var built := {"shape": key, "vertices": vertices, "faces": faces, "frames": _frames(vertices, faces)}
	_solids[key] = built
	return built

static func shape_for_sides(sides: int) -> String:
	if sides <= 4: return "D4"
	if sides <= 6: return "D6"
	if sides <= 8: return "D8"
	if sides <= 10: return "D10"
	if sides <= 12: return "D12"
	return "D20"

# --- vertex sets --------------------------------------------------------------

static func _vertices(shape: String) -> PackedVector3Array:
	var points := PackedVector3Array()
	match shape:
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
		"D10":
			# Pentagonal trapezohedron. The apex height keeps every kite face planar.
			var band := 0.105
			var apex: float = band * (1.0 + cos(deg_to_rad(36.0))) / (1.0 - cos(deg_to_rad(36.0)))
			points.append(Vector3(0.0, apex, 0.0))
			points.append(Vector3(0.0, -apex, 0.0))
			for i in 5:
				var upper := deg_to_rad(72.0 * float(i))
				points.append(Vector3(cos(upper), band, sin(upper)))
				var lower := deg_to_rad(72.0 * float(i) + 36.0)
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
		var frame: Dictionary = built.frames[index]
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
