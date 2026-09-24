extends RefCounted
## The pictographs a gem is described with, drawn as alpha masks so callers tint them.
##
## Three of them stand for the rolled properties — a balance scale for Carat, a sparkle
## for Clarity, a pierced throwing star for Cut — and the rest stand for the parts of a
## hand a formula reads: the highest dice, a pair, the running total. Nothing here knows
## a rule; `gem_text.gd` decides which glyph a term deserves and `main.gd` places it.
##
## Every glyph is a list of unit-space shapes added or subtracted in order, rasterised
## with supersampled coverage so a hole is a real hole and not a circle painted in the
## panel color. Masks are white, so one texture serves every tint; the cache is keyed
## by glyph and pixel size and dropped with `release()` alongside the rest of the kit.

const SAMPLES := 3

static var _cache: Dictionary = {}

## Hover text. A player who does not recognise a pictograph should never have to guess,
## so every glyph carries the sentence that explains it wherever it is placed.
const HINTS := {
	"carat": "Carat: how much. One multiplier over everything the stone does, and for an effect that cannot be a fraction, how many times over it happens.",
	"clarity": "Clarity: how pure. Pristine and Flawless stones ring the rail for double and triple Resonance, Flawless hits harder besides; included stones carry inclusions instead.",
	"cut": "Cut: how often. A better cut stands on a looser rung of the trigger ladder.",
	"resonance": "Resonance: builds as each gem in your rail fires, a neighbour of the same color adding extra; your Birthstone reads it last.",
	"high": "The highest dice in your hand.",
	"low": "The lowest dice in your hand.",
	"pair": "The value shown by your highest pair, not the two dice added together.",
	"triple": "The value shown by your highest group of three or more matching dice.",
	"sum": "The total of all five dice.",
	"shield": "Your block at the moment this skill resolves, including block gained earlier this turn.",
	"hit": "Separate hits against one fixed target.",
	"target": "Distinct living enemies this can reach.",
	"count": "How many dice in your hand qualify.",
	"run": "The highest value in the run of consecutive dice this used.",
	"reroll": "How many times you may reroll in one turn. A White gem raises the allowance for the rest of the battle; it never adds to itself.",
	"quad": "Four of a kind: four dice showing the same value.",
	"two_pairs": "Two pairs: two dice of one value and two of another.",
	"die": "One die of a set of matching dice.",
	"die_solid": "One die of a set of matching dice, counted.",
	"crown_die": "A crown: a die showing its own top face.",
	"crown_die_solid": "A crown in your hand: a die showing its own top face.",
	"full_house": "Full house: three dice of one value and two of another.",
	"straight3": "Straight of 3: three consecutive values, in any order.",
	"straight4": "Straight of 4: four consecutive values, in any order.",
	"straight5": "Straight of 5: five consecutive values, in any order.",
	"odd": "Odd dice: results of 1, 3, 5 and so on.",
	"even": "Even dice: results of 2, 4, 6 and so on.",
	"distinct": "Different values: no two of the counted dice alike.",
	"face": "A die showing one exact value.",
	"total_high": "Your five dice added together, at or above a line.",
	"total_low": "Your five dice added together, at or below a line.",
	"peak": "Your highest die, at or above a line.",
	"climb": "A die you rerolled that came back higher than it started.",
	"once": "Once per battle.",
	"lock": "Locked until the expedition begins."
}

# --- shape vocabulary ---------------------------------------------------------

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

static func _poly(points: Array) -> PackedVector2Array:
	var built := PackedVector2Array()
	for point in points:
		built.append(Vector2(point[0], point[1]))
	return built

static func _star(points: int, outer: float, inner: float, centre := Vector2(0.5, 0.5), turn := 0.0) -> PackedVector2Array:
	## Alternating outer and inner vertices. A wide waist reads as a blade, a narrow one
	## as a sparkle, which is the whole difference between the Cut and Clarity glyphs.
	var built := PackedVector2Array()
	for index in range(points * 2):
		var angle := turn - PI * 0.5 + PI * float(index) / float(points)
		var radius: float = outer if index % 2 == 0 else inner
		built.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return built

static func _ring(x0: float, y0: float, x1: float, y1: float, thickness: float) -> Array:
	return [ {"op": "add", "poly": _rect(x0, y0, x1, y1)},
		{"op": "sub", "poly": _rect(x0 + thickness, y0 + thickness, x1 - thickness, y1 - thickness)}]

static func _bar(from_point: Vector2, to_point: Vector2, thickness: float) -> PackedVector2Array:
	## A stroke as a quad, so a drawn line is just another polygon to the rasteriser.
	var along := to_point - from_point
	if along.length() < 0.0001:
		return PackedVector2Array()
	var side := along.orthogonal().normalized() * (thickness * 0.5)
	return PackedVector2Array([from_point + side, to_point + side, to_point - side, from_point - side])

static func _line(points: Array, thickness: float, op := "add") -> Array:
	## A polyline as one bar per segment, with a dot at each joint so corners stay solid.
	var built: Array = []
	for index in range(points.size() - 1):
		var a := Vector2(points[index][0], points[index][1])
		var b := Vector2(points[index + 1][0], points[index + 1][1])
		built.append({"op": op, "poly": _bar(a, b, thickness)})
		if index > 0:
			built.append({"op": op, "circle": [a.x, a.y, thickness * 0.5]})
	return built

