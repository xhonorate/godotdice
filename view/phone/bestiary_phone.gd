extends RefCounted
## The bestiary on the phone (docs/PHONE_UI.md, board home-bestiary, approved November 7, 2026).
## The list down every mine on the left, three to a row, scrolling as the desk's does; the
## creature picked on the right: its model in a window at the card's top left beside its name
## and words, its facts in a row under them, then its pages under tabs (the field notes, a page
## a die). A page taller than the card scrolls in it.

const BestiaryPage = preload("res://view/home/bestiary_page.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const CreatureStage = preload("res://view/creatures/creature_stage.gd")
const CreatureLedger = preload("res://view/inspect/creature_ledger.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

## The list's width and the model's window, in points (the board's).
const LIST_WIDTH: float = 262.0
const MODEL := Vector2(120.0, 104.0)
## A die's page: the die beside its rows, in points.
const DIE_EDGE: float = 64.0
## How tall a die's page is measured to stand, in points, before it runs on to the next.
const LEAF_TALL: float = 150.0

static func build(home: Control, content: VBoxContainer) -> void:
	var order: Array = DeepBestiary.order()
	if not order.has(home._bestiary_pick) and not order.is_empty():
		home._bestiary_pick = BestiaryPage._first_pick(home, order)
		home._bestiary_scroll = -1.0
	var head := DeepUi.hbox(content, int(DeepUi.pt(8)))
	DeepUi.icon(head, "book", DeepUi.pt(18), DeepUi.ACCENT)
	DeepUi.title(head, "Bestiary", 26, DeepUi.PAPER)
	DeepUi.spacer(head)
	var met: int = DeepBestiary.known_count(home.profile, order)
	DeepUi.label(head, "%d of %d met" % [met, order.size()], 11, DeepUi.MUTED)
	var meter := DeepUi.bar(head, DeepUi.pt(5), DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
	meter.custom_minimum_size = Vector2(DeepUi.pt(90), DeepUi.pt(5))
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(float(met) / float(maxi(1, order.size())))
	home.enter(head)
	var columns := DeepUi.hbox(content, int(DeepUi.pt(8)))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame: PanelContainer = BestiaryPage.list_frame(home, columns)
	frame.custom_minimum_size.x = DeepUi.pt(LIST_WIDTH)
	var card := DeepUi.card(columns, DeepUi.LINE, int(DeepUi.pt(8)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.region(DeepUi.vbox(card, int(DeepUi.pt(5))), "bestiary_detail", func(holder: Control) -> void: _detail(home, holder))
	home.enter(card, 0.1)

static func _detail(home: Control, holder: Control) -> void:
	var key: String = home._bestiary_pick
	var def: Dictionary = DeepContent.creature(key)
	if def.is_empty():
		return
	var record: Dictionary = DeepBestiary.entry(home.profile, key)
	var known: bool = int(record.get("met", 0)) > 0
	var role: String = DeepBestiary.role(key)
	var tone: Color = BestiaryPage.ROLE_WORDS[role][2] if BestiaryPage.ROLE_WORDS.has(role) else Color("c8a8ff")
	var top := DeepUi.hbox(holder, int(DeepUi.pt(8)))
	## The model in its window, turned by a drag as on the desk.
	var stage_box := Control.new()
	stage_box.custom_minimum_size = Vector2(DeepUi.pt(MODEL.x), DeepUi.pt(MODEL.y))
	stage_box.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(stage_box)
	var halo := Inspector.Halo.new(tone if known else DeepUi.LINE)
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_box.add_child(halo)
	if known:
		var stage := CreatureStage.new(key, bool(def.get("warden", false)))
		stage.name = "BestiaryStage"
		stage.fit = true
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage_box.add_child(stage)
	else:
		var shadow := TextureRect.new()
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shadow.self_modulate = BestiaryPage.UNSEEN
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_box.add_child(shadow)
		BestiaryPage.show_portrait(shadow, key)
		var mark := DeepUi.icon(stage_box, "question", DeepUi.pt(28), Color(DeepUi.MUTED, 0.5))
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := DeepUi.vbox(top, int(DeepUi.pt(2)))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := DeepUi.hbox(words, int(DeepUi.pt(6)))
	DeepUi.title(title_row, str(def.get("name", key)) if known else "???", 26, DeepUi.PAPER if known else DeepUi.DIM)
	if BestiaryPage.ROLE_WORDS.has(role):
		DeepUi.pill(title_row, str(BestiaryPage.ROLE_WORDS[role][0]), str(BestiaryPage.ROLE_WORDS[role][1]), tone, 11).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not known:
		DeepUi.wrap(words, "Not met yet. Its name, its dice and what it does are written down the first time a fight opens on it.", 12, DeepUi.MUTED)
		var where := DeepUi.vbox(holder, int(DeepUi.pt(3)))
		DeepUi.section(where, "map", "Where to look", DeepUi.ACCENT, 11)
		_haunts(home, where, key, DeepUi.PAPER)
		return
	DeepUi.wrap(words, str(def.get("text", "")), 12, DeepUi.MUTED)
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", int(DeepUi.pt(4)))
	facts.add_theme_constant_override("v_separation", int(DeepUi.pt(3)))
	holder.add_child(facts)
	DeepUi.pill(facts, "heart", "%d health" % int(def.get("hp", 0)), DeepUi.BAD, 11,
		"Its health as written. Deeper floors, deeper mines and a bigger party breed it tougher.")
	DeepUi.pill(facts, "skull", "threat %d" % int(def.get("threat", 1)), DeepUi.MUTED, 11,
		"How much of a fight's budget it takes. Fights are made from a budget that grows with depth and the party.")
	if int(def.get("block", 0)) > 0:
		DeepUi.pill(facts, "shield", "%d block" % int(def.block), DeepUi.BLOCK, 11, "The block it starts every fight with, as written. Like its health, it grows deeper down.")
	var dice: Array = def.get("dice", [])
	if dice.is_empty():
		DeepUi.pill(facts, "die", "no dice of its own", DeepUi.DIM, 11)
	for die in dice:
		var shape: String = str(die.get("shape", die)) if die is Dictionary else str(die)
		DeepUi.pill(facts, "die", shape.to_lower(), DiceIcons.palette(shape).body, 11, "Its dice, thrown in this order. Every face is one of its moves, and the face that lands is what it does.")
	var leaf := DeepUi.vbox(holder, int(DeepUi.pt(4)))
	leaf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.region(leaf, "bestiary_leaf", func(box: Control) -> void: _leaves(home, box, key, record))

static func _rows_width() -> float:
	## What a die's rows have of the card: the page's width less the rail of places, the list,
	## the die and the gaps and margins between them.
	var page: float = DeepUi.PHONE_CANVAS.x - DeepUi.safe_left - DeepUi.safe_right - DeepUi.pt(110)
	return maxf(DeepUi.pt(160), page - DeepUi.pt(LIST_WIDTH) - DeepUi.pt(8) - DeepUi.pt(24) - DeepUi.pt(DIE_EDGE) - DeepUi.pt(8))

static func _leaves(home: Control, box: Control, key: String, record: Dictionary) -> void:
	## The field notes, then a page a die (CreatureLedger), as on the desk; the page under the
	## tabs scrolls when it is taller than the card.
	var leaves: Array = [ {"name": "Field notes", "glyph": "map", "draw": func(page: Control) -> void: _notes(home, page, key, record)}]
	var foe: Dictionary = DeepCreatures.make(key, "bestiary_" + key, 1, 1)
	var width: float = _rows_width()
	for spec in CreatureLedger.pages(foe, DeepUi.pt(LEAF_TALL), width):
		leaves.append({"name": str(spec.name), "glyph": "die" if not spec.group.is_empty() else "book", "draw": func(page: Control) -> void:
			_dice(page, foe, spec, width)})
	var at: int = clampi(int(home._bestiary_leaf), 0, leaves.size() - 1)
	var tabs := HFlowContainer.new()
	tabs.name = "BestiaryLeaves"
	tabs.add_theme_constant_override("h_separation", int(DeepUi.pt(3)))
	tabs.add_theme_constant_override("v_separation", int(DeepUi.pt(3)))
	box.add_child(tabs)
	for index in range(leaves.size()):
		var to: int = index
		var tab := DeepUi.tab_button(tabs, str(leaves[index].glyph), str(leaves[index].name), index == at, func() -> void:
			home._bestiary_leaf = to
			if not home.redraw(["bestiary_leaf"]):
				home._render(), 12)
		tab.custom_minimum_size.y = DeepUi.pt(30)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta("may_scroll", true)
	box.add_child(scroll)
	var page := DeepUi.vbox(scroll, int(DeepUi.pt(5)))
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaves[at].draw.call(page)

static func _notes(home: Control, page: Control, key: String, record: Dictionary) -> void:
	## What to remember, the record as one row of four numbers, and where it lives.
	var tip: String = str(DeepContent.creature(key).get("tip", ""))
	if not tip.is_empty():
		DeepUi.section(page, "eye", "Remember", DeepUi.ACCENT_HI, 11)
		DeepUi.wrap(page, tip, 12, DeepUi.PAPER)
	DeepUi.section(page, "star", "Your record", DeepUi.ACCENT, 11)
	var row := DeepUi.hbox(page, int(DeepUi.pt(14)))
	for entry in [["eye", str(int(record.get("met", 0))), "met"], ["sword", str(int(record.get("slain", 0))), "slain"],
			["skull", str(int(record.get("lost", 0))), "fights lost"], ["calendar", str(record.get("first", "")), "first met"]]:
		var cell := DeepUi.vbox(row, 0)
		var value := DeepUi.hbox(cell, int(DeepUi.pt(3)))
		DeepUi.icon(value, str(entry[0]), DeepUi.glyph_px(12), DeepUi.ACCENT)
		DeepUi.title(value, str(entry[1]) if not str(entry[1]).is_empty() else "–", 15 if str(entry[0]) != "calendar" else 13, DeepUi.PAPER)
		DeepUi.label(cell, str(entry[2]), 11, DeepUi.DIM)
	_haunts(home, page, key, DeepUi.MUTED)

static func _haunts(home: Control, parent: Control, key: String, tone: Color) -> void:
	## Every place it is found, a line each.
	var said: Array = []
	for haunt in BestiaryPage._places(key):
		var line: Array = BestiaryPage._haunt_words(home.profile, haunt)
		if said.has(str(line[1])):
			continue
		said.append(str(line[1]))
		var row := DeepUi.hbox(parent, int(DeepUi.pt(4)))
		DeepUi.icon(row, str(line[0]), DeepUi.glyph_px(11), tone).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		DeepUi.wrap(row, str(line[1]), 11, tone).size_flags_horizontal = Control.SIZE_EXPAND_FILL

static func _dice(page: Control, foe: Dictionary, spec: Dictionary, width: float) -> void:
	## One die's page: the die, turnable, beside its rows; what lands on no face, the rows alone.
	if spec.group.is_empty():
		CreatureLedger.fill(page, foe, spec, width + DeepUi.pt(DIE_EDGE) + DeepUi.pt(8))
		return
	var row := DeepUi.hbox(page, int(DeepUi.pt(8)))
	var view: Control = CreatureLedger.die_view(spec.group.die, DeepUi.pt(DIE_EDGE))
	view.name = "BestiaryDie"
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(view)
	CreatureLedger.fill(row, foe, spec, width, {"view": view})
