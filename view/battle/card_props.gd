extends Node3D
## The furniture of a card room, standing where a plinth and a floating mark used to: the
## Smithy's forge, anvil and rack of files, the Carver's bench under its lamp, the Rest Stop's
## bench, cold stove and supply box, the Annealing Oven and the Cutter's Wheel. A flat white
## glyph hung over a column read as a room nobody had finished; the well, the stall and the
## landing all had the real thing. A card with no furniture of its own keeps the plinth
## (MineStage.shrine), and every card keeps its mark on the medallion over its name.
##
## Built facing +z, toward where the party stands, at life size inside a body the stage stands
## bigger than life, as it does the well: a forge at life size, seen across the room over a row
## of cards, is a toy. Every part of one material is cut into one mesh, so a whole forge is a
## handful of draws. The lights hang outside the scaled body, so their reach is in room units.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

## The cards with furniture of their own: the three rooms that are cards, which come up far
## more often than any one oddity does, and two oddities that are a machine in the rock.
const FURNISHED: Array = ["SMITHY", "CARVER", "FIELD_MEDIC", "ANNEALING_OVEN", "CUTTERS_WHEEL"]
## How much bigger than life each room's furniture stands. A room of one piece stands it
## bigger, to fill the same part of the room as three.
const SCALE: Dictionary = {"SMITHY": 1.75, "CARVER": 2.15, "FIELD_MEDIC": 1.75, "ANNEALING_OVEN": 1.75, "CUTTERS_WHEEL": 1.8}
## How far either side of the middle each one reaches at life size, so the party walks round it.
const HALF_WIDTH: Dictionary = {"SMITHY": 2.7, "CARVER": 1.3, "FIELD_MEDIC": 2.45, "ANNEALING_OVEN": 1.8, "CUTTERS_WHEEL": 1.85}

## A box's six faces as corner indices (x fastest, then y, then z) and the side each faces.
const BOX_FACES: Array = [[0, 1, 3, 2, Vector3(0, 0, -1)], [4, 6, 7, 5, Vector3(0, 0, 1)], [0, 4, 5, 1, Vector3(0, -1, 0)],
	[2, 3, 7, 6, Vector3(0, 1, 0)], [0, 2, 6, 4, Vector3(-1, 0, 0)], [1, 5, 7, 3, Vector3(1, 0, 0)]]

const WOOD := Color("6b4a30")
const WOOD_LIGHT := Color("94683e")
const WOOD_DARK := Color("43301f")
const IRON := Color("3b3a3d")
const STEEL := Color("8e959e")
const BRICK := Color("8a4a33")
const COAL := Color("ff8a3a")

var card: String = ""
## The scaled body every mesh hangs in.
var body: Node3D
var _rng := RandomNumberGenerator.new()
var _surfaces: Dictionary = {}
var _ground: Callable = Callable()
var _scale: float = 1.0
## Lights that are never quite still: {light, energy, speed, depth}.
var _flickers: Array = []
## Parts that turn: {node, axis, speed}.
var _spinners: Array = []
var _clock: float = 0.0

static func furnished(key: String) -> bool:
	return FURNISHED.has(key)

static func half_width(key: String) -> float:
	## In room units.
	return float(HALF_WIDTH.get(key, 1.0)) * float(SCALE.get(key, 1.0))

func build(key: String, seed_value: int, tone: Color, ground: Callable = Callable()) -> void:
	## `ground(x, z)` is the floor's height at a point of the room. Set `position` first: each
	## piece stands its own feet on the floor under it.
	card = key
	_rng.seed = seed_value
	_ground = ground
	_scale = float(SCALE.get(key, 1.0))
	body = Node3D.new()
	body.scale = Vector3.ONE * _scale
	add_child(body)
	match key:
		"SMITHY": _build_smithy(tone)
		"CARVER": _build_carver(tone)
		"FIELD_MEDIC": _build_rest_stop(tone)
		"ANNEALING_OVEN": _build_oven(tone)
		"CUTTERS_WHEEL": _build_wheel(tone)
	_commit(body)

func _commit(into: Node3D) -> void:
	## Everything cut so far, one mesh per material, hung in `into`.
	for surface_key in _surfaces:
		var node := MeshInstance3D.new()
		node.mesh = (_surfaces[surface_key] as SurfaceTool).commit()
		node.material_override = _material(str(surface_key))
		into.add_child(node)
	_surfaces.clear()

func _process(delta: float) -> void:
	_clock += delta
	for entry in _flickers:
		var light: Light3D = entry.light
		var speed: float = float(entry.speed)
		var flicker: float = sin(_clock * 9.0 * speed) * 0.5 + sin(_clock * 13.7 * speed) * 0.3 + sin(_clock * 23.0 * speed) * 0.2
		light.light_energy = float(entry.energy) * (1.0 + float(entry.depth) * flicker)
	for entry in _spinners:
		(entry.node as Node3D).rotate_object_local(entry.axis, float(entry.speed) * delta)

# --- the rooms -------------------------------------------------------------------------------------

func _build_smithy(tone: Color) -> void:
	## The forge on the left with its coals alight under the hood, the anvil in the middle on
	## its stump with a die on its face, the quench bucket at its foot, and the rack of files on
	## the right. Spread across the view, so none of it stands behind another piece.
	_forge(Vector3(-1.6, 0.0, -0.3))
	_anvil(Vector3(0.25, 0.0, 0.35), -0.32)
	_bucket(Vector3(1.15, 0.0, 0.8))
	_file_rack(Vector3(2.0, 0.0, -0.4))
	_work_light(tone, Vector3(0.0, 0.9, 0.2), 0.25)

func _build_carver(tone: Color) -> void:
	## A long bench with a lamp bent over it: a die waiting under the lamp, the chisels laid out
	## on their roll and a cup of etching needles at the end.
	_bench_table(Vector3(0.0, 0.0, 0.0))
	## Its own lamp does most of the lighting, so the shaft from above is gentler.
	_work_light(tone, Vector3(0.0, 0.95, 0.0), 0.15, 1.8)

func _build_rest_stop(tone: Color) -> void:
	## A plank bench with a blanket folded on it, the stove gone cold with its kettle, and the
	## supply box somebody left, its lid off and a lamp still burning on it.
	_rest_bench(Vector3(-1.55, 0.0, 0.25))
	_stove(Vector3(0.25, 0.0, -0.35))
	_supply_box(Vector3(1.6, 0.0, 0.35))
	_work_light(tone, Vector3(0.0, 0.6, 0.1), 0.2)

