extends "res://view/battle/birth_act.gd"
## Ardor's Rampart: even dice raise a wall, and the wall is the weapon.
##
## While the hand is planned every even die sits on a slab of hematite, a second, darker plate
## beside the Block number says how much of his Block will be kept into next turn, and a chip
## over the stone counts the blows Ram would land at the Block the rail comes to (bright once
## the hand reaches Ram). When the stone fires, Parapet stacks a course of slabs along the top
## of the dock with a thud each, Thornwork snaps iron spikes out of it (and a shard of them
## flies back at any creature whose blow then lands on him), Ram shoves the wall forward and
## drives a slab of it into the target once a blow, and Keep drops a portcullis across the
## Block plate. Wall, spikes and gate stand until his next turn, as what they stand for does.
##
## The phone keeps the kept plate in the row of chips over the ring, where the desktop sets it
## beside the Block number; the wall is the same course at half the size.

const IRON := Color("7b3b40")
const RUST := Color("b5524a")
const DARK := Color("1f0f12")
const STEEL := Color("d2c9cb")
## A slab falls into the course this long after the one before it, and takes this long to land.
const STACK_GAP: float = 0.04
const DROP: float = 0.12
const SPIKE_SNAP: float = 0.16
## A slab of the wall rides Ram's bolt to the target: the bolt's own flight.
const RAM_FLIGHT: float = 0.2
const GATE_DROP: float = 0.2
const SHARD_FLIGHT: float = 0.16

var _kept: PanelContainer = null
var _kept_said: Label = null
var _kept_now: int = 0
var _ram: PanelContainer = null
var _ram_said: Label = null
var _ram_hits: int = 0
var _evens: Array = []
## When the course began to stack, the spikes to snap out and the gate to drop (ticks; -1 for
## none, 0 for one that stands without having been watched going up).
var _wall_at: int = -1
var _spikes_at: int = -1
var _gate_at: int = -1
var _lunge_at: int = -1
var _lunge_way: Vector2 = Vector2.UP
## Slabs in flight to a creature ({from, to, at, hit}) and shards flying back ({from, to, at, hit}).
var _rams: Array = []
var _shards: Array = []

