extends RefCounted
## Pieces the workshop pages share: a stone under a lamp, a stone under the loupe, a share bar,
## rows of skill marks, the contract bench's funnel and outcome ring, a Birthstone card, and the
## small count a tab carries when something there wants looking at.

const GemView = preload("res://view/gems/gem_view.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Geode = preload("res://view/gems/geode.gd")
const Tips = preload("res://view/ui/tips.gd")


class Showcase extends Control:
	## One stone under a lamp on a velvet pad. Live, it turns slowly in its light the whole
	## time; not live (`live` false), it is a photograph that comes alive only while the
	## pointer rests on it. A page with several lamps (the Market's case) built a 3D world for
	## each on every visit and drew every one of them on every frame.
	var _clock: float = 0.0
	var _tone: Color
	var _view: Control
	func _init(stone: Dictionary, edge: float, wide: float = 1.6, live: bool = true) -> void:
		custom_minimum_size = Vector2(edge * wide, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", true)) else DeepUi.color(DeepStone.color(stone))
		var view: Control = null
		if live:
			view = GemView.new()
		else:
			view = Thumbs.GemThumb.new()
		_view = view
		var reach: float = edge * 0.8
		view.anchor_left = 0.5
		view.anchor_right = 0.5
		view.offset_left = - reach * 0.5
		view.offset_right = reach * 0.5
		view.offset_top = edge * 0.06
		view.offset_bottom = edge * 0.06 + reach
		if live:
			view.call("set_drift", true)
			view.call("set_spin", 0.35)
			view.set("inspectable", true)
			view.call("configure", stone)
			view.call("enable_interaction")
		else:
			view.call("configure", stone)
		add_child(view)
	func show_stone(stone: Dictionary) -> void:
		## Another stone under the same lamp, in the same light.
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if bool(stone.get("appraised", true)) else DeepUi.color(DeepStone.color(stone))
		_view.call("configure", stone)
		queue_redraw()
	func inspect_with(opts: Dictionary) -> void:
		## What its close look (a right-click on the stone) is opened with.
		_view.set("inspect_opts", opts)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var cx: float = size.x * 0.5
		var spread: float = minf(110.0, size.x * 0.45)
		var cone := PackedVector2Array([Vector2(cx - 30, 0), Vector2(cx + 30, 0), Vector2(cx + spread, size.y * 0.92), Vector2(cx - spread, size.y * 0.92)])
		draw_colored_polygon(cone, Color(_tone, 0.07 + 0.02 * sin(_clock * 1.7)))
		var pad := Vector2(minf(260.0, size.x), 60)
		draw_texture_rect(glow, Rect2(Vector2(cx, size.y * 0.9) - pad * 0.5, pad), false, Color(_tone, 0.45))
		for i in range(8):
			var t: float = fmod(_clock * 0.2 + float(i) / 8.0, 1.0)
			draw_circle(Vector2(cx + sin(float(i) * 1.9 + _clock * 0.3) * 80.0 * t, size.y * 0.9 - t * size.y * 0.8), 1.5, Color(_tone.lightened(0.5), 0.8 * (1.0 - t)))


class LoupeTable extends Control:
	## The stone under the jeweller's lens: live, lit from above, ringed by the loupe's rim.
	## A raw one sits there in its rock; the appraisal itself is its own sheet.
	var stone: Dictionary
	var _view: Control
	var _clock: float = 0.0
	var _tone: Color
	func _init(new_stone: Dictionary, edge: float) -> void:
		stone = new_stone
		custom_minimum_size = Vector2(edge * 1.5, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var appraised: bool = bool(stone.get("appraised", false))
		_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
		_view = GemView.new()
		var reach: float = edge * 0.78
		_view.anchor_left = 0.5
		_view.anchor_right = 0.5
		_view.anchor_top = 0.5
		_view.anchor_bottom = 0.5
		_view.offset_left = - reach * 0.5
		_view.offset_right = reach * 0.5
		_view.offset_top = - reach * 0.5
		_view.offset_bottom = reach * 0.5
		_view.set_drift(true)
		_view.set_spin(0.4)
		_view.inspectable = true
		_view.configure(stone)
		add_child(_view)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre := size * 0.5
		var radius: float = size.y * 0.47
		var pulse: float = 1.0 + 0.03 * sin(_clock * 2.0)
		var halo := Vector2(radius, radius) * 3.0 * pulse
		draw_texture_rect(glow, Rect2(centre - halo * 0.5, halo), false, Color(_tone, 0.25))
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.85))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 5.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0 + _clock * 0.1
			draw_line(centre + Vector2.from_angle(angle) * (radius + 3.0), centre + Vector2.from_angle(angle) * (radius + 9.0), Color("b8a47a", 0.8), 1.5, true)
		## A glint travelling round the glass.
		var sweep: float = fmod(_clock * 0.4, 1.0) * TAU
		draw_arc(centre, radius - 12.0, sweep, sweep + 0.5, 16, Color(1, 1, 1, 0.25), 3.0, true)


class OddsBar extends Control:
	## Shares as one bar: a segment each, in its own color, the larger ones named under the bar
	## and every one named on hover. What a Geode prints its odds with, and a contract its colors.
	var parts: Array = []
	const BAR: float = 12.0

	func _init(list: Array) -> void:
		parts = list
		custom_minimum_size = Vector2(120, 32)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "

	func _get_tooltip(at: Vector2) -> String:
		var x: float = 0.0
		for part in parts:
			var width: float = size.x * float(part.share)
			if at.x >= x and at.x <= x + width:
				return "%s: %s" % [str(part.label), Geode.percent(float(part.share))]
			x += width
		return ""

	func _draw() -> void:
		## Every segment is cut from the one rounded bar, so all of them stand the same height and
		## only the bar's two ends are round. (Drawn as boxes, the end segments' rounded corners
		## were anti-aliased inward and stood a pixel or two shorter than the square ones between.)
		var shape: PackedVector2Array = _outline()
		_fill(shape, Color(DeepUi.LINE, 0.5))
		var x: float = 0.0
		var font: Font = DeepUi.bold_font()
		## How far in from each end the highlight along the top edge starts, where the round end
		## is still below it.
		var radius: float = BAR * 0.5
		var inset: float = radius - sqrt(radius * radius - (radius - 1.0) * (radius - 1.0))
		for index in range(parts.size()):
			var part: Dictionary = parts[index]
			var width: float = size.x * float(part.share)
			if width <= 0.5:
				continue
			_fill(_cut(shape, x, x + width), part.color)
			if bool(part.get("rainbow", false)):
				## A rainbow segment: the wheel run along it, in thin strips.
				var strips: int = maxi(2, int(width / 3.0))
				for s in range(strips):
					var from: float = x + width * float(s) / float(strips)
					_fill(_cut(shape, from, from + width / float(strips) + 0.5), DeepUi.rainbow_at(float(s) / float(strips), 0.55))
			var shine_from: float = maxf(x, inset)
			var shine_to: float = minf(x + width, size.x - inset)
			if shine_to > shine_from:
				draw_line(Vector2(shine_from, 1), Vector2(shine_to, 1), Color(1, 1, 1, 0.22), 1.0)
			## Named under the bar where it is wide enough to carry the words.
			var words: String = "%s %s" % [str(part.label), Geode.percent(float(part.share))]
			var measured: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if measured > width - 2.0:
				words = Geode.percent(float(part.share))
				measured = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if measured <= width + 6.0:
				var tint: Color = part.color if not bool(part.get("rainbow", false)) else DeepUi.OPAL_TONE
				draw_string(font, Vector2(x + (width - measured) * 0.5, BAR + 15.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.15))
			x += width

	func _outline() -> PackedVector2Array:
		## The whole bar, a rectangle with half-round ends.
		var radius: float = minf(BAR * 0.5, size.x * 0.5)
		var points := PackedVector2Array()
		var steps: int = 10
		for i in range(steps + 1):
			var angle: float = -PI * 0.5 + PI * float(i) / float(steps)
			points.append(Vector2(size.x - radius + cos(angle) * radius, radius + sin(angle) * radius))
		for i in range(steps + 1):
			var angle: float = PI * 0.5 + PI * float(i) / float(steps)
			points.append(Vector2(radius + cos(angle) * radius, radius + sin(angle) * radius))
		return points

	func _cut(shape: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
		## The part of the bar between two points along it.
		var band := PackedVector2Array([Vector2(from, -1.0), Vector2(to, -1.0), Vector2(to, BAR + 1.0), Vector2(from, BAR + 1.0)])
		var pieces: Array = Geometry2D.intersect_polygons(shape, band)
		return pieces[0] if not pieces.is_empty() else PackedVector2Array()

	func _fill(points: PackedVector2Array, color: Color) -> void:
		## A piece of the bar, its edge smoothed by a hairline of its own color.
		if points.size() < 3:
			return
		draw_colored_polygon(points, color)
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, color, 1.0, true)

class MarkRows extends Control:
	## Every skill a Geode might hold, each as its mark in its gem color, in as many to a row
	## as the card is wide; past the last row the rest are counted. Each names itself on hover
	## with its rarity and its odds, and says so if it has never been found (those are dimmed).
	var marks: Array = []
	var _hover: int = -1
	const MARK: float = 24.0
	const GAP: float = 5.0
	const ROWS: int = 2

	func _init(list: Array) -> void:
		marks = list
		custom_minimum_size = Vector2(120, MARK * ROWS + GAP * (ROWS - 1))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = " "
		mouse_exited.connect(func() -> void:
			_hover = -1
			queue_redraw())

	func _per_row() -> int:
		return maxi(1, int((size.x + GAP) / (MARK + GAP)))

	func _shown() -> int:
		## All of them if they fit; otherwise one cell short, for the count of the rest.
		var room: int = _per_row() * ROWS
		return marks.size() if marks.size() <= room else room - 1

	func _cell(index: int) -> Rect2:
		return Rect2(Vector2(float(index % _per_row()), float(index / _per_row())) * (MARK + GAP), Vector2(MARK, MARK))

	func _at(point: Vector2) -> int:
		## The mark under a point, or -2 over the count of the rest, or -1 over nothing.
		if point.x < 0.0 or point.y < 0.0:
			return -1
		var column: int = int(point.x / (MARK + GAP))
		var row: int = int(point.y / (MARK + GAP))
		if column >= _per_row() or row >= ROWS:
			return -1
		var index: int = row * _per_row() + column
		if index < _shown():
			return index
		return -2 if index == _shown() and _shown() < marks.size() else -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var index: int = _at(event.position)
			if index != _hover:
				_hover = index
				queue_redraw()

	func _get_tooltip(at: Vector2) -> String:
		var index: int = _at(at)
		if index >= 0:
			return str(marks[index].tip)
		if index == -2:
			var rest: Array = []
			for i in range(_shown(), marks.size()):
				rest.append(str(marks[i].name))
			return "And %s" % ", ".join(rest)
		return ""

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var shown: int = _shown()
		for index in range(shown):
			var mark: Dictionary = marks[index]
			var cell: Rect2 = _cell(index)
			var tint: Color = mark.color
			if index == _hover:
				var halo: float = MARK * 2.4
				draw_texture_rect(glow, Rect2(cell.get_center() - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(tint, 0.45))
			draw_texture_rect(GemIcons.texture(str(mark.glyph), GemIcons.baked_size(MARK)), cell, false, tint if bool(mark.known) else Color(tint, 0.42))
		if shown < marks.size():
			var cell: Rect2 = _cell(shown)
			var font: Font = DeepUi.bold_font()
			var words: String = "+%d" % (marks.size() - shown)
			draw_string(font, Vector2(cell.position.x, cell.get_center().y + 5.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DeepUi.PAPER if _hover == -2 else DeepUi.MUTED)

class Funnel extends Control:
	## The contract bench's lines from its places down to the one they make: faint and dotted
	## while a place is empty, lit in the grade's color once a stone is on it, and once the
	## contract can be signed, light running down every line toward the middle.
	var filled: int = 0
	var count: int = 5
	var tone: Color
	var signable: bool = false
	var pitch: float = 164.0
	var _clock: float = 0.0

	func _init(on: int, places: int, color: Color, can_sign: bool, apart: float) -> void:
		filled = on
		count = places
		tone = color
		signable = can_sign
		pitch = apart
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _point(index: int, t: float) -> Vector2:
		## A line leaves its place straight down and curves in to the middle.
		var top := Vector2(size.x * 0.5 + (float(index) - float(count - 1) * 0.5) * pitch, 0.0)
		var bottom := Vector2(size.x * 0.5, size.y)
		return top.bezier_interpolate(top + Vector2(0, size.y * 0.75), bottom - Vector2(0, size.y * 0.4), bottom, t)

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		for index in range(count):
			var points := PackedVector2Array()
			for step in range(21):
				points.append(_point(index, float(step) / 20.0))
			if index >= filled:
				for step in range(0, 20, 2):
					draw_line(points[step], points[step + 1], Color(DeepUi.LINE_HI, 0.9), 2.0, true)
				continue
			draw_polyline(points, Color(tone, 0.22), 7.0, true)
			draw_polyline(points, Color(tone.lightened(0.2), 0.85), 2.0, true)
			if signable:
				var t: float = fposmod(_clock * 0.9 + float(index) * 0.17, 1.0)
				var spot: float = 24.0
				draw_texture_rect(glow, Rect2(_point(index, t) - Vector2(spot, spot) * 0.5, Vector2(spot, spot)), false, Color(tone.lightened(0.4), 0.9 * sin(t * PI)))
		draw_circle(Vector2(size.x * 0.5, size.y), 4.0, Color(tone, 0.9) if filled > 0 else DeepUi.LINE_HI)

class Outcome extends Control:
	## Where the one comes out of a contract: a brass ring lit round a fifth at a time as the
	## bench fills, in the grade it promises, a stone's shape inside with a question for a
	## heart. Once the contract can be signed, it breathes.
	var tone: Color
	var fill: float = 0.0
	var signable: bool = false
	var _clock: float = 0.0

	func _init(color: Color, share: float, can_sign: bool) -> void:
		tone = color
		fill = clampf(share, 0.0, 1.0)
		signable = can_sign
		custom_minimum_size = Vector2(150, 132)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.42
		var breath: float = 0.5 + 0.5 * sin(_clock * 2.4) if signable else 0.0
		var halo: float = radius * (3.0 + 0.35 * breath)
		draw_texture_rect(glow, Rect2(centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(tone, 0.1 + 0.25 * fill + 0.15 * breath))
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.92))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 4.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		if fill > 0.0:
			draw_arc(centre, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 64, Color(tone, 0.95), 3.0, true)
		var mark: float = radius * 1.15
		draw_texture_rect(GemIcons.texture("gem", GemIcons.baked_size(mark)), Rect2(centre - Vector2(mark, mark) * 0.5, Vector2(mark, mark)), false, Color(tone, 0.22 + 0.45 * fill + 0.2 * breath))
		var font: Font = DeepUi.display_font()
		var size_px: int = int(radius * 0.62)
		var width: float = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, centre + Vector2(-width * 0.5, size_px * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(DeepUi.PAPER, 0.45 + 0.5 * fill))


class BirthstoneCard extends PanelContainer:
	## A character's Birthstone at the end of a rail: the stone, its name, and every tier as
	## a pictograph. It is never taken out. `key` names which of the delver's three it is (the
	## one worn; "" is their first): at home it is swapped from this card (`swap_tile`, and
	## `swaps` puts the mark for that beside its foot line), down the mine it is worn for the
	## whole run and there is nothing to click.
	## `labelled` mirrors the run bench's socket cards, which carry a heading above the ring
	## and a second line under the name, so the tiers still sit level with their triggers.
	func _init(parent: Node, character_key: String, wide: float = 150.0, labelled: bool = false, key: String = "", swaps: bool = false) -> void:
		var stone: Dictionary = DeepStone.birthstone(character_key, key)
		## An inner class does not reach the script's own functions by name: asked of the script.
		var parts = load("res://view/home/home_parts.gd")
		var tint: Color = parts.birth_tone(stone)
		add_theme_stylebox_override("panel", DeepUi.raised(Color(0.07, 0.06, 0.09, 0.92), Color(tint, 0.7), 10, 10, 0.35))
		custom_minimum_size = Vector2(wide, 0)
		mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(self)
		var box := DeepUi.vbox(self, 4 if labelled else 6)
		if stone.is_empty():
			DeepUi.label(box, "No Birthstone", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
			return
		if labelled:
			DeepUi.label(box, "Birthstone", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(76, 76)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(slot)
		var ring := BattleScreen.SocketRing.new("BIRTHSTONE", false)
		ring.birth_tint = tint
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(ring)
		var thumb := StoneCard.mini(slot, stone, 60, str(stone.get("name", "")) + "\n" + str(stone.get("text", "")))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.label(box, str(stone.get("name", "")), 13 if labelled else 14, parts.birth_name_tone(stone), HORIZONTAL_ALIGNMENT_CENTER)
		if labelled:
			DeepUi.label(box, "Always set", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		## Every tier on one row, the size of a socket's trigger; each names itself on hover.
		var tiers := DeepUi.hbox(box, 4)
		tiers.alignment = BoxContainer.ALIGNMENT_CENTER
		var die: String = DiceIcons.ladder_die(stone.get("tiers", []))
		## A Bust rides the dice it is about rather than standing beside them.
		var bust: int = DiceIcons.ladder_penalty(stone.get("tiers", []), die)
		if not die.is_empty():
			var tip: String = ""
			if bust >= 0:
				var penalty: Dictionary = stone.get("tiers", [])[bust]
				tip = "%s: %s" % [str(penalty.get("name", "")), str(penalty.get("text", ""))]
			DiceIcons.build_ladder(tiers, stone.get("tiers", []), die, 0, 14 if labelled else 15, DeepUi.MUTED, DeepUi.MUTED, [], tip)
		for index in range(stone.get("tiers", []).size()):
			var tier: Dictionary = stone.get("tiers", [])[index]
			if DiceIcons.ladder_rung(tier, die) > 0 or index == bust:
				continue
			DiceIcons.build(tiers, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 14 if labelled else 15, DeepUi.MUTED,
				"%s: %s" % [str(tier.get("name", "")), str(tier.get("text", ""))])
		if swaps and not labelled:
			var foot := DeepUi.stat(box, "reroll", "Birthstone", DeepUi.MUTED, 11, "Click to change the Birthstone they wear")
			foot.alignment = BoxContainer.ALIGNMENT_CENTER
		elif not labelled:
			DeepUi.label(box, "Birthstone", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)

class Pip extends Control:
	## The small mark a tab, a tile or a button carries when something there wants looking at:
	## a count when there is a number of things to act on, a dot for "new since you looked".
	## Pinned to its holder's top-right corner, over everything else in it. Round, not cut:
	## it is a light on the thing, not part of the kit's stonework.
	var count: int = 0
	var tone: Color = DeepUi.ACCENT
	var edge: Vector2 = Vector2(10, 10)

	func _init(number: int, color: Color) -> void:
		count = number
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 5
		if number > 0:
			edge = Vector2(18.0 if number < 10 else (24.0 if number < 100 else 30.0), 18.0)
		custom_minimum_size = edge

	func _get_minimum_size() -> Vector2:
		return edge

	func _draw() -> void:
		var radius: float = edge.y * 0.5
		var left := Vector2(radius, radius)
		var right := Vector2(edge.x - radius, radius)
		## A dark ring first, so the pip reads on a lit tab as well as on the bar.
		draw_circle(left, radius, DeepUi.INK, true, -1.0, true)
		draw_circle(right, radius, DeepUi.INK, true, -1.0, true)
		draw_rect(Rect2(left.x, 0, right.x - left.x, edge.y), DeepUi.INK)
		var inner: float = radius - 1.5
		draw_circle(left, inner, tone, true, -1.0, true)
		draw_circle(right, inner, tone, true, -1.0, true)
		draw_rect(Rect2(left.x, 1.5, right.x - left.x, edge.y - 3.0), tone)
		if count > 0:
			var font: Font = DeepUi.bold_font()
			var words: String = str(count) if count < 100 else "99+"
			var font_size: int = 12
			var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var base: float = (edge.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			draw_string(font, Vector2((edge.x - width) * 0.5, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.INK)

static func pin(holder: Control, number: int, color: Color, dot: bool = false) -> Control:
	## Pins a pip to a control's top-right corner: a count when `number` is above nought, a
	## dot when `dot` asks for one, nothing otherwise. Anchored to the corner, so it follows
	## the holder however it is laid out.
	if number <= 0 and not dot:
		return null
	var mark := Pip.new(number, color)
	holder.add_child(mark)
	var lift: float = 5.0 if number > 0 else 1.0
	var tuck: float = mark.edge.x * 0.45 if number > 0 else 3.0
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.anchor_top = 0.0
	mark.anchor_bottom = 0.0
	mark.offset_left = -mark.edge.x + tuck
	mark.offset_right = tuck
	mark.offset_top = -lift
	mark.offset_bottom = -lift + mark.edge.y
	return mark

class Avatar extends Control:
	## The player's face in the top bar and on the profile page: their Steam avatar once the
	## game is running through Steam (app.gd fetches it into the Engine's "steam_face" meta),
	## and otherwise their initial on a plate cut like a stone.
	var initial: String = "?"

	func _init(player_name: String, edge: float) -> void:
		var trimmed: String = player_name.strip_edges()
		initial = trimmed.left(1).to_upper() if not trimmed.is_empty() else "?"
		custom_minimum_size = Vector2(edge, edge)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var plate := DeepUi.flat(Color("1b2440"), DeepUi.ACCENT, int(size.x * 0.3), 0, 2)
		draw_style_box(plate, r)
		## A null default counts as no default to get_meta, which then errors on every draw.
		var face: Variant = Engine.get_meta("steam_face") if Engine.has_meta("steam_face") else null
		if face is Texture2D:
			draw_texture_rect(face, r.grow(-3.0), false)
			return
		var font: Font = DeepUi.display_font()
		var font_size: int = int(size.y * 0.5)
		var width: float = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5 + font_size * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.ACCENT_HI)


static func keycaps(parent: Node, letters: Array, hint: String) -> HBoxContainer:
	## The keyboard keys that do the same as a row of buttons, drawn as small caps so a "Q"
	## is never read as a nought.
	var row := DeepUi.hbox(parent, 3)
	row.tooltip_text = hint
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for letter in letters:
		var cap := PanelContainer.new()
		var face := DeepUi.flat(Color(DeepUi.SLATE_HI, 0.9), Color(DeepUi.LINE_HI, 0.9), 3, 0)
		face.content_margin_left = 5
		face.content_margin_right = 5
		face.content_margin_top = 1
		face.content_margin_bottom = 2
		face.border_width_bottom = 2
		cap.add_theme_stylebox_override("panel", face)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cap)
		## Set in the display face, whose Q has a tail long enough to tell it from a nought.
		var word := DeepUi.label(cap, str(letter), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		word.add_theme_font_override("font", DeepUi.caps_font())
	return row

# --- a delver's three Birthstones ------------------------------------------------------------------
##
## Every delver has three Birthstones: their first, and two bought with gold. One is worn for
## a whole run, and it is chosen at home: on the dossier's Birthstone card, where any of the
## three is read before it is bought, and at the rail's Birthstone tile. The desk's page and
## the phone's build both from these pieces; the workshop keeps what is being read
## (`HomeScreen.birth_read`) and does the buying and the wearing.

static func gold_words(sum: int) -> String:
	## A sum of gold with its thousands set apart: "2,500".
	var digits: String = str(absi(sum))
	var said: String = ""
	while digits.length() > 3:
		said = "," + digits.right(3) + said
		digits = digits.left(digits.length() - 3)
	return ("-" if sum < 0 else "") + digits + said

static func birth_tone(stone: Dictionary) -> Color:
	## The color a Birthstone's card, ring and name are drawn in: its own, or its second where
	## the first is too dark to see on the page (snowflake obsidian, spectrolite, sphalerite).
	if stone.is_empty():
		return DeepUi.ACCENT
	var tone: Color = GemMesh.tint(stone)
	var second: String = str(stone.get("hue2", ""))
	if tone.get_luminance() < 0.25 and second.is_valid_html_color() and Color(second).get_luminance() > tone.get_luminance():
		tone = Color(second)
	return tone

static func birth_name_tone(stone: Dictionary) -> Color:
	## A Birthstone's name in its own color, light enough to read on the page.
	var said: Color = birth_tone(stone).lightened(0.35)
	return said if said.get_luminance() >= 0.45 else said.lerp(DeepUi.PAPER, 0.4)

static func birth_state(profile: Dictionary, character_key: String, key: String) -> String:
	## Where one of a delver's stones stands: "worn", "owned" (theirs, and not on) or "locked".
	if not DeepProfile.owns_birthstone(profile, character_key, key):
		return "locked"
	return "worn" if DeepProfile.worn_birthstone(profile, character_key) == key else "owned"

static func conquest_words(profile: Dictionary, character_key: String, key: String) -> String:
	## The mines conquered wearing a stone, in one line; "" while there are none.
	var mines: Array = DeepProfile.stone_conquests(profile, character_key, key)
	if mines.is_empty():
		return ""
	var names: Array = mines.map(func(mine: Variant) -> String: return DeepContent.mine_name(str(mine)))
	return "Conquered wearing %s: %s" % [str(DeepContent.birthstone_def(character_key, key).get("name", "it")), ", ".join(names)]

static func _corner_mark(holder: Control, corner: int, glyph: String, words: String, tone: Color) -> PanelContainer:
	## A small dark capsule in a corner of a stone's button: a mark, and a count beside it.
	## It takes no press and says nothing of its own; the button under it does both.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", DeepUi.capsule(badge, Color(DeepUi.INK, 0.92), Color(tone, 0.5), 1, 4, 0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	var row := DeepUi.stat(badge, glyph, words, tone, 11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in row.get_children():
		(part as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(part as Control).tooltip_text = ""
	badge.set_anchors_and_offsets_preset(corner, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN if corner in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN if corner in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	return badge

static func birth_stones(home: Control, parent: Node, character_key: String, read: String, joined: bool) -> HBoxContainer:
	## A delver's three Birthstones side by side as small stones: their first, then the two
	## bought with gold. The one being read is ringed, and a press reads another. Under each,
	## where it stands: Worn, or the price of one not bought. A crown and a count on a stone
	## are the mines conquered wearing it, named under the pointer (or a finger held on it).
	var edge: float = DeepUi.pt(44) if DeepUi.phone else 58.0
	var row := DeepUi.hbox(parent, int(DeepUi.pt(5)) if DeepUi.phone else 8)
	row.name = "BirthStones"
	for listed in DeepContent.birthstone_keys(character_key):
		var key: String = str(listed)
		var stone: Dictionary = DeepStone.birthstone(character_key, key)
		var state: String = birth_state(home.profile, character_key, key)
		## A delver who has not joined wears nothing yet.
		if not joined and state == "worn":
			state = "owned"
		var price: int = DeepContent.birthstone_price(character_key, key)
		var conquered: Array = DeepProfile.stone_conquests(home.profile, character_key, key)
		var cell := DeepUi.vbox(row, int(DeepUi.pt(1)) if DeepUi.phone else 2)
		var button := DeepUi.button(cell, "", Callable(), 12)
		button.name = "Stone_" + (key if not key.is_empty() else "FIRST")
		button.custom_minimum_size = Vector2(edge, edge)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.set_meta("birthstone", key)
		button.set_meta("read", key == read)
		for look in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var lit: bool = look != "normal" and look != "disabled"
			var face: StyleBoxFlat
			if key == read:
				face = DeepUi.flat(Color(DeepUi.ACCENT, 0.22 if lit else 0.14), DeepUi.ACCENT, 10, 0, 2)
			else:
				face = DeepUi.flat(Color(1, 1, 1, 0.08 if lit else 0.03), Color(DeepUi.LINE_HI, 1.0 if lit else 0.5), 10, 0, 1)
			button.add_theme_stylebox_override(look, face)
		var thumb := Thumbs.GemThumb.new(stone, edge * 0.8)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(thumb)
		## Pinned to the button's middle and grown out from it both ways to its own size.
		thumb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		thumb.grow_horizontal = Control.GROW_DIRECTION_BOTH
		thumb.grow_vertical = Control.GROW_DIRECTION_BOTH
		if state == "locked":
			thumb.modulate = Color(0.66, 0.66, 0.72, 0.92)
			_corner_mark(button, Control.PRESET_BOTTOM_RIGHT, "lock", "", DeepUi.MUTED)
		if not conquered.is_empty():
			_corner_mark(button, Control.PRESET_TOP_RIGHT, "crown", str(conquered.size()), DeepUi.ACCENT_HI).name = "Conquests"
		## What it says under the pointer, or on the phone's card when a finger is held on it.
		var said: Array = [str(stone.get("name", "Birthstone"))]
		match state:
			"worn":
				said.append("Worn")
				var worn := DeepUi.stat(cell, "check", "Worn", DeepUi.GOOD, 11)
				worn.name = "WornMark"
				worn.alignment = BoxContainer.ALIGNMENT_CENTER
			"locked":
				said.append("Locked: %s gold" % gold_words(price))
				var cost := DeepUi.stat(cell, "coin", gold_words(price), DeepUi.ACCENT_HI if joined else DeepUi.DIM, 11)
				cost.alignment = BoxContainer.ALIGNMENT_CENTER
			"owned":
				if joined:
					said.append("Owned")
					DeepUi.label(cell, "Owned", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if not conquered.is_empty():
			said.append(conquest_words(home.profile, character_key, key))
		button.tooltip_text = "\n".join(said) + "\nRight-click for details"
		var look_close := func() -> void: load("res://view/inspect/inspector.gd").stone(stone)
		Tips.hold(button, look_close)
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				look_close.call())
		button.pressed.connect(func() -> void:
			## The lift that ends a held finger is not a tap.
			if not Tips.held(button):
				home.read_birthstone(character_key, key))
	return row

static var _stone_word_regex: Dictionary = {}

static func _stone_word_pattern(keywords: Dictionary) -> RegEx:
	## The words a stone gives a meaning of its own, however they are ended ("Trophy",
	## "Trophies", "Faces"), longest first.
	var stems: Array = []
	for key in keywords:
		var stem: String = str(key).strip_edges().to_lower().replace(" ", "\\s+")
		if stem.is_empty():
			continue
		stems.append(stem.left(stem.length() - 1) + "(?:y|ies)" if stem.ends_with("y") else stem + "\\w*")
	stems.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var tag: String = "|".join(stems)
	if not _stone_word_regex.has(tag):
		var made := RegEx.new()
		made.compile("(?i)\\b(?:%s)\\b" % tag)
		_stone_word_regex[tag] = made
	return _stone_word_regex[tag]

static func stone_words(parent: Node, text: String, stone: Dictionary, size: int, color: Color, width: float = 0.0) -> Control:
	## A Birthstone's words. Plain, unless they use a word the stone gives a meaning of its own
	## (its `keywords`: a Trophy, a Prize, a Face, the scale): those are underlined, and say
	## what they mean under the pointer, or under a finger held on them.
	var keywords: Dictionary = stone.get("keywords", {}) if stone.get("keywords", {}) is Dictionary else {}
	var found: Array = _stone_word_pattern(keywords).search_all(text) if not keywords.is_empty() else []
	if found.is_empty():
		return DeepUi.wrap(parent, text, size, color, HORIZONTAL_ALIGNMENT_LEFT, width)
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.selection_enabled = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0.0:
		rtl.custom_minimum_size.x = width
	DeepUi.set_text_size(rtl, size)
	rtl.add_theme_color_override("default_color", color)
	parent.add_child(rtl)
	var cursor: int = 0
	for match_found in found:
		var m: RegExMatch = match_found
		if m.get_start() > cursor:
			rtl.add_text(text.substr(cursor, m.get_start() - cursor))
		var word: String = m.get_string()
		var meaning: String = ""
		for key in keywords:
			var stem: String = str(key).strip_edges().to_lower()
			if word.to_lower().begins_with(stem.left(stem.length() - 1) if stem.ends_with("y") else stem):
				meaning = str(keywords[key])
				break
		rtl.push_hint(meaning)
		rtl.push_underline()
		rtl.push_color(color.lerp(DeepUi.PAPER, 0.75))
		rtl.add_text(word)
		rtl.pop()
		rtl.pop()
		rtl.pop()
		cursor = m.get_end()
	if cursor < text.length():
		rtl.add_text(text.substr(cursor))
	if DeepUi.phone or DisplayServer.is_touchscreen_available():
		Tips.word_hold(rtl)
	return rtl

static func birth_ladder(parent: Node, stone: Dictionary) -> GridContainer:
	## A Birthstone's tiers as one ladder: the mark each asks for in a column as wide as the
	## widest of them, so every tier's name and words start on one line.
	var tiers: Array = stone.get("tiers", [])
	var die: String = DiceIcons.ladder_die(tiers)
	var grid := GridContainer.new()
	grid.name = "BirthLadder"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(6)) if DeepUi.phone else 10)
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(5)) if DeepUi.phone else 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	for tier in tiers:
		var mark := HBoxContainer.new()
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		if DeepUi.phone:
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			mark.custom_minimum_size.x = DeepUi.pt(44)
		else:
			## Marks at 20 with their words at the text floor ("d4/d12 ×5" was 9 px at 14): five
			## dice across for a ladder, six patches for a ladder of colors.
			mark.alignment = BoxContainer.ALIGNMENT_CENTER
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mark.custom_minimum_size.x = 92.0 if die.is_empty() else 20.0 * float(DiceIcons.ladder_span(die))
		grid.add_child(mark)
		if DiceIcons.ladder_rung(tier, die) > 0:
			DiceIcons.build_ladder(mark, [tier], die, DiceIcons.ladder_rung(tier, die), DeepUi.pt(8) if DeepUi.phone else 20.0, DeepUi.MUTED, DeepUi.DIM)
		else:
			DiceIcons.build(mark, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), DeepUi.pt(10) if DeepUi.phone else 20.0, DeepUi.MUTED, str(tier.get("text", "")))
		var words := DeepUi.vbox(grid, -2 if DeepUi.phone else 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var named := DeepUi.label(words, str(tier.get("name", "")), 12 if DeepUi.phone else 13, DeepUi.PAPER)
		if DeepUi.phone:
			named.add_theme_font_override("font", DeepUi.bold_font())
		stone_words(words, str(tier.get("text", "")), stone, 11, DeepUi.MUTED)
	return grid

static func birth_action(home: Control, parent: Node, character_key: String, key: String, joined: bool) -> VBoxContainer:
	## Under the ladder, what is done with the stone being read. The one worn has only a quiet
	## line; one owned has Wear; one not bought has Unlock, with its price. Unlocking takes a
	## second press: the first turns the button, where it stands and with nothing popping up,
	## into the question and its two answers. Anything but Unlock calls it off.
	var stone_name: String = str(DeepContent.birthstone_def(character_key, key).get("name", "Birthstone"))
	var delver: String = str(DeepContent.character(character_key).get("name", character_key))
	var price: int = DeepContent.birthstone_price(character_key, key)
	var gold: int = int(home.profile.get("gold", 0))
	var box := DeepUi.vbox(parent, int(DeepUi.pt(4)) if DeepUi.phone else 6)
	box.name = "BirthAction"
	var row := DeepUi.hbox(box, int(DeepUi.pt(6)) if DeepUi.phone else 10)
	if not joined:
		## A delver who has not joined yet buys nothing: the price is only said.
		if price > 0:
			DeepUi.icon(row, "lock", DeepUi.glyph_px(12, 3), DeepUi.DIM, "A Birthstone is bought once its delver has joined the workshop.")
			DeepUi.wrap(row, "%s gold, once %s has joined" % [gold_words(price), delver], 12, DeepUi.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return box
	match birth_state(home.profile, character_key, key):
		"worn":
			## The phone's column has no line to spare: there the mark under the stone says it.
			if not DeepUi.phone:
				var worn := DeepUi.stat(row, "check", "Worn", DeepUi.GOOD, 13, "%s goes down wearing %s." % [delver, stone_name])
				worn.name = "Worn"
		"owned":
			var wear := DeepUi.icon_button(row, "gem", "Wear", func() -> void: home.wear_birthstone(character_key, key), 14, DeepUi.ACCENT)
			wear.name = "Wear"
			wear.tooltip_text = "%s goes down wearing %s from now on." % [delver, stone_name]
			_phone_action(wear)
		"locked":
			if str(home._birth_sure) == key:
				var ask := DeepUi.wrap(box if DeepUi.phone else row, "Unlock %s for %s gold?" % [stone_name, gold_words(price)], 13, DeepUi.ACCENT_HI)
				ask.name = "UnlockAsk"
				ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if DeepUi.phone:
					box.move_child(ask, 0)
				var yes := DeepUi.icon_button(row, "lock_open", "Unlock", func() -> void: home.buy_birthstone(character_key, key), 14, DeepUi.GOOD)
				yes.name = "UnlockYes"
				DeepUi.voice(yes, "buy")
				yes.disabled = gold < price
				home.gold_gate(yes, price)
				_phone_action(yes)
				var no := DeepUi.button(row, "Not yet", func() -> void: home.ask_birthstone(""), 14)
				no.name = "UnlockNo"
				DeepUi.voice(no, "ui_back")
				_phone_action(no)
			else:
				var buy := DeepUi.icon_button(row, "lock_open", "Unlock", func() -> void: home.ask_birthstone(key), 14, DeepUi.GOOD)
				buy.name = "Unlock"
				_phone_action(buy)
				DeepUi.priced(buy, gold_words(price))
				buy.disabled = gold < price
				home.gold_gate(buy, price)
				buy.tooltip_text = ("Unlock %s for good: %s can wear it on any run from then on." % [stone_name, delver]) if not buy.disabled \
					else "You have %s gold. %s costs %s." % [gold_words(gold), stone_name, gold_words(price)]
				## The reason a greyed one gives under the pointer, a held finger gets too.
				Tips.hold(buy, Callable())
	return box

static func _phone_action(button: Button) -> void:
	## On the phone a Birthstone's action is a Ledger key 36 points tall, sharing its row. On
	## the desk it is a button of its own width, and never a narrow one.
	if not DeepUi.phone:
		button.custom_minimum_size.x = 96.0
		return
	DeepUi.ledger_button(button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
	button.custom_minimum_size.y = DeepUi.pt(36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func swap_tile(home: Control, tile: Control, character_key: String) -> void:
	## Makes the rail's Birthstone tile the way to change the stone worn: a press hangs the
	## delver's three stones under it (`birth_swap`). Opened again by itself when the page is
	## drawn with the swap still open.
	tile.name = "BirthstoneTile"
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = "Click to change the Birthstone they wear"
	DeepUi.juice(tile, 1.04)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if not event is InputEventMouseButton or event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		## A finger held on the stone opened its card or its close look: that lift is not a tap.
		if Tips.held(tile) or Tips.sheet_open() or load("res://view/inspect/inspector.gd").is_open():
			return
		DeepAudio.play("ui_open")
		home._birth_swap = true
		birth_swap(home, tile, character_key))
	if bool(home._birth_swap):
		birth_swap(home, tile, character_key)

static func birth_swap(home: Control, tile: Control, character_key: String) -> Control:
	## The swap at the rail: the delver's three stones in a small card hung under the tile. A
	## stone they own is put on by one press, and the card closes; one not bought is greyed,
	## with its price and where it is unlocked. A press anywhere else, or Escape, closes it.
	var overlay: Control = home._overlay
	for old in overlay.get_children():
		if old is BirthSwap:
			overlay.remove_child(old)
			old.queue_free()
	var swap := BirthSwap.new(home, tile)
	overlay.add_child(swap)
	var card := PanelContainer.new()
	card.name = "SwapCard"
	card.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT_DIM, 10, int(DeepUi.pt(6)) if DeepUi.phone else 10, 2, 4))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	swap.add_child(card)
	swap.card = card
	var box := DeepUi.vbox(card, int(DeepUi.pt(4)) if DeepUi.phone else 6)
	DeepUi.label(box, "Their Birthstone", 11, DeepUi.DIM)
	var picture: float = DeepUi.pt(34) if DeepUi.phone else 44.0
	for listed in DeepContent.birthstone_keys(character_key):
		var key: String = str(listed)
		var stone: Dictionary = DeepStone.birthstone(character_key, key)
		var state: String = birth_state(home.profile, character_key, key)
		var tint: Color = birth_tone(stone)
		var choice := DeepUi.choice_card(box, tint, func() -> void: home.wear_birthstone(character_key, key), int(DeepUi.pt(4)) if DeepUi.phone else 8)
		choice.name = "Swap_" + (key if not key.is_empty() else "FIRST")
		choice.set_meta("birthstone", key)
		choice.custom_minimum_size = Vector2(DeepUi.pt(196), DeepUi.pt(44)) if DeepUi.phone else Vector2(286, 0)
		var row := DeepUi.hbox(choice, int(DeepUi.pt(6)) if DeepUi.phone else 10)
		var thumb := Thumbs.GemThumb.new(stone, picture)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thumb)
		var words := DeepUi.vbox(row, -2 if DeepUi.phone else 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var named := DeepUi.label(words, str(stone.get("name", "Birthstone")), 13 if DeepUi.phone else 14, birth_name_tone(stone))
		named.add_theme_font_override("font", DeepUi.bold_font())
		match state:
			"worn":
				DeepUi.stat(words, "check", "Worn", DeepUi.GOOD, 11).mouse_filter = Control.MOUSE_FILTER_IGNORE
			"owned":
				DeepUi.label(words, "Wear it", 11, DeepUi.MUTED)
			"locked":
				var cost := DeepUi.hbox(words, int(DeepUi.pt(3)) if DeepUi.phone else 6)
				DeepUi.stat(cost, "coin", gold_words(DeepContent.birthstone_price(character_key, key)), DeepUi.ACCENT_HI, 11).mouse_filter = Control.MOUSE_FILTER_IGNORE
				DeepUi.label(cost, "Unlock on the dossier", 11, DeepUi.MUTED)
				DeepUi.disable_choice(choice)
	swap.place()
	return swap

class BirthSwap extends Control:
	## What stands behind the rail's Birthstone swap: the catch a press off the card lands on
	## (and closes it), and what keeps the card hung under the tile it was opened from,
	## wherever the page lays that tile out. Drawing the page again takes it away with the rest.
	var card: Control = null
	var _home: Control = null
	var _tile: int = 0

	func _init(home: Control, tile: Control) -> void:
		name = "BirthSwap"
		_home = home
		_tile = tile.get_instance_id()
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			close()

	func close() -> void:
		if is_instance_valid(_home):
			_home._birth_swap = false
		DeepAudio.play("ui_close", {"volume": 0.7})
		queue_free()

	func _process(_delta: float) -> void:
		place()

	func place() -> void:
		## Under the tile, their right edges in line; over it where the foot of the screen is too near.
		var tile := instance_from_id(_tile) as Control
		if card == null or tile == null or not tile.is_inside_tree() or not is_inside_tree():
			return
		var want: Vector2 = card.get_combined_minimum_size()
		var at: Rect2 = tile.get_global_rect()
		var room: Rect2 = get_global_rect().grow_individual(-DeepUi.safe_left - 8.0, -8.0, -DeepUi.safe_right - 8.0, -DeepUi.safe_bottom - 8.0)
		var x: float = clampf(at.end.x - want.x, room.position.x, maxf(room.position.x, room.end.x - want.x))
		var y: float = at.end.y + 6.0
		if y + want.y > room.end.y:
			y = maxf(room.position.y, at.position.y - want.y - 6.0)
		var spot: Vector2 = (Vector2(x, y) - get_global_rect().position).round()
		if card.size != want:
			card.size = want
		if card.position != spot:
			card.position = spot
