extends "res://view/battle/birth_act.gd"
## Ardor's Rampart: even dice raise a wall, and the wall is the weapon.
##
## While the hand is planned every even die sits on a slab of hematite, the Block badge on his
## health ring grows into one pill saying how much of his Block will be kept into next turn
## ("54 · 54 kept", centred on the ring as the badge is), and a chip
## over the stone counts the blows Ram would land at the Block the rail comes to (bright once
## the hand reaches Ram). When the stone fires, Parapet drops a course of dressed hematite blocks
## along the top of the dock, each with a thud and a puff of dust, Thornwork snaps iron spikes
## out of it (and a shard of them flies back at any creature whose blow then lands on him), Ram
## lifts the course and lunges it at the target once a blow, a block breaking off and thrown on a
## lob to land on the creature heavily (the course settles back and the gap fills again), and
## Keep slams a small iron portcullis down over that pill. Wall, spikes and gate stand until his
## next turn, as what they stand for does.
##
## Both layouts draw the same pieces, the phone's at half the size.

const IRON := Color("7b3b40")
const RUST := Color("b5524a")
const DARK := Color("1f0f12")
const STEEL := Color("d2c9cb")
const HEMATITE := Color("3a272c")
const HEMATITE_FACE := Color("54393f")
const HEMATITE_HI := Color("a08184")
const MORTAR := Color("140a0c")
const GATE_IRON := Color("3d3a42")
const DUST := Color("a8968e")
## A block falls into the course this long after the one before it, and takes this long to land.
const STACK_GAP: float = 0.055
const DROP: float = 0.12
const SPIKE_SNAP: float = 0.16
## Ram's beat, once a blow: the course lifts (LIFT), lunges at the target (LUNGE) and settles
## back onto its bed (SETTLE); a block breaks off at BREAK_AT and is thrown for RAM_FLIGHT; the
## gap it left fills again REGROW after.
const LIFT: float = 0.09
const LUNGE: float = 0.06
const SETTLE: float = 0.34
const BREAK_AT: float = 0.12
const RAM_FLIGHT: float = 0.3
const REGROW: float = 0.55
const GATE_DROP: float = 0.16
const SHARD_FLIGHT: float = 0.16
const DUST_SECONDS: float = 0.5

var _kept: PanelContainer = null
var _kept_said: Label = null
## The Block number and its shield in the kept pill (a copy of the badge's own, kept in step).
var _kept_block: Label = null
var _kept_shield: Control = null
var _kept_dot: Label = null
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
## Blocks thrown at a creature ({from, to, at, size, spin, seed}), shards flying back ({from,
## to, at}), dust kicked up ({at, ms, wide}), and the blocks of the course Ram broke off
## (index: ticks when), gaps until they drop back in.
var _rams: Array = []
## Keep's portcullis is drawn on this child, over the kept plate and the Block badge.
var _gate_layer: Control = null
var _shards: Array = []
var _dust: Array = []
var _broken: Dictionary = {}

class GateLayer extends Control:
	## The portcullis's own canvas, above the act's plates.
	var act: Control = null
	func _draw() -> void:
		if act != null and is_instance_valid(act):
			act._draw_gate(self, Time.get_ticks_msec())

func _open() -> void:
	## The kept figure and the Block badge as one pill, laid exactly over the badge at the top
	## of his health ring and centred on it: the shield and his Block as the badge has them,
	## then what of it carries into next turn.
	_kept = PanelContainer.new()
	_kept.add_theme_stylebox_override("panel", DeepUi.capsule(_kept, Color("0b1a33"), DeepUi.BLOCK, 2, 12, 1))
	_kept.z_index = 5
	var pill := DeepUi.hbox(_kept, 4)
	pill.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kept_shield = DeepUi.icon(pill, "shield", 13, DeepUi.BLOCK)
	_kept_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kept_block = DeepUi.label(pill, "", 14, Color("dbe8ff"))
	_kept_block.add_theme_font_override("font", DeepUi.bold_font())
	_kept_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kept_dot = DeepUi.label(pill, "·", 14, Color(STEEL, 0.6))
	_kept_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kept_said = DeepUi.label(pill, "", 12, RUST.lightened(0.45))
	_kept_said.add_theme_font_override("font", DeepUi.bold_font())
	_kept_said.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var layer := GateLayer.new()
	layer.act = self
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 30
	## No size of its own (nothing to press, nothing to lay out): it only draws, from the act's
	## own corner, so what it draws stands where the act's rects say.
	add_child(layer)
	layer.position = Vector2.ZERO
	layer.size = Vector2.ZERO
	_gate_layer = layer

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
		_broken.clear()
		_lunge_at = -1
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

