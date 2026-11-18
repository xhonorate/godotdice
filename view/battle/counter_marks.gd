class_name CounterMarks
extends RefCounted
## What a merchant's counter says about each stone without a click (owner's review page
## "Merchant counter marks", db `shop1`, November 18, 2026):
##
## - A grade row under every stone's name, drawn the way a vault tile draws it: the carat on a
##   dark plate, the Cut as five gold bars, the Clarity as violet dots for what is frozen inside
##   (one to three), a ring for Clear, a pale sparkle for Pristine, a bright one for Flawless.
##   A green arrow beside the carat when the stone outweighs every gem set on the buyer's rail.
## - Pills over a stone that stands apart, at most two (`pills`): Void, then Flawless or
##   Intricate, then Perfect cut, then Heavy (the most this mine gives at this depth). A lucky
##   find still rolls (DeepDescent._lucky_find) but is never named: it shows by what it is.
## - In the hover and tap card, the grade as three short ladders (`Ladders`) over the pills.

const GemIcons = preload("res://view/gems/gem_icons.gd")

## The vault tile's own tones (StoneCard.TileTags).
const CUT_TONE := Color("ffd76a")
const INCLUDED := Color("c58bff")
const SPARKLE := Color("9fe8ff")
const ARROW := Color("6fe3b0")
## The size the plates are drawn for: a plate on text of another size scales with it.
const BASE_PX := 14.0

const ORDER: Array = ["VOID", "FLAWLESS", "INTRICATE", "PERFECT", "HEAVY"]
const WORDS: Dictionary = {"VOID": "Void", "FLAWLESS": "Flawless", "INTRICATE": "Intricate", "PERFECT": "Perfect cut", "HEAVY": "Heavy"}
const MARKS: Dictionary = {"VOID": "ring", "FLAWLESS": "star", "INTRICATE": "dots", "PERFECT": "cut", "HEAVY": "carat"}

static func tone(key: String) -> Color:
	match key:
		"VOID": return DeepUi.VOID
		"FLAWLESS": return DeepUi.tier_color("PEERLESS")
		"INTRICATE": return INCLUDED
		## Perfect cut wears the Pristine sparkle's pale blue (owner, card P3), not gold.
		"PERFECT": return SPARKLE
	return DeepUi.PAPER

static func pills(stone: Dictionary, cap: int) -> Array:
	## The pills a stall stone wears, in order, at most two. `cap` is the heaviest a stone comes
	## out of this mine at this depth (`DeepForge.carat_cap`), 0 when not known.
	if stone.is_empty() or not bool(stone.get("appraised", false)):
		return []
	var out: Array = []
	if DeepStone.is_slotless(stone):
		out.append("VOID")
	var clarity: int = int(stone.get("clarity", DeepContent.clear_index()))
	if clarity >= DeepContent.clarities().size() - 1:
		out.append("FLAWLESS")
	elif clarity <= 0:
		out.append("INTRICATE")
	if int(stone.get("cut", 0)) >= DeepContent.cuts().size() - 1:
		out.append("PERFECT")
	if cap > 0 and int(stone.get("carat", 1)) >= cap:
		out.append("HEAVY")
	return out.slice(0, 2)

static func shimmer_tone(keys: Array) -> Variant:
	## A stone with a pill shimmers in its first pill's tone (owner, card L2: every stone with a
	## pill). A Void has its own look (the Hollow), so it lends no shimmer; null for none.
	for key in keys:
		if str(key) != "VOID":
			return tone(str(key))
	return null

static func heaviest_on_rail(unit: Dictionary) -> int:
	## The heaviest gem set on a player's rail (riders too, never the Birthstone); 0 for none.
	var most: int = 0
	for stone in DeepStone.rail_stones(unit):
		if stone is Dictionary and not DeepStone.is_birthstone(stone) and not DeepStone.is_geode(stone):
			most = maxi(most, int(stone.get("carat", 1)))
	return most

static func outweighs(stone: Dictionary, heaviest: int) -> bool:
	return heaviest > 0 and int(stone.get("carat", 1)) > heaviest

