extends Control
## The lantern map: the way down as the party knows it.
##
## Above the party, the trail it walked, one mark per depth. Below it, the current floor and
## two floors ahead, drawn from the larger chart held by the sim. The ways from the party's
## chamber are live and can be clicked to vote. The lantern reveals hidden mouths on the next
## floor for ore; deeper chambers stay off the chart until the party reaches them.

signal vote(offer_id: String)
signal light

const GemIcons = preload("res://view/gems/gem_icons.gd")
const WardenPlate = preload("res://view/run/warden_plate.gd")
const Plates = preload("res://view/ui/plates.gd")
const Tips = preload("res://view/ui/tips.gd")
const Biomes = preload("res://view/battle/biomes.gd")

const STEP := 84.0
const NODE := 16.0
const GUTTER := 38.0
const TOP := 66.0
const FOOT := 58.0
## A Warden's hall is its own mark, this far below its landing: the party comes to the landing
## first, and the hall stands between it and the way on down.
const HALL := 0.5
const SEATS: Array = [Color("f0b44c"), Color("5fb8ff"), Color("6fdc8c"), Color("e07ad6")]
const GLINT_GLYPHS: Dictionary = {"hostile": "eye", "glittering": "star", "strange": "swirl", "dark": "question"}
## The plate a panel lying along one side of the run's screen wears: the chart on the left and
## the bag column on the right (run_dock.gd) share it (the owner, November 6, 2026): the Ledger
## plate (opaque, a 3 px border in dim gold, corners cut straight across) with its shadow
## thrown toward the room, `toward` -1 for a panel on the right edge, 1 for one on the left.
## `pad` is the room inside it, for a container that holds its content in it. `shadow` false
## leaves the shadow off, for a panel that clips what it draws to its own rect (the chart):
## clipped, a shadow only shows as dark smudges in the cut corners.
const SIDE_LINE := DeepUi.ACCENT_DIM
const SIDE_CUT: int = 14
const SIDE_BORDER: int = 3

static func side_plate(toward: float, pad: int = 12, shadow: bool = true) -> StyleBoxFlat:
	var plate: StyleBoxFlat = DeepUi.ledger(DeepUi.LEDGER_FILL, SIDE_LINE, SIDE_CUT, pad, SIDE_BORDER, 5)
	plate.shadow_color = Color(DeepUi.LEDGER_SHADOW, 0.6)
	plate.shadow_size = 14 if shadow else 0
	plate.shadow_offset = Vector2(5.0 * signf(toward), 2.0)
	return plate

const GLINT_TONES: Dictionary = {"hostile": Color("ff5a4a"), "glittering": Color("ffd257"), "strange": Color("b58cff"), "dark": Color("6d7688")}
const GLINT_WORDS: Dictionary = {
	"hostile": "Something's moving down there.",
	"glittering": "Something glitters down there.",
	"strange": "Something strange waits down there.",
	"dark": "A dark tunnel. Light the way to see what's there.",
}

var run: Dictionary = {}:
	set(value):
		run = value
		_run_serial += 1
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
## A press on the map, where it began and the nudge then, so a drag scrolls from there.
var _drag_from: Vector2 = Vector2(-1.0, -1.0)
var _drag_nudge: float = 0.0
var _dragged: bool = false
## How far a press may move, in pixels, and still be a click on a mouth.
const DRAG_SLIP: float = 8.0
var _step: float = STEP
var _clock: float = 0.0
var _lamp: Button
## Zoomed out (the owner, November 17, 2026): every mine as a band down the shaft, the run's
## way through them lit and the party's lantern where it stands, instead of the stretch.
var zoomed: bool = false
var _zoom: Button
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
## The chart as last laid out (`_layout`): where each chamber sits, what the party can reach
## from where it stands, and what each chamber draws and says. Worked out again only when the
## run, the view or the pointer moves; the live layer only animates what is already placed.
var _run_serial: int = 0
var _layout_key: Array = []
var _laid: Dictionary = {}
## Over the hall of the Warden (or the final boss) the stretch ends at: pointing at it, or a
## finger held on it, brings up its name, face and two signature moves (review card W2).
var _hall_hot: Control
## Where the hall was drawn last frame and how deep it stands, or a depth of -1 for none.
var _hall_drawn: Dictionary = {"depth": -1}
## The header's line naming the Warden ahead ("The Foreman · depth 8"), there from the
## stretch's first floor even while its hall is still below the chart's edge, and its hot spot.
var _head_hot: Control
var _head_drawn: Dictionary = {"depth": -1}
## The Warden's baked faces, by creature key, read once.
var _faces: Dictionary = {}

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
	## The zoom key, in the header's top right: every mine, or back to this stretch.
	_zoom = DeepUi.icon_button(self, "map", "All mines", toggle_zoom, 11 if DeepUi.phone else 12, DeepUi.ACCENT)
	_zoom.name = "Zoom"
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	_zoom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_zoom.mouse_filter = Control.MOUSE_FILTER_STOP
	DeepUi.ledger_button(_zoom, DeepUi.SLATE_HI, DeepUi.ACCENT_DIM, 6)
	Tips.attach(_zoom, func() -> Control: return Plates.words("This stretch" if zoomed else "All mines",
		"Back to the stretch you are in, and the ways on from here." if zoomed else "Zoom out: every mine down the shaft, the way the party came and where it stands now.", "lantern" if zoomed else "map", DeepUi.ACCENT))
	_hall_hot = Control.new()
	_hall_hot.name = "WardenHot"
	_hall_hot.visible = false
	_hall_hot.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_hall_hot)
	Tips.attach(_hall_hot, func() -> Control: return _warden_plate(int(_hall_drawn.get("depth", -1))), {"tone": DeepUi.CHAMBER_colorS.warden})
	_head_hot = Control.new()
	_head_hot.name = "WardenLineHot"
	_head_hot.visible = false
	_head_hot.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_head_hot)
	Tips.attach(_head_hot, func() -> Control: return _warden_plate(int(_head_drawn.get("depth", -1))), {"tone": DeepUi.CHAMBER_colorS.warden, "below": true})

func show_run(state: Dictionary) -> void:
	var first: bool = run.is_empty()
	if first and zoomed:
		## A new run opens on its own stretch.
		zoomed = false
	run = state
	_sync_zoom()
	## Keep the party and the next floor in view; the older trail stays above when scrolled back.
	var goal: float = float(run.get("depth", 0))
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

func toggle_zoom() -> void:
	## Out to every mine, or back in to the stretch the party stands in.
	zoomed = not zoomed
	_hover = ""
	_nudge = 0.0
	DeepAudio.play("ui_open" if zoomed else "ui_close", {"volume": 0.6})
	_sync_zoom()
	_sync_lamp()
	_mark()
	queue_redraw()

func _sync_zoom() -> void:
	if _zoom == null:
		return
	_zoom.text = "This stretch" if zoomed else "All mines"
	_zoom.icon = GemIcons.texture("lantern" if zoomed else "map", GemIcons.baked_size(18.0))
	## On the phone the chart is drawn larger (descent_screen.gd CHART_SCALE): the key is sized
	## in the chart's own pixels so it is a finger's height once drawn.
	if DeepUi.phone:
		_zoom.custom_minimum_size.y = DeepUi.pt(DeepUi.FINGER_LEAST) / maxf(1.0, scale.y)
	_zoom.visible = not run.is_empty()

