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
	DeepUi.stat(marks, "cut", DeepContent.cut_name(int(stone.get("cut", 0))), DeepUi.PAPER, 13, GemIcons.hint("cut"))
	DeepUi.stat(marks, "clarity", DeepContent.clarity_name(int(stone.get("clarity", 3))), DeepUi.PAPER, 13, GemIcons.hint("clarity"))
	_color_chip(marks, color_key)
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
	for key in stone.get("inclusions", []):
		var inclusion: Dictionary = DeepContent.inclusion(str(key))
		var line := DeepUi.hbox(text, 8)
		_inclusion_chip(line, str(key))
		DeepUi.wrap(line, str(inclusion.get("text", "")), 12, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if opts.has("value"):
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
		var l := DeepUi.label(column, name, 12, DeepUi.PAPER if appraised else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		l.clip_text = true
		l.custom_minimum_size.x = size
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

static func size_stat(parent: Node, stone: Dictionary, size: int = 13, color: Color = DeepUi.PAPER) -> HBoxContainer:
	## A raw stone's weight as the eye judges it through the rock: a class, not a number.
	var named: Dictionary = DeepStone.size_class(int(stone.get("carat", 1)))
	return DeepUi.stat(parent, "carat", str(named.name), color, size, "%s: somewhere from %s. Only an appraisal says exactly." % [str(named.name), str(named.range)])

static func _grade_badge(parent: Node, grade: Dictionary) -> void:
	var tone: Color = DeepUi.tier_color(str(grade.tier))
	var badge := DeepUi.pill(parent, "star", str(grade.name), tone, 12, "Grade %d of 100" % int(grade.score))
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func _color_chip(parent: Node, color_key: String) -> void:
	var hue: Color = DeepUi.color(color_key)
	var rainbow: bool = DeepUi.is_rainbow(color_key)
	var row := DeepUi.hbox(parent, 5)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
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
	return DeepUi.MUTED

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
