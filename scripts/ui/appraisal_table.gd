extends Control
## The appraisal table: everything the party brought up, laid out on wood in 3D.
##
## Each player has a strip of felt in their own colour with their stones scattered on it.
## Only this machine's player can pick theirs up: clicking a stone lifts it off the felt to
## hang in front of the camera, turning slowly, while the screen beside the table reads it
## out. A kept stone is swept into the player's corner; a sold one sinks out of sight.
##
## The table only presents. Keeping and selling are profile transactions the screen makes;
## it tells the table what was decided so the stone can go where it went.

signal gem_selected(gem_id: String)

const StoneNode = preload("res://scripts/ui/stone_node.gd")

const TABLE_SIZE := Vector3(9.6, 0.3, 5.6)
const STONE_SIZE := 0.26
const LIFT_DISTANCE := 4.0
const HOVER_RADIUS := 46.0
const EASE := 6.0

var reduced_motion := false
## The reveal clock and the moment into a reading when the stone gives its name. The held
## stone flares at that moment, in step with the sheet beside the table.
var clock: Callable
var beat := 1.2
var _selected_since := 0.0
var _flare: OmniLight3D
var _areas: Array = []
var _decisions: Dictionary = {}
var _slots: Dictionary = {}
var _selected := ""
var _hover := ""
var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _signature := ""
var _clock := 0.0

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if headless():
		return
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.use_debanding = true
	frame.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_build_room()
	_rebuild_stones()

func configure(areas: Array, decisions: Dictionary) -> void:
	## `areas`: [{player_id, name, color: Color, local: bool, gems: [gem entries]}].
	## `decisions`: gem id → "kept" or "sold", for the stones already settled.
	_areas = areas
	_decisions = decisions.duplicate()
	var signature := JSON.stringify(areas.map(func(area: Dictionary) -> Array: return [area.player_id, area.gems.map(func(gem: Dictionary) -> String: return str(gem.id))]))
	if signature != _signature:
		_signature = signature
		_rebuild_stones()
	if not _selected.is_empty() and _decisions.has(_selected):
		_selected = ""

func selected() -> String:
	return _selected

func select(gem_id: String, since: float = 0.0) -> void:
	_selected = gem_id if _slots.has(gem_id) and not _decisions.has(gem_id) else ""
	_selected_since = since

func stone_ids() -> Array:
	return _slots.keys()