func _build_oven(tone: Color) -> void:
	## A brick oven with a domed top, its mouth glowing low and a gauge over it; split wood
	## stacked at its side and a tray of stones cooling on a stand.
	_oven(Vector3(-0.25, 0.0, -0.2))
	_woodpile(Vector3(-1.45, 0.0, 0.3))
	_cooling_stand(Vector3(1.3, 0.0, 0.35))
	_work_light(tone, Vector3(0.0, 0.9, 0.0), 0.2, 1.8)

func _build_wheel(tone: Color) -> void:
	## The wheel turning on its frame with a stone laid against it, and a small table beside it
	## with stones on their sticks and stones already cut.
	_grindstone(Vector3(0.35, 0.0, -0.1))
	_cut_table(Vector3(-1.3, 0.0, 0.25))
	_work_light(tone, Vector3(0.0, 0.9, 0.0), 0.2, 1.7)

# --- the smithy's pieces ---------------------------------------------------------------------------

func _forge(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(), Vector3(at.x, foot, at.z))
	var width: float = 1.5
	var height: float = 0.9
	var depth: float = 1.05
	_bricks(base, Vector3(width, height, depth), 6, 1.0)
	## The hearth: a stone lip, a bed of coals in it, some still black and most of them alight.
	_box("stone", base, Vector3(0, height + 0.04, 0), Vector3(width + 0.1, 0.08, depth + 0.08), Color("6a5e54"), 0.01)
	_box("stone", base, Vector3(0, height + 0.06, 0), Vector3(width - 0.32, 0.06, depth - 0.34), Color("1c1714"))
	for index in range(16):
		var spot := Vector3(_rng.randf_range(-0.5, 0.5), height + 0.12, _rng.randf_range(-0.28, 0.28))
		var lit: bool = index % 4 != 0
		_lump("coal" if lit else "stone", base, spot, _rng.randf_range(0.06, 0.1), Color("2a2420") if not lit else COAL, Vector3(1.0, 0.6, 1.0))
	var flames: Node3D = BattleFx.fire(0.32, false)
	flames.position = _scaled(base * Vector3(0, height + 0.12, 0))
	add_child(flames)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff8a3c")
	glow.omni_range = 5.0
	glow.light_volumetric_fog_energy = 0.8
	glow.shadow_enabled = false
	glow.position = _scaled(base * Vector3(0.15, height + 0.55, 0.45))
	add_child(glow)
	_flickers.append({"light": glow, "energy": 2.6, "speed": 0.8, "depth": 0.16})
	## The hood over it on two irons from the back corners, and the flue up into the dark.
	var hood_low: float = height + 0.72
	_frustum("iron", base * Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.7)), Vector3(0, hood_low, -0.08)), 4, 0.98, 0.3, 0.42, IRON.lightened(0.08), PI * 0.25, false, false)
	_box("iron", base, Vector3(0, hood_low + 0.03, -0.08), Vector3(1.42, 0.06, 1.0), IRON.lightened(0.15))
	_box("iron", base, Vector3(0, hood_low + 0.42 + 0.7, -0.08), Vector3(0.32, 1.4, 0.32), IRON, 0.01)
	for side in [-1.0, 1.0]:
		_box("iron", base, Vector3(side * 0.62, (height + hood_low) * 0.5 + 0.04, -0.4), Vector3(0.05, hood_low - height, 0.05), IRON)
	## A heap of fuel at its foot.
	for index in range(6):
		var spot := Vector3(width * 0.5 + _rng.randf_range(0.08, 0.38), 0.05, depth * 0.5 - _rng.randf_range(0.0, 0.5))
		_lump("stone", base, spot, _rng.randf_range(0.07, 0.11), Color("26211e"), Vector3(1.0, 0.7, 1.0))

func _anvil(at: Vector3, turn: float) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, turn), Vector3(at.x, foot, at.z))
	## The stump it is spiked to, bark round it and the end grain on top.
	var stump: float = 0.6
	_frustum("wood", base, 9, 0.34, 0.3, stump, WOOD_DARK, 0.0, true, false, WOOD_LIGHT)
	## The anvil from the side, pushed out to its width: a flat face, the heel, a horn that
	## tapers to a point both ways, a narrow waist and a flared foot.
	var profile := PackedVector2Array([Vector2(-0.28, 0.0), Vector2(0.24, 0.0), Vector2(0.17, 0.08), Vector2(0.1, 0.13),
		Vector2(0.17, 0.24), Vector2(0.32, 0.29), Vector2(0.6, 0.37), Vector2(0.27, 0.44), Vector2(-0.38, 0.44),
		Vector2(-0.38, 0.34), Vector2(-0.21, 0.27), Vector2(-0.13, 0.13), Vector2(-0.21, 0.08)])
	var depths := PackedFloat32Array([0.15, 0.15, 0.13, 0.08, 0.1, 0.075, 0.012, 0.1, 0.1, 0.1, 0.095, 0.08, 0.13])
	var anvil_at := base * Transform3D(Basis(), Vector3(0.03, stump, 0.0))
	_extrude("iron", anvil_at, profile, depths, IRON.lightened(0.05))
	## The face is worn bright where the hammer lands.
	_box("steel", anvil_at, Vector3(-0.05, 0.445, 0.0), Vector3(0.5, 0.012, 0.17), STEEL.darkened(0.15))
	## The hammer across the heel, its handle out over the edge toward the party.
	_box("iron", anvil_at, Vector3(-0.27, 0.48, -0.02), Vector3(0.08, 0.075, 0.2), IRON.darkened(0.1))
	var handle := anvil_at * Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.2, 0.48, 0.14))
	_box("wood", handle, Vector3.ZERO, Vector3(0.04, 0.04, 0.42), WOOD_LIGHT)
	## A die on the face, waiting to be struck bigger.
	_die(_scaled(anvil_at * Vector3(0.14, 0.445 + 0.09, 0.0)), 0.18, Vector3(0.0, turn + 0.5, 0.0))

func _bucket(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(), Vector3(at.x, foot, at.z))
	_frustum("wood", base, 10, 0.21, 0.25, 0.44, WOOD, 0.0, false, true)
	for lift in [0.07, 0.34]:
		_frustum("iron", base * Transform3D(Basis(), Vector3(0, lift, 0)), 10, 0.215 + lift * 0.09 + 0.012, 0.215 + (lift + 0.045) * 0.09 + 0.012, 0.045, IRON, 0.0, false, false)
	## Dark water most of the way up, and the tongs left standing in it.
	_frustum("water", base * Transform3D(Basis(), Vector3(0, 0.37, 0)), 10, 0.24, 0.24, 0.01, Color("1d2a30"), 0.0, true, false)
	for side in [-1.0, 1.0]:
		var leg := base * Transform3D(Basis(Vector3.BACK, side * 0.08 - 0.25), Vector3(side * 0.03 - 0.02, 0.55, 0.0))
		_box("iron", leg, Vector3.ZERO, Vector3(0.025, 0.62, 0.025), IRON)

