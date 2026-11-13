extends "res://view/battle/birth_act.gd"
## Rue's Bloodroot: every 1 is the price and the growth, and her health ring is where it shows.
##
## Every 1 in the tray wears a drop of blood, and while the hand is planned a line over the tray
## adds up what Tap would take ("3 ones: −5 health, 5 Poison, +3 max"): the price climbs with
## every 1 she has rolled this fight. Her ring grows: the max health Take Root has lent her for
## the fight is a pale arc outside it, and beside the numbers under it stands what the stone has
## grown her this run ("+9 this run"). While the hand would Take Root, the stretch of the ring
## she would then be missing is marked in red with the blow it would deal.
##
## When the stone fires, Tap drips each 1 into the stone, the ring flinches and its outer edge
## creeps out. Take Root grows red roots round the ring and widens it, then tears the empty part
## away and throws it at the target. Transfusion pours from the stone into the ring and sends
## one ring of red out to every creature. Heartsblood beats the ring, each beat a blow at a
## creature picked at random.
##
## Both layouts draw the same pieces round the same ring; the price line sits over the tray.

const BLOODSTONE := Color("2f4f3d")
const BLOOD := Color("b3261e")
const BLOOD_HI := Color("e5483a")
const BLOOD_PALE := Color("f2a093")
const NIGHT := Color(0.02, 0.03, 0.05)
## A 1's drip into the stone, and how far apart the dice let theirs go.
const DRIP: float = 0.22
const DRIP_GAP: float = 0.04
const DRIPS_MOST: int = 8
const FLINCH_MS: int = 300
const CREEP_MS: int = 700
## Take Root: the roots grow, stand, and the empty part of the ring flies.
const ROOTS: float = 0.3
const ROOTS_HOLD: float = 1.0
const ROOT_COUNT: int = 6
const TEAR: float = 0.22
## Transfusion's pour from the stone to the ring.
const POUR: float = 0.3
const BEAT_MS: int = 260

var _line: HBoxContainer = null
var _line_said: Label = null
var _grown: Label = null
var _growth: int = 0
## The dice showing 1, and Tap's price for them: {ones, price, grow} (empty when Tap is not lit).
var _ones: Array = []
var _price: Dictionary = {}
## Take Root's mark while the hand would make it: the share of the ring she would still hold
## (the rest is what she would be missing) and the blow it would deal; -1 for no mark.
var _root_from: float = -1.0
var _root_blow: int = 0
## The fight's lent max health as a share of her max health, and her growth this run, as they
## were last planned: what the ring shows while the stone fires, until Take Root and Tap land.
var _lent_seen: float = 0.0
var _growth_seen: int = 0
var _holding: bool = false
var _root_played: bool = false
var _tap_played: bool = false
var _tapped: bool = false
## Moments: drips {from, at}; when the ring flinched, its edge crept, the roots grew, the lent
## arc widened (from `_widen_from`), the pour began (ms, -1 for none); torn pieces {share, to,
## at}; heartbeats [ms].
var _drips: Array = []
var _flinch_at: int = -1
var _creep_at: int = -1
var _roots_at: int = -1
var _widen_at: int = -1
var _widen_from: float = 0.0
var _pour_at: int = -1
var _tears: Array = []
var _beats: Array = []
var _origin: Vector3 = Vector3.ZERO

func _open() -> void:
	_line = HBoxContainer.new()
	_line.name = "PriceLine"
	_line.add_theme_constant_override("separation", int(u(5.0, 2.5)))
	_line.mouse_filter = Control.MOUSE_FILTER_PASS
	var mark: TextureRect = GemIcons.glyph(_line, "drop", DeepUi.glyph_px(text_px(14), 1.0), BLOOD_HI)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_line_said = words(_line, "", 15, BLOOD_PALE)
	_line.visible = false
	place(_line, "over_tray", 0.5)
	tip(_line, _price_plate, {"tone": BLOOD_HI})
	_grown = words(self, "", 12, BLOOD_PALE)
	_grown.name = "Grown"
	_grown.mouse_filter = Control.MOUSE_FILTER_PASS
	_grown.visible = false
	tip(_grown, _grown_plate, {"tone": BLOOD_HI})

