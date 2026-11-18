extends "res://view/battle/birth_act.gd"
## Ardor's Rally: a set of matching dice is a rank of the Knight's men.
##
## While the hand is planned, the dice of the set the hand has made are joined by a line in the
## gap under the tray, with a small faceted stud on it under each die of the set: two studs are a
## Rank, three a File, four a Phalanx, five a Legion, and line and studs take a brighter color
## with every rung, so the rung reached reads off the tray. Nothing is hung over a die. (Rampart's
## slabs stand under even dice; Rally's studs stand under a set.)
##
## Each rung has its moment as it lands. Rank closes a wall of shields over his health ring.
## File throws three spears in file from the set's dice into the target. Phalanx flashes the
## formation: the studs under the dice blaze gold one after another and a gold sigil stands on
## the creature it stuns. Legion runs a flare of gold along the line and its studs, and then
## every die of the set throws at once, a volley a blow.
##
## Both layouts draw the same pieces, the phone's at half the size.

const CRIMSON := Color("9a2323")
const RED_HI := Color("d8524a")
const STEEL := Color("d2c9cb")
const GILT := Color("e3b65a")
const DARK := Color("1d0b0b")
## The rungs, lowest first, and the color the line under the set takes at each.
const RUNGS: Array = ["Rank", "File", "Phalanx", "Legion"]
const RUNG_TONES: Array = [Color("d2c9cb"), Color("e0645a"), Color("e3b65a"), Color("ffd98a")]
const WALL_SECONDS: float = 0.95
const WALL_CLOSE: float = 0.18
const SPEAR_FLIGHT: float = 0.2
const FILE_GAP: float = 0.07
const VOLLEY_GAP: float = 0.04
const BLAZE_SECONDS: float = 0.8
## Legion's flare: the gold runs the line in FLARE_RUN, holds, and is gone by FLARE_SECONDS;
## the volley leaves once it has reached the far end.
const FLARE_RUN: float = 0.32
const FLARE_SECONDS: float = 0.9
const VOLLEY_LEAD: float = 0.38
const GILT_HI := Color("fff0bf")

## The dice of the set reached, left to right, and the rung (index of RUNGS, -1 for none).
var _set: Array = []
var _rung: int = -1
var _wall_at: int = -1
var _wall_count: int = 0
var _blaze_at: int = -1
var _flare_at: int = -1
## Spears in the air: {from, to, at, tone}.
var _spears: Array = []

# --- reading the hand ----------------------------------------------------------------------------

func _sync_act() -> void:
	_set = []
	_rung = -1
	if not settled or unit.get("hand", []).is_empty() or bool(unit.get("downed", false)):
		return
	for index in range(RUNGS.size() - 1, -1, -1):
		if not lit(str(RUNGS[index])):
			continue
		var made: Array = tier_now(str(RUNGS[index])).get("dice", [])
		for roll in dice():
			if made.has(str(roll.get("die_id", ""))):
				_set.append(str(roll.get("die_id", "")))
		_rung = index
		break

func _look_key() -> String:
	return "%s|%d" % [str(_set), _rung]

func _tick(_delta: float) -> void:
	if _spears.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_spears = _spears.filter(func(spear: Dictionary) -> bool: return now < int(spear.at) + int(SPEAR_FLIGHT * 1000.0))

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	if settled and _set.size() >= 2:
		_draw_rank(now)
	_draw_wall(now)
	_draw_spears(now)

static func _heater(middle: Vector2, wide: float, tall: float) -> PackedVector2Array:
	## A heater shield's outline: a flat top, straight sides, curving in to a point at the foot.
	var out := PackedVector2Array()
	var top: float = middle.y - tall * 0.5
	var left: float = middle.x - wide * 0.5
	var right: float = middle.x + wide * 0.5
	var waist: float = top + tall * 0.42
	var point := Vector2(middle.x, top + tall)
	out.append(Vector2(left, top))
	out.append(Vector2(right, top))
	for step in range(1, 9):
		var k: float = float(step) / 8.0
		var bend := Vector2(right, waist + (point.y - waist) * 0.55)
		out.append(Vector2(right, waist).lerp(bend, k).lerp(bend.lerp(point, k), k))
	for step in range(1, 8):
		var k: float = float(step) / 8.0
		var bend := Vector2(left, waist + (point.y - waist) * 0.55)
		out.append(point.lerp(bend, k).lerp(bend.lerp(Vector2(left, waist), k), k))
	out.append(Vector2(left, waist))
	return out

