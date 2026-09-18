extends RefCounted
## The one way a stone is described anywhere: its picture, its name in its grade's colour,
## its four C's, the trigger it needs, what it does, and what is frozen inside it. A raw
## stone shows only what the eye can judge.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

static func build(parent: Node, stone: Dictionary, opts: Dictionary = {}) -> PanelContainer:
	var size: float = float(opts.get("size", 84))
	var appraised: bool = bool(stone.get("appraised", false)) or bool(opts.get("force_appraised", false))
	var grade: Dictionary = DeepStone.grade(stone)
	var tier_colour: Color = DeepUi.tier_colour(str(grade.tier)) if appraised else DeepUi.MUTED
	var card := DeepUi.panel(parent, DeepUi.SLATE, Color(tier_colour, 0.55) if appraised else DeepUi.LINE, 10, 10)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := DeepUi.hbox(card, 12)
	var picture := GemView.new()
	picture.custom_minimum_size = Vector2(size, size)
	picture.set_drift(bool(opts.get("drift", false)))
	var shown: Dictionary = stone.duplicate(true)
	shown.appraised = appraised
	picture.configure(shown)
	row.add_child(picture)
	var text := DeepUi.vbox(row, 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colour_key: String = DeepStone.colour(stone)
	if not appraised:
		DeepUi.label(text, DeepStone.raw_name(stone), 16, DeepUi.PAPER)
		DeepUi.label(text, "Unappraised. Its colour, size, cut and clarity are there to judge; what it does is not.", 12, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var slots: int = DeepStone.inclusion_slots(int(stone.get("clarity", 3)))
		if bool(stone.get("inclusions_revealed", false)) and not stone.get("inclusions", []).is_empty():
			var names := DeepUi.hbox(text, 6)
			for key in stone.inclusions:
				DeepUi.chip(names, str(DeepContent.inclusion(str(key)).get("name", key)), DeepUi.INFO, 11)
		elif slots > 0:
			DeepUi.label(text, "%d inclusion%s frozen inside." % [slots, "" if slots == 1 else "s"], 12, DeepUi.INFO)
		return card
	var skill: Dictionary = DeepStone.skill_of(stone)
	var title := DeepUi.hbox(text, 8)
	DeepUi.label(title, DeepStone.name(stone), 16, tier_colour)
	DeepUi.spacer(title)
	DeepUi.chip(title, str(grade.name), tier_colour, 11)
	var marks := DeepUi.hbox(text, 8)
	DeepUi.chip(marks, str(DeepContent.colour(colour_key).get("name", colour_key)), DeepUi.colour(colour_key), 11)
	DeepUi.chip(marks, str(skill.get("rarity", "COMMON")).capitalize(), DeepUi.MUTED, 11)
	var effective: Dictionary = DeepStone.effective(stone, opts.get("context", {}))
	var trigger: Dictionary = skill.get("trigger", {"kind": "always"})
	DiceIcons.build(marks, DeepPatterns.describe(trigger, int(effective.cut_step)), 18, DeepUi.PAPER)
	var text_line := DeepUi.label(text, str(skill.get("text", "")), 13, DeepUi.PAPER)
	text_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if DeepStone.is_flawless(stone) and skill.get("flawless", null) is Dictionary:
		DeepUi.label(text, "Flawless: " + str(skill.flawless.get("text", "")), 12, DeepUi.tier_colour("PEERLESS")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in stone.get("inclusions", []):
		var inclusion: Dictionary = DeepContent.inclusion(str(key))
		var line := DeepUi.hbox(text, 6)
		var cls: String = str(inclusion.get("class", ""))
		var tone: Color = DeepUi.tier_colour("PEERLESS") if cls == "STAR" else (DeepUi.BAD if cls == "FRACTURE" else DeepUi.INFO)
		DeepUi.chip(line, str(inclusion.get("name", key)), tone, 11)
		DeepUi.label(line, str(inclusion.get("text", "")), 12, DeepUi.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			DeepUi.label(text, "Found: " + ", ".join(parts), 11, DeepUi.DIM)
	if opts.has("value"):
		DeepUi.label(text, "Worth %d gold" % DeepStone.value(stone), 12, DeepUi.ACCENT)
	return card

static func mini(parent: Node, stone: Dictionary, size: float = 56.0, tooltip: String = "") -> Control:
	## Just the picture, for grids and rails. Hover for the name.
	var picture := GemView.new()
	picture.custom_minimum_size = Vector2(size, size)
	picture.set_drift(false)
	picture.configure(stone)
	picture.tooltip_text = tooltip if not tooltip.is_empty() else DeepUi.stone_name(stone)
	parent.add_child(picture)
	return picture
