extends "res://view/battle/birth_act.gd"
## Cadence's Encore: the run her straights are made of, shown in the tray.
##
## The dice of the longest run of consecutive numbers are tied under the tray like slurred
## notes, with the run's length on the tie: faint at two, violet at three (Motif), gold from
## four (Overture, Encore). One more die away from the next rung reads at a glance, and which
## dice to keep.
##
## Each rung has a short moment of its own as it lands. Motif hangs a repeat sign on the gem it
## plays again. Overture rolls a wave across the creatures under its blows. Encore draws a
## curtain call of light along the rail before the rail goes round again. The stone's count and
## its blows are the screen's own, as before.
##
## Both layouts draw the same pieces.

const NIGHT := Color(0.04, 0.045, 0.08)
const REPEAT_SECONDS: float = 1.5
const SWEEP_SECONDS: float = 0.7

## The dice of the longest run, lowest number first, and how many rungs it has reached.
var _run: Array = []
var _reached: int = 0
## The run lengths the rungs ask for, shortest first.
var _needs: Array = []
var _repeat_socket: int = -1
var _repeat_at: int = -1
var _sweep_at: int = -1

# --- the run -------------------------------------------------------------------------------------

func _sync_act() -> void:
	if _needs.is_empty():
		for def in defs:
			if def is Dictionary and str(def.get("trigger", {}).get("kind", "")) == "straight":
				_needs.append(int(def.trigger.get("amount", 0)))
		_needs.sort()
	_run = []
	_reached = 0
	if not settled or unit.is_empty() or bool(unit.get("downed", false)):
		return
	var straight: Dictionary = reading().get("straight", {})
	if int(straight.get("length", 0)) >= 2:
		_run = straight.get("dice", []).duplicate()
	for need in _needs:
		if _run.size() >= int(need):
			_reached += 1

func _look_key() -> String:
	return "%s|%d|%s" % [str(_run), _reached, str(settled)]

func _run_tone() -> Color:
	if _reached <= 0:
		return Color(DeepUi.MUTED, 0.85)
	if _reached == 1:
		return tint.lightened(0.45)
	return tint2.lightened(0.15 if _reached == 2 else 0.4)

func _tie(from: Vector2, to: Vector2, sag: float, tone: Color, thick: float) -> void:
	## One tie between two dice: a shallow curve hanging under them, fat in the middle like a
	## slur on a stave.
	var points := PackedVector2Array()
	var bend: Vector2 = (from + to) * 0.5 + Vector2(0.0, sag * 2.0)
	for step in range(17):
		var t: float = float(step) / 16.0
		points.append(from.lerp(bend, t).lerp(bend.lerp(to, t), t))
	draw_polyline(points, Color(NIGHT, 0.8), thick + u(3.0, 1.5), true)
	draw_polyline(points, tone, thick, true)

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	_draw_sweep(now)
	_draw_repeat(now)
	if not settled or _run.size() < 2:
		return
	## Where the tie touches each die of the run: under its solid, left to right across the tray.
	var feet: Array = []
	var floor_y: float = 0.0
	for id in _run:
		var seat: Rect2 = die_rect(str(id))
		if seat.size.x <= 0.0:
			return
		feet.append(Vector2(seat.get_center().x, seat.end.y - u(13.0, 6.5)))
		floor_y = seat.end.y
	feet.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var tone: Color = _run_tone()
	var thick: float = u(3.0, 1.5) if _reached > 0 else u(2.0, 1.0)
	var sag: float = u(9.0, 3.5)
	for index in range(1, feet.size()):
		_tie(feet[index - 1], feet[index], sag, tone, thick)
	for foot in feet:
		draw_circle(foot, thick * 1.5, Color(NIGHT, 0.8))
		draw_circle(foot, thick * 1.05, tone)
	## The run's length rides the middle of the tie.
	var px: int = text_px(14)
	var size_px: int = maxi(px, DeepUi.min_text())
	var radius: float = float(size_px) * 0.66
	var middle := Vector2((feet[0].x + feet[feet.size() - 1].x) * 0.5, floor_y - (DeepUi.pt(4.0) if DeepUi.phone else 2.0))
	draw_circle(middle, radius, Color(NIGHT, 0.96))
	draw_arc(middle, radius, 0.0, TAU, 28, tone, maxf(1.5, u(2.0, 1.0)), true)
	draw_words(str(_run.size()), middle, px, tone.lightened(0.15))

# --- the rungs landing ---------------------------------------------------------------------------

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

func _tier(_entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var handled: bool = false
	for effect in effects:
		if not effect is Dictionary or bool(effect.get("nothing", false)):
			continue
		match str(effect.get("kind", "")):
			"retrigger_previous":
				## Motif: a repeat sign on the gem that plays again (the gem's own replay follows).
				handled = true
				_repeat_socket = int(effect.get("socket", -1))
				_repeat_at = Time.get_ticks_msec()
				busy(REPEAT_SECONDS + 0.1)
				sound("tick_violet", {"pitch": 1.5, "volume": 0.7, "gap": 0.0})
				var ring: Rect2 = _ring_of(_repeat_socket)
				if ring.size.x > 0.0:
					burst(ring.position + ring.size * Vector2(0.5, 0.1), tint.lightened(0.45), 10, 110.0, 0.45, 4.0)
			"damage":
				_wave(effects)
			"replay_rail":
				_curtain(effect.get("sockets", []))
	if not handled:
		return false
	## Motif lands nothing of its own; whatever else the rung carries goes the screen's way.
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "retrigger_previous")
	if not rest.is_empty():
		land(rest, origin, tone)
	return true