func _sync_lamp() -> void:
	var map: Dictionary = run.get("map", {})
	var phase: String = str(run.get("phase", ""))
	var target_depth: int = mini(int(run.get("depth", 0)) + 1, int(map.get("to", 0)))
	var open: bool = not map.is_empty() and phase in ["tunnels", "landing"] and DeepDescent.needs_light(run) and not zoomed
	_lamp.visible = open
	if not open:
		return
	var unit: Dictionary = DeepDescent.player(run, local_id)
	var cost: int = DeepDescent.lantern_cost()
	_lamp.text = "Light the way  ·  %d pyrite" % cost
	_lamp.disabled = int(unit.get("ore", 0)) < cost
	_lamp.tooltip_text = "Reveal every chamber on the next floor at depth %d, including dark mouths. Costs %d pyrite." % [target_depth, cost]

func _process(delta: float) -> void:
	_clock += delta
	if is_visible_in_tree():
		queue_redraw()
		if not _painted.is_equal_approx(Vector2(_shown, _nudge)):
			_mark()
	_place_hall_hot()

func _place_hall_hot() -> void:
	## The hall's hot spot follows the hall as the chart scrolls; it goes with it.
	if _hall_hot == null:
		return
	var depth: int = int(_hall_drawn.get("depth", -1))
	var at: Vector2 = _hall_drawn.get("at", Vector2.ZERO)
	var shown: bool = depth > 0 and is_visible_in_tree() and _fade(at.y) > 0.3
	if shown:
		var edge: float = 40.0
		_hall_hot.size = Vector2(edge, edge)
		_hall_hot.position = at - Vector2(edge, edge) * 0.5
	if _hall_hot.visible != shown:
		_hall_hot.visible = shown
	var line: bool = int(_head_drawn.get("depth", -1)) > 0 and is_visible_in_tree()
	if line:
		var rect: Rect2 = _head_drawn.get("rect", Rect2())
		_head_hot.position = rect.position
		_head_hot.size = rect.size
	if _head_hot.visible != line:
		_head_hot.visible = line

func _warden_ahead() -> int:
	## The depth of the Warden (or the final boss) the party is to meet next on this stretch:
	## the hall under the landing it stands at, or the one under the landing it ends at. -1 for none.
	var map: Dictionary = _map()
	if map.is_empty():
		return -1
	var from: int = int(map.get("from", 0))
	if from > 0 and DeepDescent.run_is_warden(run, from) and not _hall_beaten(from):
		return from
	var to: int = int(map.get("to", 0))
	if to > 0 and DeepDescent.run_is_warden(run, to) and not _hall_beaten(to):
		return to
	return -1

func _warden_plate(depth: int) -> Control:
	## The Warden's plate: its face, its name, what it guards, its two signature moves.
	if depth <= 0 or run.is_empty():
		return null
	var key: String = DeepDescent.warden_key(run, depth)
	if key.is_empty():
		return null
	var plate: Control = Plates.plate(300.0)
	WardenPlate.fill(plate, key, run, depth, 276.0)
	if _hall_beaten(depth):
		DeepUi.label(plate, "Beaten.", 12, DeepUi.GOOD)
	return plate

func _warden_face(key: String) -> Texture2D:
	if not _faces.has(key):
		_faces[key] = WardenPlate.portrait(key) if DisplayServer.get_name() != "headless" else null
	return _faces[key]

# --- layout -----------------------------------------------------------------------------------

func _bottom() -> float:
	return size.y - (FOOT if _lamp != null and _lamp.visible else 16.0)

func _centre_y() -> float:
	## The head of the stretch sits high in the panel: the map is mostly about what lies ahead.
	return TOP + 58.0

func _fit_step() -> void:
	## Fit the current floor and one below it in the chart.
	_step = clampf((_bottom() - _centre_y() - 20.0) / 1.55, 62.0, 124.0)

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
	## The ways on that can be taken from the chart: the tunnels offered, or at a landing's
	## crossroads its ways down (a Warden landing's one way is into its hall). A landing's
	## mouths are chosen from the chart as they are in the room (the owner, November 17, 2026:
	## clicking the chart at a landing did nothing).
	var phase: String = str(run.get("phase", ""))
	if phase == "tunnels":
		return run.get("offers", [])
	if phase != "landing" or not DeepDescent.at_crossroads(run) or DeepDescent.in_boss_hall(run):
		return []
	var landing: Dictionary = run.get("landing", {})
	if bool(landing.get("warden_next", false)) and not bool(landing.get("cleared", false)):
		return [ {"id": "warden", "kind": "warden", "hidden": false}]
	var map: Dictionary = _map()
	if map.is_empty() or int(map.get("from", -1)) != int(run.get("depth", 0)):
		return []
	var out: Array = []
	for id in DeepDescent.row_of(map, int(run.get("depth", 0)) + 1):
		var node: Dictionary = map.get("nodes", {}).get(str(id), {})
		if not node.is_empty():
			out.append({"id": str(id), "kind": str(node.get("kind", "fight")), "hidden": bool(node.get("hidden", false))})
	return out

func _voted(unit: Dictionary) -> String:
	## The way a player has picked, as the chart marks it: their vote at the tunnels, or at a
	## landing the mouth they chose to go down by (the only one, when there is one).
	if str(run.get("phase", "")) != "landing":
		return str(unit.get("vote", ""))
	if str(unit.get("choice", "")) != "descend":
		return ""
	var via: String = str(unit.get("via", ""))
	var offers: Array = _offers()
	if via.is_empty() and offers.size() == 1:
		return str(offers[0].id)
	return via

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
	## The Warden's hall below the landing the stretch starts from, and below the one it ends at.
	if int(map.get("from", 0)) > 0 and DeepDescent.run_is_warden(run, int(map.get("from", 0))):
		out["hall"] = out.head + Vector2(0, HALL * _step)
	if out.has("landing") and DeepDescent.run_is_warden(run, int(map.get("to", 0))):
		out["hall_below"] = out.landing + Vector2(0, HALL * _step)
	return out

func _hall_beaten(depth: int) -> bool:
	return DeepPatch.holds(run.get("records", {}).get("wardens", []), depth)

func _in_hall() -> bool:
	## The party has gone on from the landing into its Warden's hall: fighting there, or past
	## it with the Warden dead.
	var from: int = int(_map().get("from", 0))
	if from <= 0 or int(run.get("depth", 0)) != from or not _here().is_empty() or not DeepDescent.run_is_warden(run, from):
		return false
	return _hall_beaten(from) or str(run.get("phase", "")) == "chamber"

func _hall_words(depth: int) -> String:
	var boss: bool = DeepDescent.run_is_boss(run, depth)
	var key: String = DeepDescent.warden_key(run, depth)
	var words: String = "Depth %d: %s, past the landing." % [depth, "the final boss's hall" if boss else "a Warden's hall"]
	if not key.is_empty():
		words += " " + WardenPlate.short_line(key) + "."
	if _hall_beaten(depth):
		return words + (" The boss is dead." if boss else " Its Warden is dead.")
	return words + (" The boss guards the bottom of the mine." if boss else " Its Warden guards the way on down.")

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

