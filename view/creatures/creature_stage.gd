extends Control
## One creature on a plinth of its own, lit from three sides and turning slowly, for the
## inspector. Its own small world, so it costs one viewport while it is open and nothing
## once it closes. Drag to turn it.

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

func _init(creature_key: String = "", warden: bool = false) -> void:
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
	var made: CrystalCreature = CrystalCreature.make(creature_key, warden)
	_pivot.add_child(made)
	made.spawn(0.1)
	_creature = made
	## Frame it by its own height, so a tick and a Warden both fill the stage.
	var height: float = maxf(1.2, made.anchor.y)
	var distance: float = height * 2.3 + 2.0
	_camera.look_at_from_position(Vector3(0, height * 0.55, distance), Vector3(0, height * 0.42, 0), Vector3.UP)

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
