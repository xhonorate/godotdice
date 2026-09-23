extends Node3D
## A way on, seen from the room: a tunnel mouth in the far wall, lit from inside by what
## waits down it once the room's business is done.
##
## A revealed chamber spills its own color out of the dark and drifts motes into the room,
## with its mark carved on a plaque over the arch and lit from below. A dark mouth shows only
## two glints far inside. The landing glows warm. Every vote hangs in the arch as a small
## lantern in the voter's color. Sealed by a rockfall, a mouth is dark.

const Tunnel = preload("res://view/battle/tunnel.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

var index: int = 0
var entry: Dictionary = {}
## "dark" (a hole, nothing known yet), "open" (lit by what waits) or "sealed".
var state: String = "dark"
var hovered: bool = false

var _level: float = 0.0
var _clock: float = 0.0
var _light: OmniLight3D
var _haze: MeshInstance3D
var _haze_material: StandardMaterial3D
var _motes: GPUParticles3D
var _motes_material: ParticleProcessMaterial
var _plaque: Node3D
var _glyph: Sprite3D
var _under: OmniLight3D
var _glints: Array = []
var _lamps: Node3D

func _ready() -> void:
	_clock = randf() * 10.0
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.8, -3.2)
	_light.omni_range = 8.5
	_light.omni_attenuation = 1.1
	_light.light_energy = 0.0
	_light.light_volumetric_fog_energy = 2.2
	_light.shadow_enabled = false
	add_child(_light)
	## A breath of color deep in the mouth, where the light turns the bend.
	_haze = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(Tunnel.WIDTH * 1.1, Tunnel.HEIGHT)
	_haze.mesh = quad
	_haze_material = StandardMaterial3D.new()
	_haze_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_haze_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_haze_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_haze_material.albedo_texture = DeepUi.glow_texture()
	_haze_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_haze_material.albedo_color = Color(1, 1, 1, 0)
	_haze.material_override = _haze_material
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haze.position = Vector3(0, Tunnel.HEIGHT * 0.45, -2.6)
	add_child(_haze)
	_motes = GPUParticles3D.new()
	_motes_material = ParticleProcessMaterial.new()
	_motes_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_motes_material.emission_box_extents = Vector3(1.1, 1.2, 1.0)
	_motes_material.direction = Vector3(0, 0.3, 1)
	_motes_material.spread = 25.0
	_motes_material.initial_velocity_min = 0.3
	_motes_material.initial_velocity_max = 0.9
	_motes_material.gravity = Vector3(0, 0.04, 0)
	_motes_material.turbulence_enabled = true
	_motes_material.turbulence_noise_strength = 0.5
	_motes_material.scale_min = 0.04
	_motes_material.scale_max = 0.09
	_motes.process_material = _motes_material
	_motes.draw_pass_1 = load("res://view/battle/battle_fx.gd").quad(true)
	_motes.amount = 18
	_motes.lifetime = 3.2
	_motes.local_coords = true
	_motes.emitting = false
	_motes.position = Vector3(0, 1.7, -2.4)
	_motes.visibility_aabb = AABB(Vector3(-3, -3, -4), Vector3(6, 6, 10))
	add_child(_motes)
	## The plaque over the arch, and the mark of what waits on it.
	_plaque = Node3D.new()
	_plaque.position = Vector3(0, Tunnel.HEIGHT + 0.95, 0.25)
	add_child(_plaque)
	var slab := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	slab.mesh = load("res://view/battle/lowpoly.gd").slab(Vector3(1.35, 1.1, 0.3), Color("2a2622"), rng, 0.05)
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 0.9
	slab.material_override = stone
	_plaque.add_child(slab)
	_glyph = Sprite3D.new()
	_glyph.shaded = false
	_glyph.double_sided = false
	_glyph.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_glyph.position = Vector3(0, 0, 0.17)
	_glyph.modulate = Color(1, 1, 1, 0)
	_plaque.add_child(_glyph)
	_under = OmniLight3D.new()
	_under.position = Vector3(0, Tunnel.HEIGHT + 0.25, 0.9)
	_under.omni_range = 2.6
	_under.light_energy = 0.0
	_under.shadow_enabled = false
	add_child(_under)
	## Two glints in a dark mouth: something down there, and nothing more.
	for side in [-1.0, 1.0]:
		var glint := Sprite3D.new()
		glint.texture = DeepUi.glow_texture()
		glint.shaded = false
		glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glint.pixel_size = 0.14 / 64.0
		glint.modulate = Color(1.0, 0.9, 0.6, 0.0)
		glint.position = Vector3(side * 0.16, 1.75, -4.5)
		add_child(glint)
		_glints.append(glint)
	_lamps = Node3D.new()
	add_child(_lamps)
	if not entry.is_empty():
		configure(entry)

