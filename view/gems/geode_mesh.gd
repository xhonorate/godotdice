extends RefCounted
## A Geode cut in 3D: a knobbly rind of its mine's rock round a hollow lined with crystal,
## made as two halves that meet along a jagged seam, so it can crack along that seam and fall
## open. `geode_view.gd` lights it and plays it out.
##
## The rind is a sphere sampled in rings about the X axis, swollen by one scale of noise and
## knobbed all over by another, the way a real geode's crust is, and shaded smooth: the grit
## comes from the material, not from the facets. Its tone is darker in the creases between
## the knobs and lighter on them. The seam is the ring halfway round, a little off true at
## every point. Each half closes over its own side of it with its face: the rind in section,
## a thin pale line and a band of agate, an edge of quartz, and behind it the hollow, cut in
## broad facets like the underside of a stone, with a few large crystal points in it.
##
## Each mine's rock has its own rind: pale limestone from the Quarry, wet mossy stone from the
## Seeps, crystal spurs breaking out of the Glass Veins' rock, fungus caps from the Warrens,
## basalt with lit seams from the Furnace, banded agate from the Hollow, void black with violet
## seams and pinpoints of light from the Rift. A color's Geode has points of its color pushing
## out of its seam; the week's is bound in brass.
##
## Everything is in the Geode's own space: about a unit in radius, the seam near the plane
## x = 0, the left half on -x and the right on +x, +y up and +z toward the viewer. Pure
## geometry: nothing here touches the scene tree, and the same Geode always gets the same rock.

## Rings from a pole to the seam, and points round each ring.
const RINGS := 12
const SEGMENTS := 48
## How far the swells push the rind in and out, and the knobs on them.
const SWELLS := 0.085
const KNOBS := 0.055
## How far the seam wanders off its plane, in radians at most.
const SEAM_JAG := 0.1
## The face, as fractions of the rind's section: where the rind ends, the pale line, the band
## of agate, and the quartz edge at the mouth of the hollow.
const BANDS: Array = [0.885, 0.873, 0.83, 0.814]
## How deep the hollow runs into each half, as a share of the half's own reach.
const HOLLOW_DEPTH := 0.72
## How far above the rind the cracks are laid, so the rind never swallows them.
const CRACK_LIFT := 1.012
## The points of the seam that face the viewer, top to bottom: the first half of the ring.
const FRONT := SEGMENTS / 2
## How far down the front of the seam the first blow's hairline runs, in seam points.
const HAIRLINE := 10

## Each mine's rock. `rind` is the rock, `dip` the dark in its creases, `fleck` the odd lighter
## grain; `rim` is the light that catches its edges from behind and `rough` how dull it is (a
## wet one shines). `glow` is the color of whatever in it gives off light.
const LOOKS: Dictionary = {
	"quarry": {"rind": "ad9a78", "fleck": "e8dfc8", "dip": "4f4230", "rim": "fff0d6", "rough": 0.95},
	"seeps": {"rind": "466863", "fleck": "a8d89a", "dip": "142321", "moss": "5f9a3c", "rim": "b4fff0", "rough": 0.42, "wet": true},
	"glass": {"rind": "6c6b98", "fleck": "dcdaff", "dip": "24233d", "spurs": "b7adff", "rim": "d9d4ff", "rough": 0.82},
	"warrens": {"rind": "7a6245", "fleck": "e8dcc0", "dip": "2a2014", "caps": "b8703f", "spots": "f3e3c6", "gill": "d9c3a0", "stem": "eadfca", "rim": "ffe9c4", "rough": 0.95},
	"furnace": {"rind": "3d3330", "fleck": "6a564d", "dip": "0e0a09", "veins": 9, "glow": "ff6a1a", "rim": "ff9a5a", "rough": 0.86},
	"hollow": {"rind": "8a7c9e", "fleck": "f0e8ff", "dip": "2f2640", "stripes": ["efe4ff", "5d4596", "b59ddb", "8a7aa6", "d9c8f5"], "rim": "eadcff", "rough": 0.62},
	"rift": {"rind": "251d36", "fleck": "4a3d66", "dip": "060409", "veins": 5, "glow": "b98aff", "stars": 14, "rim": "a67cff", "rough": 0.55},
}
const BY_MINE: Dictionary = {"QUARRY": "quarry", "SEEPS": "seeps", "GLASS_VEINS": "glass", "WARRENS": "warrens", "FURNACE": "furnace", "GEODE": "hollow", "RIFT": "rift"}
## The brass the week's Geode is bound in.
const BRASS := Color("c99636")

## One surface being built.
class Part:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

static var _cache: Dictionary = {}

static func release() -> void:
	## Lets go of the cut Geodes (their meshes and materials) before the renderer shuts down.
	_cache.clear()

static func look_of(shelf_geode: Dictionary) -> String:
	return str(BY_MINE.get(str(shelf_geode.get("mine", "QUARRY")), "quarry"))

static func seed_of(shelf_geode: Dictionary) -> int:
	return absi(hash(str(shelf_geode.get("id", shelf_geode.get("theme", "geode"))))) % 100000 + 1

static func key_of(shelf_geode: Dictionary, tone: Color) -> String:
	return "%s|%d|%s|%s|%s" % [look_of(shelf_geode), seed_of(shelf_geode), str(bool(shelf_geode.get("weekly", false))),
		str(str(shelf_geode.get("kind", "")) == "color"), tone.to_html()]

static func cached(shelf_geode: Dictionary, tone: Color) -> Dictionary:
	## The Geode if it has been cut already this session, or nothing.
	return _cache.get(key_of(shelf_geode, tone), {})

