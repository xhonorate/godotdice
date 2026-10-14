extends Control
## The mines as a cross-section of the earth under the workshop: one stratum per mine.
##
## Sky and the workshop on the surface; below it every mine is a band of its own rock, the
## Quarry at the top and the Rift at the bottom, so how deep a mine lies is how hard it is.
## One shaft runs down from the workshop floor through every stratum the player has broken
## into and stops at rubble and a lock where the first sealed one begins. Each open band
## carries its depth track (lit as far as the player has been, a crown for each Warden and
## for the final boss, gold once beaten) and the carats its rock gives up. The last crown of a
## track wears the Birthstone of the delver that mine's bottom lets out. Click a band to
## choose it. On the day's seam the whole cross-section is one route, from the Quarry down,
## and the records are the day's own: lit as far as today's digs have gone, the rest of the
## route ahead in the dark, and no delver waiting at any bottom (the seam lets nobody out).
##
## The earth is drawn once into its own layer and only redrawn when the map changes; this
## control draws only what moves: twinkling stars and veins, the lit windows, chimney smoke,
## the lantern at the deepest point of the chosen mine and the cage at the head of its stratum.
##
## Once the Rift has been reached, the sky carries the Hazard gauge (docs/HAZARDS.md): a pip
## for every tier, lit up to the one the party is set to, locked past the highest unlocked.
## The strata show the chosen tier's own map, and every carat chip reads that tier's rock.

signal chosen(mine_key: String)
signal hazard_chosen(tier: int)

