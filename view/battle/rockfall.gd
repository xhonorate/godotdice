extends Node3D
## The way out, sealed: rock crashing down across the far end of the room as a fight begins,
## and tumbling apart when it is won. Sits at the foot of the wall it covers, in room space.
##
## The boulders land lowest first, so the pile builds up the arch; each lands with a thump
## the camera feels and a puff of grit. The crumble takes them top first: they hop, turn,
## shrink and sink through the floor in a cloud, and the mouth is open again.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const Tunnel = preload("res://view/battle/tunnel.gd")

const COUNT := 34
const DUST := Color("8a7a66")

## Told how hard each landing hits: the stage turns it into camera shake.
var jolt: Callable = Callable()
var fx: Node3D = null

var _rocks: Array = []
var _material: StandardMaterial3D

func build(tone: Color, seed_value: int, half: float = Tunnel.WIDTH * 0.5 + 0.4, tall: float = Tunnel.HEIGHT + 0.4, count: int = COUNT) -> void:
	## `half` is how far the pile reaches either side of this node and `tall` how high it
	## stands. A slab of rock wants slabs to build it: the blocks are cut jagged and drawn at
	## a size set against the span they have to close, so a wall is a wall and not a heap of
	## gravel stacked up against one.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	var shapes: Array = []
	for i in range(5):
		shapes.append(Lowpoly.rock(rng, tone.lightened(0.03 * float(i)), 0.52, Vector3(1.0, 0.72, 0.85)))
	## Big enough that a handful of them close the span, with the highest a little smaller.
	var block: float = clampf(half * 0.34, 0.6, 3.0)
	var plan: Array = []
	for i in range(count):
		var x: float = rng.randf_range(-half, half)
		var top: float = tall - 0.9 * pow(absf(x) / half, 2.0) * tall * 0.25
		var y: float = maxf(0.3, top * pow(rng.randf(), 0.75))
		var up: float = clampf(y / maxf(0.5, tall), 0.0, 1.0)
		var z: float = rng.randf_range(-0.6, 1.8) * (1.0 - 0.55 * up) + 0.2
		var scale: float = block * lerpf(1.1, 0.62, up) * rng.randf_range(0.78, 1.3)
		plan.append({"at": Vector3(x, y, z), "scale": scale, "turn": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU),
			"shape": rng.randi() % shapes.size(), "delay": 0.05 + up * 0.55 + rng.randf() * 0.18,
			"from": Vector3(x * 0.8 + rng.randf_range(-0.4, 0.4), tall + 3.6 + rng.randf() * 1.6, z + 0.9), "spin": Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at.y) < float(b.at.y))
	for step in plan:
		var rock := MeshInstance3D.new()
		rock.mesh = shapes[int(step.shape)]
		rock.material_override = _material
		rock.scale = Vector3.ONE * float(step.scale)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if float(step.scale) > 1.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rock.visible = false
		add_child(rock)
		step.node = rock
		_rocks.append(step)

func rest() -> void:
	## Already down: a fight picked up where it was.
	for step in _rocks:
		var rock: MeshInstance3D = step.node
		rock.visible = true
		rock.position = step.at
		rock.rotation = step.turn

func fall() -> void:
	var landed: Array = [0]
	for step in _rocks:
		var rock: MeshInstance3D = step.node
		var from: Vector3 = step.from
		var to: Vector3 = step.at
		var spin: Vector3 = step.spin
		var turn: Vector3 = step.turn
		var drop: float = sqrt(maxf(0.1, from.y - to.y) * 2.0 / 16.0)
		rock.position = from
		var tween := rock.create_tween()
		tween.tween_interval(float(step.delay))
		tween.tween_callback(func() -> void: rock.visible = true)
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(rock):
				rock.position = Vector3(lerpf(from.x, to.x, t), lerpf(from.y, to.y, t * t), lerpf(from.z, to.z, t))
				rock.rotation = turn + spin * (1.0 - t), 0.0, 1.0, drop)
		tween.tween_callback(func() -> void:
			landed[0] += 1
			var heavy: bool = rock.scale.x > 1.0
			if heavy or int(landed[0]) % 4 == 0:
				DeepAudio.play("rock_break", {"volume": 0.45 if heavy else 0.3, "gap": 0.05, "vary": 0.25})
				if fx != null and is_instance_valid(fx):
					fx.puff(rock.global_position + Vector3(0, -0.2, 0.4), DUST, 6, 0.9, 1.3, 0.35)
					if heavy:
						fx.flash(rock.global_position + Vector3(0, 0.4, 1.2), Color("ffd0a0"), 2.5, 6.0, 0.3, 0.0)
			if jolt.is_valid():
				jolt.call(0.1 if heavy else 0.035))
		tween.tween_property(rock, "position:y", to.y + 0.1 * rock.scale.x, 0.07).set_ease(Tween.EASE_OUT)
		tween.tween_property(rock, "position:y", to.y, 0.09).set_ease(Tween.EASE_IN)

func crumble() -> void:
	## Top first: each stone hops, turns, shrinks and sinks away, and the dust hangs.
	var count: int = _rocks.size()
	for i in range(count):
		var step: Dictionary = _rocks[count - 1 - i]
		var rock: MeshInstance3D = step.node
		if not rock.visible:
			rock.visible = true
			rock.position = step.at
		var start: Vector3 = rock.position
		var hop := Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 0.7), randf_range(0.3, 1.4))
		var sink := Vector3(start.x + hop.x, -1.2, start.z + hop.z)
		var spin := Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		var size: float = rock.scale.x
		var tween := rock.create_tween()
		tween.tween_interval(0.025 * float(i))
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(rock):
				var arc: float = sin(t * PI) * hop.y * (1.0 - t)
				rock.position = start.lerp(sink, t * t) + Vector3(0, arc, 0)
				rock.rotation = Vector3(step.turn) + spin * t
				rock.scale = Vector3.ONE * size * lerpf(1.0, 0.25, t), 0.0, 1.0, randf_range(0.7, 1.1))
	if fx != null and is_instance_valid(fx):
		var centre: Vector3 = global_position + Vector3(0, 1.4, 0.8)
		fx.puff(centre, DUST, 22, 1.6, 2.2, 0.7)
		fx.puff(centre + Vector3(0, -1.0, 0.6), DUST.darkened(0.2), 14, 1.2, 1.8, 0.3)
		fx.shards(centre, DUST.lightened(0.2), 8, 3.0, 0.12, 0.9)
	var done := create_tween()
	done.tween_interval(0.025 * float(count) + 1.2)
	done.tween_callback(queue_free)
