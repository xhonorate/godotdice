extends "res://view/battle/birth_act.gd"
## Rue's Mithridate: runs of dice coat the Apothecary's own blades.
##
## While she is Envenomed every ring of her rail, the Birthstone's too, wears a film of
## malachite banded like the stone, deeper the more stacks she carries (the Envenomed chip
## over her says how many). While the hand is planned a chip over the stone counts the stabs
## Mithridate would make: her stacks once this turn's coats have landed, bright once the hand
## reaches a straight of five.
##
## When the stone fires, a coat runs green down the rail from the stone to every socket, and
## a second coat (Double Dose) pours a darker band after it. Mithridate jabs needles into the
## target, one a stack, each leaving a green drop as its Poison goes in; from then on every
## hit of hers that carries the venom splashes a small green drop where it lands.
##
## Both layouts draw the same pieces: the film lies on the rings themselves, so nothing moves.

const MALACHITE := Color("2f8a5b")
const DEEP := Color("14523a")
const PALE := Color("8fdcb0")
const VENOM := Color("9ad35a")
const STEEL := Color("d6e2da")
const NIGHT := Color(0.02, 0.05, 0.035)
## The stacks at which the film is at its deepest.
const FILM_DEEP: int = 6
## A coat's run down the rail, how long its band lingers once it is down, and the flare a
## ring gives as the band reaches it.
const FLOW: float = 0.34
const TAIL: float = 0.3
const FLARE: float = 0.3
## A needle's jab: in with the bolt, out again quicker.
const JAB: float = 0.2
const JAB_BACK: float = 0.12
## How far from the middle of the target a needle starts, in the room's own measure.
const NEEDLE_REACH: float = 1.05
const DROP_MS: int = 620
const DROPS_MOST: int = 24

var _chip: PanelContainer = null
var _chip_said: Label = null
var _stabs: int = 0
var _stab_live: bool = false
## The stacks the film shows: what she carries, held back while a coat is on its way down.
var _shown: int = 0
var _firing: bool = false
var _coats_seen: int = 0
## Coats on their way down the rail: {at (ms), from, to, deep}.
var _flows: Array = []
## Needles in a creature {from, to, at}, and drops of venom where a hit went in {at, born}.
var _needles: Array = []
var _drops: Array = []