func _badge() -> Control:
	## The dock's Block badge on his health ring, shown or not.
	var badge: Variant = page.status_row if page != null else null
	return badge if badge is Control and is_instance_valid(badge) else null

func _tick(_delta: float) -> void:
	if _kept == null or not _kept.visible:
		return
	var ring: Rect2 = ring_rect()
	if ring.size.x <= 0.0:
		return
	## The badge's own number, as it counts up while Block lands.
	var badge: Control = _badge()
	var showing: bool = badge != null and badge.is_visible_in_tree()
	var number: String = ""
	if showing:
		for found in badge.find_children("*", "Label", true, false):
			number = (found as Label).text
			break
	var with_block: bool = not number.is_empty()
	if _kept_block.text != number or _kept_block.visible != with_block:
		_kept_block.text = number
		_kept_block.visible = with_block
		_kept_shield.visible = with_block
		_kept_dot.visible = with_block
		_kept.reset_size()
	var wide: Vector2 = _kept.get_combined_minimum_size()
	if showing:
		wide.y = maxf(wide.y, badge.size.y)
	if not _kept.size.is_equal_approx(wide):
		_kept.size = wide
	## Centred on the badge where it stands (the top of the ring), standing in for it.
	var middle := Vector2(ring.get_center().x, ring.position.y + 1.0)
	if showing:
		middle = local(badge.get_global_rect()).get_center()
	var at: Vector2 = (middle - wide * 0.5).round()
	if not _kept.position.is_equal_approx(at):
		_kept.position = at
	## It jumps as the badge does when Block is gained.
	_kept.pivot_offset = wide * 0.5
	_kept.scale = badge.scale if showing else Vector2.ONE

func _wall_span() -> Vector2:
	## The stretch of the dock's top edge the course is laid along (x from, x to): from past the
	## ring and whatever stands over it to just past the Birthstone.
	var ring: Rect2 = ring_rect()
	var stone_at: Rect2 = stone_rect()
	var from: float = maxf(ring.end.x, _chips_end()) + u(12.0, 6.0)
	var to: float = stone_at.end.x + u(10.0, 5.0) if stone_at.size.x > 0.0 else tray_rect().position.x - u(24.0, 12.0)
	return Vector2(from, to)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if _gate_layer != null:
		_gate_layer.queue_redraw()
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	_draw_die_slabs()
	_draw_wall(now)
	_draw_rams(now)
	_draw_shards(now)
	_draw_dust(now)

func _slab(box: Rect2, alpha: float = 1.0) -> void:
	## One slab of hematite: a dark iron-red block, its top face catching the light.
	if box.size.x < 4.0 or box.size.y < 3.0:
		return
	var lip: float = box.size.y * 0.34
	draw_rect(box, Color(IRON.darkened(0.3), alpha))
	draw_colored_polygon(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), Vector2(box.end.x - lip, box.position.y + lip), Vector2(box.position.x + lip, box.position.y + lip)]), Color(RUST, alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(box.end.x, box.position.y), box.end, Vector2(box.end.x - lip, box.end.y), Vector2(box.end.x - lip, box.position.y + lip)]), Color(IRON.darkened(0.55), alpha))
	draw_rect(box, Color(DARK, alpha), false, maxf(1.0, u(1.5, 0.75)))

