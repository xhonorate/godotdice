extends RefCounted
## Paints a gem from its four C's, so two gems that differ in one property look different.
##
## Nothing here is pre-baked. A gem's picture is a function of Color, Carat, Cut and
## Clarity, and every one of those four changes something you can see without reading a
## number:
##
##   Color   picks the cut's outline and the body hue - triangle for Red, square for
##           Blue, heart for Green, marquise for Violet, round brilliant for Gold.
##   Carat   picks the size, on a curve, so a 24 is under three times a 1 rather than
##           twenty-four times it.
##   Cut     picks how intricate the faceting is: how many facets ring the stone, how
##           many bands they form, and how small the table in the middle ends up.
##   Clarity picks the brilliance: facet contrast, colour saturation, the strength of
##           the highlight, a star flare at the top ranks and visible flaws at the bottom.
##
## The skill's emblem is etched into the table rather than laid over it: the incision is
## drawn as a shadowed upper wall, a lit lower wall and a recessed floor, and every part
## of it only recolours pixels the stone already covers.
##
## This is 2D on purpose. Gems appear as interface icons at four sizes and often six at
## once; a texture drops straight into the existing icon path, whereas 3D would need a
## viewport, camera and light rig per distinct stone to become one. The rest of the art
## in this project is procedural 2D for the same reason, and faceting reads perfectly
## well as flat shaded polygons.

const Catalog = preload("res://scripts/core/catalog.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")

## Which cut each Color wears. Shape carries the category as loudly as hue does, and it
## survives greyscale, colour blindness and a 32-pixel thumbnail.
const CUTS := {"RED": "trilliant", "BLUE": "princess", "GREEN": "heart",
	"VIOLET": "marquise", "GOLD": "round"}
## Cut rank drives all three of these together: more points along each edge, more bands
## of facets between girdle and table, and a smaller table for the higher ranks.
const EDGE_STEPS := [1, 1, 2, 2, 3]
const BANDS := [1, 2, 2, 3, 3]
const TABLE_SPAN := [0.56, 0.50, 0.45, 0.40, 0.35]
## How wide the etched emblem sits, per outline, as a fraction of the stone's reach. A
## marquise is narrow at the waist and a princess is square, so one number cannot serve.
const EMBLEM_SPAN := {"trilliant": 0.86, "princess": 1.10, "heart": 0.94,
	"marquise": 0.78, "round": 1.06}
const LIGHT := Vector2(-0.57, -0.82)
const OUTLINE := Color("080b13")
const CACHE_LIMIT := 96

static var _cache: Dictionary = {}
static var _order: Array = []

# --- the four properties as numbers -------------------------------------------

static func carat_scale(carat: int) -> float:
	## 0.46 of the icon at Carat 1 up to the full 1.0 at Carat 24, on a curve: area grows
	## roughly with the rank, so the small end stays visible and the top stays sane.
	## The floor is what it is because the same stone has to read in a 48-pixel list row,
	## where a lower one turned a Carat 1 gem into a speck. That leaves a 2.2x span from
	## the bottom of the range to the top, well inside the 3x a stone should ever grow.
	var t := float(clampi(carat, 1, 24) - 1) / 23.0
	return 0.46 + 0.54 * pow(t, 0.62)

static func brilliance(clarity: int) -> float:
	return float(clampi(clarity, 1, 5) - 1) / 4.0

static func flaw_count(clarity: int) -> int:
	## Inclusions a stone carries. The top two ranks are clean by definition.
	return [5, 3, 1, 0, 0][clampi(clarity, 1, 5) - 1]

static func facet_count(cut: int, color_key: String) -> int:
	var k: int = clampi(cut, 1, 5)
	return silhouette(color_key).size() * EDGE_STEPS[k - 1] * 2 * BANDS[k - 1]

