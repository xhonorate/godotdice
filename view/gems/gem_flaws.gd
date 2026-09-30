extends RefCounted
## What is frozen inside a stone, drawn as real geometry set into the crystal.
##
## These all do the same job: showing something that is
## inside the solid rather than cut on its surface.
##
##   Inclusions  A stone's flaws used to be a count and nothing else, then a shape per
##               class — so all eight Pinpoints were one speck and all six Fractures one
##               crack. An inclusion is a named thing with a line of text under it, and
##               two that read differently should look different: Silk is a sheaf of
##               needles, a Knot is a crystal lodged in the body, a Void is a hole with
##               nothing in it, Fluorescence is a glow with no edge at all. Every key in
##               the pack names its own drawing here, and falls back to its class only if
##               it names none.
##   Zoning      The exception, and the one inclusion with no geometry: color zoning is a
##               band of another color grown through the crystal, not an object in it. It
##               is drawn by `gem_mesh.gd` as a stop in the body gradient, the same way a
##               Birthstone carries two hues, so a stone can wear several at once.
##   Flakes      Metal grown into a stone rather than cut on it: pyrite in leaves through
##               the matrix, which is Florin's whole stone. Scattered by the shape it is
##               cut to rather than by Clarity, because they are not a fault.
##   Seams       The six opal Seams share one emblem and one milky body, so the color each
##               plays back was the only thing telling them apart. Every Seam carries the
##               vein its skill is named for, running right through the stone in the true
##               color of the gems it replays.
##
## `gem_mesh.gd` hands over an `envelope`: the room inside the solid, as a few scalars.
## That is the whole of what this file knows about how a stone is cut, and it is why the
## two are preloaded in one direction only and never form a cycle. Nothing here touches
## the scene tree, so all of it cuts headless.

const Tuning = preload("res://view/gems/gem_tuning.gd")

## What each inclusion looks like, one entry per key in the pack.
##
##   draw   which of the routines below cuts it
##   tone   its own color, as light already in the stone rather than as paint
##   alpha  how solidly it reads through the crystal over it
##   size   how far it reaches, as a fraction of the girdle
##
## A dark mark needs more alpha than a bright one to be seen at all, and a mark that is
## mostly empty — a veil, a glow — needs less or it reads as a sticker. The sizes are
## large on purpose: what a stone carries is a decision the player makes, so it has to be
## legible in a vault thumb and not only under the loupe.
const STYLE := {
	# --- Pinpoints: small bright things caught in the melt ------------------------
	"PINPOINT_GOLD": {"draw": "speck", "tone": "ffd166", "alpha": 1.00, "size": 0.125},
	"SILK": {"draw": "silk", "tone": "e6f0ff", "alpha": 0.82, "size": 0.42},
	"NEEDLE": {"draw": "needle", "tone": "ffd2a8", "alpha": 0.92, "size": 0.52},
	"GRAIN": {"draw": "grains", "tone": "d6f2d4", "alpha": 0.92, "size": 0.24},
	"SPARK": {"draw": "sparkle", "tone": "9fe8ff", "alpha": 1.00, "size": 0.28},
	"EMBERLINE": {"draw": "emberline", "tone": "ff7a3c", "alpha": 0.95, "size": 0.40},
	"GLINT": {"draw": "flecks", "tone": "ffe08a", "alpha": 1.00, "size": 0.34},
	"DUSTING": {"draw": "dust", "tone": "e4ecf8", "alpha": 0.80, "size": 0.38},
	# --- Lenses: flat things you read the stone through ---------------------------
	"VEIL": {"draw": "veil", "tone": "dce8ff", "alpha": 0.62, "size": 0.42},
	"CATS_EYE": {"draw": "cats_eye", "tone": "ffeeb8", "alpha": 0.92, "size": 0.36},
	"GRAINING": {"draw": "graining", "tone": "d8e8ff", "alpha": 1.00, "size": 0.48},
	# --- Feathers: fine fissures, frost inside the stone --------------------------
	"FEATHER": {"draw": "feather", "tone": "eef6ff", "alpha": 0.70, "size": 0.46},
	"TWINNING_WISP": {"draw": "wisps", "tone": "d9e7ff", "alpha": 0.74, "size": 0.50},
	"FINGERPRINT": {"draw": "fingerprint", "tone": "cfe4ff", "alpha": 0.84, "size": 0.38},
	"HALO": {"draw": "halo", "tone": "fff1d0", "alpha": 0.86, "size": 0.32},
	"RESONANT_VEIN": {"draw": "filament", "tone": "7ef0d4", "alpha": 0.92, "size": 0.52},
	# --- Fractures: the stone failing ---------------------------------------------
	"FRACTURE": {"draw": "fracture", "tone": "26293a", "alpha": 0.90, "size": 0.60},
	"BRUISE": {"draw": "bruise", "tone": "a33055", "alpha": 1.00, "size": 0.38},
	"KNOT": {"draw": "knot", "tone": "8a6a3e", "alpha": 1.00, "size": 0.32},
	"VOID": {"draw": "hollow", "tone": "0a0812", "alpha": 1.00, "size": 0.32},
	"CAVITY": {"draw": "cavity", "tone": "141220", "alpha": 0.95, "size": 0.36},
	"CHIP": {"draw": "chip", "tone": "f2f7ff", "alpha": 0.96, "size": 0.34},
	# --- Stars: light the stone throws back on its own ----------------------------
	"STAR": {"draw": "star", "tone": "ffe39a", "alpha": 0.95, "size": 0.44},
	"CHATOYANCE": {"draw": "chatoyance", "tone": "fff6d8", "alpha": 1.00, "size": 0.70},
	"FLUORESCENCE": {"draw": "glow", "tone": "b47cff", "alpha": 0.62, "size": 0.50},
	"ALEXANDRITE": {"draw": "alexandrite", "tone": "e2483f", "tone2": "3fb56b", "alpha": 0.92, "size": 0.42}}

## What a key with no entry of its own falls back on: the look its class used to carry for
## everything in it. A new inclusion in the content pack is drawn as its class until
## somebody gives it a line above, rather than not drawn at all.
const CLASS_STYLE := {
	"PINPOINT": {"draw": "speck", "tone": "fff4cf", "alpha": 1.00, "size": 0.105},
	"LENS": {"draw": "veil", "tone": "cfe4ff", "alpha": 0.60, "size": 0.34},
	"FEATHER": {"draw": "feather", "tone": "eef6ff", "alpha": 0.66, "size": 0.44},
	"FRACTURE": {"draw": "fracture", "tone": "26293a", "alpha": 0.90, "size": 0.58},
	"STAR": {"draw": "star", "tone": "ffe39a", "alpha": 0.95, "size": 0.42}}

