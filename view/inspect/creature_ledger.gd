extends RefCounted
## A creature's action dice read out the way the battle's ledger reads them (docs/CREATURE_DICE.md;
## the plates rethink, rounds one to eleven; view/battle/creature_look.gd draws the battle's):
## every die as rows, one a move: a rule and the face's mark in its kind's ink, the move's name
## and number, its words, and its share of the die as pips (one dot a face). After the dice
## comes what lands on no face of its own: faces that fire together (a match), moves waiting
## for a face to be etched to them or for the fight to call them, and the traits it carries.
## Keywords in the words are underlined, their meaning on hover.
##
## The close look (inspector.gd) and the Bestiary (bestiary_page.gd) read creatures here, and
## lay the rows out in pages (`pages`) so nothing scrolls. A row, its mark, its keywords and
## its pips are the battle's own (view/battle/creature_look.gd, `Look`): this file reads the
## creature out and lays its rows into pages.

const DiceView = preload("res://view/dice/dice_view.gd")
const FaceMarks = preload("res://view/dice/face_marks.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Look = preload("res://view/battle/creature_look.gd")

## The ink each kind of move is written in on the dark sheet (its faces' paint is
## DiceView.MOVE_TINTS), and the rest of the ledger's colours: the battle's.
const INK = Look.INK
const ROW_TEXT = Look.ROW_TEXT
const TRAIT_INK = Look.TRAIT_INK
const TRAIT_NAME = Look.TRAIT_NAME
const TRAIT_TEXT = Look.TRAIT_TEXT
const PILL_LINE = Look.PILL_LINE
## A row lit for the move the reader came to it by; an unlit row's faint fill on the sheet.
const LIT = Look.LIT
const IDLE := Color(1, 1, 1, 0.02)

const NAME_TEXT = Look.NAME_SIZE
const WORD_TEXT = Look.WORD_SIZE
const NOTE_TEXT = Look.NOTE_SIZE
const MARK := 15.0
## The column the pips (or a note) stand in, the same on every row so the words line up.
const RIGHT := 56.0
## A row's rule and its insides: the rule, the gap after it, the right margin, top and bottom.
const RULE = Look.ROW_RULE
const PAD_LEFT = Look.ROW_PAD_LEFT
const PAD_RIGHT = Look.ROW_PAD_RIGHT
const PAD_Y = Look.ROW_PAD_Y
const ROW_GAP = Look.ROW_GAP
const ROWS_APART := 5

## The words in a move's text that say a rule of their own (underlined, their meaning on hover)
## and the colours of blows, block and healing: the battle's.
const KEYWORDS = Look.KEYWORDS
const TONES = Look.TONES

# --- reading the creature --------------------------------------------------------------------

static func groups(foe: Dictionary) -> Array:
	## The dice it throws now (its own, as Dread or a grown head has them), each with its moves
	## and their face counts (`DeepCreatures.face_share`), like dice side by side taken as one:
	## [{die, count, index, shape, label, faces, moves: [{move, count, mark, kind}]}].
	var dice: Array = DeepCreatures.effective_dice(foe)
	var shares: Array = DeepCreatures.face_share({"dice": dice})
	var out: Array = []
	for at in range(dice.size()):
		var share: Dictionary = shares[at]
		if share.moves.is_empty():
			continue
		var names: Array = dice[at].get("faces", []).map(func(face: Variant) -> String: return str(face.get("move", "")) if face is Dictionary else str(face))
		var signature: String = "%s|%s|%s" % [str(share.shape), str(share.label), ",".join(names)]
		if not out.is_empty() and str(out.back().signature) == signature:
			out.back().count += 1
			continue
		out.append({"signature": signature, "die": dice[at], "count": 1, "index": at, "shape": str(share.shape), "label": str(share.label),
			"faces": int(share.faces), "moves": share.moves})
	return out

static func group_name(group: Dictionary, all: Array) -> String:
	## What its tab says: the die's own label ("Lamp", "Pick"), or "Its die" / "Its dice".
	if not str(group.label).is_empty():
		return str(group.label).capitalize()
	var unlabelled: Array = all.filter(func(g: Dictionary) -> bool: return str(g.label).is_empty())
	if unlabelled.size() > 1:
		return "Die %d" % (unlabelled.find(group) + 1)
	return "Its dice" if int(group.count) > 1 else "Its die"

static func group_caption(group: Dictionary, all: Array) -> String:
	## Over its rows: which die, its shape, and how many faces ("Lamp die · d6 · 6 faces").
	var shape: String = str(group.shape).to_lower()
	var name: String = group_name(group, all)
	if not str(group.label).is_empty():
		name += " die"
	if int(group.count) > 1:
		return "%s · %s ×%d · %d faces each" % [name, shape, int(group.count), int(group.faces)]
	return "%s · %s · %d faces" % [name, shape, int(group.faces)]

static func extras(foe: Dictionary) -> Dictionary:
	## What its dice do not show face by face: {matches, waiting, called, traits}. A waiting
	## move is [move, from]: the move that puts it on a face ("Snatch"), or "".
	var moves: Array = DeepCreatures.moves_for(foe)
	var on_faces: Dictionary = {}
	for die in DeepCreatures.effective_dice(foe):
		for face in die.get("faces", []):
			if face is Dictionary:
				on_faces[str(face.get("move", ""))] = true
	var out: Dictionary = {"matches": [], "waiting": [], "called": [], "traits": []}
	for move in moves:
		var kind: String = str(move.get("trigger", {}).get("kind", "face"))
		var name: String = str(move.get("name", ""))
		if kind == "match":
			out.matches.append(move)
		elif kind == "face":
			if not on_faces.has(name):
				out.waiting.append([move, _source(moves, name)])
		else:
			out.called.append(move)
	var traits: Dictionary = DeepCreatures.traits_for(foe)
	var keys: Array = traits.keys()
	keys.sort()
	for key in keys:
		out.traits.append([str(key), traits[key]])
	return out

static func _source(moves: Array, name: String) -> String:
	## The move that etches a face to `name`, or grows a die with it.
	for move in moves:
		for effect in move.get("effects", []):
			var kind: String = str(effect.get("kind", ""))
			if (kind == "etch" and str(effect.get("to", "")) == name) or (kind == "grow_faces" and name in effect.get("faces", [])):
				return str(move.get("name", ""))
	return ""

static func number(foe: Dictionary, move: Dictionary) -> String:
	## The number beside its name: its words' first figure as this creature deals it here (the
	## `{0}` of "{0} damage", its Strength and the mine's weight counted in), or "" for a move
	## whose words carry none.
	var text: String = str(move.get("text", ""))
	var shown: Array = DeepCreatures.display_moves(foe, [move])
	var effects: Array = shown[0].get("effects", []) if not shown.is_empty() else []
	for at in range(effects.size()):
		if text.contains("{%d}" % at) or (at == 0 and text.contains("{n}")):
			return str(DeepRules.amount(effects[at].get("amount", 0), {"unit": foe}))
	return ""

static func trait_line(foe: Dictionary, key: String, value: Variant) -> Array:
	## [glyph, name, words] for one trait it carries.
	var chip: Dictionary = EffectChips.trait_entry(key, value)
	var words: String = str(chip.text)
	if words.is_empty():
		words = meaning(str(chip.title), foe)
	return [str(chip.glyph), str(chip.title), words]

static func match_note(move: Dictionary) -> String:
	## Beside a match, where a face's pips would be: "both dice", "3 dice", or "together".
	return Look.match_note(move)

static func on_page(spec: Dictionary, name: String) -> bool:
	## Whether a page (`pages`) shows this move.
	for item in spec.get("items", []):
		if str(item.get("name", "")) == name:
			return true
	return false

# --- pages -----------------------------------------------------------------------------------

static func pages(foe: Dictionary, budget: float, width: float) -> Array:
	## Its rows laid into pages no taller than `budget` at `width` (as wide as the rows stand):
	## each die (or set of like dice) on a page of its own, run on to a second where it would
	## not fit, and what lands on no face after the last die, there if it fits or on a page of
	## its own. [{name, group (or {}), items: [{kind, ...}]}]
	var out: Array = []
	var all: Array = groups(foe)
	for group in all:
		var name: String = group_name(group, all)
		var items: Array = [ {"kind": "caption", "text": group_caption(group, all)}]
		for entry in group.moves:
			items.append({"kind": "face", "name": str(entry.move), "entry": entry, "faces": int(group.faces)})
		var chunk: int = 0
		for part in _split(items, foe, budget, width):
			out.append({"name": name if chunk == 0 else "%s · %d" % [name, chunk + 1], "group": group, "items": part})
			chunk += 1
	var loose: Dictionary = extras(foe)
	var rest: Array = []
	if not loose.matches.is_empty():
		rest.append({"kind": "section", "text": "Faces together"})
		for move in loose.matches:
			rest.append({"kind": "match", "name": str(move.name), "move": move})
	if not loose.waiting.is_empty() or not loose.called.is_empty():
		rest.append({"kind": "section", "text": "On no face"})
		for pair in loose.waiting:
			rest.append({"kind": "waiting", "name": str(pair[0].name), "move": pair[0], "from": str(pair[1])})
		for move in loose.called:
			rest.append({"kind": "called", "name": str(move.name), "move": move})
	if not loose.traits.is_empty():
		rest.append({"kind": "section", "text": "What it is"})
		for pair in loose.traits:
			rest.append({"kind": "trait", "key": str(pair[0]), "value": pair[1]})
	if rest.is_empty():
		return out
	if not out.is_empty() and height(out.back().items + rest, foe, width) <= budget:
		out.back().items.append_array(rest)
		return out
	var chunk: int = 0
	for part in _split(rest, foe, budget, width):
		out.append({"name": "More" if chunk == 0 else "More · %d" % (chunk + 1), "group": {}, "items": part})
		chunk += 1
	return out

static func _split(items: Array, foe: Dictionary, budget: float, width: float) -> Array:
	## Items into runs no taller than `budget`; a heading never ends a run.
	var runs: Array = [[]]
	var tall: float = 0.0
	for at in range(items.size()):
		var item: Dictionary = items[at]
		var cost: float = item_height(item, foe, width)
		if item.kind in ["section", "caption"] and at + 1 < items.size():
			cost += item_height(items[at + 1], foe, width)
		if not runs.back().is_empty() and tall + cost > budget:
			runs.append([])
			tall = 0.0
		runs.back().append(item)
		tall += item_height(item, foe, width)
	return runs

static func height(items: Array, foe: Dictionary, width: float) -> float:
	var total: float = 0.0
	for item in items:
		total += item_height(item, foe, width)
	return total

static func item_height(item: Dictionary, foe: Dictionary, width: float) -> float:
	## How tall one item stands at `width`, as it will be drawn, with the gap under it.
	match str(item.kind):
		"caption", "section":
			return _line(NOTE_TEXT) + 8.0 + ROWS_APART
		"trait":
			var line: Array = trait_line(foe, str(item.key), item.value)
			return _line(NAME_TEXT) + 2.0 + _lines(str(line[2]), width - 2.0 * PAD_Y, WORD_TEXT) * _line(WORD_TEXT) + ROWS_APART
	var move: Dictionary = item.get("move", {})
	if move.is_empty():
		move = DeepCreatures.move_in(DeepCreatures.moves_for(foe), str(item.name))
	var words: String = DeepCreatures.move_text(foe, move)
	return _line(NAME_TEXT) + 1.0 + _lines(words, words_width(width), WORD_TEXT) * _line(WORD_TEXT) + 2.0 * PAD_Y + ROWS_APART

static func words_width(width: float) -> float:
	## What a row's words have of its width, the rule, margins and pips taken off.
	return maxf(120.0, width - RULE - PAD_LEFT - PAD_RIGHT - ROW_GAP - RIGHT)

static func _font(size: int) -> Font:
	return DeepUi.text_face(DeepUi.readable(size))

static func _line(size: int) -> float:
	return _font(size).get_height(DeepUi.readable(size))

static func _lines(text: String, width: float, size: int) -> int:
	var tall: float = _font(size).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, DeepUi.readable(size)).y
	return maxi(1, int(ceil(tall / maxf(1.0, _line(size)) - 0.05)))

