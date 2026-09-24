extends SceneTree
## Scene loading, instance isolation and the presentation API used by battles and inspection.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	_test_catalog()
	_test_isolation()
	_test_authored_pose()
	_test_variants()
	await _test_lifecycle()
	print("Creature scenes: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	for key in DeepContent.section("creatures"):
		check(CrystalCreature.SCENE_PATHS.has(key), "%s has its own scene" % key)
		var warden: bool = bool(DeepContent.creature(str(key)).get("warden", false))
		var creature := CrystalCreature.make(str(key), warden)
		var packed := load(str(CrystalCreature.SCENE_PATHS[key])) as PackedScene
		var direct := packed.instantiate() as CrystalCreature
		check(creature.scene_file_path == CrystalCreature.SCENE_PATHS[key], "%s spawns from its scene" % key)
		check(creature.key == str(key) and direct.key == str(key), "%s identifies itself when instanced directly" % key)
		check(direct.warden == warden and creature.warden == warden, "%s keeps its Warden variant" % key)
		check(creature.anchor.y > 0.0 and creature.anchor.is_equal_approx(direct.anchor), "%s can be framed before entering the tree" % key)
		var count: int = direct.get_node("Body").get_child_count()
		check(count > 0, "%s contains editable parts before ready" % key)
		root.add_child(direct)
		root.add_child(creature)
		check(direct.get_node("Body").get_child_count() == count, "%s does not rebuild its geometry at runtime" % key)
		var part := direct.get_node("Body").get_child(0) as Node3D
		var pose := part.transform
		direct._process(0.25)
		check(not part.transform.is_equal_approx(pose), "%s animates its scene parts" % key)
		check(creature.centre().y > creature.global_position.y, "%s exposes a hit position" % key)
		for pivot in direct.get_node("Body").get_children():
			var mesh := pivot.get_child(0) as MeshInstance3D
			check(mesh.mesh != null, "%s has saved geometry" % key)
			check(mesh.material_override == direct.core_material if pivot.motion == "core" else mesh.material_override == direct.body_material,
				"%s meshes use the material animated by their own instance" % key)
		direct.free()
		creature.free()

func _test_isolation() -> void:
	var first := CrystalCreature.make("CAVE_TICK")
	var second := CrystalCreature.make("CAVE_TICK")
	root.add_child(first)
	root.add_child(second)
	check(first.body_material != second.body_material and first.core_material != second.core_material, "same-type instances own their glow materials")
	var second_ring: StandardMaterial3D = second.get_node("TargetRing").material_override
	check(first.get_node("TargetRing").material_override != second_ring, "same-type instances own their target rings")
	var base: float = second.body_material.emission_energy_multiplier
	first.hit()
	first.set_targeted(true)
	first._process(0.1)
	check(first.body_material.emission_energy_multiplier > base, "a hit lights the affected creature")
	check(is_equal_approx(second.body_material.emission_energy_multiplier, base), "a hit leaves the other creature's glow alone")
	check(first.get_node("TargetRing").material_override.albedo_color.a > 0.0 and is_zero_approx(second_ring.albedo_color.a), "targeting leaves the other creature's ring hidden")
	var third := CrystalCreature.make("CAVE_TICK")
	check(is_equal_approx(third.body_material.emission_energy_multiplier, base), "new spawns do not inherit an earlier hit")
	first.free()
	second.free()
	third.free()

func _test_authored_pose() -> void:
	# Direct instancing is how creatures placed in the editor enter the tree.
	var packed := load(str(CrystalCreature.SCENE_PATHS.LANTERN_MOTH)) as PackedScene
	var creature := packed.instantiate() as CrystalCreature
	creature.position = Vector3(4, 2, -3)
	var body := creature.get_node("Body") as Node3D
	body.position = Vector3(0.1, 0.2, 0.3)
	body.scale = Vector3(1.2, 0.8, 1.1)
	body.rotation = Vector3(0.1, 0.2, 0.3)
	var core := creature.get_node("Body/Core01") as Node3D
	core.scale = Vector3(2, 3, 4)
	var wing := creature.get_node("Body/Wing01") as Node3D
	wing.rotation.z = 0.25
	var core_scale := core.scale
	var body_pose := body.transform
	root.add_child(creature)
	creature._process(0.1)
	check(is_equal_approx(creature.position.x, 4.0) and is_equal_approx(creature.position.z, -3.0) and creature.position.y > 1.9, "placed scenes keep their position during idle animation")
	check(body.transform.is_equal_approx(body_pose), "idle motion respects the authored body transform")
	var ratios: Vector3 = core.scale / core_scale
	check(is_equal_approx(ratios.x, ratios.y) and is_equal_approx(ratios.y, ratios.z), "pulsing preserves an edited core's proportions")
	var expected: float = 0.25 + sin(0.1 * 11.0 + wing.phase) * 0.55 * wing.wing_side
	check(is_equal_approx(wing.rotation.z, expected), "wing motion uses the authored rotation as its rest pose")
	creature.free()

func _test_variants() -> void:
	for key in ["CAVE_TICK", "THE_FOREMAN", "UNREGISTERED_CREATURE"]:
		var normal := CrystalCreature.make(key)
		var warden := CrystalCreature.make(key, true)
		check(warden.scale.is_equal_approx(normal.scale * 1.5), "%s scales its Warden variant once" % key)
		check(warden.anchor.is_equal_approx(normal.anchor * 1.5), "%s frames its Warden variant at the scaled height" % key)
		check(warden.tint.is_equal_approx(normal.tint.lerp(Color("ff5a4a"), 0.35)), "%s keeps its Warden palette" % key)
		check(warden.get_node("Glow").light_energy > normal.get_node("Glow").light_energy, "%s keeps its Warden light" % key)
		normal.free()
		warden.free()
	var fallback := CrystalCreature.make("UNREGISTERED_CREATURE")
	check(fallback.key == "UNREGISTERED_CREATURE" and fallback.scene_file_path == CrystalCreature.FALLBACK_SCENE, "unregistered content has a visible fallback with its original key")
	fallback.free()

func _test_lifecycle() -> void:
	var creature := CrystalCreature.make("SILT_SLIME")
	creature.position = Vector3(2, 0, -4)
	root.add_child(creature)
	creature.spawn(0.05)
	check(creature.get_node("Body").position.y < 0.0, "spawning starts below the floor")
	await create_timer(1.0).timeout
	check(creature.get_node("Body").position.is_equal_approx(Vector3.ZERO), "spawning returns the body to its authored position")
	creature.lunge(Vector3.ZERO, 0.1)
	await create_timer(0.2).timeout
	check(absf(creature.position.x - 2.0) < 0.001 and absf(creature.position.z + 4.0) < 0.001, "lunging returns to the spawn location")
	creature.channel(0.1)
	await create_timer(0.2).timeout
	check(is_zero_approx(creature._rear), "channeling settles back to idle")
	creature.die()
	await create_timer(0.6).timeout
	check(not is_instance_valid(creature), "death removes the instance after its animation")
