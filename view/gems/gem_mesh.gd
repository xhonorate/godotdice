extends RefCounted
## Builds a stone as real faceted geometry from its four C's.
##
## The stone is a cut solid: a flat table on top, a crown of facets falling away from it
## to the girdle at the widest point, and a pavilion below narrowing to a culet. Each of
## the four properties owns one part of that and nothing else:
##
##   Color   the girdle outline and the body hue — a trilliant for Red, a princess for
##           Blue, a heart for Green, a pear for Violet, a half Dutch rose for Gold and a
##           round brilliant for White.
##   Carat   the scale the whole solid is drawn at, on a curve.
##   Cut     how intricate the faceting is: vertices along each edge of the outline,
##           bands of facets above and below the girdle, and how small the table ends up.
##   Clarity the material — how far the hue sits from grey, how polished it is, how much
##           light it throws back, and how many inclusions are frozen inside it.
##
## Alternate bands are staggered half a step so facets meet point to edge, which is what
## makes a real brilliant sparkle rather than look like a stack of rings.
##
## Nothing here touches the scene tree, so all of it is testable headless: `gem_view.gd`
## is the part that needs a viewport, and it degrades to nothing when there is no display.

const GemIcons = preload("res://view/gems/gem_icons.gd")
## Every material and lighting number lives in one adjustable table, so the gem lab can
## move any of them and see the stone answer. Untouched it hands back the shipped values.
const Tuning = preload("res://view/gems/gem_tuning.gd")

## How clear each grade of the clarity ladder reads, Riddled to Flawless. The centre of the
## ladder is an honest, ordinary stone; the pure tail is glass and the included tail is milk.
const BRILLIANCE: Array = [0.0, 0.16, 0.36, 0.60, 0.84, 1.0]
## Fallback hues if the pack has none.
const FALLBACK_HUES: Dictionary = {"RED": "e0473c", "BLUE": "3f7fe0", "GREEN": "3fb56b", "VIOLET": "8b5fd6", "GOLD": "e2b23a", "WHITE": "e8eef5"}

# --- reading a stone -----------------------------------------------------------

static func skill_key(gem: Dictionary) -> String:
	return str(gem.get("skill", gem.get("key", "")))

## A Birthstone names a cut of its own. Until each has its own solid, it borrows the nearest
## of the six outlines and is told apart by its tint and its emblem.
const STYLE_OUTLINES: Dictionary = {"shield": "RED", "marquise": "VIOLET", "step": "BLUE", "briolette": "VIOLET",
	"checkerboard": "WHITE", "cube": "BLUE"}

static func colour_key(gem: Dictionary) -> String:
	var style: String = str(gem.get("style", ""))
	if STYLE_OUTLINES.has(style):
		return str(STYLE_OUTLINES[style])
	var explicit: String = str(gem.get("colour", ""))
	if explicit in FALLBACK_HUES:
		return explicit
	var found: String = str(DeepContent.skill(skill_key(gem)).get("colour", ""))
	return found if found in FALLBACK_HUES else "RED"

static func hue(color_key: String) -> Color:
	return Color(str(DeepContent.colour(color_key).get("hue", FALLBACK_HUES.get(color_key, "e0473c"))))

static func tint(gem: Dictionary) -> Color:
	## The stone's own hue: a Birthstone carries one, every other stone takes its colour's.
	var own: String = str(gem.get("hue", ""))
	if not own.is_empty() and own.is_valid_html_color():
		return Color(own)
	return hue(colour_key(gem))

static func body_colour_of(gem: Dictionary, clarity: int) -> Color:
	return _body_colour(tint(gem), clarity)

static func emblem_of(gem: Dictionary) -> String:
	var own: String = str(gem.get("emblem", ""))
	return own if not own.is_empty() else GemIcons.emblem(skill_key(gem))

static func cut_rank(gem: Dictionary) -> int:
	## The old one-to-five Cut the geometry tables were written against: Poor is 1.
	return clampi(int(gem.get("cut", 0)) + 1, 1, 5)

static func clarity_grade(gem: Dictionary) -> int:
	return clampi(int(gem.get("clarity", 3)), 0, BRILLIANCE.size() - 1)

static func seed_of(gem: Dictionary) -> int:
	## Two stones of one skill are still two stones: the id joins the hash so their facets
	## and their flaws fall differently.
	return (skill_key(gem) + "|" + str(gem.get("id", ""))).hash()

