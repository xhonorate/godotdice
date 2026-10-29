extends RefCounted
## Marks on the dock for what creatures do to a player's dice and gems (the Creature Tells
## pass, October 27, 2026): a badge on the thing that says who did it (hover for the plate,
## and a thread back to the creature while the pointer rests there), fog over a clouded
## socket, rubble over a buried one, crackle round a locked die, water over a dreaded tray,
## a ghost seat where a die sits out, the face tile that comes off a cut die, shards of a
## broken gem, and the red outline that lights what a creature's move has just taken.
##
## Everything here is a Control drawn by hand, laid over the dock by battle_screen.gd.

const Tips = preload("res://view/ui/tips.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

const INK := Color("0a0d18")
const CLOUD := Color("c9d2e6")
const DUST := Color("c9a079")
const SHOCK := Color("8fe8ff")
const WATER := Color("6ab8e0")
const TELL := Color("ff6b5c")

class Badge extends Control:
	## A round mark at the corner of a socket or a die: the creature's colour, a glyph for
	## what it did. Its plate comes up on hover; while the pointer rests on it a thread runs
	## back to the creature (`thread`).
	var glyph: String = ""
	var tone: Color = Color.WHITE
	var edge: float = 22.0
	var _texture: Texture2D = null
	var _thread: Control = null
	func _init(mark: String, color: Color, size_px: float = 22.0) -> void:
		glyph = mark
		tone = color
		edge = size_px
		custom_minimum_size = Vector2(edge, edge)
		size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_HELP
		z_index = 3
		_texture = GemIcons.texture(glyph, GemIcons.baked_size(edge * 0.64))
	func retone(color: Color) -> void:
		if color != tone:
			tone = color
			queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5
		var r: float = edge * 0.5
		draw_circle(centre, r, INK)
		draw_circle(centre, r - 2.0, tone)
		if _texture != null:
			var side: float = edge * 0.64
			draw_texture_rect(_texture, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), false, INK)
	func set_plate(builder: Callable, plate_tone: Color) -> void:
		Tips.attach(self, builder, {"tone": plate_tone})
	func thread(host: Control, to: Callable, color: Color) -> void:
		## A thread from this badge to a point on the screen (the creature) while hovered.
		var me: Badge = self
		mouse_entered.connect(func() -> void:
			if _thread != null and is_instance_valid(_thread):
				_thread.queue_free()
			_thread = Tether.new(host, func() -> Vector2: return me.global_position + me.size * 0.5 - host.global_position, to, color, true, 2.0))
		mouse_exited.connect(func() -> void:
			if _thread != null and is_instance_valid(_thread):
				(_thread as Tether).fade_out()
			_thread = null)
		tree_exiting.connect(func() -> void:
			if _thread != null and is_instance_valid(_thread):
				_thread.queue_free())