static func pill_label(parent: Node, key: String, size: int = 13) -> Label:
	## A pill as a control, for a card: its word on its own capsule.
	var px: int = DeepUi.readable(size)
	var l := Label.new()
	l.text = str(WORDS.get(key, key))
	l.add_theme_font_override("font", DeepUi.bold_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", tone(key).lightened(0.25))
	l.add_theme_stylebox_override("normal", PillPlate.new(key, float(px) / BASE_PX))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l

static func draw_star(ci: RID, middle: Vector2, reach: float, color: Color) -> void:
	## The vault's four-pointed sparkle.
	var star := PackedVector2Array()
	for point in range(8):
		var angle: float = TAU * float(point) / 8.0 - PI * 0.5
		star.append(middle + Vector2(cos(angle), sin(angle)) * (reach if point % 2 == 0 else reach * 0.28))
	RenderingServer.canvas_item_add_polygon(ci, star, PackedColorArray([color]))

static func draw_clarity(ci: RID, middle: Vector2, k: float, clarity: int) -> float:
	## The Clarity mark centred on `middle`; returns its width.
	var clear: int = DeepContent.clear_index()
	if clarity < clear:
		var count: int = clear - clarity
		var step: float = 6.5 * k
		var left: float = middle.x - step * float(count - 1) * 0.5
		for index in range(count):
			RenderingServer.canvas_item_add_circle(ci, Vector2(left + step * float(index), middle.y), 2.5 * k, INCLUDED)
		return step * float(count - 1) + 5.0 * k
	if clarity == clear:
		var ring := PackedVector2Array()
		for point in range(17):
			ring.append(middle + Vector2.from_angle(TAU * float(point) / 16.0) * 2.8 * k)
		RenderingServer.canvas_item_add_polyline(ci, ring, PackedColorArray([Color(1, 1, 1, 0.55)]), 1.3 * k, true)
		return 7.0 * k
	var flawless: bool = clarity >= DeepContent.clarities().size() - 1
	var reach: float = (5.5 if flawless else 4.2) * k
	if flawless:
		RenderingServer.canvas_item_add_circle(ci, middle, reach * 1.25, Color(SPARKLE, 0.22))
	draw_star(ci, middle, reach, SPARKLE if flawless else SPARKLE.lerp(Color.WHITE, 0.4))
	return reach * 2.0

static func clarity_width(clarity: int, k: float) -> float:
	var clear: int = DeepContent.clear_index()
	if clarity < clear:
		return 6.5 * k * float(clear - clarity - 1) + 5.0 * k
	if clarity == clear:
		return 7.0 * k
	return (11.0 if clarity >= DeepContent.clarities().size() - 1 else 8.4) * k

class PillPlate extends StyleBox:
	## A pill's capsule: filled with its tone's dark, edged in the tone, its mark in the left
	## margin (Void's ring, a sparkle, three dots, or the Cut or carat glyph).
	var _plate: StyleBoxFlat
	var _tone: Color
	var _mark: String
	var _k: float

	func _init(key: String, k: float = 1.0) -> void:
		_tone = CounterMarks.tone(key)
		_mark = str(CounterMarks.MARKS.get(key, "star"))
		_k = k
		_plate = StyleBoxFlat.new()
		_plate.bg_color = Color(_tone.darkened(0.8), 0.94)
		_plate.border_color = Color(_tone, 0.95)
		_plate.set_border_width_all(maxi(2, int(round(2.0 * k))))
		_plate.set_corner_radius_all(int(40.0 * k))
		content_margin_left = (9.0 + _mark_width() + 5.0) * k
		content_margin_right = 11.0 * k
		content_margin_top = 1.0 * k
		content_margin_bottom = 2.0 * k

	func _mark_width() -> float:
		return 15.0 if _mark == "dots" else 12.0

	func _draw(ci: RID, rect: Rect2) -> void:
		_plate.draw(ci, rect)
		var middle := Vector2(rect.position.x + (9.0 + _mark_width() * 0.5) * _k, rect.position.y + rect.size.y * 0.5)
		var ink: Color = _tone.lightened(0.3)
		var reach: float = 6.0 * _k
		match _mark:
			"ring":
				RenderingServer.canvas_item_add_circle(ci, middle, reach, ink)
				RenderingServer.canvas_item_add_circle(ci, middle, reach * 0.55, _plate.bg_color)
			"star":
				CounterMarks.draw_star(ci, middle, reach * 1.15, ink)
			"dots":
				for index in range(3):
					RenderingServer.canvas_item_add_circle(ci, middle + Vector2((float(index) - 1.0) * 5.2 * _k, 0), 2.3 * _k, ink)
			_:
				var edge: float = reach * 2.1
				var art: Texture2D = CounterMarks.GemIcons.texture(_mark, 48)
				RenderingServer.canvas_item_add_texture_rect(ci, Rect2(middle - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), art.get_rid(), false, ink)

class GradePlate extends StyleBox:
	## The grade row under a stall stone's name: a dark strip; the carat (the label's own text)
	## on a darker plate, a green arrow after it when the stone outweighs the buyer's rail, the
	## Cut's five bars and the Clarity mark in the right margin.
	var cut: int = 0
	var clarity: int = 3
	var up: bool = false
	var _k: float

	func _init(stone: Dictionary, k: float = 1.0) -> void:
		cut = int(stone.get("cut", 0))
		clarity = int(stone.get("clarity", DeepContent.clear_index()))
		_k = k
		content_margin_left = 9.0 * k
		content_margin_top = 2.0 * k
		content_margin_bottom = 3.0 * k
		_fit()

	func set_up(on: bool) -> bool:
		## Whether the arrow shows; true when that changed (the label must be laid out again).
		if up == on:
			return false
		up = on
		_fit()
		emit_changed()
		return true

	func _arrow_width() -> float:
		return 10.0 * _k if up else 0.0

	func _bars_width() -> float:
		return float(DeepContent.cuts().size()) * (_bar().x + 2.0 * _k) - 2.0 * _k

	func _bar() -> Vector2:
		return Vector2(8.0, 3.6) * _k

	func _fit() -> void:
		content_margin_right = (6.0 * _k + _arrow_width()) + 7.0 * _k + _bars_width() + 7.0 * _k + CounterMarks.clarity_width(clarity, _k) + 7.0 * _k

	func _draw(ci: RID, rect: Rect2) -> void:
		var strip := StyleBoxFlat.new()
		strip.bg_color = Color(0.02, 0.03, 0.05, 0.78)
		strip.set_corner_radius_all(int(5.0 * _k))
		strip.draw(ci, rect)
		var mid: float = rect.position.y + rect.size.y * 0.5
		var text_end: float = rect.end.x - content_margin_right
		var carat := Rect2(Vector2(rect.position.x + 4.0 * _k, rect.position.y + 2.5 * _k), Vector2(text_end - rect.position.x + 1.0 * _k, rect.size.y - 5.0 * _k))
		RenderingServer.canvas_item_add_rect(ci, carat, Color(0, 0, 0, 0.62))
		var x: float = text_end + 6.0 * _k
		if up:
			var h: float = 7.0 * _k
			RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(x + 4.0 * _k, mid - h * 0.6), Vector2(x + 8.5 * _k, mid + h * 0.45), Vector2(x - 0.5 * _k, mid + h * 0.45)]), PackedColorArray([CounterMarks.ARROW]))
			x += _arrow_width()
		x += 7.0 * _k
		var bar: Vector2 = _bar()
		for index in range(DeepContent.cuts().size()):
			RenderingServer.canvas_item_add_rect(ci, Rect2(Vector2(x, mid - bar.y * 0.5), bar), CounterMarks.CUT_TONE if index <= cut else Color(1, 1, 1, 0.18))
			x += bar.x + 2.0 * _k
		x += 5.0 * _k
		CounterMarks.draw_clarity(ci, Vector2(x + CounterMarks.clarity_width(clarity, _k) * 0.5, mid), _k, clarity)

