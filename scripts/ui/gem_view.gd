extends Control
## One gem rendered as real 3D geometry inside its own SubViewport, the way the dice are.
##
## Static views render a single frame and then stop, so a screen showing nineteen gems
## costs nineteen one-off renders rather than nineteen live cameras. The inspect sheet
## turns its own view on and hands it to the reader to drag, exactly like the die
## inspector does.
##
## `gem_mesh.gd` decides what the stone looks like; this only lights it and shows it.
## With no display — the test suites and any headless tool — the 3D half is skipped and
## the halo behind it still draws, so callers never have to branch.
##
## A view can be given a ground with `set_ground()`, and that changes what kind of picture
## it is. Ungrounded, the viewport is transparent and the stone is composited over whatever
## 2D sits behind it — which the 3D scene cannot see, so refraction has nothing to bend and
## screen-space reflections are switched off by the engine. Grounded, the background moves
## inside the viewport: the stone blends against it in 3D, so refraction bends it, SSR
## returns, and alpha finally means what it says. The cost is that the view is then an
## opaque rectangle, so its ground has to match what surrounds it.

const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Tuning = preload("res://scripts/ui/gem_tuning.gd")

## Face-on, tipped just enough to catch the crown and a sliver of the pavilion.
const REST := Vector3(-13.0, -11.0, 0.0)
## Orthogonal camera height in world units; the ground is fitted to it.
const CAMERA_SIZE := 2.10
## Far enough behind the stone that no rotation reaches it, near enough to stay in frame.
const GROUND_DEPTH := -2.6
const HALO_DEPTH := -1.6
const TURN_PER_PIXEL := 0.011
const SETTLE := 7.0
## Four lights from four quarters, so a turning stone always has facets catching one and
## facets in shadow. Two was enough for a die and far too few for a gem. Energy, colour,
## and where it stands; the tuning table scales all four together and leaves the balance.
const LIGHTS := [
	[1.20, "fff4de", Vector3(-38, -34, 0)],
	[0.42, "86b0ff", Vector3(26, 140, 0)],
	[0.62, "cfe4ff", Vector3(42, -128, 0)],
	[0.80, "ffffff", Vector3(-12, 168, 0)]]

var gem: Dictionary = {}
var interactive := false
## Transparent alpha means no ground: the view stays a hole and is composited over the 2D
## behind it. Any opaque colour stands the stone on that colour instead.
## The box the stone is measured against, in pixels. Zero means the control's own size,
## which is what the game wants: a gem is sized against the slot it is set in, and a heavy
## one is then drawn past the edges of it. A caller with room to spare — the gem lab — can
## name a smaller slot and keep the drawing area large, so the overflow has somewhere to go.
var slot: float = 0.0
var ground: Color = Color(0, 0, 0, 0)
var ground_texture: Texture2D = null