func _block(box: Rect2, alpha: float = 1.0, seed_at: int = 0) -> void:
	## One dressed block of the course: hematite's dark iron grey-red face, a bevel along its top
	## catching the light with a bright arris, the foot and the right side in shadow, a glint of
	## the metal's sheen, and a dark edge round it all.
	if box.size.x < 4.0 or box.size.y < 3.0 or alpha <= 0.0:
		return
	var bevel: float = box.size.y * 0.26
	var side: float = minf(box.size.x * 0.1, box.size.y * 0.22)
	var foot: float = box.size.y * 0.16
	draw_rect(box, Color(HEMATITE, alpha))
	## Top bevel, the right side's shadow, the foot's.
	draw_colored_polygon(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), Vector2(box.end.x - side, box.position.y + bevel), Vector2(box.position.x + side * 0.6, box.position.y + bevel)]), Color(HEMATITE_HI, alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(box.end.x, box.position.y), box.end, Vector2(box.end.x - side, box.end.y - foot), Vector2(box.end.x - side, box.position.y + bevel)]), Color(HEMATITE.darkened(0.45), alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(box.position.x, box.end.y), Vector2(box.position.x + side * 0.6, box.end.y - foot), Vector2(box.end.x - side, box.end.y - foot), box.end]), Color(HEMATITE.darkened(0.6), alpha))
	draw_colored_polygon(PackedVector2Array([box.position, Vector2(box.position.x + side * 0.6, box.position.y + bevel), Vector2(box.position.x + side * 0.6, box.end.y - foot), Vector2(box.position.x, box.end.y)]), Color(HEMATITE.lightened(0.08), alpha))
	draw_line(box.position + Vector2(1.0, 0.5), Vector2(box.end.x - 1.0, box.position.y + 0.5), Color(STEEL, 0.8 * alpha), maxf(1.0, u(1.5, 0.75)), true)
	## The metal's sheen: the upper half of the face a shade brighter than the lower, and a
	## soft band of light across it, set a little apart on each block.
	var face := Rect2(Vector2(box.position.x + side * 0.6, box.position.y + bevel), Vector2(box.size.x - side * 1.6, (box.size.y - bevel - foot) * 0.5))
	draw_rect(face, Color(HEMATITE_FACE, alpha))
	var glint: float = 0.18 + 0.5 * fposmod(float(seed_at) * 0.618, 1.0)
	var band: float = box.size.x * 0.16
	var gx: float = box.position.x + box.size.x * glint
	var lean: float = (box.size.y - bevel - foot) * 0.6
	draw_colored_polygon(PackedVector2Array([Vector2(gx, box.position.y + bevel), Vector2(gx + band, box.position.y + bevel), Vector2(gx + band - lean, box.end.y - foot), Vector2(gx - lean, box.end.y - foot)]), Color(STEEL, 0.1 * alpha))
	draw_rect(box, Color(DARK, alpha), false, maxf(1.0, u(2.0, 1.0)))

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

func _course() -> Array:
	## The blocks of the course where they stand (Rect2 each, left to right): one even row on
	## the dock's top edge, the blocks a little unlike in width as dressed stone is, a joint of
	## mortar between each. Empty where there is no room for a wall.
	var span: Vector2 = _wall_span()
	if span.y - span.x < u(120.0, 60.0):
		return []
	var foot: float = dock_rect().position.y + u(3.0, 1.5)
	var tall: float = u(20.0, 10.0)
	var count: int = clampi(int(round((span.y - span.x) / u(66.0, 34.0))), 3, 12)
	var shares: Array = []
	var total: float = 0.0
	for index in range(count):
		var share: float = 1.0 + 0.22 * sin(float(index) * 2.39 + 0.7)
		shares.append(share)
		total += share
	var joint: float = maxf(2.0, u(3.0, 1.5))
	var out: Array = []
	var x: float = span.x
	for index in range(count):
		var wide: float = (span.y - span.x) * float(shares[index]) / total
		out.append(Rect2(Vector2(x + joint * 0.5, foot - tall), Vector2(wide - joint, tall)))
		x += wide
	return out

