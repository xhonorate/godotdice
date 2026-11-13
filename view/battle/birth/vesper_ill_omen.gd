extends "res://view/battle/birth_act.gd"
## Vesper's Ill Omen: every 1 in the tray is an eye.
##
## A die showing 1 is covered by a plate of snowflake obsidian with a pale eye in it. Once the
## 1s curse the whole room the eyes are strung on a pale thread, and once they would land
## blows the thread and the pupils run red. One line over the tray names the rung the 1s have
## reached, with the next one greyed after it ("Jinx · Reckoning at four").
##
## When the stone fires, each eye sends an ash-white fleck up into the room and it settles on
## its creature as a Curse, ash drifting down with it. The blows crack the Curses standing
## round the target one after another, a hit out of each. On the top rung every eye blinks and
## the room goes dark for a beat first, and the Curses are cracked twice over.
##
## Nothing here moves on the phone: the eyes are drawn on the dice themselves, and the line
## stands clear of the words that float over the tray.

const OBSIDIAN := Color("26252c")
const ASH := Color("c9c9d2")
const BLOOD := Color("e2463c")
const BLOOD_PALE := Color("ff9a8c")
const NUMBER_WORDS: Array = ["none", "one", "two", "three", "four", "five", "six", "seven", "eight"]
## A fleck's flight from its eye, and how far apart the eyes send theirs.
const FLECK_SECONDS: float = 0.24
const FLECK_GAP: float = 0.045
const FLECKS_MOST: int = 8
## The top rung's beat of dark, and the blink that goes with it.
const BLINK_MS: int = 340
const DARK_MS: int = 560
const DARK_BEAT: float = 0.24
## How long the Curses are given to settle before the first of them is cracked.
const CAST_BEAT: float = 0.3
const CRACK_MS: int = 280
const MARKS_MOST: int = 10
## How far from the middle of the target its Curses stand, in the room's own measure.
const MARK_REACH: float = 0.95

var _line: HBoxContainer = null
var _reached: Label = null
var _next: Label = null
var _plate: StyleBoxFlat = null
## The dice showing 1, left to right.
var _ones: Array = []
## The hand curses every creature (the eyes are strung); the hand lands blows (the thread is red).
var _strung: bool = false
var _red: bool = false
## Flecks in the air: {from, to, at (ms it leaves), ms}.
var _flecks: Array = []
## The Curses standing round the target while they are cracked: {spot, at, born, cracked}.
var _marks: Array = []
var _marks_turn: int = 0
var _blink_at: int = -1
var _dark_at: int = -1

func _open() -> void:
	_plate = StyleBoxFlat.new()
	_plate.bg_color = OBSIDIAN
	_plate.set_border_width_all(maxi(1, int(u(2.0, 1.0))))
	_plate.anti_aliasing = true
	_line = HBoxContainer.new()
	_line.name = "OmenLine"
	_line.add_theme_constant_override("separation", int(u(7.0, 3.0)))
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reached = words(_line, "", 16, ASH)
	_next = words(_line, "", 16, DeepUi.MUTED, false)
	_line.visible = false
	place(_line, "over_tray", 0.5)

# --- reading the hand ------------------------------------------------------------------------

func _live(index: int) -> bool:
	## Whether the hand in the tray fires (or fired) this tier.
	if not settled or index < 0 or index >= tiers.size() or not tiers[index] is Dictionary:
		return false
	return bool(tiers[index].get("active", false))

func _need(index: int) -> int:
	return int(defs[index].get("trigger", {}).get("amount", 0))

func _does(index: int, kind: String, target: String = "") -> bool:
	## Whether a tier, as content wrote it, has an effect of this kind (aimed so, when given).
	for effect in defs[index].get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == kind and (target.is_empty() or str(effect.get("target", "")) == target):
			return true
	return false

