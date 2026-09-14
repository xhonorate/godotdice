extends RefCounted
## Procedural sprite atlas. Every hero, enemy, relic and room icon is painted
## into an Image at load time and cached for the session.
##
## Authored art always wins. Drop a PNG at either location to replace a sprite
## without touching code; the file name is the lowercase content key.
##   res://assets/sprites/<category>/<key>.png   shipped with the build
##   user://sprites/<category>/<key>.png         local override, no reimport needed
## Categories: heroes, enemies, relics, rooms, props. Gems are not here: their picture
## depends on all four of a gem instance's properties, so `gem_render.gd` paints each one
## at runtime instead of serving one baked sprite per skill.

const UNIT := 128
const ICON := 72

static var _cache: Dictionary = {}

# --- palettes -----------------------------------------------------------------

static func _skin(key: String) -> Dictionary:
	match key:
		"ARDOR": return {"base": Color("e3944f"), "dark": Color("9d5326"), "trim": Color("ffd79a"), "cloth": Color("7a2f2a"), "metal": Color("d8c7a4")}
		"KAIT": return {"base": Color("7cc46b"), "dark": Color("356b40"), "trim": Color("dcf3b4"), "cloth": Color("2c4638"), "metal": Color("bcd7c4")}
		"MAX": return {"base": Color("8f9ff0"), "dark": Color("454da3"), "trim": Color("d3dcff"), "cloth": Color("29305e"), "metal": Color("b9c4ee")}
		"SLIME": return {"base": Color("6ddc8f"), "dark": Color("2b7a4c"), "trim": Color("c8ffd9"), "cloth": Color("1d5233"), "metal": Color("9df0bb")}
		"RED_SLIME": return {"base": Color("ef6a62"), "dark": Color("8d2a2a"), "trim": Color("ffc7bd"), "cloth": Color("5f1c1c"), "metal": Color("ff9c92")}
		"SLIME_KING": return {"base": Color("62d69a"), "dark": Color("236b48"), "trim": Color("f0d68a"), "cloth": Color("17452f"), "metal": Color("e8b661")}
		"STONE_CRAB": return {"base": Color("8d9aa8"), "dark": Color("434f5f"), "trim": Color("c9d4de"), "cloth": Color("2e3743"), "metal": Color("c1704f")}
		"GEM_CULTIST": return {"base": Color("6b4fa8"), "dark": Color("31215a"), "trim": Color("ffb0ea"), "cloth": Color("221643"), "metal": Color("ff7ad9")}
		"DARTLING": return {"base": Color("d8cf6a"), "dark": Color("6f6524"), "trim": Color("f6f0bd"), "cloth": Color("46401a"), "metal": Color("cfe8ff")}
		"IRON_WARDEN": return {"base": Color("93a6bd"), "dark": Color("3b4a5f"), "trim": Color("e8b661"), "cloth": Color("24303f"), "metal": Color("cfdcea")}
		"MIRROR_WISP": return {"base": Color("bfe9ff"), "dark": Color("4e86ab"), "trim": Color("ffffff"), "cloth": Color("2b4a63"), "metal": Color("8fd4ff")}
		"MIRROR_REGENT": return {"base": Color("cbd4ea"), "dark": Color("5d6689"), "trim": Color("ffffff"), "cloth": Color("343c63"), "metal": Color("b98bff")}
		"RIFT_HOUND": return {"base": Color("9d6ce0"), "dark": Color("452a78"), "trim": Color("ff9de0"), "cloth": Color("2a1848"), "metal": Color("d8b0ff")}
		"RIFT_SOVEREIGN": return {"base": Color("3a2560"), "dark": Color("160c2c"), "trim": Color("c98bff"), "cloth": Color("0d0620"), "metal": Color("ffe6a8")}
	return {"base": Color("8d93a8"), "dark": Color("3c4152"), "trim": Color("e6e9f2"), "cloth": Color("242838"), "metal": Color("c6cbdb")}

# --- public -------------------------------------------------------------------

static func unit(key: String) -> Texture2D:
	return _fetch("heroes" if key.to_upper() in ["ARDOR", "KAIT", "MAX"] else "enemies", key.to_upper())


static func relic(key: String) -> Texture2D:
	return _fetch("relics", key.to_upper())

static func room(kind: String) -> Texture2D:
	return _fetch("rooms", kind.to_lower())

static func prop(name: String) -> Texture2D:
	return _fetch("props", name.to_lower())

static func clear_cache() -> void:
	_cache.clear()

static func bake(category: String, key: String, tags: Array = [], rarity: int = 1) -> Image:
	## Paints one sprite, ignoring both the session cache and any authored override.
	## Used by tools/bake_sprites.gd to write the shipped PNGs; the runtime never calls it.
	match category:
		"heroes", "enemies": return _paint_unit(key.to_upper())
		"relics": return _paint_relic(key.to_upper())
		"rooms": return _paint_room(key.to_lower())
	return _paint_prop(key.to_lower())

static func _fetch(category: String, key: String) -> Texture2D:
	var id := category + "/" + key
	if _cache.has(id):
		return _cache[id]
	var found := _external(category, key.to_lower())
	if found == null:
		var image: Image
		match category:
			"heroes", "enemies": image = _paint_unit(key)
			"relics": image = _paint_relic(key)
			"rooms": image = _paint_room(key)
			_: image = _paint_prop(key)
		found = ImageTexture.create_from_image(image)
	_cache[id] = found
	return found

static func _external(category: String, key: String) -> Texture2D:
	var override := "user://sprites/%s/%s.png" % [category, key]
	if FileAccess.file_exists(override):
		var image := Image.new()
		if image.load(override) == OK:
			return ImageTexture.create_from_image(image)
	var shipped := "res://assets/sprites/%s/%s.png" % [category, key]
	if ResourceLoader.exists(shipped):
		var resource: Resource = load(shipped)
		if resource is Texture2D:
			return resource
	return null

# --- raster primitives --------------------------------------------------------

static func _blank(width: int, height: int = -1) -> Image:
	return Image.create(width, height if height > 0 else width, false, Image.FORMAT_RGBA8)

static func _put(image: Image, x: int, y: int, color: Color, weight: float) -> void:
	if weight <= 0.002 or x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var source := clampf(weight, 0.0, 1.0) * color.a
	var under := image.get_pixel(x, y)
	var out := source + under.a * (1.0 - source)
	if out <= 0.002:
		return
	var mix := (1.0 - source) * under.a / out
	image.set_pixel(x, y, Color(
		lerpf(color.r, under.r, mix), lerpf(color.g, under.g, mix), lerpf(color.b, under.b, mix), out))

static func _tint(image: Image, x: int, y: int, color: Color, weight: float) -> void:
	## Recolours existing coverage without adding silhouette.
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var under := image.get_pixel(x, y)
	if under.a <= 0.02:
		return
	var amount := clampf(weight, 0.0, 1.0) * color.a * under.a
	image.set_pixel(x, y, Color(
		lerpf(under.r, color.r, amount), lerpf(under.g, color.g, amount), lerpf(under.b, color.b, amount), under.a))

static func _span(image: Image, from_x: float, to_x: float, y: int, color: Color, weight: float, masked: bool) -> void:
	if to_x <= from_x or y < 0 or y >= image.get_height():
		return
	var first := maxi(int(floor(from_x)), 0)
	var last := mini(int(ceil(to_x)), image.get_width())
	for x in range(first, last):
		var cover := minf(to_x, float(x) + 1.0) - maxf(from_x, float(x))
		if cover <= 0.0:
			continue
		if masked:
			_tint(image, x, y, color, weight * cover)
		else:
			_put(image, x, y, color, weight * cover)

static func _ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color, weight: float = 1.0, masked: bool = false) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	for y in range(maxi(int(floor(cy - ry)), 0), mini(int(ceil(cy + ry)) + 1, image.get_height())):
		var dy: float = (float(y) + 0.5 - cy) / ry
		if absf(dy) >= 1.0:
			continue
		var half: float = rx * sqrt(1.0 - dy * dy)
		var edge: float = clampf((1.0 - absf(dy)) * ry, 0.0, 1.0)
		_span(image, cx - half, cx + half, y, color, weight * (0.35 + 0.65 * edge), masked)

