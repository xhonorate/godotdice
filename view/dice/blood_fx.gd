extends RefCounted
## What a Blood die does on screen (the owner's picks, November 10, 2026, review round 3, db
## `dice3`), drawn by DiceView for a die whose look `bleeds`:
##   "stream"  thrown again (it costs its owner 2 HP, sim/dice.gd BLOOD_HP): a ribbon of blood
##             leaves the die, arcs over the dock and runs into its owner's health ring,
##             splashing there (battle_screen's blood dues call DiceView.blood_reroll)
##   "thread"  fed (something died and the face it shows climbs by one, sim/battle.gd
##             `_blood_feeds`): a thread of blood runs from where the creature fell into the
##             die, which flares and its veins pulse (battle_screen's `_kill` calls
##             DiceView.blood_fed; the oxblood shader's per-die `pulse`)
## Drawn in 2D on a top-level layer the die makes for the effect and frees after (so the dock
## does not clip it and nothing is left behind): no particles and no extra 3D pass. Every
## effect is worked out from the time since it began and its seed, so it can be drawn at any
## moment, and it runs on the fight's clock (a hurried turn hurries it).

const SECONDS := {"stream": 1.5, "thread": 1.7}
const WET := Color("8e0c1c")
const BRIGHT := Color("d0182e")
const DARK := Color("3d0309")
const SHINE := Color(1.0, 0.86, 0.86)

static func active(kind: String, time: float) -> bool:
	return SECONDS.has(kind) and time < float(SECONDS[kind])

static func pulse(kind: String, time: float) -> float:
	## How swollen the die's veins are (0 to 1): one beat as the thread arrives, back to
	## nothing before the effect ends.
	if kind == "thread":
		return exp(-pow((time - 1.0) / 0.18, 2.0))
	return 0.0

static func draw_travel(canvas: CanvasItem, kind: String, time: float, seed_value: int, die: Rect2, point: Vector2) -> void:
	## What crosses the screen, on the canvas: `die` is the die's rectangle, `point` the far end.
	match kind:
		"stream":
			_stream(canvas, time, seed_value, die, point)
		"thread":
			_thread(canvas, time, seed_value, die, point)

static func _drop(canvas: CanvasItem, at: Vector2, velocity: Vector2, radius: float, alpha: float, edge: float) -> void:
	## A bead of blood, drawn out behind it along its flight, a dark rim and a highlight.
	var speed: float = velocity.length()
	var tail: Vector2 = at - (velocity / maxf(speed, 0.001)) * radius * clampf(speed / (3.0 * edge), 0.0, 1.0) * 2.4
	canvas.draw_line(at, tail, Color(DARK, alpha), radius * 1.9, true)
	canvas.draw_circle(at, radius * 1.12, Color(DARK, alpha))
	canvas.draw_line(at, tail, Color(WET, alpha), radius * 1.3, true)
	canvas.draw_circle(at, radius, Color(WET, alpha))
	canvas.draw_circle(at + Vector2(-0.32, -0.32) * radius, radius * 0.32, Color(SHINE, alpha * 0.8))

static func _path(from: Vector2, to: Vector2, u: float, lift: float, sway: float, bow: float = 0.0) -> Vector2:
	## A point `u` of the way along an arc from `from` to `to`, bowed up by `lift`, out to one
	## side by `bow`, and swaying.
	var straight: Vector2 = from.lerp(to, u)
	var across: Vector2 = (to - from).orthogonal().normalized()
	return straight + Vector2(0.0, -lift * sin(PI * u)) + across * (bow * sin(PI * u) + sway * sin(u * TAU * 1.5) * sin(PI * u))

