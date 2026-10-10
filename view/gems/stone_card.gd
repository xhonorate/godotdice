extends RefCounted
## The one way a stone is described anywhere: its picture, its name in its grade's color,
## its four C's as marks, the trigger it needs, what it does, and what is frozen inside it.
## A raw stone shows only what the eye can judge through its rock: a color and a size class.
##
## Pictures are photographs from the thumbnail service, not live 3D: a card costs a texture.
## Pass `live` for the one stone a page is about, and it turns in the light.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")

const INCLUSION_TONES := {"STAR": Color("ffcf5a"), "FRACTURE": Color("ff7a6b"), "FEATHER": Color("9fd8ff"), "LENS": Color("c58bff"), "PINPOINT": Color("76b6ff")}
const INCLUSION_GLYPHS := {"STAR": "star", "FRACTURE": "split_shield", "FEATHER": "spark", "LENS": "eye", "PINPOINT": "crosshair"}

static func picture(parent: Node, stone: Dictionary, size: float, live: bool = false) -> Control:
	## A stone's image: a photograph, or for `live` a view that sways in its light.
	if live:
		var view := GemView.new()
		view.custom_minimum_size = Vector2(size, size)
		view.set_drift(true)
		view.configure(stone)
		view.inspectable = true
		parent.add_child(view)
		return view
	var thumb := Thumbs.GemThumb.new(stone, size)
	thumb.tooltip_text = DeepUi.stone_name(stone) + "\nRight-click for details"
	parent.add_child(thumb)
	return thumb

static func grade_entries(stone: Dictionary) -> Array:
	## A stone's carat, Cut and Clarity as [glyph, figure, words, rungs reached, rungs]: the
	## grade a full name spells out ("Fine Pristine 14-carat"), put as marks. Carat is a number
	## (rungs 0); Cut and Clarity are rungs on their ladders, drawn as pips (see `Pips`).
	## Empty for a stone whose grade is not known or not its own to show.
	if not bool(stone.get("appraised", false)) or DeepStone.is_birthstone(stone):
		return []
	var cut: int = int(stone.get("cut", 0))
	var clarity: int = int(stone.get("clarity", 0))
	return [
		["carat", str(int(stone.get("carat", 1))), "%d carats" % int(stone.get("carat", 1)), 0, 0],
		["cut", str(cut + 1), "Cut: %s" % DeepContent.cut_name(cut), cut + 1, DeepContent.cuts().size()],
		["clarity", str(clarity + 1), "Clarity: %s" % DeepContent.clarity_name(clarity), clarity + 1, DeepContent.clarities().size()],
	]

static func grade_marks(parent: Node, stone: Dictionary, size: int = 12, color: Color = DeepUi.PAPER) -> HBoxContainer:
	## The grade as a row of marks beside a name, where a picture is too small to carry them.
	var row := DeepUi.hbox(parent, maxi(6, size / 2))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for entry in grade_entries(stone):
		if int(entry[4]) <= 0:
			DeepUi.stat(row, str(entry[0]), str(entry[1]), color, size, str(entry[2]))
			continue
		var mark := DeepUi.hbox(row, maxi(2, size / 5))
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		mark.tooltip_text = str(entry[2])
		DeepUi.icon(mark, str(entry[0]), float(size) + 1.0, color, str(entry[2]))
		mark.add_child(Pips.new(int(entry[3]), int(entry[4]), maxf(3.0, float(size) * 0.4), color))
	return row