func _file_rack(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, -0.35), Vector3(at.x, foot, at.z))
	## Two dark posts on splayed feet and a bar across the top, the files hung from it by their
	## handles: bright blades of different lengths, a broad rasp among them and a pair of tongs.
	for side in [-1.0, 1.0]:
		_box("wood", base, Vector3(side * 0.55, 0.8, 0.0), Vector3(0.08, 1.6, 0.08), WOOD_DARK, 0.008)
		_box("wood", base, Vector3(side * 0.55, 0.04, 0.0), Vector3(0.1, 0.08, 0.5), WOOD_DARK, 0.008)
	_box("wood", base, Vector3(0.0, 1.52, 0.0), Vector3(1.32, 0.08, 0.09), WOOD, 0.008)
	var count: int = 6
	for index in range(count):
		var x: float = lerpf(-0.38, 0.38, float(index) / float(count - 1))
		var length: float = [0.62, 0.48, 0.7, 0.55, 0.66, 0.44][index]
		var width: float = 0.09 if index == 2 else 0.055
		var hang := base * Transform3D(Basis(Vector3.BACK, _rng.randf_range(-0.04, 0.04)), Vector3(x, 1.5, 0.07))
		_box("iron", hang, Vector3(0.0, 0.0, -0.03), Vector3(0.02, 0.05, 0.06), IRON)
		_box("wood", hang, Vector3(0.0, -0.1, 0.0), Vector3(0.05, 0.17, 0.05), WOOD_LIGHT)
		var blade := PackedVector2Array([Vector2(-width * 0.5, 0.0), Vector2(-width * 0.22, - length), Vector2(width * 0.22, - length), Vector2(width * 0.5, 0.0)])
		_extrude("steel", hang * Transform3D(Basis(), Vector3(0.0, -0.19, 0.0)), blade, PackedFloat32Array([0.01, 0.006, 0.006, 0.01]), Lowpoly.shade(STEEL.lightened(0.15), _rng, 0.1))
	var tongs := base * Transform3D(Basis(), Vector3(0.48, 1.5, 0.08))
	for side in [-1.0, 1.0]:
		_box("iron", tongs * Transform3D(Basis(Vector3.BACK, side * 0.07), Vector3.ZERO), Vector3(0.0, -0.38, 0.0), Vector3(0.025, 0.76, 0.025), IRON.lightened(0.1))

# --- the carver's bench ----------------------------------------------------------------------------

func _bench_table(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(), Vector3(at.x, foot, at.z))
	var top: float = 0.92
	_box("wood", base, Vector3(0.0, top - 0.04, 0.0), Vector3(2.4, 0.08, 1.0), WOOD_LIGHT, 0.01)
	_box("wood", base, Vector3(0.0, top - 0.13, 0.44), Vector3(2.2, 0.1, 0.05), WOOD, 0.008)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box("wood", base, Vector3(corner.x * 1.08, (top - 0.08) * 0.5, corner.y * 0.4), Vector3(0.1, top - 0.08, 0.1), WOOD, 0.008)
	_box("wood", base, Vector3(0.0, 0.18, 0.0), Vector3(2.1, 0.06, 0.06), WOOD_DARK)
	## Offcuts and shavings under it.
	for index in range(5):
		_box("wood", base * Transform3D(Basis(Vector3.UP, _rng.randf_range(-1.0, 1.0)), Vector3(_rng.randf_range(-0.9, 0.9), 0.02, _rng.randf_range(-0.3, 0.5))),
			Vector3.ZERO, Vector3(_rng.randf_range(0.08, 0.18), 0.04, _rng.randf_range(0.05, 0.09)), WOOD_LIGHT.lightened(0.1))
	## The lamp: a weighted foot, a post, an arm bent out over the work and a shade on its end
	## with the bulb burning in it, throwing a pool of light on the bench. Kept low, so the shade
	## is under the room's name and not behind it.
	var lamp := base * Transform3D(Basis(), Vector3(-0.85, top, -0.25))
	_frustum("iron", lamp, 8, 0.14, 0.11, 0.05, IRON, 0.0, true, false)
	_box("iron", lamp, Vector3(0.0, 0.25, 0.0), Vector3(0.04, 0.46, 0.04), IRON.lightened(0.1))
	var elbow := lamp * Transform3D(Basis(Vector3.BACK, -1.2), Vector3(0.0, 0.46, 0.0))
	_box("iron", elbow, Vector3(0.0, 0.28, 0.0), Vector3(0.035, 0.58, 0.035), IRON.lightened(0.1))
	var head_at: Vector3 = elbow * Vector3(0.0, 0.56, 0.0)
	var shade := Transform3D(Basis(Vector3.BACK, 0.35), head_at)
	_frustum("iron", shade * Transform3D(Basis(), Vector3(0.0, -0.2, 0.0)), 10, 0.21, 0.07, 0.2, Color("4f6a5a"), 0.0, true, false)
	_lump("bulb", shade, Vector3(0.0, -0.16, 0.0), 0.06, Color("fff1d0"))
	var pool := SpotLight3D.new()
	pool.light_color = Color("ffeccc")
	pool.light_energy = 5.5
	pool.spot_range = 4.5
	pool.spot_angle = 48.0
	pool.spot_angle_attenuation = 0.8
	pool.light_volumetric_fog_energy = 0.6
	pool.shadow_enabled = false
	_aim(pool, _scaled(shade * Vector3(0.0, -0.14, 0.0)), _scaled(base * Vector3(0.05, top, 0.12)))
	add_child(pool)
	var bulb := OmniLight3D.new()
	bulb.light_color = Color("ffe2b0")
	bulb.light_energy = 1.4
	bulb.omni_range = 2.6
	bulb.shadow_enabled = false
	bulb.position = _scaled(shade * Vector3(0.0, -0.3, 0.1))
	add_child(bulb)
	_flickers.append({"light": bulb, "energy": 1.4, "speed": 0.3, "depth": 0.04})
	## Under the lamp, a die waiting for the needle.
	_die(_scaled(base * Vector3(-0.25, top + 0.09, 0.12)), 0.18, Vector3(0.0, 0.45, 0.0))
	## A small rack at the far end with the gravers stood in a row in its holes, handles up.
	var rack := base * Transform3D(Basis(Vector3.UP, -0.3), Vector3(0.98, top, -0.28))
	for side in [-1.0, 1.0]:
		_box("wood", rack, Vector3(side * 0.2, 0.16, 0.0), Vector3(0.05, 0.32, 0.05), WOOD)
	_box("wood", rack, Vector3(0.0, 0.28, 0.0), Vector3(0.46, 0.07, 0.07), WOOD_LIGHT.darkened(0.06), 0.005)
	_box("wood", rack, Vector3(0.0, 0.1, 0.0), Vector3(0.42, 0.04, 0.1), WOOD.darkened(0.05), 0.005)
	for index in range(4):
		var x: float = lerpf(-0.13, 0.13, float(index) / 3.0)
		var length: float = 0.14 + 0.04 * float((index * 5) % 3)
		var stood := rack * Transform3D(Basis(Vector3.BACK, _rng.randf_range(-0.06, 0.06)), Vector3(x, 0.28, 0.0))
		_box("steel", stood, Vector3(0.0, - length * 0.5 + 0.04, 0.0), Vector3(0.016, length, 0.016), STEEL.lightened(0.1))
		_box("wood", stood, Vector3(0.0, 0.1, 0.0), Vector3(0.04, 0.12, 0.04), Lowpoly.shade(WOOD_LIGHT, _rng, 0.15))
	## And the mallet laid down beside the die.
	var mallet := base * Transform3D(Basis(Vector3.UP, 0.6), Vector3(-0.55, top + 0.05, 0.28))
	_box("wood", mallet, Vector3(0.0, 0.0, 0.0), Vector3(0.16, 0.1, 0.1), WOOD_LIGHT.lightened(0.08), 0.006)
	_box("wood", mallet, Vector3(0.0, -0.02, 0.17), Vector3(0.035, 0.035, 0.26), WOOD)
	for index in range(7):
		_box("wood", base * Transform3D(Basis(Vector3.UP, _rng.randf_range(-1.5, 1.5)), Vector3(_rng.randf_range(-0.55, 0.05), top + 0.004, _rng.randf_range(-0.05, 0.38))),
			Vector3.ZERO, Vector3(0.05, 0.006, 0.018), Color("e8cfa0"))
	## The chisels on their leather roll, propped up on a block so they face the party: laid
	## flat at nearly the height of the eye, they could not be seen at all.
	var roll := base * Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0.25, top + 0.2, 0.05))
	_box("wood", base, Vector3(0.25, top + 0.18, -0.13), Vector3(0.6, 0.36, 0.1), WOOD_DARK)
	_box("cloth", roll, Vector3.ZERO, Vector3(0.66, 0.014, 0.44), Color("7a3428"), 0.004)
	for index in range(6):
		var x: float = lerpf(-0.26, 0.26, float(index) / 5.0)
		var length: float = 0.13 + 0.035 * float(index % 3)
		var tool_at := roll * Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.05, 0.05)), Vector3(x, 0.025, 0.0))
		_box("wood", tool_at, Vector3(0.0, 0.0, 0.12), Vector3(0.045, 0.04, 0.15), WOOD_LIGHT.lightened(0.08))
		_box("steel", tool_at, Vector3(0.0, -0.006, 0.045 - length * 0.5), Vector3(0.026 if index % 2 == 0 else 0.015, 0.012, length), STEEL.lightened(0.2))
	## The cup of needles beside them.
	var cup := base * Transform3D(Basis(), Vector3(0.7, top, -0.02))
	_frustum("iron", cup, 10, 0.075, 0.09, 0.18, Color("4c5a66"), 0.0, true, false)
	for index in range(6):
		var lean := Basis(Vector3.BACK, _rng.randf_range(-0.28, 0.28)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.2))
		var needle := cup * Transform3D(lean, Vector3(_rng.randf_range(-0.03, 0.03), 0.24, _rng.randf_range(-0.03, 0.03)))
		_box("steel", needle, Vector3.ZERO, Vector3(0.012, 0.26, 0.012), STEEL.lightened(0.2))
		_box("wood", needle, Vector3(0.0, 0.08, 0.0), Vector3(0.022, 0.08, 0.022), WOOD_LIGHT)
	## A block of rough stock waiting its turn at the near end.
	_box("wood", base * Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.98, top + 0.05, 0.15)), Vector3.ZERO, Vector3(0.16, 0.1, 0.12), WOOD.lightened(0.15), 0.01)

