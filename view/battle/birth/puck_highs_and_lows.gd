extends "res://view/battle/birth_act.gd"
## Puck's Highs and Lows: the dice wear the theatre's two masks.
##
## A die showing its crown wears a small gold laughing mask at its corner, and a die showing 1
## a blue weeping one, with a pip under the mask for every time it pays: one on a d6, two on a
## d8, three on a d10 (a d4 is a Face but pays nothing). While she has a Sleight left and one
## die picked, the mask it would turn to stands small and ghosted at its other corner.
##
## When the stone fires, each Happy Face hops and throws paper-diamond confetti at the target,
## a strike landing with each throw on a rising laugh; each Sad Face sheds blue shards that
## stack in front of her as the Block, on falling notes. A Standing Ovation sweeps curtains in
## from both sides of the tray; behind them every die grows a size, and as they part each die
## pulses with its new size over it. Footlights then run along the tray for the rest of the
## fight (an act is dropped when a fight ends, so the flag needs no clearing).
##
## Both layouts draw the same marks at the die's corner; the phone's dice are 44 pt, which
## leaves the pips room.

const MotleyFx = preload("res://view/battle/motley_fx.gd")

const GOLD := Color("ffd45e")
const TEAR := Color("6fb8ff")
const RHODONITE := Color("c9607c")
const VELVET := Color("7c1f3a")
const FOOTLIGHT := Color("ffd88a")
const HOP_MS: int = 380
const CURTAIN_SECONDS: float = 1.1
## When the curtains start to part, and the dice show their new sizes.
const OPENS: float = 0.5
const GROWN_SECONDS: float = 1.6
const STACK_HOLD: float = 0.9

## While the hand is planned: each Face in the tray, by die id: {"happy", "pays"}.
var _faces: Dictionary = {}
## Sleight's preview: {"id", "happy"} for the picked die's mask after a turn, or {}.
var _turn: Dictionary = {}
var _picked_key: String = ""
## Dice hopping as their strikes leave: {id: started ms}.
var _hops: Dictionary = {}
## Confetti and shards in flight: [{from, to, at, seconds, tone, spin, edge, bow, shard}].
var _flights: Array = []
## The Block's shards stacked before her: how many have landed, where, and until when.
var _stack: int = 0
var _stack_at: Vector2 = Vector2.ZERO
var _stack_until: int = 0
## A Standing Ovation: the curtains' clock, the new sizes over the dice, the footlights.
var _curtain_at: int = -1
var _grown: Dictionary = {}
var _footlights: bool = false

# --- reading the faces ---------------------------------------------------------------------------

func _sync_act() -> void:
	_faces = _read_faces()
	_turn = _read_turn()

func _up() -> bool:
	return not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))

func _read_faces() -> Dictionary:
	## Every die on its crown or on a 1, and how many sizes over a d4 it is: what it pays.
	var out: Dictionary = {}
	if not settled or not _up():
		return out
	var read: Dictionary = reading()
	for roll in dice():
		var happy: bool = crowned(roll)
		if not happy and not showing_one(roll):
			continue
		var id: String = str(roll.get("die_id", ""))
		out[id] = {"happy": happy, "pays": maxi(0, DeepHand.size_steps(read, [id]))}
	return out

func _read_turn() -> Dictionary:
	## The mask the one picked die would wear once Sleight turned it, or {} (no turn left, more
	## or fewer than one die picked, a die that cannot turn, or a face that is no Face).
	if not settled or not planning or not _up() or int(unit.get("flips", 0)) <= 0:
		return {}
	var chosen: Array = picked()
	if chosen.size() != 1:
		return {}
	for roll in dice():
		if str(roll.get("die_id", "")) != str(chosen[0]):
			continue
		if not DeepBattle.shift_refusal(unit, roll).is_empty():
			return {}
		var to: int = DeepBattle.shift_face(unit, roll)
		if to < 0:
			return {}
		var turned: Dictionary = roll.duplicate()
		turned.value = to
		if crowned(turned):
			return {"id": str(chosen[0]), "happy": true}
		if showing_one(turned):
			return {"id": str(chosen[0]), "happy": false}
	return {}