# --- drawing ---------------------------------------------------------------------------------

static func fill(parent: Node, foe: Dictionary, spec: Dictionary, width: float, opts: Dictionary = {}) -> VBoxContainer:
	## One page's rows into `parent`. `opts.lit` is a move's name to light; `opts.view` the
	## DiceView showing this page's die, which turns to a row's face under the pointer.
	var box := DeepUi.vbox(parent, ROWS_APART)
	## At least `width`, the width its pages were measured at; wider where there is room.
	box.custom_minimum_size.x = width
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var view: Control = opts.get("view", null)
	var lit: String = str(opts.get("lit", ""))
	var faces: Array = spec.group.die.get("faces", []) if spec.get("group", {}) is Dictionary and spec.group.has("die") else []
	for item in spec.get("items", []):
		match str(item.kind):
			"caption":
				var cap := DeepUi.label(box, str(item.text).to_upper(), NOTE_TEXT - 1, DeepUi.MUTED)
				cap.add_theme_font_override("font", DeepUi.bold_font())
			"section":
				var head := DeepUi.label(box, str(item.text).to_upper(), NOTE_TEXT - 1, DeepUi.ACCENT)
				head.add_theme_font_override("font", DeepUi.bold_font())
			"face":
				var entry: Dictionary = item.entry
				var move: Dictionary = DeepCreatures.move_in(DeepCreatures.moves_for(foe), str(entry.move))
				if move.is_empty():
					move = {"name": str(entry.move), "mark": str(entry.mark), "kind": str(entry.kind)}
				var row := move_row(box, foe, move, width, str(item.name) == lit, int(entry.count), int(item.faces))
				_turns(row, view, _faces_of(faces, str(entry.move)))
			"match":
				move_row(box, foe, item.move, width, str(item.name) == lit, 0, 0, match_note(item.move))
			"waiting":
				var from: String = str(item.get("from", ""))
				move_row(box, foe, item.move, width, str(item.name) == lit, 0, 0, "", ("from " + from) if not from.is_empty() else "no face yet")
			"called":
				var note: String = {"emerge": "as it comes up", "on_death": "when it dies", "action_begin": "each action"}.get(str(item.move.get("trigger", {}).get("kind", "")),
					DeepCreatures.trigger_words(item.move, foe).to_lower())
				move_row(box, foe, item.move, width, str(item.name) == lit, 0, 0, "", note)
			"trait":
				trait_row(box, foe, str(item.key), item.value, width)
	return box

