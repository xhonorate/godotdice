extends Control
## A Geode in 3D, on the shelf or on the bench (docs/GOLD.md §3.3).
##
## `geode_mesh.gd` cuts the rock; this lights it, sways it and plays it out. `blows` cracks it:
## a hairline from the top of the seam, then the seam run through with light behind it and
## cracks branching off it. `split` from 0 to 1 swings the halves open like a book, so both
## faces of the hollow turn to the viewer; `light` is the light inside, which shows in the
## cracks first and fills the hollow once it is open; `open` lays it on the shelf opened and
## empty; `hover` brightens the seam. `bench` is the ceremony's framing: the Geode larger, and
## its halves falling back and apart to leave room for the stone rising between them.
##
## Built the way `gem_view.gd` is: its own world in a SubViewport composited over the 2D behind
## it, and with no display the 3D half is skipped, so the ceremony and the shelf never branch.

const GeodeMesh = preload("res://view/gems/geode_mesh.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const GemView = preload("res://view/gems/gem_view.gd")

## Vertical field of view: narrow, so the Geode has depth without its near side ballooning.
const FOV := 24.0
## How much of the Geode's height the frame leaves round it, closed, as half-heights in units.
const SHELF_FRAME := 1.22
const BENCH_FRAME := 1.42
## How the halves lie once open: swung toward the viewer, apart, back, down and tipped up.
const SHELF_OPEN: Dictionary = {"swing": 64.0, "spread": 1.02, "back": 0.0, "drop": 0.0, "tip": 22.0, "lean": 5.0}
const BENCH_OPEN: Dictionary = {"swing": 64.0, "spread": 1.22, "back": 1.4, "drop": 0.42, "tip": 24.0, "lean": 9.0}
## How far past its own box the bench's picture may reach, so the halves falling apart are
## never cut off at the stage's edges: the extra is transparent.
const BENCH_BLEED := Vector2(1.6, 1.3)
## Turned a little to its left and tipped toward the viewer, so it reads as a solid.
const REST := Vector3(0.2, -0.32, 0.0)
## Key, fill and the light from behind that finds its edges: energy, color, where it stands.
const LIGHTS: Array = [[1.55, "fff1dc", Vector3(-42, -38, 0)], [0.45, "9fb6ff", Vector3(8, 62, 0)], [1.15, "", Vector3(-28, 168, 0)]]

var tone: Color
var geode: Dictionary = {}
var bench := false
var blows: int = 0:
	set(value):
		var struck: bool = value == blows + 1
		blows = value
		if struck:
			_struck()
		_mark()
var split: float = 0.0:
	set(value):
		var opening: bool = split <= 0.0 and value > 0.0
		split = value
		if opening:
			_burst()
		_pose()
		_shine()
var light: Color = Color(1, 0.95, 0.8, 0.0):
	set(value):
		light = value
		_shine()
		_mark()
var open: bool = false:
	set(value):
		open = value
		_pose()
		_shine()
		_wake()
var hover: float = 0.0:
	set(value):
		hover = value
		_mark()
		_wake()
## The ceremony's restless bob while it waits for the first blow.
var wobble: bool = false:
	set(value):
		wobble = value
		_wake()
## The slow sway every Geode on the shelf has while nobody is doing anything to it.
var drifting: bool = true:
	set(value):
		drifting = value
		_wake()
## Handed to the reader (the close look): dragging turns it, and it stays where it is left.
var turnable := false
var _turn := Vector2.ZERO
var _dragging := false
const TURN_PER_PIXEL := 0.01

var _built: Dictionary = {}
var _frame: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _root: Node3D
var _halves: Array = []
var _lamps: Array = []
var _seam_hint: MeshInstance3D
var _crack_short: MeshInstance3D
var _crack_full: MeshInstance3D
var _branches: Array = []
var _materials: Dictionary = {}
var _shadow: Control
var _fx: Control
var _clock: float = 0.0
var _kick: float = 0.0
var _kick_axis := Vector3.ZERO
var _puff: Array = []
## Chips of rock still in the air.
var _flying: int = 0
var _seed: int = 1
## A Geode not cut yet this session is cut on a worker thread, and put together here once it is.
var _task: int = -1
var _cutting: Dictionary = {}
## Frames left in which a still Geode asks for one more picture. A single request can be
## spent before the page has finished laying out, leaving the frame blank.
var _settle: int = 0
## Waiting for its turn to start drawing, a few new views to a frame (see GemView).
var _held: bool = false

func _init(shelf_geode: Dictionary = {}, color: Color = Color.WHITE) -> void:
	geode = shelf_geode
	tone = color
	_seed = GeodeMesh.seed_of(shelf_geode)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	clip_contents = false
	_shadow = Control.new()
	_shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)
	if not _headless():
		_build()
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	resized.connect(_fit)
	_fit()
	_pose()
	_shine()
	_mark()
	_wake()

