extends RefCounted
## Dice drawn with their own shaders (view/dice/cuts/) instead of a StandardMaterial3D.
##
## The owner's picks (November 10, 2026, three review rounds: dbs `dice1`, `dice2`, `dice3`):
## the five gems cut as brilliants (`RUBY` .. `CITRINE`), diamond with fire (`DIAMOND`), a white
## opal (`OPAL`), a prismatic crystal (`CRYSTAL`), wet oxblood blood (`OXBLOOD`, which also bleeds
## when rolled again and feeds on a kill: blood_fx.gd), a polished fool's gold nugget (`NUGGET`),
## charcoal rough-hewn granite (`GRANITE`) and a silver storm cloud (`CLOUD`). dice_view.gd's
## MATERIAL_LOOKS wears them; glass and iron keep StandardMaterial3D looks there.
##
## A clear cut look costs no pass more than the shipped clear look: the far faces (cut_far)
## are one unshaded opaque pass, the near faces (cut_near) one lit premultiplied pass. An opaque
## look (cut_solid) is one lit pass and no inside at all. The mesh is the same solid fanned out
## from each face's middle (`mesh`), which is what lets a shader draw rings, a star or a window
## in the face's own outline. A look's features (`near_fx`, `far_fx`, `solid_fx`) are compiled
## into its shader (#define), so a die pays only for what it shows, and every die of one look
## shares one material.

const Geometry = preload("res://view/dice/dice_geometry.gd")

## The cut each technique is drawn with (cut_common's `facet`).
const BRILLIANT := 0
const SMOOTH := 3


const BRILLIANT_NEAR := {"cut": BRILLIANT, "window": 0.42, "tilt": 0.5, "alpha_mid": 0.45, "alpha_rim": 0.88,
	"edge_dark": 0.75, "diffuse": 0.08, "glow": 0.62, "sparkle": 2.6, "sharp": 40.0, "rough": 0.03, "metal": 0.0,
	"spec": 0.5, "coat": 1.0, "rim": 0.35}
const BRILLIANT_FAR := {"cut": BRILLIANT, "tilt": 1.0, "sharp": 14.0, "flash_gain": 1.6, "base_lo": 0.0,
	"base_hi": 1.0, "edge_dark": 0.6, "line_dark": 0.55}
const SMOOTH_NEAR := {"cut": SMOOTH, "tilt": 0.0, "alpha_mid": 0.2, "alpha_rim": 0.45, "edge_dark": 0.4,
	"diffuse": 0.1, "glow": 0.35, "sparkle": 0.0, "rough": 0.03, "metal": 0.0, "spec": 0.5, "coat": 1.0, "rim": 0.35}
const SMOOTH_FAR := {"cut": SMOOTH, "tilt": 0.0, "sharp": 5.0, "flash_gain": 0.7, "base_lo": 0.2, "base_hi": 0.7,
	"edge_dark": 0.45, "line_dark": 0.0}

## Each gem's colors, from the owner's photographs: `body` the stone's color, `deep` what it
## darkens to at the rim, `flash` the color its facets flash, `pale` its window.
const RUBY_COLORS := {"body": "a80c26", "deep": "250106", "flash": "ff2e5f", "pale": "ff9ab2"}
const SAPPHIRE_COLORS := {"body": "1b4cd6", "deep": "040d36", "flash": "3d86ff", "pale": "a8c6ff"}
const EMERALD_COLORS := {"body": "0e9c46", "deep": "023318", "flash": "4cf08a", "pale": "98f0bb"}
const AMETHYST_COLORS := {"body": "7629bd", "deep": "1c0536", "flash": "c27bff", "pale": "dcb6ff"}
const CITRINE_COLORS := {"body": "e5a024", "deep": "673303", "flash": "ffd468", "pale": "fff0b6"}

## The shipped gems: a brilliant's pavilion inside (bright and near-black facets that flash as
## the die turns), a crown on the skin, the stone's color going near-black at the rims.
const RUBY := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "a80c26", "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "colors": RUBY_COLORS, "far_over": {"base_hi": 0.9}}
const SAPPHIRE := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "1b4cd6", "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "colors": SAPPHIRE_COLORS, "far_over": {"flash_gain": 1.8}}
const EMERALD := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "0e9c46", "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "colors": EMERALD_COLORS}
const AMETHYST := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "7629bd", "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "colors": AMETHYST_COLORS}
const CITRINE := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "e5a024", "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "colors": CITRINE_COLORS, "far_over": {"base_lo": 0.15}}
## The shipped blood: opaque near-black oxblood marbled with darker veins under a wet coat,
## its numbers written white and ringed as a clear die's are.
const OXBLOOD := {"alpha": 1.0, "ring": true, "glint": 0.8, "shine": 1.6, "key_spec": 0.3, "cut": "oxblood",
	"body": "5a0711", "solid_fx": ["OXBLOOD"], "bleeds": true,
	"solid": {"body": "420409", "deep": "170104", "vein": "070001", "fresh": "7c0a18", "glow": 0.06,
		"rough": 0.32, "coat": 1.0, "bump": 0.0, "spec": 0.5, "scale": 1.0}}
