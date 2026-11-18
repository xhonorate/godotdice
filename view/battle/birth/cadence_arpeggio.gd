extends "res://view/battle/birth_act.gd"
## Cadence's Arpeggio: the scale, written over the tray as a staff.
##
## A short staff of five faint lines stands over the dock above the dice, clear of them and of
## the line of words that floats there (the owner, November 18: the notes at the dice's
## shoulders read strangely). Every die has a note on it straight over the die, standing higher
## the more the die shows, so the hand reads like a line of music. The scale (the longest climb
## from her smallest die to her largest, each showing more than the one before) is the line
## drawn through its notes, violet at the low end and green at the top; a die out of the scale
## keeps its note grey and off the line. Two notes are a faint line still waiting for a third.
## All five close the staff with a double bar: Perfect. It is drawn again after every throw, so
## the scale is read and not counted.
##
## When the stone fires the notes are played in order: each rings a step up the music's scale,
## its number flies from its note into the Resonance count, the count climbs, and then its blow
## leaves the count as a ring of light across the creatures, wider as the Resonance grows.
## Perfect Scale plays the staff again, faster and an octave up, off the double bar.
##
## The phone draws the same staff at its dice's own spacing, in points, over its tray.

const NOTE_GAP: float = 0.2
const AGAIN_GAP: float = 0.12
const FLY_SECONDS: float = 0.17
const RING_MS: int = 360
const BAR_MS: int = 700
const INK := Color(0.02, 0.03, 0.06)

## The dice in the scale, in order, and what each shows.
var _in_scale: Array = []
var _values: Array = []
## Every die's number by id, and the numbers showing, low to high: a note's height is its rank.
var _shown: Dictionary = {}
var _ranks: Array = []
## The hand plays (a scale long enough), and plays twice (every die in it).
var _plays: bool = false
var _perfect: bool = false
var _need: int = 3
var _whole: int = 5
## The Resonance count the fight holds, kept as its events go by, for the notes to climb from.
var _count: int = -1
var _rang: Dictionary = {}
var _bar_at: int = -1
var _passes: int = 0

# --- reading the scale ---------------------------------------------------------------------------

func _sync_act() -> void:
	var asked: Array = []
	for def in defs:
		if def is Dictionary and str(def.get("trigger", {}).get("kind", "")) == "scale":
			asked.append(maxi(1, int(def.trigger.get("amount", 1))))
	if not asked.is_empty():
		_need = int(asked.min())
		_whole = int(asked.max())
	_in_scale = []
	_values = []
	_shown = {}
	_ranks = []
	_plays = false
	_perfect = false
	if not settled or unit.is_empty() or bool(unit.get("downed", false)):
		return
	for roll in dice():
		var kind: String = str(roll.get("kind", "plain"))
		if kind == "blank":
			continue
		## A wild reads as its die's top, as the scale reads it.
		var value: int = maxi(1, int(roll.get("top", roll.get("value", 0)))) if kind == "wild" else int(roll.get("value", 0))
		_shown[str(roll.get("die_id", ""))] = value
		if not _ranks.has(value):
			_ranks.append(value)
	_ranks.sort()
	var climb: Dictionary = reading().get("scale", {})
	for index in range(climb.get("dice", []).size()):
		var id: String = str(climb.dice[index])
		if _shown.has(id):
			_in_scale.append(id)
			_values.append(int(climb.values[index]))
	## What the forecast (or the turn) says of the rungs, where it is known; else the scale's length.
	var known: bool = false
	var lit_rungs: int = 0
	for entry in tiers:
		if entry is Dictionary:
			known = true
			if bool(entry.get("active", false)):
				lit_rungs += 1
	_plays = lit_rungs > 0 if known else _in_scale.size() >= _need
	_perfect = _plays and _in_scale.size() >= _whole

func _look_key() -> String:
	## The staff moves with the dock's top edge and the ledger's foot.
	return "%s|%s|%s|%s|%s|%s" % [str(_shown), str(_in_scale), str(_plays), str(_perfect), str(settled), str(_staff())]

