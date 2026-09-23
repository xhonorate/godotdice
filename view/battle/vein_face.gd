extends Node3D
## A vein: six boulders of the rock strewn across the floor of the room, each with one place
## to put a pick in it. Each shows what it gives away: a bright one sparkles hard and has
## gold crystal breaking through, a glint shows a little blue, dull rock shows almost
## nothing. A struck boulder is a hole with its finder's color lit inside it.
##
## It used to be one flat wall of rock standing where a fight would, six spots in a grid on
## it. A wall that appears in the middle of a room reads as a backdrop rolled in rather than
## as the place the party is standing; six loose blocks lying about the floor read as a mine.
##
## Stands at the arena in room space. The middle is left clear, so the way up to the mouths
## runs between them. Knows nothing of the rules: it is told what each boulder looks like,
## which are taken and by whom, and when one is struck.

const Lowpoly = preload("res://view/battle/lowpoly.gd")

const WIDTH := 11.0
const HEIGHT := 3.0
## Where each boulder lies and how big it is, left to right across the room, the lane up the
## middle kept clear. No two are the same size: a row of matching lumps is a grid again.
const SPOTS: Array = [
	{"at": Vector3(-5.1, 0.0, -0.3), "size": 1.55},
	{"at": Vector3(-3.0, 0.0, 1.9), "size": 0.92},
	{"at": Vector3(-2.4, 0.0, -2.6), "size": 1.22},
	{"at": Vector3(2.1, 0.0, 1.5), "size": 1.62},
	{"at": Vector3(3.5, 0.0, -2.1), "size": 1.08},
	{"at": Vector3(5.3, 0.0, 0.5), "size": 0.86}]
const TONES: Dictionary = {"bright": Color("ffcf5a"), "glint": Color("8fd0ff"), "dull": Color("a09080")}
const SPARKS: Dictionary = {"bright": 9, "glint": 5, "dull": 2}

var hazard: bool = false
var _rock: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _spots: Array = []
var _clock: float = 0.0
## The room's own floor, so no block of rock is left hanging in the air over a dip in it.
var _ground: Callable = Callable()

func build(biome: Dictionary, spots: Array, seed_value: int, is_hazard: bool, ground: Callable = Callable()) -> void:
	hazard = is_hazard
	_ground = ground
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.6
	_rock = StandardMaterial3D.new()
	_rock.vertex_color_use_as_albedo = true
	_rock.roughness = 0.85
	_boulders(biome, rng)
	_foot(biome, rng)
	## A work lamp hung over the scatter, so the rock can be read.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(biome.key).lerp(Color("ffd9a8"), 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 13.0
	lamp.position = Vector3(0.0, 4.6, 2.4)
	lamp.shadow_enabled = false
	add_child(lamp)
	for index in range(SPOTS.size()):
		var spot: Dictionary = spots[index] if index < spots.size() else {"glint": "dull"}
		_spots.append(_nodule(index, str(spot.get("glint", "dull")), rng))

func _lie(index: int) -> Dictionary:
	return SPOTS[clampi(index, 0, SPOTS.size() - 1)]

func _floor_at(at: Vector3) -> float:
	## How high the room's floor is under a point, in this node's own space.
	if not _ground.is_valid():
		return 0.0
	return float(_ground.call(position.x + at.x, position.z + at.z)) - position.y

func _boulders(biome: Dictionary, rng: RandomNumberGenerator) -> void:
	## One block of rock for each place the pick can go, each a different size and each
	## turned its own way, sunk a little into the floor so none of them looks set down.
	var rock: Color = Color(biome.rock).lightened(0.12)
	var dark: Color = Color(biome.rock_dark)
	for index in range(SPOTS.size()):
		var lie: Dictionary = SPOTS[index]
		var size: float = float(lie.size)
		var block := MeshInstance3D.new()
		block.mesh = Lowpoly.rock(rng, rock.lerp(dark, rng.randf_range(0.0, 0.3)), 0.5, Vector3(1.0, 0.82, 0.95))
		block.material_override = _rock
		block.scale = Vector3.ONE * size
		## Bedded into the floor rather than balanced on it: a block of rock that has fallen
		## sits in the ground it landed in.
		block.position = Vector3(lie.at) + Vector3(0.0, _floor_at(lie.at) + size * 0.64, 0.0)
		block.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf() * TAU, rng.randf_range(-0.22, 0.22))
		add_child(block)
		## A shoulder of smaller rock leaning on it, so no block is a lone egg on the floor.
		for lean in range(2):
			var shoulder := MeshInstance3D.new()
			shoulder.mesh = Lowpoly.rock(rng, rock.lerp(dark, 0.35), 0.46, Vector3(1.0, 0.7, 1.0))
			shoulder.material_override = _rock
			var small: float = size * rng.randf_range(0.34, 0.52)
			shoulder.scale = Vector3.ONE * small
			var angle: float = rng.randf() * TAU
			var beside := Vector3(cos(angle) * size * 0.95, 0.0, sin(angle) * size * 0.95)
			shoulder.position = Vector3(lie.at) + beside + Vector3(0.0, _floor_at(Vector3(lie.at) + beside) + small * 0.5, 0.0)
			shoulder.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
			add_child(shoulder)