# --- reading the stone ---------------------------------------------------------------------------

func _role(index: int) -> String:
	## What a tier is, by what content wrote it does: "tap" counts the 1s, "root" lends max
	## health for the fight, "transfuse" heals, "heart" strikes at random.
	if index < 0 or index >= defs.size():
		return ""
	for effect in defs[index].get("effects", []):
		if not effect is Dictionary:
			continue
		var kind: String = str(effect.get("kind", ""))
		if kind == "fight_count":
			return "tap"
		if kind == "max_hp" and bool(effect.get("for_fight", false)):
			return "root"
		if kind == "heal":
			return "transfuse"
		if kind == "damage" and str(effect.get("target", "")) == "enemy_random":
			return "heart"
	return ""

func _index_of(role: String) -> int:
	for index in range(defs.size()):
		if _role(index) == role:
			return index
	return -1

func _live(index: int) -> bool:
	return settled and index >= 0 and index < tiers.size() and tiers[index] is Dictionary and bool(tiers[index].get("active", false))

func _lent() -> float:
	## The max health lent for this fight, as a share of her max health.
	var most: int = maxi(1, int(unit.get("max_hp", 1)))
	return clampf(float(int(unit.get("fight_max_hp", 0))) / float(most), 0.0, 1.0)

func _blow(effect: Variant) -> bool:
	## A blow at a creature (not the health Tap takes from her).
	return effect is Dictionary and str(effect.get("kind", "")) == "damage" and not bool(effect.get("lost_hp", false)) and str(effect.get("target", "")) != str(unit.get("id", ""))

func _read_price() -> Dictionary:
	## Tap's price for the 1s showing: health and Poison for every 1 rolled this fight, these
	## too, and a point of max health for the run for each of these.
	var tap: int = _index_of("tap")
	if tap < 0 or _ones.is_empty() or not _live(tap):
		return {}
	var ones: int = _ones.size()
	var price: int = DeepRules.sat_add(int(unit.get("fight_ones", 0)), ones)
	var grow: int = ones
	for effect in tiers[tap].get("effects", []):
		if not effect is Dictionary:
			continue
		match str(effect.get("kind", "")):
			"fight_count":
				price = int(effect.get("total", price))
			"max_hp":
				grow = int(effect.get("amount", grow))
	return {"ones": ones, "price": price, "grow": grow}

func _read_root() -> void:
	## Where Take Root would leave her ring, and what it would deal: the forecast's.
	_root_from = -1.0
	_root_blow = 0
	var root: int = _index_of("root")
	if not planning or not _live(root):
		return
	var most: int = 0
	var held: int = -1
	for effect in tiers[root].get("effects", []):
		if not effect is Dictionary:
			continue
		if str(effect.get("kind", "")) == "max_hp":
			most = int(effect.get("max_hp_after", 0))
			held = int(effect.get("hp_after", -1))
		elif _blow(effect):
			_root_blow += int(effect.get("raw", effect.get("amount", 0)))
	if most <= 0 or held < 0:
		most = maxi(1, int(unit.get("max_hp", 1)))
		held = int(unit.get("hp", 0))
	_root_from = clampf(float(held) / float(most), 0.0, 1.0)

func _sync_act() -> void:
	var down: bool = bool(unit.get("downed", false))
	var up: bool = settled and not down and not unit.get("hand", []).is_empty()
	_ones.clear()
	if up:
		var seen: Array = reading().get("one_ids", [])
		for roll in dice():
			if seen.has(str(roll.get("die_id", ""))):
				_ones.append(str(roll.get("die_id", "")))
	var counts: Variant = unit.get("run_counts", {})
	_growth = int((counts as Dictionary).get(DeepBattle.GROWN, 0)) if counts is Dictionary else 0
	if planning:
		_lent_seen = _lent()
		_growth_seen = _growth
		_holding = false
		_tapped = false
	_price = _read_price() if up and planning else {}
	_line.visible = not _price.is_empty()
	if _line.visible:
		var ones: int = int(_price.ones)
		_line_said.text = "%s %s: −%s health, %s Poison, +%s max" % [DeepUi.number(ones), "one" if ones == 1 else "ones", DeepUi.number(int(_price.price)), DeepUi.number(int(_price.price)), DeepUi.number(int(_price.grow))]
		_line.reset_size()
	if up:
		_read_root()
	else:
		_root_from = -1.0
	_show_growth()

