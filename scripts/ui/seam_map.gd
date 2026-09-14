extends Control
## The seam as the party sees it: a cross-section of the mine from the layer above them to
## the edge of what has been dug, drawn top to bottom.
##
## Within the lantern's reach every chamber shows its room. Past it a chamber shows only a
## silhouette — eyes for something hostile, a lit window for a service, a glint for loot, a
## question for anything else — and a lift shows as a beacon however far down it is. The
## chambers the party may walk to next are ringed and can be clicked; a ring turns red when
## the next step would wake the boss.
##
## This control only draws a snapshot. Choosing a tunnel calls back into the screen, which
## sends the vote like any other command.

const Forge = preload("res://scripts/ui/sprite_forge.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Seam = preload("res://scripts/core/seam.gd")

const ROW_HEIGHT := 78.0
const NODE_RADIUS := 23.0
const MARGIN_LEFT := 64.0
const ROWS_ABOVE := 1
const ROOM_COLORS := {"battle": Color("ff7a6b"), "elite": Color("ff9d5c"), "boss": Color("b98bff"),
	"shop": Color("e8b661"), "rest": Color("ffb870"), "event": Color("b98bff"), "mine": Color("6fe3b0"),
	"workshop": Color("b9c6d6"), "lapidary": Color("63d8d0"), "wager": Color("ffd166"),
	"crucible": Color("ff8fa3"), "lift": Color("6fe3b0"), "treasure": Color("76b6ff")}
const SILHOUETTE_NAMES := {"hostile": "Something moves down there.", "glint": "Something glints in the dark.",
	"service": "A light is burning.", "unknown": "Too dark to tell.", "lift": "A lift beacon."}

var state: Dictionary = {}
var controlled_id := ""
var on_choose: Callable
var _offers: Dictionary = {}
var _visited: Dictionary = {}
var _hover := ""
var _clock := 0.0
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func configure(snapshot: Dictionary, player_id: String, choose: Callable) -> void:
	state = snapshot
	controlled_id = player_id
	on_choose = choose
	_offers.clear()
	for offer in state.get("offers", []):
		_offers[str(offer.get("id", ""))] = offer
	_visited.clear()
	for entry in state.get("history", []):
		_visited[str(entry.get("node_id", ""))] = true
	_visited[str(state.get("position", ""))] = true
	custom_minimum_size.y = (_last_depth() - _first_depth() + 1) * ROW_HEIGHT + 24.0
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion or _offers.is_empty():
		return
	_clock += delta
	queue_redraw()

func _first_depth() -> int:
	return maxi(0, int(state.get("depth", 0)) - ROWS_ABOVE)

func _last_depth() -> int:
	return mini(int(state.get("seam", {}).get("deepest", 0)), int(state.get("depth", 0)) + Seam.LOOKAHEAD)

func _row_y(depth: int) -> float:
	return 12.0 + (depth - _first_depth()) * ROW_HEIGHT + ROW_HEIGHT * 0.5

func _node_position(node: Dictionary) -> Vector2:
	var usable: float = maxf(size.x - MARGIN_LEFT - 24.0, 200.0)
	var x: float = MARGIN_LEFT + 12.0 + usable * (float(node.get("column", 3)) + 0.5) / float(Seam.COLUMNS)
	return Vector2(x, _row_y(int(node.get("depth", 0))))

func _surface_position() -> Vector2:
	return Vector2(MARGIN_LEFT + 12.0 + maxf(size.x - MARGIN_LEFT - 24.0, 200.0) * 0.5, _row_y(0))

func _layer(depth: int) -> Array:
	return state.get("seam", {}).get("layers", {}).get(str(depth), [])

func _sighted(node: Dictionary) -> bool:
	return int(node.get("depth", 0)) - int(state.get("depth", 0)) <= int(state.get("sight", Seam.SIGHT))

func _draw() -> void:
	if state.is_empty():
		return
	var mine: Dictionary = Catalog.mine_definition(str(state.get("mine_id", "")))
	var tint := Color(str(mine.get("color", "c9a26b")))
	var first := _first_depth()
	var last := _last_depth()
	# Strata: each layer a band of rock, darker the deeper it lies.
	for depth in range(first, last + 1):
		var top: float = _row_y(depth) - ROW_HEIGHT * 0.5
		var shade: float = clampf(0.20 - depth * 0.006, 0.05, 0.20)
		var band := Color(tint.darkened(0.78), 0.55).lerp(Color(0.02, 0.02, 0.03, 0.9), 1.0 - shade * 4.0)
		if depth == 0:
			band = Color(0.30, 0.38, 0.46, 0.35)
		draw_rect(Rect2(0, top, size.x, ROW_HEIGHT), band)
		draw_line(Vector2(0, top), Vector2(size.x, top), Color(tint, 0.06), 1.0)
		var label := "SURFACE" if depth == 0 else str(depth)
		draw_string(get_theme_default_font(), Vector2(8, _row_y(depth) + 5), label, HORIZONTAL_ALIGNMENT_LEFT, MARGIN_LEFT - 4, 12 if depth > 0 else 10, Color(0.72, 0.76, 0.84, 0.55 if depth != int(state.get("depth", 0)) else 1.0))
	# Tunnels first, so chambers sit on top of them.
	if first == 0:
		for node in _layer(1):
			var walked: bool = _visited.has(str(node.id)) and str(state.get("position", "")) != Seam.SURFACE
			_tunnel(_surface_position(), _node_position(node), walked)
	for depth in range(maxi(1, first), last):
		for node in _layer(depth):
			for link in node.get("links", []):
				var target: Dictionary = Seam.find_node(state.seam, str(link))
				if target.is_empty():
					continue
				_tunnel(_node_position(node), _node_position(target), _visited.has(str(node.id)) and _visited.has(str(link)))
	if first == 0:
		_draw_surface()
	for depth in range(maxi(1, first), last + 1):
		for node in _layer(depth):
			_draw_node(node)
	_draw_party()

func _tunnel(from: Vector2, to: Vector2, walked: bool) -> void:
	var color := Color("e8b661") if walked else Color(0.55, 0.58, 0.66, 0.30)
	draw_line(from, to, Color(0, 0, 0, 0.45), 7.0 if walked else 5.0, true)
	draw_line(from, to, color, 3.0 if walked else 2.0, true)

func _draw_surface() -> void:
	var at := _surface_position()
	draw_rect(Rect2(at.x - 46, at.y - 9, 92, 18), Color("3a2e20"))
	draw_rect(Rect2(at.x - 40, at.y - 6, 80, 12), Color("15110b"))
	draw_string(get_theme_default_font(), at + Vector2(-60, -14), "MINE MOUTH", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color("d8c7a4"))

func _draw_node(node: Dictionary) -> void:
	var id := str(node.id)
	var at := _node_position(node)
	var kind := str(node.get("kind", "battle"))
	var sighted := _sighted(node)
	var offer: Dictionary = _offers.get(id, {})
	var here := id == str(state.get("position", ""))
	var passed: bool = int(node.get("depth", 0)) <= int(state.get("depth", 0)) and not here
	var accent: Color = ROOM_COLORS.get(kind, Color("8f9fb5"))
	if not offer.is_empty():
		var pulse: float = 0.5 + 0.5 * sin(_clock * 3.2)
		var ring := Color("ff5b4f") if offer.get("wakes_boss", false) else Color("e8b661")
		draw_circle(at, NODE_RADIUS + 9.0 + pulse * 3.0, Color(ring, 0.16 + 0.10 * pulse))
		draw_arc(at, NODE_RADIUS + 6.0, 0.0, TAU, 40, Color(ring, 0.9 if _hover == id else 0.65), 3.0 if _hover == id else 2.0, true)
	if not sighted and kind == "lift":
		# A lift beacon reaches past the lantern.
		draw_circle(at, NODE_RADIUS + 5.0, Color(ROOM_COLORS.lift, 0.18))
	var fill := Color("141a26") if sighted else Color("0b0e15")
	draw_circle(at, NODE_RADIUS, fill)
	draw_arc(at, NODE_RADIUS, 0.0, TAU, 36, Color(accent, 0.85) if sighted or kind == "lift" else Color(0.4, 0.44, 0.52, 0.5), 2.0, true)
	var faded: float = 0.45 if passed and not _visited.has(id) else 1.0
	if sighted or kind == "lift":
		var texture: Texture2D = Forge.room(kind)
		var edge := NODE_RADIUS * 1.5
		draw_texture_rect(texture, Rect2(at - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, Color(1, 1, 1, faded))
	else:
		_draw_silhouette(Seam.silhouette(kind), at)
	if here:
		draw_arc(at, NODE_RADIUS + 3.0, 0.0, TAU, 36, Color("eef1f7"), 2.5, true)
	if not offer.is_empty():
		_draw_votes(id, at)

func _draw_silhouette(shape: String, at: Vector2) -> void:
	match shape:
		"hostile":
			draw_circle(at + Vector2(-6, -1), 3.2, Color("ff5b4f"))
			draw_circle(at + Vector2(6, -1), 3.2, Color("ff5b4f"))
			draw_circle(at + Vector2(-6, -1), 6.0, Color("ff5b4f", 0.18))
			draw_circle(at + Vector2(6, -1), 6.0, Color("ff5b4f", 0.18))
		"glint":
			var gleam := Color("bfe9ff")
			draw_line(at + Vector2(0, -9), at + Vector2(0, 9), gleam, 2.0, true)
			draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), gleam, 2.0, true)
			draw_line(at + Vector2(-5, -5), at + Vector2(5, 5), Color(gleam, 0.6), 1.5, true)
			draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), Color(gleam, 0.6), 1.5, true)
		"service":
			draw_rect(Rect2(at - Vector2(8, 7), Vector2(16, 14)), Color("ffcf7a", 0.85))
			draw_line(at + Vector2(0, -7), at + Vector2(0, 7), Color("141a26"), 2.0)
			draw_line(at + Vector2(-8, 0), at + Vector2(8, 0), Color("141a26"), 2.0)
		_:
			draw_string(get_theme_default_font(), at + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_CENTER, 12, 20, Color(0.72, 0.62, 0.95, 0.85))

