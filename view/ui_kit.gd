class_name DeepUi
extends RefCounted
## The frame everything sits in: deep blue slate cut like a stone (every panel and button has
## its corners faceted off rather than rounded), one warm accent, one line weight, one display
## face for titles. Stones, dice and beams glow; the kit itself stays calm but never still:
## panels ease in, buttons answer the pointer, numbers roll rather than jump.

const GemIcons = preload("res://view/gems/gem_icons.gd")

const INK := Color("0a0d18")
const SLATE := Color("131a2c")
const SLATE_HI := Color("1b2440")
const SLATE_LOW := Color("0d1222")
const GLASS := Color(0.07, 0.09, 0.16, 0.88)
const LINE := Color("2c3858")
const LINE_HI := Color("465783")
const PAPER := Color("e8edf9")
const MUTED := Color("8a96b6")
const DIM := Color("59658a")
## The facet: every corner the kit draws is cut straight across instead of rounded.
## StyleBoxFlat draws a corner of one segment as a chamfer.
const FACET_DETAIL: int = 1
## How much of a capsule's height stays as a flat facet at each end (`facet_ends`).
const END_FACET: float = 0.4
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
## How wide the arrow past a row of choices stands, and the empty column that balances it.
const SKIP_WIDTH: float = 92.0
## A pale lavender: Resonance's mark and, on its own, a fallback for anywhere its word can't
## be shown letter by letter (see EFFECT_KEYWORDS' "rainbow" flag, which is how the word itself
## is colored — flat text this close to PAPER's near-white would simply vanish into it).
const RESONANCE := Color("e4cdff")
## Opal's stand-in wherever one flat color has to be picked: a border, a background, a
## dot. The pack gives an opal a near-white body hue, which is right for the stone and
## wrong for the interface — beside a White gem the two would be the same pale wash. This
## is the middle of the rainbow its word and its mark are drawn with, and nobody else's.
const OPAL_TONE := Color("8ff0dc")
## Gold: the color the Transcendent rarity starts and ends its sweep on. See `shimmer_word`.
const TRANSCENDENT_TONE := Color("ffd98a")
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
 "spikes": "Retaliates once per attacking gem or ability, even against blocked hits. Lasts the fight. No cap.",
 "strength": "Each stack adds 1 damage to every hit its owner deals. Lasts the fight.",
 "bound": "Suppresses one die per stack for the next action, even if no dice remain.",
 "clouded": "On enemies: disables one random ability for its duration; reapplication extends the same ability. On players: disables a socket until the fogging enemy is hit.",
 "curse": "Each stack reduces hit damage dealt by 10% and increases hit damage taken by 10%. Maximum 10; loses one stack per turn.",
 "marked": "Every hit of the next gem, Birthstone or creature's move to land on it deals +25% per stack; the marks are spent once that gem is done, even if Block soaked its hits. No cap.",
 "dread": "Each stack lowers every enemy die one size tier, to a minimum d2. Loses one stack after each enemy action.",
 "dulled": "Each stack reduces effective Cut by one step, to a minimum Poor. Loses one stack per turn.",
 "lifeline": "Before lethal damage downs you, consumes all stacks and restores that much HP, up to maximum HP. Lasts this fight.",
 "cleanse": "Removes the stated number of debuff stacks, starting with Poison, then Stun, Curse, Marked, Dulled, Clouded and Dread.",
 "sparkle": "Maximum 100. The next stone find consumes every stack for +1 generation luck each. Carries between fights.",
 "block": "Absorbs hit damage before HP. Resets at your next turn; Retain preserves some. Poison bypasses Block.",
 "poison": "Loses HP equal to its stacks at turn end, then loses one stack. Bypasses Block.",
 "pyrite": "Currency in your bag plus combat earnings, less spending. Wager and Stake pay once per activation.",
 "opal": "Opals never work with one another: a Seam, Matrix or Echo never repeats, wakes or copies an opal, and a Doublet skips past opals to copy the gem behind them.",
 "fizzle": "A gem fizzles when it stays dark: its trigger is not met, or its socket is buried or clouded. Resonance carries on past it.",
 "carat": "Increases gem magnitude; whole-number effects usually gain additional procs instead. Temporary bonuses last this fight.",
 "cut": "The gem’s trigger/effect ladder: Poor, Fair, Good, Fine, Perfect. Temporary bonuses last this fight.",
 "clarity": "Pristine doubles base Resonance gain. Flawless triples it, grants ×1.5 magnitude and activates the Flawless line. Temporary bonuses preserve inclusions.",
 "phantom": "An extra temporary die read by later gems. It cannot receive permanent face upgrades.",
 "reflect": "Splits the next blow a creature lands on you: part goes straight back at whoever threw it, the rest lands. One blow a stack; they fall away at your next turn.",
 "crown": "A die showing its own top face. On Gambler's dice, the 7.",
 "void": "Takes no socket: rides beside a socketed gem and fires right after it.",
 "changing face": "Puck's Motley: a face different from last turn's pays double, and one more for every turn running the faces keep changing (×2, ×3, ×4). The same face twice, or a turn with no face, starts over.",
 "turn over": "The die lands on the face underneath: its mirror face (a 2 on a d6 to its 5), always of the other parity, or the nearest face of the other parity it has.",
 "amplif": "Increases the next evaluated gem’s magnitude. Consumed even if that gem fizzles.",
 "inverted": "Turned around: damage becomes Block and Block becomes damage; healing becomes Poison and Poison becomes healing; Regeneration becomes Poison; Spikes and Marked swap; Strength and Curse swap; Retain counts as Block.",
 "permanent": "Lasts for the current run, including later fights. Does not alter your stored collection.",
 "stun": "Skips the next action per stack. Enemies break out after three consecutive missed actions and resist Stun through the following turn."
}
## The mark each chamber kind is drawn with, anywhere a chamber is shown.
## An oddity wears the swirl; the question mark is a dark mouth's alone.
const CHAMBER_GLYPHS: Dictionary = {"fight": "sword", "elite": "skull", "vein": "pick", "oddity": "swirl", "motherlode": "gem",
	"merchant": "purse", "smithy": "anvil", "carver": "face", "landing": "lift", "warden": "crown", "vug": "pick", "hidden": "arch",
	"well": "drop", "vat": "flask", "altar": "altar", "rest_stop": "heart"}
const CHAMBER_colorS: Dictionary = {"fight": Color("ff8a70"), "elite": Color("ff5f7a"), "vein": Color("ffc56a"), "oddity": Color("b58cff"),
	"motherlode": Color("ffe07a"), "merchant": Color("5fd4c8"), "smithy": Color("8fb8ff"), "carver": Color("f2a0d0"), "landing": Color("7fd1a8"),
	"warden": Color("ff4d5e"), "vug": Color("ffc56a"), "hidden": Color("8792a6"), "well": Color("6fd8e8"), "vat": Color("b9e769"), "altar": Color("d7a6ff"),
	"rest_stop": Color("8fe388")}
