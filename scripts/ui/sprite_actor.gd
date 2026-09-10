extends Control
## An animated character sprite. The texture is a still image; motion comes from
## deformation, offset and recolouring, so authored art drops in with no extra frames.

const FLASH_SHADER := """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	texel.rgb = mix(texel.rgb, vec3(luma * 0.85), drain);
	texel.rgb = mix(texel.rgb, flash_color.rgb, flash);
	texel.rgb += flash_color.rgb * glow * 0.25 * texel.a;
	COLOR = texel * COLOR;
}
"""

static var _shader: Shader

@export var facing := 1.0
@export var idle_speed := 1.0
@export var bob := 1.0
@export var show_ground := true

var accent := Color("e8b661")
var downed := false
var targeted := false
var acting := false

var _image: TextureRect
var _material: ShaderMaterial
var _clock := 0.0
var _phase := 0.0
var _hit := 0.0
var _lunge := 0.0
var _cast := 0.0
var _reduced := false
var _pending: Texture2D

static func release() -> void:
	_shader = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_phase = randf() * TAU
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var shadow := Control.new()
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.draw.connect(_draw_ground.bind(shadow))
	add_child(shadow)
	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.material = _material
	_image.texture = _pending
	add_child(_image)
	resized.connect(func() -> void: _image.pivot_offset = size * Vector2(0.5, 0.92))

func setup(texture: Texture2D, tint: Color, reduced_motion: bool) -> void:
	_pending = texture
	if is_instance_valid(_image) and _image.texture != texture:
		_image.texture = texture
	accent = tint
	_reduced = reduced_motion
	if is_instance_valid(_image):
		_image.pivot_offset = size * Vector2(0.5, 0.92)

func strike() -> void:
	_lunge = 1.0

func flinch() -> void:
	_hit = 1.0

func channel() -> void:
	_cast = 1.0

func _process(delta: float) -> void:
	if not is_instance_valid(_image):
		return
	_clock += delta * idle_speed
	_hit = maxf(0.0, _hit - delta * 2.6)
	_lunge = maxf(0.0, _lunge - delta * 2.2)
	_cast = maxf(0.0, _cast - delta * 1.4)
	var breathe := 0.0 if _reduced else sin(_clock * 1.9 + _phase)
	var sway := 0.0 if _reduced else sin(_clock * 0.9 + _phase * 0.5)
	var lunge := ease(_lunge, 0.4) * (1.0 - _lunge) * 4.0
	var shake := 0.0 if _reduced else sin(_hit * 44.0) * _hit * 6.0
	_image.scale = Vector2(
		1.0 - breathe * 0.022 * bob + _lunge * 0.10,
		1.0 + breathe * 0.030 * bob - _lunge * 0.06)
	_image.position = Vector2(
		sway * 1.6 * bob + facing * lunge * 12.0 + shake,
		-absf(breathe) * 2.4 * bob - _lunge * 6.0)
	_image.rotation = deg_to_rad(sway * 1.1 * bob + (14.0 if downed else 0.0))
	if downed:
		_image.modulate = Color(0.75, 0.75, 0.8, 0.55)
		_material.set_shader_parameter("drain", 0.85)
	else:
		_image.modulate = Color.WHITE
		_material.set_shader_parameter("drain", 0.0)
	_material.set_shader_parameter("flash", clampf(_hit, 0.0, 0.85))
	_material.set_shader_parameter("flash_color", Color("ffd9c8") if _hit > 0.0 else accent)
	var aura := _cast * 1.4
	if targeted and not _reduced:
		aura = maxf(aura, 0.25 + 0.15 * sin(_clock * 4.0))
	_material.set_shader_parameter("glow", aura)
	if targeted or _hit > 0.0 or acting:
		queue_redraw()
		for child in get_children():
			if child is Control and child != _image:
				child.queue_redraw()

func _draw_ground(target: Control) -> void:
	if not show_ground:
		return
	var centre := Vector2(target.size.x * 0.5, target.size.y * 0.93)
	var width := target.size.x * (0.30 - 0.04 * _lunge)
	target.draw_set_transform(centre, 0.0, Vector2(1.0, 0.32))
	target.draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.30))
	target.draw_circle(Vector2.ZERO, width * 0.72, Color(0, 0, 0, 0.22))
	if targeted:
		var pulse := 0.45 + 0.25 * sin(_clock * 4.0)
		target.draw_arc(Vector2.ZERO, width * 1.35, 0.0, TAU, 40, Color(accent, pulse), 4.0, true)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
