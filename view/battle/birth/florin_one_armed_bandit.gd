extends "res://view/battle/birth_act.gd"
## Florin's One-Armed Bandit: the tray is the machine.
##
## His five dice sit in five reel windows. Every throw is a pull: the windows spin and stop
## left to right with a clack each, and a match chimes. A set's windows are framed in its
## color and joined by a win line that carries its prize's mark. The pay table stands over the
## tray, one row a number, each worth what the rail would bring it right now; the rows the
## hand would pay are lit with how many times they pay. When the stone fires, the winning
## windows flash, the prize's mark jumps out of its row and pays in the game's own look for it,
## on a bell for each time. Five of a kind strings cherry and topaz lights round the tray.
##
## The phone's table shows only the rows the hand would pay (two at the most), and his throw
## button is the lever on both layouts: it reads Pull and wears the lever's mark.

const TOPAZ := Color("f2b63c")
const CHERRY := Color("ec4a62")
const GLASS := Color(0.035, 0.04, 0.065, 0.95)
## The mark each prize is drawn with, and the line its tip says.
const PRIZE_MARKS: Dictionary = {"heal": "heart", "block": "shield", "poison": "drop", "gold": "coin", "damage": "sword"}
const PRIZE_WORDS: Dictionary = {"heal": "heal %s", "block": "gain %s Block", "poison": "poison the target for %s", "gold": "gain %s pyrite", "damage": "deal %s damage"}
## The reels stop one by one, this long apart, the first a moment after the dice land.
const STOP_LEAD: float = 0.04
const STOP_GAP: float = 0.085
const FLASH_MS: int = 520
const BULBS: int = 28
const BULB_SECONDS: float = 2.8

var _table: Control = null
var _prizes: Dictionary = {}
var _numbers: Array = []
## What the hand would pay: [{value, dice, times, kind, worth}], by the number matched.
var _wins: Array = []
var _spin_at: int = -1
var _stopped: int = 0
var _chime_due: bool = false
var _flash: Dictionary = {}
var _bulbs_at: int = -1
var _frame: StyleBoxFlat = null
var _panel: StyleBoxFlat = null

func _open() -> void:
	_prizes = DeepContent.birthstone_def(str(stone.get("character", "")), str(stone.get("variant", ""))).get("prizes", {})
	for key in _prizes:
		if str(key).is_valid_int():
			_numbers.append(int(str(key)))
	_numbers.sort()
	_frame = StyleBoxFlat.new()
	_frame.draw_center = false
	_frame.set_corner_radius_all(int(u(9.0, 4.0)))
	_panel = DeepUi.flat(Color(DeepUi.LEDGER_FILL, 0.95), TOPAZ.lerp(DeepUi.LEDGER_LINE, 0.45), int(u(6.0, 3.0)), 0, 2)
	_table = Control.new()
	_table.mouse_filter = Control.MOUSE_FILTER_PASS
	place(_table, "over_tray", 1.0)
	tip(_table, _prize_plate, {"tone": TOPAZ})

func _button_words() -> Dictionary:
	return {"reroll": "Pull", "reroll_icon": "lever"}

func _spin_extra() -> float:
	return STOP_LEAD + STOP_GAP * 4.0 + 0.05

# --- the pay table ------------------------------------------------------------------------------

func _prize(number: int) -> Dictionary:
	return _prizes.get(str(number), _prizes.get("other", {}))

func _mult(number: int) -> int:
	var prize: Dictionary = _prize(number)
	return maxi(1, number - int(prize.value_less)) if prize.has("value_less") else int(prize.get("mult", 1))

func _times(count: int) -> int:
	## How many times a set pays, by its size: the tiers' own amounts.
	var times: int = 0
	for def in defs:
		var trigger: Dictionary = def.get("trigger", {})
		var most: int = int(trigger.get("max", 0))
		if str(trigger.get("kind", "")) == "set" and count >= maxi(2, int(trigger.get("amount", 2))) and (most <= 0 or count <= most):
			for effect in def.get("effects", []):
				if str(effect.get("kind", "")) == "prize":
					times = maxi(times, int(effect.get("amount", 1)))
	return times