# --- the rest stop ---------------------------------------------------------------------------------

func _rest_bench(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, 0.2), Vector3(at.x, foot, at.z))
	for plank in [-0.11, 0.11]:
		_box("wood", base, Vector3(0.0, 0.46, plank), Vector3(1.6, 0.06, 0.2), WOOD_LIGHT.darkened(0.05), 0.008)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box("wood", base, Vector3(corner.x * 0.66, 0.215, corner.y * 0.14), Vector3(0.08, 0.43, 0.08), WOOD, 0.008)
	_box("wood", base, Vector3(0.0, 0.14, 0.0), Vector3(1.32, 0.05, 0.05), WOOD_DARK)
	## A blanket folded at one end, and a tin cup at the other.
	_box("cloth", base, Vector3(-0.38, 0.54, 0.0), Vector3(0.6, 0.1, 0.38), Color("51654c"), 0.012)
	_box("cloth", base, Vector3(-0.4, 0.62, 0.01), Vector3(0.5, 0.07, 0.34), Color("617a5a"), 0.012)
	_frustum("steel", base * Transform3D(Basis(), Vector3(0.5, 0.49, 0.0)), 8, 0.05, 0.055, 0.1, STEEL.darkened(0.2), 0.0, true, false)

func _stove(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, -0.12), Vector3(at.x, foot, at.z))
	var legs: float = 0.2
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box("iron", base, Vector3(corner.x * 0.28, legs * 0.5, corner.y * 0.24), Vector3(0.07, legs, 0.07), IRON.darkened(0.1))
	_box("iron", base, Vector3(0.0, legs + 0.33, 0.0), Vector3(0.7, 0.66, 0.6), IRON, 0.008)
	_box("iron", base, Vector3(0.0, legs + 0.68, 0.0), Vector3(0.78, 0.05, 0.66), IRON.lightened(0.12), 0.006)
	## Its door shut on cold ash, a handle on it, and the draught shut under it.
	_box("iron", base, Vector3(0.0, legs + 0.36, 0.31), Vector3(0.38, 0.3, 0.025), IRON.darkened(0.25))
	_box("steel", base, Vector3(0.14, legs + 0.36, 0.33), Vector3(0.05, 0.03, 0.03), STEEL)
	_box("iron", base, Vector3(0.0, legs + 0.1, 0.31), Vector3(0.3, 0.06, 0.02), IRON.darkened(0.3))
	## The flue up from the back, and the kettle that will not boil.
	_box("iron", base, Vector3(0.0, legs + 0.7 + 0.9, -0.18), Vector3(0.16, 1.8, 0.16), IRON.lightened(0.04), 0.004)
	var kettle := base * Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.12, legs + 0.705, 0.1))
	_frustum("steel", kettle, 9, 0.15, 0.1, 0.15, Color("6f6a62"), 0.0, true, false)
	_frustum("steel", kettle * Transform3D(Basis(), Vector3(0.0, 0.15, 0.0)), 9, 0.1, 0.04, 0.05, Color("6f6a62"), 0.0, true, false)
	_box("steel", kettle * Transform3D(Basis(Vector3.BACK, -0.75), Vector3(0.17, 0.1, 0.0)), Vector3.ZERO, Vector3(0.035, 0.14, 0.035), Color("6f6a62"))