## The one inclusion drawn by the body rather than in it. Color zoning is another color
## grown through the crystal in bands, so it is a stop in the shell's gradient — see
## `GemMesh.zone_colors()`. Nothing is cut inside the stone for these.
const BODY_DRAW := "zone"

## How far past its nominal size each drawing actually reaches, so a mark can be placed
## with room for all of itself. A ray star runs to its full size; a speck stands on points
## well past its waist; a feather is narrower than it is long. Getting this wrong is what
## used to push a Lens out through a facet.
const DRAW_REACH := {"speck": 1.80, "grains": 1.80, "dust": 1.40, "flecks": 1.45,
	"silk": 1.42, "needle": 1.08, "sparkle": 1.25, "emberline": 1.22,
	"veil": 1.12, "cats_eye": 1.12, "graining": 1.42,
	"feather": 0.98, "wisps": 1.12, "fingerprint": 1.12, "halo": 1.15, "filament": 1.14,
	"fracture": 0.74, "bruise": 1.32, "knot": 1.28, "hollow": 1.32, "cavity": 1.28,
	"chip": 1.14, "star": 1.10, "chatoyance": 1.12, "glow": 1.08, "alexandrite": 1.15}

## What a stone that does not know what it carries falls back to. An unappraised stone, or
## a lab preview with no list at all, still has to look included — and with one key per
## class it looks included in five different ways rather than one.
const UNKNOWN_MARKS := ["PINPOINT_GOLD", "FEATHER", "VEIL", "FRACTURE", "STAR"]

# --- what is in there ---------------------------------------------------------

static func style_of(key: String) -> Dictionary:
	## How one inclusion is drawn: its own entry, or the one its class shares.
	if STYLE.has(key):
		return STYLE[key]
	return CLASS_STYLE.get(str(DeepContent.inclusion(key).get("class", "")), CLASS_STYLE["PINPOINT"])

static func carried(gem: Dictionary, count: int, seed_value: int) -> Array:
	## Every inclusion in the stone, by key, in order. An appraised stone knows exactly what
	## it carries; one still in its rock only knows how many, so the keys come off its seed
	## instead and stay put for that stone.
	var listed: Array = gem.get("inclusions", []) if gem.get("inclusions") is Array else []
	if not listed.is_empty():
		var named: Array = []
		for key in listed:
			named.append(str(key))
		return named
	var guessed: Array = []
	for index in count:
		var pick: int = int(_hash01(seed_value + 613 + index * 29) * float(UNKNOWN_MARKS.size()))
		guessed.append(str(UNKNOWN_MARKS[clampi(pick, 0, UNKNOWN_MARKS.size() - 1)]))
	return guessed

static func classes(gem: Dictionary, count: int, seed_value: int) -> Array:
	## The same list as the classes those keys belong to, which is the coarser word the
	## loupe and the appraisal still speak in.
	var named: Array = []
	for key in carried(gem, count, seed_value):
		named.append(str(DeepContent.inclusion(str(key)).get("class", "PINPOINT")))
	return named

static func zone_color(key: String) -> String:
	## The Color an inclusion grows through the body as a band instead of sitting in it,
	## or nothing at all. Read off the modifier rather than the key, so any inclusion that
	## makes a stone count as another color wears that color without being listed here.
	for modifier in DeepContent.inclusion(key).get("modifiers", []):
		if modifier is Dictionary and str(modifier.get("kind", "")) == "color_also":
			return str(modifier.get("color", ""))
	return ""

static func draws_inside(key: String) -> bool:
	## False for the inclusions the body wears rather than holds — the Zonings.
	return zone_color(key).is_empty() and str(style_of(key).get("draw", "")) != BODY_DRAW

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
	var domed: bool = bool(env.get("domed", false))
	if z >= crown:
		return 0.0 if domed else float(env.get("table", 0.5))
	if z >= 0.0:
		var t: float = clampf(z / crown, 0.0, 1.0)
		# A cabochon is a quarter circle from the girdle to its apex, not a cone to a table.
		if domed:
			return sqrt(maxf(1.0 - t * t, 0.0))
		return lerpf(1.0, float(env.get("table", 0.5)), t)
	if z >= -girdle:
		return 1.0
	if z <= -depth:
		return float(env.get("back_table", 0.16))
	return lerpf(1.0, float(env.get("back_table", 0.16)), clampf((-z - girdle) / maxf(depth - girdle, 0.0001), 0.0, 1.0))

static func _narrowest(env: Dictionary, low: float, high: float) -> float:
	## The tightest the stone gets anywhere between two heights. A mark has thickness as
	## well as width, so what has to fit is not the span at its centre but the span
	## everywhere it reaches — a disc set just under the table is pinched by the table.
	var tight: float = 1.0
	for step in 7:
		tight = minf(tight, _span(env, lerpf(low, high, float(step) / 6.0)))
	return tight

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

static func _clearance(outline: PackedVector2Array, span: float, at: Vector2) -> float:
	## How far a point inside the girdle can grow before it touches the wall: the radius of
	## the largest circle that fits around it at this height.
	##
	## This is the whole of how a mark is sized now. Measuring the stone's reach in one
	## direction is no good, because a mark spins freely about the viewing axis and has to
	## fit whichever way it lands; measuring only from the centre is no good either,
	## because a heart's notch and a pear's point pull that one number right down and then
	## every mark in those stones is shrunk to a speck wherever it is actually placed.
	var tight: float = 1000000.0
	for index in outline.size():
		var a: Vector2 = outline[index] * span
		var edge: Vector2 = outline[(index + 1) % outline.size()] * span - a
		var length: float = edge.length()
		if length < 0.000001:
			continue
		var along: float = clampf((at - a).dot(edge) / (length * length), 0.0, 1.0)
		tight = minf(tight, (at - (a + edge * along)).length())
	return maxf(tight, 0.0)

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

## How much of a mark's reach stands proud of the viewing plane once it has been turned.
## A mark is a flat thing leaning a little out of that plane, not a ball, so this is how
## far above and below its own height it actually reaches.
const LEAN := 0.80
## How far out from the middle a mark may be dropped, as a share of the room it has there.
const SPREAD := 0.86

