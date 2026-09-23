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
## What is set INSIDE the solid rather than cut on it: the inclusions the stone carries,
## each class drawn as its own thing, and the vein of color an opal Seam is named for. It
## is handed an `envelope()` and so never has to preload this file back.
const GemFlaws = preload("res://view/gems/gem_flaws.gd")
## Every material and lighting number lives in one adjustable table, so the gem lab can
## move any of them and see the stone answer. Untouched it hands back the shipped values.
const Tuning = preload("res://view/gems/gem_tuning.gd")

## How clear each grade of the clarity ladder reads, Intricate to Flawless. The centre of the
## ladder is an honest, ordinary stone; the pure tail is glass and the included tail is milk.
const BRILLIANCE: Array = [0.0, 0.16, 0.36, 0.60, 0.84, 1.0]
## Fallback hues if the pack has none.
const FALLBACK_HUES: Dictionary = {"RED": "e0473c", "BLUE": "3f7fe0", "GREEN": "3fb56b", "VIOLET": "8b5fd6", "GOLD": "e2b23a", "WHITE": "e8eef5",
	"OPAL": "eceaf6"}

# --- reading a stone -----------------------------------------------------------

static func skill_key(gem: Dictionary) -> String:
	return str(gem.get("skill", gem.get("key", "")))

## A Birthstone names a cut of its own, and now wears it. Each of these is a solid built
## here and nowhere else — no Birthstone borrows one of the six outlines any more, because
## borrowing is what made Ardor read as an ordinary red gem and Cadence as a Blue.
const STYLE_SHAPES: Dictionary = {"shield": "shield", "marquise": "marquise", "step": "step",
	"briolette": "briolette", "checkerboard": "checkerboard", "heptagon": "heptagon"}
## Which of the six a Birthstone stands nearest to. This decides nothing anyone can see:
## every Birthstone names its own hue and its own words, so it is only what the hue would
## fall back on if one ever did not.
const STYLE_KIN: Dictionary = {"shield": "RED", "marquise": "WHITE", "step": "VIOLET",
	"briolette": "GREEN", "checkerboard": "RED", "heptagon": "GOLD"}
## Socket fit is a visual choice, independent of the Birthstones' 24-carat weight.
const STYLE_SCALE := {"shield": 0.90, "step": 0.85, "briolette": 0.95,
	"checkerboard": 0.70, "heptagon": 0.70}
const STYLE_OFFSET := {"shield": Vector3(0.0, -0.08, 0.0)}

static func shape_of(gem: Dictionary) -> String:
	## The solid this stone is cut to. A Birthstone's style names it outright; everything
	## else takes the one its Color wears.
	var style: String = str(gem.get("style", ""))
	if STYLE_SHAPES.has(style):
		return str(STYLE_SHAPES[style])
	return str(CUTS.get(color_key(gem), "round"))

static func color_key(gem: Dictionary) -> String:
	var style: String = str(gem.get("style", ""))
	if STYLE_KIN.has(style):
		return str(STYLE_KIN[style])
	var explicit: String = str(gem.get("color", ""))
	if explicit in FALLBACK_HUES:
		return explicit
	var found: String = str(DeepContent.skill(skill_key(gem)).get("color", ""))
	return found if found in FALLBACK_HUES else "RED"

static func hue(color_key: String) -> Color:
	return Color(str(DeepContent.color(color_key).get("hue", FALLBACK_HUES.get(color_key, "e0473c"))))

static func tint2(gem: Dictionary) -> Color:
	## A second hue blended through the body. Transparent when the stone names none.
	var other: String = str(gem.get("hue2", ""))
	return Color(other) if other.is_valid_html_color() else Color(0, 0, 0, 0)

static func tint(gem: Dictionary) -> Color:
	## The stone's own hue: a Birthstone carries one, every other stone takes its color's —
	## unless its skill names a wash of its own. That last is for the opals: they are all
	## one color, which is no color, and the six Seams are told apart by the color each one
	## plays back showing faintly through the body.
	var own: String = str(gem.get("hue", ""))
	if not own.is_empty() and own.is_valid_html_color():
		return Color(own)
	var washed: String = str(DeepContent.skill(skill_key(gem)).get("hue", ""))
	if not washed.is_empty() and washed.is_valid_html_color():
		return Color(washed)
	return hue(color_key(gem))

