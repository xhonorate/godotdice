extends RefCounted
## What is frozen inside a stone, drawn as real geometry set into the crystal.
##
## These all do the same job: showing something that is
## inside the solid rather than cut on its surface.
##
##   Inclusions  A stone's flaws used to be a count and nothing else — N facets of the
##               shell darkened, so a Star looked exactly like a Fracture and both looked
##               like a smudge. Each class is now drawn as the thing it is named after: a
##               Pinpoint is a speck of light, a Lens a flat bubble, a Feather a wing of
##               fine fissures, a Fracture a jagged split and a Star a six-rayed asterism.
##               What the loupe says a stone carries is now what you can see in it.
##   Flakes      Metal grown into a stone rather than cut on it: pyrite in leaves through
##               the matrix, which is Florin's whole stone. Scattered by the shape it is
##               cut to rather than by Clarity, because they are not a fault.
##   Seams       The six opal Seams share one emblem and one milky body, so the color each
##               plays back was the only thing telling them apart — and it was a wash at a
##               sixth of full saturation, pulled towards grey by Clarity and then buried
##               under an additive play-of-color pass. Every Seam now carries the vein its
##               skill is named for, running right through the stone in the true color of
##               the gems it replays.
##
## `gem_mesh.gd` hands over an `envelope`: the room inside the solid, as a few scalars.
## That is the whole of what this file knows about how a stone is cut, and it is why the
## two are preloaded in one direction only and never form a cycle. Nothing here touches
## the scene tree, so all of it cuts headless.

const Tuning = preload("res://view/gems/gem_tuning.gd")

## The five inclusion classes, and what each is worth looking at. A flaw is not one thing:
## some are light caught in the stone and some are the stone failing, so some are drawn
## bright and some dark. Alpha is what keeps them reading as glass rather than as stickers.
const CLASS_TONE := {"PINPOINT": "fff4cf", "LENS": "cfe4ff", "FEATHER": "eef6ff",
	"FRACTURE": "26293a", "STAR": "ffe39a"}
const CLASS_ALPHA := {"PINPOINT": 1.00, "LENS": 0.72, "FEATHER": 0.66, "FRACTURE": 0.90, "STAR": 0.95}
## How far across the stone each one reaches, as a fraction of the girdle. A Pinpoint is a
## speck by definition; a Fracture is the one that runs. These are large on purpose: what a
## stone carries is a decision the player makes, so it has to be legible in a vault thumb
## and not only under the loupe.
const CLASS_SIZE := {"PINPOINT": 0.090, "LENS": 0.32, "FEATHER": 0.44, "FRACTURE": 0.60, "STAR": 0.40}
## What a stone that does not know what it carries falls back to. An unappraised stone, or
## a lab preview with no list at all, still has to look included.
const UNKNOWN_CLASSES := ["PINPOINT", "FEATHER", "LENS", "FRACTURE", "STAR"]

# --- what is in there ---------------------------------------------------------

static func classes(gem: Dictionary, count: int, seed_value: int) -> Array:
	## The class of each thing inside the stone, in order. An appraised stone knows exactly
	## what it carries and each key names its class; one still in its rock only knows how
	## many, so the classes come off its seed instead and stay put for that stone.
	var carried: Array = gem.get("inclusions", []) if gem.get("inclusions") is Array else []
	if not carried.is_empty():
		var named: Array = []
		for key in carried:
			named.append(str(DeepContent.inclusion(str(key)).get("class", "PINPOINT")))
		return named
	var guessed: Array = []
	for index in count:
		var pick: int = int(_hash01(seed_value + 613 + index * 29) * float(UNKNOWN_CLASSES.size()))
		guessed.append(str(UNKNOWN_CLASSES[clampi(pick, 0, UNKNOWN_CLASSES.size() - 1)]))
	return guessed