static func _faces_of(faces: Array, name: String) -> Array:
	var at: Array = []
	for index in range(faces.size()):
		if faces[index] is Dictionary and str(faces[index].get("move", "")) == name:
			at.append(index)
	return at

static func _turns(row: Control, view: Control, at: Array) -> void:
	## Under the pointer a face's row turns the die beside it to that face; clicked again, to
	## the next face carrying the same move.
	if view == null or not is_instance_valid(view) or at.is_empty():
		return
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var turn: Array = [0]
	row.mouse_entered.connect(func() -> void:
		if is_instance_valid(view):
			turn[0] = 0
			view.call("focus_face", int(at[0])))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(view):
			turn[0] += 1
			view.call("focus_face", int(at[turn[0] % at.size()])))

static func row_style(kind: String, lit: bool) -> StyleBoxFlat:
	return Look.row_style(kind, lit, false, IDLE)

static func move_row(parent: Node, foe: Dictionary, move: Dictionary, width: float, lit: bool = false, pips: int = 0, faces: int = 0, note: String = "", when: String = "") -> PanelContainer:
	## One move as the battle's ledger draws it (`Look.row`), with its number beside its name,
	## its pips in a column of their own so the words line up, and for a move on no face of its
	## own `when` it comes ("when it dies", "from Snatch").
	return Look.row(parent, foe, move, pips, faces, note, false, lit,
		{"figure": number(foe, move), "when": when, "right": RIGHT, "width": words_width(width), "mark": MARK, "idle": IDLE})

