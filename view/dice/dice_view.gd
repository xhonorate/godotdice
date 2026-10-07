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
## Past this many faces a numeral cut into one of them is too small to read at tray size, so
## the number it landed on is also written over the settled solid.
const READOUT_SIDES := 20

## How a die made of something catches the light. `alpha` under 1 makes it see-through,
## `glow` lights it from inside. A die of nothing in particular uses the first entry.
const PLAIN_LOOK := {"alpha": 1.0, "roughness": 0.42, "metallic": 0.22, "glow": 0.0}
const MATERIAL_LOOKS := {
	"glass": {"alpha": 0.5, "roughness": 0.04, "metallic": 0.0, "glow": 0.05},
	"crystal": {"alpha": 0.82, "roughness": 0.12, "metallic": 0.1, "glow": 0.5},
	"diamond": {"alpha": 0.86, "roughness": 0.03, "metallic": 0.25, "glow": 0.18},
	"opal": {"alpha": 0.9, "roughness": 0.18, "metallic": 0.2, "glow": 0.34},
	"ruby": {"alpha": 0.94, "roughness": 0.1, "metallic": 0.3, "glow": 0.22},
	"sapphire": {"alpha": 0.94, "roughness": 0.1, "metallic": 0.3, "glow": 0.22},
	"emerald": {"alpha": 0.94, "roughness": 0.1, "metallic": 0.3, "glow": 0.22},
	"amethyst": {"alpha": 0.94, "roughness": 0.1, "metallic": 0.3, "glow": 0.22},
	"citrine": {"alpha": 0.96, "roughness": 0.18, "metallic": 0.55, "glow": 0.16},
	"iron": {"alpha": 1.0, "roughness": 0.52, "metallic": 0.95, "glow": 0.0},
	"fools_gold": {"alpha": 1.0, "roughness": 0.24, "metallic": 1.0, "glow": 0.12},
	"granite": {"alpha": 1.0, "roughness": 0.88, "metallic": 0.04, "glow": 0.0},
	"blood": {"alpha": 1.0, "roughness": 0.3, "metallic": 0.12, "glow": 0.2}}

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
var _readout: Label
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
## An exploding face lands on its own number first, then the die is thrown again for each
## extra, and every one lands before it is added. `_chain` is the throws still to come,
## `_chain_face` the face it is showing meanwhile, `_running` what has been added up so far.
var _chain: Array = []
var _chain_face := -1
var _chain_wait := 0.0
var _running := -1

