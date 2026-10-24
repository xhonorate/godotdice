extends Control
## Florin's hot streak, worn by the reader's own dice tray. The level is the reward High Roller
## earned last turn and he is riding now (DeepBattle's `streak`): embers rise off the tray for a
## Heating Up reroll, low flames run along it for a Hot Streak's bonus die, and when he is On
## Fire his dice burn and the screen's edges shimmer with heat. Each look builds on the one
## before, and a drop eases out over a second instead of cutting. A Jackpot strings bulbs round
## the tray and chases them; a Bust snuffs whatever was burning to smoke.
##
## It lies over the whole screen, follows the tray every frame and never takes the mouse. The heat
## is drawn in `shimmer_host` (the HUD), under the dock, so it bends the room and not the words.

const EMBER := Color("ff9a3c")
const FLAME := Color("ffb347")
const HOT := Color("ff5a1f")
const BULB := Color("ffe27a")
const BULB_DIM := Color(0.35, 0.28, 0.12, 0.9)
const SMOKE := Color(0.42, 0.42, 0.46)
const FADE_SECONDS := 1.0
const BULBS := 26
const BULB_SECONDS := 2.6

const HEAT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.42, 0.1, 1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float band = smoothstep(0.12, 0.0, edge);
	float wobble = sin(uv.y * 58.0 + TIME * 6.0) * 0.5 + sin(uv.x * 43.0 - TIME * 5.0) * 0.5;
	vec2 offset = vec2(wobble * 0.0045, wobble * 0.003) * band * strength;
	vec3 seen = texture(screen_texture, uv + offset).rgb;
	COLOR = vec4(seen + tint.rgb * 0.22 * band * strength, band * strength);
}
"""

## The tray it follows, and where each die in it sits: () -> Array of Rect2, global.
var follow: Control = null
var dice_rects: Callable = Callable()
## Where the heat shimmer is drawn: first in this control, so everything after it stays crisp.
var shimmer_host: Control = null
var level: int = 0

var _embers: CPUParticles2D
var _flames: CPUParticles2D
var _burning: Array = []
var _shimmer: ColorRect
var _shimmer_material: ShaderMaterial
var _bulb_started: int = -1
var _alphas: Dictionary = {"embers": 0.0, "flames": 0.0, "burning": 0.0, "shimmer": 0.0}
var _tweens: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DeepUi.headless():
		return
	_embers = _emitter(EMBER, 22, 1.9, 30.0, 70.0, 4.0, 7.0)
	_flames = _emitter(FLAME, 60, 0.6, 30.0, 80.0, 12.0, 22.0)
	_flames.color_ramp = _ramp([Color("fff1a8"), FLAME, HOT, Color(HOT, 0.0)])
	_shimmer = ColorRect.new()
	_shimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = HEAT_SHADER
	_shimmer_material = ShaderMaterial.new()
	_shimmer_material.shader = shader
	_shimmer_material.set_shader_parameter("strength", 0.0)
	_shimmer.material = _shimmer_material
	_shimmer.visible = false
	if shimmer_host != null and is_instance_valid(shimmer_host):
		shimmer_host.add_child(_shimmer)
		shimmer_host.move_child(_shimmer, 0)
	else:
		add_child(_shimmer)
	_apply_alphas()

func _emitter(tone: Color, amount: int, life: float, slow: float, fast: float, small: float, big: float) -> CPUParticles2D:
	var fire := CPUParticles2D.new()
	fire.amount = amount
	fire.lifetime = life
	fire.texture = DeepUi.glow_texture()
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(120, 3)
	fire.direction = Vector2.UP
	fire.spread = 18.0
	fire.initial_velocity_min = slow
	fire.initial_velocity_max = fast
	fire.gravity = Vector2(0, -16)
	fire.damping_min = 4.0
	fire.damping_max = 12.0
	fire.scale_amount_min = small / 128.0
	fire.scale_amount_max = big / 128.0
	fire.color_ramp = _ramp([Color(tone.lightened(0.4), 1.0), tone, Color(tone, 0.0)])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fire.material = add
	fire.emitting = false
	add_child(fire)
	return fire

func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, colors[0])
	gradient.set_color(1, colors[colors.size() - 1])
	for index in range(1, colors.size() - 1):
		gradient.add_point(float(index) / float(colors.size() - 1), colors[index])
	return gradient

# --- the level ------------------------------------------------------------------------------

func set_level(next: int) -> void:
	## Embers from Heating Up (1), flames from a Hot Streak (2), burning dice and heat from On
	## Fire (3). Going up lights the new look at once; going down lets the old one burn out.
	next = clampi(next, 0, 3)
	if next == level:
		return
	var rising: bool = next > level
	level = next
	_ease("embers", 1.0 if level >= 1 else 0.0, 0.35 if rising else FADE_SECONDS)
	_ease("flames", 1.0 if level >= 2 else 0.0, 0.35 if rising else FADE_SECONDS)
	_ease("burning", 1.0 if level >= 3 else 0.0, 0.35 if rising else FADE_SECONDS)
	_ease("shimmer", 0.7 if level >= 3 else 0.0, 0.6 if rising else FADE_SECONDS)

func _ease(key: String, to: float, seconds: float) -> void:
	if DeepUi.headless() or not is_inside_tree():
		_alphas[key] = to
		_apply_alphas()
		return
	var running: Variant = _tweens.get(key, null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		_alphas[key] = value
		_apply_alphas(), float(_alphas[key]), to, seconds).set_trans(Tween.TRANS_SINE)
	_tweens[key] = tween

func _apply_alphas() -> void:
	if _embers == null:
		return
	_embers.modulate.a = float(_alphas.embers)
	_embers.emitting = float(_alphas.embers) > 0.02 and level >= 1
	_flames.modulate.a = float(_alphas.flames)
	_flames.emitting = float(_alphas.flames) > 0.02 and level >= 2
	for fire in _burning:
		if is_instance_valid(fire):
			(fire as CPUParticles2D).modulate.a = float(_alphas.burning)
			(fire as CPUParticles2D).emitting = float(_alphas.burning) > 0.02 and level >= 3
	_shimmer.visible = float(_alphas.shimmer) > 0.01
	_shimmer_material.set_shader_parameter("strength", float(_alphas.shimmer))

# --- the moments ----------------------------------------------------------------------------

func jackpot() -> void:
	## The slot machine pays: bulbs strung round the tray light up and chase.
	if DeepUi.headless():
		return
	_bulb_started = Time.get_ticks_msec()
	queue_redraw()

func snuff() -> void:
	## A Bust: whatever was burning goes out in a puff of smoke.
	if DeepUi.headless() or follow == null or not is_instance_valid(follow):
		return
	var area: Rect2 = _local(follow.get_global_rect())
	var smoke := CPUParticles2D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.amount = 36
	smoke.lifetime = 1.4
	smoke.texture = DeepUi.glow_texture()
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(area.size.x * 0.5, area.size.y * 0.25)
	smoke.direction = Vector2.UP
	smoke.spread = 30.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 60.0
	smoke.gravity = Vector2(0, -30)
	smoke.scale_amount_min = 18.0 / 128.0
	smoke.scale_amount_max = 34.0 / 128.0
	smoke.color_ramp = _ramp([Color(SMOKE, 0.0), Color(SMOKE, 0.6), Color(SMOKE.darkened(0.3), 0.0)])
	smoke.position = area.get_center()
	add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	## `finished` never comes while this layer is hidden (the dock turned to another page),
	## so a clock frees the puff as well.
	if is_inside_tree():
		get_tree().create_timer(smoke.lifetime + 1.0, false).timeout.connect(smoke.queue_free)
	## The fire is out at once, not over the usual second.
	level = 0
	for key in ["embers", "flames", "burning", "shimmer"]:
		_ease(key, 0.0, 0.25)

# --- following the tray ---------------------------------------------------------------------

func _local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - global_position, rect.size)

func _exit_tree() -> void:
	if _shimmer != null and is_instance_valid(_shimmer) and _shimmer.get_parent() != self:
		_shimmer.queue_free()

func _process(_delta: float) -> void:
	if _embers == null:
		return
	var shown: bool = follow != null and is_instance_valid(follow) and follow.is_visible_in_tree()
	visible = shown
	if _shimmer.get_parent() != self:
		_shimmer.visible = shown and float(_alphas.shimmer) > 0.01
	if not shown:
		return
	var area: Rect2 = _local(follow.get_global_rect())
	var floor_at := Vector2(area.get_center().x, area.end.y - 6.0)
	_embers.position = floor_at
	_embers.emission_rect_extents = Vector2(area.size.x * 0.5 + 10.0, 3.0)
	_flames.position = floor_at + Vector2(0, 4)
	_flames.emission_rect_extents = Vector2(area.size.x * 0.5 + 6.0, 2.0)
	if level >= 3 or float(_alphas.burning) > 0.02:
		_place_burning()
	if _bulb_started >= 0:
		queue_redraw()

func _place_burning() -> void:
	## One small fire under every die in the tray, kept to as many as there are dice.
	var rects: Array = dice_rects.call() if dice_rects.is_valid() else []
	while _burning.size() < rects.size():
		var fire := _emitter(HOT, 20, 0.5, 25.0, 60.0, 10.0, 18.0)
		fire.color_ramp = _ramp([Color("fff1a8"), FLAME, HOT, Color(HOT, 0.0)])
		_burning.append(fire)
	while _burning.size() > rects.size():
		var gone: Variant = _burning.pop_back()
		if is_instance_valid(gone):
			(gone as Node).queue_free()
	for index in range(rects.size()):
		var at: Rect2 = _local(rects[index])
		var fire: CPUParticles2D = _burning[index]
		fire.position = Vector2(at.get_center().x, at.end.y - 4.0)
		fire.emission_rect_extents = Vector2(at.size.x * 0.38, 2.0)
	_apply_alphas()

func _draw() -> void:
	if _bulb_started < 0 or follow == null or not is_instance_valid(follow):
		return
	var elapsed: float = float(Time.get_ticks_msec() - _bulb_started) / 1000.0
	if elapsed > BULB_SECONDS:
		_bulb_started = -1
		return
	var area: Rect2 = _local(follow.get_global_rect()).grow(14.0)
	var perimeter: float = 2.0 * (area.size.x + area.size.y)
	var fade: float = clampf((BULB_SECONDS - elapsed) / 0.4, 0.0, 1.0)
	var step: int = int(elapsed * 14.0)
	for index in range(BULBS):
		var along: float = perimeter * float(index) / float(BULBS)
		var spot: Vector2
		if along < area.size.x:
			spot = area.position + Vector2(along, 0)
		elif along < area.size.x + area.size.y:
			spot = area.position + Vector2(area.size.x, along - area.size.x)
		elif along < 2.0 * area.size.x + area.size.y:
			spot = area.position + Vector2(area.size.x - (along - area.size.x - area.size.y), area.size.y)
		else:
			spot = area.position + Vector2(0, area.size.y - (along - 2.0 * area.size.x - area.size.y))
		var lit: bool = (index + step) % 3 == 0
		var tone: Color = BULB if lit else BULB_DIM
		if lit:
			draw_circle(spot, 9.0, Color(BULB, 0.22 * fade))
		draw_circle(spot, 4.5, Color(tone, tone.a * fade))