## Each oddity card's own mark: the face of its room, and what its room on the chart wears
## once the party has been in. A card that is a room of its own wears that room's mark.
const ODDITY_GLYPHS: Dictionary = {"CUTTERS_WHEEL": "cut", "ACID_BATH": "dissolving_rock", "CRUCIBLE": "bolted_gem", "GEODE": "geode",
	"OLD_PROSPECTOR": "person", "SHRINE": "shrine_gate", "IDOL": "squat_idol", "ECHO_CHAMBER": "rough_copy", "COLLECTOR": "cushioned_gem",
	"LOUPE_CABINET": "loupe", "FIELD_MEDIC": "heart", "TUMBLER": "reroll", "SEAM": "gem_cavity", "SMITHY": "anvil", "CARVER": "face",
	"ANNEALING_OVEN": "thermometer", "WISHING_WELL": "drop", "VAT": "flask", "HOLLOW": "void_gem"}

static var _display: Font = null
static var _caps: Font = null
static var _gold: Shader = null
static var _bold: Font = null
static var _body: Font = null
static var _semibold: Font = null
## How many screen pixels one canvas pixel is drawn at: 1.0 at 1600 wide, 0.8 at 1280.
## The app sets it whenever the window changes size (`rescale`).
static var text_scale: float = 1.0
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
	## The one display face: Jaro (shipped with the game, SIL Open Font License), the face of
	## the store page's title, set at a display optical size with a little air between the
	## letters. A system face stands in if the file is missing.
	if _display == null:
		var face := FontVariation.new()
		var shipped: Variant = load("res://view/fonts/Jaro.ttf") if ResourceLoader.exists("res://view/fonts/Jaro.ttf") else null
		if shipped is Font:
			face.base_font = shipped
			face.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("opsz"): 36}
		else:
			var system := SystemFont.new()
			system.font_names = PackedStringArray(["Jaro", "Impact", "Arial Black", "sans-serif"])
			system.font_weight = 700
			face.base_font = system
		face.spacing_glyph = 1
		_display = face
	return _display

## Titles this size or smaller are set in `caps_font()`: Jaro is too heavy to read at label size.
const SMALL_TITLE := 14

static func caps_font() -> Font:
	## The face for small titles and labels: Cinzel (shipped with the game, SIL Open Font
	## License), bold, whose lowercase are small capitals, with a little air between them.
	if _caps == null:
		var face := FontVariation.new()
		var shipped: Variant = load("res://view/fonts/Cinzel.ttf") if ResourceLoader.exists("res://view/fonts/Cinzel.ttf") else null
		if shipped is Font:
			face.base_font = shipped
			face.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
		else:
			var system := SystemFont.new()
			system.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Palatino Linotype", "Book Antiqua", "Georgia", "serif"])
			system.font_weight = 700
			face.base_font = system
		face.spacing_glyph = 1
		_caps = face
	return _caps

static func title_font(font_size: int) -> Font:
	## The display face for a title of this size: Jaro, or Cinzel once it is label-sized.
	return caps_font() if font_size <= SMALL_TITLE else display_font()

