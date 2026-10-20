extends Control
## The Hollow's rite, played over the room for whoever fed it. The room goes dark and the hole
## opens; the gem lifts off the rail and hangs over it; the die lifts out of the tray, falls
## and spirals down into the dark; far below it lands, and the dark comes back up through the
## gem and leaves it Void, ringed in broken blue. Then the hole shuts and the gem floats down
## to ride its socket on the rail. A click anywhere hurries it to the end.
##
## Everything is drawn from one clock, so hurrying it is only jumping the clock: the gem still
## lands, and whatever was waiting on it is still told.

const Thumbs = preload("res://view/gems/thumbs.gd")

## "impact" (the die hits bottom), "void" (the gem turns), "landed" (it is on the rail).
signal beat(name: String)
signal done

## When each part happens, in seconds from the start.
const OPEN := 0.5
const LIFT := Vector2(0.15, 1.0)
const DROP := Vector2(0.85, 1.95)
const IMPACT := 1.95
const TURN := 2.15
const CLOSE := Vector2(3.35, 3.75)
const FLIGHT := Vector2(3.6, 4.45)
## Long enough after the landing for its sparks to die out; the room is in reach by then.
const LENGTH := 5.2

const GEM_EDGE := 128.0
const DIE_EDGE := 64.0
const HOLE := 128.0
const VOID_BLUE := Color("76b6ff")
const VOID_VIOLET := Color("8a5cff")
const CORE := Color("04020a")

var stone: Dictionary = {}
var die: Dictionary = {}
## Where the gem and the die stood in the dock, on the screen, and how big they were drawn there.
var gem_from: Vector2 = Vector2.INF
var die_from: Vector2 = Vector2.INF
var gem_from_edge: float = 46.0
var die_from_edge: float = 58.0
var land_edge: float = 14.0
## Where the gem lands, asked once it sets off: the rail is drawn again in the meantime.
var target: Callable = Callable()

var _t: float = 0.0
var _said: Dictionary = {}
var _centre: Vector2 = Vector2.ZERO
var _hang: Vector2 = Vector2.ZERO
var _land: Vector2 = Vector2.INF
var _gem_before: Control
var _gem_after: Control
var _die: Control
var _title: Label
var _line: Label
var _cost: Label
var _trail: Array = []
var _motes: Array = []
var _rng := RandomNumberGenerator.new()
var _over: bool = false

func play(void_stone: Dictionary, fed: Dictionary, gem_at: Vector2, die_at: Vector2, landing: Callable) -> void:
	stone = void_stone
	die = fed
	gem_from = gem_at
	die_from = die_at
	target = landing

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10
	_rng.seed = hash(str(stone.get("id", "")))
	## The gem as it was, and as it comes away: the second wears the rider's broken ring.
	var before: Dictionary = stone.duplicate(true)
	before.erase("voided")
	_gem_before = _thumb(Thumbs.GemThumb.new(before, GEM_EDGE), GEM_EDGE)
	_gem_after = _thumb(Thumbs.GemThumb.new(stone, GEM_EDGE), GEM_EDGE)
	_gem_after.modulate.a = 0.0
	_die = _thumb(Thumbs.DieThumb.new(die, DIE_EDGE), DIE_EDGE)
	_title = _words("VOID", 84, VOID_BLUE.lightened(0.15))
	_line = _words("%s takes no socket until the run ends" % str(DeepStone.skill_of(stone).get("name", "Your gem")), 22, DeepUi.PAPER)
	_cost = _words("Gone until the run ends: %s" % DeepDice.describe(die), 16, DeepUi.BAD.lightened(0.15))
	for _i in range(46):
		_motes.append(_new_mote(true))
	_layout()
	## Everything in its first place before the first frame is drawn, or the gem and the die
	## flash up in the corner for a frame.
	_process(0.0)

func _thumb(control: Control, edge: float) -> Control:
	if control.get("live_on_hover") != null:
		control.set("live_on_hover", false)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size = Vector2(edge, edge)
	control.pivot_offset = Vector2(edge, edge) * 0.5
	control.z_index = 2
	add_child(control)
	return control

func _words(text: String, font_size: int, tone: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", DeepUi.title_font(font_size))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", tone)
	l.add_theme_color_override("font_outline_color", Color(CORE, 0.95))
	l.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	l.z_index = 3
	add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size * 0.5
	return l

