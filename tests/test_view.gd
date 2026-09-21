extends SceneTree
## The ported visual keepers, headless: geometry is built, glyphs are known, nothing needs a screen.

const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const Chamber = preload("res://view/battle/chamber.gd")
const Lowpoly = preload("res://view/battle/lowpoly.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_gems()
	_test_dice()
	_test_pictographs()
	_test_rasteriser()
	_test_look()
	_test_effects()
	print("View keepers: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _test_gems() -> void:
	for key in ["STRIKE", "GUARD", "MEND", "HEX", "TITHE", "GLIMMER"]:
		var stone: Dictionary = DeepStone.make(key, 8, 2, 3, [], {}, key.to_lower())
		var mesh: ArrayMesh = GemMesh.build(stone)
		check(mesh != null and mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) > 30, "%s cuts to a real solid" % key)
		check(GemMesh.girdle(stone).size() >= 6, "%s has a girdle" % key)
		check(GemIcons.known(GemIcons.emblem(key)), "%s has an emblem" % key)
	for key in DeepContent.section("skills"):
		check(GemIcons.known(GemIcons.emblem(str(key))), "every skill has a known emblem: " + str(key))
	check(GemMesh.colour_key(DeepStone.make("HEX", 1, 0, 3)) == "VIOLET", "colour comes from the skill")
	check(is_equal_approx(GemMesh.brilliance(5), 1.0) and is_equal_approx(GemMesh.brilliance(3), 0.6) and is_equal_approx(GemMesh.brilliance(0), 0.0), "the clarity ladder maps to brilliance")
	check(GemMesh.cut_rank(DeepStone.make("STRIKE", 1, 4, 3)) == 5 and GemMesh.cut_rank(DeepStone.make("STRIKE", 1, 0, 3)) == 1, "Cut 0..4 becomes the geometry's 1..5")
	check(GemMesh.flaw_count(DeepStone.make("STRIKE", 1, 0, 0, ["STAR", "SILK"])) == 2, "inclusions drawn are the ones carried")
	var poor: Dictionary = DeepStone.make("STRIKE", 1, 0, 3, [], {}, "a")
	var perfect: Dictionary = DeepStone.make("STRIKE", 1, 4, 3, [], {}, "a")
	check(GemMesh.girdle(poor) != GemMesh.girdle(perfect), "a Poor stone is cut differently from a Perfect one")
	var described: String = GemMesh.describe(DeepStone.make("BARRAGE", 14, 4, 5))
	check(described.contains("Perfect") and described.contains("Flawless") and described.contains("14 carats"), "describe speaks the new grades: " + described)
	check(GemView.thumbnail_key(poor) != GemView.thumbnail_key(perfect), "thumbnails are keyed by what renders")
	check(GemView.thumbnail_key(DeepStone.make("STRIKE", 1, 0, 3, ["SILK"])) != GemView.thumbnail_key(DeepStone.make("STRIKE", 1, 0, 3)), "inclusions change the thumbnail")
	var material: StandardMaterial3D = GemMesh.body_material(perfect)
	check(material != null and material.albedo_color.a > 0.0, "a body material is made")
	check(GemMesh.fire_material(perfect) != null and GemMesh.etch_material(perfect) != null, "fire and etch materials are made")

func _test_dice() -> void:
	for shape in ["D4", "D6", "D8", "D10", "D12", "D20"]:
		var solid: Dictionary = DiceGeometry.solid(shape)
		check(solid.frames.size() == int(DeepDice.SHAPES[shape]), "%s has %d faces (%d)" % [shape, int(DeepDice.SHAPES[shape]), solid.frames.size()])
		var colors := PackedColorArray()
		for _i in range(solid.frames.size()):
			colors.append(Color.WHITE)
		check(DiceGeometry.mesh(shape, colors) != null, "%s builds a mesh" % shape)
	for key in DeepContent.section("dice"):
		var palette: Dictionary = DiceIcons.palette(str(key))
		check(palette.has("body") and palette.has("edge"), "every die has a palette: " + str(key))
	check(DiceIcons.face_text(6, "wild") == "★" and DiceIcons.face_text(4, "plain") == "4" and DiceIcons.face_text(0, "blank") == "", "special faces have marks")
	## A die handed to the inspector before it joins the tree must still take the mouse.
	var turnable: Control = load("res://view/dice/dice_view.gd").new()
	turnable.enable_interaction()
	## The tree is not running yet while a test script starts, so ready it by hand.
	turnable._ready()
	check(turnable.mouse_filter == Control.MOUSE_FILTER_STOP, "an inspected die keeps the mouse after joining the tree, so it can be turned")
	turnable.free()
	var plain: Control = load("res://view/dice/dice_view.gd").new()
	plain._ready()
	check(plain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a die in a tray lets clicks through")
	plain.free()

func _test_pictographs() -> void:
	for key in DeepContent.section("skills"):
		var trigger: Dictionary = DeepContent.skill(str(key)).get("trigger", {"kind": "always"})
		for step in range(5):
			var described: Dictionary = DeepPatterns.describe(trigger, step)
			check(GemIcons.known(DiceIcons.glyph_for(described)), "%s at step %d draws with a known glyph (%s)" % [str(key), step, DiceIcons.glyph_for(described)])
			var strip: Dictionary = DiceIcons.strip(described)
			check(strip.has("faces") and strip.has("lead"), "a strip is made for " + str(key))
	var pair: Dictionary = DiceIcons.strip(DeepPatterns.describe({"kind": "pair", "ladder": [5, 4, 3, 2, 1]}, 0))
	check(pair.faces.size() == 2 and int(pair.faces[0][0]) == 5, "a Poor pair strip shows two fives: %s" % str(pair.faces))
	var run: Dictionary = DiceIcons.strip(DeepPatterns.describe({"kind": "straight", "ladder": [5, 5, 4, 4, 3]}, 4))
	check(run.faces.size() == 3, "a Perfect straight strip shows three dice")
	var texture: ImageTexture = GemIcons.texture("pair", 32)
	check(texture != null and texture.get_width() == 32, "glyphs rasterise headless")

func _coverage_reference(glyph: String, edge: int) -> PackedFloat32Array:
	## The rasteriser as it was first written: every pixel point-tested against every shape,
	## in order. Slow, obviously right, and what the fast one must agree with. Sampled on the
	## same four-by-four grid the fast one fills, so any difference is a real one.
	var shapes: Array = GemIcons._shapes(glyph)
	var out := PackedFloat32Array()
	out.resize(edge * edge)
	var step := 1.0 / float(edge)
	for y in edge:
		for x in edge:
			var covered := 0
			for sy in 4:
				for sx in 4:
					var point := Vector2((float(x) + (float(sx) + 0.5) / 4.0) * step, (float(y) + (float(sy) + 0.5) / 4.0) * step)
					var inside := false
					for shape in shapes:
						var hit: bool
						if shape.has("circle"):
							hit = point.distance_to(Vector2(shape.circle[0], shape.circle[1])) <= float(shape.circle[2])
						else:
							hit = Geometry2D.is_point_in_polygon(point, shape.poly)
						if hit:
							inside = shape.op == "add"
					if inside:
						covered += 1
			out[y * edge + x] = float(covered) / 16.0
	return out

func _test_rasteriser() -> void:
	for glyph in ["pair", "sword", "rose", "coin", "shield", "heart", "pick", "die", "straight4", "skull"]:
		var edge := 24
		var reference := _coverage_reference(glyph, edge)
		var image: Image = GemIcons.texture(glyph, edge).get_image()
		check(image.get_width() == edge and image.get_height() == edge, "%s bakes at the size asked for" % glyph)
		var error := 0.0
		for y in edge:
			for x in edge:
				error += absf(image.get_pixel(x, y).a - reference[y * edge + x])
		error /= float(edge * edge)
		check(error < 0.01, "the fast rasteriser agrees with the reference on %s (mean error %.4f)" % [glyph, error])
	for glyph in ["ore", "loupe", "gem", "pick", "lift", "descend", "bag", "die", "person", "party", "crown", "map", "anvil", "chest",
			"book", "arch", "question", "star", "check", "cross_out", "flame", "stairs", "stun", "drop", "lock_open", "ladder", "play", "wifi", "lantern", "gear", "flag", "door"]:
		check(GemIcons.known(glyph), "the interface mark %s is drawn" % glyph)
	for kind in DeepUi.CHAMBER_GLYPHS:
		check(GemIcons.known(str(DeepUi.CHAMBER_GLYPHS[kind])), "chamber kind %s has a known mark" % kind)
	check(GemIcons.baked_size(13.0) == 16 and GemIcons.baked_size(200.0) == 128, "glyph requests snap to the baked sizes")

func _test_look() -> void:
	var seen: Dictionary = {}
	for depth in range(1, 41):
		for kind in ["fight", "elite", "warden"]:
			var biome: Dictionary = Biomes.for_depth(DeepContent.starter_mine(), depth, kind)
			seen[str(biome.id)] = true
			check(Biomes.BIOMES.has(str(biome.id)), "depth %d resolves to a biome" % depth)
			check(biome.rock is Color and biome.key is Color and biome.accent is Color and biome.lights is Array and not biome.lights.is_empty(), "biome colours resolve at depth %d" % depth)
			check(float(biome.fog_density) > 0.0 and float(biome.vol_density) > 0.0, "a room at depth %d has air" % depth)
			if kind == "warden":
				check(biome.props.has("pillars"), "a Warden's hall has pillars")
	check(seen.size() == Biomes.BIOMES.size(), "the shaft passes through every biome by depth 40 (%d of %d)" % [seen.size(), Biomes.BIOMES.size()])
	check(Biomes.for_depth("QUARRY", 3).id == Biomes.for_depth("QUARRY", 3).id, "a depth is always the same biome")
	for key in Biomes.BIOMES:
		for particle in Biomes.BIOMES[key].particles:
			check(particle in ["dust", "motes", "drips", "sparkles", "spores", "embers", "ash", "void"], "%s drifts known particles (%s)" % [key, particle])
	## Every room builds without a screen, and the same seed builds the same room.
	for depth in [2, 6, 8, 10, 14, 18, 22, 24, 30]:
		var biome: Dictionary = Biomes.for_depth(DeepContent.starter_mine(), depth, "warden" if depth in [8, 24] else "fight")
		var room: Node3D = Chamber.new()
		root.add_child(room)
		room.build(biome, depth)
		check(room.get_child_count() > 10, "the %s room at depth %d has something in it (%d)" % [str(biome.id), depth, room.get_child_count()])
		check(room.environment() is Environment, "the %s room has air to breathe" % str(biome.id))
		room.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var boulder: ArrayMesh = Lowpoly.rock(rng, Color.WHITE)
	check(boulder.get_surface_count() == 1 and boulder.surface_get_array_len(0) == 60, "a boulder is twenty flat facets")
	var spike: ArrayMesh = Lowpoly.spike(rng, Color.WHITE, 5)
	var arrays: Array = spike.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var middle := Vector3.ZERO
	for v in verts:
		middle += v
	middle /= float(verts.size())
	var outward := true
	for i in range(0, verts.size(), 3):
		var centre: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		## The emitted winding must agree with the stored normal: Godot's front face is clockwise.
		var wound: Vector3 = (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i])
		if normals[i].dot(centre - middle) < 0.0 or wound.dot(normals[i]) < 0.0:
			outward = false
	check(outward, "a spike's facets face out of it")
	check(Thumbs.gem_key(DeepStone.make("STRIKE", 3, 1, 3, [], {}, "a")) != Thumbs.gem_key(DeepStone.make("STRIKE", 3, 1, 3, [], {}, "b")), "two stones of one skill are photographed apart")
	check(Thumbs.request("x", "gem", {}, func(_t: Texture2D) -> void: pass) == null, "with no screen there is no photographer, and asking is harmless")

func _test_effects() -> void:
	## Every lasting effect a unit can carry is shown, and shown the right way round.
	var unit: Dictionary = {"statuses": {"poison": 3, "stun": 1, "curse": 25}, "block": 5, "buried": [0], "clouded": [1, 2],
		"stolen_dice": 1, "granted_rerolls": 2, "amplify": 1.5, "nullify_next": true, "quality_bonus": 20, "sparkle": 3,
		"run_mods": {"shrine": "pair"}}
	var chips: Array = EffectChips.for_player(unit, {"phase": "planning"})
	var keys: Array = chips.map(func(c: Dictionary) -> String: return str(c.key))
	for key in ["block", "poison", "stun", "curse", "buried", "clouded", "stolen", "gifts", "amplify", "nullify", "quality", "sparkle", "shrine"]:
		check(keys.has(key), "a player's %s is shown" % key)
	for chip in chips:
		check(not str(chip.text).is_empty() and not str(chip.title).is_empty(), "the %s chip says what it does" % str(chip.key))
		if str(chip.key) in ["poison", "stun", "curse", "buried", "stolen", "nullify"]:
			check(not bool(chip.good), "%s counts against the player" % str(chip.key))
	var foe: Dictionary = {"statuses": {"poison": 2, "resolve": 1}, "block": 3, "downgrade": 1, "stolen_dice": 1, "stolen_gold": 4, "gimmick": "steal_gold"}
	var foe_chips: Array = EffectChips.for_enemy(foe)
	var foe_keys: Array = foe_chips.map(func(c: Dictionary) -> String: return str(c.key))
	for key in ["block", "poison", "resolve", "dread", "bound", "gold", "gimmick"]:
		check(foe_keys.has(key), "a creature's %s is shown" % key)
	for chip in foe_chips:
		if str(chip.key) == "poison":
			check(bool(chip.good), "poison on a creature is good news for the party")
	for key in DeepContent.section("creatures"):
		var gimmick: String = str(DeepContent.creature(str(key)).get("gimmick", ""))
		if not gimmick.is_empty():
			check(EffectChips.GIMMICKS.has(gimmick) and GemIcons.known(str(EffectChips.GIMMICKS[gimmick][0])), "the %s trick is explained with a known mark" % gimmick)
	var enrage: int = int(DeepContent.constant("enrage_turn", 7))
	check(EffectChips.for_battle({"turn": 1}).is_empty(), "a fresh fight has no fight-wide effects")
	check(EffectChips.for_battle({"turn": enrage - 1}).size() == 1 and str(EffectChips.for_battle({"turn": enrage - 1})[0].key) == "enrage_soon", "enrage is warned of before it lands")
	check(str(EffectChips.for_battle({"turn": enrage + 1})[0].key) == "enrage", "enrage shows once it has landed")
