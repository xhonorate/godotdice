extends Node3D
## The altar: a drum of old stone with its face tipped toward the party, a pentagram cut into
## the face and burning faintly in its grooves, a socket at each of the five points, and over
## the middle a crystal turning in the air.
##
## In room space, facing the party. It shows what it is told: which gem sits in which socket,
## and whether the circle is dark (not full yet), cold (full, and the five make nothing) or lit.
## What a drop or a click means is the run's business; `make` plays the circle taking the five.

const Lowpoly = preload("res://view/battle/lowpoly.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")

const SOCKETS := 5
## How far the points of the star stand from the middle of the face, and how far the face is
## tipped back from upright so the party looks onto it.
const REACH := 1.12
const TILT := deg_to_rad(68.0)
## The grooves at rest, cold and lit.
const DIM := Color("5b4a7a")
const COLD := Color("4a4d57")
const LIT := Color("ffd98a")

var sockets: Array = []
var crystal: Node3D
var _face: Node3D
var _lines: Array = []
var _line_material: StandardMaterial3D
var _crystal_material: StandardMaterial3D
var _crystal_mesh: MeshInstance3D
var _light: OmniLight3D
var _gems: Array = []
var _hovered: int = -2
var _state: String = "dark"
var _clock: float = 0.0
var _glow: float = 0.0
var _glow_goal: float = 0.0
var _spin: float = 0.4
var _rainbow: bool = false

