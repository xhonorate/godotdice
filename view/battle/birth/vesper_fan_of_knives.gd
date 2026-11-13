extends "res://view/battle/birth_act.gd"
## Vesper's Fan of Knives: every die that matches another is a knife in her hand.
##
## While the hand is planned a fan of small blades stands over the Birthstone, one blade for
## every die that matches another, and each of those dice wears a blade notch. Once four of a
## kind turns Fan into Flourish the blades go blue, the fan's rivet shows what every knife gains
## ("+11"), and the highest die, the one that gives it, is ringed in the same blue.
##
## When the stone fires, the knives leave the fan one at a time, left to right, a tenth of a
## second apart: thin grey streaks that flash blue as they strike. A knife that kills comes
## back to the fan and goes out again at the next creature. Flourish throws the whole fan at
## once and every knife splits into a streak for each creature. Riposte's Block swells off the
## hits as the screen lands them.
##
## The phone's fan is no wider than the 44 pt ring under it; the notches are the same marks on
## the dice.

const STEEL := Color("c9cfdc")
const SPECTRO := Color("5a6ad0")
const SPECTRO_HI := Color("9aa8ff")
const NIGHT := Color(0.03, 0.035, 0.06)
## The knives leave this far apart, and each flies as long as the screen's own bolt does, so its
## blue flash and its hit land together.
const KNIFE_GAP: float = 0.1
const FLIGHT: float = 0.2
## A knife that killed comes back to the fan this fast; Flourish's knives split this far out.
const BACK: float = 0.14
const SPLIT: float = 0.07
const FLASH_MS: int = 200
## The angle between two blades of the fan, and how slim a blade is drawn against the mark.
const STEP_DEG: float = 24.0
const SLIM: float = 0.72

var _area: Control = null
## The dice that are knives, left to right; the highest die and what Flourish adds from it.
var _knives: Array = []
var _high_id: String = ""
var _bonus: int = 0
var _flourish: bool = false
## Once the stone has lit, the fan waits for its tier; while it throws, how many blades have
## left the fan (from the left).
var _held: bool = false
var _throwing: bool = false
var _gone: int = 0
var _turn: int = 0
## Knives in the air ({from, to, at, ms, tone, back}) and the blue flashes where they struck.
var _flights: Array = []
var _flashes: Array = []

func _open() -> void:
	_area = Control.new()
	_area.name = "KnifeRack"
	_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_area.visible = false
	place(_area, "over_stone", 0.5, Vector2(0.0, -u(4.0, 9.0)))
	tip(_area, _rack_plate, {"tone": SPECTRO_HI})

# --- reading the hand ----------------------------------------------------------------------------

func _stone_fired() -> bool:
	## Whether the stone has resolved this turn.
	return not planning and page != null and not page.birth_outcome.is_empty()

func _sync_act() -> void:
	var up: bool = settled and not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	if planning:
		## Her turn has come round: the fan is full again.
		_held = false
		_throwing = false
		_gone = 0
	_knives.clear()
	_high_id = ""
	_bonus = 0
	_flourish = false
	if up:
		var counted: Dictionary = {}
		for group in reading().get("groups", []):
			if group is Dictionary and int(group.get("count", 0)) >= 2:
				for id in group.get("dice", []):
					counted[str(id)] = true
		var best: int = -1
		for roll in dice():
			var id: String = str(roll.get("die_id", ""))
			if counted.has(id):
				_knives.append(id)
			var shows: int = int(roll.get("top", 0)) if str(roll.get("kind", "plain")) == "wild" else int(roll.get("value", 0))
			if shows > best:
				best = shows
				_high_id = id
		_flourish = lit("Flourish")
		_bonus = maxi(0, best) if _flourish else 0
	_area.visible = up and _knives.size() >= 2 and (not _stone_fired() or ((_held or _throwing) and _gone < _knives.size()))
	_size_rack()

func _fired(_played: Dictionary) -> void:
	## The stone has lit: the fan stays up through its count until the knives leave it.
	_held = true
	_gone = 0

func _look_key() -> String:
	return "%s|%s|%s|%d|%d|%s|%s" % [str(_knives), _high_id, str(_flourish), _bonus, _gone, str(_throwing), str(_area.visible)]

func _shown() -> bool:
	## The fan and the notches stand from the dice landing until the knives have all gone.
	return _area != null and _area.visible

# --- the fan's measures ----------------------------------------------------------------------------

func _hub_tall() -> float:
	return float(maxi(text_px(15, 11), DeepUi.min_text())) + u(6.0, 3.0)

func _rack_wide() -> float:
	## As wide as the stone's ring (a little over on the desktop), never past it on the phone.
	var ring: Rect2 = stone_rect()
	if ring.size.x <= 0.0:
		return 0.0
	return minf(ring.size.x, DeepUi.pt(44.0)) if DeepUi.phone else ring.size.x * 1.1