func _show_growth() -> void:
	## The run's growth beside the health numbers, held at what was planned until Tap lands.
	var growth: int = _growth_seen if _holding and not _tap_played else _growth
	_grown.visible = growth > 0 and not unit.is_empty() and not bool(unit.get("downed", false))
	if _grown.visible:
		_grown.text = "+%s this run" % DeepUi.number(growth)
		_grown.reset_size()
		_place_grown()

func _lent_now() -> float:
	## The lent arc as the ring shows it: held at what was planned until Take Root lands.
	return _lent_seen if _holding and not _root_played else _lent()

func _look_key() -> String:
	return "%s|%s|%.3f|%d|%.4f|%s|%s|%s|%s" % [str(_ones), str(_price), _root_from, _root_blow, _lent_now(), str(_tapped), str(_grown.position), _grown.text, str(bool(unit.get("downed", false)))]

func _price_plate() -> Control:
	var ones: int = int(_price.get("ones", 0))
	var price: int = int(_price.get("price", 0))
	return Plates.words("Tap", "Every 1 showing costs 1 health and 1 Poison for every 1 you have rolled this fight (%s so far, %s with these), and grows your max health by 1 for the rest of the run." % [DeepUi.number(maxi(0, price - ones)), DeepUi.number(price)], "every 1 showing", BLOOD_PALE)

func _grown_plate() -> Control:
	return Plates.words("Bloodroot", "Tap has grown your max health by %s this run, one for every 1 it has drunk." % DeepUi.number(_growth), "this run", BLOOD_PALE)

# --- where things stand --------------------------------------------------------------------------

func _ring() -> Dictionary:
	## The health ring's measures in this act's space (view/battle/vitals_ring.gd draws it from
	## its edge): its middle, the health arc's radius and width, and the block arc's radius.
	var box: Rect2 = ring_rect()
	if box.size.x <= 0.0:
		return {}
	var edge: float = box.size.x
	return {"centre": box.position + Vector2(edge, edge) * 0.5, "edge": edge, "hp": edge * 0.405, "width": maxf(6.0, edge * 0.062), "block": edge * 0.468}

func _capsule() -> Rect2:
	## The health numbers under the ring.
	var vitals: Variant = page.hp_bar if page != null else null
	if not vitals is Control or not is_instance_valid(vitals):
		return Rect2()
	var capsule: Variant = (vitals as Control).get("plate")
	return _rect_of(capsule) if capsule is Control else Rect2()

