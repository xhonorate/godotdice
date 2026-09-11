extends RefCounted
## Lays a gem out as interface: its name line, its compact rank strip, and its rule as a
## chain of marked terms.
##
## `gem_text.gd` decides what a gem says and `gem_icons.gd` draws the marks; this places
## them. It lives apart from `main.gd` because the gem lab shows the same three things,
## and two copies of this would drift the moment either was touched.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

## One tint per rolled property. Gold is value, steel is the blade, violet is the light:
## a term keeps its property's colour wherever it appears, name line or formula.
const PROPERTY_TINTS := {"carat": Color("e8b661"), "cut": Color("9fd8ff"), "clarity": Color("d8c2ff")}

static func tone(name: String) -> Color:
	match name:
		"RED": return UiKit.RED
		"BLUE": return UiKit.BLUE
		"GREEN": return UiKit.GREEN
		"GOLD": return UiKit.GOLD
		"VIOLET": return UiKit.VIOLET
		"WHITE": return UiKit.WHITE
		"AMBER": return UiKit.AMBER
	return UiKit.PAPER

static func property_tint(glyph: String, fallback: Color) -> Color:
	return PROPERTY_TINTS.get(glyph, fallback)

static func flow(parent: Node, separation: int = 6) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row

static func word(parent: Node, text: String, size_px: int, color: Color, tooltip: String = "") -> Label:
	## A word inside a flowing row. It answers the mouse only when it has something to say.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_PASS if not tooltip.is_empty() else Control.MOUSE_FILTER_IGNORE
	label.tooltip_text = tooltip
	parent.add_child(label)
	return label

static func note(parent: Node, text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func marked(parent: Node, part: Dictionary, size_px: int, color: Color) -> HBoxContainer:
	## One term: its number or phrase, then the mark saying which property produced it.
	## The pair hovers as a unit, so the explanation is available from anywhere on it.
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = str(part.get("tip", ""))
	parent.add_child(cell)
	word(cell, str(part.get("text", "")), size_px, color)
	var glyph := str(part.get("glyph", ""))
	if not glyph.is_empty():
		GemIcons.glyph(cell, glyph, float(size_px) * 1.2, Color(color, 0.9), cell.tooltip_text)
	return cell

static func title_row(parent: Node, gem: Dictionary, size_px: int, name_color: Color, show_name := true) -> HFlowContainer:
	## "Good ✂ Flawless ✦ 12 ⚖ Multistrike" — the ranks a player says out loud, each
	## followed by its mark, with the gem's own name last and in its Color.
	var row := flow(parent, 8)
	var parts: Array = GemText.title_parts(gem)
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		var last: bool = index == parts.size() - 1
		if last and not show_name:
			continue
		marked(row, part, size_px if last else maxi(10, size_px - 2),
			name_color if last else property_tint(str(part.glyph), UiKit.GOLD))
	return row

static func marks_row(parent: Node, gem: Dictionary, edge: float) -> HBoxContainer:
	## The same three ranks as bare numbers, for a card too narrow to spell them out. Carat
	## leads here rather than following the name line: it is the rank that decides the most.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var marks: Dictionary = {}
	for part in GemText.title_parts(gem):
		if PROPERTY_TINTS.has(str(part.glyph)):
			marks[str(part.glyph)] = part
	for glyph in ["carat", "cut", "clarity"]:
		var part: Dictionary = marks.get(glyph, {})
		if part.is_empty():
			continue
		var tint: Color = PROPERTY_TINTS[glyph]
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.tooltip_text = str(part.tip)
		row.add_child(cell)
		GemIcons.glyph(cell, glyph, edge, Color(tint, 0.9), cell.tooltip_text)
		word(cell, str(int(gem.get(glyph, 1))), int(edge) - 2, tint)
	return row

static func term_chip(parent: Node, part: Dictionary, size_px: int) -> PanelContainer:
	## A term of the sum, boxed so the eye can count terms without reading them.
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.tooltip_text = str(part.get("tip", ""))
	holder.add_theme_stylebox_override("panel", UiKit.flat(Color(UiKit.PANEL_HI, 0.85), Color(UiKit.LINE, 0.9), 7, 5, 1))
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cell)
	parent.add_child(holder)
	var glyph := str(part.get("glyph", ""))
	var tint: Color = property_tint(glyph, UiKit.PAPER)
	if not glyph.is_empty():
		GemIcons.glyph(cell, glyph, float(size_px) * 1.25, Color(tint, 0.9), holder.tooltip_text)
	word(cell, str(part.get("text", "")), size_px, tint)
	var factor: Dictionary = part.get("factor", {})
	if not factor.is_empty():
		var factor_glyph := str(factor.get("glyph", ""))
		var factor_tint: Color = property_tint(factor_glyph, UiKit.AMBER)
		word(cell, str(factor.get("text", "")), size_px, factor_tint)
		GemIcons.glyph(cell, factor_glyph, float(size_px) * 1.15, Color(factor_tint, 0.9), str(factor.get("tip", "")))
	return holder

static func formula_rows(parent: Node, gem: Dictionary, effective_clarity: int = -1, size_px: int = 14) -> void:
	## The rule as a short chain instead of an equation: terms added, then multiplied
	## once by Carat, then named by what they do. Nothing that contributes zero appears.
	var blocks: Array = GemText.blocks(gem, effective_clarity)
	if blocks.is_empty():
		note(parent, str(Catalog.SKILLS.get(gem.get("key", ""), {}).get("formula", "")), size_px, UiKit.MUTED)
		return
	for block in blocks:
		var row := flow(parent, 6)
		var effect_tone: Color = tone(str(block.tone))
		word(row, str(block.verb), size_px, UiKit.MUTED)
		var parts: Array = block.parts
		for index in range(parts.size()):
			if index > 0:
				word(row, "+", size_px, Color(UiKit.MUTED, 0.8))
			term_chip(row, parts[index], size_px)
		var mult: Dictionary = block.mult
		if not mult.is_empty():
			marked(row, mult, size_px, PROPERTY_TINTS.carat)
		if not str(block.label).is_empty():
			word(row, str(block.label), size_px + 1, effect_tone)
		if not str(block.suffix).is_empty():
			word(row, str(block.suffix), size_px - 1, UiKit.MUTED)
		var repeat: Dictionary = block.repeat
		if not repeat.is_empty():
			marked(row, repeat, size_px, UiKit.AMBER)
		if not str(block.note).is_empty():
			note(parent, str(block.note), maxi(11, size_px - 3), Color(UiKit.MUTED, 0.9))
