extends Control
## The mines as a cross-section of the earth under the workshop: one stratum per mine.
##
## Sky and the workshop on the surface; below it every mine is a band of its own rock, the
## Quarry at the top and the Rift at the bottom, so how deep a mine lies is how hard it is.
## One shaft runs down from the workshop floor through every stratum the player has broken
## into and stops at rubble and a lock where the first sealed one begins. Each open band
## carries its depth track (lit as far as the player has been, a crown for each Warden and
## for the final boss, gold once beaten), the carats its rock gives up, and the lapidary met
## there. Click a band to choose it.
##
## The earth is drawn once into its own layer and only redrawn when the map changes; this
## control draws only what moves: twinkling stars and veins, the lit windows, chimney smoke,
## the lantern at the deepest point of the chosen mine and the cage at the head of its stratum.

signal chosen(mine_key: String)

const Biomes = preload("res://view/battle/biomes.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")

const NUMERALS: Array = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const SHAFT_X: float = 56.0
const SHAFT_WIDTH: float = 22.0

var mines: Array = []
var records: Dictionary = {}
var selected: String = ""
var can_choose: bool = true
## The lapidaries the player has met, so a stratum can show whether its own is one of them.
var met: Array = []
var _clock: float = 0.0
var _hover: String = ""
var _hotspots: Array = []
var _bands: Dictionary = {}
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

func show_mines(keys: Array, profile_mines: Dictionary, chosen_key: String, host: bool, met_characters: Array = []) -> void:
	met = met_characters
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
		var over: String = _band_at(event.position)
		if over != _hover:
			_hover = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _choosable(over) else Control.CURSOR_ARROW
			_earth.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var over: String = _band_at(event.position)
		if _choosable(over):
			chosen.emit(over)

func _choosable(key: String) -> bool:
	return not key.is_empty() and can_choose and bool(records.get(key, {}).get("unlocked", false))

func _band_at(at: Vector2) -> String:
	for key in _bands:
		if (_bands[key] as Rect2).has_point(at):
			return str(key)
	return ""

func _get_tooltip(at_position: Vector2) -> String:
	for spot in _hotspots:
		if at_position.distance_to(spot.at) <= float(spot.radius) + 3.0:
			return str(spot.text)
	var over: String = _band_at(at_position)
	if over.is_empty():
		return ""
	var mine: Dictionary = DeepContent.mine(over)
	if not bool(records.get(over, {}).get("unlocked", false)):
		return "%s, sealed. %s" % [str(mine.get("name", over)), sealed_hint(over)]
	return "%s\n%s" % [str(mine.get("name", over)), str(mine.get("text", ""))]

static func sealed_hint(key: String) -> String:
	## What breaks a sealed mine open: the final boss of the mine above it.
	for other in DeepContent.mines_in_order():
		if str(DeepContent.mine(str(other)).get("next", "")) == key:
			return "Beat the bottom of %s to break it open." % DeepContent.mine_name(str(other))
	return "It has not been found."

static func numeral(key: String) -> String:
	if DeepContent.is_endless(key):
		return "∞"
	var tier: int = DeepContent.mine_tier(key)
	return str(NUMERALS[tier - 1]) if tier >= 1 and tier <= NUMERALS.size() else str(tier)

static func carat_words(key: String) -> String:
	## "1–7 ct": what a stone from this mine can weigh, as the strata and the expedition say it.
	var band: Dictionary = DeepForge.carat_band(DeepContent.mine(key), 1)
	if band.is_empty():
		return "any size"
	return "1–%d%s ct" % [int(band.cap), "+" if DeepContent.is_endless(key) else ""]

func _glyph(canvas: CanvasItem, name: String, centre: Vector2, edge: float, tint: Color) -> void:
	canvas.draw_texture_rect(GemIcons.texture(name, GemIcons.baked_size(edge * 1.5)), Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, tint)