static func body_color_of(gem: Dictionary, clarity: int) -> Color:
	return _body_color(tint(gem), clarity)

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
## survives greyscale, color blindness and a 32-pixel thumbnail.
const CUTS := {"RED": "trilliant", "BLUE": "princess", "GREEN": "heart",
	"VIOLET": "pear", "GOLD": "dutch_rose", "WHITE": "round", "OPAL": "cabochon"}
## What each cut is called in a sentence. The keys are identifiers; these are the words.
const SHAPE_NAMES := {"trilliant": "trilliant", "princess": "princess", "heart": "heart",
	"pear": "pear", "dutch_rose": "half Dutch rose", "round": "round brilliant", "cabochon": "cabochon",
	"shield": "shield", "marquise": "marquise", "step": "emerald", "briolette": "briolette",
	"checkerboard": "checkerboard", "heptagon": "heptagon"}
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
## still read as the same shape as a Perfect one, because color is carried by the outline.
## The first pass at these ran about 40% harder and turned a Poor trilliant into a shard.
const CUT_WANDER := [0.16, 0.10, 0.05, 0.04, 0.00]
const CUT_CHIPS := [3, 2, 1, 0, 0]
## Poor cuts are shallow: a low crown over a shallow pavilion, so the stone reads as flat.
const CUT_CROWN := [0.55, 0.70, 0.84, 0.93, 1.00]
const CUT_DEPTH := [0.72, 0.82, 0.90, 0.96, 1.00]
## How the etched emblem is sized against the stone's reach, per outline. A pear is
## narrow at the point and a princess is square, so one number cannot serve both.
const EMBLEM_SPAN := {"trilliant": 0.86, "princess": 1.10, "heart": 0.94,
	"pear": 0.84, "dutch_rose": 1.04, "round": 1.06, "cabochon": 0.96,
	"shield": 0.92, "marquise": 0.62, "step": 0.96, "briolette": 0.66,
	"checkerboard": 1.04, "heptagon": 1.00}
## Move the engraving within its slice, towards the broad part of an asymmetric face.
const EMBLEM_OFFSET := {"shield": Vector2(0.0, 0.12), "briolette": Vector2(0.0, -0.23),
	"pear": Vector2(0.0, -0.13)}
## Two of the cuts are not brilliants, and a brilliant's proportions would make them lie.
## A rose cut has no table worth the name: its crown is a dome of facets rising to a point,
## and its back is left flat, because the whole cut exists to save weight. These scale the
## table, the crown and the pavilion the rest of the file works out from Cut, so the rank
## still says how TRUE the stone was cut — it just says it about a different solid.
##
## The Birthstone cuts lean on the same three. An emerald cut is a shallow crown over a
## broad table; a briolette keeps a long drop outline over a shallow body; a checkerboard
## domes its crown the way a cabochon does but keeps its facets.
const SHAPE_TABLE := {"dutch_rose": 0.30, "cabochon": 0.0,
	"step": 0.86, "briolette": 1.12, "pear": 1.08, "checkerboard": 0.44, "shield": 0.92, "marquise": 0.80, "heptagon": 1.02}
const SHAPE_CROWN := {"dutch_rose": 1.25, "cabochon": 1.55,
	"step": 0.72, "briolette": 0.90, "pear": 0.90, "checkerboard": 1.30, "shield": 0.88, "marquise": 0.80, "heptagon": 0.78}
const SHAPE_PAVILION := {"dutch_rose": 0.40, "cabochon": 0.22,
	"step": 1.02, "briolette": 0.48, "pear": 0.72, "checkerboard": 0.66, "shield": 1.06, "heptagon": 0.74}
