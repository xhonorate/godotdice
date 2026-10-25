extends Control
## Resonance as the rail builds it (docs/UI_REDO.md): the mark, the word and the number
## centred under the sockets. Grey at nothing, in its own lavender by five, and past that the
## number glows and runs through every color. From either side of the word, light reaches out
## along the rail as it grows, the whole rail by about twenty-five: a loose bundle of thin
## strands, each its own wavelength, pace and faintness, crossing and recrossing, colored
## along their length by the gems that rang (their colors blending into one another rather
## than standing in bands), with motes of the same light drifting off them. Each gem that adds
## to the count jolts the word and sends a brightening ripple outward. Past the end of the
## rail the strands climb and quicken and run through the rainbow, and the motes rise as
## flames.

const ScreenFx = preload("res://view/battle/screen_fx.gd")

const FULL_COLOR: int = 5
const FULL_REACH: int = 25
const GREY := Color("59658a")
## How many strands make the bundle, and how many of them are the bright threads.
const STRANDS: int = 18
const BRIGHT: int = 4

## The mark, the word and the number: what the screen anchors its flights and marks to.
var box: HBoxContainer
var icon: TextureRect
var word: Label
var number: Label
var value: int = 0
## What each color of gem rang this turn, by color key: the colors the light is made of.
var contributions: Dictionary = {}
var _goal_reach: float = 0.0
var _shown_reach: float = 0.0
var _clock: float = 0.0
var _jolt: float = 0.0
var _ripples: Array = []
var _strands: Array = []
var _motes: CPUParticles2D = null
var _palette_key: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(0, 24)
	mouse_filter = Control.MOUSE_FILTER_PASS
	## The strands add their light where they cross: the meter's own drawing is additive.
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(box)
	icon = DeepUi.icon(box, "resonance", 18, GREY)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The dock's own bold face for the word and the number, so they sit on one line with
	## the mark and read at a glance; the word spaced out a little.
	word = DeepUi.label(box, "RESONANCE", 13, GREY)
	var face := FontVariation.new()
	face.base_font = DeepUi.bold_font()
	face.spacing_glyph = 2
	word.add_theme_font_override("font", face)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The bigger face carries more room over its figures: lifted a little, so the figures
	## sit level with the word.
	var lift := MarginContainer.new()
	lift.add_theme_constant_override("margin_bottom", 4)
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(lift)
	number = DeepUi.label(lift, "0", 21, GREY)
	number.add_theme_font_override("font", DeepUi.bold_font())
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.resized.connect(_place_box)
	resized.connect(_place_box)
	## Each strand its own wavelength, pace, height and faintness, laid once so the bundle
	## keeps its character from frame to frame.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(STRANDS):
		var bright: bool = i < BRIGHT
		_strands.append({"f": rng.randf_range(0.025, 0.085), "phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(1.2, 3.2) * (1.0 if rng.randf() < 0.5 else -1.0),
			"amp": rng.randf_range(0.35, 1.0), "alpha": rng.randf_range(0.3, 0.6) if bright else rng.randf_range(0.07, 0.22),
			"width": rng.randf_range(0.9, 1.3) if bright else rng.randf_range(1.2, 2.2), "hue": rng.randf_range(-0.04, 0.04),
			"lift": rng.randf_range(0.25, 0.55) if bright else rng.randf_range(0.0, 0.2), "glow": i % 3 == 0})
	set_process(true)

func _place_box() -> void:
	box.reset_size()
	box.position = Vector2((size.x - box.size.x) * 0.5, (size.y - box.size.y) * 0.5).round()

func set_value(new_value: int, animate: bool = true) -> void:
	## The count as it stands. A rise jolts the word and sends a ripple out along the light.
	var was: int = value
	value = new_value
	number.text = DeepUi.number(value)
	_goal_reach = clampf(float(value) / float(FULL_REACH), 0.0, 1.0)
	_paint()
	if value > was and animate and not DeepUi.headless() and is_visible_in_tree():
		_jolt = 1.0
		_ripples.append({"at": _clock, "strength": clampf(float(value - was) / 4.0, 0.5, 1.2)})
		DeepUi.spring(box, 0.16, 3.0, 0.4)
		## A soft chime, a step higher with every point up to the end of the rail.
		DeepAudio.from(box, "resonance", {"volume": 0.28, "pitch": 1.0 + 0.035 * float(mini(value, FULL_REACH)), "gap": 0.04, "vary": 0.0})
	_place_box()
	queue_redraw()

func set_contributions(by_color: Dictionary) -> void:
	contributions = by_color
	_palette_key = ""
	queue_redraw()

func tone() -> Color:
	## Grey at nothing, the lavender by five.
	return GREY.lerp(DeepUi.RESONANCE, clampf(float(value) / float(FULL_COLOR), 0.0, 1.0))