func _new_mote(anywhere: bool) -> Dictionary:
	return {"angle": _rng.randf() * TAU, "reach": _rng.randf_range(1.3, 2.9) if anywhere else _rng.randf_range(2.4, 2.9),
		"speed": _rng.randf_range(0.5, 1.1), "size": _rng.randf_range(1.2, 3.0), "blue": _rng.randf() < 0.35}

func _layout() -> void:
	_centre = Vector2(size.x * 0.5, size.y * 0.53)
	_hang = _centre - Vector2(0, HOLE * 1.5)

func _gui_input(event: InputEvent) -> void:
	## Any click hurries it to the end; the gem still lands where it was going.
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		finish()

func finish() -> void:
	if _over:
		return
	_once("landed", func() -> void: beat.emit("landed"))
	_over = true
	done.emit()
	queue_free()

func _once(key: String, action: Callable) -> void:
	if _said.has(key):
		return
	_said[key] = true
	action.call()

static func _span(t: float, from: float, to: float) -> float:
	return clampf((t - from) / maxf(0.0001, to - from), 0.0, 1.0)

static func _out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

static func _in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

static func _back(x: float) -> float:
	## Over and settling back, for things that arrive with a kick.
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

static func _bend(a: Vector2, b: Vector2, via: Vector2, x: float) -> Vector2:
	return a.lerp(via, x).lerp(via.lerp(b, x), x)

func _place(control: Control, at: Vector2, scale_by: float, turn: float = 0.0) -> void:
	control.position = at - control.size * 0.5
	control.scale = Vector2.ONE * maxf(0.001, scale_by)
	control.rotation = turn

func _hole_radius() -> float:
	var r: float = HOLE * _out(_span(_t, 0.0, OPEN))
	## The blow from below swells it, and it draws in before it shuts.
	r *= 1.0 + 0.28 * (1.0 - _span(_t, IMPACT, IMPACT + 0.5)) * float(_t >= IMPACT)
	r *= 1.0 - 0.12 * _span(_t, TURN + 0.4, CLOSE.x)
	return r * (1.0 - pow(_span(_t, CLOSE.x, CLOSE.y), 2.0))