static func build(shelf_geode: Dictionary, tone: Color) -> Dictionary:
	## Everything the view needs, cached by what decides it, since a Geode is cut the same
	## every time and the shelf is drawn again on every change:
	##   halves    [left, right], each an ArrayMesh whose surfaces are named for their material
	##             (rind, glow, face, wall, crystal, spur, brass)
	##   seam      the front of the seam, top to bottom, lifted just clear of the rind
	##   branches  the cracks that run off it, each {side, points}
	##   scale     how it is stretched, so a caller can find its top and bottom
	##   look      which mine's rock it is, and spur_tone / glow_tone for its spurs and seams
	var known: Dictionary = cached(shelf_geode, tone)
	return known if not known.is_empty() else finish(cut(shelf_geode, tone))

static func finish(made: Dictionary) -> Dictionary:
	## Turns what `cut` made into meshes and keeps it. On the main thread: `cut` is the slow
	## half and may run anywhere, this is the quick half that talks to the renderer.
	if _cache.has(str(made.key)):
		return _cache[str(made.key)]
	var built: Dictionary = made.duplicate()
	var halves: Array = []
	for out in made.parts:
		halves.append(_commit(out))
	built.halves = halves
	built.erase("parts")
	if _cache.size() > 24:
		_cache.clear()
	_cache[str(made.key)] = built
	return built

