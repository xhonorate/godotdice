extends Node3D
## A merchant's stall, set up where a fight would stand: a timber counter between two posts
## with a sign hung over it and a lantern at one end; the goods laid out on a cloth, each a
## real stone turning slowly in its own light with its price in front of it and its name on a
## tag under that (now and then a die, traded for one of yours); a pair of scales at one end
## for selling and a lens on a stand at the other for appraising.
##
## In room space, facing the party. It shows what it is told: the stock, what is sold, what
## the lens costs. What dragging and clicking mean is the run's business.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const DiceGeometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleFx = preload("res://view/battle/battle_fx.gd")

const WIDTH := 7.2
const TOP := 1.06
const SCALES_X := -3.05
const LENS_X := 3.05

var scales: Node3D
var lens: Node3D
var _items: Dictionary = {}
## The words over the lens and the scales: spots the stage writes over the view (see
## `MineStage.NAME_GROUP`), with their words and tone as metas.
var _lens_label: Node3D
var _scales_label: Node3D
var _pans: Array = []
var _glows: Dictionary = {}
var _clock: float = 0.0
## The buyer's pyrite, once told (-1 until then: every price reads as payable), and the lens's fee.
var _purse: int = -1
var _lens_cost: int = 0
## The lens or the scales with nothing in it for this player: its word greyed, no glow.
var _shut: Dictionary = {}
## A price the purse cannot meet.
const DEARER := Color(0.86, 0.38, 0.33, 0.9)
## The tag under a price: the goods' name on a small plate edged in their color, as the bag's
## tiles are, with a pip of that color before it (a gem's diamond, a die's own outline). Two
## stones of one color look alike from across the room; the name tells them apart without
## pointing at each one. `TAG_DROP` is how far under the goods it hangs, in room units.
const TAG_SIZE: int = 15
const TAG_PIP: float = 12.0
const TAG_DROP: float = 0.56
const DIAMOND: Array = [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
## A lucky find and a Void stone (review card S1, round 3) are told apart at a glance: a lucky
## find shimmers in gold (a halo behind it and glints winking round it, the Flawless line's
## gold) with a "Lucky find" mark under its tag; a Void stone is drawn as the dark space the
## dock draws Void in, its facets lit at the rim, with a "Void" mark. `MARK_DROP` is how far
## under the tag the first mark hangs, `MARK_STEP` the next one's step.
const MARK_SIZE: int = 13
const MARK_DROP: float = 0.3
const MARK_STEP: float = 0.27
const GLINT_SPOTS: Array = [Vector3(0.27, 0.2, 0.28), Vector3(-0.26, 0.06, 0.28), Vector3(0.1, -0.2, 0.34), Vector3(-0.12, 0.31, 0.22)]
static var _glint_material: StandardMaterial3D = null
static var _halo_material: StandardMaterial3D = null
func build(biome: Dictionary, stock: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wood := _material(Color("7a5030"), 0.9)
	wood.vertex_color_use_as_albedo = true
	var counter := MeshInstance3D.new()
	counter.mesh = Lowpoly.slab(Vector3(WIDTH, 1.0, 1.0), Color("6a4428"), rng, 0.03)
	counter.material_override = wood
	counter.position = Vector3(0, 0.5, 0)
	add_child(counter)
	var top := MeshInstance3D.new()
	top.mesh = Lowpoly.slab(Vector3(WIDTH + 0.2, 0.08, 1.15), Color("8a5c36"), rng, 0.01)
	top.material_override = wood
	top.position = Vector3(0, TOP - 0.03, 0)
	add_child(top)
	var cloth := MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(4.9, 0.02, 0.85)
	cloth.mesh = sheet
	cloth.material_override = _material(Color("5a1f2a"), 0.95)
	cloth.position = Vector3(0, TOP + 0.02, 0)
	add_child(cloth)
	## Two posts and a crossbar, and the sign hung from it.
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = Lowpoly.slab(Vector3(0.16, 3.3, 0.16), Color("5a3a22"), rng, 0.02)
		post.material_override = wood
		post.position = Vector3(side * (WIDTH * 0.5 + 0.05), 1.65, -0.45)
		add_child(post)
	var bar := MeshInstance3D.new()
	bar.mesh = Lowpoly.slab(Vector3(WIDTH + 0.5, 0.14, 0.16), Color("5a3a22"), rng, 0.02)
	bar.material_override = wood
	bar.position = Vector3(0, 3.25, -0.45)
	add_child(bar)
	var sign_board := MeshInstance3D.new()
	sign_board.mesh = Lowpoly.slab(Vector3(1.5, 0.75, 0.07), Color("7a5a3a"), rng, 0.02)
	sign_board.material_override = wood
	sign_board.position = Vector3(0, 2.72, -0.42)
	add_child(sign_board)
	var mark := Sprite3D.new()
	mark.texture = GemIcons.texture("purse", 128)
	mark.pixel_size = 0.55 / float(mark.texture.get_width())
	mark.modulate = Color("5fd4c8")
	mark.shaded = true
	mark.position = Vector3(0, 2.72, -0.37)
	add_child(mark)
	## The lantern, and the light it gives the goods.
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.32, 0.24)
	lamp.mesh = box
	var glass := _material(Color("ffb060"), 0.3)
	glass.emission_enabled = true
	glass.emission = Color("ffb060")
	glass.emission_energy_multiplier = 3.0
	lamp.material_override = glass
	lamp.position = Vector3(-WIDTH * 0.5 + 0.4, 2.9, -0.2)
	add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc890")
	light.light_energy = 2.4
	light.omni_range = 7.0
	light.position = Vector3(-1.2, 2.6, 1.2)
	light.shadow_enabled = false
	add_child(light)
	_build_scales(rng)
	_build_lens()
	show_stock(stock)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _label(text: String, color: Color, size: int = 18) -> Node3D:
	## A word over a spot on the counter, written by the stage in 2D so it stays crisp on a
	## window bigger than the canvas the room is drawn at. `size` is in canvas pixels.
	var spot := Node3D.new()
	spot.set_meta("text", text)
	spot.set_meta("tone", color)
	spot.set_meta("font_size", size)
	spot.set_meta("alpha", 1.0)
	spot.add_to_group("stage_name")
	return spot

func _build_scales(rng: RandomNumberGenerator) -> void:
	scales = Node3D.new()
	scales.position = Vector3(SCALES_X, TOP, 0.05)
	add_child(scales)
	var brass := _material(Color("c9a26b"), 0.35)
	brass.metallic = 0.85
	var post := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.05
	rod.height = 0.75
	post.mesh = rod
	post.material_override = brass
	post.position = Vector3(0, 0.375, 0)
	scales.add_child(post)
	var beam := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.9, 0.035, 0.05)
	beam.mesh = bar
	beam.material_override = brass
	beam.position = Vector3(0, 0.74, 0)
	scales.add_child(beam)
	for side in [-1.0, 1.0]:
		var pan := Node3D.new()
		pan.position = Vector3(side * 0.42, 0.74, 0)
		scales.add_child(pan)
		var chain := MeshInstance3D.new()
		var cord := BoxMesh.new()
		cord.size = Vector3(0.01, 0.42, 0.01)
		chain.mesh = cord
		chain.material_override = brass
		chain.position = Vector3(0, -0.21, 0)
		pan.add_child(chain)
		var dish := MeshInstance3D.new()
		var plate := CylinderMesh.new()
		plate.top_radius = 0.2
		plate.bottom_radius = 0.14
		plate.height = 0.04
		plate.radial_segments = 12
		dish.mesh = plate
		dish.material_override = brass
		dish.position = Vector3(0, -0.43, 0)
		pan.add_child(dish)
		_pans.append(pan)
	_scales_label = _label("Sell", DeepUi.ORE, 18)
	_scales_label.position = Vector3(0, 1.02, 0.1)
	scales.add_child(_scales_label)
	_glows["scales"] = _glow_light(scales, DeepUi.ORE)

