extends "res://view/battle/birth_act.gd"
## Rue's Bitter Draught: low dice poison, and a hand of 1s makes every poison tick.
##
## Every low die in the tray (1-2 on a d4, 1-3 on a d6) wears a small green drop on its corner,
## faint until there are enough of them for a Tincture and bright from then on, so the count
## toward four and five reads off the tray. When the stone fires, Tincture throws a vial that
## tips over the target and pours as its Poison lands; Draught and Dregs send a green ripple
## under every creature whose poison ticks (Dregs again and again). The stone's count and the
## ticks themselves are the screen's own, as before.
##
## Both layouts draw the same pieces.

const VENOM := Color("9ad35a")
const DREGS := Color("3f8f3a")
const NIGHT := Color(0.02, 0.04, 0.03)
## The vial's flight to the target, and how long it hangs there pouring.
const VIAL: float = 0.28
const POURING: float = 0.34
const RIPPLE_GAP: float = 0.2

## The low dice, left to right; whether a rung of the stone is reached (Tincture or more), and
## whether the hand is all 1s (Dregs).
var _lows: Array = []
var _rung: bool = false
var _dregs: bool = false
## Vials in the air: {from, who, at}.
var _vials: Array = []

# --- reading the hand ----------------------------------------------------------------------------

func _live(index: int) -> bool:
	return settled and index >= 0 and index < tiers.size() and tiers[index] is Dictionary and bool(tiers[index].get("active", false))

func _trigger_kind(index: int) -> String:
	return str(defs[index].get("trigger", {}).get("kind", "")) if index >= 0 and index < defs.size() else ""

func _sync_act() -> void:
	_lows.clear()
	_rung = false
	_dregs = false
	if not settled or unit.is_empty() or bool(unit.get("downed", false)) or unit.get("hand", []).is_empty():
		return
	var seen: Array = reading().get("low_ids", [])
	for roll in dice():
		if seen.has(str(roll.get("die_id", ""))):
			_lows.append(str(roll.get("die_id", "")))
	for index in range(defs.size()):
		if not _live(index):
			continue
		if _trigger_kind(index) == "low_count":
			_rung = true
		else:
			_dregs = true

func _look_key() -> String:
	return "%s|%s|%s|%s" % [str(_lows), str(_rung), str(_dregs), str(bool(unit.get("downed", false)))]

func _tick(_delta: float) -> void:
	if _vials.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_vials = _vials.filter(func(vial: Dictionary) -> bool: return float(now - int(vial.at)) / 1000.0 < VIAL + POURING)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	if settled:
		for id in _lows:
			_draw_drop(str(id))
	_draw_vials(Time.get_ticks_msec())

func _draw_drop(id: String) -> void:
	## A low die's drop: faint short of a Tincture, bright once the hand reaches one, and ringed
	## dark green on a hand of all 1s.
	var box: Rect2 = die_corner(id, CORNER_TOP_RIGHT)
	if box.size.x <= 0.0:
		return
	var at: Vector2 = box.get_center()
	var edge: float = box.size.x * 1.05
	var bright: float = 1.0 if _rung else 0.55
	draw_circle(at, edge * 0.5, Color(NIGHT, 0.8 * bright + 0.1))
	draw_arc(at, edge * 0.5, 0.0, TAU, 20, Color(DREGS.lightened(0.25) if _dregs else VENOM, 0.5 + 0.45 * bright), maxf(1.0, u(1.5, 0.75)) * (1.6 if _dregs else 1.0), true)
	draw_glyph("drop", Rect2(at - Vector2(edge, edge) * 0.35, Vector2(edge, edge) * 0.7), Color(VENOM, bright))