## The shipped diamond: the brilliant again, ice-white, its flashes split into spectral colors
## (FIRE). `calm` quiets the fire and sparkle in the middle of each face, where the numeral
## sits, and darkens it a little, and the numerals carry a heavier ring (`ring_size`): the
## owner asked for its numbers to stay legible on every face at dock size.
const DIAMOND := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "brilliant",
	"body": "eef3fb", "ring_size": 22, "near": BRILLIANT_NEAR, "far": BRILLIANT_FAR, "near_fx": ["FIRE"], "far_fx": ["FIRE"],
	"colors": {"body": "eef3fb", "deep": "5d6a80", "flash": "ffffff", "pale": "ffffff"},
	"near_over": {"alpha_mid": 0.3, "alpha_rim": 0.62, "edge_dark": 0.5, "glow": 0.5, "sparkle": 3.0, "fire": 0.8, "calm": 0.62},
	"far_over": {"body": "dfe8f5", "deep": "0e1420", "base_hi": 0.9, "flash_gain": 2.0, "fire": 0.85, "sharp": 12.0, "calm": 0.62}}
## The shipped opal: milky white with harlequin patches of color that flare and change hue as it
## turns (PLAY), quiet behind the numeral (`calm`), its numerals heavily ringed.
const OPAL := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "opal",
	"body": "e3e6f0", "ring_size": 22, "near": SMOOTH_NEAR, "far": SMOOTH_FAR, "near_fx": ["PLAY"], "far_fx": ["PLAY"],
	"colors": {"body": "e3e6f0", "deep": "a9adc2", "pale": "ffffff", "flash": "ffffff"},
	"near_over": {"alpha_mid": 0.8, "alpha_rim": 0.92, "edge_dark": 0.3, "diffuse": 0.3, "glow": 0.18, "play": 0.75,
		"play_scale": 3.0, "play_sat": 0.85, "rough": 0.05, "calm": 0.62},
	"far_over": {"body": "dfe2ee", "deep": "8b8fa6", "base_lo": 0.6, "base_hi": 0.9, "flash_gain": 0.3, "edge_dark": 0.3,
		"play": 1.0, "calm": 0.62}}
## The shipped fool's gold: a smooth, softly dented brassy nugget polished to a mirror (DENTS).
const NUGGET := {"alpha": 1.0, "ring": true, "glint": 1.6, "shine": 1.5, "key_spec": 0.3, "cut": "nugget",
	"body": "e0b84a", "solid_fx": ["DENTS"],
	"solid": {"body": "e0b84a", "fresh": "fff0b0", "metal": 1.0, "rough": 0.1, "bump": 3.0, "coat": 0.5, "spec": 0.5, "glow": 0.0}}
## Crystal: clear, with bands of rainbow light running through its inside, each a little
## spectrum, sliding as the die turns (BANDS).
const CRYSTAL := {"alpha": 0.5, "clear": true, "glint": 0.45, "shine": 2.0, "key_spec": 0.12, "cut": "prismatic",
	"body": "eef0ff", "near": SMOOTH_NEAR, "far": SMOOTH_FAR, "far_fx": ["BANDS"],
	"colors": {"body": "eef0ff", "deep": "8a8fb8", "pale": "ffffff", "flash": "ffffff"},
	"near_over": {"alpha_mid": 0.16, "alpha_rim": 0.42},
	"far_over": {"body": "c9cdea", "deep": "12142a", "base_lo": 0.2, "base_hi": 0.6, "bands": 0.9}}
## Granite: charcoal grey, rough-hewn: angular mineral grains (GRANITE), unpolished relief
## (ROUGHHEWN), and mica flakes that glint only when one is tipped to a lamp (FLAKES).
const GRANITE := {"alpha": 1.0, "ring": true, "glint": 0.8, "shine": 1.6, "key_spec": 0.3, "cut": "granite",
	"body": "706b65", "solid_fx": ["GRANITE", "ROUGHHEWN", "FLAKES"],
	"solid": {"body": "706b65", "deep": "1e1c1b", "vein": "4b4b4e", "accent": "fff6e0", "sparkle": 5.0, "flake_amount": 0.35,
		"flake_scale": 16.0, "sharp": 30.0, "rough": 0.8, "coat": 0.0, "bump": 1.2, "grain": 22.0, "spec": 0.4, "glow": 0.0}}