func _paint() -> void:
	var t: Color = tone()
	icon.modulate = t
	word.add_theme_color_override("font_color", t)
	number.add_theme_color_override("font_color", t)

func _process(delta: float) -> void:
	_clock += delta
	var moving: bool = false
	if not is_equal_approx(_shown_reach, _goal_reach):
		var step: float = delta * (2.2 if _goal_reach > _shown_reach else 1.4)
		_shown_reach = move_toward(_shown_reach, _goal_reach, step)
		moving = true
	if _jolt > 0.0:
		_jolt = maxf(0.0, _jolt - delta * 2.5)
		moving = true
	var kept: Array = []
	for ripple in _ripples:
		if _clock - float(ripple.at) < 1.1:
			kept.append(ripple)
	_ripples = kept
	if value > FULL_COLOR and not DeepUi.headless():
		## Past five the mark, the word and the number run through every color together,
		## slowly, kept pale enough to read.
		var tone: Color = Color.from_hsv(fmod(_clock * 0.18, 1.0), 0.38, 1.0)
		number.add_theme_color_override("font_color", tone)
		word.add_theme_color_override("font_color", tone)
		icon.modulate = tone
	_drift()
	if moving or _shown_reach > 0.001 or not _ripples.is_empty() or value > FULL_COLOR:
		queue_redraw()

# --- the palette ---------------------------------------------------------------------------------

func _palette() -> Array:
	## [color, weight] for each color that rang, in a steady order, so the light is colored
	## along its length by what made it; the meter's own lavender when nothing is known.
	var out: Array = []
	var keys: Array = contributions.keys()
	keys.sort()
	for key in keys:
		var weight: float = maxf(0.0, float(contributions[key]))
		if weight <= 0.0:
			continue
		var color: Color = DeepUi.RESONANCE if DeepUi.is_rainbow(str(key)) else DeepUi.color(str(key))
		out.append([color.lightened(0.15), weight])
	if out.is_empty():
		out = [[DeepUi.RESONANCE, 1.0], [Color("c9a8ff"), 1.0]]
	elif out.size() == 1:
		## One color alone still breathes between itself and the lavender.
		out.append([DeepUi.RESONANCE.lerp(out[0][0], 0.4), float(out[0][1]) * 0.5])
	return out

func _palette_at(palette: Array, u: float, hue_shift: float) -> Color:
	## The color at `u` along the light, the palette's colors blending into one another.
	var total: float = 0.0
	for entry in palette:
		total += float(entry[1])
	var at: float = clampf(u, 0.0, 1.0) * total
	var run: float = 0.0
	var color: Color = palette[palette.size() - 1][0]
	for index in range(palette.size()):
		var span: float = float(palette[index][1])
		if at <= run + span or index == palette.size() - 1:
			var here: Color = palette[index][0]
			var next: Color = palette[mini(index + 1, palette.size() - 1)][0]
			var t: float = clampf((at - run) / maxf(0.001, span), 0.0, 1.0)
			## Blend across the second half of each color into the next.
			color = here.lerp(next, smoothstep(0.5, 1.0, t))
			break
		run += span
	if absf(hue_shift) > 0.0005:
		color = Color.from_hsv(fmod(color.h + hue_shift + 1.0, 1.0), color.s, color.v)
	return color

# --- the motes -----------------------------------------------------------------------------------

func _drift() -> void:
	## Motes of the light drifting off the strands, more of them and rising as flames past
	## the end of the rail. None for anyone who asked for fewer flashes.
	var on: bool = _shown_reach > 0.02 and is_visible_in_tree() and not DeepUi.headless() and not ScreenFx.calm
	if on and _motes == null:
		_motes = CPUParticles2D.new()
		_motes.texture = DeepUi.glow_texture()
		_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_motes.direction = Vector2.UP
		_motes.spread = 60.0
		_motes.scale_amount_min = 0.06
		_motes.scale_amount_max = 0.16
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.0))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		_motes.scale_amount_curve = curve
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_motes.material = additive
		add_child(_motes)
		move_child(_motes, 0)
	if _motes == null:
		return
	_motes.emitting = on
	if not on:
		return
	var over: float = maxf(0.0, float(value - FULL_REACH))
	var middle: float = size.y * 0.5
	var left_edge: float = box.position.x - 10.0
	var right_edge: float = box.position.x + box.size.x + 10.0
	var span_left: float = left_edge * _shown_reach
	var span_right: float = (size.x - right_edge) * _shown_reach
	var from: float = left_edge - span_left
	var to: float = right_edge + span_right
	_motes.position = Vector2((from + to) * 0.5, middle)
	_motes.emission_rect_extents = Vector2((to - from) * 0.5, 4.0)
	_motes.amount = int(14.0 + 40.0 * _shown_reach + minf(60.0, over * 3.0))
	_motes.lifetime = 1.6 if over <= 0.0 else 0.9
	_motes.initial_velocity_min = 4.0 + minf(50.0, over * 2.5)
	_motes.initial_velocity_max = 14.0 + minf(110.0, over * 5.0)
	_motes.gravity = Vector2(0, -8.0 - minf(70.0, over * 3.0))
	var key: String = "%s|%s" % [str(contributions), str(over > 0.0)]
	if key != _palette_key:
		_palette_key = key
		var ramp := Gradient.new()
		var palette: Array = _palette()
		ramp.set_color(0, Color(palette[0][0], 0.0))
		for index in range(palette.size()):
			var color: Color = palette[index][0]
			if over > 0.0:
				color = Color.from_hsv(float(index) / float(palette.size()), 0.55, 1.0)
			ramp.add_point(0.15 + 0.7 * float(index) / float(maxi(1, palette.size() - 1)) * 0.8, Color(color.lightened(0.2), 0.8))
		ramp.set_color(1, Color(palette[palette.size() - 1][0], 0.0))
		_motes.color_ramp = ramp