func _offer_at(at: Vector2) -> String:
	## The way on under a click or a tap: the nearest offered chamber whose ring (and a finger's
	## room round it, wider on the phone) the point is in. Only the offers are looked at, so a
	## chamber's or the party's hover spot beside one never takes the click from it.
	if zoomed:
		return ""
	var reach: float = (DeepUi.pt(12) / maxf(1.0, scale.x)) if DeepUi.phone else 8.0
	var best: String = ""
	var best_distance: float = INF
	for spot in _live_spots + _static_spots:
		if str(spot.get("offer", "")).is_empty():
			continue
		var distance: float = at.distance_to(spot.at)
		if distance <= float(spot.radius) + reach and distance < best_distance:
			best = str(spot.offer)
			best_distance = distance
	return best

func _slip() -> float:
	## How far a press may move and still be a click: a finger wanders further than a mouse.
	return (DeepUi.pt(10) / maxf(1.0, scale.x)) if DeepUi.phone else DRAG_SLIP

func _get_tooltip(at_position: Vector2) -> String:
	return str(_spot_at(at_position).get("text", ""))

func _gui_input(event: InputEvent) -> void:
	if zoomed:
		## Every mine fits the panel: nothing to scroll, nothing to choose.
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		## The wheel looks back up the trail, or further down the shaft.
		var way: float = -0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5
		_nudge = clampf(_nudge + way, -_shown, 3.0)
		_mark()
		accept_event()
		return
	if event is InputEventMouseMotion:
		if _drag_from.x >= 0.0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			## Dragged up or down (a finger, or the mouse held): the map scrolls with it.
			var pulled: float = (event.position.y - _drag_from.y) / maxf(1.0, _step)
			if absf(event.position.y - _drag_from.y) > _slip():
				_dragged = true
			if _dragged:
				_nudge = clampf(_drag_nudge - pulled, -_shown, 3.0)
				_mark()
			accept_event()
			return
		var hovered: String = _offer_at(event.position)
		if hovered != _hover:
			_hover = hovered
			_mark()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _hover.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position
			_drag_nudge = _nudge
			_dragged = false
			if not _offer_at(event.position).is_empty():
				accept_event()
			return
		## The vote is cast on the release, so a drag that began on a mouth is only a drag.
		var was_drag: bool = _dragged
		_drag_from = Vector2(-1.0, -1.0)
		_dragged = false
		if was_drag:
			accept_event()
			return
		var offer: String = _offer_at(event.position)
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
	var colors := PackedColorArray()
	for point in points:
		colors.append(Color(tint, tint.a * _fade(point.y)))
	_canvas.draw_polyline_colors(points, colors, width, true)

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
	## The bag column's plate (`side_plate`): the two side panels read as one pair. The chart
	## clips what it draws to its own rect, so it wears the plate without its shadow.
	_canvas.draw_style_box(side_plate(1.0, 12, false), Rect2(Vector2.ZERO, size))
	if run.is_empty():
		return
	if zoomed:
		_paint_mines()
		return
	_fit_step()
	var map: Dictionary = _map()
	var laid: Dictionary = _layout(map)
	var positions: Dictionary = laid.positions
	_draw_depths()
	_draw_trail(positions)
	if not map.is_empty():
		_stretch_ways(map, positions, laid.facts)

func _draw() -> void:
	## The live layer, every frame.
	_canvas = self
	_live_spots.clear()
	_spots = _live_spots
	_hall_drawn = {"depth": -1}
	if run.is_empty():
		return
	if zoomed:
		_head_drawn = {"depth": -1}
		_draw_mines_live()
		_draw_header({}, int(run.get("depth", 0)))
		return
	_fit_step()
	var map: Dictionary = _map()
	if map.is_empty():
		_draw_loose_offers()
	else:
		var laid: Dictionary = _layout(map)
		_stretch_chambers(map, laid.positions, laid.facts, laid.chambers)
	_draw_header(map, int(run.get("depth", 0)))

func _layout(map: Dictionary) -> Dictionary:
	## {positions, facts, chambers}, kept while nothing they are worked out from has changed.
	var key: Array = [_run_serial, _shown, _nudge, size, _step, _hover, focus, local_id]
	if key != _layout_key:
		var positions: Dictionary = _positions()
		var facts: Dictionary = {} if map.is_empty() else _facts(map, positions)
		_laid = {"positions": positions, "facts": facts, "chambers": [] if map.is_empty() else _plan_chambers(map, positions, facts)}
		_layout_key = key
	return _laid

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
	var start: Vector2 = positions.hall if _in_hall() else positions.head
	return {"here": here, "here_at": positions.get(here, start) if not here.is_empty() else start, "visited": visited,
		"ways": ways, "ahead": _ahead_of(ways), "picked": picked,
		"lit_way": _ahead_of([picked]) if not picked.is_empty() and nodes.has(picked) else {},
		"choosing": not _offers().is_empty() and not _is_offer("warden")}

func _text(points: int) -> int:
	## A reading size for the chart: the screen's, less what the phone's scale on the chart adds
	## (descent_screen.gd CHART_SCALE).
	return maxi(8, int(round(float(DeepUi.readable(points)) / maxf(1.0, scale.x))))

func _caps(points: int) -> int:
	return maxi(8, int(round(float(DeepUi.caps_size(points)) / maxf(1.0, scale.x))))

