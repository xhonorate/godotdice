extends Node3D
## A merchant's stall, set up where a fight would stand: a timber counter between two posts
## with a sign hung over it and a lantern at one end; the goods laid out on a cloth, each a
## real stone turning slowly in its own light with its price in front of it (a merchant never
## sells dice); a pair of scales at one end for selling and a lens on a stand at the other for
## appraising.
##
## In room space, facing the party. It shows what it is told: the stock, what is sold, what
## the lens costs. What dragging and clicking mean is the run's business.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

const WIDTH := 7.2
const TOP := 1.06
const SCALES_X := -3.05
const LENS_X := 3.05

var scales: Node3D
var lens: Node3D
var _items: Dictionary = {}
var _lens_label: Label3D
var _scales_label: Label3D
var _pans: Array = []
var _glows: Dictionary = {}
var _clock: float = 0.0

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

func _label(text: String, color: Color, size: int = 40) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = DeepUi.display_font()
	label.font_size = size
	label.pixel_size = 0.0042
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.modulate = color
	label.double_sided = false
	return label

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
	_scales_label = _label("Sell", DeepUi.ORE, 36)
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
	_lens_label = _label("Appraise", DeepUi.INFO, 36)
	_lens_label.position = Vector3(0, 1.02, 0.1)
	lens.add_child(_lens_label)
	_glows["lens"] = _glow_light(lens, DeepUi.INFO)

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
		_scales_label.text = "Sell" if price < 0 else "Sell · %d pyrite" % price

func set_lens_price(cost: int) -> void:
	if _lens_label != null:
		_lens_label.text = "Appraise · %d pyrite" % cost

func glow(which: String, on: bool) -> void:
	## A drop target lights while something that would go there is dragged, or pointed at.
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
	## Lays out what is for sale, three stones as a rule, left to right.
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
		var stone: Dictionary = item.get("stone", {})
		var shown: Node3D = GemMesh.solid(stone)
		shown.scale = Vector3.ONE * 0.68 / float(shown.get_meta("extent", 1.0))
		shown.rotation = Vector3(deg_to_rad(-60), 0, 0)
		var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier))
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
		var price := _label("%d" % int(item.get("price", 0)), DeepUi.ORE, 44)
		price.position = Vector3(0, -0.27, 0.6)
		price.rotation = Vector3(-0.5, 0, 0)
		holder.add_child(price)
		_items[id] = {"holder": holder, "spinner": spinner, "shine": shine, "hover": false, "phase": float(index) * 1.3}

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