func _shove(now: int) -> Vector2:
	## Where Ram has the course just now: lifted off the dock, thrown at the target, and let
	## back down onto its bed (it is not spent).
	if _lunge_at < 0:
		return Vector2.ZERO
	var since: float = float(now - _lunge_at) / 1000.0
	var lift := Vector2(0.0, -u(8.0, 4.0))
	var reach: Vector2 = _lunge_way * u(20.0, 10.0)
	if since < LIFT:
		var k: float = since / LIFT
		return lift * (1.0 - (1.0 - k) * (1.0 - k))
	if since < LIFT + LUNGE:
		var k: float = (since - LIFT) / LUNGE
		return lift.lerp(lift * 0.5 + reach, k * k)
	var back: float = (since - LIFT - LUNGE) / SETTLE
	if back >= 1.0:
		return Vector2.ZERO
	var held: Vector2 = lift * 0.5 + reach
	## Down onto the bed with a small bump past it as it lands.
	var ease_back: float = 1.0 - (1.0 - back) * (1.0 - back)
	return held * (1.0 - ease_back) + Vector2(0.0, u(2.0, 1.0)) * sin(back * PI) * back

func _streak(now: int) -> float:
	## How strongly the course's lunge leaves streaks behind it just now.
	if _lunge_at < 0:
		return 0.0
	var since: float = float(now - _lunge_at) / 1000.0
	if since < LIFT * 0.6 or since > LIFT + LUNGE + 0.12:
		return 0.0
	return clampf((since - LIFT * 0.6) / 0.04, 0.0, 1.0) * clampf((LIFT + LUNGE + 0.12 - since) / 0.12, 0.0, 1.0)

static func _back(x: float) -> float:
	## Out past the end and back to it: a spike snapping out, a gate landing.
	var past: float = 1.70158
	var from_end: float = x - 1.0
	return 1.0 + (past + 1.0) * from_end * from_end * from_end + past * from_end * from_end

func _draw_wall(now: int) -> void:
	## The course: blocks side by side on the dock's top edge in a dark bed of mortar, each
	## falling into place after the one before it, Thornwork's spikes standing out of their tops.
	## Under Ram the whole course lifts and lunges, streaking, and the block that broke off is a
	## gap in it until it drops back in.
	if _wall_at < 0:
		return
	var course: Array = _course()
	if course.is_empty():
		return
	var since: float = float(now - _wall_at) / 1000.0
	var since_spikes: float = float(now - _spikes_at) / 1000.0 if _spikes_at >= 0 else -1.0
	var shove: Vector2 = _shove(now)
	var streak: float = _streak(now)
	var spike_wide: float = u(10.0, 5.0)
	var spike_tall: float = u(10.0, 5.0)
	var joint: float = maxf(2.0, u(3.0, 1.5))
	## The bed: dark mortar behind every block that has landed, so the joints read dark.
	var bed_end: float = -1.0
	for index in range(course.size()):
		if since - STACK_GAP * float(index) >= DROP:
			bed_end = (course[index] as Rect2).end.x + joint * 0.5
	if bed_end > 0.0:
		var first: Rect2 = course[0]
		var bed := Rect2(Vector2(first.position.x - joint * 0.5, first.position.y - joint * 0.25) + shove, Vector2(bed_end - first.position.x + joint * 0.5, first.size.y + joint * 0.5))
		draw_rect(bed, Color(MORTAR, 0.94))
	for index in range(course.size()):
		var home: Rect2 = course[index]
		var landed: float = clampf((since - STACK_GAP * float(index)) / DROP, 0.0, 1.0)
		if _broken.has(index):
			var gone: float = float(now - int(_broken[index])) / 1000.0
			if gone < REGROW:
				continue
			landed = minf(landed, clampf((gone - REGROW) / DROP, 0.0, 1.0))
			if landed >= 1.0:
				_broken.erase(index)
		if landed <= 0.0:
			continue
		var fall: float = (1.0 - landed * landed) * u(30.0, 15.0)
		var box := Rect2(home.position + Vector2(0.0, -fall) + shove, home.size)
		if streak > 0.0:
			## Streaks behind the lunge, never down past the dock's top edge into the rail.
			var behind: Vector2 = -_lunge_way * u(30.0, 15.0) * streak
			var floor_y: float = dock_rect().position.y + u(2.0, 1.0)
			for share in [0.2, 0.5, 0.8]:
				var from := Vector2(box.position.x + box.size.x * float(share), box.get_center().y)
				var to: Vector2 = from + behind
				if to.y > floor_y and absf(behind.y) > 0.5:
					to = from + behind * clampf((floor_y - from.y) / behind.y, 0.0, 1.0)
				draw_line(from, to, Color(STEEL, 0.32 * streak), maxf(1.0, u(2.0, 1.0)), true)
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
		_block(box, landed, index)

