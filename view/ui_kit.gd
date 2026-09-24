class_name DeepUi
extends RefCounted
## The frame everything sits in: dark slate, one warm accent, one line weight, one display
## face for titles. Stones, dice and beams glow; the kit itself stays calm but never still:
## panels ease in, buttons answer the pointer, numbers roll rather than jump.

const GemIcons = preload("res://view/gems/gem_icons.gd")

const INK := Color("0b0e14")
const SLATE := Color("141924")
const SLATE_HI := Color("1c2331")
const SLATE_LOW := Color("0f131c")
const GLASS := Color(0.07, 0.09, 0.13, 0.86)
const LINE := Color("2c3648")
const LINE_HI := Color("3d4a60")
const PAPER := Color("e9edf3")
const MUTED := Color("8792a6")
const DIM := Color("5b6578")
const ACCENT := Color("e2b23a")
const ACCENT_HI := Color("ffd76a")
const ACCENT_DIM := Color("8a6d2a")
const GOOD := Color("6fe3b0")
const BAD := Color("ff7a6b")
const INFO := Color("76b6ff")
const HP := Color("3fb56b")
const HP_LOST := Color("5a2a2a")
const BLOCK := Color("6fa8ff")
const POISON := Color("9ad35a")
const ORE := Color("e8a94f")
## A pale lavender: Resonance's mark and, on its own, a fallback for anywhere its word can't
## be shown letter by letter (see EFFECT_KEYWORDS' "rainbow" flag, which is how the word itself
## is colored — flat text this close to PAPER's near-white would simply vanish into it).
const RESONANCE := Color("e4cdff")
## Opal's stand-in wherever one flat color has to be picked: a border, a background, a
## dot. The pack gives an opal a near-white body hue, which is right for the stone and
## wrong for the interface — beside a White gem the two would be the same pale wash. This
## is the middle of the rainbow its word and its mark are drawn with, and nobody else's.
const OPAL_TONE := Color("8ff0dc")
const TIER_colorS := {"ROUGH": Color("9aa3b2"), "FINE": Color("7fd1a8"), "PRECIOUS": Color("6fa8ff"), "EXQUISITE": Color("c58bff"), "PEERLESS": Color("ffcf5a")}
## The stems an effect's own text is picked out by, wherever it is read as prose: "Damage",
## "damages" and "damaged" all catch on "damage". Keyed lowercase; matched case-insensitively,
## colored as the case it was found in. Poison here is violet on purpose, not POISON's sickly
## status-bar green: that constant is a live gameplay reading, this one is just the word.
## Resonance is nobody's one color, so instead of "color" it carries "rainbow": each of its
## letters gets its own pale hue off the wheel, and its own mark rides right after it.
const EFFECT_KEYWORDS: Dictionary = {"damage": {"color": Color("ff7a6b")}, "block": {"color": Color("6fa8ff")},
	"heal": {"color": Color("3fb56b")}, "poison": {"color": Color("b58cff")}, "ore": {"color": Color("e8a94f")},
	"resonance": {"color": RESONANCE, "icon": "resonance", "rainbow": true},
	"opal": {"color": OPAL_TONE, "rainbow": true}}
