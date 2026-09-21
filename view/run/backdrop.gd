extends Control
## The cave behind every page of a run: the biome's own colours, walls of faceted rock
## leaning in from both sides, a lantern's pool of light, and dust turning slowly in it.
## Drawn in 2D and cheap, so the pages between fights feel like the same mine the fights
## happen in without paying for a second 3D room.
##
## Each wall is drawn once into its own layer and swayed by moving the layer, never by
## redrawing it: triangulating rock every frame cost more than the rest of a page together.
## Only the light breathes by redrawing, and that is a few quads.

const Biomes = preload("res://view/battle/biomes.gd")

var biome: Dictionary = {}
var _clock: float = 0.0
var _dust: CPUParticles2D
var _embers: CPUParticles2D
var _key: String = ""
var _light: Control
var _walls: Array = []
var _shade: TextureRect

static var _vignette_texture: GradientTexture2D = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_carve)
	_light = Control.new()
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.draw.connect(_draw_light)
	add_child(_light)
	if DisplayServer.get_name() == "headless":
		return
	_dust = _particles(80, 14.0, Vector2(0, -6), 1.2, 2.8)
	_embers = _particles(24, 7.0, Vector2(0, -28), 2.0, 4.0)

func _particles(amount: int, lifetime: float, drift: Vector2, low: float, high: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.texture = DeepUi.dot_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = drift.normalized() if drift.length() > 0.0 else Vector2.UP
	p.spread = 60.0
	p.initial_velocity_min = drift.length() * 0.3
	p.initial_velocity_max = drift.length()
	p.gravity = Vector2.ZERO
	p.scale_amount_min = low / 16.0
	p.scale_amount_max = high / 16.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	add_child(p)
	return p

func show_biome(mine_key: String, depth: int) -> void:
	var key: String = "%s|%d" % [mine_key, maxi(1, depth)]
	if key == _key:
		return
	_key = key
	biome = Biomes.for_depth(mine_key, maxi(1, depth))
	var accent: Color = biome.get("accent", DeepUi.ACCENT)
	if _dust != null:
		var tone: Color = biome.get("key", Color.WHITE)
		var fade := Gradient.new()
		fade.set_color(0, Color(tone, 0.0))
		fade.set_color(1, Color(tone, 0.0))
		fade.add_point(0.3, Color(tone, 0.35))
		fade.add_point(0.7, Color(tone, 0.25))
		_dust.color_ramp = fade
		var glow := Gradient.new()
		glow.set_color(0, Color(accent, 0.0))
		glow.set_color(1, Color(accent, 0.0))
		glow.add_point(0.25, Color(accent, 0.7))
		_embers.color_ramp = glow
		_embers.emitting = str(biome.get("id", "")) in ["magma", "crystal", "geode", "fungal", "rift"]
	_carve()

func _carve() -> void:
	## Three ranks of rock on each side and a ceiling, each cut once into its own layer.
	for wall in _walls:
		if is_instance_valid(wall.node):
			wall.node.queue_free()
	_walls.clear()
	if size.x < 120.0 or size.y < 120.0 or biome.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _key.hash()
	var rock: Color = biome.get("rock", Color("3a3a3a"))
	var dark: Color = biome.get("rock_dark", Color("1a1a1a"))
	var index: int = 1
	for rank in range(3):
		var depth_share: float = float(rank) / 2.0
		var tone: Color = dark.lerp(rock, 0.25 + 0.3 * (1.0 - depth_share)).darkened(0.35 + 0.25 * depth_share)
		for side in [-1.0, 1.0]:
			var reach: float = size.x * (0.2 - 0.05 * float(rank)) * rng.randf_range(0.8, 1.15)
			var points := PackedVector2Array()
			var edge_x: float = -12.0 if side < 0.0 else size.x + 12.0
			points.append(Vector2(edge_x, -20))
			var steps := 9
			for i in range(steps + 1):
				var t: float = float(i) / float(steps)
				var bulge: float = sin(t * PI) * 0.6 + 0.4
				var x: float = edge_x - side * reach * bulge * rng.randf_range(0.75, 1.15)
				points.append(Vector2(x, lerpf(-20.0, size.y + 20.0, t)))
			points.append(Vector2(edge_x, size.y + 20))
			_add_wall(points, tone, _facets(points, rng, tone), rank, side, index)
			index += 1
	var ceiling := PackedVector2Array([Vector2(-10, -10), Vector2(size.x + 10, -10)])
	var steps := 14
	for i in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		ceiling.append(Vector2(lerpf(-10.0, size.x + 10.0, t), size.y * 0.07 * rng.randf_range(0.4, 1.4) + size.y * 0.04 * sin(t * PI * 3.0)))
	_add_wall(ceiling, dark.darkened(0.45), [], 0, 0.0, index)
	if _shade == null:
		_shade = TextureRect.new()
		_shade.texture = _vignette()
		_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shade.stretch_mode = TextureRect.STRETCH_SCALE
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
	_shade.position = -size * 0.25
	_shade.size = size * 1.5
	move_child(_shade, get_child_count() - 1)
	if _dust != null:
		_dust.position = size * 0.5
		_dust.emission_rect_extents = size * 0.5
		_embers.position = Vector2(size.x * 0.5, size.y)
		_embers.emission_rect_extents = Vector2(size.x * 0.5, 10)
		move_child(_dust, get_child_count() - 1)
		move_child(_embers, get_child_count() - 1)
	_light.queue_redraw()

func _add_wall(points: PackedVector2Array, tone: Color, facets: Array, rank: int, side: float, index: int) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty():
		return
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = size
	layer.draw.connect(func() -> void:
		layer.draw_colored_polygon(points, tone)
		for facet in facets:
			layer.draw_colored_polygon(facet.poly, facet.tone))
	add_child(layer)
	move_child(layer, mini(index, get_child_count() - 1))
	_walls.append({"node": layer, "rank": rank, "side": side})

func _facets(points: PackedVector2Array, rng: RandomNumberGenerator, tone: Color) -> Array:
	## Light and dark planes cut into a wall, so it reads as faceted rock and not a cut-out.
	var out: Array = []
	for i in range(1, points.size() - 2):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var inner: Vector2 = a.lerp(b, 0.5) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-10, 10))
		var towards_edge: Vector2 = Vector2(points[0].x, inner.y)
		var mid: Vector2 = inner.lerp(towards_edge, rng.randf_range(0.3, 0.6))
		if absf((b - a).cross(mid - a)) < 40.0:
			continue
		out.append({"poly": PackedVector2Array([a, b, mid]), "tone": tone.lightened(rng.randf_range(0.02, 0.12)) if rng.randf() > 0.5 else tone.darkened(rng.randf_range(0.05, 0.2))})
	return out

