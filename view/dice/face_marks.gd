extends RefCounted
## The marks engraved on a creature's action dice: one move a face, drawn as a mark instead of
## a number. A mark is a base (what the move does: a sword, a shield, a heart) and, after a
## double underscore, a modifier cut into its lower right corner (how: ×3, through block, kept,
## per reroll): "f_sword", "f_sword__m_x3", "shield__m_kept".
##
## Drawn in the shape language of `gem_icons.gd`, and many are gem emblems taken as they are.
## These are a set of their own: a face may share a drawing with a skill, but nothing here
## changes a glyph there. A composed mark fits the base into most of the square, the modifier
## small in its corner, and cuts an even gap round the modifier out of the base, so the two
## never run together. White on clear, so the die tints them (ivory, slate on a dud face).

const G = preload("res://view/gems/gem_icons.gd")

## The pixel size every mark is baked at: big enough for a die filling the inspector.
const EDGE := 256
## The bases the creatures' moves are drawn with, and the modifiers that ride them.
const BASES := ["f_sword", "labrys_tilt", "shield", "thorns_c", "hide_h", "prism", "snare_d", "f_coin_taken",
	"gem_d", "heart", "bolt", "call_b", "hammered_anvil", "dice_pair", "hourglass", "flee", "flame", "drop", "hex",
	"cut", "eye", "broken_chain", "spark", "cloud", "swirl", "shield_cut", "hush", "morph", "copy", "wave"]
const MODIFIERS := ["m_x2", "m_x3", "m_x4", "m_x5", "m_x10", "m_pierce", "m_kept", "m_raise", "m_richest",
	"m_reroll", "m_spark", "m_drop"]

## Where a composed mark's parts sit, as the owner approved them: the base's ink fitted to a
## square this wide about a point a little up and left of the middle, the modifier fitted to a
## square under half that in the corner (a count a touch further in, its × reaching left).
const BASE_BOX := 0.84 * 0.92
const BASE_AT := Vector2(0.47, 0.47)
const MODIFIER_BOX := 0.42 * 0.92
const MODIFIER_AT := Vector2(0.78, 0.78)
const COUNT_AT := Vector2(0.76, 0.76)
## How far the gap reaches out from the modifier's ink, as a share of the square: the approved
## marks grew the modifier by a 7.5%-wide square brush (19 px each way at 512).
const GAP := 19.0 / 512.0

static var _cache: Dictionary = {}

# --- the drawings ---------------------------------------------------------------------------

static func _upright_sword() -> Array:
	return [ {"op": "add", "poly": G._poly([[0.50, 0.00], [0.60, 0.14], [0.60, 0.62], [0.40, 0.62], [0.40, 0.14]])},
		{"op": "add", "poly": G._rect(0.26, 0.62, 0.74, 0.71)},
		{"op": "add", "poly": G._rect(0.44, 0.70, 0.56, 0.90)},
		{"op": "add", "circle": [0.5, 0.92, 0.07]}]

static func _gem() -> Array:
	return [ {"op": "add", "poly": G._poly([[0.24, 0.20], [0.76, 0.20], [0.94, 0.42], [0.06, 0.42]])},
		{"op": "add", "poly": G._poly([[0.06, 0.42], [0.94, 0.42], [0.50, 0.96]])}]

static func _times() -> Array:
	## The × of a count: small, low, by the foot of its figure.
	return [ {"op": "add", "poly": G._bar(Vector2(0.04, 0.70), Vector2(0.26, 0.92), 0.095)},
		{"op": "add", "poly": G._bar(Vector2(0.04, 0.92), Vector2(0.26, 0.70), 0.095)}]

static func _slashed_shield() -> Array:
	return G._shield_ring(Vector2(0.5, 0.5), 0.36, 0.40, 0.12) + [ {"op": "sub", "poly": G._bar(Vector2(0.10, 0.90), Vector2(0.90, 0.10), 0.22)},
		{"op": "add", "poly": G._bar(Vector2(0.10, 0.90), Vector2(0.90, 0.10), 0.12)}]