func _process(delta: float) -> void:
	if _over:
		return
	_t += delta
	_layout()
	_sounds()
	var hole: float = _hole_radius()
	## The gem: off the rail, up over the hole, turned, and down to the rail again.
	var lift: float = _in_out(_span(_t, LIFT.x, LIFT.y))
	var from: Vector2 = gem_from - global_position if gem_from != Vector2.INF else _centre + Vector2(0, size.y * 0.45)
	var start_scale: float = gem_from_edge / GEM_EDGE
	var at: Vector2 = _bend(from, _hang, Vector2(lerpf(from.x, _hang.x, 0.3), _hang.y - 40.0), lift)
	var grow: float = lerpf(start_scale, 1.0, lift)
	if _t >= LIFT.y:
		at.y += sin((_t - LIFT.y) * 2.6) * 5.0
	## Turned: a kick as the dark goes through it.
	var kick: float = _span(_t, TURN, TURN + 0.55)
	if _t >= TURN:
		grow *= lerpf(1.45, 1.0, _back(kick)) if kick < 1.0 else 1.0
	var flight: float = _in_out(_span(_t, FLIGHT.x, FLIGHT.y))
	if _t >= FLIGHT.x:
		if _land == Vector2.INF:
			_land = _landing()
		var via := Vector2(lerpf(at.x, _land.x, 0.5) + 60.0, minf(at.y, _land.y) - 90.0)
		at = _bend(at, _land, via, flight)
		grow = lerpf(1.0, land_edge / GEM_EDGE, pow(flight, 0.8))
	var turned: float = _span(_t, TURN, TURN + 0.18)
	var shown: float = _span(_t, 0.0, 0.12) * (1.0 - _span(_t, FLIGHT.y - 0.04, FLIGHT.y + 0.06))
	_gem_before.modulate = Color(1, 1, 1, shown * (1.0 - turned))
	## The dark going through it: the gem goes violet just before it turns.
	var dim: float = _span(_t, TURN - 0.25, TURN) * (1.0 - turned)
	_gem_before.self_modulate = Color.WHITE.lerp(VOID_VIOLET.darkened(0.3), dim * 0.8)
	_gem_after.modulate = Color(1, 1, 1, shown * turned)
	var sway: float = sin(_t * 1.7) * 0.06 * float(_t >= LIFT.y and _t < FLIGHT.x) + flight * TAU * 0.5
	_place(_gem_before, at, grow, sway)
	_place(_gem_after, at, grow, sway)
	## The die: lifted from the tray, tossed out over the hole, and spiralling down into it.
	var dfrom: Vector2 = die_from - global_position if die_from != Vector2.INF else _centre + Vector2(0, size.y * 0.42)
	var toss := _span(_t, DROP.x, DROP.x + 0.5)
	var brink: Vector2 = _centre + Vector2(-HOLE * 1.55, -HOLE * 0.55)
	var die_at: Vector2 = dfrom
	var die_scale: float = die_from_edge / DIE_EDGE
	var die_turn: float = 0.0
	if _t >= DROP.x:
		die_at = _bend(dfrom, brink, Vector2(lerpf(dfrom.x, brink.x, 0.5), brink.y - 120.0), _out(toss))
		die_scale = lerpf(die_from_edge / DIE_EDGE, 1.25, _out(toss))
		die_turn = _out(toss) * TAU * 0.75
	if _t >= DROP.x + 0.5:
		var fall: float = _span(_t, DROP.x + 0.5, DROP.y)
		var off: Vector2 = brink - _centre
		var angle: float = off.angle() + pow(fall, 1.4) * TAU * 1.6
		die_at = _centre + Vector2.from_angle(angle) * off.length() * (1.0 - pow(fall, 1.3))
		die_scale = 1.25 * (1.0 - pow(fall, 1.6))
		die_turn = TAU * 0.75 + pow(fall, 2.0) * TAU * 5.0
	_die.modulate.a = 1.0 - _span(_t, DROP.y - 0.06, DROP.y)
	_die.self_modulate = Color.WHITE.lerp(VOID_VIOLET, _span(_t, DROP.x + 0.5, DROP.y) * 0.7)
	_place(_die, die_at, die_scale, die_turn)
	if _t >= DROP.x and _t < DROP.y:
		_trail.push_front(die_at)
		if _trail.size() > 14:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	if _t >= IMPACT:
		_once("impact", func() -> void:
			beat.emit("impact")
			DeepUi.burst(self, _centre, VOID_VIOLET, 46, 420.0, 0.9, 7.0)
			DeepUi.burst(self, _centre, VOID_BLUE, 24, 300.0, 0.7, 5.0))
	if _t >= TURN:
		_once("void", func() -> void:
			beat.emit("void")
			DeepUi.burst(self, _hang, VOID_BLUE, 40, 360.0, 0.9, 6.0)
			DeepUi.burst(self, _hang, Color.WHITE, 18, 240.0, 0.6, 4.0))
	## The words: VOID stamped over the gem, what it means under the hole.
	var stamp: float = _span(_t, TURN + 0.12, TURN + 0.45)
	var words_out: float = 1.0 - _span(_t, FLIGHT.x - 0.1, FLIGHT.x + 0.3)
	_title.modulate.a = minf(1.0, stamp * 3.0) * words_out
	_title.scale = Vector2.ONE * lerpf(2.4, 1.0, _back(stamp)) if stamp < 1.0 else Vector2.ONE
	_title.position = Vector2(_centre.x, _hang.y - GEM_EDGE * 0.95) - _title.size * 0.5
	var read: float = _span(_t, TURN + 0.4, TURN + 0.7)
	_line.modulate.a = read * words_out
	_line.position = Vector2(_centre.x, _centre.y + HOLE + 34.0) - _line.size * 0.5 + Vector2(0, (1.0 - read) * 12.0)
	_cost.modulate.a = _span(_t, TURN + 0.6, TURN + 0.9) * words_out
	_cost.position = Vector2(_centre.x, _centre.y + HOLE + 70.0) - _cost.size * 0.5
	if _t >= FLIGHT.y:
		_once("landed", func() -> void:
			beat.emit("landed")
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _land != Vector2.INF:
				DeepUi.burst(self, _land, VOID_BLUE, 30, 220.0, 0.7, 5.0)
				DeepUi.burst(self, _land, Color.WHITE, 10, 140.0, 0.5, 3.0)
				## Said over the socket, on the room rather than on this, which is nearly gone.
				var room: Control = get_parent() as Control
				if room != null:
					DeepUi.float_text(room, _land + position - Vector2(0, 44), "Void", VOID_BLUE.lightened(0.2), 24, 40.0, 1.2))
	## The motes drawn down into the hole.
	for mote in _motes:
		mote.reach = float(mote.reach) - delta * float(mote.speed) * (1.6 if _t >= IMPACT and _t < TURN + 0.4 else 0.9)
		mote.angle = float(mote.angle) + delta * float(mote.speed) * 2.2 / maxf(0.35, float(mote.reach))
		if float(mote.reach) < 0.45:
			mote.merge(_new_mote(false), true)
	queue_redraw()
	if _t >= LENGTH:
		_over = true
		done.emit()
		queue_free()