func _shield(middle: Vector2, edge: float, rim: Color, field: Color, alpha: float = 1.0) -> void:
	## One shield, drawn here rather than from the kit's mark (red-filled, that one reads as a
	## heart at a die's size): a dark edge, a steel face, and a band of the Knight's red (or gold)
	## down its middle.
	if edge <= 3.0 or alpha <= 0.0:
		return
	var outline: PackedVector2Array = _heater(middle, edge * 0.82, edge)
	draw_colored_polygon(outline, Color(rim, alpha))
	var band: PackedVector2Array = _heater(middle + Vector2(0.0, edge * 0.02), edge * 0.3, edge * 0.86)
	draw_colored_polygon(band, Color(field, alpha))
	draw_line(Vector2(middle.x - edge * 0.41, middle.y - edge * 0.22), Vector2(middle.x + edge * 0.41, middle.y - edge * 0.22), Color(field, alpha), maxf(1.0, edge * 0.12))
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color(DARK, 0.9 * alpha), maxf(1.0, u(2.0, 1.0)), true)

func _stud(middle: Vector2, half: float, fill: Color, glow: float = 0.0) -> void:
	## One stud on the line: a small faceted rhombus in the rung's color, lit from the top left,
	## a dark edge round it so it reads on the tray's dark and on a bright die's shadow alike.
	if half <= 1.0:
		return
	var wide: float = half * 1.25
	var top := middle + Vector2(0.0, -half)
	var right := middle + Vector2(wide, 0.0)
	var foot := middle + Vector2(0.0, half)
	var left := middle + Vector2(-wide, 0.0)
	if glow > 0.0:
		draw_circle(middle, half * (2.0 + 1.2 * glow), Color(GILT, 0.22 * glow))
		draw_circle(middle, half * (1.4 + 0.6 * glow), Color(GILT_HI, 0.35 * glow))
	var edge: float = maxf(1.5, u(2.5, 1.25))
	var rim: PackedVector2Array = PackedVector2Array([top + Vector2(0.0, -edge), right + Vector2(edge * 1.2, 0.0), foot + Vector2(0.0, edge), left + Vector2(-edge * 1.2, 0.0)])
	draw_colored_polygon(rim, Color(DARK, 0.92))
	## Four facets about a raised middle: the two upper ones catch the light, the lower ones not.
	var crown: Vector2 = middle + Vector2(-wide * 0.12, -half * 0.12)
	draw_colored_polygon(PackedVector2Array([top, crown, left]), fill.lightened(0.38))
	draw_colored_polygon(PackedVector2Array([top, right, crown]), fill.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([left, crown, foot]), fill.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([crown, right, foot]), fill.darkened(0.38))
	draw_line(top.lerp(left, 0.25), top.lerp(crown, 0.7), Color(1.0, 1.0, 1.0, 0.55 + 0.4 * glow), maxf(1.0, u(1.5, 0.75)), true)

func _gap_y(id: String) -> Vector2:
	## Where the line runs under a die (y) and how tall a stud may be there (half of it), so the
	## stud stands in the gap under the die and touches neither it nor the dock's foot.
	var seat: Rect2 = die_rect(id)
	var face: Rect2 = die_face(id)
	var room: float = seat.end.y - face.end.y
	return Vector2(face.end.y + room * 0.55, clampf(room * 0.36, u(3.0, 1.5), u(8.0, 4.0)))