func _draw_votes(id: String, at: Vector2) -> void:
	var votes: Dictionary = state.get("votes", {})
	var index := 0
	for hero in state.get("heroes", []):
		if str(votes.get(str(hero.get("id", "")), "")) != id:
			continue
		var color := Color(str(Catalog.HEROES.get(str(hero.get("key", "")), {}).get("color", "e8b661")))
		var pip := at + Vector2(-NODE_RADIUS + 6.0 + index * 12.0, NODE_RADIUS + 10.0)
		draw_circle(pip, 5.0, Color("0a0d16"))
		draw_circle(pip, 4.0, color)
		index += 1

func _draw_party() -> void:
	var position_id := str(state.get("position", ""))
	var at: Vector2 = _surface_position() if position_id == Seam.SURFACE else _node_position(Seam.find_node(state.seam, position_id))
	var heroes: Array = state.get("heroes", [])
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		var color := Color(str(Catalog.HEROES.get(str(hero.get("key", "")), {}).get("color", "e8b661")))
		var pip := at + Vector2(NODE_RADIUS + 6.0, -NODE_RADIUS + 4.0 + index * 11.0)
		draw_circle(pip, 5.5, Color("0a0d16"))
		draw_circle(pip, 4.5, color if int(hero.get("hp", 0)) > 0 else Color(color, 0.35))