static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

# --- building -------------------------------------------------------------------------------------

static var _sky: Sky = null

static func release() -> void:
	## Lets go of the shared sky and grit before the renderer shuts down.
	_sky = null
	_grit = null
	_speckle = null

static func _shared_sky() -> Sky:
	if _sky == null:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("9fb6e0")
		sky_material.sky_horizon_color = Color("d8dde8")
		sky_material.ground_horizon_color = Color("5c5850")
		sky_material.ground_bottom_color = Color("221f1c")
		sky_material.energy_multiplier = 0.7
		_sky = Sky.new()
		_sky.sky_material = sky_material
	return _sky

func _build() -> void:
	## The room at once; the Geode in it as soon as it is cut.
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.use_debanding = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frame.add_child(_viewport)
	var wait: int = GemView._take_draw_slot()
	if wait > 0:
		_start_later(wait)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.1
	_camera.far = 40.0
	_camera.position = Vector3(0, 0, 7)
	var environment := Environment.new()
	## A sky for the polished face and the crystal to mirror, as the gems have: one for every
	## Geode, its light worked out once (see GemView._shared_sky).
	environment.sky = _shared_sky()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.4
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 1.0
	## The crystal and the cracks bloom; the rock does not.
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	## Shade where the knobs meet and down among the crystal points.
	environment.ssao_enabled = true
	environment.ssao_radius = 0.3
	environment.ssao_intensity = 1.6
	environment.ssao_detail = 1.0
	_camera.environment = environment
	_viewport.add_child(_camera)
	var look: Dictionary = GeodeMesh.LOOKS[GeodeMesh.look_of(geode)]
	for spec in LIGHTS:
		var lamp := DirectionalLight3D.new()
		lamp.light_energy = float(spec[0])
		lamp.light_color = Color(str(spec[1])) if not str(spec[1]).is_empty() else Color(str(look.rim))
		lamp.rotation_degrees = spec[2]
		lamp.light_specular = 1.4
		_viewport.add_child(lamp)
		if not str(spec[1]).is_empty() and lamp.light_energy > 1.0:
			lamp.shadow_enabled = true
			lamp.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			lamp.directional_shadow_max_distance = 14.0
			lamp.shadow_blur = 1.5
	_root = Node3D.new()
	_viewport.add_child(_root)
	var known: Dictionary = GeodeMesh.cached(geode, tone)
	if not known.is_empty():
		_assemble(known)
		return
	var holder: Dictionary = _cutting
	var shelf_geode: Dictionary = geode.duplicate(true)
	var color: Color = tone
	_task = WorkerThreadPool.add_task(func() -> void: holder.made = GeodeMesh.cut(shelf_geode, color), false, "Cut a Geode")
	set_process(true)

func _assemble(built: Dictionary) -> void:
	_built = built
	_dress(GeodeMesh.LOOKS[str(_built.look)])
	for index in range(2):
		var side: int = -1 if index == 0 else 1
		var half := Node3D.new()
		_root.add_child(half)
		var body := MeshInstance3D.new()
		body.mesh = _built.halves[index]
		var mesh: ArrayMesh = body.mesh
		for surface in range(mesh.get_surface_count()):
			body.set_surface_override_material(surface, _materials.get(mesh.surface_get_name(surface), _materials.rind))
		half.add_child(body)
		## A lamp in the hollow, lighting the crystal from inside once the half is open.
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(float(side) * 0.22, 0.0, 0.0)
		lamp.omni_range = 1.5
		lamp.omni_attenuation = 1.4
		lamp.light_energy = 0.0
		## No highlights of its own: on flat facets they read as a scatter of bright dots.
		lamp.light_specular = 0.0
		half.add_child(lamp)
		_halves.append(half)
		_lamps.append(lamp)
	var seam: PackedVector3Array = _built.seam
	_seam_hint = _crack(seam, 0.011, false, _root, _materials.hint)
	_crack_short = _crack(seam.slice(0, GeodeMesh.HAIRLINE + 2), 0.022, true, _root, _materials.line)
	_crack_full = _crack(seam, 0.03, false, _root, _materials.line)
	for branch in _built.branches:
		var half: Node3D = _halves[0 if int(branch.side) < 0 else 1]
		_branches.append(_crack(branch.points, 0.024, true, half, _materials.line))
	_pose()
	_shine()
	_mark()
	_wake()