static func cut(shelf_geode: Dictionary, tone: Color) -> Dictionary:
	## The geometry, as plain arrays: nothing here touches the renderer or anything shared, so
	## it can run on a worker thread.
	var look_key: String = look_of(shelf_geode)
	var seeded: int = seed_of(shelf_geode)
	var strapped: bool = bool(shelf_geode.get("weekly", false))
	var crowned: bool = str(shelf_geode.get("kind", "")) == "color"
	var look: Dictionary = LOOKS[look_key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seeded
	var shape: Dictionary = {"swells": _noise(seeded, 0.9), "knobs": _noise(seeded + 1, 2.9), "grain": _noise(seeded + 2, 1.6),
		"scale": Vector3(rng.randf_range(1.04, 1.1), rng.randf_range(0.88, 0.94), rng.randf_range(0.94, 0.99))}
	var scale: Vector3 = shape.scale
	## Where the seam crosses each meridian: halfway round, give or take.
	var wander: Array = []
	for j in range(SEGMENTS):
		wander.append(rng.randf_range(-1.0, 1.0))
	var seam_polar: Array = []
	for j in range(SEGMENTS):
		var smooth: float = 0.5 * float(wander[j]) + 0.25 * (float(wander[(j + SEGMENTS - 1) % SEGMENTS]) + float(wander[(j + 1) % SEGMENTS]))
		seam_polar.append(PI * 0.5 + smooth * SEAM_JAG)
	## The rind's points, ring by ring from the left pole (0) through the seam (RINGS) to the
	## right pole (2 * RINGS), with how far each stands out from the centre.
	var grid: Array = []
	var lifts: Array = []
	for i in range(2 * RINGS + 1):
		var row: Array = []
		var row_lift: Array = []
		if i == 0 or i == 2 * RINGS:
			var pole := Vector3(-1.0 if i == 0 else 1.0, 0.0, 0.0)
			var r: float = _radius(shape, pole)
			row.append(pole * r * scale)
			row_lift.append(r)
		else:
			for j in range(SEGMENTS):
				var turn: float = TAU * (float(j) + rng.randf_range(-0.15, 0.15)) / float(SEGMENTS)
				var polar: float
				if i <= RINGS:
					polar = float(seam_polar[j]) * float(i) / float(RINGS)
				else:
					polar = float(seam_polar[j]) + (PI - float(seam_polar[j])) * float(i - RINGS) / float(RINGS)
				if i != RINGS:
					polar += rng.randf_range(-0.12, 0.12) * PI / float(2 * RINGS)
				var d := _direction(polar, turn)
				var r: float = _radius(shape, d)
				row.append(d * r * scale)
				row_lift.append(r)
		grid.append(row)
		lifts.append(row_lift)
	var parts: Array = [ {}, {}]
	_rind(parts, grid, lifts, look, shape, rng)
	## The face: the seam, then each band's edge inside it, closing in on the mouth of the
	## hollow. The bands wander a little, as agate does, but never cross.
	var seam_row: Array = grid[RINGS]
	var loops: Array = [seam_row]
	var mouth_share: float = float(BANDS[BANDS.size() - 1])
	for b in range(BANDS.size()):
		var loop: Array = []
		var phase: float = rng.randf_range(0.0, TAU)
		var waves: float = float(rng.randi_range(2, 5))
		for j in range(SEGMENTS):
			var share: float = float(BANDS[b]) + 0.014 * sin(waves * TAU * float(j) / float(SEGMENTS) + phase) + rng.randf_range(-0.004, 0.004)
			if b > 0:
				share = minf(share, _share_of(loops[b][j], seam_row[j]) - 0.01)
			var at: Vector3 = seam_row[j]
			var flat: float = pow(clampf((share - mouth_share) / (1.0 - mouth_share), 0.0, 1.0), 0.6) if b < BANDS.size() - 1 else 0.0
			loop.append(Vector3(at.x * flat, at.y * share, at.z * share))
		loops.append(loop)
	var tones: Array = _band_tones(look, tone)
	for side in [-1, 1]:
		var out: Dictionary = parts[_index(side)]
		var facing := Vector3(-float(side), 0.0, 0.0)
		for b in range(loops.size() - 1):
			var outer: Array = loops[b]
			var inner: Array = loops[b + 1]
			for j in range(SEGMENTS):
				var n: int = (j + 1) % SEGMENTS
				for tri in [[outer[j], outer[n], inner[j]], [outer[n], inner[n], inner[j]]]:
					var shade: Color = tones[b]
					shade = shade.lightened(rng.randf_range(0.0, 0.04)) if rng.randf() < 0.5 else shade.darkened(rng.randf_range(0.0, 0.06))
					_tri(out, "face", tri[0], tri[1], tri[2], shade, facing)
	## The hollow, and the crystal growing into it.
	var mouth: Array = loops[loops.size() - 1]
	for side in [-1, 1]:
		_hollow(parts[_index(side)], side, mouth, loops[loops.size() - 2], scale, tone, rng)
	## What each mine adds to the outside.
	var spur_tone: Color = Color(str(look.get("spurs", "ffffff")))
	if look.has("spurs"):
		_spurs(parts, shape, seam_polar, rng, spur_tone)
	if look.has("caps"):
		_caps(parts, shape, seam_polar, rng, look)
	if look.has("veins"):
		_veins(parts, shape, seam_polar, rng, int(look.veins), Color(str(look.glow)))
	if look.has("stars"):
		_stars(parts, shape, seam_polar, rng, int(look.stars))
	if crowned:
		spur_tone = tone
		_crown(parts, seam_row, rng, tone)
	if strapped:
		_straps(parts, shape, seam_polar)
	## The cracks: the front of the seam, and the six that branch off it, the first two off
	## the stretch the first blow opens.
	var seam_front := PackedVector3Array()
	for j in range(FRONT + 1):
		seam_front.append((seam_row[j % SEGMENTS] as Vector3) * CRACK_LIFT)
	var branches: Array = []
	for index in range(6):
		var side: int = -1 if index % 2 == 0 else 1
		var j: int = rng.randi_range(3, HAIRLINE - 1) if index < 2 else rng.randi_range(4, FRONT - 4)
		var turn: float = TAU * float(j) / float(SEGMENTS)
		var polar: float = float(seam_polar[j])
		var points := PackedVector3Array([seam_front[j]])
		for step in range(5):
			polar += float(side) * rng.randf_range(0.06, 0.11)
			turn += rng.randf_range(-0.1, 0.1)
			var d := _direction(polar, turn)
			points.append(d * _radius(shape, d) * scale * CRACK_LIFT)
		branches.append({"side": side, "points": points})
	return {"key": key_of(shelf_geode, tone), "parts": parts, "seam": seam_front, "branches": branches, "scale": scale, "look": look_key,
		"spur_tone": spur_tone, "glow_tone": Color(str(look.get("glow", "ffffff")))}

static func ribbon(points: PackedVector3Array, width: float, taper: bool) -> ArrayMesh:
	## A crack laid on the rind: a dark gap, and the thin line of light down the middle of it.
	## Two surfaces, "gap" and "line", so the light can be turned up on its own. A branch
	## narrows to nothing at its far end.
	var out: Dictionary = {}
	for layer in [["gap", 2.4, 1.0], ["line", 1.0, 1.004]]:
		_strip(out, str(layer[0]), points, width * float(layer[1]), float(layer[2]), taper, Color.WHITE)
	return _commit(out)

static func _strip(out: Dictionary, surface: String, points: PackedVector3Array, width: float, lift: float, taper: bool, tone: Color) -> void:
	var left: Array = []
	var right: Array = []
	for index in range(points.size()):
		var at: Vector3 = points[index] * lift
		var before: Vector3 = points[maxi(0, index - 1)]
		var after: Vector3 = points[mini(points.size() - 1, index + 1)]
		var along: Vector3 = (after - before).normalized()
		var across: Vector3 = along.cross(at.normalized()).normalized()
		var t: float = float(index) / float(maxi(1, points.size() - 1))
		var w: float = width * (lerpf(1.0, 0.1, t) if taper else 1.0) * 0.5
		left.append(at - across * w)
		right.append(at + across * w)
	for index in range(points.size() - 1):
		var up: Vector3 = (points[index] + points[index + 1]).normalized()
		_tri(out, surface, left[index], right[index], left[index + 1], tone, up)
		_tri(out, surface, right[index], right[index + 1], left[index + 1], tone, up)

# --- the rind ---------------------------------------------------------------------------------------

static func _rind(parts: Array, grid: Array, lifts: Array, look: Dictionary, shape: Dictionary, rng: RandomNumberGenerator) -> void:
	## The crust, half by half, shaded smooth: each point's normal is the average of the
	## facets round it, the seam's taken from both halves so it does not show until it cracks.
	var tris: Array = [[], []]
	for side in [-1, 1]:
		var first: int = 0 if side < 0 else RINGS
		for i in range(first, first + RINGS):
			for j in range(SEGMENTS):
				var n: int = (j + 1) % SEGMENTS
				var corners: Array
				if grid[i].size() == 1:
					corners = [[[i, 0], [i + 1, j], [i + 1, n]]]
				elif grid[i + 1].size() == 1:
					corners = [[[i, j], [i, n], [i + 1, 0]]]
				elif (i + j) % 2 == 0:
					corners = [[[i, j], [i, n], [i + 1, j]], [[i, n], [i + 1, n], [i + 1, j]]]
				else:
					corners = [[[i, j], [i + 1, n], [i + 1, j]], [[i, j], [i, n], [i + 1, n]]]
				for tri in corners:
					tris[_index(side)].append(tri)
	var normals: Dictionary = {}
	for half in tris:
		for tri in half:
			var a: Vector3 = grid[tri[0][0]][tri[0][1]]
			var b: Vector3 = grid[tri[1][0]][tri[1][1]]
			var c: Vector3 = grid[tri[2][0]][tri[2][1]]
			var facet: Vector3 = (b - a).cross(c - a)
			if facet.dot(a + b + c) < 0.0:
				facet = - facet
			for corner in tri:
				var at: Vector2i = Vector2i(int(corner[0]), int(corner[1]))
				normals[at] = (normals.get(at, Vector3.ZERO) as Vector3) + facet
	var tones: Dictionary = {}
	for at in normals:
		var point: Vector3 = grid[at.x][at.y]
		var normal: Vector3 = (normals[at] as Vector3).normalized()
		normals[at] = normal
		tones[at] = _rind_tone(look, shape, rng, point, normal, float(lifts[at.x][at.y]))
	for index in range(2):
		var out: Dictionary = parts[index]
		for tri in tris[index]:
			var keys: Array = []
			for corner in tri:
				keys.append(Vector2i(int(corner[0]), int(corner[1])))
			_smooth(out, "rind", [grid[keys[0].x][keys[0].y], grid[keys[1].x][keys[1].y], grid[keys[2].x][keys[2].y]],
				[normals[keys[0]], normals[keys[1]], normals[keys[2]]], [tones[keys[0]], tones[keys[1]], tones[keys[2]]])

static func _rind_tone(look: Dictionary, shape: Dictionary, rng: RandomNumberGenerator, point: Vector3, normal: Vector3, lift: float) -> Color:
	## A point of the crust: dark down in the creases, catching the light on the knobs, and
	## whatever its mine adds.
	var knob: float = _knob(shape, point.normalized())
	var base := Color(str(look.rind))
	var tone: Color = base.lerp(Color(str(look.dip)), clampf((0.42 - knob) * 1.3, 0.0, 0.75))
	tone = tone.lightened(clampf((lift - 1.0) / SWELLS, 0.0, 1.0) * 0.1)
	var jitter: float = rng.randf_range(-0.05, 0.05)
	tone = tone.lightened(jitter) if jitter > 0.0 else tone.darkened(-jitter)
	if rng.randf() < 0.06:
		tone = tone.lerp(Color(str(look.fleck)), 0.35)
	var grain: float = (shape.grain as FastNoiseLite).get_noise_3dv(point)
	if look.has("moss") and normal.y > 0.05 and grain > -0.3:
		## Moss on whatever faces up, thickest on top and on the knobs.
		tone = tone.lerp(Color(str(look.moss)).darkened(0.15 * (1.0 - knob)), clampf(0.3 + normal.y * 0.55 + grain * 0.35, 0.0, 0.9))
	if look.has("stripes"):
		## Bands of agate wrapped round the outside, tilted, wandering with the grain.
		var stripes: Array = look.stripes
		var t: float = point.dot(Vector3(0.35, 1.0, 0.2).normalized()) * 4.6 + grain * 1.1
		var band: int = posmod(int(floor(t)), stripes.size())
		tone = tone.lerp(Color(str(stripes[band])), 0.55 * clampf(knob + 0.4, 0.3, 1.0))
	return tone

static func _band_tones(look: Dictionary, tone: Color) -> Array:
	## The face's bands, outside in: the rind in section, a thin pale line of chalcedony, a
	## band of agate stained by the crystal, and a bright edge of quartz at the mouth.
	var rind := Color(str(look.rind))
	var section: Color = rind.darkened(0.25) if rind.get_luminance() > 0.2 else rind.lightened(0.08)
	var chalcedony: Color = Color("cfccc6").lerp(tone, 0.25)
	var agate: Color = tone.lerp(Color("2e3140"), 0.5)
	var quartz: Color = tone.lightened(0.12)
	return [section, chalcedony, agate, quartz]

# --- the hollow -------------------------------------------------------------------------------------

static func _hollow(out: Dictionary, side: int, mouth: Array, rim: Array, scale: Vector3, tone: Color, rng: RandomNumberGenerator) -> void:
	## A bowl behind the face cut in a few broad facets, like the underside of a stone, and a
	## handful of large crystal points rising from its floor toward the viewer. Nothing small and
	## nothing dark: a hollow crowded with little points and the shadows between them reads as
	## a field of pits, which is unpleasant to look at, so every form in here is large and the
	## floor is the crystal's own color.
	var depth: float = HOLLOW_DEPTH * scale.x * rng.randf_range(0.94, 1.04)
	var outward := Vector3(-float(side), 0.0, 0.0)
	var heart := Vector3(float(side) * depth * 0.4, 0.0, 0.0)
	## The crystal a little richer than the Geode's own color, which is drawn for the rind.
	tone = Color.from_hsv(tone.h, minf(1.0, tone.s * 1.2 + 0.1), tone.v * 0.9)
	## The rings of the bowl, coarser as it deepens: each a list of points with the turn each
	## sits at, so rings of different counts can be stitched together.
	var rings: Array = [_loop_turns(mouth)]
	for spec in [[0.16, 16, 0.0], [0.5, 10, 0.5], [0.8, 6, 0.25]]:
		var angle: float = float(spec[0]) * PI * 0.5
		var count: int = int(spec[1])
		var points: Array = []
		var turns: Array = []
		for c in range(count):
			var turn: float = (float(c) + float(spec[2])) / float(count)
			var m: Vector3 = mouth[int(round(turn * float(SEGMENTS))) % SEGMENTS]
			var swell: float = 1.0 + rng.randf_range(-0.07, 0.07)
			points.append(Vector3(float(side) * depth * sin(angle) * swell, m.y * cos(angle) * swell, m.z * cos(angle) * swell))
			turns.append(turn)
		rings.append([points, turns])
	var bottom := Vector3(float(side) * depth, rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	## Deeper in color toward the floor, so the bowl reads as a bowl, never toward black.
	var deepest: Color = Color.from_hsv(tone.h, minf(1.0, tone.s * 1.3 + 0.08), tone.v * 0.72)
	for k in range(rings.size() - 1):
		_stitch(out, "crystal", rings[k], rings[k + 1], tone.lerp(deepest, float(k) / float(rings.size())), heart, rng)
	var last: Array = rings[rings.size() - 1][0]
	for c in range(last.size()):
		var mid: Vector3 = (last[c] + last[(c + 1) % last.size()] + bottom) / 3.0
		_tri(out, "crystal", last[c], last[(c + 1) % last.size()], bottom, _facet_tone(deepest, rng), heart - mid)
	## The points: a cluster from the floor, the tallest in the middle, and a few shorter ones
	## leaning in from the walls.
	## Fanned out so they are seen from the side, each one large enough to read on its own.
	var tall: int = rng.randi_range(3, 4)
	var first_turn: float = rng.randf_range(0.0, TAU)
	for index in range(tall):
		var turn: float = first_turn + TAU * float(index) / float(tall) + rng.randf_range(-0.4, 0.4)
		var spoke := Vector3(0.0, cos(turn), sin(turn))
		var base: Vector3 = bottom * 0.97 + spoke * (0.0 if index == 0 else 0.08)
		var lean: float = 0.25 if index == 0 else rng.randf_range(0.7, 1.0)
		var length: float = (0.82 if index == 0 else rng.randf_range(0.6, 0.72)) * depth
		_crystal(out, "crystal", base, (outward + spoke * lean).normalized(), length, length * rng.randf_range(0.26, 0.3), _crystal_tone(tone, rng).lightened(0.06), rng)
	## A ring of points round the walls, leaning in over the floor.
	var wall: Array = rings[1][0]
	var around: int = rng.randi_range(6, 7)
	var offset: int = rng.randi_range(0, wall.size() - 1)
	for index in range(around):
		var at: Vector3 = (wall[(offset + int(round(float(index) * float(wall.size()) / float(around)))) % wall.size()] as Vector3).lerp(rings[2][0][index % rings[2][0].size()], rng.randf_range(0.0, 0.35))
		var inward: Vector3 = (heart - at).normalized()
		var length: float = rng.randf_range(0.5, 0.6) * depth
		_crystal(out, "crystal", at, (inward + outward * 0.3 + _wobble(rng, 0.1)).normalized(), length, length * rng.randf_range(0.2, 0.23), _crystal_tone(tone, rng), rng)

static func _loop_turns(loop: Array) -> Array:
	## A face loop with the turn each point sits at, as `_stitch` wants it.
	var turns: Array = []
	for p in loop:
		turns.append(fposmod(atan2((p as Vector3).z, (p as Vector3).y), TAU) / TAU)
	return [loop, turns]

static func _stitch(out: Dictionary, surface: String, outer: Array, inner: Array, tone: Color, heart: Vector3, rng: RandomNumberGenerator) -> void:
	## Joins two rings of different counts with a band of facets, walking both round together
	## and always stepping along whichever is behind.
	var a: Array = outer[0]
	var ta: Array = outer[1]
	var b: Array = inner[0]
	var tb: Array = inner[1]
	var i: int = 0
	var k: int = 0
	while i < a.size() or k < b.size():
		var next_a: float = _unwrapped(ta, i + 1)
		var next_b: float = _unwrapped(tb, k + 1)
		var p: Vector3 = a[i % a.size()]
		var q: Vector3 = b[k % b.size()]
		if k >= b.size() or (i < a.size() and next_a <= next_b):
			var r: Vector3 = a[(i + 1) % a.size()]
			_tri(out, surface, p, r, q, _facet_tone(tone, rng), heart - (p + r + q) / 3.0)
			i += 1
		else:
			var r: Vector3 = b[(k + 1) % b.size()]
			_tri(out, surface, p, r, q, _facet_tone(tone, rng), heart - (p + r + q) / 3.0)
			k += 1

static func _unwrapped(turns: Array, index: int) -> float:
	## A ring's turn at an index that may run past the end, counted on past a whole turn. A
	## first point a hair short of the top counts as just before nought, not just before one.
	var size: int = turns.size()
	var at: float = float(turns[index % size])
	if index % size == 0 and at > 0.5:
		at -= 1.0
	return at + float(index / size)

static func _facet_tone(tone: Color, rng: RandomNumberGenerator) -> Color:
	## One broad facet of the hollow, lighter or darker than its neighbours as a cut stone's are.
	var shade: float = rng.randf_range(-0.16, 0.18)
	return tone.lightened(shade) if shade > 0.0 else tone.darkened(-shade)

static func _crystal_tone(tone: Color, rng: RandomNumberGenerator) -> Color:
	## Each point a little lighter or darker than the next, and now and then a clear one.
	var shade: float = rng.randf_range(-0.12, 0.1)
	var made: Color = tone.lightened(shade) if shade > 0.0 else tone.darkened(-shade)
	if rng.randf() < 0.06:
		made = made.lerp(Color("f4f1ff"), 0.5)
	return made

static func _crystal(out: Dictionary, surface: String, base: Vector3, axis: Vector3, length: float, width: float, tone: Color, rng: RandomNumberGenerator) -> void:
	## One crystal point: a short six-sided prism sunk into the rock with a pyramid on it,
	## its sides deeper in color than its tip, and every face flat so it flashes as it turns.
	var across: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(across).normalized()
	var twist: float = rng.randf_range(0.0, TAU)
	var root: Vector3 = base - axis * length * 0.2
	var shoulder: Vector3 = base + axis * length * rng.randf_range(0.3, 0.48)
	var tip: Vector3 = base + axis * length + _wobble(rng, length * 0.06)
	var centre: Vector3 = base + axis * length * 0.35
	var lower: Array = []
	var upper: Array = []
	for k in range(6):
		var angle: float = twist + TAU * float(k) / 6.0
		var spoke: Vector3 = across * cos(angle) + other * sin(angle)
		var reach: float = width * rng.randf_range(0.85, 1.1)
		lower.append(root + spoke * reach)
		upper.append(shoulder + spoke * reach * 0.96)
	var side_tone: Color = tone.darkened(0.42)
	var tip_tone: Color = tone.lerp(Color.WHITE, 0.05)
	for k in range(6):
		var n: int = (k + 1) % 6
		var face: Color = side_tone.lightened(0.07 * float(k % 3))
		_tri(out, surface, lower[k], lower[n], upper[k], face, (lower[k] + upper[n]) * 0.5 - centre)
		_tri(out, surface, lower[n], upper[n], upper[k], face, (lower[n] + upper[k]) * 0.5 - centre)
		_tri(out, surface, upper[k], upper[n], tip, tip_tone.darkened(0.08 * float(k % 2)), (upper[k] + upper[n] + tip) / 3.0 - centre)

static func _wobble(rng: RandomNumberGenerator, amount: float) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * amount

# --- what each mine adds ------------------------------------------------------------------------------

static func _spot(rng: RandomNumberGenerator, upward: float) -> Vector3:
	## A direction on the rind clear of the seam and facing the viewer more than not; `upward`
	## keeps it to the top as well.
	for _try in range(40):
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0)).normalized()
		if absf(d.x) > 0.3 and d.y >= upward:
			return d
	return Vector3(0.7, 0.5, 0.5).normalized()