# --- the staff -----------------------------------------------------------------------------------

func _gap() -> float:
	## The space between two lines of the staff.
	return float(_lay().get("gap", _head()))

func _head() -> float:
	## How tall a note's head is: a space of the staff at its fullest. It keeps this size where
	## the staff's lines are drawn closer, so a note never shrinks past reading.
	return u(10.0, 4.5)

func _staff() -> Rect2:
	## The staff's five lines, top line to bottom line.
	return _lay().get("staff", Rect2())

func _lay() -> Dictionary:
	## The staff as wide as the tray, standing over the dock with half a head's room under its
	## bottom line. On the phone it stands where the line of words over the dice leaves it room
	## whether or not the line is up (it comes as the turn resolves, and the staff would jump),
	## and keeps under the creature's ledger when the ledger stands over the tray: its lines
	## drawn closer then and the stems of its highest notes shorter, the heads kept their size.
	var tray: Rect2 = tray_rect()
	if tray.size.x <= 0.0:
		return {}
	var foot: float = tray.position.y - DeepUi.pt(26.0) if DeepUi.phone else over_tray()
	var head: float = _head()
	var bottom: float = foot - head * 0.5 - u(3.0, 1.5)
	var gap: float = head
	var ceiling: float = -INF
	var ledger: Rect2 = _ledger_rect()
	if ledger.size.x > 0.0 and ledger.end.x > tray.position.x and ledger.position.x < tray.end.x and ledger.end.y < foot:
		ceiling = ledger.end.y + u(6.0, 2.5)
		## Room over the top line for a stem near half its length.
		gap = clampf((bottom - ceiling - head / 0.31 * 0.45) / 4.0, u(6.0, 2.75), head)
	var top: float = bottom - gap * 4.0
	return {"gap": gap, "ceiling": ceiling, "staff": Rect2(tray.position.x + u(4.0, 2.0), top, tray.size.x - u(8.0, 4.0), bottom - top)}

func _ledger_rect() -> Rect2:
	## The creature's ledger at the top right, while it is up.
	var panel: Variant = screen.get("_enemy_panel") if screen != null else null
	if panel == null or not panel is Control or not is_instance_valid(panel) or not (panel as Control).is_visible_in_tree():
		return Rect2()
	return _rect_of(panel)

func _spot(die_id: String) -> Vector2:
	## Where a die's note head sits: on the staff straight over its die, its height by its rank
	## among the numbers showing (the lowest on the bottom line, the highest on the top one,
	## the rest on the lines and spaces between, spread evenly).
	var seat: Rect2 = die_rect(die_id)
	var staff: Rect2 = _staff()
	if seat.size.x <= 0.0 or staff.size.x <= 0.0 or not _shown.has(die_id):
		return Vector2.INF
	var rank: int = maxi(0, _ranks.find(int(_shown[die_id])))
	var steps: int = _ranks.size() - 1
	## In half spaces up from the bottom line: eight of them to the top line.
	var half: int = 4 if steps <= 0 else int(round(float(rank) * 8.0 / float(steps)))
	return Vector2(seat.get_center().x, staff.end.y - _gap() * 0.5 * float(clampi(half, 0, 8)))

func _draw_staff(staff: Rect2) -> void:
	## Five faint lines, edged dark so they read over the room's light.
	for line in range(5):
		var y: float = staff.position.y + _gap() * float(line)
		draw_line(Vector2(staff.position.x, y), Vector2(staff.end.x, y), Color(INK, 0.5), u(4.0, 2.0), true)
		draw_line(Vector2(staff.position.x, y), Vector2(staff.end.x, y), Color(DeepUi.PAPER, 0.5), u(1.5, 0.75), true)
	## A thin bar opening the staff.
	draw_line(Vector2(staff.position.x, staff.position.y), Vector2(staff.position.x, staff.end.y), Color(INK, 0.5), u(4.0, 2.0), true)
	draw_line(Vector2(staff.position.x, staff.position.y), Vector2(staff.position.x, staff.end.y), Color(DeepUi.PAPER, 0.5), u(1.5, 0.75), true)

