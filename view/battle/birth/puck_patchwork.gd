extends "res://view/battle/birth_act.gd"
## Puck's Patchwork: a strip of six patches, one a color, sewn in as gems of that color fire.
##
## Each patch is dark until a gem of its color fires on her rail this turn; then it is filled
## and stitched round. While the hand is planned the strip shows the colors the forecast says
## the rail would fire; once it resolves, each patch is sewn in as its color actually fires,
## with a tick in that color. Beside the patches stands the count, and under them a thin bar
## filled to it with a notch at each rung (3, 4 and 6 as content has them). From Quilt up each
## sewn patch carries its gift's mark: sword, shield, heart, drop, coin, spark.
##
## When the stone fires: Scraps throws a strip of each sewn color at the target, a hit a color;
## Quilt pays the patches left to right, each gift's mark leaving its patch for where it lands;
## Whole Cloth joins the six patches into one cloth that sweeps the dock like a curtain before
## the dice are thrown again.
##
## The desktop's strip stands just left of the Birthstone, above the dock (the stone's count
## plays over the stone itself); the phone's sits under the rail beside the Resonance number,
## its patches 11 pt.

const ORDER: Array = ["RED", "BLUE", "GREEN", "VIOLET", "GOLD", "WHITE"]
const GIFT_MARKS: Dictionary = {"RED": "sword", "BLUE": "shield", "GREEN": "heart", "VIOLET": "drop", "GOLD": "coin", "WHITE": "spark"}
const GIFT_WORDS: Dictionary = {"RED": "damage", "BLUE": "Block", "GREEN": "healing", "VIOLET": "Poison", "GOLD": "pyrite", "WHITE": "Charged"}
const INK := Color("15181f")
const SEW_MS: int = 520
const CLOTH_SECONDS: float = 1.15

var _strip: Control = null
## The stone's rungs, fewest colors first: [{name, need, text}].
var _rungs: Array = []
## The colors sewn now, in the strip's order, and when each was sewn this turn (for its flash).
var _sewn: Array = []
var _sewn_at: Dictionary = {}
## The rail of this turn has begun playing (sewn from the fight from then on, not the forecast),
## and the colors its gems were seen to fire so far.
var _rail_open: bool = false
var _fired_seen: Dictionary = {}
## Strips of color thrown at the target: [{from, to, at, seconds, tone}].
var _ribbons: Array = []
## Patches paying their gifts: {color: ms}.
var _paying: Dictionary = {}
var _cloth_at: int = -1
var _panel: StyleBoxFlat = null

func _open() -> void:
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip.visible = false
	if DeepUi.phone:
		add_child(_strip)
	else:
		## Just left of the Birthstone, above the dock: the stone's own count stands over it.
		place(_strip, "over_stone", 0.5, Vector2(-_strip_size().x * 0.5 - u(96.0), 0.0))
	tip(_strip, _plate, {"tone": tint.lightened(0.3)})

# --- measures --------------------------------------------------------------------------------------

func _edge() -> float:
	return u(22.0, 11.0)

func _gap() -> float:
	return u(5.0, 2.5)

func _pad() -> float:
	return u(6.0, 3.0)

func _count_wide() -> float:
	return maxf(u(28.0, 16.0), float(DeepUi.min_text()) * 1.3)

func _bar_tall() -> float:
	return u(4.0, 2.0)

func _strip_size() -> Vector2:
	var row: float = _edge() * 6.0 + _gap() * 5.0
	return Vector2(_pad() * 2.0 + row + _gap() + _count_wide(), _pad() * 2.0 + _edge() + _gap() + _bar_tall())

func _patch_rect(index: int) -> Rect2:
	## A patch's square in this act's own space.
	if _strip == null:
		return Rect2()
	return Rect2(_strip.position + Vector2(_pad() + float(index) * (_edge() + _gap()), _pad()), Vector2(_edge(), _edge()))

# --- reading the colors ------------------------------------------------------------------------------

func _read_rungs() -> void:
	var out: Array = []
	for def in defs:
		if def is Dictionary and str(def.get("trigger", {}).get("kind", "")) == "colors":
			out.append({"name": str(def.get("name", "")), "need": int(def.trigger.get("amount", 0)), "text": str(def.get("text", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.need) < int(b.need))
	_rungs = out

func _up() -> bool:
	return not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))

