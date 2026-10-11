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

static func _fitted(shapes: Array, margin: float = 0.06) -> Array:
	## Scaled and centred so every added part keeps `margin` clear of the square's edge on
	## its longer side. The etch blurs the mask before it bevels it, so ink drawn right up to
	## the edge comes out cut off on the stone.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for shape in shapes:
		if shape.op != "add":
			continue
		if shape.has("circle"):
			var circle: Array = shape.circle
			lo = lo.min(Vector2(circle[0] - circle[2], circle[1] - circle[2]))
			hi = hi.max(Vector2(circle[0] + circle[2], circle[1] + circle[2]))
		else:
			for point in shape.poly:
				lo = lo.min(point)
				hi = hi.max(point)
	var scale: float = (1.0 - margin * 2.0) / maxf(hi.x - lo.x, hi.y - lo.y)
	return _moved(shapes, Vector2(0.5, 0.5) - (lo + hi) * 0.5 * scale, scale)

static func _turned(shapes: Array, angle: float) -> Array:
	## Another glyph rotated about the middle of the square, so a mark can be borrowed at a tilt.
	var middle := Vector2(0.5, 0.5)
	var turned: Array = []
	for shape in shapes:
		if shape.has("circle"):
			var circle: Array = shape.circle
			var at := (Vector2(circle[0], circle[1]) - middle).rotated(angle) + middle
			turned.append({"op": shape.op, "circle": [at.x, at.y, circle[2]]})
		else:
			var poly := PackedVector2Array()
			for point in shape.poly:
				poly.append((point - middle).rotated(angle) + middle)
			turned.append({"op": shape.op, "poly": poly})
	return turned

static func _rounded(x0: float, y0: float, x1: float, y1: float, radius: float) -> PackedVector2Array:
	## A rectangle with its corners rounded off, a quarter circle at each.
	var built := PackedVector2Array()
	for corner in [[x1 - radius, y0 + radius, -PI * 0.5], [x1 - radius, y1 - radius, 0.0], [x0 + radius, y1 - radius, PI * 0.5], [x0 + radius, y0 + radius, PI]]:
		for step in 7:
			var angle: float = float(corner[2]) + PI * 0.5 * float(step) / 6.0
			built.append(Vector2(corner[0], corner[1]) + Vector2(cos(angle), sin(angle)) * radius)
	return built

static func _point(at) -> Vector2:
	return at if at is Vector2 else Vector2(float(at[0]), float(at[1]))

static func _stroke(points: Array, thickness: float, op := "add") -> Array:
	## A polyline with round joints and round ends, so a stroke never ends on a square corner.
	var built: Array = []
	for index in range(points.size() - 1):
		built.append({"op": op, "poly": _bar(_point(points[index]), _point(points[index + 1]), thickness)})
	for at in points:
		var point := _point(at)
		built.append({"op": op, "circle": [point.x, point.y, thickness * 0.5]})
	return built

static func _curve(from_point, control, to_point, steps: int = 12) -> Array:
	## Points along a quadratic curve, both ends included.
	var a := _point(from_point)
	var b := _point(control)
	var c := _point(to_point)
	var points: Array = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		points.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return points

static func _diamond(centre: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	return PackedVector2Array([centre + Vector2(0.0, -half_height), centre + Vector2(half_width, 0.0),
		centre + Vector2(0.0, half_height), centre + Vector2(-half_width, 0.0)])

static func _ellipse(centre: Vector2, radius_x: float, radius_y: float, turn: float = 0.0, steps: int = 48) -> PackedVector2Array:
	var built := PackedVector2Array()
	for index in steps:
		var angle := TAU * float(index) / float(steps)
		built.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y).rotated(turn))
	return built

static func _along(centre: Vector2, radius_x: float, radius_y: float, from_angle: float, to_angle: float, steps: int = 32) -> Array:
	## Points along an elliptical arc, both ends included.
	var points: Array = []
	for index in steps + 1:
		var angle := lerpf(from_angle, to_angle, float(index) / float(steps))
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points

static func _band(centre: Vector2, radius_x: float, radius_y: float, thickness: float, from_angle: float, to_angle: float, turn: float = 0.0, steps: int = 40) -> PackedVector2Array:
	## A stretch of an elliptical ring, `thickness` wide about its centre line. Run all the
	## way round it is a whole ring, its hole left by the even-odd fill.
	var built := PackedVector2Array()
	for index in steps + 1:
		var angle := lerpf(from_angle, to_angle, float(index) / float(steps))
		built.append(centre + Vector2(cos(angle) * (radius_x + thickness * 0.5), sin(angle) * (radius_y + thickness * 0.5)).rotated(turn))
	for index in steps + 1:
		var angle := lerpf(to_angle, from_angle, float(index) / float(steps))
		built.append(centre + Vector2(cos(angle) * (radius_x - thickness * 0.5), sin(angle) * (radius_y - thickness * 0.5)).rotated(turn))
	return built

static func _arc(centre: Vector2, radius: float, thickness: float, from_angle: float, to_angle: float, op := "add") -> Array:
	## A circular arc stroke with round caps.
	var built: Array = [ {"op": op, "poly": _band(centre, radius, radius, thickness, from_angle, to_angle)}]
	for angle in [from_angle, to_angle]:
		built.append({"op": op, "circle": [centre.x + cos(angle) * radius, centre.y + sin(angle) * radius, thickness * 0.5]})
	return built

static func _drop(tip: Vector2, centre: Vector2, radius: float, steps: int = 40) -> PackedVector2Array:
	## A teardrop whose sides leave the tip as true tangents to the round, so the two meet
	## in one smooth line instead of a corner where a triangle overlaps a circle.
	var base := (tip - centre).angle()
	var half := acos(clampf(radius / centre.distance_to(tip), -1.0, 1.0))
	var built := PackedVector2Array([tip])
	for index in steps + 1:
		var angle := lerpf(base + half, base - half + TAU, float(index) / float(steps))
		built.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return built

static func _blaze(base: Vector2, width: float, height: float, flip: bool = false) -> PackedVector2Array:
	## A flame standing on `base`: round at the foot, one tall tip and a smaller tongue licking
	## off its side. A plain teardrop tip up reads as water at a thumbnail; the tongue is what
	## makes it fire.
	var path: Array = [[0.0, 0.0], [0.50, 0.0], [0.48, 0.34], [0.46, 0.66], [0.10, 1.0], [0.20, 0.72], [-0.02, 0.56],
		[-0.10, 0.68], [-0.26, 0.76], [-0.52, 0.42], [-0.44, 0.22], [-0.36, 0.0], [0.0, 0.0]]
	var side := -1.0 if flip else 1.0
	var built := PackedVector2Array()
	for index in range(0, path.size() - 2, 2):
		var points := _curve(path[index], path[index + 1], path[index + 2], 8)
		for step in range(0 if index == 0 else 1, points.size()):
			var point: Vector2 = points[step]
			built.append(Vector2(base.x + point.x * width * side, base.y - point.y * height))
	built.remove_at(built.size() - 1)
	return built

static func _heater(centre: Vector2, half_width: float, half_height: float, steps: int = 14) -> PackedVector2Array:
	## A heater shield: flat top, straight shoulders, sides curving in to a point. The
	## six-cornered `_shield` stays for the marks already drawn with it.
	var waist := centre.y - half_height * 0.05
	var tip := Vector2(centre.x, centre.y + half_height)
	var built := PackedVector2Array([centre + Vector2(-half_width, -half_height), centre + Vector2(half_width, -half_height)])
	for point in _curve(Vector2(centre.x + half_width, waist), Vector2(centre.x + half_width, centre.y + half_height * 0.62), tip, steps):
		built.append(point)
	var left := _curve(tip, Vector2(centre.x - half_width, centre.y + half_height * 0.62), Vector2(centre.x - half_width, waist), steps)
	for index in range(1, left.size()):
		built.append(left[index])
	return built

static func _burst(centre: Vector2, reaches: Array, inner: float, turn: float = 0.0) -> PackedVector2Array:
	## A star whose points are not all alike: an impact, where `_star` is a sparkle.
	var built := PackedVector2Array()
	var count := reaches.size()
	for index in count * 2:
		var angle := turn - PI * 0.5 + PI * float(index) / float(count)
		var radius: float = float(reaches[index / 2]) if index % 2 == 0 else inner
		built.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return built

static func _opal_check() -> Array:
	## The opals' check of color patches: a lozenge at each corner of the square.
	var check: Array = []
	for spot in [[0.14, 0.14], [0.86, 0.14], [0.14, 0.86], [0.86, 0.86]]:
		var x: float = float(spot[0])
		var y: float = float(spot[1])
		check.append({"op": "add", "poly": _poly([[x, y + 0.13], [x + 0.13, y], [x, y - 0.13], [x - 0.13, y]])})
	return check

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
##
## No two skills share an emblem, and neither does a Birthstone (its own `emblem` in the
## pack): a mark is how a stone is told apart at a glance, on the rail and in the vault, so a
## new skill gets a new drawing below. tests/test_view.gd holds every one of them to that.
const SKILL_EMBLEMS := {
	"STRIKE": "sword", "CLEAVE": "labrys", "CRUSH": "hammer", "BARRAGE": "ripples", "OVERKILL": "impacts",
	"CROSSCUT": "crossed_cuts", "DETONATE": "bomb", "APEX": "apex",
	"SHELTER": "nested_stone", "MORTAR": "bricks", "SIPHON": "healing_drop",
	"STAKE": "raised_chip", "APPRAISE": "loupe", "GILDED_ARMOR": "gilded_shield", "ENRICH": "gem", "TAILINGS": "paid_stones",
	"SPALL": "split_stone", "EMBER": "embers", "FURY": "bolt",
	"GUARD": "shield", "BULWARK": "wall_before", "AEGIS": "two_shields", "BASTION": "ringed_party", "TEMPO": "hourglass",
	"ANCHOR": "anchor", "RIPOSTE": "riposte",
	"MEND": "cross", "GRAFT": "graft", "BLOOM": "heart", "RENEWAL": "struck_drop", "LIFELINE": "pulse", "THRIVE": "shield_cross", "SAP": "pierced_heart",
	"HEX": "hex", "VENOM": "skull", "MIASMA": "cloud", "CURSE": "eye", "SHATTER": "split_shield", "BIND": "chain", "DREAD": "ghost",
	"MIST": "mist", "ETCH": "crosshair",
	"TITHE": "holed_coin", "JACKPOT": "coin_pyramid", "LUCKY_SEVEN": "seven", "WAGER": "coin_fall", "DOUBLE_DOWN": "double_up", "PROSPECT": "pickaxe",
	"GLIMMER": "spark", "REFRACT": "phantom_die", "POLISH": "shine", "MIRROR": "flip", "CASCADE": "tumbling_dice", "FACET": "rose", "PRISM": "prism",
	## The opals. The six Seams are one family: each wears the opal's check of color patches,
	## with the mark of the color it fires again set in the middle of it.
	"SEAM_RED": "seam_red", "SEAM_BLUE": "seam_blue", "SEAM_GREEN": "seam_green",
	"SEAM_VIOLET": "seam_violet", "SEAM_GOLD": "seam_gold", "SEAM_WHITE": "seam_white",
	"FIRE_OPAL": "warming_flame", "DOUBLET": "twin_stones", "ECHO": "echo", "MATRIX": "split_geode", "PRELUDE": "onward",
	## The Transcendents, made at an altar and nowhere else. The Rainbow Seam keeps the Seams'
	## check round a star of six, one point for each color it plays back.
	"RAINBOW_SEAM": "rainbow_star", "PROCESSION": "climbing_stones", "BLACK_OPAL": "opal_setting",
	"QUINTESSENCE": "pentagram", "GEMINI": "gemini", "CERTAINTY": "infinity",
	## The October 2026 gems, each drawn for it and approved before it was built.
	"CREST": "crowned_peak", "GRUDGE": "broken_heart", "HONE": "honed_blade", "FLURRY": "flurry_burst", "TEMPER": "hammered_anvil", "BLOODLETTING": "nicked_heart", "CRESCENDO": "widening_spiral",
	"CALTROP": "caltrop", "BEZEL": "warded_stone", "HARDENING": "rising_shield", "BASH": "shield_charge", "FORTIFY": "watchtower", "CHAINMAIL": "mail_rings", "REBOUND": "ricochet",
	"LICHEN": "lichen", "WELLSPRING": "brimming_heart", "THIRST": "fangs", "HEARTWOOD": "heart_in_heart",
	"PETRIFY": "gorgon", "CONFLUENCE": "converging", "FERMENT": "toadstool", "HEMLOCK": "hemlock_flower", "ARSENIC": "crystal_cluster", "CONTAGION": "spore_ring",
	"PLACER": "placer_stones", "DIVIDEND": "sprouting_coin", "GILDING": "gilded_die", "RATTLE": "knocking_dice",
	"SEDIMENT": "settled_jar", "OVERTURN": "turned_die", "LODESTONE": "magnet", "BIRTHRIGHT": "crowned_gem", "TUMBLE": "rolling_boulder", "SPECTRUM": "six_cuts",
	"PINFIRE": "pin_sparks", "CONTRA_LUZ": "backlit_gem", "HYDROPHANE": "drop_die"}

