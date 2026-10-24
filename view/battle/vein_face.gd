extends Node3D
## A vein: six boulders of the rock strewn across the floor of the room, each with one place
## to put a pick in it. Each shows what it gives away: a bright one sparkles hard and has
## gold crystal breaking through, a glint shows a little blue, dull rock shows almost
## nothing. A struck boulder is a hole with its finder's color lit inside it.
##
## A motherlode has the six and a few rich seams besides, laid out again for the room (LODE):
## the six a cluster through the middle, the rich seams round about them, and every rock set
## so that the party sees its seam past every other rock and it hides none of theirs
## (`seam_clear` says so of any spot). Small rock in front and big rock behind does most of
## it: the eye looks down over the near rows to the seams of the far ones. The smaller rock
## leaning on the blocks and lying between them keeps off those lines too.
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
## Where each boulder lies and how big it is, left to right across the room. No two are the
## same size: a row of matching lumps is a grid again. Laid out against the view from where
## the party stands (VIEW) so that no boulder stands in front of another one's seam: each
## back boulder is seen past the edge of the near ones, or over their tops.
const SPOTS: Array = [
	{"at": Vector3(-5.4, 0.0, -0.6), "size": 1.45},
	{"at": Vector3(-2.5, 0.0, 2.2), "size": 0.9},
	{"at": Vector3(-1.8, 0.0, -2.8), "size": 1.2},
	{"at": Vector3(0.9, 0.0, -2.9), "size": 1.0},
	{"at": Vector3(2.4, 0.0, 1.7), "size": 1.3},
	{"at": Vector3(5.8, 0.0, 0.4), "size": 0.86}]
## Fewer spots than six: these of the six, set out across the middle of the room.
const FEW: Dictionary = {1: [3], 2: [1, 4], 3: [1, 3, 4], 4: [0, 1, 3, 4], 5: [0, 1, 2, 3, 4]}
## A motherlode's rocks: the six first, then its five rich seams, of which it has as many as
## the rock does. Three rows: small blocks in front, the six's middle pair and the rich
## seams' flanks across the middle, and the biggest at the back, where the eye looks down
## over everything nearer to their seams. Found by search (build/lode_search.gd) and checked
## by tests/test_view.gd: every seam seen clear of every other rock, whatever the seed.
## A lie's `bed` is how deep it sits in the floor (less is deeper: the near rows are sunk, so
## nothing of them reaches the lines over them) and `aim` how high up its face the seam is
## (the big back rocks carry theirs high, up out of the way of the middle row).
const LODE: Array = [
	{"at": Vector3(-2.5, 0.0, -5.2), "size": 1.32, "aim": 0.78},
	{"at": Vector3(2.6, 0.0, -5.0), "size": 1.28, "aim": 0.78},
	{"at": Vector3(-1.9, 0.0, -0.6), "size": 0.66, "bed": 0.5},
	{"at": Vector3(2.0, 0.0, -0.4), "size": 0.64, "bed": 0.5},
	{"at": Vector3(-4.6, 0.0, 2.3), "size": 0.54, "bed": 0.42},
	{"at": Vector3(4.8, 0.0, 2.2), "size": 0.52, "bed": 0.42},
	{"at": Vector3(-8.0, 0.0, -5.4), "size": 1.45, "aim": 0.78},
	{"at": Vector3(8.0, 0.0, -5.2), "size": 1.4, "aim": 0.78},
	{"at": Vector3(-6.3, 0.0, -0.6), "size": 0.68, "bed": 0.5},
	{"at": Vector3(6.4, 0.0, -0.3), "size": 0.66, "bed": 0.5},
	{"at": Vector3(1.7, 0.0, 2.7), "size": 0.5, "bed": 0.42}]
## Where the party stands to look at the vein, in this node's space (the stage's home, seen
## from where the vein is set down in the room).
const VIEW := Vector3(0.0, 2.1, 10.5)
const TONES: Dictionary = {"rich": Color("fff1a6"), "bright": Color("ffcf5a"), "glint": Color("8fd0ff"), "dull": Color("a09080")}
const SPARKS: Dictionary = {"rich": 14, "bright": 9, "glint": 5, "dull": 2}
const CRYSTALS: Dictionary = {"rich": 5, "bright": 3, "glint": 2, "dull": 0}

var hazard: bool = false
## Whether the smaller rock is laid: a search for a layout of the blocks can do without it.
var rubble: bool = true
var _rock: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _spots: Array = []
## Each boulder, and where its seam was found on its near face.
var _blocks: Array = []
var _points: Array = []
## The smaller rock: the shoulders leaning on the blocks and the chips lying between them.
var _rubble: Array = []
var _clock: float = 0.0
## The places this outcrop has rocks at: the six of a vein, and a motherlode's rich seams
## after them, each {at, size}.
var _layout: Array = SPOTS
## The room's own floor, so no block of rock is left hanging in the air over a dip in it.
var _ground: Callable = Callable()