func _collect() -> void:
	## Picks up a Geode the worker has finished cutting, and fades it in.
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _cutting.has("made"):
		return
	_assemble(GeodeMesh.finish(_cutting.made))
	_frame.modulate.a = 0.0
	create_tween().tween_property(_frame, "modulate:a", 1.0, 0.25)

func _notification(what: int) -> void:
	## A view thrown away mid-cut waits for its worker, which must always be collected.
	if what == NOTIFICATION_PREDELETE and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _dress(_look: Dictionary) -> void:
	_materials = dress(_built, tone)

static func prop(shelf_geode: Dictionary, color: Color) -> Node3D:
	## The Geode shut, as a piece of a 3D scene (a Warden's pedestal): both halves of the rock,
	## about a unit in radius, turned the way the shelf holds it. Cut on the spot, so this is
	## for the one Geode in a room and not for a shelf of them.
	var built: Dictionary = GeodeMesh.build(shelf_geode, color)
	var materials: Dictionary = dress(built, color)
	var root := Node3D.new()
	for half in built.halves:
		var body := MeshInstance3D.new()
		body.mesh = half
		var mesh: ArrayMesh = body.mesh
		for surface in range(mesh.get_surface_count()):
			body.set_surface_override_material(surface, materials.get(mesh.surface_get_name(surface), materials.rind))
		root.add_child(body)
	## The seam it will crack along, faintly lit, so a shut rock reads as a Geode and not a boulder.
	var line := MeshInstance3D.new()
	line.mesh = GeodeMesh.ribbon(built.seam, 0.016, false)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ribbon: ArrayMesh = line.mesh
	(materials.hint as StandardMaterial3D).emission_energy_multiplier = 1.6
	for surface in range(ribbon.get_surface_count()):
		line.set_surface_override_material(surface, materials.gap if ribbon.surface_get_name(surface) == "gap" else materials.hint)
	root.add_child(line)
	root.rotation = REST
	return root

static func dress(built: Dictionary, tone: Color) -> Dictionary:
	## One material per kind of surface, shared by both halves of a Geode: its view's, or the
	## closed rock on a hoard's pedestal.
	var look: Dictionary = GeodeMesh.LOOKS[str(built.look)]
	var materials: Dictionary = {}
	var rind := _flat(float(look.rough))
	rind.metallic_specular = 0.3
	_gritty(rind, 2.4, 1.0)
	if bool(look.get("wet", false)):
		rind.clearcoat_enabled = true
		rind.clearcoat = 0.7
		rind.clearcoat_roughness = 0.2
	materials.rind = rind
	var glow := _flat(0.6)
	glow.emission_enabled = true
	glow.emission = built.glow_tone
	glow.emission_energy_multiplier = 2.2
	materials.glow = glow
	## The face is cut and polished: it takes the sky.
	var face := _flat(0.4)
	face.metallic_specular = 0.45
	_gritty(face, 3.0, 0.25)
	materials.face = face
	var wall := _flat(0.75)
	materials.wall = wall
	var crystal := _flat(0.16)
	crystal.metallic_specular = 0.5
	crystal.rim_enabled = true
	crystal.rim = 0.25
	crystal.rim_tint = 0.8
	crystal.emission_enabled = true
	crystal.emission = tone
	crystal.emission_energy_multiplier = 0.0
	materials.crystal = crystal
	var spur := _flat(0.08)
	spur.metallic_specular = 0.8
	spur.rim_enabled = true
	spur.rim = 0.3
	spur.rim_tint = 0.8
	spur.emission_enabled = true
	spur.emission = built.spur_tone
	spur.emission_energy_multiplier = 0.2
	materials.spur = spur
	var brass := _flat(0.3)
	brass.metallic = 0.85
	materials.brass = brass
	var line := StandardMaterial3D.new()
	line.albedo_color = Color.BLACK
	line.roughness = 1.0
	line.emission_enabled = true
	line.emission = Color("f3e2b0")
	materials.line = line
	var hint := line.duplicate() as StandardMaterial3D
	hint.emission = tone
	materials.hint = hint
	var gap := StandardMaterial3D.new()
	gap.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gap.albedo_color = Color("0b0807")
	materials.gap = gap
	return materials

