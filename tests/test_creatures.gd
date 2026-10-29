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
	_test_moves()
	await _test_lifecycle()
	print("Creature scenes: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var BestiaryPage: Script = load("res://view/home/bestiary_page.gd")
	for key in DeepContent.section("creatures"):
		check(CrystalCreature.SCENE_PATHS.has(key), "%s has its own scene" % key)
		## The bestiary's grid shows a picture baked ahead of time (tools/creature_portraits.gd).
		check(BestiaryPage.call("portrait", str(key)) != null, "%s has a bestiary portrait (bake it with tools/creature_portraits.gd)" % key)
		check(ResourceLoader.exists(str(CrystalCreature.SCENE_PATHS.get(key, ""))), "%s's scene is on disk" % key)
		if not ResourceLoader.exists(str(CrystalCreature.SCENE_PATHS.get(key, ""))):
			continue
		var warden: bool = bool(DeepContent.creature(str(key)).get("warden", false))
		var creature := CrystalCreature.make(str(key), warden)
		var packed := load(str(CrystalCreature.SCENE_PATHS[key])) as PackedScene
		var direct := packed.instantiate() as CrystalCreature
		## A variant wears another creature's scene in its own colours.
		var base_key: String = str(CrystalCreature.VARIANTS.get(key, {}).get("of", key))
		check(creature.scene_file_path == CrystalCreature.SCENE_PATHS[key], "%s spawns from its scene" % key)
		check(creature.key == str(key) and direct.key == base_key, "%s identifies itself when instanced directly" % key)
		if CrystalCreature.VARIANTS.has(key):
			check(creature.tint.is_equal_approx(Color(str(CrystalCreature.VARIANTS[key].tint)).lerp(Color("ff5a4a"), 0.35) if warden else Color(str(CrystalCreature.VARIANTS[key].tint))), "%s wears its own colour" % key)
		check(direct.warden == warden and creature.warden == warden, "%s keeps its Warden variant" % key)
		var grown: float = float(CrystalCreature.VARIANTS.get(key, {}).get("scale", 1.0))
		check(creature.anchor.y > 0.0 and creature.anchor.is_equal_approx(direct.anchor * grown), "%s can be framed before entering the tree" % key)
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
			check(mesh.material_override == direct.core_material or mesh.material_override == direct.body_material or (direct.accent_material != null and mesh.material_override == direct.accent_material)
				or (direct.iron_material != null and mesh.material_override == direct.iron_material),
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
	## A Void Echo wears the scene of what it copies, in the Rift's light.
	var echo := CrystalCreature.make("VOID_ECHO", false, "CAVE_TICK")
	check(echo.key == "VOID_ECHO" and echo.scene_file_path == CrystalCreature.SCENE_PATHS.CAVE_TICK, "an echo spawns the scene of the creature it copies")
	check(echo.tint.is_equal_approx(CrystalCreature.ECHO_TINT) and echo.body_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "and is drawn as a ghost")
	echo.free()
	## The newer presentation calls settle without error.
	var diver := CrystalCreature.make("THE_UNDERTOW")
	root.add_child(diver)
	diver.burrow(true)
	for _i in range(40):
		diver._process(0.05)
	check(diver.get_node("Body").position.y < -0.5, "a burrowed creature sinks under the floor")
	diver.burrow(false)
	for _i in range(40):
		diver._process(0.05)
	check(absf(diver.get_node("Body").position.y) < 0.01, "and comes back up")
	diver.free()
	## The Pit Mole digs into its own mound instead: gone, a hole left in the dirt, the mound
	## where it was; and up out of it again with its Erupt (or on its own if none comes).
	var mole := CrystalCreature.make("PIT_MOLE")
	root.add_child(mole)
	mole._process(0.05)
	var head := mole.get_node("Body/Head01") as Node3D
	var mound := mole.get_node("Body/Mound01") as Node3D
	var mound_pose: Transform3D = mound.transform
	mole.burrow(true)
	for _i in range(40):
		mole._process(0.05)
	check(not head.visible and head.position.y < -0.5, "a Pit Mole digs down out of sight")
	check(mound.transform.is_equal_approx(mound_pose) and mound.visible, "and leaves its mound where it was")
	check(mole._moves._hole != null and mole._moves._hole.visible, "with a dark hole in the dirt")
	mole.burrow(false)
	for _i in range(90):
		mole._process(0.05)
	check(head.visible and absf(head.position.y - 0.5) < 0.01, "and comes back up out of it")
	check(not mole._moves._hole.visible, "and the hole is gone")
	mole.set_halo(Color.RED)
	mole._process(0.5)
	check(mole._halo_material.albedo_color.a > 0.0 and mole._halo_material.albedo_color.r > 0.9, "a guarded creature shows a halo in its colour")
	mole.free()

func _test_moves() -> void:
	## Every creature acts out every move it has (its own parts where it has them, its whole
	## body otherwise), without an error, and is back exactly at its idle after: a twin that
	## never moved, stepped alongside it, stands just as it does.
	var bare: Array = ["RAIL_RAT", "LANTERN_MOTH", "WILL_O_WISP", "CINDER_MOTH", "QUARTZ_GOLEM", "PRISM_GOLEM", "THE_REGENT", "CAVE_CRAYFISH",
		"PRISM", "PUFFBALL", "RIFTLING_SWARM", "COLLAPSAR"]
	for key in DeepContent.section("creatures"):
		var def: Dictionary = DeepContent.creature(str(key))
		var warden: bool = bool(def.get("warden", false))
		var echo: String = "SEEP_EEL" if str(key) == "VOID_ECHO" else ""
		var actor := CrystalCreature.make(str(key), warden, echo)
		var twin := CrystalCreature.make(str(key), warden, echo)
		root.add_child(actor)
		root.add_child(twin)
		if not bare.has(str(key)):
			check(actor._moves.has_rig(), "%s has named parts to act its moves out with" % key)
		var seen: int = 0
		for move in def.get("moves", []):
			var anim: String = str(move.get("anim", ""))
			var name: String = str(move.get("name", ""))
			var hostile: bool = str(move.get("kind", "")) in ["attack", "meddle"]
			if actor._moves.has_rig() and hostile:
				check(actor._moves.handles(anim, name, hostile), "%s acts out %s (%s)" % [key, name, anim])
			check(actor.move_lead(anim, name, hostile) >= 0.3 and actor.move_lead(anim, name, hostile) <= 0.47, "%s's %s starts within its windup" % [key, name])
			actor.play_move(anim, name, hostile, Vector3(0, 1.5, 5.0), null)
			var steps: int = 0
			while actor.acting() and steps < 200:
				actor._process(0.02)
				twin._process(0.02)
				steps += 1
			check(steps < 200, "%s's %s finishes" % [key, name])
			seen += 1
		## The idle eases back in after the last move.
		for _i in range(40):
			actor._process(0.02)
			twin._process(0.02)
		var drift: Array = []
		var twin_parts: Dictionary = {}
		for part in twin._parts:
			twin_parts[str(part.name)] = part
		for part in actor._parts:
			var other: Node3D = twin_parts.get(str(part.name), null)
			if other != null and not part.transform.is_equal_approx(other.transform):
				if part.transform.origin.distance_to(other.transform.origin) > 0.002 or not part.transform.basis.is_equal_approx(other.transform.basis):
					drift.append(str(part.name))
		check(drift.is_empty(), "%s is back at its idle after %d moves (%s)" % [key, seen, ", ".join(drift.slice(0, 6))])
		check(actor.get_node("Body").transform.is_equal_approx(twin.get_node("Body").transform), "%s's body is back where it stands" % key)
		actor.free()
		twin.free()
	## The states the owner asked for: a magpie's prize only once it has stolen, a wraith seen
	## through while it fades, the Kiln Wyrm's breath only when it breathes.
	var magpie := CrystalCreature.make("MAGPIE")
	root.add_child(magpie)
	var prize := magpie.get_node("Body/Prize01") as Node3D
	check(not prize.visible, "a magpie starts with nothing in its beak")
	magpie.set_prize(true)
	magpie._process(0.05)
	check(prize.visible, "and carries the pyrite once it has stolen some")
	magpie.free()
	var wraith := CrystalCreature.make("VEIN_WRAITH")
	root.add_child(wraith)
	var shape := wraith.get_node("Body/Body01").get_child(0) as GeometryInstance3D
	wraith.burrow(true)
	for _i in range(40):
		wraith._process(0.05)
	check(shape.transparency > 0.5 and absf(wraith.get_node("Body").position.y) < 0.01, "a fading wraith turns see-through where it floats")
	wraith.burrow(false)
	for _i in range(40):
		wraith._process(0.05)
	check(is_zero_approx(shape.transparency), "and solid again as it comes back")
	wraith.free()
	var dragon := CrystalCreature.make("THE_KILN_WYRM", true)
	root.add_child(dragon)
	var flame := dragon.get_node("Body/Breath01") as Node3D
	dragon._process(0.05)
	check(not flame.visible, "the Kiln Wyrm breathes no fire at rest")
	dragon.play_move("breath", "Firebreath", false, Vector3(0, 1.5, 6.0), null)
	var shown: bool = false
	for _i in range(40):
		dragon._process(0.02)
		shown = shown or flame.visible
	check(shown, "but does on Firebreath")
	for _i in range(60):
		dragon._process(0.02)
	check(not flame.visible, "and stops after")
	dragon.free()

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