func _edge() -> float:
	## A blade's length, the same for two blades as for five: five at full lean fill the width.
	var lean: float = deg_to_rad(STEP_DEG * 2.0)
	return _rack_wide() / (2.0 * 0.9 * sin(lean) + 0.1)

func _size_rack() -> void:
	var wide: float = _rack_wide()
	var want := Vector2(wide, _edge() * 0.92 + _hub_tall()) if wide > 0.0 else Vector2.ZERO
	if not _area.custom_minimum_size.is_equal_approx(want):
		_area.custom_minimum_size = want
		_area.size = want

func _tick(_delta: float) -> void:
	_size_rack()
	if _flights.is_empty() and _flashes.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_flights = _flights.filter(func(flight: Dictionary) -> bool: return now < int(flight.at) + int(flight.ms))
	_flashes = _flashes.filter(func(flash: Dictionary) -> bool: return now < int(flash.born) + FLASH_MS)

func _pivot() -> Vector2:
	## The rivet the blades fan out from: the foot of the rack, in its middle.
	var box := Rect2(_area.position, _area.size)
	return Vector2(box.get_center().x, box.end.y - _hub_tall() * 0.5)

func _blade(slot: int, count: int) -> Array:
	## Where one blade of the fan stands: [its middle, its lean], the leftmost first.
	var lean: float = deg_to_rad(STEP_DEG * (float(slot) - float(count - 1) * 0.5))
	var middle: Vector2 = _pivot() + Vector2(sin(lean), -cos(lean)) * _edge() * 0.42
	return [middle, lean]

func _blade_tip(slot: int, count: int) -> Vector2:
	var spot: Array = _blade(slot, count)
	return (spot[0] as Vector2) + Vector2(sin(float(spot[1])), -cos(float(spot[1]))) * _edge() * 0.46

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	if settled and _shown():
		var tone: Color = SPECTRO_HI if _flourish else STEEL
		for id in _knives:
			_draw_notch(str(id), tone)
		if _flourish and not _high_id.is_empty():
			_draw_high_ring(_high_id)
		_draw_rack(tone)
	_draw_flights(now)
	_draw_flashes(now)

func _knife(middle: Vector2, lean: float, edge: float, tone: Color, line: float = -1.0) -> void:
	## One blade, point outward, edged dark so it reads over the room and the dock alike.
	if edge <= 2.0:
		return
	var rim: float = line if line >= 0.0 else maxf(1.0, u(1.5, 1.0))
	draw_set_transform(middle, lean, Vector2(SLIM, 1.0))
	var box := Rect2(-Vector2(edge, edge) * 0.5, Vector2(edge, edge))
	if rim > 0.0:
		for shift in [Vector2(-rim, 0.0), Vector2(rim, 0.0), Vector2(0.0, -rim), Vector2(0.0, rim)]:
			draw_glyph("blade", Rect2(box.position + shift, box.size), Color(NIGHT, 0.9 * tone.a))
	draw_glyph("blade", box, tone)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_rack(tone: Color) -> void:
	var count: int = _knives.size()
	var edge: float = _edge()
	if edge <= 0.0 or count < 2 or (_throwing and _gone >= count):
		return
	for slot in range(count):
		if _throwing and slot < _gone:
			continue
		var spot: Array = _blade(slot, count)
		_knife(spot[0], float(spot[1]), edge, tone)
	## The rivet: a plain stud, or Flourish's gain on a blue pill.
	var pivot: Vector2 = _pivot()
	if _flourish and _bonus > 0:
		var px: int = text_px(15, 11)
		var said: String = "+%d" % _bonus
		var wide: float = DeepUi.bold_font().get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(px, DeepUi.min_text())).x + u(10.0, 5.0)
		var tall: float = _hub_tall()
		var pill := Rect2(pivot - Vector2(wide, tall) * 0.5, Vector2(wide, tall))
		var pill_box: StyleBoxFlat = DeepUi.flat(Color(NIGHT, 0.95), SPECTRO_HI, int(tall * 0.5), 0, maxi(1, int(u(2.0, 1.0))))
		draw_style_box(pill_box, pill)
		draw_words(said, pill.get_center(), px, SPECTRO_HI.lightened(0.3))
	else:
		var stud: float = u(5.0, 3.0)
		draw_circle(pivot, stud + maxf(1.0, u(1.5, 1.0)), Color(NIGHT, 0.95))
		draw_circle(pivot, stud, tone.darkened(0.25))

func _draw_notch(id: String, tone: Color) -> void:
	## A knife's notch on its die: a small blade on the die's top right corner.
	var face: Rect2 = die_face(id)
	if face.size.x <= 0.0:
		return
	var box: Rect2 = die_corner(id, CORNER_TOP_RIGHT, face.size.x * 0.44)
	_knife(box.get_center(), 0.35, box.size.x, tone)