func _build_lens() -> void:
	lens = Node3D.new()
	lens.position = Vector3(LENS_X, TOP, 0.05)
	add_child(lens)
	var brass := _material(Color("b0905a"), 0.4)
	brass.metallic = 0.8
	var stand := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.09
	rod.height = 0.45
	stand.mesh = rod
	stand.material_override = brass
	stand.position = Vector3(0, 0.225, 0)
	lens.add_child(stand)
	var head := Node3D.new()
	head.position = Vector3(0, 0.62, 0)
	head.rotation = Vector3(PI * 0.5 - 0.35, 0, 0)
	lens.add_child(head)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.21
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = brass
	head.add_child(ring)
	var glass := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.012
	disc.radial_segments = 16
	glass.mesh = disc
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.7, 0.85, 1.0, 0.3)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.05
	clear.metallic_specular = 1.0
	clear.emission_enabled = true
	clear.emission = Color(0.5, 0.75, 1.0)
	clear.emission_energy_multiplier = 0.25
	glass.material_override = clear
	head.add_child(glass)
	_lens_label = _label("Appraise", DeepUi.INFO, 18)
	_lens_label.position = Vector3(0, 1.02, 0.1)
	lens.add_child(_lens_label)
	_glows["lens"] = _glow_light(lens, DeepUi.INFO)