func _draw_header(map: Dictionary, depth: int) -> void:
	var font: Font = DeepUi.caps_font()
	var key_w: float = _zoom.size.x + 16.0 if _zoom != null and _zoom.visible else 0.0
	_canvas.draw_string(font, Vector2(18, 28), "EVERY MINE" if zoomed else "THE WAY DOWN", HORIZONTAL_ALIGNMENT_LEFT, maxf(60.0, size.x - 30.0 - key_w), 14, DeepUi.ACCENT)
	var mine_name: String = str(DeepContent.mine(str(run.get("mine", ""))).get("name", ""))
	var small: int = _text(12)
	_canvas.draw_string(DeepUi.text_face(small), Vector2(18, 46), ("The whole shaft" if zoomed else mine_name), HORIZONTAL_ALIGNMENT_LEFT, maxf(60.0, size.x - 30.0 - key_w), small, DeepUi.MUTED)
	if map.is_empty() or zoomed:
		return
	var lit: bool = DeepDescent.lit_to(run) >= mini(depth + 1, int(map.to))
	var words: String = "lit to %d" % DeepDescent.lit_to(run) if lit else "sees to %d" % mini(depth + DeepDescent.lantern_reach(run), int(map.to))
	var tone: Color = DeepUi.ACCENT if lit else DeepUi.MUTED
	var width: float = DeepUi.text_face(small).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var flicker: float = 0.85 + 0.15 * sin(_clock * 9.0) * sin(_clock * 4.3)
	## Under the zoom key in the top right corner.
	var lamp_y: float = maxf(46.0, (_zoom.position.y + _zoom.size.y + 14.0) if _zoom != null and _zoom.visible else 46.0)
	_glyph("lantern", Vector2(size.x - width - 32, lamp_y - 6.0), 16.0, Color(DeepUi.ACCENT, flicker))
	_canvas.draw_string(DeepUi.text_face(small), Vector2(size.x - width - 18, lamp_y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, small, tone)
	_spots.append({"at": Vector2(size.x - width * 0.5 - 24, lamp_y - 6.0), "radius": 14.0,
		"text": "The next floor is lit, including its dark mouths." if lit else "Your lantern shows two floors ahead."})
	## The Warden this stretch leads to, named from its first floor (review card W2).
	var ahead: int = _warden_ahead()
	_head_drawn = {"depth": -1}
	if ahead > 0:
		var key: String = DeepDescent.warden_key(run, ahead)
		var guard: String = str(DeepContent.creature(key).get("name", "")) if not key.is_empty() else ""
		if not guard.is_empty():
			var said: String = "%s · depth %d" % [guard, ahead]
			var tone_w: Color = DeepUi.CHAMBER_colorS.warden
			_glyph("crown", Vector2(26, 62), 14.0, tone_w)
			_canvas.draw_string(DeepUi.text_face(small), Vector2(38, 67), said, HORIZONTAL_ALIGNMENT_LEFT, size.x - 56, small, tone_w.lightened(0.2))
			var said_w: float = minf(size.x - 56, DeepUi.text_face(small).get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
			_head_drawn = {"depth": ahead, "rect": Rect2(Vector2(16, 52), Vector2(said_w + 28, 22))}

func _draw_depths() -> void:
	## Depth numbers down the gutter, and a faint rule across the rock at each.
	var first: int = maxi(0, int(floor(_shown + _nudge - (_centre_y() - TOP) / _step)) - 1)
	var last: int = int(ceil(_shown + _nudge + (_bottom() - _centre_y()) / _step)) + 1
	var depth: int = int(run.get("depth", 0))
	var bottom: int = DeepDescent.bottom_of(run)
	for d in range(first, last + 1):
		var y: float = _y(float(d))
		var fade: float = _fade(y)
		if fade <= 0.0:
			continue
		var tone: Color = DeepUi.PAPER if d == depth else DeepUi.DIM
		_canvas.draw_string(DeepUi.text_face(_text(12)), Vector2(8, y + 5), str(d) if d > 0 else "", HORIZONTAL_ALIGNMENT_CENTER, 24, _text(12), Color(tone, fade))
		_canvas.draw_line(Vector2(GUTTER - 4, y), Vector2(size.x - 12, y), Color(DeepUi.LINE, 0.18 * fade), 1.0)
		if bottom > 0 and d == bottom + 1:
			var below: String = DeepDescent.next_mine(run)
			## Low under the last floor, clear of the boss's hall halfway down to it.
			var words: String = ("%s BELOW" % DeepContent.mine_name(below).to_upper()) if not below.is_empty() else "THE BOTTOM"
			var tint: Color = Color(str(DeepContent.mine(below).get("palette", "b58cff"))) if not below.is_empty() else DeepUi.DIM
			_canvas.draw_string(DeepUi.caps_font(), Vector2(GUTTER, y - _step * 0.22 + 4), words, HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(11), Color(tint, fade))

func _medallion(at: Vector2, radius: float, kind: String, strength: float, ring: Color = Color(0, 0, 0, 0), mark: String = "") -> void:
	## A chamber drawn in its kind's color, wearing its kind's mark unless `mark` says otherwise.
	var tone: Color = DeepUi.CHAMBER_colorS.get(kind, DeepUi.MUTED)
	var fade: float = _fade(at.y) * strength
	_canvas.draw_circle(at, radius, Color(tone.darkened(0.62), 0.96 * fade))
	_canvas.draw_arc(at, radius, 0, TAU, 32, Color(ring if ring.a > 0.0 else tone, 0.95 * fade), 2.0, true)
	## A dark mouth wears the "?" its tunnel shows in the room, not an arch (review card X15).
	var glyph: String = mark if not mark.is_empty() else ("question" if kind == "hidden" else str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch")))
	_glyph(glyph, at, radius * 1.12, Color(tone.lightened(0.35), fade))

func _face(kind: String, oddity: String, entered: bool) -> Dictionary:
	## How a chamber is drawn: {tone (the kind whose color it takes), mark, words}. An oddity
	## the party has been into shows its own card's mark, still in the oddity's violet, so the
	## chart says what it was and that it was a surprise.
	if entered and kind == "oddity" and not oddity.is_empty():
		return {"tone": "oddity", "mark": str(DeepUi.ODDITY_GLYPHS.get(oddity, "swirl")),
			"words": "%s, an oddity" % str(DeepContent.oddity(oddity).get("name", "something odd"))}
	return {"tone": kind, "mark": "question" if kind == "hidden" else str(DeepUi.CHAMBER_GLYPHS.get(kind, "arch")), "words": _kind_words(kind)}

func _draw_trail(positions: Dictionary) -> void:
	## The way the party came, above the stretch it is in now.
	var from: int = int(_map().get("from", run.get("depth", 0)))
	var points: Array = [ {"at": Vector2(_x(0.5), _y(0.0)), "kind": "workshop", "depth": 0}]
	for entry in run.get("path", []):
		var d: int = int(entry.get("depth", 0))
		if d <= from:
			points.append({"at": Vector2(_x(float(entry.get("x", 0.5))), _y(float(d))), "kind": str(entry.get("kind", "fight")), "depth": d,
				"hidden": bool(entry.get("hidden", false)), "oddity": str(entry.get("oddity", ""))})
			if str(entry.get("kind", "")) == "landing" and DeepDescent.run_is_warden(run, d):
				points.append({"at": points.back().at + Vector2(0, HALL * _step), "kind": "hall", "depth": d})
	for i in range(points.size() - 1):
		## The way into a hall whose Warden still stands is not walked yet.
		var ahead: bool = str(points[i + 1].kind) == "hall" and not _hall_beaten(int(points[i + 1].depth))
		_stroke(_curve(points[i].at, points[i + 1].at), Color(DeepUi.CHAMBER_colorS.warden, 0.55) if ahead else Color(DeepUi.ACCENT, 0.7), 2.4 if ahead else 3.0)
	for point in points:
		var at: Vector2 = point.at
		if _fade(at.y) <= 0.0:
			continue
		if str(point.kind) == "workshop":
			_glyph("anvil", at, 22.0, Color(DeepUi.ACCENT, _fade(at.y)))
			var above: Array = run.get("mines_done", [])
			var said: String = "The workshop. The lift comes back here."
			if not above.is_empty():
				said = "The way down from %s. The lift still runs all the way up to the workshop." % DeepContent.mine_name(str(above.back().get("mine", "")))
			_spots.append({"at": at, "radius": 14.0, "text": said})
			continue
		var kind: String = str(point.kind)
		if kind == "hall":
			## A hall whose Warden still stands is drawn live, with the stretch below it.
			if _hall_beaten(int(point.depth)):
				_medallion(at, 12.0, "warden", 0.85)
				_spots.append({"at": at, "radius": 12.0, "text": _hall_words(int(point.depth))})
			continue
		var face: Dictionary = _face(kind, str(point.get("oddity", "")), true)
		_medallion(at, 12.0, str(face.tone), 0.85, Color(0, 0, 0, 0), str(face.mark))
		var words: String = "Depth %d: %s" % [int(point.depth), "a dark mouth, and then a fight" if bool(point.get("hidden", false)) and kind == "hidden" else str(face.words)]
		_spots.append({"at": at, "radius": 12.0, "text": words})

func _draw_loose_offers() -> void:
	## A run from before the way was charted: the offers, spread across the rock.
	var offers: Array = _offers()
	var from := Vector2(_x(_trail_lane(int(run.depth))), _y(float(run.depth)))
	for index in range(offers.size()):
		var offer: Dictionary = offers[index]
		var at := Vector2(_x((float(index) + 0.5) / float(offers.size())), _y(float(run.depth) + 1.0))
		var kind: String = "hidden" if bool(offer.get("hidden", false)) else str(offer.get("kind", "fight"))
		_stroke(_curve(from, at), Color(DeepUi.CHAMBER_colorS.get(kind, DeepUi.MUTED), 0.7), 2.5)
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
	## The ways between chambers, drawn as far as the lantern (or a lit stretch) shows.
	var visible_depth: int = mini(int(map.get("to", 0)), maxi(int(run.get("depth", 0)) + DeepDescent.lantern_reach(run), DeepDescent.lit_to(run)))
	## Every way is drawn, down to the landing: the ones past the lantern only as faint lines
	## between unknown chambers, so the shape of what is below can be read but not its rooms.
	var sources: Array = ["head"] if here.is_empty() else []
	for node_id in nodes:
		sources.append(node_id)
	for id in sources:
		var children: Array = DeepDescent.row_of(map, int(map.from) + 1) if id == "head" else nodes[id].next
		## Below a Warden's landing the ways down start from its hall.
		var a: Vector2 = positions.get("hall", positions.head) if id == "head" else positions[id]
		for child in children:
			var b: Vector2 = positions.get(str(child), Vector2.ZERO)
			var line: PackedVector2Array = _curve(a, b)
			var child_depth: int = int(map.get("to", 0)) if str(child) == "landing" else int(nodes.get(str(child), {}).get("depth", 0))
			if child_depth > visible_depth:
				_stroke(line, Color(DeepUi.LINE_HI, 0.16), 1.2)
				continue
			var from_here: bool = (id == "head" and here.is_empty()) or id == here
			var taken: bool = visited.has(str(child)) and (id == "head" or visited.has(str(id)))
			if taken:
				_stroke(line, Color(DeepUi.ACCENT, 0.8), 3.5)
			elif from_here and bool(facts.choosing):
				var node: Dictionary = nodes.get(str(child), {})
				var kind: String = str(node.kind) if DeepDescent.revealed(run, node) else "hidden"
				var tone: Color = DeepUi.CHAMBER_colorS.get(kind, DeepUi.PAPER)
				var hot: bool = picked == str(child)
				_stroke(line, Color(tone, 0.95 if hot else 0.7), 4.0 if hot else 3.0)
				_flows.append({"line": line, "tone": tone.lightened(0.4), "offset": float(str(child).hash() % 97) / 97.0})
			elif ahead.has(str(id)) and ahead.has(str(child)):
				var on_way: bool = lit_way.has(str(id)) and lit_way.has(str(child))
				_stroke(line, Color(DeepUi.ACCENT, 0.7) if on_way else Color(DeepUi.LINE_HI, 0.45 if lit_way.is_empty() else 0.22), 2.4 if on_way else 1.8)
			else:
				_stroke(line, Color(DeepUi.LINE_HI, 0.1), 1.4)
	## Fog below what the lantern shows: inside the plate's border and its cut corners, so the
	## border stands at full strength down to the foot and the corners stay cut (it was a
	## rectangle to the edge, which dimmed the border and filled the corners at the foot).
	if not bool(map.get("lit", false)):
		var fog_top: float = _fog_top()
		var fog_full: float = fog_top + _step * 0.7
		if fog_top < _bottom():
			var shade := Color(0.02, 0.025, 0.035)
			var rim: float = float(SIDE_BORDER)
			var cut: float = float(SIDE_CUT)
			var poly := PackedVector2Array([Vector2(rim, fog_top), Vector2(size.x - rim, fog_top), Vector2(size.x - rim, fog_full), Vector2(rim, fog_full)])
			_canvas.draw_polygon(poly, PackedColorArray([Color(shade, 0.0), Color(shade, 0.0), Color(shade, 0.72), Color(shade, 0.72)]))
			if fog_full < size.y - rim:
				## The inner edge of the border, its foot's corners cut as the plate's are.
				var low: float = maxf(fog_full, size.y - cut)
				var body := PackedVector2Array([Vector2(rim, fog_full), Vector2(size.x - rim, fog_full), Vector2(size.x - rim, low),
					Vector2(size.x - cut, size.y - rim), Vector2(cut, size.y - rim), Vector2(rim, low)])
				_canvas.draw_colored_polygon(body, Color(shade, 0.72))

func _fog_top() -> float:
	return _y(float(int(run.get("depth", 0)) + DeepDescent.lantern_reach(run)) + 0.45)

func _plan_chambers(map: Dictionary, positions: Dictionary, facts: Dictionary) -> Array:
	## What each chamber on the stretch draws and says, all but how it moves: one entry each,
	## with the hover spot it puts down (an offered chamber's spot bobs with it, so it has none).
	var out: Array = []
	var nodes: Dictionary = map.get("nodes", {})
	var here: String = facts.here
	var visited: Dictionary = facts.visited
	var ahead: Dictionary = facts.ahead
	var lit_way: Dictionary = facts.lit_way
	var picked: String = facts.picked
	var choosing: bool = facts.choosing
	var seen_to: int = mini(int(map.get("to", 0)), int(run.get("depth", 0)) + DeepDescent.lantern_reach(run))
	var my_vote: String = _voted(DeepDescent.player(run, local_id))
	for id in nodes:
		if id == "landing":
			continue
		var node: Dictionary = nodes[id]
		var at: Vector2 = positions[id]
		if _fade(at.y) <= 0.0:
			continue
		if int(node.get("depth", 0)) > seen_to:
			## Past the lantern: a chamber is there, and nothing more is known of it.
			out.append({"draw": "unknown", "at": at, "spot": {"at": at, "radius": 12.0, "text": "Depth %d: not seen yet. The lantern shows two floors ahead." % int(node.depth)}})
			continue
		var offered: bool = choosing and _is_offer(id)
		var strength: float = 1.0 if (offered or ahead.has(id) or visited.has(id) or id == here) else 0.28
		if not lit_way.is_empty() and ahead.has(id) and not lit_way.has(id) and not offered:
			strength = 0.55
		var seen: bool = DeepDescent.revealed(run, node) or visited.has(id)
		if offered:
			var kind: String = str(node.kind) if seen else "hidden"
			var hot: bool = picked == id
			out.append({"draw": "offer", "id": id, "at": at, "kind": kind, "tone": DeepUi.CHAMBER_colorS.get(kind, DeepUi.MUTED), "mine": my_vote == id,
				"hot": hot, "radius": 19.0 if hot else 17.0, "bob": float(id.hash() % 13),
				"text": "Depth %d: %s. %s to take this tunnel." % [int(node.depth), _kind_words(kind), "Tap" if DeepUi.phone else "Click"]})
			continue
		var entry: Dictionary = {"at": at, "strength": strength}
		var words: String = ""
		if seen:
			var face: Dictionary = _face(str(node.kind), str(node.get("oddity", "")), visited.has(id) or id == here)
			entry.merge({"draw": "seen", "radius": 14.0 if id != here else 15.0, "tone": str(face.tone), "mark": str(face.mark)})
			words = "Depth %d: %s" % [int(node.depth), str(face.words)]
		else:
			entry.merge({"draw": "glint", "glint": DeepDescent.glint(node)})
			words = "Depth %d: %s" % [int(node.depth), str(GLINT_WORDS.get(DeepDescent.glint(node), ""))]
		if not ahead.has(id) and not visited.has(id) and id != here:
			words += " (out of reach now)"
		entry.spot = {"at": at, "radius": 14.0, "text": words}
		out.append(entry)
	return out

func _stretch_chambers(map: Dictionary, positions: Dictionary, facts: Dictionary, chambers: Array) -> void:
	var here: String = facts.here
	var here_at: Vector2 = facts.here_at
	var ahead: Dictionary = facts.ahead
	## The lantern's pool, reaching down toward what it can show.
	var flicker: float = 0.9 + 0.1 * sin(_clock * 7.0) * sin(_clock * 2.9 + 1.0)
	var reach: float = _step * (float(DeepDescent.lantern_reach(run)) + 0.6)
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
	## The chambers, as `_plan_chambers` laid them out.
	for entry in chambers:
		var at: Vector2 = entry.at
		match str(entry.draw):
			"unknown":
				_draw_unknown(at)
			"offer":
				at.y += sin(_clock * 2.4 + float(entry.bob)) * 2.0
				var tone: Color = entry.tone
				var mine: bool = entry.mine
				var hot: bool = entry.hot
				var radius: float = entry.radius
				_glow(at, Vector2(70, 70) * (1.15 if hot else 1.0), Color(tone, (0.4 if hot else 0.24) * _fade(at.y)))
				_medallion(at, radius, str(entry.kind), 1.0, DeepUi.ACCENT if mine else Color(0, 0, 0, 0))
				if mine:
					_canvas.draw_arc(at, radius + 4.0, 0, TAU, 36, Color(DeepUi.ACCENT, 0.9 * _fade(at.y)), 2.0, true)
				_draw_voters(str(entry.id), at, radius)
				_spots.append({"at": at, "radius": radius, "text": entry.text, "offer": entry.id})
				continue
			"seen":
				_medallion(at, float(entry.radius), str(entry.tone), float(entry.strength), Color(0, 0, 0, 0), str(entry.mark))
			_:
				_draw_glint(at, str(entry.glint), float(entry.strength))
		_spots.append(entry.spot)
	if int(map.get("to", 0)) <= int(run.get("depth", 0)) + 1:
		_draw_landing(map, positions, ahead.has("landing") or here.is_empty())
	elif positions.has("landing"):
		## The landing is always known to be there, even before the lantern reaches it.
		_draw_landing(map, positions, false)
	## The hall below the landing the stretch starts from, while its Warden stands.
	if positions.has("hall") and not _hall_beaten(int(map.get("from", 0))):
		_draw_hall(positions.hall, int(map.get("from", 0)), true)
		var hall_spot: Dictionary = {"at": positions.hall, "radius": 15.0, "text": _hall_words(int(map.get("from", 0)))}
		if _is_offer("warden"):
			## A Warden's landing has one way down, into the hall: the chart takes it too.
			hall_spot.offer = "warden"
			hall_spot.radius = 18.0
			hall_spot.text += " %s to go down to it." % ("Tap" if DeepUi.phone else "Click")
			var pulse: float = 1.0 + 0.08 * sin(_clock * 3.0)
			_canvas.draw_arc(positions.hall, 22.0 * pulse, 0, TAU, 40, Color(DeepUi.CHAMBER_colorS.warden, 0.8 * _fade(positions.hall.y)), 2.0, true)
			_draw_voters("warden", positions.hall, 18.0)
		_spots.append(hall_spot)
	_draw_party(here_at)

# --- every mine (zoomed out) -----------------------------------------------------------------

## The bands' status words, by what the run is to each mine.
const NUMERALS: Array = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const MINE_STATUS: Dictionary = {"done": "BEATEN", "here": "HERE", "ahead": "AHEAD", "off": "NOT THIS RUN"}

func _mine_bands() -> Array:
	## One band per mine, shallowest first, filling the panel under its header:
	## {key, rect, state ("done", "here", "ahead", "off"), bottom, landings, wardens, beaten,
	## boss, deepest}. `done` is a mine this run has beaten and pushed on from, `here` the one
	## it is in, `ahead` the mines it can still push on into, `off` the rest (above where the
	## run began, or off its way).
	var done: Dictionary = {}
	for record in run.get("mines_done", []):
		if record is Dictionary:
			done[str(record.get("mine", ""))] = record
	var here: String = str(run.get("mine", ""))
	var ahead: Dictionary = {}
	var next: String = str(DeepContent.mine(here).get("next", ""))
	while not next.is_empty() and not ahead.has(next) and next != here:
		ahead[next] = true
		next = str(DeepContent.mine(next).get("next", ""))
	var keys: Array = DeepContent.mines_in_order()
	var top: float = TOP + 2.0
	var foot: float = size.y - 16.0
	var band_h: float = (foot - top) / float(maxi(1, keys.size()))
	var every: int = DeepDescent.landing_every()
	var out: Array = []
	for index in range(keys.size()):
		var key: String = str(keys[index])
		var state: String = "done" if done.has(key) else ("here" if key == here else ("ahead" if ahead.has(key) else "off"))
		var entry: Dictionary = {"key": key, "state": state, "rect": Rect2(Vector2(SIDE_BORDER, top + band_h * float(index)), Vector2(size.x - SIDE_BORDER * 2.0, band_h))}
		var bottom: int = DeepContent.mine_bottom(key)
		var landings: Array = []
		var wardens: Array = DeepContent.mine(key).get("warden_depths", []).duplicate()
		if bottom > 0:
			wardens.append(bottom)
			for d in range(every, bottom, every):
				landings.append(d)
		var beaten: Array = []
		var boss: bool = false
		var deepest: int = 0
		if state == "here":
			var schedule: Dictionary = run.get("schedule", {})
			bottom = DeepDescent.bottom_of(run)
			if not schedule.get("landings", []).is_empty():
				landings = schedule.landings.filter(func(d: Variant) -> bool: return int(d) < bottom or bottom <= 0)
			if not schedule.get("wardens", []).is_empty():
				wardens = schedule.wardens.duplicate()
			beaten = run.get("records", {}).get("wardens", [])
			boss = bool(run.get("records", {}).get("boss", false))
			deepest = int(run.get("depth", 0))
		elif state == "done":
			var record: Dictionary = done[key]
			beaten = record.get("wardens", [])
			boss = bool(record.get("boss", false))
			deepest = int(record.get("deepest", bottom))
		entry.merge({"bottom": bottom, "landings": landings, "wardens": wardens, "beaten": beaten, "boss": boss, "deepest": deepest})
		out.append(entry)
	return out

func _track(entry: Dictionary) -> Dictionary:
	## Where a band's depth track runs: {from, to, y}, and the x of a depth along it.
	var rect: Rect2 = entry.rect
	var from_x: float = float(SIDE_BORDER) + 30.0
	return {"from": from_x, "to": rect.end.x - 18.0, "y": rect.end.y - minf(16.0, rect.size.y * 0.22)}

func _track_x(entry: Dictionary, track: Dictionary, depth: float) -> float:
	var bottom: int = int(entry.bottom)
	## A mine with no bottom is drawn to 48 floors, fading on past them.
	var span: float = float(bottom) if bottom > 0 else 48.0
	return lerpf(float(track.from), float(track.to), clampf(depth / span, 0.0, 1.0))

func _paint_mines() -> void:
	## The still layer, zoomed out: every mine a band of its own rock, the shaft through the
	## mines this run has walked, each band's depth track with its lifts and crowns, and the
	## words that say where the run is in it. Everything is written on it, nothing waits on a
	## hover, so it reads the same under a finger.
	var bands: Array = _mine_bands()
	## The shaft down the left edge, the numerals in a column of their own beside it, the names
	## after the widest numeral.
	var shaft_x: float = float(SIDE_BORDER) + 8.0
	var numeral_x: float = shaft_x + 9.0
	var name_size: int = _text(14)
	var name_x: float = numeral_x + DeepUi.caps_font().get_string_size("VIII", HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(11)).x + 8.0
	for entry in bands:
		var rect: Rect2 = entry.rect
		var key: String = str(entry.key)
		var state: String = str(entry.state)
		var mine: Dictionary = DeepContent.mine(key)
		var tone: Color = Color(str(mine.get("palette", "c9a26b")))
		var biome: Dictionary = Biomes.for_depth(key, 1)
		var walked: bool = state in ["done", "here"]
		var rock: Color = Color(str(biome.get("rock", "3a3552"))).darkened(0.45 if walked else (0.62 if state == "ahead" else 0.78))
		_canvas.draw_rect(rect, Color(rock, 0.92))
		_canvas.draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Color(0, 0, 0, 0.55), 2.0)
		if state == "here":
			var outline := StyleBoxFlat.new()
			outline.draw_center = false
			outline.border_color = DeepUi.ACCENT
			outline.set_border_width_all(2)
			outline.set_corner_radius_all(4)
			_canvas.draw_style_box(outline, rect.grow(-2.0))
		## The shaft: lit through every mine walked, down to the party in the one it is in;
		## faint through the mines still ahead.
		var track: Dictionary = _track(entry)
		if walked:
			var low: float = rect.end.y if state == "done" else float(track.y)
			_canvas.draw_line(Vector2(shaft_x, rect.position.y), Vector2(shaft_x, low), Color(DeepUi.ACCENT, 0.75), 3.0)
			if state == "here":
				_canvas.draw_line(Vector2(shaft_x, low), Vector2(float(_track_x(entry, track, float(entry.deepest))), low), Color(DeepUi.ACCENT, 0.5), 2.0)
		elif state == "ahead":
			_canvas.draw_line(Vector2(shaft_x, rect.position.y), Vector2(shaft_x, rect.end.y), Color(DeepUi.LINE_HI, 0.35), 2.0)
		## Its numeral and name, and what the run is to it.
		var faded: float = 1.0 if walked else (0.75 if state == "ahead" else 0.45)
		var name_y: float = rect.position.y + minf(22.0, rect.size.y * 0.45)
		var tier: int = int(mine.get("tier", 0))
		var numeral: String = "∞" if DeepContent.is_endless(key) else (str(NUMERALS[tier - 1]) if tier >= 1 and tier <= NUMERALS.size() else str(tier))
		_canvas.draw_string(DeepUi.caps_font(), Vector2(numeral_x, name_y), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(11), Color(tone, faded))
		var status: String = str(MINE_STATUS.get(state, ""))
		if state == "here":
			status = "HERE · DEPTH %d" % int(run.get("depth", 0))
		elif state == "done" and not bool(entry.boss):
			status = "LEFT"
		var status_w: float = DeepUi.caps_font().get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(10)).x
		_canvas.draw_string(DeepUi.text_face(name_size), Vector2(name_x, name_y), str(mine.get("name", key)), HORIZONTAL_ALIGNMENT_LEFT, maxf(40.0, rect.end.x - name_x - status_w - 22.0), name_size,
			Color(DeepUi.PAPER if walked else DeepUi.MUTED, faded))
		_canvas.draw_string(DeepUi.caps_font(), Vector2(rect.end.x - status_w - 10.0, name_y), status, HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(10),
			DeepUi.ACCENT if state == "here" else (DeepUi.GOOD if state == "done" else Color(tone, faded)))
		_static_spots.append({"at": Vector2(name_x + 40.0, name_y - 5.0), "radius": 22.0, "text": _mine_words(entry)})
		## The depth track: how far down the run has been, its lifts and its crowns.
		var y: float = float(track.y)
		_canvas.draw_line(Vector2(float(track.from), y), Vector2(float(track.to), y), Color(0, 0, 0, 0.6), 5.0)
		_canvas.draw_line(Vector2(float(track.from), y), Vector2(float(track.to), y), Color(DeepUi.LINE_HI, 0.3 * faded), 1.5)
		if int(entry.deepest) > 0:
			_canvas.draw_line(Vector2(float(track.from), y), Vector2(_track_x(entry, track, float(entry.deepest)), y), Color(DeepUi.ACCENT, 0.9), 3.0)
		if int(entry.bottom) <= 0:
			## No bottom: the track fades on into the dark.
			for k in range(6):
				var x: float = lerpf(float(track.to) - 60.0, float(track.to), float(k) / 5.0)
				_canvas.draw_circle(Vector2(x, y), 1.6, Color(DeepUi.MUTED, faded * (1.0 - float(k) / 6.0)))
		for d in entry.landings:
			var lx: float = _track_x(entry, track, float(d))
			_canvas.draw_line(Vector2(lx, y - 4.0), Vector2(lx, y + 4.0), Color(DeepUi.CHAMBER_colorS.get("landing", DeepUi.GOOD), 0.75 * faded), 1.5)
		for d in entry.wardens:
			var depth: int = int(d)
			var last: bool = int(entry.bottom) > 0 and depth == int(entry.bottom)
			var won: bool = bool(entry.boss) if last else entry.beaten.any(func(b: Variant) -> bool: return absi(int(b) - depth) <= (0 if state == "here" else 1))
			var cx: float = _track_x(entry, track, float(depth))
			var edge: float = 13.0 if last else 10.0
			_canvas.draw_circle(Vector2(cx, y), edge * 0.62, Color(0.03, 0.03, 0.05, 0.9 * faded))
			_glyph("crown", Vector2(cx, y), edge, Color(DeepUi.ACCENT if won else DeepUi.CHAMBER_colorS.warden, (1.0 if won else 0.85) * faded))
			var who: String = "the final boss" if last else "a Warden"
			_static_spots.append({"at": Vector2(cx, y), "radius": edge * 0.7, "text": "%s, depth %d: %s%s." % [str(mine.get("name", key)), depth, who, " (beaten)" if won else ""]})

func _mine_words(entry: Dictionary) -> String:
	var name: String = DeepContent.mine_name(str(entry.key))
	match str(entry.state):
		"done":
			return "%s: beaten and left behind on the way down." % name if bool(entry.boss) else "%s: the run came through it." % name
		"here":
			return "%s: the party is at depth %d." % [name, int(run.get("depth", 0))]
		"ahead":
			return "%s: below this mine. Beat its final boss and push on to reach it." % name
	return "%s: not on this run's way down." % name

func _draw_mines_live() -> void:
	## The live layer, zoomed out: the party's lantern where it stands in its mine.
	for entry in _mine_bands():
		if str(entry.state) != "here":
			continue
		var track: Dictionary = _track(entry)
		var at := Vector2(_track_x(entry, track, float(run.get("depth", 0))), float(track.y))
		var pulse: float = 1.0 + 0.1 * sin(_clock * 3.0)
		var flicker: float = 0.85 + 0.15 * sin(_clock * 9.0) * sin(_clock * 4.3)
		_glow(at, Vector2(54, 54) * pulse, Color(DeepUi.ACCENT, 0.45 * flicker))
		_canvas.draw_arc(at, 8.0 * pulse, 0, TAU, 28, Color(DeepUi.ACCENT, 0.95), 2.0, true)
		_glyph("lantern", at + Vector2(0, -15), 12.0, Color(DeepUi.ACCENT.lightened(0.2), flicker))
		_spots.append({"at": at, "radius": 12.0, "text": "The party is here: depth %d of %s." % [int(run.get("depth", 0)), DeepContent.mine_name(str(entry.key))]})

func _kind_words(kind: String) -> String:
	match kind:
		"fight": return "a fight"
		"elite": return "an elite: a harder fight, a better stone"
		"vein": return "a pyrite vein to strike"
		"motherlode": return "a motherlode: a vein with rich seams besides"
		"oddity": return "an oddity"
		"merchant": return "a merchant: buy stones, sell and appraise"
		"smithy": return "a smithy: a die a size bigger or smaller"
		"carver": return "a carver: raise, lower or etch a die face"
		"hidden": return "a dark mouth: anything could be down there"
		"well": return "a wishing well: throw something precious down it"
		"vat": return "a vat: dip a die in a new material, or melt it plain"
		"altar": return "an altar: five gems given up for one"
		"rest_stop": return "a rest stop: heal, or polish a gem for the run"
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
	## Everyone who has picked this way, you included, in their own seat's color: the same
	## orbs the mouth in the room hangs over its arch.
	var count: int = 0
	for other in run.get("players", []):
		if _voted(other) == id:
			var dot: Vector2 = at + Vector2(radius + 8.0, -radius * 0.6 + float(count) * 9.0)
			_canvas.draw_circle(dot, 3.5, Color(SEATS[int(other.get("seat", 0)) % SEATS.size()], _fade(at.y)))
			count += 1

func _draw_landing(map: Dictionary, positions: Dictionary, reachable: bool) -> void:
	var at: Vector2 = positions.landing
	var landing: int = int(map.get("to", 0))
	if positions.has("hall_below"):
		## Its Warden's hall, below it: the landing comes first, then the hall, then the way on.
		_stroke(_curve(at, positions.hall_below), Color(DeepUi.CHAMBER_colorS.warden, 0.55 if reachable else 0.3), 2.0)
		_draw_hall(positions.hall_below, landing, reachable)
		_spots.append({"at": positions.hall_below, "radius": 15.0, "text": _hall_words(landing)})
	var fade: float = _fade(at.y)
	var tone: Color = DeepUi.CHAMBER_colorS.landing
	if fade <= 0.0:
		return
	_canvas.draw_circle(at, 19.0, Color(tone.darkened(0.65), 0.97 * fade))
	_canvas.draw_arc(at, 19.0, 0, TAU, 36, Color(tone, (0.95 if reachable else 0.5) * fade), 2.5, true)
	_glyph("lift", at, 21.0, Color(tone.lightened(0.3), fade))
	_canvas.draw_string(DeepUi.caps_font(), at + Vector2(26, 5), "LANDING", HORIZONTAL_ALIGNMENT_LEFT, -1, _caps(11), Color(tone, 0.85 * fade))
	var words: String = "Depth %d: a landing with a lift. Rest, appraise or use the well, then go up or down." % landing
	if positions.has("hall_below"):
		words += " The %s waits past it." % ("final boss" if DeepDescent.run_is_boss(run, landing) else "Warden")
	var spot: Dictionary = {"at": at, "radius": 19.0, "text": words}
	if _is_offer("landing"):
		## The last step of a stretch: the landing itself is the way on.
		spot.offer = "landing"
		spot.text = words + (" Tap to go down to it." if DeepUi.phone else " Click to go down to it.")
		var pulse: float = 1.0 + 0.08 * sin(_clock * 3.0)
		_canvas.draw_arc(at, 24.0 * pulse, 0, TAU, 40, Color(tone, 0.8 * fade), 2.0, true)
	_spots.append(spot)

func _draw_hall(at: Vector2, depth: int, reachable: bool) -> void:
	## A Warden's hall whose Warden still stands: a crown in a threatening glow.
	var fade: float = _fade(at.y)
	if fade <= 0.0:
		return
	var tone: Color = DeepUi.CHAMBER_colorS.warden
	var threat: float = 54.0 + 8.0 * sin(_clock * 2.0)
	_glow(at, Vector2(threat, threat), Color(tone, (0.3 if reachable else 0.18) * fade))
	## Named and faced from the stretch's first floor (review card W2): its own picture in the
	## ring, a small crown on the ring, and its name beside it where "WARDEN" used to be.
	var key: String = DeepDescent.warden_key(run, depth)
	var face: Texture2D = _warden_face(key) if not key.is_empty() else null
	var radius: float = 17.0 if face != null else 15.0
	_canvas.draw_circle(at, radius, Color(tone.darkened(0.65), 0.97 * fade))
	if face != null:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for index in range(32):
			var unit := Vector2(cos(TAU * float(index) / 32.0), sin(TAU * float(index) / 32.0))
			points.append(at + unit * (radius - 1.0))
			uvs.append(Vector2(0.5, 0.5) + unit * 0.5)
		_canvas.draw_colored_polygon(points, Color(1, 1, 1, fade), uvs, face)
	_canvas.draw_arc(at, radius, 0, TAU, 32, Color(tone, (0.95 if reachable else 0.5) * fade), 2.2, true)
	if face != null:
		var badge: Vector2 = at + Vector2(radius * 0.72, -radius * 0.72)
		_canvas.draw_circle(badge, 6.5, Color(tone.darkened(0.6), fade))
		_glyph("crown", badge, 9.0, Color(tone.lightened(0.35), fade))
	else:
		_glyph("crown", at, 17.0, Color(tone.lightened(0.3), fade))
	var named: String = str(DeepContent.creature(key).get("name", "")).to_upper() if not key.is_empty() else ""
	if named.is_empty():
		named = "BOSS" if DeepDescent.run_is_boss(run, depth) else "WARDEN"
	_canvas.draw_string(DeepUi.caps_font(), at + Vector2(radius + 7.0, 5), named, HORIZONTAL_ALIGNMENT_LEFT, maxf(40.0, size.x - at.x - radius - 12.0), _caps(11), Color(tone, 0.85 * fade))
	if reachable or int(_hall_drawn.get("depth", -1)) < 0:
		_hall_drawn = {"depth": depth, "at": at}

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

func _draw_unknown(at: Vector2) -> void:
	## A chamber below the lantern's reach: a dim ring with a question in it.
	var fade: float = _fade(at.y)
	_canvas.draw_circle(at, 9.0, Color(0.03, 0.035, 0.05, 0.85 * fade))
	_canvas.draw_arc(at, 9.0, 0, TAU, 24, Color(DeepUi.MUTED, 0.35 * fade), 1.2, true)
	_glyph("question", at, 10.0, Color(DeepUi.MUTED, 0.6 * fade))