func _tick(_delta: float) -> void:
	## A die picked or put back changes the preview without the fight syncing.
	var key: String = str(picked())
	if key != _picked_key:
		_picked_key = key
		_turn = _read_turn()

func _look_key() -> String:
	var lights: String = str(Time.get_ticks_msec() / 140) if _footlights and _up() else ""
	return "%s|%s|%s|%s" % [str(_faces), str(_turn), str(settled), lights]

# --- drawing --------------------------------------------------------------------------------------

func _mask_box(id: String, corner: int, shrink: float = 1.0) -> Rect2:
	var face: Rect2 = die_face(id)
	if face.size.x <= 0.0:
		return face
	return die_corner(id, corner, maxf(face.size.x * 0.42, u(20.0, 12.0)) * shrink)

func _draw_mask(box: Rect2, happy: bool, alpha: float = 1.0, lift: float = 0.0, pays: int = 0) -> void:
	if box.size.x <= 0.0 or alpha <= 0.0:
		return
	var tone: Color = GOLD if happy else TEAR
	var middle: Vector2 = box.get_center() - Vector2(0.0, lift)
	var r: float = box.size.x * 0.5
	draw_circle(middle, r * 1.1, Color(DeepUi.LEDGER_FILL, 0.93 * alpha))
	draw_arc(middle, r * 1.1, 0.0, TAU, 28, Color(tone, alpha), maxf(1.5, u(2.0, 1.0)), true)
	var glyph: String = "mask_happy" if happy else "mask_sad"
	var inner := Rect2(middle - Vector2(r, r) * 0.82, Vector2(r, r) * 1.64)
	if GemIcons.known(glyph):
		draw_glyph(glyph, inner, Color(tone, alpha))
	else:
		draw_circle(middle, r * 0.7, Color(tone, alpha))
	## A pip for each time it pays, in a row along the die's top edge beside the mask.
	var pip: float = u(3.8, 2.6)
	var gap: float = pip * 0.9
	for index in range(mini(pays, 5)):
		var at := Vector2(middle.x + r * 1.1 + gap + pip + float(index) * (pip * 2.0 + gap), middle.y - r * 0.35)
		draw_circle(at, pip + maxf(1.0, u(1.5, 0.75)), Color(0.02, 0.03, 0.05, 0.9 * alpha))
		draw_circle(at, pip, Color(tone.lightened(0.15), alpha))

func _draw() -> void:
	if unit.is_empty() or not _up():
		return
	var now: int = Time.get_ticks_msec()
	if _footlights:
		_draw_footlights(now)
	if settled:
		for id in _faces:
			var hop: float = 0.0
			if _hops.has(id):
				var t: float = float(now - int(_hops[id])) / float(HOP_MS)
				if t >= 1.0:
					_hops.erase(id)
				else:
					hop = sin(t * PI) * u(16.0, 8.0)
			_draw_mask(_mask_box(str(id), CORNER_TOP_LEFT), bool(_faces[id].happy), 1.0, hop, int(_faces[id].pays))
		if not _turn.is_empty():
			## Sleight's answer, small and ghosted at the other corner, a dashed ring round it.
			var box: Rect2 = _mask_box(str(_turn.id), CORNER_TOP_RIGHT, 0.8)
			_draw_mask(box, bool(_turn.happy), 0.55)
			if box.size.x > 0.0:
				var r: float = box.size.x * 0.5 * 1.1 + u(3.0, 1.5)
				for dash in range(10):
					var from: float = TAU * float(dash) / 10.0
					draw_arc(box.get_center(), r, from, from + TAU / 20.0, 4, Color(DeepUi.PAPER, 0.7), maxf(1.0, u(1.5, 0.75)), true)
	_draw_flights(now)
	_draw_stack(now)
	_draw_curtains(now)
	_draw_grown(now)

