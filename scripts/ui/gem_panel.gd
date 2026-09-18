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
const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Requirements = preload("res://scripts/core/requirements.gd")

## A rank is never written as a letter. Where a catalogue sentence still carries the old
## notation, each mark is drawn as its property's icon in that property's colour instead.
const NOTATION := {"M(C)": ["carat", ""], "F(L)": ["clarity", "2×"], "M(K)": ["cut", ""],
	"C": ["carat", ""], "K": ["cut", ""], "L": ["clarity", ""], "H": ["high", ""]}
static var _notation: RegEx = null

static func rich_rule(parent: Node, text: String, size_px: int, color: Color) -> RichTextLabel:
	## A catalogue sentence with every rank letter swapped for its icon.
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.bbcode_enabled = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("normal_font_size", size_px)
	label.add_theme_color_override("default_color", color)
	parent.add_child(label)
	if _notation == null:
		_notation = RegEx.new()
		_notation.compile("M\\(C\\)|F\\(L\\)|M\\(K\\)|(?<![A-Za-z])[CKLH](?![A-Za-z])")
	var at := 0
	var edge := int(round(size_px * 1.1))
	for found in _notation.search_all(text):
		label.add_text(text.substr(at, found.get_start() - at))
		var mark: Array = NOTATION[found.get_string()]
		if not str(mark[1]).is_empty():
			label.add_text(str(mark[1]))
		label.add_image(GemIcons.texture(str(mark[0]), edge * 2), edge, edge, property_tint(str(mark[0]), color))
		at = found.get_end()
	label.add_text(text.substr(at))
	label.tooltip_text = "%s  %s  %s" % [GemIcons.hint("carat"), GemIcons.hint("cut"), GemIcons.hint("clarity")]
	return label

static func requirement_row(parent: Node, requirement: Dictionary, size_px: int, tint: Color = UiKit.GREEN, with_words := true) -> HBoxContainer:
	## What a hand has to show: the requirement's mark and label, then the sentence.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	DiceIcons.build(row, requirement, float(size_px) * 1.7, str(requirement.get("words", "")), tint)
	if with_words:
		var words := note(row, str(requirement.get("words", "")), size_px, tint)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row

static func gem_requirement(parent: Node, gem: Dictionary, size_px: int, effective_clarity: int = -1, with_words := true) -> HBoxContainer:
	var clarity := effective_clarity if effective_clarity > 0 else int(gem.get("clarity", 1))
	return requirement_row(parent, Requirements.skill(str(gem.get("key", "")), clarity, int(gem.get("cut", 1)), int(gem.get("carat", 1))), size_px, UiKit.GREEN, with_words)

static func socket_tint(socket_color: String) -> Color:
	if socket_color == Catalog.SOCKET_ANY:
		return UiKit.PAPER
	return Color(str(Catalog.GEM_COLORS.get(socket_color, {}).get("hex", "8f9fb5")))

static func draw_socket(canvas: CanvasItem, centre: Vector2, radius: float, socket_color: String, filled: bool, locked: bool) -> void:
	## A setting cut to the shape of the stone it takes, outlined in that stone's Colour, so a
	## Red socket is a triangle ringed in red before anything sits in it. A prismatic setting
	## is round and ringed in every Colour at once.
	var alpha := 0.35 if locked else (0.6 if filled else 0.95)
	if socket_color == Catalog.SOCKET_ANY:
		canvas.draw_circle(centre, radius, Color(0, 0, 0, 0.3))
		var colours: Array = ["RED", "GOLD", "GREEN", "BLUE", "VIOLET", "WHITE"]
		for index in colours.size():
			var start := -PI * 0.5 + TAU * float(index) / 6.0
			canvas.draw_arc(centre, radius, start, start + TAU / 6.0, 12, Color(socket_tint(colours[index]), alpha), maxf(2.0, radius * 0.09), true)
	else:
		var outline := PackedVector2Array()
		for point in GemMesh.silhouette(socket_color):
			outline.append(centre + Vector2(point.x, -point.y) * radius)
		canvas.draw_colored_polygon(outline, Color(0, 0, 0, 0.3))
		var closed := outline.duplicate()
		closed.append(outline[0])
		canvas.draw_polyline(closed, Color(socket_tint(socket_color), alpha), maxf(2.0, radius * 0.09), true)
	if locked:
		var edge := radius * 0.8
		canvas.draw_texture_rect(GemIcons.texture("lock", int(clampf(edge, 12.0, 96.0))),
			Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, Color(UiKit.MUTED, 0.9))

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
		rich_rule(parent, str(Catalog.definitions("skills").get(gem.get("key", ""), {}).get("formula", "")), size_px, UiKit.MUTED)
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