static func cut_title(parent: Node, text: String, font_size: int) -> Control:
	## The game's name drawn the way the store page draws it: Jaro in gold, cut on a shallow
	## diagonal (from two thirds down on the left to two fifths down on the right), the top
	## half slipped up and to the right, and the whole word turned 0.6 degrees back so it
	## does not seem to lean.
	var font: Font = display_font()
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var h: float = font.get_height(font_size)
	var pad: float = font_size * 0.2
	var box := Control.new()
	box.custom_minimum_size = Vector2(w + font_size * 0.12, h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(box)
	var turn := Node2D.new()
	turn.position = Vector2(w, h) * 0.5
	turn.rotation = deg_to_rad(-0.6)
	box.add_child(turn)
	var left: float = h * 0.66
	var right: float = h * 0.40
	var halves: Array = [
		[PackedVector2Array([Vector2(-pad, -pad), Vector2(w + pad, -pad), Vector2(w + pad, right), Vector2(-pad, left)]), Vector2(0.03, -0.035) * font_size],
		[PackedVector2Array([Vector2(-pad, left), Vector2(w + pad, right), Vector2(w + pad, h + pad), Vector2(-pad, h + pad)]), Vector2.ZERO],
	]
	for half in halves:
		## Each half is the word masked by its side of the cut; the mask moves with its half.
		var mask := Polygon2D.new()
		mask.polygon = half[0]
		mask.position = -Vector2(w, h) * 0.5 + half[1]
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		mask.antialiased = true
		turn.add_child(mask)
		var word := Label.new()
		word.text = text
		word.add_theme_font_override("font", font)
		word.add_theme_font_size_override("font_size", font_size)
		word.material = gold_material(h)
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.add_child(word)
	## The cut itself: a thin bright line over the word, brightest in the middle.
	## A strip of quads rather than a Line2D, which draws nothing beside the clipping masks.
	var line := Polygon2D.new()
	var half_width: float = maxf(0.6, font_size * 0.007)
	var stops: Array = [[-0.04, 0.0], [0.25, 0.8], [0.5, 1.0], [0.75, 0.8], [1.04, 0.0]]
	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	var shades := PackedColorArray()
	for stop in stops:
		var at := Vector2(w * float(stop[0]), lerpf(left, right, float(stop[0])))
		top_edge.append(at - Vector2(0, half_width))
		bottom_edge.append(at + Vector2(0, half_width))
		shades.append(Color(1, 0.97, 0.85, float(stop[1])))
	bottom_edge.reverse()
	var back := shades.duplicate()
	back.reverse()
	line.polygon = top_edge + bottom_edge
	line.vertex_colors = shades + back
	line.position = -Vector2(w, h) * 0.5
	line.antialiased = true
	turn.add_child(line)
	return box

static func gold_material(height: float) -> ShaderMaterial:
	## Paints whatever it is on with the store page's gold, light at the top and deep at the
	## bottom of a box `height` tall.
	if _gold == null:
		_gold = Shader.new()
		_gold.code = """shader_type canvas_item;
uniform float height = 20.0;
varying float y;
void vertex() { y = VERTEX.y; }
void fragment() {
	float t = clamp(y / height, 0.0, 1.0);
	vec3 a = vec3(1.0, 0.945, 0.722), b = vec3(1.0, 0.843, 0.416), c = vec3(0.886, 0.698, 0.227), d = vec3(0.655, 0.490, 0.133);
	vec3 gold = t < 0.3 ? mix(a, b, t / 0.3) : (t < 0.62 ? mix(b, c, (t - 0.3) / 0.32) : mix(c, d, (t - 0.62) / 0.38));
	COLOR = vec4(gold, COLOR.a);
}"""
	var material := ShaderMaterial.new()
	material.shader = _gold
	material.set_shader_parameter("height", height)
	return material

static func release_fonts() -> void:
	## Lets go of the faces before the engine shuts down. A font kept in a static variable
	## past the end of the scene tree is freed after the text server is gone, which crashes
	## the game on its way out.
	_display = null
	_caps = null
	_gold = null
	_body = null
	_semibold = null
	_bold = null
	## The same goes for the shared textures: the glows and the drawn switches.
	_glow = null
	_dot = null
	_switches.clear()
	_knobs.clear()
	_shared_theme = null

static func body_font() -> Font:
	## The face everything else is set in: Barlow, shipped with the game (SIL Open Font
	## License), a little narrow so long lines fit; the engine's own face if it is missing.
	if _body == null:
		var shipped: Variant = load("res://view/fonts/Barlow-Regular.ttf") if ResourceLoader.exists("res://view/fonts/Barlow-Regular.ttf") else null
		_body = shipped if shipped is Font else ThemeDB.fallback_font
	return _body

static func semibold_font() -> Font:
	## Barlow SemiBold, the face small text is set in: Regular's strokes are thinner than a
	## screen pixel once the window draws the game smaller, and break up into jagged bits.
	if _semibold == null:
		var shipped: Variant = load("res://view/fonts/Barlow-SemiBold.ttf") if ResourceLoader.exists("res://view/fonts/Barlow-SemiBold.ttf") else null
		_semibold = shipped if shipped is Font else body_font()
	return _semibold

static func bold_font() -> Font:
	## Barlow's bold, for body text that must catch the eye before anything else on the page:
	## an effect's text, a value the player is meant to read.
	if _bold == null:
		var shipped: Variant = load("res://view/fonts/Barlow-Bold.ttf") if ResourceLoader.exists("res://view/fonts/Barlow-Bold.ttf") else null
		if shipped is Font:
			_bold = shipped
		else:
			var system := SystemFont.new()
			system.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial", "DejaVu Sans", "sans-serif"])
			system.font_weight = 700
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
	facet(box)
	return box

static func facet(box: StyleBoxFlat) -> StyleBoxFlat:
	## Cuts a box's corners straight across: the shape everything in the kit is drawn in.
	## A box with its own rounded look (a dot, a gauge) simply never calls this.
	box.corner_detail = FACET_DETAIL
	return box

## The in-run look (docs/UI_REDO.md): opaque plates with a heavy outline and a hard shadow.
const LEDGER_FILL := Color("11141d")
const LEDGER_LINE := Color("2f3752")
const LEDGER_SHADOW := Color("05070c")
const LEDGER_CUT: int = 12

static func ledger(fill: Color = LEDGER_FILL, line: Color = LEDGER_LINE, cut: int = LEDGER_CUT, pad: int = 12, width: int = 3, shadow: int = 4) -> StyleBoxFlat:
	## A Ledger plate: opaque, every corner cut straight across by `cut`, outlined `width`
	## wide, with a hard shadow `shadow` pixels down and to the right (the engine's shadow
	## is the box again, offset, with a soft ring `shadow_size` wide round it; one pixel of
	## ring is as hard as it draws).
	var box := flat(fill, line, cut, pad, width)
	if shadow > 0:
		box.shadow_color = LEDGER_SHADOW
		box.shadow_size = 1
		box.shadow_offset = Vector2(shadow, shadow)
	return box

static func capsule(control: Control, fill: Color, line: Color, width: int = 2, pad_x: int = 10, pad_y: int = 3) -> StyleBoxFlat:
	## A capsule with flat ends: its corners cut as `facet_ends` cuts a pill's, leaving a
	## facet of the height at each end rather than a point (the shape the workshop's pills
	## have). The status chips, the dock's badges and the ask's name capsule are all this.
	var box := flat(fill, line, 20, pad_y, width)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	facet_ends(control, box)
	return box

static func ledger_button(b: Button, fill: Color = SLATE_HI, line: Color = LEDGER_LINE, pad: int = 10, text: Color = PAPER) -> Button:
	## Dresses a button in the Ledger look: chamfered, outlined, a hard shadow under it, and
	## on hover the outline lights; pressed, the fill goes to the accent.
	var normal := ledger(fill, line, 8, pad, 2, 3)
	normal.content_margin_left = pad + 6
	normal.content_margin_right = pad + 6
	var hover := ledger(fill.lightened(0.12), LINE_HI, 8, pad, 2, 3)
	hover.content_margin_left = pad + 6
	hover.content_margin_right = pad + 6
	var pressed := ledger(ACCENT_DIM, ACCENT, 8, pad, 2, 1)
	pressed.content_margin_left = pad + 6
	pressed.content_margin_right = pad + 6
	var disabled := ledger(Color(fill, 0.4), Color(line, 0.4), 8, pad, 2, 0)
	disabled.content_margin_left = pad + 6
	disabled.content_margin_right = pad + 6
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", text)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(text, 0.4))
	b.add_theme_color_override("icon_disabled_color", Color(text, 0.4))
	b.add_theme_font_override("font", bold_font())
	return b

static func ledger_primary(b: Button, tone: Color = ACCENT) -> Button:
	## The one call to action on a Ledger plate: filled with the accent, ink on it, the same
	## hard shadow, and no glow.
	var normal := ledger(tone, tone.lightened(0.3), 8, 10, 2, 3)
	var hover := ledger(tone.lightened(0.15), Color.WHITE, 8, 10, 2, 3)
	var pressed := ledger(tone.darkened(0.25), tone, 8, 10, 2, 1)
	var disabled := ledger(Color(tone.darkened(0.5), 0.5), Color(tone, 0.3), 8, 10, 2, 0)
	for box in [normal, hover, pressed, disabled]:
		box.content_margin_left = 18
		box.content_margin_right = 18
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.55))
	b.add_theme_color_override("icon_disabled_color", Color(INK, 0.55))
	b.add_theme_font_override("font", bold_font())
	return b

static func end_corner(height: float) -> int:
	## The corner a capsule this tall is cut at, leaving a flat facet `END_FACET` of its height
	## at each end. A corner of half the height or more closes each end to a point, and a
	## point cuts across the mark and the digits sitting just inside it.
	return maxi(2, roundi(height * (1.0 - END_FACET) * 0.5))

static func facet_ends(control: Control, box: StyleBoxFlat) -> StyleBoxFlat:
	## Keeps a capsule's ends flat at whatever height it is laid out at: its corners are cut at
	## the radius it was given or `end_corner` of its height, whichever is smaller.
	facet(box)
	var asked: int = box.corner_radius_top_left
	control.resized.connect(func() -> void:
		var corner: int = mini(asked, end_corner(control.size.y))
		if box.corner_radius_top_left != corner:
			box.set_corner_radius_all(corner))
	return box

static func raised(bg: Color, border: Color, radius: int = 10, pad: int = 12, shadow: float = 0.45) -> StyleBoxFlat:
	## A panel that sits on the page, in the Ledger look (docs/UI_REDO.md): a 2 px outline and
	## a hard shadow down and to the right. A panel meant to be a panel (nearly opaque) is
	## made fully so; a faint tint (a lit choice, a mark) keeps its own see-through fill.
	var fill: Color = bg
	if fill.a >= 0.8:
		fill.a = 1.0 if fill.a >= 0.95 else maxf(fill.a, 0.96)
	var box := flat(fill, border, radius, pad, 2)
	if shadow > 0.0:
		box.shadow_color = Color(LEDGER_SHADOW, clampf(0.5 + shadow, 0.0, 1.0))
		box.shadow_size = 1
		var drop: float = clampf(float(radius) / 3.0, 2.0, 4.0)
		box.shadow_offset = Vector2(drop, drop)
	return box