static func emblem(skill_key: String) -> String:
	var key := skill_key.to_upper()
	return str(SKILL_EMBLEMS.get(key, "sword"))

## Twenty-five of the October 2026 emblems were drawn and approved as outlines rather than
## as code, so they are kept as those outlines: each shape an op and its points in unit
## space, x then y, simplified to within a fifth of a pixel at the largest size a mark is
## baked at. A circle is written "c" and its centre and radius.
const TRACED: Dictionary = {
	"caltrop": [
		["add", 0.3781, 0.627, 0.5, 0.1189, 0.6219, 0.627],
		["add", 0.561, 0.5214, 0.94, 0.8811, 0.439, 0.7326],
		["add", 0.561, 0.7326, 0.06, 0.8811, 0.439, 0.5214],
		["add", "c", 0.5, 0.627, 0.1524],
		["sub", "c", 0.5, 0.627, 0.066],
		["add", 0.5, 0.4949, 0.5287, 0.5983, 0.6321, 0.627, 0.5287, 0.6558, 0.5, 0.7591, 0.4713, 0.6558, 0.3679, 0.627, 0.4713, 0.5983]],
	"warded_stone": [
		["add", 0.3042, 0.4168, 0.3923, 0.3226, 0.6077, 0.3226, 0.6958, 0.4168, 0.5, 0.735],
		["add", 0.9376, 0.6422, 0.9179, 0.6926, 0.8923, 0.7404, 0.8613, 0.7849, 0.8254, 0.8254, 0.7849, 0.8613, 0.7404, 0.8923, 0.6926, 0.9179, 0.6422, 0.9376, 0.6119, 0.8445, 0.6516, 0.829, 0.6893, 0.8088, 0.7243, 0.7845, 0.7561, 0.7561, 0.7845, 0.7243, 0.8088, 0.6893, 0.829, 0.6516, 0.8445, 0.6119],
		["add", "c", 0.8911, 0.6271, 0.0489],
		["add", "c", 0.6271, 0.8911, 0.0489],
		["add", 0.3578, 0.9376, 0.3074, 0.9179, 0.2596, 0.8923, 0.2151, 0.8613, 0.1746, 0.8254, 0.1387, 0.7849, 0.1077, 0.7404, 0.0821, 0.6926, 0.0624, 0.6422, 0.1555, 0.6119, 0.171, 0.6516, 0.1912, 0.6893, 0.2155, 0.7243, 0.2439, 0.7561, 0.2757, 0.7845, 0.3107, 0.8088, 0.3484, 0.829, 0.3881, 0.8445],
		["add", "c", 0.3729, 0.8911, 0.0489],
		["add", "c", 0.1089, 0.6271, 0.0489],
		["add", 0.0624, 0.3578, 0.0821, 0.3074, 0.1077, 0.2596, 0.1387, 0.2151, 0.1746, 0.1746, 0.2151, 0.1387, 0.2596, 0.1077, 0.3074, 0.0821, 0.3578, 0.0624, 0.3881, 0.1555, 0.3484, 0.171, 0.3107, 0.1912, 0.2757, 0.2155, 0.2439, 0.2439, 0.2155, 0.2757, 0.1912, 0.3107, 0.171, 0.3484, 0.1555, 0.3881],
		["add", "c", 0.1089, 0.3729, 0.0489],
		["add", "c", 0.3729, 0.1089, 0.0489],
		["add", 0.6422, 0.0624, 0.6926, 0.0821, 0.7404, 0.1077, 0.7849, 0.1387, 0.8254, 0.1746, 0.8613, 0.2151, 0.8923, 0.2596, 0.9179, 0.3074, 0.9376, 0.3578, 0.8445, 0.3881, 0.829, 0.3484, 0.8088, 0.3107, 0.7845, 0.2757, 0.7561, 0.2439, 0.7243, 0.2155, 0.6893, 0.1912, 0.6516, 0.171, 0.6119, 0.1555],
		["add", "c", 0.6271, 0.1089, 0.0489],
		["add", "c", 0.8911, 0.3729, 0.0489]],
	"rising_shield": [
		["add", 0.0983, 0.06, 0.9017, 0.06, 0.9017, 0.478, 0.8997, 0.5195, 0.8935, 0.5596, 0.8833, 0.5985, 0.8689, 0.636, 0.8505, 0.6723, 0.828, 0.7072, 0.8013, 0.7409, 0.7706, 0.7732, 0.7357, 0.8043, 0.6968, 0.834, 0.6537, 0.8625, 0.6066, 0.8896, 0.5553, 0.9155, 0.5, 0.94, 0.4447, 0.9155, 0.3934, 0.8896, 0.3463, 0.8625, 0.3032, 0.834, 0.2643, 0.8043, 0.2294, 0.7732, 0.1987, 0.7409, 0.172, 0.7072, 0.1495, 0.6723, 0.1311, 0.636, 0.1167, 0.5985, 0.1065, 0.5596, 0.1003, 0.5195, 0.0983, 0.478],
		["sub", 0.4474, 0.3661, 0.5526, 0.3661, 0.5526, 0.7104, 0.4474, 0.7104],
		["sub", 0.2896, 0.4235, 0.7104, 0.4235, 0.5, 0.1939]],
	"shield_charge": [
		["add", 0.3417, 0.164, 0.8562, 0.2733, 0.7864, 0.5954, 0.7641, 0.6486, 0.7493, 0.673, 0.7124, 0.7174, 0.6903, 0.7373, 0.6389, 0.7729, 0.6095, 0.7885, 0.5435, 0.8152, 0.4677, 0.836, 0.407, 0.7862, 0.3575, 0.7349, 0.337, 0.7087, 0.3045, 0.6553, 0.2832, 0.6005, 0.2768, 0.5726, 0.2732, 0.5443, 0.2745, 0.4866],
		["sub", 0.416, 0.2784, 0.7418, 0.3476, 0.6953, 0.5623, 0.6888, 0.5806, 0.6713, 0.6142, 0.6602, 0.6296, 0.6334, 0.6574, 0.6005, 0.6814, 0.5397, 0.7102, 0.4914, 0.7245, 0.4532, 0.6918, 0.4093, 0.6408, 0.389, 0.6055, 0.3759, 0.5691, 0.372, 0.5506, 0.3699, 0.5318, 0.3712, 0.4934],
		["add", 0.2002, 0.352, 0.2178, 0.3567, 0.2306, 0.3696, 0.2341, 0.378, 0.2353, 0.3871, 0.2306, 0.4046, 0.2178, 0.4175, 0.2093, 0.421, 0.086, 0.421, 0.0703, 0.4119, 0.0612, 0.3962, 0.06, 0.3871, 0.0647, 0.3696, 0.0775, 0.3567, 0.086, 0.3532],
		["add", 0.1827, 0.5098, 0.2002, 0.5145, 0.2131, 0.5273, 0.2166, 0.5358, 0.2178, 0.5449, 0.2131, 0.5624, 0.2002, 0.5752, 0.1827, 0.5799, 0.1301, 0.5799, 0.1126, 0.5752, 0.0998, 0.5624, 0.0951, 0.5449, 0.0963, 0.5358, 0.1053, 0.5201, 0.1126, 0.5145, 0.1301, 0.5098],
		["add", 0.2002, 0.6676, 0.2178, 0.6723, 0.225, 0.6779, 0.2306, 0.6851, 0.2353, 0.7026, 0.2306, 0.7202, 0.2178, 0.733, 0.2093, 0.7365, 0.086, 0.7365, 0.0703, 0.7274, 0.0612, 0.7117, 0.06, 0.7026, 0.0647, 0.6851, 0.0775, 0.6723, 0.086, 0.6688],
		["add", 0.8489, 0.3696, 0.8664, 0.4444, 0.9096, 0.4397, 0.884, 0.4747, 0.94, 0.5273, 0.8664, 0.5051, 0.8489, 0.5449, 0.8314, 0.5051, 0.7578, 0.5273, 0.8138, 0.4747, 0.7882, 0.4397, 0.8314, 0.4444]],
	"watchtower": [
		["add", 0.2544, 0.2647, 0.7456, 0.2647, 0.7456, 0.94, 0.2544, 0.94],
		["add", 0.1726, 0.2033, 0.8274, 0.2033, 0.8274, 0.3056, 0.1726, 0.3056],
		["add", 0.1726, 0.06, 0.3158, 0.06, 0.3158, 0.2237, 0.1726, 0.2237],
		["add", 0.4284, 0.06, 0.5716, 0.06, 0.5716, 0.2237, 0.4284, 0.2237],
		["add", 0.6842, 0.06, 0.8274, 0.06, 0.8274, 0.2237, 0.6842, 0.2237],
		["sub", 0.4488, 0.4488, 0.5512, 0.4488, 0.5512, 0.5921, 0.4488, 0.5921],
		["sub", "c", 0.5, 0.4488, 0.0512],
		["sub", 0.3977, 0.7967, 0.6023, 0.7967, 0.6023, 0.9605, 0.3977, 0.9605],
		["sub", "c", 0.5, 0.7967, 0.1023]],
	"lichen": [
		["add", "c", 0.3533, 0.3586, 0.2095],
		["add", "c", 0.6362, 0.2852, 0.1676],
		["add", "c", 0.6676, 0.5786, 0.2095],
		["add", "c", 0.3952, 0.6414, 0.1781],
		["add", "c", 0.1752, 0.5262, 0.1152],
		["add", "c", 0.8562, 0.7986, 0.0838],
		["sub", "c", 0.3533, 0.3586, 0.0786],
		["sub", "c", 0.6676, 0.5786, 0.0786],
		["sub", "c", 0.6362, 0.2852, 0.0576],
		["sub", "c", 0.3952, 0.6414, 0.0629]],
	"brimming_heart": [
		["add", 0.5, 0.5217, 0.5027, 0.5053, 0.5205, 0.4643, 0.5618, 0.419, 0.6249, 0.392, 0.6976, 0.3981, 0.7617, 0.4385, 0.7993, 0.5035, 0.7993, 0.5787, 0.7617, 0.6528, 0.6976, 0.7213, 0.5618, 0.8425, 0.5205, 0.8924, 0.5027, 0.9273, 0.5, 0.94, 0.4973, 0.9273, 0.4795, 0.8924, 0.4382, 0.8425, 0.3024, 0.7213, 0.2383, 0.6528, 0.2007, 0.5787, 0.2007, 0.5035, 0.2383, 0.4385, 0.3024, 0.3981, 0.3751, 0.392, 0.4382, 0.419, 0.4795, 0.4643, 0.4973, 0.5053],
		["add", 0.5, 0.06, 0.5672, 0.1585, 0.5734, 0.1739, 0.5762, 0.1902, 0.5754, 0.2067, 0.571, 0.2227, 0.5583, 0.244, 0.5463, 0.2554, 0.5321, 0.2639, 0.5165, 0.2692, 0.5, 0.271, 0.4756, 0.267, 0.4605, 0.26, 0.4474, 0.25, 0.4324, 0.2302, 0.4264, 0.2148, 0.4238, 0.1985, 0.4247, 0.1819, 0.4328, 0.1585],
		["add", 0.2665, 0.1678, 0.3228, 0.2497, 0.3292, 0.2711, 0.3264, 0.2933, 0.3184, 0.3081, 0.3014, 0.3228, 0.28, 0.3292, 0.2578, 0.3264, 0.2386, 0.3148, 0.2283, 0.3015, 0.2218, 0.2801, 0.223, 0.2633, 0.2267, 0.2526],
		["add", 0.7335, 0.1678, 0.7733, 0.2526, 0.777, 0.2633, 0.7782, 0.2801, 0.7717, 0.3015, 0.7614, 0.3148, 0.7422, 0.3264, 0.72, 0.3292, 0.6986, 0.3228, 0.6816, 0.3081, 0.6736, 0.2933, 0.6708, 0.2711, 0.6772, 0.2497]],
	"fangs": [
		["add", 0.8771, 0.06, 0.8934, 0.0621, 0.9086, 0.0684, 0.9216, 0.0784, 0.9316, 0.0914, 0.9379, 0.1066, 0.94, 0.1229, 0.94, 0.1857, 0.9379, 0.202, 0.9316, 0.2171, 0.9216, 0.2302, 0.9086, 0.2402, 0.8934, 0.2464, 0.8771, 0.2486, 0.1229, 0.2486, 0.1066, 0.2464, 0.0914, 0.2402, 0.0784, 0.2302, 0.0684, 0.2171, 0.0621, 0.202, 0.06, 0.1857, 0.06, 0.1229, 0.0621, 0.1066, 0.0684, 0.0914, 0.0784, 0.0784, 0.0914, 0.0684, 0.1066, 0.0621, 0.1229, 0.06],
		["add", 0.1543, 0.2276, 0.169, 0.3341, 0.1988, 0.4843, 0.2381, 0.6232, 0.2695, 0.7095, 0.3365, 0.5518, 0.3717, 0.4529, 0.3993, 0.359, 0.4103, 0.3139, 0.4267, 0.2276],
		["add", 0.5733, 0.2276, 0.5897, 0.3341, 0.6007, 0.3854, 0.6283, 0.4843, 0.6635, 0.5782, 0.7063, 0.667, 0.7305, 0.7095, 0.7619, 0.6031, 0.8012, 0.4529, 0.8221, 0.359, 0.8457, 0.2276],
		["add", 0.5, 0.5838, 0.6121, 0.7574, 0.6217, 0.7826, 0.6256, 0.8093, 0.6238, 0.8361, 0.6163, 0.862, 0.5952, 0.8964, 0.5755, 0.9148, 0.5524, 0.9286, 0.5268, 0.9371, 0.5, 0.94, 0.4732, 0.9371, 0.4476, 0.9286, 0.4245, 0.9148, 0.4048, 0.8964, 0.3837, 0.862, 0.3762, 0.8361, 0.3744, 0.8093, 0.3783, 0.7826, 0.3879, 0.7574]],
	"heart_in_heart": [
		["add", 0.5, 0.2878, 0.504, 0.2637, 0.5301, 0.2034, 0.5908, 0.1368, 0.6836, 0.0972, 0.7905, 0.1061, 0.8848, 0.1656, 0.94, 0.2611, 0.94, 0.3716, 0.8848, 0.4807, 0.7905, 0.5813, 0.6836, 0.674, 0.5908, 0.7594, 0.5301, 0.8329, 0.504, 0.8842, 0.5, 0.9028, 0.496, 0.8842, 0.4699, 0.8329, 0.4092, 0.7594, 0.3164, 0.674, 0.2095, 0.5813, 0.1152, 0.4807, 0.06, 0.3716, 0.06, 0.2611, 0.1152, 0.1656, 0.2095, 0.1061, 0.3164, 0.0972, 0.4092, 0.1368, 0.4699, 0.2034, 0.496, 0.2637],
		["sub", 0.5, 0.3264, 0.5029, 0.309, 0.5218, 0.2654, 0.5657, 0.2172, 0.6328, 0.1886, 0.7102, 0.195, 0.7784, 0.238, 0.8183, 0.3071, 0.8183, 0.3871, 0.7784, 0.466, 0.7102, 0.5388, 0.5657, 0.6676, 0.5218, 0.7208, 0.5029, 0.7579, 0.5, 0.7714, 0.4971, 0.7579, 0.4782, 0.7208, 0.4343, 0.6676, 0.2898, 0.5388, 0.2216, 0.466, 0.1817, 0.3871, 0.1817, 0.3071, 0.2216, 0.238, 0.2898, 0.195, 0.3672, 0.1886, 0.4343, 0.2172, 0.4782, 0.2654, 0.4971, 0.309],
		["add", 0.5, 0.3621, 0.5019, 0.3509, 0.5141, 0.3226, 0.5425, 0.2915, 0.5859, 0.2729, 0.636, 0.2771, 0.6801, 0.3049, 0.706, 0.3496, 0.706, 0.4014, 0.6801, 0.4524, 0.636, 0.4995, 0.5425, 0.5829, 0.5141, 0.6173, 0.5019, 0.6413, 0.5, 0.65, 0.4981, 0.6413, 0.4859, 0.6173, 0.4575, 0.5829, 0.364, 0.4995, 0.3199, 0.4524, 0.294, 0.4014, 0.294, 0.3496, 0.3199, 0.3049, 0.364, 0.2771, 0.4141, 0.2729, 0.4575, 0.2915, 0.4859, 0.3226, 0.4981, 0.3509]],
	"gorgon": [
		["add", "c", 0.5103, 0.648, 0.2056],
		["sub", "c", 0.4363, 0.648, 0.0411],
		["sub", "c", 0.5843, 0.648, 0.0411],
		["sub", 0.4445, 0.7467, 0.5761, 0.7467, 0.5761, 0.7714, 0.4445, 0.7714],
		["add", 0.3504, 0.582, 0.2444, 0.5683, 0.2507, 0.5194, 0.3567, 0.5331],
		["add", 0.2244, 0.5524, 0.18, 0.4318, 0.2264, 0.4147, 0.2707, 0.5353],
		["add", 0.2061, 0.4478, 0.1041, 0.4601, 0.0982, 0.4111, 0.2002, 0.3988],
		["add", "c", 0.3536, 0.5576, 0.0247],
		["add", "c", 0.2475, 0.5438, 0.0247],
		["add", "c", 0.2032, 0.4233, 0.0247],
		["add", "c", 0.1011, 0.4356, 0.0247],
		["add", "c", 0.1011, 0.4356, 0.0411],
		["add", 0.4048, 0.5109, 0.3199, 0.446, 0.3498, 0.4068, 0.4348, 0.4717],
		["add", 0.3105, 0.4222, 0.3324, 0.2956, 0.381, 0.304, 0.3592, 0.4306],
		["add", 0.347, 0.3225, 0.2525, 0.2821, 0.2719, 0.2368, 0.3664, 0.2771],
		["add", "c", 0.4198, 0.4913, 0.0247],
		["add", "c", 0.3348, 0.4264, 0.0247],
		["add", "c", 0.3567, 0.2998, 0.0247],
		["add", "c", 0.2622, 0.2594, 0.0247],
		["add", "c", 0.2622, 0.2594, 0.0411],
		["add", 0.4875, 0.4766, 0.4464, 0.3779, 0.4919, 0.3589, 0.5331, 0.4576],
		["add", 0.4502, 0.3526, 0.5324, 0.2539, 0.5704, 0.2855, 0.4881, 0.3842],
		["add", 0.5317, 0.2845, 0.47, 0.2023, 0.5095, 0.1727, 0.5711, 0.2549],
		["add", "c", 0.5103, 0.4671, 0.0247],
		["add", "c", 0.4692, 0.3684, 0.0247],
		["add", "c", 0.5514, 0.2697, 0.0247],
		["add", "c", 0.4897, 0.1875, 0.0247],
		["add", "c", 0.4897, 0.1875, 0.0411],
		["add", 0.5763, 0.4882, 0.59, 0.3821, 0.639, 0.3885, 0.6252, 0.4945],
		["add", 0.606, 0.3622, 0.7265, 0.3178, 0.7436, 0.3641, 0.623, 0.4085],
		["add", 0.7106, 0.3439, 0.6983, 0.2418, 0.7473, 0.2359, 0.7596, 0.338],
		["add", "c", 0.6008, 0.4913, 0.0247],
		["add", "c", 0.6145, 0.3853, 0.0247],
		["add", "c", 0.7351, 0.341, 0.0247],
		["add", "c", 0.7228, 0.2389, 0.0247],
		["add", "c", 0.7228, 0.2389, 0.0411],
		["add", 0.6474, 0.5426, 0.7123, 0.4576, 0.7515, 0.4876, 0.6866, 0.5726],
		["add", 0.7361, 0.4483, 0.8627, 0.4702, 0.8543, 0.5188, 0.7277, 0.4969],
		["add", 0.8358, 0.4848, 0.8762, 0.3903, 0.9216, 0.4096, 0.8812, 0.5042],
		["add", "c", 0.667, 0.5576, 0.0247],
		["add", "c", 0.7319, 0.4726, 0.0247],
		["add", "c", 0.8585, 0.4945, 0.0247],
		["add", "c", 0.8989, 0.3999, 0.0247],
		["add", "c", 0.8989, 0.3999, 0.0411],
		["sub", "c", 0.4363, 0.648, 0.0411],
		["sub", "c", 0.5843, 0.648, 0.0411]],
	"converging": [
		["add", "c", 0.5, 0.5, 0.0971],
		["add", 0.8838, 0.94, 0.6966, 0.7528, 0.7528, 0.6966, 0.94, 0.8838],
		["add", 0.6248, 0.6248, 0.6498, 0.8121, 0.8121, 0.6498],
		["add", 0.06, 0.8838, 0.2472, 0.6966, 0.3034, 0.7528, 0.1162, 0.94],
		["add", 0.3752, 0.6248, 0.1879, 0.6498, 0.3502, 0.8121],
		["add", 0.1162, 0.06, 0.3034, 0.2472, 0.2472, 0.3034, 0.06, 0.1162],
		["add", 0.3752, 0.3752, 0.3502, 0.1879, 0.1879, 0.3502],
		["add", 0.94, 0.1162, 0.7528, 0.3034, 0.6966, 0.2472, 0.8838, 0.06],
		["add", 0.6248, 0.3752, 0.8121, 0.3502, 0.6498, 0.1879]],
	"hemlock_flower": [
		["add", 0.4733, 0.94, 0.4733, 0.5489, 0.5267, 0.5489, 0.5267, 0.94],
		["add", 0.5, 0.78, 0.5254, 0.7359, 0.5533, 0.6964, 0.5857, 0.6655, 0.6041, 0.654, 0.6238, 0.6452, 0.6676, 0.6355, 0.7159, 0.6343, 0.7667, 0.6378, 0.7413, 0.6819, 0.7134, 0.7213, 0.6809, 0.7523, 0.6626, 0.7638, 0.6428, 0.7726, 0.5991, 0.7823, 0.5508, 0.7835],
		["add", 0.4909, 0.5615, 0.1709, 0.3304, 0.1891, 0.3052, 0.5091, 0.5363],
		["add", "c", 0.1356, 0.3, 0.0356],
		["add", "c", 0.2244, 0.3, 0.0356],
		["add", "c", 0.18, 0.2556, 0.0356],
		["add", 0.4862, 0.556, 0.3084, 0.2093, 0.3361, 0.1951, 0.5138, 0.5418],
		["add", "c", 0.2778, 0.1844, 0.0356],
		["add", "c", 0.3667, 0.1844, 0.0356],
		["add", "c", 0.3222, 0.14, 0.0356],
		["add", 0.4844, 0.5489, 0.4844, 0.1578, 0.5156, 0.1578, 0.5156, 0.5489],
		["add", "c", 0.4556, 0.14, 0.0356],
		["add", "c", 0.5444, 0.14, 0.0356],
		["add", "c", 0.5, 0.0956, 0.0356],
		["add", 0.4862, 0.5418, 0.6639, 0.1951, 0.6916, 0.2093, 0.5138, 0.556],
		["add", "c", 0.6333, 0.1844, 0.0356],
		["add", "c", 0.7222, 0.1844, 0.0356],
		["add", "c", 0.6778, 0.14, 0.0356],
		["add", 0.4909, 0.5363, 0.8109, 0.3052, 0.8291, 0.3304, 0.5091, 0.5615],
		["add", "c", 0.7756, 0.3, 0.0356],
		["add", "c", 0.8644, 0.3, 0.0356],
		["add", "c", 0.82, 0.2556, 0.0356]],
	"crystal_cluster": [
		["add", 0.06, 0.8984, 0.0621, 0.8854, 0.0684, 0.8725, 0.0788, 0.8599, 0.0932, 0.8476, 0.1335, 0.8246, 0.1878, 0.8045, 0.2539, 0.788, 0.3294, 0.7757, 0.4112, 0.7682, 0.4964, 0.7656, 0.5815, 0.7682, 0.6633, 0.7757, 0.7388, 0.788, 0.8049, 0.8045, 0.8592, 0.8246, 0.8995, 0.8476, 0.9139, 0.8599, 0.9243, 0.8725, 0.9306, 0.8854, 0.9327, 0.8984],
		["add", 0.392, 0.8605, 0.392, 0.2685, 0.4964, 0.1016, 0.6007, 0.2685, 0.6007, 0.8605],
		["add", 0.2286, 0.8952, 0.0681, 0.5347, 0.0906, 0.3752, 0.2241, 0.4652, 0.3846, 0.8257],
		["add", 0.6081, 0.8257, 0.784, 0.4306, 0.9176, 0.3405, 0.94, 0.5, 0.7641, 0.8952],
		["sub", 0.5082, 0.2344, 0.5082, 0.7656, 0.4845, 0.7656, 0.4845, 0.2344]],
	"spore_ring": [
		["add", "c", 0.5, 0.5, 0.1757],
		["add", "c", 0.8124, 0.5, 0.0537],
		["add", "c", 0.9058, 0.6681, 0.0342],
		["add", "c", 0.7209, 0.7209, 0.0537],
		["add", "c", 0.6681, 0.9058, 0.0342],
		["add", "c", 0.5, 0.8124, 0.0537],
		["add", "c", 0.3319, 0.9058, 0.0342],
		["add", "c", 0.2791, 0.7209, 0.0537],
		["add", "c", 0.0942, 0.6681, 0.0342],
		["add", "c", 0.1876, 0.5, 0.0537],
		["add", "c", 0.0942, 0.3319, 0.0342],
		["add", "c", 0.2791, 0.2791, 0.0537],
		["add", "c", 0.3319, 0.0942, 0.0342],
		["add", "c", 0.5, 0.1876, 0.0537],
		["add", "c", 0.6681, 0.0942, 0.0342],
		["add", "c", 0.7209, 0.2791, 0.0537],
		["add", "c", 0.9058, 0.3319, 0.0342]],
	"crowned_peak": [
		["add", 0.06, 0.9209, 0.94, 0.9209, 0.5, 0.4235],
		["add", 0.3278, 0.3661, 0.3278, 0.1557, 0.4139, 0.2609, 0.5, 0.0791, 0.5861, 0.2609, 0.6722, 0.1557, 0.6722, 0.3661],
		["sub", 0.3661, 0.6913, 0.5, 0.5574, 0.6339, 0.6913, 0.5, 0.6148]],
	"broken_heart": [
		["add", 0.5, 0.2878, 0.504, 0.2637, 0.5301, 0.2034, 0.5908, 0.1368, 0.6836, 0.0972, 0.7905, 0.1061, 0.8848, 0.1656, 0.94, 0.2611, 0.94, 0.3716, 0.8848, 0.4807, 0.7905, 0.5813, 0.6836, 0.674, 0.5908, 0.7594, 0.5301, 0.8329, 0.504, 0.8842, 0.5, 0.9028, 0.496, 0.8842, 0.4699, 0.8329, 0.4092, 0.7594, 0.3164, 0.674, 0.2095, 0.5813, 0.1152, 0.4807, 0.06, 0.3716, 0.06, 0.2611, 0.1152, 0.1656, 0.2095, 0.1061, 0.3164, 0.0972, 0.4092, 0.1368, 0.4699, 0.2034, 0.496, 0.2637],
		["sub", 0.5143, 0.0276, 0.6154, 0.2501, 0.5464, 0.2815, 0.4453, 0.059],
		["sub", 0.6094, 0.2907, 0.4679, 0.4525, 0.4108, 0.4026, 0.5524, 0.2408],
		["sub", 0.4701, 0.4054, 0.6015, 0.5874, 0.54, 0.6318, 0.4086, 0.4498],
		["sub", 0.6077, 0.6182, 0.5369, 0.9216, 0.4631, 0.9043, 0.5339, 0.601],
		["sub", "c", 0.4798, 0.0433, 0.0379],
		["sub", "c", 0.5809, 0.2658, 0.0379],
		["sub", "c", 0.4393, 0.4276, 0.0379],
		["sub", "c", 0.5708, 0.6096, 0.0379],
		["sub", "c", 0.5, 0.9129, 0.0379]],
	"flurry_burst": [
		["add", 0.3438, 0.7323, 0.06, 0.2556, 0.4802, 0.6179],
		["add", 0.5741, 0.5914, 0.3014, 0.8202, 0.2499, 0.7588, 0.5226, 0.53],
		["add", 0.4444, 0.6479, 0.5324, 0.7528, 0.4676, 0.8071, 0.3796, 0.7023],
		["add", "c", 0.5286, 0.8141, 0.0801],
		["add", 0.411, 0.6431, 0.5, 0.0954, 0.589, 0.6431],
		["add", 0.678, 0.6831, 0.322, 0.6831, 0.322, 0.603, 0.678, 0.603],
		["add", 0.5423, 0.6431, 0.5423, 0.78, 0.4577, 0.78, 0.4577, 0.6431],
		["add", "c", 0.5, 0.8245, 0.0801],
		["add", 0.5198, 0.6179, 0.94, 0.2556, 0.6562, 0.7323],
		["add", 0.6986, 0.8202, 0.4259, 0.5914, 0.4774, 0.53, 0.7501, 0.7588],
		["add", 0.6204, 0.7023, 0.5324, 0.8071, 0.4676, 0.7528, 0.5556, 0.6479],
		["add", "c", 0.4714, 0.8141, 0.0801]],
	"settled_jar": [
		["add", 0.7104, 0.1939, 0.7401, 0.1978, 0.7678, 0.2093, 0.7916, 0.2275, 0.8098, 0.2513, 0.8213, 0.279, 0.8252, 0.3087, 0.8252, 0.8252, 0.8213, 0.8549, 0.8098, 0.8826, 0.7916, 0.9064, 0.7678, 0.9246, 0.7401, 0.9361, 0.7104, 0.94, 0.2896, 0.94, 0.2599, 0.9361, 0.2322, 0.9246, 0.2084, 0.9064, 0.1902, 0.8826, 0.1787, 0.8549, 0.1748, 0.8252, 0.1748, 0.3087, 0.1787, 0.279, 0.1902, 0.2513, 0.2084, 0.2275, 0.2322, 0.2093, 0.2599, 0.1978, 0.2896, 0.1939],
		["sub", 0.6722, 0.28, 0.6895, 0.2823, 0.7057, 0.289, 0.7195, 0.2996, 0.7302, 0.3135, 0.7368, 0.3296, 0.7391, 0.347, 0.7391, 0.787, 0.7368, 0.8043, 0.7302, 0.8204, 0.7195, 0.8343, 0.7057, 0.8449, 0.6895, 0.8516, 0.6722, 0.8539, 0.3278, 0.8539, 0.3105, 0.8516, 0.2943, 0.8449, 0.2805, 0.8343, 0.2698, 0.8204, 0.2632, 0.8043, 0.2609, 0.787, 0.2609, 0.347, 0.2632, 0.3296, 0.2698, 0.3135, 0.2805, 0.2996, 0.2943, 0.289, 0.3105, 0.2823, 0.3278, 0.28],
		["add", 0.3087, 0.06, 0.6913, 0.06, 0.6913, 0.1557, 0.3087, 0.1557],
		["add", 0.2609, 0.6913, 0.7391, 0.6913, 0.7391, 0.8539, 0.2609, 0.8539],
		["add", "c", 0.4043, 0.4235, 0.043],
		["add", "c", 0.5765, 0.5191, 0.0478],
		["add", "c", 0.4617, 0.5957, 0.0383],
		["add", "c", 0.6148, 0.3661, 0.0335]],
	"turned_die": [
		["add", 0.2343, 0.4397, 0.7346, 0.4397, 0.7346, 0.94, 0.2343, 0.94],
		["sub", "c", 0.4844, 0.6898, 0.0851],
		["add", 0.0869, 0.4576, 0.0877, 0.4316, 0.0945, 0.38, 0.108, 0.3298, 0.1171, 0.3054, 0.1401, 0.2588, 0.169, 0.2155, 0.2033, 0.1764, 0.2424, 0.1422, 0.2636, 0.127, 0.3086, 0.101, 0.3323, 0.0903, 0.3815, 0.0735, 0.4326, 0.0634, 0.4844, 0.06, 0.5104, 0.0609, 0.562, 0.0676, 0.5873, 0.0735, 0.6366, 0.0903, 0.6603, 0.101, 0.7053, 0.127, 0.7466, 0.1587, 0.7656, 0.1764, 0.7999, 0.2155, 0.8287, 0.2588, 0.7591, 0.299, 0.7361, 0.2645, 0.6936, 0.2191, 0.643, 0.1829, 0.6058, 0.1645, 0.5463, 0.1465, 0.5052, 0.1411, 0.443, 0.1431, 0.4024, 0.1512, 0.3631, 0.1645, 0.3082, 0.1939, 0.2753, 0.2191, 0.2328, 0.2645, 0.2, 0.3173, 0.1841, 0.3556, 0.17, 0.4162, 0.1673, 0.4576],
		["add", "c", 0.1271, 0.4576, 0.0402],
		["add", "c", 0.7939, 0.2789, 0.0402],
		["add", 0.8296, 0.4544, 0.9131, 0.2883, 0.7011, 0.3201]],
	"magnet": [
		["add", 0.9093, 0.5307, 0.9043, 0.5947, 0.8893, 0.6572, 0.8781, 0.6873, 0.849, 0.7446, 0.8311, 0.7713, 0.7894, 0.8201, 0.7406, 0.8618, 0.7139, 0.8797, 0.6566, 0.9088, 0.6265, 0.92, 0.564, 0.935, 0.5, 0.94, 0.436, 0.935, 0.3735, 0.92, 0.3434, 0.9088, 0.2861, 0.8797, 0.2594, 0.8618, 0.2106, 0.8201, 0.1689, 0.7713, 0.151, 0.7446, 0.1219, 0.6873, 0.1107, 0.6572, 0.0957, 0.5947, 0.0907, 0.5307, 0.2953, 0.5307, 0.301, 0.5785, 0.3109, 0.609, 0.3344, 0.651, 0.3553, 0.6754, 0.3797, 0.6963, 0.4217, 0.7198, 0.4522, 0.7297, 0.5, 0.7353, 0.5478, 0.7297, 0.5783, 0.7198, 0.6203, 0.6963, 0.6447, 0.6754, 0.6656, 0.651, 0.6891, 0.609, 0.699, 0.5785, 0.7047, 0.5307],
		["add", 0.0907, 0.1419, 0.2953, 0.1419, 0.2953, 0.5409, 0.0907, 0.5409],
		["add", 0.7047, 0.1419, 0.9093, 0.1419, 0.9093, 0.5409, 0.7047, 0.5409],
		["sub", -0.0116, 0.2647, 1.0116, 0.2647, 1.0116, 0.3056, -0.0116, 0.3056],
		["add", 0.5, 0.06, 0.5217, 0.1406, 0.6023, 0.1623, 0.5217, 0.184, 0.5, 0.2647, 0.4783, 0.184, 0.3977, 0.1623, 0.4783, 0.1406]],
	"crowned_gem": [
		["add", 0.2704, 0.3087, 0.2704, 0.1222, 0.3852, 0.1968, 0.5, 0.06, 0.6148, 0.1968, 0.7296, 0.1222, 0.7296, 0.3087],
		["add", 0.1174, 0.5574, 0.2896, 0.4441, 0.7104, 0.4441, 0.8826, 0.5574, 0.5, 0.94]],
	"placer_stones": [
		["add", 0.2576, 0.4945, 0.4256, 0.5885, 0.4918, 0.7369, 0.3673, 0.8749, 0.1589, 0.8569, 0.0605, 0.7302, 0.06, 0.5698],
		["add", 0.7211, 0.5145, 0.94, 0.5945, 0.9072, 0.7796, 0.7211, 0.8847, 0.5022, 0.7947, 0.5241, 0.6045],
		["add", 0.4894, 0.1153, 0.6524, 0.2031, 0.7153, 0.3599, 0.5698, 0.4597, 0.3938, 0.4867, 0.2634, 0.3599, 0.3354, 0.2094],
		["sub", 0.5104, 0.5261, 0.5104, 0.9474, 0.4683, 0.9474, 0.4683, 0.5261],
		["sub", 0.7566, 0.4019, 0.7344, 0.4437, 0.715, 0.4693, 0.6922, 0.4926, 0.6525, 0.5225, 0.6229, 0.5386, 0.5749, 0.5565, 0.5412, 0.564, 0.4894, 0.5682, 0.4375, 0.564, 0.4038, 0.5565, 0.3558, 0.5386, 0.3262, 0.5225, 0.2865, 0.4926, 0.2637, 0.4693, 0.2443, 0.4437, 0.2221, 0.4019, 0.2617, 0.3875, 0.2806, 0.4223, 0.2972, 0.4437, 0.3166, 0.4631, 0.3504, 0.488, 0.3889, 0.5071, 0.4165, 0.5163, 0.4598, 0.5245, 0.4894, 0.5261, 0.5189, 0.5245, 0.5622, 0.5163, 0.5898, 0.5071, 0.6283, 0.488, 0.6515, 0.472, 0.6816, 0.4437, 0.6981, 0.4223, 0.717, 0.3875],
		["sub", 0.4472, 0.1996, 0.4658, 0.2652, 0.5315, 0.2838, 0.4658, 0.3024, 0.4472, 0.3681, 0.4286, 0.3024, 0.363, 0.2838, 0.4286, 0.2652]],
	"sprouting_coin": [
		["add", "c", 0.4817, 0.6744, 0.2656],
		["sub", "c", 0.4817, 0.6744, 0.2015],
		["add", "c", 0.4817, 0.6744, 0.1465],
		["sub", 0.4542, 0.5829, 0.5092, 0.5829, 0.5092, 0.766, 0.4542, 0.766],
		["add", 0.4519, 0.418, 0.4519, 0.2349, 0.5114, 0.2349, 0.5114, 0.418],
		["add", 0.4817, 0.2898, 0.4251, 0.2953, 0.3719, 0.2949, 0.3475, 0.2911, 0.3249, 0.2843, 0.3043, 0.2742, 0.2857, 0.2607, 0.269, 0.244, 0.2542, 0.2243, 0.2288, 0.1775, 0.207, 0.125, 0.2636, 0.1196, 0.3168, 0.1199, 0.3412, 0.1237, 0.3637, 0.1306, 0.3844, 0.1407, 0.403, 0.1541, 0.4197, 0.1708, 0.4345, 0.1906, 0.4598, 0.2373],
		["add", 0.4817, 0.2441, 0.5078, 0.1862, 0.5375, 0.135, 0.5546, 0.1135, 0.5737, 0.0954, 0.5949, 0.0811, 0.6182, 0.0706, 0.6436, 0.0638, 0.6709, 0.0604, 0.7301, 0.062, 0.793, 0.0701, 0.767, 0.1279, 0.7373, 0.1791, 0.7201, 0.2006, 0.701, 0.2187, 0.6798, 0.233, 0.6565, 0.2435, 0.6311, 0.2503, 0.6038, 0.2537, 0.5446, 0.2521]],
	"pin_sparks": [
		["add", 0.2874, 0.0946, 0.3183, 0.2318, 0.4555, 0.2627, 0.3183, 0.2936, 0.2874, 0.4308, 0.2565, 0.2936, 0.1193, 0.2627, 0.2565, 0.2318],
		["add", 0.6631, 0.0748, 0.6831, 0.1636, 0.7719, 0.1836, 0.6831, 0.2036, 0.6631, 0.2924, 0.6432, 0.2036, 0.5544, 0.1836, 0.6432, 0.1636],
		["add", 0.7027, 0.3912, 0.7372, 0.5446, 0.8906, 0.5791, 0.7372, 0.6136, 0.7027, 0.767, 0.6682, 0.6136, 0.5148, 0.5791, 0.6682, 0.5446],
		["add", 0.327, 0.5593, 0.3488, 0.6562, 0.4456, 0.678, 0.3488, 0.6998, 0.327, 0.7966, 0.3052, 0.6998, 0.2083, 0.678, 0.3052, 0.6562],
		["add", 0.5049, 0.3517, 0.5195, 0.4162, 0.584, 0.4308, 0.5195, 0.4453, 0.5049, 0.5099, 0.4904, 0.4453, 0.4258, 0.4308, 0.4904, 0.4162],
		["add", 0.1292, 0.4308, 0.1419, 0.4873, 0.1984, 0.5, 0.1419, 0.5127, 0.1292, 0.5692, 0.1165, 0.5127, 0.06, 0.5, 0.1165, 0.4873],
		["add", 0.8807, 0.3022, 0.8916, 0.3507, 0.94, 0.3616, 0.8916, 0.3725, 0.8807, 0.4209, 0.8698, 0.3725, 0.8213, 0.3616, 0.8698, 0.3507],
		["add", 0.5445, 0.7867, 0.5572, 0.8432, 0.6137, 0.856, 0.5572, 0.8687, 0.5445, 0.9252, 0.5318, 0.8687, 0.4753, 0.856, 0.5318, 0.8432]],
	"backlit_gem": [
		["add", 0.7061, 0.5209, 0.94, 0.6823, 0.6606, 0.6309],
		["add", 0.6309, 0.6606, 0.6823, 0.94, 0.5209, 0.7061],
		["add", 0.4791, 0.7061, 0.3177, 0.94, 0.3691, 0.6606],
		["add", 0.3394, 0.6309, 0.06, 0.6823, 0.2939, 0.5209],
		["add", 0.2939, 0.4791, 0.06, 0.3177, 0.3394, 0.3691],
		["add", 0.3691, 0.3394, 0.3177, 0.06, 0.4791, 0.2939],
		["add", 0.5209, 0.2939, 0.6823, 0.06, 0.6309, 0.3394],
		["add", 0.6606, 0.3691, 0.94, 0.3177, 0.7061, 0.4791],
		["sub", 0.1825, 0.3958, 0.3254, 0.271, 0.6746, 0.271, 0.8175, 0.3958, 0.5, 0.8175],
		["add", 0.252, 0.4132, 0.3636, 0.3141, 0.6364, 0.3141, 0.748, 0.4132, 0.5, 0.748]]}