func _lit_at(index: int, count: int, now: int) -> float:
	## How much a stud of the set burns just now: Phalanx's blaze one after another, or Legion's
	## flare as it runs the line and holds.
	var lit_up: float = 0.0
	if _blaze_at >= 0:
		var blaze: float = float(now - _blaze_at) / 1000.0
		if blaze >= BLAZE_SECONDS:
			_blaze_at = -1
		else:
			var since: float = blaze - 0.07 * float(index)
			lit_up = clampf(1.0 - absf(since - 0.12) / 0.3, 0.0, 1.0) if since >= 0.0 else 0.0
			if since >= 0.12:
				lit_up = maxf(lit_up, clampf((BLAZE_SECONDS - blaze) / 0.4, 0.0, 1.0) * 0.6)
	if _flare_at >= 0:
		var flare: float = float(now - _flare_at) / 1000.0
		if flare >= FLARE_SECONDS:
			_flare_at = -1
		else:
			var reach: float = float(index) / float(maxi(1, count - 1))
			var since: float = flare - FLARE_RUN * reach
			var lit_flare: float = clampf(since / 0.06, 0.0, 1.0) * clampf((FLARE_SECONDS - flare) / 0.3, 0.0, 1.0)
			lit_up = maxf(lit_up, lit_flare)
	return lit_up

func _draw_rank(now: int) -> void:
	## The set's line in the gap under the tray, and a stud on it under every die of the set.
	## Under Phalanx's flash the studs blaze gold one after another; under Legion's the gold runs
	## the line from the first die of the set to the last.
	var spots: Array = []
	var y: float = 0.0
	var half: float = 999.0
	for id in _set:
		var face: Rect2 = die_face(str(id))
		if face.size.x <= 0.0:
			return
		var gap: Vector2 = _gap_y(str(id))
		spots.append(face.get_center().x)
		y = maxf(y, gap.x)
		half = minf(half, gap.y)
	var tone: Color = RUNG_TONES[clampi(_rung, 0, RUNG_TONES.size() - 1)]
	var thick: float = maxf(1.5, u(3.0, 1.5))
	var from := Vector2(float(spots[0]), y)
	var to := Vector2(float(spots[spots.size() - 1]), y)
	draw_line(from, to, Color(DARK, 0.85), thick + maxf(2.0, u(3.0, 1.5)), true)
	draw_line(from, to, tone, thick, true)
	if _flare_at >= 0:
		## Legion: the line burns gold behind a bright head running to the set's far end.
		var flare: float = float(now - _flare_at) / 1000.0
		var run: float = clampf(flare / FLARE_RUN, 0.0, 1.0)
		var fade: float = clampf((FLARE_SECONDS - flare) / 0.3, 0.0, 1.0)
		var head: Vector2 = from.lerp(to, run)
		draw_line(from, head, Color(GILT, 0.3 * fade), thick * 7.0, true)
		draw_line(from, head, Color(GILT, 0.55 * fade), thick * 3.5, true)
		draw_line(from, head, Color(GILT_HI, fade), thick * 1.6, true)
		if run < 1.0:
			draw_circle(head, thick * 5.0, Color(GILT, 0.35))
			draw_circle(head, thick * 3.0, Color(GILT_HI, 0.75))
			draw_circle(head, thick * 1.6, Color.WHITE)
	for index in range(spots.size()):
		var lit_up: float = _lit_at(index, spots.size(), now)
		var fill: Color = tone.lerp(GILT_HI if _flare_at >= 0 else GILT, lit_up)
		_stud(Vector2(float(spots[index]), y), half * (1.0 + 0.25 * lit_up), fill, lit_up)

