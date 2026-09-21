extends Control
## The lantern map: the way down as the party knows it.
##
## Above the party, the trail it walked, one mark per depth. Below it, the stretch down to the
## next landing as the sim charted it: chambers in lanes, the ways between them splitting and
## rejoining. The ways on from where the party stands are drawn live and can be clicked to
## vote; the lantern's pool shows what waits two depths ahead, and past its reach the rock is
## fogged and a chamber is only a glint: eyes for something hostile, a sparkle for something
## glittering, a question for something strange, nothing at all for a dark mouth. Lighting the
## way (a loupe, or ore) clears the fog down to the landing.

signal vote(offer_id: String)
signal light

const GemIcons = preload("res://view/gems/gem_icons.gd")

const STEP := 84.0
const NODE := 16.0
const GUTTER := 38.0
const TOP := 66.0
const FOOT := 58.0
const SEATS: Array = [Color("f0b44c"), Color("5fb8ff"), Color("6fdc8c"), Color("e07ad6")]
const GLINT_GLYPHS: Dictionary = {"hostile": "eye", "glittering": "star", "strange": "question", "dark": "question"}
const GLINT_TONES: Dictionary = {"hostile": Color("ff5a4a"), "glittering": Color("ffd257"), "strange": Color("b58cff"), "dark": Color("6d7688")}
const GLINT_WORDS: Dictionary = {
	"hostile": "Something moves down there: eyes catch the light.",
	"glittering": "Something glitters down there.",
	"strange": "Something strange waits down there.",
	"dark": "A dark mouth: nothing shows until the way is lit.",
}

var run: Dictionary = {}
var local_id: String = ""
## An offer the page is pointing at (a hovered tunnel card): its way ahead is picked out.
var focus: String = "":
	set(value):
		if value != focus:
			focus = value
			_mark()
var _hover: String = ""
var _shown: float = 0.0
## How far the reader has scrolled the map by hand, in depths; any move by the party resets it.
var _nudge: float = 0.0
var _step: float = STEP
var _clock: float = 0.0
var _lamp: Button
## Two layers: the rock, the depths, the trail and the ways between chambers are painted on
## the still layer only when something changes; the chambers, the glints, the sparks and the
## lantern are painted every frame on top. Painting everything every frame cost two
## milliseconds a frame.
var _back: Control
var _canvas: CanvasItem
var _painted: Vector2 = Vector2(-1, -1)
var _static_spots: Array = []
var _live_spots: Array = []
var _spots: Array = []
var _flows: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(300, 320)
	_back = Control.new()
	_back.show_behind_parent = true
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_paint_back)
	add_child(_back)
	_lamp = DeepUi.icon_button(self, "lantern", "Light the way", func() -> void: light.emit(), 13, DeepUi.ACCENT)
	_lamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	_lamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lamp.visible = false