func _supply_box(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, -0.3), Vector3(at.x, foot, at.z))
	var height: float = 0.52
	_box("wood", base, Vector3(0.0, height * 0.5, 0.0), Vector3(0.84, height, 0.56), WOOD.darkened(0.1))
	## Slats across the front and posts at the corners, so it reads as a crate and not a block.
	for slat in range(3):
		_box("wood", base, Vector3(0.0, 0.09 + float(slat) * 0.17, 0.29), Vector3(0.82, 0.13, 0.025), Lowpoly.shade(WOOD_LIGHT, _rng, 0.1), 0.006)
	for side in [-1.0, 1.0]:
		_box("wood", base, Vector3(side * 0.43, height * 0.5, 0.29), Vector3(0.06, height + 0.02, 0.04), WOOD_DARK)
		_box("wood", base, Vector3(side * 0.43, height * 0.5, -0.28), Vector3(0.06, height + 0.02, 0.04), WOOD_DARK)
	## The lid off and leant against it, and what was left inside showing over the edge.
	var lid := base * Transform3D(Basis(Vector3.RIGHT, -1.25), Vector3(0.0, height - 0.05, -0.36))
	_box("wood", lid, Vector3(0.0, 0.0, 0.29), Vector3(0.86, 0.04, 0.58), WOOD_LIGHT.darkened(0.08), 0.006)
	for index in range(3):
		_frustum("steel", base * Transform3D(Basis(), Vector3(-0.24 + float(index) * 0.16, height - 0.1, 0.02)), 8, 0.06, 0.06, 0.17, Lowpoly.shade(Color("9a8a5a"), _rng, 0.15), 0.0, true, false)
	_frustum("cloth", base * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.24, height + 0.03, -0.07)), 8, 0.07, 0.07, 0.16, Color("e6e0d2"), 0.0, true, true)
	## A sack slumped against its side, tied at the neck.
	_lump("cloth", base, Vector3(0.68, 0.22, 0.12), 0.23, Color("b8a27a"), Vector3(1.0, 1.0, 0.85))
	_frustum("cloth", base * Transform3D(Basis(Vector3.BACK, -0.2), Vector3(0.7, 0.4, 0.12)), 7, 0.11, 0.05, 0.16, Color("a8925f"), 0.0, false, false)
	_lump("cloth", base * Transform3D(Basis(Vector3.BACK, -0.2), Vector3(0.7, 0.4, 0.12)), Vector3(0.0, 0.2, 0.0), 0.07, Color("c4ae84"), Vector3(1.2, 0.7, 1.2))
	## And the lamp somebody left burning on it.
	var lamp := base * Transform3D(Basis(), Vector3(-0.22, height, 0.08))
	_box("iron", lamp, Vector3(0.0, 0.02, 0.0), Vector3(0.16, 0.04, 0.16), IRON)
	_box("bulb", lamp, Vector3(0.0, 0.13, 0.0), Vector3(0.11, 0.18, 0.11), Color("ffcf80"))
	_frustum("iron", lamp * Transform3D(Basis(), Vector3(0.0, 0.22, 0.0)), 4, 0.12, 0.04, 0.07, IRON, PI * 0.25, true, true)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc070")
	light.omni_range = 4.2
	light.shadow_enabled = false
	light.position = _scaled(lamp * Vector3(0.0, 0.2, 0.25))
	add_child(light)
	_flickers.append({"light": light, "energy": 1.8, "speed": 0.6, "depth": 0.08})

# --- the annealing oven ----------------------------------------------------------------------------

func _oven(at: Vector3) -> void:
	var foot: float = _floor(at)
	var base := Transform3D(Basis(), Vector3(at.x, foot, at.z))
	var plinth := Vector3(1.6, 0.62, 1.4)
	_bricks(base, plinth, 4, 1.0)
	_box("stone", base, Vector3(0.0, plinth.y + 0.03, 0.0), Vector3(plinth.x + 0.08, 0.06, plinth.z + 0.08), Color("6a5e54"), 0.01)
	## The dome: rings of brick drawn in to a crown.
	var rings: Array = [[0.72, 0.0], [0.69, 0.2], [0.58, 0.4], [0.38, 0.56], [0.12, 0.64]]
	var dome := base * Transform3D(Basis(), Vector3(0.0, plinth.y + 0.06, -0.05))
	for index in range(rings.size() - 1):
		var low: Array = rings[index]
		var high: Array = rings[index + 1]
		_frustum("brick", dome * Transform3D(Basis(), Vector3(0.0, float(low[1]), 0.0)), 12, float(low[0]), float(high[0]), float(high[1]) - float(low[1]),
			BRICK.darkened(0.18).lightened(0.04 * float(index)), 0.0, index == rings.size() - 2, false)
	_box("brick", dome, Vector3(0.0, 0.62, -0.3), Vector3(0.22, 0.42, 0.22), BRICK.darkened(0.1), 0.006)
	## Its mouth low on the front, an iron frame round a glow, and the last coals on the lip.
	var mouth := PackedVector2Array([Vector2(-0.18, 0.0), Vector2(0.18, 0.0)])
	var frame := PackedVector2Array([Vector2(-0.24, -0.02), Vector2(0.24, -0.02)])
	for step in range(9):
		var angle: float = PI * float(step) / 8.0
		mouth.append(Vector2(cos(angle) * 0.18, 0.12 + sin(angle) * 0.18))
		frame.append(Vector2(cos(angle) * 0.24, 0.12 + sin(angle) * 0.24))
	var front := dome * Transform3D(Basis(), Vector3(0.0, 0.02, 0.69))
	_extrude("iron", front, frame, _even(frame.size(), 0.02), IRON)
	_extrude("coal", front * Transform3D(Basis(), Vector3(0.0, 0.0, 0.025)), mouth, _even(mouth.size(), 0.006), COAL)
	for index in range(4):
		_lump("coal", front, Vector3(-0.12 + 0.08 * float(index), 0.02, 0.06), 0.04, COAL, Vector3(1.0, 0.6, 1.0))
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff8a3c")
	glow.omni_range = 4.5
	glow.light_volumetric_fog_energy = 0.6
	glow.shadow_enabled = false
	glow.position = _scaled(front * Vector3(0.0, 0.2, 0.45))
	add_child(glow)
	_flickers.append({"light": glow, "energy": 2.2, "speed": 0.35, "depth": 0.12})
	## A gauge over the mouth, its needle well up.
	var gauge := dome * Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.55), Vector3(0.0, 0.45, 0.5))
	_frustum("steel", gauge, 12, 0.11, 0.11, 0.035, Color("c9a26b"), 0.0, true, false, Color("ece2c8"))
	_box("iron", gauge * Transform3D(Basis(Vector3.UP, 0.8), Vector3(0.0, 0.04, 0.0)), Vector3(0.0, 0.0, 0.035), Vector3(0.014, 0.006, 0.08), Color("8a2a20"))