func _hue(step: int, steps: int) -> Color:
	## Fluorite's two colors along the scale: violet at its foot, green at its top.
	return tint.lightened(0.45).lerp(tint2.lightened(0.4), float(step) / float(maxi(1, steps - 1)))

func _draw_note(head: Vector2, tall: float, tone: Color, ceiling: float) -> void:
	## One note, drawn as the kit's `note` mark is (a head tilted, a stem up and its flag), its
	## head `tall` high on `head`. Its stem stops short of `ceiling` (the ledger's foot on the
	## phone), never under half its length.
	var edge: float = tall / 0.31
	var stem: float = clampf(head.y - ceiling, edge * 0.4, edge * 0.73)
	## The head, an oval tilted up to the right.
	var oval := PackedVector2Array()
	for step in range(18):
		var angle: float = TAU * float(step) / 18.0
		oval.append(head + Vector2(cos(angle) * 0.21 * edge, sin(angle) * 0.155 * edge).rotated(-0.35))
	var stem_box := Rect2(head.x + 0.11 * edge, head.y - stem, 0.13 * edge, stem)
	## The flag from the stem's top, falling back toward the head and curling right.
	var far := Vector2(stem_box.end.x, stem_box.position.y)
	var flag := PackedVector2Array()
	var share: float = stem / (0.73 * edge)
	for point in [[0.0, 0.0], [0.10, 0.18], [0.30, 0.30], [0.30, 0.56], [0.18, 0.40], [0.0, 0.34]]:
		flag.append(far + Vector2(float(point[0]) * edge, float(point[1]) * edge * share))
	var ink := Color(INK, 0.85 * tone.a)
	var rim: float = u(3.0, 1.5)
	draw_colored_polygon(oval, ink)
	draw_polyline(oval + PackedVector2Array([oval[0]]), ink, rim, true)
	draw_rect(stem_box.grow(rim * 0.5), ink)
	draw_polyline(flag + PackedVector2Array([flag[0]]), ink, rim, true)
	draw_colored_polygon(flag, ink)
	draw_colored_polygon(oval, tone)
	draw_rect(stem_box, tone)
	draw_colored_polygon(flag, tone)

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)) or not settled or _shown.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var laid: Dictionary = _lay()
	var staff: Rect2 = laid.get("staff", Rect2())
	if staff.size.x <= 0.0:
		return
	var ceiling: float = float(laid.get("ceiling", -INF))
	_draw_staff(staff)
	var tall: float = _head()
	var count: int = _in_scale.size()
	## The dice out of the scale: their notes grey, where their numbers put them, off the line.
	for id in _shown:
		if _in_scale.has(id):
			continue
		var off: Vector2 = _spot(str(id))
		if off != Vector2.INF:
			_draw_note(off, tall * 0.86, Color(DeepUi.DIM.lightened(0.12), 0.8), ceiling)
	var heads: Array = []
	for id in _in_scale:
		heads.append(_spot(str(id)))
	if heads.has(Vector2.INF) or heads.is_empty():
		return
	## The line through the scale: bright once it plays, faint while it is a note or two short.
	var thick: float = u(3.0, 1.5) if _plays else u(2.0, 1.0)
	for index in range(1, count):
		var tone: Color = _hue(index, count) if _plays else Color(tint.lightened(0.35), 0.55)
		draw_line(heads[index - 1], heads[index], Color(INK, 0.7), thick + u(3.0, 1.5), true)
		draw_line(heads[index - 1], heads[index], tone, thick, true)
	## A fifth note closes the staff with a double bar.
	if _perfect:
		_draw_bar(heads, thick, now)
	for index in range(count):
		var tone: Color = _hue(index, count) if _plays else Color(tint.lightened(0.35), 0.8)
		var swell: float = 1.0
		var id: String = str(_in_scale[index])
		if _rang.has(id):
			var since: float = float(now - int(_rang[id])) / float(RING_MS)
			if since < 1.0:
				swell = 1.0 + 0.6 * (1.0 - since)
				tone = tone.lerp(Color.WHITE, 0.8 * (1.0 - since))
				draw_circle(heads[index], tall * 2.0 * (0.6 + since), Color(tone, 0.35 * (1.0 - since)))
		_draw_note(heads[index], tall * swell, tone, ceiling)

