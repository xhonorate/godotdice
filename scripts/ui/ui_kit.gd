extends RefCounted
## Shared visual language: palette, generated gradient panels, and the small
## decorated widgets the screens are assembled from.

const VOID := Color("070a12")
const INK := Color("0c111c")
const PANEL := Color("161e2e")
const PANEL_HI := Color("1f2a3d")
const PANEL_LOW := Color("101725")
const LINE := Color("2f3d55")
const LINE_SOFT := Color("212c3f")
const GOLD := Color("e8b661")
const GOLD_DIM := Color("8a6d3c")
const PAPER := Color("eef1f7")
const MUTED := Color("8f9fb5")
const GREEN := Color("6fe3b0")
const RED := Color("ff7a6b")
const BLUE := Color("76b6ff")
const VIOLET := Color("b98bff")
const AMBER := Color("ffcf7a")

static var _boxes: Dictionary = {}

# --- generated stylebox art ---------------------------------------------------

static func _rounded(width: int, height: int, radius: float, top: Color, bottom: Color, border: Color, border_width: float, sheen: float) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var half := Vector2(float(width), float(height)) * 0.5
	for y in height:
		var t := (float(y) + 0.5) / float(height)
		var fill := top.lerp(bottom, smoothstep(0.0, 1.0, t))
		if sheen > 0.0:
			fill = fill.lerp(Color(1, 1, 1, 1), sheen * clampf(1.0 - t * 3.2, 0.0, 1.0) * 0.35)
		for x in width:
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) - half
			var q := Vector2(absf(point.x), absf(point.y)) - (half - Vector2(radius, radius))
			var distance: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var coverage := clampf(0.5 - distance, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var color := fill
			if border_width > 0.0:
				# distance is 0 at the outline and negative inside: fade the rim inwards.
				var inward := clampf(-distance / maxf(border_width, 0.001), 0.0, 1.0)
				color = border.lerp(fill, smoothstep(0.0, 1.0, inward))
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * coverage))
	return ImageTexture.create_from_image(image)

static func panel_box(top: Color, bottom: Color, border: Color, radius: int = 10, padding: int = 16, border_width: float = 1.4, sheen: float = 0.0) -> StyleBoxTexture:
	var tag := "%s|%s|%s|%d|%d|%.1f|%.2f" % [top.to_html(), bottom.to_html(), border.to_html(), radius, padding, border_width, sheen]
	var texture: ImageTexture = _boxes.get(tag, null)
	if texture == null:
		var span := radius * 2 + 6
		texture = _rounded(span, span, float(radius), top, bottom, border, border_width, sheen)
		_boxes[tag] = texture
	var box := StyleBoxTexture.new()
	box.texture = texture
	for edge in ["left", "right", "top", "bottom"]:
		box.set("texture_margin_" + edge, radius + 2)
		box.set("content_margin_" + edge, padding)
	return box

static func flat(bg: Color, border: Color, radius: int = 10, padding: int = 16, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func release() -> void:
	## Drops the generated stylebox textures so nothing outlives the interface.
	_boxes.clear()

# --- theme --------------------------------------------------------------------

static func build_theme(text_scale: float) -> Theme:
	var built := Theme.new()
	built.default_font_size = int(16 * text_scale)
	for control in ["Label", "Button", "LineEdit", "RichTextLabel", "CheckButton", "OptionButton", "PopupMenu", "SpinBox"]:
		built.set_color("font_color", control, PAPER)
	built.set_color("font_hover_color", "Button", Color.WHITE)
	built.set_color("font_pressed_color", "Button", GOLD)
	built.set_color("font_focus_color", "Button", Color.WHITE)
	built.set_color("font_disabled_color", "Button", Color("5c687a"))
	built.set_color("font_placeholder_color", "LineEdit", MUTED)
	built.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))
	built.set_constant("outline_size", "Label", 0)

	built.set_stylebox("normal", "Button", panel_box(Color("2b3a52"), Color("1b2434"), LINE, 8, 13, 1.4, 0.45))
	built.set_stylebox("hover", "Button", panel_box(Color("3c5074"), Color("26334a"), GOLD_DIM, 8, 13, 1.6, 0.65))
	built.set_stylebox("pressed", "Button", panel_box(Color("1a2231"), Color("2b3a52"), GOLD, 8, 13, 1.6, 0.0))
	built.set_stylebox("disabled", "Button", panel_box(Color("161d29"), Color("111721"), LINE_SOFT, 8, 13, 1.0, 0.0))
	built.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), GOLD, 8, 0, 2))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		built.set_stylebox(state, "OptionButton", built.get_stylebox(state, "Button"))
		built.set_stylebox(state, "MenuButton", built.get_stylebox(state, "Button"))
	built.set_stylebox("normal", "LineEdit", panel_box(Color("0b111c"), Color("0e1522"), LINE, 7, 11, 1.4, 0.0))
	built.set_stylebox("focus", "LineEdit", panel_box(Color("0b111c"), Color("101a2a"), GOLD, 7, 11, 1.6, 0.0))
	built.set_stylebox("panel", "PopupMenu", panel_box(PANEL_HI, PANEL, LINE, 9, 10, 1.4, 0.2))
	built.set_stylebox("panel", "PanelContainer", panel_box(PANEL_HI, PANEL, LINE, 10, 14, 1.4, 0.25))
	built.set_stylebox("background", "ProgressBar", flat(Color("080d16"), Color("22303f"), 5, 0))
	built.set_stylebox("fill", "ProgressBar", flat(GREEN, GREEN, 5, 0))
	built.set_stylebox("panel", "TooltipPanel", panel_box(Color("233046"), Color("18212f"), GOLD_DIM, 8, 13, 1.4, 0.2))
	built.set_color("font_color", "TooltipLabel", PAPER)
	built.set_stylebox("grabber", "HSlider", flat(GOLD, GOLD, 7, 0))
	built.set_stylebox("slider", "HSlider", flat(Color("101825"), LINE, 4, 0))
	built.set_constant("separation", "VBoxContainer", 10)
	built.set_constant("separation", "HBoxContainer", 10)
	built.set_constant("h_separation", "GridContainer", 12)
	built.set_constant("v_separation", "GridContainer", 12)
	built.set_constant("margin_left", "MarginContainer", 0)
	return built

