extends "res://view/battle/birth_act.gd"
## Vesper's Thousand Cuts: five different numbers, and the highest die says how many cuts.
##
## While the hand is planned, dice showing the same number are tied together by a pale thread
## under the tray (Ill Omen's thread), so she sees which of them to throw again. Once all five
## differ the highest die is ringed, with the number of cuts it gives on the ring ("×9"); when
## that die shows its crown as well (Clean Kill) the ring turns gold, wears a crown and counts
## every cut twice ("×18").
##
## When the stone fires, every cut is a thin slash across the target, white going red, in a
## flurry at the pace the screen keeps for the blows; Clean Kill's second pass cuts gold. The
## stone's count is the screen's own, as before.
##
## Both layouts draw the same marks; they stay inside each die's seat on the phone.

const ASH := Color("c9c9d2")
const BLOOD := Color("e2463c")
const EDGE := Color("eef1f8")
const GOLD := Color("f2c14e")
const NIGHT := Color(0.03, 0.03, 0.05)
const SLASH_MS: int = 300
## The screen's own bolt takes this long to reach the creature: the slash is cut as it lands.
const BOLT: float = 0.2
## The lean of one slash after another, so a flurry never cuts the same way twice running.
const LEANS: Array = [-0.55, 0.62, -0.18, 0.95, -0.9, 0.3, -0.38, 0.75]

## Dice showing the same number, each tie left to right.
var _ties: Array = []
## The highest die while all five differ, how many cuts it gives, and whether its crown is up.
var _high_id: String = ""
var _cuts: int = 0
var _clean: bool = false
## Slashes across the creatures ({at, lean, born, long, tone}).
var _slashes: Array = []
var _lean: int = 0

# --- reading the hand ----------------------------------------------------------------------------

func _sync_act() -> void:
	_ties.clear()
	_high_id = ""
	_cuts = 0
	_clean = false
	if not settled or unit.get("hand", []).is_empty() or bool(unit.get("downed", false)):
		return
	var by_value: Dictionary = {}
	var best: int = -1
	var best_id: String = ""
	for roll in dice():
		var id: String = str(roll.get("die_id", ""))
		var kind: String = str(roll.get("kind", "plain"))
		if kind == "blank":
			continue
		## A wild is a number of its own (it counts its top as the highest).
		var shows: int = int(roll.get("top", 0)) if kind == "wild" else int(roll.get("value", 0))
		if shows > best:
			best = shows
			best_id = id
		if kind == "wild":
			continue
		if not by_value.has(shows):
			by_value[shows] = []
		by_value[shows].append(id)
	for value in by_value:
		if by_value[value].size() >= 2:
			_ties.append(by_value[value])
	if not lit("Thousand Cuts"):
		return
	_high_id = best_id
	_clean = lit("Clean Kill")
	for tier_name in ["Thousand Cuts", "Clean Kill"]:
		if not lit(tier_name):
			continue
		for effect in tier_now(tier_name).get("effects", []):
			if effect is Dictionary and str(effect.get("kind", "")) == "damage":
				_cuts += 1
	if _cuts <= 0:
		_cuts = int(reading().get("high", best)) * (2 if _clean else 1)

func _look_key() -> String:
	return "%s|%s|%d|%s|%s" % [str(_ties), _high_id, _cuts, str(_clean), str(planning)]

func _tick(_delta: float) -> void:
	if _slashes.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_slashes = _slashes.filter(func(cut: Dictionary) -> bool: return now < int(cut.born) + SLASH_MS)

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	if settled:
		if planning:
			for tie in _ties:
				_draw_tie(tie)
		if not _high_id.is_empty():
			_draw_high(_high_id)
	_draw_slashes(Time.get_ticks_msec())

func _foot(id: String) -> Vector2:
	## Where a tie touches a die: under its solid, inside its seat.
	var seat: Rect2 = die_rect(id)
	var face: Rect2 = die_face(id)
	if seat.size.x <= 0.0:
		return Vector2.INF
	return Vector2(face.get_center().x, lerpf(face.end.y, seat.end.y, 0.25))

func _draw_tie(ids: Array) -> void:
	## A pale thread hanging from one die of a tie to the next, a knot on each: the dice that
	## keep the five from differing.
	var feet: Array = []
	var floor_y: float = -1.0
	for id in ids:
		var foot: Vector2 = _foot(str(id))
		if foot == Vector2.INF:
			return
		feet.append(foot)
		floor_y = maxf(floor_y, die_rect(str(id)).end.y)
	var thick: float = maxf(1.5, u(2.5, 1.25))
	var sag: float = maxf(0.0, floor_y - feet[0].y) * 0.8
	for index in range(feet.size() - 1):
		var from: Vector2 = feet[index]
		var to: Vector2 = feet[index + 1]
		var low := Vector2((from.x + to.x) * 0.5, maxf(from.y, to.y) + sag * 2.0)
		var curve := PackedVector2Array()
		for step in range(17):
			var k: float = float(step) / 16.0
			curve.append(from.lerp(low, k).lerp(low.lerp(to, k), k))
		draw_polyline(curve, Color(NIGHT, 0.75), thick + maxf(2.0, u(3.0, 1.5)), true)
		draw_polyline(curve, ASH, thick, true)
	for foot in feet:
		draw_circle(foot, thick * 2.0, Color(NIGHT, 0.85))
		draw_circle(foot, thick * 1.35, ASH)