func _tick(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not _drips.is_empty():
		_drips = _drips.filter(func(drip: Dictionary) -> bool: return float(now - int(drip.at)) / 1000.0 < DRIP)
	if not _tears.is_empty():
		_tears = _tears.filter(func(tear: Dictionary) -> bool: return float(now - int(tear.at)) / 1000.0 < TEAR)
	if not _beats.is_empty():
		_beats = _beats.filter(func(beat: int) -> bool: return now - beat < BEAT_MS)
	_place_grown()

func _place_grown() -> void:
	## The run's growth beside the health numbers under the ring.
	if _grown == null or not _grown.visible:
		return
	var wide: Vector2 = _grown.get_combined_minimum_size()
	var capsule: Rect2 = _capsule()
	var at := Vector2.ZERO
	if capsule.size.x > 0.0:
		at = Vector2(capsule.end.x + u(6.0, 3.0), capsule.get_center().y - wide.y * 0.5)
	else:
		var ring: Rect2 = ring_rect()
		at = Vector2(ring.end.x, ring.end.y - wide.y)
	var left: float = DeepUi.safe_left if DeepUi.phone else 4.0
	var right: float = size.x - (DeepUi.safe_right if DeepUi.phone else 4.0)
	at.x = clampf(at.x, left, maxf(left, right - wide.x))
	at.y = clampf(at.y, 4.0, maxf(4.0, size.y - (DeepUi.safe_bottom if DeepUi.phone else 4.0) - wide.y))
	if not _grown.position.is_equal_approx(at):
		_grown.position = at

# --- drawing -------------------------------------------------------------------------------------

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var now: int = Time.get_ticks_msec()
	var ring: Dictionary = _ring()
	if not ring.is_empty():
		_draw_lent(ring, now)
		_draw_roots(ring, now)
		if planning and settled:
			_draw_root_mark(ring)
		_draw_flinch(ring, now)
		_draw_beats(ring, now)
		_draw_pour(ring, now)
	if settled and not _tapped:
		_draw_ones()
	_draw_drips(now)
	_draw_tears(ring, now)

func _draw_ones() -> void:
	## A drop of blood on the corner of every die showing 1.
	for id in _ones:
		var box: Rect2 = die_corner(str(id), CORNER_TOP_RIGHT)
		if box.size.x <= 0.0:
			continue
		var at: Vector2 = box.get_center()
		var edge: float = box.size.x * 1.1
		draw_circle(at, edge * 0.5, Color(NIGHT, 0.82))
		draw_arc(at, edge * 0.5, 0.0, TAU, 20, Color(BLOOD, 0.9), maxf(1.0, u(1.5, 0.75)), true)
		draw_glyph("drop", Rect2(at - Vector2(edge, edge) * 0.36, Vector2(edge, edge) * 0.72), BLOOD_HI)

func _draw_lent(ring: Dictionary, now: int) -> void:
	## The max health lent for the fight: a pale arc outside the ring over the last stretch of
	## it (the share of her max health that is borrowed), widening as Take Root lends more.
	var share: float = _lent_now()
	if _widen_at >= 0:
		var t: float = clampf(float(now - _widen_at) / 1000.0 / ROOTS, 0.0, 1.0)
		share = lerpf(_widen_from, share, t * t * (3.0 - 2.0 * t))
		if t >= 1.0:
			_widen_at = -1
	if share <= 0.002:
		return
	var centre: Vector2 = ring.centre
	var radius: float = float(ring.block) + u(7.0, 3.5)
	var width: float = maxf(2.0, u(4.0, 2.0))
	var top: float = -PI * 0.5
	var from: float = top + TAU * (1.0 - share)
	draw_arc(centre, radius, from, top + TAU, 64, Color(NIGHT, 0.7), width + u(3.0, 1.5), true)
	draw_arc(centre, radius, from, top + TAU, 64, Color(BLOOD_PALE, 0.9), width, true)

func _draw_root_mark(ring: Dictionary) -> void:
	## Take Root's mark: the stretch of the ring she would be missing, edged red, and on it the
	## blow that missing health would deal.
	if _root_from < 0.0:
		return
	var centre: Vector2 = ring.centre
	var radius: float = ring.hp
	var width: float = ring.width
	var top: float = -PI * 0.5
	var a: float = top + TAU * _root_from
	var b: float = top + TAU
	var line: float = maxf(1.5, u(2.0, 1.0))
	if b - a > 0.01:
		draw_arc(centre, radius, a, b, 64, Color(BLOOD, 0.5), width, true)
		draw_arc(centre, radius + width * 0.5, a, b, 64, BLOOD_HI, line, true)
		draw_arc(centre, radius - width * 0.5, a, b, 64, BLOOD_HI, line, true)
		for angle in [a, b]:
			var way: Vector2 = Vector2.from_angle(float(angle))
			draw_line(centre + way * (radius - width * 0.5), centre + way * (radius + width * 0.5), BLOOD_HI, line, true)
	var text: String = DeepUi.number(_root_blow)
	var px: int = text_px(13)
	var size_px: int = maxi(px, DeepUi.min_text())
	var wide: float = DeepUi.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var round_r: float = maxf(wide * 0.5 + u(6.0, 3.0), float(size_px) * 0.78)
	var at: Vector2 = centre + Vector2.from_angle((a + b) * 0.5 if b - a > 0.01 else top) * radius
	var left: float = (DeepUi.safe_left if DeepUi.phone else 4.0) + round_r
	at.x = maxf(at.x, left)
	at.y = maxf(at.y, round_r + 4.0)
	draw_circle(at, round_r, Color(NIGHT, 0.95))
	draw_arc(at, round_r, 0.0, TAU, 28, BLOOD_HI, line, true)
	draw_words(text, at, px, BLOOD_PALE)

func _draw_roots(ring: Dictionary, now: int) -> void:
	## Take Root's roots: dark red runners growing from the foot of the ring up round it.
	if _roots_at < 0:
		return
	var since: float = float(now - _roots_at) / 1000.0
	if since > ROOTS_HOLD + 0.3:
		_roots_at = -1
		return
	var grown: float = 1.0 - pow(1.0 - clampf(since / ROOTS, 0.0, 1.0), 2.0)
	var fade: float = clampf((ROOTS_HOLD + 0.3 - since) / 0.3, 0.0, 1.0)
	var centre: Vector2 = ring.centre
	var base: float = float(ring.block) + u(4.0, 2.0)
	for index in range(ROOT_COUNT):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		## From the ring's sides (clear of the health numbers under it), up round it.
		var start: float = PI * 0.5 + side * (1.15 + 0.2 * float(index / 2))
		var sweep: float = (0.8 + 0.25 * float(index % 3)) * grown
		var runner := PackedVector2Array()
		for step in range(15):
			var k: float = float(step) / 14.0
			var angle: float = start + side * sweep * k
			var wobble: float = sin(k * 9.0 + float(index) * 1.7) * u(3.0, 1.5) * k
			runner.append(centre + Vector2.from_angle(angle) * (base + wobble + u(3.0, 1.5) * k * float(index % 2)))
		draw_polyline(runner, Color(NIGHT, 0.6 * fade), u(7.0, 3.5), true)
		for step in range(runner.size() - 1):
			var k: float = float(step) / float(runner.size() - 1)
			draw_line(runner[step], runner[step + 1], Color(BLOOD.lerp(BLOOD_HI, k * 0.8), fade), maxf(1.0, u(5.0, 2.5) * (1.0 - k * 0.7)), true)
		## A rootlet off the middle of each runner.
		var mid: Vector2 = runner[7]
		var off: float = start + side * sweep * 0.5 - side * 0.9
		draw_line(mid, mid + Vector2.from_angle(off) * u(11.0, 5.5) * grown, Color(BLOOD_HI, fade), maxf(1.0, u(2.5, 1.25)), true)

func _draw_flinch(ring: Dictionary, now: int) -> void:
	## Tap's price landing: the ring flinches red, then its outer edge creeps out a little.
	var centre: Vector2 = ring.centre
	if _flinch_at >= 0:
		var t: float = float(now - _flinch_at) / float(FLINCH_MS)
		if t >= 1.0:
			_flinch_at = -1
		elif t >= 0.0:
			var shake := Vector2(sin(t * 40.0) * u(4.0, 2.0) * (1.0 - t), 0.0)
			draw_arc(centre + shake, ring.hp, 0.0, TAU, 64, Color(BLOOD_HI, 0.65 * (1.0 - t)), float(ring.width) * 1.3, true)
	if _creep_at >= 0:
		var t: float = float(now - _creep_at) / float(CREEP_MS)
		if t >= 1.0:
			_creep_at = -1
		elif t >= 0.0:
			var out: float = float(ring.block) + u(3.0, 1.5) + u(12.0, 6.0) * (1.0 - pow(1.0 - t, 2.0))
			draw_arc(centre, out, 0.0, TAU, 96, Color(BLOOD_PALE, 0.8 * (1.0 - t)), maxf(1.5, u(3.0, 1.5)), true)

func _draw_beats(ring: Dictionary, now: int) -> void:
	## Heartsblood: the ring swells red with each beat, a pale pulse going out from it.
	for beat in _beats:
		var t: float = float(now - int(beat)) / float(BEAT_MS)
		if t < 0.0 or t >= 1.0:
			continue
		var swell: float = sin(t * PI)
		draw_arc(ring.centre, ring.hp, 0.0, TAU, 64, Color(BLOOD_HI, 0.75 * (1.0 - t)), float(ring.width) * (1.0 + 0.9 * swell), true)
		draw_arc(ring.centre, float(ring.block) + u(12.0, 6.0) * t, 0.0, TAU, 64, Color(BLOOD_PALE, 0.5 * (1.0 - t)), maxf(1.5, u(3.0, 1.5)), true)

func _pour_point(from: Vector2, to: Vector2, k: float) -> Vector2:
	var over := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - u(70.0, 30.0))
	return from.lerp(over, k).lerp(over.lerp(to, k), k)