static func _stream(canvas: CanvasItem, time: float, seed_value: int, die: Rect2, target: Vector2) -> void:
	## A ribbon of blood leaves the top of the die, arcs over the dock and runs into the health
	## ring, shedding a few drops on the way and splashing where it lands: the 2 HP it cost,
	## seen going.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var edge: float = minf(die.size.x, die.size.y)
	var width: float = maxf(4.0, edge * 0.08)
	var from: Vector2 = die.get_center() + Vector2(0.0, -edge * 0.2)
	var lift: float = maxf(edge * 0.8, from.distance_to(target) * 0.18)
	var head: float = clampf(time / 0.6, 0.0, 1.0)
	var tail: float = clampf((time - 0.3) / 0.5, 0.0, 1.0)
	if tail < 1.0 and head > tail:
		var line := PackedVector2Array()
		for k in range(29):
			var u: float = lerpf(tail, head, float(k) / 28.0)
			line.append(_path(from, target, u * u * (3.0 - 2.0 * u), lift, 0.0))
		canvas.draw_polyline(line, Color(DARK, 0.9), width * 1.5, true)
		canvas.draw_polyline(line, Color(WET, 1.0), width, true)
		canvas.draw_polyline(line, Color(BRIGHT, 0.8), width * 0.4, true)
		canvas.draw_circle(line[line.size() - 1], width * 0.85, Color(BRIGHT, 1.0))
	for i in range(6):
		## Drops shaken off the ribbon, falling away under it.
		var shed: float = rng.randf_range(0.1, 0.5)
		var age: float = time - shed
		if age < 0.0 or age > 0.5:
			continue
		var u: float = clampf(shed / 0.6, 0.0, 1.0)
		var at: Vector2 = _path(from, target, u * u * (3.0 - 2.0 * u), lift, 0.0) + Vector2(rng.randf_range(-1.0, 1.0) * width, 0.0)
		at += Vector2(0.0, 900.0 * age * age)
		_drop(canvas, at, Vector2(0.0, 1800.0 * age), width * 0.6, 1.0 - smoothstep(0.35, 0.5, age), edge)
	var landed: float = time - 0.6
	if landed > 0.0:
		var spread: float = smoothstep(0.0, 0.15, landed)
		var fade: float = 1.0 - smoothstep(0.4, 0.9, landed)
		var reach: float = maxf(edge, 60.0)
		canvas.draw_arc(target, reach * (0.15 + 0.35 * spread), 0.0, TAU, 32, Color(BRIGHT, 0.85 * fade), maxf(3.0, width * (1.0 - spread * 0.6)), true)
		for k in range(7):
			var angle: float = rng.randf() * TAU
			canvas.draw_circle(target + Vector2.from_angle(angle) * reach * 0.45 * spread, width * 0.5, Color(WET, fade))

static func _thread(canvas: CanvasItem, time: float, seed_value: int, die: Rect2, source: Vector2) -> void:
	## A thread of blood runs from where the creature fell into the die: its head races ahead,
	## its tail follows it in, and the die takes it with a flash.
	var edge: float = minf(die.size.x, die.size.y)
	var into: Vector2 = die.get_center()
	var bow: float = source.distance_to(into) * 0.18
	var head: float = clampf(time / 0.8, 0.0, 1.0)
	var tail: float = clampf((time - 0.45) / 0.6, 0.0, 1.0)
	if tail < 1.0 and head > tail:
		var line := PackedVector2Array()
		var steps: int = 28
		for k in range(steps + 1):
			var u: float = lerpf(tail, head, float(k) / float(steps))
			line.append(_path(source, into, u * u * (3.0 - 2.0 * u), 0.0, edge * 0.12, bow))
		var width: float = edge * 0.07
		canvas.draw_polyline(line, Color(DARK, 0.9), width * 1.5, true)
		canvas.draw_polyline(line, Color(WET, 1.0), width, true)
		canvas.draw_polyline(line, Color(BRIGHT, 0.8), width * 0.4, true)
		canvas.draw_circle(line[line.size() - 1], width * 0.9, Color(BRIGHT, 1.0))
		canvas.draw_circle(line[0], width * 0.6 * (1.0 - tail), Color(WET, 0.9))
	var taken: float = time - 0.95
	if taken > 0.0 and taken < 0.6:
		var fade: float = 1.0 - taken / 0.6
		canvas.draw_arc(into, edge * (0.38 + 0.3 * taken), 0.0, TAU, 40, Color(BRIGHT, 0.7 * fade), maxf(2.0, edge * 0.04), true)
