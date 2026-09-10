extends Control
## The animated stage behind every screen: a graded cavern wash, a soft key glow
## behind the action, drifting motes and a vignette. The palette shifts per act and
## per room kind so each place in the run reads differently.

const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.05, 0.07, 0.11, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 accent_color : source_color = vec4(0.9, 0.7, 0.4, 1.0);
uniform float clock = 0.0;
uniform float intensity = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	float d = distance(uv * vec2(1.0, 0.72), vec2(0.5, 0.24));
	col += accent_color.rgb * exp(-d * d * 6.0) * 0.34 * intensity;
	float strata = sin((uv.x * 2.2 - uv.y * 3.4) * 6.2831 + clock * 0.12);
	col += accent_color.rgb * 0.014 * intensity * strata;
	float beam = smoothstep(0.35, 0.0, abs(fract(uv.x * 1.5 - clock * 0.008) - 0.5));
	col += accent_color.rgb * beam * 0.020 * intensity * (1.0 - uv.y);
	float vignette = smoothstep(1.25, 0.30, distance(uv, vec2(0.5, 0.48)));
	col *= mix(0.44, 1.0, vignette);
	col += (hash(uv * vec2(1731.0, 977.0)) - 0.5) * 0.014;
	COLOR = vec4(col, 1.0);
}
"""

const THEMES := {
	"menu": {"top": "141d33", "bottom": "070a12", "accent": "e8b661"},
	"battle": {"top": "1a1526", "bottom": "07060e", "accent": "ff7a6b"},
	"elite": {"top": "22142a", "bottom": "0a0610", "accent": "ff9d5c"},
	"boss": {"top": "2a1030", "bottom": "0c0414", "accent": "b98bff"},
	"route": {"top": "101d2c", "bottom": "060a12", "accent": "76b6ff"},
	"shop": {"top": "241d12", "bottom": "0b0806", "accent": "e8b661"},
	"rest": {"top": "1d1a12", "bottom": "090705", "accent": "ff9d5c"},
	"event": {"top": "191233", "bottom": "070516", "accent": "b98bff"},
	"mine": {"top": "10251f", "bottom": "050d0a", "accent": "6fe3b0"},
	"workshop": {"top": "1b2029", "bottom": "070a0e", "accent": "b9c6d6"},
	"lapidary": {"top": "0f2530", "bottom": "050e12", "accent": "63d8d0"},
	"summary": {"top": "151c2c", "bottom": "070a12", "accent": "e8b661"}
}

static var _shader: Shader

var reduced_motion := false

var _wash: ColorRect
var _material: ShaderMaterial
var _motes: Control
var _clock := 0.0
var _seeds: Array[Vector3] = []

static func release() -> void:
	_shader = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BACKDROP_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_wash = ColorRect.new()
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.material = _material
	add_child(_wash)
	_motes = Control.new()
	_motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.draw.connect(_draw_motes.bind(_motes))
	add_child(_motes)
	for i in 46:
		_seeds.append(Vector3(randf(), randf(), randf_range(0.25, 1.0)))
	apply_theme("menu")

func apply_theme(kind: String) -> void:
	var theme_key := kind if THEMES.has(kind) else "menu"
	var chosen: Dictionary = THEMES[theme_key]
	_material.set_shader_parameter("top_color", Color(chosen.top))
	_material.set_shader_parameter("bottom_color", Color(chosen.bottom))
	_material.set_shader_parameter("accent_color", Color(chosen.accent))
	_material.set_shader_parameter("intensity", 1.0)

func accent_of(kind: String) -> Color:
	return Color(THEMES.get(kind, THEMES.menu).accent)

func _process(delta: float) -> void:
	if reduced_motion:
		return
	_clock += delta
	_material.set_shader_parameter("clock", _clock)
	if is_instance_valid(_motes):
		_motes.queue_redraw()

func _draw_motes(target: Control) -> void:
	var view := target.size
	if view.x <= 1.0 or view.y <= 1.0:
		return
	var accent: Color = _material.get_shader_parameter("accent_color")
	for seed_value in _seeds:
		var drift := 0.0 if reduced_motion else _clock * (0.006 + seed_value.z * 0.012)
		var x := fposmod(seed_value.x + drift * 0.35, 1.0) * view.x
		var y := fposmod(seed_value.y - drift, 1.0) * view.y
		var twinkle := 0.35 + 0.35 * sin(_clock * (0.9 + seed_value.z) + seed_value.x * 12.0)
		target.draw_circle(Vector2(x, y), 0.8 + seed_value.z * 1.7, Color(accent, twinkle * 0.22 * seed_value.z))