func _sync_act() -> void:
	var up: bool = settled and not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	_ones.clear()
	_strung = false
	_red = false
	var top: int = -1
	var after: int = -1
	if up:
		var seen: Array = reading().get("one_ids", [])
		for roll in dice():
			if seen.has(str(roll.get("die_id", ""))):
				_ones.append(str(roll.get("die_id", "")))
		for index in range(defs.size()):
			if _live(index):
				top = index
				_strung = _strung or _does(index, "curse", "enemies")
				_red = _red or _does(index, "damage")
		for index in range(top + 1, defs.size()):
			if not _live(index) and _need(index) > _ones.size():
				after = index
				break
	## The line: the rung reached (and how many blows it would land), then the next one, greyed.
	var known: bool = up and not tiers.is_empty()
	var reached: String = ""
	if known and top >= 0:
		reached = str(defs[top].get("name", ""))
		var blows: int = 0
		for effect in tier_now(reached).get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "damage":
				blows += 1
		if blows > 1:
			reached += " ×%d" % blows
	var coming: String = ""
	if known and after >= 0:
		var need: int = _need(after)
		coming = "%s%s at %s" % ["· " if top >= 0 else "", str(defs[after].get("name", "")), str(NUMBER_WORDS[need]) if need >= 0 and need < NUMBER_WORDS.size() else str(need)]
	_reached.text = reached
	_reached.visible = not reached.is_empty()
	_reached.add_theme_color_override("font_color", BLOOD_PALE if _red else ASH)
	_next.text = coming
	_next.visible = not coming.is_empty()
	_line.visible = known and (top >= 0 or after >= 0)

func _look_key() -> String:
	return "%s|%s|%s|%s|%s" % [str(_ones), _reached.text, _next.text, str(_strung), str(_red)]

func _tick(_delta: float) -> void:
	## Flecks that have landed are forgotten.
	if _flecks.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_flecks = _flecks.filter(func(fleck: Dictionary) -> bool: return now < int(fleck.at) + int(fleck.ms))

# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	_draw_dark(now)
	if settled:
		_draw_thread()
		for index in range(_ones.size()):
			_draw_eye(str(_ones[index]), index, now)
	_draw_marks(now)
	_draw_flecks(now)

func _eye_box(id: String) -> Rect2:
	var face: Rect2 = die_face(id)
	return face.grow(-face.size.x * 0.04) if face.size.x > 0.0 else face

func _draw_dark(now: int) -> void:
	## The room going dark for a beat: in fast, held, out slower. The eyes are drawn over it.
	if _dark_at < 0:
		return
	var t: float = float(now - _dark_at) / float(DARK_MS)
	if t >= 1.0:
		_dark_at = -1
		return
	var depth: float = clampf(t / 0.14, 0.0, 1.0) * clampf((1.0 - t) / 0.45, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02, 0.74 * depth))

func _draw_thread() -> void:
	## The thread the eyes are strung on: it hangs from one eye to the next, under the dice
	## between them, pale until the hand would land blows and red from then on.
	if not _strung or _ones.size() < 2:
		return
	var tone: Color = BLOOD if _red else ASH
	var thick: float = maxf(1.5, u(2.5, 1.25))
	for index in range(_ones.size() - 1):
		var a: Rect2 = _eye_box(str(_ones[index]))
		var b: Rect2 = _eye_box(str(_ones[index + 1]))
		if a.size.x <= 0.0 or b.size.x <= 0.0:
			continue
		var from: Vector2 = a.get_center()
		var to: Vector2 = b.get_center()
		var sag := Vector2((from.x + to.x) * 0.5, maxf(from.y, to.y) + a.size.y * 1.3)
		var curve := PackedVector2Array()
		for step in range(17):
			var k: float = float(step) / 16.0
			curve.append(from.lerp(sag, k).lerp(sag.lerp(to, k), k))
		draw_polyline(curve, Color(0.02, 0.02, 0.04, 0.7), thick + maxf(2.0, u(3.0, 1.5)), true)
		draw_polyline(curve, tone, thick, true)