func _draw_flights(now: int) -> void:
	for index in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[index]
		var t: float = (float(now - int(flight.at)) / 1000.0) / float(flight.seconds)
		if t < 0.0:
			continue
		if t >= 1.0:
			_flights.remove_at(index)
			if bool(flight.shard):
				_stack += 1
			continue
		var from: Vector2 = flight.from
		var to: Vector2 = flight.to
		var bend: Vector2 = (from + to) * 0.5 + Vector2(float(flight.bow), -absf(float(flight.bow)) - u(60.0, 26.0) * (0.0 if bool(flight.shard) else 1.0))
		var s: float = t if bool(flight.shard) else ease(t, 0.8)
		var at: Vector2 = from.lerp(bend, s).lerp(bend.lerp(to, s), s)
		var edge: float = float(flight.edge)
		var turn: float = float(flight.spin) * t
		var fade: float = clampf((1.0 - t) / 0.2, 0.0, 1.0) if not bool(flight.shard) else 1.0
		var tone: Color = Color(flight.tone, fade)
		var points := PackedVector2Array()
		if bool(flight.shard):
			## A sliver of blue glass, point first.
			var ahead: Vector2 = (to - from).normalized()
			var side := Vector2(-ahead.y, ahead.x)
			points = PackedVector2Array([at + ahead * edge, at + side * edge * 0.35, at - ahead * edge * 0.7, at - side * edge * 0.35])
		else:
			## A paper diamond, turning as it flies.
			for corner in range(4):
				var angle: float = turn + PI * 0.5 * float(corner)
				points.append(at + Vector2(cos(angle), sin(angle)) * edge * (1.0 if corner % 2 == 0 else 0.62))
		draw_colored_polygon(points, tone)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(tone.darkened(0.45), fade * 0.8), maxf(1.0, u(1.2, 0.6)), true)

func _draw_stack(now: int) -> void:
	## The shards landed so far, stacked into a little wall before her ring.
	if _stack <= 0:
		return
	var left: float = float(_stack_until - now) / 1000.0
	if left <= 0.0 and _flights.all(func(flight: Dictionary) -> bool: return not bool(flight.shard)):
		_stack = 0
		return
	var fade: float = clampf(left / 0.35, 0.0, 1.0) if left < 0.35 else 1.0
	var edge: float = u(16.0, 8.0)
	var per_row: int = 3
	for index in range(mini(_stack, 12)):
		var row: int = index / per_row
		var column: int = index % per_row
		var middle: Vector2 = _stack_at + Vector2((float(column) - float(per_row - 1) * 0.5 + 0.5 * float(row % 2)) * edge * 1.5, -float(row) * edge * 1.05)
		var slab := PackedVector2Array([middle + Vector2(0.0, -edge * 0.6), middle + Vector2(edge * 0.8, 0.0), middle + Vector2(0.0, edge * 0.6), middle + Vector2(-edge * 0.8, 0.0)])
		draw_colored_polygon(slab, Color(TEAR, 0.92 * fade))
		draw_polyline(slab + PackedVector2Array([slab[0]]), Color(TEAR.lightened(0.5), fade), maxf(1.0, u(1.5, 0.75)), true)

func _draw_grown(now: int) -> void:
	## Each grown die's new size over it, and a ring going out from it.
	for id in _grown.keys():
		var t: float = float(now - int(_grown[id].at)) / 1000.0
		if t >= GROWN_SECONDS:
			_grown.erase(id)
			continue
		if t < 0.0:
			continue
		var face: Rect2 = die_face(str(id))
		if face.size.x <= 0.0:
			continue
		var fade: float = clampf((GROWN_SECONDS - t) / 0.4, 0.0, 1.0)
		var ring: float = clampf(t / 0.45, 0.0, 1.0)
		if ring < 1.0:
			draw_arc(face.get_center(), face.size.x * (0.55 + 0.5 * ring), 0.0, TAU, 32, Color(GOLD, 0.8 * (1.0 - ring)), u(4.0, 2.0), true)
		var rise: float = u(10.0, 5.0) * clampf(t / 0.3, 0.0, 1.0)
		var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t / 0.25)
		draw_words(str(_grown[id].text), Vector2(face.get_center().x, face.position.y - u(14.0, 7.0) - rise), int(float(text_px(20, 13)) * pop), Color(GOLD.lightened(0.25), fade))

