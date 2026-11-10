class_name VoidMarks
extends RefCounted
## The Void's marks on the fight's dock (the owner's review of November 9, 2026, five rounds on
## the page https://claude.ai/artifact/QE8CFpp8yRHYoNiGC75AK8):
##
## - The Hollow look: a Void gem or a phantom die is drawn as dark space inside its own outline,
##   its facets as pale lines, its rim in its stone's color (`HollowLook`, a canvas shader on the
##   thumb). A Void thing reads as a different kind of thing at a glance, as Balatro's Negative
##   jokers do, without a loud border.
## - Icon moons: the Void gems riding a socket are small dashed discs (`VoidDisc`) round the
##   ring's right side, each with its gem's emblem; past what the arc holds, a "+N" moon
##   (`CountMark`) stands for the rest, stretching into a capsule for a long number.
## - The popout (`RidersPopout`): a Ledger panel over the dock that lays a socket's riders out
##   at full size in firing order, a run of one gem's copies as one stone with a ×N tag, two
##   rows a page and a page button past that. It opens on a click (a tap on the socket, on the
##   phone) and on its own as the socket fires.
## - The float row (`PhantomRow`): phantom dice hang over the tray, bare Hollow dice in hand
##   order, each tied to the die it copies by its own dotted line (a thrown die, copying none,
##   stands leftmost with a pale line down to the gem that threw it). When they no longer fit
##   they stack: one die a source with a ×N tag, and thrown stacks that still do not fit fold
##   into a "+N" that opens a panel of every stack.
##
## Sizes are in canvas pixels; `use_phone` sets the phone's (docs/PHONE_UI.md).

const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")

## The arc of moons round a ring: how far their centres stand from the ring's, their radius,
## and the angles (degrees, clockwise from the right) the first, second and third stand at.
## The phone's arc holds two.
static var MOON_D: float = 51.0
static var MOON_R: float = 14.5
static var MOON_ANGLES: Array = [-20.0, 18.0, 54.0]
## A rail of eight draws its moons in closer, clear of the next ring.
static var MOON_D_TIGHT: float = 46.0
static var MOON_ANGLES_TIGHT: Array = [-30.0, 10.0, 50.0]
static var MOON_ICON: float = 18.0
## The count moon, and the text in it (the long form for four characters and more).
static var COUNT_R: float = 14.5
static var COUNT_FONT: int = 15
static var COUNT_FONT_LONG: int = 13
## The popout: a place for each stone, a row's height, a disc's radius, its padding, the gap
## after the head column, the room its × takes (the phone gives the × a column of its own).
static var POP_ITEM_W: float = 89.0
static var POP_ROW_H: float = 102.0
static var POP_DISC_R: float = 33.0
static var POP_PAD: float = 16.0
static var POP_SPLIT: float = 13.0
static var POP_X_COL: float = 0.0
static var POP_BUTTON: float = 52.0
static var POP_CLOSE: float = 24.0
static var POP_NAME: int = 12
static var POP_FIG: int = 19
static var POP_BADGE: int = 12
const POP_PER_ROW: int = 7
const POP_ROWS: int = 2
## A die's photograph has room round the die: a phantom is drawn this much wider than its place.
const ROW_DIE_FILL: float = 1.3
## The float row: the largest and smallest a bare die is drawn, a stack's die, the gap between
## dice, the tag under a stack, how far the row hangs over the dock, the room between the
## thrown dice and the copies.
static var ROW_DIE_R: float = 32.0
static var ROW_DIE_LEAST: float = 15.5
static var ROW_STACK_R: float = 22.0
static var ROW_GAP: float = 7.0
static var ROW_BADGE: int = 13
static var ROW_LIFT: float = 27.0
static var ROW_SPLIT: float = 18.0
static var ROW_TIP_FONT: int = 15

static var phone: bool = false

static func use_phone() -> void:
	## The phone's sizes (docs/PHONE_UI.md): two marks on the arc, a count at the text floor,
	## the popout's buttons a finger wide.
	phone = true
	MOON_D = DeepUi.pt(24.0)
	MOON_R = DeepUi.pt(7.0)
	MOON_ANGLES = [-12.0, 34.0]
	MOON_D_TIGHT = DeepUi.pt(22.0)
	MOON_ANGLES_TIGHT = [-18.0, 30.0]
	MOON_ICON = DeepUi.pt(8.5)
	COUNT_R = DeepUi.pt(9.5)
	COUNT_FONT = int(DeepUi.pt(12.0))
	COUNT_FONT_LONG = int(DeepUi.pt(11.0))
	POP_ITEM_W = DeepUi.pt(44.0)
	POP_ROW_H = DeepUi.pt(50.0)
	POP_DISC_R = DeepUi.pt(16.0)
	POP_PAD = DeepUi.pt(7.0)
	POP_SPLIT = DeepUi.pt(6.0)
	POP_X_COL = DeepUi.pt(18.0)
	POP_BUTTON = DeepUi.pt(44.0)
	POP_CLOSE = DeepUi.pt(44.0)
	POP_NAME = 11
	POP_FIG = int(DeepUi.pt(12.5))
	POP_BADGE = int(DeepUi.pt(11.0))
	ROW_DIE_R = DeepUi.pt(15.0)
	ROW_DIE_LEAST = DeepUi.pt(7.75)
	ROW_STACK_R = DeepUi.pt(10.5)
	ROW_GAP = DeepUi.pt(3.0)
	ROW_BADGE = int(DeepUi.pt(11.0))
	ROW_LIFT = DeepUi.pt(14.0)
	ROW_SPLIT = DeepUi.pt(9.5)
	ROW_TIP_FONT = 13

# --- numbers --------------------------------------------------------------------------------

static func short_count(n: int) -> String:
	## A count on a small mark: whole below a thousand, then 1.4k, 12k, 120k, then the game's
	## 1.2M and 34B (the popout always gives the exact number).
	if n < 1000:
		return str(n)
	var steps: Array = [[1000000000, "B"], [1000000, "M"], [1000, "k"]]
	for step in steps:
		if n < int(step[0]):
			continue
		var shown: float = float(n) / float(step[0])
		var text: String = ("%.1f" % (floor(shown * 10.0) / 10.0)) if shown < 10.0 else str(int(floor(shown)))
		if text.ends_with(".0"):
			text = text.trim_suffix(".0")
		return text + str(step[1])
	return str(n)

static func with_commas(n: int) -> String:
	## 1,458: the exact count where there is room for it.
	var text: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for index in range(text.length() - 1, -1, -1):
		out = text[index] + out
		count += 1
		if count % 3 == 0 and index > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

static func tone_of(stone: Dictionary) -> Color:
	## The color a Hollow stone's rim and facets are drawn in: its own hue, paled.
	var hue: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.INFO
	return hue.lerp(Color.WHITE, 0.45)