static func _room(env: Dictionary, outline: PackedVector2Array, at: Vector2, z: float, reach: float) -> float:
	## The largest a mark can be cut and still sit wholly inside the crystal at this spot.
	##
	## A leaning disc is not a ball: at its own height it is at full width, and by the time
	## it reaches the top of its lean it has narrowed to a point. Measuring it as a ball —
	## full width at every height it touches — is what pinched every mark in a deep stone
	## down against the culet's span and left a Star drawn at a third of its size. So the
	## crystal is sampled across the mark's own height and each sample is weighed against
	## how wide the mark actually is there.
	var held: float = reach
	# The width depends on the lean and the lean depends on the width, so it is walked to
	# a fixed point rather than solved. Two passes is well inside a tenth of a percent.
	for _pass in 2:
		var lean: float = held * LEAN
		var best: float = reach
		for step in 7:
			var f: float = float(step) / 3.0 - 1.0
			var wide: float = sqrt(maxf(1.0 - f * f, 0.0))
			if wide < 0.02:
				continue
			best = minf(best, _clearance(outline, _span(env, z + lean * f), at) * 0.96 / wide)
		held = minf(reach, maxf(best, 0.0))
	return held

static func _place(env: Dictionary, outline: PackedVector2Array, seed_value: int, reach: float) -> Dictionary:
	## Where a mark of a given reach can sit with all of itself still in the crystal, and
	## how much of it will fit there.
	##
	## The old version placed a centre and hoped: a Lens is a disc a third of the stone
	## across, the margin it was given knew nothing of that radius, and half of one
	## regularly hung out through a facet. This works the other way round — the mark says
	## how far it reaches, the crystal says how much room there is exactly where the mark
	## has landed, and the mark is cut down to that rather than let out.
	var crown: float = float(env.get("crown", 0.34))
	var depth: float = float(env.get("depth", 0.74))
	## Kept to the half of the body either side of the girdle, biased to the middle of it.
	## The table and the culet are where the stone is thinnest, and a mark dropped in
	## either has to be cut to a speck to fit through.
	var t: float = 0.5 + (_hash01(seed_value + 5) - 0.5) * 0.82
	var z: float = lerpf(-depth * 0.52, crown * 0.52, t)
	var turn: float = _hash01(seed_value + 11) * TAU
	var dir := Vector2(cos(turn), sin(turn))
	# The square root spreads the marks evenly over the area instead of crowding the middle.
	var middle: float = _clearance(outline, _span(env, z), Vector2.ZERO)
	var flat: Vector2 = dir * sqrt(_hash01(seed_value + 17)) * maxf(middle - reach * 0.5, 0.0) * SPREAD
	var held: float = _room(env, outline, flat, z, reach)
	## And the crown and the pavilion have the last word on how far it may lean.
	held = minf(held, minf(crown * 0.92 - z, z + depth * 0.92) / LEAN)
	return {"at": Vector3(flat.x, flat.y, z), "fit": clampf(held / maxf(reach, 0.0001), 0.05, 1.0)}

# --- building blocks ----------------------------------------------------------

static func _hash01(seed_value: int) -> float:
	var mixed := (seed_value * 1103515245 + 12345) & 0x7fffffff
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return float((mixed ^ (mixed >> 16)) & 0xffff) / 65535.0

static func _fade(tone: Color, amount: float) -> Color:
	return Color(tone.r, tone.g, tone.b, tone.a * clampf(amount, 0.0, 1.0))

static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length() < 0.000001:
		return
	normal = normal.normalized()
	for pair in [[a, ca], [c, cc], [b, cb]]:
		surface.set_normal(normal)
		surface.set_color(pair[1])
		surface.add_vertex(pair[0])