static func _traced(glyph: String) -> Array:
	var out: Array = []
	for shape in TRACED.get(glyph, []):
		if str(shape[1]) == "c":
			out.append({"op": str(shape[0]), "circle": [float(shape[2]), float(shape[3]), float(shape[4])]})
			continue
		var poly := PackedVector2Array()
		for index in range(1, shape.size() - 1, 2):
			poly.append(Vector2(float(shape[index]), float(shape[index + 1])))
		out.append({"op": str(shape[0]), "poly": poly})
	return out

static func _band_ring(centre: Vector2, radius: float, thickness: float, op := "add") -> Array:
	return [ {"op": op, "poly": _band(centre, radius, radius, thickness, 0.0, TAU, 0.0, 48)}]

static func _arrowhead(tip: Vector2, from: Vector2, length: float, width: float) -> Dictionary:
	## A solid arrowhead at `tip`, pointing away from `from`.
	var dir := (tip - from).normalized()
	var side := dir.orthogonal() * (width * 0.5)
	var base := tip - dir * length
	return {"op": "add", "poly": PackedVector2Array([tip, base + side, base - side])}

static func _tilted_die(centre: Vector2, half: float, turn: float, pips: Array, pip_radius: float) -> Array:
	## A solid die turned on its corner, pips punched through, `pips` in units of its half edge.
	var square := PackedVector2Array()
	for point in _rounded(-half, -half, half, half, half * 0.22):
		square.append(centre + point.rotated(turn))
	var out: Array = [ {"op": "add", "poly": square}]
	for pip in pips:
		var at: Vector2 = centre + (Vector2(pip[0], pip[1]) * half).rotated(turn)
		out.append({"op": "sub", "circle": [at.x, at.y, pip_radius]})
	return out

