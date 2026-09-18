extends SceneTree
## The ported visual keepers, headless: geometry is built, glyphs are known, nothing needs a screen.

const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_gems()
	_test_dice()
	_test_pictographs()
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