## The grit on the crust and the speckle in it, mapped on from all three sides because the
## rock has no UVs. Made once and shared by every Geode.
static var _grit: NoiseTexture2D = null
static var _speckle: NoiseTexture2D = null

static func _gritty(made: StandardMaterial3D, scale: float, strength: float) -> void:
	if _grit == null:
		var bumps := FastNoiseLite.new()
		bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX
		bumps.fractal_octaves = 4
		bumps.frequency = 0.035
		_grit = NoiseTexture2D.new()
		_grit.width = 256
		_grit.height = 256
		_grit.seamless = true
		_grit.as_normal_map = true
		_grit.bump_strength = 6.0
		_grit.noise = bumps
		var specks := FastNoiseLite.new()
		specks.noise_type = FastNoiseLite.TYPE_CELLULAR
		specks.frequency = 0.06
		specks.fractal_octaves = 2
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.72, 0.72))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		ramp.add_point(0.55, Color(0.93, 0.93, 0.93))
		_speckle = NoiseTexture2D.new()
		_speckle.width = 256
		_speckle.height = 256
		_speckle.seamless = true
		_speckle.color_ramp = ramp
		_speckle.noise = specks
	made.uv1_triplanar = true
	made.uv1_triplanar_sharpness = 2.0
	made.uv1_scale = Vector3.ONE * scale
	made.normal_enabled = true
	made.normal_texture = _grit
	made.normal_scale = strength
	made.albedo_texture = _speckle