func hide_words() -> void:
	## The stall packs up (it sinks with the room's business): its words go at once. They are
	## drawn flat over the room, and sank with it to float over the floor (review card X15).
	for spot in find_children("*", "Node3D", true, false):
		if spot.is_in_group("stage_name"):
			spot.set_meta("alpha", 0.0)

func _glow_light(parent: Node3D, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 1.8
	light.position = Vector3(0, 0.6, 0.5)
	light.shadow_enabled = false
	parent.add_child(light)
	return light

func set_scales_price(price: int) -> void:
	## While a stone is held over the pans they say what it would fetch; the rest of the time
	## the scales only say what they are for. A negative price is nothing on them.
	if _scales_label != null:
		_scales_label.set_meta("text", "Sell" if price < 0 else "Sell · %d pyrite" % price)
		_scales_label.set_meta("tone", DeepUi.DIM if bool(_shut.get("scales", false)) else DeepUi.ORE)

func set_lens_price(cost: int) -> void:
	_lens_cost = cost
	if _lens_label != null:
		_lens_label.set_meta("text", "Appraise · %d pyrite" % cost)
		_lens_label.set_meta("tone", DeepUi.DIM if bool(_shut.get("lens", false)) else (DeepUi.INFO if _purse < 0 or _purse >= cost else DEARER))

func set_shut(which: String, shut: bool) -> void:
	## Nothing for this player at the lens (no raw stone) or the scales (nothing to sell): its
	## word goes grey and it does not light when pointed at (the owner, November 17, 2026).
	if bool(_shut.get(which, false)) == shut:
		return
	_shut[which] = shut
	if which == "lens":
		set_lens_price(_lens_cost)
	elif which == "scales" and _scales_label != null:
		_scales_label.set_meta("tone", DeepUi.DIM if shut else DeepUi.ORE)
	if shut:
		glow(which, false)

func is_shut(which: String) -> bool:
	return bool(_shut.get(which, false))

func glow(which: String, on: bool) -> void:
	## A drop target lights while something that would go there is dragged, or pointed at.
	if on and bool(_shut.get(which, false)):
		return
	var light: OmniLight3D = _glows.get(which, null)
	if light != null:
		var tween := light.create_tween()
		tween.tween_property(light, "light_energy", 2.2 if on else 0.0, 0.15)

func weigh() -> void:
	## Something sold: the pans dip and come level.
	for i in range(_pans.size()):
		var pan: Node3D = _pans[i]
		var tween := pan.create_tween()
		tween.tween_property(pan, "position:y", 0.74 + (-0.08 if i == 0 else 0.06), 0.15)
		tween.tween_property(pan, "position:y", 0.74, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func show_stock(stock: Array) -> void:
	## Lays out what is for sale, three stones as a rule, left to right. Goods no longer in the
	## stock at all were cleared off by a Restock (review card S1): they sink away, and the new
	## goods rise into their places.
	var listed: Array = stock.map(func(item: Dictionary) -> String: return str(item.get("id", "")))
	var cleared: bool = false
	for id in _items.keys():
		if not listed.has(str(id)):
			_clear_item(str(id))
			cleared = true
	var fresh: bool = cleared or not _items.is_empty()
	var count: int = maxi(1, stock.size())
	for index in range(stock.size()):
		var item: Dictionary = stock[index]
		var id: String = str(item.get("id", ""))
		if _items.has(id) or not str(item.get("sold", "")).is_empty():
			continue
		var x: float = lerpf(-2.0, 2.0, float(index) / float(maxi(1, count - 1))) if count > 1 else 0.0
		var holder := Node3D.new()
		holder.position = Vector3(x, TOP + 0.42, 0.0)
		add_child(holder)
		var shown: Node3D
		var tone: Color
		if str(item.get("kind", "stone")) == "die":
			## A merchant keeps one die beside the stones, turning on its own stand.
			var die: Dictionary = item.get("die", {})
			var palette: Dictionary = DiceIcons.die_palette(die)
			shown = _faced_die(die)
			shown.scale = Vector3.ONE * 0.25
			tone = Color(palette.body)
		else:
			var stone: Dictionary = item.get("stone", {})
			shown = GemMesh.solid(stone)
			shown.scale = Vector3.ONE * 0.68 / float(shown.get_meta("extent", 1.0))
			shown.rotation = Vector3(deg_to_rad(-60), 0, 0)
			tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier))
			if DeepStone.is_slotless(stone):
				_hollow(shown, stone)
				tone = _void_tone(stone)
		var spinner := Node3D.new()
		holder.add_child(spinner)
		spinner.add_child(shown)
		var stand := MeshInstance3D.new()
		var foot := CylinderMesh.new()
		foot.top_radius = 0.12
		foot.bottom_radius = 0.16
		foot.height = 0.1
		foot.radial_segments = 8
		stand.mesh = foot
		stand.material_override = _material(Color("2a2622"), 0.6)
		stand.position = Vector3(0, -0.37, 0)
		holder.add_child(stand)
		var shine := OmniLight3D.new()
		shine.light_color = tone
		shine.light_energy = 0.7
		shine.omni_range = 1.3
		shine.position = Vector3(0, 0.3, 0.45)
		shine.shadow_enabled = false
		holder.add_child(shine)
		var price := _label("%d" % int(item.get("price", 0)), _price_tone(int(item.get("price", 0))), 20)
		price.position = Vector3(0, -0.27, 0.6)
		holder.add_child(price)
		var tag := _tag(item)
		## The phone's names stand larger (mine_stage.gd): a little further under the price.
		tag.position = Vector3(0, -(TAG_DROP + (0.14 if DeepUi.phone else 0.0)), 0.62)
		holder.add_child(tag)
		var lucky: bool = bool(item.get("lucky", false))
		var glints: Array = []
		if lucky:
			shine.light_color = lucky_tone()
			glints = _shimmer(holder)
		var marks: Array = _marks(item, holder, tag.position)
		_items[id] = {"holder": holder, "spinner": spinner, "shine": shine, "hover": false, "phase": float(index) * 1.3,
			"price_label": price, "tag": tag, "price": int(item.get("price", 0)), "lucky": lucky, "glints": glints, "marks": marks}
		if fresh and is_inside_tree():
			## A Restock's goods come up onto the cloth once the old ones have gone.
			holder.scale = Vector3.ONE * 0.01
			var pop := holder.create_tween()
			pop.tween_property(holder, "scale", Vector3.ONE, 0.45).set_delay(0.3 + 0.08 * float(index)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func lucky_tone() -> Color:
	## A lucky find's gold: the Flawless line's (`FlawlessFx.tone`), the game's word for "more
	## than it should be".
	return DeepUi.tier_color("PEERLESS")

static func _void_tone(stone: Dictionary) -> Color:
	## The rim a Void stone is lit at: its own hue, paled (as `VoidMarks.tone_of`).
	return GemMesh.tint(stone).lerp(Color.WHITE, 0.45)

func _marks(item: Dictionary, holder: Node3D, under: Vector3) -> Array:
	## The marks under a stone's tag: "Lucky find" in gold, "Void" in the Void's blue. Each is
	## a word the stage writes on a capsule of its own (`MarkPlate`); on the phone they step
	## down with a staggered row of tags (`MineStage._stagger_names`, `under_tags`).
	var words: Array = []
	if bool(item.get("lucky", false)):
		words.append(["Lucky find", lucky_tone(), false])
	if str(item.get("kind", "stone")) != "die" and DeepStone.is_slotless(item.get("stone", {})):
		words.append(["Void", DeepUi.VOID, true])
	var out: Array = []
	var drop: float = MARK_DROP + (0.1 if DeepUi.phone else 0.0)
	for index in range(words.size()):
		var said: Array = words[index]
		var spot := _label(str(said[0]), Color(said[1]).lightened(0.25), MARK_SIZE)
		spot.set_meta("plate", MarkPlate.new(Color(said[1]), bool(said[2])))
		spot.set_meta("font", DeepUi.bold_font())
		spot.set_meta("under_tags", true)
		spot.position = under - Vector3(0, drop + MARK_STEP * float(index) * (1.45 if DeepUi.phone else 1.0), 0)
		holder.add_child(spot)
		out.append(spot)
	return out

func _shimmer(holder: Node3D) -> Array:
	## A lucky find's gold: a soft halo behind the stone and four glints round it that wink in
	## turn (`_process`). The halo is the first of what comes back, the glints after it.
	if _glint_material == null:
		_glint_material = StandardMaterial3D.new()
		_glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glint_material.billboard_keep_scale = true
		_glint_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_glint_material.no_depth_test = true
		_glint_material.albedo_texture = BattleFx.sparkle_texture()
		_glint_material.albedo_color = Color(lucky_tone().lightened(0.35), 1.0)
		_halo_material = _glint_material.duplicate() as StandardMaterial3D
		_halo_material.no_depth_test = false
		_halo_material.albedo_texture = DeepUi.glow_texture()
		_halo_material.albedo_color = Color(lucky_tone(), 0.5)
	var out: Array = []
	var halo := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE
	halo.mesh = disc
	halo.material_override = _halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0, 0.02, -0.12)
	holder.add_child(halo)
	out.append(halo)
	for spot in GLINT_SPOTS:
		var glint := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		glint.mesh = quad
		glint.material_override = _glint_material
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.position = spot
		glint.scale = Vector3.ONE * 0.01
		holder.add_child(glint)
		out.append(glint)
	return out