func _read_sewn() -> Array:
	## The colors sewn: the forecast's while the hand is planned, the fight's own once this
	## turn's rail has begun (nothing before it: last turn's colors are not this turn's).
	if not settled or not _up():
		return []
	var seen: Dictionary = {}
	var lists: Array = []
	if planning:
		lists = forecast().get("birthstone", {}).get("colors", [])
	elif _rail_open:
		lists = unit.get("fired_colors", [])
		for color in _fired_seen:
			seen[str(color)] = true
	for colors in lists:
		if not colors is Array:
			continue
		for color in colors:
			seen[str(color)] = true
	return ORDER.filter(func(color: String) -> bool: return seen.has(color))

func _sync_act() -> void:
	if _rungs.is_empty():
		_read_rungs()
	if planning and _rail_open:
		_rail_open = false
		_fired_seen.clear()
	_sew(_read_sewn())
	_strip.visible = _up()
	_strip.custom_minimum_size = _strip_size()
	_strip.size = _strip.custom_minimum_size
	_keep_beside_number()

func _sew(now_sewn: Array) -> void:
	## Takes the colors sewn now; a patch newly sewn while the rail plays flashes and ticks.
	if not planning and on_screen() and not DeepUi.headless():
		var step: int = 0
		for color in now_sewn:
			if not _sewn.has(color):
				_sewn_at[color] = Time.get_ticks_msec()
				sound("tick_" + str(color).to_lower(), {"volume": 0.5, "pitch": 1.0 + 0.06 * float(now_sewn.size() + step), "gap": 0.0})
				step += 1
				busy(float(SEW_MS) / 1000.0 + 0.1)
	_sewn = now_sewn

func _tick(_delta: float) -> void:
	_keep_beside_number()

func _keep_beside_number() -> void:
	## The phone's strip keeps beside the Resonance number, clear of it, as the dock moves.
	if not DeepUi.phone or _strip == null:
		return
	var number: Rect2 = resonance_rect()
	if number.size.x <= 0.0:
		return
	var wide: Vector2 = _strip_size()
	var at := Vector2(number.end.x + u(12.0, 8.0), number.get_center().y - wide.y * 0.5)
	at.x = minf(at.x, size.x - DeepUi.safe_right - wide.x)
	at.y = minf(at.y, size.y - DeepUi.safe_bottom - wide.y)
	if not _strip.position.is_equal_approx(at):
		_strip.position = at

func _event(played: Dictionary) -> void:
	if unit.is_empty() or str(played.get("unit", "")) != str(unit.get("id", "")):
		return
	match str(played.get("kind", "")):
		"rail_begin":
			_rail_open = true
			_fired_seen.clear()
			_sew([])
		"gem_fire":
			## The gem's own colors, sewn the moment it fires (the fight's count follows).
			var socket: int = int(played.get("socket", -1))
			var rail: Array = unit.get("rail", [])
			if socket >= 0 and socket < rail.size() and rail[socket] is Dictionary:
				var sockets: Array = unit.get("sockets", [])
				for color in DeepStone.colors(rail[socket], str(sockets[socket]) if socket < sockets.size() else ""):
					if ORDER.has(str(color)):
						_fired_seen[str(color)] = true
			_rail_open = true
			_sew(_read_sewn())
			queue_redraw()

func _rung_reached() -> Dictionary:
	var reached: Dictionary = {}
	for rung in _rungs:
		if _sewn.size() >= int(rung.need):
			reached = rung
	return reached

func _gifts_shown() -> bool:
	## From the second rung (Quilt) up, each sewn patch shows its gift.
	return _rungs.size() >= 2 and _sewn.size() >= int(_rungs[1].need)

func _look_key() -> String:
	return "%s|%s|%s|%s" % [str(_sewn), str(_strip.visible), str(_strip.position), str(settled)]

func _plate() -> Control:
	## The strip in words, for a hover or a held finger: the colors sewn and the rungs.
	var box: VBoxContainer = Plates.plate()
	Plates.head(box, "%d of 6 colors" % _sewn.size(), "patchwork", tint.lightened(0.4))
	var named: Array = _sewn.map(func(color: String) -> String: return str(DeepContent.color(color).get("name", color.capitalize())))
	DeepUi.effect_text(box, ("Fired this turn: %s." % ", ".join(named)) if not named.is_empty() else "No color has fired yet this turn.", 12, DeepUi.MUTED)
	var reached: Dictionary = _rung_reached()
	for index in range(_rungs.size() - 1, -1, -1):
		var rung: Dictionary = _rungs[index]
		var on: bool = str(reached.get("name", "")) == str(rung.name) or (not reached.is_empty() and int(rung.need) <= int(reached.need))
		DeepUi.effect_text(box, "%s. %s" % [str(rung.name), str(rung.text)], 12, DeepUi.PAPER if on else DeepUi.MUTED, str(reached.get("name", "")) == str(rung.name))
	return box