func _draw_eye(id: String, index: int, now: int) -> void:
	## One omen: a cushion of snowflake obsidian over the die's face, a pale eye in it. The
	## pupil is the die's one pip.
	var box: Rect2 = _eye_box(id)
	if box.size.x <= 2.0:
		return
	_plate.set_corner_radius_all(int(box.size.x * 0.3))
	_plate.border_color = Color(BLOOD if _red else ASH, 0.7)
	draw_style_box(_plate, box)
	## The snowflakes: a few pale blooms in the black, never the same on two dice.
	var blooms: Array = [Vector3(0.2, 0.2, 0.07), Vector3(0.82, 0.24, 0.05), Vector3(0.17, 0.8, 0.05), Vector3(0.8, 0.8, 0.075)]
	for at in range(blooms.size()):
		var bloom: Vector3 = blooms[(at + index) % blooms.size()]
		var spot := Vector2(bloom.x if index % 2 == 0 else 1.0 - bloom.x, bloom.y)
		draw_circle(box.position + spot * box.size, box.size.x * bloom.z, Color(ASH, 0.2))
	## The eye, shut for a moment in a blink.
	var open: float = 1.0
	if _blink_at >= 0:
		var t: float = float(now - _blink_at) / float(BLINK_MS)
		if t >= 1.0:
			_blink_at = -1
		else:
			open = clampf(absf(t * 2.0 - 1.0) * 1.4 - 0.2, 0.06, 1.0)
	var edge: float = box.size.x * 0.8
	var middle: Vector2 = box.get_center()
	draw_glyph("eye", Rect2(middle - Vector2(edge, edge * open) * 0.5, Vector2(edge, edge * open)), ASH)
	if _red and open > 0.6:
		draw_circle(middle, edge * 0.1, BLOOD)

func _draw_flecks(now: int) -> void:
	for fleck in _flecks:
		var t: float = float(now - int(fleck.at)) / float(maxi(1, int(fleck.ms)))
		if t <= 0.0 or t >= 1.0:
			continue
		var head: Vector2 = _arc(fleck.from, fleck.to, t)
		var tail: Vector2 = _arc(fleck.from, fleck.to, maxf(0.0, t - 0.18))
		draw_line(tail, head, Color(ASH, 0.6), maxf(1.5, u(3.0, 1.5)), true)
		draw_circle(head, u(10.0, 5.0), Color(ASH, 0.22))
		draw_circle(head, u(4.5, 2.25), Color(1.0, 1.0, 1.0, 0.95))

func _arc(from: Vector2, to: Vector2, t: float) -> Vector2:
	## A fleck's way: thrown up out of its eye and falling onto what it curses.
	var over := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - u(70.0, 30.0))
	return from.lerp(over, t).lerp(over.lerp(to, t), t)

func _draw_marks(now: int) -> void:
	## The Curses round the target: small eyes on obsidian, each splitting red as it is cracked.
	var edge: float = u(30.0, 15.0)
	var round: float = edge * 0.62
	for mark in _marks:
		var at: Vector2 = mark.at
		if int(mark.cracked) < 0:
			var grown: float = clampf(float(now - int(mark.born)) / 110.0, 0.0, 1.0)
			if grown <= 0.05:
				continue
			draw_circle(at, round * grown, Color(OBSIDIAN, 0.94))
			draw_arc(at, round * grown, 0.0, TAU, 24, Color(ASH, 0.75), maxf(1.0, u(1.5, 0.75)), true)
			draw_glyph("eye", Rect2(at - Vector2(edge, edge) * 0.5 * grown, Vector2(edge, edge) * grown), ASH)
			continue
		var t: float = float(now - int(mark.cracked)) / float(CRACK_MS)
		if t >= 1.0:
			continue
		var fade: float = 1.0 - t
		draw_circle(at, round * (1.0 + 1.3 * t), Color(BLOOD, 0.45 * fade * fade))
		## Its two halves fall apart.
		for side in [-1.0, 1.0]:
			var half := PackedVector2Array()
			for step in range(9):
				var angle: float = -PI * 0.5 + PI * float(step) / 8.0
				half.append(at + Vector2(float(side) * (cos(angle) * round + edge * 0.75 * t), sin(angle) * round + edge * 0.5 * t * t))
			draw_colored_polygon(half, Color(OBSIDIAN.lerp(BLOOD, 0.35), 0.95 * fade))
		## And the crack itself, white going red.
		var jag := PackedVector2Array([at + Vector2(-round * 0.15, -round * 1.25), at + Vector2(round * 0.22, -round * 0.35), at + Vector2(-round * 0.2, round * 0.3), at + Vector2(round * 0.12, round * 1.25)])
		draw_polyline(jag, Color(Color.WHITE.lerp(BLOOD, t), fade), maxf(1.5, u(3.0, 1.5)), true)