# --- widgets ------------------------------------------------------------------

class Meter extends Control:
	## A segmented bar with a shine, a shortfall ghost and an overlay caption.
	var value := 0.0
	var maximum := 1.0
	var ghost := 0.0
	var fill := Color("6fe3b0")
	var track := Color("0a1019")
	var caption := ""
	var caption_color := Color("eef1f7")
	var segments := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 16

	func set_values(current: float, top: float, shortfall: float = 0.0) -> void:
		value = current
		maximum = maxf(top, 0.0001)
		ghost = shortfall
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, track, true)
		if ghost > 0.0:
			var ghost_width := size.x * clampf((value + ghost) / maximum, 0.0, 1.0)
			draw_rect(Rect2(0, 0, ghost_width, size.y), Color(fill, 0.22), true)
		var width := size.x * clampf(value / maximum, 0.0, 1.0)
		if width > 0.5:
			draw_rect(Rect2(0, 0, width, size.y), fill, true)
			draw_rect(Rect2(0, 0, width, size.y * 0.42), Color(1, 1, 1, 0.20), true)
		if segments > 1:
			for i in range(1, segments):
				var x := size.x * float(i) / float(segments)
				draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(0, 0, 0, 0.45), 1.0)
		draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)
		if not caption.is_empty():
			var font := ThemeDB.fallback_font
			var font_size := int(clampf(size.y * 0.78, 9.0, 15.0))
			var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var origin := Vector2(size.x * 0.5 - text_size.x * 0.5, size.y * 0.5 + text_size.y * 0.32)
			draw_string_outline(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.75))
			draw_string(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, caption_color)

class Track extends Control:
	## The room track for the current campaign: passed, current and boss rooms.
	var total := 9
	var here := 1
	var bosses: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 26

	func _draw() -> void:
		if total <= 0:
			return
		var step := size.x / float(total)
		var y := size.y * 0.5
		draw_line(Vector2(step * 0.5, y), Vector2(size.x - step * 0.5, y), Color("22304a"), 2.0)
		if here > 1:
			draw_line(Vector2(step * 0.5, y), Vector2(step * (float(here) - 0.5), y), Color("6fe3b0"), 2.0)
		for room in range(1, total + 1):
			var x := step * (float(room) - 0.5)
			var boss: bool = bosses.has(room)
			var radius := 6.5 if room == here else (5.0 if boss else 3.6)
			var tone := Color("e8b661") if room == here else (Color("6fe3b0") if room < here else (Color("b98bff") if boss else Color("39496a")))
			if boss:
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, y - radius - 2.0), Vector2(x + radius + 2.0, y),
					Vector2(x, y + radius + 2.0), Vector2(x - radius - 2.0, y)]), tone)
			else:
				draw_circle(Vector2(x, y), radius, tone)
			if room == here:
				draw_arc(Vector2(x, y), radius + 4.0, 0.0, TAU, 24, Color("e8b661", 0.55), 1.5, true)

class Rule extends Control:
	## A hairline separator that fades out at both ends.
	var color := Color("2f3d55")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 9

	func _draw() -> void:
		var y := size.y * 0.5
		var steps := 26
		for i in steps:
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			var fade := sin(PI * (t0 + t1) * 0.5)
			draw_line(Vector2(size.x * t0, y), Vector2(size.x * t1, y), Color(color, fade * 0.9), 1.0)

static func meter(parent: Node, current: float, top: float, fill: Color, height: int = 14, caption: String = "", shortfall: float = 0.0) -> Meter:
	var bar := Meter.new()
	bar.fill = fill
	bar.caption = caption
	bar.custom_minimum_size.y = height
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)
	bar.set_values(current, top, shortfall)
	return bar

static func rule(parent: Node, color: Color = LINE) -> Rule:
	var line := Rule.new()
	line.color = color
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(line)
	return line

static func chip(parent: Node, text: String, color: Color, font_size: int = 11) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.add_theme_stylebox_override("panel", flat(Color(color, 0.16), Color(color, 0.55), 999, 7, 1))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	holder.add_child(label)
	parent.add_child(holder)
	return holder

static func icon(parent: Node, texture: Texture2D, edge: float, tint: Color = Color.WHITE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(edge, edge)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = tint
	parent.add_child(image)
	return image