func build(seed_value: int, rock: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 0.9
	var base := MeshInstance3D.new()
	base.mesh = Lowpoly.column(rng, rock.darkened(0.15), 8, 0.62, 1.15)
	base.material_override = stone
	add_child(base)
	## The face: a slab tipped back, carrying the star, the sockets and the crystal.
	_face = Node3D.new()
	_face.position = Vector3(0, 1.55, 0.3)
	_face.rotation.x = TILT
	add_child(_face)
	var slab := MeshInstance3D.new()
	slab.mesh = Lowpoly.column(rng, rock.lightened(0.12), 10, 1.55, 0.22)
	slab.material_override = stone
	slab.position = Vector3(0, -0.22, 0)
	_face.add_child(slab)
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = DIM
	_line_material.emission_enabled = true
	_line_material.emission = DIM
	_line_material.emission_energy_multiplier = 0.6
	var points: Array = []
	for i in range(SOCKETS):
		var angle: float = -PI * 0.5 + TAU * float(i) / float(SOCKETS)
		points.append(Vector3(cos(angle) * REACH, 0.01, sin(angle) * REACH))
	## The star in one line, point to every second point, and the ring round it.
	for i in range(SOCKETS):
		var from: Vector3 = points[i]
		var to: Vector3 = points[(i + 2) % SOCKETS]
		var groove := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(from.distance_to(to), 0.025, 0.055)
		groove.mesh = bar
		groove.material_override = _line_material
		groove.position = (from + to) * 0.5
		groove.rotation.y = -atan2(to.z - from.z, to.x - from.x)
		_face.add_child(groove)
		_lines.append(groove)
	var ring := MeshInstance3D.new()
	ring.mesh = Lowpoly.ring(REACH + 0.2, 0.06, 64)
	ring.material_override = _line_material
	ring.position = Vector3(0, 0.012, 0)
	_face.add_child(ring)
	var cup := StandardMaterial3D.new()
	cup.albedo_color = rock.darkened(0.55)
	cup.roughness = 0.6
	for i in range(SOCKETS):
		var socket := Node3D.new()
		socket.position = points[i] + Vector3(0, 0.05, 0)
		_face.add_child(socket)
		var bowl := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.24
		shape.bottom_radius = 0.19
		shape.height = 0.09
		shape.radial_segments = 10
		bowl.mesh = shape
		bowl.material_override = cup
		socket.add_child(bowl)
		var rim := MeshInstance3D.new()
		rim.mesh = Lowpoly.ring(0.25, 0.05, 20)
		rim.material_override = _line_material
		rim.position = Vector3(0, 0.05, 0)
		socket.add_child(rim)
		sockets.append(socket)
		_gems.append(null)
	## The crystal, standing off the middle of the face.
	crystal = Node3D.new()
	crystal.position = Vector3(0, 0.78, 0)
	_face.add_child(crystal)
	_crystal_mesh = MeshInstance3D.new()
	_crystal_mesh.mesh = _octahedron(0.3, 0.5)
	_crystal_material = StandardMaterial3D.new()
	_crystal_material.vertex_color_use_as_albedo = true
	_crystal_material.albedo_color = Color("3a3446")
	_crystal_material.roughness = 0.25
	_crystal_material.metallic = 0.2
	_crystal_material.emission_enabled = true
	_crystal_material.emission = DIM
	_crystal_material.emission_energy_multiplier = 0.3
	_crystal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crystal_mesh.material_override = _crystal_material
	crystal.add_child(_crystal_mesh)
	_light = OmniLight3D.new()
	_light.light_color = DIM
	_light.light_energy = 0.4
	_light.omni_range = 4.5
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 1.5
	crystal.add_child(_light)

func _octahedron(width: float, height: float) -> ArrayMesh:
	## Two four-sided pyramids point to point: the crystal over the circle.
	var surface := Lowpoly.begin()
	var top := Vector3(0, height, 0)
	var bottom := Vector3(0, -height, 0)
	var waist: Array = [Vector3(width, 0, 0), Vector3(0, 0, width), Vector3(-width, 0, 0), Vector3(0, 0, -width)]
	for i in range(4):
		var a: Vector3 = waist[i]
		var b: Vector3 = waist[(i + 1) % 4]
		Lowpoly.tri(surface, a, top, b, Color("cfc4e8") if i % 2 == 0 else Color("9a8fb8"), (a + b) * 0.5 + Vector3.UP * 0.3)
		Lowpoly.tri(surface, b, bottom, a, Color("7a6f98") if i % 2 == 0 else Color("5f5680"), (a + b) * 0.5 - Vector3.UP * 0.3)
	return surface.commit()

# --- what it is told ----------------------------------------------------------------------------

func set_gem(index: int, stone: Dictionary) -> void:
	## A gem in a socket, or the socket empty again.
	if index < 0 or index >= SOCKETS:
		return
	var held: Variant = _gems[index]
	if held is Node3D and is_instance_valid(held):
		if not stone.is_empty() and str((held as Node3D).get_meta("stone_id", "")) == str(stone.get("id", "")):
			return
		(held as Node3D).queue_free()
	_gems[index] = null
	if stone.is_empty():
		return
	var shown: Node3D = GemMesh.solid(stone)
	shown.scale = Vector3.ONE * 0.44 / float(shown.get_meta("extent", 1.0))
	shown.position = Vector3(0, 0.16, 0)
	shown.set_meta("stone_id", str(stone.get("id", "")))
	(sockets[index] as Node3D).add_child(shown)
	_gems[index] = shown
	shown.scale *= 0.2
	var pop := shown.create_tween()
	pop.tween_property(shown, "scale", Vector3.ONE * 0.44 / float(shown.get_meta("extent", 1.0)), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_hover(which: int, on: bool) -> void:
	## `which` is a socket, or -1 for the crystal.
	_hovered = which if on else (-2 if _hovered == which else _hovered)

func set_state(state: String, fx: Node3D = null) -> void:
	## dark: the circle is not full. cold: it is full and knows nothing of these five. lit: it
	## does, and the crystal can be pressed.
	if state == _state:
		return
	_state = state
	match state:
		"lit":
			_glow_goal = 1.0
			_spin = 1.4
			if fx != null and is_instance_valid(fx):
				fx.flash(crystal.global_position, LIT, 4.0, 5.0, 0.5, 0.8)
				fx.sparks(crystal.global_position, LIT, 30, 2.5, 0.8, 0.05)
		"cold":
			_glow_goal = 0.0
			_spin = 0.15
			## Sparks that catch and die in it.
			if fx != null and is_instance_valid(fx):
				fx.sparks(crystal.global_position, Color("c9c2b0"), 18, 1.6, 0.45, 0.04)
				fx.puff(crystal.global_position, Color("6a6670"), 8, 0.35, 0.9, 0.3)
		_:
			_glow_goal = 0.0
			_spin = 0.4

func state() -> String:
	return _state

func make(fx: Node3D, transcendent: bool, sink: bool = true) -> float:
	## The circle takes the five: they sink into their sockets, light runs along the star to the
	## middle, and the crystal breaks open in a flash. A Transcendent burns every color, with a
	## column of light over the crystal. Returns how long until the new gem should be shown.
	## `sink` false plays it for someone else's circle: whatever this player set down stays.
	_rainbow = transcendent
	_glow_goal = 1.6
	_spin = 6.0
	var seconds: float = 2.6 if transcendent else 1.5
	var sequence := create_tween()
	for index in range(SOCKETS if sink else 0):
		var held: Variant = _gems[index]
		if held is Node3D and is_instance_valid(held):
			var gem: Node3D = held
			sequence.parallel().tween_property(gem, "scale", Vector3.ONE * 0.01, 0.55).set_delay(0.06 * float(index)).set_ease(Tween.EASE_IN)
			sequence.parallel().tween_property(gem, "position:y", -0.1, 0.55).set_delay(0.06 * float(index))
	sequence.tween_callback(func() -> void:
		for index in range(SOCKETS if sink else 0):
			set_gem(index, {})
		if fx == null or not is_instance_valid(fx):
			return
		for index in range(SOCKETS):
			var tone: Color = Color.from_hsv(float(index) / float(SOCKETS), 0.6, 1.0) if transcendent else LIT
			fx.beam((sockets[index] as Node3D).global_position, crystal.global_position, tone, 0.45, 0.12))
	sequence.tween_interval(0.45)
	sequence.tween_callback(func() -> void:
		if fx == null or not is_instance_valid(fx):
			return
		var at: Vector3 = crystal.global_position
		fx.flash(at, Color.WHITE if transcendent else LIT, 9.0 if transcendent else 6.0, 9.0, 0.7, 1.6)
		fx.ring_wave(global_position + Vector3(0, 0.1, 0.4), LIT, 4.5 if transcendent else 3.0, 0.8)
		fx.sparks(at, LIT, 60 if transcendent else 36, 5.0, 0.9, 0.06)
		if transcendent:
			fx.stars(at, LIT, 2.0, 1.2)
			_pillar(fx, at))
	if transcendent:
		## Wave after wave of every color off the crystal while the column stands.
		for wave in range(5):
			sequence.tween_interval(0.28)
			sequence.tween_callback(func() -> void:
				if fx != null and is_instance_valid(fx):
					var tone := Color.from_hsv(randf(), 0.65, 1.0)
					fx.sparks(crystal.global_position, tone, 40, 4.5, 0.9, 0.06)
					fx.flash(crystal.global_position, tone, 5.0, 8.0, 0.4, 0.8))
	sequence.tween_interval(0.6)
	sequence.tween_callback(func() -> void:
		_rainbow = false
		_glow_goal = 0.0
		_spin = 0.4
		_state = "dark")
	return seconds

func _pillar(fx: Node3D, at: Vector3) -> void:
	## A Transcendent's column of light, rising from the crystal and fading.
	var column := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.5
	shaft.bottom_radius = 0.28
	shaft.height = 9.0
	shaft.radial_segments = 16
	column.mesh = shaft
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(LIT, 0.0)
	column.material_override = m
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(column)
	column.global_position = at + Vector3(0, 4.5, 0)
	var tween := column.create_tween()
	tween.tween_property(m, "albedo_color:a", 0.55, 0.25)
	tween.tween_interval(1.4)
	tween.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tween.tween_callback(column.queue_free)

func collapse(fx: Node3D) -> float:
	## The room is done with: the altar settles back into the floor in its own dust.
	if fx != null and is_instance_valid(fx):
		fx.puff(global_position + Vector3(0, 0.4, 0.6), Color("8a7a66"), 16, 1.6, 1.4, 0.4)
	var sink := create_tween()
	sink.tween_property(self, "position:y", position.y - 2.6, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	sink.tween_callback(queue_free)
	return 0.7

func _process(delta: float) -> void:
	_clock += delta
	if crystal == null:
		return
	crystal.rotation.y += delta * _spin
	crystal.position.y = 0.78 + sin(_clock * 1.6) * 0.05 + (0.06 if _hovered == -1 else 0.0)
	_glow = move_toward(_glow, _glow_goal, delta * 2.0)
	var pulse: float = 0.75 + 0.25 * sin(_clock * 3.0) if _state == "lit" else 1.0
	var tone: Color = DIM.lerp(LIT, clampf(_glow, 0.0, 1.0))
	if _state == "cold":
		tone = COLD
	if _rainbow:
		tone = Color.from_hsv(fposmod(_clock * 0.6, 1.0), 0.55, 1.0)
	_line_material.albedo_color = tone
	_line_material.emission = tone
	_line_material.emission_energy_multiplier = 0.6 + 1.5 * _glow * pulse
	_crystal_material.emission = tone
	_crystal_material.emission_energy_multiplier = (0.3 if _state != "cold" else 0.05) + 1.8 * _glow * pulse + (0.4 if _hovered == -1 else 0.0)
	_light.light_color = tone
	_light.light_energy = (0.4 if _state != "cold" else 0.1) + 1.8 * _glow * pulse
	for index in range(SOCKETS):
		var socket: Node3D = sockets[index]
		var lift: float = 0.08 if _hovered == index else 0.0
		socket.position.y = move_toward(socket.position.y, 0.06 + lift, delta * 0.8)
		var held: Variant = _gems[index]
		if held is Node3D and is_instance_valid(held):
			(held as Node3D).rotation.y += delta * 0.6