func _hollow(shown: Node3D, stone: Dictionary) -> void:
	## A Void stone on the counter in the dock's Void look (VoidMarks' Hollow), made solid: dark
	## space with a few stars where the body was, every facet lit at its rim in the stone's own
	## paled hue. The far half goes; its own lamp takes the rim's color.
	var material: ShaderMaterial = VoidMarks.hollow_3d_material(_void_tone(stone))
	var meshes: Array = shown.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	for index in range(meshes.size()):
		var part: MeshInstance3D = meshes[index]
		if index < meshes.size() - 1:
			part.visible = false
			continue
		part.material_override = material
		part.material_overlay = null
	for lamp in shown.get_children():
		if lamp is OmniLight3D:
			(lamp as OmniLight3D).light_color = _void_tone(stone)
			(lamp as OmniLight3D).light_energy = 0.6

func _clear_item(id: String) -> void:
	## Goods put away by a Restock: they shrink into the cloth, their words fading with them.
	var entry: Dictionary = _items.get(id, {})
	_items.erase(id)
	var holder: Variant = entry.get("holder", null)
	if not holder is Node3D or not is_instance_valid(holder):
		return
	var words: Array = ([entry.get("price_label", null), entry.get("tag", null)] + entry.get("marks", [])).filter(func(n: Variant) -> bool: return n is Node3D)
	if not is_inside_tree():
		(holder as Node3D).queue_free()
		return
	var tween := (holder as Node3D).create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_method(func(alpha: float) -> void:
		for spot in words:
			if is_instance_valid(spot):
				(spot as Node3D).set_meta("alpha", alpha), 1.0, 0.0, 0.2)
	tween.tween_callback((holder as Node3D).queue_free)

