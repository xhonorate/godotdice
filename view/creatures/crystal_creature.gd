class_name CrystalCreature
extends Node3D
## A creature of the rock, built from low-poly crystal primitives in the stones' own light.
## Every creature is one of a few silhouettes with a tint hashed from its key, so the same
## creature always looks the same and no two kinds look alike.

const STYLES: Dictionary = {"CAVE_TICK": "low", "SILT_SLIME": "blob", "QUARTZ_GOLEM": "stack", "MAGPIE": "spikes",
	"LANTERN_MOTH": "wings", "VEIN_WRAITH": "shards", "CLOUDER": "puff", "GLASS_WYRM": "long",
	"THE_FOREMAN": "tower", "THE_REGENT": "tower", "THE_DRILL": "tower"}
const TINTS: Array = ["b9a8ff", "9fd8c8", "ffb07a", "9ab8ff", "ffd66b", "d98cff", "8fe0a0", "ff8c9c", "cfd8e6", "ffe9a8"]

var key: String = ""
var body_material: StandardMaterial3D
var core_material: StandardMaterial3D
var anchor: Vector3 = Vector3(0, 1.6, 0)
var rest_position: Vector3 = Vector3.ZERO
var _parts: Array = []
var _clock: float = 0.0
var _sway: float = 1.0

static func make(creature_key: String, warden: bool = false) -> CrystalCreature:
	var creature := CrystalCreature.new()
	creature.key = creature_key
	creature.build(warden)
	return creature

func build(warden: bool) -> void:
	var seed_value: int = key.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tint := Color(str(TINTS[absi(seed_value) % TINTS.size()]))
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(tint, 0.82)
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_material.roughness = 0.22
	body_material.metallic = 0.15
	body_material.emission_enabled = true
	body_material.emission = tint
	body_material.emission_energy_multiplier = 0.25
	body_material.rim_enabled = true
	body_material.rim = 0.6
	core_material = StandardMaterial3D.new()
	core_material.albedo_color = tint.darkened(0.7)
	core_material.roughness = 0.9
	core_material.emission_enabled = true
	core_material.emission = tint
	core_material.emission_energy_multiplier = 0.9
	var style: String = str(STYLES.get(key, "cluster"))
	var scale_all: float = 1.5 if warden else 1.0
	match style:
		"low":
			_core(Vector3(0, 0.25, 0), 0.45, Vector3(1.4, 0.5, 1.0))
			for i in range(6):
				_crystal(Vector3(rng.randf_range(-0.5, 0.5), 0.35, rng.randf_range(-0.3, 0.3)), rng.randf_range(0.3, 0.6), 0.09, Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40)))
			anchor = Vector3(0, 1.1, 0)
		"blob":
			_core(Vector3(0, 0.45, 0), 0.6, Vector3(1.3, 0.8, 1.2))
			_core(Vector3(0.3, 0.75, 0.1), 0.35, Vector3(1.0, 0.8, 1.0))
			_sway = 2.2
			anchor = Vector3(0, 1.4, 0)
		"stack":
			for i in range(4):
				_block(Vector3(rng.randf_range(-0.12, 0.12), 0.35 + float(i) * 0.62, 0), Vector3(1.1 - float(i) * 0.15, 0.55, 0.9 - float(i) * 0.1), rng.randf_range(-12, 12))
			_crystal(Vector3(0, 2.75, 0), 0.5, 0.14, Vector3(0, 0, 0))
			anchor = Vector3(0, 3.4, 0)
			_sway = 0.5
		"spikes":
			_core(Vector3(0, 0.9, 0), 0.32, Vector3.ONE)
			for i in range(7):
				_crystal(Vector3(rng.randf_range(-0.3, 0.3), 0.9, rng.randf_range(-0.3, 0.3)), rng.randf_range(0.9, 1.5), 0.06, Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60)))
			anchor = Vector3(0, 2.4, 0)
			_sway = 3.0
		"wings":
			_core(Vector3(0, 1.2, 0), 0.22, Vector3(0.7, 1.6, 0.7))
			_wing(Vector3(-0.75, 1.3, 0), -1.0)
			_wing(Vector3(0.75, 1.3, 0), 1.0)
			anchor = Vector3(0, 2.1, 0)
			_sway = 4.0
		"shards":
			for i in range(8):
				_crystal(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.4), rng.randf_range(-0.4, 0.4)), rng.randf_range(0.5, 1.1), 0.08, Vector3(rng.randf_range(-70, 70), rng.randf_range(0, 360), rng.randf_range(-70, 70)))
			anchor = Vector3(0, 2.2, 0)
			_sway = 1.6
		"puff":
			for i in range(5):
				_core(Vector3(rng.randf_range(-0.4, 0.4), 0.8 + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), rng.randf_range(0.35, 0.55), Vector3.ONE)
			anchor = Vector3(0, 1.9, 0)
			_sway = 1.2
		"long":
			for i in range(6):
				var t: float = float(i) / 5.0
				_core(Vector3(lerpf(-1.4, 1.4, t), 0.5 + sin(t * PI) * 0.6, 0), 0.4 - t * 0.12, Vector3.ONE)
			_crystal(Vector3(-1.4, 1.2, 0), 0.6, 0.12, Vector3(0, 0, 30))
			anchor = Vector3(0, 2.0, 0)
			_sway = 0.8
		"tower":
			_block(Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.4), 0)
			_block(Vector3(0, 1.7, 0), Vector3(1.3, 1.0, 1.0), 8)
			for i in range(5):
				_crystal(Vector3(rng.randf_range(-0.6, 0.6), 2.3, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.8, 1.6), 0.16, Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
			anchor = Vector3(0, 4.2, 0)
			_sway = 0.4
		_:
			_core(Vector3(0, 0.5, 0), 0.5, Vector3.ONE)
			for i in range(6):
				_crystal(Vector3(rng.randf_range(-0.4, 0.4), 0.6, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.6, 1.2), 0.12, Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45)))
			anchor = Vector3(0, 2.0, 0)
	scale = Vector3.ONE * scale_all
	anchor *= scale_all