func _draw_high(id: String) -> void:
	## The highest die ringed, its cuts on a chip at the ring's foot; gold, crowned and counted
	## twice under Clean Kill.
	var face: Rect2 = die_face(id)
	var seat: Rect2 = die_rect(id)
	if face.size.x <= 0.0:
		return
	var tone: Color = GOLD if _clean else EDGE
	var middle: Vector2 = face.get_center()
	var radius: float = face.size.x * 0.66
	var thick: float = maxf(1.5, u(2.5, 1.25))
	draw_arc(middle, radius, 0.0, TAU, 40, Color(NIGHT, 0.85), thick + maxf(2.0, u(3.0, 1.5)), true)
	draw_arc(middle, radius, 0.0, TAU, 40, tone, thick, true)
	if _clean:
		var crown: Rect2 = die_corner(id, CORNER_TOP_LEFT, face.size.x * 0.46)
		var rim: float = maxf(1.0, u(1.5, 1.0))
		for shift in [Vector2(-rim, 0.0), Vector2(rim, 0.0), Vector2(0.0, -rim), Vector2(0.0, rim)]:
			draw_glyph("crown", Rect2(crown.position + shift, crown.size), Color(NIGHT, 0.9))
		draw_glyph("crown", crown, GOLD)
	if _cuts <= 0:
		return
	var px: int = text_px(16)
	var size_px: int = maxi(px, DeepUi.min_text())
	var said: String = "×%s" % DeepUi.number(_cuts)
	var wide: float = DeepUi.bold_font().get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + u(10.0, 5.0)
	var tall: float = float(size_px) + u(4.0, 2.0)
	var at := Vector2(middle.x, seat.end.y - (DeepUi.pt(4.0) if DeepUi.phone else 2.0))
	var chip := Rect2(at - Vector2(wide, tall) * 0.5, Vector2(wide, tall))
	draw_style_box(DeepUi.flat(Color(NIGHT, 0.95), tone, int(tall * 0.5), 0, maxi(1, int(u(2.0, 1.0)))), chip)
	draw_words(said, chip.get_center(), px, tone.lightened(0.15))

func _draw_slashes(now: int) -> void:
	## A cut: drawn across in a blink, then a thin bright wound fading to red.
	for cut in _slashes:
		var t: float = float(now - int(cut.born)) / float(SLASH_MS)
		if t < 0.0 or t >= 1.0:
			continue
		var grow: float = clampf(t / 0.22, 0.05, 1.0)
		var fade: float = clampf((1.0 - t) / 0.7, 0.0, 1.0)
		var way := Vector2.RIGHT.rotated(float(cut.lean))
		var side: Vector2 = way.orthogonal()
		var long: float = float(cut.long)
		var start: Vector2 = (cut.at as Vector2) - way * long * 0.5
		var tone: Color = cut.tone
		var core: Color = Color.WHITE.lerp(tone, clampf(t * 1.6, 0.0, 1.0))
		var wide: float = u(5.0, 2.5)
		for layer in range(2):
			var spread: float = wide * (2.6 if layer == 0 else 1.0)
			var shape := PackedVector2Array()
			var steps: int = 10
			for step in range(steps + 1):
				var k: float = float(step) / float(steps)
				shape.append(start + way * long * grow * k + side * spread * sin(k * PI))
			for step in range(steps - 1, 0, -1):
				var k: float = float(step) / float(steps)
				shape.append(start + way * long * grow * k - side * spread * 0.35 * sin(k * PI))
			var ink: Color = Color(tone, 0.35 * fade) if layer == 0 else Color(core, fade)
			draw_colored_polygon(shape, ink)

# --- the stone fires -----------------------------------------------------------------------------

func _near(who: String) -> Vector3:
	## Just in front of a creature, toward the lens: the screen's bolt leaves from here, so it
	## shows only as the glint before the cut.
	var at: Vector3 = creature_point(who)
	if screen != null and not DeepUi.headless() and screen._camera != null:
		var lens: Vector3 = screen._camera.global_position
		if lens.distance_to(at) > 1.0:
			return at + (lens - at).normalized() * 0.7
	return at

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var blows: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	var clean: bool = str(entry.get("name", "")) == "Clean Kill"
	if clean and not _high_id.is_empty():
		## The crown that earned the second pass glints first.
		var face: Rect2 = die_face(_high_id)
		if face.size.x > 0.0:
			burst(face.get_center(), GOLD, 16, u(170.0, 80.0), 0.45, u(5.0, 2.5))
		sound("gleam", {"volume": 0.5, "pitch": 1.3, "gap": 0.0})
	var gap: float = DeepBattle.HIT_STEP * DeepBattle.hit_pace(effects)
	for index in range(blows.size()):
		later(gap * float(index), _cut.bind(blows[index], clean))
	if not rest.is_empty():
		later(gap * float(blows.size()), land.bind(rest, origin, tone))
	busy(gap * float(blows.size()) + BOLT + float(SLASH_MS) / 1000.0 + 0.2)
	return true

func _cut(hit: Dictionary, clean: bool) -> void:
	## The screen's bolt at its smallest, in a dim red or gold: a glint, not a light on the floor.
	var who: String = str(hit.get("target", target_id()))
	land([hit], _near(who), GOLD.darkened(0.35) if clean else BLOOD.darkened(0.3), 0.0)
	later(BOLT, _slash.bind(who, clean, bool(hit.get("killed", false))))

func _slash(who: String, clean: bool, killed: bool) -> void:
	if DeepUi.headless():
		return
	var lean: float = float(LEANS[_lean % LEANS.size()])
	_lean += 1
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * u(24.0, 12.0)
	_slashes.append({"at": creature_at(who) + jitter, "lean": lean, "born": Time.get_ticks_msec(), "long": u(170.0, 86.0) * (1.35 if killed else 1.0), "tone": GOLD if clean else BLOOD})
	busy(float(SLASH_MS) / 1000.0 + 0.1)
	sound("claw", {"volume": 0.22, "pitch": 1.5 + randf() * 0.3, "gap": 0.05})