static func _poly(image: Image, points: PackedVector2Array, color: Color, weight: float = 1.0, masked: bool = false) -> void:
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
		for i in range(points.size()):
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan):
				crossings.append(a.x + (scan - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var i := 0
		while i + 1 < crossings.size():
			_span(image, crossings[i], crossings[i + 1], y, color, weight, masked)
			i += 2

static func _stroke(image: Image, a: Vector2, b: Vector2, width: float, color: Color, weight: float = 1.0) -> void:
	var delta := b - a
	if delta.length() < 0.01:
		_ellipse(image, a.x, a.y, width * 0.5, width * 0.5, color, weight)
		return
	var offset := delta.orthogonal().normalized() * (width * 0.5)
	_poly(image, PackedVector2Array([a + offset, b + offset, b - offset, a - offset]), color, weight)
	_ellipse(image, a.x, a.y, width * 0.5, width * 0.5, color, weight)
	_ellipse(image, b.x, b.y, width * 0.5, width * 0.5, color, weight)

static func _path(image: Image, points: PackedVector2Array, width: float, color: Color) -> void:
	for i in range(points.size() - 1):
		_stroke(image, points[i], points[i + 1], width, color)

static func _mirror(image: Image) -> void:
	## Copies the painted left half onto the right for symmetric silhouettes.
	var width := image.get_width()
	var height := image.get_height()
	for y in height:
		for x in range(width / 2):
			image.set_pixel(width - 1 - x, y, image.get_pixel(x, y))

static func _shade(image: Image, light: float = 0.26, dark: float = 0.34) -> void:
	var height := image.get_height()
	for y in height:
		var ramp := lerpf(1.0 + light, 1.0 - dark, smoothstep(0.0, 1.0, float(y) / maxf(1.0, float(height - 1))))
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.02:
				continue
			image.set_pixel(x, y, Color(clampf(pixel.r * ramp, 0.0, 1.0), clampf(pixel.g * ramp, 0.0, 1.0), clampf(pixel.b * ramp, 0.0, 1.0), pixel.a))

static func _rim(image: Image, color: Color, strength: float = 0.5) -> void:
	## A soft highlight sweeping in from the upper left.
	var width := image.get_width()
	var height := image.get_height()
	_ellipse(image, width * 0.34, height * 0.24, width * 0.30, height * 0.26, color, strength, true)

static func _outline(image: Image, color: Color, thickness: int = 2) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var solid := PackedByteArray()
	solid.resize(width * height)
	for y in height:
		for x in width:
			solid[y * width + x] = 1 if image.get_pixel(x, y).a > 0.4 else 0
	var edge := PackedByteArray()
	edge.resize(width * height)
	for pass_index in thickness:
		var added: Array[int] = []
		for y in height:
			for x in width:
				var index := y * width + x
				if solid[index] == 1:
					continue
				var touching := false
				if x > 0 and solid[index - 1] == 1: touching = true
				elif x < width - 1 and solid[index + 1] == 1: touching = true
				elif y > 0 and solid[index - width] == 1: touching = true
				elif y < height - 1 and solid[index + width] == 1: touching = true
				if touching:
					added.append(index)
		for index in added:
			solid[index] = 1
			edge[index] = 1
	for index in edge.size():
		if edge[index] == 1:
			image.set_pixel(index % width, index / width, color)

static func _finish(image: Image, outline: Color = Color("0a0d16")) -> Image:
	_shade(image)
	_rim(image, Color(1, 1, 1, 1), 0.30)
	_outline(image, outline, 2)
	return image

# --- units --------------------------------------------------------------------

static func _paint_unit(key: String) -> Image:
	var image := _blank(UNIT)
	var skin := _skin(key)
	match key:
		"ARDOR": _ardor(image, skin)
		"KAIT": _kait(image, skin)
		"MAX": _max(image, skin)
		"SLIME": _slime(image, skin, 1.00, false)
		"RED_SLIME": _slime(image, skin, 1.12, false)
		"SLIME_KING": _slime(image, skin, 1.22, true)
		"STONE_CRAB": _crab(image, skin)
		"GEM_CULTIST": _cultist(image, skin)
		"DARTLING": _dartling(image, skin)
		"IRON_WARDEN": _warden(image, skin)
		"MIRROR_WISP": _wisp(image, skin, 0.62)
		"MIRROR_REGENT": _regent(image, skin)
		"RIFT_HOUND": _hound(image, skin)
		"RIFT_SOVEREIGN": _sovereign(image, skin)
		_: _unknown(image, skin)
	return _finish(image)

static func _ground(image: Image, color: Color) -> void:
	var u := float(image.get_width())
	_ellipse(image, u * 0.5, u * 0.93, u * 0.32, u * 0.055, color, 0.5)

static func _ardor(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.55))
	# tower shield behind the left arm
	_poly(image, PackedVector2Array([Vector2(u * 0.10, u * 0.36), Vector2(u * 0.30, u * 0.30), Vector2(u * 0.32, u * 0.72), Vector2(u * 0.20, u * 0.84), Vector2(u * 0.08, u * 0.72)]), skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.14, u * 0.40), Vector2(u * 0.27, u * 0.35), Vector2(u * 0.28, u * 0.69), Vector2(u * 0.20, u * 0.78), Vector2(u * 0.12, u * 0.68)]), skin.dark, 0.55)
	_stroke(image, Vector2(u * 0.20, u * 0.38), Vector2(u * 0.20, u * 0.80), u * 0.035, skin.trim)
	# body
	_poly(image, PackedVector2Array([Vector2(u * 0.36, u * 0.42), Vector2(u * 0.64, u * 0.42), Vector2(u * 0.70, u * 0.88), Vector2(u * 0.30, u * 0.88)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.38, u * 0.44), Vector2(u * 0.62, u * 0.44), Vector2(u * 0.66, u * 0.70), Vector2(u * 0.34, u * 0.70)]), skin.base)
	_stroke(image, Vector2(u * 0.50, u * 0.46), Vector2(u * 0.50, u * 0.70), u * 0.05, skin.trim)
	# pauldrons
	_ellipse(image, u * 0.30, u * 0.44, u * 0.13, u * 0.10, skin.base)
	_ellipse(image, u * 0.70, u * 0.44, u * 0.13, u * 0.10, skin.base)
	_ellipse(image, u * 0.30, u * 0.42, u * 0.10, u * 0.06, skin.trim, 0.7)
	_ellipse(image, u * 0.70, u * 0.42, u * 0.10, u * 0.06, skin.trim, 0.7)
	# helm
	_ellipse(image, u * 0.50, u * 0.26, u * 0.16, u * 0.17, skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.34, u * 0.26), Vector2(u * 0.66, u * 0.26), Vector2(u * 0.64, u * 0.40), Vector2(u * 0.36, u * 0.40)]), skin.metal)
	_stroke(image, Vector2(u * 0.38, u * 0.28), Vector2(u * 0.62, u * 0.28), u * 0.05, Color("140f14"))
	_ellipse(image, u * 0.43, u * 0.28, u * 0.022, u * 0.022, Color("ffcf7a"))
	_ellipse(image, u * 0.57, u * 0.28, u * 0.022, u * 0.022, Color("ffcf7a"))
	# crest
	_poly(image, PackedVector2Array([Vector2(u * 0.46, u * 0.12), Vector2(u * 0.54, u * 0.12), Vector2(u * 0.56, u * 0.22), Vector2(u * 0.44, u * 0.22)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.47, u * 0.06), Vector2(u * 0.53, u * 0.06), Vector2(u * 0.55, u * 0.14), Vector2(u * 0.45, u * 0.14)]), skin.trim)
	# mace arm
	_stroke(image, Vector2(u * 0.72, u * 0.50), Vector2(u * 0.84, u * 0.30), u * 0.05, skin.dark)
	_ellipse(image, u * 0.86, u * 0.24, u * 0.09, u * 0.09, skin.metal)