## A marquise has the same shallow face on either side of its girdle.
const SHAPE_SYMMETRIC := ["marquise"]
## How many bands of facets the crown is built from, where the shape overrules Cut. A step
## cut is nothing but bands — that is what the name means — and a checkerboard needs enough
## of them for its grid to be a grid.
const SHAPE_BANDS := {"step": 3, "checkerboard": 3}
## Shapes whose bands are laid concentrically instead of staggered half a step. The stagger
## is what makes a brilliant sparkle, facet meeting facet point to edge; a step cut is the
## opposite idea, a staircase of parallel tiers, and a checkerboard wants its grid square.
const SHAPE_STEPPED := ["step", "checkerboard"]
## Metal grown into the stone rather than cut on it. Pyrite is fool's gold and comes out of
## the rock in leaves, so a stone cut from that matrix carries them: not a flaw, the whole
## reason to cut it. See `gem_flaws.gd`, which draws them with what is frozen inside.
## Pyrite comes out of the rock in leaves of fool's gold; a black opal throws the pinprick
## flashes it is prized for. Both are specks of light caught in a body rather than cut on
## one. The pyrite also reflects the lamps from its smaller, evenly spaced plates.
const SHAPE_FLAKES := {"heptagon": 36, "marquise": 44}
const SHAPE_FLAKE_TONE := {"heptagon": "ffd166", "marquise": "cfe8ff"}
## How large each one is cut. A leaf of pyrite is something you can see the shape of; an
## opal's flash is a pinprick, and at anything near the same size it read as confetti.
const SHAPE_FLAKE_SIZE := {"heptagon": 0.60, "marquise": 0.22}
const FLAKE_TONE := "ffd166"
## The cabochon is the one cut in the game with no facets at all: an opal's color lives in
## its body rather than in the light a facet throws back, and a real cutter domes it for
## exactly that reason — faceting would chop the play-of-color into pieces. So it is cut
## here too: a smooth dome walked round a quarter circle in this many bands, shaded off one
## curved surface instead of a hundred flat ones, over a shallow flat back. The value is
## how many bands the dome is built from; any shape not listed is a brilliant as before.
const SHAPE_DOME := {"cabochon": 6}

## The prism, as a pass laid over the near half. A cut stone splits white light because
## its refractive index differs by wavelength, so each facet returns a different color and
## the colors sweep as the stone turns. Doing that honestly would mean tracing several
## wavelengths through the solid; this reads the same and costs one additive pass.
##
## Everything is in view space, which is what makes it work under an orthogonal camera:
## `VIEW` is constant there, so the whole effect is driven by each facet's own normal, and
## turning the stone is what moves the colors.
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

## How big each size class is drawn, Tiny to Huge. A stone nobody has read is drawn at its
## class, and the classes are set well apart: the carat curve is gentle through the middle
## of its range, which is right for a stone whose weight is written under it and useless for
## one whose only clue is how big it looks. Across a counter Tiny has to read as tiny.
const CLASS_SPAN: Array = [0.55, 0.78, 1.02, 1.28, 1.62]

static func span(gem: Dictionary) -> float:
	## How wide the stone is drawn against its slot: its class if nobody has read it, its own
	## carat once somebody has.
	if gem.has("appraised") and not bool(gem.appraised):
		return float(CLASS_SPAN[clampi(int(DeepStone.size_class(int(gem.get("carat", 1))).index), 0, CLASS_SPAN.size() - 1)])
	return carat_span(int(gem.get("carat", 1))) * float(STYLE_SCALE.get(str(gem.get("style", "")), 1.0))

static func display_offset(gem: Dictionary) -> Vector3:
	return STYLE_OFFSET.get(str(gem.get("style", "")), Vector3.ZERO)

static func frame_for(gem: Dictionary) -> float:
	## The same for the reach the view has to draw into.
	return maxf(1.0, span(gem))

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
	## A cabochon has none, and saying so is half of what tells an opal apart.
	var shape := str(CUTS.get(color_key, "round"))
	if SHAPE_DOME.has(shape):
		return 0
	var k: int = clampi(cut, 1, 5)
	var around: int = outline(shape).size() * EDGE_STEPS[k - 1]
	# Two triangles per segment per band, above and below, plus the pavilion's fan.
	return around * 2 * (CROWN_BANDS[k - 1] + PAVILION_BANDS[k - 1]) + around

static func body_color(color_key: String, clarity: int) -> Color:
	return _body_color(hue(color_key), clarity)

static func _body_color(base: Color, clarity: int) -> Color:
	## A dull stone is not just darker: it is greyer. Clarity pulls the hue back towards
	## stone as it falls, which is what makes a Fractured gem look cloudy.
	var b := brilliance(clarity)
	return base.lerp(Color("6d7280"), lerpf(Tuning.value("grey_pull"), 0.0, b)).lerp(Color.BLACK, lerpf(0.18, 0.0, b))

# --- outlines -----------------------------------------------------------------

static func silhouette(color_key: String) -> PackedVector2Array:
	## The outline one of the six Colors is cut to.
	return outline(str(CUTS.get(color_key, "round")))