func _build_room() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a0806")
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("e9d6b0")
	sky_material.sky_horizon_color = Color("8a6a44")
	sky_material.ground_horizon_color = Color("3a2a1a")
	sky_material.ground_bottom_color = Color("120c08")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("3a2c20")
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 3.0
	environment.glow_enabled = true
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.04
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	_camera = Camera3D.new()
	_camera.fov = 44.0
	_camera.position = Vector3(0.0, 6.1, 5.2)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.0, 0.25), Vector3.UP)
	# A lamp over the reader's shoulder, so a stone held up to the camera is lit from the front.
	_flare = OmniLight3D.new()
	_flare.light_color = Color("fff1c2")
	_flare.omni_range = 3.0
	_flare.light_energy = 0.0
	_world.add_child(_flare)
	var loupe_light := OmniLight3D.new()
	loupe_light.position = Vector3(1.2, 0.9, -0.6)
	loupe_light.light_color = Color("fff4de")
	loupe_light.light_energy = 2.4
	loupe_light.omni_range = 5.5
	_camera.add_child(loupe_light)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 3.6, 0.8)
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 3.2
	lamp.omni_range = 11.0
	lamp.shadow_enabled = true
	_world.add_child(lamp)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("9fb8ff")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-50, 35, 0)
	_world.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("fff1dc")
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-30, -150, 0)
	_world.add_child(rim)
	var table := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = TABLE_SIZE
	table.mesh = slab
	table.position = Vector3(0, -TABLE_SIZE.y * 0.5, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _wood_texture()
	wood.uv1_scale = Vector3(2.0, 1.0, 1.0)
	wood.roughness = 0.62
	table.material_override = wood
	_world.add_child(table)

func _wood_texture() -> NoiseTexture2D:
	## Long grain: a stretched noise through a ramp of browns. Generated, so there is no
	## texture file to ship; a painted one can replace this without touching the scene.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color("3b2414"))
	ramp.set_color(1, Color("7a4f2c"))
	ramp.add_point(0.45, Color("5a3a20"))
	ramp.add_point(0.7, Color("6d4526"))
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture

func _rebuild_stones() -> void:
	if headless() or _world == null:
		_slots.clear()
		for area in _areas:
			for gem in area.gems:
				_slots[str(gem.id)] = {"local": bool(area.get("local", false))}
		return
	for slot in _slots.values():
		if is_instance_valid(slot.get("node")):
			slot.node.queue_free()
		if is_instance_valid(slot.get("felt")):
			slot.felt.queue_free()
	_slots.clear()
	for child in _world.get_children():
		if child.has_meta("felt"):
			child.queue_free()
	var count: int = maxi(1, _areas.size())
	var strip: float = (TABLE_SIZE.x - 0.4) / float(count)
	for index in range(_areas.size()):
		var area: Dictionary = _areas[index]
		var left: float = -TABLE_SIZE.x * 0.5 + 0.2 + strip * index
		var felt := MeshInstance3D.new()
		felt.set_meta("felt", true)
		var cloth := PlaneMesh.new()
		cloth.size = Vector2(strip - 0.2, TABLE_SIZE.z - 0.5)
		felt.mesh = cloth
		felt.position = Vector3(left + strip * 0.5, 0.004, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(area.get("color", Color("2d5687"))).darkened(0.62)
		material.roughness = 1.0
		felt.material_override = material
		_world.add_child(felt)
		var gems: Array = area.get("gems", [])
		var columns: int = maxi(1, ceili(sqrt(float(gems.size()) * strip / (TABLE_SIZE.z - 0.5))))
		var rows: int = maxi(1, ceili(float(gems.size()) / float(columns)))
		for gem_index in range(gems.size()):
			var gem: Dictionary = gems[gem_index]
			var column: int = gem_index % columns
			var row: int = gem_index / columns
			var rng := RandomNumberGenerator.new()
			rng.seed = str(gem.id).hash()
			var cell := Vector2((strip - 0.5) / float(columns), (TABLE_SIZE.z - 1.0) / float(rows))
			var home := Vector3(left + 0.25 + cell.x * (column + 0.5) + rng.randf_range(-0.12, 0.12) * cell.x,
				0.0, -TABLE_SIZE.z * 0.5 + 0.5 + cell.y * (row + 0.5) + rng.randf_range(-0.12, 0.12) * cell.y)
			var holder := Node3D.new()
			holder.position = home
			var shown: Dictionary = gem.duplicate()
			shown["appraised"] = true
			var stone := StoneNode.build(shown)
			# Lying on the felt, crown up, turned whichever way it fell.
			stone.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			holder.add_child(stone)
			holder.rotation.y = rng.randf_range(-PI, PI)
			holder.scale = Vector3.ONE * STONE_SIZE
			_world.add_child(holder)
			_slots[str(gem.id)] = {"node": holder, "stone": stone, "home": home, "yaw": holder.rotation.y,
				"local": bool(area.get("local", false)), "corner": Vector3(left + strip - 0.35, 0.0, TABLE_SIZE.z * 0.5 - 0.45),
				"size": STONE_SIZE, "fade": 1.0}

func _process(delta: float) -> void:
	if headless() or _camera == null:
		return
	_clock += delta
	var ease: float = 1.0 if reduced_motion else clampf(delta * EASE, 0.0, 1.0)
	var focus: Vector3 = _camera.global_position - _camera.global_basis.z * LIFT_DISTANCE - _camera.global_basis.x * 0.35 + _camera.global_basis.y * 0.25
	# The flare as the stone is named: a swell of light and size that falls away again.
	var reading: float = (float(clock.call()) - _selected_since) if clock.is_valid() and not _selected.is_empty() else 99.0
	var flare := 0.0 if reduced_motion else clampf(1.0 - absf(reading - beat) / 0.35, 0.0, 1.0)
	if is_instance_valid(_flare):
		_flare.light_energy = 9.0 * flare
		_flare.global_position = focus + _camera.global_basis.z * 0.9
	for id in _slots:
		var slot: Dictionary = _slots[id]
		var holder: Node3D = slot.node
		var target: Vector3 = slot.home
		var scale_goal: float = STONE_SIZE
		var decision: String = str(_decisions.get(id, ""))
		if id == _selected:
			target = focus
			scale_goal = STONE_SIZE * 1.7 * (1.0 + 0.28 * flare)
		elif decision == "kept":
			target = slot.corner + Vector3(0, 0.02, 0)
			scale_goal = STONE_SIZE * 0.55
		elif decision == "sold":
			target = slot.home - Vector3(0, 0.6, 0)
			scale_goal = 0.0
		elif id == _hover and slot.local:
			target = slot.home + Vector3(0, 0.12, 0)
		holder.position = holder.position.lerp(target, ease)
		holder.scale = holder.scale.lerp(Vector3.ONE * scale_goal, ease)
		holder.visible = holder.scale.x > 0.01
		var stone: Node3D = slot.stone
		if id == _selected:
			# Held up to the light: crown toward the camera, turning slowly.
			# Looking away from the camera leaves the holder's +Z, and so the crown, toward it.
			var facing := Basis.looking_at(holder.global_position - _camera.global_position, Vector3.UP)
			holder.basis = facing.scaled(holder.scale)
			stone.rotation = Vector3(0.18 * sin(_clock * 0.9), _clock * (0.0 if reduced_motion else 0.7), 0.0)
		else:
			holder.basis = Basis(Vector3.UP, slot.yaw).scaled(holder.scale)
			stone.rotation = stone.rotation.lerp(Vector3(-PI * 0.5, 0.0, 0.0), ease)

func _stone_at(point: Vector2) -> String:
	if _camera == null:
		return ""
	var best := ""
	var nearest := HOVER_RADIUS
	var scale_factor := Vector2(_viewport.size) / size if size.x > 0 and size.y > 0 else Vector2.ONE
	for id in _slots:
		var slot: Dictionary = _slots[id]
		if not slot.local or _decisions.has(id):
			continue
		var screen: Vector2 = _camera.unproject_position(slot.node.global_position) / scale_factor
		var distance := screen.distance_to(point)
		if distance < nearest:
			nearest = distance
			best = id
	return best

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := _stone_at(event.position)
		if id != _hover:
			_hover = id
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not id.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _stone_at(event.position)
		if not id.is_empty():
			_selected = id
			accept_event()
			gem_selected.emit(id)