func _foot(biome: Dictionary, rng: RandomNumberGenerator) -> void:
	## Chips and splinters lying between the blocks, so they read as rock that came down
	## rather than props set out on the floor.
	for i in range(16):
		var scale: float = rng.randf_range(0.14, 0.34)
		var chip := MeshInstance3D.new()
		chip.mesh = Lowpoly.rock(rng, Color(biome.rock).lightened(0.06), 0.42, Vector3(1.0, 0.7, 1.0))
		chip.material_override = _rock
		chip.scale = Vector3.ONE * scale
		var lie: Dictionary = SPOTS[i % SPOTS.size()]
		var beside := Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.2, 1.5))
		chip.position = Vector3(lie.at) + beside + Vector3(0.0, _floor_at(Vector3(lie.at) + beside) + scale * 0.3, 0.0)
		chip.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		add_child(chip)

func _glowing(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color.lightened(0.1)
	m.roughness = 0.15
	m.metallic = 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func spot_point(index: int) -> Vector3:
	## The seam in a boulder's near face, in this node's space: where the pick goes in.
	var lie: Dictionary = _lie(index)
	var size: float = float(lie.size)
	return Vector3(lie.at) + Vector3(0.0, _floor_at(lie.at) + size * 0.78, size * 0.78)

func _nodule(index: int, glint: String, rng: RandomNumberGenerator) -> Dictionary:
	var holder := Node3D.new()
	holder.position = spot_point(index)
	add_child(holder)
	var tone: Color = TONES.get(glint, TONES.dull)
	var lump := MeshInstance3D.new()
	lump.mesh = Lowpoly.rock(rng, Color("6a5a4a").lerp(tone, 0.15), 0.32, Vector3(1.0, 0.85, 0.6))
	lump.material_override = _rock
	lump.scale = Vector3.ONE * 0.46
	holder.add_child(lump)
	var crystals: Array = []
	if glint != "dull":
		for c in range(3 if glint == "bright" else 2):
			var shard := MeshInstance3D.new()
			shard.mesh = Lowpoly.crystal(rng, tone, 0.07, rng.randf_range(0.3, 0.5))
			shard.material_override = _glowing(tone, 1.6 if glint == "bright" else 1.0)
			shard.position = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.12, 0.2), 0.18)
			shard.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.6, 0.3), 0, rng.randf_range(-0.8, 0.8))
			holder.add_child(shard)
			crystals.append(shard)
	var sparks: Array = []
	for s in range(int(SPARKS.get(glint, 2))):
		var spark := Sprite3D.new()
		spark.texture = DeepUi.glow_texture()
		spark.shaded = false
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.pixel_size = (0.22 if glint != "dull" else 0.12) / 64.0
		spark.modulate = Color(tone.lightened(0.4), 0.0)
		spark.position = Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.35, 0.4), 0.3)
		holder.add_child(spark)
		sparks.append({"node": spark, "phase": rng.randf() * TAU, "rate": rng.randf_range(1.5, 3.5)})
	var light := OmniLight3D.new()
	light.light_color = tone
	light.light_energy = 0.9 if glint == "bright" else (0.45 if glint == "glint" else 0.0)
	light.omni_range = 1.8
	light.position = Vector3(0, 0, 0.6)
	light.shadow_enabled = false
	holder.add_child(light)
	return {"holder": holder, "lump": lump, "crystals": crystals, "sparks": sparks, "light": light, "glint": glint, "base": light.light_energy,
		"hover": false, "open": true, "taken": false, "hole": null}

func spot_node(index: int) -> Node3D:
	return _spots[index].holder if index >= 0 and index < _spots.size() else null