func _read_wins() -> Array:
	## The sets in the tray and what each would pay. Read off the forecast where it paid them
	## (it knows what a wild stood in for), else off the dice themselves.
	var out: Array = []
	if not settled:
		return out
	var paid_seen: bool = false
	for entry in tiers:
		if not entry is Dictionary or not bool(entry.get("active", false)):
			continue
		for effect in entry.get("effects", []):
			if str(effect.get("kind", "")) != "prize":
				continue
			paid_seen = true
			for paid in effect.get("paid", []):
				out.append({"value": int(paid.get("value", 0)), "dice": paid.get("dice", []), "times": int(paid.get("times", 1)), "kind": str(paid.get("prize", "damage")), "worth": int(paid.get("amount", 0))})
	if paid_seen:
		return out
	var groups: Dictionary = {}
	for roll in dice():
		if str(roll.get("kind", "plain")) in ["wild", "blank"]:
			continue
		var value: int = int(roll.get("value", 0))
		if not groups.has(value):
			groups[value] = []
		groups[value].append(str(roll.get("die_id", "")))
	var values: Array = groups.keys()
	values.sort()
	for value in values:
		var times: int = _times(groups[value].size())
		if times > 0:
			out.append({"value": int(value), "dice": groups[value], "times": times, "kind": str(_prize(int(value)).get("kind", "damage")), "worth": DeepRules.sat_mul(resonance_now(), _mult(int(value)))})
	return out

func _win_for(number: int) -> Dictionary:
	for win in _wins:
		if int(win.value) == number:
			return win
	return {}

func _shown_numbers() -> Array:
	## The rows the table draws: every number with a prize of its own on the desktop (and any
	## other number the hand has matched on), only the rows that would pay on the phone.
	var shown: Array = []
	if not DeepUi.phone:
		shown = _numbers.duplicate()
	for win in _wins:
		if not shown.has(int(win.value)) and (not DeepUi.phone or shown.size() < 2):
			shown.append(int(win.value))
	shown.sort()
	return shown

func _cell() -> Vector2:
	var tall: float = maxf(u(24.0, 15.0), float(DeepUi.min_text()) + u(8.0, 3.0))
	return Vector2(tall * 4.9, tall)

func _sync_act() -> void:
	_wins = _read_wins()
	var shown: int = _shown_numbers().size()
	var cell: Vector2 = _cell()
	var columns: int = shown if DeepUi.phone else 2
	var rows: int = 1 if DeepUi.phone else int(ceil(float(shown) / 2.0))
	var pad: float = u(6.0, 3.0)
	_table.visible = shown > 0 and not unit.get("hand", []).is_empty() and not bool(unit.get("downed", false))
	_table.custom_minimum_size = Vector2(float(columns) * cell.x + pad * 2.0, float(rows) * cell.y + pad * 2.0)
	_table.size = _table.custom_minimum_size
	## A match chimes once its reels have stopped.
	if _chime_due and settled:
		_chime_due = false
		if not _wins.is_empty() and planning and on_screen():
			sound("gleam", {"volume": 0.5, "pitch": 1.15 + 0.1 * float(_wins.size())})
			var until: int = Time.get_ticks_msec() + FLASH_MS
			for win in _wins:
				for id in win.dice:
					_flash[str(id)] = until
			busy(0.6)

func _look_key() -> String:
	return "%s|%d|%s" % [str(_wins), resonance_now(), str(_table.visible)]

