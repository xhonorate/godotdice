extends Control
## A single physical die rendered as real 3D geometry inside its own SubViewport.
##
## Face colors and numerals come from the die's face data, so engraved and
## alternative-distribution dice show their true faces. Rolling spins the solid and
## settles it with the rolled physical face turned toward the camera; the animation is
## presentation only and never chooses the result.

const Geometry = preload("res://view/dice/dice_geometry.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

const VIEW_DIRECTION := Vector3(0.0, 0.0, 1.0)
const SPIN_SECONDS := 0.72
const TURN_PER_PIXEL := 0.011

@export var live := true

## Interactive views are steered by the reader instead of by the roll: dragging
## turns the solid freely and focus_face() swings one face to the front.
var interactive := false
var spin_seconds: float = SPIN_SECONDS
var suspense: bool = false
var suspense_scale: float = 1.0

var die: Dictionary = {}
var roll: Dictionary = {}
var selected := false
var highlighted := false
var accent := Color("e8b661")

var _viewport: SubViewport
var _pivot: Node3D
var _body: MeshInstance3D
var _shell: MeshInstance3D
var _glow: Control
var _labels: Array[Label3D] = []
var _frames: Array = []
var _face_index := 0
var _signature := ""
var _roll_token := ""
var _spin_time := 99.0
var _spin_from := Quaternion.IDENTITY
var _spin_axis := Vector3.UP
var _spin_turns := 2.0
var _target := Quaternion.IDENTITY
var _clock := 0.0
var _manual := Quaternion.IDENTITY
var _goal := Quaternion.IDENTITY
var _dragging := false
var _steered := false

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	## A view handed to the reader before it joined the tree keeps its grip: resetting this
	## unconditionally is what made the inspector's die refuse to turn.
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow.bind(_glow))
	add_child(_glow)
	if headless():
		return
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.disable_3d = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.position = Vector3(0, 0, 5)
	camera.near = 0.05
	camera.far = 20.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4d5f7d")
	environment.ambient_light_energy = 1.15
	camera.environment = environment
	_viewport.add_child(camera)
	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 1.5
	key_light.light_color = Color("fff2d8")
	key_light.rotation_degrees = Vector3(-38, -34, 0)
	_viewport.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.light_energy = 0.55
	fill_light.light_color = Color("7fa8ff")
	fill_light.rotation_degrees = Vector3(24, 148, 0)
	_viewport.add_child(fill_light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_shell = MeshInstance3D.new()
	_shell.scale = Vector3.ONE * 1.055
	var shell_material := StandardMaterial3D.new()
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.cull_mode = BaseMaterial3D.CULL_FRONT
	shell_material.albedo_color = Color("090c14")
	_shell.material_override = shell_material
	_pivot.add_child(_shell)
	_body = MeshInstance3D.new()
	var body_material := StandardMaterial3D.new()
	body_material.vertex_color_use_as_albedo = true
	body_material.roughness = 0.42
	body_material.metallic = 0.22
	body_material.metallic_specular = 0.6
	body_material.rim_enabled = true
	body_material.rim = 0.5
	_body.material_override = body_material
	_pivot.add_child(_body)

func configure(new_die: Dictionary, new_roll: Dictionary, is_selected: bool, is_highlighted: bool, tint: Color) -> void:
	die = new_die
	roll = new_roll
	selected = is_selected
	highlighted = is_highlighted
	accent = tint
	var signature := "%s|%s|%s|%s" % [str(die.get("key", die.get("shape", "D6"))), str(die.get("shape", "D6")), _face_values(), str(die.get("engraving", ""))]
	if signature != _signature:
		_signature = signature
		_rebuild()
	_face_index = clampi(int(roll.get("face", 0)), 0, maxi(0, _frames.size() - 1))
	_target = _orientation(_face_index)
	var token := "%s#%s#%s#%s" % [str(roll.get("die_id", "")), str(roll.get("rerolls", -1)), str(roll.get("face", -1)), str(roll.get("turn_tag", ""))]
	if interactive:
		if not _steered:
			_manual = _target
			_goal = _target
			_steered = true
		_roll_token = token
	elif token != _roll_token:
		_roll_token = token
		if not roll.is_empty():
			_start_spin()
		elif is_instance_valid(_pivot):
			_pivot.quaternion = _target
	elif _spin_time > spin_seconds and is_instance_valid(_pivot):
		_pivot.quaternion = _target
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func settle_immediately() -> void:
	## Restored state already knows this face; do not replay a roll on reconnect.
	_spin_time = spin_seconds + 1.0
	if is_instance_valid(_pivot):
		_pivot.quaternion = _target
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE

func enable_interaction() -> void:
	## Hands the solid to the reader: the roll no longer drives its orientation.
	interactive = true
	live = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_spin_time = 99.0

func face_count() -> int:
	return _frames.size()

func face_value(index: int) -> int:
	return _value_at(index)

func orientation() -> Quaternion:
	## Where the reader has turned the solid. Interactive views only.
	return _manual

func focus_face(index: int) -> void:
	## Swings one physical face to the front. Ignored while the reader is dragging.
	if index < 0 or index >= _frames.size() or _dragging:
		return
	_goal = _orientation(index)

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

func aims_at(index: int) -> bool:
	## True when the settled orientation turns that physical face toward the camera.
	if index < 0 or index >= _frames.size():
		return false
	var facing: Vector3 = _orientation(index) * Vector3(_frames[index].normal)
	return facing.normalized().dot(VIEW_DIRECTION.normalized()) > 0.999

func set_highlight(on: bool) -> void:
	if highlighted == on:
		return
	highlighted = on
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func _face_values() -> String:
	var values: Array = []
	for face in die.get("faces", []):
		values.append(str(face.get("value", face) if face is Dictionary else face))
	return ",".join(values)

func _shape() -> String:
	var declared := str(die.get("shape", "")).to_upper()
	if declared.begins_with("D") and declared.substr(1).is_valid_int():
		return declared
	return Geometry.shape_for_sides(die.get("faces", []).size())

func _palette() -> Dictionary:
	return DiceIcons.palette(str(die.get("key", die.get("shape", "D6"))))

func _rebuild() -> void:
	var shape := _shape()
	var built := Geometry.solid(shape)
	_frames = built.frames
	var palette := _palette()
	var faces: Array = die.get("faces", [])
	var colors := PackedColorArray()
	for index in range(_frames.size()):
		var value := _value_at(index)
		var shade: float = 0.06 * float(index % 3) - 0.05
		var tone: Color = palette.body.lightened(maxf(shade, 0.0)) if shade >= 0.0 else palette.body.darkened(-shade)
		if faces.size() > 0 and value != _nominal(index):
			tone = tone.lerp(Color("ffd166"), 0.35)
		var kind: String = _kind_at(index)
		if kind != "plain":
			tone = tone.lerp(DiceIcons.face_kind_tint(kind), 0.55)
		colors.append(tone)
	# Rims and crystal tips are part of the mesh, but never carry a face value.
	for _i in range(_frames.size(), built.faces.size()):
		colors.append(palette.edge.lightened(0.12))
	if headless():
		return
	var mesh := Geometry.mesh(shape, colors)
	_body.mesh = mesh
	_shell.mesh = mesh
	for label in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	var numeral: Color = Color("15181f") if palette.body.get_luminance() > 0.45 else Color("f4f7fb")
	for index in range(_frames.size()):
		var frame: Dictionary = _frames[index]
		var label := Label3D.new()
		label.text = DiceIcons.face_text(_value_at(index), _kind_at(index))
		label.font_size = 96
		label.outline_size = 0
		label.modulate = numeral
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.double_sided = false
		label.shaded = false
		label.no_depth_test = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var digits := maxi(1, label.text.length())
		var span := 0.58 * float(digits) + 0.42
		label.pixel_size = float(frame.inradius) * 1.5 / (96.0 * span)
		label.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), frame.centre + frame.normal * 0.006)
		_pivot.add_child(label)
		_labels.append(label)