func _draw_vials(now: int) -> void:
	## Tincture's vial: thrown up from the stone, it tips over the target and pours.
	for vial in _vials:
		var t: float = float(now - int(vial.at)) / 1000.0
		if t < 0.0:
			continue
		var from: Vector2 = vial.from
		## It hangs just over the creature, under the tag above it.
		var over_target: Vector2 = creature_at(str(vial.who)) - Vector2(0.0, u(56.0, 26.0))
		var flight: float = clampf(t / VIAL, 0.0, 1.0)
		var top := Vector2((from.x + over_target.x) * 0.5, minf(from.y, over_target.y) - u(110.0, 46.0))
		var at: Vector2 = from.lerp(top, flight).lerp(top.lerp(over_target, flight), flight)
		## It turns over as it comes down, and hangs mouth down while it pours.
		var tilt: float = lerpf(0.0, PI * 0.8, clampf((flight - 0.45) / 0.55, 0.0, 1.0))
		var fade: float = clampf((VIAL + POURING - t) / 0.12, 0.0, 1.0)
		var edge: float = u(40.0, 20.0)
		draw_set_transform(at, tilt, Vector2.ONE)
		draw_circle(Vector2.ZERO, edge * 0.62, Color(VENOM, 0.18 * fade))
		draw_glyph("vial", Rect2(-Vector2(edge, edge) * 0.5, Vector2(edge, edge)), Color(VENOM.lightened(0.25), fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if t <= VIAL * 0.8:
			continue
		## What pours out of its mouth onto the target.
		var mouth: Vector2 = at + Vector2.from_angle(tilt - PI * 0.5) * edge * 0.45
		var fall: float = maxf(0.0, creature_at(str(vial.who)).y - mouth.y)
		for drop in range(5):
			var phase: float = fposmod((t - VIAL * 0.8) * 3.2 + float(drop) * 0.2, 1.0)
			var spot: Vector2 = mouth + Vector2(sin(float(drop) * 2.3) * u(4.0, 2.0), fall * phase)
			draw_circle(spot, u(4.5, 2.25) * (1.0 - 0.4 * phase), Color(VENOM, fade * (1.0 - phase * 0.6)))

# --- the stone fires -----------------------------------------------------------------------------

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var me: String = str(unit.get("id", ""))
	var doses: Array = effects.filter(func(effect: Variant) -> bool: return effect is Dictionary and str(effect.get("kind", "")) == "poison" and str(effect.get("target", "")) != me)
	var ticks: Array = effects.filter(func(effect: Variant) -> bool: return effect is Dictionary and str(effect.get("kind", "")) == "tick_poison")
	if not ticks.is_empty():
		## The poison ticks the screen's own way; a ripple runs under every creature it ticks on.
		var again: bool = _trigger_kind(tier_index(str(entry.get("name", "")))) != "low_count"
		_ripples(ticks, 3 if again else 1)
	if doses.is_empty():
		return false
	## Tincture: the vial flies, tips over the target, and its Poison lands as it pours.
	var who: String = str(doses[0].get("target", target_id()))
	var stone_at: Rect2 = stone_rect()
	if not DeepUi.headless() and stone_at.size.x > 0.0:
		_vials.append({"from": stone_at.get_center(), "who": who, "at": Time.get_ticks_msec()})
		busy(VIAL + POURING + 0.2)
	sound("splash", {"volume": 0.35, "pitch": 1.3, "gap": 0.0})
	later(VIAL, land.bind(effects, creature_point(who) + Vector3(0.0, 1.0, 0.0), tone))
	return true

func _ripples(ticks: Array, times: int) -> void:
	var stung: Dictionary = {}
	for effect in ticks:
		for tick in effect.get("ticks", []):
			if tick is Dictionary and int(tick.get("amount", 0)) >= 0:
				stung[str(tick.get("unit", ""))] = true
	if stung.is_empty():
		return
	sound("poison", {"volume": 0.4, "pitch": 0.8 if times > 1 else 1.0, "gap": 0.0})
	for round_at in range(times):
		later(RIPPLE_GAP * float(round_at), _ripple.bind(stung.keys(), round_at))

func _ripple(stung: Array, round_at: int) -> void:
	var room: Node3D = fx()
	if room == null:
		return
	for who in stung:
		var middle: Vector3 = creature_point(str(who))
		room.ring_wave(Vector3(middle.x, 0.0, middle.z), VENOM if round_at % 2 == 0 else DREGS, 1.6 + 0.5 * float(round_at), 0.5, 0.28)