func _open() -> void:
	_kept = plate(7.0, 2.0, Color(RUST, 0.85))
	var dark: StyleBoxFlat = _kept.get_theme_stylebox("panel") as StyleBoxFlat
	if dark != null:
		dark.bg_color = Color(DARK, 0.97)
	_kept_said = words(_kept, "", 12, STEEL)
	_kept.mouse_filter = Control.MOUSE_FILTER_PASS
	_kept.visible = false
	add_child(_kept)
	tip(_kept, _kept_plate, {"tone": RUST})
	_ram = plate(6.0, 2.0, Color(RUST, 0.85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u(4.0, 2.0)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ram.add_child(row)
	var mark: TextureRect = GemIcons.glyph(row, "battlement", DeepUi.glyph_px(text_px(12), 1.0), RUST.lightened(0.25))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ram_said = words(row, "", 12, STEEL)
	_ram.mouse_filter = Control.MOUSE_FILTER_PASS
	_ram.visible = false
	place(_ram, "over_stone", 0.5, Vector2(0.0, -u(0.0, 2.0)))
	tip(_ram, _ram_plate, {"tone": RUST})

# --- reading the wall ----------------------------------------------------------------------------

func _stone_fired() -> bool:
	## Whether the stone has resolved this turn: until it has, what it would do is the forecast's.
	return not planning and page != null and not page.birth_outcome.is_empty()

func _held() -> int:
	## The Block he will hold once the rail and Parapet have landed (what Ram counts in tens),
	## or holds now, once the stone has fired.
	if _stone_fired():
		return int(unit.get("block", 0))
	for effect in tier_now("Parapet").get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == "block" and effect.has("block_after"):
			return int(effect.block_after)
	return DeepRules.sat_add(int(unit.get("block", 0)), int(forecast().get("totals", {}).get("block", 0)))

func _read_kept() -> int:
	## How much of his Block will carry into next turn: what Retain covers of what he holds.
	var retain: int = int(unit.get("statuses", {}).get("retain", 0))
	if not _stone_fired():
		for tier_name in ["Parapet", "Keep"]:
			if not lit(tier_name):
				continue
			for effect in tier_now(tier_name).get("effects", []):
				if effect is Dictionary and str(effect.get("kind", "")) == "retain":
					retain = maxi(retain, int(effect.get("retain_after", 0)))
	return mini(_held(), retain)

func _sync_act() -> void:
	var up: bool = settled and not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	if planning:
		## His turn has come round: wall, spikes and gate are down.
		_wall_at = -1
		_spikes_at = -1
		_gate_at = -1
		_rams.clear()
	_kept_now = _read_kept() if up else 0
	_kept.visible = _kept_now > 0
	if _kept.visible:
		_kept_said.text = "%s kept" % DeepUi.number(_kept_now)
		_kept.reset_size()
	_evens = DeepHand.matching(reading(), func(value: int) -> bool: return value % 2 == 0) if up else []
	_ram.visible = up and planning
	if _ram.visible:
		_ram_hits = _held() / 10
		_ram_said.text = "×%s" % DeepUi.number(_ram_hits)
		var on: bool = lit("Ram")
		_ram_said.add_theme_color_override("font_color", Color.WHITE if on else STEEL)
		_ram.modulate = Color(1.0, 1.0, 1.0, 1.0 if on else 0.62)
		_ram.reset_size()

func _look_key() -> String:
	return "%d|%s|%d|%d|%d|%d|%s" % [_kept_now, str(_evens), _wall_at, _spikes_at, _gate_at, int(_chips_end()), str(_kept.position)]

func _kept_plate() -> Control:
	return Plates.words("Kept Block", "%s of your Block carries into next turn. Parapet keeps as much as it gives, and Keep holds all of it." % DeepUi.number(_kept_now), "rampart", RUST.lightened(0.3))

func _ram_plate() -> Control:
	return Plates.words("Ram", "One blow of Resonance for every 10 Block you hold as it fires. The rail comes to %s Block: %s." % [DeepUi.number(_held()), "no blow" if _ram_hits <= 0 else ("1 blow" if _ram_hits == 1 else "%s blows" % DeepUi.number(_ram_hits))], "four even dice", RUST.lightened(0.3))

# --- where things stand --------------------------------------------------------------------------

func _chips_end() -> float:
	## Where the chips and the party's tabs over the dock's top left end, in this act's own space.
	var end: float = -1.0
	var bar: Variant = screen.get("_tab_bar") if screen != null else null
	if not bar is Control or not is_instance_valid(bar):
		return end
	for tab in (bar as Control).get_children():
		if not tab is Control or not (tab as Control).is_visible_in_tree():
			continue
		var chips: Variant = tab.get("chips")
		if chips is Control and is_instance_valid(chips):
			for chip in (chips as Control).get_children():
				if chip is Control and (chip as Control).is_visible_in_tree():
					end = maxf(end, local((chip as Control).get_global_rect()).end.x)
		var face: Variant = tab.get("face")
		if face is Control and is_instance_valid(face) and (face as Control).is_visible_in_tree():
			end = maxf(end, local((face as Control).get_global_rect()).end.x)
	return end

func _tick(_delta: float) -> void:
	if _kept == null or not _kept.visible:
		return
	var ring: Rect2 = ring_rect()
	if ring.size.x <= 0.0:
		return
	var wide: Vector2 = _kept.get_combined_minimum_size()
	var at := Vector2.ZERO
	if DeepUi.phone:
		## In the row of chips over the ring, after the last of them.
		var row_end: float = _chips_end()
		at = Vector2(maxf(ring.position.x, row_end + DeepUi.pt(3.0)), dock_rect().position.y - wide.y - DeepUi.pt(2.5))
	else:
		## Beside the Block number at the top of the ring (or where it would be).
		var badge: Rect2 = block_rect()
		if badge.size.x > 0.0:
			at = Vector2(badge.end.x + 4.0, badge.get_center().y - wide.y * 0.5)
		else:
			at = Vector2(ring.get_center().x + 6.0, ring.position.y - wide.y * 0.5)
	var left: float = DeepUi.safe_left if DeepUi.phone else 4.0
	var right: float = size.x - (DeepUi.safe_right if DeepUi.phone else 4.0)
	at.x = clampf(at.x, left, maxf(left, right - wide.x))
	at.y = maxf(at.y, 4.0)
	if not _kept.position.is_equal_approx(at):
		_kept.position = at

func _wall_span() -> Vector2:
	## The stretch of the dock's top edge the course is laid along (x from, x to): from past the
	## ring and whatever stands over it to just past the Birthstone.
	var ring: Rect2 = ring_rect()
	var stone_at: Rect2 = stone_rect()
	var from: float = maxf(ring.end.x, _chips_end()) + u(12.0, 6.0)
	if DeepUi.phone and _kept != null and _kept.visible:
		from = maxf(from, _kept.position.x + _kept.size.x + u(12.0, 6.0))
	var to: float = stone_at.end.x + u(10.0, 5.0) if stone_at.size.x > 0.0 else tray_rect().position.x - u(24.0, 12.0)
	return Vector2(from, to)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	_draw_die_slabs()
	_draw_wall(now)
	_draw_rams(now)
	_draw_shards(now)
	_draw_gate(now)

func _slab(box: Rect2, alpha: float = 1.0) -> void:
	## One slab of hematite: a dark iron-red block, its top face catching the light.
	if box.size.x < 4.0 or box.size.y < 3.0:
		return
	var lip: float = box.size.y * 0.34
	draw_rect(box, Color(IRON.darkened(0.3), alpha))
	draw_colored_polygon(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), Vector2(box.end.x - lip, box.position.y + lip), Vector2(box.position.x + lip, box.position.y + lip)]), Color(RUST, alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(box.end.x, box.position.y), box.end, Vector2(box.end.x - lip, box.end.y), Vector2(box.end.x - lip, box.position.y + lip)]), Color(IRON.darkened(0.55), alpha))
	draw_rect(box, Color(DARK, alpha), false, maxf(1.0, u(1.5, 0.75)))