# --- drawing --------------------------------------------------------------------------------------------

static func _rung_tone(index: int) -> Color:
	return [Color("f3a6cc"), Color("8fdcf2"), Color("fff4c8")][clampi(index, 0, 2)]

func _stitch(box: Rect2, tone: Color, width: float) -> void:
	## A running stitch round a patch: short dashes with gaps.
	var dash: float = maxf(2.0, box.size.x / 7.0)
	var corners: Array = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for side in range(4):
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % 4]
		var length: float = from.distance_to(to)
		var along: float = dash * 0.5
		while along < length:
			draw_line(from.lerp(to, along / length), from.lerp(to, minf(along + dash, length) / length), tone, width, true)
			along += dash * 2.0

func _draw_patch(box: Rect2, color: String, sewn: bool, gift: bool, flash: float) -> void:
	var hue: Color = DeepUi.color(color)
	var swell: float = 1.0 + 0.3 * flash
	box = Rect2(box.get_center() - box.size * swell * 0.5, box.size * swell)
	if sewn:
		draw_rect(box, hue)
		_stitch(box.grow(-maxf(1.5, box.size.x * 0.12)), hue.lightened(0.6) if hue.get_luminance() < 0.6 else hue.darkened(0.5), maxf(1.0, u(1.6, 0.8)))
		if gift:
			var ink: Color = INK if hue.get_luminance() > 0.45 else Color("f4f7fb")
			draw_glyph(str(GIFT_MARKS.get(color, "spark")), box.grow(-box.size.x * 0.2), ink)
	else:
		draw_rect(box, Color(hue.darkened(0.72), 0.9))
		draw_rect(box, Color(hue, 0.45), false, maxf(1.0, u(1.4, 0.7)))
	if flash > 0.0:
		draw_rect(box.grow(u(3.0, 1.5) * flash), Color(1.0, 1.0, 1.0, 0.55 * flash), false, u(3.0, 1.5))

func _draw() -> void:
	if unit.is_empty() or not _up() or _strip == null or not _strip.visible:
		return
	var now: int = Time.get_ticks_msec()
	var cloth: float = float(now - _cloth_at) / 1000.0 if _cloth_at >= 0 else -1.0
	if cloth >= CLOTH_SECONDS:
		_cloth_at = -1
		cloth = -1.0
	if _panel == null:
		_panel = DeepUi.flat(Color(DeepUi.LEDGER_FILL, 0.94), tint.lerp(DeepUi.LEDGER_LINE, 0.4), int(u(6.0, 3.0)), 0, 2)
	draw_style_box(_panel, Rect2(_strip.position, _strip.size))
	var gifts: bool = _gifts_shown()
	for index in range(ORDER.size()):
		var color: String = ORDER[index]
		var sewn: bool = _sewn.has(color)
		var flash: float = 0.0
		if _sewn_at.has(color):
			flash = 1.0 - float(now - int(_sewn_at[color])) / float(SEW_MS)
			if flash <= 0.0:
				_sewn_at.erase(color)
				flash = 0.0
		if _paying.has(color):
			var paid: float = 1.0 - float(now - int(_paying[color])) / float(SEW_MS)
			if paid <= 0.0:
				_paying.erase(color)
			flash = maxf(flash, paid)
		## While the cloth is made, the sewn patches have left the strip for it.
		if cloth >= 0.0 and sewn:
			_draw_patch(_patch_rect(index), color, false, false, 0.0)
			continue
		_draw_patch(_patch_rect(index), color, sewn, gifts and sewn, flash)
	_draw_count()
	_draw_ribbons(now)
	if cloth >= 0.0:
		_draw_cloth(cloth)

func _draw_count() -> void:
	## The count beside the patches, in its rung's color, and the bar under them with a notch at
	## each rung.
	var reached: int = -1
	for index in range(_rungs.size()):
		if _sewn.size() >= int(_rungs[index].need):
			reached = index
	var tone: Color = _rung_tone(reached) if reached >= 0 else DeepUi.MUTED
	var row: Rect2 = Rect2(_patch_rect(0).position, Vector2(_edge() * 6.0 + _gap() * 5.0, _edge()))
	draw_words(str(_sewn.size()), Vector2(row.end.x + _gap() + _count_wide() * 0.5, row.get_center().y), text_px(18, 11), tone)
	var bar := Rect2(Vector2(row.position.x, row.end.y + _gap()), Vector2(row.size.x, _bar_tall()))
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55))
	if not _sewn.is_empty():
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(_sewn.size()) / 6.0, bar.size.y)), tone)
	for index in range(_rungs.size()):
		var x: float = bar.position.x + bar.size.x * float(int(_rungs[index].need)) / 6.0
		x = minf(x, bar.end.x - 1.0)
		var on: bool = _sewn.size() >= int(_rungs[index].need)
		draw_line(Vector2(x, bar.position.y - u(3.0, 1.5)), Vector2(x, bar.end.y + u(2.0, 1.0)), _rung_tone(index) if on else Color(DeepUi.PAPER, 0.45), maxf(1.5, u(2.0, 1.0)), true)