func _arc_at(ram: Dictionary, along: float) -> Vector2:
	## Where a thrown block is on its lob: up off the wall, over, and down into the creature.
	var from: Vector2 = ram.from
	var to: Vector2 = ram.to
	var top: Vector2 = (from + to) * 0.5 + Vector2(0.0, -u(110.0, 55.0))
	return from.lerp(top, along).lerp(top.lerp(to, along), along)

func _draw_rams(now: int) -> void:
	## A block broken off the wall on its lob into a creature: tumbling, smaller as it goes into
	## the room, a streak of grit behind it.
	for ram in _rams.duplicate():
		var along: float = float(now - int(ram.at)) / 1000.0 / RAM_FLIGHT
		if along >= 1.0:
			_rams.erase(ram)
			continue
		if along < 0.0:
			continue
		var eased: float = along * (0.55 + 0.45 * along)
		var at: Vector2 = _arc_at(ram, eased)
		for back in range(1, 6):
			var was: float = maxf(0.0, eased - 0.045 * float(back))
			var then: Vector2 = _arc_at(ram, was)
			var nearer: Vector2 = _arc_at(ram, maxf(0.0, eased - 0.045 * float(back - 1)))
			draw_line(nearer, then, Color(RUST.lightened(0.2), 0.42 * (1.0 - float(back) / 6.0)), u(11.0, 5.5) * (1.0 - float(back) / 6.0) * lerpf(1.15, 0.6, along), true)
		var size_now: Vector2 = (ram.size as Vector2) * lerpf(1.15, 0.6, along)
		draw_set_transform(at, float(ram.spin) * along, Vector2.ONE)
		_block(Rect2(-size_now * 0.5, size_now), 1.0, int(ram.seed))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

func _puff(at: Vector2, wide: float) -> void:
	## A small cloud of dust kicked up where something heavy has come down.
	if DeepUi.headless():
		return
	_dust.append({"at": at, "ms": Time.get_ticks_msec(), "wide": wide})
	busy(DUST_SECONDS + 0.1)

func _draw_dust(now: int) -> void:
	## Dust: a few soft grey clouds rolling out from where it was kicked up, rising and thinning.
	for puff in _dust.duplicate():
		var t: float = float(now - int(puff.ms)) / 1000.0 / DUST_SECONDS
		if t >= 1.0:
			_dust.erase(puff)
			continue
		var at: Vector2 = puff.at
		var wide: float = puff.wide
		var out: float = 1.0 - (1.0 - t) * (1.0 - t)
		for cloud in range(5):
			var lean: float = (float(cloud) - 2.0) / 2.0
			var spot: Vector2 = at + Vector2(lean * wide * (0.35 + 0.65 * out), -wide * 0.25 * out * (1.0 - absf(lean) * 0.5))
			var radius: float = wide * (0.16 + 0.22 * out) * (1.0 - absf(lean) * 0.3)
			draw_circle(spot, radius, Color(DUST, 0.34 * (1.0 - t) * (1.0 - t)))