func _draw_curtains(now: int) -> void:
	if _curtain_at < 0:
		return
	var t: float = float(now - _curtain_at) / 1000.0
	if t >= CURTAIN_SECONDS:
		_curtain_at = -1
		return
	## Shut in a quarter of a second, held a beat while the dice grow, then drawn back.
	var shut: float = 1.0
	if t < OPENS - 0.24:
		shut = ease(t / (OPENS - 0.24), 0.4)
	elif t > OPENS:
		shut = 1.0 - ease(clampf((t - OPENS) / (CURTAIN_SECONDS - OPENS), 0.0, 1.0), 0.45)
	var stage: Rect2 = tray_rect().grow_individual(u(16.0, 6.0), 0.0, u(16.0, 6.0), u(8.0, 3.0))
	if stage.size.x <= 0.0 or shut <= 0.0:
		return
	var wide: float = stage.size.x * 0.5 * shut
	for side in [0, 1]:
		var drape := Rect2(Vector2(stage.position.x if side == 0 else stage.end.x - wide, stage.position.y), Vector2(wide, stage.size.y))
		draw_rect(drape, Color(VELVET, 0.97))
		## Folds: darker and lighter bands that bunch up as the drape opens.
		var fold: float = maxf(u(10.0, 5.0), wide / 7.0)
		var x: float = drape.position.x
		var band: int = 0
		while x < drape.end.x:
			var strip := Rect2(Vector2(x, drape.position.y), Vector2(minf(fold * 0.5, drape.end.x - x), drape.size.y))
			draw_rect(strip, Color(RHODONITE.darkened(0.25), 0.55) if band % 2 == 0 else Color(0.0, 0.0, 0.0, 0.22))
			x += fold * 0.5
			band += 1
		## The gold hem and the edge that meets the other drape.
		draw_rect(Rect2(Vector2(drape.position.x, drape.end.y - u(5.0, 2.5)), Vector2(drape.size.x, u(5.0, 2.5))), GOLD)
		var meet: float = drape.end.x if side == 0 else drape.position.x
		draw_line(Vector2(meet, drape.position.y), Vector2(meet, drape.end.y), GOLD.darkened(0.15), u(3.0, 1.5), true)
	## The valance over both.
	draw_rect(Rect2(stage.position, Vector2(stage.size.x, u(10.0, 5.0))), Color(VELVET.darkened(0.2), minf(1.0, shut * 3.0)))
	draw_rect(Rect2(stage.position + Vector2(0.0, u(10.0, 5.0)), Vector2(stage.size.x, u(2.5, 1.25))), Color(GOLD, minf(1.0, shut * 3.0)))

func _draw_footlights(now: int) -> void:
	## Warm lamps along the foot of the tray, flickering a little.
	var tray: Rect2 = tray_rect()
	if tray.size.x <= 0.0:
		return
	var count: int = maxi(5, dice().size() * 2 + 1)
	var y: float = tray.end.y + u(3.0, 1.0)
	for index in range(count):
		var x: float = tray.position.x + tray.size.x * (float(index) + 0.5) / float(count)
		var flicker: float = 0.75 + 0.25 * sin(float(now) * 0.004 + float(index) * 1.9)
		draw_circle(Vector2(x, y), u(10.0, 4.5), Color(FOOTLIGHT, 0.16 * flicker))
		draw_circle(Vector2(x, y), u(3.2, 1.6), Color(FOOTLIGHT.lightened(0.3), 0.95 * flicker))

# --- firing ----------------------------------------------------------------------------------------

func _which(entry: Dictionary, effects: Array) -> String:
	## Which of the three rungs a lit tier is, by what it reads and what it does.
	var kinds: Array = effects.map(func(effect: Dictionary) -> String: return str(effect.get("kind", "")))
	if kinds.has("grow_dice"):
		return "ovation"
	match str(entry.get("trigger", {}).get("kind", "")):
		"crowns":
			return "comedy"
		"value":
			return "tragedy"
		"all_faces":
			return "ovation"
	if kinds.has("block"):
		return "tragedy"
	return "comedy" if kinds.has("damage") else ""

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	match _which(entry, effects):
		"comedy":
			return _comedy(entry, effects, origin)
		"tragedy":
			return _tragedy(entry, effects, origin)
		"ovation":
			return _ovation(entry, effects, origin, tone)
	return false