func _bar_x() -> float:
	## The double bar closes the staff at its right end.
	return _staff().end.x

func _draw_bar(heads: Array, thick: float, now: int) -> void:
	var staff: Rect2 = _staff()
	if staff.size.x <= 0.0:
		return
	var tone: Color = tint2.lightened(0.45)
	var flash: float = clampf(1.0 - float(now - _bar_at) / float(BAR_MS), 0.0, 1.0) if _bar_at >= 0 else 0.0
	tone = tone.lerp(Color.WHITE, 0.8 * flash)
	var x: float = _bar_x()
	var top: float = staff.position.y
	var foot: float = staff.end.y
	var heavy: float = u(5.0, 2.5)
	var light: float = u(2.0, 1.0)
	var inner: float = x - heavy - u(4.0, 2.0)
	## The line runs on from the top note to the bar, where no other note stands in its way.
	var last: Vector2 = heads[heads.size() - 1]
	var clear: bool = true
	for head in heads:
		if (head as Vector2).x > last.x + 1.0:
			clear = false
	if clear and last.x < inner:
		draw_line(last, Vector2(inner, last.y), Color(INK, 0.7), thick + u(3.0, 1.5), true)
		draw_line(last, Vector2(inner, last.y), tone, thick, true)
	draw_rect(Rect2(inner - light - 1.0, top - 1.0, x - inner + light + 2.0, foot - top + 2.0), Color(INK, 0.7))
	draw_rect(Rect2(inner - light, top, light, foot - top), tone)
	draw_rect(Rect2(x - heavy, top, heavy, foot - top), tone)
	if flash > 0.0:
		draw_rect(Rect2(inner - light, top, x - inner + light, foot - top).grow(u(6.0, 3.0) * flash), Color(tone, 0.3 * flash))

# --- playing it ----------------------------------------------------------------------------------

func _event(played: Dictionary) -> void:
	## The count the rail has reached, gem by gem: the notes climb on from it.
	if unit.is_empty() or str(played.get("unit", "")) != str(unit.get("id", "")):
		return
	if str(played.get("kind", "")) in ["rail_begin", "gem_fire", "gem_fizzle"] and played.has("resonance"):
		_count = int(played.resonance)

func _fired(_played: Dictionary) -> void:
	_passes = 0
	if _count < 0 and page != null:
		_count = int(page.resonance_shown)

func _tier(_entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## The notes of a pass, one after another inside the beat its blows were given; the second
	## pass (Perfect Scale) goes faster.
	var passes: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "arpeggio" and not bool(effect.get("nothing", false)))
	if passes.is_empty():
		return false
	var at: float = 0.0
	for effect in passes:
		var notes: Array = effect.get("notes", [])
		var again: bool = _passes > 0
		_passes += 1
		if notes.is_empty():
			continue
		var room: float = maxf(DeepBattle.BIRTH_LAND, DeepBattle.hits_span(effect.get("hits", [])))
		var gap: float = clampf(room / float(notes.size()), 0.07, AGAIN_GAP if again else NOTE_GAP)
		if again:
			later(at, _strike_bar)
		for index in range(notes.size()):
			later(at + gap * float(index), _play.bind(notes[index], index, notes.size(), again, origin))
		at += gap * float(notes.size())
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "arpeggio")
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	return true