static func _quad(surface: SurfaceTool, at: Basis, origin: Vector3, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(surface, origin + at * a, origin + at * b, origin + at * c, ca, cb, cc)
	_tri(surface, origin + at * a, origin + at * c, origin + at * d, ca, cc, cd)

static func _blade(surface: SurfaceTool, at: Basis, origin: Vector3, from: Vector3, to: Vector3,
		half: float, near: Color, far: Color) -> void:
	## One tapering sliver in the mark's own plane: broad at `from`, a point at `to`. Every
	## flaw that reads as a line — a ray, a barb, a spine, a needle — is built out of these.
	var along := to - from
	if along.length() < 0.000001:
		return
	var side := Vector3(-along.y, along.x, 0.0).normalized() * half
	_tri(surface, origin + at * (from + side), origin + at * (from - side), origin + at * to, near, near, far)

static func _disc(surface: SurfaceTool, at: Basis, origin: Vector3, radius: float,
		middle: Color, rim: Color, steps: int = 20, squash: float = 1.0) -> void:
	## A filled round patch shaded from its centre out. Everything soft — a veil, a glow,
	## a bruise — is one or more of these, and the rim color decides whether it has an edge
	## at all or dissolves into the body.
	for index in steps:
		var one := float(index) / float(steps) * TAU
		var two := float(index + 1) / float(steps) * TAU
		_tri(surface, origin,
			origin + at * (Vector3(cos(one), sin(one) * squash, 0.0) * radius),
			origin + at * (Vector3(cos(two), sin(two) * squash, 0.0) * radius), middle, rim, rim)

static func _annulus(surface: SurfaceTool, at: Basis, origin: Vector3, inner: float, outer: float,
		near: Color, far: Color, steps: int = 22, from: float = 0.0, sweep: float = TAU) -> void:
	## A ring, or an arc of one. `near` is the color on the inner rail and `far` on the
	## outer, so a ring can be a hard wall or fade away into the body.
	for index in steps:
		var one := from + sweep * float(index) / float(steps)
		var two := from + sweep * float(index + 1) / float(steps)
		var ia := Vector3(cos(one), sin(one), 0.0) * inner
		var ib := Vector3(cos(two), sin(two), 0.0) * inner
		var oa := Vector3(cos(one), sin(one), 0.0) * outer
		var ob := Vector3(cos(two), sin(two), 0.0) * outer
		_tri(surface, origin + at * ia, origin + at * oa, origin + at * ob, near, far, far)
		_tri(surface, origin + at * ia, origin + at * ob, origin + at * ib, near, far, near)

static func _ribbon(surface: SurfaceTool, at: Basis, origin: Vector3, path: Array, half: float,
		tone: Color, taper: float = 0.5) -> void:
	## A strip following a path, thinning and fading towards both ends. `taper` of zero is
	## a plain band with square ends; higher pulls it to a point, which is what makes a
	## wisp read as something that grew rather than as a drawn line.
	## A band given only its two ends tapers to nothing at both of them and comes out with
	## no width anywhere — which is how Graining and Chatoyance were drawing an empty mesh.
	## Walk it instead, so the ends come to a point and the middle is full.
	if path.size() == 2 and taper > 0.0:
		var walked: Array = []
		for step in 9:
			walked.append((path[0] as Vector3).lerp(path[1] as Vector3, float(step) / 8.0))
		path = walked
	var last: int = path.size() - 1
	if last < 1:
		return
	for index in last:
		var t0 := float(index) / float(last)
		var t1 := float(index + 1) / float(last)
		var a: Vector3 = path[index]
		var b: Vector3 = path[index + 1]
		var along := b - a
		if along.length() < 0.000001:
			continue
		var side := Vector3(-along.y, along.x, 0.0).normalized()
		var wa: float = 1.0 if taper <= 0.0 else pow(sin(t0 * PI), taper)
		var wb: float = 1.0 if taper <= 0.0 else pow(sin(t1 * PI), taper)
		_quad(surface, at, origin, a + side * half * wa, b + side * half * wb,
			b - side * half * wb, a - side * half * wa,
			_fade(tone, wa), _fade(tone, wb), _fade(tone, wb), _fade(tone, wa))

static func _polygon(surface: SurfaceTool, at: Basis, origin: Vector3, points: Array,
		middle: Color, rim: Color) -> void:
	## A flat many-sided patch as a fan from its own centre, so a hexagon of crystal or a
	## ragged crater lip is one call rather than a list of triangles.
	for index in points.size():
		_tri(surface, origin, origin + at * (points[index] as Vector3),
			origin + at * (points[(index + 1) % points.size()] as Vector3), middle, rim, rim)

static func _lip(surface: SurfaceTool, at: Basis, origin: Vector3, points: Array,
		width: float, tone: Color) -> void:
	## A bright edge run round a patch, which is how a hole in a stone is seen at all: the
	## hole itself returns nothing, and what the eye finds is its wall catching the light.
	for index in points.size():
		var a: Vector3 = points[index]
		var b: Vector3 = points[(index + 1) % points.size()]
		var out_a: Vector3 = a.normalized() * width if a.length() > 0.000001 else Vector3.ZERO
		var out_b: Vector3 = b.normalized() * width if b.length() > 0.000001 else Vector3.ZERO
		_quad(surface, at, origin, a, b, b + out_b, a + out_a,
			tone, tone, _fade(tone, 0.0), _fade(tone, 0.0))

static func _crystal(size: float, sides: int, turn: float, rough: float, seed_value: int) -> Array:
	## The outline of something grown in the stone: a regular figure knocked about by as
	## much as `rough`, so a Knot and a Void are the same idea cut to different shapes.
	var built: Array = []
	for index in sides:
		var angle := turn + TAU * float(index) / float(sides)
		var radius: float = size * lerpf(1.0 - rough, 1.0, _hash01(seed_value + index * 47))
		built.append(Vector3(cos(angle), sin(angle), 0.0) * radius)
	return built

# --- the pinpoints ------------------------------------------------------------

static func _speck(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## A speck of something caught in the melt, and the one flaw that is solid: a tiny
	## octahedron, bright at its points, so it reads as a glint rather than a dot of paint.
	var rim := _fade(tone, 0.30)
	var ring := [Vector3(size, 0, 0), Vector3(0, size, 0), Vector3(-size, 0, 0), Vector3(0, -size, 0)]
	for way: float in [1.0, -1.0]:
		var apex := Vector3(0, 0, size * 1.7 * way)
		for index in 4:
			_tri(surface, origin + at * apex, origin + at * ring[index], origin + at * ring[(index + 1) % 4],
				tone, rim, rim)

static func _grains(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A knot of small rounded grains sitting together, the way a seed of something grows
	## in a melt. Heal 1: the smallest mercy in the game, and the smallest thing in a stone.
	for index in 5:
		var turn := _hash01(seed_value + index * 31) * TAU
		var out: float = size * lerpf(0.10, 0.95, _hash01(seed_value + index * 53))
		var at_grain := Vector3(cos(turn) * out, sin(turn) * out, (_hash01(seed_value + index * 71) - 0.5) * size)
		_speck(surface, at, origin + at * at_grain, size * lerpf(0.26, 0.46, _hash01(seed_value + index * 97)),
			_fade(tone, lerpf(0.62, 1.0, _hash01(seed_value + index * 13))))

static func _dust(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A haze of pinpoints too fine to count: what a jeweller means by dusting. Block by the
	## handful, from nothing you can point at.
	for index in 26:
		var turn := _hash01(seed_value + index * 29) * TAU
		var out: float = size * sqrt(_hash01(seed_value + index * 41))
		var at_mote := Vector3(cos(turn) * out, sin(turn) * out,
			(_hash01(seed_value + index * 59) - 0.5) * size * 1.2)
		_speck(surface, at, origin + at * at_mote, size * lerpf(0.05, 0.11, _hash01(seed_value + index * 83)),
			_fade(tone, lerpf(0.45, 1.0, _hash01(seed_value + index * 17))))

static func _flecks(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## Leaves of metal rather than specks of it: flat plates at every angle, so some catch
	## the light and some are edge-on and nearly gone. Pyrite for as many as the hand held.
	var dull := Color(tone.r * 0.50, tone.g * 0.38, tone.b * 0.20, tone.a * 0.85)
	for index in 7:
		var turn := _hash01(seed_value + index * 37) * TAU
		var out: float = size * sqrt(_hash01(seed_value + index * 61)) * 0.86
		var middle := Vector3(cos(turn) * out, sin(turn) * out,
			(_hash01(seed_value + index * 73) - 0.5) * size)
		var tilt := Basis.from_euler(Vector3((_hash01(seed_value + index * 11) - 0.5) * 2.6,
			(_hash01(seed_value + index * 23) - 0.5) * 2.6, _hash01(seed_value + index * 43) * TAU))
		var leaf: float = size * lerpf(0.20, 0.34, _hash01(seed_value + index * 89))
		var plate := [Vector3(leaf, leaf * 0.64, 0.0), Vector3(-leaf * 0.72, leaf, 0.0),
			Vector3(-leaf, -leaf * 0.66, 0.0), Vector3(leaf * 0.68, -leaf, 0.0)]
		var here: Vector3 = origin + at * middle
		var turned := at * tilt
		_tri(surface, here + turned * plate[0], here + turned * plate[1], here + turned * plate[2], tone, dull, tone)
		_tri(surface, here + turned * plate[0], here + turned * plate[2], here + turned * plate[3], tone, tone, dull)

static func _silk(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## Silk: rutile grown as a sheaf of parallel needles, all lying the same way, which is
	## what gives a stone its sheen — and here, a sheet of block off one soft shimmer.
	var gone := _fade(tone, 0.0)
	for index in 11:
		var across: float = lerpf(-size * 0.92, size * 0.92, float(index) / 10.0)
		var long: float = size * lerpf(0.55, 1.0, sin((float(index) / 10.0) * PI)) \
			* lerpf(0.80, 1.0, _hash01(seed_value + index * 19))
		var slant: float = (_hash01(seed_value + index * 29) - 0.5) * size * 0.10
		_blade(surface, at, origin, Vector3(across - slant, -long, 0.0), Vector3(across + slant, long, 0.0),
			size * 0.020, _fade(tone, 0.85), gone)
		_blade(surface, at, origin, Vector3(across + slant, long, 0.0), Vector3(across - slant, -long, 0.0),
			size * 0.020, _fade(tone, 0.85), gone)

static func _needle(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## One needle, run right across the stone and sharpened at both ends. A gem reads every
	## die through it, so it is the longest single thing anything in this file draws.
	var gone := _fade(tone, 0.0)
	var half: float = size * 0.055
	_blade(surface, at, origin, Vector3(0.0, 0.0, 0.0), Vector3(0.0, size, 0.0), half, tone, gone)
	_blade(surface, at, origin, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -size, 0.0), half, tone, gone)
	# A needle is round, not flat: a second blade across the first keeps it from vanishing
	# when the stone is turned edge-on to it.
	var side := Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0))
	_blade(surface, at * side, origin, Vector3.ZERO, Vector3(0.0, size, 0.0), half, tone, gone)
	_blade(surface, at * side, origin, Vector3.ZERO, Vector3(0.0, -size, 0.0), half, tone, gone)

static func _sparkle(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## A four-rayed flash with a hot core: the one pinpoint that is not a thing in the stone
	## but light coming off one. Resonance, standing still.
	var gone := _fade(tone, 0.0)
	for index in 4:
		var turn := float(index) * PI * 0.5
		_blade(surface, at, origin, Vector3.ZERO, Vector3(cos(turn), sin(turn), 0.0) * size, size * 0.075, tone, gone)
	for index in 4:
		var turn := float(index) * PI * 0.5 + PI * 0.25
		_blade(surface, at, origin, Vector3.ZERO, Vector3(cos(turn), sin(turn), 0.0) * size * 0.42,
			size * 0.055, _fade(tone, 0.55), gone)
	_disc(surface, at, origin, size * 0.20, tone, gone, 14)
	_speck(surface, at, origin, size * 0.12, tone)

static func _emberline(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A line of embers banked along a seam, hottest at one end and going out at the other.
	## Poison: something in the stone that is still burning.
	var cool := Color(tone.r * 0.62, tone.g * 0.20, tone.b * 0.22, tone.a)
	var path: Array = []
	for index in 9:
		var t := float(index) / 8.0
		path.append(Vector3(lerpf(-size, size, t), sin(t * PI * 1.4 + _hash01(seed_value) * TAU) * size * 0.22, 0.0))
	_ribbon(surface, at, origin, path, size * 0.045, _fade(tone, 0.35), 0.6)
	for index in 7:
		var t := (float(index) + 0.5) / 7.0
		var hot: Color = tone.lerp(cool, t)
		var at_ember: Vector3 = Vector3(lerpf(-size * 0.92, size * 0.92, t),
			sin(t * PI * 1.4 + _hash01(seed_value) * TAU) * size * 0.22, 0.0)
		_speck(surface, at, origin + at * at_ember,
			size * lerpf(0.13, 0.07, t), _fade(hot, lerpf(1.0, 0.55, t)))

# --- the lenses ---------------------------------------------------------------

static func _veil(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A veil: a sheet of something so fine it is only a change in what the stone lets
	## through. No edge to speak of, a faint stipple of droplets across it, and the gem
	## reading its lowest die as its highest through the smoke.
	var gone := _fade(tone, 0.0)
	_disc(surface, at, origin, size, _fade(tone, 0.55), gone, 22, 0.74)
	_disc(surface, at, origin, size * 0.58, _fade(tone, 0.80), _fade(tone, 0.20), 18, 0.74)
	for index in 9:
		var turn := _hash01(seed_value + index * 37) * TAU
		var out: float = size * 0.82 * sqrt(_hash01(seed_value + index * 53))
		_speck(surface, at, origin + at * Vector3(cos(turn) * out, sin(turn) * out * 0.74, 0.0),
			size * 0.035, _fade(tone, 0.9))

static func _cats_eye(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## A pupil: a dark lens with one bright slit standing in it, the band of light a
	## chatoyant stone throws. Every 1 is wild, and the stone is watching for them.
	var dark := Color(0.08, 0.07, 0.12, tone.a * 0.85)
	var gone := _fade(tone, 0.0)
	_disc(surface, at, origin, size, dark, Color(dark.r, dark.g, dark.b, 0.0), 22, 0.78)
	_annulus(surface, at, origin, size * 0.86, size, _fade(tone, 0.55), gone, 24)
	# The slit itself, bright at its middle and drawn to a point at each end.
	_blade(surface, at, origin, Vector3.ZERO, Vector3(0.0, size * 0.92, 0.0), size * 0.12, tone, gone)
	_blade(surface, at, origin, Vector3.ZERO, Vector3(0.0, -size * 0.92, 0.0), size * 0.12, tone, gone)
	_disc(surface, at, origin, size * 0.17, tone, gone, 12)

static func _graining(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## Graining: flat parallel planes left where the crystal grew in steps. One band is
	## drawn twice as strongly as the rest, which is the whole of what the inclusion does.
	var doubled: int = 1 + int(_hash01(seed_value) * 3.0)
	for index in 5:
		var across: float = lerpf(-size * 0.86, size * 0.86, float(index) / 4.0)
		var strength: float = 1.0 if index == doubled else 0.44
		var long: float = size * lerpf(0.72, 1.0, sin((float(index) / 4.0) * PI))
		var band: Array = [Vector3(across, -long, 0.0), Vector3(across, long, 0.0)]
		_ribbon(surface, at, origin, band, size * 0.055 * (1.6 if index == doubled else 1.0),
			_fade(tone, strength), 0.35)
		if index == doubled:
			_ribbon(surface, at, origin, [Vector3(across, -long, 0.0), Vector3(across, long, 0.0)],
				size * 0.018, tone, 0.2)
	# One faint line across the grain, so the bands read as planes rather than as stripes.
	_ribbon(surface, at, origin, [Vector3(-size, 0.0, 0.0), Vector3(size, 0.0, 0.0)], size * 0.01,
		_fade(tone, 0.22), 0.4)

# --- the feathers -------------------------------------------------------------

static func _feather(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A wing: a spine with fine barbs off both sides, each fading to nothing at its tip.
	## Feathers are the flaw that looks like frost, and it is the fade that does that.
	var gone := _fade(tone, 0.0)
	var barbs := 9
	_blade(surface, at, origin, Vector3(0.0, -size * 0.62, 0.0), Vector3(0.0, size * 0.70, 0.0),
		size * 0.026, tone, gone)
	for index in barbs:
		var t := (float(index) + 0.5) / float(barbs)
		var root := Vector3(0.0, lerpf(-size * 0.54, size * 0.54, t), 0.0)
		var out := size * 0.52 * sin(t * PI) * lerpf(0.55, 1.0, _hash01(seed_value + index * 37))
		for way: float in [-1.0, 1.0]:
			_blade(surface, at, origin, root, root + Vector3(way * out, size * 0.22, 0.0),
				size * 0.030, _fade(tone, 0.9), gone)

static func _wisps(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## Twinning wisps: two ribbons running the same way, one a shade behind the other —
	## the crystal having grown twice. The gem fires again if the one before it did.
	for pair in 2:
		var side: float = (float(pair) - 0.5) * size * 0.30
		var phase: float = _hash01(seed_value + pair * 61) * TAU
		var path: Array = []
		for index in 11:
			var t := float(index) / 10.0
			path.append(Vector3(side + sin(t * PI * 1.8 + phase) * size * 0.20,
				lerpf(-size * 0.94, size * 0.94, t), 0.0))
		_ribbon(surface, at, origin, path, size * 0.085, _fade(tone, 1.0 if pair == 0 else 0.55), 0.55)

static func _fingerprint(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A fingerprint: healed fissure, refilled as curved sheets of tiny droplets. Nested
	## arcs of specks rather than lines, because that is what one is under a loupe — and
	## because it carries the print of the gem before it.
	var turn: float = _hash01(seed_value) * TAU
	for loop in 3:
		var radius: float = size * lerpf(0.34, 1.0, float(loop) / 2.0)
		var sweep: float = lerpf(2.3, 4.4, _hash01(seed_value + loop * 17))
		var motes: int = 7 + loop * 4
		for index in motes:
			var angle: float = turn + sweep * float(index) / float(motes - 1) - sweep * 0.5 + float(loop) * 0.24
			_speck(surface, at, origin + at * (Vector3(cos(angle), sin(angle), 0.0) * radius),
				size * lerpf(0.035, 0.055, _hash01(seed_value + loop * 31 + index)),
				_fade(tone, lerpf(0.55, 1.0, _hash01(seed_value + loop * 13 + index * 7))))

static func _halo(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A halo: one crystal at the centre and a ring of short stress cracks thrown out of it
	## into the stone around it. Its neighbours gain a carat — and here they wear the mark.
	var gone := _fade(tone, 0.0)
	_speck(surface, at, origin, size * 0.26, tone)
	_annulus(surface, at, origin, size * 0.40, size * 0.46, _fade(tone, 0.75), gone, 26)
	for index in 12:
		var turn := TAU * float(index) / 12.0 + _hash01(seed_value) * TAU
		var dir := Vector3(cos(turn), sin(turn), 0.0)
		var out: float = size * lerpf(0.70, 1.0, _hash01(seed_value + index * 43))
		_blade(surface, at, origin, dir * size * 0.42, dir * out, size * 0.045, _fade(tone, 0.85), gone)

static func _filament(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A vein of something that hums: a bright thread across the stone with three swollen
	## nodes strung on it, each with its own small halo of light.
	var phase: float = _hash01(seed_value) * TAU
	var path: Array = []
	for index in 13:
		var t := float(index) / 12.0
		path.append(Vector3(lerpf(-size, size, t), sin(t * PI * 2.2 + phase) * size * 0.26, 0.0))
	_ribbon(surface, at, origin, path, size * 0.075, _fade(tone, 0.55), 0.5)
	_ribbon(surface, at, origin, path, size * 0.022, tone, 0.35)
	for index in 3:
		var t := (float(index) + 0.5) / 3.0
		var node: Vector3 = Vector3(lerpf(-size * 0.92, size * 0.92, t),
			sin(t * PI * 2.2 + phase) * size * 0.26, 0.0)
		_disc(surface, at, origin + at * node, size * 0.15, _fade(tone, 0.7), _fade(tone, 0.0), 14)
		_speck(surface, at, origin + at * node, size * 0.07, tone)

# --- the fractures ------------------------------------------------------------

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

static func _bruise(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A bruise: where the stone was struck. A dark blot of ruptured crystal with short
	## cracks thrown out of the point of impact, and the blood color to say it costs HP.
	var gone := _fade(tone, 0.0)
	var deep := Color(tone.r * 0.55, tone.g * 0.35, tone.b * 0.50, tone.a)
	_disc(surface, at, origin, size, _fade(deep, 0.85), gone, 20, 0.86)
	_disc(surface, at, origin, size * 0.52, tone, _fade(tone, 0.25), 16, 0.86)
	for index in 7:
		var turn := TAU * float(index) / 7.0 + _hash01(seed_value) * TAU
		var dir := Vector3(cos(turn), sin(turn), 0.0)
		_blade(surface, at, origin, dir * size * 0.30,
			dir * size * lerpf(0.95, 1.30, _hash01(seed_value + index * 29)), size * 0.055,
			_fade(tone, 0.9), gone)

static func _knot(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A knot: another crystal grown inside this one and never coming out, which is exactly
	## what the inclusion says. Blocky, opaque, with the stone strained in a ring around it.
	var face: Array = _crystal(size, 6, _hash01(seed_value) * TAU, 0.22, seed_value)
	var lit := Color(tone.r * 1.5, tone.g * 1.4, tone.b * 1.2, tone.a)
	_polygon(surface, at, origin, face, tone, _fade(tone, 0.92))
	_lip(surface, at, origin, face, size * 0.10, _fade(lit, 0.55))
	# The facets of the thing inside, so it reads as a crystal and not as a blot.
	for index in face.size():
		var a: Vector3 = face[index]
		var b: Vector3 = face[(index + 1) % face.size()]
		_tri(surface, origin + at * (a * 0.30), origin + at * a, origin + at * b,
			_fade(lit, 0.45), _fade(tone, 0.0), _fade(lit, 0.30))
	_annulus(surface, at, origin, size * 1.10, size * 1.22, _fade(lit, 0.34), _fade(lit, 0.0), 24)

static func _hollow(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A void: a negative crystal, a hole in the shape of the stone that should have been
	## there. Black to the middle, with only its wall catching any light — the one mark in
	## the game that is an absence, for the one inclusion that takes no socket.
	var face: Array = _crystal(size, 6, _hash01(seed_value) * TAU, 0.10, seed_value)
	var rim := Color(0.54, 0.48, 0.78, tone.a * 0.80)
	_polygon(surface, at, origin, face, Color(tone.r, tone.g, tone.b, tone.a),
		Color(tone.r, tone.g, tone.b, tone.a * 0.92))
	_lip(surface, at, origin, face, size * 0.16, rim)
	# A second, smaller face inside it, offset: a negative crystal has depth to fall into.
	var inner: Array = []
	for point in face:
		inner.append((point as Vector3) * 0.52 + Vector3(size * 0.12, size * 0.10, 0.0))
	_polygon(surface, at, origin, inner, Color(0, 0, 0, tone.a), Color(0, 0, 0, tone.a * 0.6))
	_lip(surface, at, origin, inner, size * 0.06, _fade(rim, 0.45))

static func _cavity(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A cavity: a pit opening out of the stone, ragged where it broke rather than faceted
	## where it grew. Double the carats, and a Poor cut, because this is what a cutter has
	## to work around.
	var face: Array = _crystal(size, 11, _hash01(seed_value) * TAU, 0.52, seed_value)
	var lip := Color(0.82, 0.86, 0.94, tone.a * 0.62)
	_polygon(surface, at, origin, face, Color(tone.r, tone.g, tone.b, tone.a),
		Color(tone.r, tone.g, tone.b, tone.a * 0.85))
	_lip(surface, at, origin, face, size * 0.13, lip)
	# The walls falling away inside it, drawn as spokes so the pit has a bottom.
	for index in face.size():
		_tri(surface, origin, origin + at * ((face[index] as Vector3) * 0.86),
			origin + at * ((face[(index + 1) % face.size()] as Vector3) * 0.86),
			Color(0, 0, 0, tone.a * 0.9), _fade(lip, 0.30), _fade(lip, 0.10))

static func _chip(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## A chip: a wedge knocked clean out, all flat planes meeting in sharp edges. It buys
	## carats and costs a Cut step, and it is the only flaw here with straight sides.
	var gone := _fade(tone, 0.0)
	var turn: float = _hash01(seed_value) * TAU
	var spin := Basis.from_euler(Vector3(0.0, 0.0, turn))
	var faces := [[Vector3(-size, -size * 0.45, 0.0), Vector3(size * 0.86, -size * 0.20, 0.0), Vector3(-size * 0.10, size, 0.0)],
		[Vector3(-size, -size * 0.45, 0.0), Vector3(-size * 0.10, size, 0.0), Vector3(-size * 0.30, size * 0.10, size * 0.42)],
		[Vector3(size * 0.86, -size * 0.20, 0.0), Vector3(-size * 0.30, size * 0.10, size * 0.42), Vector3(-size * 0.10, size, 0.0)]]
	for index in faces.size():
		var face: Array = faces[index]
		var shade: float = [1.0, 0.52, 0.76][index]
		_tri(surface, origin + at * (spin * (face[0] as Vector3)), origin + at * (spin * (face[1] as Vector3)),
			origin + at * (spin * (face[2] as Vector3)), _fade(tone, shade), _fade(tone, shade * 0.6), gone)

# --- the stars ----------------------------------------------------------------

static func _star(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## Asterism: six rays of light standing off one centre, the way a star sapphire throws
	## them. Broad where they meet and gone at the tips, so the middle burns and the arms
	## trail off into the body.
	var gone := _fade(tone, 0.0)
	for index in 6:
		var turn := float(index) * PI / 3.0
		_blade(surface, at, origin, Vector3.ZERO, Vector3(cos(turn), sin(turn), 0.0) * size, size * 0.06, tone, gone)
	_disc(surface, at, origin, size * 0.22, _fade(tone, 0.55), gone, 16)
	_speck(surface, at, origin, size * 0.16, tone)

static func _chatoyance(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color) -> void:
	## Two bands of silk light lying across the stone rather than one, because the gem
	## fires twice. Broad, soft-edged and going out at both ends: a sheen, not a line.
	var gone := _fade(tone, 0.0)
	for pair in 2:
		var across: float = (float(pair) - 0.5) * size * 0.46
		var band: Array = [Vector3(-size, across, 0.0), Vector3(size, across, 0.0)]
		_ribbon(surface, at, origin, band, size * 0.16, _fade(tone, 0.30), 0.85)
		_ribbon(surface, at, origin, band, size * 0.045, _fade(tone, 0.95), 0.6)
	_disc(surface, at, origin, size * 0.30, _fade(tone, 0.28), gone, 18, 0.55)

static func _glow(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		seed_value: int) -> void:
	## Fluorescence: not a thing in the stone at all, but the stone answering a light it is
	## not standing in. No edge anywhere — layered haze with a few motes hanging in it, and
	## it gets stronger the deeper the run goes.
	var gone := _fade(tone, 0.0)
	for layer in 4:
		var radius: float = size * lerpf(0.34, 1.0, float(layer) / 3.0)
		_disc(surface, at, origin, radius, _fade(tone, lerpf(0.55, 0.16, float(layer) / 3.0)), gone, 20,
			lerpf(1.0, 0.78, float(layer) / 3.0))
	for index in 6:
		var turn := _hash01(seed_value + index * 53) * TAU
		var out: float = size * 0.66 * sqrt(_hash01(seed_value + index * 67))
		_speck(surface, at, origin + at * Vector3(cos(turn) * out, sin(turn) * out, 0.0),
			size * 0.05, _fade(tone, 0.9))

static func _alexandrite(surface: SurfaceTool, at: Basis, origin: Vector3, size: float, tone: Color,
		other: Color) -> void:
	## Two colors in one stone, each returned under a different light: the rays alternate
	## between them and the core is split down the middle. It takes the color of whatever
	## socket it sits in, and this is it caught halfway between two of them.
	for index in 6:
		var turn := float(index) * PI / 3.0
		var shade: Color = tone if index % 2 == 0 else other
		_blade(surface, at, origin, Vector3.ZERO, Vector3(cos(turn), sin(turn), 0.0) * size,
			size * 0.085, shade, _fade(shade, 0.0))
	_disc(surface, at, origin, size * 0.26, _fade(tone, 0.85), _fade(tone, 0.0), 12, 1.0)
	var half := Basis.from_euler(Vector3(0.0, 0.0, PI))
	_disc(surface, at * half, origin, size * 0.26, _fade(other, 0.85), _fade(other, 0.0), 12, 1.0)
	_speck(surface, at, origin, size * 0.11, Color(1, 1, 1, tone.a))

# --- placing ------------------------------------------------------------------

static func _mark(surface: SurfaceTool, env: Dictionary, outline: PackedVector2Array,
		key: String, seed_value: int, scale: float) -> void:
	var style: Dictionary = style_of(key)
	var draw: String = str(style.get("draw", "speck"))
	var size: float = float(style.get("size", 0.2)) * scale
	var named: String = str(style.get("tone", "ffffff"))
	var tone := Color(named) if named.is_valid_html_color() else Color.WHITE
	## The same bargain the emblem strikes: a cloudy stone lets very little of its inside
	## back out, and a cloudy stone is exactly the one with things in it worth seeing. Murk
	## is allowed to change how a flaw looks, never whether it can be found.
	var murk: float = clampf(float(env.get("murk", 0.0)), 0.0, 1.0)
	tone.a = clampf(float(style.get("alpha", 0.6)) * lerpf(1.0, 2.0, murk), 0.0, 1.0) \
		* clampf(Tuning.value("flaw_alpha"), 0.0, 1.0)
	## Where it sits, and how much of it the crystal has room for. A mark declares how far
	## past its nominal size it actually reaches; everything else follows from that.
	var room: Dictionary = _place(env, outline, seed_value, size * float(DRAW_REACH.get(draw, 1.1)))
	var origin: Vector3 = room.at
	size *= float(room.fit)
	## How it lies. The flat marks would vanish edge-on if they were turned freely, and a
	## stone is nearly always looked at face on, so they spin about the viewing axis and
	## only lean out of it — scattered in three dimensions, still every one of them legible.
	var at := Basis.from_euler(Vector3(
		(_hash01(seed_value + 23) - 0.5) * 1.10,
		(_hash01(seed_value + 29) - 0.5) * 1.10,
		_hash01(seed_value + 31) * TAU))
	## Every mark is laid on a soft shadow of its own size. Light that reaches something
	## frozen in a stone scatters off it and does not come back out, so the body right
	## around an inclusion goes darker — and that shadow is also the only thing that lets
	## a pale mark be found on a bright body. A white Star on a Gold gem was white on gold
	## and could not be seen at all; every mark was legible on a Blue and half of them
	## were invisible on a Green, a Gold or a White, which is not a look, it is a bug.
	## How far the mark's own color is lost in the body it is set in. A white Star in a
	## Gold gem is two shades of one pale yellow and reads as nothing at all, so the shadow
	## under it is deepened by exactly as much as its color fails to carry it — and left
	## nearly off where the two already contrast, so a Void in a White gem keeps its edge
	## instead of sitting in a bruise of its own.
	var body: Color = env.get("body", Color(0.34, 0.36, 0.42))
	var clash: float = clampf(1.0 - Vector3(tone.r - body.r, tone.g - body.g,
		tone.b - body.b).length() / 0.62, 0.0, 1.0)
	var shade: float = clampf(Tuning.value("flaw_shadow") * lerpf(0.45, 1.9, clash), 0.0, 1.0) * tone.a
	if shade > 0.001:
		var dark := Color(0.05, 0.04, 0.09, shade)
		_disc(surface, at, origin, size * float(DRAW_REACH.get(draw, 1.1)) * 0.90,
			dark, Color(dark.r, dark.g, dark.b, 0.0), 22)
	match draw:
		"speck": _speck(surface, at, origin, size, tone)
		"grains": _grains(surface, at, origin, size, tone, seed_value)
		"dust": _dust(surface, at, origin, size, tone, seed_value)
		"flecks": _flecks(surface, at, origin, size, tone, seed_value)
		"silk": _silk(surface, at, origin, size, tone, seed_value)
		"needle": _needle(surface, at, origin, size, tone)
		"sparkle": _sparkle(surface, at, origin, size, tone)
		"emberline": _emberline(surface, at, origin, size, tone, seed_value)
		"veil": _veil(surface, at, origin, size, tone, seed_value)
		"cats_eye": _cats_eye(surface, at, origin, size, tone)
		"graining": _graining(surface, at, origin, size, tone, seed_value)
		"feather": _feather(surface, at, origin, size, tone, seed_value)
		"wisps": _wisps(surface, at, origin, size, tone, seed_value)
		"fingerprint": _fingerprint(surface, at, origin, size, tone, seed_value)
		"halo": _halo(surface, at, origin, size, tone, seed_value)
		"filament": _filament(surface, at, origin, size, tone, seed_value)
		"fracture": _fracture(surface, at, origin, size, tone, seed_value)
		"bruise": _bruise(surface, at, origin, size, tone, seed_value)
		"knot": _knot(surface, at, origin, size, tone, seed_value)
		"hollow": _hollow(surface, at, origin, size, tone, seed_value)
		"cavity": _cavity(surface, at, origin, size, tone, seed_value)
		"chip": _chip(surface, at, origin, size, tone, seed_value)
		"star": _star(surface, at, origin, size, tone)
		"chatoyance": _chatoyance(surface, at, origin, size, tone)
		"glow": _glow(surface, at, origin, size, tone, seed_value)
		"alexandrite":
			var second: String = str(style.get("tone2", "3fb56b"))
			var other := Color(second) if second.is_valid_html_color() else Color("3fb56b")
			other.a = tone.a
			_alexandrite(surface, at, origin, size, tone, other)
		_: _speck(surface, at, origin, size, tone)

# --- metal in the matrix ------------------------------------------------------

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

# --- the whole interior -------------------------------------------------------

static func build(gem: Dictionary, env: Dictionary) -> ArrayMesh:
	## Everything set inside this stone, as one mesh. Null when there is nothing in there,
	## which is the common case: a Flawless gem that is not a Seam has a clean interior.
	var outline: PackedVector2Array = env.get("outline", PackedVector2Array())
	if outline.size() < 3:
		return null
	var seed_value: int = int(env.get("seed", 0))
	var scale: float = clampf(Tuning.value("flaw_size"), 0.1, 3.0)
	## Zonings are worn by the body rather than held in it, so they are dropped here and
	## picked up by the shell's gradient instead. A stone carrying nothing else is clean.
	var listed: Array = carried(gem, int(env.get("flaws", 0)), seed_value)
	var keys: Array = []
	for index in listed.size():
		var key: String = str(listed[index])
		if draws_inside(key):
			keys.append([key, index])
	var vein := seam_color(gem)
	var flakes: int = int(env.get("flakes", 0))
	if keys.is_empty() and vein.a <= 0.0 and flakes <= 0:
		return null
	var mesh := ArrayMesh.new()
	if not keys.is_empty() or vein.a > 0.0:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(inside_material())
		if vein.a > 0.0:
			_seam(surface, env, outline, vein, seed_value)
		for entry: Array in keys:
			_mark(surface, env, outline, str(entry[0]), seed_value + 101 + int(entry[1]) * 911, scale)
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
	# is what puts it inside the stone rather than over it. After the emblem, though, and
	# not alongside it: a stone's flaws are the thing the player is deciding on, and a big
	# emblem sitting at the same priority would sort in front of any mark behind it.
	material.no_depth_test = true
	material.render_priority = 2
	return material
