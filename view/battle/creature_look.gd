extends RefCounted
## How a creature's action dice read in the room (docs/CREATURE_DICE.md; the plates rethink,
## artifact NMAGkwooypHHUKxsB4tR71, rounds one to eleven): the colours of a move's kind, its
## engraved mark, the one number it lands, and its words with the keywords that explain
## themselves on hover. The feet tags (creature_tag.gd), the ledger panel (enemy_panel.gd), the
## die window (creature_die_window.gd), and outside the fight the close look and the Bestiary
## (view/inspect/creature_ledger.gd) all draw a move from here, so one move reads the same
## wherever it is shown.

const FaceMarks = preload("res://view/dice/face_marks.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")

## A face's own paint, as the die is coloured (DiceView.MOVE_TINTS): the owner's "lighter and
## richer" set of round seven.
const FACE := {"attack": Color("d72d47"), "guard": Color("2c6ae8"), "meddle": Color("7f4dd1"),
	"mend": Color("3fb57a"), "ready": Color("f1bb25"), "dud": Color("4d5363")}
## The same kinds as ink on a dark plate: a pill's mark, a row's rule, a pip.
const INK := {"attack": Color("ff8f7e"), "guard": Color("7fb0ff"), "meddle": Color("c9a9ff"),
	"mend": Color("6fd69a"), "ready": Color("f0c860"), "dud": Color("9aa3b8")}
## A result pill's edge: what the move does, in the game's own keyword colours.
const EDGE := {"attack": Color("ff7a6b"), "guard": Color("6fa8ff"), "meddle": Color("b58cff"),
	"mend": Color("3fb56b"), "ready": Color("e2b23a"), "dud": Color("e2b23a")}
const PILL_FILL := Color("1c2232")
const PILL_LINE := Color("2f3752")
const ROW_TEXT := Color("dfe5f4")
const TRAIT_INK := Color("c8a8ff")
const TRAIT_NAME := Color("d7b8ff")
const TRAIT_TEXT := Color("c9b3f0")
const MATCH_LINE := Color("b58cff")
## A lit row (the face that just landed): a wash of the colour of a blow.
const LIT := Color(1.0, 0.478, 0.42, 0.16)
## How big a mark is baked for the interface: a size up from the largest it is drawn at.
const MARK_PX: int = 96

## The kinds of effect whose amount is the number a move wears on its pill. A count of
## creatures, a turn of stun or a die taken is not a number to read at a glance.
const NUMBERED: Array = ["damage", "block", "heal", "poison", "burn", "marked", "curse", "dulled", "festering", "scorched",
	"strength", "steal_gold", "regeneration", "spikes", "max_hp", "remove_block", "gold", "swell", "reflect", "empower_next"]

static var _marks: Dictionary = {}

static func kind_of(move: Dictionary) -> String:
	var kind: String = str(move.get("kind", move.get("move_kind", "attack")))
	return kind if INK.has(kind) else "attack"

static func ink(kind: String) -> Color:
	return INK.get(kind, INK.attack)

static func mark_texture(mark: String) -> Texture2D:
	## A face mark, white on clear, baked small enough for a pill and a row and kept.
	if mark.is_empty() or not FaceMarks.known(mark):
		mark = "f_sword"
	var cached: Texture2D = _marks.get(mark, null)
	if cached != null:
		return cached
	var image: Image = FaceMarks.raster(mark, MARK_PX)
	image.generate_mipmaps()
	var built := ImageTexture.create_from_image(image)
	_marks[mark] = built
	return built

static func mark(parent: Node, mark_name: String, edge: float, tint: Color) -> TextureRect:
	var image := TextureRect.new()
	image.texture = mark_texture(mark_name)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size = Vector2(edge, edge)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

static func release() -> void:
	_marks.clear()

# --- the moves -----------------------------------------------------------------------------------

static func moves(foe: Dictionary) -> Array:
	## The moves it fights with now, as it is written now: an echo that has just become
	## something else fights with that one's moves before its next action is prepared.
	return DeepCreatures.moves_for(foe)

static func move_of(foe: Dictionary, name: String) -> Dictionary:
	return DeepCreatures.move_in(moves(foe), name)

