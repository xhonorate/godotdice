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
## panel colour. Masks are white, so one texture serves every tint; the cache is keyed
## by glyph and pixel size and dropped with `release()` alongside the rest of the kit.

const SAMPLES := 3

static var _cache: Dictionary = {}

## Hover text. A player who does not recognise a pictograph should never have to guess,
## so every glyph carries the sentence that explains it wherever it is placed.
const HINTS := {
	"carat": "Carat — the gem's overall strength. It multiplies the whole effect.",
	"clarity": "Clarity — a flat bonus that does not depend on your roll. Higher ranks also make the gem easier to activate.",
	"cut": "Cut — multiplies what the dice contribute, so it is worth most on attacks.",
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
	return [{"op": "add", "poly": _rect(x0, y0, x1, y1)},
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
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		raw.append(point)
		peak = maxf(peak, point.length())
	for point in raw:
		built.append(centre + Vector2(point) * (radius / peak))
	return built

static func _shield_ring(centre: Vector2, half_width: float, half_height: float, thickness: float) -> Array:
	return [{"op": "add", "poly": _shield(centre, half_width, half_height)},
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
	## second group reads apart from the first even tinted one colour.
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
			return [{"op": "add", "circle": [0.5, 0.115, 0.062]},
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
			return [{"op": "add", "poly": _star(6, 0.400, 0.062, Vector2(0.430, 0.550))},
				{"op": "add", "poly": _star(6, 0.170, 0.026, Vector2(0.820, 0.200))},
				{"op": "add", "poly": _star(6, 0.112, 0.018, Vector2(0.135, 0.825))}]
		"cut":
			# A four-point throwing star with a real pierced centre.
			return [{"op": "add", "poly": _star(4, 0.495, 0.205)},
				{"op": "sub", "circle": [0.5, 0.5, 0.118]}]
		"high", "low":
			var up := glyph == "high"
			var head: Array = [[0.845, 0.075], [0.995, 0.400], [0.695, 0.400]] if up else \
				[[0.845, 0.925], [0.995, 0.600], [0.695, 0.600]]
			var shaft: PackedVector2Array = _rect(0.790, 0.380, 0.900, 0.930) if up else _rect(0.790, 0.070, 0.900, 0.620)
			return _ring(0.030, 0.170, 0.630, 0.830, 0.105) + \
				[{"op": "add", "poly": _poly(head)}, {"op": "add", "poly": shaft}]
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
				+ [{"op": "add", "poly": _bar(Vector2(0.43, 0.86), Vector2(0.57, 0.14), 0.07)}]
		"face":
			return _dice([[0.08, 0.08]], 0.84, 0.09, []) \
				+ [{"op": "add", "poly": _poly([[0.5, 0.26], [0.74, 0.5], [0.5, 0.74], [0.26, 0.5]])},
					{"op": "sub", "poly": _poly([[0.5, 0.38], [0.62, 0.5], [0.5, 0.62], [0.38, 0.5]])}]
		"total_high", "total_low":
			var up := glyph == "total_high"
			return _moved(_shapes("sum"), Vector2(-0.02, 0.06), 0.66) + [{"op": "add", "poly": _poly(
				[[0.82, 0.18], [1.0, 0.48], [0.64, 0.48]] if up else [[0.82, 0.82], [1.0, 0.52], [0.64, 0.52]])}]
		"peak":
			return _dice([[0.04, 0.40]], 0.52, 0.085, [[0.5, 0.5]]) \
				+ [{"op": "add", "poly": _rect(0.0, 0.22, 0.60, 0.30)},
					{"op": "add", "poly": _poly([[0.82, 0.10], [1.0, 0.42], [0.64, 0.42]])},
					{"op": "add", "poly": _rect(0.77, 0.40, 0.87, 0.92)}]
		"climb":
			return _moved(_shapes("reroll"), Vector2(-0.04, 0.12), 0.72) + [
				{"op": "add", "poly": _poly([[0.84, 0.08], [1.0, 0.36], [0.68, 0.36]])},
				{"op": "add", "poly": _rect(0.79, 0.34, 0.89, 0.88)}]
		"once":
			return [{"op": "add", "circle": [0.5, 0.5, 0.47]}, {"op": "sub", "circle": [0.5, 0.5, 0.36]},
				{"op": "add", "poly": _rect(0.44, 0.24, 0.57, 0.76)},
				{"op": "add", "poly": _poly([[0.44, 0.24], [0.57, 0.24], [0.34, 0.38], [0.34, 0.30]])}]
		"lock":
			return [{"op": "add", "circle": [0.5, 0.36, 0.25]}, {"op": "sub", "circle": [0.5, 0.36, 0.15]},
				{"op": "sub", "poly": _rect(0.2, 0.36, 0.8, 0.5)},
				{"op": "add", "poly": _rect(0.18, 0.44, 0.82, 0.94)},
				{"op": "sub", "circle": [0.5, 0.63, 0.07]},
				{"op": "sub", "poly": _rect(0.465, 0.63, 0.535, 0.82)}]
		"sum":
			return [{"op": "add", "poly": _poly([
				[0.140, 0.080], [0.860, 0.080], [0.860, 0.245], [0.425, 0.245], [0.640, 0.500],
				[0.425, 0.755], [0.860, 0.755], [0.860, 0.920], [0.140, 0.920], [0.395, 0.500]])}]
		"shield":
			return [{"op": "add", "poly": _poly([
				[0.500, 0.050], [0.925, 0.205], [0.925, 0.525], [0.500, 0.950], [0.075, 0.525], [0.075, 0.205]])},
				{"op": "sub", "poly": _poly([
				[0.500, 0.215], [0.790, 0.320], [0.790, 0.500], [0.500, 0.790], [0.210, 0.500], [0.210, 0.320]])}]
		"hit":
			return [{"op": "add", "poly": _star(8, 0.490, 0.150)},
				{"op": "add", "circle": [0.5, 0.5, 0.215]}]
		"target":
			return [{"op": "add", "circle": [0.5, 0.5, 0.465]},
				{"op": "sub", "circle": [0.5, 0.5, 0.335]},
				{"op": "add", "circle": [0.5, 0.5, 0.165]}]
		"count":
			return [{"op": "add", "poly": _rect(0.095, 0.215, 0.285, 0.865)},
				{"op": "add", "poly": _rect(0.405, 0.215, 0.595, 0.865)},
				{"op": "add", "poly": _rect(0.715, 0.215, 0.905, 0.865)}]
		"run":
			return [{"op": "add", "poly": _rect(0.075, 0.615, 0.285, 0.925)},
				{"op": "add", "poly": _rect(0.395, 0.375, 0.605, 0.925)},
				{"op": "add", "poly": _rect(0.715, 0.135, 0.925, 0.925)}]
		"reroll":
			# A ring broken at the top with an arrowhead on the open end: the mark for
			# "again". The gap is cut before the head is added, so the head survives it.
			return [{"op": "add", "circle": [0.5, 0.54, 0.44]},
				{"op": "sub", "circle": [0.5, 0.54, 0.26]},
				{"op": "sub", "poly": _rect(0.44, -0.05, 1.05, 0.34)},
				{"op": "add", "poly": _poly([[0.30, 0.00], [0.76, 0.17], [0.30, 0.34]])}]
	return _emblem_shapes(glyph)

## The emblem etched into a gem's face, one per skill. These are read at the size of a
## thumbnail and through a bevel, so every one is a bold silhouette with no thin detail.
const SKILL_EMBLEMS := {
	"STRIKE": "sword", "BLOCK": "shield", "HEAL": "flask", "MULTISTRIKE": "slashes",
	"LUCKYSTRIKE": "seven", "HEAVYSTRIKE": "hammer", "BLESSING": "sun",
	"SHIELDBASH": "shield_burst", "STUN": "bolt", "BULWARK": "rampart",
	"DRAINSTRIKE": "drain", "INTERPOSE": "two_shields", "MEND": "cross",
	"SUNDER": "split_shield", "ARC_BURST": "arcs", "VENOM": "skull",
	"EVEN_TEMPO": "hourglass", "PRECISION": "crosshair", "LIFELINE": "pulse",
	"GLIMMER": "spark", "REFRACT": "prism", "SECOND_SIGHT": "eye", "ECHO": "copy",
	"FACET": "rose", "QUARTET": "quad", "BASTION": "broken_chain", "PURGE": "clean_drop",
	"GRAFT": "knot", "HEXBOLT": "thorn", "MIASMA": "cloud", "ENERVATE": "wilt",
	"TITHE": "coin", "MINT": "coins", "WAGER": "coin_fall"}

## The same marks for the other side's actions. An enemy carries no stone, but its routine
## reaches a fixed set of named moves, and the party reads that roster the way it reads a
## loadout — so each one needs a silhouette of its own.
const ENEMY_EMBLEMS := {
	"SHELL_UP": "rampart", "CLAW": "slashes", "SHARD": "spark", "RESTORE": "cross",
	"BARBED_DART": "thorn", "FORTIFY": "rampart", "HAMMER": "hammer",
	"REFLECTION": "prism", "TRACK": "crosshair", "POUNCE": "slashes",
	"SLAM": "hammer", "ABSORB": "drain", "REFRACTION": "prism",
	"SHATTER": "split_shield", "MENDING_GLASS": "cross", "HIGH_TIDE": "arcs",
	"LOW_TIDE": "arcs", "ECLIPSE": "sun"}

## A hero's passive and signature wear marks too, so they sit on the board like stones.
const HERO_EMBLEMS := {
	"STAND_FIRM": "rampart", "CALCULATED_RISK": "prism", "SECOND_THOUGHT": "eye",
	"UNBREAKABLE_VOW": "shield_burst", "LONG_ODDS": "seven", "MASTER_PLAN": "crosshair"}

static func emblem(skill_key: String) -> String:
	var key := skill_key.to_upper()
	return str(SKILL_EMBLEMS.get(key, ENEMY_EMBLEMS.get(key, HERO_EMBLEMS.get(key, "sword"))))

static func _emblem_shapes(glyph: String) -> Array:
	match glyph:
		"sword":
			return [{"op": "add", "poly": _poly([[0.50, 0.02], [0.61, 0.19], [0.61, 0.60], [0.39, 0.60], [0.39, 0.19]])},
				{"op": "add", "poly": _rect(0.20, 0.60, 0.80, 0.70)},
				{"op": "add", "poly": _rect(0.43, 0.70, 0.57, 0.89)},
				{"op": "add", "circle": [0.5, 0.92, 0.075]}]
		"heart":
			return [{"op": "add", "poly": _heart(Vector2(0.5, 0.50), 0.48)}]
		"flask":
			return [{"op": "add", "poly": _rect(0.355, 0.02, 0.645, 0.115)},
				{"op": "add", "poly": _rect(0.435, 0.02, 0.565, 0.30)},
				{"op": "add", "poly": _poly([[0.435, 0.26], [0.565, 0.26], [0.80, 0.66], [0.20, 0.66]])},
				{"op": "add", "circle": [0.5, 0.645, 0.295]}]
		"slashes":
			return _line([[0.10, 0.86], [0.34, 0.14]], 0.15) \
				+ _line([[0.38, 0.86], [0.62, 0.14]], 0.15) \
				+ _line([[0.66, 0.86], [0.90, 0.14]], 0.15)
		"seven":
			return [{"op": "add", "poly": _poly([[0.15, 0.08], [0.87, 0.08], [0.87, 0.25],
				[0.60, 0.93], [0.38, 0.93], [0.65, 0.27], [0.15, 0.27]])}]
		"hammer":
			var haft := Vector2(0.605, -0.796)
			var head := Vector2(0.74, 0.22)
			return [{"op": "add", "poly": _bar(Vector2(0.20, 0.94), head, 0.135)},
				{"op": "add", "poly": _bar(head - haft.orthogonal() * 0.24, head + haft.orthogonal() * 0.24, 0.30)}]
		"sun":
			var rays: Array = [{"op": "add", "circle": [0.5, 0.5, 0.235]}]
			for index in 8:
				var angle := TAU * float(index) / 8.0
				var step := Vector2(cos(angle), sin(angle))
				rays.append({"op": "add", "poly": _bar(Vector2(0.5, 0.5) + step * 0.31,
					Vector2(0.5, 0.5) + step * 0.48, 0.11)})
			return rays
		"shield":
			return [{"op": "add", "poly": _shield(Vector2(0.5, 0.5), 0.425, 0.45)},
				{"op": "sub", "poly": _shield(Vector2(0.5, 0.5), 0.275, 0.29)}]
		"shield_burst":
			return _shield_ring(Vector2(0.40, 0.57), 0.37, 0.41, 0.115) \
				+ [{"op": "add", "poly": _star(4, 0.29, 0.065, Vector2(0.80, 0.19))}]
		"two_shields":
			return _shield_ring(Vector2(0.67, 0.37), 0.30, 0.34, 0.10) \
				+ [{"op": "sub", "poly": _shield(Vector2(0.36, 0.62), 0.38, 0.42)}] \
				+ _shield_ring(Vector2(0.36, 0.62), 0.33, 0.37, 0.10)
		"bolt":
			return [{"op": "add", "poly": _poly([[0.62, 0.03], [0.22, 0.54], [0.45, 0.54],
				[0.34, 0.97], [0.78, 0.43], [0.53, 0.43]])}]
		"rampart":
			return [{"op": "add", "poly": _rect(0.06, 0.20, 0.94, 0.92)},
				{"op": "sub", "poly": _rect(0.24, 0.14, 0.40, 0.40)},
				{"op": "sub", "poly": _rect(0.60, 0.14, 0.76, 0.40)},
				{"op": "sub", "poly": _rect(0.44, 0.52, 0.56, 0.94)}]
		"drain":
			return [{"op": "add", "poly": _poly([[0.50, 0.04], [0.76, 0.48], [0.24, 0.48]])},
				{"op": "add", "circle": [0.5, 0.50, 0.26]},
				{"op": "add", "poly": _rect(0.20, 0.86, 0.80, 0.96)}]
		"cross":
			return [{"op": "add", "poly": _rect(0.39, 0.08, 0.61, 0.92)},
				{"op": "add", "poly": _rect(0.08, 0.39, 0.92, 0.61)}]
		"split_shield":
			return [{"op": "add", "poly": _shield(Vector2(0.5, 0.5), 0.44, 0.47)},
				{"op": "sub", "poly": _poly([[0.42, 0.00], [0.60, 0.30], [0.42, 0.50],
					[0.62, 0.74], [0.44, 1.00], [0.58, 1.00], [0.76, 0.74], [0.56, 0.50],
					[0.74, 0.30], [0.56, 0.00]])}]
		"arcs":
			return [{"op": "add", "circle": [0.06, 0.5, 0.90]}, {"op": "sub", "circle": [0.06, 0.5, 0.76]},
				{"op": "add", "circle": [0.06, 0.5, 0.60]}, {"op": "sub", "circle": [0.06, 0.5, 0.46]},
				{"op": "add", "circle": [0.06, 0.5, 0.30]}, {"op": "sub", "circle": [0.06, 0.5, 0.16]},
				{"op": "sub", "poly": _rect(-0.2, -0.2, 0.16, 1.2)}]
		"skull":
			return [{"op": "add", "circle": [0.5, 0.42, 0.35]},
				{"op": "add", "poly": _rect(0.29, 0.60, 0.71, 0.88)},
				{"op": "sub", "circle": [0.37, 0.41, 0.115]},
				{"op": "sub", "circle": [0.63, 0.41, 0.115]},
				{"op": "sub", "poly": _poly([[0.50, 0.48], [0.57, 0.61], [0.43, 0.61]])},
				{"op": "sub", "poly": _rect(0.43, 0.66, 0.47, 0.90)},
				{"op": "sub", "poly": _rect(0.53, 0.66, 0.57, 0.90)}]
		"hourglass":
			return [{"op": "add", "poly": _poly([[0.15, 0.10], [0.85, 0.10], [0.50, 0.50]])},
				{"op": "add", "poly": _poly([[0.50, 0.50], [0.85, 0.90], [0.15, 0.90]])},
				{"op": "add", "poly": _rect(0.10, 0.03, 0.90, 0.12)},
				{"op": "add", "poly": _rect(0.10, 0.88, 0.90, 0.97)}]
		"crosshair":
			return [{"op": "add", "circle": [0.5, 0.5, 0.44]},
				{"op": "sub", "circle": [0.5, 0.5, 0.31]},
				{"op": "add", "poly": _rect(0.455, 0.01, 0.545, 0.30)},
				{"op": "add", "poly": _rect(0.455, 0.70, 0.545, 0.99)},
				{"op": "add", "poly": _rect(0.01, 0.455, 0.30, 0.545)},
				{"op": "add", "poly": _rect(0.70, 0.455, 0.99, 0.545)},
				{"op": "add", "circle": [0.5, 0.5, 0.105]}]
		"pulse":
			return [{"op": "add", "poly": _heart(Vector2(0.5, 0.48), 0.48)}] \
				+ _line([[0.00, 0.52], [0.28, 0.52], [0.37, 0.33], [0.50, 0.72], [0.60, 0.47], [1.00, 0.47]], 0.105, "sub")
		"spark":
			# One bright point and two lesser ones: light coming off a stone that was
			# only polished, not recut.
			return [{"op": "add", "poly": _star(4, 0.42, 0.105, Vector2(0.44, 0.48))},
				{"op": "add", "poly": _star(4, 0.17, 0.042, Vector2(0.86, 0.15))},
				{"op": "add", "circle": [0.84, 0.80, 0.085]}]
		"prism":
			# A triangle throwing three rays out of one face — white light going in and
			# coming out spread, which is exactly what the skill does to a die.
			var rays: Array = [{"op": "add", "poly": _poly([[0.32, 0.05], [0.61, 0.85], [0.03, 0.85]])},
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
			return [{"op": "add", "poly": lens},
				{"op": "sub", "circle": [0.5, 0.5, 0.215]},
				{"op": "add", "circle": [0.5, 0.5, 0.105]}]
		"copy":
			# One square behind another: the mark every interface uses for "again".
			return _ring(0.30, 0.04, 0.96, 0.70, 0.10) \
				+ [{"op": "sub", "poly": _rect(0.04, 0.30, 0.70, 0.96)}] \
				+ _ring(0.04, 0.30, 0.70, 0.96, 0.10)
		"rose":
			# A rose-cut stone from directly above: a hexagonal girdle divided into the six
			# crown facets that rise to its point. The facet lines are cut out of the solid,
			# so the mark survives being tinted one colour and shrunk to a thumbnail.
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
			var built: Array = [{"op": "add", "poly": outer}]
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
			return [{"op": "add", "circle": [0.20, 0.50, 0.235]}, {"op": "sub", "circle": [0.20, 0.50, 0.125]},
				{"op": "add", "circle": [0.80, 0.50, 0.235]}, {"op": "sub", "circle": [0.80, 0.50, 0.125]},
				{"op": "add", "poly": _bar(Vector2(0.38, 0.38), Vector2(0.50, 0.25), 0.09)},
				{"op": "add", "poly": _bar(Vector2(0.62, 0.62), Vector2(0.50, 0.75), 0.09)}]
		"clean_drop":
			# A droplet struck through: the mark for poison taken back out.
			return [{"op": "add", "poly": _poly([[0.44, 0.06], [0.76, 0.52], [0.70, 0.76], [0.18, 0.76], [0.12, 0.52]])},
				{"op": "add", "circle": [0.44, 0.62, 0.30]},
				{"op": "sub", "poly": _bar(Vector2(0.06, 0.94), Vector2(0.94, 0.06), 0.15)},
				{"op": "add", "poly": _bar(Vector2(0.10, 0.90), Vector2(0.90, 0.10), 0.095)}]
		"knot":
			# Two stocks joined into one shoot, with the binding across the join. Crossing
			# them instead read as a scribbled X, which says nothing about grafting.
			return _line([[0.10, 0.95], [0.50, 0.58]], 0.13) \
				+ _line([[0.90, 0.95], [0.50, 0.58]], 0.13) \
				+ [{"op": "add", "poly": _bar(Vector2(0.50, 0.62), Vector2(0.50, 0.06), 0.13)},
					{"op": "sub", "poly": _rect(0.06, 0.44, 0.94, 0.52)},
					{"op": "add", "poly": _rect(0.18, 0.40, 0.82, 0.50)}]
		"thorn":
			# A barb, hooked and backswept, so it reads as a hex rather than a plain spike.
			return [{"op": "add", "poly": _poly([[0.86, 0.05], [0.58, 0.62], [0.20, 0.95],
				[0.34, 0.52], [0.60, 0.30]])},
				{"op": "add", "poly": _bar(Vector2(0.62, 0.28), Vector2(0.94, 0.44), 0.11)},
				{"op": "add", "circle": [0.20, 0.95, 0.075]}]
		"cloud":
			# A lumpy cloud with three drops falling out of it.
			return [{"op": "add", "circle": [0.30, 0.36, 0.22]},
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
			return [{"op": "add", "circle": [0.5, 0.5, 0.47]},
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
			return [{"op": "add", "circle": [0.5, 0.5, 0.47]},
				{"op": "sub", "circle": [0.5, 0.5, 0.35]},
				{"op": "add", "poly": _rect(0.42, 0.16, 0.58, 0.62)},
				{"op": "add", "poly": _poly([[0.50, 0.88], [0.24, 0.52], [0.76, 0.52]])}]
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

static func texture(glyph: String, edge: int) -> ImageTexture:
	## White with real alpha, so one mask tints to any colour without a second bake.
	edge = clampi(edge, 8, 128)
	var tag := "%s|%d" % [glyph, edge]
	var cached: ImageTexture = _cache.get(tag, null)
	if cached != null:
		return cached
	var shapes: Array = _shapes(glyph)
	var image := Image.create(edge, edge, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	if not shapes.is_empty():
		var step := 1.0 / float(edge)
		for y in edge:
			for x in edge:
				var covered := 0
				for sy in SAMPLES:
					for sx in SAMPLES:
						var point := Vector2(
							(float(x) + (float(sx) + 0.5) / float(SAMPLES)) * step,
							(float(y) + (float(sy) + 0.5) / float(SAMPLES)) * step)
						if _inside(shapes, point):
							covered += 1
				if covered > 0:
					image.set_pixel(x, y, Color(1, 1, 1, float(covered) / float(SAMPLES * SAMPLES)))
	var built := ImageTexture.create_from_image(image)
	_cache[tag] = built
	return built

static func hint(glyph: String) -> String:
	return str(HINTS.get(glyph, ""))

static func known(glyph: String) -> bool:
	return not _shapes(glyph).is_empty()

static func glyph(parent: Node, name: String, edge: float, tint: Color, tooltip: String = "") -> TextureRect:
	## Places one pictograph. It answers the mouse itself so the sentence behind the
	## picture is always one hover away, even inside a row that is otherwise inert.
	var image := TextureRect.new()
	image.texture = texture(name, int(round(edge)))
	image.custom_minimum_size = Vector2(edge, edge)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_PASS
	image.tooltip_text = tooltip if not tooltip.is_empty() else hint(name)
	parent.add_child(image)
	return image

static func release() -> void:
	## Drops the generated masks so nothing outlives the interface.
	_cache.clear()