## Shared keyword definitions, shown only when hovering a highlighted word.
const KEYWORD_HINTS: Dictionary = {
 "resonance": "Builds when gems fire and powers the Birthstone. Starts at zero each turn unless Charged supplies a starting value. Fizzles preserve it.",
 "ward": "Consumes one stack to block one debuff application. Maximum 99; lasts this fight.",
 "retain": "At the next Block reset, preserves up to its stacks of remaining Block, then is consumed. Maximum 20.",
 "charge": "Charged Battery: all stacks become starting Resonance at your next turn, then are consumed. No cap.",
 "regeneration": "Heals its stacks at turn end after Poison, then loses one stack. Cannot revive. No cap.",
 "spikes": "Retaliates once per attacking gem or ability, even against blocked hits. Expires at your next Block reset. No cap.",
 "bound": "Suppresses one die per stack for the next action, even if no dice remain.",
 "clouded": "On enemies: disables one random ability for its duration; reapplication extends the same ability. On players: disables a socket until the fogging enemy is hit.",
 "curse": "Each stack reduces hit damage dealt by 10% and increases hit damage taken by 10%. Maximum 10; loses one stack per turn.",
 "marked": "The next direct hit deals +25% per stack and consumes all stacks, even if Block absorbs it. No cap.",
 "dread": "Each stack lowers every enemy die one size tier, to a minimum d2. Loses one stack after each enemy action.",
 "dulled": "Each stack reduces effective Cut by one step, to a minimum Poor. Loses one stack per turn.",
 "lifeline": "Before lethal damage downs you, consumes all stacks and restores that much HP, up to maximum HP. Lasts this fight.",
 "cleanse": "Removes the stated number of debuff stacks, starting with Poison, then Stun, Curse, Marked, Dulled, Clouded and Dread.",
 "sparkle": "Maximum 100. The next stone find consumes every stack for +1 generation luck each. Carries between fights.",
 "block": "Absorbs hit damage before HP. Resets at your next turn; Retain preserves some. Poison bypasses Block.",
 "poison": "Loses HP equal to its stacks at turn end, then loses one stack. Bypasses Block.",
 "pyrite": "Currency in your bag plus combat earnings, less spending. Wager and Stake pay once per activation.",
 "carat": "Increases gem magnitude; whole-number effects usually gain additional procs instead. Temporary bonuses last this fight.",
 "cut": "The gem’s trigger/effect ladder: Poor, Fair, Good, Fine, Perfect. Temporary bonuses last this fight.",
 "clarity": "Pristine doubles base Resonance gain. Flawless triples it, grants ×1.5 magnitude and activates the Flawless line. Temporary bonuses preserve inclusions.",
 "phantom": "An extra temporary die read by later gems. It cannot receive permanent face upgrades.",
 "amplif": "Increases the next evaluated gem’s magnitude. Consumed even if that gem fizzles.",
 "permanent": "Lasts for the current run, including later fights. Does not alter your stored collection.",
 "stun": "Skips the next action per stack. Enemies break out after three consecutive missed actions and resist Stun through the following turn."
}
## The mark each chamber kind is drawn with, anywhere a chamber is shown.
const CHAMBER_GLYPHS: Dictionary = {"fight": "sword", "elite": "skull", "vein": "pick", "oddity": "question", "motherlode": "gem",
	"merchant": "purse", "smithy": "anvil", "carver": "face", "landing": "lift", "warden": "crown", "vug": "pick", "hidden": "arch",
	"well": "drop"}
const CHAMBER_colorS: Dictionary = {"fight": Color("ff8a70"), "elite": Color("ff5f7a"), "vein": Color("ffc56a"), "oddity": Color("b58cff"),
	"motherlode": Color("ffe07a"), "merchant": Color("5fd4c8"), "smithy": Color("8fb8ff"), "carver": Color("f2a0d0"), "landing": Color("7fd1a8"),
	"warden": Color("ff4d5e"), "vug": Color("ffc56a"), "hidden": Color("8792a6"), "well": Color("6fd8e8")}

static var _display: Font = null
static var _bold: Font = null
static var _glow: GradientTexture2D = null
static var _dot: GradientTexture2D = null
static var _keyword_regex: RegEx = null

static func color(key: String) -> Color:
	## A color family's hue from the pack, except Opal's: see OPAL_TONE.
	if key == DeepContent.OPAL:
		return OPAL_TONE
	var hue: String = str(DeepContent.color(key).get("hue", ""))
	return Color(hue) if not hue.is_empty() else PAPER

static func rainbow_at(t: float, saturation: float = 0.32) -> Color:
	return GemIcons.rainbow_at(t, saturation)

static func is_rainbow(color_key: String) -> bool:
	## Whether a gem color has to be drawn as all of them. Only the opals.
	return color_key == DeepContent.OPAL

static func tier_color(tier: String) -> Color:
	return TIER_colorS.get(tier, PAPER)

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func display_font() -> Font:
	## The one display face: a bookish serif from the system, bold, with a little air
	## between the capitals. Falls back to the engine font where none is installed.
	if _display == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "DejaVu Serif", "serif"])
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		var face := FontVariation.new()
		face.base_font = system
		face.spacing_glyph = 1
		_display = face
	return _display

static func bold_font() -> Font:
	## A heavier weight of the system's plain face, for body text that must catch the eye
	## before anything else on the page: an effect's text, a value the player is meant to read.
	if _bold == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "DejaVu Sans", "sans-serif"])
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_bold = system
	return _bold

static func glow_texture() -> GradientTexture2D:
	## A soft radial light, shared by every halo, beam and 2D particle.
	if _glow == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow

static func dot_texture() -> GradientTexture2D:
	## A small hard-edged dot for sparks.
	if _dot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.6, Color(1, 1, 1, 0.9))
		_dot = GradientTexture2D.new()
		_dot.gradient = gradient
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, pad: int = 12, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.anti_aliasing = true
	return box

