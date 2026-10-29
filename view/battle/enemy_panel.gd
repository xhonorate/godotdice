extends PanelContainer
## The ledger (the plates rethink, artifact NMAGkwooypHHUKxsB4tR71, the owner's final room):
## everything about one creature in a panel on the side of the room away from it. Whose it is
## (your target, the one under the pointer, the one acting), its name and how many faces its
## dice have, its health and block; then its dice, each face's move as a row: a rule and a mark
## in the colour of its kind, its name, its words with their keywords explained on hover, and
## its share of the die as pips, one dot a face. Then what its faces make together, what the
## fight calls it to do, and what it always is. The face it has just landed is lit. There is no
## die in it: the die is on the creature's tag, and a right-click turns it over in a window.
##
## A creature whose rows would stand the ledger taller than `max_height` reads them one line a
## move (`dense`), so it never needs a scroll bar.

const Look = preload("res://view/battle/creature_look.gd")
const Tag = preload("res://view/battle/creature_tag.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")

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
var _block_row: HBoxContainer
var _block_label: Label
var _list: VBoxContainer
var _foot: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
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
	_block_row = DeepUi.hbox(box, 6)
	_block_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", DeepUi.capsule(chip, Color("14223a"), DeepUi.BLOCK, 2, 6, 0))
	_block_row.add_child(chip)
	var chip_row := DeepUi.hbox(chip, 3)
	DeepUi.icon(chip_row, "shield", 11, Color("9cc4ff")).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label = DeepUi.label(chip_row, "", 11, Color("cfe2ff"))
	_block_label.add_theme_font_override("font", DeepUi.bold_font())
	_list = DeepUi.vbox(box, 5)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_foot = DeepUi.label(box, "Right-click it to turn its die over", 10, DeepUi.MUTED)
	_style()
	visible = false

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
	_block_row.visible = block > 0
	_block_label.text = DeepUi.number(block)
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
	if paged and not move_name.is_empty() and not _rows.has(move_name):
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
## A die at a time: which.
var page: int = 0
var paged: bool = false

func _build() -> void:
	var groups: Array = Look.groups(foe)
	var room: float = max_height - 6.0
	var mode: int = ROOMY
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
	_foot.visible = _estimate(mode) + _foot_h() <= room
	if not lit.is_empty():
		for name in _rows:
			Look.set_lit(_rows[name], str(name) == lit)

static func _group_words(group: Dictionary) -> String:
	## "claws · d8", "d6 ×3".
	var label: String = str(group.get("label", ""))
	return (label + " · " if not label.is_empty() else "") + str(group.shape).to_lower() + (" ×%d" % int(group.count) if int(group.count) > 1 else "")

func _tabs(groups: Array) -> void:
	## A button a die, the one being read lit.
	var strip := DeepUi.hbox(_list, 4)
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	for at in range(groups.size()):
		var button := Button.new()
		button.text = _group_words(groups[at])
		button.focus_mode = Control.FOCUS_NONE
		DeepUi.set_text_size(button, 11)
		if at == page:
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
			page = at
			_build()
			reset_size())
		strip.add_child(button)

func _estimate(mode: int) -> float:
	## How tall the ledger stands with its rows laid one of the three ways, worked out from the
	## fonts and the words themselves, wrapped as the text server wraps them (`_lines`): rich
	## text is measured at no width until it has been laid out, so it is not asked.
	var bold: Font = DeepUi.bold_font()
	var small: int = DeepUi.readable(10)
	## The panel's margins, and its lines one under another six apart: whose, the name and its
	## dice, the bar, the block, the rows (the foot is reckoned apart: `_foot_h`).
	var tall: float = 24.0
	tall += _label_h(bold, small) + 6.0
	tall += maxf(_label_h(bold, DeepUi.readable(17)), _label_h(bold, small) + 2.0) + 6.0
	tall += maxf(18.0, float(DeepUi.readable(10)) + 5.0) + 6.0
	if int(foe.get("block", 0)) > 0:
		tall += _label_h(bold, DeepUi.readable(11)) + 6.0
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

static func _foot_h() -> float:
	return _label_h(DeepUi.text_face(DeepUi.readable(10)), DeepUi.readable(10)) + 6.0

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
