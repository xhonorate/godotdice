extends "res://view/battle/birth_act.gd"
## Florin's Blackjack: the hand's count, and what one more card risks.
##
## The game shows no total of its own, so the count stands over the tray on the shared track
## (total_track.gd): a cell for 16 or less, one for each total from 17 to 21, and Bust past it,
## the marker on the hand's cell with the count over it and the rung it reads beside it ("20 ·
## Stand ×4"). Grey at 16 or less, gold from 17, white at 21, red from 22. While the stone is
## worn his throw button reads Hit and his lock-in Stand.
##
## When the stone fires: Stand slides a stack of chips from the count to the target for every
## point over 16, the blow landing with the last; Twenty-One flips the count over like a card
## to 21, three heavy hits land off it with a snap each and 21 coins go to the purse; a Bust
## cracks the count red and the hit comes back on him, a red flash over his ring.
##
## Both layouts draw the same track over the tray; the phone's stands clear of the line of
## words that floats over the dice.

const TotalTrack = preload("res://view/battle/birth/total_track.gd")

const GOLD := Color("f0b640")
const CHIP := Color("e0a030")
const CHIP_DARK := Color("4a3418")
const CARD := Color("f6f1e4")
const INK := Color("15181f")
const BUST := Color("ff5a4a")
const CARD_SECONDS: float = 2.1
const CRACK_SECONDS: float = 1.4

var _track: Control = null
## The stone's rungs as content wrote them, lowest first: [{name, from, to, penalty, text, tone}].
var _rungs: Array = []
var _laid: String = ""
## Chip stacks sliding to the target: [{from, to, at, seconds}].
var _stacks: Array = []
## Twenty-One's card, and the jolt each hit gives it.
var _card_at: int = -1
var _card_jolt: int = -1
var _card_spot: Vector2 = Vector2.ZERO
## A Bust: the cracks over the count, the red streak to his ring and its flash.
var _crack_at: int = -1
var _crack_spot: Vector2 = Vector2.ZERO
var _cracks: Array = []

func _open() -> void:
	_track = TotalTrack.new()
	_track.visible = false
	place(_track, "over_tray", 0.5)
	tip(_track, _plate, {"tone": GOLD})

func _button_words() -> Dictionary:
	return {"reroll": "Hit", "lock": "Stand"}

# --- the count -----------------------------------------------------------------------------------

func _total() -> int:
	return int(reading().get("total", 0))