var _viewport: SubViewport
var _frame: SubViewportContainer
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _lights: Array = []
var _pivot: Node3D
var _ground: MeshInstance3D
var _halo: MeshInstance3D
var _body: MeshInstance3D
var _shell: MeshInstance3D
var _etch: MeshInstance3D
var _glow: Control
var _signature := ""
var _manual := Quaternion.IDENTITY
var _goal := Quaternion.IDENTITY
var _dragging := false
## A caller may configure this before the tree gets round to building the viewport,
## so what was asked for is remembered and applied once the 3D half exists.
var _wants_interaction := false
## Radians per second of idle turn. Zero leaves the stone where the reader put it.
var _spin := 0.0
## The slow sway every gem has at rest. Its size and speed are in the tuning table.
var drifting := true
var _clock := 0.0
## One radial gradient serves every halo; only its tint and size change.
static var _halo_texture: ImageTexture

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow.bind(_glow))
	add_child(_glow)
	if headless():
		return
	# Placed by hand rather than anchored, because a heavy stone is drawn into a frame
	# larger than the slot the layout gave this control. See `_fit_frame`.
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.disable_3d = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.use_debanding = true
	# A stone that never moves does not need a camera running every frame.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frame.add_child(_viewport)
	resized.connect(_fit_frame)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.position = Vector3(0, 0, 5)
	camera.near = 0.05
	camera.far = 20.0
	_environment = Environment.new()
	# Clear background, but a real sky behind the scenes for the facets to mirror. Flat
	# ambient colour gave them nothing to reflect, and a gem that reflects nothing reads
	# as coloured plastic however well it is lit.
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("8fb4ef")
	_sky_material.sky_horizon_color = Color("dce6f4")
	_sky_material.ground_horizon_color = Color("6a7488")
	_sky_material.ground_bottom_color = Color("2b3242")
	_sky_material.sun_angle_max = 24.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Highlights are what sell a gem. ACES rolls them off instead of clipping flat, and
	# glow lets the ones that clip anyway bloom into the sparkle a cut stone throws. Both
	# of these do real work under Forward+; under the Compatibility renderer this project
	# used to run, glow through a SubViewport did nothing at all.
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_white = 3.2
	_environment.glow_enabled = true
	_environment.glow_strength = 0.95
	_environment.glow_bloom = 0.03
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.glow_hdr_scale = 2.0
	# Facets mirroring facets and the ground they stand on. Godot switches this off in a
	# viewport with a transparent background, so it only does anything once a ground is set.
	_environment.ssr_max_steps = 48
	_environment.ssr_fade_in = 0.1
	_environment.ssr_fade_out = 1.6
	_environment.ssr_depth_tolerance = 0.3
	# A little contact shadow where facets meet, so the cut reads as cut.
	_environment.ssao_radius = 0.35
	_environment.ssao_detail = 1.0
	camera.environment = _environment
	_viewport.add_child(camera)
	for spec: Array in LIGHTS:
		var light := DirectionalLight3D.new()
		light.light_color = Color(str(spec[1]))
		light.rotation_degrees = spec[2]
		light.light_specular = 2.0
		_viewport.add_child(light)
		_lights.append(light)
	# Everything the tuning table owns is set in one place, so moving a knob later runs the
	# same code that set it up.
	_tune()
	# The ground and the halo stand behind the stone and do not turn with it, so they hang
	# off the viewport rather than the pivot. Both are drawn before the stone, which is what
	# puts them in the buffer its refraction reads.
	_ground = MeshInstance3D.new()
	_ground.mesh = QuadMesh.new()
	_ground.position = Vector3(0, 0, GROUND_DEPTH)
	var ground_material := StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_material.disable_receive_shadows = true
	_ground.material_override = ground_material
	_viewport.add_child(_ground)
	_halo = MeshInstance3D.new()
	_halo.mesh = QuadMesh.new()
	_halo.position = Vector3(0, 0, HALO_DEPTH)
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.albedo_texture = _halo_gradient()
	halo_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	halo_material.render_priority = -1
	_halo.material_override = halo_material
	_viewport.add_child(_halo)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	# The far side of the stone, drawn before the near side. This replaces the dark
	# back-faced shell the dice use for an outline: seen through a transparent gem that
	# shell read as a black core, and the stone stopped looking like glass.
	_shell = MeshInstance3D.new()
	_pivot.add_child(_shell)
	_body = MeshInstance3D.new()
	_pivot.add_child(_body)
	_etch = MeshInstance3D.new()
	_body.add_child(_etch)
	_manual = Quaternion.from_euler(Vector3(deg_to_rad(REST.x), deg_to_rad(REST.y), 0.0))
	_goal = _manual
	_pivot.quaternion = _manual
	_wake()
	_apply_ground()
	if _wants_interaction:
		enable_interaction()
	if not gem.is_empty():
		_apply()

