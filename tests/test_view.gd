extends SceneTree
## The ported visual keepers, headless: geometry is built, glyphs are known, nothing needs a screen.

const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemFlaws = preload("res://view/gems/gem_flaws.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Biomes = preload("res://view/battle/biomes.gd")
const Chamber = preload("res://view/battle/chamber.gd")
const Lowpoly = preload("res://view/battle/lowpoly.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Tunnel = preload("res://view/battle/tunnel.gd")
const Mouth = preload("res://view/battle/mouth.gd")
const Rockfall = preload("res://view/battle/rockfall.gd")
const VeinFace = preload("res://view/battle/vein_face.gd")
const Stall = preload("res://view/battle/stall.gd")
const LiftHall = preload("res://view/battle/lift_hall.gd")
const Hoard = preload("res://view/battle/hoard.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_gems()
	_test_rock()
	_test_appraisal_sheet()
	_test_dice()
	_test_pictographs()
	_test_rasteriser()
	_test_look()
	_test_effects()
	_test_mine()
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
	check(GemMesh.color_key(DeepStone.make("HEX", 1, 0, 3)) == "VIOLET", "color comes from the skill")
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
	_test_inside()
	_test_cuts()

func _test_cuts() -> void:
	## Every Birthstone is cut to a solid of its own. They used to borrow the nearest of the
	## six outlines, which put Ardor in a Red trilliant and Cadence in a Blue princess, so
	## what this guards is that no two of them — and none of them and one of the six — are
	## the same shape any more.
	var shapes: Dictionary = {}
	for key in DeepContent.section("characters"):
		var born: Dictionary = DeepStone.birthstone(str(key))
		if born.is_empty():
			continue
		var shape: String = GemMesh.shape_of(born)
		check(GemMesh.STYLE_SHAPES.has(str(born.style)), "%s names a cut this can build: %s" % [key, born.style])
		check(not GemMesh.CUTS.values().has(shape), "%s is not wearing one of the six Colors' cuts" % key)
		check(not shapes.has(shape), "%s does not share its cut with %s" % [key, str(shapes.get(shape, ""))])
		shapes[shape] = str(key)
		var girdle: PackedVector2Array = GemMesh.girdle(born)
		check(girdle.size() >= 5, "%s has a girdle" % key)
		var reach := 0.0
		for point in girdle:
			reach = maxf(reach, point.length())
		check(reach > 0.55 and reach <= 1.0001, "%s is cut in unit space: %f" % [key, reach])
		check(GemMesh.build(born) != null, "%s cuts to a real solid" % key)
		check(GemMesh.describe(born).begins_with(str(born.name)), "%s is described by its own name" % key)
	check(shapes.size() == 6, "all six Birthstones are cut differently")
	## Rue is a drop and Violet is a pear, and before this they were the same curve. The
	## briolette has to come to the sharper point or the two read as one stone.
	var drop: PackedVector2Array = GemMesh.outline("briolette")
	var pear: PackedVector2Array = GemMesh.outline("pear")
	check(_waist(drop) < _waist(pear), "a briolette tapers harder than a pear: %f vs %f" % [_waist(drop), _waist(pear)])
	## A stone that grew in two colors carries the second as a solid inside the first, and
	## one that grew in one carries nothing extra.
	var puck: Dictionary = DeepStone.birthstone("PUCK")
	check(GemMesh.tint2(puck).a > 0.0 and GemMesh.inside(puck) != null, "Puck shows both of its colors")
	check(GemMesh.tint2(DeepStone.birthstone("ARDOR")).a <= 0.0, "a one-colored Birthstone names no second hue")
	## Florin's fool's gold and Vesper's pinprick flashes are both metal in the body.
	for key in ["FLORIN", "VESPER"]:
		var born: Dictionary = DeepStone.birthstone(str(key))
		check(int(GemMesh.envelope(born).get("flakes", 0)) > 0 and GemMesh.inside(born) != null,
			"%s carries what its words promise" % key)

func _waist(shape: PackedVector2Array) -> float:
	## How wide an outline still is a third of the way down from its point: the number that
	## says whether a taper is a taper.
	var widest := 0.0
	for point in shape:
		if point.y > 0.55 and point.y < 0.75:
			widest = maxf(widest, absf(point.x))
	return widest

func _test_inside() -> void:
	## What is frozen in a stone is cut as real geometry, and each class of inclusion is cut
	## as its own thing. Before this they were all the same darkened facet, so the test that
	## matters is that no two classes come out alike.
	var shapes: Dictionary = {}
	var seen: Dictionary = {}
	for key in DeepContent.section("inclusions").keys():
		var kind: String = str(DeepContent.inclusion(str(key)).get("class", ""))
		check(GemFlaws.CLASS_SIZE.has(kind), "inclusion class is one this can draw: " + kind)
		if seen.has(kind):
			continue
		seen[kind] = true
		var stone: Dictionary = DeepStone.make("STRIKE", 8, 4, 2, [str(key)], {}, "inside")
		var mesh: ArrayMesh = GemMesh.inside(stone)
		check(mesh != null and mesh.surface_get_array_len(0) > 0, "%s is cut into the stone" % kind)
		var span: Vector3 = mesh.get_aabb().size
		for other in shapes:
			check(not span.is_equal_approx(shapes[other]), "%s is not drawn as %s" % [kind, other])
		shapes[kind] = span
	check(seen.size() == GemFlaws.CLASS_SIZE.size(), "every class the pack uses has a shape")
	## Nothing inside a clean stone. A stone that carries no list at all — a lab preview,
	## a card built from a skill — still has to look as included as its Clarity says, so
	## there the classes come off the seed instead.
	check(GemMesh.inside(DeepStone.make("STRIKE", 8, 4, 5, [], {}, "clean")) == null, "a Flawless stone is empty inside")
	check(GemMesh.inside(DeepStone.make("STRIKE", 8, 4, 2, [], {}, "bathed")) == null, "a stone whose flaws were dissolved is empty inside")
	check(GemMesh.inside({"skill": "STRIKE", "carat": 8, "cut": 4, "clarity": 1, "id": "nolist"}) != null, "a stone with no list still looks as included as its Clarity says")
	## The six Seams are one emblem on one milky body, so the color each replays has to be
	## the thing telling them apart — in the stone, not only in the tooltip.
	var veins: Dictionary = {}
	for key in DeepContent.section("skills"):
		var skill: Dictionary = DeepContent.skill(str(key))
		if str(skill.get("color", "")) != "OPAL":
			continue
		var opal: Dictionary = DeepStone.make(str(key), 14, 4, 4, [], {}, "opal")
		var vein: Color = GemFlaws.seam_color(opal)
		var replays: bool = false
		for effect in skill.get("effects", []):
			replays = replays or (effect is Dictionary and str(effect.get("kind", "")) == "replay_color")
		if not replays:
			check(vein.a <= 0.0, "%s is an opal but not a Seam, so it carries no vein" % key)
			continue
		check(vein.a > 0.0 and GemMesh.inside(opal) != null, "%s carries a vein" % key)
		for other in veins:
			check(not vein.is_equal_approx(veins[other]), "%s does not run the same color as %s" % [key, other])
		veins[key] = vein
	check(veins.size() == 6, "all six Seams carry one")

func _test_rock() -> void:
	## A raw stone comes in a crust of rock, the largest chunk last, the same every time.
	var counts: Dictionary = {}
	for index in range(40):
		var stone: Dictionary = DeepStone.make("STRIKE", 8, 2, 3, [], {}, "rock%d" % index)
		var built: Array = GemRock.chunks(stone)
		counts[built.size()] = true
		check(built.size() == GemRock.chunk_count(stone), "a stone's rock has as many chunks as it says")
		var last: float = float(built[built.size() - 1].radius)
		check(built.slice(0, built.size() - 1).all(func(c: Dictionary) -> bool: return float(c.radius) < last), "the last chunk off is the largest")
		check(built.all(func(c: Dictionary) -> bool: return (c.mesh as ArrayMesh).get_surface_count() == 2), "every chunk has its rock and its seams")
		check(GemRock.reach(built) >= 1.0 and GemRock.reach(built) <= GemRock.reach(GemRock.layout(stone)) + 0.001, "the clump reaches past the stone and no further than its layout allows")
	check(counts.has(6) and counts.has(7), "some stones are crusted in six chunks and some in seven")
	var raw: Dictionary = DeepStone.make("BARRAGE", 11, 1, 2, ["STAR"], {}, "same")
	check(str(GemRock.layout(raw)) == str(GemRock.layout(raw.duplicate(true))), "the same stone always gets the same rock")
	## A raw stone looks no bigger or clearer than its class, and keeps its Star to itself.
	var view: Control = GemView.new()
	view.configure(raw)
	check(view.sealed(), "a raw stone is drawn sealed, in its rock")
	check(view.call("_carat") == DeepStone.shown_carat(raw) and view.call("_carat") != 11, "a raw stone is drawn at its class's size, not its own")
	check(is_equal_approx(view.call("_brilliance"), GemView.SEALED_BRILLIANCE), "a raw stone throws an ordinary stone's light")
	check(view.tooltip_text == GemView.UNAPPRAISED_TEXT, "a raw stone's picture says nothing about its cut or clarity")
	view.free()
	var thumb := Thumbs.GemThumb.new(raw, 64)
	check(not thumb.glint, "a raw stone with a Star does not glint")
	thumb.free()
	var known: Dictionary = raw.duplicate(true)
	known.appraised = true
	var known_thumb := Thumbs.GemThumb.new(known, 64)
	check(known_thumb.glint, "an appraised stone with a Star does")
	known_thumb.free()

func _test_appraisal_sheet() -> void:
	## The appraisal reads a stone out line by line: name, the three C's, anything frozen
	## inside one at a time, grade, worth, and the comparison when there is a kept stone.
	var found: Dictionary = DeepStone.make("BARRAGE", 14, 3, 1, ["STAR", "FEATHER"], {}, "found")
	found.appraised = true
	var kept: Dictionary = DeepStone.make("BARRAGE", 9, 4, 3, [], {}, "kept")
	kept.appraised = true
	var sheet = Appraisal.Sheet.new(found, kept)
	check(sheet.parts() == ["name", "carat", "cut", "clarity", "inclusions", "inclusion:0", "inclusion:1", "grade", "worth", "compare"], "the lines are read in order: %s" % str(sheet.parts()))
	sheet.free()
	var plain: Dictionary = DeepStone.make("GUARD", 3, 0, 4, [], {}, "plain")
	var alone = Appraisal.Sheet.new(plain)
	check(alone.parts() == ["name", "carat", "cut", "clarity", "grade", "worth"], "a clean stone with nothing to weigh it against has no inclusions and no comparison: %s" % str(alone.parts()))
	alone.free()

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
			check(biome.rock is Color and biome.key is Color and biome.accent is Color and biome.lights is Array and not biome.lights.is_empty(), "biome colors resolve at depth %d" % depth)
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
	check(Thumbs.request("x", "gem", {}, func(_t: Texture2D) -> void: pass ) == null, "with no screen there is no photographer, and asking is harmless")

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
	var foe: Dictionary = {"statuses": {"poison": 2, "resolve": 1}, "block": 3, "dread_turns": 1, "stolen_dice": 1, "stolen_gold": 4, "gimmick": "steal_gold"}
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

func _test_mine() -> void:
	## The rooms are joined by tunnels that fit them exactly: every mouth is cut to the
	## portal's arch, every tunnel starts on the far wall's plane and ends on the next room's
	## entrance, and a stub and the rest of its tunnel meet on one shared ring.
	var mine: String = DeepContent.starter_mine()
	check(Chamber.exit_xs(1) == [0.0] and Chamber.exit_xs(2).size() == 2 and Chamber.exit_xs(3).size() == 3, "one to three mouths stand across the far wall")
	for count in [1, 2, 3]:
		var biome: Dictionary = Biomes.for_depth(mine, 6, "fight")
		var room: Node3D = Chamber.new()
		root.add_child(room)
		room.build(biome, 60 + count, count, 2.5)
		check(room.exits.size() == count, "a room built for %d ways on has %d mouths" % [count, room.exits.size()])
		var stubs: int = 0
		for way in room.exits:
			var stub: Node3D = way.stub
			if stub != null and is_instance_valid(stub):
				stubs += 1
				check(stub.cap != null, "a stub is capped out of sight")
			var start: Vector3 = stub.point_at(Tunnel.WALL_GAP)
			check(absf(start.z - (Chamber.Z_FAR - 0.05)) < 0.02 and absf(start.x - float(way.x)) < 0.01, "a tunnel's walls begin just behind the far wall, in its mouth")
			var heading: Vector3 = stub.heading_at(Tunnel.WALL_GAP)
			check(heading.dot(Vector3.FORWARD) > 0.999, "a tunnel leaves its room square to the far wall")
			check(room.trail_distance(float(way.x), Chamber.Z_FAR + 1.0) < 0.1 and absf(room.ground(float(way.x), Chamber.Z_FAR + 1.0)) < 0.01, "a trail runs level to every mouth")
			## The rest of the tunnel, built as a walk would build it.
			var ahead: Dictionary = Biomes.for_depth(mine, 7, "fight")
			var rest: Node3D = Tunnel.new()
			root.add_child(rest)
			rest.build(biome, ahead, way.points, int(way.seed), Tunnel.STUB, INF, false)
			var entrance: Vector3 = Vector3(way.origin) + Vector3(0, 0, Chamber.Z_NEAR)
			var rings: Array = Tunnel.ring_distances(rest.length)
			var last: Vector3 = rest.point_at(float(rings.back()))
			check(last.z < entrance.z and last.distance_to(entrance) < 0.1, "a tunnel's walls run just into the next room's entrance (%s vs %s)" % [last, entrance])
			check(rest.heading_at(rest.length - Tunnel.WALL_GAP).dot(Vector3.FORWARD) > 0.999, "a tunnel enters the next room square to it")
			check(absf(float(Vector3(way.origin).y) + 2.5) < 0.001, "the next room stands lower: the shaft goes down")
			check(Tunnel.ring_distances(rest.length).has(minf(Tunnel.STUB, rest.length - Tunnel.WALL_GAP)), "the stub's last ring is one of the tunnel's own")
			check(rest.get_child_count() >= 2, "the rest of the tunnel has walls and a floor")
			rest.free()
		check(stubs == count, "every mouth holds a stub")
		## The mouths ahead are sealed and opened again.
		var fall: Node3D = Rockfall.new()
		room.add_child(fall)
		fall.build(Color(biome.rock), 5)
		fall.rest()
		check(fall.get_child_count() == Rockfall.COUNT and fall.get_children().all(func(n: Node) -> bool: return (n as Node3D).visible), "a rockfall comes to rest filling its mouth")
		var mouth: Node3D = Mouth.new()
		room.add_child(mouth)
		mouth.configure({"kind": "fight", "color": Color.RED, "glyph": "sword", "voters": [Color.WHITE, Color.BLUE], "mine": true})
		mouth.set_state("open")
		check(mouth.state == "open", "a mouth opens")
		room.free()
	## What a room is for stands in it, built from what the run says is there.
	var biome: Dictionary = Biomes.for_depth(mine, 5, "fight")
	var spots: Array = []
	for i in range(6):
		spots.append({"index": i, "glint": ["bright", "glint", "dull"][i % 3]})
	var face: Node3D = VeinFace.new()
	root.add_child(face)
	face.build(biome, spots, 3, false)
	check(range(6).all(func(i: int) -> bool: return face.spot_node(i) != null), "a vein has six spots to strike")
	face.hollow(2, Color.RED)
	check(face.is_taken(2) and not face.is_taken(1), "a struck spot is a hole, the rest are whole")
	face.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dig: Dictionary = DeepContent.mine(mine)
	var stock: Array = [ {"id": "i1", "kind": "stone", "stone": DeepForge.roll_stone(rng, dig, 5, 2, {}, "s1"), "price": 40, "sold": ""},
		{"id": "i2", "kind": "stone", "stone": DeepForge.roll_stone(rng, dig, 5, 2, {}, "s3"), "price": 55, "sold": ""},
		{"id": "i3", "kind": "stone", "stone": DeepForge.roll_stone(rng, dig, 5, 2, {}, "s2"), "price": 40, "sold": "p1"}]
	var counter: Node3D = Stall.new()
	root.add_child(counter)
	counter.build(biome, stock, 3)
	check(counter.has_item("i1") and counter.has_item("i2") and not counter.has_item("i3"), "a stall lays out what is unsold")
	check(counter.scales != null and counter.lens != null, "a stall has its scales and its lens")
	var goods: Node3D = counter.take("i1")
	check(goods != null and not counter.has_item("i1"), "goods bought leave the counter")
	counter.free()
	var hall: Node3D = LiftHall.new()
	root.add_child(hall)
	hall.build(biome, 3, true, false, Callable())
	check(hall.cage != null and hall.parts.has("rest") and hall.parts.has("appraise") and hall.parts.has("polish") and hall.parts.has("up"), "a landing has its cage, its fire, its bench and its wheel")
	hall.free()
	var hall_only: Node3D = LiftHall.new()
	root.add_child(hall_only)
	hall_only.build(biome, 3, false, true, Callable())
	check(hall_only.cage != null and not hall_only.parts.has("rest"), "the shaft head and a Warden's hall have the lift and nothing else")
	hall_only.free()
	var pile: Node3D = Hoard.new()
	root.add_child(pile)
	pile.build(biome, [stock[0].stone, stock[2].stone], 3)
	check(pile.spot(str(stock[0].stone.id)) != null, "a hoard shows each stone on its pedestal")
	pile.free()
	## A hole is drawn a hair inside the tunnel, so the wall always overlaps it.
	var hole: PackedVector2Array = Tunnel.outline(0.0, 30, -0.06)
	var fits: bool = true
	for p in Tunnel.arch():
		if p.y > 0.1:
			var within: Vector2 = p + (Vector2(0.0, Tunnel.SPRING) - p).normalized() * 0.15
			if Geometry2D.is_point_in_polygon(p, hole) or not Geometry2D.is_point_in_polygon(within, hole):
				fits = false
	check(hole.size() == 30 and fits, "a mouth's hole follows the tunnel's arch, a hair inside it")