func _landing() -> Vector2:
	var spot: Vector2 = target.call() if target.is_valid() else Vector2.INF
	if spot == Vector2.INF:
		return _centre + Vector2(0, size.y * 0.45)
	return spot - global_position

func _sounds() -> void:
	if _t >= 0.0:
		_once("s_open", func() -> void:
			DeepAudio.play("cave_rumble", {"volume": 0.55})
			DeepAudio.play("altar_hum", {"volume": 0.6}))
	if _t >= LIFT.x:
		_once("s_lift", func() -> void: DeepAudio.play("gleam", {"volume": 0.55}))
	if _t >= DROP.x:
		## The drop's own blow lands 1.1 seconds in, which is when the die reaches the bottom.
		_once("s_drop", func() -> void: DeepAudio.play("hollow_drop", {"volume": 0.95}))
	if _t >= TURN - 0.12:
		_once("s_rise", func() -> void: DeepAudio.play("hollow_rise", {"volume": 0.95}))
	if _t >= FLIGHT.x:
		_once("s_fly", func() -> void: DeepAudio.play("ui_open", {"volume": 0.6}))
	if _t >= FLIGHT.y:
		_once("s_land", func() -> void:
			DeepAudio.play("keep", {"volume": 0.7})
			DeepAudio.play("gem_blue", {"volume": 0.7}))

