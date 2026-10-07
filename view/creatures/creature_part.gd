class_name CrystalCreaturePart
extends Node3D
## An editable pivot for one piece of a creature. Child meshes keep their own transforms.
##
## `motion` is how the piece idles: still, a crystal that sways, a core that pulses, a block
## that turns a little, a wing that beats, or one of the newer kinds: a part that orbits the
## body, one that spins on its axis (or bores, at a drill's pace), one that bobs, one that swings like a pendulum, a tread
## that rolls and a flame that flickers. `phase` offsets its clock so no two parts move
## together; `wing_side` mirrors a wing.

@export_enum("static", "crystal", "core", "block", "wing", "orbit", "spin", "drill", "bob", "swing", "tread", "flicker") var motion: String = "static"
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
		"orbit":
			## Circles the body at its own height, keeping its distance from the axis.
			position = _rest.origin.rotated(Vector3.UP, clock * 0.7 + phase) + Vector3(0, sin(clock * 1.9 + phase) * 0.06, 0)
			rotation = base_rotation + Vector3(0, clock * 0.7 + phase, 0)
		"spin":
			## About the part's own long axis, however it is tilted: a wheel on its axle, a
			## crystal on its point. Adding yaw to the resting angles swung a tilted part round
			## the body instead.
			transform.basis = _rest.basis * Basis(Vector3.UP, clock * 2.4 + phase)
		"drill":
			## The same, at a drill's pace.
			transform.basis = _rest.basis * Basis(Vector3.UP, clock * 11.0 + phase)
		"bob":
			position = _rest.origin + Vector3(0, sin(clock * 2.2 + phase) * 0.1, 0)
		"swing":
			rotation = base_rotation + Vector3(0, 0, sin(clock * 1.6 + phase) * 0.22)
		"tread":
			rotation = base_rotation + Vector3(clock * 1.8 + phase, 0, 0)
		"flicker":
			var lick: float = 1.0 + 0.18 * sin(clock * 9.0 + phase) * sin(clock * 5.3 + phase * 1.7)
			scale = _rest.basis.get_scale() * Vector3(1.0, lick, 1.0)
			rotation = base_rotation + Vector3(sin(clock * 7.0 + phase) * 0.08, 0, cos(clock * 6.0 + phase) * 0.08)