func _read_rungs() -> void:
	var out: Array = []
	for def in defs:
		if not def is Dictionary or str(def.get("trigger", {}).get("kind", "")) != "total_window":
			continue
		var from: int = int(def.trigger.get("amount", 0))
		var most: int = int(def.trigger.get("max", -1))
		out.append({"name": str(def.get("name", "")), "from": from, "to": most if most >= from else from + 40, "open": most < from,
			"penalty": bool(def.get("penalty", false)), "text": str(def.get("text", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.from) < int(b.from))
	## A Bust is red, a single total (21) white, a stretch (Stand) gold.
	for rung in out:
		rung.tone = BUST if bool(rung.penalty) else (Color("ffffff") if int(rung.from) == int(rung.to) else GOLD)
	_rungs = out

func _lay_track() -> void:
	## The track's cells: everything under the first rung in one, each total of the rungs that
	## are not open-ended in its own, and the open one (Bust) after them, each as wide as its
	## words need at the text floor.
	if _rungs.is_empty():
		_read_rungs()
	var key: String = "%s|%d|%s" % [str(_rungs.map(func(rung: Dictionary) -> int: return int(rung.from))), DeepUi.min_text(), str(DeepUi.phone)]
	if key == _laid or _rungs.is_empty():
		return
	_laid = key
	var cells: Array = []
	var first: int = int(_rungs[0].from)
	cells.append({"from": 0, "to": first - 1, "label": str(first - 1), "tone": DeepUi.MUTED})
	for rung in _rungs:
		if bool(rung.open):
			cells.append({"from": int(rung.from), "to": int(rung.to), "label": str(rung.name), "tone": rung.tone})
		else:
			for total in range(int(rung.from), int(rung.to) + 1):
				cells.append({"from": total, "to": total, "label": str(total), "tone": rung.tone})
	var font: Font = DeepUi.bold_font()
	var px: int = DeepUi.min_text()
	var pad: float = u(9.0, 4.0)
	var span: float = 0.0
	for cell in cells:
		cell.weight = font.get_string_size(str(cell.label), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + pad * 2.0
		span += float(cell.weight)
	_track.lay(cells, span)

func _rung_lit() -> Dictionary:
	## The rung the hand reads, as the forecast (or the turn itself) says.
	for rung in _rungs:
		if lit(str(rung.name)):
			return rung
	return {}

func _caption(rung: Dictionary, total: int) -> String:
	if rung.is_empty():
		return ""
	var said: String = "· " + str(rung.name)
	## A stretch pays once for every point past the total under it.
	if not bool(rung.penalty) and int(rung.to) > int(rung.from):
		said += " ×%d" % maxi(1, total - (int(rung.from) - 1))
	return said

func _up() -> bool:
	return not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))

func _sync_act() -> void:
	_lay_track()
	var up: bool = _up()
	_track.visible = up and not _rungs.is_empty()
	var total: int = _total()
	var rung: Dictionary = _rung_lit()
	var tone: Color = rung.get("tone", DeepUi.MUTED)
	_track.set_total(total, up and settled, _caption(rung, total), tone.lightened(0.1))

func _look_key() -> String:
	return "%s|%s" % [str(_track.visible), str(settled)]

func _plate() -> Control:
	## The rungs in words, for a hover or a held finger: the one the hand is on is lit.
	var box: VBoxContainer = Plates.plate()
	Plates.head(box, "Count %d" % _total(), "blackjack", GOLD)
	var reached: Dictionary = _rung_lit()
	for rung in _rungs:
		var on: bool = str(reached.get("name", "")) == str(rung.name)
		DeepUi.effect_text(box, "%s. %s" % [str(rung.name), str(rung.text)], 12, DeepUi.PAPER if on else DeepUi.MUTED, on)
	DeepUi.effect_text(box, "Hit throws every die again; Stand locks the hand in.", 12, DeepUi.MUTED)
	return box

func _count_spot() -> Vector2:
	## Where the count stands over the marker, in this act's own space.
	if _track == null or not _track.visible:
		return tray_rect().get_center()
	var along: float = _track._x_of(_track.value) if _track.marked else _track.size.x * 0.5
	return _track.position + Vector2(along, _track._line() * 0.55)

# --- drawing ---------------------------------------------------------------------------------------

static func _oval(middle: Vector2, wide: float, tall: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(18):
		var angle: float = TAU * float(step) / 18.0
		points.append(middle + Vector2(cos(angle) * wide, sin(angle) * tall))
	return points

func _draw_chips(middle: Vector2, alpha: float) -> void:
	## A stack of three chips, gold and sphalerite brown, notched white round the rim.
	var wide: float = u(17.0, 9.0)
	var tall: float = wide * 0.42
	var step: float = tall * 0.95
	for chip in range(3):
		var at: Vector2 = middle + Vector2(0.0, -step * float(chip))
		var tone: Color = CHIP if chip % 2 == 0 else CHIP_DARK.lightened(0.15)
		draw_colored_polygon(_oval(at + Vector2(0.0, tall * 0.45), wide, tall), Color(tone.darkened(0.45), alpha))
		draw_colored_polygon(_oval(at, wide, tall), Color(tone, alpha))
		for notch in range(4):
			var angle: float = PI * 0.25 + PI * 0.5 * float(notch)
			var spot: Vector2 = at + Vector2(cos(angle) * wide * 0.8, sin(angle) * tall * 0.8)
			draw_circle(spot, maxf(1.0, tall * 0.22), Color(1.0, 1.0, 1.0, 0.85 * alpha))
		draw_polyline(_oval(at, wide, tall) + PackedVector2Array([_oval(at, wide, tall)[0]]), Color(INK, 0.6 * alpha), maxf(1.0, u(1.2, 0.6)), true)

func _draw() -> void:
	if unit.is_empty() or not _up():
		return
	var now: int = Time.get_ticks_msec()
	_draw_stacks(now)
	_draw_card(now)
	_draw_crack(now)

func _draw_stacks(now: int) -> void:
	for index in range(_stacks.size() - 1, -1, -1):
		var stack: Dictionary = _stacks[index]
		var t: float = (float(now - int(stack.at)) / 1000.0) / float(stack.seconds)
		if t < 0.0:
			continue
		if t >= 1.0:
			_stacks.remove_at(index)
			continue
		var s: float = ease(t, 0.6)
		var from: Vector2 = stack.from
		var to: Vector2 = stack.to
		var at: Vector2 = from.lerp(to, s) + Vector2(0.0, -sin(s * PI) * u(30.0, 14.0))
		_draw_chips(at, clampf((1.0 - t) / 0.15, 0.0, 1.0))

func _draw_card(now: int) -> void:
	## Twenty-One's card: the count turns over like a card to show 21, jolting with each hit.
	if _card_at < 0:
		return
	var t: float = float(now - _card_at) / 1000.0
	if t >= CARD_SECONDS:
		_card_at = -1
		return
	var flip: float = 0.0
	var face: bool = true
	if t < 0.12:
		flip = 1.0 - t / 0.12
		face = false
	elif t < 0.24:
		flip = (t - 0.12) / 0.12
	else:
		flip = 1.0
	var jolt: float = 0.0
	if _card_jolt >= 0:
		jolt = maxf(0.0, 1.0 - float(now - _card_jolt) / 180.0)
	var fade: float = clampf((CARD_SECONDS - t) / 0.3, 0.0, 1.0)
	var size := Vector2(u(58.0, 28.0), u(80.0, 39.0)) * (1.0 + 0.12 * jolt)
	size.x *= maxf(0.04, flip)
	var box := Rect2(_card_spot - size * 0.5 - Vector2(0.0, u(14.0, 7.0)), size)
	var paper := StyleBoxFlat.new()
	paper.set_corner_radius_all(int(u(6.0, 3.0)))
	paper.bg_color = Color(CARD if face else CHIP_DARK, fade)
	paper.border_color = Color(GOLD, fade)
	paper.set_border_width_all(int(maxf(1.0, u(2.0, 1.0))))
	draw_style_box(paper, box)
	if not face:
		## The back: gold lattice on sphalerite brown.
		var inner: Rect2 = box.grow(-u(5.0, 2.5))
		for line in range(4):
			var y: float = inner.position.y + inner.size.y * (float(line) + 0.5) / 4.0
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(GOLD, 0.6 * fade), maxf(1.0, u(1.5, 0.75)))
		return
	if flip > 0.6:
		draw_words("21", box.get_center(), text_px(30, 17), Color(INK, fade), true, true, false)
		var pip: float = u(4.0, 2.0)
		for corner in [box.position + Vector2(pip * 2.0, pip * 2.0), box.end - Vector2(pip * 2.0, pip * 2.0)]:
			draw_colored_polygon(PackedVector2Array([corner + Vector2(0.0, -pip), corner + Vector2(pip * 0.75, 0.0), corner + Vector2(0.0, pip), corner + Vector2(-pip * 0.75, 0.0)]), Color(BUST.darkened(0.1), fade))

func _draw_crack(now: int) -> void:
	## A Bust: the count cracks red; a red streak runs from it to his ring, which flashes red.
	if _crack_at < 0:
		return
	var t: float = float(now - _crack_at) / 1000.0
	if t >= CRACK_SECONDS:
		_crack_at = -1
		return
	var fade: float = clampf((CRACK_SECONDS - t) / 0.45, 0.0, 1.0)
	var grow: float = clampf(t / 0.12, 0.0, 1.0)
	if _track != null and _track.visible:
		draw_rect(Rect2(_track.position, _track.size).grow(u(3.0, 1.5)), Color(BUST, 0.22 * fade))
	for crack in _cracks:
		var points := PackedVector2Array()
		var shown: int = maxi(2, int(ceil(float((crack as PackedVector2Array).size()) * grow)))
		for index in range(mini(shown, (crack as PackedVector2Array).size())):
			points.append(_crack_spot + (crack as PackedVector2Array)[index])
		draw_polyline(points, Color(0.05, 0.0, 0.0, 0.8 * fade), u(5.0, 2.5), true)
		draw_polyline(points, Color(BUST, fade), u(2.5, 1.25), true)
	var ring: Rect2 = ring_rect()
	if ring.size.x <= 0.0:
		return
	## The streak, then the flash once it arrives.
	var go: float = clampf((t - 0.08) / 0.2, 0.0, 1.0)
	if go > 0.0 and go < 1.0:
		var head: Vector2 = _crack_spot.lerp(ring.get_center(), go)
		var tail: Vector2 = _crack_spot.lerp(ring.get_center(), maxf(0.0, go - 0.35))
		draw_line(tail, head, Color(BUST, 0.9), u(6.0, 3.0), true)
		draw_circle(head, u(6.0, 3.0), BUST.lightened(0.3))
	var flash: float = clampf(1.0 - (t - 0.28) / 0.5, 0.0, 1.0) if t >= 0.28 else 0.0
	if flash > 0.0:
		draw_circle(ring.get_center(), ring.size.x * 0.52, Color(BUST, 0.45 * flash))
		draw_arc(ring.get_center(), ring.size.x * (0.52 + 0.12 * (1.0 - flash)), 0.0, TAU, 40, Color(BUST.lightened(0.3), 0.8 * flash), u(4.0, 2.0), true)

# --- firing -----------------------------------------------------------------------------------------

func _rung_named(tier_name: String) -> Dictionary:
	for rung in _rungs:
		if str(rung.name) == tier_name:
			return rung
	return {}

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	if _rungs.is_empty():
		_read_rungs()
	var rung: Dictionary = _rung_named(str(entry.get("name", "")))
	if rung.is_empty():
		return false
	if bool(rung.penalty):
		return _bust(effects, origin)
	if int(rung.from) == int(rung.to):
		return _twenty_one(effects, origin, tone)
	return _stand(entry, rung, effects, origin, tone)

func _stand(entry: Dictionary, rung: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## A stack of chips for every point over 16, sliding from the count to the target one after
	## another, a clack as each arrives; the blow lands with the last.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var points: int = int(entry.get("count", {}).get("coef", _total() - (int(rung.from) - 1)))
	points = clampi(points, 1, 12)
	var from: Vector2 = _count_spot()
	var to: Vector2 = creature_at(str(blows[0].get("target", target_id())))
	var gap: float = 0.09
	var slide: float = 0.34
	if not DeepUi.headless():
		var now: int = Time.get_ticks_msec()
		for index in range(points):
			var aside: float = (float(index) - float(points - 1) * 0.5) * u(14.0, 7.0)
			_stacks.append({"from": from + Vector2(aside, 0.0), "to": to + Vector2(aside * 0.6, u(20.0, 9.0)), "at": now + int(gap * float(index) * 1000.0), "seconds": slide})
			later(gap * float(index) + slide, sound.bind("reel_stop", {"volume": 0.5, "pitch": 1.2 + 0.07 * float(index), "gap": 0.0}))
		busy(gap * float(points) + slide + 0.2)
	later(gap * float(points - 1) + slide - 0.18, land.bind(blows, room_point(from), GOLD))
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	if not rest.is_empty():
		later(gap * float(points) + slide, land.bind(rest, origin, tone))
	return true

func _twenty_one(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The count turns over like a card to 21; three heavy hits leave it with a snap each, and
	## 21 coins go to the purse.
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	var purse: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "gold")
	_card_spot = _count_spot()
	_card_at = Time.get_ticks_msec()
	busy(CARD_SECONDS + 0.2)
	sound("reel_lever", {"volume": 0.5, "pitch": 1.4})
	var at: float = 0.3
	for blow in blows:
		later(at, _snap.bind(blow))
		at += 0.26
	if not purse.is_empty():
		later(at, _coins.bind(purse))
		at += 0.15
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return not str(effect.get("kind", "")) in ["damage", "gold"])
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	return true

func _snap(blow: Dictionary) -> void:
	_card_jolt = Time.get_ticks_msec()
	busy(0.4)
	sound("reel_stop", {"volume": 0.8, "pitch": 1.75, "gap": 0.0})
	burst(_card_spot, Color("ffffff"), 10, 140.0, 0.35, 4.0)
	land([blow], room_point(_card_spot), Color("fff6dc"), 1.6)

func _coins(purse: Array) -> void:
	if fx() != null and screen != null:
		fx().coins(room_point(_card_spot, 2.4), screen._purse(), 21)
	sound("ore", {"volume": 0.7})
	land(purse, room_point(_card_spot), DeepUi.ORE)

func _bust(effects: Array, origin: Vector3) -> bool:
	## The count cracks red and the hit comes back on him: a red streak to his ring, a flash.
	_crack_spot = _count_spot()
	_crack_at = Time.get_ticks_msec()
	_cracks = _crack_lines()
	busy(CRACK_SECONDS + 0.2)
	sound("die_break", {"volume": 0.75})
	later(0.28, sound.bind("hit_heavy", {"volume": 0.55, "pitch": 0.8}))
	if fx() != null:
		fx().puff(room_point(_crack_spot, 2.2), Color(0.32, 0.3, 0.3), 10, 0.5, 0.9, 0.3)
	later(0.08, land.bind(effects, room_point(_crack_spot), BUST))
	return true

func _crack_lines() -> Array:
	## Four jagged cracks out from the count, the same every frame of one Bust.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2117
	var reach: float = u(46.0, 22.0)
	var out: Array = []
	for line in range(4):
		var angle: float = PI * 0.5 * float(line) + rng.randf_range(-0.5, 0.5)
		var points := PackedVector2Array([Vector2.ZERO])
		var at := Vector2.ZERO
		for step in range(4):
			var bend: float = angle + rng.randf_range(-0.6, 0.6)
			at += Vector2(cos(bend), sin(bend) * 0.45) * reach * 0.25
			points.append(at)
		out.append(points)
	return out