func _draw_pour(ring: Dictionary, now: int) -> void:
	## Transfusion: a stream of red from the stone over the rail into the ring.
	if _pour_at < 0:
		return
	var t: float = float(now - _pour_at) / 1000.0 / POUR
	if t >= 1.5:
		_pour_at = -1
		return
	var stone_at: Rect2 = stone_rect()
	if stone_at.size.x <= 0.0 or t < 0.0:
		return
	var from: Vector2 = stone_at.get_center()
	var to: Vector2 = ring.centre
	var head: float = clampf(t, 0.0, 1.0)
	var tail: float = clampf((t - 0.5) / 1.0, 0.0, 1.0)
	if head - tail <= 0.01:
		return
	var stream := PackedVector2Array()
	for step in range(17):
		stream.append(_pour_point(from, to, lerpf(tail, head, float(step) / 16.0)))
	var width: float = u(7.0, 3.5)
	draw_polyline(stream, Color(NIGHT, 0.6), width + u(3.0, 1.5), true)
	draw_polyline(stream, BLOOD_HI, width, true)
	draw_polyline(stream, Color(BLOOD_PALE, 0.7), width * 0.3, true)
	if t < 1.0:
		draw_circle(stream[stream.size() - 1], width * 0.8, BLOOD_PALE)