static func _heart(centre: Vector2, radius: float) -> PackedVector2Array:
	## The classic parametric heart, sampled and normalised to the radius asked for.
	var built := PackedVector2Array()
	var peak := 0.0
	var raw: Array = []
	for index in range(30):
		var t := TAU * float(index) / 30.0
		var point := Vector2(16.0 * pow(sin(t), 3.0),
			- (13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		raw.append(point)
		peak = maxf(peak, point.length())
	for point in raw:
		built.append(centre + Vector2(point) * (radius / peak))
	return built

static func _shield_ring(centre: Vector2, half_width: float, half_height: float, thickness: float) -> Array:
	return [ {"op": "add", "poly": _shield(centre, half_width, half_height)},
		{"op": "sub", "poly": _shield(centre, half_width - thickness, half_height - thickness)}]

static func _shield(centre: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	return PackedVector2Array([
		centre + Vector2(0.0, -half_height),
		centre + Vector2(half_width, -half_height * 0.62),
		centre + Vector2(half_width, half_height * 0.10),
		centre + Vector2(0.0, half_height),
		centre + Vector2(-half_width, half_height * 0.10),
		centre + Vector2(-half_width, -half_height * 0.62)])

static func _dice(origins: Array, edge: float, thickness: float, pips: Array, pip_radius: float = -1.0) -> Array:
	## Square dice seen face on, each at a top-left origin. A die with a thickness is an outline
	## with its pips painted in; one without is solid with its pips punched through, so a
	## second group reads apart from the first even tinted one color.
	var built: Array = []
	var radius: float = pip_radius if pip_radius > 0.0 else edge * 0.17
	for origin in origins:
		var x0: float = float(origin[0])
		var y0: float = float(origin[1])
		if thickness > 0.0:
			built.append_array(_ring(x0, y0, x0 + edge, y0 + edge, thickness))
		else:
			built.append({"op": "add", "poly": _rect(x0, y0, x0 + edge, y0 + edge)})
		for pip in pips:
			var at := Vector2(x0 + edge * float(pip[0]), y0 + edge * float(pip[1]))
			built.append({"op": "add" if thickness > 0.0 else "sub", "circle": [at.x, at.y, radius]})
	return built

static func _stair(steps: int) -> Array:
	## A straight: a stair of dice, one step per value it needs, each step a column with a die
	## face punched into its top. Columns rather than floating squares, so a five-step stair
	## still reads as a stair at the size of a line of text.
	var gap := 0.035
	var width: float = (0.98 - gap * float(steps - 1)) / float(steps)
	var built: Array = []
	for index in steps:
		var x0: float = 0.01 + float(index) * (width + gap)
		var top: float = 0.62 - 0.56 * float(index) / float(maxi(1, steps - 1))
		built.append({"op": "add", "poly": _rect(x0, top, x0 + width, 0.96)})
		var hole: float = width * 0.46
		built.append({"op": "sub", "poly": _rect(x0 + (width - hole) * 0.5, top + width * 0.22, x0 + (width + hole) * 0.5, top + width * 0.22 + hole)})
	return built

static func _moved(shapes: Array, offset: Vector2, scale: float) -> Array:
	## Another glyph shrunk and shifted, so a mark can lend its drawing to a compound one.
	var moved: Array = []
	for shape in shapes:
		if shape.has("circle"):
			var circle: Array = shape.circle
			moved.append({"op": shape.op, "circle": [float(circle[0]) * scale + offset.x, float(circle[1]) * scale + offset.y, float(circle[2]) * scale]})
		else:
			var poly := PackedVector2Array()
			for point in shape.poly:
				poly.append(point * scale + offset)
			moved.append({"op": shape.op, "poly": poly})
	return moved

static func _shapes(glyph: String) -> Array:
	match glyph:
		"carat":
			# A balance scale: knob, post, beam, two hanging pans, and a splayed foot.
			return [ {"op": "add", "circle": [0.5, 0.115, 0.062]},
				{"op": "add", "poly": _rect(0.465, 0.155, 0.535, 0.815)},
				{"op": "add", "poly": _rect(0.085, 0.185, 0.915, 0.248)},
				{"op": "add", "poly": _rect(0.172, 0.248, 0.216, 0.445)},
				{"op": "add", "poly": _rect(0.784, 0.248, 0.828, 0.445)},
				{"op": "add", "poly": _poly([[0.040, 0.435], [0.348, 0.435], [0.278, 0.605], [0.110, 0.605]])},
				{"op": "add", "poly": _poly([[0.652, 0.435], [0.960, 0.435], [0.890, 0.605], [0.722, 0.605]])},
				{"op": "add", "poly": _poly([[0.340, 0.800], [0.660, 0.800], [0.745, 0.900], [0.255, 0.900]])},
				{"op": "add", "poly": _rect(0.200, 0.888, 0.800, 0.948)}]
		"clarity":
			# Six needle points and two satellites. Cut is a solid four-point blade with a
			# pierced centre, so the two never read as the same mark, even at 14 pixels
			# where the tint alone was not enough to tell them apart.
			return [ {"op": "add", "poly": _star(6, 0.400, 0.062, Vector2(0.430, 0.550))},
				{"op": "add", "poly": _star(6, 0.170, 0.026, Vector2(0.820, 0.200))},
				{"op": "add", "poly": _star(6, 0.112, 0.018, Vector2(0.135, 0.825))}]
		"cut":
			# A four-point throwing star with a real pierced centre.
			return [ {"op": "add", "poly": _star(4, 0.495, 0.205)},
				{"op": "sub", "circle": [0.5, 0.5, 0.118]}]
		"resonance":
			# A bright point with one clear pulse ring around it: bold strokes so it still
			# reads at the small size it sits inline with a word at. The ring's own cutout
			# would erase the centre point if drawn after it, so the point goes last.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.460]}, {"op": "sub", "circle": [0.5, 0.5, 0.355]},
				{"op": "add", "poly": _star(4, 0.175, 0.058, Vector2(0.5, 0.5))}]
		"high", "low":
			var up := glyph == "high"
			var head: Array = [[0.845, 0.075], [0.995, 0.400], [0.695, 0.400]] if up else \
				[[0.845, 0.925], [0.995, 0.600], [0.695, 0.600]]
			var shaft: PackedVector2Array = _rect(0.790, 0.380, 0.900, 0.930) if up else _rect(0.790, 0.070, 0.900, 0.620)
			return _ring(0.030, 0.170, 0.630, 0.830, 0.105) + \
				[ {"op": "add", "poly": _poly(head)}, {"op": "add", "poly": shaft}]
		# The hand shapes a requirement is drawn with. Every one is built from dice seen face on,
		# the way Dice Throne draws its combinations: matching dice each wear one pip, a second
		# group is drawn solid so two groups never read as one, a straight is dice climbing a
		# stair, and a parity die shows a real odd or even face. No two share a silhouette.
		"pair":
			return _dice([[0.03, 0.28]], 0.44, 0.085, [[0.5, 0.5]]) + _dice([[0.53, 0.28]], 0.44, 0.085, [[0.5, 0.5]])
		"triple":
			return _dice([[0.01, 0.345], [0.345, 0.345], [0.68, 0.345]], 0.31, 0.07, [[0.5, 0.5]])
		"quad":
			return _dice([[0.03, 0.03], [0.53, 0.03], [0.03, 0.53], [0.53, 0.53]], 0.44, 0.08, [[0.5, 0.5]])
		"two_pairs":
			return _dice([[0.03, 0.03], [0.53, 0.03]], 0.44, 0.08, [[0.5, 0.5]]) \
				+ _dice([[0.03, 0.53], [0.53, 0.53]], 0.44, 0.0, [[0.5, 0.5]])
		"die", "die_solid":
			# One die of a set, drawn five abreast for a Birthstone that counts matching dice:
			# an outline while it does not count, solid with its pip punched through once it does.
			return _dice([[0.08, 0.08]], 0.84, 0.13 if glyph == "die" else 0.0, [[0.5, 0.5]])
		"crown_die", "crown_die_solid":
			# The same die on its top face, wearing a three-point crown where the pip was.
			var solid := glyph == "crown_die_solid"
			var crown := _poly([[0.25, 0.70], [0.25, 0.30], [0.375, 0.47], [0.5, 0.26], [0.625, 0.47], [0.75, 0.30], [0.75, 0.70]])
			return _dice([[0.08, 0.08]], 0.84, 0.0 if solid else 0.11, []) + [ {"op": "sub" if solid else "add", "poly": crown}]
		"full_house":
			return _dice([[0.02, 0.07], [0.35, 0.07], [0.68, 0.07]], 0.30, 0.065, [[0.5, 0.5]]) \
				+ _dice([[0.185, 0.60], [0.515, 0.60]], 0.30, 0.0, [[0.5, 0.5]])
		"straight3", "straight4", "straight5":
			return _stair(int(glyph.substr(8)))
		"odd":
			return _dice([[0.06, 0.06]], 0.88, 0.09, [[0.28, 0.28], [0.5, 0.5], [0.72, 0.72]], 0.085)
		"even":
			return _dice([[0.06, 0.06]], 0.88, 0.09, [[0.29, 0.29], [0.71, 0.29], [0.29, 0.71], [0.71, 0.71]], 0.085)
		"distinct":
			return _dice([[0.01, 0.30]], 0.40, 0.075, [[0.5, 0.5]]) \
				+ _dice([[0.59, 0.30]], 0.40, 0.075, [[0.28, 0.28], [0.72, 0.72]]) \
				+[ {"op": "add", "poly": _bar(Vector2(0.43, 0.86), Vector2(0.57, 0.14), 0.07)}]
		"face":
			return _dice([[0.08, 0.08]], 0.84, 0.09, []) \
				+[ {"op": "add", "poly": _poly([[0.5, 0.26], [0.74, 0.5], [0.5, 0.74], [0.26, 0.5]])},
					{"op": "sub", "poly": _poly([[0.5, 0.38], [0.62, 0.5], [0.5, 0.62], [0.38, 0.5]])}]
		"total_high", "total_low":
			var up := glyph == "total_high"
			return _moved(_shapes("sum"), Vector2(-0.02, 0.06), 0.66) + [ {"op": "add", "poly": _poly(
				[[0.82, 0.18], [1.0, 0.48], [0.64, 0.48]] if up else [[0.82, 0.82], [1.0, 0.52], [0.64, 0.52]])}]
		"peak":
			return _dice([[0.04, 0.40]], 0.52, 0.085, [[0.5, 0.5]]) \
				+[ {"op": "add", "poly": _rect(0.0, 0.22, 0.60, 0.30)},
					{"op": "add", "poly": _poly([[0.82, 0.10], [1.0, 0.42], [0.64, 0.42]])},
					{"op": "add", "poly": _rect(0.77, 0.40, 0.87, 0.92)}]
		"climb":
			return _moved(_shapes("reroll"), Vector2(-0.04, 0.12), 0.72) + [
				{"op": "add", "poly": _poly([[0.84, 0.08], [1.0, 0.36], [0.68, 0.36]])},
				{"op": "add", "poly": _rect(0.79, 0.34, 0.89, 0.88)}]
		"once":
			return [ {"op": "add", "circle": [0.5, 0.5, 0.47]}, {"op": "sub", "circle": [0.5, 0.5, 0.36]},
				{"op": "add", "poly": _rect(0.44, 0.24, 0.57, 0.76)},
				{"op": "add", "poly": _poly([[0.44, 0.24], [0.57, 0.24], [0.34, 0.38], [0.34, 0.30]])}]
		"lock":
			return [ {"op": "add", "circle": [0.5, 0.36, 0.25]}, {"op": "sub", "circle": [0.5, 0.36, 0.15]},
				{"op": "sub", "poly": _rect(0.2, 0.36, 0.8, 0.5)},
				{"op": "add", "poly": _rect(0.18, 0.44, 0.82, 0.94)},
				{"op": "sub", "circle": [0.5, 0.63, 0.07]},
				{"op": "sub", "poly": _rect(0.465, 0.63, 0.535, 0.82)}]
		"sum":
			return [ {"op": "add", "poly": _poly([
				[0.140, 0.080], [0.860, 0.080], [0.860, 0.245], [0.425, 0.245], [0.640, 0.500],
				[0.425, 0.755], [0.860, 0.755], [0.860, 0.920], [0.140, 0.920], [0.395, 0.500]])}]
		"shield":
			return [ {"op": "add", "poly": _poly([
				[0.500, 0.050], [0.925, 0.205], [0.925, 0.525], [0.500, 0.950], [0.075, 0.525], [0.075, 0.205]])},
				{"op": "sub", "poly": _poly([
				[0.500, 0.215], [0.790, 0.320], [0.790, 0.500], [0.500, 0.790], [0.210, 0.500], [0.210, 0.320]])}]
		"hit":
			return [ {"op": "add", "poly": _star(8, 0.490, 0.150)},
				{"op": "add", "circle": [0.5, 0.5, 0.215]}]
		"target":
			return [ {"op": "add", "circle": [0.5, 0.5, 0.465]},
				{"op": "sub", "circle": [0.5, 0.5, 0.335]},
				{"op": "add", "circle": [0.5, 0.5, 0.165]}]
		"count":
			return [ {"op": "add", "poly": _rect(0.095, 0.215, 0.285, 0.865)},
				{"op": "add", "poly": _rect(0.405, 0.215, 0.595, 0.865)},
				{"op": "add", "poly": _rect(0.715, 0.215, 0.905, 0.865)}]
		"run":
			return [ {"op": "add", "poly": _rect(0.075, 0.615, 0.285, 0.925)},
				{"op": "add", "poly": _rect(0.395, 0.375, 0.605, 0.925)},
				{"op": "add", "poly": _rect(0.715, 0.135, 0.925, 0.925)}]
		"reroll":
			# A ring broken at the top with an arrowhead on the open end: the mark for
			# "again". The gap is cut before the head is added, so the head survives it.
			return [ {"op": "add", "circle": [0.5, 0.54, 0.44]},
				{"op": "sub", "circle": [0.5, 0.54, 0.26]},
				{"op": "sub", "poly": _rect(0.44, -0.05, 1.05, 0.34)},
				{"op": "add", "poly": _poly([[0.30, 0.00], [0.76, 0.17], [0.30, 0.34]])}]
	return _emblem_shapes(glyph)

## The emblem etched into a gem's face, one per skill. These are read at the size of a
## thumbnail and through a bevel, so every one is a bold silhouette with no thin detail.
const SKILL_EMBLEMS := {
	"STRIKE": "sword", "CLEAVE": "slashes", "CRUSH": "hammer", "BARRAGE": "arcs", "OVERKILL": "shield_burst",
	"CROSSCUT": "slashes", "DETONATE": "flame", "APEX": "sword",
	"SHELTER": "two_shields", "MORTAR": "rampart", "SIPHON": "drain",
	"STAKE": "coin_fall", "APPRAISE": "eye", "GILDED_ARMOR": "shield", "ENRICH": "gem",
	"SPALL": "split_shield", "EMBER": "spark", "FURY": "bolt",
	"GUARD": "shield", "BULWARK": "rampart", "AEGIS": "two_shields", "BASTION": "broken_chain", "TEMPO": "hourglass",
	"ANCHOR": "knot", "RIPOSTE": "split_shield",
	"MEND": "cross", "GRAFT": "knot", "BLOOM": "heart", "RENEWAL": "clean_drop", "LIFELINE": "pulse", "THRIVE": "flask", "SAP": "wilt",
	"HEX": "bolt", "VENOM": "skull", "MIASMA": "cloud", "CURSE": "eye", "SHATTER": "split_shield", "BIND": "broken_chain", "DREAD": "thorn",
	"MIST": "cloud", "ETCH": "crosshair",
	"TITHE": "coin", "JACKPOT": "coins", "LUCKY_SEVEN": "seven", "WAGER": "coin_fall", "WINDFALL": "sun", "DOUBLE_DOWN": "copy", "PROSPECT": "crosshair",
	"GLIMMER": "spark", "REFRACT": "prism", "POLISH": "rose", "MIRROR": "eye", "CASCADE": "drain", "FACET": "rose", "ECHO": "copy", "PRISM": "prism",
	## The opals. All six Seams wear the same check of color patches, because what tells
	## them apart is the color washed through the stone under it, not the mark cut into it.
	"SEAM_RED": "lattice", "SEAM_BLUE": "lattice", "SEAM_GREEN": "lattice",
	"SEAM_VIOLET": "lattice", "SEAM_GOLD": "lattice", "SEAM_WHITE": "lattice",
	"FIRE_OPAL": "flame", "DOUBLET": "copy", "MATRIX": "geode", "PRELUDE": "reroll"}

## The creatures' abilities wear the same marks as stones.
const MOVE_EMBLEMS := {
	"BITE": "slashes", "LATCH": "knot", "OOZE": "cloud", "ENGULF": "drain", "POUND": "hammer", "QUAKE": "arcs",
	"PECK": "thorn", "SNATCH": "coin_fall", "FLUTTER": "spark", "DRAIN": "drain", "WAIL": "skull", "PUFF": "cloud",
	"SMOTHER": "cloud", "LASH": "slashes", "COIL": "rampart", "SHATTERBREATH": "arcs", "PICK": "hammer", "CAVE-IN": "rampart",
	"SHORE UP": "shield", "BLAST": "shield_burst", "COLLAPSE": "hammer", "REFLECT": "prism", "REFRACTION": "prism",
	"HARDEN": "shield", "GATHER": "cloud", "REINFORCE": "die", "SPLINTER": "thorn",
	"ABRASIVE FOG": "cloud", "REKNIT": "heart", "OMEN": "eye",
	"SHATTER": "split_shield", "BORE": "hammer", "GRIND": "rose", "OVERDRIVE": "bolt"}

static func emblem(skill_key: String) -> String:
	var key := skill_key.to_upper()
	return str(SKILL_EMBLEMS.get(key, MOVE_EMBLEMS.get(key, "sword")))

static func _emblem_shapes(glyph: String) -> Array:
	match glyph:
		"sword":
			return [ {"op": "add", "poly": _poly([[0.50, 0.02], [0.61, 0.19], [0.61, 0.60], [0.39, 0.60], [0.39, 0.19]])},
				{"op": "add", "poly": _rect(0.20, 0.60, 0.80, 0.70)},
				{"op": "add", "poly": _rect(0.43, 0.70, 0.57, 0.89)},
				{"op": "add", "circle": [0.5, 0.92, 0.075]}]
		"heart":
			return [ {"op": "add", "poly": _heart(Vector2(0.5, 0.50), 0.48)}]
		"flask":
			return [ {"op": "add", "poly": _rect(0.355, 0.02, 0.645, 0.115)},
				{"op": "add", "poly": _rect(0.435, 0.02, 0.565, 0.30)},
				{"op": "add", "poly": _poly([[0.435, 0.26], [0.565, 0.26], [0.80, 0.66], [0.20, 0.66]])},
				{"op": "add", "circle": [0.5, 0.645, 0.295]}]
		"slashes":
			return _line([[0.10, 0.86], [0.34, 0.14]], 0.15) \
				+ _line([[0.38, 0.86], [0.62, 0.14]], 0.15) \
				+ _line([[0.66, 0.86], [0.90, 0.14]], 0.15)
		"seven":
			return [ {"op": "add", "poly": _poly([[0.15, 0.08], [0.87, 0.08], [0.87, 0.25],
				[0.60, 0.93], [0.38, 0.93], [0.65, 0.27], [0.15, 0.27]])}]
		"hammer":
			var haft := Vector2(0.605, -0.796)
			var head := Vector2(0.74, 0.22)
			return [ {"op": "add", "poly": _bar(Vector2(0.20, 0.94), head, 0.135)},
				{"op": "add", "poly": _bar(head - haft.orthogonal() * 0.24, head + haft.orthogonal() * 0.24, 0.30)}]
		"sun":
			var rays: Array = [ {"op": "add", "circle": [0.5, 0.5, 0.235]}]
			for index in 8:
				var angle := TAU * float(index) / 8.0
				var step := Vector2(cos(angle), sin(angle))
				rays.append({"op": "add", "poly": _bar(Vector2(0.5, 0.5) + step * 0.31,
					Vector2(0.5, 0.5) + step * 0.48, 0.11)})
			return rays
		"shield":
			return [ {"op": "add", "poly": _shield(Vector2(0.5, 0.5), 0.425, 0.45)},
				{"op": "sub", "poly": _shield(Vector2(0.5, 0.5), 0.275, 0.29)}]
		"shield_burst":
			return _shield_ring(Vector2(0.40, 0.57), 0.37, 0.41, 0.115) \
				+[ {"op": "add", "poly": _star(4, 0.29, 0.065, Vector2(0.80, 0.19))}]
		"two_shields":
			return _shield_ring(Vector2(0.67, 0.37), 0.30, 0.34, 0.10) \
				+[ {"op": "sub", "poly": _shield(Vector2(0.36, 0.62), 0.38, 0.42)}] \
				+ _shield_ring(Vector2(0.36, 0.62), 0.33, 0.37, 0.10)
		"bolt":
			return [ {"op": "add", "poly": _poly([[0.62, 0.03], [0.22, 0.54], [0.45, 0.54],
				[0.34, 0.97], [0.78, 0.43], [0.53, 0.43]])}]
		"rampart":
			return [ {"op": "add", "poly": _rect(0.06, 0.20, 0.94, 0.92)},
				{"op": "sub", "poly": _rect(0.24, 0.14, 0.40, 0.40)},
				{"op": "sub", "poly": _rect(0.60, 0.14, 0.76, 0.40)},
				{"op": "sub", "poly": _rect(0.44, 0.52, 0.56, 0.94)}]
		"drain":
			return [ {"op": "add", "poly": _poly([[0.50, 0.04], [0.76, 0.48], [0.24, 0.48]])},
				{"op": "add", "circle": [0.5, 0.50, 0.26]},
				{"op": "add", "poly": _rect(0.20, 0.86, 0.80, 0.96)}]
		"cross":
			return [ {"op": "add", "poly": _rect(0.39, 0.08, 0.61, 0.92)},
				{"op": "add", "poly": _rect(0.08, 0.39, 0.92, 0.61)}]
		"split_shield":
			return [ {"op": "add", "poly": _shield(Vector2(0.5, 0.5), 0.44, 0.47)},
				{"op": "sub", "poly": _poly([[0.42, 0.00], [0.60, 0.30], [0.42, 0.50],
					[0.62, 0.74], [0.44, 1.00], [0.58, 1.00], [0.76, 0.74], [0.56, 0.50],
					[0.74, 0.30], [0.56, 0.00]])}]
		"arcs":
			return [ {"op": "add", "circle": [0.06, 0.5, 0.90]}, {"op": "sub", "circle": [0.06, 0.5, 0.76]},
				{"op": "add", "circle": [0.06, 0.5, 0.60]}, {"op": "sub", "circle": [0.06, 0.5, 0.46]},
				{"op": "add", "circle": [0.06, 0.5, 0.30]}, {"op": "sub", "circle": [0.06, 0.5, 0.16]},
				{"op": "sub", "poly": _rect(-0.2, -0.2, 0.16, 1.2)}]
		"skull":
			return [ {"op": "add", "circle": [0.5, 0.42, 0.35]},
				{"op": "add", "poly": _rect(0.29, 0.60, 0.71, 0.88)},
				{"op": "sub", "circle": [0.37, 0.41, 0.115]},
				{"op": "sub", "circle": [0.63, 0.41, 0.115]},
				{"op": "sub", "poly": _poly([[0.50, 0.48], [0.57, 0.61], [0.43, 0.61]])},
				{"op": "sub", "poly": _rect(0.43, 0.66, 0.47, 0.90)},
				{"op": "sub", "poly": _rect(0.53, 0.66, 0.57, 0.90)}]
		"hourglass":
			return [ {"op": "add", "poly": _poly([[0.15, 0.10], [0.85, 0.10], [0.50, 0.50]])},
				{"op": "add", "poly": _poly([[0.50, 0.50], [0.85, 0.90], [0.15, 0.90]])},
				{"op": "add", "poly": _rect(0.10, 0.03, 0.90, 0.12)},
				{"op": "add", "poly": _rect(0.10, 0.88, 0.90, 0.97)}]
		"crosshair":
			return [ {"op": "add", "circle": [0.5, 0.5, 0.44]},
				{"op": "sub", "circle": [0.5, 0.5, 0.31]},
				{"op": "add", "poly": _rect(0.455, 0.01, 0.545, 0.30)},
				{"op": "add", "poly": _rect(0.455, 0.70, 0.545, 0.99)},
				{"op": "add", "poly": _rect(0.01, 0.455, 0.30, 0.545)},
				{"op": "add", "poly": _rect(0.70, 0.455, 0.99, 0.545)},
				{"op": "add", "circle": [0.5, 0.5, 0.105]}]
		"pulse":
			return [ {"op": "add", "poly": _heart(Vector2(0.5, 0.48), 0.48)}] \
				+ _line([[0.00, 0.52], [0.28, 0.52], [0.37, 0.33], [0.50, 0.72], [0.60, 0.47], [1.00, 0.47]], 0.105, "sub")
		"spark":
			# One bright point and two lesser ones: light coming off a stone that was
			# only polished, not recut.
			return [ {"op": "add", "poly": _star(4, 0.42, 0.105, Vector2(0.44, 0.48))},
				{"op": "add", "poly": _star(4, 0.17, 0.042, Vector2(0.86, 0.15))},
				{"op": "add", "circle": [0.84, 0.80, 0.085]}]
		"prism":
			# A triangle throwing three rays out of one face — white light going in and
			# coming out spread, which is exactly what the skill does to a die.
			var rays: Array = [ {"op": "add", "poly": _poly([[0.32, 0.05], [0.61, 0.85], [0.03, 0.85]])},
				{"op": "sub", "poly": _poly([[0.32, 0.31], [0.49, 0.74], [0.15, 0.74]])}]
			for index in 3:
				var height := 0.36 + 0.15 * float(index)
				rays.append({"op": "add", "poly": _bar(Vector2(0.50, height),
					Vector2(0.99, height - 0.16), 0.085)})
			return rays
		"eye":
			# Two arcs meeting at the corners, with a ring and a pupil cut through them.
			var lens := PackedVector2Array()
			for index in range(13):
				var t := float(index) / 12.0
				lens.append(Vector2(lerpf(0.03, 0.97, t), 0.5 - 0.34 * sin(PI * t)))
			for index in range(13):
				var t := 1.0 - float(index) / 12.0
				lens.append(Vector2(lerpf(0.03, 0.97, t), 0.5 + 0.34 * sin(PI * t)))
			return [ {"op": "add", "poly": lens},
				{"op": "sub", "circle": [0.5, 0.5, 0.215]},
				{"op": "add", "circle": [0.5, 0.5, 0.105]}]
		"copy":
			# One square behind another: the mark every interface uses for "again".
			return _ring(0.30, 0.04, 0.96, 0.70, 0.10) \
				+[ {"op": "sub", "poly": _rect(0.04, 0.30, 0.70, 0.96)}] \
				+ _ring(0.04, 0.30, 0.70, 0.96, 0.10)
		"rose":
			# A rose-cut stone from directly above: a hexagonal girdle divided into the six
			# crown facets that rise to its point. The facet lines are cut out of the solid,
			# so the mark survives being tinted one color and shrunk to a thumbnail.
			var outer := PackedVector2Array()
			var centre := Vector2(0.5, 0.5)
			for index in 6:
				var angle := -PI * 0.5 + TAU * float(index) / 6.0
				outer.append(centre + Vector2(cos(angle), sin(angle)) * 0.47)
			var girdle := PackedVector2Array()
			var table := PackedVector2Array()
			for point in outer:
				girdle.append(centre.lerp(point, 0.64))
				table.append(centre.lerp(point, 0.50))
			var built: Array = [ {"op": "add", "poly": outer}]
			# Six spokes and one girdle line, and no more: the twelve-ray version of this
			# read as a snowflake at thumbnail size rather than as a stone.
			for index in 6:
				built.append({"op": "sub", "poly": _bar(centre, outer[index], 0.055)})
			built.append({"op": "sub", "poly": girdle})
			built.append({"op": "add", "poly": table})
			return built
		"quad":
			# Four alike, as four of the same square. Nothing else in the set is a grid.
			var squares: Array = []
			for index in 4:
				var column := 0.07 + 0.50 * float(index % 2)
				var row := 0.07 + 0.50 * float(index / 2)
				squares.append({"op": "add", "poly": _rect(column, row, column + 0.36, row + 0.36)})
			return squares
		"broken_chain":
			# Two links pulling apart from the one that snapped between them: what a stun
			# looks like once it is cleared. Round links, because square ones read as boxes.
			# The gap on the centre line has to stay open, so the snapped ends flare away
			# from it at different heights rather than meeting in it.
			return [ {"op": "add", "circle": [0.20, 0.50, 0.235]}, {"op": "sub", "circle": [0.20, 0.50, 0.125]},
				{"op": "add", "circle": [0.80, 0.50, 0.235]}, {"op": "sub", "circle": [0.80, 0.50, 0.125]},
				{"op": "add", "poly": _bar(Vector2(0.38, 0.38), Vector2(0.50, 0.25), 0.09)},
				{"op": "add", "poly": _bar(Vector2(0.62, 0.62), Vector2(0.50, 0.75), 0.09)}]
		"clean_drop":
			# A droplet struck through: the mark for poison taken back out.
			return [ {"op": "add", "poly": _poly([[0.44, 0.06], [0.76, 0.52], [0.70, 0.76], [0.18, 0.76], [0.12, 0.52]])},
				{"op": "add", "circle": [0.44, 0.62, 0.30]},
				{"op": "sub", "poly": _bar(Vector2(0.06, 0.94), Vector2(0.94, 0.06), 0.15)},
				{"op": "add", "poly": _bar(Vector2(0.10, 0.90), Vector2(0.90, 0.10), 0.095)}]
		"knot":
			# Two stocks joined into one shoot, with the binding across the join. Crossing
			# them instead read as a scribbled X, which says nothing about grafting.
			return _line([[0.10, 0.95], [0.50, 0.58]], 0.13) \
				+ _line([[0.90, 0.95], [0.50, 0.58]], 0.13) \
				+[ {"op": "add", "poly": _bar(Vector2(0.50, 0.62), Vector2(0.50, 0.06), 0.13)},
					{"op": "sub", "poly": _rect(0.06, 0.44, 0.94, 0.52)},
					{"op": "add", "poly": _rect(0.18, 0.40, 0.82, 0.50)}]
		"thorn":
			# A barb, hooked and backswept, so it reads as a hex rather than a plain spike.
			return [ {"op": "add", "poly": _poly([[0.86, 0.05], [0.58, 0.62], [0.20, 0.95],
				[0.34, 0.52], [0.60, 0.30]])},
				{"op": "add", "poly": _bar(Vector2(0.62, 0.28), Vector2(0.94, 0.44), 0.11)},
				{"op": "add", "circle": [0.20, 0.95, 0.075]}]
		"cloud":
			# A lumpy cloud with three drops falling out of it.
			return [ {"op": "add", "circle": [0.30, 0.36, 0.22]},
				{"op": "add", "circle": [0.54, 0.28, 0.27]},
				{"op": "add", "circle": [0.78, 0.40, 0.19]},
				{"op": "add", "poly": _rect(0.10, 0.36, 0.94, 0.56)},
				{"op": "add", "circle": [0.24, 0.74, 0.085]},
				{"op": "add", "circle": [0.52, 0.82, 0.085]},
				{"op": "add", "circle": [0.78, 0.72, 0.085]}]
		"wilt":
			# Three chevrons pointing down: strength going out of something.
			var chevrons: Array = []
			for index in 3:
				var top := 0.06 + 0.30 * float(index)
				chevrons.append_array(_line([[0.14, top], [0.50, top + 0.24], [0.86, top]], 0.135))
			return chevrons
		"coin":
			# A milled rim and one struck bar. Crossing two bars made a plus sign, which is
			# already Mend's mark and says medicine rather than money.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.47]},
				{"op": "sub", "circle": [0.5, 0.5, 0.355]},
				{"op": "add", "circle": [0.5, 0.5, 0.275]},
				{"op": "sub", "poly": _rect(0.20, 0.44, 0.80, 0.56)},
				{"op": "add", "poly": _rect(0.26, 0.465, 0.74, 0.535)}]
		"coins":
			# A stack seen from the side, which no single coin can be mistaken for.
			var stack: Array = []
			for index in 3:
				var middle := 0.78 - 0.28 * float(index)
				stack.append({"op": "add", "circle": [0.5, middle, 0.40]})
				stack.append({"op": "sub", "circle": [0.5, middle - 0.09, 0.40]})
			return stack
		"coin_fall":
			# A coin with the arrow of a falling total through it: the lower the better.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.47]},
				{"op": "sub", "circle": [0.5, 0.5, 0.35]},
				{"op": "add", "poly": _rect(0.42, 0.16, 0.58, 0.62)},
				{"op": "add", "poly": _poly([[0.50, 0.88], [0.24, 0.52], [0.76, 0.52]])}]
		"lattice":
			# The squared-off patches of color an opal shows when it is turned: four of
			# them, because what the mark has to say is "every one of these, again".
			var check: Array = []
			for spot in [[0.31, 0.69], [0.69, 0.69], [0.31, 0.31], [0.69, 0.31]]:
				var x: float = float(spot[0])
				var y: float = float(spot[1])
				check.append({"op": "add", "poly": _poly([[x, y + 0.24], [x + 0.24, y], [x, y - 0.24], [x - 0.24, y]])})
			return check
		"flame":
			# A broad tongue of flame, bellied out so it still reads at a thumbnail.
			return [ {"op": "add", "poly": _poly([[0.50, 0.97], [0.68, 0.72], [0.64, 0.56], [0.80, 0.40],
				[0.76, 0.19], [0.58, 0.03], [0.34, 0.06], [0.20, 0.26], [0.26, 0.48], [0.36, 0.64], [0.34, 0.80]])}]
		"geode":
			# A stone still in its rock: a broken shell with the gem showing through it.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.47]},
				{"op": "sub", "circle": [0.5, 0.5, 0.31]},
				{"op": "add", "poly": _poly([[0.50, 0.76], [0.70, 0.50], [0.50, 0.24], [0.30, 0.50]])}]
	return _ui_shapes(glyph)