static func _die_gap(centre: Vector2, half: float, turn: float, margin: float) -> Dictionary:
	## The clear space round a tilted die, so another drawn behind it reads apart from it.
	var square := PackedVector2Array()
	var h := half + margin
	for point in _rounded(-h, -h, h, h, h * 0.25):
		square.append(centre + point.rotated(turn))
	return {"op": "sub", "poly": square}

static func _regular(centre: Vector2, radius: float, sides: int) -> PackedVector2Array:
	## A regular polygon with a point straight up.
	var out := PackedVector2Array()
	for index in sides:
		var angle := -PI * 0.5 + TAU * float(index) / float(sides)
		out.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return out

static func _rock(centre: Vector2, radius: float, turn: float, wobble: Array) -> PackedVector2Array:
	## A lumpy stone: a polygon whose corners stand at `wobble` times the radius.
	var out := PackedVector2Array()
	for index in wobble.size():
		var angle := turn + TAU * float(index) / float(wobble.size())
		out.append(centre + Vector2(cos(angle), sin(angle)) * radius * float(wobble[index]))
	return out

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
		"cross":
			return [ {"op": "add", "poly": _rect(0.39, 0.08, 0.61, 0.92)},
				{"op": "add", "poly": _rect(0.08, 0.39, 0.92, 0.61)}]
		"split_shield":
			return [ {"op": "add", "poly": _shield(Vector2(0.5, 0.5), 0.44, 0.47)},
				{"op": "sub", "poly": _poly([[0.42, 0.00], [0.60, 0.30], [0.42, 0.50],
					[0.62, 0.74], [0.44, 1.00], [0.58, 1.00], [0.76, 0.74], [0.56, 0.50],
					[0.74, 0.30], [0.56, 0.00]])}]
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
			return _fitted(rays)
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
		"apex":
			# A peak with a star over its summit: the highest roll, and nothing above it.
			return [ {"op": "add", "poly": _poly([[0.02, 0.95], [0.50, 0.32], [0.98, 0.95]])},
				{"op": "sub", "poly": _poly([[0.30, 0.95], [0.50, 0.68], [0.70, 0.95]])},
				{"op": "add", "poly": _star(4, 0.21, 0.055, Vector2(0.50, 0.16))}]
		"bomb":
			# A round charge with its fuse lit.
			return [ {"op": "add", "circle": [0.42, 0.62, 0.34]},
				{"op": "add", "poly": _bar(Vector2(0.56, 0.40), Vector2(0.68, 0.28), 0.17)},
				{"op": "sub", "circle": [0.30, 0.52, 0.07]}] \
				+ _line([[0.66, 0.30], [0.74, 0.17], [0.84, 0.15]], 0.06) \
				+[ {"op": "add", "poly": _star(6, 0.14, 0.045, Vector2(0.86, 0.13))}]
		"bricks":
			# Courses of brick with the mortar between them: what holds a wall together.
			var courses: Array = []
			for row in 3:
				var y0: float = 0.10 + 0.28 * float(row)
				var offset: float = 0.0 if row % 2 == 0 else 0.22
				for column in range(-1, 3):
					var x0: float = maxf(0.04, 0.04 + offset + 0.44 * float(column))
					var x1: float = minf(0.96, 0.04 + offset + 0.44 * float(column) + 0.40)
					if x1 - x0 >= 0.1:
						courses.append({"op": "add", "poly": _rect(x0, y0, x1, y0 + 0.22)})
			return courses
		"anchor":
			# An anchor: ring, shank and stock, and the arms curving up to their flukes.
			return [ {"op": "add", "circle": [0.50, 0.48, 0.42]}, {"op": "sub", "circle": [0.50, 0.48, 0.31]},
				{"op": "sub", "poly": _rect(0.0, -0.1, 1.0, 0.62)},
				{"op": "add", "poly": _poly([[0.04, 0.68], [0.16, 0.48], [0.30, 0.68]])},
				{"op": "add", "poly": _poly([[0.70, 0.68], [0.84, 0.48], [0.96, 0.68]])},
				{"op": "add", "poly": _rect(0.44, 0.22, 0.56, 0.90)},
				{"op": "add", "poly": _rect(0.24, 0.30, 0.76, 0.40)},
				{"op": "add", "circle": [0.50, 0.13, 0.11]}, {"op": "sub", "circle": [0.50, 0.13, 0.05]}]
		"riposte":
			# A shield with a blow turned straight back off it.
			return [ {"op": "add", "poly": _shield(Vector2(0.34, 0.58), 0.30, 0.38)},
				{"op": "sub", "poly": _bar(Vector2(0.30, 0.62), Vector2(0.86, 0.24), 0.21)},
				{"op": "add", "poly": _bar(Vector2(0.30, 0.62), Vector2(0.80, 0.28), 0.10)},
				{"op": "add", "poly": _poly([[0.97, 0.16], [0.70, 0.18], [0.85, 0.42]])}]
		"hex":
			# A hex sign: a six-sided ring with a star set in it.
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for index in 6:
				var angle := TAU * float(index) / 6.0
				outer.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.48)
				inner.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.36)
			return [ {"op": "add", "poly": outer}, {"op": "sub", "poly": inner},
				{"op": "add", "poly": _star(5, 0.27, 0.11, Vector2(0.5, 0.53))}]
		"mist":
			# Three slow waves of fog, staggered.
			var waves: Array = []
			for row in 3:
				var y: float = 0.22 + 0.28 * float(row)
				var start: float = 0.06 if row % 2 == 0 else 0.14
				var points: Array = []
				for index in range(9):
					var t: float = float(index) / 8.0
					points.append([lerpf(start, start + 0.80, t), y + 0.07 * sin(t * TAU)])
				waves.append_array(_line(points, 0.11))
			return waves
		"shine":
			# A stone buffed until it gleams: a bright edge along it and a point of light off it.
			return [ {"op": "add", "poly": _poly([[0.42, 0.12], [0.80, 0.52], [0.42, 0.94], [0.04, 0.52]])},
				{"op": "sub", "poly": _poly([[0.42, 0.29], [0.64, 0.52], [0.42, 0.77], [0.20, 0.52]])},
				{"op": "add", "poly": _bar(Vector2(0.29, 0.48), Vector2(0.40, 0.35), 0.07)},
				{"op": "add", "poly": _star(4, 0.21, 0.055, Vector2(0.80, 0.18))}]
		"gilded_shield":
			# The rim of a heater shield with a coin inside it: armour bought with what you
			# carry. The coin is stamped with a stone, since a struck bar read as a minus sign.
			return [ {"op": "add", "poly": _heater(Vector2(0.5, 0.5), 0.40, 0.46)},
				{"op": "sub", "poly": _heater(Vector2(0.5, 0.47), 0.29, 0.335)},
				{"op": "add", "circle": [0.5, 0.43, 0.15]},
				{"op": "sub", "poly": _diamond(Vector2(0.5, 0.43), 0.065, 0.08)}]
		"echo":
			# A stone and the two fainter ones it leaves behind it.
			var built: Array = []
			for index in 3:
				var cx: float = 0.74 - 0.22 * float(index)
				built.append({"op": "sub", "poly": _poly([[cx, 0.10], [cx + 0.28, 0.50], [cx, 0.90], [cx - 0.28, 0.50]])})
				built.append({"op": "add", "poly": _poly([[cx, 0.16], [cx + 0.22, 0.50], [cx, 0.84], [cx - 0.22, 0.50]])})
				if index < 2:
					built.append({"op": "sub", "poly": _poly([[cx, 0.31], [cx + 0.12, 0.50], [cx, 0.69], [cx - 0.12, 0.50]])})
			return built
		"seam_red", "seam_blue", "seam_green", "seam_violet", "seam_gold", "seam_white":
			# An opal's check of color patches at the corners and, set in the middle, the mark
			# of the color it fires again: one family, and still never two alike.
			var check: Array = _opal_check()
			var marks: Dictionary = {"seam_red": "sword", "seam_blue": "shield", "seam_green": "heart", "seam_violet": "eye", "seam_gold": "holed_coin", "seam_white": "spark"}
			return check + _moved(_shapes(str(marks[glyph])), Vector2(0.21, 0.21), 0.58)
		"rainbow_star":
			# The Seams' check round a six-pointed star, one point for each color it plays back.
			return _opal_check() + [ {"op": "add", "poly": _star(6, 0.28, 0.105)}, {"op": "sub", "circle": [0.5, 0.5, 0.055]}]
		"climbing_stones":
			# Five stones climbing a diagonal, each a size bigger than the last: a straight.
			var climb: Array = []
			for s in [[0.12, 0.80, 0.075, 0.12], [0.30, 0.66, 0.09, 0.14], [0.49, 0.51, 0.105, 0.165], [0.69, 0.35, 0.12, 0.19], [0.89, 0.18, 0.135, 0.215]]:
				climb.append({"op": "add", "poly": _diamond(Vector2(s[0], s[1]), s[2], s[3])})
			return _fitted(climb)
		"opal_setting":
			# A setting: one opal in the middle and five more set into the ring round it.
			var setting: Array = [ {"op": "add", "poly": _band(Vector2(0.5, 0.5), 0.38, 0.38, 0.075, 0.0, TAU, 0.0, 64)},
				{"op": "add", "circle": [0.5, 0.5, 0.17]}]
			for index in 5:
				var angle := -PI * 0.5 + TAU * float(index) / 5.0
				var at := Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.38
				setting.append({"op": "sub", "circle": [at.x, at.y, 0.135]})
				setting.append({"op": "add", "circle": [at.x, at.y, 0.10]})
			return _fitted(setting)
		"pentagram":
			# The five-pointed star drawn in one line, its heart left open, inside a ring: the
			# altar's own sign, on the gem that turns three alike into five.
			var star := PackedVector2Array()
			for step in 5:
				var angle := -PI * 0.5 + TAU * float(step * 2 % 5) / 5.0
				star.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.40)
			return [ {"op": "add", "poly": _band(Vector2(0.5, 0.5), 0.44, 0.44, 0.075, 0.0, TAU, 0.0, 64)}, {"op": "add", "poly": star}]
		"gemini":
			# The twins' sign: two pillars under one lintel and over one sill.
			var sign: Array = []
			sign += _stroke(_curve([0.12, 0.13], [0.5, 0.33], [0.88, 0.13], 12), 0.11)
			sign += _stroke(_curve([0.12, 0.87], [0.5, 0.67], [0.88, 0.87], 12), 0.11)
			sign.append({"op": "add", "poly": _rect(0.285, 0.18, 0.395, 0.82)})
			sign.append({"op": "add", "poly": _rect(0.605, 0.18, 0.715, 0.82)})
			return _fitted(sign)
		"infinity":
			# Infinity, drawn as one thick loop: every hand, every turn.
			var loop: Array = []
			for index in 73:
				var t := TAU * float(index) / 72.0
				var d := 1.0 + sin(t) * sin(t)
				loop.append([0.5 + 0.40 * cos(t) / d, 0.5 + 0.52 * sin(t) * cos(t) / d])
			return _fitted(_stroke(loop, 0.12))
		"ripples":
			# Three arcs spreading out from a point off to the left, each ending in a round cap
			# inside the square: a volley widening as it goes.
			var source := Vector2(0.06, 0.5)
			return _fitted(_arc(source, 0.24, 0.12, deg_to_rad(-56.0), deg_to_rad(56.0))
				+ _arc(source, 0.50, 0.12, deg_to_rad(-42.0), deg_to_rad(42.0))
				+ _arc(source, 0.76, 0.12, deg_to_rad(-30.0), deg_to_rad(30.0)))
		"labrys":
			# A double-bitted axe on its haft: one blow that bites to both sides.
			var bit: Array = [Vector2(0.46, 0.27)]
			bit.append_array(_curve([0.46, 0.27], [0.32, 0.26], [0.153, 0.079], 8).slice(1))
			bit.append_array(_along(Vector2(0.50, 0.35), 0.44, 0.44, deg_to_rad(218.0), deg_to_rad(142.0), 16).slice(1))
			bit.append_array(_curve([0.153, 0.621], [0.32, 0.44], [0.46, 0.43], 8).slice(1))
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for point in bit:
				left.append(point)
				right.append(Vector2(1.0 - point.x, point.y))
			return _fitted([ {"op": "add", "poly": left}, {"op": "add", "poly": right},
				{"op": "add", "poly": _rect(0.455, 0.10, 0.545, 0.96)}, {"op": "add", "circle": [0.5, 0.08, 0.05]}])
		"impacts":
			# A ragged impact with a smaller one thrown off from it: a blow with more than
			# enough left over to land again.
			return _fitted([ {"op": "add", "poly": _burst(Vector2(0.40, 0.60), [0.40, 0.31, 0.44, 0.34, 0.41, 0.30, 0.45, 0.35, 0.39], 0.20, 0.2)},
				{"op": "add", "poly": _burst(Vector2(0.82, 0.18), [0.16, 0.12, 0.17, 0.12, 0.15, 0.13], 0.07, 0.3)}])
		"crossed_cuts":
			# Two long tapering cuts crossing, one passing over the other.
			return [ {"op": "add", "poly": _poly([[0.08, 0.08], [0.571, 0.429], [0.92, 0.92], [0.429, 0.571]])},
				{"op": "sub", "poly": _poly([[0.96, 0.04], [0.5955, 0.5955], [0.04, 0.96], [0.4045, 0.4045]])},
				{"op": "add", "poly": _poly([[0.92, 0.08], [0.571, 0.571], [0.08, 0.92], [0.429, 0.429]])}]
		"embers":
			# Three small flames of different sizes drifting up, the middle one turned the other way.
			return _fitted([ {"op": "add", "poly": _blaze(Vector2(0.32, 0.94), 0.46, 0.54)},
				{"op": "add", "poly": _blaze(Vector2(0.74, 0.70), 0.32, 0.38, true)},
				{"op": "add", "poly": _blaze(Vector2(0.48, 0.32), 0.22, 0.26)}])
		"split_stone":
			# A stone split by a jagged crack, a chip flown off either side.
			return _fitted([ {"op": "add", "poly": _poly([[0.20, 0.20], [0.62, 0.08], [0.90, 0.36], [0.84, 0.80], [0.40, 0.94], [0.08, 0.62]])}]
				+ _stroke([[0.50, 0.03], [0.57, 0.30], [0.43, 0.50], [0.59, 0.70], [0.50, 0.99]], 0.08, "sub")
				+ [ {"op": "add", "poly": _diamond(Vector2(0.10, 0.20), 0.045, 0.06)}, {"op": "add", "poly": _diamond(Vector2(0.94, 0.88), 0.045, 0.06)}])
		"wall_before":
			# A thick curved wall standing over a single dot: cover for one.
			return _fitted(_arc(Vector2(0.5, 0.72), 0.40, 0.16, deg_to_rad(200.0), deg_to_rad(340.0))
				+ [ {"op": "add", "circle": [0.5, 0.72, 0.12]}])
		"ringed_party":
			# A thick ring with three dots safe inside it: the whole party behind one wall.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.46]}, {"op": "sub", "circle": [0.5, 0.5, 0.35]},
				{"op": "add", "circle": [0.5, 0.37, 0.085]}, {"op": "add", "circle": [0.385, 0.58, 0.085]},
				{"op": "add", "circle": [0.615, 0.58, 0.085]}]
		"graft":
			# Two stocks joined into one shoot, with the binding across the join. Crossing
			# them instead read as a scribbled X, which says nothing about grafting.
			return _fitted(_stroke([[0.12, 0.92], [0.5, 0.58]], 0.13) + _stroke([[0.88, 0.92], [0.5, 0.58]], 0.13)
				+ _stroke([[0.5, 0.60], [0.5, 0.09]], 0.13) + [ {"op": "sub", "poly": _rect(0.10, 0.425, 0.90, 0.515)}]
				+ _stroke([[0.22, 0.47], [0.78, 0.47]], 0.085))
		"struck_drop":
			# A droplet struck through: poison taken back out. Its sides run as true tangents
			# into its round, where the older `clean_drop` meets them at a corner.
			return [ {"op": "add", "poly": _drop(Vector2(0.5, 0.05), Vector2(0.5, 0.63), 0.31)}] \
				+ _stroke([[0.10, 0.90], [0.90, 0.10]], 0.16, "sub") + _stroke([[0.10, 0.90], [0.90, 0.10]], 0.075)
		"shield_cross":
			# The rim of a heater shield with a healing cross inside: block turned into health.
			return [ {"op": "add", "poly": _heater(Vector2(0.5, 0.5), 0.40, 0.46)},
				{"op": "sub", "poly": _heater(Vector2(0.5, 0.47), 0.29, 0.335)},
				{"op": "add", "poly": _rect(0.44, 0.26, 0.56, 0.64)}, {"op": "add", "poly": _rect(0.32, 0.39, 0.68, 0.51)}]
		"pierced_heart":
			# A heart run through by a dagger: the healing done this turn turned into a wound.
			var across := Vector2(0.707, -0.707).orthogonal()
			var hilt := Vector2(0.30, 0.70)
			return _fitted([ {"op": "add", "poly": _heart(Vector2(0.46, 0.54), 0.40)},
				{"op": "sub", "poly": PackedVector2Array([hilt + across * 0.11, Vector2(0.97, 0.03), hilt - across * 0.11])},
				{"op": "add", "poly": PackedVector2Array([hilt + across * 0.055, Vector2(0.92, 0.08), hilt - across * 0.055])},
				{"op": "add", "poly": _bar(hilt + across * 0.13, hilt - across * 0.13, 0.07)}]
				+ _stroke([[0.27, 0.73], [0.14, 0.86]], 0.08) + [ {"op": "add", "circle": [0.11, 0.89, 0.06]}])
		"healing_drop":
			# A drop of poison with a healing cross cut through it: the venom turned to mending.
			return [ {"op": "add", "poly": _drop(Vector2(0.5, 0.04), Vector2(0.5, 0.62), 0.34)},
				{"op": "sub", "poly": _rect(0.44, 0.46, 0.56, 0.80)}, {"op": "sub", "poly": _rect(0.33, 0.57, 0.67, 0.69)}]
		"chain":
			# Three links of chain: two face on, the middle one edge on and lying over both.
			return _fitted([ {"op": "add", "poly": _band(Vector2(0.25, 0.5), 0.19, 0.12, 0.08, 0.0, TAU)},
				{"op": "add", "poly": _band(Vector2(0.75, 0.5), 0.19, 0.12, 0.08, 0.0, TAU)}]
				+ _stroke([[0.34, 0.5], [0.66, 0.5]], 0.17, "sub") + _stroke([[0.34, 0.5], [0.66, 0.5]], 0.10))
		"ghost":
			# A sheet ghost with hollow eyes and a mouth open in a scream.
			return _fitted([ {"op": "add", "circle": [0.5, 0.42, 0.36]}, {"op": "add", "poly": _rect(0.14, 0.42, 0.86, 0.80)},
				{"op": "add", "circle": [0.26, 0.80, 0.12]}, {"op": "add", "circle": [0.50, 0.80, 0.12]}, {"op": "add", "circle": [0.74, 0.80, 0.12]},
				{"op": "sub", "poly": _ellipse(Vector2(0.38, 0.44), 0.06, 0.09)}, {"op": "sub", "poly": _ellipse(Vector2(0.62, 0.44), 0.06, 0.09)},
				{"op": "sub", "poly": _ellipse(Vector2(0.5, 0.64), 0.06, 0.08)}])
		"holed_coin":
			# A rimmed coin with a square hole through its middle, like old cash: Tithe's own
			# coin, apart from the plain one the interface counts gold with.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.47]}, {"op": "sub", "circle": [0.5, 0.5, 0.38]},
				{"op": "add", "circle": [0.5, 0.5, 0.33]}, {"op": "sub", "poly": _rect(0.40, 0.40, 0.60, 0.60)}]
		"coin_pyramid":
			# Three rimmed coins piled two and one: a winning hand paid out.
			var pile: Array = []
			for coin in [[0.29, 0.67], [0.71, 0.67], [0.5, 0.31]]:
				if not pile.is_empty():
					pile.append({"op": "sub", "circle": [coin[0], coin[1], 0.285]})
				pile.append_array([ {"op": "add", "circle": [coin[0], coin[1], 0.25]}, {"op": "sub", "circle": [coin[0], coin[1], 0.19]},
					{"op": "add", "circle": [coin[0], coin[1], 0.145]}])
			return _fitted(pile)
		"double_up":
			# A coin with two chevrons stacked inside it: the next gem doubled, on a flip.
			return [ {"op": "add", "circle": [0.5, 0.5, 0.46]}, {"op": "sub", "circle": [0.5, 0.5, 0.35]}] \
				+ _stroke([[0.32, 0.50], [0.5, 0.33], [0.68, 0.50]], 0.10) + _stroke([[0.32, 0.69], [0.5, 0.52], [0.68, 0.69]], 0.10)
		"raised_chip":
			# A gambling chip with an arrow struck through it: a stake that raises the next gem.
			# Its inlays sit inside an unbroken rim; notches cut through the edge read as a gear.
			var chip: Array = [ {"op": "add", "circle": [0.5, 0.5, 0.46]}]
			for index in 8:
				var way := Vector2.RIGHT.rotated(TAU * float(index) / 8.0 + PI / 8.0)
				chip.append({"op": "sub", "poly": _bar(Vector2(0.5, 0.5) + way * 0.335, Vector2(0.5, 0.5) + way * 0.415, 0.10)})
			chip.append_array([ {"op": "sub", "circle": [0.5, 0.5, 0.29]}, {"op": "add", "circle": [0.5, 0.5, 0.245]},
				{"op": "sub", "poly": _poly([[0.5, 0.31], [0.65, 0.48], [0.56, 0.48], [0.56, 0.68], [0.44, 0.68], [0.44, 0.48], [0.35, 0.48]])}])
			return chip
		"flip":
			# A solid triangle and its outlined reflection either side of a dashed line: one
			# die turned to match another.
			return [ {"op": "add", "poly": _poly([[0.06, 0.50], [0.40, 0.16], [0.40, 0.84]])},
				{"op": "add", "poly": _poly([[0.94, 0.50], [0.60, 0.16], [0.60, 0.84]])},
				{"op": "sub", "poly": _poly([[0.82, 0.50], [0.67, 0.34], [0.67, 0.66]])},
				{"op": "add", "poly": _rect(0.47, 0.06, 0.53, 0.24)}, {"op": "add", "poly": _rect(0.47, 0.41, 0.53, 0.59)},
				{"op": "add", "poly": _rect(0.47, 0.76, 0.53, 0.94)}]
		"tumbling_dice":
			# Three dice tumbling down a slope, showing one, two and three: luck rolling on into
			# the next turn.
			var tumble: Array = []
			var faces: Array = [[[0.0, 0.0]], [[-0.5, -0.5], [0.5, 0.5]], [[-0.5, -0.5], [0.0, 0.0], [0.5, 0.5]]]
			for index in 3:
				var centre := Vector2(0.22 + 0.28 * float(index), 0.22 + 0.28 * float(index))
				var turn := 0.25 * float(index)
				var square := PackedVector2Array()
				var margin := PackedVector2Array()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					square.append(centre + (corner * 0.15).rotated(turn))
					margin.append(centre + (corner * 0.20).rotated(turn))
				tumble.append({"op": "sub", "poly": margin})
				tumble.append({"op": "add", "poly": square})
				for pip in faces[index]:
					var at: Vector2 = centre + (Vector2(pip[0], pip[1]) * 0.15).rotated(turn)
					tumble.append({"op": "sub", "circle": [at.x, at.y, 0.035]})
			return _fitted(tumble)
		"warming_flame":
			# A flame with a small stone either side of it, warmed by it: every other gem grows.
			return _fitted([ {"op": "add", "poly": _blaze(Vector2(0.5, 0.94), 0.50, 0.84)},
				{"op": "sub", "poly": _drop(Vector2(0.5, 0.60), Vector2(0.5, 0.80), 0.08)},
				{"op": "add", "poly": _diamond(Vector2(0.15, 0.72), 0.09, 0.13)}, {"op": "add", "poly": _diamond(Vector2(0.85, 0.72), 0.09, 0.13)}])
		"twin_stones":
			# A solid oval stone in front of an outlined one: the stone and the copy it makes.
			return _fitted([ {"op": "add", "poly": _ellipse(Vector2(0.62, 0.40), 0.32, 0.30)},
				{"op": "sub", "poly": _ellipse(Vector2(0.62, 0.40), 0.24, 0.22)},
				{"op": "sub", "poly": _ellipse(Vector2(0.38, 0.60), 0.37, 0.35)},
				{"op": "add", "poly": _ellipse(Vector2(0.38, 0.60), 0.32, 0.30)}]
				+ _arc(Vector2(0.38, 0.60), 0.21, 0.055, deg_to_rad(200.0), deg_to_rad(245.0), "sub"))
		"split_geode":
			# A geode broken into two halves, crystals lining each, with two stones freed
			# between them: the gems that fizzled, brought back out.
			var halves: Array = [ {"op": "add", "poly": _band(Vector2(0.5, 0.5), 0.36, 0.40, 0.16, PI * 0.58, PI * 1.42)},
				{"op": "add", "poly": _band(Vector2(0.5, 0.5), 0.36, 0.40, 0.16, -PI * 0.42, PI * 0.42)}]
			for side in [-1.0, 1.0]:
				for y in [0.34, 0.5, 0.66]:
					var x: float = 0.5 + side * 0.28
					halves.append({"op": "add", "poly": _poly([[x, y - 0.07], [x, y + 0.07], [x - side * 0.10, y]])})
			halves.append({"op": "add", "poly": _diamond(Vector2(0.5, 0.33), 0.09, 0.13)})
			halves.append({"op": "add", "poly": _diamond(Vector2(0.5, 0.67), 0.09, 0.13)})
			return _fitted(halves)
		"nested_stone":
			# A small stone held inside the outline of a larger one: cover for the one who needs it.
			return [ {"op": "add", "poly": _diamond(Vector2(0.5, 0.5), 0.44, 0.46)},
				{"op": "sub", "poly": _diamond(Vector2(0.5, 0.5), 0.30, 0.32)},
				{"op": "add", "poly": _diamond(Vector2(0.5, 0.5), 0.15, 0.17)}]
		"paid_stones":
			# Three empty stones with a coin dropped under each: every gem that fizzled pays once.
			var row: Array = []
			for x in [0.18, 0.5, 0.82]:
				row.append_array([ {"op": "add", "poly": _diamond(Vector2(x, 0.32), 0.14, 0.20)},
					{"op": "sub", "poly": _diamond(Vector2(x, 0.32), 0.07, 0.11)}, {"op": "add", "circle": [x, 0.78, 0.08]}])
			return _fitted(row)
		"pickaxe":
			# The interface's pick, tilted so its head and handle fill the square: digging for a find.
			return _fitted(_turned(_ui_shapes("pick"), -0.785))
		"phantom_die":
			# A die with a broken outline of itself behind it: the phantom copy of your highest roll.
			# The outline breaks once along each side the front die leaves open.
			return [ {"op": "add", "poly": _rounded(0.36, 0.06, 0.94, 0.64, 0.09)}, {"op": "sub", "poly": _rounded(0.43, 0.13, 0.87, 0.57, 0.04)},
				{"op": "sub", "poly": _rect(0.62, 0.0, 0.68, 0.16)}, {"op": "sub", "poly": _rect(0.84, 0.32, 1.0, 0.38)},
				{"op": "sub", "poly": _rounded(0.015, 0.315, 0.685, 0.985, 0.12)}, {"op": "add", "poly": _rounded(0.06, 0.36, 0.64, 0.94, 0.09)},
				{"op": "sub", "circle": [0.20, 0.50, 0.055]}, {"op": "sub", "circle": [0.35, 0.65, 0.055]}, {"op": "sub", "circle": [0.50, 0.80, 0.055]}]
		"onward":
			# Two chevrons pointing into a stone: whatever fires next fires again.
			return _fitted(_stroke([[0.08, 0.24], [0.24, 0.50], [0.08, 0.76]], 0.11) + _stroke([[0.29, 0.24], [0.45, 0.50], [0.29, 0.76]], 0.11)
				+ [ {"op": "add", "poly": _diamond(Vector2(0.75, 0.50), 0.20, 0.30)}])
		"formation":
			# Five stones in a wedge behind a leader: matching dice falling into line for the Knight.
			var wedge: Array = []
			for spot in [[0.5, 0.20, 0.13], [0.33, 0.44, 0.10], [0.67, 0.44, 0.10], [0.17, 0.68, 0.085], [0.83, 0.68, 0.085]]:
				wedge.append({"op": "add", "poly": _diamond(Vector2(spot[0], spot[1]), spot[2], spot[2] * 1.25)})
			return _fitted(wedge)
		"cuts":
			# A thousand cuts: rows of short nicks, none of them much on its own.
			var nicks: Array = []
			for row in 3:
				for column in 3:
					var x: float = 0.14 + 0.32 * float(column) + (0.08 if row % 2 == 1 else 0.0)
					var y: float = 0.20 + 0.30 * float(row)
					nicks.append({"op": "add", "poly": _bar(Vector2(x - 0.08, y + 0.11), Vector2(x + 0.08, y - 0.11), 0.10)})
			return nicks
		"notes":
			# Two notes beamed together: the phrase played again.
			return [ {"op": "add", "circle": [0.26, 0.80, 0.15]}, {"op": "add", "circle": [0.72, 0.72, 0.15]},
				{"op": "add", "poly": _rect(0.32, 0.18, 0.41, 0.80)},
				{"op": "add", "poly": _rect(0.78, 0.10, 0.87, 0.72)},
				{"op": "add", "poly": _poly([[0.32, 0.16], [0.87, 0.06], [0.87, 0.22], [0.32, 0.32]])}]
		"vial":
			# A narrow bottle stoppered at the neck, a bubble caught in what is inside.
			return [ {"op": "add", "poly": _rect(0.38, 0.02, 0.62, 0.14)},
				{"op": "add", "poly": _rect(0.43, 0.12, 0.57, 0.34)},
				{"op": "add", "poly": _poly([[0.43, 0.30], [0.57, 0.30], [0.78, 0.52], [0.78, 0.86], [0.68, 0.97], [0.32, 0.97], [0.22, 0.86], [0.22, 0.52]])},
				{"op": "sub", "circle": [0.42, 0.62, 0.08]}, {"op": "sub", "circle": [0.60, 0.80, 0.055]}]
		"harlequin":
			# A diamond quartered in checks, two solid and two hollow: a motley coat.
			var centre := Vector2(0.5, 0.5)
			var tips: Array = [Vector2(0.5, 0.03), Vector2(0.97, 0.5), Vector2(0.5, 0.97), Vector2(0.03, 0.5)]
			var built: Array = [ {"op": "add", "poly": PackedVector2Array(tips)}]
			for side in [1, 3]:
				var a: Vector2 = (tips[side - 1] + tips[side]) * 0.5
				var b: Vector2 = (tips[side] + tips[(side + 1) % 4]) * 0.5
				var quarter := PackedVector2Array([a, tips[side], b, centre])
				var middle: Vector2 = (a + tips[side] + b + centre) * 0.25
				var hollow := PackedVector2Array()
				for point in quarter:
					hollow.append(middle.lerp(point, 0.5))
				built.append({"op": "sub", "poly": hollow})
			built.append({"op": "sub", "poly": _bar((tips[0] + tips[3]) * 0.5, (tips[1] + tips[2]) * 0.5, 0.05)})
			built.append({"op": "sub", "poly": _bar((tips[0] + tips[1]) * 0.5, (tips[2] + tips[3]) * 0.5, 0.05)})
			return built
		"dice_pair":
			# Two dice in the air, tumbling: the high roller's throw. Set close and only a
			# little turned, so they stay large inside the margin their corners need.
			var built: Array = []
			for spec in [[Vector2(0.36, 0.60), 0.25, 0.28, [[-0.5, -0.5], [0.0, 0.0], [0.5, 0.5]]], [Vector2(0.74, 0.28), 0.18, -0.45, [[-0.5, 0.5], [0.5, -0.5]]]]:
				var centre: Vector2 = spec[0]
				var half: float = float(spec[1])
				var turn: float = float(spec[2])
				var square := PackedVector2Array()
				var margin := PackedVector2Array()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					square.append(centre + (corner * half).rotated(turn))
					margin.append(centre + (corner * (half + 0.05)).rotated(turn))
				built.append({"op": "sub", "poly": margin})
				built.append({"op": "add", "poly": square})
				for pip in spec[3]:
					var at: Vector2 = centre + (Vector2(pip[0], pip[1]) * half).rotated(turn)
					built.append({"op": "sub", "circle": [at.x, at.y, half * 0.2]})
			return _fitted(built)
		## The October 2026 gems drawn as code. The rest are outlines in TRACED, below.
		"mail_rings":
			# Chainmail: nine rings, every other one laid over its neighbours with a gap cut
			# round it, so the grid reads as linked mail rather than a sheet of circles.
			var built: Array = []
			for over_pass in [false, true]:
				for row in 3:
					for column in 3:
						var over: bool = (row + column) % 2 == 0
						if over != over_pass:
							continue
						var centre := Vector2(0.18 + 0.32 * column, 0.18 + 0.32 * row)
						if over:
							built += _band_ring(centre, 0.17, 0.115, "sub")
						built += _band_ring(centre, 0.17, 0.075)
			return _fitted(built)
		"ricochet":
			# Rebound: a shield, and a blow that comes in dotted, glances off it and flies on.
			var hit := Vector2(0.50, 0.46)
			var built: Array = [ {"op": "add", "poly": _heater(Vector2(0.27, 0.52), 0.21, 0.34)},
				{"op": "sub", "poly": _heater(Vector2(0.27, 0.52), 0.11, 0.21)}]
			for at in [[0.93, 0.08], [0.82, 0.18], [0.71, 0.27], [0.61, 0.36]]:
				built.append({"op": "add", "circle": [at[0], at[1], 0.04]})
			built.append({"op": "add", "poly": _star(4, 0.10, 0.03, hit + Vector2(0.02, 0.0))})
			built += _stroke([hit, Vector2(0.80, 0.72)], 0.085)
			built.append(_arrowhead(Vector2(0.95, 0.86), hit, 0.2, 0.22))
			return built
		"toadstool":
			# Ferment: a spotted toadstool with bubbles rising off it as it works.
			var cap := PackedVector2Array()
			for point in _along(Vector2(0.40, 0.60), 0.34, 0.30, PI, TAU, 32):
				cap.append(point)
			for point in _curve(Vector2(0.74, 0.60), Vector2(0.40, 0.52), Vector2(0.06, 0.60), 12):
				cap.append(point)
			var built: Array = [ {"op": "add", "poly": cap}]
			for spot in [[0.27, 0.43, 0.05], [0.46, 0.37, 0.04], [0.56, 0.50, 0.05]]:
				built.append({"op": "sub", "circle": spot})
			built.append({"op": "add", "poly": _poly([[0.32, 0.59], [0.48, 0.59], [0.50, 0.94], [0.30, 0.94]])})
			built += _band_ring(Vector2(0.80, 0.30), 0.085, 0.045)
			built += _band_ring(Vector2(0.66, 0.12), 0.06, 0.04)
			built.append({"op": "add", "circle": [0.90, 0.07, 0.035]})
			return _fitted(built)
		"honed_blade":
			# Hone: a sword whose point has been honed into an arrowhead.
			return [ {"op": "add", "poly": _poly([[0.5, 0.02], [0.75, 0.28], [0.60, 0.28], [0.60, 0.64], [0.40, 0.64], [0.40, 0.28], [0.25, 0.28]])},
				{"op": "sub", "poly": _rect(0.485, 0.30, 0.515, 0.60)},
				{"op": "add", "poly": _rect(0.18, 0.64, 0.82, 0.73)},
				{"op": "add", "poly": _rect(0.44, 0.73, 0.56, 0.89)},
				{"op": "add", "circle": [0.5, 0.92, 0.07]}]
		"hammered_anvil":
			# Temper: a hammer coming down on an anvil, sparks flying.
			var hammer := PackedVector2Array()
			for point in _rounded(-0.15, -0.07, 0.15, 0.07, 0.02):
				hammer.append(Vector2(0.58, 0.30) + point.rotated(-0.35))
			return _fitted([ {"op": "add", "poly": _poly([[0.04, 0.50], [0.22, 0.50], [0.22, 0.47], [0.86, 0.47], [0.86, 0.60], [0.70, 0.62], [0.64, 0.70],
					[0.64, 0.78], [0.78, 0.84], [0.78, 0.92], [0.26, 0.92], [0.26, 0.84], [0.40, 0.78], [0.40, 0.70], [0.32, 0.62], [0.22, 0.60]])},
				{"op": "add", "poly": hammer},
				{"op": "add", "poly": _bar(Vector2(0.58, 0.30), Vector2(0.88, 0.08), 0.06)},
				{"op": "add", "poly": _star(4, 0.10, 0.03, Vector2(0.20, 0.30))},
				{"op": "add", "poly": _star(4, 0.06, 0.02, Vector2(0.33, 0.16))}])
		"nicked_heart":
			# Bloodletting: a nick at the heart's shoulder, one big drop falling from its point.
			return _fitted([ {"op": "add", "poly": _heart(Vector2(0.5, 0.36), 0.36)},
				{"op": "sub", "poly": _poly([[0.95, 0.06], [0.98, 0.20], [0.62, 0.34]])},
				{"op": "add", "poly": _drop(Vector2(0.5, 0.68), Vector2(0.5, 0.86), 0.09)}])
		"widening_spiral":
			# Crescendo: a spiral winding outward, its line thickening as it goes.
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for index in 91:
				var t: float = float(index) / 90.0
				var angle: float = -PI * 0.5 + t * TAU * 2.25
				var reach: float = 0.04 + 0.40 * t
				var width: float = 0.025 + 0.085 * t
				var dir := Vector2(cos(angle), sin(angle))
				outer.append(Vector2(0.5, 0.5) + dir * (reach + width * 0.5))
				inner.append(Vector2(0.5, 0.5) + dir * maxf(reach - width * 0.5, 0.0))
			inner.reverse()
			outer.append_array(inner)
			return _fitted([ {"op": "add", "poly": outer}, {"op": "add", "circle": [0.5, 0.46, 0.035]}])
		"rolling_boulder":
			# Tumble: a cracked boulder rolling, speed lines behind it and a turn over it.
			var centre := Vector2(0.60, 0.56)
			var built: Array = [ {"op": "add", "poly": _rock(centre, 0.34, 0.2, [1.0, 0.92, 1.04, 0.88, 0.98, 1.06, 0.90, 1.0, 0.95])}]
			built += _stroke([Vector2(0.34, 0.40), Vector2(0.48, 0.47), Vector2(0.44, 0.58), Vector2(0.60, 0.66), Vector2(0.62, 0.80)], 0.035, "sub")
			for line in [[0.04, 0.20, 0.44], [0.0, 0.18, 0.60], [0.06, 0.22, 0.76]]:
				built += _stroke([Vector2(line[0], line[2]), Vector2(line[1], line[2])], 0.055)
			built += _arc(centre, 0.44, 0.045, -PI * 0.85, -PI * 0.45)
			built.append(_arrowhead(centre + Vector2(cos(-PI * 0.42), sin(-PI * 0.42)) * 0.44 + Vector2(0.05, 0.01),
				centre + Vector2(cos(-PI * 0.55), sin(-PI * 0.55)) * 0.44, 0.12, 0.13))
			return _fitted(built)
		"six_cuts":
			# Spectrum: the six colours' own stone outlines, in two rows.
			var edge := 0.13
			return _fitted([ {"op": "add", "poly": _regular(Vector2(0.18, 0.31), edge * 1.3, 3)},
				{"op": "add", "poly": _rect(0.5 - edge, 0.27 - edge, 0.5 + edge, 0.27 + edge)},
				{"op": "add", "poly": _heart(Vector2(0.82, 0.28), edge * 1.15)},
				{"op": "add", "poly": _drop(Vector2(0.18, 0.76 - edge * 1.6), Vector2(0.18, 0.76), edge * 0.9)},
				{"op": "add", "poly": _regular(Vector2(0.5, 0.72), edge * 1.12, 6)},
				{"op": "add", "circle": [0.82, 0.72, edge]}])
		"gilded_die":
			# Gilding: a die seen from above a corner, its top face gilded solid, its sides plain.
			return _fitted([ {"op": "add", "poly": _poly([[0.5, 0.08], [0.90, 0.30], [0.5, 0.52], [0.10, 0.30]])},
				{"op": "sub", "circle": [0.5, 0.30, 0.06]},
				{"op": "add", "poly": _poly([[0.10, 0.36], [0.47, 0.58], [0.47, 0.96], [0.10, 0.74]])},
				{"op": "sub", "poly": _poly([[0.16, 0.45], [0.41, 0.60], [0.41, 0.86], [0.16, 0.71]])},
				{"op": "add", "poly": _poly([[0.90, 0.36], [0.53, 0.58], [0.53, 0.96], [0.90, 0.74]])},
				{"op": "sub", "poly": _poly([[0.84, 0.45], [0.59, 0.60], [0.59, 0.86], [0.84, 0.71]])},
				{"op": "add", "circle": [0.285, 0.655, 0.045]},
				{"op": "add", "circle": [0.66, 0.62, 0.04]},
				{"op": "add", "circle": [0.775, 0.73, 0.04]}])
		"knocking_dice":
			# Rattle: two dice knocking together in the air.
			var built: Array = _tilted_die(Vector2(0.32, 0.60), 0.21, -0.40, [[-0.5, -0.5], [0.5, 0.5]], 0.055)
			built.append(_die_gap(Vector2(0.68, 0.40), 0.21, 0.35, 0.045))
			built += _tilted_die(Vector2(0.68, 0.40), 0.21, 0.35, [[-0.5, -0.5], [0.0, 0.0], [0.5, 0.5]], 0.05)
			for line in [[0.56, 0.86, 0.62, 0.96], [0.70, 0.76, 0.82, 0.82], [0.22, 0.24, 0.30, 0.12], [0.36, 0.30, 0.40, 0.18]]:
				built += _stroke([Vector2(line[0], line[1]), Vector2(line[2], line[3])], 0.05)
			return _fitted(built)
		"drop_die":
			# Hydrophane: a die that came up 1, its one pip a drop of water.
			return [ {"op": "add", "poly": _rounded(0.06, 0.06, 0.94, 0.94, 0.16)},
				{"op": "sub", "poly": _drop(Vector2(0.5, 0.20), Vector2(0.5, 0.58), 0.20)}]
	if TRACED.has(glyph):
		return _traced(glyph)
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
		"altar":
			# A stone table with a light hanging over it: the altar on the map.
			return _fitted([ {"op": "add", "poly": _rect(0.10, 0.42, 0.90, 0.54)},
				{"op": "add", "poly": _poly([[0.30, 0.54], [0.70, 0.54], [0.78, 0.90], [0.22, 0.90]])},
				{"op": "add", "poly": _rect(0.14, 0.88, 0.86, 0.97)},
				{"op": "add", "poly": _star(4, 0.17, 0.045, Vector2(0.5, 0.20))}])
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
		"swirl":
			# Something strange: a spiral winding out from the middle, nearly two turns, so it reads
			# apart from the question mark a dark mouth wears.
			var turns: Array = []
			for index in range(31):
				var t: float = float(index) / 30.0
				var angle: float = t * TAU * 1.75 - PI * 0.5
				var radius: float = 0.05 + t * 0.37
				turns.append([0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius])
			return _line(turns, 0.12)
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
		"depth":
			# Strata of rock with an arrow sinking through them: what fighting deeper does to a
			# creature's blows. Never the Carat scale, which is a stone's own multiplier.
			return [ {"op": "add", "poly": _rect(0.04, 0.12, 0.96, 0.25)},
				{"op": "add", "poly": _rect(0.04, 0.41, 0.96, 0.54)},
				{"op": "add", "poly": _rect(0.04, 0.70, 0.96, 0.83)},
				{"op": "sub", "poly": _rect(0.33, -0.1, 0.67, 1.1)},
				{"op": "add", "poly": _rect(0.42, 0.02, 0.58, 0.60)},
				{"op": "add", "poly": _poly([[0.22, 0.54], [0.78, 0.54], [0.50, 0.97]])}]
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
		"calendar":
			# A day's page: two rings holding it to the board, a heading band, and today
			# picked out of the grid as the one filled square.
			return [ {"op": "add", "poly": _rounded(0.08, 0.16, 0.92, 0.94, 0.08)},
				{"op": "sub", "poly": _rect(0.16, 0.38, 0.84, 0.86)},
				{"op": "add", "poly": _rect(0.20, 0.44, 0.34, 0.56)}, {"op": "add", "poly": _rect(0.43, 0.44, 0.57, 0.56)},
				{"op": "add", "poly": _rect(0.66, 0.44, 0.80, 0.56)}, {"op": "add", "poly": _rect(0.20, 0.66, 0.34, 0.78)},
				{"op": "add", "poly": _rect(0.43, 0.62, 0.57, 0.80)},
				{"op": "add", "poly": _rounded(0.22, 0.04, 0.32, 0.26, 0.04)}, {"op": "add", "poly": _rounded(0.68, 0.04, 0.78, 0.26, 0.04)}]
		"contract":
			# A sheet with its lines written and a wax seal pressed at the foot.
			return [ {"op": "add", "poly": _poly([[0.14, 0.04], [0.68, 0.04], [0.86, 0.22], [0.86, 0.96], [0.14, 0.96]])},
				{"op": "sub", "poly": _poly([[0.66, 0.04], [0.86, 0.24], [0.66, 0.24]])},
				{"op": "sub", "poly": _rect(0.25, 0.30, 0.62, 0.36)}, {"op": "sub", "poly": _rect(0.25, 0.44, 0.75, 0.50)},
				{"op": "sub", "poly": _rect(0.25, 0.58, 0.55, 0.64)},
				{"op": "sub", "circle": [0.66, 0.80, 0.15]}, {"op": "add", "circle": [0.66, 0.80, 0.105]},
				{"op": "sub", "poly": _star(5, 0.06, 0.025, Vector2(0.66, 0.80))}]
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
	var image := raster(glyph, edge, rainbow)
	image.generate_mipmaps()
	var built := ImageTexture.create_from_image(image)
	_cache[tag] = built
	return built

static func raster(glyph: String, edge: int, rainbow: bool = false) -> Image:
	## The mark drawn into a bare image, without mipmaps and without touching the cache, so
	## it is safe to call from a worker thread.
	edge = clampi(edge, 8, 128)
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
	return image

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