# --- the Hollow look ------------------------------------------------------------------------

## A canvas shader over a stone's or a die's photograph: dark space with a few stars where the
## body was, the facets as pale lines where the shading breaks, the outline in the stone's
## color, and on a die its dark marks (the number) in white.
const HOLLOW_SHADER: String = """
shader_type canvas_item;
uniform vec4 tone : source_color = vec4(0.66, 0.82, 1.0, 1.0);
uniform float die = 0.0;
uniform float seed = 1.0;

float lum(vec4 c) { return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// A texel, or a screen pixel when the picture is drawn smaller than it was taken: the
	// facet lines and the rim stay a pixel or two wide at any size.
	vec2 unit = max(TEXTURE_PIXEL_SIZE, fwidth(UV));
	vec2 px = unit * 1.2;
	float l = lum(c);
	float lx = lum(texture(TEXTURE, UV + vec2(px.x, 0.0))) - lum(texture(TEXTURE, UV - vec2(px.x, 0.0)));
	float ly = lum(texture(TEXTURE, UV + vec2(0.0, px.y))) - lum(texture(TEXTURE, UV - vec2(0.0, px.y)));
	float edge = clamp(length(vec2(lx, ly)) * 2.6, 0.0, 1.0);
	vec2 rx = unit * 1.6;
	float ax = texture(TEXTURE, UV + vec2(rx.x, 0.0)).a - texture(TEXTURE, UV - vec2(rx.x, 0.0)).a;
	float ay = texture(TEXTURE, UV + vec2(0.0, rx.y)).a - texture(TEXTURE, UV - vec2(0.0, rx.y)).a;
	float rim = clamp(length(vec2(ax, ay)) * 1.4, 0.0, 1.0);
	float body = smoothstep(0.2, 0.5, c.a);
	vec2 cell = floor(UV * 42.0);
	float h = hash(cell);
	vec2 f = fract(UV * 42.0) - 0.5;
	float star = (h > 0.962 ? smoothstep(0.34, 0.04, length(f)) : 0.0) * (0.55 + 0.45 * fract(h * 7.3));
	float glow = smoothstep(0.95, 0.0, length(UV - vec2(0.38, 0.34)) * 1.35);
	vec3 base = mix(vec3(0.015, 0.02, 0.045), vec3(0.1, 0.125, 0.24), glow);
	vec3 lite = tone.rgb * 0.55 + vec3(0.45);
	vec3 col = base + vec3(star);
	col = mix(col, lite, edge * 0.6 * body);
	if (die > 0.5) {
		float mark = (1.0 - smoothstep(0.36, 0.46, l)) * step(0.6, c.a);
		col = mix(col, vec3(0.92, 0.94, 1.0), mark * 0.85);
	}
	col = mix(col, lite, rim);
	float alpha = max(body * 0.94, rim);
	COLOR = vec4(col * COLOR.rgb, alpha * COLOR.a);
}
"""

static var _hollow_shader: Shader = null
static var _hollow_materials: Dictionary = {}

static func hollow_material(tone: Color, die: bool, seed: int = 1) -> ShaderMaterial:
	## One material a tone (and a die's), shared by every thumb drawn in it.
	var key: String = "%s|%s|%d" % [tone.to_html(false), "d" if die else "g", seed % 7]
	var found: ShaderMaterial = _hollow_materials.get(key, null)
	if found != null:
		return found
	if _hollow_shader == null:
		_hollow_shader = Shader.new()
		_hollow_shader.code = HOLLOW_SHADER
	var material := ShaderMaterial.new()
	material.shader = _hollow_shader
	material.set_shader_parameter("tone", tone)
	material.set_shader_parameter("die", 1.0 if die else 0.0)
	material.set_shader_parameter("seed", float(seed % 7) + 1.0)
	_hollow_materials[key] = material
	return material

static func hollow_gem(stone: Dictionary, edge: float) -> Control:
	## A stone's picture in the Hollow look, its emblem in white over the dark.
	var thumb := Thumbs.GemThumb.new({}, edge)
	thumb.hollow = true
	thumb.live_on_hover = false
	thumb.configure(stone)
	return thumb

static func hollow_die(die: Dictionary, edge: float, face: int) -> Control:
	var thumb := Thumbs.DieThumb.new({}, edge)
	thumb.hollow = true
	thumb.configure(die, face)
	return thumb

# --- a Void disc ------------------------------------------------------------------------------

class VoidDisc extends Control:
	## The dashed disc a Void thing stands in: dark space behind, the Void's blue dashes round
	## it, brighter for a gem that will fire. Holds whatever is set in it (an emblem, a stone).
	var lit: bool = false:
		set(value):
			if value != lit:
				lit = value
				queue_redraw()
	## A gem the hand leaves dark steps back, as a set gem does.
	var dim: bool = false:
		set(value):
			dim = value
			modulate = Color(0.78, 0.78, 0.84, 0.92) if value else Color.WHITE
	var _flash: float = 0.0

	func _init(radius: float) -> void:
		custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_PASS
		pivot_offset = size * 0.5

	func fire() -> void:
		## It fires: a flash of the Void's light, and a jolt.
		_flash = 1.0
		set_process(true)
		DeepUi.spring(self, 0.22, 6.0, 0.4)

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 2.4)
		queue_redraw()
		if _flash <= 0.0:
			set_process(false)

	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(centre, radius, Color("05070c"))
		draw_circle(centre + Vector2(-radius * 0.12, -radius * 0.16), radius * 0.78, Color("18203a", 0.5))
		draw_circle(centre + Vector2(-radius * 0.16, -radius * 0.2), radius * 0.42, Color("1d2346", 0.45))
		var width: float = maxf(1.3, radius * 0.09)
		var tone := Color(DeepUi.INFO, (0.95 if lit else 0.5) + _flash * 0.05)
		for arc in range(12):
			var angle: float = TAU * float(arc) / 12.0
			draw_arc(centre, radius - width * 0.5, angle, angle + TAU / 12.0 * 0.64, 6, tone, width, true)
		if _flash > 0.0:
			var reach: float = radius * 3.2
			draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(DeepUi.INFO, 0.7 * _flash))

	func hold(content: Control, edge: float) -> Control:
		## Puts `content` in the disc's middle, `edge` wide.
		content.position = (size - Vector2(edge, edge)) * 0.5
		content.size = Vector2(edge, edge)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content)
		return content

static func moon(stone: Dictionary, lit: bool) -> VoidDisc:
	## A rider's moon on the rail: its gem's emblem in a small Void disc.
	var disc := VoidDisc.new(MOON_R)
	disc.lit = lit
	disc.dim = not lit
	var mark := TextureRect.new()
	mark.texture = GemIcons.texture(GemIcons.emblem(str(stone.get("skill", ""))), GemIcons.baked_size(MOON_ICON * 1.5))
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.modulate = DeepUi.INFO.lightened(0.3) if lit else DeepUi.MUTED
	disc.hold(mark, MOON_ICON)
	return disc