func _draw_high_ring(id: String) -> void:
	## The die Flourish takes its gain from, ringed in the blades' blue.
	var face: Rect2 = die_face(id)
	if face.size.x <= 0.0:
		return
	var radius: float = face.size.x * 0.66
	var thick: float = maxf(1.5, u(3.0, 1.5))
	draw_arc(face.get_center(), radius, 0.0, TAU, 40, Color(NIGHT, 0.85), thick + maxf(2.0, u(3.0, 1.5)), true)
	draw_arc(face.get_center(), radius, 0.0, TAU, 40, SPECTRO_HI, thick, true)

func _draw_flights(now: int) -> void:
	## Knives in the air: a thin grey streak with the blade at its head.
	var thin: float = maxf(1.5, u(3.0, 1.5))
	var long: float = u(130.0, 60.0)
	for flight in _flights:
		var t: float = float(now - int(flight.at)) / float(maxi(1, int(flight.ms)))
		if t <= 0.0 or t >= 1.0:
			continue
		var from: Vector2 = flight.from
		var to: Vector2 = flight.to
		var eased: float = t * (2.0 - t) if bool(flight.back) else t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65
		var head: Vector2 = from.lerp(to, eased)
		var way: Vector2 = (to - from).normalized() if from.distance_to(to) > 1.0 else Vector2.UP
		var tail: Vector2 = head - way * minf(long, head.distance_to(from))
		var tone: Color = flight.tone
		draw_line(tail, head, Color(NIGHT, 0.5), thin + maxf(2.0, u(3.0, 1.5)), true)
		draw_line(tail, head, Color(tone, 0.9), thin, true)
		_knife(head, way.angle() + PI * 0.5, u(40.0, 20.0), tone.lightened(0.2), maxf(1.0, u(1.5, 1.0)))

func _draw_flashes(now: int) -> void:
	## A knife striking: a blue flash where it went in.
	for flash in _flashes:
		var t: float = float(now - int(flash.born)) / float(FLASH_MS)
		if t < 0.0 or t >= 1.0:
			continue
		var at: Vector2 = flash.at
		var fade: float = 1.0 - t
		draw_circle(at, u(14.0, 7.0) + u(26.0, 13.0) * t, Color(SPECTRO_HI, 0.35 * fade))
		var arm: float = u(22.0, 11.0) * (0.6 + 0.6 * t)
		draw_line(at - Vector2(arm, 0.0), at + Vector2(arm, 0.0), Color(1.0, 1.0, 1.0, 0.9 * fade), maxf(1.0, u(2.0, 1.0)), true)
		draw_line(at - Vector2(0.0, arm * 0.6), at + Vector2(0.0, arm * 0.6), Color(SPECTRO_HI.lightened(0.4), 0.8 * fade), maxf(1.0, u(2.0, 1.0)), true)

# --- the tip -------------------------------------------------------------------------------------

func _each() -> int:
	## What one knife deals, as the fight reckons it.
	var tier_name: String = "Flourish" if _flourish else "Fan"
	for effect in tier_now(tier_name).get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == "damage" and effect.has("amount"):
			return int(effect.amount)
	return DeepRules.sat_add(resonance_now(), _bonus)

func _rack_plate() -> Control:
	var count: int = _knives.size()
	var knives: String = "1 knife" if count == 1 else "%d knives" % count
	if _flourish:
		return Plates.words("Flourish", "%s, each dealing %s to every creature: Resonance and %d from your highest die. A knife that kills is thrown again." % [knives, DeepUi.number(_each()), _bonus], "fan of knives", SPECTRO_HI)
	return Plates.words("Fan", "%s, one for every die that matches another, each dealing %s to a random creature. A knife that kills is thrown again." % [knives, DeepUi.number(_each())], "fan of knives", SPECTRO_HI)

# --- the stone fires -----------------------------------------------------------------------------

func _near(who: String) -> Vector3:
	## Just in front of a creature, toward the lens: the screen's bolt is thrown from here, so
	## all that shows of it is the blue flash on the knife's arrival.
	var at: Vector3 = creature_point(who)
	if screen != null and not DeepUi.headless() and screen._camera != null:
		var lens: Vector3 = screen._camera.global_position
		if lens.distance_to(at) > 1.0:
			return at + (lens - at).normalized() * 0.7
	return at