class Tether extends Control:
	## A line between two points of the screen, laid over everything: dashed and flowing
	## toward its end while a badge is hovered, or a bright bolt that draws itself out and
	## fades (`flash`): a tongue, a shock, a gaze, a reflected blow.
	var from: Callable
	var to: Callable
	var tone: Color = Color.WHITE
	var dashed: bool = true
	var width: float = 2.0
	## How jagged: 0 for a smooth line, more for lightning.
	var jag: float = 0.0
	var sag: float = 0.12
	var _phase: float = 0.0
	var _alpha: float = 0.0
	var _goal: float = 1.0
	var _grow: float = 1.0
	var _grow_speed: float = 0.0
	var _life: float = -1.0
	var _jitter: PackedFloat32Array = PackedFloat32Array()
	var _jitter_clock: float = 0.0
	func _init(host: Control, a: Callable, b: Callable, color: Color, is_dashed: bool = true, line_width: float = 2.0) -> void:
		from = a
		to = b
		tone = color
		dashed = is_dashed
		width = line_width
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 60
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(self)
	static func flash(host: Control, a: Vector2, b: Vector2, color: Color, line_width: float = 3.0, jagged: float = 0.0, seconds: float = 0.5) -> Tether:
		## One bolt from a to b: drawn out over 0.15 s, held, gone after `seconds`.
		var bolt := Tether.new(host, func() -> Vector2: return a, func() -> Vector2: return b, color, false, line_width)
		bolt.jag = jagged
		bolt.sag = 0.04
		bolt._grow = 0.0
		bolt._grow_speed = 1.0 / 0.15
		bolt._life = seconds
		bolt._alpha = 1.0
		return bolt
	func fade_out() -> void:
		_goal = 0.0
	func _process(delta: float) -> void:
		_phase += delta
		if _life >= 0.0:
			_life -= delta
			if _life <= 0.15:
				_goal = 0.0
		_alpha = move_toward(_alpha, _goal, delta * 6.0)
		if _grow < 1.0:
			_grow = minf(1.0, _grow + delta * _grow_speed)
		if _goal <= 0.0 and _alpha <= 0.0:
			queue_free()
			return
		_jitter_clock -= delta
		if jag > 0.0 and _jitter_clock <= 0.0:
			_jitter_clock = 0.06
			_jitter = PackedFloat32Array()
		queue_redraw()
	func _draw() -> void:
		if not from.is_valid() or not to.is_valid():
			return
		var a: Vector2 = from.call()
		var b: Vector2 = to.call()
		var span: Vector2 = b - a
		if span.length() < 2.0:
			return
		var steps: int = clampi(int(span.length() / 14.0), 6, 40)
		var side: Vector2 = Vector2(-span.y, span.x).normalized()
		## A thread hangs a little; a bolt bends hardly at all.
		var droop: float = span.length() * sag
		if jag > 0.0 and _jitter.size() != steps + 1:
			_jitter = PackedFloat32Array()
			for i in range(steps + 1):
				_jitter.append(randf_range(-1.0, 1.0) * (0.0 if i == 0 or i == steps else 1.0))
		var points := PackedVector2Array()
		var shown: int = maxi(1, int(ceil(float(steps) * _grow)))
		for i in range(shown + 1):
			var t: float = float(i) / float(steps)
			var p: Vector2 = a + span * t + side * (droop * 4.0 * t * (1.0 - t))
			if jag > 0.0 and i < _jitter.size():
				p += side * _jitter[i] * jag
			points.append(p)
		var color := Color(tone, _alpha)
		if not dashed:
			draw_polyline(points, Color(tone, _alpha * 0.25), width * 4.0, true)
			draw_polyline(points, color, width, true)
			draw_polyline(points, Color(tone.lightened(0.5), _alpha * 0.9), maxf(1.0, width * 0.4), true)
			return
		## Dashes walk along the line toward its end: the curve is cut into short pieces and
		## every piece that falls in a dash is drawn.
		var dash: float = 7.0
		var gap: float = 6.0
		var walked: float = -fmod(_phase * 40.0, dash + gap)
		var piece: float = 2.5
		for i in range(points.size() - 1):
			var seg_from: Vector2 = points[i]
			var seg_to: Vector2 = points[i + 1]
			var seg_len: float = seg_from.distance_to(seg_to)
			var at: float = 0.0
			while at < seg_len:
				var step: float = minf(piece, seg_len - at)
				if fposmod(walked + at, dash + gap) < dash:
					draw_line(seg_from.lerp(seg_to, at / seg_len), seg_from.lerp(seg_to, (at + step) / seg_len), color, width, true)
				at += step
			walked += seg_len