func show_run(state: Dictionary) -> void:
	var first: bool = run.is_empty()
	run = state
	## The map rests on the head of the stretch, so the whole way to the landing is in view.
	var goal: float = float(int(run.get("map", {}).get("from", run.get("depth", 0))))
	if not is_equal_approx(goal, _shown):
		_nudge = 0.0
	if first or DisplayServer.get_name() == "headless":
		_shown = goal
	elif not is_equal_approx(goal, _shown):
		var tween := create_tween()
		tween.tween_property(self, "_shown", goal, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_sync_lamp()
	_mark()
	queue_redraw()

func _mark() -> void:
	if _back != null:
		_back.queue_redraw()

func _sync_lamp() -> void:
	var map: Dictionary = run.get("map", {})
	var phase: String = str(run.get("phase", ""))
	var open: bool = not map.is_empty() and phase in ["tunnels", "landing"] and int(map.get("to", 0)) > int(run.get("depth", 0)) and not bool(map.get("lit", false))
	_lamp.visible = open
	if not open:
		return
	var unit: Dictionary = DeepDescent.player(run, local_id)
	var cost: int = DeepDescent.lantern_cost()
	if int(unit.get("loupes", 0)) > 0:
		_lamp.text = "Light the way  ·  1 loupe"
		_lamp.disabled = false
	else:
		_lamp.text = "Light the way  ·  %d ore" % cost
		_lamp.disabled = int(unit.get("ore", 0)) < cost
	_lamp.tooltip_text = "Show every chamber down to the landing at depth %d, dark mouths too.\nCosts a loupe, or %d ore when you have none." % [int(map.get("to", 0)), cost]

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree():
		queue_redraw()
		if not _painted.is_equal_approx(Vector2(_shown, _nudge)):
			_mark()

# --- layout -----------------------------------------------------------------------------------

func _bottom() -> float:
	return size.y - (FOOT if _lamp != null and _lamp.visible else 16.0)

func _centre_y() -> float:
	## The head of the stretch sits high in the panel: the map is mostly about what lies ahead.
	return TOP + 58.0

func _fit_step() -> void:
	## Spread the stretch over the panel, the landing near the foot with a little room below.
	var map: Dictionary = _map()
	var span: float = float(maxi(3, int(map.get("to", 4)) - int(map.get("from", 0)))) + 0.55
	_step = clampf((_bottom() - _centre_y() - 20.0) / span, 62.0, 124.0)

func _y(depth: float) -> float:
	return _centre_y() + (depth - _shown - _nudge) * _step

func _x(lane: float) -> float:
	return GUTTER + 12.0 + lane * (size.x - GUTTER - 34.0)

func _fade(y: float) -> float:
	return clampf(minf(y - TOP, _bottom() - y) / 34.0, 0.0, 1.0)

func _map() -> Dictionary:
	return run.get("map", {})

func _here() -> String:
	## The charted chamber the party stands in, or "" at the head of the stretch.
	var map: Dictionary = _map()
	var at: String = str(map.get("at", ""))
	var node: Dictionary = map.get("nodes", {}).get(at, {})
	if node.is_empty() or int(node.depth) != int(run.get("depth", 0)):
		return ""
	return at

func _offers() -> Array:
	return run.get("offers", []) if str(run.get("phase", "")) == "tunnels" else []

func _is_offer(id: String) -> bool:
	for offer in _offers():
		if str(offer.id) == id:
			return true
	return false

func _ahead_of(ids: Array) -> Dictionary:
	## Every chamber that can still be reached through any of these.
	var map: Dictionary = _map()
	var seen: Dictionary = {}
	var queue: Array = ids.duplicate()
	while not queue.is_empty():
		var id: String = str(queue.pop_back())
		if seen.has(id):
			continue
		seen[id] = true
		for child in map.get("nodes", {}).get(id, {}).get("next", []):
			queue.append(str(child))
	return seen

func _positions() -> Dictionary:
	## Where each charted chamber sits, plus "head" for where the stretch begins.
	var map: Dictionary = _map()
	var out: Dictionary = {}
	for id in map.get("nodes", {}):
		var node: Dictionary = map.nodes[id]
		out[id] = Vector2(_x(float(node.get("x", 0.5))), _y(float(node.depth)))
	out["head"] = Vector2(_x(_trail_lane(int(map.get("from", 0)))), _y(float(map.get("from", 0))))
	return out

func _trail_lane(depth: int) -> float:
	for entry in run.get("path", []):
		if int(entry.get("depth", -1)) == depth:
			return float(entry.get("x", 0.5))
	return 0.5

# --- input ------------------------------------------------------------------------------------

func _spot_at(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for spot in _live_spots + _static_spots:
		var distance: float = at.distance_to(spot.at)
		if distance <= float(spot.radius) + 6.0 and distance < best_distance:
			best = spot
			best_distance = distance
	return best

func _get_tooltip(at_position: Vector2) -> String:
	return str(_spot_at(at_position).get("text", ""))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		## The wheel looks back up the trail, or further down the shaft.
		var way: float = -0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5
		_nudge = clampf(_nudge + way, -_shown, 3.0)
		_mark()
		accept_event()
		return
	if event is InputEventMouseMotion:
		var spot: Dictionary = _spot_at(event.position)
		var hovered: String = str(spot.get("offer", ""))
		if hovered != _hover:
			_hover = hovered
			_mark()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _hover.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var offer: String = str(_spot_at(event.position).get("offer", ""))
		if not offer.is_empty():
			vote.emit(offer)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _hover.is_empty():
		_hover = ""
		_mark()

# --- drawing ----------------------------------------------------------------------------------

func _glyph(name: String, centre: Vector2, edge: float, tint: Color) -> void:
	var texture: Texture2D = GemIcons.texture(name, GemIcons.baked_size(edge * 1.5))
	_canvas.draw_texture_rect(texture, Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, tint)

func _glow(at: Vector2, extent: Vector2, tint: Color) -> void:
	_canvas.draw_texture_rect(DeepUi.glow_texture(), Rect2(at - extent * 0.5, extent), false, tint)

func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var bend := Vector2(0, (b.y - a.y) * 0.55)
	for i in range(15):
		out.append(a.bezier_interpolate(a + bend, b - bend, b, float(i) / 14.0))
	return out

func _stroke(points: PackedVector2Array, tint: Color, width: float) -> void:
	var colours := PackedColorArray()
	for point in points:
		colours.append(Color(tint, tint.a * _fade(point.y)))
	_canvas.draw_polyline_colors(points, colours, width, true)

func _flow(points: PackedVector2Array, tint: Color, offset: float) -> void:
	## Sparks running down a way the party can take.
	for k in range(3):
		var t: float = fmod(_clock * 0.45 + float(k) / 3.0 + offset, 1.0)
		var at: Vector2 = points[int(t * float(points.size() - 1))]
		_canvas.draw_circle(at, 2.4, Color(tint, 0.9 * _fade(at.y) * sin(t * PI)))

func _paint_back() -> void:
	## The still layer: the panel, the depths, the trail, the ways and the fog.
	_canvas = _back
	_static_spots.clear()
	_spots = _static_spots
	_flows.clear()
	_painted = Vector2(_shown, _nudge)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.042, 0.06, 0.86)
	panel.border_color = Color(DeepUi.LINE_HI, 0.6)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(14)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 12
	_canvas.draw_style_box(panel, Rect2(Vector2.ZERO, size))
	if run.is_empty():
		return
	_fit_step()
	var positions: Dictionary = _positions()
	_draw_depths()
	_draw_trail(positions)
	var map: Dictionary = _map()
	if not map.is_empty():
		_stretch_ways(map, positions, _facts(map, positions))

func _draw() -> void:
	## The live layer, every frame.
	_canvas = self
	_live_spots.clear()
	_spots = _live_spots
	if run.is_empty():
		return
	_fit_step()
	var map: Dictionary = _map()
	if map.is_empty():
		_draw_loose_offers()
	else:
		var positions: Dictionary = _positions()
		_stretch_chambers(map, positions, _facts(map, positions))
	_draw_header(map, int(run.get("depth", 0)))

func _facts(map: Dictionary, positions: Dictionary) -> Dictionary:
	## Where the party is on the stretch and what it can still reach from there.
	var nodes: Dictionary = map.get("nodes", {})
	var here: String = _here()
	var visited: Dictionary = {}
	for entry in run.get("path", []):
		if int(entry.get("depth", 0)) > int(map.from) and not str(entry.get("id", "")).is_empty():
			visited[str(entry.id)] = true
	var ways: Array = DeepDescent.row_of(map, int(map.from) + 1) if here.is_empty() else nodes[here].next
	var picked: String = _hover if not _hover.is_empty() else focus
	return {"here": here, "here_at": positions.get(here, positions.head) if not here.is_empty() else positions.head, "visited": visited,
		"ways": ways, "ahead": _ahead_of(ways), "picked": picked,
		"lit_way": _ahead_of([picked]) if not picked.is_empty() and nodes.has(picked) else {},
		"choosing": str(run.get("phase", "")) == "tunnels"}

func _draw_header(map: Dictionary, depth: int) -> void:
	var font: Font = DeepUi.display_font()
	_canvas.draw_string(font, Vector2(18, 28), "THE WAY DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DeepUi.ACCENT)
	var mine_name: String = str(DeepContent.mine(str(run.get("mine", ""))).get("name", ""))
	_canvas.draw_string(ThemeDB.fallback_font, Vector2(18, 46), mine_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 12, DeepUi.MUTED)
	if map.is_empty():
		return
	var lit: bool = bool(map.get("lit", false))
	var words: String = "lit to %d" % int(map.to) if lit else "sees to %d" % mini(depth + DeepDescent.LANTERN_REACH, int(map.to))
	var tone: Color = DeepUi.ACCENT if lit else DeepUi.MUTED
	var width: float = ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var flicker: float = 0.85 + 0.15 * sin(_clock * 9.0) * sin(_clock * 4.3)
	_glyph("lantern", Vector2(size.x - width - 32, 40), 16.0, Color(DeepUi.ACCENT, flicker))
	_canvas.draw_string(ThemeDB.fallback_font, Vector2(size.x - width - 18, 46), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tone)
	_spots.append({"at": Vector2(size.x - width * 0.5 - 24, 40), "radius": 14.0,
		"text": "The way is lit down to the landing." if lit else "Your lantern shows what waits %d depths ahead. Past that, only glints." % DeepDescent.LANTERN_REACH})

func _draw_depths() -> void:
	## Depth numbers down the gutter, and a faint rule across the rock at each.
	var first: int = maxi(0, int(floor(_shown + _nudge - (_centre_y() - TOP) / _step)) - 1)
	var last: int = int(ceil(_shown + _nudge + (_bottom() - _centre_y()) / _step)) + 1
	var depth: int = int(run.get("depth", 0))
	var run_depth: int = int(DeepContent.constant("run_depth", 24))
	for d in range(first, last + 1):
		var y: float = _y(float(d))
		var fade: float = _fade(y)
		if fade <= 0.0:
			continue
		var tone: Color = DeepUi.PAPER if d == depth else DeepUi.DIM
		_canvas.draw_string(ThemeDB.fallback_font, Vector2(8, y + 5), str(d) if d > 0 else "", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color(tone, fade))
		_canvas.draw_line(Vector2(GUTTER - 4, y), Vector2(size.x - 12, y), Color(DeepUi.LINE, 0.18 * fade), 1.0)
		if d == run_depth + 1:
			_canvas.draw_string(DeepUi.display_font(), Vector2(GUTTER, y - _step * 0.5 + 4), "ENDLESS BELOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Color("b58cff"), fade))

func _medallion(at: Vector2, radius: float, kind: String, strength: float, ring: Color = Color(0, 0, 0, 0)) -> void:
	var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.MUTED)
	var fade: float = _fade(at.y) * strength
	_canvas.draw_circle(at, radius, Color(tone.darkened(0.62), 0.96 * fade))
	_canvas.draw_arc(at, radius, 0, TAU, 32, Color(ring if ring.a > 0.0 else tone, 0.95 * fade), 2.0, true)
	var glyph: String = str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch"))
	_glyph(glyph, at, radius * 1.12, Color(tone.lightened(0.35), fade))

func _draw_trail(positions: Dictionary) -> void:
	## The way the party came, above the stretch it is in now.
	var from: int = int(_map().get("from", run.get("depth", 0)))
	var points: Array = [{"at": Vector2(_x(0.5), _y(0.0)), "kind": "workshop", "depth": 0}]
	for entry in run.get("path", []):
		var d: int = int(entry.get("depth", 0))
		if d <= from:
			points.append({"at": Vector2(_x(float(entry.get("x", 0.5))), _y(float(d))), "kind": str(entry.get("kind", "fight")), "depth": d,
				"hidden": bool(entry.get("hidden", false))})
	for i in range(points.size() - 1):
		_stroke(_curve(points[i].at, points[i + 1].at), Color(DeepUi.ACCENT, 0.7), 3.0)
	var wardens: Array = run.get("records", {}).get("wardens", [])
	for point in points:
		var at: Vector2 = point.at
		if _fade(at.y) <= 0.0:
			continue
		if str(point.kind) == "workshop":
			_glyph("anvil", at, 22.0, Color(DeepUi.ACCENT, _fade(at.y)))
			_spots.append({"at": at, "radius": 14.0, "text": "The workshop. The lift comes back here."})
			continue
		var kind: String = str(point.kind)
		if kind == "landing" and DeepDescent.is_warden_depth(int(point.depth)):
			kind = "warden"
		_medallion(at, 12.0, kind, 0.85)
		var words: String = "Depth %d: %s" % [int(point.depth), "a dark mouth, and then a fight" if bool(point.get("hidden", false)) and kind == "hidden" else _kind_words(kind)]
		if kind == "warden":
			words += ". The Warden here is dead." if wardens.has(int(point.depth)) else ". A Warden held the way down."
		_spots.append({"at": at, "radius": 12.0, "text": words})

func _draw_loose_offers() -> void:
	## A run from before the way was charted: the offers, spread across the rock.
	var offers: Array = _offers()
	var from := Vector2(_x(_trail_lane(int(run.depth))), _y(float(run.depth)))
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var at := Vector2(_x((float(index) + 0.5) / float(offers.size())), _y(float(run.depth) + 1.0))
		var kind: String = "hidden" if bool(offer.get("hidden", false)) else str(offer.get("kind", "fight"))
		_stroke(_curve(from, at), Color(DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.MUTED), 0.7), 2.5)
		_medallion(at, 17.0, kind, 1.0)
		_spots.append({"at": at, "radius": 17.0, "text": "Take this tunnel", "offer": str(offer.id)})
	_draw_party(from)

func _stretch_ways(map: Dictionary, positions: Dictionary, facts: Dictionary) -> void:
	var nodes: Dictionary = map.get("nodes", {})
	var here: String = facts.here
	var visited: Dictionary = facts.visited
	var ahead: Dictionary = facts.ahead
	var lit_way: Dictionary = facts.lit_way
	var picked: String = facts.picked
	## The ways between chambers.
	var sources: Array = ["head"]
	sources.append_array(nodes.keys())
	for id in sources:
		var children: Array = DeepDescent.row_of(map, int(map.from) + 1) if id == "head" else nodes[id].next
		var a: Vector2 = positions[id]
		for child in children:
			var b: Vector2 = positions.get(str(child), Vector2.ZERO)
			var line: PackedVector2Array = _curve(a, b)
			var from_here: bool = (id == "head" and here.is_empty()) or id == here
			var taken: bool = visited.has(str(child)) and (id == "head" or visited.has(str(id)))
			if taken:
				_stroke(line, Color(DeepUi.ACCENT, 0.8), 3.5)
			elif from_here and bool(facts.choosing):
				var node: Dictionary = nodes.get(str(child), {})
				var kind: String = str(node.kind) if DeepDescent.revealed(run, node) else "hidden"
				var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.PAPER)
				var hot: bool = picked == str(child)
				_stroke(line, Color(tone, 0.95 if hot else 0.7), 4.0 if hot else 3.0)
				_flows.append({"line": line, "tone": tone.lightened(0.4), "offset": float(str(child).hash() % 97) / 97.0})
			elif ahead.has(str(id)) and ahead.has(str(child)):
				var on_way: bool = lit_way.has(str(id)) and lit_way.has(str(child))
				_stroke(line, Color(DeepUi.ACCENT, 0.7) if on_way else Color(DeepUi.LINE_HI, 0.45 if lit_way.is_empty() else 0.22), 2.4 if on_way else 1.8)
			else:
				_stroke(line, Color(DeepUi.LINE_HI, 0.1), 1.4)
	## The shaft goes on below the landing, to landings no one has charted yet.
	var landing_at: Vector2 = positions.landing
	var below_y: float = _y(float(int(map.to) + DeepDescent.landing_every()))
	var dash: float = landing_at.y + 22.0
	while dash < below_y - 16.0:
		var dash_end: float = minf(dash + 6.0, below_y - 16.0)
		_canvas.draw_line(Vector2(landing_at.x, dash), Vector2(landing_at.x, dash_end), Color(DeepUi.LINE_HI, 0.5 * _fade(dash)), 2.0)
		dash += 12.0
	## Fog past the lantern's reach.
	if not bool(map.get("lit", false)):
		var fog_top: float = _fog_top()
		var fog_full: float = fog_top + _step * 0.7
		if fog_top < _bottom():
			var shade := Color(0.02, 0.025, 0.035)
			var poly := PackedVector2Array([Vector2(1, fog_top), Vector2(size.x - 1, fog_top), Vector2(size.x - 1, fog_full), Vector2(1, fog_full)])
			_canvas.draw_polygon(poly, PackedColorArray([Color(shade, 0.0), Color(shade, 0.0), Color(shade, 0.72), Color(shade, 0.72)]))
			if fog_full < size.y:
				_canvas.draw_rect(Rect2(Vector2(1, fog_full), Vector2(size.x - 2, size.y - fog_full - 1)), Color(shade, 0.72))