const Biomes = preload("res://view/battle/biomes.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

const NUMERALS: Array = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const SHAFT_X: float = 56.0
const SHAFT_WIDTH: float = 22.0

var mines: Array = []
var records: Dictionary = {}
var selected: String = ""
var can_choose: bool = true
## The delvers the player has met, so a track's last crown can show whether its own is one.
var met: Array = []
## The day's seam: the strata are one route, `records` say how far today's digs reached,
## and none can be chosen.
var daily: bool = false
## Birthstone photographs for the crowns, by delver, as they arrive.
var _faces: Dictionary = {}
var _clock: float = 0.0
var _hover: String = ""
var _hotspots: Array = []
var _bands: Dictionary = {}
var _earth: Control
var _twinkles: Array = []
var _lanterns: Array = []
var _cage: Vector2 = Vector2(-1, -1)
var _home: Vector2 = Vector2.ZERO
## The Hazard tier the party is set to, the highest this player has unlocked, and the highest
## the whole party has (a guest's lower tier caps the host's).
var hazard: int = 0
var hazard_top: int = 0
var hazard_cap: int = 0
var can_pick_hazard: bool = false
var _pips: Array = []
var _pip_hover: int = -1

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

func show_mines(keys: Array, profile_mines: Dictionary, chosen_key: String, host: bool, met_characters: Array = [], route: bool = false,
		tier: int = 0, top: int = 0, cap: int = 0) -> void:
	hazard = tier
	hazard_top = top
	hazard_cap = mini(cap, top)
	can_pick_hazard = host
	met = met_characters
	mines = keys
	records = profile_mines
	selected = chosen_key if not route else ""
	can_choose = host and not route
	daily = route
	for key in keys:
		var lapidary: String = _lets_out(str(key))
		if lapidary.is_empty() or _faces.has(lapidary):
			continue
		var stone: Dictionary = DeepStone.birthstone(lapidary)
		if stone.is_empty():
			continue
		_faces[lapidary] = Thumbs.request(Thumbs.gem_key(stone), "gem", {"stone": stone}, _face_arrived.bind(lapidary))
	if _earth != null:
		_earth.queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree():
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pip: int = _pip_at(event.position)
		var over: String = _band_at(event.position) if pip < 0 else ""
		if over != _hover or pip != _pip_hover:
			_hover = over
			_pip_hover = pip
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _choosable(over) or _pickable(pip) else Control.CURSOR_ARROW
			_earth.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pip: int = _pip_at(event.position)
		if pip >= 0:
			if _pickable(pip) and pip != hazard:
				hazard_chosen.emit(pip)
			return
		var over: String = _band_at(event.position)
		if _choosable(over):
			chosen.emit(over)

func _pip_at(at: Vector2) -> int:
	for pip in _pips:
		if (pip.rect as Rect2).has_point(at):
			return int(pip.tier)
	return -1

func _pickable(tier: int) -> bool:
	return tier >= 0 and can_pick_hazard and tier <= hazard_cap

func _choosable(key: String) -> bool:
	return not key.is_empty() and can_choose and bool(records.get(key, {}).get("unlocked", false))

func _face_arrived(texture: Texture2D, lapidary: String) -> void:
	_faces[lapidary] = texture
	if is_instance_valid(_earth):
		_earth.queue_redraw()

static func _lets_out(key: String) -> String:
	## The delver this mine's final boss lets out: the one whose own mine lies below it.
	return str(DeepContent.mine(str(DeepContent.mine(key).get("next", ""))).get("lapidary", ""))

func _band_at(at: Vector2) -> String:
	for key in _bands:
		if (_bands[key] as Rect2).has_point(at):
			return str(key)
	return ""

func _get_tooltip(at_position: Vector2) -> String:
	for spot in _hotspots:
		if spot.has("rect"):
			if (spot.rect as Rect2).has_point(at_position):
				return str(spot.text)
		elif at_position.distance_to(spot.at) <= float(spot.radius) + 3.0:
			return str(spot.text)
	var over: String = _band_at(at_position)
	if over.is_empty():
		return ""
	var mine: Dictionary = DeepContent.mine(over)
	if daily:
		var reached: bool = records.has(over)
		return "%s\n%s" % [str(mine.get("name", over)), "Reached on today's seam." if reached else ("Every dig today starts here." if mines.find(over) == 0 else "On today's route, not reached yet today.")]
	if not bool(records.get(over, {}).get("unlocked", false)):
		return "%s, sealed. %s" % [str(mine.get("name", over)), sealed_hint(over, hazard)]
	return "%s\n%s" % [str(mine.get("name", over)), str(mine.get("text", ""))]

static func sealed_hint(key: String, tier: int = 0) -> String:
	## What breaks a sealed mine open: the final boss of the mine above it, on this tier.
	for other in DeepContent.mines_in_order():
		if str(DeepContent.mine(str(other)).get("next", "")) == key:
			return "Beat the bottom of %s%s to break it open." % [DeepContent.mine_name(str(other)), " on Hazard %d" % tier if tier > 0 else ""]
	return "It has not been found."

static func numeral(key: String) -> String:
	if DeepContent.is_endless(key):
		return "∞"
	var tier: int = DeepContent.mine_tier(key)
	return str(NUMERALS[tier - 1]) if tier >= 1 and tier <= NUMERALS.size() else str(tier)

static func carat_words(key: String, tier: int = 0) -> String:
	## "1–7 ct": what a stone from this mine can weigh on a Hazard tier, as the strata and the
	## expedition say it. The Rift's climbs with every Warden, until nothing can be heavier.
	var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(DeepContent.mine(key), tier), 1)
	if band.is_empty():
		return "any size"
	return "1–%d%s ct" % [int(band.cap), "+" if DeepContent.is_endless(key) and int(band.cap) < DeepStone.carat_max() else ""]

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
	DeepUi.facet(frame)
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
	var open_to: float = surface_y
	var outlines: Array = []
	## The day's seam: the deepest mine its digs reached today, where the lantern hangs, and
	## the bottom of the last stratum reached, below which the route is still ahead.
	var deepest_today: String = ""
	for key in mines:
		if records.has(str(key)):
			deepest_today = str(key)
	var reached_to: float = surface_y
	for index in range(mines.size()):
		var key: String = str(mines[index])
		var mine: Dictionary = DeepContent.mine(key)
		var record: Dictionary = records.get(key, {})
		## On the day's seam a stratum is lit once today's digs reach it, and the first always,
		## where every dig begins; the rest are ahead, dark but never sealed.
		var reached: bool = records.has(key) or index == 0
		var open: bool = bool(record.get("unlocked", false)) if not daily else reached
		var ahead: bool = daily and not reached
		var biome: Dictionary = Biomes.for_depth(key, 1)
		var top: float = surface_y + float(index) * band_h
		var bottom: float = top + band_h
		var rect := Rect2(Vector2(0, top), Vector2(size.x, band_h))
		_bands[key] = rect
		var rock: Color = Color(biome.rock).darkened(0.3 if open else (0.58 if ahead else 0.72))
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
			## Outlined once every band is down (below), or the next band's ragged top covers
			## the bottom edge of this one.
			outlines.append([rect, DeepUi.ACCENT if chosen_one else Color(tone, 0.8)])
		## The shaft through this stratum: lit if the mine is open, rubble and a lock where the
		## way down is still shut.
		var shaft := Rect2(Vector2(SHAFT_X - SHAFT_WIDTH * 0.5, top), Vector2(SHAFT_WIDTH, band_h))
		if open:
			canvas.draw_rect(shaft, Color(0, 0, 0, 0.7))
			canvas.draw_rect(Rect2(shaft.position + Vector2(4, 0), Vector2(SHAFT_WIDTH - 8, band_h)), Color(DeepUi.ACCENT, 0.42 if chosen_one else 0.22))
			canvas.draw_line(shaft.position, shaft.position + Vector2(0, band_h), Color(DeepUi.ACCENT, 0.6), 1.5)
			canvas.draw_line(shaft.position + Vector2(SHAFT_WIDTH, 0), shaft.position + Vector2(SHAFT_WIDTH, band_h), Color(DeepUi.ACCENT, 0.6), 1.5)
			open_to = bottom
			if daily:
				reached_to = bottom
		elif ahead:
			canvas.draw_rect(shaft, Color(0, 0, 0, 0.45))
		elif top <= open_to + 1.0:
			for i in range(7):
				canvas.draw_circle(Vector2(SHAFT_X + rng.randf_range(-8, 8), top + 6.0 + float(i) * 5.0), rng.randf_range(3, 5.5), Color("4a4038"))
		if not open and not ahead:
			canvas.draw_circle(Vector2(SHAFT_X, (top + bottom) * 0.5), 13.0, Color(0.03, 0.035, 0.05, 0.9))
			_glyph(canvas, "lock", Vector2(SHAFT_X, (top + bottom) * 0.5), 14.0, DeepUi.DIM)
		## The mine's numeral and name.
		var mid: float = (top + bottom) * 0.5
		var badge := Vector2(SHAFT_X + 44.0, mid)
		canvas.draw_circle(badge, 15.0, Color(0, 0, 0, 0.35))
		canvas.draw_arc(badge, 15.0, 0, TAU, 28, Color(tone, 1.0 if open else 0.4), 1.5, true)
		var lit_name: bool = open or ahead
		canvas.draw_string(DeepUi.display_font(), badge + Vector2(-15, 4), numeral(key), HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(tone, 1.0 if open else (0.7 if ahead else 0.45)))
		var name_x: float = badge.x + 26.0
		canvas.draw_string(DeepUi.display_font(), Vector2(name_x, mid - 2), str(mine.get("name", key)), HORIZONTAL_ALIGNMENT_LEFT, 230, 19, DeepUi.PAPER if open else (DeepUi.MUTED if ahead else DeepUi.DIM))
		var under: String = ("SEALED" if not open else ("BEATEN" if bool(record.get("boss", false)) else "OPEN"))
		if daily:
			## Short, to fit beside the longest biome's name: the whole map is today's.
			under = "AHEAD" if ahead else ("BEATEN" if bool(record.get("boss", false)) else ("REACHED" if records.has(key) else "START"))
		canvas.draw_string(DeepUi.display_font(), Vector2(name_x, mid + 15), "%s  ·  %s" % [str(biome.name).to_upper(), under], HORIZONTAL_ALIGNMENT_LEFT, 240, 10, Color(tone, 0.85 if open else (0.6 if lit_name else 0.4)))
		## The depth track: how far down this mine the player has been, and its crowns.
		var track_x: float = name_x + 238.0
		var track_w: float = clampf(size.x - track_x - 150.0, 120.0, 380.0)
		if ahead:
			canvas.draw_string(DeepUi.body_font(), Vector2(track_x, mid + 4), "Not reached today", HORIZONTAL_ALIGNMENT_LEFT, track_w + 40.0, 13, DeepUi.MUTED)
		elif not open:
			canvas.draw_string(DeepUi.body_font(), Vector2(track_x, mid + 4), sealed_hint(key, hazard), HORIZONTAL_ALIGNMENT_LEFT, track_w + 40.0, 13, DeepUi.DIM)
		else:
			_draw_track(canvas, key, record, Vector2(track_x, mid), track_w, chosen_one or (daily and key == deepest_today))
		## What its rock gives up, and who is met down there.
		var chip_x: float = track_x + track_w + 28.0
		var chip := Rect2(Vector2(chip_x, mid - 12), Vector2(86, 24))
		var chip_box := StyleBoxFlat.new()
		chip_box.bg_color = Color(0, 0, 0, 0.38)
		## A Hazard tier's heavier rock rings its chip in gold.
		var heavier: bool = DeepForge.hazard_carats(mine, hazard) > 0
		chip_box.border_color = Color(DeepUi.ACCENT, 0.8 if open else 0.3) if heavier else Color(tone, 0.5 if open else 0.2)
		chip_box.set_border_width_all(1)
		chip_box.set_corner_radius_all(12)
		DeepUi.facet(chip_box)
		canvas.draw_style_box(chip_box, chip)
		_glyph(canvas, "gem", chip.position + Vector2(15, 12), 12.0, Color(tone, 1.0 if open else 0.45))
		canvas.draw_string(DeepUi.body_font(), chip.position + Vector2(25, 17), carat_words(key, hazard), HORIZONTAL_ALIGNMENT_LEFT, 58, 12, (DeepUi.ACCENT_HI if heavier else DeepUi.PAPER) if open else DeepUi.DIM)
		_hotspots.append({"at": chip.get_center(), "radius": 30.0, "text": _carat_tip(key)})
		if chosen_one:
			_cage = Vector2(SHAFT_X, top + 4.0)
	for line in outlines:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = line[1]
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(6)
		DeepUi.facet(outline)
		canvas.draw_style_box(outline, (line[0] as Rect2).grow_individual(-3, -1, -3, -1))
	if daily:
		## The rest of the day's route: a dashed line of light down the shaft below the
		## strata today's digs have reached.
		var y: float = reached_to + 6.0
		while y < size.y - 10.0:
			canvas.draw_line(Vector2(SHAFT_X, y), Vector2(SHAFT_X, minf(y + 9.0, size.y - 10.0)), Color(DeepUi.ACCENT, 0.55), 3.0)
			y += 16.0
	## A Hazard tier reddens the deep.
	if hazard > 0:
		canvas.draw_texture_rect(glow, Rect2(Vector2(-size.x * 0.25, size.y * 0.55), Vector2(size.x * 1.5, size.y * 0.9)), false, Color(DeepUi.BAD, 0.22 * float(hazard) / float(maxi(1, DeepContent.hazard_max()))))
	_draw_hazard_gauge(canvas, surface_y)
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
		canvas.draw_string(DeepUi.body_font(), Vector2(at.x, at.y + 16), "Endless  ·  deepest %d  ·  a Warden every %d" % [deepest, DeepDescent.warden_every(mine)], HORIZONTAL_ALIGNMENT_LEFT, width + 60.0, 11, DeepUi.MUTED)
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
		var who: String = "the final boss" if boss else "a Warden"
		## The day's seam lets nobody out at any bottom, so its crowns are plain.
		var lapidary: String = _lets_out(key) if boss and not daily else ""
		if not lapidary.is_empty():
			## The delver this bottom lets out, as their Birthstone, ringed in gold once met.
			var face_r: float = 15.0
			var known: bool = met.has(lapidary)
			canvas.draw_circle(spot, face_r, Color(0.05, 0.05, 0.07))
			var texture: Variant = _faces.get(lapidary, null)
			if texture is Texture2D:
				canvas.draw_texture_rect(texture, Rect2(spot - Vector2.ONE * face_r * 0.85, Vector2.ONE * face_r * 1.7), false, Color(1, 1, 1, 1.0) if known else Color(0.45, 0.45, 0.5, 0.9))
			canvas.draw_arc(spot, face_r, 0, TAU, 32, DeepUi.ACCENT if won or known else DeepUi.BAD, 2.0, true)
			_glyph(canvas, "crown", spot + Vector2(face_r * 0.75, -face_r * 0.75), 11.0, DeepUi.ACCENT if won else DeepUi.BAD)
			var joins: String = "%s has joined you." % DeepContent.character_title(lapidary) if known else "%s joins when it falls." % DeepContent.character_title(lapidary)
			_hotspots.append({"at": spot, "radius": face_r, "text": "Depth %d: %s%s. %s" % [depth, who, " (beaten)" if won else "", joins]})
			continue
		canvas.draw_circle(spot, radius, Color(0.05, 0.05, 0.07))
		canvas.draw_arc(spot, radius, 0, TAU, 24, DeepUi.ACCENT if won else DeepUi.BAD, 2.0, true)
		_glyph(canvas, "crown", spot, radius * 1.2, DeepUi.ACCENT if won else DeepUi.BAD)
		_hotspots.append({"at": spot, "radius": radius, "text": "Depth %d: %s%s" % [depth, who, " (beaten)" if won else ""]})
	var wardens_won: int = beaten.size()
	canvas.draw_string(DeepUi.body_font(), Vector2(at.x, at.y + 16), "deepest %d of %d  ·  %d of %d crowns" % [deepest, bottom, mini(wardens_won, crowns.size()), crowns.size()],
		HORIZONTAL_ALIGNMENT_LEFT, width + 40.0, 11, DeepUi.MUTED)

