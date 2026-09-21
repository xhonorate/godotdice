extends RefCounted
## The one way a stone is described anywhere: its picture, its name in its grade's colour,
## its four C's as marks, the trigger it needs, what it does, and what is frozen inside it.
## A raw stone shows only what the eye can judge.
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
	var tier_colour: Color = DeepUi.tier_colour(str(grade.tier)) if appraised else DeepUi.MUTED
	var colour_key: String = DeepStone.colour(stone)
	var hue: Color = DeepUi.colour(colour_key)
	var card := DeepUi.card(parent, Color(tier_colour, 0.6) if appraised else Color(hue, 0.35), 12)
	var row := DeepUi.hbox(card, 14)
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
		DeepUi.stat(facts, "carat", "%d ct" % int(stone.get("carat", 1)), DeepUi.PAPER, 13, GemIcons.hint("carat"))
		_colour_chip(facts, colour_key)
		DeepUi.stat(facts, "question", "skill unknown", DeepUi.MUTED, 12, "Appraise it to learn what it does.")
		var slots: int = DeepStone.inclusion_slots(int(stone.get("clarity", 3)))
		if bool(stone.get("inclusions_revealed", false)) and not stone.get("inclusions", []).is_empty():
			var names := DeepUi.hbox(text, 6)
			for key in stone.inclusions:
				_inclusion_chip(names, str(key))
		elif slots > 0:
			DeepUi.stat(text, "spark", "%s frozen inside" % DeepUi.plural(slots, "inclusion"), DeepUi.INFO, 12)
		return card
	var skill: Dictionary = DeepStone.skill_of(stone)
	var title := DeepUi.hbox(text, 10)
	var name := DeepUi.title(title, DeepStone.name(stone), 18, tier_colour)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade_badge(title, grade)
	var marks := DeepUi.hbox(text, 12)
	DeepUi.stat(marks, "carat", "%d ct" % int(stone.get("carat", 1)), DeepUi.PAPER, 13, GemIcons.hint("carat"))
	DeepUi.stat(marks, "cut", DeepContent.cut_name(int(stone.get("cut", 0))), DeepUi.PAPER, 13, GemIcons.hint("cut"))
	DeepUi.stat(marks, "clarity", DeepContent.clarity_name(int(stone.get("clarity", 3))), DeepUi.PAPER, 13, GemIcons.hint("clarity"))
	_colour_chip(marks, colour_key)
	var needs := DeepUi.hbox(text, 10)
	var effective: Dictionary = DeepStone.effective(stone, opts.get("context", {}))
	var trigger: Dictionary = skill.get("trigger", {"kind": "always"})
	var described: Dictionary = DeepPatterns.describe(trigger, int(effective.cut_step))
	var need_box := DeepUi.panel(needs, Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 6, 4)
	DiceIcons.build(need_box, described, 18, DeepUi.PAPER)
	DeepUi.chip(needs, str(skill.get("rarity", "COMMON")).capitalize(), _rarity_colour(str(skill.get("rarity", "COMMON"))), 11)
	DeepUi.wrap(text, str(skill.get("text", "")), 13, DeepUi.PAPER)
	if DeepStone.is_flawless(stone) and skill.get("flawless", null) is Dictionary:
		var flawless := DeepUi.hbox(text, 6)
		DeepUi.icon(flawless, "star", 14, DeepUi.tier_colour("PEERLESS"))
		DeepUi.wrap(flawless, "Flawless: " + str(skill.flawless.get("text", "")), 12, DeepUi.tier_colour("PEERLESS")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	## A stone as a square tile for grids: picture, short name, and a grade-coloured foot.
	var appraised: bool = bool(stone.get("appraised", false))
	var grade: Dictionary = DeepStone.grade(stone)
	var tone: Color = DeepUi.tier_colour(str(grade.tier)) if appraised else DeepUi.colour(DeepStone.colour(stone))
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
		var name: String = str(DeepStone.skill_of(stone).get("name", "")) if appraised else "%d ct raw" % int(stone.get("carat", 1))
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

static func _grade_badge(parent: Node, grade: Dictionary) -> void:
	var tone: Color = DeepUi.tier_colour(str(grade.tier))
	var badge := DeepUi.pill(parent, "star", str(grade.name), tone, 12, "Grade %d of 100" % int(grade.score))
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func _colour_chip(parent: Node, colour_key: String) -> void:
	var hue: Color = DeepUi.colour(colour_key)
	var row := DeepUi.hbox(parent, 5)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var domain: String = str(DeepContent.colour(colour_key).get("domain", ""))
	row.tooltip_text = "%s: %s" % [str(DeepContent.colour(colour_key).get("name", colour_key)), domain]
	var dot := _Dot.new(hue)
	row.add_child(dot)
	DeepUi.label(row, str(DeepContent.colour(colour_key).get("name", colour_key)), 13, hue.lightened(0.2))

static func _inclusion_chip(parent: Node, key: String) -> void:
	var inclusion: Dictionary = DeepContent.inclusion(key)
	var cls: String = str(inclusion.get("class", "PINPOINT"))
	var tone: Color = INCLUSION_TONES.get(cls, DeepUi.INFO)
	var chip := DeepUi.pill(parent, str(INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), tone, 11, str(inclusion.get("text", "")))
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

static func _rarity_colour(rarity: String) -> Color:
	match rarity:
		"UNCOMMON": return Color("7fd1a8")
		"RARE": return Color("6fa8ff")
		"LEGENDARY": return Color("ffcf5a")
	return DeepUi.MUTED

class _Dot extends Control:
	var tone: Color
	func _init(colour: Color) -> void:
		tone = colour
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5, tone.darkened(0.3))
		draw_circle(size * 0.5, size.x * 0.36, tone)
		draw_circle(size * 0.5 - Vector2(2, 2), size.x * 0.12, Color(1, 1, 1, 0.6))