static func button_style(bg: Color, border: Color, pad: int = 10) -> StyleBoxFlat:
	## Every button in the game: chamfered, a 2 px outline and the Ledger's hard shadow.
	var box := flat(bg, border, 8, pad, 2)
	box.content_margin_left = pad + 6
	box.content_margin_right = pad + 6
	box.content_margin_top = pad - 2
	box.content_margin_bottom = pad - 2
	if bg.a > 0.0:
		box.shadow_color = LEDGER_SHADOW
		box.shadow_size = 1
		box.shadow_offset = Vector2(3, 3)
	return box

static func theme(scale: float = 1.0) -> Theme:
	var t := Theme.new()
	t.default_font_size = int(15 * scale)
	t.default_font = text_face(t.default_font_size)
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
	t.set_stylebox("panel", "TooltipPanel", ledger(LEDGER_FILL, LEDGER_LINE, 8, 9, 2, 3))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font("font", "TooltipLabel", semibold_font())
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, flat(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 4, 0))
		t.set_stylebox("grabber", bar, flat(Color(LINE_HI, 0.8), Color(0, 0, 0, 0), 4, 3))
		t.set_stylebox("grabber_highlight", bar, flat(ACCENT_DIM, Color(0, 0, 0, 0), 4, 3))
		t.set_stylebox("grabber_pressed", bar, flat(ACCENT, Color(0, 0, 0, 0), 4, 3))
	## The engine's slider is a hairline track with a small knob, drawn for a light page: on
	## these panels the track vanishes and all that is left is a dot nobody takes for a slider.
	## Here the track is a slate channel, the part already taken is lit gold, and the knob is
	## big enough to see and grab.
	var channel := flat(Color("1b2230"), LINE_HI.lightened(0.15), 5, 0)
	channel.content_margin_top = 4
	channel.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", channel)
	var taken := flat(Color(ACCENT, 0.92), ACCENT_HI, 5, 0)
	taken.content_margin_top = 4
	taken.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", taken)
	var taken_hot := flat(ACCENT_HI, ACCENT_HI, 5, 0)
	taken_hot.content_margin_top = 4
	taken_hot.content_margin_bottom = 4
	t.set_stylebox("grabber_area_highlight", "HSlider", taken_hot)
	t.set_icon("grabber", "HSlider", slider_knob(false))
	t.set_icon("grabber_highlight", "HSlider", slider_knob(true))
	t.set_icon("grabber_disabled", "HSlider", slider_knob(false, true))
	## The engine's own switch is drawn for a light page: off, its track is a dark grey that
	## vanishes into these panels and the setting stops looking like something to click.
	for entry in [["checked", true, false], ["unchecked", false, false], ["checked_disabled", true, true], ["unchecked_disabled", false, true],
			["checked_mirrored", true, false], ["unchecked_mirrored", false, false], ["checked_disabled_mirrored", true, true], ["unchecked_disabled_mirrored", false, true]]:
		t.set_icon(str(entry[0]), "CheckButton", switch_icon(bool(entry[1]), bool(entry[2]), str(entry[0]).ends_with("mirrored")))
	return t

static var _switches: Dictionary = {}
static var _knobs: Dictionary = {}
static var _shared_theme: Theme = null
const THEMED_GROUP: StringName = &"deep_themed"

static func shared_theme() -> Theme:
	## One theme for the whole game, built once and again only when `rescale` moves the text
	## face, so opening a sheet does not draw some forty boxes all over again.
	if _shared_theme == null:
		_shared_theme = theme()
	return _shared_theme

static func use_theme(control: Control) -> void:
	## Gives a sheet the shared theme and keeps it on the newest one after a rescale.
	control.theme = shared_theme()
	if not control.is_in_group(THEMED_GROUP):
		control.add_to_group(THEMED_GROUP)

