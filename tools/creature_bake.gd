extends SceneTree
## Bakes creature scenes from recipes: each recipe is data (shapes, where they sit, what
## material they wear, how they idle) and the result is an editable .tscn in
## view/creatures/scenes, exactly the shape `CrystalCreature` expects. Run headless:
##
##   /path/to/Godot --headless --path . --script tools/creature_bake.gd            # every recipe
##   /path/to/Godot --headless --path . --script tools/creature_bake.gd -- RAIL_RAT PIT_MOLE
##
## Recipes live in tools/creature_recipes/<mine>.gd, one file a mine, each a class with
## `static func recipes() -> Dictionary` of creature key to recipe:
##
##   {"style": "low", "sway": 3.0, "tint": "a8927a", "accent": "ffb24a", "anchor": 1.2,
##    "warden": false, "shadow": 2.2, "ring": 1.15, "parts": [ ... ]}
##
## A part: {"shape": ..., "at": [x, y, z], "rot": [deg x, y, z], "scale": s or [x, y, z],
## "material": "body" | "core" | "accent", "motion": any CrystalCreaturePart motion,
## "phase": 0.0, "side": 1.0, "seed": 7} plus the shape's own numbers:
##   rock(jitter, squash[3])  crystal(radius, height, sides)  spike(sides, radius, height, lean)
##   column(sides, radius, height)  cap(radius, height, sides)  slab(size[3], jitter)
##   shard(size)  dome(radius)  ring(radius, width, segments)  prism(size[3])
##   sphere(radius, segments, rings)  cylinder(top, bottom, height, sides)  cone(radius, height, sides)
##   box(size[3])  torus(inner, outer, rings, segments)  capsule(radius, height, segments)
## Positions are in creature units: a Cave Tick is about 1 high, a Warden about 3.
## The whole recipe may name "scale" to size the finished body at once.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const Part = preload("res://view/creatures/creature_part.gd")
const CreatureScript = preload("res://view/creatures/crystal_creature.gd")
const RECIPE_DIR: String = "res://tools/creature_recipes/"
const SCENE_DIR: String = "res://view/creatures/scenes/"

func _init() -> void:
	var wanted: Array = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if not str(arg).begins_with("--"):
			wanted.append(str(arg))
	var all: Dictionary = recipes()
	var keys: Array = wanted if not wanted.is_empty() else all.keys()
	keys.sort()
	var baked: int = 0
	for key in keys:
		if not all.has(key):
			printerr("no recipe for ", key)
			continue
		var errors: Array = validate(str(key), all[key])
		if not errors.is_empty():
			for error in errors:
				printerr("RECIPE %s: %s" % [key, error])
			continue
		bake(str(key), all[key])
		baked += 1
	print("Baked %d creature scenes" % baked)
	quit(0 if baked == keys.size() else 1)

static func recipes() -> Dictionary:
	## Every recipe from every file in the recipe directory.
	var out: Dictionary = {}
	var dir := DirAccess.open(RECIPE_DIR)
	if dir == null:
		return out
	var names: Array = []
	for file in dir.get_files():
		if str(file).ends_with(".gd"):
			names.append(str(file))
	names.sort()
	for file in names:
		var script: GDScript = load(RECIPE_DIR + file)
		if script == null or not script.has_method("recipes"):
			continue
		var found: Dictionary = script.call("recipes")
		for key in found:
			out[str(key)] = found[key]
	return out

static func validate(key: String, recipe: Dictionary) -> Array:
	var errors: Array = []
	if not recipe.get("parts", []) is Array or recipe.get("parts", []).is_empty():
		errors.append("needs parts")
	if not str(recipe.get("tint", "")).is_valid_html_color():
		errors.append("needs a tint colour")
	for part in recipe.get("parts", []):
		if not part is Dictionary:
			errors.append("every part is an object")
			continue
		if not str(part.get("shape", "")) in SHAPES:
			errors.append("unknown shape " + str(part.get("shape", "")))
		if not str(part.get("material", "body")) in ["body", "core", "accent"]:
			errors.append("material is body, core or accent")
		if not str(part.get("motion", "static")) in MOTIONS:
			errors.append("unknown motion " + str(part.get("motion", "")))
	return errors