func _gate_rect() -> Rect2:
	## What the portcullis comes down across: the Block badge, or the kept pill standing over
	## it, no wider than that and a little taller, centred on his health ring.
	var over: Rect2 = block_rect()
	if _kept != null and _kept.visible:
		over = Rect2(_kept.position, _kept.size)
	if over.size.x <= 0.0:
		return over
	if DeepUi.phone:
		## The row of chips sits right over the pill: the head beam comes down inside it.
		var beam: float = maxf(1.5, u(3.0, 1.5)) * 1.4 + DeepUi.pt(1.0)
		return Rect2(over.position + Vector2(u(2.0, 1.0), beam), over.size + Vector2(-u(4.0, 2.0), u(2.0, 2.0) - beam))
	return Rect2(over.position + Vector2(u(2.0, 1.0), -u(3.0, 1.5)), over.size + Vector2(-u(4.0, 2.0), u(4.0, 2.0)))

func _iron_bar(on: CanvasItem, from: Vector2, to: Vector2, thick: float, alpha: float) -> void:
	## One bar of the portcullis: black iron with a dark edge and a cold light down one side.
	var edge: float = maxf(1.0, u(1.5, 0.75))
	on.draw_line(from, to, Color(DARK, alpha), thick + edge * 2.0, false)
	on.draw_line(from, to, Color(GATE_IRON, alpha), thick, false)
	var way: Vector2 = (to - from).normalized()
	var side: Vector2 = way.orthogonal() * thick * 0.25
	on.draw_line(from - side, to - side, Color(STEEL, 0.5 * alpha), maxf(1.0, thick * 0.3), false)

func _draw_gate(on: CanvasItem, now: int) -> void:
	## Keep's portcullis: an iron grate, spiked at its foot, slammed down over the Block he will
	## not lose. It bounces once as it lands and then stands there. Drawn on its own layer
	## over the act's plates and the dock's Block badge, so the bars lie across them.
	if _gate_at < 0 or unit.is_empty() or bool(unit.get("downed", false)):
		return
	var over: Rect2 = _gate_rect()
	if over.size.x <= 0.0:
		return
	var since: float = float(now - _gate_at) / 1000.0 if _gate_at > 0 else 99.0
	var down: float = clampf(since / GATE_DROP, 0.0, 1.0)
	var lift: float = (1.0 - down * down) * (over.size.y + u(44.0, 22.0))
	if since > GATE_DROP:
		lift = -absf(sin((since - GATE_DROP) * 26.0)) * exp(-(since - GATE_DROP) * 12.0) * u(4.0, 2.0)
	var alpha: float = clampf(since / 0.05, 0.0, 1.0)
	var thick: float = maxf(1.5, u(3.0, 1.5))
	var top: float = over.position.y - lift
	var foot: float = top + over.size.y
	var tine: float = u(5.0, 2.5)
	## A faint shade behind the bars, so the grate reads over the bright ring.
	on.draw_rect(Rect2(Vector2(over.position.x, top), over.size), Color(DARK, 0.12 * alpha))
	var bars: int = maxi(3, int(round(over.size.x / u(13.0, 8.0))))
	var crossing: Array = [top + over.size.y * 0.5]
	for y in crossing:
		_iron_bar(on, Vector2(over.position.x - thick * 0.5, float(y)), Vector2(over.end.x + thick * 0.5, float(y)), thick * 0.8, alpha)
	for index in range(bars + 1):
		var x: float = over.position.x + over.size.x * float(index) / float(bars)
		_iron_bar(on, Vector2(x, top), Vector2(x, foot), thick, alpha)
		var spike := PackedVector2Array([Vector2(x - thick * 0.95, foot - 1.0), Vector2(x + thick * 0.95, foot - 1.0), Vector2(x, foot + tine)])
		on.draw_colored_polygon(spike, Color(GATE_IRON.lightened(0.15), alpha))
		on.draw_polyline(PackedVector2Array([spike[0], spike[2], spike[1]]), Color(DARK, alpha), maxf(1.0, u(1.5, 0.75)), true)
		for y in crossing:
			on.draw_circle(Vector2(x, float(y)), thick * 0.55, Color(STEEL.darkened(0.1), alpha))
	## The head beam it hangs from.
	var beam := Rect2(Vector2(over.position.x - thick, top - thick * 1.4), Vector2(over.size.x + thick * 2.0, thick * 2.0))
	on.draw_rect(beam.grow(maxf(1.0, u(1.5, 0.75))), Color(DARK, alpha))
	on.draw_rect(beam, Color(GATE_IRON, alpha))
	on.draw_line(beam.position + Vector2(1.0, 1.0), Vector2(beam.end.x - 1.0, beam.position.y + 1.0), Color(STEEL, 0.6 * alpha), maxf(1.0, u(1.5, 0.75)), false)