static func slider_knob(hot: bool, disabled: bool = false) -> Texture2D:
	## A slider's knob: a round paper button ringed in gold, lit brighter under the pointer.
	var key: String = "%s%s" % [hot, disabled]
	if _knobs.has(key):
		return _knobs[key]
	var edge: int = 22
	var image := Image.create(edge, edge, false, Image.FORMAT_RGBA8)
	var centre := Vector2(edge, edge) * 0.5
	var radius: float = float(edge) * 0.5 - 1.0
	var ring: Color = (ACCENT_HI if hot else ACCENT) if not disabled else LINE_HI
	var face: Color = Color.WHITE if hot else PAPER
	for y in range(edge):
		for x in range(edge):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(centre)
			var cover: float = clampf(radius + 0.5 - d, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var inner: float = clampf(radius - 3.0 + 0.5 - d, 0.0, 1.0)
			var pixel: Color = ring.lerp(face, inner)
			pixel.a = cover * (0.5 if disabled else 1.0)
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	_knobs[key] = texture
	return texture

static func switch_icon(on: bool, disabled: bool = false, mirrored: bool = false) -> Texture2D:
	## A toggle's track and knob: a lit gold track with the knob at its far end when on, an
	## outlined slate track with the knob at its near end when off. Drawn once per look.
	var key: String = "%s%s%s" % [on, disabled, mirrored]
	if _switches.has(key):
		return _switches[key]
	var w: int = 46
	var h: int = 26
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var radius: float = float(h) * 0.5 - 1.0
	var ends: Array = [Vector2(radius + 1.0, h * 0.5), Vector2(w - radius - 1.0, h * 0.5)]
	var track: Color = Color(ACCENT, 0.92) if on else Color("1b2230")
	var edge: Color = ACCENT_HI if on else LINE_HI.lightened(0.15)
	var knob_tone: Color = PAPER if on else MUTED
	var knob_at: Vector2 = ends[1] if on != mirrored else ends[0]
	var fade: float = 0.45 if disabled else 1.0
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			## Distance to the track's spine, so the track is a capsule with an edge 1.5 px wide.
			var along: float = clampf(p.x, ends[0].x, ends[1].x)
			var from_spine: float = p.distance_to(Vector2(along, h * 0.5))
			var cover: float = clampf(radius + 0.5 - from_spine, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var inner: float = clampf(radius - 1.5 + 0.5 - from_spine, 0.0, 1.0)
			var pixel: Color = edge.lerp(track, inner)
			var knob: float = clampf(radius - 3.5 + 0.5 - p.distance_to(knob_at), 0.0, 1.0)
			pixel = pixel.lerp(knob_tone, knob)
			pixel.a = cover * fade * (pixel.a if knob <= 0.0 else 1.0)
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	_switches[key] = texture
	return texture

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

## The smallest any text is set, whatever a caller asks. A page that no longer fits at this
## size is split into pages, never set smaller.
const MIN_TEXT: int = 12
## The same floor in screen pixels: a smaller window draws the whole game smaller (0.8 at
## 1280 wide), so the floor in canvas pixels rises until the smallest text still lands on at
## least this many real ones. It stops rising at MAX_TEXT_FLOOR, which is as far as the
## tightest pages can grow before they no longer fit.
const READABLE_PX: float = 12.0
const MAX_TEXT_FLOOR: int = 15
## Text drawn under this many screen pixels is set in SemiBold instead of Regular.
const SEMIBOLD_UNDER_PX: float = 13.0
## Every label, button and effect text whose size goes through `set_text_size`, so a change
## of window size can set it again (`rescale`).
const TEXT_GROUP: StringName = &"deep_text"

static func min_text() -> int:
	## The smallest text, in canvas pixels, at the current window size.
	return clampi(ceili(READABLE_PX / maxf(text_scale, 0.01) - 0.05), MIN_TEXT, MAX_TEXT_FLOOR)

static func readable(size: int) -> int:
	## `size`, raised to the floor if it is under it.
	return maxi(size, min_text())

static func text_face(size: int) -> Font:
	## Regular for text big enough on screen, SemiBold for text that would break up.
	return semibold_font() if float(size) * text_scale < SEMIBOLD_UNDER_PX else body_font()

static func caps_size(size: int) -> int:
	## The floor for words set in capitals (`caps_font`), which stand a cap-height tall
	## everywhere and read at two pixels less than lowercase.
	return maxi(size, min_text() - 2)

static func set_text_size(control: Control, size: int) -> void:
	## Sets a control's text size (raised to the floor) and its face, and keeps both up to date
	## when the window changes size. A face the caller set afterwards (bold, display) is kept.
	control.set_meta(&"text_asked", size)
	if not control.is_in_group(TEXT_GROUP):
		control.add_to_group(TEXT_GROUP)
	_apply_text_size(control)

static func _apply_text_size(control: Control) -> void:
	var rich: bool = control is RichTextLabel
	var size_name: StringName = &"normal_font_size" if rich else &"font_size"
	var face_name: StringName = &"normal_font" if rich else &"font"
	## A size the caller set by hand since (a count that grows) becomes the size asked for.
	if control.has_meta(&"text_set") and control.get_theme_font_size(size_name) != int(control.get_meta(&"text_set")):
		control.set_meta(&"text_asked", control.get_theme_font_size(size_name))
	var size: int = readable(int(control.get_meta(&"text_asked", MIN_TEXT)))
	control.add_theme_font_size_override(size_name, size)
	control.set_meta(&"text_set", size)
	if control.has_theme_font_override(face_name):
		var face: Font = control.get_theme_font(face_name)
		if face != body_font() and face != semibold_font():
			return
	control.add_theme_font_override(face_name, text_face(size))

static func rescale(root: Control) -> void:
	## Called when the window changes size: works out the new draw scale and, if the floor or
	## the small-text face moved with it, sets every registered text again.
	var window: Window = root.get_window()
	var canvas: Vector2 = root.get_viewport_rect().size
	if window == null or canvas.x <= 0.0 or window.size.x <= 0:
		return
	var was_floor: int = min_text()
	var was_face: Font = text_face(15)
	text_scale = float(window.size.x) / canvas.x
	if min_text() == was_floor and text_face(15) == was_face:
		return
	_shared_theme = theme()
	root.theme = _shared_theme
	for node in root.get_tree().get_nodes_in_group(THEMED_GROUP):
		(node as Control).theme = _shared_theme
	for node in root.get_tree().get_nodes_in_group(TEXT_GROUP):
		_apply_text_size(node as Control)

static func label(parent: Node, text: String, size: int = 15, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	set_text_size(l, size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	## Centred down the label's own box. A label in a row is stretched to the row's height,
	## and text drawn from the top of that box sits a few pixels above the mark beside it —
	## which is every misaligned word on every strip and dock in the game.
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func fit_label(parent: Node, text: String, size: int, color: Color, width: float, align: int = HORIZONTAL_ALIGNMENT_CENTER, floor_size: int = MIN_TEXT) -> Label:
	## A label that steps its font down until the whole text fits `width`, so a long name is
	## smaller rather than cut off. Past the floor size (never under MIN_TEXT) it clips instead
	## of going unreadable.
	var l := label(parent, text, size, color, align)
	var fitted: int = readable(size)
	var least: int = readable(floor_size)
	while fitted > least and text_face(fitted).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	set_text_size(l, fitted)
	l.custom_minimum_size.x = width
	l.clip_text = true
	return l

static func skill_name(stone: Dictionary) -> String:
	## Just the skill ("Strike"): the grade words are drawn as marks on the picture instead.
	if DeepStone.is_geode(stone):
		return DeepStone.raw_name(stone)
	if not bool(stone.get("appraised", false)):
		return "%s raw" % DeepStone.size_name(int(stone.get("carat", 1)))
	if DeepStone.is_birthstone(stone):
		return str(stone.get("name", "Birthstone"))
	return str(DeepStone.skill_of(stone).get("name", stone.get("skill", "stone")))

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
	set_text_size(rtl, size)
	if bold:
		rtl.push_font(bold_font())
	rtl.push_color(color)
	push_effect_text(rtl, text)
	rtl.pop_all()
	parent.add_child(rtl)
	return rtl

static func title(parent: Node, text: String, size: int = 26, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	## A display-face title with a soft shadow, for the name of a place or a moment.
	var l := label(parent, text, size, color, align)
	l.add_theme_font_override("font", title_font(size))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

static func heading(parent: Node, text: String, size: int = 13, color: Color = ACCENT) -> Label:
	var l := label(parent, text.to_upper(), size, color)
	l.add_theme_font_override("font", title_font(size))
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

static func shimmer_word(parent: Node, text: String, size: int = 13) -> HBoxContainer:
	## The one word written in moving gold and every color: Transcendent, the rarity no roll
	## gives. The letters chase a slow sweep along the word, so it reads alive even standing still.
	var row := Shimmer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	for i in range(text.length()):
		var letter := label(row, text[i], size, TRANSCENDENT_TONE)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.paint(0.0)
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
	## A stat in a faceted capsule, for headers and strips.
	var box := PanelContainer.new()
	## The outline is mixed down onto the dark rather than laid over it at less than full
	## alpha: where a capsule's ends turn, the ring doubles back on itself inside one pixel
	## and a see-through outline reads heavier there than it does down the sides.
	## Its ends are cut flat (`facet_ends`) rather than to a point, which bit into the mark
	## and the last digit; a short pill takes a smaller corner still and roomier sides.
	var short: bool = not rainbow and text.length() <= 3
	var style := flat(Color(color, 0.12), SLATE_LOW.lerp(color, 0.45), 8 if short else 20, 5)
	facet_ends(box, style)
	## A pill with nothing but a mark in it is padded evenly, so the mark sits in its middle.
	style.content_margin_left = 9 if not text.is_empty() or rainbow else 8
	style.content_margin_right = 11 if not text.is_empty() or rainbow else 8
	if short:
		style.content_margin_left = 8 if text.is_empty() else 10
		style.content_margin_right = 8 if text.is_empty() else 10
		style.content_margin_top = 6
		style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = tooltip
	parent.add_child(box)
	stat(box, glyph, text, color, size, tooltip, rainbow)
	return box

static func button(parent: Node, text: String, callback: Callable = Callable(), size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	set_text_size(b, size)
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
	## Filled with its tone, a hard shadow under it and no glow: the Ledger's call to action.
	var normal := button_style(tone, tone.lightened(0.35), 14)
	var hover := button_style(tone.lightened(0.15), Color.WHITE, 14)
	var pressed := button_style(tone.darkened(0.25), tone, 14)
	pressed.shadow_offset = Vector2(1, 1)
	var disabled := button_style(Color(tone.darkened(0.6), 0.6), Color(tone, 0.25), 14)
	disabled.shadow_size = 0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(key, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.6))
	b.add_theme_color_override("icon_disabled_color", Color(INK, 0.6))
	return b

## A button that sells something: its own fill, never the accent, so the coin on it reads.
const TRADE := Color("b99cff")

static func coin_safe(tone: Color, instead: Color = INFO) -> Color:
	## A fill a coin can sit on: any tone but a yellow one (the accent, a Peerless gold), which
	## the coin would melt into.
	var yellow: bool = tone.s > 0.35 and tone.h > 0.09 and tone.h < 0.19
	return instead if yellow else tone

static func price_chip(parent: Node, sum: String, size: int = 13, tone: Color = ACCENT_HI, boxed: bool = true, glyph: String = "coin") -> PanelContainer:
	## A sum of gold as every button shows one: the coin, then the number. Gold is never written
	## out as a word on a button. `boxed` sets it in a dark capsule (no outline) for a fill that
	## is not the button's own; on a button it is bare and takes the button's text color. A sum
	## of pyrite is the same tag with the nugget (`glyph` "ore") in place of the coin.
	var chip := PanelContainer.new()
	var style := facet_ends(chip, flat(Color(INK, 0.62) if boxed else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0))
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.name = "Price"
	parent.add_child(chip)
	var row := stat(chip, glyph, sum, tone, size)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in row.get_children():
		(part as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip

static func priced(b: Button, sum: String, size: int = -1, glyph: String = "coin") -> Button:
	## Sets a price tag (`price_chip`) at the right end of a button built with its own mark and
	## words, and widens the button's right margin to make room for it. The tag dims with the
	## button when it is disabled. `sum` is the number as shown: "240", or "+38" for a payout.
	var font_size: int = size if size > 0 else readable(b.get_theme_font_size("font_size") - 2)
	var chip := price_chip(b, sum, font_size, b.get_theme_color("font_color"), false, glyph)
	var gap: float = 10.0
	var room: float = chip.get_combined_minimum_size().x + gap
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box: StyleBox = b.get_theme_stylebox(state)
		if box == null:
			continue
		var wider: StyleBox = box.duplicate()
		wider.content_margin_right = maxf(0.0, box.get_margin(SIDE_RIGHT)) + room
		b.add_theme_stylebox_override(state, wider)
	## Also run on every draw of the button, since that is the one thing a change to
	## `disabled` is sure to cause; nothing is set that has not changed.
	var place := func() -> void:
		var want: Vector2 = chip.get_combined_minimum_size()
		var at := Vector2(b.size.x - want.x - gap, (b.size.y - want.y) * 0.5).round()
		if chip.size != want:
			chip.size = want
		if chip.position != at:
			chip.position = at
		var alpha: float = 0.5 if b.disabled else 1.0
		if chip.modulate.a != alpha:
			chip.modulate.a = alpha
	b.resized.connect(place)
	b.draw.connect(place)
	chip.minimum_size_changed.connect(place)
	place.call()
	return b

static func choice_card(parent: Node, tone: Color, callback: Callable, pad: int = 16) -> PanelContainer:
	## An option that is a whole card rather than a card with a button on it: it lights in its
	## tone under the pointer, dips on press and acts on release. What goes inside should
	## let the mouse through (labels and containers do).
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", raised(GLASS, Color(tone, 0.4), 12, pad))
	parent.add_child(box)
	make_choice(box, tone, callback)
	return box

static func make_choice(box: PanelContainer, tone: Color, callback: Callable) -> void:
	## Turns a card already built (a stone's card, say) into a choice card, keeping its own
	## look at rest.
	var rest: StyleBox = box.get_theme_stylebox("panel")
	var lit: StyleBoxFlat = rest.duplicate() if rest is StyleBoxFlat else raised(GLASS, tone, 12, 16)
	lit.bg_color = lit.bg_color.lerp(Color(tone, lit.bg_color.a), 0.14)
	lit.border_color = tone.lightened(0.25)
	lit.set_border_width_all(3)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.focus_mode = Control.FOCUS_ALL
	box.set_meta("choice", true)
	juice(box, 1.03)
	var light := func(on: bool) -> void:
		box.add_theme_stylebox_override("panel", lit if on and not bool(box.get_meta("disabled", false)) else rest)
	box.mouse_entered.connect(light.bind(true))
	box.mouse_exited.connect(light.bind(false))
	box.focus_entered.connect(light.bind(true))
	box.focus_exited.connect(light.bind(false))
	var act := func() -> void:
		if bool(box.get_meta("disabled", false)):
			return
		DeepAudio.play("ui_confirm")
		callback.call()
	box.gui_input.connect(func(event: InputEvent) -> void:
		if bool(box.get_meta("disabled", false)):
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			box.accept_event()
			var tween := box.create_tween()
			tween.tween_property(box, "scale", Vector2.ONE * (0.97 if event.pressed else 1.03), 0.06 if event.pressed else 0.1)
			if not event.pressed and Rect2(Vector2.ZERO, box.size).has_point(event.position):
				act.call()
		elif event.is_action_pressed("ui_accept"):
			box.accept_event()
			act.call())

static func disable_choice(box: Control) -> void:
	## A choice card with nothing it could be done to: shown, but dimmed and deaf.
	box.set_meta("disabled", true)
	box.mouse_default_cursor_shape = Control.CURSOR_ARROW
	box.focus_mode = Control.FOCUS_NONE
	## Dimmed through self and children rather than `modulate`, which an entrance tween owns.
	box.self_modulate.a = 0.55
	for child in box.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 0.55

static func skip_arrow(parent: Node, text: String, callback: Callable, tone: Color = MUTED, glyph: String = "next") -> Control:
	## The way past a row of choices: an arrow off the end of the row rather than a button over
	## it, with what it does written small beneath. Under the pointer it brightens and keeps
	## nudging on, the way it would take you. Pair it with `skip_ghost` on the row's other end
	## so the choices stay centred. With "prev" it is the way back instead, and nudges back.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = SKIP_WIDTH
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(column)
	var b := Button.new()
	b.tooltip_text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(64, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon = GemIcons.texture(glyph, GemIcons.baked_size(40))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 24)
	## The same key every other button on the page is cut as (a rounded slab, heavier along
	## the bottom), only darker and empty but for its arrow: the way on is offered, not urged.
	var key := func(fill: Color, edge: Color) -> StyleBoxFlat:
		var style := button_style(fill, edge, 8)
		style.content_margin_left = 10
		style.content_margin_right = 10
		return style
	b.add_theme_stylebox_override("normal", key.call(Color(GLASS, 0.85), Color(tone, 0.4)))
	b.add_theme_stylebox_override("hover", key.call(Color(tone, 0.18), tone.lightened(0.3)))
	b.add_theme_stylebox_override("pressed", key.call(Color(tone, 0.3), tone.lightened(0.3)))
	b.add_theme_stylebox_override("focus", key.call(Color(0, 0, 0, 0), Color(tone, 0.8)))
	b.add_theme_color_override("icon_normal_color", tone)
	b.add_theme_color_override("icon_hover_color", tone.lightened(0.4))
	b.add_theme_color_override("icon_pressed_color", tone.lightened(0.4))
	b.add_theme_color_override("icon_focus_color", tone.lightened(0.4))
	b.pressed.connect(func() -> void: DeepAudio.play("ui_tap"))
	if callback.is_valid():
		b.pressed.connect(callback)
	column.add_child(b)
	var words := label(column, text, 12, PAPER.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	## It stands over the room, not on a card: an outline keeps it readable on bright rock.
	words.add_theme_constant_override("outline_size", 6)
	words.add_theme_color_override("font_outline_color", Color(INK, 0.9))
	words.custom_minimum_size.x = SKIP_WIDTH
	## The nudge: the arrow keeps stepping on and back while the pointer is over it.
	var nudge: Array = [null]
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void:
		DeepAudio.play("ui_hover", {"volume": 0.5, "gap": 0.07})
		words.add_theme_color_override("font_color", tone.lightened(0.4))
		if headless():
			return
		var tween := b.create_tween().set_loops()
		tween.tween_property(b, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(b, "position:x", b.position.x + (-7.0 if glyph == "prev" else 7.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(b, "position:x", b.position.x, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		nudge[0] = tween)
	b.mouse_exited.connect(func() -> void:
		words.add_theme_color_override("font_color", PAPER.darkened(0.15))
		if nudge[0] != null and (nudge[0] as Tween).is_valid():
			(nudge[0] as Tween).kill()
		nudge[0] = null
		if headless():
			return
		var tween := b.create_tween()
		tween.tween_property(b, "scale", Vector2.ONE, 0.14)
		## Let the container put it back where it belongs.
		tween.tween_callback(column.queue_sort))
	return column

static func skip_ghost(parent: Node) -> Control:
	## An empty column the width of a skip arrow, for the other end of its row.
	var ghost := Control.new()
	ghost.custom_minimum_size.x = SKIP_WIDTH
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ghost)
	return ghost

static func tab_button(parent: Node, glyph: String, text: String, active: bool, callback: Callable, size: int = 14, badge: int = 0, rainbow: bool = false) -> Button:
	## A tab: plain at rest, and when it is the one open, a faint gold wash over a gold rule
	## along its foot, the facet's way of marking a choice.
	var b := icon_button(parent, glyph, text if badge <= 0 else "%s  %d" % [text, badge], callback, size, ACCENT if active else MUTED, rainbow)
	b.set_meta("sound", "ui_tab")
	if active:
		var on := button_style(Color(ACCENT, 0.12), Color(0, 0, 0, 0), 10)
		on.border_color = ACCENT
		on.set_border_width_all(0)
		on.border_width_bottom = 2
		b.add_theme_stylebox_override("normal", on)
		b.add_theme_stylebox_override("hover", on)
		b.add_theme_color_override("font_color", ACCENT_HI)
	else:
		b.add_theme_stylebox_override("normal", button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10))
	return b

## The haul is kept in three tabs: stones read and ready to set, stones still in their rock,
## and Geodes, which only the workshop can crack. [key, name, glyph, what it holds].
const HAUL_TABS: Array = [["gems", "Appraised", "gem", "Appraised stones, ready to set"],
	["raw", "Raw", "pick", "Stones still in their rock: appraise them at a stall or a landing"],
	["geodes", "Geodes", "geode", "Sealed Geodes: only the workshop can crack them"]]

static func haul_tab(stone: Dictionary) -> String:
	return DeepStone.haul_tab(stone)

static func haul_of(haul: Array, tab: String) -> Array:
	## The stones of a haul that belong under one tab, in the order they were found.
	return haul.filter(func(s: Dictionary) -> bool: return DeepStone.haul_tab(s) == tab)

static func haul_tabs(parent: Node, haul: Array, current: String, choose: Callable, size: int = 14) -> HBoxContainer:
	## The tabs themselves, each with the number of stones in it. `choose` is given the key.
	var row := hbox(parent, 4)
	for entry in HAUL_TABS:
		var key: String = str(entry[0])
		var count: int = haul_of(haul, key).size()
		var tab := tab_button(row, str(entry[2]), str(entry[1]), current == key, func() -> void: choose.call(key), size, count)
		tab.tooltip_text = str(entry[3])
	return row

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
		if (control is BaseButton and (control as BaseButton).disabled) or bool(control.get_meta("disabled", false)):
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

static func spring(control: Control, kick: float = 0.2, twist: float = 0.0, seconds: float = 0.5) -> void:
	## A jolt that rings out like something on a spring: the control is thrown `kick` larger at
	## once (smaller, if negative) and turned up to `twist` degrees one way or the other, then
	## swings back and forth through rest, each swing smaller, and settles where it was. What
	## a gem firing, a die counting or a number landing is drawn with: a pulse eases, this
	## snaps. Scale and rotation only, so a container keeps ownership of where it sits, and a
	## second jolt before the first has settled takes over from it rather than fighting it.
	if headless() or control == null or not is_instance_valid(control):
		return
	var running: Variant = control.get_meta("spring") if control.has_meta("spring") else null
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	control.pivot_offset = control.size * 0.5
	var lean: float = deg_to_rad(twist) * (1.0 if randf() < 0.5 else -1.0)
	var tween := control.create_tween()
	control.set_meta("spring", tween)
	## About two and a half swings over the time, dying away fast enough that the last of
	## them is felt more than seen.
	tween.tween_method(func(t: float) -> void:
		var ring: float = exp(-5.0 * t)
		## Kept on the centre as it goes: a control built this frame has no size yet.
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * (1.0 + kick * ring * cos(t * TAU * 2.4))
		control.rotation = lean * ring * sin(t * TAU * 2.4), 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		control.scale = Vector2.ONE
		control.rotation = 0.0)

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

class Shimmer extends HBoxContainer:
	## A word whose letters run from gold through the wheel and back, slowly, for ever.
	var _clock: float = 0.0
	## Letters are set in white once and tinted through self_modulate, so a frame of the sweep
	## does not restyle every letter (and reshape its text).
	var _whitened: int = 0
	func paint(clock: float) -> void:
		var count: int = maxi(1, get_child_count())
		var whiten: bool = _whitened != get_child_count()
		for i in range(get_child_count()):
			var letter: Variant = get_child(i)
			if not letter is Label:
				continue
			if whiten:
				(letter as Label).add_theme_color_override("font_color", Color.WHITE)
			var t: float = fposmod(float(i) / float(count) * 0.6 - clock * 0.12, 1.0)
			## Gold for the first stretch of every sweep, then the wheel, then gold again.
			var tone: Color = DeepUi.TRANSCENDENT_TONE.lerp(DeepUi.rainbow_at(t, 0.55), smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.75, 1.0, t)))
			(letter as Label).self_modulate = tone
		_whitened = get_child_count()
	func _process(delta: float) -> void:
		_clock += delta
		if is_visible_in_tree():
			paint(_clock)

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
	## A player's health: below half the fill eases to amber, below a quarter on to red, so who
	## is in trouble reads off the bar before anyone reads its number. See `health_tone`.
	var warn: bool = false
	## Block drawn as a cap past the end of health, hatched, and a blow hatched in red over the
	## health it would take (docs/UI_REDO.md); off, block rides along the bottom as a strip.
	var cap: bool = false
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
	## Kept and reshaped rather than made new on every redraw: a moving bar redraws each frame.
	var _fill_box: StyleBoxFlat = StyleBoxFlat.new()
	var _outline: StyleBoxFlat = StyleBoxFlat.new()
	func _init(height: float = 10.0) -> void:
		custom_minimum_size = Vector2(60, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill_box.anti_aliasing = true
		_outline.bg_color = Color(0, 0, 0, 0)
		_outline.border_color = Color(0, 0, 0, 0.55)
		_outline.set_border_width_all(1)
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
			_box(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y)), DeepUi.health_tone(_shown, fill) if warn else fill, radius)
			_box(Rect2(Vector2(1, 1), Vector2(maxf(0.0, size.x * _shown - 2.0), size.y * 0.38)), Color(1, 1, 1, 0.16), radius * 0.6)
		if preview > 0.0 and _shown > 0.001:
			var cut: float = minf(preview, _shown)
			var pulse: float = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
			var taking := Rect2(Vector2(size.x * (_shown - cut), 0), Vector2(size.x * cut, size.y))
			if cap:
				_box(taking, Color(1.0, 0.35, 0.3, pulse * 0.5), 0.0)
				_hatch(taking, Color(1.0, 0.45, 0.4, pulse))
			else:
				_box(taking, Color(1, 0.95, 0.85, pulse), 0.0)
		if _shown_overlay > 0.0:
			if cap:
				## Block past the end of health: it is what a blow has to get through first.
				var from: float = size.x * _shown
				var span: float = minf(size.x * _shown_overlay, size.x - from)
				if span > 0.5:
					var guard := Rect2(Vector2(from, 0), Vector2(span, size.y))
					_box(guard, Color(overlay_color, 0.5), 0.0)
					_hatch(guard, Color(overlay_color.lightened(0.3), 0.9))
			else:
				var h: float = maxf(3.0, size.y * 0.32)
				_box(Rect2(Vector2(0, size.y - h), Vector2(size.x * _shown_overlay, h)), overlay_color, radius * 0.5)
		if _flash > 0.0:
			_box(r, Color(_flash_color, 0.35 * _flash), radius)
		_outline.set_corner_radius_all(int(radius))
		draw_style_box(_outline, r)
		if not text.is_empty() and size.y >= 12.0:
			## Bold and lightly outlined: at this size a heavy outline swallows the glyphs and
			## the number reads as a dark smudge on the fill.
			var font: Font = DeepUi.bold_font()
			var font_size := int(size.y * 0.78)
			var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var at := Vector2((size.x - measured.x) * 0.5, size.y * 0.5 + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, clampi(roundi(font_size / 5.5), 2, 3), Color(0, 0, 0, 0.8))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	func _hatch(rect: Rect2, color: Color) -> void:
		## Diagonal lines across a rect, clipped to it.
		var h: float = rect.size.y
		var x: float = rect.position.x - h
		while x < rect.end.x:
			var a := Vector2(x, rect.end.y)
			var b := Vector2(x + h, rect.position.y)
			var t0: float = maxf(0.0, (rect.position.x - x) / h)
			var t1: float = minf(1.0, (rect.end.x - x) / h)
			if t1 > t0:
				draw_line(a.lerp(b, t0), a.lerp(b, t1), color, 1.5, true)
			x += 5.0
	func _box(rect: Rect2, color: Color, radius: float) -> void:
		if rect.size.x <= 0.5:
			return
		if radius <= 0.5:
			draw_rect(rect, color)
			return
		## One box, reshaped for each layer: a style box is drawn the moment it is called, so
		## changing it for the next layer leaves the last one as it was.
		_fill_box.bg_color = color
		_fill_box.set_corner_radius_all(int(minf(radius, rect.size.x * 0.5)))
		draw_style_box(_fill_box, rect)

static func health_tone(share: float, healthy: Color = HP) -> Color:
	## Health at a glance: its own green while there is plenty of it, easing to amber by a
	## quarter and to red by a tenth.
	const AMBER := Color("e8b04a")
	const DANGER := Color("e5533d")
	if share >= 0.5:
		return healthy
	if share >= 0.25:
		return healthy.lerp(AMBER, (0.5 - share) / 0.25)
	return AMBER.lerp(DANGER, clampf((0.25 - share) / 0.15, 0.0, 1.0))

static func bar(parent: Node, height: float = 10.0, fill: Color = HP, back: Color = HP_LOST) -> Bar:
	var b := Bar.new(height)
	b.fill = fill
	b.back = back
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

# --- flourishes ------------------------------------------------------------------------------

## The mark for a count that reached the ceiling (DeepRules.CEILING), where counting stops.
const INFINITY_MARK := "∞"

static func number(value: int) -> String:
	## A fight's count as the player reads it: as it is below a million, shortened past that
	## (1.2M, 34B, 560T), and the ceiling, where counting stops, as Infinite.
	if DeepRules.infinite(value):
		return INFINITY_MARK if value > 0 else "−" + INFINITY_MARK
	var size: int = absi(value)
	if size < 1000000:
		return str(value)
	for step in [[1000000000000, "T"], [1000000000, "B"], [1000000, "M"]]:
		if size < int(step[0]):
			continue
		var shown: float = float(size) / float(step[0])
		var text: String = ("%.2f" if shown < 10.0 else "%.1f" if shown < 100.0 else "%.0f") % shown
		if text.contains("."):
			text = text.rstrip("0").trim_suffix(".")
		return ("−" if value < 0 else "") + text + str(step[1])
	return str(value)

static func float_text(parent: Control, at: Vector2, text: String, color: Color, size: int = 22, rise: float = 46.0, seconds: float = 0.9) -> Label:
	## A number that pops, rises and fades where something happened. Bigger numbers pop harder.
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", title_font(size))
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

static func burst(parent: Control, at: Vector2, color: Color, amount: int = 16, speed: float = 160.0, seconds: float = 0.6, size: float = 5.0, z: int = 60) -> void:
	## A spray of sparks in 2D, gone when it is done.
	if headless() or parent == null or not parent.is_inside_tree():
		return
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.92
	## Never more than a few hundred, however big the number a burst was sized from.
	sparks.amount = clampi(amount, 1, 600)
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
	sparks.z_index = z
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
	## A die dipped in a vat or stamped at an anvil changes only its material or its pattern,
	## so both are in it too; and a stone out of the Tumbler changes only its skill.
	var out: String = "%s%s%s%s|%s|%s|%s|%s" % [str(item.get("id", "")), str(item.get("shape", "")), str(item.get("engraving", "")),
		"a" if bool(item.get("appraised", false)) else "", str(item.get("material", "")), str(item.get("pattern", "")), str(item.get("name", "")),
		str(item.get("skill", ""))]
	for face in item.get("faces", []):
		out += "%d%s," % [int(face.get("value", 0)), str(face.get("kind", ""))]
	if item.has("cut"):
		out += "/%d/%d/%d/%s" % [int(item.get("carat", 0)), int(item.get("cut", 0)), int(item.get("clarity", 0)), str(item.get("inclusions", []))]
	return out

static func stone_name(stone: Dictionary) -> String:
	return DeepStone.name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone)

static func plural(count: int, word: String, many: String = "") -> String:
	return "%d %s" % [count, word if count == 1 else (many if not many.is_empty() else word + "s")]