func _kind_at(index: int) -> String:
	var faces: Array = die.get("faces", [])
	if index < faces.size() and faces[index] is Dictionary:
		return str(faces[index].get("kind", "plain"))
	return "plain"

func _value_at(index: int) -> int:
	var faces: Array = die.get("faces", [])
	if index < faces.size():
		var face: Variant = faces[index]
		return int(face.get("value", index + 1)) if face is Dictionary else int(face)
	return index + 1

func _nominal(index: int) -> int:
	return index + 1

func _orientation(index: int) -> Quaternion:
	if index < 0 or index >= _frames.size():
		return Quaternion.IDENTITY
	var frame: Dictionary = _frames[index]
	var aim := VIEW_DIRECTION.normalized()
	var swing := Quaternion(Vector3(frame.normal).normalized(), aim)
	var desired := (Vector3.UP - aim * aim.dot(Vector3.UP)).normalized()
	var current := (swing * Vector3(frame.up)).normalized()
	var angle := atan2(current.cross(desired).dot(aim), current.dot(desired))
	return Quaternion(aim, angle) * swing

func _start_spin() -> void:
	if not is_instance_valid(_pivot) or interactive:
		return
	_spin_time = 0.0
	## Each solid tumbles and lands on its own, a little apart from its neighbours, so five
	## dice sound like five dice and not one.
	DeepAudio.play("die_tumble", {"volume": 0.45, "gap": 0.0, "delay": randf() * 0.05})
	DeepAudio.play("die_settle", {"volume": 0.55, "gap": 0.0, "delay": spin_seconds * randf_range(0.82, 0.98)})
	_spin_from = Quaternion(Vector3(0.4, 1.0, 0.25).normalized(), randf() * TAU)
	_spin_axis = Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.0), randf_range(-1.0, 1.0)).normalized()
	_spin_turns = randf_range(1.6, 2.6)