## Which cut each Color wears. Shape carries the category as loudly as hue does, and it
## survives greyscale, colour blindness and a 32-pixel thumbnail.
const CUTS := {"RED": "trilliant", "BLUE": "princess", "GREEN": "heart",
	"VIOLET": "pear", "GOLD": "dutch_rose", "WHITE": "round"}
## What each cut is called in a sentence. The keys are identifiers; these are the words.
const SHAPE_NAMES := {"trilliant": "trilliant", "princess": "princess", "heart": "heart",
	"pear": "pear", "dutch_rose": "half Dutch rose", "round": "round brilliant"}
## Cut is how TRUE the stone is cut, not how busy it is.
##
## Perfect is the clean solid: one band of crown facets over a two-band pavilion, a narrow
## table, and a girdle that follows the outline exactly. Every rank below it is that same
## solid cut worse — squatter, blunter, with a girdle that wanders where the wheel took too
## much and, at the bottom of the range, corners knocked clean off as chips.
##
## The first model ran the other way, adding facets and bands as the rank rose. It was
## wrong twice over: a Perfect stone came out looking like a golf ball, and every shape
## lost its silhouette to the extra geometry. The best-looking stone was always the
## simplest one, so that is what Perfect is now, and Poor is a damaged version of it.
const EDGE_STEPS := [1, 1, 1, 1, 1]
const CROWN_BANDS := [1, 1, 1, 1, 1]
## A Poor stone is blunt underneath as well: one pavilion band instead of two.
const PAVILION_BANDS := [1, 2, 2, 2, 2]
## A badly cut stone keeps a wide flat table, because that is where the weight is saved.
const TABLE_SPAN := [0.72, 0.66, 0.62, 0.59, 0.56]
## How far the girdle wanders off the true outline, and how many corners are chipped away.
## Both are deliberately restrained: a Poor stone has to read as badly cut at a glance and
## still read as the same shape as a Perfect one, because Colour is carried by the outline.
## The first pass at these ran about 40% harder and turned a Poor trilliant into a shard.
const CUT_WANDER := [0.16, 0.10, 0.05, 0.04, 0.00]
const CUT_CHIPS := [3, 2, 1, 0, 0]
## Poor cuts are shallow: a low crown over a shallow pavilion, so the stone reads as flat.
const CUT_CROWN := [0.55, 0.70, 0.84, 0.93, 1.00]
const CUT_DEPTH := [0.72, 0.82, 0.90, 0.96, 1.00]
## How the etched emblem is sized against the stone's reach, per outline. A pear is
## narrow at the point and a princess is square, so one number cannot serve both.
const EMBLEM_SPAN := {"trilliant": 0.86, "princess": 1.10, "heart": 0.94,
	"pear": 0.84, "dutch_rose": 1.04, "round": 1.06}
## Two of the cuts are not brilliants, and a brilliant's proportions would make them lie.
## A rose cut has no table worth the name: its crown is a dome of facets rising to a point,
## and its back is left flat, because the whole cut exists to save weight. These scale the
## table, the crown and the pavilion the rest of the file works out from Cut, so the rank
## still says how TRUE the stone was cut — it just says it about a different solid.
const SHAPE_TABLE := {"dutch_rose": 0.30}
const SHAPE_CROWN := {"dutch_rose": 1.25}
const SHAPE_PAVILION := {"dutch_rose": 0.40}

## The prism, as a pass laid over the near half. A cut stone splits white light because
## its refractive index differs by wavelength, so each facet returns a different colour and
## the colours sweep as the stone turns. Doing that honestly would mean tracing several
## wavelengths through the solid; this reads the same and costs one additive pass.
##
## Everything is in view space, which is what makes it work under an orthogonal camera:
## `VIEW` is constant there, so the whole effect is driven by each facet's own normal, and
## turning the stone is what moves the colours.
const FIRE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float fire = 0.85;
uniform float bands = 3.4;
uniform float spread = 1.0;
uniform float reach = 0.25;
uniform float sharpness = 2.0;
uniform vec3 tint = vec3(1.0);

