extends "res://view/battle/birth_act.gd"
## Ardor's Rally: a set of matching dice is a rank of the Knight's men.
##
## While the hand is planned, the dice of the set the hand has made stand on a line under the
## tray, each with a small shield on it: two shields are a Rank, three a File, four a Phalanx,
## five a Legion, and the line takes a brighter color with every rung, so the rung reached reads
## off the tray. (Rampart's slabs stand under even dice; Rally's shields stand under a set.)
##
## Each rung has its moment as it lands. Rank closes a wall of shields over his health ring.
## File throws three spears in file from the set's dice into the target. Phalanx flashes the
## formation: the shields under the dice blaze gold one after another and a gold sigil stands on
## the creature it stuns. Legion raises a banner over the Birthstone and every die of the set
## throws at once, a volley a blow.
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
const BANNER_SECONDS: float = 1.8

## The dice of the set reached, left to right, and the rung (index of RUNGS, -1 for none).
var _set: Array = []
var _rung: int = -1
var _wall_at: int = -1
var _wall_count: int = 0
var _blaze_at: int = -1
var _banner_at: int = -1
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
	_draw_banner(now)
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

func _draw_rank(now: int) -> void:
	## The set's line under the tray and a shield on it under every die of the set. Under
	## Phalanx's flash the shields blaze gold one after another.
	var spots: Array = []
	var edge: float = 0.0
	var y: float = 0.0
	for id in _set:
		var seat: Rect2 = die_rect(str(id))
		var face: Rect2 = die_face(str(id))
		if seat.size.x <= 0.0:
			return
		spots.append(face.get_center().x)
		edge = face.size.x * 0.5
		y = maxf(y, lerpf(face.end.y, seat.end.y, 0.4))
	var tone: Color = RUNG_TONES[clampi(_rung, 0, RUNG_TONES.size() - 1)]
	var thick: float = maxf(1.5, u(3.0, 1.5))
	var from := Vector2(float(spots[0]), y)
	var to := Vector2(float(spots[spots.size() - 1]), y)
	draw_line(from, to, Color(DARK, 0.85), thick + maxf(2.0, u(3.0, 1.5)), true)
	draw_line(from, to, tone, thick, true)
	var blaze: float = float(now - _blaze_at) / 1000.0 if _blaze_at >= 0 else -1.0
	if blaze >= BLAZE_SECONDS:
		_blaze_at = -1
		blaze = -1.0
	for index in range(spots.size()):
		var at := Vector2(float(spots[index]), y)
		var lit_up: float = 0.0
		if blaze >= 0.0:
			var since: float = blaze - 0.07 * float(index)
			lit_up = clampf(1.0 - absf(since - 0.12) / 0.3, 0.0, 1.0) if since >= 0.0 else 0.0
			if since >= 0.12:
				lit_up = maxf(lit_up, clampf((BLAZE_SECONDS - blaze) / 0.4, 0.0, 1.0) * 0.6)
		if lit_up > 0.0:
			draw_circle(at, edge * (0.8 + 0.5 * lit_up), Color(GILT, 0.35 * lit_up))
		_shield(at, edge * (1.0 + 0.35 * lit_up), STEEL.lerp(GILT, lit_up), CRIMSON.lerp(GILT.darkened(0.2), lit_up))

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

func _draw_banner(now: int) -> void:
	## Legion's banner over the Birthstone: a staff, the red cloth let down from its crossbar
	## with gilt edges and the stone's own mark on it.
	if _banner_at < 0:
		return
	var since: float = float(now - _banner_at) / 1000.0
	if since >= BANNER_SECONDS:
		_banner_at = -1
		return
	var stone_at: Rect2 = stone_rect()
	if stone_at.size.x <= 0.0:
		return
	var wide: float = u(56.0, 30.0)
	var tall: float = u(84.0, 44.0)
	var foot: float = minf(stone_at.position.y, dock_rect().position.y) - u(6.0, 3.0)
	var rise: float = clampf(since / 0.2, 0.0, 1.0)
	rise = 1.0 - (1.0 - rise) * (1.0 - rise)
	var down: float = clampf((since - 0.15) / 0.22, 0.0, 1.0)
	down = 1.0 - (1.0 - down) * (1.0 - down)
	var alpha: float = clampf((BANNER_SECONDS - since) / 0.35, 0.0, 1.0)
	var pole: float = (tall + u(30.0, 14.0)) * rise
	var x: float = stone_at.get_center().x
	var top := Vector2(x - wide * 0.5, foot - pole)
	var line: float = maxf(1.5, u(3.0, 1.5))
	draw_line(Vector2(x, foot), Vector2(x, foot - pole - u(8.0, 4.0)), Color(DARK, 0.9 * alpha), line + maxf(2.0, u(3.0, 1.5)), true)
	draw_line(Vector2(x, foot), Vector2(x, foot - pole - u(8.0, 4.0)), Color(GILT.darkened(0.2), alpha), line, true)
	draw_circle(Vector2(x, foot - pole - u(8.0, 4.0)), line * 1.5, Color(GILT, alpha))
	if rise < 1.0:
		return
	var hung: float = tall * down
	var notch: float = wide * 0.3
	var cloth := PackedVector2Array([top, top + Vector2(wide, 0.0), top + Vector2(wide, hung), top + Vector2(wide * 0.5, maxf(0.0, hung - notch)), top + Vector2(0.0, hung)])
	if hung > notch:
		draw_colored_polygon(cloth, Color(CRIMSON, 0.96 * alpha))
		draw_polyline(cloth + PackedVector2Array([top]), Color(GILT, 0.9 * alpha), maxf(1.0, u(2.0, 1.0)), true)
	draw_rect(Rect2(top + Vector2(-wide * 0.12, -u(4.0, 2.0)), Vector2(wide * 1.24, u(5.0, 2.5))), Color(GILT.darkened(0.25), alpha))
	if down >= 1.0:
		var mark: float = wide * 0.62
		var mark_at := Rect2(Vector2(x - mark * 0.5, top.y + tall * 0.2), Vector2(mark, mark))
		draw_glyph("formation" if GemIcons.known("formation") else "shield", mark_at, Color(GILT.lightened(0.2), alpha))

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
			## The formation flashes: the set's shields blaze, and a sigil on the stunned creature.
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
	## The banner goes up over the stone and every die of the set throws at once.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	_banner_at = Time.get_ticks_msec()
	busy(BANNER_SECONDS + 0.2)
	sound("harmony", {"volume": 0.55, "gap": 0.0})
	var lead: float = 0.3
	for index in range(blows.size()):
		var hit: Dictionary = blows[index]
		var who: String = str(hit.get("target", target_id()))
		later(lead + VOLLEY_GAP * float(index), _spear.bind(who, index, GILT))
		later(lead + VOLLEY_GAP * float(index), land.bind([hit], _near(who), GILT))
	if not rest.is_empty():
		later(lead + VOLLEY_GAP * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _spear(who: String, index: int, tone: Color) -> void:
	if DeepUi.headless():
		return
	var to: Vector2 = creature_at(who) + Vector2(float(index % 3 - 1) * u(14.0, 7.0), float(index % 2) * u(10.0, 5.0))
	_spears.append({"from": _die_spot(index), "to": to, "at": Time.get_ticks_msec(), "tone": tone})
	busy(SPEAR_FLIGHT + 0.3)
	sound("hit_lash", {"volume": 0.3, "pitch": 0.85 + 0.08 * float(index), "gap": 0.0})
	later(SPEAR_FLIGHT, burst.bind(to, tone, 8, u(140.0, 70.0), 0.35, u(4.0, 2.0)))