static func raised(bg: Color, border: Color, radius: int = 10, pad: int = 12, shadow: float = 0.45) -> StyleBoxFlat:
	## A panel that sits on the page: a lit top edge, a heavier bottom one and a soft shadow.
	var box := flat(bg, border, radius, pad)
	box.border_width_top = 1
	box.border_width_bottom = 2
	box.shadow_color = Color(0, 0, 0, shadow)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	return box

static func button_style(bg: Color, border: Color, pad: int = 10) -> StyleBoxFlat:
	var box := flat(bg, border, 8, pad)
	box.content_margin_left = pad + 6
	box.content_margin_right = pad + 6
	box.content_margin_top = pad - 2
	box.content_margin_bottom = pad - 2
	box.border_width_bottom = 2
	return box

static func theme(scale: float = 1.0) -> Theme:
	var t := Theme.new()
	t.default_font_size = int(15 * scale)
	t.set_stylebox("panel", "Panel", flat(SLATE, LINE, 10, 14))
	t.set_stylebox("panel", "PanelContainer", flat(SLATE, LINE, 10, 14))
	t.set_stylebox("normal", "Button", button_style(SLATE_HI, LINE))
	t.set_stylebox("hover", "Button", button_style(Color("252f41"), LINE_HI))
	t.set_stylebox("pressed", "Button", button_style(ACCENT_DIM, ACCENT))
	t.set_stylebox("disabled", "Button", button_style(SLATE_LOW, Color(LINE, 0.5)))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), Color(ACCENT, 0.7), 8, 10, 2))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("icon_normal_color", "Button", PAPER)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", INK)
	t.set_color("icon_disabled_color", "Button", DIM)
	t.set_constant("h_separation", "Button", 8)
	t.set_color("font_color", "Label", PAPER)
	t.set_stylebox("normal", "LineEdit", flat(SLATE_LOW, LINE, 8, 9))
	t.set_stylebox("focus", "LineEdit", flat(SLATE_LOW, ACCENT_DIM, 8, 9))
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_stylebox("normal", "OptionButton", button_style(SLATE_HI, LINE))
	t.set_stylebox("hover", "OptionButton", button_style(Color("252f41"), LINE_HI))
	t.set_stylebox("pressed", "OptionButton", button_style(SLATE_HI, ACCENT))
	t.set_stylebox("panel", "PopupMenu", flat(INK, LINE, 8, 6))
	t.set_stylebox("hover", "PopupMenu", flat(ACCENT_DIM, Color(0, 0, 0, 0), 6, 4))
	t.set_stylebox("panel", "TooltipPanel", flat(Color(INK, 0.96), LINE_HI, 6, 9))
	t.set_color("font_color", "TooltipLabel", PAPER)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, flat(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber", bar, flat(Color(LINE_HI, 0.8), Color(0, 0, 0, 0), 4, 3))
		t.set_stylebox("grabber_highlight", bar, flat(ACCENT_DIM, Color(0, 0, 0, 0), 4, 3))
		t.set_stylebox("grabber_pressed", bar, flat(ACCENT, Color(0, 0, 0, 0), 4, 3))
	return t

# --- builders ------------------------------------------------------------------------------

static func vbox(parent: Node, separation: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

static func hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

static func center(parent: Node) -> CenterContainer:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

static func margin(parent: Node, sides: int = 16, top: int = -1) -> MarginContainer:
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "bottom"]:
		box.add_theme_constant_override("margin_" + side, sides)
	box.add_theme_constant_override("margin_top", sides if top < 0 else top)
	parent.add_child(box)
	return box

static func panel(parent: Node, bg: Color = SLATE, border: Color = LINE, radius: int = 10, pad: int = 14) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", flat(bg, border, radius, pad))
	parent.add_child(box)
	return box

static func card(parent: Node, border: Color = LINE, pad: int = 14, bg: Color = GLASS) -> PanelContainer:
	## A raised card: the unit every page is built from.
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", raised(bg, border, 12, pad))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	return box

static func label(parent: Node, text: String, size: int = 15, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	## Centred down the label's own box. A label in a row is stretched to the row's height,
	## and text drawn from the top of that box sits a few pixels above the mark beside it —
	## which is every misaligned word on every strip and dock in the game.
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func wrap(parent: Node, text: String, size: int = 13, color: Color = MUTED, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = 0.0) -> Label:
	var l := label(parent, text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l

static func _keyword_pattern() -> RegEx:
	if _keyword_regex == null:
		_keyword_regex = RegEx.new()
		_keyword_regex.compile("(?i)\\b(%s)\\w*" % "|".join(EFFECT_KEYWORDS.keys() + KEYWORD_HINTS.keys()))
	return _keyword_regex

static func push_effect_text(rtl: RichTextLabel, text: String) -> void:
	## Writes `text` into an already-open RichTextLabel, coloring damage/block/heal/poison/
	## ore/resonance stems (see EFFECT_KEYWORDS) as it goes — Resonance also gets its mark
	## inline — and leaving everything else at whatever color the caller already pushed.
	## Splits the work from `effect_text()` below so a caller that wants to keep writing to
	## the label after (a multiplier, a badge) can.
	var cursor: int = 0
	for m in _keyword_pattern().search_all(text):
		if m.get_start() > cursor:
			rtl.add_text(text.substr(cursor, m.get_start() - cursor))
		var word: String = m.get_string()
		var stem: String = word.to_lower()
		var entry: Dictionary = {}
		for key in EFFECT_KEYWORDS:
			if stem.begins_with(key):
				entry = EFFECT_KEYWORDS[key]
				break
		var hint: String = ""
		for key in KEYWORD_HINTS:
			if stem.begins_with(key):
				hint = str(KEYWORD_HINTS[key])
				break
		if not hint.is_empty():
			rtl.push_hint(hint)
		var tone: Color = entry.get("color", INFO if not hint.is_empty() else PAPER)
		if bool(entry.get("rainbow", false)):
			var span: int = maxi(1, word.length() - 1)
			for i in range(word.length()):
				rtl.push_color(rainbow_at(float(i) / float(span)))
				rtl.add_text(word[i])
				rtl.pop()
		else:
			rtl.push_color(tone)
			rtl.add_text(word)
			rtl.pop()
		var icon: String = str(entry.get("icon", ""))
		if not icon.is_empty():
			rtl.add_text(" ")
			rtl.add_image(GemIcons.texture(icon, GemIcons.baked_size(14.0)), 13, 13, tone)
		if not hint.is_empty():
			rtl.pop()
		cursor = m.get_end()
	if cursor < text.length():
		rtl.add_text(text.substr(cursor))

static func effect_text(parent: Node, text: String, size: int = 13, color: Color = PAPER, bold: bool = false, width: float = 0.0) -> RichTextLabel:
	## A `wrap()` for a skill's own effect text, with its keywords picked out in color.
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0.0:
		rtl.custom_minimum_size.x = width
	if bold:
		rtl.push_font(bold_font())
	rtl.push_font_size(size)
	rtl.push_color(color)
	push_effect_text(rtl, text)
	rtl.pop_all()
	parent.add_child(rtl)
	return rtl

static func title(parent: Node, text: String, size: int = 26, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	## A display-face title with a soft shadow, for the name of a place or a moment.
	var l := label(parent, text, size, color, align)
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

static func heading(parent: Node, text: String, size: int = 13, color: Color = ACCENT) -> Label:
	var l := label(parent, text.to_upper(), size, color)
	l.add_theme_font_override("font", display_font())
	l.add_theme_constant_override("line_spacing", 0)
	return l

static func section(parent: Node, glyph: String, text: String, color: Color = ACCENT, size: int = 14) -> HBoxContainer:
	## A section header: its mark, its name in capitals, and a rule running out to the edge.
	## Mark, name and rule all take only the height they need and centre on the row, so the
	## three line up on one another whatever font metrics the name's face brings with it.
	var row := hbox(parent, 8)
	if not glyph.is_empty():
		icon(row, glyph, size + 4, color).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head := heading(row, text, size, color)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := ColorRect.new()
	line.color = Color(color, 0.25)
	line.custom_minimum_size = Vector2(20, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return row

static func icon(parent: Node, glyph: String, size: float = 18.0, tint: Color = PAPER, tooltip: String = "", rainbow: bool = false) -> TextureRect:
	return GemIcons.glyph(parent, glyph, size, tint, tooltip, rainbow)

static func rainbow_word(parent: Node, text: String, size: int = 13, saturation: float = 0.42) -> HBoxContainer:
	## A word no single color can carry, set letter by letter off the wheel. One label a
	## letter rather than one rich label: a RichTextLabel in a row of sized siblings needs
	## a width told to it or it draws nothing at all, and a word this short would rather
	## lose a little kerning than its existence.
	var row := hbox(parent, 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var span: int = maxi(1, text.length() - 1)
	for i in range(text.length()):
		var letter := label(row, text[i], size, rainbow_at(float(i) / float(span), saturation))
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row

static func stat(parent: Node, glyph: String, text: String, color: Color = PAPER, size: int = 15, tooltip: String = "", rainbow: bool = false) -> HBoxContainer:
	## A mark and a number, read as one thing: the way every quantity is shown.
	var row := hbox(parent, maxi(3, size / 4))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tooltip
	var mark := icon(row, glyph, size + 3, color, tooltip, rainbow)
	mark.mouse_filter = Control.MOUSE_FILTER_PASS
	if rainbow:
		## Never named "Value": that name means a Label something rewrites in place, and a
		## word set letter by letter is a row of them.
		rainbow_word(row, text, size)
		return row
	if text.is_empty():
		## A mark with no number beside it yet: no gap after it and nothing pushing it over,
		## or it sits off-centre in whatever holds it. The label itself stays, empty and of
		## no width, because a row whose number is written later looks it up by name.
		row.add_theme_constant_override("separation", 0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var value := label(row, text, size, color)
	value.name = "Value"
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row

static func pill(parent: Node, glyph: String, text: String, color: Color, size: int = 13, tooltip: String = "", rainbow: bool = false) -> PanelContainer:
	## A stat in a rounded capsule, for headers and strips.
	var box := PanelContainer.new()
	## The outline is mixed down onto the dark rather than laid over it at less than full
	## alpha: where a capsule's ends curve, the ring doubles back on itself inside one pixel
	## and a see-through outline reads heavier there than it does down the sides.
	var style := flat(Color(color, 0.12), SLATE_LOW.lerp(color, 0.45), 20, 5)
	## A pill with nothing but a mark in it is padded evenly, so the mark sits in its middle.
	style.content_margin_left = 9 if not text.is_empty() or rainbow else 8
	style.content_margin_right = 11 if not text.is_empty() or rainbow else 8
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = tooltip
	parent.add_child(box)
	stat(box, glyph, text, color, size, tooltip, rainbow)
	return box

static func button(parent: Node, text: String, callback: Callable = Callable(), size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: DeepAudio.play(str(b.get_meta("sound", "ui_tap"))))
	if callback.is_valid():
		b.pressed.connect(callback)
	parent.add_child(b)
	juice(b)
	return b

static func voice(control: Control, sound: String) -> Control:
	## What this control says when it is pressed. Everything says `ui_tap` unless told otherwise.
	control.set_meta("sound", sound)
	return control

static func icon_button(parent: Node, glyph: String, text: String, callback: Callable = Callable(), size: int = 15, tint: Color = PAPER, rainbow: bool = false) -> Button:
	## A button that says what it does with a mark as well as a word. A rainbow mark
	## carries its own color, so the tint above it has to be white or it flattens.
	var b := button(parent, text, callback, size)
	var edge: float = float(size) + 5.0
	b.icon = GemIcons.texture(glyph, GemIcons.baked_size(edge * 1.5), rainbow)
	b.add_theme_constant_override("icon_max_width", int(edge))
	b.add_theme_color_override("icon_normal_color", Color.WHITE if rainbow else tint)
	b.add_theme_color_override("icon_hover_color", Color.WHITE if rainbow else tint.lightened(0.25))
	b.expand_icon = false
	return b

static func gear_button(parent: Node, callback: Callable) -> Button:
	## The way into the game menu, for anyone who does not know about Esc.
	var b := icon_button(parent, "gear", "", callback, 17, MUTED)
	b.set_meta("sound", "ui_open")
	b.tooltip_text = "Menu (Esc)"
	b.add_theme_stylebox_override("normal", button_style(Color(0, 0, 0, 0), Color(LINE, 0.7), 8))
	b.custom_minimum_size = Vector2(42, 38)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

static func primary(parent: Node, glyph: String, text: String, callback: Callable = Callable(), size: int = 17, tone: Color = ACCENT) -> Button:
	## The one call to action on a page: filled with the accent and breathing gently.
	var b := icon_button(parent, glyph, text, callback, size, INK)
	b.set_meta("sound", "ui_confirm")
	var normal := button_style(tone, tone.lightened(0.35), 14)
	normal.shadow_color = Color(tone, 0.35)
	normal.shadow_size = 14
	var hover := button_style(tone.lightened(0.15), Color.WHITE, 14)
	hover.shadow_color = Color(tone, 0.55)
	hover.shadow_size = 20
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", button_style(tone.darkened(0.25), tone, 14))
	b.add_theme_stylebox_override("disabled", button_style(Color(tone.darkened(0.6), 0.6), Color(tone, 0.25), 14))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.6))
	b.add_theme_color_override("icon_disabled_color", Color(INK, 0.6))
	return b

static func tab_button(parent: Node, glyph: String, text: String, active: bool, callback: Callable, size: int = 14, badge: int = 0, rainbow: bool = false) -> Button:
	var b := icon_button(parent, glyph, text if badge <= 0 else "%s  %d" % [text, badge], callback, size, ACCENT if active else MUTED, rainbow)
	b.set_meta("sound", "ui_tab")
	if active:
		var on := button_style(Color(ACCENT, 0.16), ACCENT, 10)
		b.add_theme_stylebox_override("normal", on)
		b.add_theme_stylebox_override("hover", on)
		b.add_theme_color_override("font_color", ACCENT_HI)
	else:
		b.add_theme_stylebox_override("normal", button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10))
	return b

static func pager(parent: Node, page: int, pages: int, turn: Callable, size: int = 13) -> HBoxContainer:
	## Back and forth through a list longer than its page: "<  2 of 5  >". Pages never
	## scroll; a long list is turned like a book. `turn` is given the page to show.
	var row := hbox(parent, 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := icon_button(row, "prev", "", func() -> void: turn.call(page - 1), size, PAPER)
	back.disabled = page <= 0
	back.tooltip_text = "Previous page"
	var where := label(row, "%d of %d" % [page + 1, pages], size, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	where.custom_minimum_size.x = 60
	var ahead := icon_button(row, "next", "", func() -> void: turn.call(page + 1), size, PAPER)
	ahead.disabled = page >= pages - 1
	ahead.tooltip_text = "Next page"
	return row

static func pages(count: int, per_page: int) -> int:
	return maxi(1, ceili(float(count) / float(maxi(1, per_page))))

static func page_of(items: Array, page: int, per_page: int) -> Array:
	## The items on one page, with the page held inside the list's range.
	var last: int = pages(items.size(), per_page) - 1
	var at: int = clampi(page, 0, last)
	return items.slice(at * per_page, (at + 1) * per_page)

static func selected_style(button: Button, tone: Color = ACCENT) -> void:
	var on := button_style(Color(tone, 0.22), tone, 10)
	button.add_theme_stylebox_override("normal", on)
	button.add_theme_stylebox_override("hover", on)

static func spacer(parent: Node, horizontal: bool = true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

static func gap(parent: Node, pixels: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(pixels, pixels)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

static func rule(parent: Node, color: Color = LINE) -> Control:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line

static func chip(parent: Node, text: String, color: Color, size: int = 12, rainbow: bool = false) -> PanelContainer:
	var box := PanelContainer.new()
	var style := flat(Color(color, 0.16), Color(color, 0.55), 6, 5)
	style.content_margin_left = 7
	style.content_margin_right = 7
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	if rainbow:
		rainbow_word(box, text, size)
		return box
	label(box, text, size, color)
	return box

# --- motion ----------------------------------------------------------------------------------

static func juice(control: Control, grow: float = 1.035) -> void:
	## The pointer is answered: a control swells a touch on hover and dips on press.
	control.resized.connect(func() -> void: control.pivot_offset = control.size * 0.5)
	control.mouse_entered.connect(func() -> void:
		if control is BaseButton and (control as BaseButton).disabled:
			return
		DeepAudio.play("ui_hover", {"volume": 0.5, "gap": 0.07})
		var tween := control.create_tween()
		tween.tween_property(control, "scale", Vector2.ONE * grow, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	control.mouse_exited.connect(func() -> void:
		var tween := control.create_tween()
		tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT))
	if control is BaseButton:
		(control as BaseButton).button_down.connect(func() -> void:
			var tween := control.create_tween()
			tween.tween_property(control, "scale", Vector2.ONE * 0.96, 0.06))
		(control as BaseButton).button_up.connect(func() -> void:
			var tween := control.create_tween()
			tween.tween_property(control, "scale", Vector2.ONE * grow, 0.1))

static func pop_in(control: Control, delay: float = 0.0, from_scale: float = 0.94, seconds: float = 0.32) -> void:
	## Eases a freshly built control into view. Scale and alpha only, so containers keep
	## ownership of where it sits.
	if headless():
		return
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * from_scale
	var set_pivot := func() -> void: control.pivot_offset = control.size * 0.5
	control.resized.connect(set_pivot)
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, seconds).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, seconds + 0.08).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func stagger(nodes: Array, start: float = 0.0, step: float = 0.05, from_scale: float = 0.94) -> void:
	var at: float = start
	for node in nodes:
		if node is Control:
			pop_in(node, at, from_scale)
			at += step

static func pulse(control: Control, strength: float = 1.12, seconds: float = 0.35) -> void:
	if headless() or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * strength, seconds * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, seconds * 0.65).set_ease(Tween.EASE_IN_OUT)

static func breathe(control: Control, low: float = 0.72, seconds: float = 1.6) -> Tween:
	## A slow, endless fade between full and `low`, for things waiting on the player.
	if headless():
		return null
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "modulate:a", low, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate:a", 1.0, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	return tween

static func shake(control: Control, strength: float = 6.0, seconds: float = 0.3) -> void:
	if headless() or not is_instance_valid(control):
		return
	var tween := control.create_tween()
	var steps := 6
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		tween.tween_property(control, "rotation", deg_to_rad(randf_range(-1.0, 1.0) * strength * 0.4 * falloff), seconds / float(steps))
	tween.tween_property(control, "rotation", 0.0, 0.05)

# --- gauges ----------------------------------------------------------------------------------

class Bar extends Control:
	## A gauge that moves like one: the fill eases to its new share, a pale ghost of what was
	## lost trails behind it, a flash marks each change, and block rides along the bottom.
	var ratio: float = 1.0
	var fill: Color = DeepUi.HP
	var back: Color = DeepUi.HP_LOST
	var overlay: float = 0.0
	var overlay_color: Color = DeepUi.BLOCK
	var text: String = ""
	var glyph: String = ""
	var rounded: bool = true
	## A share of the bar shown pulsing at the end of the fill: what is about to be lost.
	var preview: float = 0.0:
		set(value):
			if not is_equal_approx(value, preview):
				preview = value
				set_process(true)
	var _shown: float = -1.0
	var _ghost: float = 1.0
	var _flash: float = 0.0
	var _flash_color: Color = Color.WHITE
	var _clock: float = 0.0
	var _shown_overlay: float = 0.0
	func _init(height: float = 10.0) -> void:
		custom_minimum_size = Vector2(60, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_values(new_ratio: float, new_text: String = "", new_overlay: float = 0.0) -> void:
		new_ratio = clampf(new_ratio, 0.0, 1.0)
		if _shown < 0.0 or not is_inside_tree() or DeepUi.headless():
			_shown = new_ratio
			_ghost = new_ratio
		elif not is_equal_approx(new_ratio, ratio):
			_flash = 1.0
			_flash_color = Color(1, 0.35, 0.3) if new_ratio < ratio else Color(0.6, 1, 0.7)
			if new_ratio > _ghost:
				_ghost = new_ratio
		ratio = new_ratio
		text = new_text
		overlay = clampf(new_overlay, 0.0, 1.0)
		set_process(true)
		queue_redraw()
	func _process(delta: float) -> void:
		_clock += delta
		var settled := true
		if not is_equal_approx(_shown, ratio):
			_shown = move_toward(_shown, ratio, maxf(0.4, absf(ratio - _shown) * 6.0) * delta)
			settled = false
		if _ghost > _shown:
			if _clock > 0.35:
				_ghost = move_toward(_ghost, _shown, 0.55 * delta)
			settled = false
		else:
			_ghost = _shown
			_clock = 0.0
		if not is_equal_approx(_shown_overlay, overlay):
			_shown_overlay = move_toward(_shown_overlay, overlay, 2.5 * delta)
			settled = false
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 3.0)
			settled = false
		if preview > 0.0:
			settled = false
		queue_redraw()
		if settled:
			_clock = 0.0
			set_process(false)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var radius: float = minf(size.y * 0.5, 5.0) if rounded else 0.0
		_box(r, back.darkened(0.2), radius)
		if _ghost > _shown:
			_box(Rect2(Vector2.ZERO, Vector2(size.x * _ghost, size.y)), Color(1, 0.92, 0.8, 0.55), radius)
		if _shown > 0.001:
			_box(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y)), fill, radius)
			_box(Rect2(Vector2(1, 1), Vector2(maxf(0.0, size.x * _shown - 2.0), size.y * 0.38)), Color(1, 1, 1, 0.16), radius * 0.6)
		if preview > 0.0 and _shown > 0.001:
			var cut: float = minf(preview, _shown)
			var pulse: float = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
			_box(Rect2(Vector2(size.x * (_shown - cut), 0), Vector2(size.x * cut, size.y)), Color(1, 0.95, 0.85, pulse), 0.0)
		if _shown_overlay > 0.0:
			var h: float = maxf(3.0, size.y * 0.32)
			_box(Rect2(Vector2(0, size.y - h), Vector2(size.x * _shown_overlay, h)), overlay_color, radius * 0.5)
		if _flash > 0.0:
			_box(r, Color(_flash_color, 0.35 * _flash), radius)
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color(0, 0, 0, 0)
		outline.border_color = Color(0, 0, 0, 0.55)
		outline.set_border_width_all(1)
		outline.set_corner_radius_all(int(radius))
		draw_style_box(outline, r)
		if not text.is_empty() and size.y >= 12.0:
			var font := ThemeDB.fallback_font
			var font_size := int(size.y * 0.78)
			var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var at := Vector2((size.x - measured.x) * 0.5, size.y * 0.5 + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.7))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.PAPER)
	func _box(rect: Rect2, color: Color, radius: float) -> void:
		if rect.size.x <= 0.5:
			return
		if radius <= 0.5:
			draw_rect(rect, color)
			return
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(minf(radius, rect.size.x * 0.5)))
		box.anti_aliasing = true
		draw_style_box(box, rect)

static func bar(parent: Node, height: float = 10.0, fill: Color = HP, back: Color = HP_LOST) -> Bar:
	var b := Bar.new(height)
	b.fill = fill
	b.back = back
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

# --- flourishes ------------------------------------------------------------------------------

static func float_text(parent: Control, at: Vector2, text: String, color: Color, size: int = 22, rise: float = 46.0, seconds: float = 0.9) -> Label:
	## A number that pops, rises and fades where something happened. Bigger numbers pop harder.
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.95))
	l.add_theme_constant_override("outline_size", maxi(4, size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 50
	parent.add_child(l)
	var width: float = l.get_minimum_size().x
	l.position = at - Vector2(width * 0.5, 0)
	l.pivot_offset = l.get_minimum_size() * 0.5
	l.scale = Vector2.ONE * 0.4
	var drift: float = randf_range(-18.0, 18.0)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "scale", Vector2.ONE, 0.18).set_delay(0.12)
	tween.tween_property(l, "position:y", at.y - rise, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "position:x", l.position.x + drift, seconds)
	tween.tween_property(l, "modulate:a", 0.0, seconds * 0.45).set_delay(seconds * 0.55)
	tween.chain().tween_callback(l.queue_free)
	return l

static func burst(parent: Control, at: Vector2, color: Color, amount: int = 16, speed: float = 160.0, seconds: float = 0.6, size: float = 5.0) -> void:
	## A spray of sparks in 2D, gone when it is done.
	if headless() or parent == null or not parent.is_inside_tree():
		return
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.92
	sparks.amount = amount
	sparks.lifetime = seconds
	sparks.texture = dot_texture()
	sparks.spread = 180.0
	sparks.direction = Vector2.UP
	sparks.initial_velocity_min = speed * 0.45
	sparks.initial_velocity_max = speed
	sparks.gravity = Vector2(0, 260)
	sparks.damping_min = 40.0
	sparks.damping_max = 90.0
	sparks.scale_amount_min = size / 32.0 * 0.6
	sparks.scale_amount_max = size / 32.0 * 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(color.lightened(0.5), 1.0))
	fade.set_color(1, Color(color, 0.0))
	sparks.color_ramp = fade
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = add
	sparks.position = at
	sparks.z_index = 60
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)