static func shapes(name: String) -> Array:
	## One base or modifier, in the unit square. A name drawn nowhere here is a gem emblem
	## (or interface glyph) borrowed as it stands; one drawn nowhere at all is empty.
	match name:
		"f_sword":
			# The sword at a slant, the way it is swung.
			return G._fitted(G._turned(_upright_sword(), deg_to_rad(38.0)))
		"labrys_tilt":
			# Cleave's axe, swung at the sword's slant.
			return G._fitted(G._turned(G._shapes("labrys"), deg_to_rad(38.0)))
		"f_coin_taken":
			# A coin with a bite out of it, the crumbs flying.
			return [ {"op": "add", "circle": [0.46, 0.54, 0.44]}, {"op": "sub", "circle": [0.46, 0.54, 0.33]},
				{"op": "add", "circle": [0.46, 0.54, 0.25]}, {"op": "sub", "poly": G._rect(0.18, 0.50, 0.74, 0.58)},
				{"op": "add", "poly": G._rect(0.24, 0.52, 0.68, 0.56)},
				{"op": "sub", "circle": [0.80, 0.26, 0.21]},
				{"op": "add", "circle": [0.86, 0.08, 0.045]}, {"op": "add", "circle": [0.95, 0.20, 0.04]}, {"op": "add", "circle": [0.93, 0.36, 0.035]}]
		"thorns_c":
			# A briar ring: a band with six thorns standing out of it.
			var briar: Array = G._band_ring(Vector2(0.5, 0.5), 0.25, 0.11)
			for index in 6:
				var angle: float = TAU * float(index) / 6.0 - PI * 0.5
				var dir := Vector2(cos(angle), sin(angle))
				var side := Vector2(-dir.y, dir.x)
				var base := Vector2(0.5, 0.5) + dir * 0.27
				var tip := Vector2(0.5, 0.5) + dir * 0.49
				briar.append({"op": "add", "poly": PackedVector2Array([base + side * 0.075, tip, base - side * 0.075])})
			return briar
		"call_b":
			# A figure and a plus: one more comes.
			return G._fitted([ {"op": "add", "circle": [0.38, 0.24, 0.14]},
				{"op": "add", "poly": G._poly([[0.18, 0.98], [0.58, 0.98], [0.58, 0.62], [0.52, 0.42], [0.24, 0.42], [0.18, 0.62]])},
				{"op": "add", "poly": G._rect(0.66, 0.42, 0.98, 0.52)}, {"op": "add", "poly": G._rect(0.77, 0.31, 0.87, 0.63)}])
		"snare_d":
			# A spiral drawing in.
			var points: Array = []
			for index in 61:
				var t: float = float(index) / 60.0
				var angle: float = t * TAU * 1.8
				var radius: float = 0.04 + 0.42 * t
				points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius)
			return G._fitted(G._stroke(points, 0.11))
		"gem_d":
			# A gem with a crack down the middle.
			return _gem() + G._line([[0.50, 0.17], [0.44, 0.36], [0.56, 0.54], [0.46, 0.74], [0.52, 0.98]], 0.075, "sub")
		"hide_h":
			# The way down: an arrow over a hole in the ground.
			return G._fitted([ {"op": "add", "poly": G._band(Vector2(0.5, 0.80), 0.34, 0.13, 0.10, 0.0, TAU)},
				{"op": "add", "poly": G._bar(Vector2(0.50, 0.02), Vector2(0.50, 0.30), 0.15)},
				{"op": "add", "poly": G._poly([[0.50, 0.60], [0.24, 0.28], [0.76, 0.28]])}])
		"swirl":
			# Festering: a whirl of three arms about the very centre.
			var whirl: Array = []
			for index in 3:
				var turn: float = TAU * float(index) / 3.0
				whirl.append_array(G._turned(G._stroke(G._curve([0.50, 0.50], [0.90, 0.38], [0.76, 0.06], 10), 0.12), turn))
			whirl.append({"op": "add", "circle": [0.5, 0.5, 0.12]})
			return G._moved(whirl, Vector2(0.08, 0.08), 0.84)
		"wave":
			# Flood: three breaking waves stacked.
			var water: Array = []
			for row in 3:
				var y: float = 0.22 + 0.28 * float(row)
				water.append_array(G._stroke(G._curve([0.04, y + 0.10], [0.30, y - 0.16], [0.52, y + 0.06], 8) + G._curve([0.52, y + 0.06], [0.74, y - 0.16], [0.96, y + 0.06], 8), 0.11))
			return G._fitted(water)
		"shield_cut":
			# Block melted away: a shield with a slash through it.
			return G._fitted(_slashed_shield())
		"morph":
			# Becomes another creature: the ghost emblem.
			return G._shapes("ghost")
		"hush":
			# Resonance halved: a rising signal with a slash through it.
			return [ {"op": "add", "poly": G._rect(0.08, 0.62, 0.28, 0.94)}, {"op": "add", "poly": G._rect(0.40, 0.38, 0.60, 0.94)}, {"op": "add", "poly": G._rect(0.72, 0.14, 0.92, 0.94)},
				{"op": "sub", "poly": G._bar(Vector2(0.06, 0.92), Vector2(0.94, 0.08), 0.24)}, {"op": "add", "poly": G._bar(Vector2(0.06, 0.92), Vector2(0.94, 0.08), 0.12)}]
		"flee":
			# Leaving: an arrow out of the door.
			return G._fitted([ {"op": "add", "poly": G._rect(0.06, 0.08, 0.20, 0.92)}, {"op": "add", "poly": G._rect(0.06, 0.08, 0.46, 0.20)}, {"op": "add", "poly": G._rect(0.06, 0.80, 0.46, 0.92)},
				{"op": "add", "poly": G._bar(Vector2(0.30, 0.50), Vector2(0.74, 0.50), 0.14)},
				{"op": "add", "poly": G._poly([[0.98, 0.50], [0.66, 0.26], [0.66, 0.74]])}])
		# -- the modifiers --
		"m_raise":
			# Raised: two chevrons climbing.
			return G._line([[0.16, 0.50], [0.50, 0.16], [0.84, 0.50]], 0.17) + G._line([[0.16, 0.88], [0.50, 0.54], [0.84, 0.88]], 0.17)
		"m_richest":
			# The richest: a coin with a glint.
			return [ {"op": "add", "circle": [0.46, 0.54, 0.42]}, {"op": "sub", "circle": [0.46, 0.54, 0.30]}, {"op": "add", "circle": [0.46, 0.54, 0.19]},
				{"op": "add", "poly": G._star(4, 0.20, 0.06, Vector2(0.82, 0.18))}]
		"m_kept":
			# Kept: a padlock.
			return [ {"op": "add", "poly": G._band(Vector2(0.5, 0.36), 0.21, 0.21, 0.11, PI, TAU)},
				{"op": "add", "poly": G._rounded(0.16, 0.42, 0.84, 0.94, 0.08)},
				{"op": "sub", "circle": [0.50, 0.62, 0.075]}, {"op": "sub", "poly": G._rect(0.455, 0.62, 0.545, 0.80)}]
		"m_pierce":
			# Through: an arrow passing through a bar (your block).
			return [ {"op": "add", "poly": G._rect(0.44, 0.06, 0.58, 0.94)},
				{"op": "sub", "poly": G._rect(0.02, 0.38, 0.98, 0.62)},
				{"op": "add", "poly": G._bar(Vector2(0.04, 0.50), Vector2(0.72, 0.50), 0.14)},
				{"op": "add", "poly": G._poly([[0.98, 0.50], [0.66, 0.26], [0.66, 0.74]])}]
		"m_spark":
			# Then becomes something else: one bright sparkle.
			return [ {"op": "add", "poly": G._star(4, 0.47, 0.12, Vector2(0.5, 0.5))}]
		"m_reroll":
			# Per reroll: the game's own "again" ring.
			return G._shapes("reroll")
		"m_drop":
			# A rider: and Poison.
			return G._shapes("drop")
		"m_x2":
			# ×2 in a condensed bold: a rounded top, a straight diagonal, a flat foot.
			return G._fitted(_times() + [ {"op": "add", "poly": G._band(Vector2(0.66, 0.30), 0.20, 0.22, 0.14, -3.0, 0.55)}]
				+ [ {"op": "add", "poly": G._bar(Vector2(0.82, 0.42), Vector2(0.44, 0.86), 0.14)}, {"op": "add", "poly": G._rect(0.40, 0.84, 0.92, 0.98)}])
		"m_x3":
			# ×3: a flat top, a diagonal to the waist, a round bowl.
			return G._fitted(_times() + [ {"op": "add", "poly": G._rect(0.40, 0.02, 0.92, 0.16)},
				{"op": "add", "poly": G._bar(Vector2(0.86, 0.12), Vector2(0.60, 0.46), 0.14)},
				{"op": "add", "poly": G._band(Vector2(0.66, 0.70), 0.21, 0.24, 0.14, -1.9, 2.5)}])
		"m_x4":
			# ×4: an upright, a diagonal, a crossbar.
			return G._fitted(_times() + [ {"op": "add", "poly": G._rect(0.74, 0.02, 0.90, 0.98)},
				{"op": "add", "poly": G._poly([[0.74, 0.02], [0.90, 0.02], [0.52, 0.72], [0.36, 0.72]])},
				{"op": "add", "poly": G._rect(0.36, 0.60, 0.98, 0.74)}])
		"m_x5":
			# ×5: a flat top, a stem to the waist, a bowl.
			return G._fitted(_times() + [ {"op": "add", "poly": G._rect(0.40, 0.02, 0.92, 0.16)},
				{"op": "add", "poly": G._rect(0.40, 0.02, 0.55, 0.52)},
				{"op": "add", "poly": G._rect(0.40, 0.40, 0.68, 0.54)},
				{"op": "add", "poly": G._band(Vector2(0.66, 0.70), 0.21, 0.24, 0.14, -1.9, 2.5)}])
		"m_x10":
			# ×10: a flagged one and a squared nought.
			return G._fitted(_times() + [ {"op": "add", "poly": G._rect(0.34, 0.02, 0.48, 0.98)},
				{"op": "add", "poly": G._poly([[0.34, 0.02], [0.48, 0.02], [0.48, 0.16], [0.26, 0.24], [0.26, 0.12]])},
				{"op": "add", "poly": G._rect(0.58, 0.02, 0.98, 0.98)}, {"op": "sub", "poly": G._rect(0.72, 0.16, 0.84, 0.84)}])
	return G._shapes(name)