func _fog_top() -> float:
	return _y(float(int(run.get("depth", 0)) + DeepDescent.LANTERN_REACH) + 0.45)

func _stretch_chambers(map: Dictionary, positions: Dictionary, facts: Dictionary) -> void:
	var nodes: Dictionary = map.get("nodes", {})
	var here: String = facts.here
	var here_at: Vector2 = facts.here_at
	var visited: Dictionary = facts.visited
	var ahead: Dictionary = facts.ahead
	var lit_way: Dictionary = facts.lit_way
	var picked: String = facts.picked
	var choosing: bool = facts.choosing
	## The lantern's pool, reaching down toward what it can show.
	var flicker: float = 0.9 + 0.1 * sin(_clock * 7.0) * sin(_clock * 2.9 + 1.0)
	var reach: float = _step * (float(DeepDescent.LANTERN_REACH) + 0.6)
	_glow(here_at + Vector2(0, reach * 0.36), Vector2(size.x * 1.25, reach * 1.7) * flicker, Color(DeepUi.ACCENT, 0.1 * _fade(here_at.y)))
	## Sparks running down the ways the party can take.
	for flow in _flows:
		_flow(flow.line, flow.tone, float(flow.offset))
	## Wisps drifting through the fog.
	if not bool(map.get("lit", false)):
		var fog_top: float = _fog_top()
		for k in range(5):
			var drift: float = fmod(_clock * (8.0 + float(k) * 3.0) + float(k) * 97.0, size.x + 160.0) - 80.0
			var wisp_y: float = fog_top + _step * (0.5 + 0.35 * float(k))
			if wisp_y < _bottom():
				_glow(Vector2(drift, wisp_y), Vector2(170, 34), Color(0.55, 0.6, 0.7, 0.05 * _fade(wisp_y)))
	## The chambers.
	for id in nodes:
		if id == "landing":
			continue
		var node: Dictionary = nodes[id]
		var at: Vector2 = positions[id]
		if _fade(at.y) <= 0.0:
			continue
		var offered: bool = choosing and _is_offer(id)
		var strength: float = 1.0 if (offered or ahead.has(id) or visited.has(id) or id == here) else 0.28
		if not lit_way.is_empty() and ahead.has(id) and not lit_way.has(id) and not offered:
			strength = 0.55
		var seen: bool = DeepDescent.revealed(run, node) or visited.has(id)
		var words: String = ""
		if offered:
			at.y += sin(_clock * 2.4 + float(id.hash() % 13)) * 2.0
			var kind: String = str(node.kind) if seen else "hidden"
			var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.MUTED)
			var mine: bool = str(DeepDescent.player(run, local_id).get("vote", "")) == id
			var hot: bool = picked == id
			var radius: float = 19.0 if hot else 17.0
			_glow(at, Vector2(70, 70) * (1.15 if hot else 1.0), Color(tone, (0.4 if hot else 0.24) * _fade(at.y)))
			_medallion(at, radius, kind, 1.0, DeepUi.ACCENT if mine else Color(0, 0, 0, 0))
			if mine:
				_canvas.draw_arc(at, radius + 4.0, 0, TAU, 36, Color(DeepUi.ACCENT, 0.9 * _fade(at.y)), 2.0, true)
			_draw_voters(id, at, radius)
			words = "Depth %d: %s. Click to take this tunnel." % [int(node.depth), _kind_words(kind)]
			_spots.append({"at": at, "radius": radius, "text": words, "offer": id})
			continue
		if seen:
			_medallion(at, 14.0 if id != here else 15.0, str(node.kind), strength)
			words = "Depth %d: %s" % [int(node.depth), _kind_words(str(node.kind))]
		else:
			_draw_glint(at, DeepDescent.glint(node), strength)
			words = "Depth %d: %s" % [int(node.depth), str(GLINT_WORDS.get(DeepDescent.glint(node), ""))]
		if not ahead.has(id) and not visited.has(id) and id != here:
			words += " (out of reach now)"
		_spots.append({"at": at, "radius": 14.0, "text": words})
	_draw_landing(map, positions.landing, ahead.has("landing") or here.is_empty())
	_draw_party(here_at)