class Pips extends Control:
	## A rank on its ladder as a row of dots, the rungs reached filled and the rest hollow: what
	## a bare 1-based number said, read at a glance.
	var filled: int = 0
	var total: int = 5
	var dot: float = 4.0
	var tint: Color = DeepUi.PAPER
	func _init(reached: int, rungs: int, edge: float, color: Color) -> void:
		filled = reached
		total = maxi(1, rungs)
		dot = edge
		tint = color
		custom_minimum_size = Vector2(float(total) * dot + float(total - 1) * dot * 0.4, dot + 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var step: float = dot * 1.4
		for index in range(total):
			var centre := Vector2(dot * 0.5 + step * float(index), size.y * 0.5)
			if index < filled:
				draw_circle(centre, dot * 0.5, tint)
			else:
				draw_arc(centre, dot * 0.5 - 0.5, 0.0, TAU, 14, Color(tint, 0.6), 1.0, true)

static func marked_picture(parent: Node, stone: Dictionary, size: float, tooltip: String = "", interactive: bool = true) -> Control:
	## A photograph with its carat, Cut and Clarity stacked over one corner as marks, the way a
	## fight stacks what a gem has gained: for cards too narrow to spell the grade out. The
	## picture stays live and right-clickable unless `interactive` is off, for a card that
	## takes its own clicks.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var thumb := Thumbs.GemThumb.new(stone, size)
	if interactive:
		thumb.tooltip_text = (tooltip if not tooltip.is_empty() else DeepUi.stone_name(stone)) + "\nRight-click for details"
	else:
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(thumb)
	var entries: Array = grade_entries(stone)
	if entries.is_empty():
		return holder
	## A small picture gets smaller marks, or the stack would cover the stone.
	var small: bool = size < 70.0
	var marks := VBoxContainer.new()
	marks.add_theme_constant_override("separation", 1)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.z_index = 1
	holder.add_child(marks)
	for entry in entries:
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.03, 0.04, 0.06, 0.82), Color(DeepUi.LINE_HI, 0.5), 5, 1 if small else 2))
		plate.size_flags_horizontal = Control.SIZE_SHRINK_END
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.add_child(plate)
		var chip := DeepUi.hbox(plate, 2)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(entry[4]) > 0:
			chip.add_child(Pips.new(int(entry[3]), int(entry[4]), 3.0 if small else 4.0, DeepUi.PAPER))
		else:
			DeepUi.label(chip, str(entry[1]), 9 if small else 10, DeepUi.PAPER)
		DeepUi.icon(chip, str(entry[0]), 10 if small else 11, DeepUi.PAPER)
	## Pinned to the bottom-right once the stack has its size.
	marks.resized.connect(func() -> void: marks.position = Vector2(size, size) - marks.size)
	marks.position = Vector2(size - 28, size - 48)
	return holder

