extends SceneTree
## Topology, playable faces and the complete upgrade ladder, including high values.

const Geometry = preload("res://view/dice/dice_geometry.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const Icons = preload("res://view/dice/dice_icons.gd")

var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _init() -> void:
	check(DeepContent.validate().is_empty(), "content accepts all new dice")
	for shape in DeepDice.TIERS:
		_geometry(str(shape))
	_progression()
	_values()
	print("Dice shapes: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _geometry(shape: String) -> void:
	var started := Time.get_ticks_usec()
	var built: Dictionary = Geometry.solid(shape)
	var micros := Time.get_ticks_usec() - started
	var count := int(DeepDice.SHAPES[shape])
	check(built.frames.size() == count, "%s has exactly %d playable faces" % [shape, count])
	check(Geometry.shape_for_sides(count) == shape, "%s maps from its side count" % shape)
	check(str(Icons.silhouette(shape).shape) == shape and Icons.DIE_PALETTE.has(shape), "%s has an icon and palette" % shape)
	var edges: Dictionary = {}
	var triangles := 0
	var areas: Array[float] = []
	for i in built.faces.size():
		var face: PackedInt32Array = built.faces[i]
		var frame: Dictionary = built.surface_frames[i]
		check(face.size() >= 3 and float(frame.inradius) > 0.001, "%s surface %d has room for a label" % [shape, i])
		var normal: Vector3 = frame.normal
		var centre: Vector3 = frame.centre
		check(normal.is_finite() and normal.dot(centre) > 0.0, "%s surface %d points outward" % [shape, i])
		for point in built.vertices:
			check(normal.dot(point - centre) < 0.002, "%s surface %d bounds a convex solid" % [shape, i])
		for j in face.size():
			var a := face[j]
			var b := face[(j + 1) % face.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = int(edges.get(key, 0)) + 1
			check(absf(normal.dot(built.vertices[a] - centre)) < 0.001, "%s surface %d is planar" % [shape, i])
		var area := 0.0
		for j in range(1, face.size() - 1):
			var cross: Vector3 = (built.vertices[face[j]] - built.vertices[face[0]]).cross(built.vertices[face[j + 1]] - built.vertices[face[0]])
			check(cross.dot(normal) > 0.000001, "%s surface %d has nondegenerate outward winding" % [shape, i])
			area += cross.length() * 0.5
		areas.append(area)
		triangles += face.size() - 2
	check(edges.values().all(func(uses: int) -> bool: return uses == 2), "%s is closed with two faces per edge" % shape)
	check(built.vertices.size() - edges.size() + built.faces.size() == 2, "%s has spherical topology" % shape)
	check(triangles < 400, "%s stays below 400 body triangles" % shape)
	var polygons := {"D3": 4, "D16": 4, "D24": 5, "D30": 4, "D60": 3}
	if polygons.has(shape):
		for frame in built.frames:
			check(int(frame.sides) == int(polygons[shape]), "%s has the requested face polygon" % shape)
		var playable_areas := areas.slice(0, count)
		check(float(playable_areas.max()) - float(playable_areas.min()) < 0.001, "%s has equal-area playable faces" % shape)
	if shape == "D30":
		for face in built.faces:
			var lengths: Array[float] = []
			for i in face.size():
				lengths.append(built.vertices[face[i]].distance_to(built.vertices[face[(i + 1) % face.size()]]))
			check(float(lengths.max()) - float(lengths.min()) < 0.001, "d30 faces are rhombi")
	check(built.faces.size() == (98 if shape == "D2" else 9 if shape == "D3" else count), "%s has only the expected decorative surfaces" % shape)
	var mesh := Geometry.mesh(shape, PackedColorArray([Color.WHITE]))
	check(mesh.surface_get_array_index_len(0) == triangles * 3, "%s mesh includes every surface" % shape)
	var die := DeepDice.make(shape, DeepContent.die(shape), "shape")
	var view := DiceView.new()
	view.configure(die, {}, false, false, Color.WHITE)
	check(view.face_count() == count, "%s view exposes only playable faces" % shape)
	for i in count:
		check(view.aims_at(i) and view.face_value(i) == i + 1, "%s roll %d points to its true numeral" % [shape, i + 1])
	view.free()
	print("%s: %d surfaces, %d triangles, %.2f ms cold geometry" % [shape, built.faces.size(), triangles, micros / 1000.0])

func _progression() -> void:
	var die := DeepDice.make("D2", DeepContent.die("D2"), "kept", "twin")
	check(not DeepOddities.resize_refusal(die, -1).is_empty(), "d2 is the lower limit")
	for shape in DeepDice.TIERS.slice(1):
		check(DeepOddities.resize(die, 1).is_empty() and die.shape == shape, "upgrade reaches " + str(shape))
		check(die.id == "kept" and die.engraving == "twin" and die.faces.size() == int(DeepDice.SHAPES[shape]), "resizing preserves identity and engraving, replaces faces")
	check(not DeepOddities.resize_refusal(die, 1).is_empty(), "d100 is the upper limit")
	var reverse := DeepDice.TIERS.slice(0, -1)
	reverse.reverse()
	for shape in reverse:
		check(DeepOddities.resize(die, -1).is_empty() and die.shape == shape, "downgrade reaches " + str(shape))
	for i in DeepDice.TIERS.size():
		var shape := str(DeepDice.TIERS[i])
		var enemy := {"dice": [DeepDice.make(shape, DeepContent.die(shape), "base")], "dread_turns": 1}
		check(DeepCreatures.effective_dice(enemy)[0].shape == DeepDice.TIERS[maxi(0, i - 1)], "Dread follows the same ladder at " + shape)
		check(enemy.dice[0].shape == shape, "Dread preserves the base die")

func _values() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4716
	for shape in DeepDice.TIERS:
		var die := DeepDice.make(str(shape), DeepContent.die(str(shape)), "roll")
		var count := int(DeepDice.SHAPES[shape])
		var seen: Dictionary = {}
		for _i in range(count * 40):
			var roll := DeepDice.roll_one(die, rng)
			check(int(roll.value) == int(roll.face) + 1 and int(roll.top) == count, "%s values agree with physical faces without a d20 clamp" % shape)
			seen[int(roll.value)] = true
		check(seen.size() == count, "all faces can roll on " + str(shape))
	var high := DeepDice.make("D100", {"shape": "D100", "faces": [100]}, "high")
	var mirror := DeepDice.make("MIRROR_D6", {"shape": "D6", "faces": [{"value": 0, "kind": "mirror"}]}, "mirror")
	var rolls := DeepDice.roll_hand([high, mirror], rng)
	check(rolls[1].value == 100, "mirrors copy results above 20")
	var analysis := DeepHand.analyze(rolls.slice(0, 1))
	check(analysis.total == 100 and analysis.max_total == 100 and analysis.high_pct == 100, "large dice keep relative thresholds and totals")
	var explode := DeepDice.make("D100", {"shape": "D100", "faces": [{"value": 100, "kind": "exploding"}]}, "explode")
	var result := DeepDice.roll_one(explode, rng)
	check(result.value == 100 and result.explosions == DeepDice.MAX_EXPLOSIONS, "explosions retain finite caps")