# --- composing ------------------------------------------------------------------------------

static func parts(mark: String) -> Array:
	## [base, modifier] of a mark; the modifier is "" for a plain one.
	var split: PackedStringArray = mark.split("__", true, 1)
	return [split[0], split[1] if split.size() > 1 else ""]

static func drawn(mark: String) -> Array:
	## The whole mark as one list of shapes, a modifier composed into its corner.
	var pieces: Array = parts(mark)
	var base: Array = shapes(str(pieces[0]))
	var modifier: String = str(pieces[1])
	if modifier.is_empty():
		return base
	var rider: Array = shapes(modifier)
	if rider.is_empty():
		return base
	var corner: Array = _placed(rider, MODIFIER_BOX, COUNT_AT if modifier.begins_with("m_x") else MODIFIER_AT)
	return _placed(base, BASE_BOX, BASE_AT) + _gap(corner, GAP) + corner

static func _placed(drawing: Array, box: float, at: Vector2) -> Array:
	## Its ink fitted to a square `box` wide centred on `at`. The ink is measured inside the
	## unit square, as the approved marks were measured off their own pictures.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for shape in drawing:
		if str(shape.op) != "add":
			continue
		if shape.has("circle"):
			var circle: Array = shape.circle
			lo = lo.min(Vector2(circle[0] - circle[2], circle[1] - circle[2]))
			hi = hi.max(Vector2(circle[0] + circle[2], circle[1] + circle[2]))
		else:
			for point in shape.poly:
				lo = lo.min(point)
				hi = hi.max(point)
	if lo.x > hi.x:
		return []
	lo = lo.clamp(Vector2.ZERO, Vector2.ONE)
	hi = hi.clamp(Vector2.ZERO, Vector2.ONE)
	var scale: float = box / maxf(0.0001, maxf(hi.x - lo.x, hi.y - lo.y))
	return G._moved(drawing, at - (lo + hi) * 0.5 * scale, scale)