func _strike_bar() -> void:
	## Perfect: the double bar rings and the staff is played again.
	_bar_at = Time.get_ticks_msec()
	busy(float(BAR_MS) / 1000.0 + 0.1)
	sound("harmony", {"volume": 0.7, "pitch": 1.2})
	var staff: Rect2 = _staff()
	if staff.size.x > 0.0:
		burst(Vector2(_bar_x() - u(5.0, 2.5), staff.get_center().y), tint2.lightened(0.5), 14, 130.0, 0.5, 4.0)

func _play(note: Dictionary, index: int, steps: int, again: bool, origin: Vector3) -> void:
	## One note: it rings, and its number leaves its die for the Resonance count.
	var id: String = str(note.get("die", ""))
	var hue: Color = _hue(index, steps)
	_rang[id] = Time.get_ticks_msec()
	busy(float(RING_MS) / 1000.0 + FLY_SECONDS + 0.2)
	sound("tick_white", {"pitch": _pitch(index, 1 if again else 0), "volume": 0.9, "gap": 0.0, "vary": 0.0})
	var counter: Rect2 = resonance_rect()
	if not DeepUi.headless() and counter.size.x > 0.0:
		var head: Vector2 = _spot(id)
		var from: Vector2 = head if head != Vector2.INF else tray_rect().get_center()
		burst(from, hue, 8, 90.0, 0.4, 3.0)
		_fly("+%s" % DeepUi.number(int(note.get("value", 0))), from, counter.get_center(), hue)
	later(FLY_SECONDS, _arrive.bind(note, index, hue, origin))

func _fly(text: String, from: Vector2, to: Vector2, tone: Color) -> void:
	## A note's number on its way into the count.
	var said: Label = words(self, text, 22, tone.lightened(0.2))
	var half: Vector2 = said.get_combined_minimum_size() * 0.5
	said.size = half * 2.0
	said.pivot_offset = half
	said.position = from - half
	said.scale = Vector2.ONE * 1.3
	var tween := said.create_tween()
	tween.tween_property(said, "position", to - half, FLY_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(said, "scale", Vector2.ONE * 0.85, FLY_SECONDS)
	tween.tween_callback(said.queue_free)

func _arrive(note: Dictionary, index: int, hue: Color, origin: Vector3) -> void:
	## The number lands: the count climbs, and the blow it has grown leaves as a ring of light.
	_count = DeepRules.sat_add(maxi(_count, 0), maxi(0, int(note.get("value", 0))))
	var hits: Array = note.get("hits", [])
	if DeepUi.headless() or screen == null:
		return
	var from: Vector3 = origin
	var counter: Rect2 = resonance_rect()
	if counter.size.x > 0.0 and page != null:
		screen._show_resonance(_count, page)
		DeepUi.spring(page.resonance_box, 0.3, 5.0, 0.4)
		burst(counter.get_center(), hue, 10, 110.0, 0.4, 4.0)
		from = room_point(counter.get_center())
	if hits.is_empty():
		return
	var room: Node3D = fx()
	if room != null:
		## The ring rolls out from between the creatures it reaches, wider the more it carries.
		var middle := Vector3.ZERO
		for hit in hits:
			middle += creature_point(str(hit.get("target", "")))
		middle /= float(hits.size())
		var wide: float = 2.4 + 0.55 * float(index) + 0.05 * float(mini(int(note.get("resonance", 0)), 70))
		room.ring_wave(Vector3(middle.x, 0.0, middle.z), hue, wide, 0.5, 0.3)
	## Every creature takes it at once.
	for hit in hits:
		land([hit], from, hue)

static func _pitch(step: int, octave: int = 0) -> float:
	## The pitch that puts a sound written on C on this step of the scale the music is in.
	var key: Dictionary = DeepMusic.tonic()
	var steps: Array = key.get("steps", [0, 2, 4, 7, 9])
	var pc: int = int(key.get("pc", 0))
	var shift: int = pc if pc <= 6 else pc - 12
	var at: int = maxi(0, step)
	var up: int = octave + int(floor(float(at) / float(maxi(1, steps.size()))))
	return pow(2.0, float(shift + 12 * mini(up, 2) + int(steps[at % maxi(1, steps.size())])) / 12.0)