static func _kait(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.55))
	# cloak
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.24), Vector2(u * 0.78, u * 0.56), Vector2(u * 0.72, u * 0.90), Vector2(u * 0.28, u * 0.90), Vector2(u * 0.22, u * 0.56)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.30), Vector2(u * 0.66, u * 0.58), Vector2(u * 0.62, u * 0.86), Vector2(u * 0.38, u * 0.86), Vector2(u * 0.34, u * 0.58)]), skin.base)
	# belt
	_stroke(image, Vector2(u * 0.36, u * 0.64), Vector2(u * 0.64, u * 0.64), u * 0.045, skin.dark)
	_ellipse(image, u * 0.50, u * 0.64, u * 0.035, u * 0.030, skin.trim)
	# hood
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.09), Vector2(u * 0.70, u * 0.30), Vector2(u * 0.63, u * 0.44), Vector2(u * 0.37, u * 0.44), Vector2(u * 0.30, u * 0.30)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.14), Vector2(u * 0.64, u * 0.31), Vector2(u * 0.59, u * 0.42), Vector2(u * 0.41, u * 0.42), Vector2(u * 0.36, u * 0.31)]), Color("14100f"))
	_ellipse(image, u * 0.44, u * 0.31, u * 0.028, u * 0.020, skin.trim)
	_ellipse(image, u * 0.56, u * 0.31, u * 0.028, u * 0.020, skin.trim)
	# twin daggers
	_poly(image, PackedVector2Array([Vector2(u * 0.80, u * 0.34), Vector2(u * 0.88, u * 0.44), Vector2(u * 0.78, u * 0.62), Vector2(u * 0.73, u * 0.55)]), Color("dfe7ef"))
	_stroke(image, Vector2(u * 0.75, u * 0.58), Vector2(u * 0.70, u * 0.68), u * 0.045, skin.dark)
	_poly(image, PackedVector2Array([Vector2(u * 0.20, u * 0.34), Vector2(u * 0.12, u * 0.44), Vector2(u * 0.22, u * 0.62), Vector2(u * 0.27, u * 0.55)]), Color("dfe7ef"))
	_stroke(image, Vector2(u * 0.25, u * 0.58), Vector2(u * 0.30, u * 0.68), u * 0.045, skin.dark)

static func _max(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.55))
	# robe
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.30), Vector2(u * 0.74, u * 0.66), Vector2(u * 0.78, u * 0.90), Vector2(u * 0.22, u * 0.90), Vector2(u * 0.26, u * 0.66)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.34), Vector2(u * 0.64, u * 0.66), Vector2(u * 0.66, u * 0.86), Vector2(u * 0.34, u * 0.86), Vector2(u * 0.36, u * 0.66)]), skin.base)
	for i in 3:
		_ellipse(image, u * 0.50, u * (0.52 + 0.10 * i), u * 0.026, u * 0.026, skin.trim, 0.85)
	# wide hat
	_poly(image, PackedVector2Array([Vector2(u * 0.16, u * 0.30), Vector2(u * 0.84, u * 0.30), Vector2(u * 0.66, u * 0.36), Vector2(u * 0.34, u * 0.36)]), skin.cloth)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.04), Vector2(u * 0.66, u * 0.30), Vector2(u * 0.34, u * 0.30)]), skin.cloth)
	_ellipse(image, u * 0.50, u * 0.06, u * 0.035, u * 0.035, skin.trim)
	# face shadow
	_poly(image, PackedVector2Array([Vector2(u * 0.38, u * 0.36), Vector2(u * 0.62, u * 0.36), Vector2(u * 0.58, u * 0.48), Vector2(u * 0.42, u * 0.48)]), Color("0f0d1c"))
	_ellipse(image, u * 0.44, u * 0.41, u * 0.026, u * 0.020, Color("9fe8ff"))
	_ellipse(image, u * 0.56, u * 0.41, u * 0.026, u * 0.020, Color("9fe8ff"))
	# orbiting focus orb
	_ellipse(image, u * 0.83, u * 0.50, u * 0.085, u * 0.085, skin.trim, 0.35)
	_ellipse(image, u * 0.83, u * 0.50, u * 0.055, u * 0.055, Color("bcd0ff"))
	_ellipse(image, u * 0.81, u * 0.47, u * 0.020, u * 0.020, Color("ffffff"))
	_stroke(image, Vector2(u * 0.66, u * 0.60), Vector2(u * 0.80, u * 0.54), u * 0.04, skin.dark)

static func _slime(image: Image, skin: Dictionary, scale: float, crowned: bool) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	var cx := u * 0.5
	var base_y := u * 0.88
	var rx := u * 0.36 * scale
	var ry := u * 0.30 * scale
	# body: dome with a wobbling skirt
	_ellipse(image, cx, base_y - ry * 0.85, rx, ry, skin.base)
	_poly(image, PackedVector2Array([Vector2(cx - rx, base_y - ry * 0.85), Vector2(cx + rx, base_y - ry * 0.85), Vector2(cx + rx, base_y), Vector2(cx - rx, base_y)]), skin.base)
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		_ellipse(image, cx - rx + rx * 2.0 * t, base_y, rx * 0.22, ry * (0.16 + 0.10 * float(i % 2)), skin.base)
	_ellipse(image, cx, base_y - ry * 0.35, rx * 0.85, ry * 0.45, skin.dark, 0.35)
	# gloss
	_ellipse(image, cx - rx * 0.34, base_y - ry * 1.20, rx * 0.24, ry * 0.20, skin.metal, 0.85)
	# face
	var eye_y := base_y - ry * 0.95
	_ellipse(image, cx - rx * 0.30, eye_y, rx * 0.11, ry * 0.14, Color("0b1018"))
	_ellipse(image, cx + rx * 0.30, eye_y, rx * 0.11, ry * 0.14, Color("0b1018"))
	_ellipse(image, cx - rx * 0.27, eye_y - ry * 0.05, rx * 0.04, ry * 0.05, Color("ffffff"))
	_ellipse(image, cx + rx * 0.33, eye_y - ry * 0.05, rx * 0.04, ry * 0.05, Color("ffffff"))
	_path(image, PackedVector2Array([Vector2(cx - rx * 0.16, eye_y + ry * 0.36), Vector2(cx, eye_y + ry * 0.46), Vector2(cx + rx * 0.16, eye_y + ry * 0.36)]), u * 0.018, Color("0b1018"))
	if crowned:
		var top := base_y - ry * 1.85
		_poly(image, PackedVector2Array([
			Vector2(cx - rx * 0.52, top + u * 0.10), Vector2(cx - rx * 0.58, top), Vector2(cx - rx * 0.26, top + u * 0.05),
			Vector2(cx, top - u * 0.03), Vector2(cx + rx * 0.26, top + u * 0.05), Vector2(cx + rx * 0.58, top),
			Vector2(cx + rx * 0.52, top + u * 0.10)]), skin.metal)
		_ellipse(image, cx, top + u * 0.005, u * 0.026, u * 0.026, Color("ff7a6b"))

static func _crab(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	# legs
	for i in 3:
		var y := u * (0.66 + 0.07 * i)
		_path(image, PackedVector2Array([Vector2(u * 0.34, y), Vector2(u * 0.18, y + u * 0.06), Vector2(u * 0.12, y + u * 0.14)]), u * 0.035, skin.dark)
		_path(image, PackedVector2Array([Vector2(u * 0.66, y), Vector2(u * 0.82, y + u * 0.06), Vector2(u * 0.88, y + u * 0.14)]), u * 0.035, skin.dark)
	# claws
	_ellipse(image, u * 0.16, u * 0.44, u * 0.11, u * 0.09, skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.06, u * 0.40), Vector2(u * 0.22, u * 0.36), Vector2(u * 0.20, u * 0.46), Vector2(u * 0.06, u * 0.46)]), skin.metal)
	_ellipse(image, u * 0.84, u * 0.44, u * 0.11, u * 0.09, skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.94, u * 0.40), Vector2(u * 0.78, u * 0.36), Vector2(u * 0.80, u * 0.46), Vector2(u * 0.94, u * 0.46)]), skin.metal)
	# carapace
	_ellipse(image, u * 0.50, u * 0.56, u * 0.30, u * 0.24, skin.base)
	_ellipse(image, u * 0.50, u * 0.50, u * 0.26, u * 0.16, skin.dark, 0.45)
	for i in 4:
		_stroke(image, Vector2(u * (0.30 + 0.135 * i), u * 0.40), Vector2(u * (0.32 + 0.12 * i), u * 0.72), u * 0.018, skin.dark, 0.7)
	# eye stalks
	_stroke(image, Vector2(u * 0.42, u * 0.38), Vector2(u * 0.40, u * 0.24), u * 0.030, skin.dark)
	_stroke(image, Vector2(u * 0.58, u * 0.38), Vector2(u * 0.60, u * 0.24), u * 0.030, skin.dark)
	_ellipse(image, u * 0.40, u * 0.22, u * 0.045, u * 0.045, Color("f4f7fb"))
	_ellipse(image, u * 0.60, u * 0.22, u * 0.045, u * 0.045, Color("f4f7fb"))
	_ellipse(image, u * 0.40, u * 0.22, u * 0.020, u * 0.024, Color("101620"))
	_ellipse(image, u * 0.60, u * 0.22, u * 0.020, u * 0.024, Color("101620"))

