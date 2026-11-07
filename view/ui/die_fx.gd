extends RefCounted
## A die struck on the anvil, or a face of it turned wild (Nov 5 2026, round 5): the sound and
## the light, played over whatever shows that die. One piece wherever a die is hammered (a
## Hammered card's charges, the Smithy's hammer, plain or upgraded) or a face turns wild (A Wild
## Face's charges). `at` is in `layer`'s own coordinates. Headless, only the sound is asked for.

const SPARK_WHITE := Color("fff4d6")
const SPARK_HOT := Color("ffae42")
const SPARK_COOL := Color("c8452f")
const GLINT := Color("fff1a6")

static func strike(layer: Control, at: Vector2, strength: float = 1.0) -> void:
	## The hammer coming down: a ringing strike and hot sparks flung up off the die.
	DeepAudio.play("hammer_strike", {"volume": 0.9})
	if DeepUi.headless() or layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return
	var sparks := Sparks.new(at, strength)
	layer.add_child(sparks)
	DeepUi.burst(layer, at, SPARK_WHITE, int(8.0 * strength), 160.0, 0.25, 3.0)

static func glint(layer: Control, at: Vector2) -> void:
	## A face turning wild: a bright chime and a four-pointed glint turning over the die.
	DeepAudio.play("gleam", {"volume": 0.85})
	if DeepUi.headless() or layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return
	layer.add_child(Glint.new(at))
	DeepUi.burst(layer, at, GLINT, 14, 140.0, 0.5, 3.5)

class Sparks extends Control:
	## Sparks off the anvil: short streaks flung up and out, falling as they go, cooling from
	## white through orange to a dull red before they are gone. Drawn added to what is under them.
	const LIFE: float = 0.8
	const GRAVITY: float = 980.0
	var origin: Vector2
	var bits: Array = []
	var age: float = 0.0

	func _init(at: Vector2, strength: float) -> void:
		origin = at
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 60
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for _i in range(int(22.0 * strength)):
			## Mostly up and out, a few low and wide.
			var angle: float = rng.randf_range(-PI * 0.92, -PI * 0.08)
			var speed: float = rng.randf_range(200.0, 470.0) * strength
			bits.append({"v": Vector2.from_angle(angle) * speed, "life": rng.randf_range(0.35, LIFE), "width": rng.randf_range(1.5, 2.6)})

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		## A step at most a frame long: the first strike bakes its sound and hitches, and a whole
		## hitch taken at once would end the sparks before they were ever drawn.
		age += minf(delta, 1.0 / 30.0)
		if age > LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for bit in bits:
			var life: float = float(bit.life)
			if age > life:
				continue
			var t: float = age
			var v0: Vector2 = bit.v
			var now: Vector2 = origin + v0 * t + Vector2(0.0, 0.5 * GRAVITY * t * t)
			var velocity: Vector2 = v0 + Vector2(0.0, GRAVITY * t)
			var tail: Vector2 = now - velocity * 0.035
			var k: float = age / life
			var tone: Color = SPARK_WHITE.lerp(SPARK_HOT, clampf(k * 2.0, 0.0, 1.0)).lerp(SPARK_COOL, clampf(k * 2.0 - 1.0, 0.0, 1.0))
			draw_line(tail, now, Color(tone, 1.0 - k * k), float(bit.width), true)

class Glint extends Control:
	## A four-pointed star that opens, turns a quarter and closes over the face turned wild.
	const LIFE: float = 0.7
	var origin: Vector2
	var age: float = 0.0

	func _init(at: Vector2) -> void:
		origin = at
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 60
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		## A step at most a frame long: the first strike bakes its sound and hitches, and a whole
		## hitch taken at once would end the sparks before they were ever drawn.
		age += minf(delta, 1.0 / 30.0)
		if age > LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = age / LIFE
		var reach: float = 46.0 * sin(k * PI)
		var waist: float = reach * 0.16
		var turn: float = k * PI * 0.5
		var points := PackedVector2Array()
		for i in range(8):
			var angle: float = turn + PI * 0.25 * float(i)
			points.append(origin + Vector2.from_angle(angle) * (reach if i % 2 == 0 else waist))
		if reach > 1.0:
			draw_colored_polygon(points, Color(GLINT, 0.85 * (1.0 - k * 0.5)))
			draw_arc(origin, reach * 0.55, 0.0, TAU, 32, Color(GLINT, 0.4 * (1.0 - k)), 2.0, true)