static func number(foe: Dictionary, move: Dictionary) -> String:
	## The one number a move wears: its first plain amount as this creature lands it here (the
	## mine's weight, its Strength and the like counted in), "3×3" for several hits. A move
	## whose number is a count, a turn or a die reads by its mark alone.
	if move.is_empty():
		return ""
	var shown: Array = DeepCreatures.display_moves(foe, [move])
	var effects: Array = shown[0].get("effects", []) if not shown.is_empty() else []
	for effect in effects:
		if not effect is Dictionary or not str(effect.get("kind", "")) in NUMBERED or not effect.has("amount"):
			continue
		if str(effect.kind) == "remove_block" and bool(effect.get("remove_all", false)):
			continue
		var amount: int = DeepRules.amount(effect.get("amount", 0), {"unit": foe})
		if amount <= 0:
			continue
		var words: String = DeepUi.number(amount)
		if str(effect.kind) in ["reflect", "empower_next"]:
			words += "%"
		var repeat: Variant = effect.get("repeat", 1)
		if repeat is int and int(repeat) > 1:
			words = "%s×%d" % [words, int(repeat)]
		return words
	return ""

static func text(foe: Dictionary, move: Dictionary) -> String:
	return DeepCreatures.move_text(foe, move) if not move.is_empty() else ""

static func face_dice(foe: Dictionary) -> Array:
	## The dice it throws this action (Dread or a raise resizes them, moves and all), each with
	## the moves on its faces: [{die, moves: [{move, count, mark, kind}]}].
	var out: Array = []
	for die in DeepCreatures.effective_dice(foe):
		var order: Array = []
		var counts: Dictionary = {}
		for face in die.get("faces", []):
			if not face is Dictionary or str(face.get("move", "")).is_empty():
				continue
			var name: String = str(face.move)
			if not counts.has(name):
				counts[name] = 0
				order.append({"move": name, "mark": str(face.get("mark", "")), "kind": str(face.get("move_kind", "attack"))})
			counts[name] = int(counts[name]) + 1
		for entry in order:
			entry.count = int(counts[str(entry.move)])
		out.append({"die": die, "moves": order})
	return out

static func groups(foe: Dictionary) -> Array:
	## Its dice as the ledger lists them: dice written alike (the Choir's three voices, a
	## Hydra's heads) once, with how many there are. [{shape, label, count, faces, moves}]
	var out: Array = []
	var index: Dictionary = {}
	for entry in face_dice(foe):
		if entry.moves.is_empty():
			continue
		var die: Dictionary = entry.die
		var key: String = "%s|%s|%s" % [str(die.get("shape", "")), str(die.get("label", "")),
			",".join(die.get("faces", []).map(func(f: Variant) -> String: return str(f.get("move", "")) if f is Dictionary else ""))]
		if index.has(key):
			out[int(index[key])].count = int(out[int(index[key])].count) + 1
			continue
		index[key] = out.size()
		out.append({"shape": str(die.get("shape", "D6")), "label": str(die.get("label", "")), "count": 1,
			"faces": die.get("faces", []).size(), "moves": entry.moves})
	return out

static func on_faces(foe: Dictionary) -> Dictionary:
	var named: Dictionary = {}
	for entry in face_dice(foe):
		for move in entry.moves:
			named[str(move.move)] = true
	return named

static func distinct(foe: Dictionary) -> Array:
	## Every move on any of its faces once, in the order its dice first show them, with how
	## many faces carry it across all of them: what its tag's pills read.
	var out: Array = []
	var at: Dictionary = {}
	for entry in face_dice(foe):
		for move in entry.moves:
			var name: String = str(move.move)
			if at.has(name):
				out[int(at[name])].count = int(out[int(at[name])].count) + int(move.count)
				continue
			at[name] = out.size()
			out.append(move.duplicate())
	return out

static func matches(foe: Dictionary) -> Array:
	## Moves its faces make together (the Rail Rats' Frenzy, the Choir's Requiem Chorus).
	return moves(foe).filter(func(m: Dictionary) -> bool: return str(m.get("trigger", {}).get("kind", "")) == "match")

static func match_note(move: Dictionary) -> String:
	## When a match comes, beside its row where a face's pips would be: "both dice", "3 dice",
	## or "together" for every named face landing once.
	var t: Dictionary = move.get("trigger", {})
	var need: int = int(t.get("count", 0))
	if need == 2:
		return "both dice"
	if need > 2:
		return "%d dice" % need
	return "together"