## Cloud: a silvery storm cloud roiling slowly, lightning flickering through it (STORM).
const CLOUD := {"alpha": 1.0, "ring": true, "glint": 0.8, "shine": 1.6, "key_spec": 0.3, "cut": "storm",
	"body": "aab2c0", "solid_fx": ["STORM"],
	"solid": {"body": "aab2c0", "deep": "6a7383", "fresh": "dbe4f2", "accent": "fff6d8", "rough": 0.85, "coat": 0.0,
		"spec": 0.2, "bump": 0.4, "glow": 0.1}}


static var _materials: Dictionary = {}
static var _shaders: Dictionary = {}

static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for key in over:
		out[key] = over[key]
	return out

static func dress(chosen: Dictionary, key: String, body: MeshInstance3D, inner: MeshInstance3D) -> void:
	## Puts a cut look's materials on a die's near faces and its inside. `key` names the look
	## (its material and option) so every die wearing it shares the same materials.
	var tone: Color = Color(str(chosen.get("body", "ffffff")))
	var colors: Dictionary = chosen.get("colors", {})
	if chosen.has("solid"):
		body.material_override = _material(key + ":solid", "solid", chosen.get("solid_fx", []), _merge(chosen.solid, colors), tone)
		return
	var near: Dictionary = _merge(_merge(chosen.near, colors), chosen.get("near_over", {}))
	body.material_override = _material(key + ":near", "near", chosen.get("near_fx", []), near, tone)
	if inner != null:
		var far: Dictionary = _merge(_merge(chosen.far, colors), chosen.get("far_over", {}))
		inner.material_override = _material(key + ":far", "far", chosen.get("far_fx", []), far, tone)

static func _shader(role: String, features: Array) -> Shader:
	## One shader for each pass and set of features, shared by every look that asks for them.
	var key: String = role + ":" + ",".join(features)
	if _shaders.has(key):
		return _shaders[key]
	var code: String = "shader_type spatial;\n"
	for feature in features:
		code += "#define %s\n" % str(feature)
	code += "#include \"res://view/dice/cuts/cut_%s.gdshaderinc\"\n" % role
	var shader := Shader.new()
	shader.code = code
	_shaders[key] = shader
	return shader

static func _material(key: String, role: String, features: Array, params: Dictionary, tone: Color) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = _shader(role, features)
	material.set_shader_parameter("tone_base", tone)
	for name in params:
		var value: Variant = params[name]
		if name == "cut":
			material.set_shader_parameter(name, int(value))
		elif value is String and str(value).is_valid_html_color():
			material.set_shader_parameter(name, Color(str(value)))
		else:
			material.set_shader_parameter(name, value)
	_materials[key] = material
	return material

static func mesh(shape: String, colors: PackedColorArray) -> ArrayMesh:
	## The solid with each face fanned out from its middle, each corner saying where in the face
	## it is (cut_common.gdshaderinc). Same faces, normals, colors and grooves' UVs as
	## Geometry.mesh, so it lies exactly where the plain mesh does.
	var built := Geometry.solid(shape)
	var points: PackedVector3Array = built.vertices
	var faces: Array = built.faces
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for index in range(faces.size()):
		var face: PackedInt32Array = faces[index]
		var frame: Dictionary = built.surface_frames[index]
		var color: Color = colors[index % colors.size()] if colors.size() > 0 else Color.WHITE
		var centre: Vector3 = frame.centre
		var sides: int = face.size()
		for side in range(sides):
			var a: Vector3 = points[face[side]]
			var b: Vector3 = points[face[(side + 1) % sides]]
			## Wound as Geometry.mesh winds (clockwise seen from outside): middle, b, a.
			for corner in [[centre, 0.0, 0.0], [b, 0.0, 1.0], [a, 1.0, 0.0]]:
				var point: Vector3 = corner[0]
				surface.set_normal(frame.normal)
				surface.set_color(color)
				surface.set_uv(Vector2((point - centre).dot(frame.right), (point - centre).dot(frame.up)) * 0.5 + Vector2(0.5, 0.5))
				surface.set_custom(0, Color(float(corner[1]), float(corner[2]), float(side), float(sides)))
				surface.set_custom(1, Color(centre.x, centre.y, centre.z, float(index)))
				surface.add_vertex(point)
	surface.generate_tangents()
	surface.index()
	return surface.commit()
