extends "res://view/battle/birth_act.gd"
## Cadence's Nocturne: a quiet hand wakes the gems that stayed dark.
##
## The game shows no total of its own, so the hand's total stands over the tray on a track cut
## at the stone's three rungs (16, 12 and 9 as content has them), a marker on the cell the hand
## is in and the rung's name beside the number. Every dark gem the hand would wake wears a small
## moon at its ring's corner before the rail closes: the first of them under Hush, all of them
## under Nocturne, two moons each under Small Hours.
##
## When the stone fires the dock dims to indigo for a beat and the moons glow. The woken gems
## then fire as events of their own, the way the screen plays any gem: as each arrives its moon
## swells and goes out on a soft bell, a step up the music's scale for every gem. A gem's second
## go under Small Hours is its echo: the same note again, softer and an octave up.
##
## Both layouts draw the same pieces; the phone's track stands over the tray, clear of the line
## of words that floats there.

const TotalTrack = preload("res://view/battle/birth/total_track.gd")

const INDIGO := Color("1b2150")
const NIGHT := Color(0.05, 0.06, 0.13)
const MOONLIGHT := Color("e6eaff")
const WASH_SECONDS: float = 1.5
const FADE_MS: int = 480

var _track: Control = null
## The stone's rungs as content wrote them, quietest first: [{name, most, wakes, times, text, tone}].
var _rungs: Array = []
var _laid: String = ""
## While the hand is planned: the dark gems it would wake, by socket, and how many moons each wears.
var _moons: Dictionary = {}
## Once the stone has fired: the goes each woken gem still has to play, by socket.
var _waking: Dictionary = {}
## Moons going out: [{socket, slot, at}].
var _fading: Array = []
var _stone_fired: bool = false
var _wash_at: int = -1
var _bells: int = 0
var _last_woken: int = -1

func _open() -> void:
	_track = TotalTrack.new()
	_track.visible = false
	place(_track, "over_tray", 0.5)
	tip(_track, _plate, {"tone": tint.lightened(0.3)})

# --- the hand's total ----------------------------------------------------------------------------

func _total() -> int:
	## The total as the stone reads it: every die's number, a wild counting as 1.
	var read: Dictionary = reading()
	return int(read.get("total", 0)) - int(read.get("wild_total", 0)) + read.get("wilds", []).size()