func _draw_ribbons(now: int) -> void:
	## Strips of cloth flying at the target, rippling as they go.
	for index in range(_ribbons.size() - 1, -1, -1):
		var ribbon: Dictionary = _ribbons[index]
		var t: float = (float(now - int(ribbon.at)) / 1000.0) / float(ribbon.seconds)
		if t < 0.0:
			continue
		if t >= 1.15:
			_ribbons.remove_at(index)
			continue
		var from: Vector2 = ribbon.from
		var to: Vector2 = ribbon.to
		var bend: Vector2 = (from + to) * 0.5 + Vector2(0.0, -u(70.0, 30.0))
		var points := PackedVector2Array()
		var head: float = clampf(t, 0.0, 1.0)
		var tail: float = clampf(t - 0.32, 0.0, 1.0)
		for step in range(9):
			var s: float = lerpf(tail, head, float(step) / 8.0)
			var at: Vector2 = from.lerp(bend, s).lerp(bend.lerp(to, s), s)
			var ahead: Vector2 = (bend.lerp(to, s) - from.lerp(bend, s)).normalized()
			at += Vector2(-ahead.y, ahead.x) * sin(s * 18.0 + float(now) * 0.02) * u(5.0, 2.5)
			points.append(at)
		var fade: float = clampf((1.15 - t) / 0.2, 0.0, 1.0)
		draw_polyline(points, Color(ribbon.tone, fade), u(7.0, 3.5), true)
		draw_polyline(points, Color(Color(ribbon.tone).lightened(0.5), 0.6 * fade), maxf(1.0, u(1.5, 0.75)), true)

func _draw_cloth(t: float) -> void:
	## The six patches fly to the dock's left edge and join into one cloth of six bands, which
	## then sweeps across the dock like a curtain drawn and on out of it.
	var dock: Rect2 = dock_rect()
	if dock.size.x <= 0.0:
		return
	var gather: float = 0.3
	if t < gather:
		var s: float = ease(t / gather, 0.5)
		for index in range(ORDER.size()):
			var from: Rect2 = _patch_rect(index)
			var band_tall: float = dock.size.y / 6.0
			var to := Rect2(Vector2(dock.position.x, dock.position.y + band_tall * float(index)), Vector2(u(30.0, 14.0), band_tall))
			var box := Rect2(from.position.lerp(to.position, s), from.size.lerp(to.size, s))
			draw_rect(box, DeepUi.color(str(ORDER[index])))
		return
	var s2: float = ease((t - gather) / (CLOTH_SECONDS - gather), 0.7)
	var wide: float = dock.size.x * 0.7
	var lead: float = dock.position.x + u(30.0, 14.0) + (dock.size.x + wide) * s2
	var left: float = maxf(dock.position.x, lead - wide)
	var right: float = minf(dock.end.x, lead)
	if right <= left:
		return
	var tall: float = dock.size.y / 6.0
	for index in range(ORDER.size()):
		var band := Rect2(Vector2(left, dock.position.y + tall * float(index)), Vector2(right - left, tall))
		draw_rect(band, Color(DeepUi.color(str(ORDER[index])), 0.96))
		if index > 0:
			var seam_y: float = band.position.y
			var x: float = left
			while x < right:
				draw_line(Vector2(x, seam_y), Vector2(minf(x + u(8.0, 4.0), right), seam_y), Color(1.0, 1.0, 1.0, 0.7), maxf(1.0, u(2.0, 1.0)), true)
				x += u(16.0, 8.0)
	## The leading edge, a stitched hem.
	if lead <= dock.end.x:
		draw_line(Vector2(lead, dock.position.y), Vector2(lead, dock.end.y), Color(1.0, 1.0, 1.0, 0.85), u(4.0, 2.0), true)

# --- firing ----------------------------------------------------------------------------------------------