func _draw_wall(now: int) -> void:
	## Rank's wall: shields sliding in from both sides to close over his health ring, held a
	## beat, then gone.
	if _wall_at < 0:
		return
	var since: float = float(now - _wall_at) / 1000.0
	if since >= WALL_SECONDS:
		_wall_at = -1
		return
	var ring: Rect2 = ring_rect()
	if ring.size.x <= 0.0:
		return
	var edge: float = u(52.0, 26.0)
	var gap: float = edge * 0.74
	var count: int = clampi(_wall_count, 2, 5)
	var foot: float = minf(ring.position.y, dock_rect().position.y) - u(4.0, 2.0)
	var closed: float = clampf(since / WALL_CLOSE, 0.0, 1.0)
	closed = 1.0 - (1.0 - closed) * (1.0 - closed)
	var alpha: float = clampf((WALL_SECONDS - since) / 0.3, 0.0, 1.0)
	## Never out past the ring's own left edge (nor the phone's camera island).
	var left: float = maxf(ring.position.x - u(8.0, 4.0), DeepUi.safe_left if DeepUi.phone else 4.0) + edge * 0.5
	var middle_x: float = maxf(ring.get_center().x, left + gap * float(count - 1) * 0.5)
	for index in range(count):
		var share: float = float(index) - float(count - 1) * 0.5
		var home := Vector2(middle_x + share * gap, foot - edge * 0.5)
		var away: float = (1.0 if share >= 0.0 else -1.0) * u(90.0, 45.0) * (1.0 - closed)
		_shield(home + Vector2(away, 0.0), edge, STEEL, CRIMSON, alpha * clampf(closed * 2.0, 0.0, 1.0))
	if closed >= 1.0 and since < WALL_CLOSE + 0.12:
		var flash: float = 1.0 - (since - WALL_CLOSE) / 0.12
		draw_rect(Rect2(Vector2(middle_x - gap * float(count) * 0.5, foot - edge), Vector2(gap * float(count), edge)), Color(1.0, 0.95, 0.9, 0.25 * flash))

func _draw_spears(now: int) -> void:
	## A spear on its way: a steel head on a dark shaft, a red streak behind it.
	for spear in _spears:
		var t: float = float(now - int(spear.at)) / 1000.0 / SPEAR_FLIGHT
		if t < 0.0 or t >= 1.0:
			continue
		var from: Vector2 = spear.from
		var to: Vector2 = spear.to
		var way: Vector2 = (to - from).normalized() if from.distance_to(to) > 1.0 else Vector2.UP
		var side: Vector2 = way.orthogonal()
		var head: Vector2 = from.lerp(to, t * t * 0.4 + t * 0.6)
		var long: float = u(96.0, 48.0)
		var tail: Vector2 = head - way * minf(long, head.distance_to(from) + long * 0.3)
		var tone: Color = spear.tone
		draw_line(tail - way * long * 0.7, tail, Color(tone, 0.5), maxf(1.5, u(4.0, 2.0)), true)
		draw_line(tail, head, Color(DARK, 0.9), maxf(2.5, u(7.0, 3.5)), true)
		draw_line(tail, head, Color("9a6a4a"), maxf(1.5, u(3.5, 1.75)), true)
		var point: float = u(24.0, 12.0)
		var barb: float = u(8.0, 4.0)
		var tip_at: Vector2 = head + way * point
		draw_colored_polygon(PackedVector2Array([tip_at, head + side * barb, head - side * barb]), STEEL)
		draw_polyline(PackedVector2Array([tip_at, head + side * barb, head - side * barb, tip_at]), DARK, maxf(1.0, u(1.5, 0.75)), true)

# --- the rungs landing ---------------------------------------------------------------------------

func _near(who: String) -> Vector3:
	## Just in front of a creature, toward the lens: the screen's bolt is thrown from here, so
	## the spear is what is seen flying and the bolt is its flash on arrival.
	var at: Vector3 = creature_point(who)
	if screen != null and not DeepUi.headless() and screen._camera != null:
		var lens: Vector3 = screen._camera.global_position
		if lens.distance_to(at) > 1.0:
			return at + (lens - at).normalized() * 0.7
	return at