# --- firing ------------------------------------------------------------------------------------

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## Curses leave the eyes as flecks of ash; blows crack the Curses on the target. The top
	## rung does both, after a blink and a beat of dark.
	var curses: Array = []
	var blows: Array = []
	var rest: Array = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		match str(effect.get("kind", "")):
			"curse":
				curses.append(effect)
			"damage":
				blows.append(effect)
			_:
				rest.append(effect)
	if curses.is_empty() and blows.is_empty():
		return false
	var at: float = 0.0
	var top: bool = not curses.is_empty() and not blows.is_empty() and tier_index(str(entry.get("name", ""))) == defs.size() - 1
	if top:
		_blink_at = Time.get_ticks_msec()
		_dark_at = _blink_at
		busy(float(DARK_MS) / 1000.0 + 0.2)
		sound("curse", {"pitch": 0.55, "volume": 0.9})
		at += DARK_BEAT
	if not curses.is_empty():
		later(at, _cast.bind(curses))
		if not blows.is_empty():
			at += CAST_BEAT
	if not blows.is_empty():
		later(at, _reckon.bind(blows, top))
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	return true

func _cast(curses: Array) -> void:
	## Every eye sends its fleck: to the target, or shared out over the room when the Curse
	## falls on every creature. Each Curse settles as the first fleck reaches it.
	var now: int = Time.get_ticks_msec()
	var eyes: Array = []
	for id in _ones:
		var box: Rect2 = _eye_box(str(id))
		if box.size.x > 0.0:
			eyes.append(box.get_center())
	if eyes.is_empty():
		eyes.append(stone_rect().get_center())
	var over: float = u(100.0, 44.0)
	for index in range(mini(maxi(eyes.size(), curses.size()), FLECKS_MOST)):
		var who: String = str(curses[index % curses.size()].get("target", ""))
		_flecks.append({"from": eyes[index % eyes.size()], "to": creature_at(who) - Vector2(0.0, over), "at": now + int(FLECK_GAP * 1000.0) * index, "ms": int(FLECK_SECONDS * 1000.0)})
	busy(FLECK_SECONDS + FLECK_GAP * float(FLECKS_MOST) + 0.3)
	for effect in curses:
		later(FLECK_SECONDS * 0.85, _settle.bind(effect, curses.size() > 1))

func _settle(effect: Dictionary, many: bool) -> void:
	var who: String = str(effect.get("target", ""))
	_ash(creature_at(who) - Vector2(0.0, u(120.0, 52.0)), 16 if many else 9)
	land([effect], creature_point(who) + Vector3(0.0, 1.1, 0.0), ASH)