static func trait_row(parent: Node, foe: Dictionary, key: String, value: Variant, width: float) -> VBoxContainer:
	## A trait: its mark and name in violet with "always", and what it means.
	var line_words: Array = trait_line(foe, key, value)
	return Look.trait_row(parent, foe, {"glyph": line_words[0], "title": line_words[1], "text": line_words[2]}, false, maxf(120.0, width - 2.0 * PAD_Y))

static func mark(parent: Node, mark_name: String, edge: float, tint: Color) -> TextureRect:
	## A face's mark, white on clear, in `tint`.
	return Look.mark(parent, mark_name, edge, tint)

static func mark_texture(mark_name: String) -> Texture2D:
	return Look.mark_texture(mark_name)

static func mark_chip(parent: Node, mark_name: String, kind: String, edge: float) -> Control:
	## A face as the die wears it, small: its mark in ivory (slate on a dud) on its kind's paint.
	var chip := MarkChip.new(mark_name, kind, edge)
	parent.add_child(chip)
	return chip

# --- words ------------------------------------------------------------------------------------

static func meaning(word: String, foe: Dictionary = {}) -> String:
	## A keyword's meaning, with the creature's own number where its trait has one.
	return Look.meaning(word, foe)

static func words(parent: Node, text: String, size: int, color: Color, width: float, foe: Dictionary = {}) -> RichTextLabel:
	## Words with their keywords underlined (meaning on hover) and their blows, block and healing
	## in colour. Given its width: a rich label beside sized siblings draws nothing without one.
	return Look.words(parent, text, size, color, width, foe)

