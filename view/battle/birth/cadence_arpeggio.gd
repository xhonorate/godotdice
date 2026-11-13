extends "res://view/battle/birth_act.gd"
## Cadence's Arpeggio: the scale, written across the tray as a staff.
##
## Every die wears a note at its shoulder, standing higher the more the die shows, so the hand
## reads like a line of music. The scale (the longest climb from her smallest die to her largest,
## each showing more than the one before) is the line drawn through its notes, violet at the low
## end and green at the top; a die out of the scale keeps its note grey and off the line. Two
## notes are a faint line still waiting for a third. All five close the staff with a double bar:
## Perfect. It is drawn again after every throw, so the scale is read and not counted.
##
## When the stone fires the notes are played in order: each rings a step up the music's scale,
## its number flies from its die into the Resonance count, the count climbs, and then its blow
## leaves the count as a ring of light across the creatures, wider as the Resonance grows.
## Perfect Scale plays the staff again, faster and an octave up, off the double bar.
##
## The phone draws the same staff at its dice's own spacing.

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
	return "%s|%s|%s|%s|%s" % [str(_shown), str(_in_scale), str(_plays), str(_perfect), str(settled)]

# --- the staff -----------------------------------------------------------------------------------

func _spot(die_id: String) -> Vector2:
	## Where a die's note head sits: at the die's left shoulder, between it and the die before,
	## a step higher for every number showing that is lower than its own.
	var seat: Rect2 = die_rect(die_id)
	if seat.size.x <= 0.0 or not _shown.has(die_id):
		return Vector2.INF
	var rank: int = clampi(_ranks.find(int(_shown[die_id])), 0, 5)
	return Vector2(seat.position.x + seat.size.x * 0.13, seat.position.y + u(35.0, 17.5) - u(6.0, 3.0) * float(rank))

func _hue(step: int, steps: int) -> Color:
	## Fluorite's two colors along the scale: violet at its foot, green at its top.
	return tint.lightened(0.45).lerp(tint2.lightened(0.4), float(step) / float(maxi(1, steps - 1)))

func _draw_note(head: Vector2, edge: float, tone: Color) -> void:
	## One note, its head on `head`: the kit's mark, or a head and a stem where it has none.
	if GemIcons.known("note"):
		var box := Rect2(head - Vector2(0.36, 0.79) * edge, Vector2(edge, edge))
		draw_glyph("note", Rect2(box.position + Vector2(0.0, u(2.0, 1.0)), box.size).grow(u(1.5, 0.75)), Color(INK, 0.85 * tone.a))
		draw_glyph("note", box, tone)
		return
	var thick: float = maxf(1.5, edge * 0.11)
	draw_circle(head, edge * 0.24, Color(INK, 0.85 * tone.a))
	draw_circle(head, edge * 0.19, tone)
	draw_line(head + Vector2(edge * 0.16, 0.0), head + Vector2(edge * 0.16, -edge * 0.72), tone, thick, true)

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)) or not settled or _shown.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var edge: float = u(24.0, 12.0)
	var count: int = _in_scale.size()
	## The dice out of the scale: their notes grey, where their numbers put them, off the line.
	for id in _shown:
		if _in_scale.has(id):
			continue
		var off: Vector2 = _spot(str(id))
		if off != Vector2.INF:
			_draw_note(off, edge * 0.86, Color(DeepUi.DIM.lightened(0.12), 0.8))
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
		_draw_bar(heads[count - 1], thick, now)
	for index in range(count):
		var tone: Color = _hue(index, count) if _plays else Color(tint.lightened(0.35), 0.8)
		var swell: float = 1.0
		var id: String = str(_in_scale[index])
		if _rang.has(id):
			var since: float = float(now - int(_rang[id])) / float(RING_MS)
			if since < 1.0:
				swell = 1.0 + 0.6 * (1.0 - since)
				tone = tone.lerp(Color.WHITE, 0.8 * (1.0 - since))
				draw_circle(heads[index], edge * 0.6 * (0.6 + since), Color(tone, 0.35 * (1.0 - since)))
		_draw_note(heads[index], edge * swell, tone)

func _bar_x() -> float:
	## The double bar stands at the far edge of the last die's seat.
	var seat: Rect2 = die_rect(str(_in_scale[_in_scale.size() - 1])) if not _in_scale.is_empty() else Rect2()
	return seat.end.x - u(5.0, 2.5)

func _draw_bar(last: Vector2, thick: float, now: int) -> void:
	var seat: Rect2 = die_rect(str(_in_scale[_in_scale.size() - 1]))
	if seat.size.x <= 0.0:
		return
	var tone: Color = tint2.lightened(0.45)
	var flash: float = clampf(1.0 - float(now - _bar_at) / float(BAR_MS), 0.0, 1.0) if _bar_at >= 0 else 0.0
	tone = tone.lerp(Color.WHITE, 0.8 * flash)
	var x: float = _bar_x()
	var top: float = seat.position.y + u(3.0, 1.5)
	var foot: float = seat.position.y + u(41.0, 20.5)
	var heavy: float = u(5.0, 2.5)
	var light: float = u(2.0, 1.0)
	var inner: float = x - heavy - u(4.0, 2.0)
	## The line runs on from the last note to the bar.
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
	if not _in_scale.is_empty() and die_rect(str(_in_scale[_in_scale.size() - 1])).size.x > 0.0:
		burst(Vector2(_bar_x(), die_rect(str(_in_scale[_in_scale.size() - 1])).position.y + u(22.0, 11.0)), tint2.lightened(0.5), 14, 130.0, 0.5, 4.0)

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