static func _on_rind(shape: Dictionary, d: Vector3) -> Vector3:
	return d * _radius(shape, d) * (shape.scale as Vector3)

static func _spurs(parts: Array, shape: Dictionary, seam_polar: Array, rng: RandomNumberGenerator, tone: Color) -> void:
	## The Glass Veins: clusters of crystal breaking out through the rind.
	for cluster in range(6):
		var d: Vector3 = _spot(rng, -0.6)
		var base: Vector3 = _on_rind(shape, d) * 0.96
		var out: Dictionary = parts[_index(_side_of(base, shape.scale, seam_polar))]
		var grand: float = 1.0 if cluster < 2 else 0.7
		for _k in range(rng.randi_range(3, 6)):
			var axis: Vector3 = (d + _wobble(rng, 0.55)).normalized()
			var length: float = rng.randf_range(0.14, 0.34) * grand
			_crystal(out, "spur", base + _wobble(rng, 0.07), axis, length, length * 0.26, _crystal_tone(tone, rng), rng)

static func _caps(parts: Array, shape: Dictionary, seam_polar: Array, rng: RandomNumberGenerator, look: Dictionary) -> void:
	## The Warrens: fungus caps growing out of the crust, in twos and threes.
	for cluster in range(4):
		var d: Vector3 = _spot(rng, 0.0 if cluster < 3 else -0.5)
		var base: Vector3 = _on_rind(shape, d) * 0.985
		var out: Dictionary = parts[_index(_side_of(base, shape.scale, seam_polar))]
		for k in range(rng.randi_range(2, 3)):
			var at: Vector3 = base + _wobble(rng, 0.08)
			var axis: Vector3 = (d + Vector3.UP * 0.7 + _wobble(rng, 0.25)).normalized()
			var reach: float = rng.randf_range(0.11, 0.17) * (1.0 if k == 0 else 0.62)
			_mushroom(out, at, axis, reach, look, rng)