func _woodpile(at: Vector3) -> void:
	## Split wood stacked three, two and one, end grain to the party.
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, 0.25), Vector3(at.x, foot, at.z))
	var rows: Array = [[-0.17, 0.0, 0.17], [-0.085, 0.085], [0.0]]
	for row in range(rows.size()):
		for x in rows[row]:
			var log_at := base * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(float(x), 0.08 + 0.145 * float(row), -0.32))
			_frustum("wood", log_at, 6, 0.085, 0.08, 0.64, WOOD_DARK, _rng.randf_range(0.0, 1.0), true, true, WOOD_LIGHT.lightened(0.1))

func _cooling_stand(at: Vector3) -> void:
	## An iron stand with a tray on it, three stones cooling and the tongs laid by them.
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, -0.3), Vector3(at.x, foot, at.z))
	var top: float = 0.72
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box("iron", base, Vector3(corner.x * 0.3, top * 0.5, corner.y * 0.2), Vector3(0.04, top, 0.04), IRON)
	_box("iron", base, Vector3(0.0, top, 0.0), Vector3(0.72, 0.04, 0.5), IRON.lightened(0.1))
	_box("iron", base, Vector3(0.0, 0.18, 0.0), Vector3(0.62, 0.03, 0.42), IRON.darkened(0.1))
	_box("stone", base, Vector3(0.0, top + 0.035, 0.0), Vector3(0.6, 0.03, 0.4), Color("2c2724"))
	var tones: Array = [Color("9fd0ec"), Color("f0a0b8"), Color("f2c46a")]
	for index in range(3):
		_lump("gem", base, Vector3(-0.17 + 0.17 * float(index), top + 0.1, -0.04 + 0.05 * float(index % 2)), 0.065, tones[index], Vector3(1.0, 0.8, 1.0))
	for side in [-1.0, 1.0]:
		_box("iron", base * Transform3D(Basis(Vector3.UP, side * 0.05), Vector3(0.05, top + 0.065, 0.14)), Vector3.ZERO, Vector3(0.5, 0.018, 0.02), IRON.lightened(0.15))

# --- the cutter's wheel ----------------------------------------------------------------------------

func _grindstone(at: Vector3) -> void:
	## A round of grey stone stood on edge face on to the party, on an axle held out from a
	## frame behind it, a crank on its front and a trough of water under it to turn through.
	## A stone on its stick lies on the rest against the rim, where the cut is made.
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, -0.38), Vector3(at.x, foot, at.z))
	var centre := Vector3(0.0, 0.95, 0.0)
	var radius: float = 0.6
	## Two splayed legs behind the wheel meeting at the bearing, braced at the foot.
	for side in [-1.0, 1.0]:
		_rod("wood", base, Vector3(side * 0.6, 0.0, -0.28), Vector3(side * 0.06, centre.y + 0.06, -0.24), 0.1, WOOD_DARK)
	_box("wood", base, Vector3(0.0, 0.16, -0.28), Vector3(1.16, 0.08, 0.08), WOOD_DARK, 0.006)
	_box("iron", base, Vector3(0.0, centre.y, -0.21), Vector3(0.16, 0.16, 0.1), IRON)
	_box("iron", base, Vector3(0.0, centre.y, -0.1), Vector3(0.05, 0.05, 0.24), IRON.lightened(0.1))
	_box("wood", base, Vector3(0.0, 0.13, 0.02), Vector3(0.95, 0.26, 0.34), WOOD.darkened(0.05), 0.006)
	_box("water", base, Vector3(0.0, 0.265, 0.02), Vector3(0.85, 0.01, 0.26), Color("1d2a30"))
	## The rest on the right on its own post, and the stone on its stick laid against the rim.
	_box("wood", base, Vector3(0.86, 0.42, -0.04), Vector3(0.08, 0.84, 0.08), WOOD_DARK, 0.006)
	_box("wood", base, Vector3(0.8, 0.86, 0.04), Vector3(0.34, 0.05, 0.2), WOOD_LIGHT.darkened(0.08), 0.006)
	var rim: Vector3 = centre + Vector3(cos(-0.25), sin(-0.25), 0.0) * (radius + 0.035) + Vector3(0.0, 0.0, 0.03)
	_rod("wood", base, Vector3(1.1, 0.92, 0.1), rim + Vector3(0.04, 0.0, 0.0), 0.03, WOOD_LIGHT)
	_lump("gem", base, rim, 0.05, Color("9fe0c8"), Vector3(1.0, 0.9, 0.9))
	_commit(body)
	## The stone itself, still turning: worn darker in places, so it can be seen to go round.
	var wheel := Node3D.new()
	wheel.transform = Transform3D(base.basis, base * centre)
	body.add_child(wheel)
	_frustum("stone", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, -0.1)), 22, radius, radius, 0.2, Color("57504a"), 0.0, true, true, Color("6c6458"))
	for index in range(4):
		var turn := Transform3D(Basis(Vector3.BACK, TAU * float(index) / 4.0 + 0.4), Vector3.ZERO)
		_box("stone", turn, Vector3(0.0, 0.36 + 0.06 * float(index % 2), 0.102), Vector3(0.07, 0.26, 0.004), Color("48423b"))
	_frustum("iron", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.1)), 8, 0.14, 0.13, 0.03, IRON, 0.0, true, false)
	_box("iron", Transform3D(), Vector3(0.0, -0.15, 0.145), Vector3(0.05, 0.34, 0.035), IRON.lightened(0.08))
	_box("wood", Transform3D(), Vector3(0.0, -0.3, 0.235), Vector3(0.05, 0.05, 0.18), WOOD_LIGHT)
	_commit(wheel)
	_spinners.append({"node": wheel, "axis": Vector3.BACK, "speed": -1.1})

