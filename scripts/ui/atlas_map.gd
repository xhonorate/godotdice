extends Control
## The map of the deeps: every mine a player has opened or can see from one, and the unlock
## routes between them, drawn on parchment.
##
## An unlocked mine is lit in its own colour and can be chosen. A mine linked from one is a
## dark silhouette with a question mark: known to exist, not yet reachable. Anything further
## out is not drawn at all, so the map grows as bosses fall.

signal mine_selected(mine_id: String)

const Catalog = preload("res://scripts/core/catalog.gd")
const Profile = preload("res://scripts/core/profile.gd")

const NODE_RADIUS := 26.0

var profile: Dictionary = {}
var selected := ""
var special_mines: Array = []
var _clock := 0.0
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 380)
	tooltip_text = " "

func configure(new_profile: Dictionary, chosen: String, specials: Array = []) -> void:
	profile = new_profile
	selected = chosen
	special_mines = specials
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_clock += delta
	queue_redraw()

func _at(mine_id: String) -> Vector2:
	var mine: Dictionary = Catalog.mine_definition(mine_id)
	var inner := Rect2(Vector2(40, 40), size - Vector2(80, 80))
	return inner.position + inner.size * Vector2(float(mine.get("atlas_x", 50)) / 100.0, float(mine.get("atlas_y", 50)) / 100.0)

func _draw() -> void:
	var paper := Rect2(Vector2.ZERO, size)
	draw_rect(paper, Color("d9c08e"))
	draw_rect(paper.grow(-10), Color("e6d2a6"))
	for index in range(7):
		var y: float = size.y * (0.15 + 0.12 * index)
		var points := PackedVector2Array()
		for step in range(21):
			var x: float = size.x * float(step) / 20.0
			points.append(Vector2(x, y + sin(float(step) * 0.8 + index) * 8.0))
		draw_polyline(points, Color("b89a64", 0.35), 1.5, true)
	draw_rect(paper, Color("6b4526"), false, 6.0)
	if profile.is_empty():
		return
	var visible_ids: Array = Catalog.mine_ids().filter(func(id: String) -> bool: return Profile.mine_state(profile, id) != "hidden")
	for id in visible_ids:
		if Profile.mine_state(profile, id) != "unlocked":
			continue
		for link in Catalog.mine_definition(id).get("links", []):
			if not str(link) in visible_ids:
				continue
			_dashed(_at(id), _at(str(link)), Color("6b4526"), 4.0)
	for id in visible_ids:
		var state := Profile.mine_state(profile, id)
		var mine: Dictionary = Catalog.mine_definition(id)
		var at := _at(id)
		var tint := Color(str(mine.get("color", "c9a26b")))
		if id in special_mines:
			var pulse: float = 0.5 + 0.5 * sin(_clock * 3.0)
			draw_circle(at, NODE_RADIUS + 14.0 + pulse * 4.0, Color("e2564a", 0.25))
		if id == selected:
			draw_circle(at, NODE_RADIUS + 9.0, Color("fff4de", 0.8))
		if state == "unlocked":
			draw_circle(at, NODE_RADIUS, Color("3a2718"))
			draw_circle(at, NODE_RADIUS - 4.0, tint)
			var peak := PackedVector2Array([at + Vector2(-12, 9), at + Vector2(0, -13), at + Vector2(12, 9)])
			draw_colored_polygon(peak, Color("3a2718"))
			if profile.get("mines", {}).get(id, {}).get("boss_defeated", false):
				draw_circle(at + Vector2(NODE_RADIUS - 4, -NODE_RADIUS + 4), 9.0, Color("6fe3b0"))
				draw_polyline(PackedVector2Array([at + Vector2(NODE_RADIUS - 8, -NODE_RADIUS + 4), at + Vector2(NODE_RADIUS - 5, -NODE_RADIUS + 7), at + Vector2(NODE_RADIUS + 0, -NODE_RADIUS + 1)]), Color("123024"), 2.0)
			var label := str(mine.get("name", id))
			var font := get_theme_default_font()
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, at + Vector2(-width * 0.5, NODE_RADIUS + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("3a2718"))
		else:
			draw_circle(at, NODE_RADIUS, Color("3a2718"))
			draw_circle(at, NODE_RADIUS - 4.0, Color("6b5a44"))
			draw_string(get_theme_default_font(), at + Vector2(-6, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e6d2a6"))

func _dashed(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(length, 0.001)
	var travelled := NODE_RADIUS
	while travelled < length - NODE_RADIUS:
		var end := minf(travelled + 14.0, length - NODE_RADIUS)
		draw_line(from + direction * travelled, from + direction * end, color, width, true)
		travelled += 24.0

func _mine_at(point: Vector2) -> String:
	for id in Catalog.mine_ids():
		if Profile.mine_state(profile, id) == "hidden":
			continue
		if _at(id).distance_to(point) <= NODE_RADIUS + 6.0:
			return id
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _mine_at(event.position)
		if not id.is_empty():
			accept_event()
			mine_selected.emit(id)
	elif event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not _mine_at(event.position).is_empty() else Control.CURSOR_ARROW

func _get_tooltip(at_position: Vector2) -> String:
	var id := _mine_at(at_position)
	if id.is_empty():
		return ""
	if Profile.mine_state(profile, id) != "unlocked":
		return "Uncharted. Defeat the boss of a neighbouring mine to open the way."
	return str(Catalog.mine_definition(id).get("name", id))