static func write(rtl: RichTextLabel, text: String, foe: Dictionary = {}) -> void:
	Look.write(rtl, text, foe)

# --- the die ---------------------------------------------------------------------------------

## How a die on a page first rests, by shape: a cube or a pyramid face on is a flat square or
## triangle, so it is turned a third of the way round and tipped toward the reader, three of
## its faces showing; the rounder dice show their neighbours face on and are only tipped.
const POSES := {"D4": Vector3(0.5, 0.45, 0.0), "D6": Vector3(0.45, 0.6, 0.0)}
const POSE := Vector3(-0.14, 0.17, 0.0)

static func die_view(die: Dictionary, edge: float, tint: Color = TRAIT_INK) -> Control:
	## A creature's die as a real solid in its matte faces and engraved marks, turned by hand.
	var view: Control = DiceView.new()
	view.custom_minimum_size = Vector2(edge, edge)
	view.call("enable_interaction")
	view.tooltip_text = "Drag to turn it over"
	view.ready.connect(func() -> void:
		view.call("configure", die, {}, false, false, tint)
		## Where the reader's hand starts it (the view keeps the turn it is given in these two).
		var turn: Vector3 = POSES.get(str(die.get("shape", "D6")).to_upper(), POSE)
		var pose: Quaternion = (Quaternion.from_euler(turn) * (view.call("orientation") as Quaternion)).normalized()
		if "_manual" in view and "_goal" in view:
			view.set("_manual", pose)
			view.set("_goal", pose), CONNECT_ONE_SHOT)
	return view

# --- the pieces -------------------------------------------------------------------------------

class MarkChip extends Control:
	## A face's mark on its kind's paint, ivory (slate on a dud), the way the die wears it.
	var face_mark: String
	var kind: String
	func _init(mark_name: String, move_kind: String, edge: float) -> void:
		face_mark = mark_name
		kind = move_kind if DiceView.MOVE_TINTS.has(move_kind) else "dud"
		custom_minimum_size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var edge: float = minf(size.x, size.y)
		var box := Rect2((size - Vector2(edge, edge)) * 0.5, Vector2(edge, edge))
		var fill := StyleBoxFlat.new()
		fill.bg_color = DiceView.MOVE_TINTS[kind]
		fill.set_corner_radius_all(maxi(2, int(edge * 0.2)))
		draw_style_box(fill, box)
		if face_mark.is_empty() or not FaceMarks.known(face_mark):
			return
		draw_texture_rect(FaceMarks.texture(face_mark), box.grow(-edge * 0.12), false, DiceView.DUD_INK if kind == "dud" else DiceView.MARK_INK)

## A move's share of its die, one dot a face: the battle's.
const Pips = Look.Pips
