class_name RailWarnings
extends RefCounted
## Two small marks on a socket, laid over the fight's rail and the loadout at home (lane `sim`
## of the November 13, 2026 playtest review):
##
## - a countdown on a socket the Foreman's rubble or a Clouder's fog holds for a few turns
##   (`DeepBattle.hold_left`): an hourglass and the turns still to go, at the ring's foot;
## - a warning where an opal sits beside or behind a gem it cannot touch (opals never copy
##   opals, `DeepBattle.opal_blocks`): a small amber badge with a broken link at the socket's
##   lower left, and the link drawn dim toward the gem it cannot reach, the way Balatro marks a
##   Blueprint that can't copy its neighbour. Its plate (hover, or a hold on the phone) says
##   why, line by line ("Can't copy Blue Seam: opals never copy opals.").

const Tips = preload("res://view/ui/tips.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Plates = preload("res://view/ui/plates.gd")

const WARN := Color("e2b23a")
const INK := Color("0a0d18")

static func lines_for(rail: Array, socket: int, blocks: Dictionary) -> Array:
	## The plate's lines for one socket of `DeepBattle.opal_blocks`, or [] when it has none.
	var out: Array = []
	if socket < 0 or socket >= rail.size() or not rail[socket] is Dictionary:
		return out
	for mark in blocks.get(socket, []):
		out.append(DeepBattle.opal_block_line(rail[socket], mark))
	return out

static func run_blocks(unit: Dictionary) -> Dictionary:
	## `DeepBattle.opal_blocks` read off a rail that is not laid flat (the run's dock and bench
	## keep the riders apart from the sockets): socket -> {"lines": [...], "toward": [socket,
	## ...]} for the gem set in each socket, so the run's rail says what the fight's does
	## (November 16, 2026: the warning was only seen in a fight and in the loadout at home).
	var flat: Dictionary = {"character": str(unit.get("character", "")), "rail": unit.get("rail", []).duplicate(),
		"sockets": unit.get("sockets", []).duplicate(), "riders": unit.get("riders", []).duplicate(true), "haul": []}
	DeepStone.flatten_rail(flat)
	var blocks: Dictionary = DeepBattle.opal_blocks(flat.rail)
	var out: Dictionary = {}
	var places: Array = flat.get("places", [])
	for at in blocks:
		if int(at) < 0 or int(at) >= places.size():
			continue
		var place: Dictionary = places[int(at)]
		if int(place.get("rider", -1)) >= 0:
			continue
		var toward: Array = []
		for mark in blocks[at]:
			var other: int = int(mark.get("at", -1))
			if other >= 0 and other < places.size():
				toward.append(int(places[other].get("socket", -1)))
		out[int(place.get("socket", -1))] = {"lines": lines_for(flat.rail, int(at), blocks), "toward": toward}
	return out

static func plate(stone: Dictionary, said: Array) -> Control:
	## The warning's own plate: the opal's name and each thing it cannot reach.
	var box := Plates.plate(290.0)
	Plates.head(box, str(DeepStone.skill_of(stone).get("name", "Opal")), "opal", WARN)
	for line in said:
		DeepUi.stat(box, "broken_chain", str(line), WARN, 12)
	return box

static func countdown(slot: Control, left: int, tone: Color) -> void:
	## The turns a rubble or fog still holds this socket, at the ring's foot ("⌛ 3"); none
	## when `left` is 0 (it holds for the fight, or until its creature is hit).
	var pill: Control = slot.get_node_or_null("HoldCount")
	var key: String = "%d|%s" % [left, tone.to_html()]
	if left <= 0:
		if pill != null:
			pill.name = "HoldCountGone"
			pill.queue_free()
		return
	if pill != null and str(pill.get_meta("key", "")) == key:
		return
	if pill != null:
		pill.name = "HoldCountGone"
		pill.queue_free()
	var panel := PanelContainer.new()
	panel.name = "HoldCount"
	panel.set_meta("key", key)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 3
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK, 0.92)
	style.border_color = tone
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(DeepUi.pt(8) if DeepUi.phone else 9))
	style.content_margin_left = DeepUi.pt(4) if DeepUi.phone else 5
	style.content_margin_right = DeepUi.pt(5) if DeepUi.phone else 6
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	var row := DeepUi.hbox(panel, int(DeepUi.pt(2) if DeepUi.phone else 3))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := DeepUi.icon(row, "hourglass", DeepUi.pt(10) if DeepUi.phone else 12.0, tone)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var number := DeepUi.label(row, str(left), 13, Color.WHITE)
	number.add_theme_font_override("font", DeepUi.bold_font())
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Bottom right of the ring, a little outside it, so the gem stays seen.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var out: float = DeepUi.pt(4) if DeepUi.phone else 6.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = out
	panel.offset_bottom = out
	slot.add_child(panel)
	if slot.is_inside_tree() and DisplayServer.get_name() != "headless":
		DeepUi.pop_in(panel, 0.0, 0.4)