func _tier(_entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	var kinds: Array = effects.map(func(effect: Dictionary) -> String: return str(effect.get("kind", "")))
	if kinds.has("second_act"):
		return _whole_cloth(effects, origin, tone)
	if kinds.has("quilt"):
		return _quilt(effects, origin, tone)
	if kinds.has("damage"):
		return _scraps(effects, origin, tone)
	return false

func _from_color(color: String) -> Vector2:
	var at: int = ORDER.find(color)
	var box: Rect2 = _patch_rect(maxi(0, at))
	return box.get_center() if box.size.x > 0.0 else stone_rect().get_center()

func _scraps(effects: Array, origin: Vector3, tone: Color) -> bool:
	## A strip of each sewn color thrown at the target, one hit each.
	var hits: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "damage")
	var colors: Array = _sewn.duplicate() if not _sewn.is_empty() else ORDER.duplicate()
	for index in range(hits.size()):
		later(DeepBattle.BOLT_GAP * float(index), _throw_strip.bind(str(colors[index % colors.size()]), hits[index], index))
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "damage")
	if not rest.is_empty():
		later(DeepBattle.BOLT_GAP * float(hits.size()), land.bind(rest, origin, tone))
	return true

func _throw_strip(color: String, hit: Dictionary, index: int) -> void:
	var from: Vector2 = _from_color(color)
	var hue: Color = DeepUi.color(color)
	_paying[color] = Time.get_ticks_msec()
	if not DeepUi.headless():
		_ribbons.append({"from": from, "to": creature_at(str(hit.get("target", target_id()))), "at": Time.get_ticks_msec(), "seconds": 0.3, "tone": hue})
		busy(0.7)
	sound("tick_" + color.to_lower(), {"volume": 0.5, "pitch": 1.0 + 0.07 * float(index), "gap": 0.0})
	later(0.1, land.bind([hit], room_point(from), hue))

func _quilt(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The patches pay left to right, each gift's mark leaving its patch for where it lands.
	var at: float = 0.0
	for effect in effects:
		if str(effect.get("kind", "")) != "quilt":
			continue
		if bool(effect.get("nothing", false)):
			continue
		for hit in effect.get("hits", []):
			later(at, _gift.bind(hit))
			at += 0.24
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "quilt")
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	return true

func _gift(hit: Dictionary) -> void:
	var color: String = str(hit.get("color", "WHITE"))
	var from: Vector2 = _from_color(color)
	var hue: Color = DeepUi.color(color)
	_paying[color] = Time.get_ticks_msec()
	busy(0.7)
	var kind: String = str(hit.get("kind", ""))
	var to: Vector2 = ring_rect().get_center()
	if kind in ["damage", "poison"]:
		to = creature_at(str(hit.get("target", target_id())))
	elif kind == "gold" and screen != null and screen._purse_spot() != null:
		to = local((screen._purse_spot() as Control).get_global_rect()).get_center()
	_jump(str(GIFT_MARKS.get(color, "spark")), hue, from, to)
	sound("tick_" + color.to_lower(), {"volume": 0.6, "pitch": 1.0 + 0.08 * float(ORDER.find(color)), "gap": 0.0})
	later(0.16, land.bind([hit], room_point(from), hue))

func _jump(glyph: String, tone: Color, from: Vector2, to: Vector2) -> void:
	## A gift's mark leaving its patch: it swells where it stood, then flies to what it pays.
	if DeepUi.headless():
		return
	var edge: float = u(28.0, 14.0)
	var mark: TextureRect = GemIcons.glyph(self, glyph, edge, tone)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.pivot_offset = Vector2(edge, edge) * 0.5
	mark.position = from - Vector2(edge, edge) * 0.5
	mark.scale = Vector2.ONE * 0.6
	var tween := mark.create_tween()
	tween.tween_property(mark, "scale", Vector2.ONE * 1.6, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mark, "position", to - Vector2(edge, edge) * 0.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mark, "scale", Vector2.ONE * 0.9, 0.22)
	tween.tween_property(mark, "modulate:a", 0.0, 0.08)
	tween.tween_callback(mark.queue_free)
	burst(from, tone, 8, 110.0, 0.4, 4.0)

func _whole_cloth(effects: Array, origin: Vector3, tone: Color) -> bool:
	## The six patches join into one cloth that sweeps the dock; the dice are thrown again and
	## the rail lights from its first socket as events of their own.
	var acts: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "second_act")
	if acts.all(func(effect: Dictionary) -> bool: return bool(effect.get("nothing", false))):
		return false
	_cloth_at = Time.get_ticks_msec()
	busy(CLOTH_SECONDS + 0.2)
	sound("chisel", {"volume": 0.5, "pitch": 1.3})
	later(0.3, sound.bind("dice_reroll", {"volume": 0.8}))
	later(0.3, land.bind(effects, origin, tone))
	return true
