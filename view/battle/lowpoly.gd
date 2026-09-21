extends RefCounted
## Faceted geometry for the chamber: rocks, spikes, crystals, columns, caps. Everything is
## flat-shaded (one normal per facet) and vertex-coloured, so one material lights it all and
## the facets catch the light the way the stones do. Pure mesh building; no scene tree.

## Pass corners so that (b - a) x (c - a) points out of the solid, or name the side it should
## face. Godot calls clockwise-from-the-front triangles front facing, hence the swap on emit.
static func tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color, facing: Vector3 = Vector3.ZERO) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	normal = normal.normalized()
	if facing != Vector3.ZERO and normal.dot(facing) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(tone)
		surface.add_vertex(point)

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: Color, facing: Vector3 = Vector3.ZERO) -> void:
	tri(surface, a, b, c, tone, facing)
	tri(surface, a, c, d, tone, facing)

static func _out(a: Vector3, b: Vector3) -> Vector3:
	return ((a + b) * 0.5).normalized()

static func shade(tone: Color, rng: RandomNumberGenerator, swing: float = 0.12) -> Color:
	var s := rng.randf_range(-swing, swing)
	return tone.lightened(s) if s >= 0.0 else tone.darkened(-s)

static func begin() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

# --- solids --------------------------------------------------------------------------------

const ICO_T := 1.618034

static func _ico() -> Array:
	var t := ICO_T
	var points: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in range(points.size()):
		points[i] = (points[i] as Vector3).normalized()
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	return [points, faces]

static func rock(rng: RandomNumberGenerator, tone: Color, jitter: float = 0.28, squash: Vector3 = Vector3.ONE) -> ArrayMesh:
	## A boulder: an icosahedron knocked about, so no two are alike and all read as stone.
	var built: Array = _ico()
	var points: Array = built[0]
	for i in range(points.size()):
		var p: Vector3 = points[i]
		points[i] = p * (1.0 + rng.randf_range(-jitter, jitter)) * squash
	var surface := begin()
	for face in built[1]:
		var a: Vector3 = points[face[0]]
		var b: Vector3 = points[face[1]]
		var c: Vector3 = points[face[2]]
		tri(surface, a, b, c, shade(tone, rng), (a + b + c).normalized())
	return surface.commit()

static func spike(rng: RandomNumberGenerator, tone: Color, sides: int = 5, radius: float = 0.3, height: float = 1.6, lean: float = 0.12, tip_tone: Color = Color(0, 0, 0, 0)) -> ArrayMesh:
	## A cone of rock from its base at the origin up the Y axis: stalagmites, stalactites
	## (turned over), thorns. Two rings of bark so it is not a perfect cone.
	var surface := begin()
	var base: Array = []
	var mid: Array = []
	var twist := rng.randf_range(0.0, TAU)
	var tip := Vector3(rng.randf_range(-lean, lean) * height, height, rng.randf_range(-lean, lean) * height)
	for i in range(sides):
		var angle := twist + TAU * float(i) / float(sides)
		var r := radius * rng.randf_range(0.8, 1.15)
		base.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		mid.append(Vector3(cos(angle) * r * 0.55, height * 0.42, sin(angle) * r * 0.55) + tip * 0.2 * Vector3(1, 0, 1))
	var top_tone: Color = tip_tone if tip_tone.a > 0.0 else tone.lightened(0.12)
	for i in range(sides):
		var j := (i + 1) % sides
		var out := _out(base[i], base[j])
		quad(surface, base[i], base[j], mid[j], mid[i], shade(tone, rng, 0.1), out)
		tri(surface, mid[i], mid[j], tip, shade(top_tone, rng, 0.1), out + Vector3.UP * 0.3)
	return surface.commit()

static func crystal(rng: RandomNumberGenerator, tone: Color, radius: float = 0.18, height: float = 1.2, sides: int = 6) -> ArrayMesh:
	## A hexagonal prism with a pyramid tip: the unit every crystal growth is made of.
	var surface := begin()
	var shoulder := height * rng.randf_range(0.66, 0.8)
	var ring_low: Array = []
	var ring_high: Array = []
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		var r := radius * rng.randf_range(0.9, 1.1)
		ring_low.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		ring_high.append(Vector3(cos(angle) * r * 0.92, shoulder, sin(angle) * r * 0.92))
	var tip := Vector3(0, height, 0)
	for i in range(sides):
		var j := (i + 1) % sides
		var out := _out(ring_low[i], ring_low[j])
		var facet := tone.lightened(0.18) if i % 2 == 0 else tone.darkened(0.08)
		quad(surface, ring_low[i], ring_low[j], ring_high[j], ring_high[i], facet, out)
		tri(surface, ring_high[i], ring_high[j], tip, tone.lightened(0.3 if i % 2 == 0 else 0.05), out + Vector3.UP)
	return surface.commit()

static func cluster(rng: RandomNumberGenerator, tone: Color, count: int = 5, scale: float = 1.0) -> ArrayMesh:
	## A spray of crystals from one root, leaning outward.
	var surface := begin()
	for n in range(count):
		var height := rng.randf_range(0.5, 1.4) * scale * (1.4 if n == 0 else 1.0)
		var radius := height * rng.randf_range(0.12, 0.18)
		var part := crystal(rng, tone, radius, height)
		var arrays := part.surface_get_arrays(0)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6) if n > 0 else 0.0, rng.randf_range(0, TAU), rng.randf_range(-0.6, 0.6) if n > 0 else 0.0))
		var offset := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)) * scale
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in range(verts.size()):
			surface.set_normal(basis * normals[i])
			surface.set_color(colors[i])
			surface.add_vertex(basis * verts[i] + offset)
	return surface.commit()