func _comedy(entry: Dictionary, effects: Array, origin: Vector3) -> bool:
	## Each Happy Face throws its own strikes, as many as its die is sizes over a d4.
	var strikes: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if strikes.is_empty():
		return false
	var read: Dictionary = reading()
	var at: float = 0.0
	var next: int = 0
	var laugh: int = 0
	for id in entry.get("dice", []):
		var steps: int = maxi(0, DeepHand.size_steps(read, [str(id)]))
		if steps <= 0 or next >= strikes.size():
			continue
		var share: Array = strikes.slice(next, mini(next + steps, strikes.size()))
		next += share.size()
		later(at, _laugh.bind(str(id), share, laugh))
		at += 0.04 + DeepBattle.BOLT_GAP * float(share.size())
		laugh += share.size()
	var rest: Array = strikes.slice(next) + effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	if not rest.is_empty():
		later(at, land.bind(rest, origin, GOLD))
	return true

func _laugh(id: String, strikes: Array, laugh: int) -> void:
	## One Happy Face hops and throws a fistful of confetti at the target for each strike.
	var face: Rect2 = die_face(id)
	var from: Vector2 = face.get_center() if face.size.x > 0.0 else tray_rect().get_center()
	_hops[id] = Time.get_ticks_msec()
	busy(1.2)
	var view: Control = die_view(id)
	if view != null and not DeepUi.headless():
		DeepUi.pulse(view, 1.14, 0.3)
	for index in range(strikes.size()):
		var strike: Dictionary = strikes[index]
		var to: Vector2 = creature_at(str(strike.get("target", target_id())))
		var delay: float = DeepBattle.BOLT_GAP * float(index)
		later(delay, _confetti.bind(from, to))
		later(delay, sound.bind("tick_gold", {"pitch": 1.0 + 0.09 * float(mini(laugh + index, 10)), "volume": 0.55, "gap": 0.0}))
		later(delay + 0.08, land.bind([strike], room_point(from), GOLD))
	sound("gleam", {"pitch": 1.1 + 0.06 * float(mini(laugh, 8)), "volume": 0.45})

func _confetti(from: Vector2, to: Vector2) -> void:
	if DeepUi.headless():
		return
	var now: int = Time.get_ticks_msec()
	var tones: Array = [GOLD, RHODONITE.lightened(0.25), MotleyFx.CRUEL, Color("fff3d6")]
	for index in range(7):
		_flights.append({"from": from + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * u(10.0, 5.0), "to": to + Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * u(26.0, 12.0),
			"at": now + index * 14, "seconds": 0.3 + randf() * 0.08, "tone": tones[index % tones.size()], "spin": randf_range(-9.0, 9.0),
			"edge": u(9.0, 4.5) * randf_range(0.8, 1.2), "bow": randf_range(-1.0, 1.0) * u(50.0, 22.0), "shard": false})
	_puff(from, [GOLD, RHODONITE.lightened(0.3)])
	busy(0.6)

func _puff(at: Vector2, tones: Array) -> void:
	## A pinch of paper diamonds thrown up off the die.
	if DeepUi.headless() or not is_inside_tree():
		return
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 10
	puff.lifetime = 0.7
	puff.texture = MotleyFx.diamond_texture()
	puff.direction = Vector2.UP
	puff.spread = 60.0
	puff.initial_velocity_min = u(90.0, 40.0)
	puff.initial_velocity_max = u(190.0, 85.0)
	puff.gravity = Vector2(0.0, u(320.0, 140.0))
	puff.angular_velocity_min = -260.0
	puff.angular_velocity_max = 260.0
	puff.scale_amount_min = u(0.35, 0.18)
	puff.scale_amount_max = u(0.65, 0.32)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tones[0], 1.0))
	ramp.set_color(1, Color(tones[tones.size() - 1], 0.0))
	puff.color_ramp = ramp
	puff.position = at
	add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	## `finished` never comes while the act is hidden, so a clock frees it as well.
	get_tree().create_timer(puff.lifetime + 1.0, false).timeout.connect(puff.queue_free)