func _carat_tip(key: String) -> String:
	var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(DeepContent.mine(key), hazard), 1)
	if band.is_empty():
		return "Stones of any size."
	var heavier: String = ""
	var lift: int = DeepForge.hazard_carats(DeepContent.mine(key), hazard)
	if lift > 0:
		heavier = " Hazard %d lifts both by %d, and a stone that reaches the usual top keeps growing %d%% of the time." % [hazard, lift, int(round(float(band.get("pressure", 0.0))))]
	if DeepContent.is_endless(key):
		return "Stones usually up to %d carats and never over %d; both climb a carat with every Warden, up to %d.%s" % [int(band.soft), int(band.cap), DeepStone.carat_max(), heavier]
	return "Stones usually up to %d carats, rarely up to %d, never more.%s" % [int(band.soft), int(band.cap), heavier]

## Where the gauge starts, clear of the workshop and its name.
const GAUGE_LEFT: float = 300.0

func _draw_hazard_gauge(canvas: CanvasItem, surface_y: float) -> void:
	## The Hazard gauge in the sky: a pip for tier 0 and one for every tier of the ladder, a
	## bigger one every fifth. Lit up to the party's tier; past the highest it is locked.
	_pips.clear()
	if hazard_top <= 0:
		return
	var tiers: int = DeepContent.hazard_max()
	var left: float = GAUGE_LEFT
	var right: float = size.x - 24.0
	if right - left < 160.0:
		return
	var step: float = minf(30.0, (right - left) / float(tiers + 1))
	var row_y: float = surface_y * 0.66
	var label_y: float = surface_y * 0.34
	## The label: the tier, its newest hazard, and how many more are under it.
	var adds: Dictionary = DeepContent.hazard_tier(hazard)
	var head: String = "HAZARD %d" % hazard if hazard > 0 else "NO HAZARD"
	var font: Font = DeepUi.display_font()
	canvas.draw_string(font, Vector2(left, label_y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DeepUi.BAD if hazard > 0 else DeepUi.MUTED)
	var head_w: float = font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var said: String = "The ordinary map. Pick a tier to make it harder."
	if hazard > 0:
		said = str(adds.get("name", "")) + (", and %d more" % (hazard - 1) if hazard > 1 else "")
	canvas.draw_string(DeepUi.body_font(), Vector2(left + head_w + 12.0, label_y), said, HORIZONTAL_ALIGNMENT_LEFT, right - left - head_w - 12.0, 12, DeepUi.PAPER if hazard > 0 else DeepUi.MUTED)
	_hotspots.append({"rect": Rect2(Vector2(left, label_y - 14.0), Vector2(right - left, 18.0)), "text": hazard_list(hazard)})
	for tier in range(tiers + 1):
		var centre := Vector2(left + step * (float(tier) + 0.5), row_y)
		var open: bool = tier <= hazard_top
		var within: bool = tier <= hazard_cap
		var on: bool = tier == hazard
		var lit: bool = tier > 0 and tier <= hazard
		var hover: bool = tier == _pip_hover and _pickable(tier)
		var r: float = 7.5 if tier % 5 == 0 and tier > 0 else 6.0
		if on:
			canvas.draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(18, 18), Vector2(36, 36)), false, Color(DeepUi.BAD if tier > 0 else DeepUi.MUTED, 0.55))
		var edge: Color = DeepUi.BAD if tier > 0 else DeepUi.MUTED
		if not open or not within:
			edge = Color(DeepUi.DIM, 0.6)
		if hover:
			edge = edge.lightened(0.35)
		var fill: Color = Color(0.04, 0.05, 0.08, 0.85)
		if on:
			fill = DeepUi.BAD if tier > 0 else DeepUi.MUTED
		elif lit:
			fill = Color(DeepUi.BAD, 0.35)
		if tier == 0:
			canvas.draw_circle(centre, r, fill)
			canvas.draw_arc(centre, r, 0, TAU, 20, edge, 1.5, true)
		else:
			var shape := PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)])
			canvas.draw_colored_polygon(shape, fill)
			shape.append(shape[0])
			canvas.draw_polyline(shape, edge, 1.5, true)
		var hit := Rect2(centre - Vector2(step * 0.5, 12.0), Vector2(step, 24.0))
		_pips.append({"rect": hit, "tier": tier})
		_hotspots.append({"rect": hit, "text": _pip_tip(tier, open, within)})

static func hazard_list(tier: int) -> String:
	## Every hazard a tier carries, one to a line.
	if tier <= 0:
		return "Hazard 0: no hazards. The map as it was before the Rift."
	var lines: Array = ["Hazard %d carries:" % tier]
	for index in range(1, tier + 1):
		var entry: Dictionary = DeepContent.hazard_tier(index)
		lines.append("%d. %s: %s" % [index, str(entry.get("name", "")), str(entry.get("text", ""))])
	return "\n".join(lines)

func _pip_tip(tier: int, open: bool, within: bool) -> String:
	if tier == 0:
		return "Hazard 0: no hazards. Start in any mine you have opened."
	var entry: Dictionary = DeepContent.hazard_tier(tier)
	var adds: String = "Hazard %d adds %s: %s" % [tier, str(entry.get("name", "")), str(entry.get("text", ""))]
	if not open:
		return "%s\nReach the Rift on Hazard %d to open it." % [adds, tier - 1]
	if not within:
		return "%s\nNot everyone in the party has it open." % adds
	return adds + ("" if can_pick_hazard else "\nThe host picks the tier.")

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