static func column(rng: RandomNumberGenerator, tone: Color, sides: int = 6, radius: float = 0.4, height: float = 2.0) -> ArrayMesh:
	## A flat-topped prism: basalt columns, pillars, stumps.
	var surface := begin()
	var ring_low: Array = []
	var ring_high: Array = []
	var tilt := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		ring_low.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
		ring_high.append(Vector3(cos(angle) * radius * 0.96, height, sin(angle) * radius * 0.96) + tilt * height)
	var lid := Vector3(0, height, 0) + tilt * height
	for i in range(sides):
		var j := (i + 1) % sides
		var out := _out(ring_low[i], ring_low[j])
		quad(surface, ring_low[i], ring_low[j], ring_high[j], ring_high[i], shade(tone, rng, 0.1), out)
		tri(surface, ring_high[i], ring_high[j], lid, tone.lightened(0.12), Vector3.UP)
	return surface.commit()

static func cap(rng: RandomNumberGenerator, tone: Color, under: Color, radius: float = 0.8, height: float = 0.45, sides: int = 8) -> ArrayMesh:
	## A mushroom cap: a low cone with a flat, differently coloured gill face underneath.
	var surface := begin()
	var rim: Array = []
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		var r := radius * rng.randf_range(0.9, 1.08)
		rim.append(Vector3(cos(angle) * r, rng.randf_range(-0.04, 0.04), sin(angle) * r))
	var top := Vector3(0, height, 0)
	var middle := Vector3(0, height * 0.15, 0)
	for i in range(sides):
		var j := (i + 1) % sides
		tri(surface, rim[i], rim[j], top, shade(tone, rng, 0.1), _out(rim[i], rim[j]) + Vector3.UP)
		tri(surface, rim[i], rim[j], middle, under, Vector3.DOWN)
	return surface.commit()

static func slab(size: Vector3, tone: Color, rng: RandomNumberGenerator, jitter: float = 0.0) -> ArrayMesh:
	## A box with its corners pushed about, for beams, planks and ruined blocks.
	var h := size * 0.5
	var corners: Array = []
	for z in [-1, 1]:
		for y in [-1, 1]:
			for x in [-1, 1]:
				corners.append(Vector3(x * h.x, y * h.y, z * h.z) + Vector3(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	var faces: Array = [[0, 1, 3, 2, Vector3(0, 0, -1)], [4, 6, 7, 5, Vector3(0, 0, 1)], [0, 4, 5, 1, Vector3(0, -1, 0)],
		[2, 3, 7, 6, Vector3(0, 1, 0)], [0, 2, 6, 4, Vector3(-1, 0, 0)], [1, 5, 7, 3, Vector3(1, 0, 0)]]
	var surface := begin()
	for face in faces:
		quad(surface, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], shade(tone, rng, 0.08), face[4])
	return surface.commit()

static func shard(rng: RandomNumberGenerator, tone: Color, size: float = 0.12) -> ArrayMesh:
	## A splinter of crystal: a stretched tetrahedron, for debris.
	var surface := begin()
	var a := Vector3(0, size * 1.8, 0)
	var b := Vector3(size, 0, 0)
	var c := Vector3(-size * 0.5, 0, size * 0.8)
	var d := Vector3(-size * 0.5, 0, -size * 0.8)
	var centre := (a + b + c + d) * 0.25
	for face in [[a, b, c], [a, c, d], [a, d, b], [b, d, c]]:
		tri(surface, face[0], face[1], face[2], shade(tone, rng, 0.2), ((face[0] + face[1] + face[2]) / 3.0 - centre).normalized())
	return surface.commit()

static func ring(radius: float, width: float, segments: int = 48) -> ArrayMesh:
	## A flat annulus in the XZ plane facing up, for targets, shockwaves and auras.
	var surface := begin()
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var inner0 := Vector3(cos(a0), 0, sin(a0)) * (radius - width)
		var outer0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var inner1 := Vector3(cos(a1), 0, sin(a1)) * (radius - width)
		var outer1 := Vector3(cos(a1), 0, sin(a1)) * radius
		surface.set_uv(Vector2(0, 0))
		quad(surface, inner0, outer0, outer1, inner1, Color.WHITE, Vector3.UP)
	return surface.commit()

static func hex_dome(radius: float = 1.0) -> ArrayMesh:
	## A shallow faceted shield face, for block: a hexagon pushed out at its centre.
	var surface := begin()
	var centre := Vector3(0, 0, radius * 0.25)
	for i in range(6):
		var a0 := TAU * float(i) / 6.0 + PI / 6.0
		var a1 := TAU * float(i + 1) / 6.0 + PI / 6.0
		var p0 := Vector3(cos(a0), sin(a0), 0) * radius
		var p1 := Vector3(cos(a1), sin(a1), 0) * radius
		tri(surface, centre, p0, p1, Color.WHITE.darkened(0.1 * float(i % 2)), Vector3(0, 0, 1))
	return surface.commit()