func _tag(item: Dictionary) -> Node3D:
	## The name under the price: a gem's name, or a die's size ("d4"), the way the bag reads them.
	var words: String = ""
	var tone: Color = DeepUi.PAPER
	var outline: Array = DIAMOND
	if str(item.get("kind", "stone")) == "die":
		var die: Dictionary = item.get("die", {})
		var shape: String = str(die.get("shape", "D6"))
		words = shape.to_lower()
		tone = Color(DiceIcons.die_palette(die).body)
		outline = DiceIcons.silhouette(shape).points
	else:
		var stone: Dictionary = item.get("stone", {})
		words = str(DeepStone.skill_of(stone).get("name", DeepStone.name(stone)))
		tone = DeepUi.color(DeepStone.color(stone))
	var spot := _label(words, DeepUi.PAPER, TAG_SIZE)
	spot.set_meta("stagger", true)
	spot.set_meta("plate", TagPlate.new(tone, outline))
	spot.set_meta("font", DeepUi.bold_font())
	return spot

func set_purse(ore: int) -> void:
	## What the buyer can pay for reads off the counter at a glance: a price within the purse
	## in gold, one beyond it in a dull red. The lens says the same of its fee.
	_purse = ore
	for id in _items:
		var label: Variant = _items[id].get("price_label", null)
		if label is Node3D and is_instance_valid(label):
			(label as Node3D).set_meta("tone", _price_tone(int(_items[id].get("price", 0))))
	if _lens_label != null:
		_lens_label.set_meta("tone", DeepUi.DIM if bool(_shut.get("lens", false)) else (DeepUi.INFO if _purse < 0 or _purse >= _lens_cost else DEARER))