void fragment() {
	// Where this facet would throw a reflection decides which part of the spectrum it
	// returns, so neighbouring facets never agree and a turning stone sweeps through them.
	vec3 bounce = reflect(-VIEW, NORMAL);
	float phase = dot(bounce, vec3(0.61, 0.42, 0.27)) * spread;
	float band = fract(phase * bands);
	vec3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (band + vec3(0.0, 0.3333, 0.6667)));
	// Steep facets split light hardest, which is why a stone's fire lives at its edges.
	float grazing = clamp(1.0 - abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	ALBEDO = spectrum * tint * fire;
	ALPHA = clamp(mix(reach, 1.0, pow(grazing, sharpness)), 0.0, 1.0);
}
"""

const CROWN_HEIGHT := 0.34
const GIRDLE := 0.055
const PAVILION_DEPTH := 0.74
const ETCH_PIXELS := 96

static var _normals: Dictionary = {}
static var _faces: Dictionary = {}
static var _fire: Shader = null

# --- the four properties as numbers -------------------------------------------

static func carat_span(carat: int) -> float:
	## How big the stone is against the slot it sits in, and the number that matters: Carat
	## is the rank that decides the most, so it should be the one visible from across the
	## table. 0.65 at Carat 1 — the size a small gem has always been, set by legibility in a
	## 56-pixel list row — rising gently through the middle of the range on the first term,
	## then hard at the top on the second. Past about Carat 19 it is wider than its own slot
	## and spills over the edges; at Carat 24 it is a little over twice the reach of Carat 1.
	var t := float(clampi(carat, 1, DeepStone.carat_max()) - 1) / float(maxi(1, DeepStone.carat_max() - 1))
	return 0.85 + 0.33 * pow(t, 0.62) + 0.47 * pow(t, 8.0)

static func carat_frame(carat: int) -> float:
	## How far past its slot the view has to reach to draw the stone whole. An overflowing
	## stone is drawn into a bigger viewport centred on the same spot rather than cropped at
	## the slot edge: a clipped gem reads as a bug, one hanging over the edge reads as a
	## boulder that will not fit in the setting.
	return maxf(1.0, carat_span(carat))

static func carat_scale(carat: int) -> float:
	## The scale inside that frame. It never passes 1.0, so the solid always fits the camera
	## and is never cut off; everything above 1.0 is carried by the frame instead.
	return carat_span(carat) / carat_frame(carat)

static func brilliance(clarity: int) -> float:
	return float(BRILLIANCE[clampi(clarity, 0, BRILLIANCE.size() - 1)])

static func flaw_count(gem: Dictionary) -> int:
	## Inclusions frozen in the stone: the ones it really carries, each drawn as a darkened
	## facet. A stone whose inclusions have been eaten away by an acid bath is cleaner than
	## its grade says, and looks it.
	if gem.has("inclusions") and gem.inclusions is Array:
		return gem.inclusions.size()
	return DeepStone.inclusion_slots(clarity_grade(gem))

static func facet_count(cut: int, color_key: String) -> int:
	var k: int = clampi(cut, 1, 5)
	var around: int = silhouette(color_key).size() * EDGE_STEPS[k - 1]
	# Two triangles per segment per band, above and below, plus the pavilion's fan.
	return around * 2 * (CROWN_BANDS[k - 1] + PAVILION_BANDS[k - 1]) + around

static func body_colour(color_key: String, clarity: int) -> Color:
	return _body_colour(hue(color_key), clarity)

static func _body_colour(base: Color, clarity: int) -> Color:
	## A dull stone is not just darker: it is greyer. Clarity pulls the hue back towards
	## stone as it falls, which is what makes a Fractured gem look cloudy.
	var b := brilliance(clarity)
	return base.lerp(Color("6d7280"), lerpf(Tuning.value("grey_pull"), 0.0, b)).lerp(Color.BLACK, lerpf(0.18, 0.0, b))

# --- outlines -----------------------------------------------------------------

static func silhouette(color_key: String) -> PackedVector2Array:
	## Unit space, centred on the origin, longest reach 1.0, always wound the same way.
	match str(CUTS.get(color_key, "round")):
		"trilliant":
			return _wound(_truncated(_regular(3, -PI * 0.5), 0.17))
		"princess":
			return _wound(_truncated(_regular(4, PI * 0.25), 0.20))
		"heart":
			return _wound(_heart())
		"pear":
			return _wound(_pear())
		"dutch_rose":
			# A rose cut's girdle is a hexagon, and six segments over one crown band is
			# exactly the twelve-facet dome the cut is named for.
			return _wound(_regular(6, -PI * 0.5))
	return _wound(_regular(20, -PI * 0.5))

static func _wound(points: PackedVector2Array) -> PackedVector2Array:
	## Counter-clockwise seen from the front, which is what every facet below assumes when
	## it decides which way its normal points. An outline written the other way round is
	## reversed here rather than lighting the stone from inside.
	var area := 0.0
	var count := points.size()
	for index in count:
		var here := points[index]
		var following := points[(index + 1) % count]
		area += here.x * following.y - following.x * here.y
	if area >= 0.0:
		return points
	var flipped := PackedVector2Array()
	for index in range(count - 1, -1, -1):
		flipped.append(points[index])
	return flipped

static func _regular(sides: int, turn: float) -> PackedVector2Array:
	var built := PackedVector2Array()
	for index in sides:
		var angle := turn + TAU * float(index) / float(sides)
		built.append(Vector2(cos(angle), sin(angle)))
	return built

static func _truncated(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	## Clips every corner, which is what turns a triangle into a trilliant and a square
	## into a princess without changing what either reads as.
	var built := PackedVector2Array()
	var count := points.size()
	for index in count:
		var here := points[index]
		built.append(here.lerp(points[(index + count - 1) % count], amount))
		built.append(here.lerp(points[(index + 1) % count], amount))
	return built

static func _heart() -> PackedVector2Array:
	var raw: Array = []
	var peak := 0.0
	for index in range(24):
		var t := TAU * float(index) / 24.0
		var point := Vector2(16.0 * pow(sin(t), 3.0),
			13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		raw.append(point)
		peak = maxf(peak, point.length())
	var built := PackedVector2Array()
	for point in raw:
		built.append(Vector2(point) / peak)
	return built

static func _pear() -> PackedVector2Array:
	## The teardrop curve, sampled so the first vertex lands exactly on the point. Squaring
	## the half-angle is what pulls the shoulders in towards it: without that term this is
	## a circle, and with it the belly stays round while the top comes to a crisp tip.
	var built := PackedVector2Array()
	var steps := 20
	for index in steps:
		var t := TAU * float(index) / float(steps)
		built.append(Vector2(sin(t) * pow(sin(t * 0.5), 2.0), cos(t)))
	return built

static func _resample(base: PackedVector2Array, steps: int) -> PackedVector2Array:
	## Inserts vertices along each edge without moving the outline, so a higher Cut adds
	## facets to the same stone rather than rounding it into a different shape.
	if steps <= 1:
		return base
	var built := PackedVector2Array()
	var count := base.size()
	for index in count:
		var here := base[index]
		var following := base[(index + 1) % count]
		for step in steps:
			built.append(here.lerp(following, float(step) / float(steps)))
	return built

static func girdle(gem: Dictionary) -> PackedVector2Array:
	## The outline this stone was actually cut to, damage and all. `silhouette()` is the
	## shape it was meant to be; this is what its Cut left of it.
	var k: int = cut_rank(gem)
	return _miscut(_resample(silhouette(colour_key(gem)), EDGE_STEPS[k - 1]),
		float(CUT_WANDER[k - 1]), int(CUT_CHIPS[k - 1]), seed_of(gem))

static func _miscut(points: PackedVector2Array, wander: float, chips: int, seed_value: int) -> PackedVector2Array:
	## A poorly cut stone is the same stone, cut badly. Its girdle wanders in and out where
	## the wheel took too much, and its worst ranks have corners knocked clean off. Working
	## on the outline rather than on the facets means every band inherits the damage, so the
	## stone stays one solid instead of a true crown sitting on a broken pavilion.
	if wander <= 0.0 and chips <= 0:
		return points
	var count := points.size()
	var nicked: Dictionary = {}
	for index in chips:
		nicked[int(_hash01(seed_value + 419 + index) * float(count))] = true
	var built := PackedVector2Array()
	for index in count:
		# Biased slightly inward: a miscut stone has lost material, not gained it.
		var pull := 1.0 - wander * (_hash01(seed_value + 233 + index) - 0.32)
		if nicked.has(index):
			# A chip takes a real bite rather than a wobble, or it reads as noise.
			pull -= 0.11 + 0.10 * _hash01(seed_value + 601 + index)
		built.append(points[index] * maxf(pull, 0.34))
	return built

static func table_span(cut: int, shape: String) -> float:
	## How wide the flat top is. Cut decides it — a badly cut stone keeps a wide table —
	## and the shape scales that, because a rose cut barely has one.
	return TABLE_SPAN[clampi(cut, 1, 5) - 1] * float(SHAPE_TABLE.get(shape, 1.0))

static func _ring(base: PackedVector2Array, span: float, height: float, staggered: bool) -> PackedVector3Array:
	var built := PackedVector3Array()
	var count := base.size()
	for index in count:
		var point: Vector2 = base[index]
		if staggered:
			point = point.lerp(base[(index + 1) % count], 0.5)
		built.append(Vector3(point.x * span, point.y * span, height))
	return built

# --- geometry -----------------------------------------------------------------

static func _hash01(seed_value: int) -> float:
	var mixed := (seed_value * 1103515245 + 12345) & 0x7fffffff
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return float((mixed ^ (mixed >> 16)) & 0xffff) / 65535.0

static func _facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color) -> void:
	## One flat facet. Its own normal is what makes the stone catch light facet by facet
	## instead of shading like a smooth blob. Pass the corners so that (b-a) x (c-a) points
	## out of the solid; the reversed winding emitted below is what Godot calls front.
	var normal := (b - a).cross(c - a)
	if normal.length() < 0.000001:
		return
	normal = normal.normalized()
	for point in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(tone)
		surface.add_vertex(point)

static func build(gem: Dictionary) -> ArrayMesh:
	## The cut solid: table, crown, girdle, pavilion, culet.
	var color_key: String = colour_key(gem)
	var k: int = cut_rank(gem)
	var l: int = clarity_grade(gem)
	var seed_value: int = seed_of(gem)
	var base := girdle(gem)
	var count := base.size()
	var shape: String = str(CUTS.get(color_key, "round"))
	var crown: int = CROWN_BANDS[k - 1]
	var pavilion: int = PAVILION_BANDS[k - 1]
	var table_width: float = table_span(k, shape)
	var crown_height: float = CROWN_HEIGHT * float(CUT_CROWN[k - 1]) * float(SHAPE_CROWN.get(shape, 1.0))
	var pavilion_depth: float = PAVILION_DEPTH * float(CUT_DEPTH[k - 1]) * float(SHAPE_PAVILION.get(shape, 1.0))
	var body := body_colour_of(gem, l)
	var hue_spread := Tuning.value("facet_hue")

	# Which facets carry an inclusion. A Fractured stone has several, a Pristine one none.
	var flawed: Dictionary = {}
	for index in flaw_count(gem):
		flawed[int(_hash01(seed_value + 31 + index) * float(count * (crown + pavilion) * 2))] = true

	var rings: Array = []
	# Table down to the girdle.
	for band in range(crown + 1):
		var t := float(band) / float(crown)
		rings.append(_ring(base, lerpf(table_width, 1.0, t), lerpf(crown_height, 0.0, t),
			band % 2 == 1 and band < crown))
	# The girdle itself: a thin straight wall, so the widest point reads as an edge.
	rings.append(_ring(base, 1.0, -GIRDLE, false))
	# Girdle down towards the culet.
	for band in range(1, pavilion + 1):
		var t := float(band) / float(pavilion)
		rings.append(_ring(base, lerpf(1.0, 0.16, t), lerpf(-GIRDLE, -pavilion_depth, t),
			band % 2 == 1 and band < pavilion))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The table, as a fan from its own centre so it stays flat and single-toned.
	var table: PackedVector3Array = rings[0]
	var middle := Vector3(0.0, 0.0, crown_height)
	for index in count:
		_facet(surface, middle, table[index], table[(index + 1) % count], body.lightened(0.10))

	var facet := 0
	for band in range(rings.size() - 1):
		var upper: PackedVector3Array = rings[band]
		var lower: PackedVector3Array = rings[band + 1]
		for index in count:
			var a: Vector3 = upper[index]
			var b: Vector3 = upper[(index + 1) % count]
			var c: Vector3 = lower[(index + 1) % count]
			var d: Vector3 = lower[index]
			# Ordered so the facet normal points out of the stone. Wound the other way the
			# crown lights from inside and the outline shell lands in front of the body.
			for triangle in [[a, d, b], [b, d, c]]:
				var tone := body
				# Facets are cut, not moulded: some catch the light and some turn away
				# from it. A one-sided jitter only ever brightened them.
				var swing := (_hash01(seed_value + facet) - 0.5) * Tuning.value("facet_swing")
				tone = tone.lightened(swing) if swing >= 0.0 else tone.darkened(-swing)
				# The static half of the prism: no two facets return quite the same
				# colour, even before the fire pass sweeps over them.
				if hue_spread > 0.001:
					tone = Color.from_hsv(fposmod(tone.h
						+ (_hash01(seed_value + 977 + facet) - 0.5) * hue_spread, 1.0),
						tone.s, tone.v, tone.a)
				if flawed.has(facet):
					tone = tone.darkened(0.55)
				_facet(surface, triangle[0], triangle[1], triangle[2], tone)
				facet += 1
	# The culet, closing the pavilion to a point.
	var last: PackedVector3Array = rings[rings.size() - 1]
	var culet := Vector3(0.0, 0.0, -pavilion_depth)
	for index in count:
		_facet(surface, culet, last[(index + 1) % count], last[index], body.darkened(0.28))
	return surface.commit()

static func etch_plate(gem: Dictionary) -> ArrayMesh:
	## A flat panel carrying the skill's emblem, suspended inside the crown rather than laid
	## over the table. Sitting on the surface, the emblem had to be drawn with the depth test
	## off to be seen at all, and then parts of it floated clear of a face that had sloped
	## away underneath — the stone turned and the emblem did not follow it. Set into the
	## crystal it is behind real geometry, so it goes where the stone goes and reads as
	## something cut into the stone rather than printed on it.
	var color_key: String = colour_key(gem)
	var k: int = cut_rank(gem)
	var shape := str(CUTS.get(color_key, "round"))
	var inset := clampf(Tuning.value("etch_inset"), 0.0, 1.0)
	var crown_height: float = CROWN_HEIGHT * float(CUT_CROWN[k - 1]) * float(SHAPE_CROWN.get(shape, 1.0))
	# The crown narrows from the girdle up to the table, so the deeper the emblem is set the
	# more room it has. Its own size stays what it was; only the stone around it grows.
	var depth: float = crown_height * (1.0 - inset) + 0.004
	# The crown narrows from the girdle up to the table, so this is how wide the stone
	# actually is at the height the emblem sits at.
	var table: float = table_span(k, shape)
	var local: float = lerpf(table, 1.0, inset)
	var span: float = minf(clampf(table * 1.05, 0.42, 0.60),
		float(EMBLEM_SPAN.get(shape, 1.0)) * 0.5)
	# The plate is a slice of the stone at that height, not a square: a square one pushed its
	# corners out through the notch wherever a Poor cut had chipped one away, and the emblem
	# hung in the air outside the gem. Following the worn girdle means it cannot escape.
	var outline := girdle(gem)
	var count := outline.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in count:
		var here: Vector2 = outline[index] * local
		var following: Vector2 = outline[(index + 1) % count] * local
		for point: Vector2 in [Vector2.ZERO, following, here]:
			surface.set_normal(Vector3.BACK)
			# The emblem occupies a centred square of its own; the rest of the slice reads
			# the transparent border of the mask, so only the emblem is ever drawn.
			surface.set_uv(Vector2(point.x / (span * 2.0) + 0.5, 0.5 - point.y / (span * 2.0)))
			surface.add_vertex(Vector3(point.x, point.y, depth))
	return surface.commit()

# --- materials ----------------------------------------------------------------

static func transparency(clarity: int) -> float:
	## How much of the stone you see through. A Fractured gem is nearly solid; a Flawless
	## one is glass, and what you see through it is its own back facets.
	return lerpf(Tuning.value("near_alpha_dull"), Tuning.value("near_alpha_clear"), brilliance(clarity))

static func _stone_material(gem: Dictionary, interior: bool) -> StandardMaterial3D:
	var l: int = clarity_grade(gem)
	var b := brilliance(l)
	var body := body_colour_of(gem, l)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# The two passes are the whole illusion: the far side of the stone is drawn first,
	# then the near side over it. That is what a real gem shows you — its own pavilion,
	# seen through its crown — and no amount of shading on a single opaque hull gets there.
	material.cull_mode = BaseMaterial3D.CULL_FRONT if interior else BaseMaterial3D.CULL_BACK
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The near half writes depth so its own facets occlude each other and stay crisp; the
	# far half does not, so it shows through as one soft mass behind them. With depth off
	# on both, two hundred facets composited in arbitrary order and averaged to a blob.
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED if interior else BaseMaterial3D.DEPTH_DRAW_ALWAYS
	# Far half, then the emblem set inside the crown, then the near half over both, then
	# the fire on top of that. The emblem used to be last and outside the stone entirely.
	material.render_priority = 0 if interior else 2
	var alpha := transparency(l)
	if interior:
		# The far facets sit deeper in the stone, so they read darker, and a cloudy gem
		# hides them almost entirely.
		body = body.darkened(Tuning.value("far_darken"))
		alpha = lerpf(Tuning.value("far_alpha_dull"), Tuning.value("far_alpha_clear"), b)
	material.albedo_color = Color(body.r, body.g, body.b, alpha)
	# Clarity is the rest of the material story: a Fractured stone is rough, flat and
	# grey; a Flawless one is polished, lacquered and lit from within.
	material.roughness = lerpf(Tuning.value("roughness_dull"), Tuning.value("roughness_clear"), b)
	# A touch of metallic strengthens the sky reflection without reading as metal.
	material.metallic = lerpf(Tuning.value("metallic_dull"), Tuning.value("metallic_clear"), b)
	material.metallic_specular = lerpf(0.35, 1.0, b)
	material.rim_enabled = true
	material.rim = lerpf(Tuning.value("rim_dull"), Tuning.value("rim_clear"), b)
	material.rim_tint = 0.35
	var coat := Tuning.value("clearcoat")
	material.clearcoat_enabled = b > 0.24 and coat > 0.001
	material.clearcoat = lerpf(0.0, coat, b)
	material.clearcoat_roughness = 0.04
	material.emission_enabled = true
	material.emission = tint(gem)
	material.emission_energy_multiplier = lerpf(0.0, Tuning.value("emission_clear"), b) \
		* (Tuning.value("far_emission") if interior else 1.0)
	if not interior:
		# Screen-space refraction, so the near half bends what is behind it — which, thanks
		# to the render order above, is the stone's own far half. This needs Forward+; it
		# is a no-op on the Compatibility renderer. Clarity decides how much it bends.
		#
		# The catch is what "behind it" means. Godot's refraction branch composites the
		# screen behind the surface itself and then writes ALPHA = 1.0, so it can only ever
		# show what is inside this viewport, and it makes the stone opaque to everything
		# outside it. On a view with no ground that is fatal — the alpha values below stop
		# meaning anything. `GemView.set_ground()` is the answer: it moves the background
		# into the scene, and then refraction bends real content and alpha still counts.
		var bend := lerpf(0.0, Tuning.value("refraction"), b)
		material.refraction_enabled = bend > 0.001
		material.refraction_scale = bend
		material.refraction_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	return material

static func body_material(gem: Dictionary) -> StandardMaterial3D:
	## The near half of the stone.
	return _stone_material(gem, false)

static func interior_material(gem: Dictionary) -> StandardMaterial3D:
	## The far half, drawn first and seen through the near half.
	return _stone_material(gem, true)

static func fire_material(gem: Dictionary) -> ShaderMaterial:
	## The moving half of the prism, laid over the near pass as `material_overlay` so it
	## rides the same geometry without a second mesh to keep in step with it.
	if _fire == null:
		_fire = Shader.new()
		_fire.code = FIRE_SHADER
	var b := brilliance(clarity_grade(gem))
	var tint := tint(gem)
	var material := ShaderMaterial.new()
	material.shader = _fire
	# A cloudy stone scatters light rather than splitting it, so Clarity owns the fire too.
	material.set_shader_parameter("fire", Tuning.value("fire") * b)
	material.set_shader_parameter("bands", Tuning.value("fire_bands"))
	material.set_shader_parameter("spread", Tuning.value("fire_spread"))
	material.set_shader_parameter("reach", Tuning.value("fire_reach"))
	material.set_shader_parameter("sharpness", Tuning.value("fire_sharpness"))
	material.set_shader_parameter("tint",
		Vector3.ONE.lerp(Vector3(tint.r, tint.g, tint.b), Tuning.value("fire_tint")))
	material.render_priority = 3
	return material

static func etch_material(gem: Dictionary) -> StandardMaterial3D:
	var l: int = clarity_grade(gem)
	var body := body_colour_of(gem, l)
	var emblem := emblem_of(gem)
	# The emblem names the skill, so it has to read at every rank — and a cloudy stone is
	# nearly solid, letting only a fraction of what is set inside it through. Clarity is
	# allowed to change how the emblem looks, but never whether it can be found: as the
	# stone murks up, the emblem takes on the shade and opacity it needs to come back.
	var b := brilliance(l)
	var murk: float = Tuning.value("etch_murk") * (1.0 - b)
	var shade: float = Tuning.value("etch_darken")
	var ink: float = clampf(Tuning.value("etch_alpha") + murk * 0.4, 0.0, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _etch_albedo(emblem, body, shade, ink)
	material.normal_enabled = true
	material.normal_texture = _etch_normal(emblem)
	material.texture_repeat = false
	material.normal_scale = Tuning.value("etch_depth")
	# What makes the emblem readable is that its relief catches the light, and a cloudy
	# stone lets almost none of that back out. Darkening it only made it vanish faster into
	# a dark stone, so instead it lights itself by as much as the murk takes away. Alpha is
	# zero everywhere but the emblem, so nothing else on the plate glows.
	material.emission_enabled = murk > 0.001
	material.emission = body.lightened(0.55)
	material.emission_energy_multiplier = murk * 1.6
	# A groove is not polished. Left specular it caught a broad highlight and read as a
	# bright inlay sitting on the stone rather than a cut into it.
	material.roughness = Tuning.value("etch_roughness")
	material.metallic_specular = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# Still no depth test — it is inside the solid, so the near half's depth would reject
	# it — but it is now drawn BEFORE the near half, which is what puts it inside.
	material.no_depth_test = true
	material.render_priority = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _blurred(mask: Image) -> PackedFloat32Array:
	## The emblem softened into a height field, so its walls slope instead of stepping.
	var span := mask.get_width()
	var height := PackedFloat32Array()
	height.resize(span * span)
	for y in span:
		for x in span:
			height[y * span + x] = mask.get_pixel(x, y).a
	for _pass in 3:
		var next := height.duplicate()
		for y in span:
			for x in span:
				var total := 0.0
				var taken := 0
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						var px: int = x + dx
						var py: int = y + dy
						if px < 0 or py < 0 or px >= span or py >= span:
							continue
						total += height[py * span + px]
						taken += 1
				next[y * span + x] = total / float(taken)
		height = next
	return height

static func _etch_normal(emblem: String) -> ImageTexture:
	var cached: ImageTexture = _normals.get(emblem, null)
	if cached != null:
		return cached
	var mask: Image = GemIcons.texture(emblem, ETCH_PIXELS).get_image()
	mask.convert(Image.FORMAT_RGBA8)
	var span := mask.get_width()
	var height := _blurred(mask)
	var built := Image.create(span, span, false, Image.FORMAT_RGBA8)
	for y in span:
		for x in span:
			var left: float = height[y * span + maxi(x - 1, 0)]
			var right: float = height[y * span + mini(x + 1, span - 1)]
			var up: float = height[maxi(y - 1, 0) * span + x]
			var down: float = height[mini(y + 1, span - 1) * span + x]
			# The emblem is cut into the face, so the surface falls where the mask rises.
			var normal := Vector3(right - left, down - up, 0.55).normalized()
			built.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	var texture := ImageTexture.create_from_image(built)
	_normals[emblem] = texture
	return texture

static func _etch_albedo(emblem: String, body: Color, shade: float, ink: float) -> ImageTexture:
	# Shade and opacity are part of the key: two etches cut to different depths into two
	# differently coloured stones are two textures, and both vary with Clarity.
	var tag := "%s|%s|%.3f|%.3f" % [emblem, body.to_html(false), shade, ink]
	var cached: ImageTexture = _faces.get(tag, null)
	if cached != null:
		return cached
	var mask: Image = GemIcons.texture(emblem, ETCH_PIXELS).get_image()
	mask.convert(Image.FORMAT_RGBA8)
	var span := mask.get_width()
	# The groove faces the key light square on while the stone around it is all angled
	# facets, so a merely darker tone lights back up to a pale tint. It has to start far
	# darker than the body to read as a recess once the light is on it.
	var floor_tone := body.darkened(shade)
	var built := Image.create(span, span, false, Image.FORMAT_RGBA8)
	for y in span:
		for x in span:
			var alpha := mask.get_pixel(x, y).a
			built.set_pixel(x, y, Color(floor_tone.r, floor_tone.g, floor_tone.b, alpha * ink))
	var texture := ImageTexture.create_from_image(built)
	_faces[tag] = texture
	return texture

# --- words --------------------------------------------------------------------

static func describe(gem: Dictionary) -> String:
	## What the stone is saying, in words, so the visual language can be learned.
	var color_key: String = colour_key(gem)
	var c: int = clampi(int(gem.get("carat", 1)), 1, DeepStone.carat_max())
	var k: int = cut_rank(gem)
	var l: int = clarity_grade(gem)
	var size: String = ["tiny", "small", "middling", "large", "huge"][clampi((c - 1) / 4, 0, 4)]
	var lustre: String = ["milky, riddled with what is frozen inside it", "veined, with flaws you can see",
		"clear but for one flaw", "clear", "bright and clean", "blazing"][l]
	var shape: String = str(CUTS.get(color_key, "round"))
	return "A %s %s-cut %s stone, %s, %s. %s, %s, %d carats. Drag to turn it." % [
		size, str(SHAPE_NAMES.get(shape, shape)),
		str(DeepContent.colour(color_key).get("name", "Red")).to_lower(),
		cut_note(k), lustre, DeepContent.cut_name(k - 1), DeepContent.clarity_name(l), c]

static func cut_note(cut: int) -> String:
	## What the rank did to the solid, in the words someone would use looking at it.
	return ["squat and chipped", "shallow, with a nicked girdle",
		"a little off true, with one nicked corner", "cleanly cut, barely off true",
		"cut true, with a crisp girdle"][clampi(cut, 1, 5) - 1]

static func release() -> void:
	_normals.clear()
	_faces.clear()
	_fire = null