# --- the stone fires -----------------------------------------------------------------------------

func _stand(now: int) -> void:
	## The course is up, however it came to be: a tier that builds on it finds it standing.
	if _wall_at < 0:
		_wall_at = now

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var now: int = Time.get_ticks_msec()
	match str(entry.get("name", "")):
		"Parapet":
			## Blocks drop into a course along the dock, a thud and a puff of dust for each.
			_wall_at = now
			_broken.clear()
			var count: int = _course().size()
			busy(STACK_GAP * float(count) + DROP + DUST_SECONDS)
			for index in range(count):
				later(DROP + STACK_GAP * float(index), _block_down.bind(index, 0.42, 0.62 + 0.03 * float(index)))
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
			## The portcullis slams down over the Block plate as the tier lands. Keep has no figure
			## of its own (its Retain is "all of it"), so nothing is landed: a "+0" would only confuse.
			_slam_gate()
			return true
	return false

func _slam_gate() -> void:
	## The portcullis slams down over the Block plate: a clang, dust off its foot, and a word.
	## Once a turn: a gate already let down this turn is not dropped again.
	if _gate_at > 0:
		return
	if DeepUi.headless() or not on_screen():
		if _gate_at < 0:
			_gate_at = 0
		return
	_gate_at = Time.get_ticks_msec()
	busy(GATE_DROP + 0.7)
	sound("hammer_strike", {"volume": 0.5, "pitch": 0.72, "delay": GATE_DROP, "gap": 0.0})
	sound("block", {"volume": 0.35, "pitch": 0.8, "delay": GATE_DROP, "gap": 0.0})
	later(GATE_DROP, func() -> void:
		var over: Rect2 = _gate_rect()
		if over.size.x > 0.0:
			_puff(Vector2(over.position.x, over.end.y), u(20.0, 10.0))
			_puff(Vector2(over.end.x, over.end.y), u(20.0, 10.0))
			burst(Vector2(over.get_center().x, over.end.y), STEEL, 10, 110.0, 0.4, 4.0)
			say(Vector2(over.get_center().x, over.position.y - u(30.0, 24.0)), "All Block kept", STEEL, text_px(16, 12)))

func _block_down(index: int, volume: float, pitch: float) -> void:
	## A block of the course has come down onto its bed: the thud and the dust off its foot.
	sound("die_drop", {"volume": volume, "pitch": pitch, "gap": 0.0})
	var course: Array = _course()
	if index < course.size():
		var box: Rect2 = course[index]
		_puff(Vector2(box.position.x, box.end.y - box.size.y * 0.15), box.size.y * 1.1)
		_puff(Vector2(box.end.x, box.end.y - box.size.y * 0.15), box.size.y * 1.1)

func _ram_tier(effects: Array, origin: Vector3, tone: Color) -> bool:
	## Once a blow, the wall lifts and lunges at the target and a block breaks off it and is
	## thrown on a lob into the creature, landing heavily.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	_stand(0)
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var gap: float = DeepBattle.HIT_STEP * DeepBattle.hit_pace(effects)
	for index in range(blows.size()):
		later(gap * float(index), _ram_blow.bind(blows[index], tone, index))
	if not rest.is_empty():
		later(gap * float(blows.size()) + BREAK_AT + RAM_FLIGHT, land.bind(rest, origin, tone))
	return true