const SHAPES: Array = ["rock", "crystal", "spike", "column", "cap", "slab", "shard", "dome", "ring", "prism", "sphere", "cylinder", "cone", "box", "torus", "capsule"]
const MOTIONS: Array = ["static", "crystal", "core", "block", "wing", "orbit", "spin", "bob", "swing", "tread", "flicker"]

static func _vec(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is float or value is int:
		return Vector3.ONE * float(value)
	return fallback

static func material(tone: Color, role: String) -> StandardMaterial3D:
	## The three materials a creature wears: a faceted body, a dim glowing core, and an
	## accent (a lamp, a fire, an eye) that glows harder than either.
	var m := StandardMaterial3D.new()
	m.resource_local_to_scene = true
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	match role:
		"core":
			m.albedo_color = tone.darkened(0.6)
			m.roughness = 0.7
			m.emission = tone.lightened(0.2)
			m.emission_energy_multiplier = 1.4
		"accent":
			m.albedo_color = tone.darkened(0.2)
			m.roughness = 0.4
			m.metallic = 0.1
			m.emission = tone
			m.emission_energy_multiplier = 2.2
		_:
			m.albedo_color = tone.darkened(0.25)
			m.roughness = 0.18
			m.metallic = 0.25
			m.metallic_specular = 0.9
			m.emission = tone
			m.emission_energy_multiplier = 0.22
			m.rim_enabled = true
			m.rim = 1.0
			m.rim_tint = 0.3
	return m

static func mesh_for(part: Dictionary, rng: RandomNumberGenerator) -> Mesh:
	var white := Color.WHITE
	match str(part.get("shape", "rock")):
		"rock": return Lowpoly.rock(rng, white, float(part.get("jitter", 0.28)), _vec(part.get("squash", null), Vector3.ONE))
		"crystal": return Lowpoly.crystal(rng, white, float(part.get("radius", 0.18)), float(part.get("height", 1.2)), int(part.get("sides", 6)))
		"spike": return Lowpoly.spike(rng, white, int(part.get("sides", 5)), float(part.get("radius", 0.3)), float(part.get("height", 1.6)), float(part.get("lean", 0.12)))
		"column": return Lowpoly.column(rng, white, int(part.get("sides", 6)), float(part.get("radius", 0.4)), float(part.get("height", 2.0)))
		"cap": return Lowpoly.cap(rng, white, Color(0.85, 0.85, 0.85), float(part.get("radius", 0.8)), float(part.get("height", 0.45)), int(part.get("sides", 8)))
		"slab": return Lowpoly.slab(_vec(part.get("size", null), Vector3(1, 0.5, 1)), white, rng, float(part.get("jitter", 0.05)))
		"shard": return Lowpoly.shard(rng, white, float(part.get("size", 0.12)))
		"dome": return Lowpoly.hex_dome(float(part.get("radius", 1.0)))
		"ring": return Lowpoly.ring(float(part.get("radius", 1.0)), float(part.get("width", 0.1)), int(part.get("segments", 24)))
		"prism":
			var prism := PrismMesh.new()
			prism.size = _vec(part.get("size", null), Vector3(1, 1, 0.05))
			return prism
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = float(part.get("radius", 0.5))
			sphere.height = sphere.radius * 2.0
			sphere.radial_segments = int(part.get("segments", 8))
			sphere.rings = int(part.get("rings", 4))
			return sphere
		"cylinder", "cone":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0 if str(part.shape) == "cone" else float(part.get("top", 0.4))
			cyl.bottom_radius = float(part.get("radius", part.get("bottom", 0.4)))
			cyl.height = float(part.get("height", 1.0))
			cyl.radial_segments = int(part.get("sides", 8))
			cyl.rings = 1
			return cyl
		"box":
			var box := BoxMesh.new()
			box.size = _vec(part.get("size", null), Vector3.ONE)
			return box
		"torus":
			var torus := TorusMesh.new()
			torus.inner_radius = float(part.get("inner", 0.3))
			torus.outer_radius = float(part.get("outer", 0.5))
			torus.rings = int(part.get("rings", 10))
			torus.ring_segments = int(part.get("segments", 6))
			return torus
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = float(part.get("radius", 0.3))
			capsule.height = float(part.get("height", 1.0))
			capsule.radial_segments = int(part.get("segments", 8))
			capsule.rings = 3
			return capsule
	return Lowpoly.rock(rng, white)

static func bake(key: String, recipe: Dictionary) -> void:
	var tint := Color(str(recipe.get("tint", "9a7dff")))
	var accent := Color(str(recipe.get("accent", recipe.get("tint", "ffffff"))))
	var warden: bool = bool(recipe.get("warden", false))
	var body_material := material(tint.lerp(Color("ff5a4a"), 0.35) if warden else tint, "body")
	if warden:
		body_material.emission_energy_multiplier = 0.4
	var core_material := material(tint.lerp(Color("ff5a4a"), 0.35) if warden else tint, "core")
	var accent_material := material(accent, "accent")
	var root := Node3D.new()
	root.name = key.to_pascal_case()
	root.set_script(CreatureScript)
	root.set("key", key)
	root.set("warden", warden)
	root.set("style", str(recipe.get("style", "cluster")))
	root.set("sway", float(recipe.get("sway", 1.0)))
	root.set("body_material", body_material)
	root.set("core_material", core_material)
	root.set("accent_material", accent_material)
	root.set("normal_tint", tint)
	root.set("normal_accent", accent)
	var whole: float = 1.5 if warden else 1.0
	root.scale = Vector3.ONE * whole * float(recipe.get("scale", 1.0))
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var counts: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var index: int = 0
	for part in recipe.get("parts", []):
		index += 1
		var motion: String = str(part.get("motion", "static"))
		var label: String = str(part.get("name", motion if motion != "static" else str(part.get("shape", "part"))))
		counts[label] = int(counts.get(label, 0)) + 1
		var pivot := Node3D.new()
		pivot.name = "%s%02d" % [label.to_pascal_case(), counts[label]]
		pivot.position = _vec(part.get("at", null), Vector3.ZERO)
		var tilt: Vector3 = _vec(part.get("rot", null), Vector3.ZERO)
		pivot.rotation_degrees = tilt
		pivot.set_script(Part)
		pivot.set("motion", motion)
		pivot.set("phase", float(part.get("phase", float(index) * 0.9)))
		pivot.set("wing_side", float(part.get("side", 1.0)))
		body.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		if part.has("seed"):
			rng.seed = int(part.seed)
		mesh.mesh = mesh_for(part, rng)
		match str(part.get("material", "body")):
			"core": mesh.material_override = core_material
			"accent": mesh.material_override = accent_material
			_: mesh.material_override = body_material
		mesh.scale = _vec(part.get("scale", null), Vector3.ONE)
		mesh.rotation_degrees = _vec(part.get("mesh_rot", null), Vector3.ZERO)
		mesh.position = _vec(part.get("offset", null), Vector3.ZERO)
		pivot.add_child(mesh)
	var anchor := Marker3D.new()
	anchor.name = "Anchor"
	anchor.position = Vector3(0, float(recipe.get("anchor", 1.6)), 0)
	root.add_child(anchor)
	## Its own light, thrown on the floor around it.
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = tint
	light.light_energy = 2.6 if warden else 1.4
	light.omni_range = 5.0 if warden else 3.2
	light.light_volumetric_fog_energy = 1.5
	light.position = Vector3(0, float(recipe.get("anchor", 1.6)) * 0.45, 0.4)
	root.add_child(light)
	## A soft shadow pooled beneath it.
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var disc := QuadMesh.new()
	var width: float = float(recipe.get("shadow", 2.2))
	disc.size = Vector2(width, minf(width, 2.2))
	disc.orientation = PlaneMesh.FACE_Y
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_texture = DeepUi.glow_texture()
	dark.albedo_color = Color(0, 0, 0, 0.75)
	dark.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	disc.material = dark
	shadow.mesh = disc
	shadow.position = Vector3(0, 0.03, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	## The target ring, hidden until the party picks this creature.
	var ring := MeshInstance3D.new()
	ring.name = "TargetRing"
	ring.mesh = Lowpoly.ring(float(recipe.get("ring", 1.15)), 0.09, 40)
	var ring_material := StandardMaterial3D.new()
	ring_material.resource_local_to_scene = true
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.albedo_color = Color(DeepUi.ACCENT, 0.0)
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_material
	ring.position = Vector3(0, 0.05, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	_own(root, root)
	var packed := PackedScene.new()
	var packed_ok: int = packed.pack(root)
	assert(packed_ok == OK)
	var path: String = SCENE_DIR + key.to_lower() + ".tscn"
	var saved: int = ResourceSaver.save(packed, path)
	assert(saved == OK)
	print("baked ", path)
	root.free()

static func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