static func outline(shape: String) -> PackedVector2Array:
	## Unit space, centred on the origin, longest reach 1.0, always wound the same way.
	match shape:
		"trilliant":
			return _wound(_truncated(_regular(3, -PI * 0.5), 0.17))
		"princess":
			return _wound(_truncated(_regular(4, PI * 0.25), 0.20))
		"heart":
			return _wound(_heart())
		"pear":
			# A pointed pear, still broader through the shoulders than Rue's long drop.
			return _wound(_pear(1.55))
		"shield":
			# A heraldic shield: a straight top edge, shoulders that carry the width down,
			# and two long curves closing to a point. It has to say shield at a thumbnail,
			# so the top is flat and wide and everything below it narrows without pause.
			return _wound(_unit(PackedVector2Array([
				Vector2(-0.82, 1.00), Vector2(0.82, 1.00), Vector2(0.88, 0.52), Vector2(0.86, 0.14),
				Vector2(0.74, -0.26), Vector2(0.52, -0.62), Vector2(0.27, -0.87), Vector2(0.00, -1.00),
				Vector2(-0.27, -0.87), Vector2(-0.52, -0.62), Vector2(-0.74, -0.26), Vector2(-0.86, 0.14),
				Vector2(-0.88, 0.52)])))
		"marquise":
			# A navette: two circular arcs meeting in a point at each end. Built from real
			# arcs rather than a squashed ellipse, because an ellipse has rounded ends and
			# the points are the whole cut.
			return _wound(_marquise(24, 0.40))
		"step":
			# An emerald cut's girdle: a rectangle with its corners taken off. What makes
			# it a step cut is not the outline but the bands above and below it, which is
			# what `SHAPE_BANDS` and `SHAPE_STEPPED` are for.
			return _wound(_unit(_truncated(PackedVector2Array([
				Vector2(0.74, 1.0), Vector2(0.74, -1.0), Vector2(-0.74, -1.0), Vector2(-0.74, 1.0)]), 0.24)))
		"briolette":
			# The long taper distinguishes the drop, while a broad table carries its icon.
			return _wound(_pear(2.8))
		"checkerboard":
			# A cushion: a square with its sides bowed out, which is the outline a
			# checkerboard is cut on. Round enough not to read as a princess, square
			# enough that the grid of facets over it has corners to sit in.
			return _wound(_unit(_cushion(28, 3.1, 0.94)))
		"heptagon":
			# Seven sides. Pyrite grows in the rock as cubes and pyritohedra, and no
			# faceted stone in the game has an odd number of sides, so a heptagon reads as
			# something grown rather than something cut — which is the joke about fool's
			# gold. The slight truncation keeps its corners from chipping into nothing at
			# the low Cut ranks.
			return _wound(_truncated(_regular(7, -PI * 0.5), 0.10))
		"dutch_rose":
			# A rose cut's girdle is a hexagon, and six segments over one crown band is
			# exactly the twelve-facet dome the cut is named for.
			return _wound(_regular(6, -PI * 0.5))
		"cabochon":
			# An oval, the outline every opal is cut to. Round enough to be no shape at
			# all, which is the point: an opal is not one of the six, and the eye should
			# not go looking for the round brilliant White wears.
			return _wound(_oval(24, 0.76))
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

static func _unit(points: PackedVector2Array) -> PackedVector2Array:
	## Scales a hand-written outline so its longest reach is exactly 1.0, which is what
	## every table in this file measures against.
	var peak := 0.0
	for point in points:
		peak = maxf(peak, point.length())
	if peak < 0.000001:
		return points
	var built := PackedVector2Array()
	for point in points:
		built.append(point / peak)
	return built

static func _marquise(steps: int, waist: float) -> PackedVector2Array:
	## Two circular arcs through the tips at the poles and the widest point at the equator.
	## One circle is found from those three points and the other is its mirror.
	var centre: float = (waist * waist - 1.0) / (2.0 * waist)
	var radius: float = absf(waist - centre)
	var sweep: float = atan2(1.0, -centre)
	var built := PackedVector2Array()
	var half: int = maxi(3, steps / 2)
	for index in half + 1:
		var angle := lerpf(-sweep, sweep, float(index) / float(half))
		built.append(Vector2(centre + cos(angle) * radius, sin(angle) * radius))
	for index in range(half - 1, 0, -1):
		var angle := lerpf(-sweep, sweep, float(index) / float(half))
		built.append(Vector2(-(centre + cos(angle) * radius), sin(angle) * radius))
	return built

static func _cushion(steps: int, squareness: float, waist: float) -> PackedVector2Array:
	## A superellipse: two at a circle, high at a square, and between them the bowed square
	## a cushion cut is ground to.
	var power := 2.0 / maxf(squareness, 0.5)
	var built := PackedVector2Array()
	for index in steps:
		var angle := -PI * 0.5 + TAU * float(index) / float(steps)
		built.append(Vector2(signf(cos(angle)) * pow(absf(cos(angle)), power) * waist,
			signf(sin(angle)) * pow(absf(sin(angle)), power)))
	return built