func _group(blows: Array, splits: bool) -> Array:
	## The hits as knives: each one thrown starts a knife, a rethrow (`chained`) belongs to the
	## knife before it, and under Flourish one knife's hits are one a creature.
	var out: Array = []
	var seen: Dictionary = {}
	for hit in blows:
		var chained: bool = bool(hit.get("chained", false))
		var who: String = str(hit.get("target", ""))
		if out.is_empty() or (not chained and (not splits or seen.has(who))):
			out.append({"hits": [], "again": []})
			seen.clear()
		if chained:
			out.back().again.append(hit)
		else:
			out.back().hits.append(hit)
			seen[who] = true
	return out

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var all_at_once: bool = str(entry.get("name", "")) == "Flourish"
	var knives: Array = _group(blows, all_at_once)
	var count: int = maxi(1, _knives.size())
	_throwing = true
	_gone = 0
	_turn += 1
	var end: float = 0.0
	for index in range(knives.size()):
		var start: float = 0.0 if all_at_once else KNIFE_GAP * float(index)
		later(start, _throw.bind(knives[index], index % count, count, all_at_once))
		var knife: Dictionary = knives[index]
		end = maxf(end, start + (SPLIT if all_at_once else 0.0) + FLIGHT + float(knife.again.size()) * (BACK + FLIGHT))
	if all_at_once:
		sound("hit_lash", {"volume": 0.55, "pitch": 1.3, "gap": 0.0})
	if not rest.is_empty():
		later(end, land.bind(rest, origin, tone))
	later(end + 0.05, _done.bind(_turn))
	busy(end + 0.5)
	return true

func _done(turn: int) -> void:
	if turn == _turn:
		_held = false
		_gone = _knives.size()
		_area.visible = false
		queue_redraw()

func _throw(knife: Dictionary, slot: int, count: int, splits: bool) -> void:
	## One knife leaves the fan: straight at its creature, or, under Flourish, out a little way
	## and then a streak for every creature. Each rethrow comes back to the fan and goes again.
	var from: Vector2 = _blade_tip(slot, count) if _area.size.x > 0.0 else stone_rect().get_center()
	_gone = count if splits else maxi(_gone, slot + 1)
	var now: int = Time.get_ticks_msec()
	var hits: Array = knife.hits
	var t: float = 0.0
	var last: Vector2 = from
	if splits:
		var middle := Vector2.ZERO
		for hit in hits:
			middle += creature_at(str(hit.get("target", target_id())))
		middle /= float(maxi(1, hits.size()))
		var split_at: Vector2 = from.lerp(middle, 0.3)
		if not DeepUi.headless():
			_flights.append({"from": from, "to": split_at, "at": now, "ms": int(SPLIT * 1000.0), "tone": SPECTRO_HI, "back": false})
		for hit in hits:
			later(SPLIT, _strike.bind(hit, split_at, SPECTRO_HI))
		t = SPLIT + FLIGHT
		if not hits.is_empty():
			last = creature_at(str(hits.back().get("target", target_id())))
	else:
		sound("hit_lash", {"volume": 0.32, "pitch": 1.45 + 0.06 * float(slot), "gap": 0.0})
		for hit in hits:
			_strike(hit, from, STEEL)
			last = creature_at(str(hit.get("target", target_id())))
		t = FLIGHT
	for hit in knife.again:
		later(t, _bounce.bind(last, from))
		later(t + BACK, _strike.bind(hit, from, SPECTRO_HI if splits else STEEL))
		last = creature_at(str(hit.get("target", target_id())))
		t += BACK + FLIGHT
	busy(t + 0.4)

func _strike(hit: Dictionary, from: Vector2, tone: Color) -> void:
	## A knife on its way to one creature; the hit lands as it arrives, with a blue flash.
	var who: String = str(hit.get("target", target_id()))
	var to: Vector2 = creature_at(who)
	if not DeepUi.headless():
		_flights.append({"from": from, "to": to, "at": Time.get_ticks_msec(), "ms": int(FLIGHT * 1000.0), "tone": tone, "back": false})
	busy(FLIGHT + 0.4)
	## The screen's bolt in the stone's deeper blue and at its smallest: its glow is the flash.
	land([hit], _near(who), SPECTRO, 0.0)
	later(FLIGHT, _flash_at.bind(to))

func _bounce(from: Vector2, to: Vector2) -> void:
	## A knife that killed coming back to her hand.
	if not DeepUi.headless():
		_flights.append({"from": from, "to": to, "at": Time.get_ticks_msec(), "ms": int(BACK * 1000.0), "tone": STEEL, "back": true})
	busy(BACK + 0.3)
	sound("hit_lash", {"volume": 0.25, "pitch": 1.9, "gap": 0.0})

func _flash_at(at: Vector2) -> void:
	if DeepUi.headless():
		return
	_flashes.append({"at": at, "born": Time.get_ticks_msec()})
	burst(at, SPECTRO_HI, 8, u(150.0, 70.0), 0.35, u(4.0, 2.0))
	busy(float(FLASH_MS) / 1000.0 + 0.1)