static func _gap(drawing: Array, reach: float) -> Array:
	## The drawing's ink grown `reach` every way, as shapes that cut: each part, every edge of it
	## swept by a square, every round grown into a rounded square. A square brush, as the approved
	## marks were cut. Holes inside the modifier are cut through too, so nothing of the base
	## shows inside it.
	var cut: Array = []
	var corners: Array = [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(reach, reach), Vector2(-reach, reach)]
	for shape in drawing:
		if str(shape.op) != "add":
			continue
		if shape.has("circle"):
			var circle: Array = shape.circle
			var x: float = float(circle[0])
			var y: float = float(circle[1])
			var r: float = float(circle[2])
			cut.append({"op": "sub", "poly": G._rounded(x - r - reach, y - r - reach, x + r + reach, y + r + reach, r)})
			continue
		var poly: PackedVector2Array = shape.poly
		cut.append({"op": "sub", "poly": poly})
		for index in poly.size():
			var a: Vector2 = poly[index]
			var b: Vector2 = poly[(index + 1) % poly.size()]
			var swept := PackedVector2Array()
			for offset in corners:
				swept.append(a + offset)
				swept.append(b + offset)
			cut.append({"op": "sub", "poly": Geometry2D.convex_hull(swept)})
	return cut

# --- baking ---------------------------------------------------------------------------------

static func raster(mark: String, edge: int = EDGE) -> Image:
	## The mark drawn into a bare image, white on clear, without mipmaps and without touching
	## the cache. Coverage is sampled four times finer and boxed down, as the gem glyphs are.
	var span: int = edge * G.SUPER
	var image := Image.create(span, span, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for shape in drawn(mark):
		var ink := Color(1, 1, 1, 1) if str(shape.op) == "add" else Color(1, 1, 1, 0)
		if shape.has("circle"):
			G._fill_circle(image, span, shape.circle, ink)
		else:
			G._fill_polygon(image, span, shape.poly, ink)
	image.shrink_x2()
	image.shrink_x2()
	return image

static func texture(mark: String) -> Texture2D:
	## The mark at EDGE px with mipmaps, baked once and kept.
	var cached: Texture2D = _cache.get(mark, null)
	if cached != null:
		return cached
	var image: Image = raster(mark)
	image.generate_mipmaps()
	var built := ImageTexture.create_from_image(image)
	_cache[mark] = built
	return built

static func known(mark: String) -> bool:
	return not shapes(str(parts(mark)[0])).is_empty()

static func release() -> void:
	## Drops the baked marks so nothing outlives the interface.
	_cache.clear()