func _draw_die_slabs() -> void:
	## Every even die sits on a slab, until the slabs have gone up into the wall.
	if _wall_at >= 0:
		return
	for id in _evens:
		var seat: Rect2 = die_rect(str(id))
		var face: Rect2 = die_face(str(id))
		if seat.size.x <= 0.0:
			continue
		var room: float = seat.end.y - face.end.y
		var tall: float = clampf(room * 0.55, u(5.0, 2.5), u(9.0, 4.5))
		_slab(Rect2(face.position.x + face.size.x * 0.06, face.end.y + room * 0.2, face.size.x * 0.88, tall))

func _shove(now: int) -> Vector2:
	## How far the wall is thrown forward by Ram just now: out fast, back slower.
	if _lunge_at < 0:
		return Vector2.ZERO
	var since: float = float(now - _lunge_at) / 1000.0
	if since > 0.24:
		return Vector2.ZERO
	var out: float = since / 0.05 if since < 0.05 else 1.0 - (since - 0.05) / 0.19
	return _lunge_way * u(20.0, 10.0) * out

static func _back(x: float) -> float:
	## Out past the end and back to it: a spike snapping out, a gate landing.
	var past: float = 1.70158
	var from_end: float = x - 1.0
	return 1.0 + (past + 1.0) * from_end * from_end * from_end + past * from_end * from_end