func _read_rungs() -> void:
	var out: Array = []
	for def in defs:
		if not def is Dictionary or str(def.get("trigger", {}).get("kind", "")) != "total_at_most":
			continue
		var wakes: int = 0
		var times: int = 1
		for effect in def.get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "replay_fizzled":
				wakes = maxi(1, int(effect.get("amount", 1)))
				times = maxi(1, int(effect.get("repeat", 1)))
		out.append({"name": str(def.get("name", "")), "most": int(def.trigger.get("amount", 0)), "wakes": wakes, "times": times, "text": str(def.get("text", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.most) < int(b.most))
	## The quietest rung is the brightest: moonlight, then the iolite's blue, then its grey.
	var tones: Array = [MOONLIGHT, tint.lightened(0.42), tint.lerp(tint2, 0.55).lightened(0.12)]
	for index in range(out.size()):
		out[index].tone = tones[mini(index, tones.size() - 1)]
	_rungs = out

func _lay_track() -> void:
	## The track's cells, one a rung and one for a hand too loud for any, each as wide as its
	## words need at the text floor.
	if _rungs.is_empty():
		_read_rungs()
	var key: String = "%s|%d|%s" % [str(_rungs.map(func(rung: Dictionary) -> int: return int(rung.most))), DeepUi.min_text(), str(DeepUi.phone)]
	if key == _laid or _rungs.is_empty():
		return
	_laid = key
	var font: Font = DeepUi.bold_font()
	var px: int = DeepUi.min_text()
	var pad: float = u(11.0, 5.0)
	var cells: Array = []
	var floor_at: int = 0
	for index in range(_rungs.size()):
		var most: int = int(_rungs[index].most)
		var label: String = "%d or less" % most if index == 0 else ("%d" % most if floor_at == most else "%d-%d" % [floor_at, most])
		cells.append({"from": floor_at, "to": most, "label": label, "tone": _rungs[index].tone})
		floor_at = most + 1
	cells.append({"from": floor_at, "to": floor_at + 40, "label": "%d+" % floor_at, "tone": DeepUi.MUTED})
	var span: float = 0.0
	for cell in cells:
		cell.weight = font.get_string_size(str(cell.label), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + pad * 2.0
		span += float(cell.weight)
	_track.lay(cells, span)

func _rung_lit() -> Dictionary:
	## The rung the hand has reached, as the forecast (or the turn itself) says.
	for rung in _rungs:
		if lit(str(rung.name)):
			return rung
	return {}

func _sync_act() -> void:
	_lay_track()
	## A new hand is being planned: last turn's waking is over.
	if planning and _stone_fired:
		_stone_fired = false
		_waking.clear()
		_bells = 0
		_last_woken = -1
	var up: bool = not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	_track.visible = up and not _rungs.is_empty()
	var rung: Dictionary = _rung_lit()
	var tone: Color = rung.get("tone", DeepUi.MUTED)
	_track.set_total(_total(), up and settled, str(rung.get("name", "")), tone.lightened(0.15))
	_moons = _read_moons() if up and not _stone_fired else {}

func _look_key() -> String:
	return "%s|%s|%s|%s" % [str(_moons), str(_waking), str(settled), str(_stone_fired)]

func _plate() -> Control:
	## The three rungs in words, for a hover or a held finger: the one the hand is on is lit.
	var box: VBoxContainer = Plates.plate()
	Plates.head(box, "Total %d" % _total(), "nocturne", tint.lightened(0.4))
	var reached: Dictionary = _rung_lit()
	for index in range(_rungs.size() - 1, -1, -1):
		var rung: Dictionary = _rungs[index]
		var on: bool = str(reached.get("name", "")) == str(rung.name)
		DeepUi.effect_text(box, "%s. %s" % [str(rung.name), str(rung.text)], 12, DeepUi.PAPER if on else DeepUi.MUTED, on)
	return box

# --- the moons -----------------------------------------------------------------------------------

func _read_moons() -> Dictionary:
	## The dark gems this hand would wake and how many times each: the sockets the forecast's
	## own lit rung says it would reach, or, where it does not say, the rail's dark gems in order.
	var out: Dictionary = {}
	if not settled:
		return out
	for index in range(mini(tiers.size(), defs.size())):
		var entry: Variant = tiers[index]
		if not entry is Dictionary or not bool(entry.get("active", false)):
			continue
		var most: int = 0
		var times: int = 1
		for effect in defs[index].get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "replay_fizzled":
				most = maxi(1, int(effect.get("amount", 1)))
				times = maxi(1, int(effect.get("repeat", 1)))
		if most <= 0:
			continue
		var sockets: Array = []
		var told: bool = false
		for effect in entry.get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "replay_fizzled" and effect.has("sockets"):
				sockets = effect.sockets
				told = true
		if not told:
			for seen in forecast().get("sockets", []):
				if seen is Dictionary and not bool(seen.get("empty", false)) and not bool(seen.get("active", false)) and sockets.size() < most:
					sockets.append(int(seen.get("socket", -1)))
		for socket in sockets:
			out[int(socket)] = maxi(int(out.get(int(socket), 0)), times)
	return out

func _ring_of(socket: int) -> Rect2:
	## A gem's ring on the rail, by the socket the fight names: the rail is laid flat there, so
	## a Void gem riding a socket has a number of its own.
	var cards: Array = page.socket_cards if page != null else []
	if socket < 0 or socket >= cards.size():
		return socket_rect(socket)
	var card: Variant = cards[socket]
	if card == null or not card is Control or not is_instance_valid(card):
		return Rect2()
	var slot: Node = (card as Control).get_node_or_null("Slot")
	return _rect_of(slot if slot != null else card)

func _moon_box(socket: int, slot: int) -> Rect2:
	## A moon's square at a ring's top left corner (the Void's riders stand round its right
	## side); a second moon stands beside the first.
	var ring: Rect2 = _ring_of(socket)
	if ring.size.x <= 0.0:
		return Rect2()
	var edge: float = maxf(ring.size.x * 0.3, u(24.0, 12.0))
	return Rect2(ring.position + Vector2(-edge * 0.3 + edge * 0.78 * float(slot), -edge * 0.3), Vector2(edge, edge))

func _draw_moon(box: Rect2, glow: float, alpha: float, swell: float = 1.0) -> void:
	if box.size.x <= 0.0 or alpha <= 0.0:
		return
	var middle: Vector2 = box.get_center()
	var r: float = box.size.x * 0.5 * swell
	if glow > 0.0:
		draw_circle(middle, r * (1.6 + 0.5 * glow), Color(MOONLIGHT, 0.2 * glow * alpha))
	draw_circle(middle, r * 1.1, Color(NIGHT, 0.94 * alpha))
	draw_arc(middle, r * 1.1, 0.0, TAU, 28, Color(tint.lightened(0.3 + 0.3 * glow), alpha), maxf(1.5, u(2.0, 1.0)), true)
	if GemIcons.known("moon"):
		draw_glyph("moon", Rect2(middle - Vector2(r, r) * 0.74, Vector2(r, r) * 1.48), Color(MOONLIGHT, alpha))
	else:
		draw_circle(middle, r * 0.66, Color(MOONLIGHT, alpha))
		draw_circle(middle + Vector2(r * 0.3, -r * 0.14), r * 0.56, Color(NIGHT, alpha))

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	## The dock gone indigo for a beat as the stone fires.
	var night: float = 0.0
	if _wash_at >= 0:
		var t: float = float(now - _wash_at) / 1000.0
		if t >= WASH_SECONDS:
			_wash_at = -1
		else:
			night = clampf(t / 0.22, 0.0, 1.0) * clampf((WASH_SECONDS - t) / 0.55, 0.0, 1.0)
			var dock: Rect2 = dock_rect()
			if dock.size.x > 0.0:
				draw_rect(dock, Color(INDIGO, 0.58 * night))
	if not settled:
		return
	var worn: Dictionary = _waking if _stone_fired else _moons
	for socket in worn:
		for slot in range(mini(int(worn[socket]), 3)):
			_draw_moon(_moon_box(int(socket), slot), night if _stone_fired else 0.0, 1.0)
	## A moon whose gem has just woken swells and goes out.
	for index in range(_fading.size() - 1, -1, -1):
		var going: Dictionary = _fading[index]
		var gone: float = float(now - int(going.at)) / float(FADE_MS)
		if gone >= 1.0:
			_fading.remove_at(index)
			continue
		_draw_moon(_moon_box(int(going.socket), int(going.slot)), 1.0 - gone, 1.0 - gone * gone, 1.0 + 0.7 * gone)

# --- firing --------------------------------------------------------------------------------------

func _fired(played: Dictionary) -> void:
	## The stone lights: the dock dims, and the gems it is about to wake keep their moons until
	## each has played.
	_stone_fired = true
	_moons.clear()
	var listed: Array = played.get("tiers", [])
	for index in range(mini(listed.size(), defs.size())):
		var entry: Variant = listed[index]
		if not entry is Dictionary or not bool(entry.get("active", false)):
			continue
		var times: int = 1
		for effect in defs[index].get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "replay_fizzled":
				times = maxi(1, int(effect.get("repeat", 1)))
		for effect in entry.get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "replay_fizzled" and not bool(effect.get("nothing", false)):
				for socket in effect.get("sockets", []):
					_waking[int(socket)] = int(_waking.get(int(socket), 0)) + times
	_wash_at = Time.get_ticks_msec()
	busy(WASH_SECONDS + 0.2)

func _tier(_entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## The rung lands nothing itself: it says how many gems wake, and they follow as their own.
	var wakes: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "replay_fizzled")
	if wakes.is_empty():
		return false
	var count: int = 0
	for effect in wakes:
		if not bool(effect.get("nothing", false)):
			count += effect.get("sockets", []).size()
	var card: Control = stone_card()
	if card != null:
		say(card, "Nothing stayed dark" if count <= 0 else ("%d gems wake" % count if count > 1 else "A gem wakes"), MOONLIGHT if count > 0 else DeepUi.DIM, 16)
	if count > 0:
		sound("gleam", {"volume": 0.4, "pitch": 0.75})
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "replay_fizzled")
	if not rest.is_empty():
		land(rest, origin, tone)
	return true

func _event(played: Dictionary) -> void:
	var kind: String = str(played.get("kind", ""))
	if unit.is_empty() or str(played.get("unit", "")) != str(unit.get("id", "")):
		return
	var socket: int = int(played.get("socket", -1))
	match kind:
		"gem_fire":
			if _stone_fired and _waking.has(socket):
				_wake(socket, true)
		"gem_fizzle":
			## A woken gem its socket still holds down (buried, clouded): its moon goes out unrung.
			if _stone_fired and _waking.has(socket):
				_wake(socket, false)
		"rail_end":
			_waking.clear()

func _wake(socket: int, rings: bool) -> void:
	var left: int = int(_waking.get(socket, 0)) - 1
	if left <= 0:
		_waking.erase(socket)
	else:
		_waking[socket] = left
	_fading.append({"socket": socket, "slot": maxi(0, left), "at": Time.get_ticks_msec()})
	busy(float(FADE_MS) / 1000.0 + 0.1)
	if not rings or not on_screen() or DeepUi.headless():
		_last_woken = socket
		return
	## A bell a step higher for every gem that wakes; a gem's second go is its echo.
	var echo: bool = socket == _last_woken
	if not echo:
		_bells += 1
	_last_woken = socket
	sound("tick_violet", {"pitch": _pitch(_bells - 1, 1 if echo else 0), "volume": 0.5 if echo else 0.8, "gap": 0.0, "vary": 0.0})
	var box: Rect2 = _moon_box(socket, maxi(0, left))
	if box.size.x > 0.0:
		burst(box.get_center(), MOONLIGHT, 10, 90.0, 0.5, 3.0)

static func _pitch(step: int, octave: int = 0) -> float:
	## The pitch that puts a sound written on C on this step of the scale the music is in.
	var key: Dictionary = DeepMusic.tonic()
	var steps: Array = key.get("steps", [0, 2, 4, 7, 9])
	var pc: int = int(key.get("pc", 0))
	var shift: int = pc if pc <= 6 else pc - 12
	var at: int = maxi(0, step)
	var up: int = octave + int(floor(float(at) / float(maxi(1, steps.size()))))
	return pow(2.0, float(shift + 12 * mini(up, 2) + int(steps[at % maxi(1, steps.size())])) / 12.0)