func configure(new_gem: Dictionary) -> void:
	## Safe to call before this node is in the tree: the stone is cut on `_ready` instead.
	gem = new_gem
	var signature := "%s|%d|%d|%d" % [Catalog.canonical_key(str(gem.get("key", ""))),
		int(gem.get("carat", 1)), int(gem.get("cut", 1)), int(gem.get("clarity", 1))]
	if signature == _signature:
		return
	_signature = signature
	tooltip_text = GemMesh.describe(gem) if interactive else GemMesh.describe(gem).trim_suffix(" Drag to turn it.")
	if is_instance_valid(_glow):
		_glow.queue_redraw()
	_apply()

func set_ground(color: Color, texture: Texture2D = null) -> void:
	## Stands the stone on something. See the note at the top of this file: this is the
	## difference between a transparent cut-out and a picture the stone is part of. Pass a
	## fully transparent colour to go back to the cut-out.
	ground = color
	ground_texture = texture
	_apply_ground()

func _halo_gradient() -> ImageTexture:
	if _halo_texture != null:
		return _halo_texture
	var span := 128
	var built := Image.create(span, span, false, Image.FORMAT_RGBA8)
	var middle := float(span - 1) * 0.5
	for y in span:
		for x in span:
			var reach: float = Vector2(float(x) - middle, float(y) - middle).length() / middle
			# Falls to nothing well before the rim, so the quad has no visible edge.
			built.set_pixel(x, y, Color(1, 1, 1, pow(maxf(1.0 - reach, 0.0), 2.6)))
	_halo_texture = ImageTexture.create_from_image(built)
	return _halo_texture

func _apply_ground() -> void:
	if headless() or _viewport == null or _environment == null or _ground == null:
		return
	var standing: bool = ground.a > 0.001
	_viewport.transparent_bg = not standing
	_environment.background_mode = Environment.BG_COLOR if standing else Environment.BG_CLEAR_COLOR
	_environment.background_color = Color(ground.r, ground.g, ground.b)
	_environment.ssr_enabled = standing and Tuning.flag("ssr")
	var material: StandardMaterial3D = _ground.material_override
	material.albedo_color = Color(ground.r, ground.g, ground.b)
	material.albedo_texture = ground_texture
	# With no texture the background colour already fills the frame, so the quad is only
	# needed when the ground has a pattern to show.
	_ground.visible = standing and ground_texture != null
	_halo.visible = standing
	# The 2D halo is drawn behind the viewport, where an opaque one hides it. Grounded, the
	# same light is thrown by a quad inside the scene, which the stone can then refract.
	if is_instance_valid(_glow):
		_glow.visible = not standing
	_fit_ground()
	_redraw()

func set_slot(pixels: float) -> void:
	## Measures the stone against a box other than this control. See `slot`.
	slot = pixels
	_fit_frame()

func _fit_frame() -> void:
	## Works out how much room the stone needs and where that room comes from. Everything up
	## to the slot is drawn inside the control; anything past it grows the viewport around
	## the same centre, so a heavy stone hangs over the edges instead of being cropped at
	## them. Nothing here changes the space the gem takes up in a row of gems — only how far
	## its picture reaches out of that space.
	if headless() or _frame == null:
		return
	var reach: float = minf(size.x, size.y)
	if reach <= 1.0:
		return
	var box: float = slot if slot > 0.0 else reach
	var span: float = 1.0 if gem.is_empty() else GemMesh.carat_span(int(gem.get("carat", 1)))
	var want: float = span * box
	var grown: float = maxf(1.0, want / reach)
	_frame.size = size * grown
	_frame.position = (size - _frame.size) * 0.5
	if is_instance_valid(_pivot):
		_pivot.scale = Vector3.ONE * (want / (reach * grown))
	_fit_ground()

func _fit_ground() -> void:
	## The ground covers the whole orthogonal frame, whatever shape the view has been given.
	if headless() or _ground == null:
		return
	var reach: Vector2 = _frame.size if _frame != null and _frame.size.y > 0.0 else size
	var aspect: float = (reach.x / reach.y) if reach.y > 0.0 else 1.0
	var frame := Vector2(CAMERA_SIZE * aspect, CAMERA_SIZE)
	(_ground.mesh as QuadMesh).size = frame * 1.02
	_shape_halo()
	_redraw()