func collapse(fx: Node3D) -> float:
	## The rock is spent: it settles into the floor in its own dust and the way on is clear.
	## Returns how long it takes.
	var seconds: float = 1.1
	if fx != null and is_instance_valid(fx):
		for lie in SPOTS:
			fx.puff(global_position + Vector3(lie.at) + Vector3(0, 0.8, 0.6), Color("8a7a66"), 10, 1.4, 2.0, 0.5)
		fx.shards(global_position + Vector3(0, 1.4, 0.8), Color("8d8479"), 14, 3.5, 0.16, 1.2)
	DeepAudio.play("crumble", {"volume": 0.9})
	DeepAudio.play("cave_rumble", {"volume": 0.5})
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - HEIGHT - 0.6, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation:x", -0.12, seconds)
	tween.chain().tween_callback(queue_free)
	return seconds * 0.8

func set_open(index: int, open: bool) -> void:
	## Whether the party's pick can still go in here: a closed spot's sparkle goes dim.
	if index >= 0 and index < _spots.size():
		_spots[index].open = open

func set_hover(index: int) -> void:
	for i in range(_spots.size()):
		_spots[i].hover = i == index

func is_taken(index: int) -> bool:
	return index >= 0 and index < _spots.size() and bool(_spots[index].taken)

func hollow(index: int, finder: Color) -> void:
	## A struck spot: the lump is gone, and a hole with the finder's color lit inside it.
	if index < 0 or index >= _spots.size() or bool(_spots[index].taken):
		return
	var spot: Dictionary = _spots[index]
	spot.taken = true
	for part in [spot.lump] + spot.crystals:
		if is_instance_valid(part):
			part.queue_free()
	for spark in spot.sparks:
		if is_instance_valid(spark.node):
			spark.node.queue_free()
	spot.sparks = []
	var holder: Node3D = spot.holder
	var hole := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 31 + 7
	hole.mesh = Lowpoly.rock(rng, Color("0c0a09"), 0.25, Vector3(1.0, 0.8, 0.35))
	var dark := StandardMaterial3D.new()
	dark.vertex_color_use_as_albedo = true
	dark.roughness = 1.0
	dark.emission_enabled = true
	dark.emission = finder
	dark.emission_energy_multiplier = 0.25
	hole.material_override = dark
	hole.scale = Vector3.ONE * 0.4
	hole.position = Vector3(0, 0, -0.12)
	holder.add_child(hole)
	spot.hole = hole
	var light: OmniLight3D = spot.light
	light.light_color = finder
	spot.base = 0.7
	spot.glint = "taken"

func strike(index: int, fx: Node3D, heavy: bool) -> Vector3:
	## The pick goes in: the rock bursts, the lump is gone. Returns where the find comes out,
	## in world space.
	if index < 0 or index >= _spots.size():
		return global_position
	var spot: Dictionary = _spots[index]
	var holder: Node3D = spot.holder
	var at: Vector3 = holder.global_position + global_transform.basis.z * 0.3
	var tone: Color = TONES.get(str(spot.glint), TONES.dull)
	if fx != null and is_instance_valid(fx):
		fx.sparks(at, tone.lightened(0.3) if spot.glint != "dull" else Color("ffd8a0"), 40 if heavy else 22, 6.0, 0.6, 0.06)
		fx.shards(at, Color("8d8479"), 10 if heavy else 6, 3.2, 0.12, 1.0)
		fx.puff(at, Color("8a7a66"), 10, 0.9, 1.4, 0.4)
		fx.flash(at, tone, 5.0, 5.0, 0.3, 0.8)
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE * 1.25, 0.06)
	tween.tween_property(holder, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	return at

func _process(delta: float) -> void:
	_clock += delta
	for spot in _spots:
		var lit: float = 1.0 if bool(spot.open) else 0.35
		var hover: float = 1.0 if bool(spot.hover) else 0.0
		var holder: Node3D = spot.holder
		holder.scale = holder.scale.lerp(Vector3.ONE * (1.0 + 0.12 * hover), clampf(delta * 10.0, 0.0, 1.0))
		var light: OmniLight3D = spot.light
		light.light_energy = float(spot.base) * lit * (1.0 + 0.8 * hover) * (0.85 + 0.15 * sin(_clock * 2.0))
		for spark in spot.sparks:
			var twinkle: float = maxf(0.0, sin(_clock * float(spark.rate) + float(spark.phase)))
			(spark.node as Sprite3D).modulate.a = twinkle * lit * (0.55 if str(spot.glint) == "dull" else 1.0) * (1.0 + hover * 0.5)