# --- the count ------------------------------------------------------------------------------

class CountMark extends Control:
	## "+N" in a Void moon: as wide as the number needs, a capsule past a moon's width, dashed
	## round like the moons it stands with. The exact count is its `more`.
	var more: int = 0
	var text: String = "+0"
	var font_px: int = 15
	var radius: float = 14.5
	var lit: bool = true:
		set(value):
			lit = value
			queue_redraw()

	func _init(count: int, r: float, px: int, long_px: int) -> void:
		radius = r
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_count(count, px, long_px)

	func set_count(count: int, px: int, long_px: int) -> void:
		more = count
		text = "+" + VoidMarks.short_count(count)
		font_px = px if text.length() <= 3 else long_px
		var measured: Vector2 = DeepUi.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		var width: float = maxf(radius * 2.0, measured.x + radius * 0.9)
		custom_minimum_size = Vector2(width, radius * 2.0)
		size = custom_minimum_size
		pivot_offset = size * 0.5
		queue_redraw()

	func _draw() -> void:
		var r: float = radius - 1.0
		var rect := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
		## A stadium: two half-discs and the straight between, filled dark.
		var left := Vector2(rect.position.x + r, rect.position.y + r)
		var right := Vector2(rect.end.x - r, rect.position.y + r)
		draw_circle(left, r, Color("05070c"))
		draw_circle(right, r, Color("05070c"))
		if right.x > left.x:
			draw_rect(Rect2(left.x, rect.position.y, right.x - left.x, rect.size.y), Color("05070c"))
		draw_circle(left + Vector2(-r * 0.1, -r * 0.16), r * 0.7, Color("18203a", 0.45))
		## The dashes, run round the stadium's edge at a moon's pace.
		var width: float = maxf(1.3, r * 0.09)
		var tone := Color(DeepUi.INFO, 0.95 if lit else 0.5)
		var path: PackedVector2Array = _stadium(left, right, r - width * 0.5)
		var period: float = TAU * r / 12.0
		var run: float = 0.0
		for index in range(path.size() - 1):
			var a: Vector2 = path[index]
			var b: Vector2 = path[index + 1]
			var step: float = a.distance_to(b)
			var at: float = 0.0
			while at < step:
				var phase: float = fmod(run + at, period) / period
				var until: float = minf(step, at + (0.64 - phase) * period if phase < 0.64 else at + (1.0 - phase) * period + 0.001)
				if phase < 0.64:
					draw_line(a.lerp(b, at / step), a.lerp(b, minf(until, step) / step), tone, width, true)
				at = maxf(until, at + 0.5)
			run += step
		var font: Font = DeepUi.bold_font()
		var measured: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		var ascent: float = font.get_ascent(font_px)
		var at_text: Vector2 = Vector2((size.x - measured.x) * 0.5, (size.y - measured.y) * 0.5 + ascent - 0.5)
		draw_string(font, at_text, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, DeepUi.INFO.lightened(0.3))

	static func _stadium(left: Vector2, right: Vector2, r: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var steps: int = 14
		for k in range(steps + 1):
			var angle: float = -PI * 0.5 + PI * float(k) / float(steps)
			points.append(right + Vector2(cos(angle), sin(angle)) * r)
		for k in range(steps + 1):
			var angle: float = PI * 0.5 + PI * float(k) / float(steps)
			points.append(left + Vector2(cos(angle), sin(angle)) * r)
		points.append(points[0])
		return points

# --- the figure a lit stone wears ------------------------------------------------------------

static func figure(parent: Control, text: String, color: Color, px: int) -> Label:
	## A number drawn big and bold with a dark edge, so it reads over anything.
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DeepUi.bold_font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.05, 0.95))
	l.add_theme_constant_override("outline_size", maxi(4, px / 3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 2
	parent.add_child(l)
	l.reset_size()
	return l

static func badge(parent: Control, text: String, px: int, thrown: bool = false) -> PanelContainer:
	## A ×N tag on a stack: a capsule in the Void's blue (grey for a thrown die's).
	var tag := PanelContainer.new()
	var line: Color = Color("b9c4dc") if thrown else DeepUi.INFO
	tag.add_theme_stylebox_override("panel", DeepUi.capsule(tag, Color("07090f"), line, 2, maxi(4, px / 3), 0))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.z_index = 2
	var said := Label.new()
	said.name = "Value"
	said.text = text
	said.add_theme_font_override("font", DeepUi.bold_font())
	said.add_theme_font_size_override("font_size", px)
	said.add_theme_color_override("font_color", DeepUi.PAPER if thrown else DeepUi.INFO.lightened(0.3))
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	said.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(said)
	parent.add_child(tag)
	tag.reset_size()
	return tag

static func ledger_panel(parent: Control, rect: Rect2) -> Control:
	## A Ledger plate drawn as a control of its own, under whatever is laid on it.
	var panel := Control.new()
	panel.name = "Panel"
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.LEDGER_LINE, 10, 0, 3, 4)
	panel.draw.connect(func() -> void: panel.draw_style_box(style, Rect2(Vector2.ZERO, panel.size)))
	parent.add_child(panel)
	return panel

static func notch(parent: Control, at: Vector2) -> Control:
	## The little point under a panel, at the thing it hangs over.
	var mark := Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = at
	mark.z_index = 1
	mark.draw.connect(func() -> void:
		var points := PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(0, 11)])
		mark.draw_colored_polygon(points, DeepUi.LEDGER_FILL)
		mark.draw_line(Vector2(-11, 0), Vector2(0, 11), DeepUi.LEDGER_LINE, 3.0, true)
		mark.draw_line(Vector2(11, 0), Vector2(0, 11), DeepUi.LEDGER_LINE, 3.0, true))
	parent.add_child(mark)
	return mark

static func pages_of(count: int, per_page: int) -> Array:
	## [first, end) a page, each holding what two rows hold: a › takes a place on a page that
	## has more after it, a ‹ one on every page after the first.
	var pages: Array = []
	var at: int = 0
	while at < count:
		var room: int = per_page - (0 if pages.is_empty() else 1)
		if count - at > room:
			room -= 1
		room = maxi(room, 1)
		pages.append([at, mini(count, at + room)])
		at += room
	return pages if not pages.is_empty() else [[0, 0]]

# --- the riders' popout ----------------------------------------------------------------------