func _tragedy(entry: Dictionary, effects: Array, origin: Vector3) -> bool:
	## Each Sad Face weeps blue shards that stack before her into the Block, on falling notes.
	var guards: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "block")
	if guards.is_empty():
		return false
	var ring: Rect2 = ring_rect()
	_stack = 0
	_stack_at = ring.get_center() + Vector2(0.0, ring.size.y * 0.18) if ring.size.x > 0.0 else tray_rect().get_center()
	var read: Dictionary = reading()
	var ids: Array = entry.get("dice", [])
	var at: float = 0.0
	for index in range(ids.size()):
		later(at, _weep.bind(str(ids[index]), maxi(1, DeepHand.size_steps(read, [str(ids[index])])), index))
		at += 0.1
	var flown: float = at + 0.36
	_stack_until = Time.get_ticks_msec() + int((flown + STACK_HOLD) * 1000.0)
	busy(flown + STACK_HOLD + 0.2)
	later(flown - 0.05, land.bind(guards, room_point(_stack_at), TEAR))
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "block")
	if not rest.is_empty():
		later(flown, land.bind(rest, origin, TEAR))
	return true

func _weep(id: String, pays: int, index: int) -> void:
	var face: Rect2 = die_face(id)
	var from: Vector2 = face.get_center() if face.size.x > 0.0 else tray_rect().get_center()
	sound("tick_blue", {"pitch": maxf(0.55, 1.05 - 0.1 * float(index)), "volume": 0.6, "gap": 0.0})
	if DeepUi.headless():
		return
	var now: int = Time.get_ticks_msec()
	for shard in range(mini(pays * 2, 6)):
		_flights.append({"from": from + Vector2(randf_range(-1.0, 1.0) * u(12.0, 6.0), u(6.0, 3.0)), "to": _stack_at + Vector2(randf_range(-1.0, 1.0) * u(12.0, 6.0), 0.0),
			"at": now + shard * 30, "seconds": 0.32, "tone": TEAR.lightened(0.1 * float(shard % 2)), "spin": 0.0, "edge": u(16.0, 8.0),
			"bow": randf_range(-1.0, 1.0) * u(24.0, 10.0), "shard": true})
	busy(0.8)

func _ovation(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## The curtains sweep in from both sides; behind them every die grows a size; as they part
	## each die shows its new size; the footlights stay lit for the rest of the fight.
	var grows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "grow_dice")
	if grows.is_empty() or grows.all(func(effect: Dictionary) -> bool: return bool(effect.get("nothing", false))):
		return false
	_curtain_at = Time.get_ticks_msec()
	busy(CURTAIN_SECONDS + 0.3)
	sound("harmony", {"volume": 0.85})
	var shapes: Dictionary = {}
	for roll in dice():
		shapes[str(roll.get("die_id", ""))] = str(roll.get("shape", "D6"))
	var grown: Array = []
	for effect in grows:
		for id in effect.get("dice", []):
			if not grown.has(str(id)):
				grown.append(str(id))
	for index in range(grown.size()):
		var id: String = grown[index]
		later(OPENS + 0.06 * float(index), _grow.bind(id, _bigger(str(shapes.get(id, "")), maxi(1, int(grows[0].get("amount", 1)))), index))
	later(OPENS, func() -> void:
		_footlights = true
		queue_redraw())
	## As the curtains part the screen says it and pulses each grown die its own way.
	later(OPENS, land.bind(effects, origin, tone))
	return true

static func _bigger(shape: String, steps: int) -> String:
	## The die a size (or more) up the line from this one, as the tray writes it ("d8").
	var at: int = DeepDice.TIERS.find(shape)
	if at < 0:
		return ""
	return str(DeepDice.TIERS[mini(at + steps, DeepDice.TIERS.size() - 1)]).to_lower()

func _grow(id: String, shown: String, index: int) -> void:
	if not shown.is_empty():
		_grown[id] = {"text": shown, "at": Time.get_ticks_msec()}
	busy(GROWN_SECONDS + 0.1)
	sound("die_pick", {"pitch": 0.9 + 0.08 * float(index), "volume": 0.6, "gap": 0.0})