func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_pivot):
		return
	if interactive:
		if not _dragging:
			_manual = _manual.slerp(_goal, clampf(delta * 9.0, 0.0, 1.0)).normalized()
		_pivot.quaternion = _manual
		_pivot.position = Vector3.ZERO
		_pivot.scale = Vector3.ONE
		return
	if _spin_time <= spin_seconds:
		_spin_time += delta
		var t := clampf(_spin_time / spin_seconds, 0.0, 1.0)
		var eased := smoothstep(0.55, 1.0, t) if suspense else 1.0 - pow(1.0 - t, 3.0)
		var settled := _spin_from.slerp(_target, eased)
		_pivot.quaternion = Quaternion(_spin_axis, _spin_turns * TAU * (1.0 - eased) + (TAU * 3.0 * t * (1.0 - eased) if suspense else 0.0)) * settled
		_pivot.position = Vector3(0, sin(PI * t) * 0.34, 0)
		var squash := 1.0 + 0.16 * sin(PI * clampf((t - 0.82) / 0.18, 0.0, 1.0))
		_pivot.scale = Vector3(squash, 2.0 - squash, squash) * (1.0 + 0.16 * suspense_scale * sin(PI * t * 0.9) if suspense else 1.0)
		if t >= 1.0:
			_pivot.position = Vector3.ZERO
			_pivot.scale = Vector3.ONE
			_pivot.quaternion = _target
	elif live:
		_pivot.position = Vector3(0, sin(_clock * 1.7) * 0.045, 0)
		_pivot.quaternion = Quaternion(Vector3.UP, sin(_clock * 0.9) * 0.07) * _target
		_pivot.scale = Vector3.ONE
	if is_instance_valid(_glow) and (selected or highlighted):
		_glow.queue_redraw()

func _draw_glow(target: Control) -> void:
	var centre := target.size * 0.5
	var radius := minf(target.size.x, target.size.y) * 0.46
	if headless():
		# Fallback presentation when no renderer is available.
		var silhouette := PackedVector2Array()
		var sides := clampi(die.get("faces", []).size(), 3, 12)
		for i in sides:
			silhouette.append(centre + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(sides)) * radius)
		target.draw_colored_polygon(silhouette, _palette().body)
	if highlighted:
		target.draw_circle(centre, radius * 1.16, Color(accent, 0.16))
	if selected:
		var pulse := 0.55 + 0.25 * sin(_clock * 4.2)
		target.draw_arc(centre, radius * 1.06, 0.0, TAU, 48, Color(accent, pulse), 2.5, true)
		for i in 4:
			var angle := _clock * 1.1 + TAU * float(i) / 4.0
			target.draw_circle(centre + Vector2.from_angle(angle) * radius * 1.06, 2.6, Color(accent, pulse))