func _prize_plate() -> Control:
	## The whole table in words, for a hover or a held finger.
	var box: VBoxContainer = Plates.plate()
	Plates.head(box, "Prizes", "one-armed bandit", TOPAZ)
	DeepUi.effect_text(box, "Every set of matching dice pays the Prize of its number: once for a pair, three times for three or four of a kind, seven times for all five.", 12, DeepUi.MUTED)
	var read: int = resonance_now()
	for number in _numbers:
		var prize: Dictionary = _prize(number)
		var kind: String = str(prize.get("kind", "damage"))
		var row := DeepUi.hbox(box, 8)
		row.add_child(DiceIcons.readable_face(18.0, number, TOPAZ, "D6", not _win_for(number).is_empty()))
		DeepUi.icon(row, str(PRIZE_MARKS.get(kind, "sword")), DeepUi.glyph_px(12, 2.0), _tone(kind))
		var worth: String = "Resonance" if _mult(number) == 1 else "%d× Resonance" % _mult(number)
		DeepUi.effect_text(row, "%s (%s now)" % [str(PRIZE_WORDS.get(kind, "%s")) % worth, DeepUi.number(DeepRules.sat_mul(read, _mult(number)))], 12, DeepUi.PAPER)
	if _prizes.has("other"):
		DeepUi.effect_text(box, "Any other number deals Resonance times its points over %d." % int(_prizes.other.get("value_less", 3)), 12, DeepUi.MUTED)
	return box

static func _tone(kind: String) -> Color:
	if kind == "gold":
		return DeepUi.ORE
	return DeepUi.EFFECT_KEYWORDS[kind].color if DeepUi.EFFECT_KEYWORDS.has(kind) else DeepUi.PAPER

# --- the reels -----------------------------------------------------------------------------------

func _thrown() -> void:
	_spin_at = Time.get_ticks_msec()
	_stopped = 0
	_chime_due = true
	_flash.clear()
	busy(SPIN + _spin_extra() + 0.5)
	if on_screen():
		sound("reel_lever", {"volume": 0.5})

func _stop_time(index: int) -> float:
	return SPIN + STOP_LEAD + STOP_GAP * float(index)

func _tick(_delta: float) -> void:
	if _spin_at < 0:
		return
	var count: int = dice().size()
	var elapsed: float = float(Time.get_ticks_msec() - _spin_at) / 1000.0
	while _stopped < count and elapsed >= _stop_time(_stopped):
		sound("reel_stop", {"volume": 0.4, "pitch": 0.92 + 0.06 * float(_stopped), "gap": 0.0})
		_stopped += 1
	if _stopped >= count and elapsed > _stop_time(count - 1) + 0.25:
		_spin_at = -1
		queue_redraw()

func _window(die_id: String) -> Rect2:
	var seat: Rect2 = die_rect(die_id)
	return seat.grow(-u(5.0, 1.5)) if seat.size.x > 0.0 else seat

func _win_tone(index: int) -> Color:
	return CHERRY if index % 2 == 0 else TOPAZ

func _draw() -> void:
	if unit.is_empty() or bool(unit.get("downed", false)):
		return
	var rolls: Array = dice()
	var now: int = Time.get_ticks_msec()
	## Which set each die is in, if any.
	var set_of: Dictionary = {}
	for index in range(_wins.size()):
		for id in _wins[index].dice:
			set_of[str(id)] = index
	for seat in range(rolls.size()):
		var id: String = str(rolls[seat].get("die_id", ""))
		var window: Rect2 = _window(id)
		if window.size.x <= 0.0:
			continue
		var spinning: bool = _spin_at >= 0 and float(now - _spin_at) / 1000.0 < _stop_time(seat)
		if spinning:
			_draw_reel(window, seat, now)
		var winning: bool = set_of.has(id) and not spinning
		var tone: Color = _win_tone(int(set_of[id])) if winning else Color(TOPAZ, 0.34)
		if winning:
			_frame.border_color = Color(tone, 0.22)
			_frame.set_border_width_all(int(u(7.0, 3.0)))
			draw_style_box(_frame, window.grow(u(3.0, 1.5)))
		_frame.border_color = tone
		_frame.set_border_width_all(int(u(3.0, 1.5)) if winning else int(u(2.0, 1.0)))
		draw_style_box(_frame, window)
		## A window that has just stopped, or whose set is being paid, flashes.
		var since_stop: float = float(now - _spin_at) / 1000.0 - _stop_time(seat) if _spin_at >= 0 else 1.0
		var lit: float = clampf(1.0 - since_stop / 0.16, 0.0, 1.0) if since_stop >= 0.0 else 0.0
		if _flash.has(id):
			lit = maxf(lit, clampf(float(int(_flash[id]) - now) / float(FLASH_MS), 0.0, 1.0))
		if lit > 0.0:
			draw_rect(window.grow(-u(2.0, 1.0)), Color(1.0, 0.95, 0.8, 0.5 * lit))
	_draw_win_lines(rolls)
	_draw_table()
	_draw_bulbs(now)