func _shape_halo() -> void:
	## The light the stone throws onto its ground, as a quad rather than as 2D circles.
	if headless() or _halo == null or gem.is_empty():
		return
	var color_key: String = Catalog.gem_color(Catalog.canonical_key(str(gem.get("key", ""))))
	var hue := Color(str(Catalog.GEM_COLORS.get(color_key, Catalog.GEM_COLORS.RED).hex))
	var b := GemMesh.brilliance(int(gem.get("clarity", 1)))
	var throw: float = 2.9 * GemMesh.carat_scale(int(gem.get("carat", 1)))
	(_halo.mesh as QuadMesh).size = Vector2(throw, throw)
	var material: StandardMaterial3D = _halo.material_override
	material.albedo_color = Color(hue, (0.10 + 0.20 * b) * Tuning.value("halo"))

func restyle() -> void:
	## Re-reads the tuning table: room first, then the stone, which is re-cut rather than
	## re-skinned because two of the knobs are baked into its facet colours. The gem lab
	## calls this when a slider moves; nothing in the game does.
	_tune()
	_wake()
	_apply_ground()
	_apply()
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func _tune() -> void:
	if _environment == null:
		return
	_environment.tonemap_exposure = Tuning.value("exposure")
	_environment.ambient_light_energy = Tuning.value("ambient")
	_environment.glow_intensity = Tuning.value("glow_intensity")
	_environment.glow_hdr_threshold = Tuning.value("glow_threshold")
	_environment.ssr_enabled = ground.a > 0.001 and Tuning.flag("ssr")
	var shade := Tuning.value("ssao")
	_environment.ssao_enabled = shade > 0.001
	_environment.ssao_intensity = shade
	if _sky_material != null:
		_sky_material.energy_multiplier = Tuning.value("sky_energy")
	var strength := Tuning.value("light_energy")
	for slot in range(_lights.size()):
		var light: DirectionalLight3D = _lights[slot]
		light.light_energy = float(LIGHTS[slot][0]) * strength
	_redraw()

func _apply() -> void:
	if headless() or not is_instance_valid(_body) or gem.is_empty():
		return
	var mesh := GemMesh.build(gem)
	_body.mesh = mesh
	_body.material_override = GemMesh.body_material(gem)
	# The prism rides the same geometry as the near half rather than a mesh of its own.
	_body.material_overlay = GemMesh.fire_material(gem)
	_shell.mesh = mesh
	_shell.material_override = GemMesh.interior_material(gem)
	# Hiding the far half is a tuning switch rather than a state: with it off you see the
	# front of the stone over the background alone, which is the only clean read of its alpha.
	_shell.visible = Tuning.flag("far_pass")
	_shape_halo()
	_etch.mesh = GemMesh.etch_plate(gem)
	_etch.material_override = GemMesh.etch_material(gem)
	# Carat is the one property that changes nothing about the geometry, only its size.
	# Carat is the one property that changes nothing about the geometry, only its size, and
	# `_fit_frame` is what decides that — it has to weigh the slot against the drawing area.
	_fit_frame()
	_redraw()

func enable_interaction() -> void:
	## Hands the stone to the reader. Only the inspect sheet does this: it is the one
	## place a live camera earns its keep.
	interactive = true
	_wants_interaction = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	if not gem.is_empty():
		tooltip_text = GemMesh.describe(gem)
	_wake()

func set_spin(radians_per_second: float) -> void:
	## Turns the stone on its own. A live camera is the cost, so this is for a showcase —
	## the gem lab — and not for the six cards sitting above a battle.
	_spin = radians_per_second
	_wake()

func set_drift(swaying: bool) -> void:
	## Whether this stone breathes at rest. On by default; a caller that needs a still frame
	## more than it needs the motion can turn it off.
	drifting = swaying
	_wake()