static func _cultist(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.22), Vector2(u * 0.76, u * 0.62), Vector2(u * 0.80, u * 0.90), Vector2(u * 0.20, u * 0.90), Vector2(u * 0.24, u * 0.62)]), skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.30), Vector2(u * 0.64, u * 0.64), Vector2(u * 0.66, u * 0.88), Vector2(u * 0.34, u * 0.88), Vector2(u * 0.36, u * 0.64)]), skin.dark)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.06), Vector2(u * 0.68, u * 0.28), Vector2(u * 0.62, u * 0.42), Vector2(u * 0.38, u * 0.42), Vector2(u * 0.32, u * 0.28)]), skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.14), Vector2(u * 0.62, u * 0.30), Vector2(u * 0.58, u * 0.40), Vector2(u * 0.42, u * 0.40), Vector2(u * 0.38, u * 0.30)]), Color("120b22"))
	_ellipse(image, u * 0.45, u * 0.30, u * 0.024, u * 0.026, skin.metal)
	_ellipse(image, u * 0.55, u * 0.30, u * 0.024, u * 0.026, skin.metal)
	# offered gem
	_ellipse(image, u * 0.50, u * 0.60, u * 0.12, u * 0.12, skin.metal, 0.28)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.50), Vector2(u * 0.59, u * 0.58), Vector2(u * 0.50, u * 0.70), Vector2(u * 0.41, u * 0.58)]), skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.50), Vector2(u * 0.55, u * 0.58), Vector2(u * 0.50, u * 0.62)]), Color("ffffff"), 0.6)
	_path(image, PackedVector2Array([Vector2(u * 0.34, u * 0.70), Vector2(u * 0.42, u * 0.64)]), u * 0.045, skin.dark)
	_path(image, PackedVector2Array([Vector2(u * 0.66, u * 0.70), Vector2(u * 0.58, u * 0.64)]), u * 0.045, skin.dark)

static func _dartling(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.4))
	# wings
	_ellipse(image, u * 0.26, u * 0.36, u * 0.20, u * 0.13, skin.metal, 0.55)
	_ellipse(image, u * 0.74, u * 0.36, u * 0.20, u * 0.13, skin.metal, 0.55)
	_ellipse(image, u * 0.28, u * 0.52, u * 0.16, u * 0.10, skin.metal, 0.40)
	_ellipse(image, u * 0.72, u * 0.52, u * 0.16, u * 0.10, skin.metal, 0.40)
	# thorax and abdomen
	_ellipse(image, u * 0.50, u * 0.44, u * 0.14, u * 0.16, skin.base)
	_ellipse(image, u * 0.50, u * 0.66, u * 0.11, u * 0.17, skin.base)
	for i in 3:
		_stroke(image, Vector2(u * 0.40, u * (0.60 + 0.09 * i)), Vector2(u * 0.60, u * (0.60 + 0.09 * i)), u * 0.030, skin.dark, 0.8)
	# stinger
	_poly(image, PackedVector2Array([Vector2(u * 0.46, u * 0.82), Vector2(u * 0.54, u * 0.82), Vector2(u * 0.50, u * 0.97)]), Color("b8f06a"))
	# head
	_ellipse(image, u * 0.50, u * 0.26, u * 0.11, u * 0.10, skin.dark)
	_ellipse(image, u * 0.45, u * 0.25, u * 0.038, u * 0.042, Color("ff6b6b"))
	_ellipse(image, u * 0.55, u * 0.25, u * 0.038, u * 0.042, Color("ff6b6b"))
	_stroke(image, Vector2(u * 0.44, u * 0.19), Vector2(u * 0.36, u * 0.09), u * 0.020, skin.dark)
	_stroke(image, Vector2(u * 0.56, u * 0.19), Vector2(u * 0.64, u * 0.09), u * 0.020, skin.dark)

static func _warden(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.55))
	# hammer
	_stroke(image, Vector2(u * 0.80, u * 0.22), Vector2(u * 0.68, u * 0.80), u * 0.045, Color("6a4a30"))
	_poly(image, PackedVector2Array([Vector2(u * 0.66, u * 0.10), Vector2(u * 0.96, u * 0.10), Vector2(u * 0.96, u * 0.30), Vector2(u * 0.66, u * 0.30)]), skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.70, u * 0.14), Vector2(u * 0.92, u * 0.14), Vector2(u * 0.92, u * 0.22), Vector2(u * 0.70, u * 0.22)]), skin.dark, 0.6)
	# torso
	_poly(image, PackedVector2Array([Vector2(u * 0.28, u * 0.40), Vector2(u * 0.72, u * 0.40), Vector2(u * 0.66, u * 0.90), Vector2(u * 0.34, u * 0.90)]), skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.34, u * 0.46), Vector2(u * 0.66, u * 0.46), Vector2(u * 0.62, u * 0.72), Vector2(u * 0.38, u * 0.72)]), skin.cloth)
	_stroke(image, Vector2(u * 0.36, u * 0.58), Vector2(u * 0.64, u * 0.58), u * 0.035, skin.trim)
	# pauldrons
	_poly(image, PackedVector2Array([Vector2(u * 0.16, u * 0.36), Vector2(u * 0.40, u * 0.32), Vector2(u * 0.40, u * 0.52), Vector2(u * 0.18, u * 0.50)]), skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.84, u * 0.36), Vector2(u * 0.60, u * 0.32), Vector2(u * 0.60, u * 0.52), Vector2(u * 0.82, u * 0.50)]), skin.base)
	# helm
	_poly(image, PackedVector2Array([Vector2(u * 0.36, u * 0.14), Vector2(u * 0.64, u * 0.14), Vector2(u * 0.68, u * 0.36), Vector2(u * 0.32, u * 0.36)]), skin.metal)
	_poly(image, PackedVector2Array([Vector2(u * 0.40, u * 0.22), Vector2(u * 0.60, u * 0.22), Vector2(u * 0.60, u * 0.28), Vector2(u * 0.40, u * 0.28)]), Color("0d1220"))
	_ellipse(image, u * 0.44, u * 0.25, u * 0.020, u * 0.018, skin.trim)
	_ellipse(image, u * 0.56, u * 0.25, u * 0.020, u * 0.018, skin.trim)

static func _wisp(image: Image, skin: Dictionary, scale: float) -> void:
	var u := float(image.get_width())
	var cx := u * 0.5
	var cy := u * 0.48
	_ellipse(image, cx, cy, u * 0.36 * scale, u * 0.36 * scale, skin.base, 0.18)
	var shards := [
		[Vector2(0.0, -0.34), Vector2(0.16, -0.06), Vector2(0.0, 0.12), Vector2(-0.16, -0.06)],
		[Vector2(0.30, -0.10), Vector2(0.42, 0.10), Vector2(0.26, 0.24), Vector2(0.18, 0.04)],
		[Vector2(-0.30, -0.10), Vector2(-0.42, 0.10), Vector2(-0.26, 0.24), Vector2(-0.18, 0.04)],
		[Vector2(0.06, 0.24), Vector2(0.20, 0.42), Vector2(0.0, 0.50), Vector2(-0.14, 0.36)]
	]
	for shard in shards:
		var points := PackedVector2Array()
		for offset in shard:
			points.append(Vector2(cx, cy) + Vector2(offset) * u * scale * 1.5)
		_poly(image, points, skin.base)
		_poly(image, PackedVector2Array([points[0], points[1], points[2]]), skin.trim, 0.32)
	_ellipse(image, cx, cy, u * 0.10, u * 0.10, skin.trim)
	_ellipse(image, cx, cy, u * 0.055, u * 0.055, Color("ffffff"))