## The marks the interface itself is drawn with: the things a player carries, the places a
## run goes, and the verbs on its buttons. Same rules as the emblems: bold, no hairlines.
static func _ui_shapes(glyph: String) -> Array:
	match glyph:
		"ore":
			# A nugget: an irregular lump with two facet cuts, so it reads as rock, not coin.
			return [ {"op": "add", "poly": _poly([[0.18, 0.38], [0.40, 0.14], [0.70, 0.18], [0.92, 0.46],
				[0.80, 0.82], [0.42, 0.90], [0.10, 0.70]])},
				{"op": "sub", "poly": _bar(Vector2(0.40, 0.14), Vector2(0.50, 0.50), 0.06)},
				{"op": "sub", "poly": _bar(Vector2(0.50, 0.50), Vector2(0.92, 0.46), 0.06)},
				{"op": "sub", "poly": _bar(Vector2(0.50, 0.50), Vector2(0.42, 0.90), 0.06)}]
		"loupe":
			return [ {"op": "add", "circle": [0.40, 0.40, 0.33]}, {"op": "sub", "circle": [0.40, 0.40, 0.23]},
				{"op": "add", "poly": _bar(Vector2(0.62, 0.62), Vector2(0.92, 0.92), 0.17)},
				{"op": "add", "poly": _star(4, 0.13, 0.035, Vector2(0.40, 0.40))}]
		"gem":
			# The stone as everyone draws it: a table, a crown and a pavilion to a point.
			var outline := _poly([[0.26, 0.14], [0.74, 0.14], [0.96, 0.38], [0.50, 0.92], [0.04, 0.38]])
			return [ {"op": "add", "poly": outline},
				{"op": "sub", "poly": _bar(Vector2(0.04, 0.38), Vector2(0.96, 0.38), 0.05)},
				{"op": "sub", "poly": _bar(Vector2(0.36, 0.14), Vector2(0.30, 0.38), 0.05)},
				{"op": "sub", "poly": _bar(Vector2(0.64, 0.14), Vector2(0.70, 0.38), 0.05)},
				{"op": "sub", "poly": _bar(Vector2(0.30, 0.38), Vector2(0.50, 0.92), 0.05)},
				{"op": "sub", "poly": _bar(Vector2(0.70, 0.38), Vector2(0.50, 0.92), 0.05)}]
		"pick":
			var head := PackedVector2Array()
			for index in range(13):
				var t := float(index) / 12.0
				head.append(Vector2(lerpf(0.06, 0.94, t), 0.34 - 0.22 * sin(PI * t)))
			for index in range(13):
				var t := 1.0 - float(index) / 12.0
				head.append(Vector2(lerpf(0.06, 0.94, t), 0.40 - 0.12 * sin(PI * t) + 0.02))
			return [ {"op": "add", "poly": head},
				{"op": "add", "poly": _bar(Vector2(0.50, 0.22), Vector2(0.50, 0.96), 0.12)}]
		"lift":
			# A cage on its cable with an arrow pointing home.
			return [ {"op": "add", "poly": _rect(0.47, 0.02, 0.53, 0.30)}] + _ring(0.16, 0.30, 0.84, 0.96, 0.08) + [
				{"op": "add", "poly": _poly([[0.50, 0.40], [0.72, 0.64], [0.58, 0.64], [0.58, 0.86], [0.42, 0.86], [0.42, 0.64], [0.28, 0.64]])}]
		"descend":
			return [ {"op": "add", "poly": _poly([[0.50, 0.96], [0.14, 0.52], [0.36, 0.52], [0.36, 0.06], [0.64, 0.06], [0.64, 0.52], [0.86, 0.52]])}]
		"bag":
			return [ {"op": "add", "circle": [0.5, 0.64, 0.33]},
				{"op": "add", "poly": _poly([[0.34, 0.12], [0.66, 0.12], [0.58, 0.34], [0.42, 0.34]])},
				{"op": "sub", "poly": _rect(0.30, 0.30, 0.70, 0.36)},
				{"op": "add", "poly": _rect(0.36, 0.28, 0.64, 0.33)}]
		"purse":
			# A merchant's bag of gold: a sack tied at the neck with its sign on the belly and
			# a coin spilled at its foot, so it never reads as the plain kit bag.
			var shapes: Array = [ {"op": "add", "circle": [0.42, 0.63, 0.31]},
				{"op": "add", "poly": _poly([[0.32, 0.34], [0.52, 0.34], [0.68, 0.50], [0.16, 0.50]])},
				{"op": "add", "poly": _poly([[0.33, 0.31], [0.16, 0.10], [0.31, 0.15], [0.42, 0.05], [0.53, 0.15], [0.68, 0.10], [0.51, 0.31]])},
				{"op": "sub", "poly": _rect(0.10, 0.275, 0.74, 0.305)},
				{"op": "sub", "poly": _rect(0.10, 0.365, 0.74, 0.39)},
				{"op": "add", "poly": _rect(0.27, 0.305, 0.57, 0.365)}]
			## The sign: an S of two bowls, each walked round most of the way, and a bar through it.
			var sign: Array = []
			for index in range(10):
				var turn: float = deg_to_rad(lerpf(25.0, 270.0, float(index) / 9.0))
				sign.append([0.42 + cos(turn) * 0.062, 0.600 - sin(turn) * 0.062])
			for index in range(1, 10):
				var turn: float = deg_to_rad(lerpf(90.0, -155.0, float(index) / 9.0))
				sign.append([0.42 + cos(turn) * 0.062, 0.724 - sin(turn) * 0.062])
			shapes.append_array(_line(sign, 0.055, "sub"))
			shapes.append({"op": "sub", "poly": _rect(0.395, 0.48, 0.445, 0.84)})
			shapes.append({"op": "sub", "circle": [0.80, 0.82, 0.19]})
			shapes.append({"op": "add", "circle": [0.80, 0.82, 0.145]})
			shapes.append({"op": "sub", "circle": [0.80, 0.82, 0.10]})
			shapes.append({"op": "add", "circle": [0.80, 0.82, 0.075]})
			return shapes
		"die":
			# A cube corner-on: three faces parted by gaps, one pip on each.
			var c := Vector2(0.5, 0.5)
			var top := _poly([[0.50, 0.04], [0.90, 0.26], [0.50, 0.48], [0.10, 0.26]])
			var left := _poly([[0.08, 0.31], [0.47, 0.53], [0.47, 0.96], [0.08, 0.74]])
			var right := _poly([[0.53, 0.53], [0.92, 0.31], [0.92, 0.74], [0.53, 0.96]])
			return [ {"op": "add", "poly": top}, {"op": "add", "poly": left}, {"op": "add", "poly": right},
				{"op": "sub", "circle": [c.x, 0.26, 0.07]},
				{"op": "sub", "circle": [0.24, 0.52, 0.06]}, {"op": "sub", "circle": [0.33, 0.77, 0.06]},
				{"op": "sub", "circle": [0.72, 0.64, 0.065]}]
		"person":
			return [ {"op": "add", "circle": [0.5, 0.30, 0.20]},
				{"op": "add", "circle": [0.5, 0.98, 0.42]},
				{"op": "sub", "poly": _rect(0.0, 0.98, 1.0, 1.4)}]
		"party":
			return [ {"op": "add", "circle": [0.32, 0.30, 0.16]}, {"op": "add", "circle": [0.32, 0.92, 0.32]},
				{"op": "add", "circle": [0.70, 0.36, 0.14]}, {"op": "add", "circle": [0.70, 0.94, 0.28]},
				{"op": "sub", "poly": _rect(0.0, 0.94, 1.0, 1.4)}]
		"crown":
			return [ {"op": "add", "poly": _poly([[0.06, 0.24], [0.30, 0.52], [0.50, 0.14], [0.70, 0.52], [0.94, 0.24], [0.86, 0.78], [0.14, 0.78]])},
				{"op": "add", "poly": _rect(0.14, 0.82, 0.86, 0.92)},
				{"op": "add", "circle": [0.06, 0.22, 0.07]}, {"op": "add", "circle": [0.50, 0.12, 0.07]}, {"op": "add", "circle": [0.94, 0.22, 0.07]}]
		"map":
			# A folded chart with a route and its end marked.
			return [ {"op": "add", "poly": _poly([[0.04, 0.16], [0.34, 0.06], [0.66, 0.16], [0.96, 0.06], [0.96, 0.84], [0.66, 0.94], [0.34, 0.84], [0.04, 0.94]])},
				{"op": "sub", "poly": _bar(Vector2(0.34, 0.10), Vector2(0.34, 0.86), 0.05)},
				{"op": "sub", "poly": _bar(Vector2(0.66, 0.14), Vector2(0.66, 0.90), 0.05)}] + \
				_line([[0.16, 0.74], [0.30, 0.52], [0.50, 0.60], [0.74, 0.34]], 0.06, "sub") + \
				[ {"op": "sub", "circle": [0.80, 0.28, 0.08]}]
		"anvil":
			return [ {"op": "add", "poly": _poly([[0.04, 0.22], [0.78, 0.22], [0.96, 0.30], [0.80, 0.44], [0.62, 0.48], [0.62, 0.66], [0.36, 0.66], [0.36, 0.48], [0.20, 0.42], [0.04, 0.34]])},
				{"op": "add", "poly": _poly([[0.26, 0.64], [0.72, 0.64], [0.84, 0.90], [0.14, 0.90]])}]
		"chest":
			return [ {"op": "add", "poly": _rect(0.08, 0.42, 0.92, 0.90)},
				{"op": "add", "circle": [0.5, 0.46, 0.42]},
				{"op": "sub", "poly": _rect(0.0, 0.46, 1.0, 0.52)},
				{"op": "sub", "poly": _rect(0.0, -0.1, 1.0, 0.20)},
				{"op": "add", "poly": _rect(0.40, 0.40, 0.60, 0.62)},
				{"op": "sub", "circle": [0.5, 0.50, 0.04]}]
		"book":
			return [ {"op": "add", "poly": _poly([[0.04, 0.20], [0.30, 0.14], [0.47, 0.22], [0.47, 0.90], [0.30, 0.82], [0.04, 0.88]])},
				{"op": "add", "poly": _poly([[0.53, 0.22], [0.70, 0.14], [0.96, 0.20], [0.96, 0.88], [0.70, 0.82], [0.53, 0.90]])},
				{"op": "sub", "poly": _bar(Vector2(0.14, 0.40), Vector2(0.38, 0.36), 0.04)},
				{"op": "sub", "poly": _bar(Vector2(0.14, 0.56), Vector2(0.38, 0.52), 0.04)},
				{"op": "sub", "poly": _bar(Vector2(0.62, 0.36), Vector2(0.86, 0.40), 0.04)},
				{"op": "sub", "poly": _bar(Vector2(0.62, 0.52), Vector2(0.86, 0.56), 0.04)}]
		"arch":
			# A tunnel mouth: a round-headed arch with the dark cut out of it.
			var outer := PackedVector2Array([Vector2(0.06, 0.96)])
			var inner := PackedVector2Array([Vector2(0.24, 0.96)])
			for index in range(15):
				var angle := PI + PI * float(index) / 14.0
				outer.append(Vector2(0.5, 0.48) + Vector2(cos(angle), sin(angle)) * 0.44)
				inner.append(Vector2(0.5, 0.52) + Vector2(cos(angle), sin(angle)) * 0.26)
			outer.append(Vector2(0.94, 0.96))
			inner.append(Vector2(0.76, 0.96))
			return [ {"op": "add", "poly": outer}, {"op": "sub", "poly": inner}]
		"question":
			return [ {"op": "add", "circle": [0.5, 0.32, 0.26]}, {"op": "sub", "circle": [0.5, 0.32, 0.13]},
				{"op": "sub", "poly": _rect(0.10, 0.34, 0.50, 0.62)},
				{"op": "add", "poly": _rect(0.43, 0.50, 0.57, 0.70)},
				{"op": "add", "poly": _poly([[0.43, 0.56], [0.62, 0.52], [0.70, 0.40], [0.57, 0.58]])},
				{"op": "add", "circle": [0.5, 0.86, 0.085]}]
		"star":
			return [ {"op": "add", "poly": _star(5, 0.48, 0.20, Vector2(0.5, 0.54))}]
		"check":
			return _line([[0.10, 0.54], [0.38, 0.80], [0.90, 0.20]], 0.16)
		"cross_out":
			return [ {"op": "add", "poly": _bar(Vector2(0.14, 0.14), Vector2(0.86, 0.86), 0.16)},
				{"op": "add", "poly": _bar(Vector2(0.86, 0.14), Vector2(0.14, 0.86), 0.16)}]
		"flame":
			return [ {"op": "add", "poly": _poly([[0.50, 0.02], [0.66, 0.26], [0.82, 0.44], [0.86, 0.66], [0.72, 0.88],
				[0.50, 0.96], [0.28, 0.88], [0.14, 0.66], [0.20, 0.42], [0.34, 0.50], [0.36, 0.28]])},
				{"op": "sub", "poly": _poly([[0.50, 0.52], [0.62, 0.70], [0.58, 0.84], [0.42, 0.84], [0.38, 0.70]])}]
		"stairs":
			return [ {"op": "add", "poly": _poly([[0.04, 0.14], [0.30, 0.14], [0.30, 0.38], [0.54, 0.38], [0.54, 0.62], [0.78, 0.62], [0.78, 0.86], [0.96, 0.86], [0.96, 0.96], [0.04, 0.96]])}]
		"scales":
			return _shapes("carat")
		"stun":
			return [ {"op": "add", "poly": _star(5, 0.28, 0.11, Vector2(0.30, 0.34))},
				{"op": "add", "poly": _star(5, 0.22, 0.09, Vector2(0.74, 0.30))},
				{"op": "add", "poly": _star(5, 0.20, 0.08, Vector2(0.52, 0.76))}]
		"drop":
			return [ {"op": "add", "poly": _poly([[0.50, 0.04], [0.78, 0.52], [0.22, 0.52]])},
				{"op": "add", "circle": [0.5, 0.64, 0.29]}]
		"lock_open":
			return [ {"op": "add", "circle": [0.66, 0.30, 0.22]}, {"op": "sub", "circle": [0.66, 0.30, 0.12]},
				{"op": "sub", "poly": _rect(0.40, 0.30, 0.92, 0.50)},
				{"op": "add", "poly": _rect(0.10, 0.44, 0.72, 0.94)},
				{"op": "sub", "circle": [0.41, 0.63, 0.07]}]
		"ladder":
			return [ {"op": "add", "poly": _rect(0.18, 0.02, 0.30, 0.98)}, {"op": "add", "poly": _rect(0.70, 0.02, 0.82, 0.98)},
				{"op": "add", "poly": _rect(0.30, 0.20, 0.70, 0.28)}, {"op": "add", "poly": _rect(0.30, 0.46, 0.70, 0.54)},
				{"op": "add", "poly": _rect(0.30, 0.72, 0.70, 0.80)}]
		"play":
			return [ {"op": "add", "poly": _poly([[0.22, 0.08], [0.90, 0.50], [0.22, 0.92]])}]
		"rise":
			return [ {"op": "add", "poly": _poly([[0.50, 0.10], [0.92, 0.58], [0.64, 0.58], [0.64, 0.92], [0.36, 0.92], [0.36, 0.58], [0.08, 0.58]])}]
		"fall":
			return [ {"op": "add", "poly": _poly([[0.36, 0.08], [0.64, 0.08], [0.64, 0.42], [0.92, 0.42], [0.50, 0.90], [0.08, 0.42], [0.36, 0.42]])}]
		"level":
			return [ {"op": "add", "poly": _rect(0.14, 0.30, 0.86, 0.42)}, {"op": "add", "poly": _rect(0.14, 0.58, 0.86, 0.70)}]
		"prev":
			return [ {"op": "add", "poly": _poly([[0.70, 0.08], [0.50, 0.08], [0.12, 0.50], [0.50, 0.92], [0.70, 0.92], [0.32, 0.50]])}]
		"next":
			return [ {"op": "add", "poly": _poly([[0.30, 0.08], [0.50, 0.08], [0.88, 0.50], [0.50, 0.92], [0.30, 0.92], [0.68, 0.50]])}]
		"wifi":
			return [ {"op": "add", "circle": [0.5, 0.92, 0.84]}, {"op": "sub", "circle": [0.5, 0.92, 0.70]},
				{"op": "add", "circle": [0.5, 0.92, 0.56]}, {"op": "sub", "circle": [0.5, 0.92, 0.42]},
				{"op": "add", "circle": [0.5, 0.92, 0.18]},
				{"op": "sub", "poly": _poly([[0.5, 0.92], [-0.6, -0.2], [-0.6, 1.2]])},
				{"op": "sub", "poly": _poly([[0.5, 0.92], [1.6, -0.2], [1.6, 1.2]])}]
		"lantern":
			# A miner's lamp: a ring to hang it by, a cap, a glass with the flame in it, a foot.
			return [ {"op": "add", "circle": [0.5, 0.13, 0.11]}, {"op": "sub", "circle": [0.5, 0.13, 0.055]},
				{"op": "add", "poly": _poly([[0.30, 0.22], [0.70, 0.22], [0.82, 0.34], [0.18, 0.34]])},
				{"op": "add", "poly": _rect(0.24, 0.34, 0.76, 0.84)},
				{"op": "sub", "poly": _rect(0.32, 0.41, 0.68, 0.78)},
				{"op": "add", "poly": _poly([[0.50, 0.44], [0.61, 0.60], [0.58, 0.73], [0.42, 0.73], [0.39, 0.60]])},
				{"op": "add", "poly": _rect(0.16, 0.84, 0.84, 0.95)}]
		"gear":
			var teeth: Array = [ {"op": "add", "circle": [0.5, 0.5, 0.31]}]
			for index in range(8):
				var way := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
				teeth.append({"op": "add", "poly": _bar(Vector2(0.5, 0.5) + way * 0.26, Vector2(0.5, 0.5) + way * 0.46, 0.15)})
			teeth.append({"op": "sub", "circle": [0.5, 0.5, 0.13]})
			return teeth
		"flag":
			return [ {"op": "add", "poly": _rect(0.16, 0.06, 0.25, 0.96)},
				{"op": "add", "poly": _poly([[0.25, 0.08], [0.90, 0.28], [0.25, 0.50]])}]
		"door":
			return [ {"op": "add", "poly": _rect(0.18, 0.04, 0.82, 0.96)}, {"op": "sub", "poly": _rect(0.27, 0.12, 0.73, 0.96)},
				{"op": "add", "poly": _poly([[0.27, 0.12], [0.62, 0.20], [0.62, 0.96], [0.27, 0.96]])},
				{"op": "sub", "circle": [0.54, 0.58, 0.045]}]
	return []