func _ash(at: Vector2, amount: int) -> void:
	## Ash drifting down onto a creature.
	if DeepUi.headless() or not is_inside_tree():
		return
	var ash := CPUParticles2D.new()
	ash.one_shot = true
	ash.explosiveness = 0.5
	ash.amount = amount
	ash.lifetime = 0.9
	ash.texture = DeepUi.dot_texture()
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(u(50.0, 22.0), u(8.0, 4.0))
	ash.direction = Vector2.DOWN
	ash.spread = 16.0
	ash.initial_velocity_min = u(50.0, 22.0)
	ash.initial_velocity_max = u(110.0, 48.0)
	ash.gravity = Vector2(0.0, u(70.0, 30.0))
	ash.scale_amount_min = u(4.0, 2.0) / 32.0
	ash.scale_amount_max = u(8.0, 4.0) / 32.0
	var fade := Gradient.new()
	fade.set_color(0, Color(ASH, 0.0))
	fade.set_color(1, Color(ASH, 0.0))
	fade.add_point(0.15, Color(ASH, 0.95))
	fade.add_point(0.7, Color(ASH, 0.7))
	ash.color_ramp = fade
	ash.position = at
	add_child(ash)
	ash.emitting = true
	ash.finished.connect(ash.queue_free)
	## `finished` never comes while the act is hidden, so a clock frees it as well.
	get_tree().create_timer(ash.lifetime + 1.0, false).timeout.connect(ash.queue_free)

func _reckon(blows: Array, twice: bool) -> void:
	## The Curses on the target stand round it as small eyes and are cracked one after another,
	## a blow out of each. Twice over on the top rung: they stand back up for the second pass.
	if blows.is_empty():
		return
	var count: int = blows.size()
	var who: String = str(blows[0].get("target", target_id()))
	var passes: int = 2 if twice and count >= 2 else 1
	var each: int = int(ceil(float(count) / float(passes)))
	var shown: int = clampi(each, 1, MARKS_MOST)
	var now: int = Time.get_ticks_msec()
	var right: Vector3 = Vector3.RIGHT
	var up_way: Vector3 = Vector3.UP
	if screen != null and not DeepUi.headless() and screen._camera != null:
		right = screen._camera.global_transform.basis.x
		up_way = screen._camera.global_transform.basis.y
	var middle: Vector3 = creature_point(who)
	_marks_turn += 1
	_marks.clear()
	for index in range(shown):
		var angle: float = lerpf(PI * 0.92, PI * 0.08, (float(index) + 0.5) / float(shown))
		var spot: Vector3 = middle + (right * cos(angle) + up_way * (0.3 + sin(angle))) * MARK_REACH
		_marks.append({"spot": spot, "at": screen_point(spot), "born": now + index * 16, "cracked": -1})
	## The run of them keeps to the time the fight gave these blows.
	var span: float = maxf(0.0, DeepBattle.hits_span(blows) - (0.45 if twice else 0.3))
	var gap: float = clampf(span / float(count), 0.035, 0.12)
	var lead: float = 0.12
	var end: float = lead
	for index in range(count):
		var again: bool = passes > 1 and index == each
		end = lead + gap * float(index) + (0.12 if passes > 1 and index >= each else 0.0)
		later(end, _crack.bind(blows[index], (index % each) % shown, again))
	busy(end + float(CRACK_MS) / 1000.0 + 0.4)
	later(end + float(CRACK_MS) / 1000.0 + 0.05, _clear_marks.bind(_marks_turn))

func _crack(blow: Dictionary, slot: int, again: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if again:
		for mark in _marks:
			mark.born = now - 60
			mark.cracked = -1
	var who: String = str(blow.get("target", ""))
	var from: Vector3 = creature_point(who) + Vector3(0.0, 1.0, 0.0)
	if slot >= 0 and slot < _marks.size():
		var mark: Dictionary = _marks[slot]
		mark.cracked = now
		from = mark.spot
		burst(mark.at, BLOOD, 7, u(150.0, 70.0), 0.35, u(4.0, 2.0))
	sound("die_break", {"volume": 0.3, "pitch": 1.25 + 0.04 * float(slot), "gap": 0.0})
	land([blow], from, BLOOD)

func _clear_marks(turn: int) -> void:
	if turn == _marks_turn:
		_marks.clear()
		queue_redraw()