static func _oval(steps: int, waist: float) -> PackedVector2Array:
	var built := PackedVector2Array()
	for index in steps:
		var angle := -PI * 0.5 + TAU * float(index) / float(steps)
		built.append(Vector2(cos(angle) * waist, sin(angle)))
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

static func _pear(taper: float) -> PackedVector2Array:
	## The teardrop curve, sampled so the first vertex lands exactly on the point. Raising
	## the half-angle to a power is what pulls the shoulders in towards it: without that
	## term this is a circle, and with it the belly stays round while the top comes to a
	## tip. `taper` is how sharp that tip is — near one it is a broad pear, and high it is
	## the long drop a briolette is cut to.
	var built := PackedVector2Array()
	var steps := 20
	for index in steps:
		var t := TAU * float(index) / float(steps)
		built.append(Vector2(sin(t) * pow(sin(t * 0.5), taper), cos(t)))
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
	return _miscut(_resample(outline(shape_of(gem)), EDGE_STEPS[k - 1]),
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

static func _facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tone: Color, dome: float = 0.0) -> void:
	## One flat facet. Its own normal is what makes the stone catch light facet by facet
	## instead of shading like a smooth blob. Pass the corners so that (b-a) x (c-a) points
	## out of the solid; the reversed winding emitted below is what Godot calls front.
	##
	## `dome` is the one exception, and it is the height of the dome the corners sit on: a
	## cabochon wants the blob. Each corner then carries the normal of the surface it lies
	## on rather than of the triangle it belongs to, so the whole top shades as one curve
	## and the fire pass sweeps over it in patches instead of breaking on every edge.
	var normal := (b - a).cross(c - a)
	if normal.length() < 0.000001:
		return
	normal = normal.normalized()
	for point in [a, c, b]:
		surface.set_normal(Vector3(point.x, point.y, point.z / (dome * dome)).normalized() if dome > 0.0 and point.z > 0.0 else normal)
		surface.set_color(tone)
		# Object-space color coordinates stay continuous across every facet and both faces.
		surface.set_uv(Vector2(point.x * 0.5 + 0.5, 0.5 - point.y * 0.5))
		surface.add_vertex(point)