func _open() -> void:
	_chip = plate(6.0, 2.0, Color(MALACHITE.lightened(0.2), 0.9))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(u(4.0, 2.0)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(row)
	var mark: TextureRect = GemIcons.glyph(row, "coated_blade", DeepUi.glyph_px(text_px(12), 1.0), PALE)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_said = words(row, "", 12, PALE)
	_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_chip.visible = false
	place(_chip, "over_stone", 0.5, Vector2(0.0, -u(0.0, 2.0)))
	tip(_chip, _chip_plate, {"tone": MALACHITE.lightened(0.3)})

# --- reading the stone ---------------------------------------------------------------------------

func _coats(index: int) -> bool:
	## A tier that coats her (Coat, Double Dose), as content wrote it.
	if index < 0 or index >= defs.size():
		return false
	for effect in defs[index].get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == "envenom":
			return true
	return false

func _stab_index() -> int:
	## The tier that stabs once a stack (Mithridate).
	for index in range(defs.size()):
		for effect in defs[index].get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "damage" and effect.get("repeat", null) is Dictionary and str(effect.repeat.get("term", "")) == "envenom":
				return index
	return -1

func _live(index: int) -> bool:
	return settled and index >= 0 and index < tiers.size() and tiers[index] is Dictionary and bool(tiers[index].get("active", false))

func _carried() -> int:
	return int(unit.get("statuses", {}).get("envenom", 0))

func _read_stabs() -> int:
	## Her stacks once this turn's coats have landed: what Mithridate would stab with.
	var stacks: int = _carried()
	for index in range(defs.size()):
		if not _coats(index) or not _live(index):
			continue
		for effect in tiers[index].get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "envenom" and effect.has("envenom_after"):
				stacks = maxi(stacks, int(effect.envenom_after))
	return stacks

func _sync_act() -> void:
	var down: bool = bool(unit.get("downed", false))
	if planning:
		## Her turn has come round: whatever was on its way has long landed.
		_firing = false
		_flows.clear()
	if not _firing and _flows.is_empty():
		_shown = _carried()
	var up: bool = planning and settled and not down and not unit.get("hand", []).is_empty() and not tiers.is_empty()
	var stab: int = _stab_index()
	_stabs = _read_stabs() if up else 0
	_stab_live = up and _live(stab)
	_chip.visible = up and stab >= 0 and (_stabs > 0 or _stab_live)
	if _chip.visible:
		_chip_said.text = "×%s" % DeepUi.number(_stabs)
		_chip_said.add_theme_color_override("font_color", Color.WHITE if _stab_live else PALE)
		_chip.modulate = Color(1.0, 1.0, 1.0, 1.0 if _stab_live else 0.62)
		_chip.reset_size()

func _look_key() -> String:
	return "%d|%d|%s|%s|%s|%s" % [_shown, _stabs, str(_stab_live), str(_chip.visible), str(bool(unit.get("downed", false))), str(_ring_rects())]

func _chip_plate() -> Control:
	var stab: int = _stab_index()
	var title: String = str(defs[stab].get("name", "Mithridate")) if stab >= 0 else "Mithridate"
	var count: String = "no stab" if _stabs <= 0 else ("1 stab" if _stabs == 1 else "%s stabs" % DeepUi.number(_stabs))
	return Plates.words(title, "A straight of five stabs the target once for every Envenomed you carry, each stab for Resonance. Once this turn's coats have landed you carry %s: %s." % [DeepUi.number(_stabs), count], "straight of five", MALACHITE.lightened(0.35))

# --- where things stand --------------------------------------------------------------------------

func _ring_rects() -> Array:
	## The rings of her rail's sockets, left to right (not the Birthstone's).
	var out: Array = []
	if page == null or page.rail_box == null or not is_instance_valid(page.rail_box):
		return out
	var card: Control = stone_card()
	for index in range(page.rail_box.get_child_count()):
		if card != null and page.rail_box.get_child(index) == card:
			continue
		var ring: Rect2 = socket_rect(index)
		if ring.size.x <= 0.0 or ring.size.y <= 0.0:
			continue
		## A socket with no ring of its own: the square in the middle of what is there.
		var edge: float = minf(ring.size.x, ring.size.y)
		out.append(Rect2(ring.get_center() - Vector2(edge, edge) * 0.5, Vector2(edge, edge)))
	return out

func _far_x() -> float:
	## Where a coat's run ends: the middle of the socket furthest from the stone.
	var far: float = stone_rect().get_center().x
	for ring in _ring_rects():
		far = minf(far, (ring as Rect2).get_center().x)
	return far

func _share(x: float) -> float:
	## How far down the rail a point is, from the stone (0) to the furthest socket (1).
	var from: float = stone_rect().get_center().x
	var span: float = from - _far_x()
	if span <= 1.0:
		return 0.0
	return clampf((from - x) / span, 0.0, 1.0)

func _reach_time(share: float) -> float:
	## Seconds into a coat's run at which its band reaches a point this far down the rail
	## (the band runs out fast and slows as it goes).
	return FLOW * (1.0 - sqrt(maxf(0.0, 1.0 - share)))

func _film_at(x: float, now: int) -> int:
	## The stacks a ring's film shows: each coat's once its band has reached the ring.
	var shown: int = _shown
	for flow in _flows:
		var since: float = float(now - int(flow.at)) / 1000.0
		if since >= _reach_time(_share(x)):
			shown = int(flow.to)
		else:
			break
	return shown

func _flare_at(x: float, now: int) -> float:
	## How bright a ring flares just after a band has reached it.
	var flare: float = 0.0
	for flow in _flows:
		var since: float = float(now - int(flow.at)) / 1000.0 - _reach_time(_share(x))
		if since >= 0.0 and since < FLARE:
			flare = maxf(flare, 1.0 - since / FLARE)
	return flare

func _tick(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	## A coat that has run its course is the film from now on.
	while not _flows.is_empty() and float(now - int(_flows[0].at)) / 1000.0 > FLOW + TAIL + FLARE:
		_shown = int(_flows[0].to)
		_flows.pop_front()
	if not _needles.is_empty():
		_needles = _needles.filter(func(needle: Dictionary) -> bool: return float(now - int(needle.at)) / 1000.0 < JAB + JAB_BACK)
	if not _drops.is_empty():
		_drops = _drops.filter(func(drop: Dictionary) -> bool: return now - int(drop.born) < DROP_MS)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	for ring in _ring_rects():
		var box: Rect2 = ring
		_draw_film(box, _film_at(box.get_center().x, now), _flare_at(box.get_center().x, now))
	var stone_at: Rect2 = stone_rect()
	if stone_at.size.x > 0.0:
		var edge: float = minf(stone_at.size.x, stone_at.size.y)
		_draw_film(Rect2(stone_at.get_center() - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), _film_at(stone_at.get_center().x, now), _flare_at(stone_at.get_center().x, now))
	_draw_flows(now)
	_draw_needles(now)
	_draw_drops(now)

func _draw_film(ring: Rect2, stacks: int, flare: float) -> void:
	## A ring coated in venom: a green wash over it and malachite's wavy bands round its rim,
	## more of them and darker the more stacks she carries.
	if ring.size.x <= 2.0 or (stacks <= 0 and flare <= 0.0):
		return
	var middle: Vector2 = ring.get_center()
	var radius: float = ring.size.x * 0.5
	if stacks > 0:
		var depth: float = clampf(float(stacks) / float(FILM_DEEP), 0.15, 1.0)
		draw_circle(middle, radius * 0.97, Color(MALACHITE, 0.08 + 0.16 * depth))
		var bands: int = clampi(1 + stacks, 2, 5)
		var width: float = radius * 0.32 / float(bands)
		var dark: Color = DEEP.lerp(Color("082a1c"), depth * 0.6)
		var light: Color = PALE.lerp(MALACHITE, depth * 0.55)
		for index in range(bands):
			var at: float = radius * 1.0 - width * (float(index) + 0.5)
			var tone: Color = dark if index % 2 == 0 else light
			var wave := PackedVector2Array()
			for step in range(41):
				var angle: float = TAU * float(step) / 40.0
				var swell: float = sin(angle * 3.0 + float(index) * 1.3) * width * 0.35
				wave.append(middle + Vector2.from_angle(angle) * (at + swell))
			draw_polyline(wave, Color(tone, 0.32 + 0.45 * depth), width + 0.5, true)
	if flare > 0.0:
		draw_arc(middle, radius * 1.02, 0.0, TAU, 40, Color(VENOM.lightened(0.3), 0.85 * flare), maxf(2.0, u(4.0, 2.0)) * (1.0 + flare), true)

func _draw_flows(now: int) -> void:
	## A coat running down the rail: a band of malachite from the stone to the furthest socket,
	## a bright bead of venom at its head, then the band drains away after it.
	if _flows.is_empty():
		return
	var stone_at: Rect2 = stone_rect()
	if stone_at.size.x <= 0.0:
		return
	var y: float = stone_at.get_center().y
	var from: float = stone_at.get_center().x
	var far: float = _far_x()
	for flow in _flows:
		var t: float = float(now - int(flow.at)) / 1000.0 / FLOW
		if t <= 0.0:
			continue
		var tail_share: float = TAIL / FLOW
		var fade: float = clampf((1.0 + tail_share - t) / tail_share, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var eased: float = 1.0 - pow(1.0 - minf(t, 1.0), 2.0)
		var head := Vector2(lerpf(from, far, eased), y)
		var drained: float = clampf((t - 1.0) / tail_share, 0.0, 1.0)
		var tail := Vector2(lerpf(from, far, drained * drained), y)
		var deep: bool = bool(flow.deep)
		var thick: float = u(9.0, 4.5) * (1.4 if deep else 1.0)
		var body: Color = DEEP.darkened(0.3) if deep else MALACHITE
		var vein: Color = MALACHITE.lightened(0.1) if deep else PALE
		draw_line(tail, head, Color(NIGHT, 0.55 * fade), thick + u(4.0, 2.0), true)
		draw_line(tail, head, Color(body, 0.92 * fade), thick, true)
		draw_line(tail - Vector2(0.0, thick * 0.18), head - Vector2(0.0, thick * 0.18), Color(vein, 0.85 * fade), thick * 0.3, true)
		if t < 1.0:
			draw_circle(head, thick * 1.7, Color(VENOM, 0.22))
			draw_circle(head, thick * 0.75, VENOM.lightened(0.3))

func _draw_needles(now: int) -> void:
	## A needle jabbed into a creature: steel, its point coated green, in with the bolt and out.
	for needle in _needles:
		var t: float = float(now - int(needle.at)) / 1000.0
		if t < 0.0 or t >= JAB + JAB_BACK:
			continue
		var reach: float = clampf(t / JAB, 0.0, 1.0) if t < JAB else clampf(1.0 - (t - JAB) / JAB_BACK, 0.0, 1.0)
		var fade: float = 1.0 if t < JAB else clampf(1.0 - (t - JAB) / JAB_BACK, 0.0, 1.0)
		var from: Vector2 = needle.from
		var to: Vector2 = needle.to
		if from.distance_to(to) < 1.0:
			continue
		var way: Vector2 = (to - from).normalized()
		var tip_at: Vector2 = from.lerp(to, 0.8 * reach * reach)
		var length: float = u(66.0, 33.0)
		var tail: Vector2 = tip_at - way * length
		var side: Vector2 = way.orthogonal() * u(3.4, 1.7)
		var waist: Vector2 = tail.lerp(tip_at, 0.7)
		var coat: Vector2 = tail.lerp(tip_at, 0.62)
		draw_line(tail - way * u(40.0, 20.0) * reach, tail, Color(STEEL, 0.25 * fade), maxf(1.0, u(2.0, 1.0)), true)
		var body := PackedVector2Array([tail, waist + side, tip_at, waist - side])
		draw_colored_polygon(body, Color(STEEL, fade))
		draw_colored_polygon(PackedVector2Array([coat + side * 0.9, tip_at, coat - side * 0.9]), Color(VENOM, fade))
		body.append(tail)
		draw_polyline(body, Color(NIGHT, 0.8 * fade), maxf(1.0, u(1.5, 0.75)), true)
		draw_arc(tail, side.length() * 1.2, 0.0, TAU, 12, Color(STEEL, fade), maxf(1.0, u(1.5, 0.75)), true)

func _draw_drops(now: int) -> void:
	## A drop of venom where a hit went in: it swells as it lands, then runs down and fades.
	for drop in _drops:
		var t: float = float(now - int(drop.born)) / float(DROP_MS)
		if t < 0.0 or t >= 1.0:
			continue
		var pop: float = 1.0 + 0.5 * clampf(1.0 - t / 0.15, 0.0, 1.0)
		var edge: float = u(24.0, 12.0) * pop * (1.0 - 0.25 * t)
		var at: Vector2 = (drop.at as Vector2) + Vector2(0.0, u(26.0, 13.0) * t * t)
		var fade: float = clampf((1.0 - t) / 0.35, 0.0, 1.0)
		draw_circle(at, edge * 0.7, Color(VENOM, 0.22 * fade))
		draw_glyph("drop", Rect2(at - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), Color(VENOM, fade))

# --- the stone fires -----------------------------------------------------------------------------

func _fired(_played: Dictionary) -> void:
	_firing = true
	_coats_seen = 0

func _tier(_entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var coats: Array = []
	var blows: Array = []
	var rest: Array = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var kind: String = str(effect.get("kind", ""))
		if kind == "envenom":
			coats.append(effect)
		elif kind == "damage" and not bool(effect.get("lost_hp", false)) and str(effect.get("target", "")) != str(unit.get("id", "")):
			blows.append(effect)
		else:
			rest.append(effect)
	if not coats.is_empty():
		_coat(coats)
	if blows.is_empty():
		## A coat's numbers land the screen's own way, under its band.
		return false
	## Mithridate: a needle a stack, each jab one of the screen's own blows.
	var gap: float = DeepBattle.HIT_STEP * DeepBattle.hit_pace(blows)
	for index in range(blows.size()):
		later(gap * float(index), _stab.bind(blows[index], index))
	rest.append_array(coats)
	if not rest.is_empty():
		later(gap * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _coat(coats: Array) -> void:
	## A coat runs down the rail; a second this turn (Double Dose) pours darker after it.
	var from: int = int(_flows.back().to) if not _flows.is_empty() else _shown
	var after: int = from
	for effect in coats:
		after = maxi(after, int(effect.get("envenom_after", after)))
	if after <= from and coats.all(func(effect: Dictionary) -> bool: return int(effect.get("amount", 0)) <= 0):
		return
	var now: int = Time.get_ticks_msec()
	_firing = true
	_flows.append({"at": now, "from": from, "to": after, "deep": _coats_seen > 0})
	_coats_seen += 1
	busy(FLOW + TAIL + FLARE + 0.2)
	sound("poison", {"volume": 0.45, "pitch": 1.25 if _coats_seen <= 1 else 0.85, "gap": 0.0})
	var rings: Array = _ring_rects()
	for index in range(rings.size()):
		var when: float = _reach_time(_share((rings[index] as Rect2).get_center().x))
		later(when, sound.bind("tick_green", {"volume": 0.22, "pitch": 1.0 + 0.06 * float(rings.size() - index), "gap": 0.0}))

func _stab(hit: Dictionary, index: int) -> void:
	var who: String = str(hit.get("target", target_id()))
	var right: Vector3 = Vector3.RIGHT
	var up_way: Vector3 = Vector3.UP
	if screen != null and not DeepUi.headless() and screen._camera != null:
		right = screen._camera.global_transform.basis.x
		up_way = screen._camera.global_transform.basis.y
	## Each needle comes in from its own side, round the creature's upper half.
	var angle: float = PI * (0.12 + 0.76 * fposmod(float(index) * 0.618034, 1.0))
	var spot: Vector3 = creature_point(who) + (right * cos(angle) + up_way * sin(angle)) * NEEDLE_REACH
	if not DeepUi.headless():
		_needles.append({"from": screen_point(spot), "to": creature_at(who), "at": Time.get_ticks_msec()})
		busy(JAB + JAB_BACK + 0.3)
	sound("hit_light", {"volume": 0.4, "pitch": 1.6 + 0.07 * float(index % 5), "gap": 0.0})
	land([hit], spot, VENOM)
	if _venomous(hit):
		later(JAB, _splash.bind(who, index))

static func _venomous(hit: Dictionary) -> bool:
	## A hit that got past block and put her venom in.
	for key in ["envenom", "envenomed"]:
		var dose: Variant = hit.get(key, null)
		if dose is Dictionary and not (dose as Dictionary).is_empty() and int((dose as Dictionary).get("amount", 0)) > 0:
			return true
	return false

func _splash(who: String, seed_at: int) -> void:
	if DeepUi.headless() or not on_screen():
		return
	var at: Vector2 = creature_at(who) + Vector2(u(14.0, 7.0) * float(seed_at % 3 - 1), -u(6.0, 3.0) * float(seed_at % 2))
	_drops.append({"at": at, "born": Time.get_ticks_msec()})
	while _drops.size() > DROPS_MOST:
		_drops.pop_front()
	busy(float(DROP_MS) / 1000.0 + 0.1)
	burst(at, VENOM, 7, u(120.0, 55.0), 0.35, u(4.0, 2.0))

func _event(played: Dictionary) -> void:
	var kind: String = str(played.get("kind", ""))
	var me: String = str(unit.get("id", ""))
	match kind:
		"turn_begin", "rail_end":
			## Whatever was on its way has landed, watched or not.
			if kind == "turn_begin" or str(played.get("unit", "")) == me:
				_firing = false
				_flows.clear()
				_shown = _carried()
				queue_redraw()
		"gem_fire":
			if str(played.get("unit", "")) == me and not me.is_empty() and not DeepUi.headless() and on_screen():
				_watch_hits(played)

func _watch_hits(played: Dictionary) -> void:
	## Every hit of a gem of hers that carries the venom splashes a drop where it lands: when
	## the screen's own bolt arrives (after the gem's count, a bolt a beat apart, 0.2 s flying).
	var effects: Array = played.get("effects", [])
	var pace: float = DeepBattle.hit_pace(effects)
	var at: float = DeepBattle.tally_span(played.get("tally", {}))
	var seen: int = 0
	for effect in effects:
		if not effect is Dictionary or str(effect.get("kind", "")) != "damage":
			continue
		var over: int = maxi(1, int(effect.get("repeat", 1)))
		for hit in [effect] + effect.get("splash", []):
			if hit is Dictionary and _venomous(hit):
				later(at + JAB, _splash.bind(str(hit.get("target", "")), seen))
				seen += 1
			at += DeepBattle.BOLT_GAP * pace * float(over)
		at += DeepBattle.HIT_BREATH * pace