func _draw_wall(now: int) -> void:
	## The course: slabs side by side on the dock's top edge, each falling into place after the
	## one before it, and Thornwork's spikes standing out of their tops.
	if _wall_at < 0:
		return
	var span: Vector2 = _wall_span()
	if span.y - span.x < u(120.0, 60.0):
		return
	var foot: float = dock_rect().position.y + u(3.0, 1.5)
	var tall: float = u(16.0, 8.0)
	var count: int = clampi(int(round((span.y - span.x) / u(98.0, 52.0))), 3, 10)
	var wide: float = (span.y - span.x) / float(count)
	var since: float = float(now - _wall_at) / 1000.0
	var since_spikes: float = float(now - _spikes_at) / 1000.0 if _spikes_at >= 0 else -1.0
	var shove: Vector2 = _shove(now)
	var spike_wide: float = u(15.0, 7.5)
	var spike_tall: float = u(15.0, 7.5)
	for index in range(count):
		var landed: float = clampf((since - STACK_GAP * float(index)) / DROP, 0.0, 1.0)
		if landed <= 0.0:
			continue
		var fall: float = (1.0 - landed * landed) * u(44.0, 22.0)
		var box := Rect2(Vector2(span.x + wide * float(index) + u(1.5, 0.75), foot - tall - fall) + shove, Vector2(wide - u(3.0, 1.5), tall))
		if since_spikes >= 0.0:
			for spike in range(2):
				var out: float = clampf((since_spikes - 0.012 * float(index * 2 + spike)) / SPIKE_SNAP, 0.0, 1.0)
				if out <= 0.0:
					continue
				var reach: float = spike_tall * _back(out)
				var middle: float = box.position.x + box.size.x * (0.27 + 0.46 * float(spike))
				var tip_at := Vector2(middle, box.position.y - reach)
				var base_y: float = box.position.y + 1.0
				draw_colored_polygon(PackedVector2Array([Vector2(middle - spike_wide * 0.5, base_y), Vector2(middle, base_y), tip_at]), STEEL)
				draw_colored_polygon(PackedVector2Array([Vector2(middle, base_y), Vector2(middle + spike_wide * 0.5, base_y), tip_at]), STEEL.darkened(0.45))
				draw_polyline(PackedVector2Array([Vector2(middle - spike_wide * 0.5, base_y), tip_at, Vector2(middle + spike_wide * 0.5, base_y)]), DARK, maxf(1.0, u(1.5, 0.75)), true)
		_slab(box, landed)

func _bolt_at(from: Vector3, to: Vector3, along: float) -> Vector3:
	## Where the screen's own bolt is on its way (battle_fx.gd `projectile`: slow off the mark,
	## bowed a little upward), so what rides it stays with its light.
	var eased: float = along * along
	var control: Vector3 = (from + to) * 0.5 + Vector3(0.0, 0.85, 0.0)
	return from.lerp(control, eased).lerp(control.lerp(to, eased), eased)

func _draw_rams(now: int) -> void:
	## A slab of the wall on its way into a creature, smaller as it goes, and iron off it as it lands.
	for ram in _rams.duplicate():
		var along: float = float(now - int(ram.at)) / 1000.0 / RAM_FLIGHT
		if along >= 1.0:
			_rams.erase(ram)
			burst(screen_point(ram.to), RUST, 14, 190.0, 0.45, 5.0)
			continue
		var at: Vector2 = screen_point(_bolt_at(ram.from, ram.to, along))
		var shrink: float = lerpf(1.0, 0.5, along)
		var box := Vector2(u(84.0, 44.0), u(22.0, 11.0)) * shrink
		_slab(Rect2(at - box * 0.5, box))