static func _regent(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.16), Vector2(u * 0.74, u * 0.54), Vector2(u * 0.80, u * 0.92), Vector2(u * 0.20, u * 0.92), Vector2(u * 0.26, u * 0.54)]), skin.base)
	for i in 5:
		var t := float(i) / 4.0
		_stroke(image, Vector2(u * lerpf(0.30, 0.70, t), u * 0.30), Vector2(u * lerpf(0.24, 0.76, t), u * 0.90), u * 0.016, skin.dark, 0.55)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.20), Vector2(u * 0.62, u * 0.52), Vector2(u * 0.50, u * 0.74), Vector2(u * 0.38, u * 0.52)]), skin.metal, 0.55)
	# crown of shards
	_poly(image, PackedVector2Array([
		Vector2(u * 0.30, u * 0.24), Vector2(u * 0.34, u * 0.06), Vector2(u * 0.42, u * 0.20),
		Vector2(u * 0.50, u * 0.00), Vector2(u * 0.58, u * 0.20), Vector2(u * 0.66, u * 0.06),
		Vector2(u * 0.70, u * 0.24)]), skin.metal)
	# mirrored face plate
	_poly(image, PackedVector2Array([Vector2(u * 0.40, u * 0.24), Vector2(u * 0.60, u * 0.24), Vector2(u * 0.56, u * 0.42), Vector2(u * 0.44, u * 0.42)]), Color("161a2e"))
	_stroke(image, Vector2(u * 0.43, u * 0.30), Vector2(u * 0.48, u * 0.30), u * 0.026, skin.trim)
	_stroke(image, Vector2(u * 0.52, u * 0.30), Vector2(u * 0.57, u * 0.30), u * 0.026, skin.trim)

static func _hound(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	# rift glow
	_ellipse(image, u * 0.50, u * 0.52, u * 0.42, u * 0.30, skin.trim, 0.12)
	# legs
	for x in [0.26, 0.40, 0.62, 0.76]:
		_path(image, PackedVector2Array([Vector2(u * x, u * 0.62), Vector2(u * (x - 0.02), u * 0.78), Vector2(u * (x + 0.02), u * 0.90)]), u * 0.045, skin.dark)
	# body
	_ellipse(image, u * 0.50, u * 0.56, u * 0.30, u * 0.16, skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.22, u * 0.52), Vector2(u * 0.36, u * 0.36), Vector2(u * 0.48, u * 0.42), Vector2(u * 0.62, u * 0.34), Vector2(u * 0.74, u * 0.50)]), skin.trim, 0.55)
	# head
	_ellipse(image, u * 0.78, u * 0.42, u * 0.14, u * 0.11, skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.86, u * 0.38), Vector2(u * 0.98, u * 0.44), Vector2(u * 0.86, u * 0.50)]), skin.base)
	_poly(image, PackedVector2Array([Vector2(u * 0.70, u * 0.34), Vector2(u * 0.72, u * 0.20), Vector2(u * 0.80, u * 0.32)]), skin.dark)
	_ellipse(image, u * 0.84, u * 0.41, u * 0.030, u * 0.024, Color("ffe066"))
	# tail
	_path(image, PackedVector2Array([Vector2(u * 0.22, u * 0.54), Vector2(u * 0.10, u * 0.46), Vector2(u * 0.06, u * 0.28)]), u * 0.040, skin.dark)
	_ellipse(image, u * 0.06, u * 0.24, u * 0.05, u * 0.05, skin.trim)

static func _sovereign(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	# halo ring
	_ellipse(image, u * 0.50, u * 0.34, u * 0.40, u * 0.40, skin.trim, 0.22)
	_ellipse(image, u * 0.50, u * 0.34, u * 0.34, u * 0.34, skin.trim, 0.55)
	_ellipse(image, u * 0.50, u * 0.34, u * 0.29, u * 0.29, Color("0b0718"))
	# mantle
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.24), Vector2(u * 0.86, u * 0.66), Vector2(u * 0.92, u * 0.96), Vector2(u * 0.08, u * 0.96), Vector2(u * 0.14, u * 0.66)]), skin.dark)
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.30), Vector2(u * 0.72, u * 0.66), Vector2(u * 0.76, u * 0.92), Vector2(u * 0.24, u * 0.92), Vector2(u * 0.28, u * 0.66)]), skin.base)
	# starfield inside the mantle
	for i in 14:
		var px := u * (0.30 + fmod(float(i) * 0.173, 0.40))
		var py := u * (0.40 + fmod(float(i) * 0.281, 0.48))
		_ellipse(image, px, py, u * 0.012, u * 0.012, skin.trim, 0.9)
	# void face
	_ellipse(image, u * 0.50, u * 0.30, u * 0.13, u * 0.15, Color("07040f"))
	_ellipse(image, u * 0.45, u * 0.30, u * 0.026, u * 0.032, skin.metal)
	_ellipse(image, u * 0.55, u * 0.30, u * 0.026, u * 0.032, skin.metal)
	# horns
	_poly(image, PackedVector2Array([Vector2(u * 0.38, u * 0.20), Vector2(u * 0.28, u * 0.02), Vector2(u * 0.46, u * 0.14)]), skin.trim)
	_poly(image, PackedVector2Array([Vector2(u * 0.62, u * 0.20), Vector2(u * 0.72, u * 0.02), Vector2(u * 0.54, u * 0.14)]), skin.trim)

static func _unknown(image: Image, skin: Dictionary) -> void:
	var u := float(image.get_width())
	_ground(image, Color(0, 0, 0, 0.5))
	_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.14), Vector2(u * 0.76, u * 0.46), Vector2(u * 0.70, u * 0.90), Vector2(u * 0.30, u * 0.90), Vector2(u * 0.24, u * 0.46)]), skin.base)
	_ellipse(image, u * 0.50, u * 0.34, u * 0.16, u * 0.16, skin.dark)
	_ellipse(image, u * 0.44, u * 0.32, u * 0.030, u * 0.030, skin.trim)
	_ellipse(image, u * 0.56, u * 0.32, u * 0.030, u * 0.030, skin.trim)

# --- relics, rooms ------------------------------------------------------------