static func _mushroom(out: Dictionary, base: Vector3, axis: Vector3, reach: float, look: Dictionary, rng: RandomNumberGenerator) -> void:
	var across: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(across).normalized()
	var height: float = reach * rng.randf_range(0.8, 1.2)
	var top: Vector3 = base + axis * height
	var stem: float = reach * 0.26
	var count: int = 9
	var ring_low: Array = []
	var ring_high: Array = []
	var brim: Array = []
	var crown: Array = []
	for k in range(count):
		var angle: float = TAU * float(k) / float(count)
		var spoke: Vector3 = across * cos(angle) + other * sin(angle)
		ring_low.append(base - axis * 0.04 + spoke * stem * 1.15)
		ring_high.append(top + spoke * stem * 0.8)
		brim.append(top - axis * reach * 0.14 + spoke * reach)
		crown.append(top + axis * reach * 0.36 + spoke * reach * 0.7)
	var peak: Vector3 = top + axis * reach * 0.56
	var cap := Color(str(look.caps))
	var stem_tone := Color(str(look.stem))
	var mid: Vector3 = base + axis * height * 0.5
	for k in range(count):
		var n: int = (k + 1) % count
		_tri(out, "rind", ring_low[k], ring_low[n], ring_high[k], stem_tone, ring_low[k] - mid)
		_tri(out, "rind", ring_low[n], ring_high[n], ring_high[k], stem_tone.darkened(0.05), ring_low[n] - mid)
		## The gills underneath, then the cap in two bands up to its peak.
		_tri(out, "rind", ring_high[k], brim[n], brim[k], Color(str(look.gill)), -axis)
		var spotted: bool = (k * 7 + int(reach * 100.0)) % 4 == 0
		var shade: Color = Color(str(look.spots)) if spotted else cap.darkened(0.05 * float(k % 2))
		_tri(out, "rind", brim[k], brim[n], crown[k], shade, (brim[k] + crown[n]) * 0.5 - top)
		_tri(out, "rind", brim[n], crown[n], crown[k], shade, (brim[n] + crown[k]) * 0.5 - top)
		_tri(out, "rind", crown[k], crown[n], peak, cap.darkened(0.1), axis)