static func _flat(rough: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	made.vertex_color_is_srgb = true
	made.roughness = rough
	return made

func _crack(points: PackedVector3Array, width: float, taper: bool, parent: Node3D, glow: Material) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.mesh = GeodeMesh.ribbon(points, width, taper)
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: ArrayMesh = made.mesh
	for surface in range(mesh.get_surface_count()):
		made.set_surface_override_material(surface, _materials.gap if mesh.surface_get_name(surface) == "gap" else glow)
	made.visible = false
	parent.add_child(made)
	return made

# --- what it shows ----------------------------------------------------------------------------------

func _amount() -> float:
	## How far open it is: the split as it plays, or all the way on the shelf once bought.
	return 1.0 if open else split

func _fit() -> void:
	## The camera backs off far enough for the closed Geode to fill the frame, and on the shelf
	## for both open halves to fit across it; on the bench the halves fall back instead.
	if _camera == null or size.y <= 1.0:
		return
	var bleed: Vector2 = BENCH_BLEED if bench else Vector2.ONE
	_frame.size = size * bleed
	_frame.position = (size - _frame.size) * 0.5
	var aspect: float = size.x / size.y
	var closed: float = (BENCH_FRAME if bench else SHELF_FRAME) * bleed.y
	var pose: Dictionary = BENCH_OPEN if bench else SHELF_OPEN
	var across: float = (float(pose.spread) + 1.06) * 1.04 / aspect
	var reach: float = lerpf(closed, maxf(closed, across), clampf(_amount(), 0.0, 1.0)) if not bench else closed
	_camera.position.z = reach / tan(deg_to_rad(FOV * 0.5))
	_redraw()

func _pose() -> void:
	## The halves, from shut to lying open.
	if _halves.is_empty():
		return
	var amount: float = _amount()
	var pose: Dictionary = BENCH_OPEN if bench else SHELF_OPEN
	for index in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var half: Node3D = _halves[index]
		var swing: Basis = Basis(Vector3.UP, side * deg_to_rad(float(pose.swing)) * amount)
		var tip: Basis = Basis(Vector3.RIGHT, -deg_to_rad(float(pose.tip)) * amount)
		var lean: Basis = Basis(Vector3.BACK, -side * deg_to_rad(float(pose.lean)) * amount)
		half.transform = Transform3D(lean * tip * swing, Vector3(side * float(pose.spread), -float(pose.drop), -float(pose.back)) * amount)
	_fit()
	_place()
	_mark()

func _place() -> void:
	## The whole Geode's turn: at rest, swaying, jolted by a blow. Open, it faces square on.
	if _root == null:
		return
	var amount: float = clampf(_amount(), 0.0, 1.0)
	var sway: float = 0.0
	if wobble and blows == 0:
		sway = 1.0
	elif drifting and not open:
		sway = 0.75
	sway += hover * 0.4
	sway *= 1.0 - amount
	var turn := Vector3(REST.x + sin(_clock * 0.53 + 1.1) * 0.05 * sway, REST.y + sin(_clock * 0.71) * 0.24 * sway, sin(_clock * 0.43 + 0.4) * 0.03 * sway) * (1.0 - amount)
	turn += _kick_axis * _kick * sin(_clock * 46.0) * 0.6
	## The reader's own turn, open or shut: round about its upright, and tipped toward them.
	turn += Vector3(_turn.y, _turn.x, 0.0)
	_root.rotation = turn
	var squash: float = 0.05 * _kick
	_root.scale = Vector3(1.0 + squash, 1.0 - squash * 1.3, 1.0 + squash)
	_root.position = Vector3(0.0, sin(_clock * 2.1) * 0.025 * sway + hover * 0.04, 0.0)
	_redraw()

func _mark() -> void:
	## The seam and the cracks: a faint line it will split along, brighter while the pointer
	## is on its button; then the hairline, then the crack run through and the light in it.
	if _seam_hint == null:
		return
	var shut: bool = _amount() <= 0.001
	_seam_hint.visible = shut and blows == 0
	(_materials.hint as StandardMaterial3D).emission_energy_multiplier = 0.35 + 2.2 * hover
	_crack_short.visible = shut and blows == 1
	_crack_full.visible = shut and blows >= 2
	for index in range(_branches.size()):
		(_branches[index] as MeshInstance3D).visible = blows >= 2 or (blows == 1 and index < 2)
	var lit: Color = light if light.a > 0.0 else Color("f3e2b0")
	var line: StandardMaterial3D = _materials.line
	line.emission = Color(lit.r, lit.g, lit.b)
	var pulse: float = 0.8 + 0.2 * sin(_clock * 6.0)
	line.emission_energy_multiplier = (0.8 if blows <= 1 else 2.4 + 2.6 * light.a * pulse) * (1.0 - clampf(_amount(), 0.0, 1.0) * 0.6)
	_redraw()

func _shine() -> void:
	## The light in the hollow: the stone's own once it is cracked open, the Geode's color
	## left dim in an emptied one on the shelf.
	if _lamps.is_empty():
		return
	var amount: float = clampf(_amount(), 0.0, 1.0)
	## The lamp takes the light's color; the crystal keeps its own and only glows brighter.
	var lit: Color = tone.lerp(light, 0.65) if light.a > 0.0 and not open else tone
	var strength: float = (light.a if not open else 0.35) * amount
	for lamp in _lamps:
		(lamp as OmniLight3D).light_color = Color(lit.lightened(0.15), 1.0)
		(lamp as OmniLight3D).light_energy = 0.2 + 1.1 * strength if amount > 0.0 else 0.0
	var crystal: StandardMaterial3D = _materials.crystal
	crystal.emission = Color(tone.r, tone.g, tone.b)
	crystal.emission_energy_multiplier = 0.04 + 0.3 * strength
	_redraw()

# --- turned by hand -------------------------------------------------------------------------------

func enable_interaction() -> void:
	## For the close look: the shelf's sway stops, and a drag turns it.
	turnable = true
	drifting = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE

func _gui_input(event: InputEvent) -> void:
	if not turnable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_turn.x += event.relative.x * TURN_PER_PIXEL
		_turn.y = clampf(_turn.y + event.relative.y * TURN_PER_PIXEL, -1.3, 1.3)
		_place()
		accept_event()

# --- the blows ------------------------------------------------------------------------------------

func dust(at: Vector2) -> void:
	## Grit in the air after a blow, at a point in this control's own space.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 99 + blows
	for i in range(18):
		_puff.append({"at": at + Vector2(rng.randf_range(-60, 60), rng.randf_range(-90, -20)), "v": Vector2(rng.randf_range(-40, 40), rng.randf_range(-90, -20)), "life": 1.0})
	_wake()

func _struck() -> void:
	## A blow lands: the rock jolts and chips fly from where the crack is opening.
	_kick = 1.0
	_kick_axis = Vector3(randf_range(-0.05, 0.05), randf_range(-0.08, 0.08), randf_range(-0.06, 0.06))
	if _built.is_empty() or _root == null:
		return
	var seam: PackedVector3Array = _built.seam
	var at: Vector3 = seam[mini(seam.size() - 1, GeodeMesh.HAIRLINE if blows == 1 else seam.size() / 2)]
	_chips(_root.transform * at, 5 + 3 * blows, 0.05)
	_wake()

func _burst() -> void:
	## It splits: a spray of rock from all along the seam.
	if _built.is_empty() or _root == null or not is_inside_tree():
		return
	var seam: PackedVector3Array = _built.seam
	for index in range(0, seam.size(), 3):
		_chips(_root.transform * seam[index], 3, 0.07)

func _chips(at: Vector3, count: int, size_of: float) -> void:
	if _viewport == null or not is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rock: Color = Color(str(GeodeMesh.LOOKS[str(_built.look)].rind))
	for _i in range(count):
		var chip := MeshInstance3D.new()
		chip.mesh = GemRock.boulder(rng, size_of * rng.randf_range(0.6, 1.3), rock).mesh
		chip.material_override = _materials.rind
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_viewport.add_child(chip)
		chip.position = at
		var away := Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.8))
		var spin := Vector3(rng.randf_range(-14, 14), rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		var life: float = rng.randf_range(0.55, 0.85)
		var tween := chip.create_tween()
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(chip):
				chip.position = at + away * t * 1.4 + Vector3(0, -4.2 * t * t, 0)
				chip.rotation = spin * t
				chip.scale = Vector3.ONE * (1.0 - t * 0.5), 0.0, 1.0, life)
		_flying += 1
		tween.tween_callback(func() -> void:
			_flying -= 1
			chip.queue_free())
	_wake()