# --- the light ------------------------------------------------------------------------------------

func _draw() -> void:
	var middle: float = size.y * 0.5
	var over: float = maxf(0.0, float(value - FULL_REACH))
	if value > FULL_COLOR and not DeepUi.headless():
		## A glow behind the number, brighter the higher the count.
		var reach: float = 46.0 + minf(30.0, float(value - FULL_COLOR) * 1.5)
		var hue: float = fmod(_clock * 0.18, 1.0)
		var centre: Vector2 = number.position + box.position + number.size * 0.5
		draw_texture_rect(DeepUi.glow_texture(), Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(Color.from_hsv(hue, 0.5, 1.0), 0.18 + 0.06 * sin(_clock * 3.0)))
	if _shown_reach <= 0.001 and _ripples.is_empty():
		return
	var left_edge: float = box.position.x - 10.0
	var right_edge: float = box.position.x + box.size.x + 10.0
	var palette: Array = _palette()
	## Faint while the count is small, full by five; taller with the count, taller and
	## quicker still past the end of the rail, and lifted by the jolt of a gem adding to it.
	var vivid: float = 0.45 + 0.55 * clampf(float(value) / float(FULL_COLOR), 0.0, 1.0)
	var amplitude: float = (4.0 + 9.0 * _shown_reach + minf(8.0, over * 0.25)) * (1.0 + 0.6 * _jolt)
	var quicken: float = 1.0 + minf(1.6, over * 0.04)
	var drift: float = fmod(_clock * 0.08, 1.0) if over > 0.0 else 0.0
	for side in [-1.0, 1.0]:
		var start: float = left_edge if side < 0.0 else right_edge
		var room: float = start if side < 0.0 else size.x - start
		var span: float = room * _shown_reach
		if span < 4.0:
			continue
		## Eighteen strands over a short span pile into a white blob: a short bundle is fainter.
		var thin: float = clampf(span / 160.0, 0.3, 1.0)
		for strand in _strands:
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			var x: float = 0.0
			while x <= span:
				var u: float = x / span
				## Pinched where it leaves the word and where it ends, fullest between.
				var envelope: float = pow(sin(PI * u), 0.75) * 0.85 + 0.15 * (1.0 - u)
				var y: float = sin(x * float(strand.f) * quicken + float(strand.phase) + _clock * float(strand.speed) * quicken) * amplitude * float(strand.amp) * envelope
				y += sin(x * float(strand.f) * 0.37 + float(strand.phase) * 2.0 - _clock * float(strand.speed) * 0.6) * amplitude * 0.3 * float(strand.amp) * envelope
				var bright: float = 1.0
				for ripple in _ripples:
					var age: float = (_clock - float(ripple.at)) / 1.1
					var near: float = exp(-pow((u - age) * 5.0, 2.0))
					y += sin(x * float(strand.f) * 1.7 + float(strand.phase) * 1.3) * amplitude * float(ripple.strength) * near * (1.0 - age)
					bright += 1.6 * near * (1.0 - age)
				points.append(Vector2(start + side * x, middle + y))
				var color: Color = _palette_at(palette, u, drift + float(strand.hue)).lightened(float(strand.lift))
				colors.append(Color(color, float(strand.alpha) * vivid * thin * (0.35 + 0.65 * envelope) * bright))
				x += 3.0
			if points.size() < 2:
				continue
			if bool(strand.glow):
				var soft := PackedColorArray()
				for color in colors:
					soft.append(Color(color, color.a * 0.3))
				draw_polyline_colors(points, soft, float(strand.width) * 4.0, true)
			draw_polyline_colors(points, colors, float(strand.width), true)