class FogBank extends Control:
	## Cloud over a clouded socket: a few soft puffs drifting over the gem, blown off the
	## socket in one gust when the creature that fogged it is hit (`blow_away`).
	var radius: float = 30.0
	var tone: Color = Color("c9d2e6")
	var _puffs: Array = []
	var _clock: float = 0.0
	var _gone: bool = false
	func _init(r: float, color: Color = Color("c9d2e6")) -> void:
		radius = r
		tone = color
		size = Vector2(r * 2.0, r * 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 2
		var rng := RandomNumberGenerator.new()
		rng.seed = int(r * 7.0)
		for i in range(5):
			_puffs.append({"at": Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.38, 0.38)) * r, "r": r * rng.randf_range(0.5, 0.72), "phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.5, 0.9)})
		modulate.a = 0.0
	func appear() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	func blow_away() -> void:
		if _gone:
			return
		_gone = true
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "position:x", position.x + 46.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(queue_free)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5
		draw_circle(centre, radius * 0.72, Color(tone, 0.5))
		for puff in _puffs:
			var drift := Vector2(sin(_clock * float(puff.speed) + float(puff.phase)) * 5.0, cos(_clock * float(puff.speed) * 0.8 + float(puff.phase)) * 3.0)
			var r: float = float(puff.r)
			var at: Vector2 = centre + Vector2(puff.at) + drift
			## Soft-edged puffs: a few discs stepping down in alpha.
			draw_circle(at, r, Color(tone, 0.22))
			draw_circle(at, r * 0.78, Color(tone, 0.4))
			draw_circle(at, r * 0.55, Color(tone.lightened(0.2), 0.75))

class Rubble extends Control:
	## Rocks piled over a buried socket, with dust drifting over them: they fall in from
	## above (`fall_in`) and sit for the turn.
	var rocks: Array = []
	var dust: Array = []
	var _clock: float = 0.0
	var _fallen: float = 1.0
	func _init(edge: float) -> void:
		size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 2
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		var centre := Vector2(edge, edge) * 0.5
		var tones: Array = [Color("8a6a4a"), Color("7a7f8e"), Color("9a7a5a"), Color("666b7a"), Color("a88a66")]
		for i in range(6):
			var at: Vector2 = centre + Vector2(rng.randf_range(-0.34, 0.34), rng.randf_range(-0.12, 0.4)) * edge
			var r: float = edge * rng.randf_range(0.13, 0.21)
			var pts := PackedVector2Array()
			var sides: int = 5 + rng.randi_range(0, 2)
			for k in range(sides):
				var angle: float = TAU * float(k) / float(sides) + rng.randf_range(-0.2, 0.2)
				pts.append(at + Vector2.from_angle(angle) * r * rng.randf_range(0.75, 1.15))
			rocks.append({"pts": pts, "color": tones[i % tones.size()], "delay": 0.05 * float(i)})
		for i in range(4):
			dust.append({"at": Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.35, 0.2)) * edge, "r": edge * rng.randf_range(0.3, 0.45), "phase": rng.randf_range(0.0, TAU)})
	func fall_in() -> void:
		_fallen = 0.0
		var tween := create_tween()
		tween.tween_property(self, "_fallen", 1.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5
		for puff in dust:
			var drift := Vector2(sin(_clock * 0.7 + float(puff.phase)) * 6.0, -4.0 + sin(_clock * 0.5 + float(puff.phase)) * 3.0)
			var r: float = float(puff.r)
			draw_circle(centre + Vector2(puff.at) + drift, r, Color(DUST, 0.18 * _fallen))
			draw_circle(centre + Vector2(puff.at) + drift, r * 0.6, Color(DUST, 0.3 * _fallen))
		for rock in rocks:
			var drop: float = (1.0 - clampf((_fallen - float(rock.delay)) / 0.9, 0.0, 1.0)) * -70.0
			var pts: PackedVector2Array = rock.pts
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(p + Vector2(0, drop))
			draw_colored_polygon(moved, rock.color)
			var outline: PackedVector2Array = moved.duplicate()
			outline.append(moved[0])
			draw_polyline(outline, Color("1a120a"), 1.5, true)

class Crackle extends Control:
	## Lightning crawling round a locked die.
	var tone: Color = Color("8fe8ff")
	var _clock: float = 0.0
	var _rng := RandomNumberGenerator.new()
	var _lines: Array = []
	func _init(edge: float, color: Color = Color("8fe8ff")) -> void:
		tone = color
		size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 2
		_rng.randomize()
	func _process(delta: float) -> void:
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.07
			_lines.clear()
			var inset: float = -3.0
			var corners: Array = [Vector2(inset, inset), Vector2(size.x - inset, inset), Vector2(size.x - inset, size.y - inset), Vector2(inset, size.y - inset)]
			for i in range(4):
				var a: Vector2 = corners[i]
				var b: Vector2 = corners[(i + 1) % 4]
				var pts := PackedVector2Array()
				var side: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized()
				for k in range(7):
					var t: float = float(k) / 6.0
					pts.append(a.lerp(b, t) + side * (_rng.randf_range(-4.0, 4.0) if k > 0 and k < 6 else 0.0))
				_lines.append([pts, _rng.randf_range(0.45, 1.0)])
			queue_redraw()
	func _draw() -> void:
		for line in _lines:
			draw_polyline(line[0], Color(tone, float(line[1]) * 0.35), 5.0, true)
			draw_polyline(line[0], Color(tone.lightened(0.4), float(line[1])), 1.8, true)

class Water extends Control:
	## Water over a dreaded tray: it rises from the bottom, the dice bob in it, and it drains
	## as the next turn begins.
	var level: float = 0.0
	var _clock: float = 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func rise(to: float = 0.6) -> void:
		var tween := create_tween()
		tween.tween_property(self, "level", to, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	func drain() -> void:
		var tween := create_tween()
		tween.tween_property(self, "level", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		if level <= 0.04 or size.y <= 8.0 or size.x <= 8.0:
			return
		var top: float = size.y * (1.0 - level)
		var pts := PackedVector2Array()
		var colors := PackedColorArray()
		var steps: int = 16
		for i in range(steps + 1):
			var x: float = size.x * float(i) / float(steps)
			pts.append(Vector2(x, minf(size.y - 2.0, top + sin(_clock * 2.4 + x * 0.05) * 3.0 + sin(_clock * 1.3 + x * 0.11) * 2.0)))
			colors.append(Color(WATER, 0.42))
		pts.append(Vector2(size.x, size.y))
		colors.append(Color("143a5a", 0.8))
		pts.append(Vector2(0, size.y))
		colors.append(Color("143a5a", 0.8))
		draw_polygon(pts, colors)
		var crest := PackedVector2Array()
		for i in range(steps + 1):
			crest.append(pts[i])
		draw_polyline(crest, Color("dff0ff", 0.7), 2.0, true)

class TilePop extends Control:
	## The face of a die as a tile that comes off it: it drops and tumbles when a face is cut
	## down (`drop`), or glows, burns and goes to smoke when one is melted blank (`burn`).
	var text: String = ""
	var fill: Color = Color("f4f2ea")
	var ink: Color = Color("0b0e16")
	func _init(edge: float, words: String, body: Color = Color("f4f2ea"), number: Color = Color("0b0e16")) -> void:
		text = words
		fill = body
		ink = number
		size = Vector2(edge, edge)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 4
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), fill)
		draw_rect(Rect2(Vector2.ZERO, size), Color("05070c"), false, 2.5)
		var font: Font = DeepUi.bold_font()
		var px: int = int(size.y * 0.74)
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		draw_string(font, Vector2((size.x - measured.x) * 0.5, size.y * 0.5 + measured.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
	func drop() -> void:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "position", position + Vector2(randf_range(-12.0, 18.0), 64.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation", randf_range(0.5, 1.1), 0.7)
		tween.tween_property(self, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
	func burn(host: Control, at: Vector2) -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color("ff7a2a"), 0.22).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func() -> void: DeepUi.burst(host, at, Color("3a3230"), 12, 60.0, 0.9, 7.0))
		tween.tween_property(self, "modulate", Color(0.2, 0.15, 0.12, 0.0), 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(queue_free)

class Telegraph extends Control:
	## What a creature's move has just taken, lit: a pulsing red outline round the die or
	## socket with the move's name over it, for a moment as the move lands.
	var words: String = ""
	var tone: Color = Color("ff6b5c")
	var _clock: float = 0.0
	var _life: float = 1.5
	var _chip: Label = null
	func _init(rect: Rect2, name_words: String, color: Color = Color("ff6b5c")) -> void:
		words = name_words
		tone = color
		position = rect.position - Vector2(6, 6)
		size = rect.size + Vector2(12, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 55
		if not words.is_empty():
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", DeepUi.capsule(chip, tone.darkened(0.55), tone, 2, 10, 2))
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(chip)
			_chip = DeepUi.label(chip, words, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			_chip.add_theme_font_override("font", DeepUi.bold_font())
			chip.resized.connect(func() -> void: chip.position = Vector2((size.x - chip.size.x) * 0.5, -chip.size.y - 4.0).round())
	func _process(delta: float) -> void:
		_clock += delta
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		modulate.a = clampf(_life / 0.3, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var pulse: float = 0.6 + 0.4 * sin(_clock * 9.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(tone, 0.12 * pulse))
		draw_rect(Rect2(Vector2.ZERO, size), Color(tone, pulse), false, 3.0)

class Shards extends Control:
	## Pieces of a broken thing flying: thrown up a little and falling, tumbling, fading.
	var pieces: Array = []
	var tone: Color = Color.WHITE
	var _life: float = 0.0
	func _init(at: Vector2, color: Color, count: int = 8, downward: bool = true) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 58
		position = at
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in range(count):
			var pts := PackedVector2Array()
			var r: float = rng.randf_range(4.0, 9.0)
			var turn: float = rng.randf_range(0.0, TAU)
			for k in range(3):
				pts.append(Vector2.from_angle(turn + TAU * float(k) / 3.0 + rng.randf_range(-0.4, 0.4)) * r * rng.randf_range(0.7, 1.2))
			var velocity := Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-140.0, -20.0) if not downward else rng.randf_range(-60.0, 40.0))
			pieces.append({"pts": pts, "at": Vector2.ZERO, "v": velocity, "spin": rng.randf_range(-6.0, 6.0), "angle": 0.0})
	func _process(delta: float) -> void:
		_life += delta
		if _life > 1.0:
			queue_free()
			return
		for piece in pieces:
			piece.v = piece.v + Vector2(0, 420.0) * delta
			piece.at = piece.at + piece.v * delta
			piece.angle = piece.angle + piece.spin * delta
		queue_redraw()
	func _draw() -> void:
		var alpha: float = clampf(1.0 - (_life - 0.5) / 0.5, 0.0, 1.0)
		for piece in pieces:
			var pts := PackedVector2Array()
			for p in piece.pts:
				pts.append(Vector2(piece.at) + Vector2(p).rotated(float(piece.angle)))
			draw_colored_polygon(pts, Color(tone, alpha))
			var outline: PackedVector2Array = pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color("05070c", alpha), 1.2, true)

class GhostSeat extends Control:
	## A die's seat in the tray while the die is elsewhere: a dashed outline with a mark for
	## what has it (a creature's claw, a tick, a lock), or a dark cracked outline for one
	## broken for the fight.
	var tone: Color = Color.WHITE
	var glyph: String = ""
	var cracked: bool = false
	var _texture: Texture2D = null
	func _init(edge: float, mark: String, color: Color, broken: bool = false) -> void:
		glyph = mark
		tone = color
		cracked = broken
		custom_minimum_size = Vector2(edge, edge)
		size = Vector2(edge, edge)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_HELP
		_texture = GemIcons.texture(glyph, GemIcons.baked_size(edge * 0.4))
	func _draw() -> void:
		var inset: float = 4.0
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		draw_rect(rect, Color(0, 0, 0, 0.45))
		if cracked:
			draw_rect(rect, Color(tone, 0.7), false, 2.0)
			var c := size * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-18, -16), c + Vector2(-3, -3), c + Vector2(-8, 12), c + Vector2(10, 22)]), Color(tone, 0.8), 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(16, -20), c + Vector2(5, -5), c + Vector2(14, 6)]), Color(tone, 0.8), 2.0, true)
		else:
			## A dashed rounded rim.
			var dash: float = 6.0
			var gap: float = 5.0
			var corners: Array = [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
			for i in range(4):
				var a: Vector2 = corners[i]
				var b: Vector2 = corners[(i + 1) % 4]
				var length: float = a.distance_to(b)
				var at: float = 0.0
				while at < length:
					draw_line(a.lerp(b, at / length), a.lerp(b, minf(length, at + dash) / length), Color(tone, 0.85), 2.0, true)
					at += dash + gap
		if _texture != null:
			var side: float = size.x * 0.4
			draw_texture_rect(_texture, Rect2(size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(tone, 0.9))

class Cross extends Control:
	## Two red strokes across a button that is not the player's to press this turn.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		z_index = 2
	func _draw() -> void:
		var inset := Vector2(size.x * 0.3, size.y * 0.22)
		draw_line(inset, size - inset, Color("ff6b5c", 0.9), 3.0, true)
		draw_line(Vector2(size.x - inset.x, inset.y), Vector2(inset.x, size.y - inset.y), Color("ff6b5c", 0.9), 3.0, true)

static func dim(holder: Control, edge: float, on: bool, tone: Color = Color(0, 0, 0, 0.5)) -> void:
	## A dark pane over a die or stone that is not the player's to use right now.
	var pane: Panel = holder.get_node_or_null("DimPane")
	if pane == null and on:
		pane = Panel.new()
		pane.name = "DimPane"
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pane.position = Vector2(2, 2)
		pane.size = Vector2(edge - 4.0, edge - 4.0)
		pane.z_index = 1
		pane.add_theme_stylebox_override("panel", DeepUi.flat(tone, Color(0, 0, 0, 0), 10, 0, 0))
		holder.add_child(pane)
	if pane != null:
		pane.visible = on

static func fly(host: Control, copy: Control, from: Vector2, to: Vector2, seconds: float = 0.5, shrink: float = 0.3, arc: float = 0.0, done: Callable = Callable()) -> void:
	## Carries `copy` across the screen from one point to another (both host-local), along an
	## arc that bulges `arc` pixels sideways, shrinking to `shrink` of its size, then frees it.
	host.add_child(copy)
	copy.z_index = 60
	copy.pivot_offset = copy.size * 0.5
	copy.position = from - copy.size * 0.5
	var side: Vector2 = Vector2(-(to - from).y, (to - from).x).normalized() * arc
	var tween := host.create_tween()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(copy):
			return
		var eased: float = t * t * (3.0 - 2.0 * t)
		copy.position = from.lerp(to, eased) + side * 4.0 * t * (1.0 - t) - copy.size * 0.5
		copy.scale = Vector2.ONE * lerpf(1.0, shrink, eased), 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		if is_instance_valid(copy):
			copy.queue_free()
		if done.is_valid():
			done.call())