static func _veins(parts: Array, shape: Dictionary, seam_polar: Array, rng: RandomNumberGenerator, count: int, tone: Color) -> void:
	## The Furnace and the Rift: seams of light wandering over the crust, forking now and then.
	for _vein in range(count):
		var d: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 1.0)).normalized()
		var heading: Vector3 = d.cross(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))).normalized()
		var points := PackedVector3Array()
		var steps: int = rng.randi_range(7, 12)
		for _s in range(steps):
			points.append(_on_rind(shape, d) * 1.006)
			heading = (heading + _wobble(rng, 0.55)).normalized()
			heading = (heading - d * heading.dot(d)).normalized()
			d = (d + heading * 0.11).normalized()
		_split_strip(parts, shape, seam_polar, points, rng.randf_range(0.018, 0.034), tone)

static func _split_strip(parts: Array, shape: Dictionary, seam_polar: Array, points: PackedVector3Array, width: float, tone: Color) -> void:
	## A strip laid over the crust, each length of it kept by the half it lies on.
	var run := PackedVector3Array()
	var side: int = 0
	for index in range(points.size()):
		var own: int = _side_of(points[index], shape.scale, seam_polar)
		if side != 0 and own != side:
			if run.size() > 1:
				_strip(parts[_index(side)], "glow", run, width, 1.0, false, tone)
			run = PackedVector3Array()
		side = own
		run.append(points[index])
	if run.size() > 1:
		_strip(parts[_index(side)], "glow", run, width, 1.0, true, tone)