static func _body_colour(color_key: String, clarity: int) -> Color:
	## A dull stone is not just darker: it is greyer. Clarity pulls the hue back towards
	## stone as it falls, which is what makes a Fractured gem look cloudy.
	var hue := Color(str(Catalog.GEM_COLORS.get(color_key, Catalog.GEM_COLORS.RED).hex))
	var b := brilliance(clarity)
	return hue.lerp(Color("6d7280"), lerpf(0.38, 0.0, b)).lerp(Color.BLACK, lerpf(0.16, 0.0, b))

# --- outlines -----------------------------------------------------------------

static func silhouette(color_key: String) -> PackedVector2Array:
	## Unit space, centred on the origin, longest reach 1.0.
	match str(CUTS.get(color_key, "round")):
		"trilliant":
			return _truncated(_regular(3, -PI * 0.5), 0.17)
		"princess":
			return _truncated(_regular(4, PI * 0.25), 0.20)
		"heart":
			return _heart()
		"marquise":
			return _marquise()
	return _regular(22, -PI * 0.5)

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
		var previous := points[(index + count - 1) % count]
		var here := points[index]
		var following := points[(index + 1) % count]
		built.append(here.lerp(previous, amount))
		built.append(here.lerp(following, amount))
	return built

static func _heart() -> PackedVector2Array:
	var raw: Array = []
	var peak := 0.0
	for index in range(26):
		var t := TAU * float(index) / 26.0
		var point := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		raw.append(point)
		peak = maxf(peak, point.length())
	var built := PackedVector2Array()
	for point in raw:
		built.append(Vector2(point) / peak)
	return built

static func _marquise() -> PackedVector2Array:
	## Two arcs meeting at a point top and bottom.
	var built := PackedVector2Array()
	var steps := 7
	for index in range(1, steps):
		var t := float(index) / float(steps)
		built.append(Vector2(sin(PI * t) * 0.54, -cos(PI * t)))
	built.append(Vector2(0.0, 1.0))
	for index in range(1, steps):
		var t := float(index) / float(steps)
		built.append(Vector2(-sin(PI * t) * 0.54, cos(PI * t)))
	built.append(Vector2(0.0, -1.0))
	return built

static func _resample(base: PackedVector2Array, steps: int) -> PackedVector2Array:
	## Inserts vertices along each edge without moving the outline, so a higher Cut adds
	## facets to the same stone rather than rounding it off into a different shape.
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

static func _band(base: PackedVector2Array, scale: float, staggered: bool, centre: Vector2, radius: float) -> PackedVector2Array:
	var built := PackedVector2Array()
	var count := base.size()
	for index in count:
		var point: Vector2 = base[index]
		if staggered:
			point = point.lerp(base[(index + 1) % count], 0.5)
		built.append(centre + point * (radius * scale))
	return built

# --- raster helpers -----------------------------------------------------------

static func _put(image: Image, x: int, y: int, color: Color, weight: float) -> void:
	if weight <= 0.002 or x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var source := clampf(weight, 0.0, 1.0) * color.a
	var under := image.get_pixel(x, y)
	var out := source + under.a * (1.0 - source)
	if out <= 0.002:
		return
	var mix := (1.0 - source) * under.a / out
	image.set_pixel(x, y, Color(lerpf(color.r, under.r, mix), lerpf(color.g, under.g, mix),
		lerpf(color.b, under.b, mix), out))

static func _tint(image: Image, x: int, y: int, color: Color, weight: float) -> void:
	## Recolours coverage the stone already has. Everything drawn on the gem — highlight,
	## flaw, etched emblem — goes through here, so none of it can widen the silhouette.
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var under := image.get_pixel(x, y)
	if under.a <= 0.02:
		return
	var amount := clampf(weight, 0.0, 1.0) * color.a * under.a
	image.set_pixel(x, y, Color(lerpf(under.r, color.r, amount), lerpf(under.g, color.g, amount),
		lerpf(under.b, color.b, amount), under.a))

