class_name DeepUi
extends RefCounted
## The flat frame everything sits in. Dark slate, one warm accent, one line weight.
## Only stones, dice and beams are allowed to glow; the kit itself stays quiet.

const INK := Color("0b0e14")
const SLATE := Color("141924")
const SLATE_HI := Color("1c2331")
const SLATE_LOW := Color("0f131c")
const LINE := Color("2c3648")
const PAPER := Color("e9edf3")
const MUTED := Color("8792a6")
const DIM := Color("5b6578")
const ACCENT := Color("e2b23a")
const ACCENT_DIM := Color("8a6d2a")
const GOOD := Color("6fe3b0")
const BAD := Color("ff7a6b")
const INFO := Color("76b6ff")
const HP := Color("3fb56b")
const HP_LOST := Color("5a2a2a")
const BLOCK := Color("6fa8ff")
const POISON := Color("9ad35a")
const TIER_COLOURS := {"ROUGH": Color("9aa3b2"), "FINE": Color("7fd1a8"), "PRECIOUS": Color("6fa8ff"), "EXQUISITE": Color("c58bff"), "PEERLESS": Color("ffcf5a")}

static func colour(key: String) -> Color:
	## A colour family's hue from the pack.
	var hue: String = str(DeepContent.colour(key).get("hue", ""))
	return Color(hue) if not hue.is_empty() else PAPER

static func tier_colour(tier: String) -> Color:
	return TIER_COLOURS.get(tier, PAPER)

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, pad: int = 12, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width if border.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.anti_aliasing = true
	return box

static func theme(scale: float = 1.0) -> Theme:
	var t := Theme.new()
	t.default_font_size = int(15 * scale)
	t.set_stylebox("panel", "Panel", flat(SLATE, LINE, 10, 14))
	t.set_stylebox("panel", "PanelContainer", flat(SLATE, LINE, 10, 14))
	t.set_stylebox("normal", "Button", flat(SLATE_HI, LINE, 8, 10))
	t.set_stylebox("hover", "Button", flat(Color("242d3d"), Color("3d4a60"), 8, 10))
	t.set_stylebox("pressed", "Button", flat(ACCENT_DIM, ACCENT, 8, 10))
	t.set_stylebox("disabled", "Button", flat(SLATE_LOW, Color(LINE, 0.5), 8, 10))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), ACCENT, 8, 10, 2))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", PAPER)
	t.set_stylebox("panel", "TooltipPanel", flat(INK, LINE, 6, 8))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_stylebox("panel", "ScrollContainer", flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	return t

# --- builders ------------------------------------------------------------------------------

static func vbox(parent: Node, separation: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

static func hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

static func panel(parent: Node, bg: Color = SLATE, border: Color = LINE, radius: int = 10, pad: int = 14) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", flat(bg, border, radius, pad))
	parent.add_child(box)
	return box

static func label(parent: Node, text: String, size: int = 15, color: Color = PAPER, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func heading(parent: Node, text: String, size: int = 13, color: Color = ACCENT) -> Label:
	var l := label(parent, text.to_upper(), size, color)
	l.add_theme_constant_override("line_spacing", 0)
	return l

static func button(parent: Node, text: String, callback: Callable = Callable(), size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	if callback.is_valid():
		b.pressed.connect(callback)
	parent.add_child(b)
	return b

static func spacer(parent: Node, horizontal: bool = true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

static func chip(parent: Node, text: String, color: Color, size: int = 12) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", flat(Color(color, 0.16), Color(color, 0.55), 6, 5))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	label(box, text, size, color)
	return box

class Bar extends Control:
	## A flat gauge: filled share, a ghost of what was lost, a second overlay for block.
	var ratio: float = 1.0
	var fill: Color = DeepUi.HP
	var back: Color = DeepUi.HP_LOST
	var overlay: float = 0.0
	var overlay_colour: Color = DeepUi.BLOCK
	var text: String = ""
	func _init(height: float = 10.0) -> void:
		custom_minimum_size = Vector2(60, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_values(new_ratio: float, new_text: String = "", new_overlay: float = 0.0) -> void:
		ratio = clampf(new_ratio, 0.0, 1.0)
		text = new_text
		overlay = clampf(new_overlay, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, back)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill)
		if overlay > 0.0:
			draw_rect(Rect2(Vector2(0, size.y - maxf(3.0, size.y * 0.3)), Vector2(size.x * overlay, maxf(3.0, size.y * 0.3))), overlay_colour)
		draw_rect(r, DeepUi.LINE, false, 1.0)
		if not text.is_empty() and size.y >= 12.0:
			var font := ThemeDB.fallback_font
			var font_size := int(size.y * 0.8)
			var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, Vector2((size.x - measured.x) * 0.5, size.y * 0.5 + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.PAPER)

static func bar(parent: Node, height: float = 10.0, fill: Color = HP, back: Color = HP_LOST) -> Bar:
	var b := Bar.new(height)
	b.fill = fill
	b.back = back
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

static func float_text(parent: Control, at: Vector2, text: String, color: Color, size: int = 22, rise: float = 46.0, seconds: float = 0.9) -> void:
	## A number that rises and fades where something happened.
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 50
	parent.add_child(l)
	l.position = at - Vector2(l.get_minimum_size().x * 0.5, 0)
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", at.y - rise, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, seconds).set_delay(seconds * 0.4)
	tween.chain().tween_callback(l.queue_free)

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func stone_name(stone: Dictionary) -> String:
	return DeepStone.name(stone) if bool(stone.get("appraised", false)) else DeepStone.raw_name(stone)