func _draw_reel(window: Rect2, seat: int, now: int) -> void:
	## A reel going round: the window's glass gone dark, and prize marks streaming down it.
	draw_rect(window.grow(-u(2.0, 1.0)), GLASS)
	var marks: Array = PRIZE_MARKS.values()
	var edge: float = window.size.x * 0.46
	var lane: float = window.size.y + edge
	var travel: float = float(now) * 0.001 * lane * 2.6 + float(seat) * 37.0
	for index in range(3):
		var down: float = fposmod(travel + lane * float(index) / 3.0, lane)
		var middle := Vector2(window.get_center().x, window.position.y - edge * 0.5 + down)
		var box := Rect2(middle - Vector2(edge, edge) * 0.5, Vector2(edge, edge))
		## Only what is inside the window shows, fading at its lips.
		var inside: float = clampf(minf(box.position.y - window.position.y, window.end.y - box.end.y) / (edge * 0.4) + 1.0, 0.0, 1.0)
		if inside <= 0.0:
			continue
		var kind: String = str(PRIZE_MARKS.keys()[(index + seat + int(travel / lane)) % marks.size()])
		draw_glyph(str(PRIZE_MARKS[kind]), box, Color(_tone(kind), 0.8 * inside))

func _draw_win_lines(rolls: Array) -> void:
	## Each set's win line: across the top of the windows from its first die to its last, a
	## tick down onto every die in it, and its prize's mark riding the middle of the line.
	if _spin_at >= 0:
		return
	var order: Dictionary = {}
	for seat in range(rolls.size()):
		order[str(rolls[seat].get("die_id", ""))] = seat
	for index in range(_wins.size()):
		var win: Dictionary = _wins[index]
		var tone: Color = _win_tone(index)
		var spots: Array = []
		for id in win.dice:
			var window: Rect2 = _window(str(id))
			if window.size.x > 0.0 and order.has(str(id)):
				spots.append(window)
		if spots.size() < 2:
			continue
		spots.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		var y: float = spots[0].position.y - u(5.0, 2.5) - u(5.0, 2.5) * float(index)
		var from := Vector2(spots[0].get_center().x, y)
		var to := Vector2(spots[spots.size() - 1].get_center().x, y)
		var thick: float = u(3.0, 1.5)
		draw_line(from, to, tone, thick, true)
		for window in spots:
			var foot := Vector2(window.get_center().x, window.position.y + u(2.0, 1.0))
			draw_line(Vector2(foot.x, y), foot, tone, thick, true)
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-thick * 1.6, 0.0), foot + Vector2(thick * 1.6, 0.0), foot + Vector2(0.0, thick * 2.2)]), tone)
		var edge: float = u(18.0, 9.0)
		var middle: Vector2 = (from + to) * 0.5
		draw_circle(middle, edge * 0.72, Color(DeepUi.LEDGER_FILL, 0.96))
		draw_arc(middle, edge * 0.72, 0.0, TAU, 24, tone, maxf(1.5, thick * 0.6), true)
		draw_glyph(str(PRIZE_MARKS.get(str(win.kind), "sword")), Rect2(middle - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), _tone(str(win.kind)))

func _row_rect(number: int) -> Rect2:
	## Where a number's row stands in the table, in this act's own space (an empty rect when
	## the table does not show it).
	var shown: Array = _shown_numbers()
	var at: int = shown.find(number)
	if at < 0 or _table == null or not _table.visible:
		return Rect2()
	var cell: Vector2 = _cell()
	var pad: float = u(6.0, 3.0)
	var rows: int = 1 if DeepUi.phone else int(ceil(float(shown.size()) / 2.0))
	var column: int = at if DeepUi.phone else at / rows
	var row: int = 0 if DeepUi.phone else at % rows
	return Rect2(_table.position + Vector2(pad + float(column) * cell.x, pad + float(row) * cell.y), cell)