func _price_tone(price: int) -> Color:
	return DeepUi.ORE if _purse < 0 or _purse >= price else DEARER

func item_node(id: String) -> Node3D:
	return _items[id].holder if _items.has(id) and is_instance_valid(_items[id].holder) else null

func has_item(id: String) -> bool:
	return item_node(id) != null

func take(id: String) -> Node3D:
	## An item sold: it leaves the counter. Returns the goods themselves, for the stage to
	## send wherever they went; the stand and the price stay behind a moment and fade.
	if not _items.has(id):
		return null
	var entry: Dictionary = _items[id]
	_items.erase(id)
	var holder: Node3D = entry.holder
	if not is_instance_valid(holder):
		return null
	var spinner: Node3D = entry.spinner
	## Where it stands in the space it is handed to, worked out locally so it holds even
	## before anything is on screen.
	var at: Transform3D = transform * holder.transform * spinner.transform
	holder.remove_child(spinner)
	get_parent().add_child(spinner)
	spinner.transform = at
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE * 0.01, 0.35).set_delay(0.2)
	## The words are drawn flat over the room and do not shrink with it: they fade instead,
	## or the price and the tag would slide together into the empty stand.
	var words: Array = ([entry.get("price_label", null), entry.get("tag", null)] + entry.get("marks", [])).filter(func(n: Variant) -> bool: return n is Node3D)
	tween.parallel().tween_method(func(alpha: float) -> void:
		for spot in words:
			if is_instance_valid(spot):
				(spot as Node3D).set_meta("alpha", alpha), 1.0, 0.0, 0.25).set_delay(0.2)
	tween.tween_callback(holder.queue_free)
	return spinner

func set_hover(id: String, on: bool) -> void:
	if _items.has(id):
		_items[id].hover = on

func _process(delta: float) -> void:
	_clock += delta
	for id in _items:
		var entry: Dictionary = _items[id]
		var spinner: Node3D = entry.spinner
		if not is_instance_valid(spinner):
			continue
		spinner.rotation.y += delta * (1.4 if bool(entry.hover) else 0.45)
		spinner.position.y = sin(_clock * 1.3 + float(entry.phase)) * 0.025 + (0.06 if bool(entry.hover) else 0.0)
		var scale_goal: float = 1.18 if bool(entry.hover) else 1.0
		spinner.scale = spinner.scale.lerp(Vector3.ONE * scale_goal, clampf(delta * 10.0, 0.0, 1.0))
		(entry.shine as OmniLight3D).light_energy = 1.6 if bool(entry.hover) else 0.7
		if bool(entry.get("lucky", false)):
			## A lucky find breathes its gold, and its glints wink in turn round it.
			var breath: float = 0.5 + 0.5 * sin(_clock * 2.1 + float(entry.phase))
			(entry.shine as OmniLight3D).light_energy = (1.9 if bool(entry.hover) else 1.0) + 0.6 * breath
			var glints: Array = entry.get("glints", [])
			for index in range(glints.size()):
				var glint: Variant = glints[index]
				if not glint is MeshInstance3D or not is_instance_valid(glint):
					continue
				if index == 0:
					(glint as Node3D).scale = Vector3.ONE * (0.95 + 0.2 * breath)
					continue
				var wink: float = pow(maxf(0.0, sin(_clock * 2.6 + float(index) * 1.9 + float(entry.phase))), 4.0)
				(glint as Node3D).scale = Vector3.ONE * (0.04 + 0.3 * wink)