func _draw_drips(now: int) -> void:
	## A 1's drop of blood on its way from its die into the stone.
	var stone_at: Rect2 = stone_rect()
	if stone_at.size.x <= 0.0:
		return
	var to: Vector2 = stone_at.get_center()
	for drip in _drips:
		var t: float = float(now - int(drip.at)) / 1000.0 / DRIP
		if t < 0.0 or t >= 1.0:
			continue
		var from: Vector2 = drip.from
		var over := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - u(56.0, 24.0))
		var k: float = t * t
		var at: Vector2 = from.lerp(over, k).lerp(over.lerp(to, k), k)
		var edge: float = u(22.0, 11.0) * (1.0 - 0.35 * t)
		draw_circle(at, edge * 0.6, Color(BLOOD, 0.25))
		draw_glyph("drop", Rect2(at - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), BLOOD_HI)

func _draw_tears(ring: Dictionary, now: int) -> void:
	## The empty part of the ring torn away and thrown at the target, spinning as it goes.
	if ring.is_empty():
		return
	var top: float = -PI * 0.5
	for tear in _tears:
		var t: float = float(now - int(tear.at)) / 1000.0 / TEAR
		if t < 0.0 or t >= 1.0:
			continue
		var a: float = top + TAU * float(tear.share)
		var b: float = top + TAU
		if b - a < 0.05:
			a = b - 0.05
		var centre: Vector2 = ring.centre
		var home: Vector2 = centre + Vector2.from_angle((a + b) * 0.5) * float(ring.hp)
		var now_at: Vector2 = home + ((tear.to as Vector2) - home) * t * t
		var spin: float = t * 2.4
		var shrink: float = 1.0 - 0.45 * t
		var piece := PackedVector2Array()
		for step in range(25):
			var on_ring: Vector2 = centre + Vector2.from_angle(lerpf(a, b, float(step) / 24.0)) * float(ring.hp) - home
			piece.append(now_at + on_ring.rotated(spin) * shrink)
		var width: float = float(ring.width) * (1.2 - 0.4 * t)
		draw_polyline(piece, Color(NIGHT, 0.7), width + u(3.0, 1.5), true)
		draw_polyline(piece, BLOOD_HI.lerp(BLOOD, t), width, true)