static func build(parent: Node, stone: Dictionary, opts: Dictionary = {}) -> PanelContainer:
	var size: float = float(opts.get("size", 84))
	var appraised: bool = bool(stone.get("appraised", false)) or bool(opts.get("force_appraised", false))
	var grade: Dictionary = DeepStone.grade(stone)
	var tier_color: Color = DeepUi.tier_color(str(grade.tier)) if appraised else DeepUi.MUTED
	var color_key: String = DeepStone.color(stone)
	var hue: Color = DeepUi.color(color_key)
	var card := DeepUi.card(parent, Color(tier_color, 0.6) if appraised else Color(hue, 0.35), 12)
	## `vertical` stands the picture over the words, for a stone shown large beside its rivals.
	var row: BoxContainer
	if bool(opts.get("vertical", false)):
		row = DeepUi.vbox(card, 12)
	else:
		row = DeepUi.hbox(card, 14)
	var shown: Dictionary = stone.duplicate(true)
	shown.appraised = appraised
	if bool(opts.get("picture", true)):
		var frame := DeepUi.center(row)
		frame.custom_minimum_size = Vector2(size, size)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture(frame, shown, size, bool(opts.get("live", false)))
	var text := DeepUi.vbox(row, 5)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var min_width: float = float(opts.get("text_width", 0.0))
	if min_width > 0.0:
		text.custom_minimum_size.x = min_width
	if not appraised:
		DeepUi.title(text, DeepStone.raw_name(stone), 18, DeepUi.PAPER)
		var facts := DeepUi.hbox(text, 12)
		size_stat(facts, stone, 13)
		_color_chip(facts, color_key)
		DeepUi.stat(facts, "question", "skill unknown", DeepUi.MUTED, 12, "Appraise it to learn what it does.")
		## Whether anything is frozen inside is the loupe's to say, unless something has
		## already shown it.
		if bool(stone.get("inclusions_revealed", false)) and not stone.get("inclusions", []).is_empty():
			var names := DeepUi.hbox(text, 6)
			for key in stone.inclusions:
				_inclusion_chip(names, str(key))
		return card
	var skill: Dictionary = DeepStone.skill_of(stone)
	var title := DeepUi.hbox(text, 10)
	var name := DeepUi.title(title, DeepStone.name(stone), 18, tier_color)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_badge(title, grade)
	var marks := DeepUi.hbox(text, 12)
	DeepUi.stat(marks, "carat", "%d ct" % int(stone.get("carat", 1)), DeepUi.PAPER, 13, GemIcons.hint("carat"))
	staked_mark(marks, stone, "carat")
	DeepUi.stat(marks, "cut", DeepContent.cut_name(int(stone.get("cut", 0))), DeepUi.PAPER, 13, GemIcons.hint("cut"))
	staked_mark(marks, stone, "cut")
	DeepUi.stat(marks, "clarity", DeepContent.clarity_name(int(stone.get("clarity", 3))), DeepUi.PAPER, 13, GemIcons.hint("clarity"))
	staked_mark(marks, stone, "clarity")
	_color_chip(marks, color_key, stone)
	var needs := DeepUi.hbox(text, 10)
	var effective: Dictionary = DeepStone.effective(stone, opts.get("context", {}))
	var trigger: Dictionary = skill.get("trigger", {"kind": "always"})
	var described: Dictionary = DeepPatterns.describe(trigger, int(effective.cut_step))
	var need_box := DeepUi.panel(needs, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 6, 4)
	DiceIcons.build(need_box, described, 18, DeepUi.PAPER)
	DeepUi.effect_text(needs, DeepStone.text(stone, opts.get("context", {})), 13, DeepUi.PAPER, true)
	carat_lines(text, stone, opts.get("context", {}))
	if bool(effective.flawless) and skill.get("flawless", null) is Dictionary:
		var flawless := DeepUi.hbox(text, 6)
		DeepUi.icon(flawless, "star", 14, DeepUi.tier_color("PEERLESS"))
		DeepUi.effect_text(flawless, "Flawless: " + DeepStone.flawless_text(stone, opts.get("context", {})), 12, DeepUi.tier_color("PEERLESS")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var carrying: Dictionary = opts.get("context", {}).get("fingerprint", {})
	for key in stone.get("inclusions", []):
		var inclusion: Dictionary = DeepContent.inclusion(str(key))
		var line := DeepUi.hbox(text, 8)
		_inclusion_chip(line, str(key))
		## A Fingerprint on a rail says what it is carrying, and is dimmed when it carries nothing.
		var idle: bool = str(key) == "FINGERPRINT" and not carrying.is_empty() and str(carrying.get("inclusion", "")).is_empty()
		var words: String = DeepStone.fingerprint_line(carrying) if str(key) == "FINGERPRINT" and not carrying.is_empty() else str(inclusion.get("text", ""))
		DeepUi.wrap(line, words, 12, DeepUi.DIM if idle else DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if idle:
			line.modulate.a = 0.6
	var footer := DeepUi.hbox(text, 14)
	if bool(opts.get("provenance", false)) and not stone.get("provenance", {}).is_empty():
		var where: Dictionary = stone.provenance
		var parts: Array = []
		if where.has("mine") and not str(where.mine).is_empty():
			parts.append(str(DeepContent.mine(str(where.mine)).get("name", where.mine)))
		if where.has("depth"):
			parts.append("depth %d" % int(where.depth))
		if where.has("date"):
			parts.append(str(where.date))
		if not parts.is_empty():
			DeepUi.stat(footer, "map", ", ".join(parts), DeepUi.DIM, 11, "Where it was found")
	if bool(stone.get("temporary", false)):
		DeepUi.stat(footer, "hourglass", "Temporary · lent for this run only", DeepUi.INFO, 12, "Filled an empty socket at the shaft head. It cannot be sold, kept or wished on, and it is gone when the run ends.")
	elif DeepStone.is_fragile(stone):
		DeepUi.stat(footer, "split_shield", "Fragile · cannot sell or keep", DeepUi.BAD, 12)
	elif opts.has("value"):
		DeepUi.stat(footer, "coin", "%d gold" % DeepStone.value(stone), DeepUi.ACCENT, 12, "What a buyer would pay")
	return card

static func tile(parent: Node, stone: Dictionary, size: float = 72.0, caption: bool = true) -> PanelContainer:
	## A stone as a square tile for grids: picture, short name, and a grade-colored foot.
	var appraised: bool = bool(stone.get("appraised", false))
	var grade: Dictionary = DeepStone.grade(stone)
	var tone: Color = DeepUi.tier_color(str(grade.tier)) if appraised else DeepUi.color(DeepStone.color(stone))
	var box := PanelContainer.new()
	var style := DeepUi.raised(Color(DeepUi.SLATE, 0.9), Color(tone, 0.45), 12, 8, 0.3)
	style.border_width_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	var column := DeepUi.vbox(box, 4)
	var frame := DeepUi.center(column)
	frame.custom_minimum_size = Vector2(size, size)
	var thumb := picture(frame, stone, size * 0.86)
	thumb.tooltip_text = DeepUi.stone_name(stone) + ("\n" + str(grade.name) if appraised else "") + "\nRight-click for details"
	if caption:
		var name: String = str(DeepStone.skill_of(stone).get("name", "")) if appraised else "%s raw" % DeepStone.size_name(int(stone.get("carat", 1)))
		DeepUi.fit_label(column, name, 12, DeepUi.PAPER if appraised else DeepUi.MUTED, size)
	return box

static func mini(parent: Node, stone: Dictionary, size: float = 56.0, tooltip: String = "") -> Control:
	## Just the picture, for rails and strips. Hover for the name.
	var thumb := Thumbs.GemThumb.new(stone, size)
	thumb.tooltip_text = (tooltip if not tooltip.is_empty() else DeepUi.stone_name(stone)) + "\nRight-click for details"
	parent.add_child(thumb)
	return thumb

static func carat_lines(parent: Node, stone: Dictionary, context: Dictionary = {}, size: int = 12) -> void:
	## What a heavy stone buys an effect that cannot take a multiplier: more goes at it. What
	## is certain reads green, what is only likely reads in the carat's own gold.
	for line in DeepStone.proc_lines(stone, context):
		DeepUi.stat(parent, "carat", str(line.text), DeepUi.GOOD if bool(line.sure) else DeepUi.ACCENT, size,
			"Carat. An effect that cannot be a fraction happens more often instead of harder.")

static func staked_mark(parent: Node, stone: Dictionary, field: String, size: int = 12) -> void:
	## What the Grubstake did to this stone, marked beside the figure it changed the way a
	## buff is marked in a fight. The rail is a copy of the vault for the length of a run, so
	## every one of these is borrowed: the stone that goes home is the stone that came down.
	var moved: int = int(stone.get("staked", {}).get(field, 0))
	if moved == 0:
		return
	var tone: Color = DeepUi.GOOD if moved > 0 else DeepUi.BAD
	var words: String = {"carat": "carat", "cut": "Cut step", "clarity": "Clarity step"}.get(field, field)
	DeepUi.pill(parent, "rise" if moved > 0 else "fall", "%+d" % moved, tone, size,
		"Staked at the shaft head: %+d %s for this run only. It does not come home." % [moved, words])

static func size_stat(parent: Node, stone: Dictionary, size: int = 13, color: Color = DeepUi.PAPER) -> HBoxContainer:
	## A raw stone's weight as the eye judges it through the rock: a class, not a number.
	var named: Dictionary = DeepStone.size_class(int(stone.get("carat", 1)))
	return DeepUi.stat(parent, "carat", str(named.name), color, size, "%s: somewhere from %s. Only an appraisal says exactly." % [str(named.name), str(named.range)])

static func _grade_badge(parent: Node, grade: Dictionary) -> void:
	var tone: Color = DeepUi.tier_color(str(grade.tier))
	var badge := DeepUi.pill(parent, "star", str(grade.name), tone, 12, "Grade %d of 100" % int(grade.score))
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func _color_chip(parent: Node, color_key: String, stone: Dictionary = {}) -> void:
	var hue: Color = DeepUi.color(color_key)
	var rainbow: bool = DeepUi.is_rainbow(color_key)
	var row := DeepUi.hbox(parent, 5)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	## A gem made from several colors counts as every one of them, and says so: a dot apiece.
	var several: Array = DeepStone.skill_of(stone).get("colors", []) if not stone.is_empty() else []
	if several.size() > 1:
		row.add_theme_constant_override("separation", 2)
		for key in several:
			row.add_child(_Dot.new(DeepUi.color(str(key))))
		row.tooltip_text = "Counts as %s." % ", ".join(several.map(func(k: Variant) -> String: return str(DeepContent.color(str(k)).get("name", k))))
		DeepUi.label(row, " %d colors" % several.size(), 13, DeepUi.PAPER)
		return
	var name: String = str(DeepContent.color(color_key).get("name", color_key))
	var domain: String = str(DeepContent.color(color_key).get("domain", ""))
	row.tooltip_text = "%s: %s" % [name, domain]
	var dot := _Dot.new(hue, rainbow)
	row.add_child(dot)
	## An opal is no one color, so neither its dot nor its name is drawn in one.
	if rainbow:
		DeepUi.rainbow_word(row, name, 13)
		return
	DeepUi.label(row, name, 13, hue.lightened(0.2))

static func _inclusion_chip(parent: Node, key: String) -> void:
	var inclusion: Dictionary = DeepContent.inclusion(key)
	var cls: String = str(inclusion.get("class", "PINPOINT"))
	var tone: Color = INCLUSION_TONES.get(cls, DeepUi.INFO)
	var chip := DeepUi.pill(parent, str(INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), tone, 11, str(inclusion.get("text", "")))
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"UNCOMMON": return Color("7fd1a8")
		"RARE": return Color("6fa8ff")
		"LEGENDARY": return Color("ffcf5a")
		"MYTHIC": return DeepUi.OPAL_TONE
		"TRANSCENDENT": return DeepUi.TRANSCENDENT_TONE
	return DeepUi.MUTED

static func rarity_tag(parent: Node, rarity: String, size: int = 13, as_pill: bool = true) -> Control:
	## A stone's rarity, said the way every page says it: a Mythic in every color, a
	## Transcendent in moving gold, anything else in its own tone.
	if rarity == DeepContent.TRANSCENDENT:
		var box := PanelContainer.new()
		var style := DeepUi.flat(Color(DeepUi.TRANSCENDENT_TONE, 0.14), Color(DeepUi.TRANSCENDENT_TONE, 0.6), 20 if as_pill else 6, 5)
		style.content_margin_left = 9
		style.content_margin_right = 11
		box.add_theme_stylebox_override("panel", style)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = "Transcendent: made at an altar, and nowhere else."
		parent.add_child(box)
		var row := DeepUi.hbox(box, maxi(3, size / 4))
		if as_pill:
			DeepUi.icon(row, "spark", size + 3, DeepUi.TRANSCENDENT_TONE)
		DeepUi.shimmer_word(row, "Transcendent", size)
		return box
	if as_pill:
		return DeepUi.pill(parent, "spark", rarity.capitalize(), _rarity_color(rarity), size, "", is_mythic(rarity))
	return DeepUi.chip(parent, rarity.capitalize(), _rarity_color(rarity), size, is_mythic(rarity))

static func color_words(stone: Dictionary) -> String:
	## The color line a card prints: one color and its domain, or every color a gem made
	## from several counts as.
	var colors: Array = DeepStone.skill_of(stone).get("colors", [])
	if colors.size() > 1:
		return " · ".join(colors.map(func(c: Variant) -> String: return str(DeepContent.color(str(c)).get("name", c))))
	var key: String = DeepStone.color(stone)
	return "%s · %s" % [str(DeepContent.color(key).get("name", key)), str(DeepContent.color(key).get("domain", ""))]

static func is_mythic(rarity: String) -> bool:
	## The one rarity written in every color, because the only stones that wear it are.
	return rarity == "MYTHIC"

class _Dot extends Control:
	var tone: Color
	var rainbow: bool
	func _init(color: Color, all_of_them: bool = false) -> void:
		tone = color
		rainbow = all_of_them
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5, tone.darkened(0.3))
		if rainbow:
			## An opal's dot is the whole wheel, swept round it in wedges.
			var wedges: int = 12
			for i in range(wedges):
				draw_arc(size * 0.5, size.x * 0.25, TAU * float(i) / float(wedges), TAU * float(i + 1) / float(wedges),
					4, DeepUi.rainbow_at(float(i) / float(wedges - 1), 0.62), size.x * 0.22)
		else:
			draw_circle(size * 0.5, size.x * 0.36, tone)
		draw_circle(size * 0.5 - Vector2(2, 2), size.x * 0.12, Color(1, 1, 1, 0.6))