func configure(new_entry: Dictionary) -> void:
	## {kind, color, glyph, hidden, voters: [Color], mine}
	entry = new_entry
	if _glyph == null:
		return
	var glyph: String = str(entry.get("glyph", "arch"))
	var texture: Texture2D = GemIcons.texture(glyph, 128)
	_glyph.texture = texture
	_glyph.pixel_size = 0.78 / float(maxi(1, texture.get_width()))
	var color: Color = entry.get("color", Color.WHITE)
	_light.light_color = entry.get("light", color)
	_under.light_color = color
	_haze_material.albedo_color = Color(color, _haze_material.albedo_color.a)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.4), 0.0))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.2, Color(color.lightened(0.3), 0.9))
	var texture_ramp := GradientTexture1D.new()
	texture_ramp.gradient = ramp
	_motes_material.color_ramp = texture_ramp
	for child in _lamps.get_children():
		child.queue_free()
	var voters: Array = entry.get("voters", [])
	for i in range(voters.size()):
		var lamp := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.1
		ball.height = 0.2
		ball.radial_segments = 8
		ball.rings = 4
		lamp.mesh = ball
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(voters[i]) * 2.2
		lamp.material_override = glow
		var spread: float = (float(i) - float(voters.size() - 1) * 0.5) * 0.36
		lamp.position = Vector3(spread, Tunnel.HEIGHT - 0.45 - 0.08 * absf(spread), 0.05)
		_lamps.add_child(lamp)

func set_state(new_state: String) -> void:
	state = new_state
	if _motes != null:
		_motes.emitting = state == "open" and not bool(entry.get("hidden", false))

func set_hover(on: bool) -> void:
	hovered = on

func brighten() -> void:
	## Lit at once, without the slow swell: the room was built lit.
	_level = 1.0

func _process(delta: float) -> void:
	_clock += delta
	var hidden: bool = bool(entry.get("hidden", false))
	var goal: float = 0.0
	if state == "open":
		goal = 1.0 + (0.45 if hovered else 0.0) + (0.25 if bool(entry.get("mine", false)) else 0.0)
	_level = move_toward(_level, goal, delta * (3.0 if goal > _level else 5.0))
	var flicker: float = 0.88 + 0.12 * sin(_clock * 6.3) * sin(_clock * 2.7 + 1.0)
	_light.light_energy = (0.0 if hidden else 2.8) * _level * flicker
	_haze_material.albedo_color.a = (0.05 if hidden else 0.22) * _level * flicker
	_under.light_energy = 1.2 * _level
	var color: Color = entry.get("color", Color.WHITE)
	var lit: float = clampf(_level, 0.0, 1.5)
	var plain: bool = bool(entry.get("plain", false))
	_glyph.modulate = Color(color.lightened(0.1) * (0.7 + 0.5 * lit), 0.0 if plain else clampf(0.15 + 0.85 * lit, 0.0, 1.0) * (0.45 if hidden else 1.0))
	var swell: float = 1.0 + (0.12 if hovered and state == "open" else 0.0) + (0.04 * sin(_clock * 3.0) if bool(entry.get("mine", false)) and state == "open" else 0.0)
	_plaque.scale = _plaque.scale.lerp(Vector3.ONE * swell, clampf(delta * 10.0, 0.0, 1.0))
	for i in range(_glints.size()):
		var blink: float = clampf(sin(_clock * 0.9 + float(i) * 1.7) * 4.0, 0.0, 1.0)
		(_glints[i] as Sprite3D).modulate.a = (0.9 * blink * _level) if hidden else 0.0
	_lamps.visible = state == "open"
