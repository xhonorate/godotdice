extends Control
## One creature on a plinth of its own, lit from three sides and turning slowly, for the
## inspector. Its own small world, so it costs one viewport while it is open and nothing
## once it closes. Drag to turn it.
##
## With `fit` set before it enters the tree, the camera is drawn back to the creature's own
## shape rather than its height, so a long wyrm turning on the spot never leaves the frame,
## and the plinth is cut to its size (the bestiary, and the portraits baked for its list).

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _creature: Node3D
var _turn: float = 0.4
var _spin: float = 0.35
var _dragging: bool = false
var _clock: float = 0.0
var _key: String = ""
var _warden: bool = false

var _echo_of: String = ""
var _plinth: MeshInstance3D
## Frame the creature by its bounds, turning, instead of by its height.
var fit: bool = false
## Whether it stands on its plinth.
var plinth_shown: bool = true
## What `fit` frames: the creature's bounds as it rests, kept so a resize can frame it again.
var _box: AABB = AABB()

func _init(creature_key: String = "", warden: bool = false, echo_of: String = "") -> void:
	_echo_of = echo_of
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Drag to turn it."
	if DisplayServer.get_name() == "headless":
		return
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	frame.add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4258")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	_camera = Camera3D.new()
	_camera.environment = env
	_camera.fov = 34.0
	_viewport.add_child(_camera)
	for spec in [[Color("fff0d8"), 1.3, Vector3(-40, -30, 0)], [Color("7fa8ff"), 0.7, Vector3(-10, 150, 0)], [Color("ffb080"), 0.5, Vector3(20, 70, 0)]]:
		var light := DirectionalLight3D.new()
		light.light_color = spec[0]
		light.light_energy = spec[1]
		light.rotation_degrees = spec[2]
		_viewport.add_child(light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var plinth := MeshInstance3D.new()
	_plinth = plinth
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.7
	disc.height = 0.18
	disc.radial_segments = 10
	disc.rings = 1
	plinth.mesh = disc
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("2a2f3a")
	stone.roughness = 0.8
	plinth.material_override = stone
	plinth.position = Vector3(0, -0.09, 0)
	_pivot.add_child(plinth)
	_key = creature_key
	_warden = warden

func _ready() -> void:
	if not _key.is_empty():
		show_creature(_key, _warden)

func show_creature(creature_key: String, warden: bool) -> void:
	if _pivot == null:
		return
	if _creature != null and is_instance_valid(_creature):
		_creature.queue_free()
	var made: CrystalCreature = CrystalCreature.make(creature_key, warden, _echo_of)
	_pivot.add_child(made)
	_creature = made
	_plinth.visible = plinth_shown
	if fit:
		## Measured as it rests, before it rises out of the rock.
		_box = _bounds(made)
		_frame_bounds(_box)
		made.spawn(0.1)
		return
	made.spawn(0.1)
	## Frame it by its own height, so a tick and a Warden both fill the stage.
	var height: float = maxf(1.2, made.anchor.y)
	var distance: float = height * 2.3 + 2.0
	_camera.look_at_from_position(Vector3(0, height * 0.55, distance), Vector3(0, height * 0.42, 0), Vector3.UP)

func _bounds(made: Node3D) -> AABB:
	## The creature's body as it rests, in the turntable's own space.
	var body: Node = made.get_node_or_null("Body")
	var to_pivot: Transform3D = _pivot.global_transform.affine_inverse()
	var box := AABB()
	var first: bool = true
	for node in (body if body != null else made).find_children("*", "GeometryInstance3D", true, false):
		var shape := node as GeometryInstance3D
		if not shape.is_visible_in_tree():
			continue
		var placed: AABB = to_pivot * shape.global_transform * shape.get_aabb()
		box = placed if first else box.merge(placed)
		first = false
	return box if not first else AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, maxf(1.2, made.anchor.y), 1.2))

func _frame_bounds(box: AABB) -> void:
	## Back just far enough that the creature fits whichever way it has turned: every corner
	## of its bounds, swung round the turntable's axis, lies inside the picture. The plinth is
	## cut to the circle its widest part sweeps.
	var reach: float = 0.3
	for index in range(8):
		var corner: Vector3 = box.get_endpoint(index)
		reach = maxf(reach, Vector2(corner.x, corner.z).length())
	var radius: float = clampf(reach * 1.12, 0.45, 4.0)
	_plinth.scale = Vector3(radius / 1.6, 1.0, radius / 1.6)
	var points: Array = []
	for index in range(8):
		points.append(box.get_endpoint(index))
	if plinth_shown:
		for step in range(12):
			var angle: float = TAU * float(step) / 12.0
			points.append(Vector3(cos(angle) * radius * 1.06, -0.18, sin(angle) * radius * 1.06))
	var low: float = INF
	var high: float = -INF
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var centre := Vector3(0, (low + high) * 0.5, 0)
	## A little above it and looking down, as the inspector's camera does.
	var tilt: float = deg_to_rad(14.0)
	var back := Vector3(0, sin(tilt), cos(tilt))
	var up := Vector3(0, cos(tilt), -sin(tilt))
	var aspect: float = size.x / size.y if size.x > 0.0 and size.y > 0.0 else 1.0
	var half_v: float = tan(deg_to_rad(_camera.fov) * 0.5) * 0.94
	var half_h: float = half_v * aspect
	var distance: float = 0.5
	for turn in range(16):
		var spun := Basis(Vector3.UP, TAU * float(turn) / 16.0)
		for point in points:
			var at: Vector3 = spun * point - centre
			var across: float = maxf(absf(at.x) / half_h, absf(at.dot(up)) / half_v)
			distance = maxf(distance, at.dot(back) + across)
	_camera.look_at_from_position(centre + back * distance, centre, Vector3.UP)

func _notification(what: int) -> void:
	## A stage laid out after it was filled has its camera drawn back for its real shape.
	if what == NOTIFICATION_RESIZED and fit and _creature != null and _camera != null:
		_frame_bounds(_box)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_turn += event.relative.x * 0.012
		accept_event()

func _process(delta: float) -> void:
	_clock += delta
	if _pivot == null:
		return
	if not _dragging:
		_turn += _spin * delta
	_pivot.rotation.y = _turn
