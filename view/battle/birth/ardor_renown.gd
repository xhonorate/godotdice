extends "res://view/battle/birth_act.gd"
## Ardor's Renown: every die showing 6 or more is a pass with the lance.
##
## While the hand is planned, each die showing 6 or more wears a small carnelian pennant, so
## the number of passes reads off the tray before the rail closes. His Trophies are counted on
## the stone's sheet and its tip and nowhere on the dock.
##
## When the stone fires, every blow is a pass: a long carnelian shard driven through its target
## from a new side, a quarter of a second after the one before, the pennant of the die that
## earned it jumping as it goes. A pass that kills breaks the creature orange-red and a signet
## arcs back into the stone (the screen says "+1 Trophy" itself). Grand Melee lets banners down
## at both ends of the dock and its passes go in together, as one volley.

const CARNELIAN := Color("b5482a")
const BLAZE := Color("ff5a2a")
const GILT := Color("eab85c")
const DARK := Color("1c0d09")
## A pass rides the screen's own bolt in (its flight), is driven on through, holds and fades.
const FLIGHT: float = 0.2
const THROUGH: float = 0.09
const HOLD: float = 0.1
const FADE: float = 0.16
const VOLLEY_GAP: float = 0.045
const TOKEN_FLIGHT: float = 0.5
const BANNER_SECONDS: float = 1.9
## The sides a pass comes from, one after another: out from the target to where it starts.
const SIDES: Array = [Vector2(-1.0, -0.2), Vector2(1.0, -0.26), Vector2(-0.74, -0.66), Vector2(0.78, -0.6), Vector2(-0.18, -1.0), Vector2(0.96, 0.1), Vector2(-0.96, 0.08)]

var _highs: Array = []
## Passes on their way ({from, to, at, killed, struck}), signets flying home ({from, at}), the
## pennants jumping (die id: until), and when the banners came down.
var _passes: Array = []
var _tokens: Array = []
var _jump: Dictionary = {}
var _banners_at: int = -1
var _side: int = 0

func _sync_act() -> void:
	var up: bool = settled and not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	_highs = DeepHand.matching(reading(), func(value: int) -> bool: return value >= 6) if up else []

func _look_key() -> String:
	return str(_highs)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	_draw_banners(now)
	for id in _highs:
		_draw_pennant(str(id), now)
	_draw_passes(now)
	_draw_tokens(now)

func _pennant(box: Rect2, tone: Color) -> void:
	## A swallow-tailed pennant on its staff: the kit's mark, or drawn here where it has none.
	if GemIcons.known("pennant"):
		draw_glyph("pennant", box, tone)
		return
	var at: Vector2 = box.position
	var edge: float = box.size.x
	draw_rect(Rect2(at + Vector2(edge * 0.12, edge * 0.04), Vector2(edge * 0.13, edge * 0.92)), tone)
	draw_colored_polygon(PackedVector2Array([at + Vector2(edge * 0.25, edge * 0.08), at + Vector2(edge * 0.96, edge * 0.08), at + Vector2(edge * 0.72, edge * 0.32),
		at + Vector2(edge * 0.96, edge * 0.56), at + Vector2(edge * 0.25, edge * 0.56)]), tone)

func _draw_pennant(id: String, now: int) -> void:
	## Planted on the die's top right corner, its staff's foot on the die.
	var face: Rect2 = die_face(id)
	if face.size.x <= 0.0:
		return
	var edge: float = face.size.x * 0.48
	var lift: float = 0.0
	if _jump.has(id):
		var left: float = float(int(_jump[id]) - now) / 320.0
		if left <= 0.0:
			_jump.erase(id)
		else:
			lift = sin(left * PI) * edge * 0.45
	var box := Rect2(face.end.x - edge * 0.5, face.position.y - edge * 0.6 - lift, edge, edge)
	var line: float = maxf(1.0, u(1.5, 1.0))
	for shift in [Vector2(-line, 0.0), Vector2(line, 0.0), Vector2(0.0, -line), Vector2(0.0, line)]:
		_pennant(Rect2(box.position + shift, box.size), Color(DARK, 0.9))
	_pennant(box, CARNELIAN.lightened(0.12) if lift <= 0.0 else BLAZE.lightened(0.2))

func _bolt_at(from: Vector3, to: Vector3, along: float) -> Vector3:
	## Where the screen's own bolt is on its way (battle_fx.gd `projectile`: slow off the mark,
	## bowed a little upward), so the lance is the thing its light rides on.
	var eased: float = along * along
	var control: Vector3 = (from + to) * 0.5 + Vector3(0.0, 0.85, 0.0)
	return from.lerp(control, eased).lerp(control.lerp(to, eased), eased)