# --- rasterising --------------------------------------------------------------

static func _inside(shapes: Array, point: Vector2) -> bool:
	var covered := false
	for shape in shapes:
		var hit: bool
		if shape.has("circle"):
			var circle: Array = shape.circle
			hit = point.distance_to(Vector2(circle[0], circle[1])) <= float(circle[2])
		else:
			hit = Geometry2D.is_point_in_polygon(point, shape.poly)
		if hit:
			covered = shape.op == "add"
	return covered

## Coverage is sampled on a grid this many times finer than the glyph, then boxed down by
## two native halvings. Scanlines fill whole runs of samples with one native call, which is
## what took a 96-pixel glyph from a sixth of a second to a few milliseconds.
const SUPER := 4
## The pixel sizes glyphs are actually baked at. A request is baked at the next size up and
## drawn down, so a screen full of slightly different sizes still shares a handful of masks.
const BAKED_SIZES: Array = [12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128]

static func baked_size(edge: float) -> int:
	for candidate in BAKED_SIZES:
		if float(candidate) >= edge:
			return int(candidate)
	return 128

static func rainbow_at(t: float, saturation: float = 0.32) -> Color:
	## The sweep off the wheel that Resonance and Opal are both drawn with. Neither is any
	## one color — Resonance because it is a rail ringing, an opal because it is the one
	## stone whose color is not its own — and both would otherwise read as the near-white
	## of a White gem. Pale by default, because it is usually carrying letters of text; a
	## mark being baked asks for more, since it has no shape of a word to hold it together.
	return Color.from_hsv(0.02 + 0.8 * clampf(t, 0.0, 1.0), saturation, 0.99)