func _cut_table(at: Vector3) -> void:
	## A small table beside it: the peg the sticks stand in while their cement sets, and the
	## stones already cut laid out by a rough one still waiting.
	var foot: float = _floor(at)
	var base := Transform3D(Basis(Vector3.UP, 0.25), Vector3(at.x, foot, at.z))
	var top: float = 0.8
	_box("wood", base, Vector3(0.0, top - 0.04, 0.0), Vector3(0.95, 0.08, 0.7), WOOD_LIGHT.darkened(0.05), 0.008)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box("wood", base, Vector3(corner.x * 0.4, (top - 0.08) * 0.5, corner.y * 0.28), Vector3(0.08, top - 0.08, 0.08), WOOD, 0.006)
	_box("wood", base, Vector3(-0.2, top + 0.1, -0.16), Vector3(0.26, 0.2, 0.16), WOOD, 0.006)
	var tones: Array = [Color("f2b0c8"), Color("b0c8ff"), Color("ffd890")]
	for index in range(3):
		var stick_top := Vector3(-0.3 + 0.1 * float(index), top + 0.42 + 0.04 * float(index % 2), -0.1)
		_rod("wood", base, Vector3(-0.29 + 0.09 * float(index), top + 0.18, -0.16), stick_top, 0.024, WOOD_LIGHT)
		_lump("gem", base, stick_top + Vector3(0.0, 0.03, 0.0), 0.04, tones[index], Vector3(0.9, 1.0, 0.9))
	_lump("gem", base, Vector3(0.14, top + 0.04, 0.14), 0.055, Color("c9a0f0"), Vector3(1.0, 0.8, 1.0))
	_lump("gem", base, Vector3(0.28, top + 0.035, 0.0), 0.045, Color("9fd0ec"), Vector3(1.0, 0.8, 1.0))
	_lump("stone", base, Vector3(0.26, top + 0.06, 0.2), 0.08, Color("6a625a"), Vector3(1.0, 0.8, 1.0))

# --- light -----------------------------------------------------------------------------------------

func _work_light(tone: Color, aim: Vector3, tint: float, energy: float = 3.2) -> void:
	## A shaft from above and in front, a little of the card's color in it, so the furniture is
	## picked out of the dark the way the well and the stall are, and never reads as more rock.
	var beam := SpotLight3D.new()
	beam.light_color = Color("fff0d8").lerp(tone, tint)
	beam.light_energy = energy
	beam.spot_range = 11.0
	beam.spot_angle = 34.0
	beam.spot_angle_attenuation = 1.1
	beam.light_volumetric_fog_energy = 0.5
	beam.shadow_enabled = false
	_aim(beam, Vector3(0.0, 4.6, 3.4), _scaled(aim))
	add_child(beam)

func _aim(light: Node3D, from: Vector3, to: Vector3) -> void:
	## Set by hand rather than with `look_at`, which wants the node in the tree, and this is
	## built before the stage stands it in the room.
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.BACK
	light.transform = Transform3D(Basis.looking_at(to - from, up), from)

# --- shapes ----------------------------------------------------------------------------------------

func _floor(at: Vector3) -> float:
	## The floor under a piece, in the body's own units, sunk a hair so nothing hovers.
	if not _ground.is_valid():
		return 0.0
	var room_at: Vector3 = position + at * _scale
	return (float(_ground.call(room_at.x, room_at.z)) - position.y) / _scale - 0.02

func _scaled(point: Vector3) -> Vector3:
	## A point of the body, where it is in this node's own (unscaled) space.
	return point * _scale

func _st(key: String) -> SurfaceTool:
	if not _surfaces.has(key):
		_surfaces[key] = Lowpoly.begin()
	return _surfaces[key]

func _material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match key:
		"coal", "bulb":
			## Lit from inside: one color, its own light. The same build as the stall's lantern.
			m.albedo_color = Color("5a2010") if key == "coal" else Color("ffe6b8")
			m.roughness = 0.6
			m.emission_enabled = true
			m.emission = COAL if key == "coal" else Color("ffe2a8")
			m.emission_energy_multiplier = 2.6 if key == "coal" else 3.2
			return m
	m.vertex_color_use_as_albedo = true
	match key:
		"wood": m.roughness = 0.9
		"stone", "brick": m.roughness = 0.95
		"cloth": m.roughness = 1.0
		"iron":
			m.roughness = 0.55
			m.metallic = 0.5
		"steel":
			m.roughness = 0.32
			m.metallic = 0.75
		"water":
			m.roughness = 0.08
			m.metallic = 0.2
		"gem": m.roughness = 0.15
		_: m.roughness = 0.8
	return m

func _bricks(at: Transform3D, size: Vector3, courses: int, side: float) -> void:
	## A block of brickwork standing on `at`: a core of dark stone with bricks laid in courses
	## over its front and the end facing the party (`side`: +1 the right end, -1 the left), each
	## course half a brick along from the one under it.
	_box("stone", at, Vector3(0, size.y * 0.5, 0), Vector3(size.x - 0.06, size.y, size.z - 0.06), Color("3a302a"))
	var course_h: float = size.y / float(courses)
	for course in range(courses):
		var y: float = course_h * (float(course) + 0.5)
		var x: float = - size.x * 0.5 - (0.15 if course % 2 == 1 else 0.0)
		while x < size.x * 0.5 - 0.01:
			var x0: float = maxf(x, - size.x * 0.5)
			var x1: float = minf(x + 0.3, size.x * 0.5)
			if x1 - x0 > 0.05:
				_box("brick", at, Vector3((x0 + x1) * 0.5, y, size.z * 0.5 - 0.02), Vector3(x1 - x0 - 0.025, course_h - 0.025, 0.07), Lowpoly.shade(BRICK, _rng, 0.14), 0.006)
			x += 0.3
		var z: float = - size.z * 0.5 - (0.15 if course % 2 == 0 else 0.0)
		while z < size.z * 0.5 - 0.01:
			var z0: float = maxf(z, - size.z * 0.5)
			var z1: float = minf(z + 0.3, size.z * 0.5 - 0.06)
			if z1 - z0 > 0.05:
				_box("brick", at, Vector3(side * (size.x * 0.5 - 0.02), y, (z0 + z1) * 0.5), Vector3(0.07, course_h - 0.025, z1 - z0 - 0.025), Lowpoly.shade(BRICK.darkened(0.08), _rng, 0.14), 0.006)
			z += 0.3