static func match_faces(move: Dictionary) -> Array:
	## The faces a match is made of, as the moves they are.
	return move.get("trigger", {}).get("faces", [])

static func extras(foe: Dictionary) -> Array:
	## Moves not on any face it throws now, with when they come: called by the fight (coming up
	## out of the floor, dying, half its health), or waiting for a face to be etched to them.
	## [{move, note}]
	var named: Dictionary = on_faces(foe)
	var out: Array = []
	for move in moves(foe):
		var kind: String = str(move.get("trigger", {}).get("kind", "face"))
		if kind == "match" or named.has(str(move.get("name", ""))):
			continue
		var note: String = ""
		match kind:
			"emerge": note = "as it comes up"
			"on_death": note = "when it dies"
			"hp_below": note = "at %d%% health" % int(move.get("trigger", {}).get("amount", 50))
			"action_begin": note = "each action"
			"face": note = "no face yet"
			_: note = DeepCreatures.trigger_words(move, foe)
		out.append({"move": move, "note": note})
	return out

static func traits(foe: Dictionary) -> Array:
	## What it always is (Sturdy, Acid Armour, Waterlogged): the chips' words, without what the
	## fight pinned on it for a turn (that is a chip on its tag while it lasts).
	var all: Dictionary = DeepCreatures.traits_for(foe) if foe.has("key") else {}
	var pinned: Dictionary = foe.get("pinned", {}) if foe.get("pinned", null) is Dictionary else {}
	var keys: Array = all.keys()
	keys.sort()
	var out: Array = []
	for key in keys:
		if pinned.has(key):
			continue
		if str(key) == "waterlogged" and bool(foe.get("risen", false)):
			continue
		out.append(EffectChips.trait_entry(str(key), all[key]))
	return out

static func dice_words(foe: Dictionary) -> String:
	## "D8 · 8 FACES", "D4 ×2 · 8 FACES", "3 DICE · 28 FACES".
	var dice: Array = face_dice(foe).map(func(e: Dictionary) -> Dictionary: return e.die)
	if dice.is_empty():
		return ""
	var total: int = 0
	var shapes: Dictionary = {}
	for die in dice:
		total += die.get("faces", []).size()
		shapes[str(die.get("shape", "D6"))] = true
	var shape: String = str(dice[0].get("shape", "D6")).to_lower()
	var faces: String = "%d %s" % [total, "face" if total == 1 else "faces"]
	if dice.size() == 1:
		return "%s · %s" % [shape, faces]
	if shapes.size() == 1:
		return "%s ×%d · %s" % [shape, dice.size(), faces]
	return "%d dice · %s" % [dice.size(), faces]

# --- the words ---------------------------------------------------------------------------------

## The words in a move's text that say a rule of their own, and what each means: underlined,
## and their meaning comes up under the pointer (the review page's keywords, in the game's
## own rules). Sturdy, Acid Armour, Steadfast and Waterlogged read the creature's own number.
const KEYWORDS: Dictionary = {
	"Marked": "Every hit of the next gem or move to land on you deals 25% more for each Mark; then the Marks are spent.",
	"Poison": "Loses that much health at the end of the turn, then a stack less each turn. Block does not stop it.",
	"Burn": "Hurts that much at the end of the turn, block soaking it first, then one less each turn.",
	"Curse": "Each stack: 10% less damage dealt and 10% more taken. Ten at most; one less each turn.",
	"Dulled": "Each stack: your gems are judged a Cut step lower. One less each turn.",
	"Festering": "Healing you receive is halved while it lasts. One less each turn.",
	"Scorched": "Block you gain is halved while it lasts. One less each turn.",
	"Strength": "Every blow deals that much more. Lasts the fight.",
	"Stunned": "Skips a turn: a stunned player's rail does not fire.",
	"Drink": "It drinks a colour: gems of that colour do it no damage, and what they would give their owner (block, healing, Ward) goes to it.",
	"Drinks": "It drinks a colour: gems of that colour do it no damage, and what they would give their owner (block, healing, Ward) goes to it.",
	"Resonance": "Builds as your gems fire and powers your Birthstone.",
	"Acid Armour": "Whoever hits it takes Poison for it.",
	"Sturdy": "No single hit takes more than a share of its health off it.",
	"Steadfast": "Stun, Bound and Clouded last half as long on it, and it cannot be stunned two actions in a row.",
	"Waterlogged": "The first time it dies, it gets back up at half its health."}
