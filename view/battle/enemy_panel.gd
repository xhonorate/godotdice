extends PanelContainer
## The ledger (the plates rethink, artifact NMAGkwooypHHUKxsB4tR71, the owner's final room):
## everything about one creature in a panel on the side of the room away from it. Whose it is
## (your target, the one under the pointer, the one acting), its name and how many faces its
## dice have, its health, its block as a chip over its top right corner the way its tag wears
## it; then its dice, each face's move as a row: a rule and a mark in the colour of its kind,
## its name, its words with their keywords explained on hover, and its share of the die as
## pips, one dot a face. Then what its faces make together, what the
## fight calls it to do, and what it always is. The face it has just landed is lit. There is no
## die in it: the die is on the creature's tag, and a right-click turns it over in a window.
##
## A creature whose rows would stand the ledger taller than `max_height` reads them one line a
## move (`dense`), so it never needs a scroll bar.

const Look = preload("res://view/battle/creature_look.gd")
const Tag = preload("res://view/battle/creature_tag.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")

const WIDTH: float = 384.0
const FILL := Color(0.067, 0.078, 0.114, 0.96)
## Whose it is: the reader's target, the one under the pointer, the one acting.
const WHO: Dictionary = {"target": ["Your target", Color("e2b23a")], "looking": ["Looking at", Color("c5cde3")], "acting": ["Acting", Color("ff7a6b")]}

## The interface's mark for each kind of effect, kept for anything that still names a move by
## what it does rather than by its face.
const GLYPHS: Dictionary = {"damage": "sword", "block": "shield", "heal": "heart", "poison": "drop", "die_steal": "die", "remove_block": "split_shield", "stun": "stun",
	"curse": "eye", "clouded": "cloud", "marked": "eye", "regeneration": "heart", "spikes": "caltrop", "dulled": "cut", "summon": "copy", "burrow": "rampart",
	"festering": "drop", "burn": "flame", "strength": "bolt", "steal_gold": "coin_fall", "hold_gem": "gem", "bury_socket": "rampart", "charge": "bolt"}

static func move_glyph(move: Dictionary) -> String:
	var effects: Array = move.get("effects", [])
	for effect in effects:
		if str(effect.get("kind", "")) == "damage" and str(effect.get("target", "heroes")) != "self":
			return "sword"
	if effects.is_empty():
		return "spark"
	return str(GLYPHS.get(str(effects[0].get("kind", "")), "spark"))

var enemy_id: String = ""
var foe: Dictionary = {}
## How tall it may stand; the battle screen sets it to the room it has above the dock.
var max_height: float = 450.0
## Whose it is now, and the move whose row is lit.
var who: String = "target"
var lit: String = ""
## One line a move, for a creature with more to say than the room holds.
var dense: bool = false
var _key: String = ""
var _style_key: String = ""
var _rows: Dictionary = {}
var _who: Label
var _name: Label
var _dice_words: Label
var _bar: Tag.HealthBar
## The block chip and the overlay it stands in, over the panel's top right corner.
var _over: Control
var _block: PanelContainer
var _block_label: Label
var _list: VBoxContainer

