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
const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const GemTuning = preload("res://scripts/ui/gem_tuning.gd")
const GemViewScript = preload("res://scripts/ui/gem_view.gd")
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
	for kind in ["battle", "elite", "boss", "shop", "rest", "event", "mine", "workshop", "lapidary", "wager", "crucible"]:
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
	_check_gem_tuning()
	host.queue_free()
	Kit.release()
	GemIcons.release()
	GemMesh.release()
	Forge.clear_cache()
	SpriteActor.release()
	BackdropScript.release()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("Art integration: %d checks, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _reach(mesh: ArrayMesh) -> Vector3:
	return mesh.get_aabb().size

func _stone(key: String, carat: int, cut: int, clarity: int) -> Dictionary:
	return Catalog.gem(key, "probe", carat, cut, clarity)

func _check_gem_pictures() -> void:
	## A gem is cut from all four of its properties, so changing any one of them has to
	## change the solid or the material it wears. These check each axis on its own.
	for key in Catalog.SKILLS:
		var gem: Dictionary = _stone(str(key), 12, 3, 3)
		var mesh: ArrayMesh = GemMesh.build(gem)
		check(mesh.get_surface_count() == 1, "%s cuts one solid" % key)
		check(mesh.surface_get_array_len(0) >= 36, "%s has a faceted body" % key)
		var box: AABB = mesh.get_aabb()
		check(box.size.x > 0.2 and box.size.y > 0.2 and box.size.z > 0.5,
			"%s has a crown and a pavilion, not a flat disc" % key)
		check(GemMesh.etch_plate(gem).get_surface_count() == 1, "%s carries an etch panel" % key)
		check(GemIcons.known(GemIcons.emblem(str(key))), "%s has an emblem to etch" % key)
		check(GemMesh.etch_material(gem).normal_texture != null, "%s etch is cut, not printed on" % key)
		check(not GemMesh.describe(gem).is_empty(), "%s describes its own stone in words" % key)
	# Colour: one outline per category, and no two categories share a cut.
	var outlines: Dictionary = {}
	for color_key in Catalog.GEM_COLORS:
		var cut_name := str(GemMesh.CUTS.get(str(color_key), ""))
		check(not cut_name.is_empty(), "Colour %s wears a named cut" % color_key)
		check(not outlines.has(cut_name), "No two Colours share the cut %s" % cut_name)
		outlines[cut_name] = true
		check(GemMesh.silhouette(str(color_key)).size() >= 3, "Colour %s has a real outline" % color_key)
	# Carat: strictly larger, and the top stays under three times the bottom. It scales
	# the solid rather than recutting it, so the mesh itself must not change.
	var previous := 0.0
	for c in [1, 4, 8, 12, 16, 20, 24]:
		var span: float = GemMesh.carat_span(c)
		check(span > previous, "Carat %d is larger than the rank below" % c)
		previous = span
		# The solid itself never outgrows the camera; overflow is carried by the frame.
		check(GemMesh.carat_scale(c) <= 1.0001, "Carat %d is never cropped by its own view" % c)
		check(is_equal_approx(GemMesh.carat_scale(c) * GemMesh.carat_frame(c), span),
			"Carat %d splits its size between scale and frame without losing any" % c)
	check(GemMesh.carat_span(24) / GemMesh.carat_span(1) < 3.05,
		"Carat 24 stays under three times the reach of Carat 1")
	check(GemMesh.carat_span(24) > 1.2 and GemMesh.carat_frame(24) > 1.2,
		"A Carat 24 stone overflows the slot it is set in")
	check(is_equal_approx(GemMesh.carat_frame(1), 1.0),
		"A small stone stays inside its slot")
	check(_reach(GemMesh.build(_stone("STRIKE", 1, 3, 3))).is_equal_approx(_reach(GemMesh.build(_stone("STRIKE", 24, 3, 3)))),
		"Carat scales the stone rather than recutting it")
	# Cut is how TRUE the stone is, not how busy. Perfect is the clean solid cut exactly to
	# its own outline; every rank below is that solid cut worse — further off the outline,
	# and shallower. Measured on the girdle itself, because an AABB cannot see a chip that
	# lands away from the widest point.
	var truth: PackedVector2Array = GemMesh.silhouette("BLUE")
	var stray := 9.99
	var depth := 0.0
	for k in range(1, 6):
		var worn: PackedVector2Array = GemMesh.girdle(_stone("BLOCK", 16, k, 3))
		check(worn.size() == truth.size(), "Cut %d cuts the same outline, not a new shape" % k)
		var off := 0.0
		for index in truth.size():
			off += truth[index].distance_to(worn[index])
		check(off < stray + 0.0001, "Cut %d sits no further off its true outline than the rank below" % k)
		stray = off
		var mesh: ArrayMesh = GemMesh.build(_stone("BLOCK", 16, k, 3))
		check(mesh.surface_get_array_len(0) > 0, "Cut %d builds a solid" % k)
		check(_reach(mesh).z > depth, "Cut %d is a deeper stone than the rank below" % k)
		depth = _reach(mesh).z
	check(is_zero_approx(stray), "A Perfect cut is exactly the shape it is supposed to be")
	check(int(GemMesh.CUT_CHIPS[0]) > 0 and int(GemMesh.CUT_CHIPS[4]) == 0,
		"Only a poor cut is chipped")
	check(GemMesh.facet_count(5, "BLUE") <= GemMesh.facet_count(1, "BLUE") * 2,
		"A Perfect cut stays a simple solid rather than a golf ball")
	# Clarity: greyer and rougher as it falls, with inclusions only the dull ranks carry.
	var polish := 1.1
	var saturation := -1.0
	var flaws := 99
	for l in range(1, 6):
		var material: StandardMaterial3D = GemMesh.body_material(_stone("HEAL", 16, 3, l))
		check(material.roughness < polish, "Clarity %d is better polished than the rank below" % l)
		check(material.albedo_color.s > saturation, "Clarity %d is less grey than the rank below" % l)
		check(GemMesh.flaw_count(l) < flaws or GemMesh.flaw_count(l) == 0,
			"Clarity %d carries no more flaws than the rank below" % l)
		polish = material.roughness
		saturation = material.albedo_color.s
		flaws = GemMesh.flaw_count(l)
	check(GemMesh.flaw_count(1) == 5 and GemMesh.flaw_count(5) == 0, "Only a dull stone is flawed")
	# A clean stone is glass and a cloudy one is nearly solid, and the far half of every
	# stone is drawn before the near half so you see through one into the other.
	var solidity := 1.1
	for l in range(1, 6):
		var alpha: float = GemMesh.transparency(l)
		check(alpha < solidity, "Clarity %d is more see-through than the rank below" % l)
		solidity = alpha
	var near: StandardMaterial3D = GemMesh.body_material(_stone("HEAL", 16, 3, 4))
	var far: StandardMaterial3D = GemMesh.interior_material(_stone("HEAL", 16, 3, 4))
	check(far.render_priority < near.render_priority, "The far half of the stone is drawn first")
	check(far.cull_mode == BaseMaterial3D.CULL_FRONT and near.cull_mode == BaseMaterial3D.CULL_BACK,
		"The two passes take opposite halves of the solid")
	check(near.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "The stone is glass, not paint")
	check(near.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_ALWAYS,
		"The near half occludes itself, or its facets average into a blob")
	var emblem: StandardMaterial3D = GemMesh.etch_material(_stone("HEAL", 16, 3, 4))
	check(emblem.render_priority > far.render_priority and emblem.render_priority < near.render_priority,
		"The emblem is set inside the stone: after the far half, before the near one")
	check(GemMesh.brilliance(1) == 0.0 and GemMesh.brilliance(5) == 1.0, "Brilliance spans its whole range")
	check(GemMesh.body_material(_stone("HEAL", 16, 3, 5)).emission_energy_multiplier
		> GemMesh.body_material(_stone("HEAL", 16, 3, 1)).emission_energy_multiplier,
		"A clean stone is lit from within and a cloudy one is not")
	# Two gems alike but for one rank must not come out the same.
	var base: PackedVector3Array = GemMesh.build(_stone("STRIKE", 12, 3, 3)).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(base != GemMesh.build(_stone("STRIKE", 12, 4, 3)).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		"One changed Cut changes the solid")
	# Measured on the span, not the scale: an overflowing stone holds its scale at 1.0 and
	# grows its frame instead, so from the rank the stone outgrows its slot the scale alone
	# can no longer tell two Carats apart.
	check(GemMesh.carat_span(12) != GemMesh.carat_span(13), "One changed Carat changes the size")
	check(GemMesh.body_material(_stone("STRIKE", 12, 3, 3)).roughness
		!= GemMesh.body_material(_stone("STRIKE", 12, 3, 4)).roughness,
		"One changed Clarity changes the material")
	check(base == GemMesh.build(_stone("STRIKE", 12, 3, 3)).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		"The same gem always cuts the same stone")

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

func _stone_print(gem: Dictionary) -> String:
	## Everything about a stone that a tuning knob could reach: both material passes, the
	## etched emblem's own texture, and the facet tones baked into the solid.
	var near: StandardMaterial3D = GemMesh.body_material(gem)
	var far: StandardMaterial3D = GemMesh.interior_material(gem)
	var etch: StandardMaterial3D = GemMesh.etch_material(gem)
	var fire: ShaderMaterial = GemMesh.fire_material(gem)
	# How deep the emblem is set is geometry, not a material, so the plate has to be in here.
	var seat: Vector3 = GemMesh.etch_plate(gem).get_aabb().position
	var spark := ""
	for name: String in ["fire", "bands", "spread", "reach", "sharpness", "tint"]:
		spark += " %s" % fire.get_shader_parameter(name)
	var tally := 0.0
	for tone: Color in GemMesh.build(gem).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		tally += tone.r * 1.7 + tone.g * 2.3 + tone.b * 3.1
	var image: Image = etch.albedo_texture.get_image()
	var ink := 0.0
	for y in range(0, image.get_height(), 7):
		for x in range(0, image.get_width(), 7):
			var pixel: Color = image.get_pixel(x, y)
			ink += pixel.a * 3.0 + pixel.r + pixel.g * 1.3 + pixel.b * 1.7
	return "%s %s %.5f %.5f %.5f %.5f %s %.5f %.5f %.5f %.5f %.5f %.5f %.5f" % [
		near.albedo_color, far.albedo_color, near.roughness, near.metallic, near.rim,
		near.clearcoat, near.refraction_enabled, near.refraction_scale,
		near.emission_energy_multiplier, far.emission_energy_multiplier,
		etch.normal_scale, etch.roughness, ink, tally] + spark + str(seat) + str(etch.emission_energy_multiplier)

func _emblem_ink(gem: Dictionary) -> float:
	## Whether the emblem can be picked out of the stone at all. It reads three ways — a tone
	## the stone does not have, a light of its own, or relief that catches the key light —
	## and any one of them is enough, so the measure is their sum across its coverage.
	var body: Color = GemMesh.body_colour(Catalog.gem_color(str(gem.key)),
		int(gem.get("clarity", 1)))
	var material: StandardMaterial3D = GemMesh.etch_material(gem)
	var image: Image = material.albedo_texture.get_image()
	var bumps: Image = material.normal_texture.get_image()
	var lit: float = material.emission_energy_multiplier
	var relief: float = material.normal_scale
	var total := 0.0
	var count := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel: Color = image.get_pixel(x, y)
			var bump: Color = bumps.get_pixel(x, y)
			# Relief that catches the key light is the third way it reads, and on a clean
			# stone it is the only one: there the emblem is the body's own colour.
			var tilt := Vector2(bump.r - 0.5, bump.g - 0.5).length() * 2.0
			total += pixel.a * (absf(pixel.r - body.r) + absf(pixel.g - body.g)
				+ absf(pixel.b - body.b) + lit + relief * tilt)
			count += 1
	return total / float(maxi(count, 1))

func _check_gem_tuning() -> void:
	## The tuning table is the gem lab's whole reason to exist, so a knob that reaches
	## nothing is a silent failure: the slider moves and the stone does not. Every knob
	## outside the lighting group is swept here and has to change what the stone looks like.
	var seen: Dictionary = {}
	for knob: Dictionary in GemTuning.KNOBS:
		var key := str(knob.get("key", ""))
		check(not key.is_empty() and not seen.has(key), "Knob %s is named once" % key)
		seen[key] = true
		check(not str(knob.get("label", "")).is_empty(), "Knob %s has a caption" % key)
		check(not str(knob.get("hint", "")).is_empty(), "Knob %s says what it does" % key)
		check(not str(knob.get("group", "")).is_empty(), "Knob %s belongs to a group" % key)
		check(float(knob.step) > 0.0, "Knob %s steps by something" % key)
		check(float(knob.low) <= float(knob.value) and float(knob.value) <= float(knob.high),
			"Knob %s ships inside its own range" % key)
	check(GemTuning.moved().is_empty(), "The table starts at the shipped look")
	check(GemTuning.source_lines().findn("default") >= 0, "An untouched table reports itself untouched")

	# A stone at Clarity 3 sits halfway along every ramp, so both ends of each pair matter.
	var gem: Dictionary = _stone("STRIKE", 14, 3, 3)
	var shipped := _stone_print(gem)
	for knob: Dictionary in GemTuning.KNOBS:
		var key := str(knob.key)
		if str(knob.group) == "LIGHT" or bool(knob.get("view", false)):
			continue
		var here := float(knob.value)
		var probe: float = float(knob.high) if here - float(knob.low) < float(knob.high) - here else float(knob.low)
		GemTuning.set_value(key, probe)
		check(GemTuning.moved().has(key), "Moving %s registers as moved" % key)
		check(_stone_print(gem) != shipped, "Knob %s reaches the stone" % key)
		GemTuning.set_value(key, here)
		check(not GemTuning.moved().has(key), "Putting %s back stops counting as a change" % key)
	check(_stone_print(gem) == shipped, "Every knob put back is the shipped stone again")

	GemTuning.set_value("exposure", 99.0)
	check(is_equal_approx(GemTuning.value("exposure"), float(GemTuning.definition("exposure").high)),
		"A knob cannot be pushed past its own range")
	check(GemTuning.source_lines().findn("exposure") >= 0, "The report names what was changed")
	GemTuning.set_value("no_such_knob", 3.0)
	check(GemTuning.value("no_such_knob") == 0.0 and GemTuning.moved().size() == 1,
		"An unknown knob is ignored rather than invented")
	GemTuning.reset()
	check(GemTuning.moved().is_empty() and _stone_print(gem) == shipped,
		"Reset puts the whole table back")

	# The lighting knobs cannot be read off a material, so check the view still owns the
	# lights they scale and the one entry point that applies them.
	check(GemViewScript.LIGHTS.size() == 4, "The stone is lit from four quarters")
	var view: Control = GemViewScript.new()
	check(view.has_method("restyle"), "The view can be re-tuned without being rebuilt")
	check(view.has_method("set_drift") and view.drifting, "A view sways at rest unless told not to")
	check(view.ground.a == 0.0, "A view is a transparent cut-out until it is given a ground")
	view.set_ground(Color("161e2e"))
	check(view.ground.a > 0.9, "A view can be stood on a ground")
	view.set_ground(Color(0, 0, 0, 0))
	check(view.ground.a == 0.0, "and taken off it again")
	for knob: Dictionary in GemTuning.in_group("LIGHT"):
		check(GemTuning.definition(str(knob.key)).has("value"), "Lighting knob %s is in the table" % knob.key)
	check(GemTuning.flag("far_pass"), "The stone ships with both halves drawn")
	check(GemTuning.value("drift_turn") > 0.0 and GemTuning.value("drift_rate") > 0.0,
		"A gem at rest still turns, the way the dice do")
	# A cloudy stone scatters light instead of splitting it, so it throws no fire at all.
	check(float(GemMesh.fire_material(_stone("STRIKE", 14, 3, 1)).get_shader_parameter("fire")) == 0.0,
		"A Fractured stone throws no fire")
	# The emblem names the skill, so a murky stone must not be allowed to swallow it.
	var murky: StandardMaterial3D = GemMesh.etch_material(_stone("STRIKE", 14, 3, 1))
	var clean: StandardMaterial3D = GemMesh.etch_material(_stone("STRIKE", 14, 3, 5))
	check(murky.emission_energy_multiplier > clean.emission_energy_multiplier,
		"A cloudy stone lights its own emblem, because the murk takes the light away")
	for l in range(1, 6):
		check(_emblem_ink(_stone("STRIKE", 14, 3, l)) > 0.02,
			"Clarity %d still has an emblem to find" % l)
	check(float(GemMesh.fire_material(_stone("STRIKE", 14, 3, 5)).get_shader_parameter("fire"))
		> float(GemMesh.fire_material(_stone("STRIKE", 14, 3, 3)).get_shader_parameter("fire")),
		"A cleaner stone throws more fire")
	view.free()