static func _stars(parts: Array, shape: Dictionary, seam_polar: Array, rng: RandomNumberGenerator, count: int) -> void:
	## The Rift: pinpoints of light set in the black, like a sky seen through the rock.
	for _star in range(count):
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0)).normalized()
		var at: Vector3 = _on_rind(shape, d) * 0.995
		var out: Dictionary = parts[_index(_side_of(at, shape.scale, seam_polar))]
		var size_of: float = rng.randf_range(0.012, 0.03)
		_crystal(out, "glow", at, d, size_of * 1.6, size_of, Color("f6efff"), rng)

static func _crown(parts: Array, seam_row: Array, rng: RandomNumberGenerator, tone: Color) -> void:
	## A color's Geode: points of its color pushing out through the front of the seam.
	var used: Dictionary = {}
	for index in range(7):
		var j: int = rng.randi_range(4, FRONT - 5)
		if used.has(j / 2):
			continue
		used[j / 2] = true
		var at: Vector3 = (seam_row[j] as Vector3) * 0.95
		var axis: Vector3 = (at.normalized() + Vector3.UP * 0.4 + _wobble(rng, 0.4)).normalized()
		var length: float = rng.randf_range(0.2, 0.38)
		_crystal(parts[index % 2], "spur", at, axis, length, length * 0.3, _crystal_tone(tone, rng), rng)

static func _straps(parts: Array, shape: Dictionary, seam_polar: Array) -> void:
	## The week's Geode: two brass straps round it, crossing on its front, riveted where they
	## cross. They are cut where they pass over the seam, so each half keeps its own lengths.
	var rings: Array = [Vector3(0.16, 1.0, 0.1).normalized(), Vector3(0.8, 0.04, 0.6).normalized()]
	for normal in rings:
		var start: Vector3 = (normal as Vector3).cross(Vector3.FORWARD if absf((normal as Vector3).z) < 0.9 else Vector3.UP).normalized()
		var steps: int = 96
		var points: Array = []
		for k in range(steps + 1):
			var d: Vector3 = start.rotated(normal, TAU * float(k) / float(steps))
			points.append(d * (_radius(shape, d) + 0.022) * (shape.scale as Vector3))
		for k in range(steps):
			var a: Vector3 = points[k]
			var b: Vector3 = points[k + 1]
			var out: Dictionary = parts[_index(_side_of((a + b) * 0.5, shape.scale, seam_polar))]
			## Shaded smooth along its length, so it reads as one band of metal.
			var up_a: Vector3 = a.normalized()
			var up_b: Vector3 = b.normalized()
			var across: Vector3 = (b - a).cross(up_a).normalized() * 0.07
			var deep: float = 0.06
			var flat: Array = [BRASS, BRASS, BRASS]
			var edge: Array = [BRASS.darkened(0.3), BRASS.darkened(0.3), BRASS.darkened(0.3)]
			var side: Vector3 = across.normalized()
			_smooth(out, "brass", [a - across, a + across, b - across], [up_a, up_a, up_b], flat)
			_smooth(out, "brass", [a + across, b + across, b - across], [up_a, up_b, up_b], flat)
			_smooth(out, "brass", [a + across, a + across - up_a * deep, b + across], [side, side, side], edge)
			_smooth(out, "brass", [a + across - up_a * deep, b + across - up_b * deep, b + across], [side, side, side], edge)
			_smooth(out, "brass", [a - across, b - across, a - across - up_a * deep], [-side, -side, -side], edge)
			_smooth(out, "brass", [b - across, b - across - up_b * deep, a - across - up_a * deep], [-side, -side, -side], edge)
	var cross: Vector3 = (rings[0] as Vector3).cross(rings[1] as Vector3).normalized()
	for facing in [cross, -cross]:
		var rivet: Vector3 = _on_rind(shape, facing) + facing * 0.045
		_dome(parts[_index(_side_of(rivet, shape.scale, seam_polar))], "brass", rivet, facing, 0.1, BRASS.lightened(0.18))