# --- running ------------------------------------------------------------------------------------------

func _live() -> bool:
	## Whether anything is moving, and so whether the camera has to run every frame.
	return wobble or (drifting and not open) or hover > 0.0 or _kick > 0.0 or not _puff.is_empty() or _flying > 0 \
		or (blows >= 2 and _amount() <= 0.0) or (split > 0.0 and split < 1.0 and not open)

func _start_later(frames: int) -> void:
	_held = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	## The main loop's frames rather than this view's tree: a view the Market keeps between its
	## drawings can be off the page (out of the tree) while it waits.
	var loop := Engine.get_main_loop() as SceneTree
	for _i in range(frames):
		await loop.process_frame
	if not is_instance_valid(self) or _viewport == null:
		return
	_held = false
	_wake()
	_redraw()

func _wake() -> void:
	if not is_inside_tree():
		return
	var live: bool = _live()
	set_process(live or _task >= 0 or _settle > 0)
	if _viewport != null and not _held:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE

func _redraw() -> void:
	if _viewport != null and not _held and _viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_settle = 3
		if is_inside_tree():
			set_process(true)
	if is_instance_valid(_shadow):
		_shadow.queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	if _task >= 0:
		_collect()
		if _task >= 0:
			return
	var live: bool = _live()
	if live:
		if _kick > 0.0:
			_kick = maxf(0.0, _kick - delta * 3.2)
		_place()
		if blows >= 2:
			_mark()
		if not _puff.is_empty():
			_drift_puff(delta)
			_fx.queue_redraw()
	if _settle > 0:
		_settle -= 1
		if _viewport != null and not _held and _viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not _live():
		_wake()

func _draw_shadow() -> void:
	## The shadow it casts on whatever it sits on, and when it is open, under each half.
	var glow: Texture2D = DeepUi.glow_texture()
	var amount: float = clampf(_amount(), 0.0, 1.0)
	var width: float = minf(size.x * 0.8, size.y * 1.1) * lerpf(1.0, 1.6, amount if not bench else 0.0)
	var depth: float = size.y * 0.12
	var shown: float = 1.0 - (amount if bench else 0.0)
	if shown > 0.01:
		_shadow.draw_texture_rect(glow, Rect2(Vector2((size.x - width) * 0.5, size.y * 0.86 - depth * 0.5), Vector2(width, depth)), false, Color(0, 0, 0, 0.6 * shown))

func _drift_puff(delta: float) -> void:
	## The dust moves by the frame's own time, so it falls as fast at any frame rate.
	for p in _puff:
		p.life = float(p.life) - delta
		p.at = Vector2(p.at) + Vector2(p.v) * delta
		p.v = Vector2(p.v) + Vector2(0, 220) * delta
	_puff = _puff.filter(func(p: Dictionary) -> bool: return float(p.life) > 0.0)

func _draw_fx() -> void:
	for p in _puff:
		_fx.draw_circle(p.at, 1.6 + 1.6 * float(p.life), Color(0.85, 0.79, 0.66, float(p.life)))