func build(biome: Dictionary, spots: Array, seed_value: int, is_hazard: bool, ground: Callable = Callable(), layout: Array = []) -> void:
	## `layout` lays the rocks out as given ({at, size} a spot) instead of as the count of
	## spots decides: the search for LODE uses it.
	hazard = is_hazard
	_ground = ground
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.6
	_layout = []
	if not layout.is_empty():
		for lie in layout:
			_layout.append(lie)
	elif spots.size() < SPOTS.size():
		for at in FEW.get(spots.size(), []):
			_layout.append(SPOTS[int(at)])
	elif spots.size() == SPOTS.size():
		for lie in SPOTS:
			_layout.append(lie)
	else:
		## A motherlode: the six laid out again to leave its rich seams room, and as many of
		## those as the rock has, which of the five being the room's own choice.
		for lie in LODE.slice(0, SPOTS.size()):
			_layout.append(lie)
		var seams: Array = LODE.slice(SPOTS.size())
		for n in range(seams.size() - 1, 0, -1):
			var swap: int = rng.randi_range(0, n)
			var held: Dictionary = seams[n]
			seams[n] = seams[swap]
			seams[swap] = held
		for lie in seams.slice(0, spots.size() - SPOTS.size()):
			_layout.append(lie)
	## More spots than places (nothing digs so many): the rest against the far wall.
	while _layout.size() < spots.size():
		var nth: int = _layout.size() - LODE.size()
		_layout.append({"at": Vector3(9.0 * (1.0 if nth % 2 == 0 else -1.0), 0.0, -7.0 + float(nth) * 1.5), "size": 1.0})
	_rock = StandardMaterial3D.new()
	_rock.vertex_color_use_as_albedo = true
	_rock.roughness = 0.85
	var rock: Color = Color(biome.rock).lightened(0.12)
	var dark: Color = Color(biome.rock_dark)
	for lie in _layout:
		_bed(_block(rng, rock, dark, float(lie.size)), lie)
	if rubble:
		_shoulders(rock, dark, rng)
		_foot(biome, rng)
	## A work lamp hung over the scatter, so the rock can be read; a motherlode's reaches
	## the seams out by the walls.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(biome.key).lerp(Color("ffd9a8"), 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 13.0 if _layout.size() <= SPOTS.size() else 16.0
	lamp.position = Vector3(0.0, 4.6, 2.4)
	lamp.shadow_enabled = false
	add_child(lamp)
	for index in range(_layout.size()):
		var spot: Dictionary = spots[index] if index < spots.size() else {"glint": "dull"}
		_spots.append(_nodule(index, str(spot.get("glint", "dull")), rng))

func layout() -> Array:
	## Where the rocks lie, each {at, size} in this node's space, in the order of the spots.
	return _layout.duplicate(true)

func _lie(index: int) -> Dictionary:
	return _layout[clampi(index, 0, _layout.size() - 1)] if not _layout.is_empty() else SPOTS[0]

func _floor_at(at: Vector3) -> float:
	## How high the room's floor is under a point, in this node's own space.
	if not _ground.is_valid():
		return 0.0
	return float(_ground.call(position.x + at.x, position.z + at.z)) - position.y

func _rest(lie: Dictionary) -> Vector3:
	## Where a block lies at its place on the floor: bedded into it rather than balanced on
	## it, because a block of rock that has fallen sits in the ground it landed in, and as
	## deep as its lie says (`bed`, in its own size).
	var at: Vector3 = lie.at
	return at + Vector3(0.0, _floor_at(at) + float(lie.size) * float(lie.get("bed", 0.64)), 0.0)

func _block(rng: RandomNumberGenerator, rock: Color, dark: Color, size: float) -> MeshInstance3D:
	## One block of rock, its own shape and size and turned its own way, not yet put anywhere.
	var block := MeshInstance3D.new()
	block.mesh = Lowpoly.rock(rng, rock.lerp(dark, rng.randf_range(0.0, 0.3)), 0.5, Vector3(1.0, 0.82, 0.95))
	block.material_override = _rock
	block.scale = Vector3.ONE * size
	block.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf() * TAU, rng.randf_range(-0.22, 0.22))
	return block

func _bed(block: MeshInstance3D, lie: Dictionary) -> void:
	## Sets a block down at its place and finds its seam.
	block.position = _rest(lie)
	add_child(block)
	_blocks.append(block)
	_points.append(_seam_of(block, lie))

