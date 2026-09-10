extends SceneTree
## Presentation scenarios: polyhedron generation, face orientation, generated sprites
## and the widget kit. Art never touches the simulation, so these checks only assert
## that every content key produces a usable, correctly shaped presentation object.

const Geometry = preload("res://scripts/ui/dice_geometry.gd")
const Forge = preload("res://scripts/ui/sprite_forge.gd")
const Kit = preload("res://scripts/ui/ui_kit.gd")
const DiceView = preload("res://scripts/ui/dice_view.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const SpriteActor = preload("res://scripts/ui/sprite_actor.gd")
const BackdropScript = preload("res://scripts/ui/backdrop.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const GemRender = preload("res://scripts/ui/gem_render.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const EXPECTED := {"D4": [4, 3], "D6": [6, 4], "D8": [8, 3], "D10": [10, 4], "D12": [12, 5], "D20": [20, 3]}

var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for shape in EXPECTED:
		var solid: Dictionary = Geometry.solid(shape)
		var faces: Array = solid.faces
		check(faces.size() == EXPECTED[shape][0], "%s has %d faces" % [shape, EXPECTED[shape][0]])
		var corners_match := true
		var planar := true
		var outward := true
		for index in range(faces.size()):
			var face: PackedInt32Array = faces[index]
			var frame: Dictionary = solid.frames[index]
			if face.size() != EXPECTED[shape][1]:
				corners_match = false
			if frame.normal.dot(frame.centre) <= 0.0:
				outward = false
			for corner in face:
				if absf(frame.normal.dot(solid.vertices[corner] - frame.centre)) > 0.001:
					planar = false
		check(corners_match, "%s faces are %d-gons" % [shape, EXPECTED[shape][1]])
		check(planar, "%s faces are planar" % shape)
		check(outward, "%s face normals point outward" % shape)
		var mesh: ArrayMesh = Geometry.mesh(shape, PackedColorArray([Color.WHITE]))
		check(mesh.get_surface_count() == 1, "%s builds one mesh surface" % shape)

	var host := Control.new()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(120, 120)
	host.add_child(stage)
	var view := DiceView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(view)
	var aimed := true
	for key in ["D4", "D6", "D8", "D10", "D12", "D20"]:
		var die: Dictionary = Catalog.die(key, "art-" + key)
		for face_index in range(die.faces.size()):
			view.configure(die, {"die_id": die.id, "face_index": face_index, "value": die.faces[face_index].value, "roll_count": face_index}, false, false, Color.WHITE)
			if not view.aims_at(face_index):
				aimed = false
	check(aimed, "every rolled physical face turns toward the camera")

	# Every trigger must be drawable: a reader counts dice instead of parsing prose.
	var every_trigger_drawn := true
	for key in Catalog.SKILLS:
		var spec: Dictionary = DiceIcons.requirement(key, 1)
		if spec.faces.is_empty() and str(spec.lead).is_empty():
			every_trigger_drawn = false
		if DiceIcons.detail(key, 1).is_empty():
			every_trigger_drawn = false
	check(every_trigger_drawn, "every skill trigger renders as a dice requirement")
	check(DiceIcons.requirement("BLOCK", 1).faces.size() == 2, "a pair draws two dice")
	check(DiceIcons.requirement("HEAVYSTRIKE", 1).faces.size() == 3, "a triple draws three dice")
	check(DiceIcons.requirement("SHIELDBASH", 1).faces.size() == 5, "a full house draws three and two")
	check(DiceIcons.requirement("MULTISTRIKE", 1).faces.size() == 5, "a straight draws five dice at Clarity 1")
	check(DiceIcons.requirement("MULTISTRIKE", 5).faces.size() == 3, "the same straight draws three dice at Clarity 5")
	check(str(DiceIcons.requirement("BULWARK", 1).lead) == "\u03a3 \u2264 20", "a hand total draws its comparison")
	check(int(DiceIcons.requirement("STUN", 1).faces[0][0]) == 20, "a high-die threshold draws the value it needs")

	for key in Catalog.HEROES:
		check(Forge.unit(key).get_width() > 0, "hero sprite " + key)
	for key in Catalog.ENEMIES:
		check(Forge.unit(key).get_width() > 0, "enemy sprite " + key)
	for key in Catalog.RELICS:
		check(Forge.relic(key).get_width() > 0, "relic sprite " + key)
	for kind in ["battle", "elite", "boss", "shop", "rest", "event", "mine", "workshop", "lapidary"]:
		check(Forge.room(kind).get_width() > 0, "room icon " + kind)
	for prop_name in ["sigil", "gold", "heart", "shield", "skull", "sword", "bolt", "shieldbreak"]:
		check(Forge.prop(prop_name).get_width() > 0, "prop icon " + prop_name)
	check(Forge.unit("ARDOR") == Forge.unit("ARDOR"), "sprites are cached, not rebuilt on every lookup")
	# Baked art is the shipped default; the painter is the fallback when a file is absent.
	var baked := 0
	var served := 0
	for probe in [["heroes", "ardor"], ["enemies", "slime_king"], ["relics", "matchbox"], ["rooms", "boss"], ["props", "sigil"]]:
		var path := "res://assets/sprites/%s/%s.png" % [probe[0], probe[1]]
		if not ResourceLoader.exists(path):
			continue
		baked += 1
		var shipped: Resource = load(path)
		var served_texture: Texture2D
		match probe[0]:
			"heroes", "enemies": served_texture = Forge.unit(probe[1])
			"relics": served_texture = Forge.relic(probe[1])
			"rooms": served_texture = Forge.room(probe[1])
			_: served_texture = Forge.prop(probe[1])
		if served_texture == shipped:
			served += 1
	check(baked == 0 or served == baked, "baked PNGs are served instead of being repainted")

	# The two lines hold their ground: the middle of the field stays clear at any count.
	var BattleStage = load("res://scripts/ui/battle_stage.gd")
	for sides in [[1, 1], [3, 3], [4, 5]]:
		var arena: Control = BattleStage.new()
		host.add_child(arena)
		arena.size = Vector2(1200, 420)
		var line: Array = []
		for i in range(int(sides[0])):
			line.append(_probe_unit("h%d" % i, "ARDOR", -1))
		for i in range(int(sides[1])):
			line.append(_probe_unit("e%d" % i, "SLIME", 1))
		arena.sync(line, true, Kit.RED, Callable(), Callable())
		var innermost_hero: float = -1.0
		var innermost_foe: float = 1e9
		for id in arena._slots:
			var slot: Dictionary = arena._slots[id]
			if int(slot.side) < 0:
				innermost_hero = maxf(innermost_hero, float(slot.home.x))
			else:
				innermost_foe = minf(innermost_foe, float(slot.home.x))
		check(innermost_foe - innermost_hero >= 1200.0 * 0.30 - 0.5,
			"%d against %d keeps the middle third of the field clear" % [int(sides[0]), int(sides[1])])
		arena.queue_free()
	await process_frame

	var built := Kit.build_theme(1.25)
	check(built.default_font_size == 20, "text scale reaches the theme")
	check(built.get_stylebox("normal", "Button") != null, "buttons have a generated panel")
	var bar := Kit.meter(host, 7.0, 20.0, Kit.GREEN, 14, "7 / 20")
	check(is_instance_valid(bar) and bar.maximum == 20.0, "meters accept values")
	var track := Kit.Track.new()
	track.total = 18
	track.here = 5
	host.add_child(track)
	var actor := SpriteActor.new()
	actor.custom_minimum_size = Vector2(90, 90)
	host.add_child(actor)
	actor.setup(Forge.unit("SLIME"), Kit.GREEN, false)
	actor.flinch()
	actor.strike()
	var scene_backdrop := BackdropScript.new()
	host.add_child(scene_backdrop)
	for kind in BackdropScript.THEMES:
		scene_backdrop.apply_theme(kind)
	scene_backdrop.apply_theme("nonexistent-room")
	await process_frame
	await process_frame
	check(is_instance_valid(scene_backdrop), "the backdrop survives every room theme")

	_check_gem_marks()
	_check_gem_pictures()
	host.queue_free()
	Kit.release()
	GemIcons.release()
	GemRender.release()
	Forge.clear_cache()
	SpriteActor.release()
	BackdropScript.release()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("Art integration: %d checks, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _ink(picture: Image) -> Array:
	## Coverage, average colour, brightest and darkest luminance of a painted stone, which
	## is enough to tell whether a property actually changed the picture.
	var covered := 0
	var total := Color(0, 0, 0)
	var lightest := 0.0
	var darkest := 1.0
	for y in picture.get_height():
		for x in picture.get_width():
			var pixel: Color = picture.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			covered += 1
			total += pixel
			lightest = maxf(lightest, pixel.get_luminance())
			darkest = minf(darkest, pixel.get_luminance())
	if covered == 0:
		return [0, Color(0, 0, 0), 0.0, 0.0, 0.0]
	return [covered, total / float(covered), lightest, (total / float(covered)).get_luminance(), darkest]

func _picture(key: String, carat: int, cut: int, clarity: int, edge := 96) -> Image:
	var made: Image = GemRender.texture(Catalog.gem(key, "probe", carat, cut, clarity), edge).get_image()
	made.convert(Image.FORMAT_RGBA8)
	return made

func _check_gem_pictures() -> void:
	## A gem is drawn from all four of its properties, so changing any one of them has to
	## change the picture. These check each axis on its own, holding the other three.
	for key in Catalog.SKILLS:
		var picture: Image = _picture(str(key), 12, 3, 3, 64)
		check(picture.get_size() == Vector2i(64, 64), "%s paints at the size asked for" % key)
		check(int(_ink(picture)[0]) > 200, "%s paints a stone, not an empty square" % key)
		check(GemIcons.known(GemIcons.emblem(str(key))), "%s has an emblem to etch" % key)
		check(not GemRender.describe(Catalog.gem(str(key), "d", 9, 2, 4)).is_empty(),
			"%s describes its own picture in words" % key)
	# Colour: one outline and one hue per category, and no two categories share a cut.
	var outlines: Dictionary = {}
	for color_key in Catalog.GEM_COLORS:
		var cut_name := str(GemRender.CUTS.get(str(color_key), ""))
		check(not cut_name.is_empty(), "Colour %s wears a named cut" % color_key)
		check(not outlines.has(cut_name), "No two Colours share the cut %s" % cut_name)
		outlines[cut_name] = true
		check(GemRender.silhouette(str(color_key)).size() >= 3, "Colour %s has a real outline" % color_key)
	# Carat: strictly larger, and the top is under three times the bottom.
	var previous := 0
	for c in [1, 4, 8, 12, 16, 20, 24]:
		var covered := int(_ink(_picture("STRIKE", c, 3, 3))[0])
		check(covered > previous, "Carat %d covers more of the icon than the rank below" % c)
		previous = covered
	check(GemRender.carat_scale(24) / GemRender.carat_scale(1) < 3.05,
		"Carat 24 stays under three times the reach of Carat 1")
	check(GemRender.carat_scale(1) < GemRender.carat_scale(2), "Carat 1 is the smallest stone")
	# Cut: strictly more facets, same outline. A better cut must not become a new shape.
	var facets := 0
	for k in range(1, 6):
		var count: int = GemRender.facet_count(k, "BLUE")
		check(count > facets, "Cut %d cuts more facets than the rank below" % k)
		facets = count
		var covered := int(_ink(_picture("BLOCK", 16, k, 3))[0])
		var plain := int(_ink(_picture("BLOCK", 16, 1, 3))[0])
		check(absi(covered - plain) < plain / 12, "Cut %d keeps the Block outline" % k)
	# Clarity: brighter overall and a stronger highlight every rank, with the inclusions
	# only the dull ranks carry. Peak-minus-darkest is not the measure — a Fractured stone
	# has the widest range of all, because its flaws are the darkest thing on it.
	var lit := 0.0
	var peak := 0.0
	var flaws := 99
	for l in range(1, 6):
		var read: Array = _ink(_picture("HEAL", 16, 3, l))
		check(float(read[3]) > lit, "Clarity %d is brighter than the rank below" % l)
		check(float(read[2]) > peak, "Clarity %d throws more light than the rank below" % l)
		check(GemRender.flaw_count(l) < flaws or GemRender.flaw_count(l) == 0,
			"Clarity %d carries no more flaws than the rank below" % l)
		lit = float(read[3])
		peak = float(read[2])
		flaws = GemRender.flaw_count(l)
	check(GemRender.flaw_count(1) == 5 and GemRender.flaw_count(5) == 0, "Only a dull stone is flawed")
	check(GemRender.brilliance(1) == 0.0 and GemRender.brilliance(5) == 1.0, "Brilliance spans its whole range")
	# Two gems alike but for one rank must not paint the same picture.
	var base: Image = _picture("STRIKE", 12, 3, 3)
	for other in [_picture("STRIKE", 13, 3, 3), _picture("STRIKE", 12, 4, 3), _picture("STRIKE", 12, 3, 4)]:
		check(base.get_data() != other.get_data(), "One changed rank changes the picture")
	check(base.get_data() == _picture("STRIKE", 12, 3, 3).get_data(), "The same gem always paints the same")
	check(GemRender.texture(Catalog.gem("STRIKE", "c", 5, 2, 2), 64) == GemRender.texture(Catalog.gem("STRIKE", "c", 5, 2, 2), 64),
		"One paint serves every use of a stone")
	# The etch may recolour the stone but must never widen it.
	var plain_gem: Dictionary = Catalog.gem("STRIKE", "plain", 20, 3, 3)
	var reach: float = GemRender.carat_scale(20) * 0.455 * 96.0
	var edge_pixels := 0
	var picture: Image = GemRender.texture(plain_gem, 96).get_image()
	picture.convert(Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			if picture.get_pixel(x, y).a > 0.5 and Vector2(x + 0.5, y + 0.5).distance_to(Vector2(48, 48)) > reach + 2.5:
				edge_pixels += 1
	check(edge_pixels == 0, "Nothing painted on the stone spills outside its girdle")

func _check_gem_marks() -> void:
	## The pictographs a gem is described with, and the description built from them.
	var glyphs: Array = GemIcons.HINTS.keys()
	for glyph in glyphs:
		check(GemIcons.known(str(glyph)), "Glyph %s has artwork" % glyph)
		check(not GemIcons.hint(str(glyph)).is_empty(), "Glyph %s carries hover text" % glyph)
		var mask: Image = GemIcons.texture(str(glyph), 24).get_image()
		check(mask.get_size() == Vector2i(24, 24), "Glyph %s bakes at the size asked for" % glyph)
		var painted := false
		var clear := false
		for y in 24:
			for x in 24:
				if mask.get_pixel(x, y).a > 0.5:
					painted = true
				elif mask.get_pixel(x, y).a < 0.02:
					clear = true
		check(painted and clear, "Glyph %s is a shape with real transparency around it" % glyph)
	check(GemIcons.texture("cut", 32) == GemIcons.texture("cut", 32), "One bake serves every use of a glyph")
	check(not GemIcons.known("no_such_glyph"), "An unknown glyph is reported rather than invented")
	# The pierced centre of the Cut mark has to survive, or it reads as the Clarity star.
	var blade: Image = GemIcons.texture("cut", 48).get_image()
	check(blade.get_pixel(24, 24).a < 0.5, "The Cut mark keeps a real hole through its centre")
	var counted: int = 0
	for key in Catalog.SKILLS:
		for ranks in [[1, 1, 1], [24, 5, 5], [12, 3, 2]]:
			var gem: Dictionary = Catalog.gem(str(key), "probe", ranks[0], ranks[1], ranks[2])
			var blocks: Array = GemText.blocks(gem)
			check(not blocks.is_empty(), "%s describes what it does" % key)
			for block in blocks:
				check(not str(block.verb).is_empty(), "%s names an action" % key)
				check(not block.parts.is_empty(), "%s keeps at least one term" % key)
				for part in block.parts:
					check(not str(part.text).is_empty(), "%s has no blank terms" % key)
					check(str(part.glyph).is_empty() or GemIcons.known(str(part.glyph)),
						"%s only asks for glyphs that exist: %s" % [key, part.glyph])
					check(str(part.tip).length() > 4, "%s explains every term on hover" % key)
					if not part.factor.is_empty():
						check(GemIcons.known(str(part.factor.glyph)), "%s factor glyph exists" % key)
				# Carat 1 multiplies by one, so it is dropped rather than written out.
				check(block.mult.is_empty() if ranks[0] == 1 else true,
					"%s hides a Carat 1 multiplier" % key)
			check(not GemText.sentence(gem).is_empty(), "%s reads as a sentence too" % key)
			counted += 1
	check(counted == Catalog.SKILLS.size() * 3, "Every skill was described at three rank spreads")
	# A term worth nothing is absent, which is the whole point of resolving per instance.
	var poor: Array = GemText.blocks(Catalog.gem("INTERPOSE", "poor", 1, 1, 1))
	var great: Array = GemText.blocks(Catalog.gem("INTERPOSE", "great", 1, 4, 1))
	check(poor[0].parts.size() + 1 == great[0].parts.size(), "A Cut worth zero is left out entirely")
	check(GemText.blocks(Catalog.gem("STRIKE", "flat", 1, 1, 4))[0].parts[1].text == str(Combat.clarity_bonus(4)),
		"Clarity is shown as the flat number it actually adds")
	check(GemText.title(Catalog.gem("MULTISTRIKE", "named", 12, 4, 5)) == "Great Flawless 12 Multistrike",
		"The name line reads as ranks then the gem")
	var prism: Array = GemText.blocks(Catalog.gem("STRIKE", "prism", 1, 1, 2), 4)
	check(prism[0].parts[1].text == str(Combat.clarity_bonus(4)) and "Prism" in str(prism[0].parts[1].tip),
		"An effective Clarity is described, and says what raised it")

func _probe_unit(id: String, key: String, side: int) -> Dictionary:
	return {"id": id, "key": key, "side": side, "name": id, "hp": 10, "max_hp": 10,
		"block": 0, "downed": false, "targeted": false, "boss": false, "mine": false,
		"tint": Color.WHITE, "bar": Kit.RED, "intents": [], "forecast": [], "badges": []}

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