static func _dome(out: Dictionary, surface: String, base: Vector3, axis: Vector3, reach: float, tone: Color) -> void:
	var across: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(across).normalized()
	var ring: Array = []
	var upper: Array = []
	for k in range(10):
		var angle: float = TAU * float(k) / 10.0
		var spoke: Vector3 = across * cos(angle) + other * sin(angle)
		ring.append(base + spoke * reach)
		upper.append(base + axis * reach * 0.42 + spoke * reach * 0.7)
	var peak: Vector3 = base + axis * reach * 0.6
	for k in range(10):
		var n: int = (k + 1) % 10
		_tri(out, surface, ring[k], ring[n], upper[k], tone.darkened(0.12), (ring[k] + upper[n]) * 0.5 - base)
		_tri(out, surface, ring[n], upper[n], upper[k], tone.darkened(0.12), (ring[n] + upper[k]) * 0.5 - base)
		_tri(out, surface, upper[k], upper[n], peak, tone, axis)

# --- the pieces -----------------------------------------------------------------------------------------

static func _noise(seeded: int, frequency: float) -> FastNoiseLite:
	var made := FastNoiseLite.new()
	made.seed = seeded
	made.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	made.fractal_type = FastNoiseLite.FRACTAL_NONE
	made.frequency = frequency
	return made

static func _knob(shape: Dictionary, d: Vector3) -> float:
	## 0 down in a crease, 1 on top of a knob: the crust is knobs crowded together, rounded on
	## top and pinched where they meet.
	return sqrt(absf((shape.knobs as FastNoiseLite).get_noise_3dv(d)) * 1.4)

static func _radius(shape: Dictionary, d: Vector3) -> float:
	return 1.0 + SWELLS * (shape.swells as FastNoiseLite).get_noise_3dv(d) + KNOBS * (minf(_knob(shape, d), 1.0) - 0.55)

static func _direction(polar: float, turn: float) -> Vector3:
	## Polar angle from the left pole, turn about the X axis from the top toward the viewer.
	return Vector3(-cos(polar), sin(polar) * cos(turn), sin(polar) * sin(turn))

static func _share_of(p: Vector3, seam: Vector3) -> float:
	var full: float = Vector2(seam.y, seam.z).length()
	return Vector2(p.y, p.z).length() / full if full > 0.0001 else 1.0

static func _side_of(p: Vector3, scale: Vector3, seam_polar: Array) -> int:
	## Which half a point on the rind belongs to: which side of the seam it lies.
	var d: Vector3 = (p / scale).normalized()
	var turn: float = fposmod(atan2(d.z, d.y), TAU)
	var at: float = turn / TAU * float(SEGMENTS)
	var j0: int = int(floor(at)) % SEGMENTS
	var seam: float = lerpf(float(seam_polar[j0]), float(seam_polar[(j0 + 1) % SEGMENTS]), at - floor(at))
	return -1 if acos(clampf(-d.x, -1.0, 1.0)) < seam else 1

static func _index(side: int) -> int:
	return 0 if side < 0 else 1

static func _part(out: Dictionary, surface: String) -> Part:
	if not out.has(surface):
		out[surface] = Part.new()
	return out[surface]

static func _tri(out: Dictionary, surface: String, a: Vector3, b: Vector3, c: Vector3, tone: Color, away: Vector3) -> void:
	## One flat facet, wound so it faces along `away`.
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 1e-14:
		return
	normal = normal.normalized()
	if normal.dot(away) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = - normal
	var part: Part = _part(out, surface)
	part.points.append(a)
	part.points.append(c)
	part.points.append(b)
	for _k in range(3):
		part.normals.append(normal)
		part.colors.append(tone)

static func _smooth(out: Dictionary, surface: String, corners: Array, normals: Array, tones: Array) -> void:
	## One facet with a normal and a tone at each corner, wound to face the way they do.
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var facet: Vector3 = (b - a).cross(c - a)
	if facet.length_squared() < 1e-14:
		return
	var order: Array = [0, 2, 1] if facet.dot((normals[0] as Vector3) + (normals[1] as Vector3) + (normals[2] as Vector3)) >= 0.0 else [0, 1, 2]
	var part: Part = _part(out, surface)
	for k in order:
		part.points.append(corners[k])
		part.normals.append(normals[k])
		part.colors.append(tones[k])

static func _commit(out: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in out:
		var part: Part = out[surface]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part.points
		arrays[Mesh.ARRAY_NORMAL] = part.normals
		arrays[Mesh.ARRAY_COLOR] = part.colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, str(surface))
	return mesh