## The words coloured as the gem sheet colours them: blows red, block blue, healing green.
const TONES: Dictionary = {"damage": Color("ff7a6b"), "block": Color("6fa8ff"), "heal": Color("3fb56b"), "health": Color("3fb56b")}

static var _pattern: RegEx = null

static func _regex() -> RegEx:
	if _pattern == null:
		var names: Array = KEYWORDS.keys()
		names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
		_pattern = RegEx.new()
		_pattern.compile("\\b(%s)\\b|(?i)\\b(damage|block|heals?|healing|health)\\b" % "|".join(names.map(func(k: String) -> String: return k.replace(" ", "\\s"))))
	return _pattern

static func meaning(word: String, foe: Dictionary = {}) -> String:
	## A keyword's meaning, with the creature's own number where its trait has one.
	var key: String = word.replace("\n", " ")
	var said: String = str(KEYWORDS.get(key, ""))
	if foe.is_empty():
		return said
	match key:
		"Sturdy":
			var share: int = DeepCreatures.trait_value(foe, "sturdy", 0)
			if share > 0:
				said = "No single hit takes more than %d%% of its health off it." % share
		"Acid Armour":
			var acid: int = DeepCreatures.trait_value(foe, "acid_armour", 0)
			if acid > 0:
				said = "Whoever hits it takes %d Poison for every hit." % acid
	return said

static func write(rtl: RichTextLabel, words: String, foe: Dictionary = {}) -> void:
	## Writes a move's words into an open label: its keywords underlined with their meaning on
	## hover, its blows, block and healing in their colours. The label's own colour is kept.
	var cursor: int = 0
	for m in _regex().search_all(words):
		if m.get_start() > cursor:
			rtl.add_text(words.substr(cursor, m.get_start() - cursor))
		var word: String = m.get_string()
		if not m.get_string(1).is_empty():
			rtl.push_hint(meaning(word, foe))
			rtl.push_underline()
			rtl.push_color(DeepUi.PAPER)
			rtl.add_text(word)
			rtl.pop()
			rtl.pop()
			rtl.pop()
		else:
			var stem: String = word.to_lower()
			var tone: Color = TONES.heal if stem.begins_with("heal") else TONES.get(stem, DeepUi.PAPER)
			rtl.push_color(tone)
			rtl.add_text(word)
			rtl.pop()
		cursor = m.get_end()
	if cursor < words.length():
		rtl.add_text(words.substr(cursor))

static func rich(parent: Node, size: int, color: Color, width: float = 0.0) -> RichTextLabel:
	## An empty label for `write`. Given a `width` where it stands beside sized siblings: a rich
	## label there draws nothing without one.
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.selection_enabled = false
	if width > 0.0:
		rtl.custom_minimum_size.x = width
	DeepUi.set_text_size(rtl, size)
	rtl.add_theme_color_override("default_color", color)
	parent.add_child(rtl)
	return rtl

static func words(parent: Node, said: String, size: int, color: Color, width: float = 0.0, foe: Dictionary = {}) -> RichTextLabel:
	## Words with their keywords underlined (meaning on hover) and their blows, block and healing
	## in colour.
	var rtl := rich(parent, size, color, width)
	write(rtl, said, foe)
	return rtl

static func result_words(foe: Dictionary, move: Dictionary, party: int) -> String:
	## What a landed face says over the die: "Rake 3×3 → you", "Fortify 14", "Latch".
	var name: String = str(move.get("name", ""))
	var figure: String = number(foe, move)
	var said: String = name + (" " + figure if not figure.is_empty() else "")
	if kind_of(move) == "attack":
		var picks: bool = move.get("effects", []).any(func(e: Dictionary) -> bool: return str(e.get("target", "heroes")) in DeepRules.HERO_PICKS)
		said += " → " + ("one of you" if picks and party > 1 else ("you" if party <= 1 else "all"))
	return said

# --- a move's row ------------------------------------------------------------------------------