func _in_face(piece: Node3D) -> Transform3D:
	## A piece's transform in this node's space, wherever it hangs under it (or nowhere yet).
	var xform: Transform3D = piece.transform
	var up: Node = piece.get_parent()
	while up != null and up != self and up is Node3D:
		xform = (up as Node3D).transform * xform
		up = up.get_parent()
	return xform

func _hit(piece: MeshInstance3D, toward: Vector3) -> float:
	## How far from the party's eye a line from it meets this rock, or INF. A rock nowhere near
	## the line is known for one by its reach, without a look at its faces.
	var xform: Transform3D = _in_face(piece)
	var reach: float = float(piece.get_meta("reach", 0.0))
	if reach <= 0.0:
		var box: AABB = piece.mesh.get_aabb()
		reach = Vector3(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.y), absf(box.end.y)),
			maxf(absf(box.position.z), absf(box.end.z))).length()
		piece.set_meta("reach", reach)
	var scale: Vector3 = xform.basis.get_scale()
	reach *= maxf(scale.x, maxf(scale.y, scale.z))
	var along: float = (xform.origin - VIEW).dot(toward)
	if along < -reach or (VIEW + toward * maxf(along, 0.0)).distance_to(xform.origin) > reach + 0.01:
		return INF
	var faces: PackedVector3Array = piece.mesh.get_faces()
	var nearest: float = INF
	for i in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(VIEW, toward, xform * faces[i], xform * faces[i + 1], xform * faces[i + 2])
		if hit != null:
			nearest = minf(nearest, VIEW.distance_to(hit))
	return nearest

func _clear(to: Vector3, rocks: Array, spheres: Array) -> bool:
	## Whether the line from the party's eye to a point meets none of these rocks and none of
	## these spheres ({at, r}) on the way there.
	var toward: Vector3 = to - VIEW
	var length: float = toward.length()
	if length <= 0.001:
		return true
	toward /= length
	for rock in rocks:
		if _hit(rock, toward) < length - 0.05:
			return false
	for sphere in spheres:
		var along: float = clampf((Vector3(sphere.at) - VIEW).dot(toward), 0.0, length - 0.05)
		if (VIEW + toward * along).distance_to(Vector3(sphere.at)) < float(sphere.r):
			return false
	return true

func seam_clear(index: int) -> bool:
	## Whether the party sees this spot's seam past every other rock on the floor: no other
	## block, no shoulder or chip, and no other seam's lump stands on the line from where
	## they look to it.
	if index < 0 or index >= _points.size():
		return false
	var rocks: Array = []
	for i in range(_blocks.size()):
		if i != index:
			rocks.append(_blocks[i])
	rocks.append_array(_rubble)
	for i in range(_spots.size()):
		if i != index and is_instance_valid(_spots[i].lump):
			rocks.append(_spots[i].lump)
	return _clear(_points[index], rocks, [])

func _settle(piece: MeshInstance3D, tries: int, place: Callable) -> bool:
	## Finds a piece of smaller rock a place off the line to every seam, trying so many that
	## `place` offers. False when none of them was.
	for _try in range(tries):
		piece.position = place.call()
		if _points.all(func(point: Vector3) -> bool: return _clear(point, [piece], [])):
			return true
	return false

func _shoulders(rock: Color, dark: Color, rng: RandomNumberGenerator) -> void:
	## A shoulder of smaller rock or two leaning on each block, so no block is a lone egg on
	## the floor. Behind it or to its sides, never in front where the seam is, and never on
	## the line to anybody's seam: drawn again until it is off them all, or left out.
	for lie in _layout:
		var size: float = float(lie.size)
		for _lean in range(2):
			var shoulder := MeshInstance3D.new()
			shoulder.mesh = Lowpoly.rock(rng, rock.lerp(dark, 0.35), 0.46, Vector3(1.0, 0.7, 1.0))
			shoulder.material_override = _rock
			var small: float = size * rng.randf_range(0.34, 0.52)
			shoulder.scale = Vector3.ONE * small
			shoulder.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
			var lean := func() -> Vector3:
				var angle: float = rng.randf_range(PI * 0.95, TAU + PI * 0.05)
				var beside := Vector3(cos(angle) * size * 0.95, 0.0, sin(angle) * size * 0.95)
				return Vector3(lie.at) + beside + Vector3(0.0, _floor_at(Vector3(lie.at) + beside) + small * 0.5, 0.0)
			if _settle(shoulder, 8, lean):
				add_child(shoulder)
				_rubble.append(shoulder)
			else:
				shoulder.free()