func _node_at(point: Vector2) -> Dictionary:
	for depth in range(maxi(1, _first_depth()), _last_depth() + 1):
		for node in _layer(depth):
			if _node_position(node).distance_to(point) <= NODE_RADIUS + 8.0:
				return node
	return {}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var node := _node_at(event.position)
		var id := str(node.get("id", ""))
		if id != _hover:
			_hover = id
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _offers.has(id) else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var node := _node_at(event.position)
		var id := str(node.get("id", ""))
		if _offers.has(id) and on_choose.is_valid():
			accept_event()
			on_choose.call(id)

func _get_tooltip(at_position: Vector2) -> String:
	var node := _node_at(at_position)
	if node.is_empty():
		return ""
	var kind := str(node.get("kind", ""))
	var depth := int(node.get("depth", 0))
	if not _sighted(node) and kind != "lift":
		return "Depth %d · %s" % [depth, SILHOUETTE_NAMES.get(Seam.silhouette(kind), "Too dark to tell.")]
	var offer: Dictionary = _offers.get(str(node.id), {})
	var text := "Depth %d · %s" % [depth, str(offer.get("name", kind.capitalize()))]
	if not offer.is_empty():
		text += "\n" + str(offer.get("description", ""))
		if offer.get("wakes_boss", false):
			text += "\nThe next step fills the tremor meter: the boss will be waiting here."
		text += "\nClick to vote for this tunnel."
	elif kind == "lift" and not _sighted(node):
		text += "\nToo far to see anything but its beacon."
	return text