func _crystal(at: Vector3, height: float, radius: float, tilt: Vector3) -> void:
	var prism := CylinderMesh.new()
	prism.radial_segments = 6
	prism.rings = 1
	prism.top_radius = radius * 0.35
	prism.bottom_radius = radius
	prism.height = height
	var tip := CylinderMesh.new()
	tip.radial_segments = 6
	tip.rings = 1
	tip.top_radius = 0.0
	tip.bottom_radius = radius * 0.35
	tip.height = radius * 1.6
	var holder := Node3D.new()
	holder.position = at
	holder.rotation_degrees = tilt
	add_child(holder)
	var body := MeshInstance3D.new()
	body.mesh = prism
	body.material_override = body_material
	body.position = Vector3(0, height * 0.5, 0)
	holder.add_child(body)
	var point := MeshInstance3D.new()
	point.mesh = tip
	point.material_override = body_material
	point.position = Vector3(0, height + radius * 0.8, 0)
	holder.add_child(point)
	_parts.append(holder)

func _core(at: Vector3, radius: float, stretch: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.radius = radius
	sphere.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.material_override = core_material
	node.position = at
	node.scale = stretch
	add_child(node)
	_parts.append(node)

func _block(at: Vector3, size: Vector3, yaw: float) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = body_material
	node.position = at
	node.rotation_degrees = Vector3(0, yaw, 0)
	add_child(node)
	_parts.append(node)

func _wing(at: Vector3, side: float) -> void:
	var quad := PrismMesh.new()
	quad.size = Vector3(1.1, 0.9, 0.05)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = body_material
	node.position = at
	node.rotation_degrees = Vector3(0, 0, 20.0 * side)
	add_child(node)
	_parts.append(node)

func flash(strength: float = 2.4) -> void:
	## A hit: the whole creature blazes and settles.
	var tween := create_tween()
	tween.tween_property(body_material, "emission_energy_multiplier", strength, 0.06)
	tween.tween_property(body_material, "emission_energy_multiplier", 0.25, 0.35)

func lunge(toward: Vector3, seconds: float = 0.5) -> void:
	## The creature's move: a step toward the party and back to its mark.
	var tween := create_tween()
	tween.tween_property(self, "position", rest_position.lerp(toward, 0.35), seconds * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rest_position, seconds * 0.6).set_ease(Tween.EASE_IN_OUT)

func die() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(scale.x * 1.2, 0.05, scale.z * 1.2), 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(body_material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
	_clock += delta
	## Breathing: the whole creature rises and falls a little, faster for the light ones.
	position.y = rest_position.y + sin(_clock * _sway) * 0.05