static func seam_color(gem: Dictionary) -> Color:
	## The color an opal Seam plays back, or a fully transparent color when the stone is not
	## one. Read off the skill's own effect rather than a list of keys here, so a new Seam
	## in the content pack gets its vein without this file being touched.
	for effect in DeepContent.skill(str(gem.get("skill", gem.get("key", "")))).get("effects", []):
		if not (effect is Dictionary) or str(effect.get("kind", "")) != "replay_color":
			continue
		var named: String = str(effect.get("color", ""))
		if named.is_empty():
			continue
		var hue: String = str(DeepContent.color(named).get("hue", ""))
		return Color(hue) if hue.is_valid_html_color() else Color(0, 0, 0, 0)
	return Color(0, 0, 0, 0)

# --- the room inside the solid ------------------------------------------------

static func _span(env: Dictionary, z: float) -> float:
	## How wide the stone is at one height, as a fraction of its girdle. This mirrors the
	## rings `gem_mesh.build()` lays down; anything placed outside it pokes through a facet.
	var crown: float = maxf(float(env.get("crown", 0.34)), 0.0001)
	var depth: float = maxf(float(env.get("depth", 0.74)), 0.0001)
	var girdle: float = float(env.get("girdle", 0.055))
	if z >= 0.0:
		var t: float = clampf(z / crown, 0.0, 1.0)
		# A cabochon is a quarter circle from the girdle to its apex, not a cone to a table.
		if bool(env.get("domed", false)):
			return sqrt(maxf(1.0 - t * t, 0.0))
		return lerpf(1.0, float(env.get("table", 0.5)), t)
	if z >= -girdle:
		return 1.0
	return lerpf(1.0, float(env.get("back_table", 0.16)), clampf((-z - girdle) / maxf(depth - girdle, 0.0001), 0.0, 1.0))

static func _reach(outline: PackedVector2Array, dir: Vector2) -> float:
	## How far the girdle outline goes in one direction. A heart and a pear are not discs:
	## dropped at a fixed radius, the marks in a heart's notch ended up outside the stone.
	var best := 1.0
	var found := false
	for index in outline.size():
		var a: Vector2 = outline[index]
		var edge: Vector2 = outline[(index + 1) % outline.size()] - a
		var denominator: float = dir.cross(edge)
		if absf(denominator) < 0.000001:
			continue
		var along: float = a.cross(edge) / denominator
		var across: float = a.cross(dir) / denominator
		if along <= 0.0 or across < 0.0 or across > 1.0:
			continue
		if not found or along < best:
			best = along
			found = true
	return best if found else 1.0

static func _inside(env: Dictionary, outline: PackedVector2Array, at: Vector3, margin: float) -> Vector3:
	## Pulls a point back until it is clear of the surface, keeping the direction it lay in.
	var flat := Vector2(at.x, at.y)
	if flat.length() < 0.000001:
		return at
	var room: float = _span(env, at.z) * _reach(outline, flat.normalized()) * maxf(margin, 0.05)
	if flat.length() <= room:
		return at
	flat = flat.normalized() * room
	return Vector3(flat.x, flat.y, at.z)

# --- building -----------------------------------------------------------------

static func _hash01(seed_value: int) -> float:
	var mixed := (seed_value * 1103515245 + 12345) & 0x7fffffff
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return float((mixed ^ (mixed >> 16)) & 0xffff) / 65535.0

static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length() < 0.000001:
		return
	normal = normal.normalized()
	for pair in [[a, ca], [c, cc], [b, cb]]:
		surface.set_normal(normal)
		surface.set_color(pair[1])
		surface.add_vertex(pair[0])

static func _blade(surface: SurfaceTool, at: Basis, origin: Vector3, from: Vector3, to: Vector3,
		half: float, near: Color, far: Color) -> void:
	## One tapering sliver in the mark's own plane: broad at `from`, a point at `to`. Every
	## flaw that reads as a line — a ray, a barb, a spine — is built out of these.
	var along := to - from
	if along.length() < 0.000001:
		return
	var side := Vector3(-along.y, along.x, 0.0).normalized() * half
	_tri(surface, origin + at * (from + side), origin + at * (from - side), origin + at * to, near, near, far)