func _draw_earth() -> void:
	var canvas: Control = _earth
	_hotspots.clear()
	_bands.clear()
	_twinkles.clear()
	_lanterns.clear()
	_cage = Vector2(-1, -1)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("07080b")
	frame.set_corner_radius_all(16)
	frame.border_color = Color(DeepUi.LINE_HI, 0.6)
	frame.set_border_width_all(1)
	canvas.draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var surface_y: float = clampf(size.y * 0.13, 70.0, 110.0)
	var glow: Texture2D = DeepUi.glow_texture()
	## Sky: a deep dusk over the workshop, with a few stars.
	canvas.draw_rect(Rect2(Vector2(1, 1), Vector2(size.x - 2, surface_y)), Color("121a2c"))
	canvas.draw_texture_rect(glow, Rect2(Vector2(size.x * 0.5 - size.x * 0.6, surface_y - size.y * 0.25), Vector2(size.x * 1.2, size.y * 0.5)), false, Color("e2b23a", 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(30):
		_twinkles.append({"at": Vector2(rng.randf() * size.x, rng.randf() * surface_y * 0.8), "r": rng.randf_range(0.6, 1.6), "color": Color(1, 1, 1, 0.5), "rate": rng.randf_range(0.5, 2.0), "phase": float(i)})
	## The strata: one band per mine, shallowest first, each the color of its own rock.
	var count: int = maxi(1, mines.size())
	var band_h: float = (size.y - surface_y - 6.0) / float(count)
	var wide: bool = size.x >= 760.0
	var open_to: float = surface_y
	for index in range(mines.size()):
		var key: String = str(mines[index])
		var mine: Dictionary = DeepContent.mine(key)
		var record: Dictionary = records.get(key, {})
		var open: bool = bool(record.get("unlocked", false))
		var biome: Dictionary = Biomes.for_depth(key, 1)
		var top: float = surface_y + float(index) * band_h
		var bottom: float = top + band_h
		var rect := Rect2(Vector2(0, top), Vector2(size.x, band_h))
		_bands[key] = rect
		var rock: Color = Color(biome.rock).darkened(0.3 if open else 0.72)
		var poly := PackedVector2Array()
		var steps := 14
		for i in range(steps + 1):
			poly.append(Vector2(size.x * float(i) / float(steps), top + (sin(float(i) * 1.7 + float(index)) * 3.0 if index > 0 else 0.0)))
		for i in range(steps, -1, -1):
			poly.append(Vector2(size.x * float(i) / float(steps), bottom + sin(float(i) * 1.7 + float(index + 1)) * 3.0 + 1.0))
		canvas.draw_colored_polygon(poly, rock)
		for i in range(8):
			canvas.draw_circle(Vector2(rng.randf() * size.x, rng.randf_range(top + 4.0, bottom - 4.0)), rng.randf_range(1.5, 3.5), rock.lightened(0.08))
		if open:
			for i in range(3):
				_twinkles.append({"at": Vector2(rng.randf_range(SHAFT_X + 40.0, size.x), rng.randf_range(top + 6.0, bottom - 6.0)), "r": 1.8, "color": Color(biome.accent, 0.9), "rate": 1.5, "phase": float(i + index)})
		var tone: Color = Color(str(mine.get("palette", "c9a26b")))
		var chosen_one: bool = key == selected
		var hovered: bool = key == _hover and _choosable(key)
		if chosen_one or hovered:
			canvas.draw_rect(rect.grow_individual(-3, -2, -3, -2), DeepUi.ACCENT if chosen_one else Color(tone, 0.8), false, 2.0)
		## The shaft through this stratum: lit if the mine is open, rubble and a lock where the
		## way down is still shut.
		var shaft := Rect2(Vector2(SHAFT_X - SHAFT_WIDTH * 0.5, top), Vector2(SHAFT_WIDTH, band_h))
		if open:
			canvas.draw_rect(shaft, Color(0, 0, 0, 0.7))
			canvas.draw_rect(Rect2(shaft.position + Vector2(4, 0), Vector2(SHAFT_WIDTH - 8, band_h)), Color(DeepUi.ACCENT, 0.42 if chosen_one else 0.22))
			canvas.draw_line(shaft.position, shaft.position + Vector2(0, band_h), Color(DeepUi.ACCENT, 0.6), 1.5)
			canvas.draw_line(shaft.position + Vector2(SHAFT_WIDTH, 0), shaft.position + Vector2(SHAFT_WIDTH, band_h), Color(DeepUi.ACCENT, 0.6), 1.5)
			open_to = bottom
		elif top <= open_to + 1.0:
			for i in range(7):
				canvas.draw_circle(Vector2(SHAFT_X + rng.randf_range(-8, 8), top + 6.0 + float(i) * 5.0), rng.randf_range(3, 5.5), Color("4a4038"))
		if not open:
			canvas.draw_circle(Vector2(SHAFT_X, (top + bottom) * 0.5), 13.0, Color(0.03, 0.035, 0.05, 0.9))
			_glyph(canvas, "lock", Vector2(SHAFT_X, (top + bottom) * 0.5), 14.0, DeepUi.DIM)
		## The mine's numeral and name.
		var mid: float = (top + bottom) * 0.5
		var badge := Vector2(SHAFT_X + 44.0, mid)
		canvas.draw_circle(badge, 15.0, Color(0, 0, 0, 0.35))
		canvas.draw_arc(badge, 15.0, 0, TAU, 28, Color(tone, 1.0 if open else 0.4), 1.5, true)
		canvas.draw_string(DeepUi.display_font(), badge + Vector2(-15, 4), numeral(key), HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(tone, 1.0 if open else 0.45))
		var name_x: float = badge.x + 26.0
		canvas.draw_string(DeepUi.display_font(), Vector2(name_x, mid - 2), str(mine.get("name", key)), HORIZONTAL_ALIGNMENT_LEFT, 230, 19, DeepUi.PAPER if open else DeepUi.DIM)
		var under: String = ("SEALED" if not open else ("BEATEN" if bool(record.get("boss", false)) else "OPEN"))
		canvas.draw_string(DeepUi.display_font(), Vector2(name_x, mid + 15), "%s  ·  %s" % [str(biome.name).to_upper(), under], HORIZONTAL_ALIGNMENT_LEFT, 240, 10, Color(tone, 0.85 if open else 0.4))
		## The depth track: how far down this mine the player has been, and its crowns.
		var track_x: float = name_x + 238.0
		var track_w: float = clampf(size.x - track_x - (250.0 if wide else 120.0), 120.0, 300.0)
		if not open:
			canvas.draw_string(ThemeDB.fallback_font, Vector2(track_x, mid + 4), sealed_hint(key), HORIZONTAL_ALIGNMENT_LEFT, track_w + 40.0, 12, DeepUi.DIM)
		else:
			_draw_track(canvas, key, record, Vector2(track_x, mid), track_w, chosen_one)
		## What its rock gives up, and who is met down there.
		var chip_x: float = track_x + track_w + 28.0
		var chip := Rect2(Vector2(chip_x, mid - 12), Vector2(86, 24))
		var chip_box := StyleBoxFlat.new()
		chip_box.bg_color = Color(0, 0, 0, 0.38)
		chip_box.border_color = Color(tone, 0.5 if open else 0.2)
		chip_box.set_border_width_all(1)
		chip_box.set_corner_radius_all(12)
		canvas.draw_style_box(chip_box, chip)
		_glyph(canvas, "gem", chip.position + Vector2(15, 12), 12.0, Color(tone, 1.0 if open else 0.45))
		canvas.draw_string(ThemeDB.fallback_font, chip.position + Vector2(25, 17), carat_words(key), HORIZONTAL_ALIGNMENT_LEFT, 58, 12, DeepUi.PAPER if open else DeepUi.DIM)
		_hotspots.append({"at": chip.get_center(), "radius": 30.0, "text": _carat_tip(key)})
		var lapidary: String = str(mine.get("lapidary", ""))
		if wide and not lapidary.is_empty():
			var known: bool = met.has(lapidary)
			var face := Vector2(chip_x + 112.0, mid)
			var hue: Color = GemMesh.tint(DeepStone.birthstone(lapidary)) if not DeepStone.birthstone(lapidary).is_empty() else tone
			if hue.get_luminance() < 0.3:
				hue = hue.lightened(0.45)
			canvas.draw_circle(face, 13.0, Color(hue.darkened(0.2), 0.95 if known else 0.35))
			_glyph(canvas, "person", face, 16.0, Color(0.03, 0.035, 0.05, 0.75))
			canvas.draw_string(ThemeDB.fallback_font, face + Vector2(19, 5), str(DeepContent.character(lapidary).get("name", lapidary)), HORIZONTAL_ALIGNMENT_LEFT, 90, 13, DeepUi.PAPER if known else DeepUi.DIM)
			_hotspots.append({"at": face, "radius": 14.0, "text": "%s joins when the boss of %s falls." % [DeepContent.character_title(lapidary), DeepContent.mine_name(DeepProfile.lapidary_boss_mine(lapidary))] + ("" if known else " Not met yet.")})
		if chosen_one:
			_cage = Vector2(SHAFT_X, top + 4.0)
	## The ground line and the workshop on it, over the top of the shaft.
	canvas.draw_rect(Rect2(Vector2(0, surface_y - 3), Vector2(size.x, 6)), Color("3a2e22"))
	_home = Vector2(SHAFT_X + 44.0, surface_y - 3)
	var home := _home
	canvas.draw_colored_polygon(PackedVector2Array([home + Vector2(-46, 0), home + Vector2(-46, -34), home + Vector2(0, -62), home + Vector2(46, -34), home + Vector2(46, 0)]), Color("241c16"))
	canvas.draw_rect(Rect2(home + Vector2(22, -64), Vector2(10, 22)), Color("241c16"))
	canvas.draw_string(DeepUi.display_font(), home + Vector2(60, -10), "THE WORKSHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DeepUi.ACCENT)
	queue_redraw()

func _draw_track(canvas: CanvasItem, key: String, record: Dictionary, at: Vector2, width: float, chosen_one: bool) -> void:
	## A line for the mine's depth with the deepest the player has reached lit along it, a
	## crown at each Warden and at the boss. The Rift has no bottom, so its track is a fade.
	var mine: Dictionary = DeepContent.mine(key)
	var bottom: int = DeepContent.mine_bottom(key)
	var deepest: int = int(record.get("deepest", 0))
	var beaten: Array = record.get("wardens", [])
	var line_y: float = at.y - 4.0
	canvas.draw_rect(Rect2(Vector2(at.x, line_y - 3), Vector2(width, 6)), Color(0, 0, 0, 0.5))
	if bottom <= 0:
		var reach: float = clampf(float(deepest) / 64.0, 0.0, 1.0)
		if deepest > 0:
			canvas.draw_rect(Rect2(Vector2(at.x, line_y - 3), Vector2(width * reach, 6)), Color(DeepUi.ACCENT, 0.85))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(at.x, at.y + 16), "Endless  ·  deepest %d  ·  a Warden every %d" % [deepest, DeepDescent.warden_every(mine)], HORIZONTAL_ALIGNMENT_LEFT, width + 60.0, 11, DeepUi.MUTED)
		if deepest > 0:
			_lanterns.append(Vector2(at.x + width * reach, line_y) if chosen_one else Vector2(-1, -1))
		return
	var lit: float = clampf(float(deepest) / float(bottom), 0.0, 1.0)
	if deepest > 0:
		canvas.draw_rect(Rect2(Vector2(at.x, line_y - 3), Vector2(width * lit, 6)), Color(DeepUi.ACCENT, 0.9))
		if chosen_one:
			_lanterns.append(Vector2(at.x + width * lit, line_y))
	var crowns: Array = mine.get("warden_depths", []).duplicate()
	crowns.append(bottom)
	for index in range(crowns.size()):
		var depth: int = int(crowns[index])
		var boss: bool = index == crowns.size() - 1
		var won: bool = beaten.any(func(d: Variant) -> bool: return absi(int(d) - depth) <= 1) if not boss else bool(record.get("boss", false))
		var spot := Vector2(at.x + width * float(depth) / float(bottom), line_y)
		var radius: float = 10.0 if boss else 8.0
		canvas.draw_circle(spot, radius, Color(0.05, 0.05, 0.07))
		canvas.draw_arc(spot, radius, 0, TAU, 24, DeepUi.ACCENT if won else DeepUi.BAD, 2.0, true)
		_glyph(canvas, "crown", spot, radius * 1.2, DeepUi.ACCENT if won else DeepUi.BAD)
		var who: String = "the final boss" if boss else "a Warden"
		_hotspots.append({"at": spot, "radius": radius, "text": "Depth %d: %s%s" % [depth, who, " (beaten)" if won else ""]})
	var wardens_won: int = beaten.size()
	canvas.draw_string(ThemeDB.fallback_font, Vector2(at.x, at.y + 16), "deepest %d of %d  ·  %d of %d crowns" % [deepest, bottom, mini(wardens_won, crowns.size()), crowns.size()],
		HORIZONTAL_ALIGNMENT_LEFT, width + 40.0, 11, DeepUi.MUTED)

func _carat_tip(key: String) -> String:
	var band: Dictionary = DeepForge.carat_band(DeepContent.mine(key), 1)
	if band.is_empty():
		return "Stones of any size."
	if DeepContent.is_endless(key):
		return "Stones usually up to %d carats and never over %d; both climb a carat with every Warden, up to %d." % [int(band.soft), int(band.cap), DeepStone.carat_max()]
	return "Stones usually up to %d carats, rarely up to %d, never more." % [int(band.soft), int(band.cap)]

func _draw() -> void:
	## Only what moves.
	for spot in _twinkles:
		var pulse: float = 0.45 + 0.55 * absf(sin(_clock * float(spot.rate) + float(spot.phase)))
		draw_circle(spot.at, float(spot.r), Color(spot.color, Color(spot.color).a * pulse))
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
		if tip.x < 0.0:
			continue
		var flare: float = 30.0 + 6.0 * sin(_clock * 3.0)
		draw_texture_rect(glow, Rect2(tip - Vector2(flare, flare) * 0.5, Vector2(flare, flare)), false, Color(DeepUi.ACCENT, 0.7))
	if _cage.x >= 0.0:
		var bob: float = sin(_clock * 1.6) * 2.0
		var cage := Rect2(Vector2(_cage.x - 9, _cage.y + 6 + bob), Vector2(18, 16))
		draw_line(Vector2(_cage.x, _cage.y - 4), Vector2(_cage.x, cage.position.y), Color("9aa0aa"), 1.0)
		draw_rect(cage, Color("9aa0aa"), false, 1.5)