func _ram_blow(hit: Dictionary, tone: Color, blow: int) -> void:
	var target: String = str(hit.get("target", target_id()))
	if DeepUi.headless():
		land([hit], creature_point(target), tone)
		return
	var aim: Vector2 = creature_at(target)
	var course: Array = _course()
	var middle := Vector2(dock_rect().get_center().x, dock_rect().position.y)
	if not course.is_empty():
		var first: Rect2 = course[0]
		var last: Rect2 = course[course.size() - 1]
		middle = Vector2(clampf(aim.x, first.get_center().x, last.get_center().x), first.position.y)
	_lunge_way = (aim - middle).normalized() if aim.distance_to(middle) > 1.0 else Vector2.UP
	_lunge_at = Time.get_ticks_msec()
	busy(LIFT + LUNGE + SETTLE + 0.2)
	sound("die_drop", {"volume": 0.5, "pitch": 0.45, "gap": 0.0})
	later(BREAK_AT, _break_off.bind(hit, tone, target, blow))

func _break_off(hit: Dictionary, tone: Color, target: String, blow: int) -> void:
	## At the top of the lunge the block nearest the target comes away and is thrown.
	var course: Array = _course()
	var aim: Vector2 = creature_at(target)
	var pick: int = -1
	var best: float = INF
	for index in range(course.size()):
		var off: float = absf((course[index] as Rect2).get_center().x - aim.x) + (10000.0 if _broken.has(index) else 0.0)
		if off < best:
			best = off
			pick = index
	var now: int = Time.get_ticks_msec()
	var from: Vector2 = Vector2(dock_rect().get_center().x, dock_rect().position.y - u(20.0, 10.0))
	var size_of: Vector2 = Vector2(u(60.0, 30.0), u(20.0, 10.0))
	if pick >= 0:
		var box: Rect2 = course[pick]
		from = box.get_center() + _shove(now)
		size_of = box.size
		_broken[pick] = now
		later(REGROW, _block_down.bind(pick, 0.3, 0.7))
		busy(REGROW + DROP + DUST_SECONDS)
	_rams.append({"from": from, "to": aim, "at": now, "size": size_of, "spin": (0.9 if blow % 2 == 0 else -0.8), "seed": pick + blow})
	busy(RAM_FLIGHT + 0.3)
	sound("rock_break", {"volume": 0.3, "pitch": 1.3, "gap": 0.0})
	later(RAM_FLIGHT, _ram_lands.bind(hit, tone, target, aim))

func _ram_lands(hit: Dictionary, tone: Color, target: String, aim: Vector2) -> void:
	## The block comes down on the creature: the blow's number, iron shards, a crack and a flash.
	var at: Vector3 = creature_point(target)
	land([hit], _near(target), tone)
	sound("hit_heavy", {"volume": 0.55, "pitch": 0.8, "gap": 0.0})
	sound("rock_break", {"volume": 0.45, "pitch": 0.75, "gap": 0.0})
	burst(aim, RUST, 12, u(180.0, 90.0), 0.4, u(5.0, 2.5))
	if fx() != null:
		fx().shards(at, RUST, 10, 4.0, 0.14, 0.8)
		fx().flash(at, RUST.lightened(0.3), 5.0, 5.0, 0.28, 0.9)
		fx().puff(at + Vector3(0.0, -0.3, 0.0), DUST, 10, 0.8, 0.9, 0.5)

func _near(who: String) -> Vector3:
	## Just in front of a creature, toward the lens: the screen's bolt is thrown from here, so
	## the block is what is seen flying and the bolt is its flash on arrival.
	var at: Vector3 = creature_point(who)
	if screen != null and not DeepUi.headless() and screen._camera != null:
		var lens: Vector3 = screen._camera.global_position
		if lens.distance_to(at) > 1.0:
			return at + (lens - at).normalized() * 0.7
	return at

func _event(played: Dictionary) -> void:
	var kind: String = str(played.get("kind", ""))
	var me: String = str(unit.get("id", ""))
	match kind:
		"turn_begin":
			_wall_at = -1
			_broken.clear()
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
	var from := Vector2(clampf(to.x, span.x, maxf(span.x, span.y)), dock_rect().position.y - u(16.0, 8.0))
	_shards.append({"from": from, "to": to, "at": Time.get_ticks_msec()})
	busy(SHARD_FLIGHT + 0.4)
	sound("hammer_strike", {"volume": 0.28, "pitch": 1.8, "gap": 0.0})