func _draw() -> void:
	var glow: Texture2D = DeepUi.glow_texture()
	## The room goes dark, and comes back as the gem goes down to the rail.
	var dark: float = _out(_span(_t, 0.0, 0.45)) * (1.0 - _in_out(_span(_t, FLIGHT.x, FLIGHT.y - 0.1)))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.008, 0.035, 0.76 * dark))
	## A flash as the die lands far below.
	var flash: float = (1.0 - _span(_t, IMPACT, IMPACT + 0.28)) * float(_t >= IMPACT)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(VOID_VIOLET.lightened(0.5), 0.32 * flash))
	var hole: float = _hole_radius()
	if hole > 1.0:
		var churn: float = _t * (1.2 + 2.2 * float(_t >= IMPACT and _t < TURN + 0.6))
		var halo: float = hole * (4.2 + 1.4 * flash)
		draw_texture_rect(glow, Rect2(_centre - Vector2(halo, halo) * 0.5, Vector2(halo, halo)), false, Color(VOID_VIOLET, 0.55 + 0.35 * flash))
		## Arms of the whirl, bright at their tips and lost in the dark at the middle.
		for arm in range(6):
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for step in range(26):
				var along: float = float(step) / 25.0
				var radius: float = hole * lerpf(0.42, 1.55, along)
				var angle: float = churn + TAU * float(arm) / 6.0 + (1.0 - along) * 2.4
				points.append(_centre + Vector2.from_angle(angle) * radius)
				var tone: Color = VOID_VIOLET.lerp(VOID_BLUE, along)
				colors.append(Color(tone.lightened(0.2), 0.85 * sin(along * PI)))
			draw_polyline_colors(points, colors, 3.0, true)
		draw_circle(_centre, hole * 0.62, CORE)
		draw_arc(_centre, hole * 0.62, 0.0, TAU, 64, Color(VOID_VIOLET.lightened(0.35), 0.95), 3.0, true)
		draw_arc(_centre, hole * 0.7, churn * 0.5, churn * 0.5 + TAU * 0.7, 48, Color(VOID_BLUE, 0.5), 1.5, true)
		for mote in _motes:
			var reach: float = float(mote.reach)
			var spot: Vector2 = _centre + Vector2.from_angle(float(mote.angle)) * hole * reach
			var fade: float = clampf((reach - 0.45) / 0.6, 0.0, 1.0) * clampf((3.0 - reach) / 0.6, 0.0, 1.0)
			draw_circle(spot, float(mote.size), Color(VOID_BLUE if bool(mote.blue) else VOID_VIOLET.lightened(0.3), 0.8 * fade))
	## The die's trail as it goes round and down.
	for index in range(_trail.size()):
		var fade: float = 1.0 - float(index) / float(maxi(1, _trail.size()))
		draw_circle(_trail[index], 7.0 * fade, Color(VOID_VIOLET.lightened(0.3), 0.45 * fade))
	## Shockwaves off the blow at the bottom.
	for ring in [[0.0, VOID_VIOLET, 760.0], [0.14, VOID_BLUE, 560.0]]:
		var wave: float = _span(_t, IMPACT + float(ring[0]), IMPACT + float(ring[0]) + 0.75)
		if _t >= IMPACT + float(ring[0]) and wave < 1.0:
			draw_arc(_centre, lerpf(HOLE * 0.6, float(ring[2]), _out(wave)), 0.0, TAU, 96, Color((ring[1] as Color).lightened(0.3), 1.0 - wave), lerpf(9.0, 1.0, wave), true)
	## The dark coming back up, through the gem.
	var column: float = _span(_t, IMPACT + 0.05, TURN) * (1.0 - _span(_t, TURN, TURN + 0.5))
	if column > 0.0 and hole > 1.0:
		var width: float = 70.0 * column
		var top: float = _hang.y - GEM_EDGE * 0.3
		draw_texture_rect(glow, Rect2(Vector2(_centre.x - width, top), Vector2(width * 2.0, _centre.y - top)), false, Color(VOID_VIOLET.lightened(0.25), 0.85 * column))
		draw_rect(Rect2(Vector2(_centre.x - width * 0.12, top), Vector2(width * 0.24, _centre.y - top)), Color(1, 1, 1, 0.55 * column))
	## Landed: two rings of the rider's blue go out from its place on the rail.
	if _t >= FLIGHT.y and _land != Vector2.INF:
		for echo in [0.0, 0.12]:
			var out: float = _span(_t, FLIGHT.y + echo, FLIGHT.y + echo + 0.55)
			if out > 0.0 and out < 1.0:
				draw_arc(_land, lerpf(10.0, 78.0, _out(out)), 0.0, TAU, 48, Color(VOID_BLUE.lightened(0.3), 1.0 - out), lerpf(5.0, 1.0, out), true)
	## Once turned: rays behind the gem and the broken ring closing round it.
	if _t >= TURN:
		var held: float = _span(_t, TURN, TURN + 0.3) * (1.0 - _span(_t, FLIGHT.x, FLIGHT.x + 0.35))
		var gem_at: Vector2 = _gem_after.position + _gem_after.size * 0.5
		var gem_scale: float = _gem_after.scale.x
		if held > 0.0:
			var reach: float = 230.0 * gem_scale
			draw_texture_rect(glow, Rect2(gem_at - Vector2(reach, reach), Vector2(reach, reach) * 2.0), false, Color(VOID_BLUE, 0.45 * held))
			for ray in range(12):
				var angle: float = _t * 0.35 + TAU * float(ray) / 12.0
				var wide: float = 0.07
				var tip: float = reach * (0.9 + 0.2 * sin(_t * 3.0 + float(ray)))
				draw_colored_polygon(PackedVector2Array([gem_at, gem_at + Vector2.from_angle(angle - wide) * tip, gem_at + Vector2.from_angle(angle + wide) * tip]),
					Color(VOID_BLUE.lightened(0.4), 0.13 * held))
		var closing: float = _out(_span(_t, TURN, TURN + 0.5))
		var ring_alpha: float = 1.0 - _span(_t, FLIGHT.y - 0.25, FLIGHT.y)
		if ring_alpha > 0.0:
			var radius: float = GEM_EDGE * 0.62 * gem_scale * lerpf(1.6, 1.0, closing)
			for arc in range(6):
				var angle: float = TAU * float(arc) / 6.0 + _t * 0.8
				draw_arc(gem_at, radius, angle, angle + TAU / 9.0 * closing, 16, Color(VOID_BLUE.lightened(0.2), 0.95 * ring_alpha), maxf(1.5, 5.0 * gem_scale), true)