func _kind_words(kind: String) -> String:
	match kind:
		"fight": return "a fight"
		"elite": return "an elite: a harder fight, a better stone"
		"vein": return "an ore vein to strike"
		"motherlode": return "a motherlode: stones for everyone"
		"oddity": return "an oddity"
		"hidden": return "a dark mouth: anything could be down there"
		"landing": return "a landing"
	return kind

func _draw_glint(at: Vector2, glint: String, strength: float) -> void:
	var tone: Color = GLINT_TONES.get(glint, DeepUi.MUTED)
	var fade: float = _fade(at.y) * strength
	var twinkle: float = 0.5 + 0.5 * sin(_clock * (2.2 + float(int(at.x) % 5) * 0.4) + at.x * 0.13)
	_canvas.draw_circle(at, 10.0, Color(0.03, 0.035, 0.05, 0.9 * fade))
	_canvas.draw_arc(at, 10.0, 0, TAU, 24, Color(tone, 0.28 * fade), 1.5, true)
	if glint == "dark":
		_glyph("question", at, 11.0, Color(tone, 0.5 * fade))
		return
	_glow(at, Vector2(34, 34), Color(tone, 0.22 * twinkle * fade))
	_glyph(str(GLINT_GLYPHS.get(glint, "question")), at, 12.0, Color(tone, (0.35 + 0.45 * twinkle) * fade))
	if glint == "glittering" and twinkle > 0.8:
		var spark: Vector2 = at + Vector2(7, -7)
		var arm: float = 5.0 * (twinkle - 0.8) / 0.2
		_canvas.draw_line(spark - Vector2(arm, 0), spark + Vector2(arm, 0), Color(1, 0.95, 0.8, fade), 1.2, true)
		_canvas.draw_line(spark - Vector2(0, arm), spark + Vector2(0, arm), Color(1, 0.95, 0.8, fade), 1.2, true)