static func opal_warn(slot: Control, stone: Variant, said: Array, toward: Array = [], with_plate: bool = true) -> void:
	## The warning on an opal's socket: none when `said` is empty. `toward` holds Callables
	## that give the global rect of each gem it cannot reach (its ring's slot); the link is
	## drawn dim from the badge toward the nearest. `with_plate` gives the badge its own plate
	## (the loadout); the fight's rail says the same on the gem's own plate instead.
	var badge: Warn = slot.get_node_or_null("OpalWarn")
	var key: String = "|".join(said)
	if said.is_empty() or not stone is Dictionary:
		if badge != null:
			badge.name = "OpalWarnGone"
			badge.queue_free()
		return
	if badge != null and str(badge.get_meta("key", "")) == key:
		badge.toward = toward
		return
	if badge != null:
		badge.name = "OpalWarnGone"
		badge.queue_free()
	var edge: float = DeepUi.pt(15) if DeepUi.phone else 24.0
	badge = Warn.new(edge)
	badge.name = "OpalWarn"
	badge.set_meta("key", key)
	badge.toward = toward
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -edge * 0.3
	badge.offset_right = edge * 0.7
	badge.offset_top = -edge * 0.7
	badge.offset_bottom = edge * 0.3
	if with_plate:
		var shown: Dictionary = stone
		var words: Array = said.duplicate()
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		Tips.attach(badge, func() -> Control: return plate(shown, words), {"tone": WARN})
	else:
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(badge)

static func loadout(home: Control, row: Node, character_key: String) -> void:
	## The loadout at home (the desk's socket cards and the phone's tiles, the first children of
	## `row` in socket order): the same warning on every opal set where it cannot reach the gem
	## beside or behind it, with its own plate.
	var record: Dictionary = home.profile.characters.get(character_key, {})
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	var rail: Array = []
	for index in range(sockets.size()):
		var skill: String = home.rail_skill(record, index)
		var stone: Dictionary = DeepProfile.owned(home.profile, skill) if DeepProfile.fillable_socket(home.profile, character_key, index) and skill != "" else {}
		rail.append(stone if not stone.is_empty() else null)
	var blocks: Dictionary = DeepBattle.opal_blocks(rail)
	if blocks.is_empty():
		return
	var slots: Array = []
	for index in range(mini(rail.size(), row.get_child_count())):
		slots.append(_ring_slot(row.get_child(index)))
	for socket in blocks:
		var slot: Control = slots[int(socket)] if int(socket) < slots.size() else null
		if slot == null:
			continue
		var toward: Array = []
		for mark in blocks[socket]:
			var at: int = int(mark.get("at", -1))
			var aim: Control = slots[at] if at >= 0 and at < slots.size() else null
			if aim != null:
				toward.append(func() -> Rect2: return aim.get_global_rect() if is_instance_valid(aim) else Rect2())
		opal_warn(slot, rail[int(socket)], lines_for(rail, int(socket), blocks), toward, true)

static func _ring_slot(node: Node) -> Control:
	## The control a socket's ring is laid in, somewhere inside its card.
	for child in node.get_children():
		## A socket's ring (BattleScreen.SocketRing, named by what it does: a class name here
		## would make the two scripts load each other).
		if child is Control and child.has_method("set_ready") and "shown" in child:
			return node as Control
	for child in node.get_children():
		var found: Control = _ring_slot(child)
		if found != null:
			return found
	return null

class Warn extends Control:
	## An amber badge with a broken link in it, and the link drawn dim toward what the opal
	## cannot reach: a short dashed line with a gap in the middle.
	var edge: float = 22.0
	var toward: Array = []
	var _texture: Texture2D = null
	var _last: Rect2 = Rect2()
	func _init(size_px: float) -> void:
		edge = size_px
		custom_minimum_size = Vector2(edge, edge)
		z_index = 3
		_texture = GemIcons.texture("broken_chain", GemIcons.baked_size(edge * 0.7))
	func _process(_delta: float) -> void:
		## The rail settles after it is laid: redraw the link when what it points at moves.
		var at: Rect2 = _target()
		if at != _last:
			_last = at
			queue_redraw()
	func _target() -> Rect2:
		## The nearest of the gems it cannot reach, as a rect in this badge's own space.
		var best: Rect2 = Rect2()
		for point in toward:
			if point is Callable and (point as Callable).is_valid():
				var got: Variant = (point as Callable).call()
				if not got is Rect2 or (got as Rect2).size == Vector2.ZERO:
					continue
				var local := Rect2((got as Rect2).position - global_position, (got as Rect2).size)
				if best.size == Vector2.ZERO or local.get_center().length() < best.get_center().length():
					best = local
		return best
	func _draw() -> void:
		var centre := size * 0.5
		var r: float = edge * 0.5
		var aim: Rect2 = _target()
		## It stops at the ring's edge, so the gem it points at stays clear.
		var at: Vector2 = aim.get_center() + (centre - aim.get_center()).normalized() * minf(aim.size.x, aim.size.y) * 0.47
		if aim.size != Vector2.ZERO and at.distance_to(centre) > r * 2.0:
			## The dim link: dashes from the badge toward the gem, broken in the middle.
			var from: Vector2 = centre + (at - centre).normalized() * r
			var span: Vector2 = at - from
			var length: float = span.length()
			var dir: Vector2 = span / length
			var dash: float = maxf(4.0, edge * 0.28)
			var walked: float = 0.0
			var tone := Color(WARN, 0.38)
			while walked < length:
				var mid: float = walked + dash * 0.5
				var gap_here: bool = absf(mid - length * 0.5) < dash * 0.9
				if not gap_here:
					draw_line(from + dir * walked, from + dir * minf(length, walked + dash), tone, maxf(2.0, edge * 0.1), true)
				walked += dash * 1.8
		draw_circle(centre, r, INK)
		draw_circle(centre, r - maxf(1.5, edge * 0.08), WARN)
		if _texture != null:
			var side: float = edge * 0.7
			draw_texture_rect(_texture, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), false, INK)