func _faced_die(die: Dictionary) -> Node3D:
	## The die as it rolls in a hand: each face shaded and numbered, etched faces tinted, so
	## what is for sale can be read off the counter and not just its outline.
	var node := Node3D.new()
	var shape: String = str(die.get("shape", "D6"))
	var built: Dictionary = DiceGeometry.solid(shape)
	var frames: Array = built.frames
	var palette: Dictionary = DiceIcons.die_palette(die)
	var faces: Array = die.get("faces", [])
	var colors := PackedColorArray()
	for index in range(frames.size()):
		var tone: Color = Color(palette.body).lightened(0.06 * float(index % 3))
		var kind: String = str(faces[index].get("kind", "plain")) if index < faces.size() and faces[index] is Dictionary else "plain"
		if kind != "plain":
			tone = tone.lerp(DiceIcons.face_kind_tint(kind), 0.55)
		colors.append(tone)
	for _i in range(frames.size(), built.faces.size()):
		colors.append(Color(palette.edge).lightened(0.12))
	var body := MeshInstance3D.new()
	body.mesh = DiceGeometry.mesh(shape, colors)
	var material := _material(Color.WHITE, 0.35)
	material.vertex_color_use_as_albedo = true
	body.material_override = material
	node.add_child(body)
	var numeral: Color = Color("15181f") if Color(palette.body).get_luminance() > 0.45 else Color("f4f7fb")
	for index in range(frames.size()):
		var frame: Dictionary = frames[index]
		var face: Variant = faces[index] if index < faces.size() else index + 1
		var value: int = int(face.get("value", index + 1)) if face is Dictionary else int(face)
		var kind: String = str(face.get("kind", "plain")) if face is Dictionary else "plain"
		var label := Label3D.new()
		label.text = DiceIcons.face_text(value, kind)
		label.font_size = 96
		label.outline_size = 0
		label.modulate = numeral
		label.double_sided = false
		label.shaded = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.pixel_size = float(frame.inradius) * 1.5 / (96.0 * (0.58 * float(maxi(1, label.text.length())) + 0.42))
		label.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), frame.centre + frame.normal * 0.006)
		node.add_child(label)
	return node

class TagPlate extends StyleBox:
	## A tag's plate (the stage sits the name on it, see `MineStage.NAME_GROUP`): a small Ledger
	## plate edged in the goods' color, and the pip in its left margin.
	var _plate: StyleBoxFlat
	var _pip: PackedVector2Array = PackedVector2Array()
	var _tone: Color

	func _init(tone: Color, outline: Array) -> void:
		_tone = tone
		_plate = DeepUi.ledger(DeepUi.SLATE_LOW, Color(tone, 0.7), 6, 3, 2, 2)
		for point in outline:
			_pip.append(Vector2(point))
		content_margin_left = 8.0 + TAG_PIP + 6.0
		content_margin_right = 10.0
		content_margin_top = 2.0
		content_margin_bottom = 3.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		_plate.draw(to_canvas_item, rect)
		var at := Vector2(rect.position.x + 8.0, rect.position.y + (rect.size.y - TAG_PIP) * 0.5)
		var shape := PackedVector2Array()
		for point in _pip:
			shape.append(at + point * TAG_PIP)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, shape, PackedColorArray([_tone]))
		var rim := shape.duplicate()
		rim.append(shape[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, rim, PackedColorArray([_tone.darkened(0.45)]), 1.0, true)

class MarkPlate extends StyleBox:
	## A mark under a stall stone's tag (review card S1, round 3): a capsule filled with its
	## tone's dark and edged in the tone, a small glyph in its left margin (a lucky find's
	## four-pointed glint, a Void's ring).
	var _plate: StyleBoxFlat
	var _tone: Color
	var _ring: bool

	func _init(tone: Color, ring: bool) -> void:
		_tone = tone
		_ring = ring
		_plate = StyleBoxFlat.new()
		_plate.bg_color = Color(tone.darkened(0.8), 0.94)
		_plate.border_color = Color(tone, 0.95)
		_plate.set_border_width_all(2)
		_plate.set_corner_radius_all(40)
		content_margin_left = 9.0 + TAG_PIP + 5.0
		content_margin_right = 11.0
		content_margin_top = 1.0
		content_margin_bottom = 2.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		_plate.draw(to_canvas_item, rect)
		var middle := Vector2(rect.position.x + 9.0 + TAG_PIP * 0.5, rect.position.y + rect.size.y * 0.5)
		var reach: float = TAG_PIP * 0.5
		if _ring:
			RenderingServer.canvas_item_add_circle(to_canvas_item, middle, reach, _tone.lightened(0.2))
			RenderingServer.canvas_item_add_circle(to_canvas_item, middle, reach * 0.55, _plate.bg_color)
			return
		var star := PackedVector2Array()
		for point in range(8):
			var angle: float = TAU * float(point) / 8.0 - PI * 0.5
			star.append(middle + Vector2(cos(angle), sin(angle)) * (reach * 1.15 if point % 2 == 0 else reach * 0.3))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, star, PackedColorArray([_tone.lightened(0.35)]))