func _process(delta: float) -> void:
	_clock += delta
	if not is_visible_in_tree():
		return
	for wall in _walls:
		var node: Control = wall.node
		if is_instance_valid(node):
			node.position.x = sin(_clock * 0.25 + float(wall.rank)) * (3.0 - float(wall.rank)) * float(wall.side)
	_light.queue_redraw()

func _draw_light() -> void:
	if biome.is_empty():
		_light.draw_rect(Rect2(Vector2.ZERO, size), DeepUi.INK)
		return
	var back: Color = biome.get("background", DeepUi.INK)
	var fog: Color = biome.get("fog", back)
	var key: Color = biome.get("key", Color.WHITE)
	var accent: Color = biome.get("accent", DeepUi.ACCENT)
	## The far dark, lifting toward the middle where the lantern is.
	_light.draw_rect(Rect2(Vector2.ZERO, size), back)
	var glow: Texture2D = DeepUi.glow_texture()
	var breath: float = 1.0 + 0.04 * sin(_clock * 1.3) + 0.02 * sin(_clock * 3.7)
	var pool := Vector2(size.x * 1.1, size.y * 1.4) * breath
	_light.draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y * 0.35) - pool * 0.5, pool), false, Color(fog.lightened(0.25), 0.9))
	var lamp := Vector2(size.x * 0.6, size.y * 0.7) * breath
	_light.draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y * 0.3) - lamp * 0.5, lamp), false, Color(key, 0.10))
	var rim := Vector2(size.x * 0.5, size.y * 0.5)
	_light.draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5, size.y * 1.0) - rim * 0.5, rim), false, Color(accent, 0.07))

static func _vignette() -> GradientTexture2D:
	if _vignette_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0))
		gradient.set_color(1, Color(0, 0, 0, 0.85))
		gradient.add_point(0.45, Color(0, 0, 0, 0))
		_vignette_texture = GradientTexture2D.new()
		_vignette_texture.gradient = gradient
		_vignette_texture.fill = GradientTexture2D.FILL_RADIAL
		_vignette_texture.fill_from = Vector2(0.5, 0.5)
		_vignette_texture.fill_to = Vector2(1.0, 0.5)
		_vignette_texture.width = 256
		_vignette_texture.height = 256
	return _vignette_texture