# --- the stone fires -----------------------------------------------------------------------------

func _fired(_played: Dictionary) -> void:
	## The fight already holds what the stone did: the ring keeps what was planned until each
	## tier lands its part.
	_holding = true
	_tap_played = false
	_root_played = false

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	_origin = origin
	match _role(tier_index(str(entry.get("name", "")))):
		"tap":
			return _tap(effects, origin, tone)
		"root":
			return _take_root(effects, origin, tone)
		"transfuse":
			return _transfuse(effects, origin, tone)
		"heart":
			return _heartsblood(effects, origin, tone)
	return false

func _tap(effects: Array, origin: Vector3, tone: Color) -> bool:
	## Each 1 drips from its die into the stone; as the last arrives the price lands, the ring
	## flinches and its edge creeps out with the max health it grows.
	var sources: Array = []
	for id in _ones:
		var face: Rect2 = die_face(str(id))
		if face.size.x > 0.0:
			sources.append(face.get_center())
	_tapped = true
	if sources.is_empty() or DeepUi.headless():
		_flinch(effects, origin, tone)
		return true
	var now: int = Time.get_ticks_msec()
	var count: int = mini(sources.size(), DRIPS_MOST)
	for index in range(count):
		_drips.append({"from": sources[index], "at": now + int(DRIP_GAP * 1000.0 * float(index))})
		later(DRIP_GAP * float(index) + DRIP, sound.bind("hit_drink", {"volume": 0.35, "pitch": 1.4 + 0.08 * float(index), "gap": 0.0}))
	var arrive: float = DRIP + DRIP_GAP * float(count - 1)
	busy(arrive + float(CREEP_MS) / 1000.0 + 0.3)
	later(arrive, _flinch.bind(effects, origin, tone))
	return true

func _flinch(effects: Array, origin: Vector3, tone: Color) -> void:
	var now: int = Time.get_ticks_msec()
	_flinch_at = now
	_creep_at = now + 120
	_tap_played = true
	_show_growth()
	busy(float(CREEP_MS + 120) / 1000.0 + 0.2)
	land(effects, origin, tone)

func _take_root(effects: Array, origin: Vector3, tone: Color) -> bool:
	## Roots grow round the ring and the lent arc widens with the max health; then the empty part
	## of the ring is torn away and thrown at the target as the blow.
	var blows: Array = effects.filter(func(effect: Variant) -> bool: return _blow(effect))
	var rest: Array = effects.filter(func(effect: Variant) -> bool: return not _blow(effect))
	var now: int = Time.get_ticks_msec()
	_roots_at = now
	_widen_at = now
	_widen_from = _lent_now()
	_root_played = true
	busy(ROOTS_HOLD + 0.4)
	sound("crumble", {"volume": 0.4, "pitch": 1.2, "gap": 0.0})
	if not rest.is_empty():
		land(rest, origin, tone)
	if blows.is_empty():
		return true
	## What she holds of her ring once the roots have widened it: the rest is torn away.
	var share: float = clampf(float(int(unit.get("hp", 0))) / float(maxi(1, int(unit.get("max_hp", 1)))), 0.0, 1.0)
	for effect in rest:
		if effect is Dictionary and str(effect.get("kind", "")) == "max_hp" and int(effect.get("max_hp_after", 0)) > 0:
			share = clampf(float(int(effect.get("hp_after", 0))) / float(int(effect.max_hp_after)), 0.0, 1.0)
	later(ROOTS, _tear.bind(blows, share))
	return true