static func _pinpoint(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## A speck of something caught in the melt, and the one flaw that is solid: a tiny
	## octahedron, bright at its points, so it reads as a glint rather than a dot of paint.
	var rim := Color(tone.r, tone.g, tone.b, tone.a * 0.30)
	var ring := [Vector3(size, 0, 0), Vector3(0, size, 0), Vector3(-size, 0, 0), Vector3(0, -size, 0)]
	for way: float in [1.0, -1.0]:
		var apex := Vector3(0, 0, size * 1.7 * way)
		for index in 4:
			_tri(surface, origin + at * apex, origin + at * ring[index], origin + at * ring[(index + 1) % 4],
				tone, rim, rim)

static func _lens(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## A flat disc of nothing — a negative crystal. What you see of a bubble is its wall, so
	## the bright ring is the mark and the middle is left nearly clear.
	var steps := 16
	var hollow := Color(tone.r, tone.g, tone.b, tone.a * 0.12)
	var wall := Color(tone.r, tone.g, tone.b, tone.a)
	var gone := Color(tone.r, tone.g, tone.b, 0.0)
	for index in steps:
		var one := float(index) / float(steps) * TAU
		var two := float(index + 1) / float(steps) * TAU
		var inner_a := Vector3(cos(one), sin(one), 0.0) * size * 0.70
		var inner_b := Vector3(cos(two), sin(two), 0.0) * size * 0.70
		var outer_a := Vector3(cos(one), sin(one), 0.0) * size
		var outer_b := Vector3(cos(two), sin(two), 0.0) * size
		_tri(surface, origin, origin + at * inner_a, origin + at * inner_b, hollow, hollow, hollow)
		_tri(surface, origin + at * inner_a, origin + at * outer_a, origin + at * outer_b, wall, gone, gone)
		_tri(surface, origin + at * inner_a, origin + at * outer_b, origin + at * inner_b, wall, gone, wall)

static func _feather(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A wing: a spine with fine barbs off both sides, each fading to nothing at its tip.
	## Feathers are the flaw that looks like frost, and it is the fade that does that.
	var gone := Color(tone.r, tone.g, tone.b, 0.0)
	var barbs := 7
	_blade(surface, at, origin, Vector3(0.0, -size * 0.55, 0.0), Vector3(0.0, size * 0.62, 0.0),
		size * 0.028, tone, gone)
	for index in barbs:
		var t := (float(index) + 0.5) / float(barbs)
		var root := Vector3(0.0, lerpf(-size * 0.48, size * 0.48, t), 0.0)
		var out := size * 0.58 * sin(t * PI) * lerpf(0.55, 1.0, _hash01(seed_value + index * 37))
		for way: float in [-1.0, 1.0]:
			_blade(surface, at, origin, root, root + Vector3(way * out, size * 0.20, 0.0),
				size * 0.034, tone, gone)

static func _fracture(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## The stone failing: a split that walks across it in steps, widest where it opened and
	## closing to nothing at both ends, so it reads as a crack and not as a drawn line.
	##
	## Two bands, not one. A crack drawn dark alone vanished into a Violet or a Red; drawn
	## bright it was a Feather. A real one is both — a dark opening with the light the two
	## new faces throw back along it — and that pair reads on a body of any tone.
	var steps := 6
	var path: Array = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		path.append(Vector3(lerpf(-size * 0.5, size * 0.5, t),
			(_hash01(seed_value + index * 17) - 0.5) * size * 0.46, 0.0))
	var glint := Color(0.92, 0.95, 1.0, tone.a * 0.62)
	for layer: Array in [[0.22, glint], [0.11, tone]]:
		var half: float = float(layer[0])
		var shade: Color = layer[1]
		for index in steps:
			var t0 := float(index) / float(steps)
			var t1 := float(index + 1) / float(steps)
			var a: Vector3 = path[index]
			var b: Vector3 = path[index + 1]
			var along := (b - a).normalized()
			var side := Vector3(-along.y, along.x, 0.0)
			var wide_a := side * size * half * sin(t0 * PI)
			var wide_b := side * size * half * sin(t1 * PI)
			var ca := Color(shade.r, shade.g, shade.b, shade.a * sin(t0 * PI))
			var cb := Color(shade.r, shade.g, shade.b, shade.a * sin(t1 * PI))
			_tri(surface, origin + at * (a + wide_a), origin + at * (b + wide_b), origin + at * (b - wide_b), ca, cb, cb)
			_tri(surface, origin + at * (a + wide_a), origin + at * (b - wide_b), origin + at * (a - wide_a), ca, cb, ca)

static func _star(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## Asterism: six rays of light standing off one centre, the way a star sapphire throws
	## them. Broad where they meet and gone at the tips, so the middle burns and the arms
	## trail off into the body.
	var gone := Color(tone.r, tone.g, tone.b, 0.0)
	for index in 6:
		var turn := float(index) * PI / 3.0
		_blade(surface, at, origin, Vector3.ZERO, Vector3(cos(turn), sin(turn), 0.0) * size, size * 0.06, tone, gone)
	_pinpoint(surface, at, origin, size * 0.16, tone)

static func _mark(surface: SurfaceTool, env: Dictionary, outline: PackedVector2Array,
		kind: String, seed_value: int, scale: float) -> void:
	var size: float = float(CLASS_SIZE.get(kind, 0.2)) * scale
	var tone := Color(str(CLASS_TONE.get(kind, "ffffff")))
	## The same bargain the emblem strikes: a cloudy stone lets very little of its inside
	## back out, and a cloudy stone is exactly the one with things in it worth seeing. Murk
	## is allowed to change how a flaw looks, never whether it can be found.
	var murk: float = clampf(float(env.get("murk", 0.0)), 0.0, 1.0)
	tone.a = clampf(float(CLASS_ALPHA.get(kind, 0.6)) * lerpf(1.0, 2.4, murk), 0.0, 1.0) 		* clampf(Tuning.value("flaw_alpha"), 0.0, 1.0)
	## Where it sits. Biased into the body rather than the tips: the culet and the table are
	## where the stone is thinnest, and a flaw dropped there pokes out through a facet.
	var z: float = lerpf(-float(env.get("depth", 0.74)) * 0.58, float(env.get("crown", 0.34)) * 0.62,
		_hash01(seed_value + 5))
	var turn: float = _hash01(seed_value + 11) * TAU
	var dir := Vector2(cos(turn), sin(turn))
	# The square root spreads the marks evenly over the area instead of crowding the middle.
	var out: float = sqrt(_hash01(seed_value + 17)) * 0.72
	var origin := _inside(env, outline, Vector3(dir.x * out, dir.y * out, z), 0.80 - size * 0.5)
	## How it lies. The flat marks would vanish edge-on if they were turned freely, and a
	## stone is nearly always looked at face on, so they spin about the viewing axis and
	## only lean out of it — scattered in three dimensions, still every one of them legible.
	var at := Basis.from_euler(Vector3(
		(_hash01(seed_value + 23) - 0.5) * 1.32,
		(_hash01(seed_value + 29) - 0.5) * 1.32,
		_hash01(seed_value + 31) * TAU))
	match kind:
		"PINPOINT": _pinpoint(surface, at, origin, size, tone)
		"LENS": _lens(surface, at, origin, size, tone)
		"FEATHER": _feather(surface, at, origin, size, tone, seed_value)
		"FRACTURE": _fracture(surface, at, origin, size, tone, seed_value)
		"STAR": _star(surface, at, origin, size, tone)
		_: _pinpoint(surface, at, origin, size, tone)

static func _flake(surface: SurfaceTool, env: Dictionary, outline: PackedVector2Array,
		seed_value: int, tone: Color, index: int, count: int) -> void:
	## A leaf of fool's gold caught in the matrix. Not a flaw and not scattered by Clarity:
	## pyrite grows in the rock in sheets, and a stone cut out of that carries them because
	## they are the reason it was cut. Flat plates rather than solids, so each one catches
	## the light from one angle and goes dark from another, the way metal in stone does.
	var size: float = lerpf(0.045, 0.115, _hash01(seed_value + 3)) * maxf(float(env.get("flake_size", 1.0)), 0.02)
	var z: float = lerpf(-float(env.get("depth", 0.74)) * 0.62, float(env.get("crown", 0.34)) * 0.62,
		_hash01(seed_value + 5))
	var turn: float = _hash01(seed_value + 11) * TAU
	var out: float = sqrt(_hash01(seed_value + 17)) * 0.82
	var origin := _inside(env, outline, Vector3(cos(turn) * out, sin(turn) * out, z), 0.80)
	if bool(env.get("even_flakes", false)):
		# A golden-angle spiral fills the face without random clumps or empty quarters.
		# Map to each slice's actual outline instead of clamping a disc onto its edges.
		var phase: float = _hash01(int(env.seed) + 11)
		turn = TAU * (phase + float(index) * 0.38196601125)
		z = lerpf(-float(env.depth) * 0.55, float(env.crown) * 0.55,
			fposmod(phase + float(index) * 0.754877666, 1.0))
		var direction := Vector2(cos(turn), sin(turn))
		out = sqrt((float(index) + 0.5) / float(count)) * 0.84 * _span(env, z) * _reach(outline, direction)
		origin = Vector3(direction.x * out, direction.y * out, z)
	var at := Basis.from_euler(Vector3(
		(_hash01(seed_value + 23) - 0.5) * 2.4,
		(_hash01(seed_value + 29) - 0.5) * 2.4,
		_hash01(seed_value + 31) * TAU))
	var lit := tone
	var dull := Color(tone.r * 0.52, tone.g * 0.40, tone.b * 0.22, tone.a * 0.85)
	var plate := [Vector3(size, size * 0.62, 0.0), Vector3(-size * 0.74, size, 0.0),
		Vector3(-size, -size * 0.68, 0.0), Vector3(size * 0.70, -size, 0.0)]
	for corner in plate.size():
		var point: Vector3 = origin + at * plate[corner]
		point.z = clampf(point.z, -float(env.depth) * 0.88, float(env.crown) * 0.88)
		plate[corner] = _inside(env, outline, point, 0.92)
	_tri(surface, plate[0], plate[1], plate[2], lit, dull, lit)
	_tri(surface, plate[0], plate[2], plate[3], lit, lit, dull)

static func _prism(surface: SurfaceTool, from: Vector3, to: Vector3, wide: float, tall: float,
		near: Color, far: Color) -> void:
	## One segment of a vein: a flattened four-sided tube, broad across and thin through, so
	## the seam is still there when the stone is turned edge-on to it.
	var along := to - from
	if along.length() < 0.000001:
		return
	var side := Vector3(-along.y, along.x, 0.0)
	side = Vector3(0.0, 1.0, 0.0) if side.length() < 0.000001 else side.normalized()
	var up := along.normalized().cross(side).normalized()
	var ring := [side * wide, up * tall, -side * wide, -up * tall]
	for index in 4:
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[(index + 1) % 4]
		_tri(surface, from + a, to + a, to + b, near, far, far)
		_tri(surface, from + a, to + b, from + b, near, far, near)

static func _seam(surface: SurfaceTool, env: Dictionary, outline: PackedVector2Array,
		tone: Color, seed_value: int) -> void:
	## The vein an opal Seam is named for, run right through the stone. Three of them, not
	## one: a single stripe reads as paint on the dome, and a few at slightly different
	## headings read as something the rock did.
	var width: float = clampf(Tuning.value("seam_width"), 0.01, 0.6)
	var peak: float = clampf(Tuning.value("seam_alpha"), 0.0, 1.0)
	## Deepened before it goes in. The body it runs through is milk and the play-of-color
	## is laid over the whole dome additively, so a vein at the color's own value came out
	## paler than the stone around it and read as a smear of light rather than as color.
	tone = tone.darkened(0.18)
	var base: float = _hash01(seed_value + 41) * PI
	var steps := 14
	for vein in 3:
		var turn: float = base + (float(vein) - 1.0) * 0.42 + (_hash01(seed_value + vein * 53) - 0.5) * 0.3
		var dir := Vector2(cos(turn), sin(turn))
		var side := Vector2(-dir.y, dir.x)
		var phase: float = _hash01(seed_value + vein * 71) * TAU
		var thick: float = width * lerpf(0.55, 1.0, _hash01(seed_value + vein * 83))
		var drift: float = (float(vein) - 1.0) * 0.26
		var rail: Array = []
		var shade: Array = []
		for index in steps + 1:
			var t := float(index) / float(steps)
			var flat := dir * lerpf(-0.94, 0.94, t) + side * (drift + sin(t * PI * 1.7 + phase) * 0.17)
			var z: float = lerpf(float(env.get("crown", 0.34)) * 0.34, -float(env.get("depth", 0.74)) * 0.40, t) \
				+ sin(t * PI * 2.1 + phase) * 0.06
			# The vein is a tube, not a line, so its own half-width comes off the margin or
			# a corner of it stands out past the girdle where the path runs closest to it.
			rail.append(_inside(env, outline, Vector3(flat.x, flat.y, z), 0.92 - thick))
			# A seam does not start and stop inside a stone: both ends fade into the body.
			shade.append(Color(tone.r, tone.g, tone.b, tone.a * peak * pow(sin(t * PI), 0.55)))
		for index in steps:
			_prism(surface, rail[index], rail[index + 1], thick, thick * 0.34, shade[index], shade[index + 1])

static func build(gem: Dictionary, env: Dictionary) -> ArrayMesh:
	## Everything set inside this stone, as one mesh. Null when there is nothing in there,
	## which is the common case: a Flawless gem that is not a Seam has a clean interior.
	var outline: PackedVector2Array = env.get("outline", PackedVector2Array())
	if outline.size() < 3:
		return null
	var seed_value: int = int(env.get("seed", 0))
	var scale: float = clampf(Tuning.value("flaw_size"), 0.1, 3.0)
	var kinds: Array = classes(gem, int(env.get("flaws", 0)), seed_value)
	var vein := seam_color(gem)
	var flakes: int = int(env.get("flakes", 0))
	if kinds.is_empty() and vein.a <= 0.0 and flakes <= 0:
		return null
	var mesh := ArrayMesh.new()
	if not kinds.is_empty() or vein.a > 0.0:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(inside_material())
		if vein.a > 0.0:
			_seam(surface, env, outline, vein, seed_value)
		for index in kinds.size():
			_mark(surface, env, outline, str(kinds[index]), seed_value + 101 + index * 911, scale)
		surface.commit(mesh)
	if flakes > 0:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_gold_material() if bool(env.get("even_flakes", false)) else inside_material())
		var metal: String = str(env.get("flake_tone", "ffd166"))
		var gold := Color(metal) if metal.is_valid_html_color() else Color("ffd166")
		for index in flakes:
			_flake(surface, env, outline, seed_value + 7717 + index * 131, gold, index, flakes)
		surface.commit(mesh)
	return mesh

static func _gold_material() -> StandardMaterial3D:
	## Gold shares the interior compositing order, but its tilted faces reflect the lamps.
	var material := inside_material()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.metallic = 0.78
	material.metallic_specular = 1.0
	material.roughness = 0.16
	material.clearcoat_enabled = true
	material.clearcoat = 0.65
	material.clearcoat_roughness = 0.08
	material.emission_enabled = true
	material.emission = Color("ffd166")
	material.emission_energy_multiplier = 0.12
	return material

static func inside_material() -> StandardMaterial3D:
	## Unshaded on purpose. The shell is lit facet by facet because that is what a cut
	## surface does; what is frozen inside the stone is light that is already in there, and
	## lighting it again let the lamps decide whether a Fracture was dark. Vertex color is
	## the whole of its look, so one material carries every class and every Seam.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	# Every tone in here is written as an sRGB value, the way the rest of the game writes
	# color. Left unflagged Godot takes vertex color to be linear already and skips the
	# conversion, which lifts a mid tone by half and washes the saturation out of it: a
	# deep green vein came out as a pale band lighter than the stone it ran through.
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# The same trick the emblem uses: no depth test, but drawn before the near half, which
	# is what puts it inside the stone rather than over it.
	material.no_depth_test = true
	material.render_priority = 1
	return material