static func texture(glyph: String, edge: int, rainbow: bool = false) -> ImageTexture:
	## White with real alpha, so one mask tints to any color without a second bake. A
	## rainbow mark is the exception: the sweep is baked into it, and whatever tints it
	## afterwards has to be white or it would flatten the thing back to one color.
	edge = clampi(edge, 8, 128)
	var tag := "%s|%d%s" % [glyph, edge, "|r" if rainbow else ""]
	var cached: ImageTexture = _cache.get(tag, null)
	if cached != null:
		return cached
	var shapes: Array = _shapes(glyph)
	var span: int = edge * SUPER
	var image := Image.create(span, span, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for shape in shapes:
		var ink := Color(1, 1, 1, 1) if str(shape.op) == "add" else Color(1, 1, 1, 0)
		if shape.has("circle"):
			_fill_circle(image, span, shape.circle, ink)
		else:
			_fill_polygon(image, span, shape.poly, ink)
	if rainbow:
		## Laid across the mark corner to corner rather than straight across, so a glyph
		## that is mostly one upright bar still shows more than one color — and fitted to
		## the ink rather than to the square it sits in, or a small compact mark would take
		## one narrow slice of the wheel and come out looking like a green gem.
		var lo: int = span * 2
		var hi: int = 0
		for y in range(span):
			for x in range(span):
				if image.get_pixel(x, y).a <= 0.0:
					continue
				lo = mini(lo, x + y)
				hi = maxi(hi, x + y)
		var reach: float = float(maxi(1, hi - lo))
		for y in range(span):
			for x in range(span):
				var was: Color = image.get_pixel(x, y)
				if was.a <= 0.0:
					continue
				var lit: Color = rainbow_at(float(x + y - lo) / reach, 0.62)
				image.set_pixel(x, y, Color(lit.r, lit.g, lit.b, was.a))
	image.shrink_x2()
	image.shrink_x2()
	image.generate_mipmaps()
	var built := ImageTexture.create_from_image(image)
	_cache[tag] = built
	return built

static func _fill_circle(image: Image, span: int, circle: Array, ink: Color) -> void:
	var cx: float = float(circle[0])
	var cy: float = float(circle[1])
	var r: float = float(circle[2])
	var first: int = maxi(0, int(floor((cy - r) * span - 0.5)))
	var last: int = mini(span - 1, int(ceil((cy + r) * span - 0.5)))
	for y in range(first, last + 1):
		var dy: float = (float(y) + 0.5) / float(span) - cy
		if dy * dy > r * r:
			continue
		var half: float = sqrt(r * r - dy * dy)
		var x0: int = maxi(0, int(ceil((cx - half) * span - 0.5)))
		var x1: int = mini(span - 1, int(floor((cx + half) * span - 0.5)))
		if x1 >= x0:
			image.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), ink)

