extends Control
## What a lapidary sees while they are down and the party fights on without them: the room
## drained of its colour and bruised at the edges, a slow pulse in it, and a banner that says
## what has happened and when it ends. Going down drains the colour in; getting back on their
## feet at a landing floods it back with a warm flash.
##
## Only in a party: alone, going down is the end of the dig, and the run's own ending says so.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec3 col = texture(screen, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(lum) * vec3(0.92, 0.94, 1.02);
	col = mix(col, grey, amount * 0.85);
	col *= 1.0 - amount * 0.22;
	float d = length((UV - 0.5) * vec2(1.0, 0.8));
	float edge = smoothstep(0.3, 0.85, d);
	col = mix(col, vec3(0.32, 0.02, 0.04), edge * amount * (0.45 + 0.25 * pulse));
	COLOR = vec4(col, 1.0);
}
"""

var down: bool = false
var _amount: float = 0.0
var _clock: float = 0.0
var _wash: ColorRect
var _banner: PanelContainer
var _glyph: TextureRect
var _title: Label
var _line: Label
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash = ColorRect.new()
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_wash.material = material
	add_child(_wash)
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.05, 0.02, 0.03, 0.92), Color(DeepUi.BAD, 0.7), 14, 12, 0.6))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)
	var row := DeepUi.hbox(_banner, 12)
	_glyph = DeepUi.icon(row, "skull", 30, DeepUi.BAD)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := DeepUi.vbox(row, 0)
	_title = DeepUi.title(words, "You are down", 20, DeepUi.BAD)
	_line = DeepUi.label(words, "The party carries you on. You get back on your feet at the next landing.", 13, DeepUi.MUTED)
	_show(0.0)
	_banner.visible = false

func _process(delta: float) -> void:
	_clock += delta
	if _amount <= 0.001:
		return
	## A heartbeat: two quick beats and a rest.
	var beat: float = fmod(_clock, 1.4)
	var pulse: float = exp(-pow((beat - 0.1) * 14.0, 2.0)) + 0.6 * exp(-pow((beat - 0.38) * 14.0, 2.0))
	(_wash.material as ShaderMaterial).set_shader_parameter("pulse", pulse)

func _show(amount: float) -> void:
	_amount = amount
	_wash.visible = amount > 0.001
	(_wash.material as ShaderMaterial).set_shader_parameter("amount", amount)

func set_down(now_down: bool, animate: bool) -> void:
	## The local player went down, or got back up. `animate` is false when the state is only
	## being caught up with (a party joined mid-run, a screen shown again).
	if now_down == down:
		return
	down = now_down
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree():
		_show(1.0 if down else 0.0)
		_banner.visible = down
		_banner.modulate.a = 1.0
		_set_words(down)
		return
	_set_words(down)
	_banner.visible = true
	_banner.pivot_offset = _banner.size * 0.5
	_tween = create_tween()
	if down:
		DeepAudio.play("defeat", {"volume": 0.55, "pitch": 0.8})
		_banner.modulate.a = 0.0
		_banner.scale = Vector2(1.25, 1.25)
		_tween.set_parallel(true)
		_tween.tween_method(_show, _amount, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
		_tween.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		DeepAudio.play("heal", {"volume": 0.8})
		DeepAudio.play("unlock", {"volume": 0.6})
		_banner.modulate.a = 1.0
		DeepUi.burst(self, Vector2(size.x * 0.5, size.y * 0.55), DeepUi.GOOD, 40, 420.0, 1.0, 6.0)
		DeepUi.burst(self, Vector2(size.x * 0.5, size.y * 0.55), DeepUi.ACCENT, 26, 260.0, 1.2, 4.0)
		DeepUi.pulse(_banner, 1.12, 0.4)
		_tween.tween_method(_show, _amount, 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_interval(1.6)
		_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
		_tween.tween_callback(func() -> void: _banner.visible = down)

func _set_words(is_down: bool) -> void:
	var tone: Color = DeepUi.BAD if is_down else DeepUi.GOOD
	_banner.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.05, 0.02, 0.03, 0.92) if is_down else Color(0.02, 0.05, 0.03, 0.92), Color(tone, 0.7), 14, 12, 0.6))
	_glyph.texture = GemIconsRef.texture("skull" if is_down else "heart", GemIconsRef.baked_size(45.0))
	_glyph.modulate = tone
	_title.text = "You are down" if is_down else "Back on your feet"
	_title.add_theme_color_override("font_color", tone)
	_line.text = "The party carries you on. You get back on your feet at the next landing." if is_down else "The landing's air brings you round."

const GemIconsRef = preload("res://view/gems/gem_icons.gd")
