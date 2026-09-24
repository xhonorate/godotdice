class_name CrystalCreaturePart
extends Node3D
## An editable pivot for one piece of a creature. Child meshes keep their own transforms.

@export_enum("static", "crystal", "core", "block", "wing") var motion: String = "static"
@export var phase: float = 0.0
@export var wing_side: float = 1.0

var _rest: Transform3D

func capture_pose() -> void:
	_rest = transform

func animate(clock: float, style: String) -> void:
	var base_rotation := _rest.basis.orthonormalized().get_euler()
	match motion:
		"wing":
			var beat: float = sin(clock * 11.0 + phase) * 0.55
			rotation = base_rotation + Vector3(0, 0, beat * wing_side)
		"crystal":
			rotation = base_rotation + Vector3(sin(clock * 1.3 + phase) * 0.05, 0, cos(clock * 1.1 + phase) * 0.05)
			if style == "shards":
				var orbit: float = clock * 0.6 + phase
				position = _rest.origin.rotated(Vector3.UP, sin(orbit) * 0.4) + Vector3(0, sin(clock * 1.7 + phase) * 0.08, 0)
		"core":
			var pulse: float = 1.0 + 0.06 * sin(clock * (2.4 if style != "puff" else 1.3) + phase)
			scale = _rest.basis.get_scale() * pulse
			if style == "long":
				position = _rest.origin + Vector3(0, sin(clock * 2.0 - _rest.origin.x * 1.4) * 0.12, 0)
		"block":
			rotation = base_rotation + Vector3(0, sin(clock * 0.7 + phase) * 0.06, 0)