func _draw_passes(now: int) -> void:
	for run in _passes.duplicate():
		var since: float = float(now - int(run.at)) / 1000.0
		if since >= FLIGHT + THROUGH + HOLD + FADE:
			_passes.erase(run)
			continue
		var from: Vector2 = screen_point(run.from)
		var to: Vector2 = screen_point(run.to)
		var way: Vector2 = (to - from).normalized() if from.distance_to(to) > 1.0 else Vector2.RIGHT
		var long: float = u(250.0, 130.0)
		var head: Vector2 = to
		if since < FLIGHT:
			head = screen_point(_bolt_at(run.from, run.to, since / FLIGHT))
		else:
			## Driven on through: the head comes out the far side and stops.
			var on: float = clampf((since - FLIGHT) / THROUGH, 0.0, 1.0)
			head = to + way * long * 0.56 * (1.0 - (1.0 - on) * (1.0 - on))
			if not bool(run.struck):
				run.struck = true
				_strike(run, to)
		var alpha: float = clampf((FLIGHT + THROUGH + HOLD + FADE - since) / FADE, 0.0, 1.0)
		_lance(head, way, long, alpha, since < FLIGHT)

func _lance(head: Vector2, way: Vector2, long: float, alpha: float, flying: bool) -> void:
	## One long shard of carnelian, lit along its upper face.
	var side: Vector2 = way.orthogonal() * u(8.0, 4.5)
	if side.y > 0.0:
		side = -side
	var shoulder: Vector2 = head - way * long * 0.2
	var tail: Vector2 = head - way * long
	if flying:
		draw_line(tail, tail - way * long * 0.5, Color(BLAZE, 0.3 * alpha), maxf(1.5, u(3.0, 1.5)), true)
	draw_colored_polygon(PackedVector2Array([head, shoulder + side, tail]), Color(CARNELIAN.lightened(0.38), alpha))
	draw_colored_polygon(PackedVector2Array([head, tail, shoulder - side]), Color(CARNELIAN.darkened(0.12), alpha))
	draw_polyline(PackedVector2Array([head, shoulder + side, tail, shoulder - side, head]), Color(DARK, 0.85 * alpha), maxf(1.0, u(1.5, 0.75)), true)
	draw_line(head - way * long * 0.04, head - way * long * 0.7, Color(1.0, 0.92, 0.82, 0.8 * alpha), maxf(1.0, u(1.5, 0.75)), true)

func _strike(run: Dictionary, at: Vector2) -> void:
	## The pass lands: splinters of carnelian, and for a kill the creature breaking orange-red
	## and a signet leaving it for the stone.
	burst(at, CARNELIAN.lightened(0.2), 12, 200.0, 0.4, 5.0)
	if not bool(run.killed):
		return
	burst(at, BLAZE, 46, 320.0, 0.75, 7.0)
	if fx() != null:
		fx().shards(run.to, BLAZE, 12, 4.5, 0.14, 1.0)
		fx().glow_burst(run.to, BLAZE, 3.2, 0.4)
	if bool(run.trophy):
		_tokens.append({"from": at, "at": Time.get_ticks_msec()})
		busy(TOKEN_FLIGHT + 0.4)

func _draw_tokens(now: int) -> void:
	## A Trophy on its way home: a signet arcing from the kill into the stone.
	var home: Rect2 = stone_rect()
	for token in _tokens.duplicate():
		var along: float = float(now - int(token.at)) / 1000.0 / TOKEN_FLIGHT
		var to: Vector2 = home.get_center() if home.size.x > 0.0 else Vector2(size.x * 0.5, size.y)
		if along >= 1.0:
			_tokens.erase(token)
			burst(to, GILT, 16, 150.0, 0.5, 5.0)
			sound("contract_seal", {"volume": 0.5, "gap": 0.0})
			var card: Control = stone_card()
			if card != null:
				DeepUi.pulse(card, 1.1, 0.3)
			continue
		var from: Vector2 = token.from
		var eased: float = along * along * (3.0 - 2.0 * along)
		var at: Vector2 = from.lerp(to, eased) + Vector2(0.0, -sin(along * PI) * u(120.0, 60.0))
		var radius: float = u(13.0, 7.0) * (1.0 + 0.5 * sin(along * PI))
		draw_circle(at, radius, GILT.darkened(0.25))
		draw_circle(at, radius * 0.8, CARNELIAN)
		draw_arc(at, radius, 0.0, TAU, 24, GILT.lightened(0.2), maxf(1.5, u(2.5, 1.25)), true)
		_pennant(Rect2(at - Vector2(radius, radius) * 0.55, Vector2(radius, radius) * 1.1), Color(DARK, 0.85))