func _foot(biome: Dictionary, rng: RandomNumberGenerator) -> void:
	## Chips and splinters lying between the blocks, so they read as rock that came down
	## rather than props set out on the floor. Off the line to every seam, like the shoulders.
	for i in range(16 if not _layout.is_empty() else 0):
		var scale: float = rng.randf_range(0.14, 0.34)
		var chip := MeshInstance3D.new()
		chip.mesh = Lowpoly.rock(rng, Color(biome.rock).lightened(0.06), 0.42, Vector3(1.0, 0.7, 1.0))
		chip.material_override = _rock
		chip.scale = Vector3.ONE * scale
		chip.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		var lie: Dictionary = _layout[i % _layout.size()]
		var lying := func() -> Vector3:
			var beside := Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.2, 1.5))
			return Vector3(lie.at) + beside + Vector3(0.0, _floor_at(Vector3(lie.at) + beside) + scale * 0.3, 0.0)
		if _settle(chip, 6, lying):
			add_child(chip)
			_rubble.append(chip)
		else:
			chip.free()

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
	if index >= 0 and index < _points.size():
		return _points[index]
	var lie: Dictionary = _lie(index)
	var size: float = float(lie.size)
	return Vector3(lie.at) + Vector3(0.0, _floor_at(lie.at) + size * 0.78, size * 0.78)

func _seam_of(block: MeshInstance3D, lie: Dictionary) -> Vector3:
	## Where a line from the party's eye to the middle of a boulder first meets that boulder:
	## the seam sits on the face actually turned to them, a hand's width proud of it, so no
	## bulge of its own rock can stand in front of it.
	var size: float = float(lie.size)
	var aim: Vector3 = Vector3(lie.at) + Vector3(0.0, _floor_at(lie.at) + size * float(lie.get("aim", 0.72)), 0.0)
	var toward: Vector3 = (aim - VIEW).normalized()
	var nearest: float = _hit(block, toward)
	if nearest == INF:
		return Vector3(lie.at) + Vector3(0.0, _floor_at(lie.at) + size * 0.78, size * 0.78)
	return VIEW + toward * (nearest - 0.12)

func _nodule(index: int, glint: String, rng: RandomNumberGenerator) -> Dictionary:
	var holder := Node3D.new()
	holder.position = spot_point(index)
	add_child(holder)
	var tone: Color = TONES.get(glint, TONES.dull)
	var rich: bool = glint == "rich"
	## The lump and its crystal keep in proportion to the rock they are in: a motherlode's
	## near rocks are small.
	var fit: float = clampf(float(_lie(index).size) / 0.86, 0.6, 1.0)
	var lump := MeshInstance3D.new()
	lump.mesh = Lowpoly.rock(rng, Color("6a5a4a").lerp(tone, 0.3 if rich else 0.15), 0.32, Vector3(1.0, 0.85, 0.6))
	lump.material_override = _rock
	lump.scale = Vector3.ONE * 0.46 * fit
	holder.add_child(lump)
	var crystals: Array = []
	## The crystal breaking through: a rich seam's is bigger, more of it, and lit harder.
	for c in range(int(CRYSTALS.get(glint, 0))):
		var shard := MeshInstance3D.new()
		shard.mesh = Lowpoly.crystal(rng, tone, (0.09 if rich else 0.07) * fit, (rng.randf_range(0.4, 0.62) if rich else rng.randf_range(0.3, 0.5)) * fit)
		shard.material_override = _glowing(tone, 2.4 if rich else (1.6 if glint == "bright" else 1.0))
		var spread: float = (0.24 if rich else 0.2) * fit
		shard.position = Vector3(rng.randf_range(-spread, spread), rng.randf_range(-0.12, 0.2) * fit, 0.18 * fit)
		shard.rotation = Vector3(PI * 0.5 + rng.randf_range(-0.6, 0.3), 0, rng.randf_range(-0.8, 0.8))
		holder.add_child(shard)
		crystals.append(shard)
	var sparks: Array = []
	for s in range(int(SPARKS.get(glint, 2))):
		var spark := Sprite3D.new()
		spark.texture = DeepUi.glow_texture()
		spark.shaded = false
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.pixel_size = (0.26 if rich else (0.22 if glint != "dull" else 0.12)) / 64.0
		spark.modulate = Color(tone.lightened(0.4), 0.0)
		var wide: float = 0.5 if rich else 0.45
		spark.position = Vector3(rng.randf_range(-wide, wide), rng.randf_range(-0.35, 0.4), 0.3)
		holder.add_child(spark)
		sparks.append({"node": spark, "phase": rng.randf() * TAU, "rate": rng.randf_range(1.5, 3.5)})
	var light := OmniLight3D.new()
	light.light_color = tone
	light.light_energy = 1.5 if rich else (0.9 if glint == "bright" else (0.45 if glint == "glint" else 0.0))
	light.omni_range = 2.6 if rich else 1.8
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
		for lie in _layout:
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