func _die_spot(index: int) -> Vector2:
	## Where a spear leaves from: a die of the set (one after another), else the Birthstone.
	if not _set.is_empty():
		var face: Rect2 = die_face(str(_set[index % _set.size()]))
		if face.size.x > 0.0:
			return face.get_center()
	return stone_rect().get_center()

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var now: int = Time.get_ticks_msec()
	match str(entry.get("name", "")):
		"Rank":
			## A wall of shields closes over him as the Block lands.
			_wall_at = now
			_wall_count = maxi(2, _set.size())
			busy(WALL_SECONDS + 0.2)
			sound("hammer_strike", {"volume": 0.3, "pitch": 1.25, "delay": WALL_CLOSE, "gap": 0.0})
			land(effects, origin, tone)
			return true
		"File":
			return _file(effects, origin, tone)
		"Phalanx":
			## The formation flashes: the set's studs blaze, and a sigil on the stunned creature.
			_blaze_at = now
			busy(BLAZE_SECONDS + 0.2)
			sound("harmony", {"volume": 0.4, "pitch": 0.9, "gap": 0.0})
			for effect in effects:
				if effect is Dictionary and str(effect.get("kind", "")) == "stun" and fx() != null:
					var who: String = str(effect.get("target", target_id()))
					later(0.16, func() -> void:
						if fx() != null:
							fx().sigil(creature_point(who), GILT, 1.1, 0.8))
			land(effects, origin, tone)
			return true
		"Legion":
			return _legion(effects, origin, tone)
	return false

func _file(effects: Array, origin: Vector3, tone: Color) -> bool:
	## Three spears in file from the set's dice; the blow lands with the last of them.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var at: float = 0.0
	for hit in blows:
		var who: String = str(hit.get("target", target_id()))
		for index in range(3):
			later(at + FILE_GAP * float(index), _spear.bind(who, index, RED_HI))
		later(at + FILE_GAP * 2.0, land.bind([hit], _near(who), RED_HI))
		at += FILE_GAP * 3.0 + 0.12
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	busy(at + SPEAR_FLIGHT + 0.4)
	return true

func _legion(effects: Array, origin: Vector3, tone: Color) -> bool:
	## Gold runs the line under the set and lights its studs one by one; once it reaches the far
	## end every die of the set throws at once.
	_flare_at = Time.get_ticks_msec()
	busy(FLARE_SECONDS + 0.2)
	sound("harmony", {"volume": 0.55, "gap": 0.0})
	sound("hammer_strike", {"volume": 0.22, "pitch": 1.5, "delay": FLARE_RUN, "gap": 0.0})
	for index in range(_set.size()):
		later(FLARE_RUN * float(index) / float(maxi(1, _set.size() - 1)), _spark_stud.bind(index))
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	for index in range(blows.size()):
		var hit: Dictionary = blows[index]
		var who: String = str(hit.get("target", target_id()))
		later(VOLLEY_LEAD + VOLLEY_GAP * float(index), _spear.bind(who, index, GILT))
		later(VOLLEY_LEAD + VOLLEY_GAP * float(index), land.bind([hit], _near(who), GILT))
	if not rest.is_empty():
		later(VOLLEY_LEAD + VOLLEY_GAP * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _spark_stud(index: int) -> void:
	## Gold thrown off a stud as Legion's flare reaches it.
	if index >= _set.size():
		return
	var id: String = str(_set[index])
	var face: Rect2 = die_face(id)
	if face.size.x > 0.0:
		burst(Vector2(face.get_center().x, _gap_y(id).x), GILT, 10, u(120.0, 60.0), 0.35, u(4.0, 2.0))
		sound("tally_tick", {"volume": 0.25, "pitch": 1.0 + 0.1 * float(index), "gap": 0.0})

func _spear(who: String, index: int, tone: Color) -> void:
	if DeepUi.headless():
		return
	var to: Vector2 = creature_at(who) + Vector2(float(index % 3 - 1) * u(14.0, 7.0), float(index % 2) * u(10.0, 5.0))
	_spears.append({"from": _die_spot(index), "to": to, "at": Time.get_ticks_msec(), "tone": tone})
	busy(SPEAR_FLIGHT + 0.3)
	sound("hit_lash", {"volume": 0.3, "pitch": 0.85 + 0.08 * float(index), "gap": 0.0})
	later(SPEAR_FLIGHT, burst.bind(to, tone, 8, u(140.0, 70.0), 0.35, u(4.0, 2.0)))