class Pips extends Control:
	## A move's share of its die: one dot a face, in its kind's ink, six to a line.
	const DOT: float = 6.0
	const GAP: float = 2.5
	const PER_LINE: int = 6
	var count: int = 0
	var tone: Color = Color.WHITE
	func _init(faces: int, color: Color) -> void:
		count = faces
		tone = color
		mouse_filter = Control.MOUSE_FILTER_PASS
		var across: int = mini(count, PER_LINE)
		var lines: int = ceili(float(count) / float(PER_LINE))
		custom_minimum_size = Vector2(float(across) * DOT + float(maxi(0, across - 1)) * GAP, maxf(DOT, float(lines) * DOT + float(maxi(0, lines - 1)) * GAP))
		size = custom_minimum_size
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		for i in range(count):
			var at := Vector2(float(i % PER_LINE) * (DOT + GAP), float(i / PER_LINE) * (DOT + GAP)) + Vector2.ONE * DOT * 0.5
			draw_circle(at, DOT * 0.5, tone, true, -1.0, true)

static func row_style(kind: String, lit: bool, dense: bool = false, idle: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	## A move's row: a rule in its kind's ink down its left edge, lit with a wash of the colour of
	## a blow, else `idle` (the close look's rows wear the faintest fill).
	var style := StyleBoxFlat.new()
	style.bg_color = LIT if lit else idle
	style.border_color = ink(kind)
	style.border_width_left = ROW_RULE
	style.content_margin_left = ROW_PAD_LEFT
	style.content_margin_right = ROW_PAD_RIGHT
	style.content_margin_top = 3 if dense else ROW_PAD_Y
	style.content_margin_bottom = 3 if dense else ROW_PAD_Y
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	return style

## A row's rule and its insides: the rule, the gap after it, the right margin, top and bottom;
## the gap before what stands at its right (pips, a note).
const ROW_RULE: int = 3
const ROW_PAD_LEFT: int = 10
const ROW_PAD_RIGHT: int = 4
const ROW_PAD_Y: int = 5
const ROW_GAP: int = 8
const NAME_SIZE: int = 14
const WORD_SIZE: int = 13
const NOTE_SIZE: int = 11

static func row(parent: Node, foe: Dictionary, move: Dictionary, pips: int, faces: int, note: String = "", dense: bool = false, lit: bool = false, opts: Dictionary = {}) -> PanelContainer:
	## One move as a ledger reads it: a rule and a mark in its kind's ink, its name, its words
	## (keywords explained on hover), and its share of the die as pips, or a note of when it
	## comes for a move that is not on a face. `dense` lays the name and words on one line.
	## `opts` for the close look: `figure` (a number beside its name), `when` (when a move on
	## no face of its own comes, after its name), `right` (a fixed column for the pips, so the
	## words line up), `width` (the words' own width), `mark` (its size), `idle` (the unlit fill).
	var kind: String = kind_of(move)
	var idle: Color = opts.get("idle", Color(0, 0, 0, 0))
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_stylebox_override("panel", row_style(kind, lit, dense, idle))
	box.set_meta("move", str(move.get("name", "")))
	box.set_meta("kind", kind)
	box.set_meta("dense", dense)
	box.set_meta("idle", idle)
	parent.add_child(box)
	var line := DeepUi.hbox(box, ROW_GAP)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var said := DeepUi.vbox(line, 1)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = ink(kind)
	var mark_edge: float = float(opts.get("mark", 14.0))
	var width: float = float(opts.get("width", 0.0))
	var words_said: String = text(foe, move)
	var head := DeepUi.hbox(said, 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dense:
		## One line a move: the mark, the name in bold, then its words.
		var marked := mark(head, str(move.get("mark", "")), mark_edge, tint)
		marked.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var rtl := rich(head, WORD_SIZE, ROW_TEXT, maxf(0.0, width - mark_edge - 6.0) if width > 0.0 else 0.0)
		rtl.push_font(DeepUi.bold_font())
		rtl.push_color(DeepUi.PAPER if kind != "dud" else INK.dud)
		rtl.add_text(str(move.get("name", "")))
		rtl.pop()
		rtl.pop()
		if not words_said.is_empty():
			rtl.add_text("  ")
			write(rtl, words_said, foe)
	else:
		mark(head, str(move.get("mark", "")), mark_edge, tint)
		var named := DeepUi.label(head, str(move.get("name", "")), NAME_SIZE, DeepUi.PAPER if kind != "dud" else INK.dud)
		named.add_theme_font_override("font", DeepUi.bold_font())
		var figure: String = str(opts.get("figure", ""))
		if not figure.is_empty():
			var amount := DeepUi.label(head, figure, NAME_SIZE, tint)
			amount.add_theme_font_override("font", DeepUi.bold_font())
		## Said once: a called move's words often open with when it comes ("As it comes up: ...").
		var when: String = str(opts.get("when", ""))
		var asked: String = when.trim_prefix("as ").trim_prefix("when ")
		if not when.is_empty() and not words_said.to_lower().contains(asked):
			var aside := DeepUi.label(head, "· " + when, NOTE_SIZE, DeepUi.MUTED)
			aside.clip_text = true
			aside.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			aside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not words_said.is_empty():
			words(said, words_said, WORD_SIZE, ROW_TEXT, width, foe)
	var right_w: float = float(opts.get("right", 0.0))
	var right: Control = line
	if right_w > 0.0:
		## A column of its own, the same on every row, so the words line up.
		var column := DeepUi.vbox(line, 0)
		column.custom_minimum_size.x = right_w
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		right = column
	if pips > 0:
		var dots := Pips.new(pips, tint)
		dots.tooltip_text = "%d of its %d faces" % [pips, faces] if faces > 0 else ""
		if right_w > 0.0:
			dots.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(dots)
	elif not note.is_empty():
		var aside := DeepUi.label(right, note, NOTE_SIZE, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_RIGHT if right_w > 0.0 else HORIZONTAL_ALIGNMENT_LEFT)
		aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if right_w > 0.0:
			aside.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return box

static func set_lit(box: Control, lit: bool) -> void:
	if box == null or not is_instance_valid(box):
		return
	box.add_theme_stylebox_override("panel", row_style(str(box.get_meta("kind", "attack")), lit, bool(box.get_meta("dense", false)), box.get_meta("idle", Color(0, 0, 0, 0))))

static func trait_row(parent: Node, foe: Dictionary, chip: Dictionary, dense: bool = false, width: float = 0.0) -> VBoxContainer:
	## A trait: its mark and name in violet with "always", and what it means. `chip` is
	## {glyph, title, text}, as `EffectChips.trait_entry` gives it.
	var box := DeepUi.vbox(parent, 2)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := DeepUi.hbox(box, 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := DeepUi.icon(head, str(chip.get("glyph", "spark")), 14, TRAIT_INK)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var named := DeepUi.label(head, str(chip.get("title", "")), NAME_SIZE, TRAIT_NAME)
	named.add_theme_font_override("font", DeepUi.bold_font())
	var always := PanelContainer.new()
	always.mouse_filter = Control.MOUSE_FILTER_IGNORE
	always.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	always.add_theme_stylebox_override("panel", DeepUi.capsule(always, Color(0, 0, 0, 0), PILL_LINE, 2, 6, 0))
	head.add_child(always)
	DeepUi.label(always, "always", NOTE_SIZE, DeepUi.MUTED)
	var said: String = str(chip.get("text", ""))
	if said.is_empty():
		said = meaning(str(chip.get("title", "")), foe)
	if not said.is_empty():
		words(box, said, WORD_SIZE if not dense else 12, TRAIT_TEXT, width, foe)
	return box

# --- on the dock ---------------------------------------------------------------------------------

class ClingRing extends Control:
	## A leech on a gem: a ring of violet barbs round the socket, turning slowly, so the gem it
	## clings to reads from across the dock.
	var tone: Color = Color("c9a9ff")
	var _clock: float = 0.0
	func _init(edge: float) -> void:
		size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 2
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 1.0
		draw_arc(centre, r, 0.0, TAU, 64, Color(tone, 0.28), 6.0, true)
		draw_arc(centre, r, 0.0, TAU, 64, Color(tone, 0.85), 1.6, true)
		var barbs: int = 10
		for i in range(barbs):
			var angle: float = TAU * float(i) / float(barbs) + _clock * 0.6
			var out := Vector2.from_angle(angle)
			var side := Vector2(-out.y, out.x)
			var base: Vector2 = centre + out * r
			draw_colored_polygon(PackedVector2Array([base + side * 3.0, base - out * 6.0, base - side * 3.0]), Color(tone, 0.9))
