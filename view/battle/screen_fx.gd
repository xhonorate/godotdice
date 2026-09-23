extends ColorRect
## One full-screen pass over the chamber: a vignette tinted by the biome, chromatic fringes
## and a radial blur that kick on heavy blows, a red rim when the party is hurt or close to
## death, color flashes, a grey wash when the fight is lost, and a little grain so flat
## low-poly shading never looks like plastic. The HUD sits above this and is never touched.

var vignette: float = 0.45
var vignette_color: Color = Color(0, 0, 0)
var aberration: float = 0.0
var zoom_blur: float = 0.0
var hurt: float = 0.0
var danger: float = 0.0
var flash: float = 0.0
var flash_color: Color = Color.WHITE
var desaturate: float = 0.0
var grain: float = 0.035
## Fewer flashes: set from the settings menu, it softens every flash and smear.
static var calm: bool = false
var _clock: float = 0.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.45;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float aberration = 0.0;
uniform float zoom_blur = 0.0;
uniform float hurt = 0.0;
uniform float danger = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float desaturate = 0.0;
uniform float grain = 0.03;
uniform float clock = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 local = UV - 0.5;
	float d = length(local * vec2(1.0, 0.8));
	vec2 toward = (uv - vec2(0.5)) ;
	vec3 col;
	if (zoom_blur > 0.001) {
		col = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float s = 1.0 - zoom_blur * float(i) / 8.0 * 0.12;
			col += texture(screen, vec2(0.5) + toward * s).rgb;
		}
		col /= 8.0;
	} else {
		col = texture(screen, uv).rgb;
	}
	if (aberration > 0.001) {
		float ab = aberration * d * 0.02;
		col.r = mix(col.r, texture(screen, uv - toward * ab).r, 0.9);
		col.b = mix(col.b, texture(screen, uv + toward * ab).b, 0.9);
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.95, 0.97, 1.05), desaturate);
	float v = smoothstep(0.32, 0.9, d);
	col = mix(col, vignette_color.rgb, v * vignette);
	float pulse = 0.65 + 0.35 * sin(clock * 5.0);
	col = mix(col, vec3(0.55, 0.02, 0.04), v * clamp(hurt + danger * pulse * 0.6, 0.0, 1.0));
	col += flash_color.rgb * flash;
	col += (hash(UV * 900.0 + fract(clock) * 37.0) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	material = m

func _process(delta: float) -> void:
	_clock += delta
	## Kicks decay on their own; the steady values are set by whoever owns the screen.
	aberration = move_toward(aberration, 0.0, delta * 2.5)
	zoom_blur = move_toward(zoom_blur, 0.0, delta * 3.0)
	hurt = move_toward(hurt, 0.0, delta * 1.4)
	flash = move_toward(flash, 0.0, delta * 3.2)
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("vignette", vignette)
	m.set_shader_parameter("vignette_color", vignette_color)
	m.set_shader_parameter("aberration", aberration)
	m.set_shader_parameter("zoom_blur", zoom_blur)
	m.set_shader_parameter("hurt", hurt)
	m.set_shader_parameter("danger", danger)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("flash_color", flash_color)
	m.set_shader_parameter("desaturate", desaturate)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("clock", _clock)

func kick(strength: float) -> void:
	## A heavy blow: color splits and the frame smears toward the middle.
	strength *= 0.3 if calm else 1.0
	aberration = maxf(aberration, 2.0 * strength)
	zoom_blur = maxf(zoom_blur, 0.9 * strength)

func blink(color: Color, strength: float = 0.35) -> void:
	flash_color = color
	flash = maxf(flash, strength * (0.3 if calm else 1.0))

func wound(strength: float = 0.6) -> void:
	hurt = maxf(hurt, strength)