static func _fill_polygon(image: Image, span: int, poly: PackedVector2Array, ink: Color) -> void:
	## Even-odd scanlines. Each edge only visits the rows it crosses, so a shape costs about
	## twice its height rather than its height times its edge count.
	var count: int = poly.size()
	if count < 3:
		return
	var top: float = INF
	var bottom: float = - INF
	for point in poly:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var first: int = maxi(0, int(ceil(top * span - 0.5)))
	var last: int = mini(span - 1, int(floor(bottom * span - 0.5)))
	if last < first:
		return
	var rows: Array = []
	rows.resize(last - first + 1)
	for index in range(rows.size()):
		rows[index] = []
	for index in range(count):
		var a: Vector2 = poly[index]
		var b: Vector2 = poly[(index + 1) % count]
		if is_equal_approx(a.y, b.y):
			continue
		var low: Vector2 = a if a.y < b.y else b
		var high: Vector2 = b if a.y < b.y else a
		## Half-open in y, so a vertex shared by two edges is crossed exactly once.
		var y0: int = maxi(first, int(ceil(low.y * span - 0.5)))
		var y1: int = mini(last, int(ceil(high.y * span - 0.5)) - 1)
		var slope: float = (high.x - low.x) / (high.y - low.y)
		for y in range(y0, y1 + 1):
			var py: float = (float(y) + 0.5) / float(span)
			rows[y - first].append(low.x + (py - low.y) * slope)
	for index in range(rows.size()):
		var crossings: Array = rows[index]
		if crossings.size() < 2:
			continue
		crossings.sort()
		var y: int = first + index
		var pair: int = 0
		while pair + 1 < crossings.size():
			var x0: int = maxi(0, int(ceil(float(crossings[pair]) * span - 0.5)))
			var x1: int = mini(span - 1, int(floor(float(crossings[pair + 1]) * span - 0.5)))
			if x1 >= x0:
				image.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), ink)
			pair += 2

static func hint(glyph: String) -> String:
	return str(HINTS.get(glyph, ""))

static func known(glyph: String) -> bool:
	return not _shapes(glyph).is_empty()

static func glyph(parent: Node, name: String, edge: float, tint: Color, tooltip: String = "", rainbow: bool = false) -> TextureRect:
	## Places one pictograph. It answers the mouse itself so the sentence behind the
	## picture is always one hover away, even inside a row that is otherwise inert.
	var image := TextureRect.new()
	## Baked a size up and drawn down with mipmaps, so a scaled-up window stays crisp.
	image.texture = texture(name, baked_size(edge * 1.5), rainbow)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size = Vector2(edge, edge)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## A rainbow mark carries its own color and only ever takes the caller's alpha.
	image.modulate = Color(1.0, 1.0, 1.0, tint.a) if rainbow else tint
	image.mouse_filter = Control.MOUSE_FILTER_PASS
	image.tooltip_text = tooltip if not tooltip.is_empty() else hint(name)
	parent.add_child(image)
	return image

static func release() -> void:
	## Drops the generated masks so nothing outlives the interface.
	_cache.clear()