static func _span(image: Image, from_x: float, to_x: float, y: int, color: Color, weight: float, masked: bool) -> void:
	if to_x <= from_x or y < 0 or y >= image.get_height():
		return
	for x in range(maxi(int(floor(from_x)), 0), mini(int(ceil(to_x)), image.get_width())):
		var cover := minf(to_x, float(x) + 1.0) - maxf(from_x, float(x))
		if cover <= 0.0:
			continue
		if masked:
			_tint(image, x, y, color, weight * cover)
		else:
			_put(image, x, y, color, weight * cover)

static func _fill(image: Image, points: PackedVector2Array, color: Color, weight := 1.0, masked := false) -> void:
	if points.size() < 3:
		return
	var top := INF
	var bottom := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	for y in range(maxi(int(floor(top)), 0), mini(int(ceil(bottom)) + 1, image.get_height())):
		var scan := float(y) + 0.5
		var crossings: Array[float] = []
		for index in range(points.size()):
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan):
				crossings.append(a.x + (scan - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var index := 0
		while index + 1 < crossings.size():
			_span(image, crossings[index], crossings[index + 1], y, color, weight, masked)
			index += 2

static func _disc(image: Image, centre: Vector2, rx: float, ry: float, color: Color, weight := 1.0, masked := false) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	for y in range(maxi(int(floor(centre.y - ry)), 0), mini(int(ceil(centre.y + ry)) + 1, image.get_height())):
		var dy := (float(y) + 0.5 - centre.y) / ry
		if absf(dy) >= 1.0:
			continue
		var half := rx * sqrt(1.0 - dy * dy)
		_span(image, centre.x - half, centre.x + half, y, color, weight, masked)

static func _stroke(image: Image, a: Vector2, b: Vector2, width: float, color: Color, weight: float) -> void:
	var along := b - a
	if along.length() < 0.01:
		return
	var side := along.orthogonal().normalized() * (width * 0.5)
	_fill(image, PackedVector2Array([a + side, b + side, b - side, a - side]), color, weight, true)

static func _flare(centre: Vector2, reach: float) -> PackedVector2Array:
	## A four-point star with needle points: the shape light makes on a clean facet.
	var built := PackedVector2Array()
	for index in 8:
		var angle := PI * float(index) / 4.0
		var radius: float = reach if index % 2 == 0 else reach * 0.085
		built.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return built

static func _stamp(image: Image, mask: Image, centre: Vector2, span: float, color: Color, weight: float) -> void:
	## Draws an alpha mask scaled to `span`, recolouring only what the stone covers.
	var half := span * 0.5
	var source := float(mask.get_width())
	for y in range(maxi(int(centre.y - half), 0), mini(int(centre.y + half) + 1, image.get_height())):
		for x in range(maxi(int(centre.x - half), 0), mini(int(centre.x + half) + 1, image.get_width())):
			var u := (float(x) + 0.5 - (centre.x - half)) / span * source
			var v := (float(y) + 0.5 - (centre.y - half)) / span * source
			if u < 0.0 or v < 0.0 or u >= source or v >= source:
				continue
			var alpha := mask.get_pixel(int(u), int(v)).a
			if alpha > 0.02:
				_tint(image, x, y, color, weight * alpha)

static func _edge_pass(image: Image, color: Color, thickness: int) -> void:
	## A dark girdle around whatever the stone ended up covering.
	var width := image.get_width()
	var height := image.get_height()
	for _pass in thickness:
		var found: Array = []
		for y in height:
			for x in width:
				if image.get_pixel(x, y).a > 0.06:
					continue
				var touching := false
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var probe: Vector2i = Vector2i(x, y) + step
					if probe.x < 0 or probe.y < 0 or probe.x >= width or probe.y >= height:
						continue
					if image.get_pixel(probe.x, probe.y).a > 0.55:
						touching = true
						break
				if touching:
					found.append(Vector2i(x, y))
		for point in found:
			image.set_pixel(point.x, point.y, color)

static func _hash01(seed_value: int) -> float:
	var mixed := (seed_value * 1103515245 + 12345) & 0x7fffffff
	mixed = (mixed ^ (mixed >> 13)) * 1274126177
	return float((mixed ^ (mixed >> 16)) & 0xffff) / 65535.0

static func _shade(body: Color, lift: float) -> Color:
	if lift >= 0.0:
		return body.lightened(minf(lift, 0.86))
	return body.darkened(minf(-lift, 0.64))

# --- the stone ----------------------------------------------------------------

static func _paint(gem: Dictionary, edge: int) -> Image:
	var key: String = Catalog.canonical_key(str(gem.get("key", "")))
	var color_key: String = Catalog.gem_color(key)
	var c: int = clampi(int(gem.get("carat", 1)), 1, 24)
	var k: int = clampi(int(gem.get("cut", 1)), 1, 5)
	var l: int = clampi(int(gem.get("clarity", 1)), 1, 5)
	var b := brilliance(l)
	var image := Image.create(edge, edge, false, Image.FORMAT_RGBA8)
	var centre := Vector2(edge, edge) * 0.5
	var radius := float(edge) * 0.455 * carat_scale(c)
	var body := _body_colour(color_key, l)
	var hue := Color(str(Catalog.GEM_COLORS.get(color_key, Catalog.GEM_COLORS.RED).hex))
	var base := _resample(silhouette(color_key), EDGE_STEPS[k - 1])
	var bands: int = BANDS[k - 1]
	var seed_value: int = key.hash()

	# A clean stone throws light onto what it sits on; a cloudy one barely does.
	for step in range(3, 0, -1):
		var reach := radius * (1.0 + 0.10 * float(step))
		_disc(image, centre, reach, reach, Color(hue, (0.045 + 0.075 * b) / float(step)))

	# Girdle to table, one ring per band, alternate rings staggered so the facets meet in
	# the zig-zag a real brilliant cut makes rather than in a stack of concentric rings.
	var rings: Array = []
	for index in range(bands + 1):
		var t := float(index) / float(bands)
		var scale: float = lerpf(1.0, TABLE_SPAN[k - 1], t)
		rings.append(_band(base, scale, index % 2 == 1 and index < bands, centre, radius))

	var amp := lerpf(0.13, 0.42, b)
	var grain := lerpf(0.13, 0.045, b)
	var count := base.size()
	var facet := 0
	for band in range(bands):
		var outer: PackedVector2Array = rings[band]
		var inner: PackedVector2Array = rings[band + 1]
		var depth := 1.0 - float(band) / float(maxi(bands, 1))
		for index in count:
			for triangle in [
					PackedVector2Array([outer[index], outer[(index + 1) % count], inner[index]]),
					PackedVector2Array([outer[(index + 1) % count], inner[(index + 1) % count], inner[index]])]:
				var middle: Vector2 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
				var away := middle - centre
				var lambert := 0.0 if away.length() < 0.001 else away.normalized().dot(LIGHT)
				var alternate := 0.80 if facet % 2 == 0 else 1.20
				var lift := 0.06 * (1.0 - depth) + lambert * amp * (0.55 + 0.45 * depth) * alternate \
					+ (_hash01(seed_value + facet) - 0.5) * grain
				_fill(image, triangle, _shade(body, lift))
				facet += 1

	var table: PackedVector2Array = rings[bands]
	_fill(image, table, _shade(body, 0.08 + 0.26 * b))

	# One faint line around the table only. Outlining every ring buried the facets under
	# a web of seams and made all five Cuts look alike.
	if edge >= 72:
		var seam := Color(body.darkened(0.5), 0.14 + 0.18 * b)
		for index in count:
			_stroke(image, table[index], table[(index + 1) % count], maxf(1.0, float(edge) * 0.005), seam, 1.0)

	# Brilliance: a highlight on the lit shoulder, and a star only the top ranks earn.
	# Out on the shoulder, not across the face: a highlight sitting on the table washed
	# the etched emblem out just where it needed contrast.
	var lit := centre + Vector2(LIGHT.x, LIGHT.y) * radius * 0.56
	_disc(image, lit, radius * 0.27, radius * 0.18, Color(1, 1, 1, 0.12 + 0.66 * b), 1.0, true)
	if l >= 4:
		_fill(image, _flare(lit, radius * (0.40 + 0.34 * b)), Color(1, 1, 1, 0.52 + 0.40 * b), 1.0, true)

	# Flaws: a Fractured stone carries visible inclusions, a Flawless one carries none.
	for index in flaw_count(l):
		var angle := _hash01(seed_value + 61 + index) * TAU
		var reach := radius * (0.22 + 0.58 * _hash01(seed_value + 131 + index))
		var spot := centre + Vector2(cos(angle), sin(angle)) * reach
		var size := radius * (0.07 + 0.10 * _hash01(seed_value + 197 + index))
		_disc(image, spot, size, size * 0.66, Color(body.darkened(0.70), 0.78), 1.0, true)
		_disc(image, spot - Vector2(size, size) * 0.35, size * 0.45, size * 0.30,
			Color(1, 1, 1, 0.22), 1.0, true)

	_etch(image, key, centre, radius * float(EMBLEM_SPAN.get(str(CUTS.get(color_key, "round")), 1.0)), body, edge)
	_edge_pass(image, OUTLINE, 1 if edge < 96 else 2)
	return image

static func _etch(image: Image, key: String, centre: Vector2, span: float, body: Color, edge: int) -> void:
	## The skill's emblem cut into the table. Light falls from the upper left, so the wall
	## facing that way is in shadow and the far wall catches it; the floor between them
	## sits a shade under the stone. Every pass is masked, so the groove cannot spill
	## outside the gem or add to its outline.
	if span < 7.0:
		return
	var mask: Image = GemIcons.texture(GemIcons.emblem(key), 64).get_image()
	mask.convert(Image.FORMAT_RGBA8)
	var relief := maxf(1.0, float(edge) * 0.015)
	var step := Vector2(LIGHT.x, LIGHT.y) * relief
	_stamp(image, mask, centre + step, span, body.darkened(0.78), 0.92)
	_stamp(image, mask, centre - step, span, Color(1, 1, 1), 0.55)
	_stamp(image, mask, centre, span, body.darkened(0.44), 0.82)

# --- public -------------------------------------------------------------------

static func texture(gem: Dictionary, edge: int) -> ImageTexture:
	edge = clampi(edge, 16, 256)
	var tag := "%s|%d|%d|%d|%d" % [Catalog.canonical_key(str(gem.get("key", ""))),
		clampi(int(gem.get("carat", 1)), 1, 24), clampi(int(gem.get("cut", 1)), 1, 5),
		clampi(int(gem.get("clarity", 1)), 1, 5), edge]
	var cached: ImageTexture = _cache.get(tag, null)
	if cached != null:
		return cached
	var built := ImageTexture.create_from_image(_paint(gem, edge))
	_cache[tag] = built
	_order.append(tag)
	while _order.size() > CACHE_LIMIT:
		_cache.erase(_order.pop_front())
	return built

static func describe(gem: Dictionary) -> String:
	## What the picture is saying, in words, so the visual language can be learned.
	var key: String = Catalog.canonical_key(str(gem.get("key", "")))
	var color_key: String = Catalog.gem_color(key)
	var c: int = clampi(int(gem.get("carat", 1)), 1, 24)
	var k: int = clampi(int(gem.get("cut", 1)), 1, 5)
	var l: int = clampi(int(gem.get("clarity", 1)), 1, 5)
	var size: String = ["tiny", "small", "middling", "large", "huge"][clampi((c - 1) / 5, 0, 4)]
	var lustre: String = ["cloudy and flawed", "dull, with a visible flaw", "clear",
		"bright and clean", "blazing"][l - 1]
	return "A %s %s-cut %s stone with %d facets, %s. Carat %d sets its size, Cut %d its faceting, Clarity %d its lustre." % [
		size, str(CUTS.get(color_key, "round")), str(Catalog.GEM_COLORS.get(color_key, {}).get("name", "Red")).to_lower(),
		facet_count(k, color_key), lustre, c, k, l]

static func release() -> void:
	_cache.clear()
	_order.clear()