static func _paint_relic(key: String) -> Image:
	var image := _blank(ICON)
	var u := float(ICON)
	var gold := Color("e8b661")
	var dark := Color("6b4c22")
	var steel := Color("aebccd")
	match key:
		"MATCHBOX":
			_poly(image, PackedVector2Array([Vector2(u * 0.20, u * 0.34), Vector2(u * 0.80, u * 0.34), Vector2(u * 0.80, u * 0.76), Vector2(u * 0.20, u * 0.76)]), dark)
			_poly(image, PackedVector2Array([Vector2(u * 0.26, u * 0.40), Vector2(u * 0.74, u * 0.40), Vector2(u * 0.74, u * 0.54), Vector2(u * 0.26, u * 0.54)]), gold)
			_stroke(image, Vector2(u * 0.50, u * 0.16), Vector2(u * 0.50, u * 0.34), u * 0.06, steel)
			_ellipse(image, u * 0.50, u * 0.14, u * 0.08, u * 0.10, Color("ff9d5c"))
		"STEADY_HAND":
			_stroke(image, Vector2(u * 0.32, u * 0.82), Vector2(u * 0.68, u * 0.24), u * 0.10, steel)
			_stroke(image, Vector2(u * 0.24, u * 0.44), Vector2(u * 0.50, u * 0.62), u * 0.07, gold)
			_ellipse(image, u * 0.70, u * 0.20, u * 0.08, u * 0.08, gold)
		"FIELD_DRESSING":
			_poly(image, PackedVector2Array([Vector2(u * 0.16, u * 0.42), Vector2(u * 0.84, u * 0.42), Vector2(u * 0.84, u * 0.62), Vector2(u * 0.16, u * 0.62)]), Color("f0f3f8"))
			_poly(image, PackedVector2Array([Vector2(u * 0.40, u * 0.18), Vector2(u * 0.60, u * 0.18), Vector2(u * 0.60, u * 0.86), Vector2(u * 0.40, u * 0.86)]), Color("f0f3f8"))
			_ellipse(image, u * 0.50, u * 0.52, u * 0.12, u * 0.12, Color("ff7a6b"))
		"MINERS_LANTERN":
			_poly(image, PackedVector2Array([Vector2(u * 0.30, u * 0.30), Vector2(u * 0.70, u * 0.30), Vector2(u * 0.78, u * 0.78), Vector2(u * 0.22, u * 0.78)]), dark)
			_poly(image, PackedVector2Array([Vector2(u * 0.36, u * 0.38), Vector2(u * 0.64, u * 0.38), Vector2(u * 0.70, u * 0.70), Vector2(u * 0.30, u * 0.70)]), Color("ffdf9a"))
			_stroke(image, Vector2(u * 0.36, u * 0.28), Vector2(u * 0.50, u * 0.10), u * 0.05, steel)
			_stroke(image, Vector2(u * 0.64, u * 0.28), Vector2(u * 0.50, u * 0.10), u * 0.05, steel)
		"FOCUSING_PRISM":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.12), Vector2(u * 0.84, u * 0.80), Vector2(u * 0.16, u * 0.80)]), Color("9fd7ff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.12), Vector2(u * 0.66, u * 0.80), Vector2(u * 0.50, u * 0.80)]), Color("d8f0ff"))
			_stroke(image, Vector2(u * 0.04, u * 0.52), Vector2(u * 0.40, u * 0.52), u * 0.05, Color("ffffff"))
			_stroke(image, Vector2(u * 0.60, u * 0.56), Vector2(u * 0.96, u * 0.40), u * 0.04, Color("ff9d5c"))
			_stroke(image, Vector2(u * 0.60, u * 0.62), Vector2(u * 0.96, u * 0.62), u * 0.04, Color("6fe3b0"))
		"MERCHANT_SEAL":
			_ellipse(image, u * 0.50, u * 0.50, u * 0.34, u * 0.34, gold)
			_ellipse(image, u * 0.50, u * 0.50, u * 0.24, u * 0.24, dark)
			_stroke(image, Vector2(u * 0.50, u * 0.32), Vector2(u * 0.50, u * 0.68), u * 0.06, gold)
			_stroke(image, Vector2(u * 0.38, u * 0.42), Vector2(u * 0.62, u * 0.42), u * 0.05, gold)
		"TINKERS_BELT":
			_poly(image, PackedVector2Array([Vector2(u * 0.06, u * 0.40), Vector2(u * 0.94, u * 0.40), Vector2(u * 0.94, u * 0.60), Vector2(u * 0.06, u * 0.60)]), Color("6b4c22"))
			_poly(image, PackedVector2Array([Vector2(u * 0.38, u * 0.30), Vector2(u * 0.62, u * 0.30), Vector2(u * 0.62, u * 0.70), Vector2(u * 0.38, u * 0.70)]), gold)
			_poly(image, PackedVector2Array([Vector2(u * 0.45, u * 0.38), Vector2(u * 0.55, u * 0.38), Vector2(u * 0.55, u * 0.62), Vector2(u * 0.45, u * 0.62)]), Color("2a2016"))
		"LASTING_AEGIS":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.10), Vector2(u * 0.86, u * 0.28), Vector2(u * 0.74, u * 0.76), Vector2(u * 0.50, u * 0.92), Vector2(u * 0.26, u * 0.76), Vector2(u * 0.14, u * 0.28)]), Color("6fb2ff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.20), Vector2(u * 0.76, u * 0.33), Vector2(u * 0.67, u * 0.70), Vector2(u * 0.50, u * 0.82), Vector2(u * 0.33, u * 0.70), Vector2(u * 0.24, u * 0.33)]), Color("2c4f7d"))
			_stroke(image, Vector2(u * 0.50, u * 0.28), Vector2(u * 0.50, u * 0.74), u * 0.05, gold)
		_:
			_ellipse(image, u * 0.50, u * 0.50, u * 0.32, u * 0.32, gold)
			_ellipse(image, u * 0.50, u * 0.50, u * 0.18, u * 0.18, dark)
	_shade(image, 0.16, 0.22)
	_outline(image, Color("0a0d16"), 2)
	return image

static func _paint_room(kind: String) -> Image:
	var image := _blank(ICON)
	var u := float(ICON)
	var gold := Color("e8b661")
	var steel := Color("b9c6d6")
	match kind:
		"battle", "combat":
			_stroke(image, Vector2(u * 0.18, u * 0.84), Vector2(u * 0.78, u * 0.18), u * 0.10, steel)
			_stroke(image, Vector2(u * 0.82, u * 0.84), Vector2(u * 0.22, u * 0.18), u * 0.10, steel)
			_stroke(image, Vector2(u * 0.16, u * 0.62), Vector2(u * 0.36, u * 0.82), u * 0.07, gold)
			_stroke(image, Vector2(u * 0.84, u * 0.62), Vector2(u * 0.64, u * 0.82), u * 0.07, gold)
		"elite":
			_ellipse(image, u * 0.50, u * 0.44, u * 0.28, u * 0.30, Color("e7ecf4"))
			_poly(image, PackedVector2Array([Vector2(u * 0.32, u * 0.66), Vector2(u * 0.68, u * 0.66), Vector2(u * 0.62, u * 0.86), Vector2(u * 0.38, u * 0.86)]), Color("e7ecf4"))
			_ellipse(image, u * 0.40, u * 0.44, u * 0.08, u * 0.09, Color("141a26"))
			_ellipse(image, u * 0.60, u * 0.44, u * 0.08, u * 0.09, Color("141a26"))
			_stroke(image, Vector2(u * 0.40, u * 0.74), Vector2(u * 0.60, u * 0.74), u * 0.04, Color("141a26"))
		"boss":
			_poly(image, PackedVector2Array([
				Vector2(u * 0.12, u * 0.72), Vector2(u * 0.12, u * 0.26), Vector2(u * 0.31, u * 0.48),
				Vector2(u * 0.50, u * 0.18), Vector2(u * 0.69, u * 0.48), Vector2(u * 0.88, u * 0.26),
				Vector2(u * 0.88, u * 0.72)]), gold)
			_poly(image, PackedVector2Array([Vector2(u * 0.12, u * 0.74), Vector2(u * 0.88, u * 0.74), Vector2(u * 0.88, u * 0.86), Vector2(u * 0.12, u * 0.86)]), gold.darkened(0.25))
			_ellipse(image, u * 0.50, u * 0.62, u * 0.06, u * 0.06, Color("ff7a6b"))
		"shop":
			_poly(image, PackedVector2Array([Vector2(u * 0.24, u * 0.42), Vector2(u * 0.76, u * 0.42), Vector2(u * 0.86, u * 0.88), Vector2(u * 0.14, u * 0.88)]), Color("8a6a3e"))
			_stroke(image, Vector2(u * 0.36, u * 0.44), Vector2(u * 0.42, u * 0.16), u * 0.05, Color("5d4526"))
			_stroke(image, Vector2(u * 0.64, u * 0.44), Vector2(u * 0.58, u * 0.16), u * 0.05, Color("5d4526"))
			_ellipse(image, u * 0.50, u * 0.66, u * 0.14, u * 0.14, gold)
		"rest", "camp":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.14), Vector2(u * 0.72, u * 0.54), Vector2(u * 0.50, u * 0.82), Vector2(u * 0.28, u * 0.54)]), Color("ff9d5c"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.34), Vector2(u * 0.62, u * 0.58), Vector2(u * 0.50, u * 0.76), Vector2(u * 0.38, u * 0.58)]), Color("ffdf9a"))
			_stroke(image, Vector2(u * 0.18, u * 0.88), Vector2(u * 0.82, u * 0.76), u * 0.07, Color("6b4c22"))
			_stroke(image, Vector2(u * 0.18, u * 0.76), Vector2(u * 0.82, u * 0.88), u * 0.07, Color("6b4c22"))
		"event":
			_ellipse(image, u * 0.50, u * 0.50, u * 0.36, u * 0.36, Color("b98bff"), 0.30)
			_path(image, PackedVector2Array([Vector2(u * 0.36, u * 0.34), Vector2(u * 0.50, u * 0.22), Vector2(u * 0.64, u * 0.36), Vector2(u * 0.50, u * 0.52), Vector2(u * 0.50, u * 0.62)]), u * 0.09, Color("e0d0ff"))
			_ellipse(image, u * 0.50, u * 0.78, u * 0.07, u * 0.07, Color("e0d0ff"))
		"mine":
			_stroke(image, Vector2(u * 0.24, u * 0.84), Vector2(u * 0.68, u * 0.34), u * 0.07, Color("6b4c22"))
			_path(image, PackedVector2Array([Vector2(u * 0.42, u * 0.20), Vector2(u * 0.68, u * 0.28), Vector2(u * 0.90, u * 0.46)]), u * 0.09, steel)
			_ellipse(image, u * 0.30, u * 0.36, u * 0.10, u * 0.10, Color("6fe3b0"))
		"workshop":
			_poly(image, PackedVector2Array([Vector2(u * 0.14, u * 0.42), Vector2(u * 0.74, u * 0.42), Vector2(u * 0.86, u * 0.52), Vector2(u * 0.60, u * 0.58), Vector2(u * 0.20, u * 0.56)]), steel)
			_poly(image, PackedVector2Array([Vector2(u * 0.34, u * 0.58), Vector2(u * 0.58, u * 0.58), Vector2(u * 0.66, u * 0.86), Vector2(u * 0.26, u * 0.86)]), Color("58657a"))
			_stroke(image, Vector2(u * 0.26, u * 0.30), Vector2(u * 0.52, u * 0.14), u * 0.06, gold)
		"lapidary":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.16), Vector2(u * 0.80, u * 0.44), Vector2(u * 0.50, u * 0.84), Vector2(u * 0.20, u * 0.44)]), Color("6fe3b0"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.16), Vector2(u * 0.66, u * 0.44), Vector2(u * 0.50, u * 0.60), Vector2(u * 0.34, u * 0.44)]), Color("c8ffe6"))
			_stroke(image, Vector2(u * 0.78, u * 0.86), Vector2(u * 0.96, u * 0.62), u * 0.07, steel)
		"wager":
			# Two dice over a stack of coins: what the room takes and what it pays.
			_poly(image, PackedVector2Array([Vector2(u * 0.10, u * 0.34), Vector2(u * 0.34, u * 0.20), Vector2(u * 0.50, u * 0.32), Vector2(u * 0.26, u * 0.48)]), Color("eef1f7"))
			_poly(image, PackedVector2Array([Vector2(u * 0.10, u * 0.34), Vector2(u * 0.26, u * 0.48), Vector2(u * 0.26, u * 0.70), Vector2(u * 0.10, u * 0.56)]), Color("b6c1d2"))
			_poly(image, PackedVector2Array([Vector2(u * 0.26, u * 0.48), Vector2(u * 0.50, u * 0.32), Vector2(u * 0.50, u * 0.54), Vector2(u * 0.26, u * 0.70)]), Color("8e9bad"))
			_ellipse(image, u * 0.30, u * 0.34, u * 0.035, u * 0.030, Color("2a3346"))
			_ellipse(image, u * 0.18, u * 0.58, u * 0.030, u * 0.035, Color("2a3346"))
			_ellipse(image, u * 0.38, u * 0.50, u * 0.030, u * 0.035, Color("2a3346"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.22), Vector2(u * 0.70, u * 0.12), Vector2(u * 0.86, u * 0.22), Vector2(u * 0.66, u * 0.33)]), Color("ffe6a8"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.22), Vector2(u * 0.66, u * 0.33), Vector2(u * 0.66, u * 0.50), Vector2(u * 0.50, u * 0.39)]), gold)
			_poly(image, PackedVector2Array([Vector2(u * 0.66, u * 0.33), Vector2(u * 0.86, u * 0.22), Vector2(u * 0.86, u * 0.39), Vector2(u * 0.66, u * 0.50)]), gold.darkened(0.28))
			_ellipse(image, u * 0.68, u * 0.24, u * 0.032, u * 0.026, Color("5d4526"))
			_ellipse(image, u * 0.58, u * 0.44, u * 0.026, u * 0.030, Color("5d4526"))
			for stack in 3:
				var y: float = u * (0.84 - 0.075 * float(stack))
				_ellipse(image, u * 0.50, y + u * 0.020, u * 0.24, u * 0.075, gold.darkened(0.35))
				_ellipse(image, u * 0.50, y, u * 0.24, u * 0.075, gold)
				_ellipse(image, u * 0.50, y, u * 0.12, u * 0.036, Color("c9963f"))
		"crucible":
			# A gem held in the fire of a stone bowl: Carat bought with what feeds the flame.
			_poly(image, PackedVector2Array([Vector2(u * 0.16, u * 0.62), Vector2(u * 0.84, u * 0.62), Vector2(u * 0.70, u * 0.88), Vector2(u * 0.30, u * 0.88)]), Color("58657a"))
			_ellipse(image, u * 0.50, u * 0.62, u * 0.34, u * 0.085, Color("7d8a9e"))
			_ellipse(image, u * 0.50, u * 0.62, u * 0.26, u * 0.060, Color("2a1a14"))
			_poly(image, PackedVector2Array([Vector2(u * 0.34, u * 0.62), Vector2(u * 0.50, u * 0.26), Vector2(u * 0.66, u * 0.62)]), Color("ff9d5c"))
			_poly(image, PackedVector2Array([Vector2(u * 0.41, u * 0.62), Vector2(u * 0.50, u * 0.38), Vector2(u * 0.59, u * 0.62)]), Color("ffdf9a"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.08), Vector2(u * 0.66, u * 0.26), Vector2(u * 0.50, u * 0.46), Vector2(u * 0.34, u * 0.26)]), Color("b98bff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.08), Vector2(u * 0.58, u * 0.26), Vector2(u * 0.50, u * 0.34), Vector2(u * 0.42, u * 0.26)]), Color("e0d0ff"))
			_stroke(image, Vector2(u * 0.22, u * 0.90), Vector2(u * 0.78, u * 0.90), u * 0.05, Color("3a4658"))
		"lift":
			# A cage on a rope under a pulley: the way home, and the only one.
			_stroke(image, Vector2(u * 0.12, u * 0.14), Vector2(u * 0.88, u * 0.14), u * 0.06, Color("6b4c22"))
			_ellipse(image, u * 0.50, u * 0.14, u * 0.10, u * 0.10, steel)
			_ellipse(image, u * 0.50, u * 0.14, u * 0.04, u * 0.04, Color("3a4658"))
			_stroke(image, Vector2(u * 0.42, u * 0.18), Vector2(u * 0.42, u * 0.36), u * 0.03, Color("d8c7a4"))
			_stroke(image, Vector2(u * 0.58, u * 0.18), Vector2(u * 0.58, u * 0.36), u * 0.03, Color("d8c7a4"))
			_poly(image, PackedVector2Array([Vector2(u * 0.24, u * 0.36), Vector2(u * 0.76, u * 0.36), Vector2(u * 0.76, u * 0.88), Vector2(u * 0.24, u * 0.88)]), Color("2a3346"))
			for bar in 4:
				var x: float = u * (0.30 + 0.133 * float(bar))
				_stroke(image, Vector2(x, u * 0.38), Vector2(x, u * 0.86), u * 0.035, steel)
			_stroke(image, Vector2(u * 0.22, u * 0.37), Vector2(u * 0.78, u * 0.37), u * 0.06, gold)
			_stroke(image, Vector2(u * 0.22, u * 0.87), Vector2(u * 0.78, u * 0.87), u * 0.06, gold)
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.48), Vector2(u * 0.62, u * 0.62), Vector2(u * 0.54, u * 0.62), Vector2(u * 0.54, u * 0.76), Vector2(u * 0.46, u * 0.76), Vector2(u * 0.46, u * 0.62), Vector2(u * 0.38, u * 0.62)]), Color("6fe3b0"))
		"treasure":
			# An open chest with a stone catching the light.
			_poly(image, PackedVector2Array([Vector2(u * 0.14, u * 0.52), Vector2(u * 0.86, u * 0.52), Vector2(u * 0.82, u * 0.88), Vector2(u * 0.18, u * 0.88)]), Color("8a5a2e"))
			_poly(image, PackedVector2Array([Vector2(u * 0.18, u * 0.52), Vector2(u * 0.82, u * 0.52), Vector2(u * 0.90, u * 0.22), Vector2(u * 0.10, u * 0.22)]), Color("6b4122"))
			_stroke(image, Vector2(u * 0.14, u * 0.54), Vector2(u * 0.86, u * 0.54), u * 0.06, gold)
			_stroke(image, Vector2(u * 0.50, u * 0.56), Vector2(u * 0.50, u * 0.86), u * 0.06, gold.darkened(0.2))
			_ellipse(image, u * 0.34, u * 0.50, u * 0.10, u * 0.06, gold)
			_ellipse(image, u * 0.66, u * 0.50, u * 0.10, u * 0.06, gold)
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.26), Vector2(u * 0.62, u * 0.40), Vector2(u * 0.50, u * 0.54), Vector2(u * 0.38, u * 0.40)]), Color("76b6ff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.26), Vector2(u * 0.56, u * 0.40), Vector2(u * 0.50, u * 0.46), Vector2(u * 0.44, u * 0.40)]), Color("d6ecff"))
		_:
			_ellipse(image, u * 0.50, u * 0.50, u * 0.30, u * 0.30, gold, 0.5)
			_ellipse(image, u * 0.50, u * 0.50, u * 0.16, u * 0.16, gold)
	_outline(image, Color("0a0d16"), 2)
	return image

static func _paint_prop(name: String) -> Image:
	var image := _blank(ICON)
	var u := float(ICON)
	match name:
		"sigil":
			_poly(image, PackedVector2Array([
				Vector2(u * 0.50, u * 0.06), Vector2(u * 0.86, u * 0.30), Vector2(u * 0.74, u * 0.74),
				Vector2(u * 0.50, u * 0.94), Vector2(u * 0.26, u * 0.74), Vector2(u * 0.14, u * 0.30)]), Color("1d2a3a"))
			_path(image, PackedVector2Array([Vector2(u * 0.50, u * 0.06), Vector2(u * 0.86, u * 0.30), Vector2(u * 0.74, u * 0.74), Vector2(u * 0.50, u * 0.94), Vector2(u * 0.26, u * 0.74), Vector2(u * 0.14, u * 0.30), Vector2(u * 0.50, u * 0.06)]), u * 0.05, Color("e8b661"))
			_path(image, PackedVector2Array([Vector2(u * 0.26, u * 0.74), Vector2(u * 0.50, u * 0.34), Vector2(u * 0.74, u * 0.74)]), u * 0.035, Color("e8b661"))
			_stroke(image, Vector2(u * 0.14, u * 0.30), Vector2(u * 0.86, u * 0.30), u * 0.03, Color("e8b661"))
			_ellipse(image, u * 0.50, u * 0.50, u * 0.08, u * 0.08, Color("e8b661"))
		"gold":
			_ellipse(image, u * 0.50, u * 0.52, u * 0.34, u * 0.34, Color("b98229"))
			_ellipse(image, u * 0.50, u * 0.48, u * 0.32, u * 0.32, Color("e8b661"))
			_ellipse(image, u * 0.50, u * 0.48, u * 0.20, u * 0.20, Color("c9963f"))
			_stroke(image, Vector2(u * 0.50, u * 0.34), Vector2(u * 0.50, u * 0.62), u * 0.06, Color("ffe6a8"))
		"heart":
			_ellipse(image, u * 0.36, u * 0.38, u * 0.20, u * 0.20, Color("ff7a6b"))
			_ellipse(image, u * 0.64, u * 0.38, u * 0.20, u * 0.20, Color("ff7a6b"))
			_poly(image, PackedVector2Array([Vector2(u * 0.17, u * 0.44), Vector2(u * 0.83, u * 0.44), Vector2(u * 0.50, u * 0.90)]), Color("ff7a6b"))
			_ellipse(image, u * 0.36, u * 0.34, u * 0.07, u * 0.06, Color("ffc7bd"))
		"shield":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.08), Vector2(u * 0.88, u * 0.26), Vector2(u * 0.76, u * 0.74), Vector2(u * 0.50, u * 0.94), Vector2(u * 0.24, u * 0.74), Vector2(u * 0.12, u * 0.26)]), Color("6fb2ff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.20), Vector2(u * 0.77, u * 0.32), Vector2(u * 0.68, u * 0.68), Vector2(u * 0.50, u * 0.82), Vector2(u * 0.32, u * 0.68), Vector2(u * 0.23, u * 0.32)]), Color("2d5687"))
		"shieldbreak":
			_poly(image, PackedVector2Array([Vector2(u * 0.46, u * 0.08), Vector2(u * 0.12, u * 0.26), Vector2(u * 0.24, u * 0.74), Vector2(u * 0.46, u * 0.92)]), Color("8b6bb5"))
			_poly(image, PackedVector2Array([Vector2(u * 0.60, u * 0.10), Vector2(u * 0.88, u * 0.26), Vector2(u * 0.76, u * 0.74), Vector2(u * 0.56, u * 0.90)]), Color("6f5596"))
			_path(image, PackedVector2Array([Vector2(u * 0.50, u * 0.06), Vector2(u * 0.42, u * 0.34), Vector2(u * 0.56, u * 0.52), Vector2(u * 0.44, u * 0.70), Vector2(u * 0.52, u * 0.96)]), u * 0.06, Color("1a1030"))
		"sword":
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.05), Vector2(u * 0.62, u * 0.24), Vector2(u * 0.58, u * 0.66), Vector2(u * 0.42, u * 0.66), Vector2(u * 0.38, u * 0.24)]), Color("d9e2f0"))
			_poly(image, PackedVector2Array([Vector2(u * 0.50, u * 0.09), Vector2(u * 0.56, u * 0.25), Vector2(u * 0.53, u * 0.63), Vector2(u * 0.47, u * 0.63)]), Color("ffffff"))
			_poly(image, PackedVector2Array([Vector2(u * 0.20, u * 0.66), Vector2(u * 0.80, u * 0.66), Vector2(u * 0.80, u * 0.76), Vector2(u * 0.20, u * 0.76)]), Color("c9963f"))
			_poly(image, PackedVector2Array([Vector2(u * 0.44, u * 0.76), Vector2(u * 0.56, u * 0.76), Vector2(u * 0.56, u * 0.92), Vector2(u * 0.44, u * 0.92)]), Color("8a6d3c"))
			_ellipse(image, u * 0.50, u * 0.94, u * 0.09, u * 0.07, Color("e8b661"))
		"bolt":
			_poly(image, PackedVector2Array([Vector2(u * 0.60, u * 0.06), Vector2(u * 0.30, u * 0.54), Vector2(u * 0.48, u * 0.54), Vector2(u * 0.38, u * 0.94), Vector2(u * 0.72, u * 0.42), Vector2(u * 0.52, u * 0.42), Vector2(u * 0.66, u * 0.06)]), Color("ffcf7a"))
			_poly(image, PackedVector2Array([Vector2(u * 0.58, u * 0.14), Vector2(u * 0.40, u * 0.48), Vector2(u * 0.50, u * 0.48), Vector2(u * 0.46, u * 0.72)]), Color("fff1c2"))
		"ore":
			# Three lumps of rock with a seam of colour running through them.
			_ellipse(image, u * 0.34, u * 0.64, u * 0.22, u * 0.18, Color("5a5f6e"))
			_ellipse(image, u * 0.66, u * 0.60, u * 0.20, u * 0.20, Color("6d7384"))
			_ellipse(image, u * 0.50, u * 0.40, u * 0.20, u * 0.17, Color("7d8394"))
			_stroke(image, Vector2(u * 0.36, u * 0.36), Vector2(u * 0.62, u * 0.46), u * 0.05, Color("63d8d0"))
			_stroke(image, Vector2(u * 0.22, u * 0.66), Vector2(u * 0.44, u * 0.60), u * 0.04, Color("e8b661"))
			_stroke(image, Vector2(u * 0.58, u * 0.64), Vector2(u * 0.78, u * 0.56), u * 0.04, Color("63d8d0"))
		"loupe":
			# A jeweller's loupe: the lens that tells a stone what it is.
			_stroke(image, Vector2(u * 0.58, u * 0.58), Vector2(u * 0.88, u * 0.88), u * 0.12, Color("6b4c22"))
			_ellipse(image, u * 0.40, u * 0.40, u * 0.30, u * 0.30, Color("c9963f"))
			_ellipse(image, u * 0.40, u * 0.40, u * 0.23, u * 0.23, Color("2d5687"))
			_ellipse(image, u * 0.40, u * 0.40, u * 0.20, u * 0.20, Color("76b6ff"), 0.55)
			_ellipse(image, u * 0.32, u * 0.32, u * 0.07, u * 0.05, Color("ffffff"), 0.8)
		"skull":
			_ellipse(image, u * 0.50, u * 0.44, u * 0.30, u * 0.32, Color("e7ecf4"))
			_poly(image, PackedVector2Array([Vector2(u * 0.34, u * 0.66), Vector2(u * 0.66, u * 0.66), Vector2(u * 0.60, u * 0.88), Vector2(u * 0.40, u * 0.88)]), Color("e7ecf4"))
			_ellipse(image, u * 0.39, u * 0.44, u * 0.09, u * 0.10, Color("141a26"))
			_ellipse(image, u * 0.61, u * 0.44, u * 0.09, u * 0.10, Color("141a26"))
		_:
			_ellipse(image, u * 0.50, u * 0.50, u * 0.30, u * 0.30, Color("8f9fb5"))
	_outline(image, Color("0a0d16"), 2)
	return image