func _draw_banners(now: int) -> void:
	## Grand Melee's banners, let down at both ends of the dock over the room.
	if _banners_at < 0:
		return
	var since: float = float(now - _banners_at) / 1000.0
	if since >= BANNER_SECONDS:
		_banners_at = -1
		return
	var dock: Rect2 = dock_rect()
	var wide: float = u(64.0, 34.0)
	var tall: float = u(132.0, 64.0)
	var foot: float = dock.position.y - u(46.0, 30.0)
	var left: float = maxf(dock.position.x + u(26.0, 0.0), DeepUi.safe_left + u(0.0, 3.0) if DeepUi.phone else 0.0)
	var right: float = minf(dock.end.x - u(26.0, 0.0), size.x - DeepUi.safe_right - u(0.0, 3.0) if DeepUi.phone else size.x)
	var down: float = clampf(since / 0.22, 0.0, 1.0)
	down = 1.0 - (1.0 - down) * (1.0 - down)
	var alpha: float = clampf((BANNER_SECONDS - since) / 0.3, 0.0, 1.0)
	for x in [left, right - wide]:
		var top := Vector2(float(x), foot - tall)
		var hung: float = tall * down
		var notch: float = wide * 0.34
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(wide, 0.0), top + Vector2(wide, hung), top + Vector2(wide * 0.5, maxf(0.0, hung - notch)), top + Vector2(0.0, hung)]), Color(CARNELIAN, 0.95 * alpha))
		draw_rect(Rect2(top + Vector2(wide * 0.12, 0.0), Vector2(wide * 0.1, maxf(0.0, hung - notch * 0.8))), Color(GILT, 0.85 * alpha))
		draw_rect(Rect2(top + Vector2(wide * 0.78, 0.0), Vector2(wide * 0.1, maxf(0.0, hung - notch * 0.8))), Color(GILT, 0.85 * alpha))
		draw_rect(Rect2(top + Vector2(-wide * 0.1, -u(5.0, 2.5)), Vector2(wide * 1.2, u(6.0, 3.0))), Color(GILT.darkened(0.3), alpha))
		if down >= 1.0:
			var mark: float = wide * 0.5
			draw_glyph("pennant_lance", Rect2(top + Vector2((wide - mark) * 0.5, tall * 0.26), Vector2(mark, mark)), Color(DARK, 0.8 * alpha))

# --- the stone fires -----------------------------------------------------------------------------

func _fired(_played: Dictionary) -> void:
	_side = 0

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var tier_name: String = str(entry.get("name", ""))
	var volley: bool = tier_name == "Grand Melee"
	var gap: float = VOLLEY_GAP if volley else DeepBattle.HIT_STEP * DeepBattle.hit_pace(effects)
	## Which die's pass each blow is: the first die for the Lance, the rest for the Tourney.
	var first: int = 1 if tier_name == "Tourney" else 0
	if volley:
		## The banners come down, and every pass goes in together.
		_banners_at = Time.get_ticks_msec()
		busy(BANNER_SECONDS + 0.2)
		sound("harmony", {"volume": 0.5})
	for index in range(blows.size()):
		var die: String = str(_highs[(first + index) % _highs.size()]) if not _highs.is_empty() else ""
		later(gap * float(index), _pass.bind(blows[index], tone, die))
	if not rest.is_empty():
		later(gap * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _reach(at: Vector3) -> float:
	## How far from the lens a point of the room is.
	if screen == null or DeepUi.headless() or screen._camera == null:
		return 6.0
	return maxf(1.6, screen._camera.global_position.distance_to(at))

func _pass(hit: Dictionary, tone: Color, die: String) -> void:
	## One pass: the lance starts off to one side of its target, level with it in the room, and
	## the blow's own bolt carries it in.
	var target: String = str(hit.get("target", target_id()))
	var to: Vector3 = creature_point(target)
	var way: Vector2 = (SIDES[_side % SIDES.size()] as Vector2).normalized()
	_side += 1
	var from: Vector3 = room_point(creature_at(target) + way * u(350.0, 190.0), _reach(to))
	var now: int = Time.get_ticks_msec()
	if not DeepUi.headless():
		_passes.append({"from": from, "to": to, "at": now, "killed": bool(hit.get("killed", false)), "trophy": hit.has("trophy"), "struck": false})
	if not die.is_empty():
		_jump[die] = now + 320
	busy(FLIGHT + THROUGH + HOLD + FADE + 0.3)
	land([hit], from, tone)