func _draw_voters(id: String, at: Vector2, radius: float) -> void:
	var seat: int = 0
	var count: int = 0
	for other in run.get("players", []):
		if str(other.get("vote", "")) == id and str(other.id) != local_id:
			var dot: Vector2 = at + Vector2(radius + 8.0, -radius * 0.6 + float(count) * 9.0)
			_canvas.draw_circle(dot, 3.5, Color(SEATS[seat % SEATS.size()], _fade(at.y)))
			count += 1
		seat += 1

func _draw_landing(map: Dictionary, at: Vector2, reachable: bool) -> void:
	var fade: float = _fade(at.y)
	var landing: int = int(map.get("to", 0))
	var warden: bool = DeepDescent.is_warden_depth(landing)
	var kind: String = "warden" if warden else "landing"
	var tone: Color = DeepUi.CHAMBER_COLOURS.get(kind, DeepUi.ACCENT)
	var every: int = DeepDescent.landing_every()
	var below: Vector2 = Vector2(at.x, _y(float(landing + every)))
	if _fade(below.y) > 0.0:
		var later: bool = DeepDescent.is_warden_depth(landing + every)
		_canvas.draw_circle(below, 11.0, Color(0.04, 0.05, 0.07, 0.9 * _fade(below.y)))
		_canvas.draw_arc(below, 11.0, 0, TAU, 24, Color(DeepUi.CHAMBER_COLOURS.get("warden" if later else "landing", DeepUi.MUTED), 0.4 * _fade(below.y)), 1.5, true)
		_glyph("crown" if later else "lift", below, 12.0, Color(DeepUi.MUTED, 0.6 * _fade(below.y)))
		_spots.append({"at": below, "radius": 11.0, "text": "Depth %d: %s" % [landing + every, "a Warden's gate" if later else "the landing after"]})
	if fade <= 0.0:
		return
	if warden:
		var threat: float = 64.0 + 10.0 * sin(_clock * 2.0)
		_glow(at, Vector2(threat, threat), Color(tone, 0.3 * fade))
	_canvas.draw_circle(at, 19.0, Color(tone.darkened(0.65), 0.97 * fade))
	_canvas.draw_arc(at, 19.0, 0, TAU, 36, Color(tone, (0.95 if reachable else 0.5) * fade), 2.5, true)
	_glyph("crown" if warden else "lift", at, 21.0, Color(tone.lightened(0.3), fade))
	_canvas.draw_string(DeepUi.display_font(), at + Vector2(26, 5), "WARDEN" if warden else "LANDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tone, 0.85 * fade))
	var words: String = "Depth %d: a landing with a lift, a lapidary and a merchant." % landing
	if warden:
		words += " A Warden guards the way down."
	var spot: Dictionary = {"at": at, "radius": 19.0, "text": words}
	if _is_offer("landing"):
		## The last step of a stretch: the landing itself is the way on.
		spot.offer = "landing"
		spot.text = words + " Click to go down to it."
		var pulse: float = 1.0 + 0.08 * sin(_clock * 3.0)
		_canvas.draw_arc(at, 24.0 * pulse, 0, TAU, 40, Color(tone, 0.8 * fade), 2.0, true)
	_spots.append(spot)

func _draw_party(at: Vector2) -> void:
	## Where the party stands: a lantern's glow and a slow pulse.
	var fade: float = _fade(at.y)
	if fade <= 0.0:
		return
	var pulse: float = 1.0 + 0.1 * sin(_clock * 3.0)
	var flicker: float = 0.85 + 0.15 * sin(_clock * 9.0) * sin(_clock * 4.3)
	_glow(at, Vector2(96, 96) * pulse, Color(DeepUi.ACCENT, 0.4 * fade * flicker))
	_canvas.draw_arc(at, 20.0 * pulse, 0, TAU, 40, Color(DeepUi.ACCENT, 0.9 * fade), 2.0, true)
	var lamp: Vector2 = at + Vector2(0, -30) + Vector2(sin(_clock * 1.3) * 1.5, 0)
	_canvas.draw_line(lamp + Vector2(0, -12), lamp + Vector2(0, -7), Color(DeepUi.MUTED, fade), 1.0)
	_glyph("lantern", lamp, 15.0, Color(DeepUi.ACCENT.lightened(0.2), fade * flicker))
	_spots.append({"at": at, "radius": 16.0, "text": "The party is here."})