## The total so far, each time the die lands: the first face, then each extra added on.
signal chain_stepped(total: int)

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
	## Above the solid whatever order the viewport container lands in.
	_readout = DeepUi.title(self, "", 22, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.z_index = 1
	_readout.visible = false
	_readout.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	_readout.add_theme_constant_override("outline_size", 8)
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
	var signature := "%s|%s|%s|%s" % [str(die.get("shape", "D6")), str(die.get("material", "")), _face_values(), str(die.get("pattern", ""))]
	if signature != _signature:
		_signature = signature
		_rebuild()
	_face_index = clampi(int(roll.get("face", 0)), 0, maxi(0, _frames.size() - 1))
	if bool(roll.get("flipped", false)):
		var shifted_value: int = int(roll.get("value", 0))
		for index in range(_frames.size()):
			if _value_at(index) == shifted_value and _kind_at(index) == "plain":
				_face_index = index
				break
	var resting: int = _face_index
	var thrown: Array = roll.get("chain", []) if str(roll.get("kind", "plain")) == "exploding" else []
	if not thrown.is_empty():
		resting = clampi(int(thrown[thrown.size() - 1].get("face", resting)), 0, maxi(0, _frames.size() - 1))
	if _running >= 0 and _chain_face >= 0:
		_face_index = _chain_face
	else:
		_face_index = resting
	_target = _orientation(_face_index)
	var token := "%s#%s#%s#%s" % [str(roll.get("die_id", "")), str(roll.get("rerolls", -1)), str(roll.get("face", -1)), str(roll.get("turn_tag", ""))]
	if bool(roll.get("flipped", false)):
		token += "#shift:%d" % int(roll.get("value", 0))
	if str(roll.get("kind", "plain")) == "tally":
		## A Tally face climbs as it is landed on, so the numeral cut into it is recut and the
		## solid turns over onto the new number rather than changing where it lies.
		token += "#" + str(roll.get("value", 0))
		_relabel(_face_index, DiceIcons.face_text(int(roll.get("value", 0)), "tally"))
	if interactive:
		if not _steered:
			_manual = _target
			_goal = _target
			_steered = true
		_roll_token = token
	elif token != _roll_token:
		_roll_token = token
		_chain = []
		_chain_face = -1
		_running = -1
		if not roll.is_empty():
			if not thrown.is_empty() and is_instance_valid(_pivot):
				## It lands on the face it was thrown onto, and the rest follow.
				_chain = thrown.duplicate()
				_chain_face = clampi(int(roll.get("face", 0)), 0, maxi(0, _frames.size() - 1))
				_running = int(roll.get("base", _value_at(_chain_face)))
				_face_index = _chain_face
				_target = _orientation(_face_index)
			_start_spin()
		elif is_instance_valid(_pivot):
			_pivot.quaternion = _target
	elif _spin_time > spin_seconds and is_instance_valid(_pivot):
		_pivot.quaternion = _target
	_sync_readout()
	if is_instance_valid(_glow):
		_glow.queue_redraw()

func _sync_readout() -> void:
	## A d24 and up carries its numerals on faces too small to read, so the number it landed
	## on is written over the solid as well. It is not shown while the solid is still turning,
	## and never on a view the reader steers: there the face under the eye is the answer.
	if not is_instance_valid(_readout):
		return
	var wanted: bool = _frames.size() > READOUT_SIDES and not interactive
	_readout.visible = wanted
	if not wanted:
		return
	var value: int = int(roll.get("value", _value_at(_face_index))) if not roll.is_empty() else _value_at(_face_index)
	if _running >= 0:
		value = _running
	_readout.text = str(value)
	_readout.add_theme_font_size_override("font_size", maxi(14, int(minf(size.x, size.y) * 0.42)))
	_readout.modulate.a = 1.0 if _spin_time > spin_seconds else 0.0

func settle_immediately() -> void:
	## Restored state already knows this face; do not replay a roll on reconnect.
	_spin_time = spin_seconds + 1.0
	_chain = []
	_chain_face = -1
	_running = -1
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
	_sync_readout()

func running_total() -> int:
	## What the die has added up to so far while an exploding face is still being thrown
	## again, or -1 when it is not.
	return _running

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

func _wear_material(palette: Dictionary) -> void:
	## What the die is made of, on the solid itself: glass goes see-through, crystal lights up
	## from inside, iron reads as metal, granite as stone. Colour is already the material.
	var body_material: StandardMaterial3D = _body.material_override as StandardMaterial3D
	if body_material == null:
		return
	var look: Dictionary = MATERIAL_LOOKS.get(str(die.get("material", "")), PLAIN_LOOK)
	var alpha: float = float(look.get("alpha", 1.0))
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	body_material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	body_material.roughness = float(look.get("roughness", 0.42))
	body_material.metallic = float(look.get("metallic", 0.22))
	var glow: float = float(look.get("glow", 0.0))
	body_material.emission_enabled = glow > 0.001
	body_material.emission = palette.body
	body_material.emission_energy_multiplier = glow

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
	return DiceIcons.die_palette(die)

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
	_wear_material(palette)
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
		_fit_label(label, frame)
		label.transform = Transform3D(Basis(frame.right, frame.up, frame.normal), frame.centre + frame.normal * 0.006)
		_pivot.add_child(label)
		_labels.append(label)

func _fit_label(label: Label3D, frame: Dictionary) -> void:
	## Sized to its face for however many characters it shows.
	var digits := maxi(1, label.text.length())
	var span := 0.58 * float(digits) + 0.42
	label.pixel_size = float(frame.inradius) * 1.5 / (96.0 * span)

func _relabel(index: int, text: String) -> void:
	## One face's text changed after the solid was built (a mirror copying a new number).
	if index < 0 or index >= _labels.size() or index >= _frames.size():
		return
	var label: Label3D = _labels[index]
	if not is_instance_valid(label) or label.text == text:
		return
	label.text = text
	_fit_label(label, _frames[index])

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
	if is_instance_valid(_readout) and _readout.visible:
		## Written on only once the solid has stopped: a number over a tumbling die would give
		## the roll away before it landed.
		var want: float = 1.0 if _spin_time > spin_seconds else 0.0
		_readout.modulate.a = move_toward(_readout.modulate.a, want, delta * 7.0)
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
			if _running >= 0:
				chain_stepped.emit(_running)
				_sync_readout()
				_chain_wait = 0.22
	elif _running >= 0:
		_throw_again(delta)
	elif live:
		_pivot.position = Vector3(0, sin(_clock * 1.7) * 0.045, 0)
		_pivot.quaternion = Quaternion(Vector3.UP, sin(_clock * 0.9) * 0.07) * _target
		_pivot.scale = Vector3.ONE
	if is_instance_valid(_glow) and (selected or highlighted):
		_glow.queue_redraw()

func _throw_again(delta: float) -> void:
	## The die has landed with throws still owed: after a beat it is picked up and thrown onto
	## the next face, and what it shows is added to the total once it has stopped.
	_chain_wait -= delta
	if _chain_wait > 0.0:
		return
	if _chain.is_empty():
		_running = -1
		_chain_face = -1
		return
	var next: Dictionary = _chain.pop_front()
	_chain_face = clampi(int(next.get("face", 0)), 0, maxi(0, _frames.size() - 1))
	_running += int(next.get("value", 0))
	if _chain.is_empty():
		## The last landing reports the figure the rules settled on, which a cap may have trimmed.
		_running = int(roll.get("value", _running))
	_face_index = _chain_face
	_target = _orientation(_face_index)
	_start_spin()

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