func _draw_table() -> void:
	if _table == null or not _table.visible:
		return
	draw_style_box(_panel, Rect2(_table.position, _table.size))
	var read: int = resonance_now()
	var px: int = int(u(13.0, 11.0))
	for number in _shown_numbers():
		var row: Rect2 = _row_rect(number)
		var win: Dictionary = _win_for(number)
		var pays: bool = not win.is_empty()
		var kind: String = str(_prize(number).get("kind", "damage"))
		var tone: Color = _tone(kind)
		if pays:
			draw_rect(row.grow_individual(-u(1.0, 0.5), -u(1.0, 0.5), -u(1.0, 0.5), -u(1.0, 0.5)), Color(tone, 0.2))
			draw_rect(Rect2(row.position, Vector2(u(3.0, 1.5), row.size.y)).grow_individual(0.0, -u(2.0, 1.0), 0.0, -u(2.0, 1.0)), tone)
		var chip_edge: float = row.size.y - u(6.0, 3.0)
		var chip := Rect2(row.position + Vector2(u(7.0, 3.5), (row.size.y - chip_edge) * 0.5), Vector2(chip_edge, chip_edge))
		draw_rect(chip, TOPAZ if pays else Color(TOPAZ, 0.2))
		draw_rect(chip, TOPAZ if pays else Color(TOPAZ, 0.55), false, maxf(1.0, u(1.5, 0.75)))
		draw_words(str(number), chip.get_center(), px, Color("15181f") if pays else Color(TOPAZ, 0.9), true, true, not pays)
		var mark_edge: float = chip_edge * 0.86
		var mark := Rect2(Vector2(chip.end.x + u(6.0, 3.0), row.position.y + (row.size.y - mark_edge) * 0.5), Vector2(mark_edge, mark_edge))
		draw_glyph(str(PRIZE_MARKS.get(kind, "sword")), mark, tone if pays else Color(tone, 0.6))
		var worth: int = int(win.worth) if pays else DeepRules.sat_mul(read, _mult(number))
		draw_words(DeepUi.number(worth), Vector2(mark.end.x + u(6.0, 3.0), row.get_center().y), px, DeepUi.PAPER if pays else DeepUi.MUTED, false)
		if pays and int(win.times) > 1:
			var times: String = "×%d" % int(win.times)
			var wide: float = DeepUi.bold_font().get_string_size(times, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(px, DeepUi.min_text())).x
			draw_words(times, Vector2(row.end.x - wide - u(6.0, 3.0), row.get_center().y), px, TOPAZ, false)

func _draw_bulbs(now: int) -> void:
	## The Jackpot's lights, cherry and topaz, chasing round the tray.
	if _bulbs_at < 0:
		return
	var elapsed: float = float(now - _bulbs_at) / 1000.0
	if elapsed > BULB_SECONDS:
		_bulbs_at = -1
		return
	var around: Rect2 = tray_rect().grow(u(12.0, 5.0))
	var perimeter: float = (around.size.x + around.size.y) * 2.0
	var fade: float = clampf((BULB_SECONDS - elapsed) / 0.4, 0.0, 1.0)
	var chase: int = int(elapsed * 16.0)
	for index in range(BULBS):
		var along: float = perimeter * float(index) / float(BULBS)
		var at: Vector2 = around.position
		if along < around.size.x:
			at += Vector2(along, 0.0)
		elif along < around.size.x + around.size.y:
			at += Vector2(around.size.x, along - around.size.x)
		elif along < around.size.x * 2.0 + around.size.y:
			at += Vector2(around.size.x - (along - around.size.x - around.size.y), around.size.y)
		else:
			at += Vector2(0.0, around.size.y - (along - around.size.x * 2.0 - around.size.y))
		var tone: Color = CHERRY if index % 2 == 0 else TOPAZ
		var on: bool = (index + chase) % 3 == 0
		draw_circle(at, u(5.0, 2.5), Color(tone.darkened(0.55), 0.9 * fade))
		if on:
			draw_circle(at, u(9.0, 4.5), Color(tone, 0.28 * fade))
			draw_circle(at, u(4.2, 2.1), Color(tone.lightened(0.35), fade))