static func build(gem: Dictionary) -> ArrayMesh:
	## The cut solid: table, crown, girdle, pavilion, culet.
	var k: int = cut_rank(gem)
	var l: int = clarity_grade(gem)
	var seed_value: int = seed_of(gem)
	var env := envelope(gem)
	var base: PackedVector2Array = env.outline
	var count := base.size()
	var shape: String = shape_of(gem)
	## A cabochon is not a cut solid at all: no table, no crown facets, just a dome walked
	## round a quarter circle over a shallow back.
	var domed: bool = SHAPE_DOME.has(shape)
	var crown: int = int(SHAPE_DOME[shape]) if domed else int(SHAPE_BANDS.get(shape, CROWN_BANDS[k - 1]))
	var pavilion: int = PAVILION_BANDS[k - 1] + (1 if SHAPE_STEPPED.has(shape) else 0)
	if SHAPE_SYMMETRIC.has(shape):
		pavilion = crown
	## A staircase of parallel tiers, or a brilliant's facets meeting point to edge. This
	## is the whole difference between an emerald cut and everything else in the game.
	var stepped: bool = SHAPE_STEPPED.has(shape)
	var table_width: float = table_span(k, shape)
	var crown_height: float = float(env.crown)
	var pavilion_depth: float = float(env.depth)
	# Two-color stones get their hue from a continuous texture, leaving vertex colors
	# free to carry the same facet lighting and flaws as every other stone.
	var body := Color.WHITE if tint2(gem).a > 0.0 else body_color_of(gem, l)
	var hue_spread := Tuning.value("facet_hue")

	# Where a flaw reaches the surface. A Fractured stone has several, a Pristine one none.
	# This used to be the whole of what an inclusion looked like, which made every class
	# of them identical; the thing itself is now cut inside the stone by `gem_flaws.gd`,
	# and what is left here is the smudge it leaves on the facet above it.
	var flawed: Dictionary = {}
	for index in flaw_count(gem):
		flawed[int(_hash01(seed_value + 31 + index) * float(count * (crown + pavilion) * 2))] = true

	var rings: Array = []
	# Table down to the girdle, or, for a cabochon, the apex down to it on a quarter circle.
	for band in range(crown + 1):
		var t := float(band) / float(crown)
		if domed:
			var turn := t * PI * 0.5
			rings.append(_ring(base, sin(turn), crown_height * cos(turn), false))
		else:
			rings.append(_ring(base, lerpf(table_width, 1.0, t), lerpf(crown_height, 0.0, t),
				not stepped and band % 2 == 1 and band < crown))
	# The girdle itself: a thin straight wall, so the widest point reads as an edge.
	rings.append(_ring(base, 1.0, -GIRDLE, false))
	# Girdle down towards the culet.
	for band in range(1, pavilion + 1):
		var t := float(band) / float(pavilion)
		rings.append(_ring(base, lerpf(1.0, float(env.back_table), t), lerpf(-GIRDLE, -pavilion_depth, t),
			not stepped and band % 2 == 1 and band < pavilion))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The table, as a fan from its own centre so it stays flat and single-toned.
	var table: PackedVector3Array = rings[0]
	var middle := Vector3(0.0, 0.0, crown_height)
	if not domed:
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
			# The dome above the girdle shades as one surface; everything below it, and every
			# band of a brilliant, is a facet in its own right.
			var smooth: float = crown_height if domed and band < crown else 0.0
			for triangle in [[a, d, b], [b, d, c]]:
				var tone := body
				# Facets are cut, not moulded: some catch the light and some turn away
				# from it. A one-sided jitter only ever brightened them. A dome has none
				# to jitter, and jittering it anyway only banded the curve.
				if smooth <= 0.0:
					var swing := (_hash01(seed_value + facet) - 0.5) * Tuning.value("facet_swing")
					tone = tone.lightened(swing) if swing >= 0.0 else tone.darkened(-swing)
					# The static half of the prism: no two facets return quite the same
					# color, even before the fire pass sweeps over them.
					if hue_spread > 0.001:
						tone = Color.from_hsv(fposmod(tone.h
							+ (_hash01(seed_value + 977 + facet) - 0.5) * hue_spread, 1.0),
							tone.s, tone.v, tone.a)
				if flawed.has(facet):
					tone = tone.darkened(Tuning.value("flaw_facet"))
				_facet(surface, triangle[0], triangle[1], triangle[2], tone, smooth)
				facet += 1
	# The culet, closing the pavilion to a point.
	var last: PackedVector3Array = rings[rings.size() - 1]
	var culet := Vector3(0.0, 0.0, -pavilion_depth)
	for index in count:
		_facet(surface, culet, last[(index + 1) % count], last[index], body.darkened(0.28))
	return surface.commit()

static func envelope(gem: Dictionary) -> Dictionary:
	## The room inside this stone, as the handful of numbers it takes to stay in there: the
	## outline it was cut to, how far it rises above the girdle and falls below it, and how
	## it narrows at each end. `gem_flaws.gd` places everything it sets inside the crystal
	## against this, which is why it never has to know how a stone is cut.
	var k: int = cut_rank(gem)
	var shape := shape_of(gem)
	var domed: bool = SHAPE_DOME.has(shape)
	var crown: float = CROWN_HEIGHT * float(CUT_CROWN[k - 1]) * float(SHAPE_CROWN.get(shape, 1.0))
	var symmetric: bool = SHAPE_SYMMETRIC.has(shape)
	return {
		"outline": girdle(gem),
		"crown": crown,
		"depth": crown + GIRDLE if symmetric else PAVILION_DEPTH * float(CUT_DEPTH[k - 1]) * float(SHAPE_PAVILION.get(shape, 1.0)),
		"girdle": GIRDLE,
		"table": table_span(k, shape),
		"back_table": table_span(k, shape) if symmetric else 0.16,
		"domed": domed,
		"seed": seed_of(gem),
		"flaws": flaw_count(gem),
		"flakes": int(SHAPE_FLAKES.get(shape, 0)),
		"flake_tone": str(SHAPE_FLAKE_TONE.get(shape, FLAKE_TONE)),
		"flake_size": float(SHAPE_FLAKE_SIZE.get(shape, 1.0)),
		"even_flakes": shape == "heptagon",
		"murk": 1.0 - brilliance(clarity_grade(gem))}

static func inside(gem: Dictionary) -> ArrayMesh:
	## What is frozen in the stone: its inclusions, each drawn as its own class, and an
	## opal Seam's vein. Null when the crystal is clean, which most of them are.
	return GemFlaws.build(gem, envelope(gem))