func _draw_shards(now: int) -> void:
	## An iron shard flying back up a creature's own line of attack.
	for shard in _shards.duplicate():
		var along: float = float(now - int(shard.at)) / 1000.0 / SHARD_FLIGHT
		if along >= 1.0:
			_shards.erase(shard)
			burst(shard.to, STEEL, 10, 150.0, 0.4, 4.0)
			continue
		var from: Vector2 = shard.from
		var to: Vector2 = shard.to
		var way: Vector2 = (to - from).normalized()
		var side: Vector2 = way.orthogonal() * u(5.0, 2.5)
		var head: Vector2 = from.lerp(to, along)
		var tail: Vector2 = head - way * u(46.0, 23.0)
		draw_colored_polygon(PackedVector2Array([head, tail + side, tail - side * 0.4]), STEEL)
		draw_colored_polygon(PackedVector2Array([head, tail - side * 0.4, tail - side]), STEEL.darkened(0.45))
		draw_line(tail, tail - way * u(40.0, 20.0), Color(STEEL, 0.35), maxf(1.0, u(2.0, 1.0)), true)

func _gate_rect() -> Rect2:
	## What the portcullis comes down across: the Block number, and the kept plate where it
	## stands beside it.
	var over: Rect2 = block_rect()
	if _kept != null and _kept.visible and (not DeepUi.phone or over.size.x <= 0.0):
		var kept_at := Rect2(_kept.position, _kept.size)
		over = over.merge(kept_at) if over.size.x > 0.0 else kept_at
	return over.grow(u(3.0, 1.5)) if over.size.x > 0.0 else over

func _draw_gate(now: int) -> void:
	## Keep's portcullis: iron bars let down over the Block he will not lose.
	if _gate_at < 0:
		return
	var over: Rect2 = _gate_rect()
	if over.size.x <= 0.0:
		return
	var since: float = float(now - _gate_at) / 1000.0
	var down: float = clampf(since / GATE_DROP, 0.0, 1.0)
	var lift: float = (1.0 - down * down) * (over.size.y + u(26.0, 13.0))
	if since > GATE_DROP:
		lift = absf(sin((since - GATE_DROP) * 24.0)) * exp(-(since - GATE_DROP) * 10.0) * u(6.0, 3.0)
	var bar: float = maxf(1.5, u(2.0, 1.0))
	var tone := Color(STEEL.darkened(0.3), 0.92 * clampf(since / 0.06, 0.0, 1.0))
	var top: float = over.position.y - lift
	var bars: int = maxi(3, int(round(over.size.x / u(10.0, 5.5))))
	for index in range(bars + 1):
		var x: float = over.position.x + over.size.x * float(index) / float(bars)
		draw_line(Vector2(x, top), Vector2(x, top + over.size.y), tone, bar, true)
		draw_colored_polygon(PackedVector2Array([Vector2(x - bar * 1.2, top + over.size.y), Vector2(x + bar * 1.2, top + over.size.y), Vector2(x, top + over.size.y + bar * 2.4)]), tone)
	for share in [0.0, 0.5, 1.0]:
		var y: float = top + over.size.y * float(share)
		draw_line(Vector2(over.position.x - bar, y), Vector2(over.end.x + bar, y), tone, bar * (1.6 if float(share) == 0.0 else 1.0), true)

# --- the stone fires -----------------------------------------------------------------------------

func _stand(now: int) -> void:
	## The course is up, however it came to be: a tier that builds on it finds it standing.
	if _wall_at < 0:
		_wall_at = now

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var now: int = Time.get_ticks_msec()
	match str(entry.get("name", "")):
		"Parapet":
			## Slabs stack into a course along the dock, a thud for each.
			_wall_at = now
			busy(STACK_GAP * 10.0 + DROP + 0.3)
			for thud in range(5):
				later(DROP + STACK_GAP * 2.0 * float(thud), sound.bind("die_drop", {"volume": 0.5, "pitch": 0.62 + 0.03 * float(thud), "gap": 0.0}))
			land(effects, origin, tone)
			return true
		"Thornwork":
			## Spikes snap out of the wall's top.
			_stand(0)
			_spikes_at = now
			busy(SPIKE_SNAP + 0.5)
			sound("hammer_strike", {"volume": 0.32, "pitch": 1.6, "gap": 0.0})
			land(effects, origin, tone)
			return true
		"Ram":
			return _ram_tier(effects, origin, tone)
		"Keep":
			## The portcullis comes down over the Block plate.
			_gate_at = now
			busy(GATE_DROP + 0.6)
			sound("hammer_strike", {"volume": 0.45, "pitch": 0.8, "gap": 0.0})
			later(GATE_DROP, func() -> void:
				var over: Rect2 = _gate_rect()
				if over.size.x > 0.0:
					burst(Vector2(over.get_center().x, over.end.y), STEEL, 10, 110.0, 0.4, 4.0)
					say(Vector2(over.get_center().x, over.position.y - u(26.0, 13.0)), "All Block kept", STEEL, text_px(16, 12)))
			return true
	return false