class Ladders extends Control:
	## The hover and tap card's grade (card X1): Carat, Cut and Clarity each as a short ladder
	## with its word, the stone's rung lit. Carat runs to this depth's cap (or the most a stone
	## weighs, with none known); Clarity is one ladder with Clear marked in the middle, so its two
	## good ends (Intricate, Flawless) both read as ends.
	var stone: Dictionary
	var cap: int
	var px: int
	var _width: float

	func _init(new_stone: Dictionary, new_cap: int, size: int, width: float) -> void:
		stone = new_stone
		cap = new_cap if new_cap > 0 else DeepStone.carat_max()
		px = DeepUi.readable(size)
		_width = width
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(width, _row_h() * (1.0 if DeepUi.phone else 3.0))

	func _row_h() -> float:
		return float(px) * 1.6

	func _draw() -> void:
		if DeepUi.phone:
			_draw_line()
			return
		var font: Font = DeepUi.bold_font()
		var head_w: float = font.get_string_size("Clarity", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + float(px) * 0.8
		var word_w: float = font.get_string_size("Intricate", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + float(px) * 0.6
		var left: float = head_w
		var right: float = size.x - word_w
		var bar_h: float = maxf(5.0, float(px) * 0.42)
		var carat: int = int(stone.get("carat", 1))
		var cut: int = int(stone.get("cut", 0))
		var clear: int = DeepContent.clear_index()
		var clarity: int = int(stone.get("clarity", clear))
		var rungs: int = DeepContent.clarities().size()
		var clarity_tone: Color = _clarity_tone(clarity)
		var rows: Array = [["Carat", "%d ct" % carat, DeepUi.PAPER], ["Cut", DeepContent.cut_name(cut), CounterMarks.CUT_TONE if cut >= DeepContent.cuts().size() - 1 else DeepUi.PAPER],
			["Clarity", DeepContent.clarity_name(clarity), clarity_tone]]
		for index in range(3):
			var mid: float = _row_h() * (float(index) + 0.5)
			var base: float = mid + float(px) * 0.36
			draw_string(font, Vector2(0, base), str(rows[index][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, DeepUi.MUTED)
			draw_string(font, Vector2(right + float(px) * 0.6, base), str(rows[index][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(rows[index][2]))
			var span: float = right - left
			var y: float = mid - bar_h * 0.5
			match index:
				0:
					draw_rect(Rect2(Vector2(left, y), Vector2(span, bar_h)), Color(1, 1, 1, 0.14))
					draw_rect(Rect2(Vector2(left, y), Vector2(span * clampf(float(carat) / float(cap), 0.04, 1.0), bar_h)), DeepUi.PAPER)
				1:
					_segments(left, y, span, bar_h, DeepContent.cuts().size(), func(k: int) -> Color: return CounterMarks.CUT_TONE if k <= cut else Color(1, 1, 1, 0.14), -1)
				2:
					_segments(left, y, span, bar_h, rungs, func(k: int) -> Color: return clarity_tone if k == clarity else Color(1, 1, 1, 0.14), clear)

	const SPARKLE_TONE := Color("9fe8ff")

	func _clarity_tone(clarity: int) -> Color:
		var clear: int = DeepContent.clear_index()
		if clarity >= DeepContent.clarities().size() - 1:
			return DeepUi.tier_color("PEERLESS")
		if clarity > clear:
			return SPARKLE_TONE
		return DeepUi.PAPER if clarity == clear else CounterMarks.INCLUDED

	func _draw_line() -> void:
		## The phone's card is short of height: the three ladders on one line, each with its
		## word after it ("5 ct", five Cut bars "Fair", six Clarity rungs "Intricate").
		var font: Font = DeepUi.bold_font()
		var mid: float = size.y * 0.5
		var base: float = mid + float(px) * 0.36
		var bar_h: float = maxf(5.0, float(px) * 0.4)
		var gap: float = float(px) * 0.45
		var carat: int = int(stone.get("carat", 1))
		var cut: int = int(stone.get("cut", 0))
		var clear: int = DeepContent.clear_index()
		var clarity: int = int(stone.get("clarity", clear))
		var rungs: int = DeepContent.clarities().size()
		var tone: Color = _clarity_tone(clarity)
		var x: float = 0.0
		var words: String = "%d ct" % carat
		draw_string(font, Vector2(x, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, DeepUi.PAPER)
		x += font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + gap * 1.6
		var cut_word: String = DeepContent.cut_name(cut)
		var clarity_word: String = DeepContent.clarity_name(clarity)
		var left_over: float = size.x - x - font.get_string_size(cut_word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x - font.get_string_size(clarity_word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x - gap * 3.6
		var seg: float = clampf(left_over / float(DeepContent.cuts().size() + rungs) - 2.0, 4.0, float(px) * 0.7)
		for k in range(DeepContent.cuts().size()):
			draw_rect(Rect2(Vector2(x, mid - bar_h * 0.5), Vector2(seg, bar_h)), CounterMarks.CUT_TONE if k <= cut else Color(1, 1, 1, 0.14))
			x += seg + 2.0
		x += gap * 0.6
		draw_string(font, Vector2(x, base), cut_word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, CounterMarks.CUT_TONE if cut >= DeepContent.cuts().size() - 1 else DeepUi.PAPER)
		x += font.get_string_size(cut_word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + gap * 1.6
		for k in range(rungs):
			var box := Rect2(Vector2(x, mid - bar_h * 0.5), Vector2(seg, bar_h))
			draw_rect(box, tone if k == clarity else Color(1, 1, 1, 0.14))
			if k == clear:
				draw_rect(box.grow(1.0), Color(1, 1, 1, 0.45), false, 1.0)
			x += seg + 2.0
		x += gap * 0.6
		draw_string(font, Vector2(x, base), clarity_word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tone)

	func _segments(left: float, y: float, span: float, h: float, count: int, ink: Callable, marked: int) -> void:
		var gap: float = 3.0
		var w: float = (span - gap * float(count - 1)) / float(count)
		for k in range(count):
			var box := Rect2(Vector2(left + (w + gap) * float(k), y), Vector2(w, h))
			draw_rect(box, ink.call(k))
			if k == marked:
				draw_rect(box.grow(1.0), Color(1, 1, 1, 0.45), false, 1.0)
