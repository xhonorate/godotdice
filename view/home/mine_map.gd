extends Control
## The mines as a cross-section of the earth under the workshop.
##
## Sky and the workshop on the surface; bands of strata below, coloured by the biome each
## depth is; and each mine as a shaft cut straight down from the workshop floor. A shaft is
## lit as far as the player has ever been, marked with its landings and its Wardens (a
## crown, gold once beaten), and runs on into the dark below the third Warden. Sealed mines
## are drawn as rubble with a lock. Click a shaft to choose it.
##
## The earth is drawn once into its own layer and only redrawn when the map changes; this
## control draws only what moves: twinkling stars and veins, the lit windows, chimney smoke,
## the lantern at the deepest point and the cage at the head of the chosen shaft.

signal chosen(mine_key: String)

const Biomes = preload("res://view/battle/biomes.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

var mines: Array = []
var records: Dictionary = {}
var selected: String = ""
var can_choose: bool = true
var _clock: float = 0.0
var _hover: String = ""
var _hotspots: Array = []
var _shafts: Dictionary = {}
var _earth: Control
var _twinkles: Array = []
var _lanterns: Array = []
var _cage: Vector2 = Vector2(-1, -1)
var _home: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 560)
	clip_contents = true
	_earth = Control.new()
	_earth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_earth.show_behind_parent = true
	_earth.draw.connect(_draw_earth)
	add_child(_earth)
	resized.connect(func() -> void: _earth.queue_redraw())

func show_mines(keys: Array, profile_mines: Dictionary, chosen_key: String, host: bool) -> void:
	mines = keys
	records = profile_mines
	selected = chosen_key
	can_choose = host
	if _earth != null:
		_earth.queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree():
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over: String = _shaft_at(event.position)
		if over != _hover:
			_hover = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not over.is_empty() and can_choose else Control.CURSOR_ARROW
			_earth.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var over: String = _shaft_at(event.position)
		if not over.is_empty() and can_choose and bool(records.get(over, {}).get("unlocked", false)):
			chosen.emit(over)

func _shaft_at(at: Vector2) -> String:
	for key in _shafts:
		var rect: Rect2 = _shafts[key]
		if rect.grow(18.0).has_point(at):
			return str(key)
	return ""

func _get_tooltip(at_position: Vector2) -> String:
	for spot in _hotspots:
		if at_position.distance_to(spot.at) <= float(spot.radius) + 3.0:
			return str(spot.text)
	var over: String = _shaft_at(at_position)
	if not over.is_empty():
		var mine: Dictionary = DeepContent.mine(over)
		if not bool(records.get(over, {}).get("unlocked", false)):
			return "A sealed shaft. Beat a Warden to break it open."
		return "%s\n%s" % [str(mine.get("name", over)), str(mine.get("text", ""))]
	return ""

func _glyph(canvas: CanvasItem, name: String, centre: Vector2, edge: float, tint: Color) -> void:
	canvas.draw_texture_rect(GemIcons.texture(name, GemIcons.baked_size(edge * 1.5)), Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, tint)