static func etch_plate(gem: Dictionary) -> ArrayMesh:
	## A flat panel carrying the skill's emblem, suspended inside the crown rather than laid
	## over the table. Sitting on the surface, the emblem had to be drawn with the depth test
	## off to be seen at all, and then parts of it floated clear of a face that had sloped
	## away underneath — the stone turned and the emblem did not follow it. Set into the
	## crystal it is behind real geometry, so it goes where the stone goes and reads as
	## something cut into the stone rather than printed on it.
	var k: int = cut_rank(gem)
	var shape := shape_of(gem)
	var inset := clampf(Tuning.value("etch_inset"), 0.0, 1.0)
	## A cabochon has no table to set an emblem under, only dome, and the deeper it sits
	## the more milky body and more play-of-color lie over it. Set higher in the dome it
	## still reads as something frozen inside the stone and can still be found.
	if SHAPE_DOME.has(shape):
		inset = minf(inset, 0.55)
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
	var offset: Vector2 = EMBLEM_OFFSET.get(shape, Vector2.ZERO)
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
			# The emblem occupies an offset square of its own; the rest of the slice reads
			# the transparent border of the mask, so only the emblem is ever drawn.
			var ink_point: Vector2 = point - offset
			surface.set_uv(Vector2(ink_point.x / (span * 2.0) + 0.5, 0.5 - ink_point.y / (span * 2.0)))
			surface.add_vertex(Vector3(point.x, point.y, depth))
	return surface.commit()

# --- materials ----------------------------------------------------------------

static func transparency(clarity: int) -> float:
	## How much of the stone you see through. A Fractured gem is nearly solid; a Flawless
	## one is glass, and what you see through it is its own back facets.
	return lerpf(Tuning.value("near_alpha_dull"), Tuning.value("near_alpha_clear"), brilliance(clarity))

static func _color_gradient(gem: Dictionary) -> GradientTexture2D:
	var clarity := clarity_grade(gem)
	var first := body_color_of(gem, clarity)
	var second := first.lerp(_body_color(tint2(gem), clarity), clampf(Tuning.value("rind_alpha"), 0.0, 1.0))
	var gradient := Gradient.new()
	gradient.set_color(0, first)
	gradient.set_color(1, second)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill_from = Vector2(0.20, 0.32)
	texture.fill_to = Vector2(0.80, 0.68)
	return texture

static func _stone_material(gem: Dictionary, interior: bool) -> StandardMaterial3D:
	var l: int = clarity_grade(gem)
	var b := brilliance(l)
	var body := body_color_of(gem, l)
	var two_colors: bool = tint2(gem).a > 0.0
	if two_colors:
		body = Color.WHITE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	if two_colors:
		material.albedo_texture = _color_gradient(gem)
		material.texture_repeat = false
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
	material.emission = Color.WHITE if two_colors else tint(gem)
	if two_colors:
		material.emission_texture = material.albedo_texture
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