class RidersPopout extends Control:
	## A socket's riders laid out over the dock (round 2's D1, round 5's K2): the socket's own
	## ring at the head with the total riding it, a rule, then each run of riders as a Hollow
	## stone in a dashed disc with its name over it (the desktop) and the number it would land,
	## a ×N tag on a run of copies, and page buttons past two rows. `spec`:
	##   anchor (x, the socket's centre, local to the parent), bottom (the dock's top), left and
	##   right (the room it may take), head (a Control to stand at the head), count (the total
	##   riding), runs ([{stone, flats, lit, figure: [text, color]}]), page, on_close, on_page.
	signal closed
	var page: int = 0
	var pages: Array = []
	var runs: Array = []
	## Each run's disc and tag, and which run each flat index stands in.
	var _discs: Array = []
	var _tags: Array = []
	var _run_of: Dictionary = {}
	var _spec: Dictionary = {}
	var _anchor_x: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func build(spec: Dictionary) -> void:
		_spec = spec
		for child in get_children():
			child.queue_free()
		_discs.clear()
		_tags.clear()
		_run_of.clear()
		runs = spec.get("runs", [])
		page = int(spec.get("page", 0))
		pages = VoidMarks.pages_of(runs.size(), VoidMarks.POP_PER_ROW * VoidMarks.POP_ROWS)
		page = clampi(page, 0, pages.size() - 1)
		for k in range(runs.size()):
			for flat in runs[k].get("flats", []):
				_run_of[int(flat)] = k
		var span: Array = pages[page]
		var prev: bool = page > 0
		var next: bool = page < pages.size() - 1
		var slots: int = (1 if prev else 0) + (int(span[1]) - int(span[0])) + (1 if next else 0)
		var cols: int = mini(VoidMarks.POP_PER_ROW, maxi(slots, 1)) + 1
		var rows: int = maxi(1, ceili(float(slots) / float(VoidMarks.POP_PER_ROW)))
		var w: float = float(cols) * VoidMarks.POP_ITEM_W + 2.0 * VoidMarks.POP_PAD + VoidMarks.POP_SPLIT + VoidMarks.POP_X_COL
		var h: float = float(rows) * VoidMarks.POP_ROW_H + 2.0 * VoidMarks.POP_PAD
		var bottom: float = float(spec.get("bottom", 0.0)) - 14.0
		var left_bound: float = float(spec.get("left", 0.0))
		var right_bound: float = float(spec.get("right", 1600.0))
		_anchor_x = float(spec.get("anchor", 0.0))
		var left: float = clampf(_anchor_x - w * 0.5, left_bound, maxf(left_bound, right_bound - w))
		position = Vector2(left, bottom - h).round()
		size = Vector2(w, h)
		var panel: Control = VoidMarks.ledger_panel(self, Rect2(Vector2.ZERO, size))
		## A click on the plate itself closes nothing and hurries nothing.
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				panel.accept_event())
		VoidMarks.notch(self, Vector2(clampf(_anchor_x - left, 16.0, w - 16.0), h - 1.0))
		var head_top: float = VoidMarks.POP_PAD + (VoidMarks.POP_NAME + 8.0 if not VoidMarks.phone else 6.0)
		var disc_y: float = head_top + VoidMarks.POP_DISC_R + 2.0
		## The head: the socket's own ring and stone, and under it how many ride it.
		var head: Control = spec.get("head", null)
		var head_x: float = VoidMarks.POP_PAD + VoidMarks.POP_ITEM_W * 0.5
		if head != null:
			head.position = Vector2(head_x - VoidMarks.POP_DISC_R, disc_y - VoidMarks.POP_DISC_R)
			head.size = Vector2(VoidMarks.POP_DISC_R * 2.0, VoidMarks.POP_DISC_R * 2.0)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(head)
		if not VoidMarks.phone:
			var head_name: Label = DeepUi.fit_label(self, str(spec.get("name", "")), VoidMarks.POP_NAME, Color("c9d1e6"), VoidMarks.POP_ITEM_W - 6.0)
			head_name.position = Vector2(head_x - (VoidMarks.POP_ITEM_W - 6.0) * 0.5, disc_y - VoidMarks.POP_DISC_R - VoidMarks.POP_NAME - 6.0)
			head_name.size = Vector2(VoidMarks.POP_ITEM_W - 6.0, VoidMarks.POP_NAME + 4.0)
		var total: PanelContainer = VoidMarks.badge(self, VoidMarks.with_commas(int(spec.get("count", 0))), VoidMarks.POP_BADGE)
		(total.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color("465783")
		total.position = Vector2(head_x - total.size.x * 0.5, disc_y + VoidMarks.POP_DISC_R + 4.0)
		var rule := ColorRect.new()
		rule.color = DeepUi.LEDGER_LINE
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.position = Vector2(VoidMarks.POP_PAD + VoidMarks.POP_ITEM_W + VoidMarks.POP_SPLIT * 0.5 - 1.0, VoidMarks.POP_PAD + 4.0)
		rule.size = Vector2(2.0, h - 2.0 * VoidMarks.POP_PAD - 8.0)
		add_child(rule)
		## The places: a page button, the runs, a page button.
		var slot: int = 0
		var at := func(index: int) -> Vector2:
			var row: int = index / VoidMarks.POP_PER_ROW
			var col: int = index % VoidMarks.POP_PER_ROW + 1
			return Vector2(VoidMarks.POP_PAD + float(col) * VoidMarks.POP_ITEM_W + VoidMarks.POP_ITEM_W * 0.5 + VoidMarks.POP_SPLIT, disc_y + float(row) * VoidMarks.POP_ROW_H)
		if prev:
			_page_button(at.call(slot), -1)
			slot += 1
		for k in range(int(span[0]), int(span[1])):
			var run: Dictionary = runs[k]
			var centre: Vector2 = at.call(slot)
			slot += 1
			var disc := VoidDisc.new(VoidMarks.POP_DISC_R)
			disc.position = centre - Vector2(VoidMarks.POP_DISC_R, VoidMarks.POP_DISC_R)
			disc.lit = bool(run.get("lit", false))
			disc.dim = not bool(run.get("lit", false))
			add_child(disc)
			var stone: Dictionary = run.get("stone", {})
			## The photograph has room round the stone: drawn a little wider than the disc, the
			## stone itself fills about two thirds of it.
			disc.hold(VoidMarks.hollow_gem(stone, VoidMarks.POP_DISC_R * 1.9), VoidMarks.POP_DISC_R * 1.9)
			var build_plate: Callable = spec.get("plate", Callable())
			if build_plate.is_valid():
				var flat_first: int = int(run.get("flats", [k])[0])
				Tips.attach(disc, func() -> Control: return build_plate.call(flat_first), {"tone": DeepUi.INFO})
			var look: Callable = spec.get("look", Callable())
			if look.is_valid():
				var looked: Dictionary = stone
				disc.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
						look.call(looked)
						disc.accept_event())
				Tips.hold(disc, func() -> Variant:
					look.call(looked)
					return true)
			if not VoidMarks.phone:
				var said: Label = DeepUi.fit_label(self, str(run.get("name", "")), VoidMarks.POP_NAME, DeepUi.INFO.lightened(0.3) if bool(run.get("lit", false)) else DeepUi.DIM, VoidMarks.POP_ITEM_W - 6.0)
				said.position = Vector2(centre.x - (VoidMarks.POP_ITEM_W - 6.0) * 0.5, centre.y - VoidMarks.POP_DISC_R - VoidMarks.POP_NAME - 6.0)
				said.size = Vector2(VoidMarks.POP_ITEM_W - 6.0, VoidMarks.POP_NAME + 4.0)
			var fig: Array = run.get("figure", ["", DeepUi.PAPER])
			if bool(run.get("lit", false)) and not str(fig[0]).is_empty():
				var number: Label = VoidMarks.figure(self, str(fig[0]), Color(fig[1]).lightened(0.25), VoidMarks.POP_FIG)
				number.position = Vector2(centre.x + VoidMarks.POP_DISC_R - number.size.x + 4.0, centre.y - VoidMarks.POP_DISC_R - number.size.y * 0.5 + 2.0)
			var tag: PanelContainer = null
			var flats: Array = run.get("flats", [])
			if flats.size() > 1:
				tag = VoidMarks.badge(self, "×" + VoidMarks.with_commas(flats.size()), VoidMarks.POP_BADGE)
				tag.position = Vector2(centre.x + VoidMarks.POP_DISC_R * 0.55 - tag.size.x * 0.5, centre.y + VoidMarks.POP_DISC_R * 0.78 - tag.size.y * 0.5)
			_discs.append(disc)
			_tags.append(tag)
		if next:
			_page_button(at.call(slot), 1)
		## The ×: at the corner on a desk; on the phone a finger-wide pad in its own column, in
		## the middle of the panel's height.
		var close := Button.new()
		close.text = "×"
		close.flat = true
		close.focus_mode = Control.FOCUS_NONE
		close.add_theme_font_override("font", DeepUi.bold_font())
		close.add_theme_font_size_override("font_size", int(VoidMarks.POP_CLOSE * (0.8 if not VoidMarks.phone else 0.45)))
		close.add_theme_color_override("font_color", DeepUi.MUTED)
		close.add_theme_color_override("font_hover_color", DeepUi.PAPER)
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			close.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		close.custom_minimum_size = Vector2(VoidMarks.POP_CLOSE, VoidMarks.POP_CLOSE)
		close.size = close.custom_minimum_size
		close.position = Vector2(w - VoidMarks.POP_CLOSE - (4.0 if not VoidMarks.phone else VoidMarks.POP_X_COL * 0.5 - VoidMarks.POP_CLOSE * 0.5 + 8.0), (4.0 if not VoidMarks.phone else minf(h * 0.5 - VoidMarks.POP_CLOSE * 0.5, 40.0)))
		close.tooltip_text = "Close"
		close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close.pressed.connect(func() -> void: closed.emit())
		add_child(close)

	func _page_button(centre: Vector2, direction: int) -> void:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = "‹" if direction < 0 else "›"
		button.add_theme_font_override("font", DeepUi.bold_font())
		button.add_theme_font_size_override("font_size", int(VoidMarks.POP_BUTTON * 0.45))
		DeepUi.ledger_button(button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
		button.custom_minimum_size = Vector2(VoidMarks.POP_BUTTON, VoidMarks.POP_BUTTON)
		button.size = button.custom_minimum_size
		button.position = centre - button.size * 0.5
		button.tooltip_text = "Page %d of %d" % [page + 1 + direction, pages.size()]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var turn: Callable = _spec.get("on_page", Callable())
		var to: int = page + direction
		button.pressed.connect(func() -> void:
			if turn.is_valid():
				turn.call(to))
		add_child(button)
		var small := Label.new()
		small.text = "%d / %d" % [to + 1, pages.size()]
		small.add_theme_font_size_override("font_size", maxi(DeepUi.min_text(), int(VoidMarks.POP_BUTTON * 0.22)))
		small.add_theme_color_override("font_color", DeepUi.MUTED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		small.offset_top = -small.get_minimum_size().y - 3.0
		small.offset_bottom = -3.0
		button.add_child(small)

	func page_of(flat: int) -> int:
		## Which page the run holding this rider is on; -1 if it rides elsewhere.
		var run: int = int(_run_of.get(flat, -1))
		if run < 0:
			return -1
		for index in range(pages.size()):
			if run >= int(pages[index][0]) and run < int(pages[index][1]):
				return index
		return -1

	func element_for(flat: int) -> Control:
		## The disc standing for this rider on the page shown, or null.
		var run: int = int(_run_of.get(flat, -1))
		if run < 0 or page_of(flat) != page:
			return null
		var index: int = run - int(pages[page][0])
		return _discs[index] if index >= 0 and index < _discs.size() else null

	func mark_fired(outcomes: Dictionary, firing: int, spent: bool) -> void:
		## What has fired so far: a run's tag counts down to what is still to play, a run played
		## through steps back, and the rider firing now flashes. A spent rail dims what is left.
		for k in range(int(pages[page][0]), int(pages[page][1])):
			var run: Dictionary = runs[k]
			var flats: Array = run.get("flats", [])
			var left: int = 0
			for flat in flats:
				if not outcomes.has(int(flat)):
					left += 1
			var index: int = k - int(pages[page][0])
			if index < 0 or index >= _discs.size():
				continue
			var tag: PanelContainer = _tags[index]
			if tag != null:
				(tag.get_node("Value") as Label).text = "×" + VoidMarks.with_commas(left if left > 0 or outcomes.is_empty() else flats.size())
			var disc: VoidDisc = _discs[index]
			if flats.has(firing):
				disc.fire()
			if left == 0 and not flats.is_empty():
				disc.modulate = Color(0.85, 0.85, 0.9, 0.7)
			elif spent and left > 0 and flats.any(func(f: Variant) -> bool: return outcomes.has(int(f))) == false:
				disc.modulate = Color(0.45, 0.45, 0.5, 0.6)

# --- the float row of phantom dice -----------------------------------------------------------

class PhantomRow extends Control:
	## The phantom dice over the tray (round 3's B2, round 5's P1 and T1). Laid from the hand:
	## copies tied to the die they copy, thrown dice leftmost; one die a copy while they fit,
	## stacks when they do not, a "+N" for thrown stacks past the room. The row is as wide as
	## the dock and takes no pointer itself; its dice do. `die_anchor(die_id)` finds a die in
	## the tray, `socket_anchor(socket)` a socket's card, `maker_of(die_id)` {socket, name} for a
	## die a gem threw, `look(die, face)` opens a die.
	var die_anchor: Callable = Callable()
	var socket_anchor: Callable = Callable()
	var maker_of: Callable = Callable()
	var look: Callable = Callable()
	## The dice drawn, by die id (a stack answers for every die in it), for a count to point at.
	var items: Dictionary = {}
	var entries: Array = []
	var mode: String = "single"
	var fold: CountMark = null
	var _fold_panel: Control = null
	var _tray := Rect2()
	var _dock_top: float = 0.0
	var _bounds := Vector2(0.0, 1600.0)
	var _chosen: int = -1
	var _r: float = 0.0
	var _key: String = ""
	var _ghosts: Array = []
	var _dice: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_geometry(tray_global: Rect2, dock_top_global: float, bounds: Vector2) -> void:
		## Where the tray's dice are and where the dock begins, in the screen's pixels; the row
		## lays its dice again when they move.
		var tray_local := Rect2(tray_global.position - global_position, tray_global.size)
		var top_local: float = dock_top_global - global_position.y
		if tray_local.is_equal_approx(_tray) and is_equal_approx(top_local, _dock_top) and bounds.is_equal_approx(_bounds):
			return
		var widened: bool = absf(tray_local.size.x - _tray.size.x) > 2.0
		_tray = tray_local
		_dock_top = top_local
		_bounds = bounds
		if not entries.is_empty():
			if widened:
				## The tray's width decides how the row is laid (one die a copy, or stacks).
				_key = ""
				lay(_ghosts, _dice, [], Vector2.ZERO)
			else:
				_place()
		queue_redraw()

	func clear() -> void:
		for child in get_children():
			child.queue_free()
		items.clear()
		entries.clear()
		fold = null
		_fold_panel = null
		_chosen = -1
		_key = ""
		queue_redraw()

	func lay(ghosts: Array, dice_by_id: Dictionary, arriving: Array, from: Vector2) -> void:
		## The hand's phantoms laid out: `ghosts` are the phantom rolls in hand order,
		## `dice_by_id` the player's dice, `arriving` the die ids that have just been thrown (they
		## fly in from `from`, a point in the screen's pixels).
		var key: String = ",".join(ghosts.map(func(r: Dictionary) -> String: return "%s=%d=%s" % [str(r.get("die_id", "")), int(r.get("value", 0)), str(r.get("source_id", ""))]))
		if key == _key and not entries.is_empty():
			return
		clear()
		_key = key
		_ghosts = ghosts
		_dice = dice_by_id
		if ghosts.is_empty():
			return
		## Copies by the die they copy, in hand order; thrown dice by shape and face.
		var copies: Array = []
		var copy_of: Dictionary = {}
		var thrown: Array = []
		var thrown_of: Dictionary = {}
		for ghost in ghosts:
			var source_id: String = str(ghost.get("source_id", ""))
			var source: Dictionary = dice_by_id.get(source_id, {})
			if not source.is_empty():
				if not copy_of.has(source_id):
					copy_of[source_id] = {"kind": "copy", "source_id": source_id, "die": source, "rolls": []}
					copies.append(copy_of[source_id])
				copy_of[source_id].rolls.append(ghost)
			else:
				var shape: String = str(ghost.get("shape", "D6"))
				var tag: String = "%s|%d" % [shape, int(ghost.get("value", 0))]
				if not thrown_of.has(tag):
					thrown_of[tag] = {"kind": "thrown", "shape": shape, "value": int(ghost.get("value", 0)), "die": DeepDice.make(shape, str(ghost.get("die_id", ""))), "rolls": []}
					thrown.append(thrown_of[tag])
				thrown_of[tag].rolls.append(ghost)
		thrown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra: int = DeepDice.TIERS.find(str(a.shape))
			var rb: int = DeepDice.TIERS.find(str(b.shape))
			return ra < rb if ra != rb else int(a.value) < int(b.value))
		var singles: Array = []
		for group in thrown + copies:
			for roll in group.rolls:
				singles.append({"kind": group.kind, "die": group.die, "rolls": [roll], "source_id": str(group.get("source_id", "")), "shape": str(group.get("shape", "")), "value": int(group.get("value", 0))})
		var span: float = maxf(60.0, _tray.size.x)
		var split: float = VoidMarks.ROW_SPLIT if not thrown.is_empty() and not copies.is_empty() else 0.0
		var fit: float = ((span - split + VoidMarks.ROW_GAP) / float(maxi(singles.size(), 1)) - VoidMarks.ROW_GAP) * 0.5
		if fit >= VoidMarks.ROW_DIE_LEAST:
			mode = "single"
			entries = singles
			_r = minf(VoidMarks.ROW_DIE_R, fit)
		else:
			mode = "stacks"
			_r = VoidMarks.ROW_STACK_R
			var all: Array = thrown + copies
			var width := func(list: Array) -> float:
				var total: float = -VoidMarks.ROW_GAP + split
				for entry in list:
					total += _item_width(entry) + VoidMarks.ROW_GAP
				return total
			if width.call(all) <= span:
				entries = all
			else:
				## The copies always show; thrown stacks take the room that is left, and the rest
				## fold into a "+N" at the far left.
				var keep: int = thrown.size()
				while keep > 0:
					var trial: Array = [_more_entry(thrown.slice(keep), all)] + thrown.slice(0, keep) + copies
					if width.call(trial) <= span:
						break
					keep -= 1
				entries = [_more_entry(thrown.slice(keep), all)] + thrown.slice(0, keep) + copies
		_build(arriving, from)
		_place()
		queue_redraw()

	func _more_entry(hidden: Array, all: Array) -> Dictionary:
		var count: int = 0
		for group in hidden:
			count += group.rolls.size()
		return {"kind": "more", "count": count, "all": all, "rolls": []}

	func _item_width(entry: Dictionary) -> float:
		if mode != "stacks":
			return _r * 2.0
		if str(entry.kind) == "more":
			var text: String = "+" + VoidMarks.short_count(int(entry.count))
			return maxf(VoidMarks.COUNT_R * 2.0, DeepUi.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, VoidMarks.COUNT_FONT).x + VoidMarks.COUNT_R * 0.9)
		var n: int = entry.rolls.size()
		if n <= 1:
			return VoidMarks.ROW_STACK_R * 2.0
		var tag: String = "×" + VoidMarks.short_count(n)
		return maxf(VoidMarks.ROW_STACK_R * 2.0, DeepUi.bold_font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, VoidMarks.ROW_BADGE).x + float(VoidMarks.ROW_BADGE) * 0.9)

	func _build(arriving: Array, from: Vector2) -> void:
		var index: int = 0
		for entry in entries:
			var holder := Control.new()
			holder.name = "Item%d" % index
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(holder)
			entry.holder = holder
			if str(entry.kind) == "more":
				var mark := CountMark.new(int(entry.count), VoidMarks.COUNT_R, VoidMarks.COUNT_FONT, VoidMarks.COUNT_FONT_LONG)
				holder.add_child(mark)
				mark.mouse_filter = Control.MOUSE_FILTER_STOP
				mark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var opened: Dictionary = entry
				mark.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_toggle_fold(opened)
						mark.accept_event())
				Tips.attach(mark, func() -> Control: return Plates.words("%s more thrown dice" % VoidMarks.with_commas(int(opened.count)), "Thrown by gems this turn, in no die's place. Click to lay every stack out.", "phantom dice", DeepUi.INFO))
				fold = mark
				entry.view = mark
			else:
				var n: int = entry.rolls.size()
				var face: int = int(entry.rolls[0].get("face", -1))
				var thumb: Control = VoidMarks.hollow_die(entry.die, _r * 2.0 * VoidMarks.ROW_DIE_FILL, face)
				thumb.mouse_filter = Control.MOUSE_FILTER_STOP
				holder.add_child(thumb)
				entry.view = thumb
				var here: int = index
				thumb.mouse_entered.connect(func() -> void: _select(here))
				thumb.mouse_exited.connect(func() -> void:
					if _chosen == here:
						_select(-1))
				thumb.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_select(-1 if _chosen == here else here)
						thumb.accept_event())
				var described: Dictionary = entry
				Tips.attach(thumb, func() -> Control: return _plate(described), {"tone": DeepUi.INFO})
				if n > 1:
					var tag: PanelContainer = VoidMarks.badge(holder, "×" + VoidMarks.short_count(n), VoidMarks.ROW_BADGE, str(entry.kind) == "thrown")
					entry.tag = tag
				for roll in entry.rolls:
					items[str(roll.get("die_id", ""))] = thumb
				## Just thrown: it flies in from the gem that threw it and lands with a pop.
				var fresh: bool = entry.rolls.any(func(r: Dictionary) -> bool: return arriving.has(str(r.get("die_id", ""))))
				if fresh and not DeepUi.headless():
					entry.arrive_from = from
			index += 1

	func _place() -> void:
		## Every item at its place along the row, over the tray.
		if entries.is_empty():
			return
		var split: float = 0.0
		for k in range(1, entries.size()):
			if str(entries[k].kind) == "copy" and str(entries[k - 1].kind) != "copy":
				split = VoidMarks.ROW_SPLIT
		var total: float = -VoidMarks.ROW_GAP + split
		for entry in entries:
			total += _item_width(entry) + VoidMarks.ROW_GAP
		var x: float = _tray.position.x + _tray.size.x * 0.5 - total * 0.5
		var tag_room: float = (float(VoidMarks.ROW_BADGE) * 0.65 if mode == "stacks" else 0.0)
		var y: float = _dock_top - VoidMarks.ROW_LIFT - tag_room - _r
		var arrivals: int = 0
		for k in range(entries.size()):
			var entry: Dictionary = entries[k]
			if k > 0 and str(entry.kind) == "copy" and str(entries[k - 1].kind) != "copy":
				x += split
			var w: float = _item_width(entry)
			var centre := Vector2(x + w * 0.5, y)
			entry.centre = centre
			var holder: Control = entry.holder
			holder.position = Vector2.ZERO
			var view: Control = entry.view
			if str(entry.kind) == "more":
				view.position = (centre - view.size * 0.5).round()
			else:
				var drawn: float = _r * VoidMarks.ROW_DIE_FILL
				view.position = (centre - Vector2(drawn, drawn)).round()
				view.size = Vector2(drawn * 2.0, drawn * 2.0)
				if entry.has("tag") and entry.tag != null:
					var tag: PanelContainer = entry.tag
					tag.position = (centre + Vector2(0.0, _r * 0.95) - tag.size * 0.5).round()
			if entry.has("arrive_from"):
				_arrive(entry, arrivals)
				arrivals += 1
				entry.erase("arrive_from")
			x += w + VoidMarks.ROW_GAP

	func _arrive(entry: Dictionary, order: int) -> void:
		## A spark leaves the gem that threw it and the die pops in where the spark lands; a
		## stack's tag counts up as its dice land.
		var view: Control = entry.view
		var from: Vector2 = Vector2(entry.arrive_from) - global_position
		var to: Vector2 = entry.centre
		var delay: float = 0.06 * float(mini(order, 16))
		if order < 16:
			var spark := TextureRect.new()
			spark.texture = DeepUi.glow_texture()
			spark.size = Vector2(22, 22)
			spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spark.modulate = Color(DeepUi.INFO.lightened(0.5), 0.0)
			spark.z_index = 6
			add_child(spark)
			var lift: Vector2 = Vector2(0.0, -maxf(60.0, absf(to.x - from.x) * 0.18))
			var tween := spark.create_tween()
			tween.tween_interval(delay)
			tween.tween_method(func(t: float) -> void:
				var mid: Vector2 = (from + to) * 0.5 + lift
				spark.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t) - spark.size * 0.5
				spark.modulate.a = sin(PI * t) * 0.95, 0.0, 1.0, 0.5)
			tween.tween_callback(spark.queue_free)
		DeepUi.pop_in(view, delay + 0.45, 0.3, 0.3)
		if entry.has("tag") and entry.tag != null:
			var tag: PanelContainer = entry.tag
			var said: Label = tag.get_node("Value")
			var n: int = entry.rolls.size()
			tag.modulate.a = 0.0
			var count := tag.create_tween()
			count.tween_interval(delay + 0.45)
			count.tween_property(tag, "modulate:a", 1.0, 0.2)
			count.parallel().tween_method(func(t: float) -> void:
				said.text = "×" + VoidMarks.short_count(maxi(1, int(round(float(n) * t * t)))), 0.0, 1.0, 0.9)

	func _plate(entry: Dictionary) -> Control:
		## What a phantom is and where it came from.
		var n: int = entry.rolls.size()
		var value: int = int(entry.rolls[0].get("value", 0))
		var kind: String = str(entry.kind)
		var title: String = ("Copy of a %d" % value) if kind == "copy" else ("A thrown %d · %s" % [value, str(entry.shape).to_lower()])
		if n > 1:
			title += " · ×%s" % VoidMarks.with_commas(n)
		var maker: Dictionary = maker_of.call(str(entry.rolls[0].get("die_id", ""))) if maker_of.is_valid() else {}
		var made: String = ("Made by %s" % str(maker.get("name", ""))) if not str(maker.get("name", "")).is_empty() else ("Copied from the die under it" if kind == "copy" else "Thrown by a gem on the rail")
		var text: String = "%s · it counts for every gem after it this turn, and is not yours to reroll." % made
		return Plates.words(title, text, "phantom " + DeepUi.plural(n, "die", "dice").trim_prefix(str(n) + " "), DeepUi.INFO)

	func _select(k: int) -> void:
		## One phantom picked out: its line goes solid, the die (or socket) it came from gets a
		## ring, and the others step back.
		_chosen = k
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			if str(entry.kind) == "more":
				continue
			var view: Control = entry.view
			view.modulate = Color(1, 1, 1, 0.4) if k >= 0 and index != k else Color.WHITE
		queue_redraw()

	func _toggle_fold(entry: Dictionary) -> void:
		if _fold_panel != null and is_instance_valid(_fold_panel):
			_fold_panel.queue_free()
			_fold_panel = null
			return
		_fold_panel = _build_fold(entry)

	func _build_fold(entry: Dictionary) -> Control:
		## Every stack, thrown dice then copies, on a plate of its own to the row's left with its
		## foot on the dock.
		var all: Array = entry.all
		var groups: Array = []
		var thrown: Array = all.filter(func(g: Dictionary) -> bool: return str(g.kind) == "thrown")
		var copies: Array = all.filter(func(g: Dictionary) -> bool: return str(g.kind) == "copy")
		if not thrown.is_empty():
			groups.append(["Thrown", thrown, true])
		if not copies.is_empty():
			groups.append(["Copies", copies, false])
		var cap: int = 9
		var iw: float = VoidMarks.ROW_STACK_R * 2.9
		var rh: float = VoidMarks.ROW_STACK_R * 3.1
		var rr: float = VoidMarks.ROW_STACK_R
		var pad: float = VoidMarks.POP_PAD * 0.8
		var label_w: float = iw * 1.45
		var rows: int = 0
		var widest: int = 1
		for group in groups:
			rows += ceili(float(group[1].size()) / float(cap))
			widest = maxi(widest, mini(cap, group[1].size()))
		var w: float = label_w + float(widest) * iw + 2.0 * pad
		var h: float = float(rows) * rh + 2.0 * pad
		var fold_view: Control = entry.view
		var right: float = fold_view.position.x - 10.0
		var left: float = maxf(_bounds.x, right - w)
		var top: float = _dock_top - 10.0 - h
		var plate := Control.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.position = Vector2(left, top).round()
		plate.size = Vector2(w, h)
		plate.z_index = 5
		add_child(plate)
		VoidMarks.ledger_panel(plate, Rect2(Vector2.ZERO, plate.size))
		var y: float = pad
		var first: bool = true
		for group in groups:
			if not first:
				var rule := ColorRect.new()
				rule.color = DeepUi.LEDGER_LINE
				rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rule.position = Vector2(pad, y - 1.0)
				rule.size = Vector2(w - 2.0 * pad, 2.0)
				plate.add_child(rule)
			first = false
			var list: Array = group[1]
			var count: int = 0
			for g in list:
				count += g.rolls.size()
			var heading := DeepUi.vbox(plate, 0)
			heading.position = Vector2(pad + 4.0, y + rh * 0.5 - 14.0)
			heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
			DeepUi.heading(heading, str(group[0]), 10, DeepUi.MUTED)
			DeepUi.label(heading, VoidMarks.with_commas(count), 13, DeepUi.PAPER)
			for k in range(list.size()):
				var g: Dictionary = list[k]
				var col: int = k % cap
				var row: int = k / cap
				var centre := Vector2(pad + label_w + float(col) * iw + iw * 0.5, y + float(row) * rh + rh * 0.5 - 5.0)
				var drawn: float = rr * VoidMarks.ROW_DIE_FILL
				var thumb: Control = VoidMarks.hollow_die(g.die, drawn * 2.0, int(g.rolls[0].get("face", -1)))
				thumb.position = centre - Vector2(drawn, drawn)
				thumb.size = Vector2(drawn * 2.0, drawn * 2.0)
				thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				plate.add_child(thumb)
				if g.rolls.size() > 1:
					var tag: PanelContainer = VoidMarks.badge(plate, "×" + VoidMarks.with_commas(g.rolls.size()), VoidMarks.ROW_BADGE, bool(group[2]))
					tag.position = (centre + Vector2(0.0, rr * 0.95) - tag.size * 0.5).round()
			y += float(ceili(float(list.size()) / float(cap))) * rh
		return plate

	func _draw() -> void:
		## A dotted line from each copy to the die it copies; a pale one from a thrown die down to
		## the gem that threw it, when that is known. The one picked out draws solid, the rest
		## fade while it is.
		var any_chosen: bool = _chosen >= 0
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			if not entry.has("centre") or str(entry.kind) == "more":
				continue
			var chosen: bool = index == _chosen
			var faded: float = 0.2 if any_chosen and not chosen else 1.0
			var start: Vector2 = Vector2(entry.centre) + Vector2(0.0, _r * 0.8 + (float(VoidMarks.ROW_BADGE) * 0.65 if entry.has("tag") and entry.tag != null else 0.0))
			if str(entry.kind) == "copy":
				var target: Control = die_anchor.call(str(entry.source_id)) if die_anchor.is_valid() else null
				if target == null or not is_instance_valid(target):
					continue
				var rect: Rect2 = target.get_global_rect()
				var end: Vector2 = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 4.0) - global_position
				if chosen:
					draw_line(start, end, Color("cfe5ff"), 3.0, true)
					draw_arc(Vector2(rect.get_center()) - global_position, rect.size.x * 0.5 + 6.0, 0.0, TAU, 40, Color("cfe5ff"), 3.0, true)
				else:
					draw_dashed_line(start, end, Color(0.59, 0.78, 1.0, 0.75 * faded), 2.0, 6.0, true)
			else:
				var maker: Dictionary = maker_of.call(str(entry.rolls[0].get("die_id", ""))) if maker_of.is_valid() else {}
				var card: Control = socket_anchor.call(int(maker.get("socket", -1))) if maker.has("socket") and socket_anchor.is_valid() else null
				if card == null or not is_instance_valid(card):
					continue
				var rect: Rect2 = card.get_global_rect()
				var end: Vector2 = Vector2(rect.position.x + rect.size.x * 0.5, _dock_top + 4.0)
				end.x -= global_position.x
				## A curve: down from the die, across under the room, into the socket from above.
				var c1: Vector2 = start + Vector2(0.0, 70.0)
				var c2: Vector2 = end + Vector2(90.0, -80.0)
				var previous: Vector2 = start
				var tone := Color(0.88, 0.91, 0.97, (0.9 if chosen else 0.55) * faded)
				for step in range(1, 25):
					var t: float = float(step) / 24.0
					var point: Vector2 = start.bezier_interpolate(c1, c2, end, t)
					if chosen:
						draw_line(previous, point, tone, 3.0, true)
					elif step % 2 == 1:
						draw_line(previous, point, tone, 2.0, true)
					previous = point
				if chosen:
					draw_arc(Vector2(rect.get_center()) - global_position, rect.size.x * 0.5 + 6.0, 0.0, TAU, 40, Color("cfe5ff"), 3.0, true)