func _wave(effects: Array) -> void:
	## Overture: a wave across the floor under every creature its blows reach, violet then gold.
	var room: Node3D = fx()
	if room == null:
		return
	var middle := Vector3.ZERO
	var reached: int = 0
	for effect in effects:
		if effect is Dictionary and str(effect.get("kind", "")) == "damage":
			for hit in [effect] + effect.get("splash", []):
				middle += creature_point(str(hit.get("target", "")))
				reached += 1
	if reached <= 0:
		return
	middle /= float(reached)
	var at := Vector3(middle.x, 0.0, middle.z)
	room.ring_wave(at, tint.lightened(0.3), 5.5, 0.6, 0.4)
	later(0.14, func() -> void:
		if fx() != null:
			fx().ring_wave(at, tint2.lightened(0.2), 7.0, 0.65, 0.3))

func _curtain(sockets: Array) -> void:
	## Encore: light sweeps the rail from its first socket to the stone, and every gem that will
	## play again glints as it passes.
	_sweep_at = Time.get_ticks_msec()
	busy(SWEEP_SECONDS + 0.2)
	var rail: Rect2 = _rail()
	if rail.size.x <= 0.0 or DeepUi.headless():
		return
	for socket in sockets:
		var ring: Rect2 = _ring_of(int(socket))
		if ring.size.x <= 0.0:
			continue
		var share: float = clampf((ring.get_center().x - rail.position.x) / rail.size.x, 0.0, 1.0)
		later(SWEEP_SECONDS * 0.8 * share, burst.bind(ring.get_center(), tint2.lightened(0.4), 10, 120.0, 0.5, 4.0))

func _rail() -> Rect2:
	return _rect_of(page.rail_box) if page != null else Rect2()

func _draw_sweep(now: int) -> void:
	if _sweep_at < 0:
		return
	var t: float = float(now - _sweep_at) / 1000.0 / SWEEP_SECONDS
	var rail: Rect2 = _rail()
	if t >= 1.0 or rail.size.x <= 0.0:
		_sweep_at = -1 if t >= 1.0 else _sweep_at
		return
	## A bright edge leading a fading train, left to right.
	var eased: float = t * t * (3.0 - 2.0 * t)
	var lead: float = rail.position.x + rail.size.x * eased
	var fade: float = clampf((1.0 - t) / 0.25, 0.0, 1.0)
	var slice: float = u(22.0, 11.0)
	var gold: Color = tint2.lightened(0.35)
	for index in range(8):
		var left: float = maxf(rail.position.x, lead - slice * float(index + 1))
		var right: float = maxf(rail.position.x, lead - slice * float(index))
		if right > left:
			draw_rect(Rect2(left, rail.position.y, right - left, rail.size.y), Color(gold if index < 3 else tint.lightened(0.3), 0.3 * fade * (1.0 - float(index) / 8.0)))
	draw_rect(Rect2(lead - u(3.0, 1.5), rail.position.y, u(3.0, 1.5), rail.size.y), Color(gold.lightened(0.4), 0.9 * fade))

func _draw_repeat(now: int) -> void:
	## A repeat sign (two dots and a double bar) at the corner of the gem Motif plays again.
	if _repeat_at < 0:
		return
	var t: float = float(now - _repeat_at) / 1000.0
	var ring: Rect2 = _ring_of(_repeat_socket)
	if t >= REPEAT_SECONDS or ring.size.x <= 0.0:
		_repeat_at = -1 if t >= REPEAT_SECONDS else _repeat_at
		return
	var alpha: float = clampf((REPEAT_SECONDS - t) / 0.4, 0.0, 1.0)
	var swell: float = 1.0 + 0.5 * clampf(1.0 - t / 0.18, 0.0, 1.0)
	var edge: float = maxf(ring.size.x * 0.4, u(30.0, 15.0)) * swell
	## At the ring's top left corner: the Void's riders stand round its right side.
	var middle: Vector2 = ring.position + Vector2(ring.size.x * 0.1, ring.size.y * 0.1)
	var box := Rect2(middle - Vector2(edge, edge) * 0.5, Vector2(edge, edge))
	var tone: Color = Color(tint2.lightened(0.35), alpha)
	draw_circle(middle, edge * 0.62, Color(NIGHT, 0.95 * alpha))
	draw_arc(middle, edge * 0.62, 0.0, TAU, 28, Color(tint.lightened(0.4), alpha), maxf(1.5, u(2.0, 1.0)), true)
	draw_rect(Rect2(box.position + box.size * Vector2(0.64, 0.2), box.size * Vector2(0.14, 0.6)), tone)
	draw_rect(Rect2(box.position + box.size * Vector2(0.5, 0.2), box.size * Vector2(0.06, 0.6)), tone)
	draw_circle(box.position + box.size * Vector2(0.33, 0.38), edge * 0.07, tone)
	draw_circle(box.position + box.size * Vector2(0.33, 0.62), edge * 0.07, tone)