static func solid(gem: Dictionary) -> Node3D:
	## A stone as a thing standing in a room: its far half, its near half drawn over that,
	## and the fire riding the near one — the same three passes the loupe's own view uses.
	## The near half alone is very nearly all transparency, and in a dim room it reads as
	## nothing at all, which is why anything shown in the world is built from this.
	## Carries `extent`, the diagonal of the stone's box, so a caller can size it.
	var node := Node3D.new()
	var mesh: ArrayMesh = build(gem)
	var glow: Color = tint(gem)
	var behind: StandardMaterial3D = interior_material(gem)
	var front: StandardMaterial3D = body_material(gem)
	## A room is not the loupe. The loupe stands a stone under four lamps and a sky; a room
	## gives it a lantern twenty feet away, and a material that is nearly all transparency
	## under that reads as a black pebble on a counter. Both halves are given a floor under
	## their body and their emission, and the stone carries a little of its own light, so it
	## is a gem wherever it is set down.
	for m in [behind, front]:
		m.albedo_color.a = maxf(m.albedo_color.a, 0.62)
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = maxf(m.emission_energy_multiplier, 0.75)
	var far := MeshInstance3D.new()
	far.mesh = mesh
	far.material_override = behind
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(far)
	var near := MeshInstance3D.new()
	near.mesh = mesh
	near.material_override = front
	near.material_overlay = fire_material(gem)
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(near)
	var lamp := OmniLight3D.new()
	lamp.light_color = glow
	lamp.light_energy = 1.1
	lamp.omni_range = 1.8
	lamp.shadow_enabled = false
	node.add_child(lamp)
	node.set_meta("extent", maxf(0.01, mesh.get_aabb().size.length()))
	return node

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
	if SHAPE_DOME.has(shape_of(gem)):
		## Play-of-color, which is the whole of what an opal is. Every other stone borrows
		## the spectrum at its edges, where steep facets split the light hardest; an opal
		## has no facets and returns it from the body, in broad patches that swim across
		## the dome as it turns. Same pass, opened right up: fewer, wider bands, reaching
		## well in from the rim, and no tint at all, because an opal has no color of its
		## own to bias them towards. Clarity may dim it but never put it out — a milky
		## opal is still an opal, and this is how it is known at a glance.
		material.set_shader_parameter("fire", Tuning.value("fire") * lerpf(0.55, 1.35, b))
		material.set_shader_parameter("bands", Tuning.value("fire_bands") * 0.75)
		material.set_shader_parameter("spread", Tuning.value("fire_spread") * 1.7)
		material.set_shader_parameter("reach", 0.42)
		material.set_shader_parameter("sharpness", 1.0)
		## An ordinary opal has no color of its own to bias the spectrum towards, so its
		## play-of-color stays white-light and is opened right up. A Seam is the exception
		## and the whole point of one: it is named for a color and it replays that color's
		## gems, so its fire leans the way its vein runs — and it is pulled back off the
		## middle of the dome to leave room for the vein to be seen through. At full
		## strength the additive pass drowned everything under it and all six Seams came
		## out the same pastel, which is the thing this is here to fix.
		var seam := GemFlaws.seam_color(gem)
		if seam.a > 0.0:
			material.set_shader_parameter("tint",
				Vector3.ONE.lerp(Vector3(seam.r, seam.g, seam.b), Tuning.value("seam_fire")))
			material.set_shader_parameter("fire",
				Tuning.value("fire") * lerpf(0.55, 1.35, b) * Tuning.value("seam_room"))
			material.set_shader_parameter("reach", 0.26)
		else:
			material.set_shader_parameter("tint", Vector3.ONE)
	material.render_priority = 3
	return material

static func etch_material(gem: Dictionary) -> StandardMaterial3D:
	var l: int = clarity_grade(gem)
	var body := body_color_of(gem, l)
	var emblem := emblem_of(gem)
	# The emblem names the skill, so it has to read at every rank — and a cloudy stone is
	# nearly solid, letting only a fraction of what is set inside it through. Clarity is
	# allowed to change how the emblem looks, but never whether it can be found: as the
	# stone murks up, the emblem takes on the shade and opacity it needs to come back.
	var b := brilliance(l)
	var murk: float = Tuning.value("etch_murk") * (1.0 - b)
	var shade: float = Tuning.value("etch_darken")
	var ink: float = clampf(Tuning.value("etch_alpha") + murk * 0.4, 0.0, 1.0)
	## Every other stone lets its emblem be read by relief alone. An opal cannot: its body
	## is pale to start with and the play-of-color is laid over the whole dome additively,
	## which washes a groove flat. So on a cabochon the emblem is cut dark, and reads as a
	## shadow inside the stone the way an opal's own matrix does.
	if SHAPE_DOME.has(shape_of(gem)):
		shade = clampf(shade + 0.55, 0.0, 1.0)
		ink = clampf(ink + 0.14, 0.0, 1.0)
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
	# differently colored stones are two textures, and both vary with Clarity.
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
	var color_key: String = color_key(gem)
	var c: int = clampi(int(gem.get("carat", 1)), 1, DeepStone.carat_max())
	var k: int = cut_rank(gem)
	var l: int = clarity_grade(gem)
	var size: String = ["tiny", "small", "middling", "large", "huge"][clampi((c - 1) / 4, 0, 4)]
	var lustre: String = ["milky, intricate with what is frozen inside it", "etched, with what you can see inside",
		"clear but for one flaw", "clear", "bright and clean", "blazing"][l]
	var shape: String = shape_of(gem)
	## A Birthstone is not one of the six and was never graded against them. It has a name,
	## a cut of its own and a line already written about it, and those are better words
	## than a Color it only stands near.
	if STYLE_SHAPES.has(str(gem.get("style", ""))):
		return "%s, a %s cut. %s Drag to turn it." % [str(gem.get("name", "A birthstone")),
			str(SHAPE_NAMES.get(shape, shape)), str(gem.get("text", "")).strip_edges()]
	return "A %s %s-cut %s stone, %s, %s. %s, %s, %d carats. Drag to turn it." % [
		size, str(SHAPE_NAMES.get(shape, shape)),
		str(DeepContent.color(color_key).get("name", "Red")).to_lower(),
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