func _draw_earth() -> void:
	var canvas: Control = _earth
	_hotspots.clear()
	_shafts.clear()
	_twinkles.clear()
	_lanterns.clear()
	_cage = Vector2(-1, -1)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("07080b")
	frame.set_corner_radius_all(16)
	frame.border_color = Color(DeepUi.LINE_HI, 0.6)
	frame.set_border_width_all(1)
	canvas.draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var surface_y: float = size.y * 0.2
	var run_depth: int = int(DeepContent.constant("run_depth", 24))
	var span: int = run_depth + 4
	var step: float = (size.y - surface_y - 24.0) / float(span)
	var glow: Texture2D = DeepUi.glow_texture()
	## Sky: a deep dusk over the workshop, with a few stars.
	canvas.draw_rect(Rect2(Vector2(1, 1), Vector2(size.x - 2, surface_y)), Color("121a2c"))
	canvas.draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5 - size.x * 0.6, surface_y - size.y * 0.25), Vector2(size.x * 1.2, size.y * 0.5)), false, Color("e2b23a", 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(40):
		_twinkles.append({"at": Vector2(rng.randf() * size.x, rng.randf() * surface_y * 0.8), "r": rng.randf_range(0.6, 1.6), "colour": Color(1, 1, 1, 0.5), "rate": rng.randf_range(0.5, 2.0), "phase": float(i)})
	## Strata: one band per biome, the colour of its rock.
	var mine_key: String = str(mines[0]) if not mines.is_empty() else DeepContent.starter_mine()
	var d: int = 1
	while d <= span:
		var band: String = Biomes.band_for(mine_key, d)
		var biome: Dictionary = Biomes.for_depth(mine_key, d)
		var end: int = d
		while end + 1 <= span and Biomes.band_for(mine_key, end + 1) == band:
			end += 1
		var top: float = surface_y + float(d - 1) * step
		var bottom: float = surface_y + float(end) * step
		var poly := PackedVector2Array()
		var steps := 12
		for i in range(steps + 1):
			poly.append(Vector2(size.x * float(i) / float(steps), top + sin(float(i) * 1.7 + float(d)) * step * 0.25))
		for i in range(steps, -1, -1):
			poly.append(Vector2(size.x * float(i) / float(steps), bottom + sin(float(i) * 1.7 + float(end + 1)) * step * 0.25 + 1.0))
		canvas.draw_colored_polygon(poly, Color(biome.rock).darkened(0.35))
		for i in range(10):
			canvas.draw_circle(Vector2(rng.randf() * size.x, rng.randf_range(top + 4.0, bottom - 4.0)), rng.randf_range(1.5, 4.0), Color(biome.rock).darkened(0.1))
		for i in range(3):
			_twinkles.append({"at": Vector2(rng.randf() * size.x, rng.randf_range(top + 4.0, bottom - 4.0)), "r": 1.8, "colour": Color(biome.accent, 0.9), "rate": 1.5, "phase": float(i + d)})
		canvas.draw_string(DeepUi.display_font(), Vector2(size.x - 190, (top + bottom) * 0.5 + 5), str(biome.name).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 176, 11, Color(biome.accent, 0.55))
		d = end + 1
	## The ground line and the workshop on it.
	canvas.draw_rect(Rect2(Vector2(0, surface_y - 3), Vector2(size.x, 6)), Color("3a2e22"))
	_home = Vector2(size.x * 0.34, surface_y - 3)
	var home := _home
	canvas.draw_colored_polygon(PackedVector2Array([home + Vector2(-46, 0), home + Vector2(-46, -34), home + Vector2(0, -62), home + Vector2(46, -34), home + Vector2(46, 0)]), Color("241c16"))
	canvas.draw_rect(Rect2(home + Vector2(22, -64), Vector2(10, 22)), Color("241c16"))
	canvas.draw_string(DeepUi.display_font(), home + Vector2(-220, -8), "THE WORKSHOP", HORIZONTAL_ALIGNMENT_RIGHT, 166, 12, DeepUi.ACCENT)
	## One shaft per mine.
	var count: int = maxi(1, mines.size())
	for index in range(mines.size()):
		var key: String = str(mines[index])
		var mine: Dictionary = DeepContent.mine(key)
		var record: Dictionary = records.get(key, {})
		var unlocked: bool = bool(record.get("unlocked", false))
		var x: float = home.x + (float(index) - float(count - 1) * 0.5) * 70.0
		var chosen_one: bool = key == selected
		var hovered: bool = key == _hover
		var width: float = 22.0
		var shaft := Rect2(Vector2(x - width * 0.5, surface_y), Vector2(width, size.y - 18.0 - surface_y))
		_shafts[key] = shaft
		if not unlocked:
			canvas.draw_rect(Rect2(shaft.position, Vector2(width, step * 3.0)), Color(0, 0, 0, 0.6))
			for i in range(6):
				canvas.draw_circle(Vector2(x + rng.randf_range(-8, 8), surface_y + 6.0 + float(i) * 7.0), rng.randf_range(3, 6), Color("4a4038"))
			_glyph(canvas, "chest", Vector2(x, surface_y + step * 4.0), 22.0, DeepUi.DIM)
			continue
		var tone: Color = Color(str(mine.get("palette", "c9a26b")))
		canvas.draw_rect(shaft, Color(0, 0, 0, 0.72))
		var deepest: int = int(record.get("deepest", 0))
		if deepest > 0:
			canvas.draw_rect(Rect2(shaft.position + Vector2(4, 0), Vector2(width - 8, minf(float(deepest) * step, shaft.size.y))), Color(DeepUi.ACCENT, 0.5 if chosen_one else 0.3))
			var tip := Vector2(x, surface_y + float(deepest) * step)
			_lanterns.append(tip)
			canvas.draw_string(ThemeDB.fallback_font, tip + Vector2(width, 4), "deepest %d" % deepest, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DeepUi.ACCENT_HI)
			_hotspots.append({"at": tip, "radius": 10.0, "text": "The deepest you have been in %s: depth %d" % [str(mine.get("name", key)), deepest]})
		canvas.draw_rect(shaft, DeepUi.ACCENT if chosen_one else (Color(tone, 0.9) if hovered else Color(tone, 0.5)), false, 2.0 if chosen_one or hovered else 1.0)
		var beaten: Array = record.get("wardens", [])
		for depth in range(DeepDescent.landing_every(), span + 1, DeepDescent.landing_every()):
			var at := Vector2(x, surface_y + float(depth) * step)
			if DeepDescent.is_warden_depth(depth):
				var won: bool = beaten.has(depth)
				canvas.draw_circle(at, 11.0, Color(0.05, 0.05, 0.07))
				canvas.draw_arc(at, 11.0, 0, TAU, 24, DeepUi.ACCENT if won else DeepUi.BAD, 2.0, true)
				_glyph(canvas, "crown", at, 13.0, DeepUi.ACCENT if won else DeepUi.BAD)
				_hotspots.append({"at": at, "radius": 11.0, "text": "Depth %d: a Warden%s" % [depth, " (beaten)" if won else ""]})
			else:
				canvas.draw_circle(at, 7.0, Color(0.05, 0.05, 0.07))
				canvas.draw_arc(at, 7.0, 0, TAU, 20, Color(DeepUi.GOOD, 0.7), 1.5, true)
				_hotspots.append({"at": at, "radius": 7.0, "text": "Depth %d: a landing with a lift" % depth})
			canvas.draw_string(ThemeDB.fallback_font, at + Vector2(-width - 18, 4), str(depth), HORIZONTAL_ALIGNMENT_RIGHT, 20, 10, DeepUi.DIM)
		canvas.draw_string(DeepUi.display_font(), Vector2(x + width, surface_y + float(run_depth) * step + step * 0.6 + 4), "ENDLESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b58cff"))
		canvas.draw_string(DeepUi.display_font(), Vector2(x + width * 0.5 + 10.0, surface_y + 22.0), str(mine.get("name", key)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DeepUi.PAPER if chosen_one else DeepUi.MUTED)
		if chosen_one:
			_cage = Vector2(x, surface_y)
	queue_redraw()

func _draw() -> void:
	## Only what moves.
	for spot in _twinkles:
		var pulse: float = 0.45 + 0.55 * absf(sin(_clock * float(spot.rate) + float(spot.phase)))
		draw_circle(spot.at, float(spot.r), Color(spot.colour, Color(spot.colour).a * pulse))
	var glow: Texture2D = DeepUi.glow_texture()
	var home := _home
	var window_glow: float = 0.75 + 0.25 * sin(_clock * 2.7) * sin(_clock * 1.3)
	draw_rect(Rect2(home + Vector2(-26, -26), Vector2(14, 14)), Color(Color("ffc860"), window_glow))
	draw_rect(Rect2(home + Vector2(10, -26), Vector2(14, 14)), Color(Color("ffc860"), window_glow))
	draw_texture_rect(glow, Rect2(home + Vector2(-60, -60), Vector2(120, 80)), false, Color(Color("ffc860"), 0.18 * window_glow))
	for i in range(5):
		var t: float = fmod(_clock * 0.25 + float(i) * 0.2, 1.0)
		draw_circle(home + Vector2(27 + sin(t * 6.0 + float(i)) * 6.0, -68 - t * 50.0), 3.0 + t * 6.0, Color(0.6, 0.6, 0.65, 0.25 * (1.0 - t)))
	for tip in _lanterns:
		var flare: float = 36.0 + 6.0 * sin(_clock * 3.0)
		draw_texture_rect(glow, Rect2(tip - Vector2(flare, flare) * 0.5, Vector2(flare, flare)), false, Color(DeepUi.ACCENT, 0.7))
	if _cage.x >= 0.0:
		var bob: float = sin(_clock * 1.6) * 2.0
		var cage := Rect2(Vector2(_cage.x - 9, _cage.y + 6 + bob), Vector2(18, 16))
		draw_line(Vector2(_cage.x, _cage.y - 4), Vector2(_cage.x, cage.position.y), Color("9aa0aa"), 1.0)
		draw_rect(cage, Color("9aa0aa"), false, 1.5)