func _drifts() -> bool:
	return drifting and Tuning.value("drift_turn") > 0.01 and Tuning.value("drift_rate") > 0.001

func _wake() -> void:
	## A view only needs a live camera if something is going to move. Drift means every gem
	## does, and that is the price of it: a screen of nineteen gems becomes nineteen live
	## viewports rather than nineteen one-off renders. Idle sway at zero puts that back.
	if headless() or _viewport == null:
		return
	var moving: bool = interactive or not is_zero_approx(_spin) or _drifts()
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if moving
		else SubViewport.UPDATE_ONCE)
	set_process(moving)

func _sway() -> Quaternion:
	## The turn a gem has when nothing is happening to it, the way the dice breathe on the
	## table. Two swings at rates that do not divide into each other, so it never comes back
	## round on a beat anyone can count, and neither large enough to fight a pose the reader
	## has dragged the stone into.
	if not _drifts() or _dragging:
		return Quaternion.IDENTITY
	var turn := deg_to_rad(Tuning.value("drift_turn"))
	var rate := Tuning.value("drift_rate")
	var yaw := Quaternion(Vector3.UP, sin(_clock * rate) * turn)
	var nod := Quaternion(Vector3.RIGHT, sin(_clock * rate * 0.71 + 1.3) * turn * 0.45)
	return yaw * nod

func orientation() -> Quaternion:
	return _manual

func rest() -> void:
	## Puts the stone back the way it is first shown.
	_goal = Quaternion.from_euler(Vector3(deg_to_rad(REST.x), deg_to_rad(REST.y), 0.0))
	if is_zero_approx(_spin) and not interactive:
		_manual = _goal
		_apply_turn()

func _redraw() -> void:
	if headless() or _viewport == null:
		return
	if _viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_goal = _manual
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		# Screen-space turn: pre-multiplying rotates about the camera's own axes.
		var yaw := Quaternion(Vector3.UP, event.relative.x * TURN_PER_PIXEL)
		var pitch := Quaternion(Vector3.RIGHT, event.relative.y * TURN_PER_PIXEL)
		_manual = (yaw * pitch * _manual).normalized()
		_goal = _manual
		accept_event()

func _process(delta: float) -> void:
	if headless() or not is_instance_valid(_pivot):
		return
	_clock += delta
	if not _dragging:
		if not is_zero_approx(_spin):
			_manual = (Quaternion(Vector3.UP, _spin * delta) * _manual).normalized()
			_goal = _manual
		elif not _manual.is_equal_approx(_goal):
			_manual = _manual.slerp(_goal, clampf(delta * SETTLE, 0.0, 1.0)).normalized()
	_apply_turn()

func _apply_turn() -> void:
	if is_instance_valid(_pivot):
		_pivot.quaternion = (_sway() * _manual).normalized()
		_redraw()

func _draw_glow(target: Control) -> void:
	## The light a clean stone throws onto what it sits on. A cloudy one throws almost
	## none, which is one more place Clarity shows without a number.
	if gem.is_empty():
		return
	var color_key: String = Catalog.gem_color(Catalog.canonical_key(str(gem.get("key", ""))))
	var hue := Color(str(Catalog.GEM_COLORS.get(color_key, Catalog.GEM_COLORS.RED).hex))
	var b := GemMesh.brilliance(int(gem.get("clarity", 1)))
	var reach: float = minf(size.x, size.y) * 0.5 * GemMesh.carat_span(int(gem.get("carat", 1)))
	# Enough steps that the falloff reads as light rather than as a stack of rings.
	var steps := 10
	var lift := Tuning.value("halo")
	for step in range(steps, 0, -1):
		var t := float(step) / float(steps)
		target.draw_circle(size * 0.5, reach * (0.90 + 0.26 * t),
			Color(hue, (0.014 + 0.026 * b) * (1.0 - t) * lift))