func _tear(blows: Array, share: float) -> void:
	var ring: Dictionary = _ring()
	var from: Vector3 = room_point(ring.centre, 2.0) if not ring.is_empty() else _origin
	if not DeepUi.headless() and not ring.is_empty():
		var who: String = str(blows[0].get("target", target_id()))
		_tears.append({"share": share, "to": creature_at(who), "at": Time.get_ticks_msec()})
		busy(TEAR + 0.3)
		var top: float = -PI * 0.5
		burst((ring.centre as Vector2) + Vector2.from_angle(top + TAU * (share + 1.0) * 0.5) * float(ring.hp), BLOOD_HI, 12, u(150.0, 70.0), 0.4, u(4.0, 2.0))
	sound("block_break", {"volume": 0.5, "pitch": 0.75, "gap": 0.0})
	land(blows, from, BLOOD_HI)

func _transfuse(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The stone pours into the ring as she heals, and what it restored goes out as one ring of
	## red to every creature.
	var blows: Array = effects.filter(func(effect: Variant) -> bool: return _blow(effect))
	var rest: Array = effects.filter(func(effect: Variant) -> bool: return not _blow(effect))
	_pour_at = Time.get_ticks_msec()
	busy(POUR * 1.5 + 0.3)
	sound("splash", {"volume": 0.35, "pitch": 0.7, "gap": 0.0})
	if not rest.is_empty():
		later(POUR * 0.75, land.bind(rest, origin, tone))
	if not blows.is_empty():
		later(POUR, _wave_out.bind(blows))
	return true

func _wave_out(blows: Array) -> void:
	var room: Node3D = fx()
	if room != null:
		var middle := Vector3.ZERO
		var spots: Array = []
		for blow in blows:
			var spot: Vector3 = creature_point(str(blow.get("target", "")))
			spots.append(spot)
			middle += spot
		middle /= float(maxi(1, spots.size()))
		var reach: float = 1.4
		for spot in spots:
			reach = maxf(reach, Vector2((spot as Vector3).x - middle.x, (spot as Vector3).z - middle.z).length() + 1.2)
		room.ring_wave(Vector3(middle.x, 0.0, middle.z), BLOOD_HI, reach, 0.45, 0.45)
	sound("hit_heavy", {"volume": 0.4, "pitch": 0.7, "gap": 0.0})
	for index in range(blows.size()):
		var who: String = str(blows[index].get("target", ""))
		later(0.14 + 0.03 * float(index), land.bind([blows[index]], creature_point(who) + Vector3(0.0, 1.3, 0.0), BLOOD_HI))

func _heartsblood(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The ring beats, and every beat is a blow at a creature picked at random.
	var blows: Array = effects.filter(func(effect: Variant) -> bool: return _blow(effect))
	if blows.is_empty():
		return false
	var rest: Array = effects.filter(func(effect: Variant) -> bool: return not _blow(effect))
	var gap: float = DeepBattle.HIT_STEP * DeepBattle.hit_pace(blows)
	for index in range(blows.size()):
		later(gap * float(index), _beat.bind(blows[index], index))
	if not rest.is_empty():
		later(gap * float(blows.size()), land.bind(rest, origin, tone))
	return true

func _beat(blow: Dictionary, index: int) -> void:
	_beats.append(Time.get_ticks_msec())
	busy(float(BEAT_MS) / 1000.0 + 0.2)
	sound("die_drop", {"volume": 0.5, "pitch": 0.45 + 0.03 * float(index % 4), "gap": 0.0})
	var ring: Dictionary = _ring()
	land([blow], room_point(ring.centre, 2.2) if not ring.is_empty() else _origin, BLOOD_HI)

func _event(played: Dictionary) -> void:
	var kind: String = str(played.get("kind", ""))
	## Whatever the stone did has landed, watched or not (another player's page was up).
	if kind == "turn_begin" or (kind == "rail_end" and str(played.get("unit", "")) == str(unit.get("id", ""))):
		_holding = false
		if kind == "turn_begin":
			_tapped = false
		_show_growth()
		queue_redraw()