func _ram_tier(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The wall is thrown forward once a blow, and a slab of it rides each bolt into the target.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	_stand(0)
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var gap: float = DeepBattle.HIT_STEP * DeepBattle.hit_pace(effects)
	for index in range(blows.size()):
		later(gap * float(index), _ram_blow.bind(blows[index], tone))
	if not rest.is_empty():
		later(gap * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _ram_blow(hit: Dictionary, tone: Color) -> void:
	var span: Vector2 = _wall_span()
	var top := Vector2((span.x + span.y) * 0.5, dock_rect().position.y - u(14.0, 7.0))
	var target: String = str(hit.get("target", target_id()))
	var aim: Vector2 = creature_at(target)
	## It leaves the wall under the creature it is for, as far as the wall reaches.
	top.x = clampf(aim.x, span.x + u(60.0, 30.0), maxf(span.x + u(60.0, 30.0), span.y - u(60.0, 30.0)))
	_lunge_way = (aim - top).normalized() if aim.distance_to(top) > 1.0 else Vector2.UP
	_lunge_at = Time.get_ticks_msec()
	busy(RAM_FLIGHT + 0.5)
	var from: Vector3 = room_point(top, 2.2)
	if not DeepUi.headless():
		_rams.append({"from": from, "to": creature_point(target), "at": _lunge_at})
	sound("die_drop", {"volume": 0.6, "pitch": 0.5, "gap": 0.0})
	land([hit], from, tone)

func _event(played: Dictionary) -> void:
	var kind: String = str(played.get("kind", ""))
	var me: String = str(unit.get("id", ""))
	match kind:
		"turn_begin":
			_wall_at = -1
			_spikes_at = -1
			_gate_at = -1
		"rail_end":
			## What the stone raised stands for the creatures' turn whether or not it was
			## watched going up (another player's page was in the dock).
			if str(played.get("unit", "")) == me and not me.is_empty() and _stone_fired():
				if lit("Parapet") and _wall_at < 0:
					_wall_at = 0
				if lit("Thornwork") and _spikes_at < 0:
					_spikes_at = 0
				if lit("Keep") and _gate_at < 0:
					_gate_at = 0
				queue_redraw()
		"enemy_move":
			## A blow that landed on him through Thornwork: a shard of the spikes goes back at it.
			if _spikes_at < 0 or DeepUi.headless() or not on_screen():
				return
			for effect in played.get("effects", []):
				if effect is Dictionary and effect.get("spikes", null) is Dictionary and str(effect.get("target", "")) == me:
					_throw_back(str(effect.spikes.get("target", played.get("unit", ""))))

func _throw_back(creature_id: String) -> void:
	var to: Vector2 = creature_at(creature_id)
	var span: Vector2 = _wall_span()
	var from := Vector2(clampf(to.x, span.x, maxf(span.x, span.y)), dock_rect().position.y - u(22.0, 11.0))
	_shards.append({"from": from, "to": to, "at": Time.get_ticks_msec()})
	busy(SHARD_FLIGHT + 0.4)
	sound("hammer_strike", {"volume": 0.28, "pitch": 1.8, "gap": 0.0})