func _box(key: String, at: Transform3D, centre: Vector3, size: Vector3, tone: Color, jitter: float = 0.0) -> void:
	## A box about `centre`, placed by `at`, its corners pushed about by up to `jitter`.
	var surface := _st(key)
	var h := size * 0.5
	var corners: Array = []
	for z in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for x in [-1.0, 1.0]:
				var point := centre + Vector3(x * h.x, y * h.y, z * h.z)
				if jitter > 0.0:
					point += Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter))
				corners.append(at * point)
	for face in BOX_FACES:
		Lowpoly.quad(surface, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], Lowpoly.shade(tone, _rng, 0.06), at.basis * (face[4] as Vector3))

func _frustum(key: String, at: Transform3D, sides: int, low: float, high: float, height: float, tone: Color, turn: float = 0.0,
		top: bool = true, bottom: bool = false, lid: Color = Color(0, 0, 0, 0)) -> void:
	## A ring of flat sides from radius `low` at the foot to `high` at `height`: a stump, a
	## bucket, a lamp's shade, a flue's hood. `lid` colors the top when it is not the sides'.
	var surface := _st(key)
	var ring_low: Array = []
	var ring_high: Array = []
	for index in range(sides):
		var angle: float = TAU * float(index) / float(sides) + turn
		ring_low.append(at * Vector3(cos(angle) * low, 0.0, sin(angle) * low))
		ring_high.append(at * Vector3(cos(angle) * high, height, sin(angle) * high))
	var centre_low: Vector3 = at * Vector3.ZERO
	var centre_high: Vector3 = at * Vector3(0.0, height, 0.0)
	for index in range(sides):
		var next: int = (index + 1) % sides
		var mid: float = TAU * (float(index) + 0.5) / float(sides) + turn
		var out: Vector3 = at.basis * Vector3(cos(mid), 0.0, sin(mid))
		Lowpoly.quad(surface, ring_low[index], ring_low[next], ring_high[next], ring_high[index], Lowpoly.shade(tone, _rng, 0.07), out)
		if top:
			Lowpoly.tri(surface, ring_high[index], ring_high[next], centre_high, tone.lightened(0.1) if lid.a <= 0.0 else Lowpoly.shade(lid, _rng, 0.04), at.basis * Vector3.UP)
		if bottom:
			Lowpoly.tri(surface, ring_low[index], ring_low[next], centre_low, tone.darkened(0.2), at.basis * Vector3.DOWN)

func _extrude(key: String, at: Transform3D, profile: PackedVector2Array, depths: PackedFloat32Array, tone: Color) -> void:
	## A side view (x along, y up, counter-clockwise) pushed out either side of z = 0, each
	## corner to its own half depth, so a horn can taper to a point and a foot can flare.
	var surface := _st(key)
	var front: Array = []
	var back: Array = []
	for index in range(profile.size()):
		front.append(at * Vector3(profile[index].x, profile[index].y, depths[index]))
		back.append(at * Vector3(profile[index].x, profile[index].y, - depths[index]))
	var cuts: PackedInt32Array = Geometry2D.triangulate_polygon(profile)
	for index in range(0, cuts.size(), 3):
		Lowpoly.tri(surface, front[cuts[index]], front[cuts[index + 1]], front[cuts[index + 2]], tone, at.basis * Vector3.BACK)
		Lowpoly.tri(surface, back[cuts[index]], back[cuts[index + 1]], back[cuts[index + 2]], tone.darkened(0.06), at.basis * Vector3.FORWARD)
	for index in range(profile.size()):
		var next: int = (index + 1) % profile.size()
		var edge: Vector2 = profile[next] - profile[index]
		var out: Vector3 = at.basis * Vector3(edge.y, - edge.x, 0.0)
		Lowpoly.quad(surface, front[index], front[next], back[next], back[index], Lowpoly.shade(tone, _rng, 0.07), out)

func _rod(key: String, at: Transform3D, from: Vector3, to: Vector3, thickness: float, tone: Color) -> void:
	## A square stick from one point to another: a dop, a handle.
	var along: Vector3 = to - from
	var up: Vector3 = Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.BACK
	_box(key, at * Transform3D(Basis.looking_at(along, up), (from + to) * 0.5), Vector3.ZERO, Vector3(thickness, thickness, along.length()), tone)

static func _even(count: int, depth: float) -> PackedFloat32Array:
	## The same half depth at every corner of a profile.
	var depths := PackedFloat32Array()
	depths.resize(count)
	depths.fill(depth)
	return depths

func _lump(key: String, at: Transform3D, centre: Vector3, radius: float, tone: Color, squash: Vector3 = Vector3.ONE) -> void:
	## A knocked-about icosahedron: a coal, a bulb, a sack.
	var surface := _st(key)
	var built: Array = Lowpoly._ico()
	var points: Array = []
	for point in built[0]:
		var p: Vector3 = point
		points.append(at * (centre + p * radius * squash * _rng.randf_range(0.82, 1.12)))
	var middle: Vector3 = at * centre
	for face in built[1]:
		var a: Vector3 = points[face[0]]
		var b: Vector3 = points[face[1]]
		var c: Vector3 = points[face[2]]
		Lowpoly.tri(surface, a, b, c, Lowpoly.shade(tone, _rng, 0.12), (a + b + c) / 3.0 - middle)

func _die(at: Vector3, edge: float, turn: Vector3) -> void:
	## A plain six-sided die, numbered the way a die in a hand is, at `at` in this node's space.
	var shape: String = "D6"
	var built: Dictionary = DiceGeometry.solid(shape)
	var frames: Array = built.frames
	var palette: Dictionary = DiceIcons.palette(shape)
	var colors := PackedColorArray()
	for index in range(frames.size()):
		colors.append(Color(palette.body).lightened(0.06 * float(index % 3)))
	for _i in range(frames.size(), built.faces.size()):
		colors.append(Color(palette.edge).lightened(0.12))
	var node := Node3D.new()
	var solid := MeshInstance3D.new()
	solid.mesh = DiceGeometry.mesh(shape, colors)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.35
	solid.material_override = material
	node.add_child(solid)
	var numeral: Color = Color("15181f") if Color(palette.body).get_luminance() > 0.45 else Color("f4f7fb")
	for index in range(frames.size()):
		var frame: Dictionary = frames[index]
		var label := Label3D.new()
		label.text = DiceIcons.face_text(index + 1)
		label.font_size = 96
		label.outline_size = 0
		label.modulate = numeral
		label.double_sided = false
		label.shaded = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.pixel_size = float(frame.inradius) * 1.5 / (96.0 * (0.58 * float(maxi(1, label.text.length())) + 0.42))
		label.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), frame.centre + frame.normal * 0.006)
		node.add_child(label)
	## The solid's corners are a unit from its middle, so its edge is 2 / sqrt(3) long.
	node.scale = Vector3.ONE * edge * _scale / 1.1547
	node.rotation = turn
	node.position = at
	add_child(node)
