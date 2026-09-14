extends Control
## The shop: the game's main menu, drawn as a room full of things to click.
##
## Every object that does something is its own picture laid over the room at a fixed spot
## on a 1600 × 900 stage, and the stage is scaled to fit the window. An object answers only
## where it is actually painted, so the shopkeeper behind the counter can still be clicked
## over the glass. Hovering or focusing one outlines it and names it; clicking it, or
## pressing accept while it has focus, asks the screen to open whatever it stands for.
##
## The pictures are SVGs under `res://assets/hub/`. Replacing one with a PNG of the same name
## and roughly the same framing needs no code change; `LAYOUT` is where to move one.

signal activated(id: String)

const STAGE := Vector2(1600, 900)
const ART := "res://assets/hub/%s.%s"
## Drawn in order, back to front. Position and size are stage pixels.
const LAYOUT := [
	{"id": "commission_board", "rect": Rect2(110, 150, 300, 290), "name": "Commission board", "hint": "Commissions and special missions"},
	{"id": "wall_map", "rect": Rect2(1200, 125, 250, 220), "name": "The map of the deeps", "hint": "Choose where to dig"},
	{"id": "door", "rect": Rect2(1450, 160, 150, 460), "name": "The door", "hint": "Host a party, invite friends, or join one"},
	{"id": "clock", "rect": Rect2(686, 166, 96, 130), "name": "The clock", "hint": "Settings"},
	{"id": "shopkeeper", "rect": Rect2(700, 262, 240, 300), "name": "Old Garnet, the jeweller", "hint": "Today's gems for sale"},
	{"id": "counter", "rect": Rect2(540, 490, 640, 270), "name": "The display case", "hint": "Today's gems for sale"},
	{"id": "ledger", "rect": Rect2(1034, 432, 120, 76), "name": "The ledger", "hint": "The expedition journal"},
	{"id": "jewel_bag", "rect": Rect2(370, 640, 200, 210), "name": "Your gem sack", "hint": "Every gem you own, have seen, or have yet to find"},
	{"id": "armor_stand", "rect": Rect2(140, 420, 210, 450), "name": "The armor stand", "hint": "Heroes and their loadouts"},
	{"id": "mine_cart", "rect": Rect2(1200, 612, 340, 280), "name": "The mine cart", "hint": "Set out on an expedition"}]
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float width = 5.0;
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float outline = 0.0;
	if (glow > 0.001) {
		vec2 reach = TEXTURE_PIXEL_SIZE * width;
		for (int i = 0; i < 16; i++) {
			float angle = float(i) * 6.2831853 / 16.0;
			outline = max(outline, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * reach).a);
		}
	}
	float edge = clamp(outline - base.a, 0.0, 1.0) * glow;
	vec3 lit = base.rgb * (1.0 + 0.2 * glow);
	COLOR = vec4(mix(lit, outline_color.rgb, edge), max(base.a, edge));
}
"""

class Hotspot extends TextureRect:
	## A picture that only counts as hit where it is opaque.
	var id := ""
	var mask: Image
	func _has_point(point: Vector2) -> bool:
		if mask == null or size.x <= 0.0 or size.y <= 0.0:
			return Rect2(Vector2.ZERO, size).has_point(point)
		var pixel := Vector2i((point / size) * Vector2(mask.get_size()))
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask.get_width() or pixel.y >= mask.get_height():
			return false
		return mask.get_pixelv(pixel).a > 0.2

static var _shader: Shader

var reduced_motion := false
var badges: Dictionary = {}
var _stage: Control
var _spots: Dictionary = {}
var _glow: Dictionary = {}
var _hovered := ""
var _nameplate: PanelContainer
var _name_label: Label
var _hint_label: Label
var _badge_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OUTLINE_SHADER
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stage)
	var room := TextureRect.new()
	room.texture = _art("background")
	room.size = STAGE
	room.stretch_mode = TextureRect.STRETCH_SCALE
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(room)
	for entry in LAYOUT:
		var spot := Hotspot.new()
		spot.id = entry.id
		spot.texture = _art(entry.id)
		spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spot.stretch_mode = TextureRect.STRETCH_SCALE
		spot.position = entry.rect.position
		spot.size = entry.rect.size
		spot.focus_mode = Control.FOCUS_ALL
		spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		spot.tooltip_text = "%s\n%s" % [entry.name, entry.hint]
		spot.set_meta("focus_tag", "hub_" + entry.id)
		var material := ShaderMaterial.new()
		material.shader = _shader
		spot.material = material
		if spot.texture != null:
			var image: Image = spot.texture.get_image()
			if image != null:
				spot.mask = image
		spot.mouse_entered.connect(_hover.bind(entry.id))
		spot.mouse_exited.connect(_unhover.bind(entry.id))
		spot.focus_entered.connect(_hover.bind(entry.id))
		spot.focus_exited.connect(_unhover.bind(entry.id))
		spot.gui_input.connect(_spot_input.bind(entry.id))
		_stage.add_child(spot)
		_spots[entry.id] = spot
		_glow[entry.id] = 0.0
	_badge_layer = Control.new()
	_badge_layer.size = STAGE
	_badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_badge_layer)
	_nameplate = PanelContainer.new()
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.03, 0.9)
	style.border_color = Color("e8b661")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	_nameplate.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_nameplate.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color("e8b661"))
	column.add_child(_name_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color("d8c7a4"))
	column.add_child(_hint_label)
	_nameplate.visible = false
	_stage.add_child(_nameplate)
	resized.connect(_fit)
	_fit()
	_draw_badges()

func _art(id: String) -> Texture2D:
	for extension in ["png", "svg"]:
		var path: String = ART % [id, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func spot(id: String) -> Control:
	return _spots.get(id, null)

func set_badges(values: Dictionary) -> void:
	## Small counters pinned to objects: notes ready to claim on the board, and so on.
	badges = values
	if is_instance_valid(_badge_layer):
		_draw_badges()

func _draw_badges() -> void:
	for child in _badge_layer.get_children():
		child.queue_free()
	for id in badges:
		var text := str(badges[id])
		if text.is_empty() or not _spots.has(id):
			continue
		var rect: Rect2 = Rect2(_spots[id].position, _spots[id].size)
		var badge := Label.new()
		badge.text = text
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color("1a100a"))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("6fe3b0")
		style.set_corner_radius_all(14)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 2
		style.content_margin_bottom = 3
		badge.add_theme_stylebox_override("normal", style)
		badge.position = rect.position + Vector2(rect.size.x - 30, -6)
		_badge_layer.add_child(badge)

func _fit() -> void:
	if not is_instance_valid(_stage) or size.x <= 0.0 or size.y <= 0.0:
		return
	var factor: float = minf(size.x / STAGE.x, size.y / STAGE.y)
	_stage.scale = Vector2(factor, factor)
	_stage.position = (size - STAGE * factor) * 0.5

func _hover(id: String) -> void:
	_hovered = id
	var entry: Dictionary = {}
	for candidate in LAYOUT:
		if candidate.id == id: entry = candidate
	_name_label.text = str(entry.get("name", ""))
	_hint_label.text = str(entry.get("hint", ""))
	_nameplate.visible = true
	_nameplate.reset_size()
	var rect: Rect2 = entry.get("rect", Rect2())
	var above := Vector2(rect.position.x + rect.size.x * 0.5 - _nameplate.size.x * 0.5, rect.position.y - _nameplate.size.y - 10)
	_nameplate.position = Vector2(clampf(above.x, 8, STAGE.x - _nameplate.size.x - 8), maxf(8, above.y))

func _unhover(id: String) -> void:
	if _hovered == id and not (is_instance_valid(_spots.get(id)) and _spots[id].has_focus()):
		_hovered = ""
		_nameplate.visible = false

func _spot_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		activated.emit(id)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activated.emit(id)

func _process(delta: float) -> void:
	for id in _spots:
		var target: float = 1.0 if id == _hovered else 0.0
		var current: float = _glow[id]
		var next: float = target if reduced_motion else move_toward(current, target, delta * 6.0)
		if not is_equal_approx(next, current):
			_glow[id] = next
			(_spots[id].material as ShaderMaterial).set_shader_parameter("glow", next)