static func width() -> float:
	## The ledger's width: the phone's is 224 points (docs/PHONE_UI.md).
	return DeepUi.pt(224) if DeepUi.phone else WIDTH

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = width()
	var box := DeepUi.vbox(self, 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	_who = DeepUi.label(box, "", 10, WHO.target[1])
	_who.add_theme_font_override("font", DeepUi.bold_font())
	var head := DeepUi.hbox(box, 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = DeepUi.label(head, "", 17, DeepUi.PAPER)
	_name.add_theme_font_override("font", DeepUi.bold_font())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := DeepUi.flat(Color(0, 0, 0, 0), Color("55608a"), 3, 1, 2)
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge.add_theme_stylebox_override("panel", badge_style)
	head.add_child(badge)
	_dice_words = DeepUi.label(badge, "", 10, DeepUi.MUTED)
	_dice_words.add_theme_font_override("font", DeepUi.bold_font())
	_bar = Tag.HealthBar.new()
	_bar.thick = true
	_bar.custom_minimum_size.y = 18
	box.add_child(_bar)
	_list = DeepUi.vbox(box, 5)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	## Its block straddles the panel's top edge at the right, as the chip on its tag does, rather
	## than taking a row of its own under the bar. A PanelContainer stretches its direct children,
	## so the chip stands in a plain overlay that takes the content rect and lets the pointer
	## through; the panel has no clip, so the overhang draws.
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_over)
	_block = PanelContainer.new()
	_block.mouse_filter = Control.MOUSE_FILTER_PASS
	_block.add_theme_stylebox_override("panel", DeepUi.capsule(_block, Color("14223a"), DeepUi.BLOCK, 2, 6, 0))
	_over.add_child(_block)
	var chip_row := DeepUi.hbox(_block, 3)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DeepUi.icon(chip_row, "shield", 11, Color("9cc4ff")).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label = DeepUi.label(chip_row, "", 11, Color("cfe2ff"))
	_block_label.add_theme_font_override("font", DeepUi.bold_font())
	_block.visible = false
	Tips.attach(_block, func() -> Control: return Plates.words("Block", "Soaks %s damage before its health." % _block_label.text, "", DeepUi.BLOCK), {"tone": DeepUi.BLOCK})
	resized.connect(_place_block)
	_over.resized.connect(_place_block)
	_style()
	visible = false

func _place_block() -> void:
	## Over the panel's top right corner, half out over its edge, in the overlay's own frame
	## (which starts inside the panel's margins: 14 in, 12 down).
	if _block == null or _over == null:
		return
	_block.reset_size()
	_block.position = Vector2(size.x - _block.size.x - 10.0, -_block.size.y * 0.5 - 2.0) - _over.position

func _process(_delta: float) -> void:
	## Rich text is measured at no width until its row is laid out, and stands the ledger tall
	## for that frame: once the words have their width, it shrinks back to what they need.
	if visible and size.y > get_combined_minimum_size().y + 0.5:
		reset_size()

func reset() -> void:
	enemy_id = ""
	foe = {}
	lit = ""
	_key = ""
	_rows.clear()
	visible = false

func show_enemy(unit: Dictionary, _turn: int = 0) -> void:
	## The ledger on one creature, as your target.
	show_foe(unit, {}, "target", "")

func show_foe(unit: Dictionary, _battle: Dictionary, whose: String, lit_move: String) -> void:
	if enemy_id != str(unit.get("id", "")):
		page = 0
	foe = unit
	enemy_id = str(unit.get("id", ""))
	who = whose if WHO.has(whose) else "target"
	visible = true
	_who.text = str(WHO[who][0]).to_upper()
	_who.add_theme_color_override("font_color", WHO[who][1])
	_name.text = str(foe.get("name", "")).to_upper()
	_name.add_theme_color_override("font_color", Color("ffb0a0") if bool(foe.get("warden", false)) else DeepUi.PAPER)
	_dice_words.text = Look.dice_words(foe).to_upper()
	var max_hp: int = maxi(1, int(foe.get("max_hp", 1)))
	var hp: int = maxi(0, int(foe.get("hp", 0)))
	var block: int = int(foe.get("block", 0))
	_bar.show_health(float(hp) / float(max_hp), "%s / %s" % [DeepUi.number(hp), DeepUi.number(max_hp)], clampf(float(block) / float(max_hp), 0.0, 0.4))
	_block.visible = block > 0
	_block_label.text = DeepUi.number(block)
	_place_block()
	var key: String = "%s|%s|%s|%s|%d" % [enemy_id, str(Look.groups(foe)), str(Look.moves(foe).map(func(m: Dictionary) -> String: return str(m.get("name", "")) + Look.text(foe, m))),
		str(Look.traits(foe).map(func(c: Dictionary) -> String: return str(c.get("key", "")))), roundi(max_height)]
	if key != _key:
		_key = key
		_build()
	set_lit(lit_move)
	_style()
	reset_size()

func _style() -> void:
	var key: String = who
	if key == _style_key:
		return
	_style_key = key
	var line: Color = Look.PILL_LINE
	var width: int = 2
	if who == "acting":
		line = DeepUi.BAD
		width = 3
	elif who == "target":
		line = DeepUi.ACCENT
		width = 3
	elif who == "looking":
		line = Tag.HOVER_LINE
	var style := DeepUi.ledger(FILL, line, 12, 12, width, 4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	if who == "acting":
		style.shadow_color = Color(DeepUi.BAD, 0.3)
		style.shadow_size = 12
		style.shadow_offset = Vector2.ZERO
	add_theme_stylebox_override("panel", style)

func set_lit(move_name: String) -> void:
	## The row of the face that has just landed is lit; the rest are not. Read a die at a time,
	## the ledger turns to the die that face is on.
	lit = move_name
	if paged and not move_name.is_empty() and not _rows.has(move_name) and DeepUi.phone:
		## The phone's pages are a die's parts: the one that holds the move.
		for at in range(_parts.size()):
			if _parts[at].items.any(func(item: Dictionary) -> bool: return str(item.get("name", "")) == move_name):
				page = at
				_build()
				break
	elif paged and not move_name.is_empty() and not _rows.has(move_name):
		var groups: Array = Look.groups(foe)
		for at in range(groups.size()):
			if groups[at].moves.any(func(m: Dictionary) -> bool: return str(m.move) == move_name):
				page = at
				_build()
				break
	for name in _rows:
		Look.set_lit(_rows[name], str(name) == move_name and not move_name.is_empty())

func row_for(move_name: String) -> Control:
	return _rows.get(move_name, null)

func rows() -> Dictionary:
	return _rows

# --- the rows ------------------------------------------------------------------------------------

## The three ways the rows are laid, roomiest first: the name over the words; one line a move;
## one line a move, a die at a time (a Warden with three dice read at a small window's text).
const ROOMY: int = 0
const DENSE: int = 1
const PAGED: int = 2
## A die at a time: which (on the phone, which of `_parts`).
var page: int = 0
var paged: bool = false

func _build() -> void:
	var groups: Array = Look.groups(foe)
	var room: float = max_height - 6.0
	var mode: int = ROOMY
	if DeepUi.phone:
		_build_phone(groups, room)
		return
	if _estimate(ROOMY) > room:
		mode = DENSE if _estimate(DENSE) <= room or groups.size() < 2 else PAGED
	dense = mode != ROOMY
	paged = mode == PAGED
	page = clampi(page, 0, maxi(0, groups.size() - 1))
	DeepUi.clear(_list)
	_rows.clear()
	if paged:
		_tabs(groups)
	for at in range(groups.size()):
		if paged and at != page:
			continue
		var group: Dictionary = groups[at]
		if groups.size() > 1 and not paged:
			var sub := DeepUi.label(_list, _group_words(group).to_upper(), 10, DeepUi.MUTED)
			sub.add_theme_font_override("font", DeepUi.bold_font())
		for entry in group.moves:
			var move: Dictionary = Look.move_of(foe, str(entry.move))
			if move.is_empty():
				move = {"name": str(entry.move), "mark": str(entry.mark), "kind": str(entry.kind)}
			_rows[str(entry.move)] = Look.row(_list, foe, move, int(entry.count), int(group.faces), "", dense)
	for move in Look.matches(foe):
		_rows[str(move.get("name", ""))] = Look.row(_list, foe, move, 0, 0, Look.match_note(move), dense)
	for extra in Look.extras(foe):
		var move: Dictionary = extra.move
		_rows[str(move.get("name", ""))] = Look.row(_list, foe, move, 0, 0, str(extra.note), dense)
	var traits: Array = Look.traits(foe)
	if not traits.is_empty():
		var rule := DeepUi.rule(_list, Look.PILL_LINE)
		rule.custom_minimum_size.y = 2
		for chip in traits:
			Look.trait_row(_list, foe, chip, dense)
	if not lit.is_empty():
		for name in _rows:
			Look.set_lit(_rows[name], str(name) == lit)

# --- the phone's pages ---------------------------------------------------------------------------

## The phone reads a move on two lines (H1: its name, then its words wrapped under it), so a
## Warden's die can stand the ledger taller than the room over the dock (the Drill's treads, five
## moves, stood it over the dice tray). The phone's pages, then (November 16, 2026): every die on
## one when it all fits; else a die at a time (its tabs); and a die whose rows still stand too
## tall is read in parts, the key at the strip's end ("1/2 ›") turning to its next. Every page is
## held to the room: the ledger never stands over the dock. Each part is {die (-1: every die),
## items, at (its place among its die's parts), of (how many parts its die has)}, an item as
## `_phone_items` gives it.
var _parts: Array = []
## The gap between the list's rows (its separation).
const LIST_GAP: float = 5.0

func _build_phone(groups: Array, room: float) -> void:
	_parts = _phone_parts(groups, room)
	paged = _parts.size() > 1
	dense = true
	page = clampi(page, 0, _parts.size() - 1)
	DeepUi.clear(_list)
	_rows.clear()
	var part: Dictionary = _parts[page]
	if paged:
		_phone_strip(groups, part)
	var ruled: bool = false
	for item in part.items:
		match str(item.kind):
			"die":
				var sub := DeepUi.label(_list, _group_words(item.group).to_upper(), 10, DeepUi.MUTED)
				sub.add_theme_font_override("font", DeepUi.bold_font())
			"move":
				_rows[str(item.name)] = Look.line_row(_list, foe, item.move, int(item.pips), int(item.faces), str(item.note))
			"trait":
				if not ruled:
					ruled = true
					var rule := DeepUi.rule(_list, Look.PILL_LINE)
					rule.custom_minimum_size.y = 2
				Look.trait_line(_list, foe, item.chip)
	if not lit.is_empty():
		for name in _rows:
			Look.set_lit(_rows[name], str(name) == lit)

func _phone_parts(groups: Array, room: float) -> Array:
	## The pages the phone's ledger is read in, each held to `room`.
	var head: float = _phone_head_h()
	var whole: Array = _phone_items(groups, -1)
	if head + _items_h(whole) <= room:
		return [{"die": -1, "items": whole, "at": 0, "of": 1}]
	var left: float = room - head - _phone_strip_h() - LIST_GAP
	var parts: Array = []
	for die in range(maxi(1, groups.size())):
		var packed: Array = _pack(_phone_items(groups, die if groups.size() > 1 else -1), left)
		for at in range(packed.size()):
			parts.append({"die": die if groups.size() > 1 else -1, "items": packed[at], "at": at, "of": packed.size()})
	return parts

func _phone_items(groups: Array, die: int) -> Array:
	## What a page of the phone's ledger lists, in order, each with how tall it stands: one die's
	## moves (`die`), or every die's under its name (-1, more than one die); then the moves no
	## face carries (the matches, the called moves) and the traits, as every page lists them.
	var items: Array = []
	for at in range(groups.size()):
		if die >= 0 and at != die:
			continue
		var group: Dictionary = groups[at]
		if die < 0 and groups.size() > 1:
			items.append({"kind": "die", "group": group, "h": _label_h(DeepUi.bold_font(), DeepUi.readable(10))})
		for entry in group.moves:
			var move: Dictionary = Look.move_of(foe, str(entry.move))
			if move.is_empty():
				move = {"name": str(entry.move), "mark": str(entry.mark), "kind": str(entry.kind)}
			items.append({"kind": "move", "name": str(entry.move), "move": move, "pips": int(entry.count), "faces": int(group.faces), "note": "", "h": _phone_row_h(move, "")})
	for move in Look.matches(foe):
		items.append({"kind": "move", "name": str(move.get("name", "")), "move": move, "pips": 0, "faces": 0, "note": Look.match_note(move), "h": _phone_row_h(move, Look.match_note(move))})
	for extra in Look.extras(foe):
		var move: Dictionary = extra.move
		items.append({"kind": "move", "name": str(move.get("name", "")), "move": move, "pips": 0, "faces": 0, "note": str(extra.note), "h": _phone_row_h(move, str(extra.note))})
	for chip in Look.traits(foe):
		items.append({"kind": "trait", "chip": chip, "h": _phone_trait_h(chip)})
	return items

func _items_h(items: Array) -> float:
	## How tall these items stand in the list: each, the gaps between them, and the rule over
	## the traits.
	if items.is_empty():
		return 0.0
	var tall: float = LIST_GAP * float(items.size() - 1)
	var ruled: bool = false
	for item in items:
		tall += float(item.h)
		if str(item.kind) == "trait" and not ruled:
			ruled = true
			tall += 2.0 + LIST_GAP
	return tall

func _pack(items: Array, left: float) -> Array:
	## The items in as few parts as hold them, each standing no taller than `left`, as even as
	## the parts allow (three and two, not four and one).
	var greedy: Array = []
	var current: Array = []
	for item in items:
		if not current.is_empty() and _items_h(current + [item]) > left:
			greedy.append(current)
			current = []
		current.append(item)
	if not current.is_empty() or greedy.is_empty():
		greedy.append(current)
	if greedy.size() < 2:
		return greedy
	var each: int = ceili(float(items.size()) / float(greedy.size()))
	var even: Array = []
	for start in range(0, items.size(), each):
		var slice: Array = items.slice(start, mini(items.size(), start + each))
		if _items_h(slice) > left:
			return greedy
		even.append(slice)
	return even if even.size() == greedy.size() else greedy

func _phone_head_h() -> float:
	## How tall the ledger's head stands, from the nodes themselves (none of them wraps): the
	## panel's margins, whose it is, the name and its dice, the bar, and the gap under each.
	var style: StyleBox = get_theme_stylebox("panel")
	var tall: float = (style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)) if style != null else 24.0
	tall += _who.get_combined_minimum_size().y + 6.0
	tall += _name.get_parent().get_combined_minimum_size().y + 6.0
	tall += _bar.get_combined_minimum_size().y + 6.0
	return tall

func _phone_strip_h() -> float:
	## The strip of tabs and the parts key: a button's text and its margins.
	return _label_h(DeepUi.text_face(DeepUi.readable(11)), DeepUi.readable(11)) + 4.0 + 4.0

func _phone_row_h(move: Dictionary, note: String) -> float:
	## A move's row (`Look.line_row`): its name line (the mark, the name, the pips or a note),
	## then its words wrapped at the row's width, two lines at the most, and the row's margins.
	var line: float = maxf(DeepUi.pt(12), _label_h(DeepUi.bold_font(), DeepUi.readable(12)))
	if not note.is_empty():
		line = maxf(line, _label_h(DeepUi.text_face(DeepUi.readable(11)), DeepUi.readable(11)))
	var inner: float = width() - 28.0 - float(Look.ROW_RULE + Look.ROW_PAD_LEFT + Look.ROW_PAD_RIGHT)
	return 6.0 + line + _phone_words_h(Look.text(foe, move).trim_suffix("."), inner)

func _phone_trait_h(chip: Dictionary) -> float:
	## A trait (`Look.trait_line`): its mark and name on a line, the gap, its meaning under them.
	var said: String = str(chip.get("text", ""))
	if said.is_empty():
		said = Look.meaning(str(chip.get("title", "")), foe)
	var line: float = maxf(DeepUi.pt(12), _label_h(DeepUi.bold_font(), DeepUi.readable(12)))
	return line + LIST_GAP + _phone_words_h(said, width() - 28.0)

func _phone_words_h(said: String, across: float) -> float:
	## Words set as `Look._two_lines` sets them: the phone's words, wrapped at `across`, two
	## lines at the most (an empty label still stands a line tall).
	var size: int = DeepUi.readable(11)
	var face: Font = DeepUi.text_face(size)
	var lines: int = mini(2, _lines([[DeepUi.phone_words(said), face]], size, across)) if not said.is_empty() else 1
	var spacing: float = float(get_theme_constant(&"line_spacing", &"Label"))
	return float(lines) * _label_h(face, size) + float(lines - 1) * spacing

func _phone_strip(groups: Array, part: Dictionary) -> void:
	## The phone's strip: a tab a die (more than one), the one being read lit; then, for a die
	## read in parts, the key that turns to its next part ("1/2 ›", round to the first).
	var strip := DeepUi.hbox(_list, 4)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	strip.name = "Pages"
	var die: int = int(part.die)
	if groups.size() > 1:
		for at in range(groups.size()):
			var first: int = _parts.find_custom(func(p: Dictionary) -> bool: return int(p.die) == at)
			_tab(strip, _group_words(groups[at]), at == die, first)
	if int(part.of) > 1:
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_child(pad)
		var next: int = page + 1 if int(part.at) + 1 < int(part.of) else page - int(part.at)
		var key := _tab(strip, "%d/%d ›" % [int(part.at) + 1, int(part.of)], false, next)
		key.name = "Parts"

func _tab(strip: HBoxContainer, words: String, lit_now: bool, to: int) -> Button:
	## One of the strip's buttons: lit for the page being read, else plain; a press turns to
	## page `to`. A finger's reach on the phone (28 points tall) without standing any taller.
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	DeepUi.set_text_size(button, 11)
	if lit_now:
		DeepUi.ledger_primary(button)
	else:
		DeepUi.ledger_button(button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 3)
	for side in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = button.get_theme_stylebox(side)
		if box is StyleBoxFlat:
			(box as StyleBoxFlat).content_margin_left = 8
			(box as StyleBoxFlat).content_margin_right = 8
			(box as StyleBoxFlat).content_margin_top = 2
			(box as StyleBoxFlat).content_margin_bottom = 2
	button.pressed.connect(func() -> void:
		page = to
		_build()
		reset_size())
	strip.add_child(button)
	if DeepUi.phone:
		var least: float = DeepUi.pt(DeepUi.FINGER_LEAST)
		var drawn: Vector2 = button.get_combined_minimum_size()
		DeepUi.reach(button, Vector2(maxf(2.0, (least - drawn.x) * 0.5 + 1.0), maxf(0.0, (least - drawn.y) * 0.5 + 1.0)))
	return button

static func _group_words(group: Dictionary) -> String:
	## "claws · d8", "d6 ×3".
	var label: String = str(group.get("label", ""))
	return (label + " · " if not label.is_empty() else "") + str(group.shape).to_lower() + (" ×%d" % int(group.count) if int(group.count) > 1 else "")

func _tabs(groups: Array) -> void:
	## A button a die, the one being read lit.
	var strip := DeepUi.hbox(_list, 4)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	for at in range(groups.size()):
		_tab(strip, _group_words(groups[at]), at == page, at)

func _estimate(mode: int) -> float:
	## How tall the ledger stands with its rows laid one of the three ways, worked out from the
	## fonts and the words themselves, wrapped as the text server wraps them (`_lines`): rich
	## text is measured at no width until it has been laid out, so it is not asked.
	var bold: Font = DeepUi.bold_font()
	var small: int = DeepUi.readable(10)
	## The panel's margins, and its lines one under another six apart: whose, the name and its
	## dice, the bar, the rows (the block chip hangs over the corner and takes no line).
	var tall: float = 24.0
	tall += _label_h(bold, small) + 6.0
	tall += maxf(_label_h(bold, DeepUi.readable(17)), _label_h(bold, small) + 2.0) + 6.0
	tall += maxf(18.0, float(DeepUi.readable(10)) + 5.0) + 6.0
	## The rows' last gap is not there.
	tall -= 5.0
	var rows: Array = []
	var groups: Array = Look.groups(foe)
	var tallest: Array = []
	var tallest_h: float = -1.0
	for group in groups:
		var these: Array = []
		for entry in group.moves:
			these.append([Look.move_of(foe, str(entry.move)), _pips_w(int(entry.count))])
		if mode == PAGED:
			var h: float = _rows_height(these, true)
			if h > tallest_h:
				tallest_h = h
				tallest = these
		else:
			if groups.size() > 1:
				tall += _label_h(bold, small) + 5.0
			rows.append_array(these)
	if mode == PAGED:
		rows = tallest
		## The buttons a die.
		tall += _label_h(bold, DeepUi.readable(11)) + 8.0 + 5.0
	var note_font: Font = DeepUi.text_face(DeepUi.readable(11))
	for move in Look.matches(foe):
		rows.append([move, note_font.get_string_size(Look.match_note(move), HORIZONTAL_ALIGNMENT_LEFT, -1, DeepUi.readable(11)).x])
	for extra in Look.extras(foe):
		rows.append([extra.move, note_font.get_string_size(str(extra.note), HORIZONTAL_ALIGNMENT_LEFT, -1, DeepUi.readable(11)).x])
	tall += _rows_height(rows, mode != ROOMY)
	var traits: Array = Look.traits(foe)
	if not traits.is_empty():
		tall += 2.0 + 5.0
		var size: int = DeepUi.readable(12 if mode != ROOMY else 13)
		for chip in traits:
			tall += _label_h(bold, DeepUi.readable(14)) + 2.0 + 5.0
			var said: String = str(chip.get("text", ""))
			if not said.is_empty():
				tall += float(_lines([[said, DeepUi.text_face(size)]], size, INNER)) * _line_h(size)
	return tall

## How wide the rows' words may run: the panel's inside, less a row's rule and margins.
const INNER: float = WIDTH - 28.0 - 17.0

func _rows_height(rows: Array, one_line: bool) -> float:
	var bold: Font = DeepUi.bold_font()
	var size: int = DeepUi.readable(13)
	var face: Font = DeepUi.text_face(size)
	var tall: float = 0.0
	for pair in rows:
		var move: Dictionary = pair[0]
		var words: String = Look.text(foe, move)
		## What stands beside the words: the pips, or a note, and the gap before it.
		var across: float = INNER - (float(pair[1]) + 8.0 if float(pair[1]) > 0.0 else 0.0)
		if one_line:
			var parts: Array = [[str(move.get("name", "")), bold]]
			if not words.is_empty():
				parts.append(["  " + words, face])
			tall += float(_lines(parts, size, across - 20.0)) * _line_h(size) + 6.0 + 5.0
		else:
			tall += _label_h(bold, DeepUi.readable(14)) + 1.0 + 10.0 + 5.0
			if not words.is_empty():
				tall += float(_lines([[words, face]], size, across)) * _line_h(size)
	return tall

static func _pips_w(count: int) -> float:
	var across: int = mini(count, Look.Pips.PER_LINE)
	return float(across) * Look.Pips.DOT + float(maxi(0, across - 1)) * Look.Pips.GAP

static func _label_h(font: Font, size: int) -> float:
	return ceilf(font.get_height(size))

static func _line_h(size: int) -> float:
	return ceilf(maxf(DeepUi.bold_font().get_height(size), DeepUi.text_face(size).get_height(size)))

static func _lines(parts: Array, size: int, width: float) -> int:
	## How many lines these words take wrapped at this width, as the text server breaks them.
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(40.0, width)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	for part in parts:
		paragraph.add_string(str(part[0]), part[1], size)
	return maxi(1, paragraph.get_line_count())