static func glow(parent: Control, color: Color, strength: float = 0.5, scale: float = 1.0) -> TextureRect:
	## A soft light behind whatever is placed after it in the same parent.
	var light := TextureRect.new()
	light.texture = glow_texture()
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.modulate = Color(color, strength)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = add
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(light)
	if scale != 1.0:
		light.set_anchor_and_offset(SIDE_LEFT, 0.5 - scale * 0.5, 0)
		light.set_anchor_and_offset(SIDE_RIGHT, 0.5 + scale * 0.5, 0)
		light.set_anchor_and_offset(SIDE_TOP, 0.5 - scale * 0.5, 0)
		light.set_anchor_and_offset(SIDE_BOTTOM, 0.5 + scale * 0.5, 0)
	return light

static func held(shown: Control) -> Control:
	## A drag preview hangs off the pointer by its middle. Godot pins one by its top left
	## corner, which makes everything picked up jump down and to the right as it is lifted.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge: Vector2 = shown.custom_minimum_size if shown.custom_minimum_size != Vector2.ZERO else shown.size
	shown.position = - edge * 0.5
	holder.add_child(shown)
	return holder

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func stone_marks(item: Dictionary) -> String:
	## Everything about one stone or one die that a card draws, as one string. A thing worked
	## on down the mine keeps its id, so a view that rebuilds on the id alone would go on
	## drawing the one that was there before.
	var out: String = "%s%s%s%s" % [str(item.get("id", "")), str(item.get("shape", "")), str(item.get("engraving", "")),
		"a" if bool(item.get("appraised", false)) else ""]
	for face in item.get("faces", []):
		out += "%d%s," % [int(face.get("value", 0)), str(face.get("kind", ""))]
	if item.has("cut"):
		out += "/%d/%d/%d/%s" % [int(item.get("carat", 0)), int(item.get("cut", 0)), int(item.get("clarity", 0)), str(item.get("inclusions", []))]
	return out

static func stone_name(stone: Dictionary) -> String:
	return DeepStone.name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone)

static func plural(count: int, word: String, many: String = "") -> String:
	return "%d %s" % [count, word if count == 1 else (many if not many.is_empty() else word + "s")]