# --- paying --------------------------------------------------------------------------------------

func _tier(entry: Dictionary, effects: Array, origin: Vector3, tone: Color) -> bool:
	## The sets pay one after another: each set's windows flash, its prize's mark jumps out of
	## its row, and what it is worth lands the game's own way, a bell for each time it pays.
	var prizes: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "prize")
	if prizes.is_empty():
		return false
	var at: float = 0.0
	for effect in prizes:
		for paid in effect.get("paid", []):
			later(at, _pay.bind(paid, origin))
			at += 0.34 + DeepBattle.hits_span(paid.get("hits", []))
	var rest: Array = effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) != "prize")
	if not rest.is_empty():
		later(at, land.bind(rest, origin, tone))
	if int(_times(5)) > 0 and prizes.any(func(effect: Dictionary) -> bool: return effect.get("paid", []).any(func(paid: Dictionary) -> bool: return int(paid.get("count", 0)) >= 5)):
		_jackpot()
	return true

func _pay(paid: Dictionary, origin: Vector3) -> void:
	var kind: String = str(paid.get("prize", "damage"))
	var tone: Color = _tone(kind)
	var until: int = Time.get_ticks_msec() + FLASH_MS
	var middle := Vector2.ZERO
	var seen: int = 0
	for id in paid.get("dice", []):
		_flash[str(id)] = until
		var window: Rect2 = _window(str(id))
		if window.size.x > 0.0:
			middle += window.get_center()
			seen += 1
	busy(0.9)
	## The mark leaves its row of the table (or the middle of its set, where the table is put away).
	var row: Rect2 = _row_rect(int(paid.get("value", 0)))
	var from: Vector2 = row.get_center() if row.size.x > 0.0 else (middle / float(maxi(1, seen)) if seen > 0 else tray_rect().get_center())
	var to: Vector2 = ring_rect().get_center()
	var hits: Array = paid.get("hits", [])
	if kind in ["damage", "poison"] and not hits.is_empty():
		to = creature_at(str(hits[0].get("target", target_id())))
	elif kind == "gold" and screen._purse_spot() != null:
		to = local((screen._purse_spot() as Control).get_global_rect()).get_center()
	_jump(str(PRIZE_MARKS.get(kind, "sword")), tone, from, to)
	var times: int = maxi(1, int(paid.get("times", 1)))
	for bell in range(mini(times, 7)):
		later(0.085 * float(bell), sound.bind("tally_tick", {"volume": 0.55, "pitch": 1.0 + 0.11 * float(bell), "gap": 0.0}))
	later(0.2, land.bind(hits, room_point(from) if row.size.x > 0.0 else origin, tone))

func _jump(glyph: String, tone: Color, from: Vector2, to: Vector2) -> void:
	## A prize's mark jumping out of the table: it swells where it stood, then flies to what it pays.
	if DeepUi.headless():
		return
	var edge: float = u(30.0, 15.0)
	var mark: TextureRect = GemIcons.glyph(self, glyph, edge, tone)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.pivot_offset = Vector2(edge, edge) * 0.5
	mark.position = from - Vector2(edge, edge) * 0.5
	mark.scale = Vector2.ONE * 0.6
	var tween := mark.create_tween()
	tween.tween_property(mark, "scale", Vector2.ONE * 1.7, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mark, "position", to - Vector2(edge, edge) * 0.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mark, "scale", Vector2.ONE * 0.9, 0.22)
	tween.tween_property(mark, "modulate:a", 0.0, 0.08)
	tween.tween_callback(mark.queue_free)
	burst(from, tone, 10, 120.0, 0.4, 4.0)

func _jackpot() -> void:
	## Five of a kind: the lights chase round the tray, and the pyrite pours with the prizes.
	_bulbs_at = Time.get_ticks_msec()
	busy(BULB_SECONDS + 0.2)
	call_out("JACKPOT", TOPAZ, "Seven prizes", 1.6)
	sound("jackpot", {"volume": 0.9})
	if fx() != null and not DeepUi.headless():
		later(1.0, func() -> void: fx().coins(room_point(tray_rect().get_center(), 2.4), screen._purse(), 26))
