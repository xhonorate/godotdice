extends RefCounted
## Recipes for tools/creature_bake.gd: the Glass Veins. See tools/creature_bake.gd for the format.
##
## The Echo Sprite, the Refractor, the Glazier and the Kaleidoscope are the owner's picks from the
## model review (build/options/recipes/glass_veins.gd), the Prismarch is round 3's
## (build/options/recipes/r3c.gd). Each names its review key as "seed", so it bakes facet for facet
## as it was picked. The Prism is today's model, unchanged.
##
## Low poly and angular, made of crystals and gems: eyes and motes are pentagonal gems, hearts and
## lenses six-sided gems, hoops bands of boxes, tails rows of cut stones. The parts an animation
## moves are named (the pivot becomes <Name>01, <Name>02, ...) and hung from their hinge by
## "joint"; build/options/part_roles/glass_veins.md says which way each one moves. z+ faces the
## party, y is up, and a creature's own left (`_l`) is +x.

static func recipes() -> Dictionary:
	return {
		"ECHO_SPRITE": _echo_sprite(),
		"REFRACTOR": _refractor(),
		"THE_GLAZIER": _glazier(),
		"THE_KALEIDOSCOPE": _kaleidoscope(),
		"THE_PRISMARCH": _prismarch(),
		"PRISM": _prism()}

## ---- helpers ------------------------------------------------------------------------------

static func _v(p: Vector3) -> Array:
	## A point as the recipe writes it.
	return [p.x, p.y, p.z]

static func _m(part: Dictionary, extra: Dictionary) -> Dictionary:
	## The part with `extra` laid over it (a name, a joint, a motion).
	part.merge(extra, true)
	return part

static func _aimed(direction: Vector3) -> Basis:
	## The bake's own rule: upright turned the shortest way round until Y runs along `direction`.
	var up: Vector3 = direction.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return Basis() if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

static func _rot(basis: Basis) -> Array:
	## A basis as the recipe's "rot", in degrees.
	var e: Vector3 = basis.orthonormalized().get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _dot(at: Array, size: float, material: String = "accent", motion: String = "static", phase: float = 0.0) -> Dictionary:
	## A small cut gem: an eye, a glint, a mote. A pentagonal bipyramid, never a ball.
	return {"shape": "sphere", "at": at, "scale": size, "material": material, "motion": motion, "phase": phase, "radius": 1.0, "segments": 5, "rings": 2}

static func _ball(at: Array, size: float, material: String = "core", motion: String = "core", phase: float = 0.0) -> Dictionary:
	## A bigger faceted gem for a heart, a lamp or a lens: six sides, three rings.
	return {"shape": "sphere", "at": at, "scale": size, "material": material, "motion": motion, "phase": phase, "radius": 1.0, "segments": 6, "rings": 3}

static func _eye(at: Vector3, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## The Prismarch's pentagonal gem: an eye, a jewel. Still unless `extra` says otherwise.
	return _m({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}, extra)

static func _gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## The biggest cut gem allowed (six by three): a heart, an orb. Pulses.
	var s: Variant = _v(size) if size is Vector3 else float(size)
	return _m({"shape": "sphere", "at": _v(at), "scale": s, "material": material, "motion": "core", "radius": 1.0, "segments": 6, "rings": 3}, extra)

static func _rock(at: Vector3, size: Vector3, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## A cut stone of its own seed.
	return _m({"shape": "rock", "at": _v(at), "scale": _v(size), "material": material, "jitter": jitter, "seed": seed}, extra)

static func _stone(from: Vector3, to: Vector3, r: float, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## One cut stone laid from `from` to `to`: an upper arm.
	return _m({"shape": "rock", "at": _v((from + to) * 0.5), "rot": _rot(_aimed(to - from)), "scale": [r, from.distance_to(to) * 0.6 + r * 0.2, r * 0.92], "material": material, "jitter": jitter, "seed": seed}, extra)

static func _stick(shape: String, a: Vector3, b: Vector3, r: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A shape stood between two points: a hex drum tapering a little, a five-sided cone, a
	## six-sided crystal or column, a spike.
	var part: Dictionary = {"shape": shape, "from": _v(a), "to": _v(b), "material": material}
	match shape:
		"cylinder":
			part.merge({"bottom": r, "top": r * 0.8, "sides": 6})
		"cone":
			part.merge({"radius": r, "sides": 5})
		"spike":
			part.merge({"radius": r, "sides": 5, "lean": 0.0})
		_:
			part.merge({"radius": r, "sides": 6})
	return _m(part, extra)

static func _rim(centre: Vector3, normal: Vector3, radius: float, thick: float, depth: float, material: String, motion: String = "static", phase: float = 0.0, n: int = 6, roll: float = 0.0) -> Array:
	## A lowpoly hoop in place of a torus: `n` boxes laid end to end round `normal` (a lens rim, a
	## halo, an iris). `radius` runs to the middle of the boxes, `thick` is their radial depth,
	## `depth` their size along the normal, `roll` turns the hoop so its corners land where they
	## are wanted. The same hoop as `_band`, written as the review batch glass_veins.gd wrote it
	## (its angles rounded its own way), so the Refractor and the Kaleidoscope bake as picked.
	var axis: Vector3 = normal.normalized()
	var u: Vector3 = Vector3.UP.cross(axis)
	if u.length() < 0.001:
		u = Vector3.RIGHT
	u = u.normalized()
	var w: Vector3 = axis.cross(u).normalized()
	var length: float = 2.0 * (radius + thick * 0.5) * tan(PI / float(n))
	var out: Array = []
	for i in range(n):
		var ang: float = TAU * float(i) / float(n) + roll
		var radial: Vector3 = (u * cos(ang) + w * sin(ang)).normalized()
		var tangent: Vector3 = axis.cross(radial).normalized()
		var euler: Vector3 = Basis(radial, tangent, axis).get_euler() * (180.0 / PI)
		out.append({"shape": "box", "at": _v(centre + radial * radius), "rot": _v(euler), "material": material, "motion": motion, "phase": phase, "size": [thick, length, depth]})
	return out

static func _band(centre: Vector3, normal: Vector3, radius: float, thick: float, depth: float, material: String, n: int = 8, roll: float = 0.0, extra: Dictionary = {}) -> Array:
	## The Prismarch's hoop of `n` boxes round `normal` (a crown's band, a collar, a rim), as
	## round 3's batch r3c.gd wrote it, with `extra` (a name, a joint) on every box.
	var axis: Vector3 = normal.normalized()
	var u: Vector3 = Vector3.UP.cross(axis)
	if u.length() < 0.001:
		u = Vector3.RIGHT
	u = u.normalized()
	var w: Vector3 = axis.cross(u).normalized()
	var length: float = 2.0 * (radius + thick * 0.5) * tan(PI / float(n))
	var out: Array = []
	for i in range(n):
		var ang: float = TAU * float(i) / float(n) + roll
		var radial: Vector3 = (u * cos(ang) + w * sin(ang)).normalized()
		var tangent: Vector3 = axis.cross(radial).normalized()
		out.append(_m({"shape": "box", "at": _v(centre + radial * radius), "rot": _rot(Basis(radial, tangent, axis)), "material": material, "size": [thick, length, depth]}, extra.duplicate()))
	return out

static func _crown(out: Array, centre: Vector3, r: float, points: String, extra: Dictionary = {}, band: String = "accent", jewels: String = "core") -> void:
	## An eight-pointed crown: an eight-sided band, a crystal point at every corner (tall and short
	## by turns, `points` and body by turns, or all accent when `points` is "all"), and a lit jewel
	## on every face between them.
	var k: float = r / 1.035
	for piece in _band(centre, Vector3.UP, r, 0.23 * k, 0.22 * k, band, 8, PI / 8.0):
		out.append(_m(piece, extra.duplicate()))
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		var mat: String = "accent" if points == "all" else (points if i % 2 == 0 else "body")
		var base := centre + Vector3(cos(ang) * r * 0.97, 0.05 * k, sin(ang) * r * 0.97)
		var tip := centre + Vector3(cos(ang) * r * 1.12, (1.2 if i % 2 == 0 else 0.9) * k, sin(ang) * r * 1.12)
		out.append(_m(_stick("crystal", base, tip, 0.13 * k, mat), extra.duplicate()))
		var between: float = ang + PI / 8.0
		out.append(_m(_eye(centre + Vector3(cos(between) * r * 1.13, 0.0, sin(between) * r * 1.13), 0.1 * k, jewels), extra.duplicate()))

static func _sceptre(out: Array, foot: Vector3, top: Vector3, extra: Dictionary = {}) -> void:
	## A sceptre of light: a gold hex rod, a cut orb at its head held in four gold claws with a
	## crystal spike above it, a gold collar under the orb. The orb is the second piece.
	var up: Vector3 = (top - foot).normalized()
	var pieces: Array = [
		_stick("cylinder", foot, top, 0.05, "accent"),
		_gem(top + up * 0.16, 0.16, "core", {"phase": 0.4}),
		_stick("crystal", top + up * 0.28, top + up * 0.62, 0.05, "accent")]
	pieces.append_array(_band(top, up, 0.11, 0.06, 0.06, "accent", 6))
	for i in range(4):
		var ang: float = TAU * float(i) / 4.0 + 0.4
		var out_dir := Vector3(cos(ang), 0, sin(ang))
		pieces.append(_stick("crystal", top + out_dir * 0.08, top + out_dir * 0.2 + up * 0.32, 0.03, "accent"))
	for piece in pieces:
		out.append(_m(piece, extra.duplicate()))

static func _saw(at: Vector3, axis: Vector3, radius: float) -> Array:
	## A diamond saw: a hex iron disc turning on its axle with a lit hex rim on each face and a
	## lit hub, and ten pyramid teeth round its edge that turn with it (each tooth is a stick
	## along the axle, its mesh pushed out to the rim, and its phase is where on the rim it sits,
	## so the drill turn carries it round).
	var dir: Vector3 = axis.normalized()
	var out: Array = [
		{"shape": "cylinder", "from": _v(at - dir * 0.03), "to": _v(at + dir * 0.03), "material": "iron", "motion": "drill", "phase": 0.0, "top": radius * 0.8, "bottom": radius * 0.8, "sides": 6},
		{"shape": "ring", "at": _v(at + dir * 0.035), "aim": _v(dir), "material": "accent", "motion": "drill", "phase": 0.0, "radius": radius * 0.66, "width": radius * 0.1, "segments": 6},
		{"shape": "ring", "at": _v(at - dir * 0.035), "aim": _v(-dir), "material": "accent", "motion": "drill", "phase": 0.0, "radius": radius * 0.66, "width": radius * 0.1, "segments": 6},
		{"shape": "cylinder", "from": _v(at - dir * 0.045), "to": _v(at + dir * 0.045), "material": "accent", "motion": "drill", "phase": 0.0, "top": radius * 0.18, "bottom": radius * 0.18, "sides": 6}]
	for i in range(10):
		out.append({"shape": "cone", "from": _v(at - dir * 0.02), "to": _v(at + dir * 0.02), "material": "iron", "motion": "drill", "phase": TAU * float(i) / 10.0, "height": radius * 0.4, "radius": radius * 0.1, "sides": 4, "offset": [radius * 0.9, 0, 0], "mesh_rot": [0, 0, -90]})
	return out

## ---- the creatures ----------------------------------------------------------------------

## The Echo Sprite: a glass fairy. A cut-gem head with eyes and antennae over a teardrop body with
## a lit heart, four long prism wings beating from the shoulders, a tail of light trailing.
static func _echo_sprite() -> Dictionary:
	var neck: Array = [0, 1.09, 0]
	var parts: Array = [
		{"shape": "crystal", "from": [0, 1.0, 0], "to": [0, 0.4, 0], "material": "body", "motion": "core", "radius": 0.12, "name": "body"},
		{"shape": "column", "from": [0, 0.97, 0], "to": [0, 1.09, 0], "material": "body", "sides": 6, "radius": 0.16, "name": "body"},
		{"shape": "rock", "at": [0, 1.21, 0.03], "scale": 0.13, "material": "body", "motion": "bob", "phase": 0.4, "jitter": 0.06, "seed": 11, "name": "head", "joint": neck},
		_m(_dot([0, 0.9, 0.09], 0.065, "accent", "core", 1.0), {"name": "heart"}),
		{"shape": "crystal", "from": [0.03, 1.08, -0.08], "to": [0.12, 1.3, -0.22], "material": "body", "motion": "crystal", "radius": 0.03},
		{"shape": "crystal", "from": [-0.04, 1.06, -0.09], "to": [-0.1, 1.24, -0.24], "material": "body", "motion": "crystal", "radius": 0.025},
		_dot([0.45, 1.35, 0.2], 0.03, "accent", "orbit", 2.0)]
	for side in [-1.0, 1.0]:
		var wing: String = "wing_l" if side > 0.0 else "wing_r"
		parts.append(_m(_dot([side * 0.055, 1.22, 0.13], 0.03, "accent", "bob", 0.4), {"name": "head", "joint": neck}))
		## The antennae bob with the head they stand on.
		parts.append({"shape": "crystal", "from": [side * 0.05, 1.3, 0.0], "to": [side * 0.2, 1.52, -0.1], "material": "accent", "motion": "bob", "phase": 0.4, "radius": 0.015, "name": "head", "joint": neck})
		## Two wings a side, each hinged at the shoulder: a long upper blade raised, a shorter lower one dropped.
		parts.append({"shape": "prism", "at": [side * 0.1, 1.0, -0.03], "rot": [0, 0, side * 28.0], "material": "body", "motion": "wing", "side": side, "phase": 0.0, "mesh_rot": [0, 0, -side * 90.0], "offset": [side * 0.5, 0, 0], "size": [0.42, 1.0, 0.03], "name": wing, "joint": [side * 0.1, 1.0, -0.03]})
		parts.append({"shape": "prism", "at": [side * 0.1, 0.92, 0.0], "rot": [0, 0, -side * 22.0], "material": "body", "motion": "wing", "side": side, "phase": 0.9, "mesh_rot": [0, 0, -side * 90.0], "offset": [side * 0.36, 0, 0], "size": [0.3, 0.72, 0.03], "name": wing, "joint": [side * 0.1, 0.92, 0.0]})
	## The tail: three motes of light trailing under the tip, each on its own beat.
	for i in range(3):
		parts.append(_m(_dot([0.03 * float(i), 0.33 - 0.11 * float(i), -0.05 - 0.09 * float(i)], 0.045 - 0.01 * float(i), "accent", "bob", 0.9 * float(i)), {"name": "tail", "joint": [0, 0.4, 0]}))
	return {"style": "wings", "sway": 3.6, "tint": "d8c8ff", "accent": "ffffff", "anchor": 1.7, "shadow": 1.4, "ring": 0.8, "seed": "ECHO_SPRITE_A", "parts": parts}

## The Refractor: a lens-eye. A great double-pointed crystal with a lens under a hex rim, four rays
## of split light, a hexagonal halo of glass turning round its waist with gems at its corners, a
## collar of small crystals, shards circling.
static func _refractor() -> Dictionary:
	var waist: Array = [0, 0.95, 0]
	var body: Dictionary = {"name": "body", "joint": waist}
	var lens: Dictionary = {"name": "eye", "joint": [0, 1.0, 0.31]}
	var parts: Array = [
		_m({"shape": "crystal", "from": [0, 0.95, 0], "to": [0, 1.8, 0], "material": "body", "motion": "bob", "phase": 0.0, "radius": 0.3}, body),
		_m({"shape": "crystal", "from": [0, 0.95, 0], "to": [0, 0.28, 0], "material": "body", "motion": "bob", "phase": 0.0, "radius": 0.3}, body),
		## The lens and the gem on the tip bob with the body they are set in.
		_m(_ball([0, 1.0, 0.31], 0.11, "core", "bob", 0.0), lens),
		_m(_dot([0, 1.84, 0], 0.06, "accent", "bob", 0.0), body)]
	for piece in _rim(Vector3(0, 1.0, 0.3), Vector3(0, 0, 1), 0.16, 0.06, 0.06, "accent", "bob", 0.0):
		parts.append(_m(piece, lens))
	## The halo and the gems at its corners turn as one ring round the waist.
	for piece in _rim(Vector3(0, 0.95, 0), Vector3.UP, 0.68, 0.12, 0.06, "body", "orbit", 0.0):
		parts.append(_m(piece, {"name": "ring", "joint": waist}))
	for i in range(6):
		var corner: float = TAU * float(i) / 6.0 + PI / 6.0
		parts.append(_m(_dot([cos(corner) * 0.77, 0.95, sin(corner) * 0.77], 0.05, "accent", "orbit", 0.0), {"name": "ring", "joint": waist}))
	## Four rays of split light fanned out of the lens.
	for i in range(4):
		var ang: float = PI / 4.0 + TAU * float(i) / 4.0
		var ray := Vector3(cos(ang), sin(ang), 0.25).normalized()
		parts.append({"shape": "cone", "from": _v(Vector3(0, 1.0, 0.36) + ray * 0.15), "to": _v(Vector3(0, 1.0, 0.36) + ray * 0.7), "material": "accent", "motion": "bob", "phase": 0.0, "radius": 0.035, "sides": 4, "name": "ray", "joint": [0, 1.0, 0.36]})
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0
		var out := Vector3(cos(ang), 0, sin(ang))
		parts.append(_m({"shape": "crystal", "from": _v(out * 0.24 + Vector3(0, 0.72, 0)), "to": _v(out * 0.5 + Vector3(0, 0.62, 0)), "material": "body", "motion": "bob", "phase": 0.0, "radius": 0.05}, body))
	for i in range(5):
		var ang: float = float(i) * TAU / 5.0
		parts.append({"shape": "shard", "at": [cos(ang) * 0.95, 0.95 + sin(ang * 2.0) * 0.3, sin(ang) * 0.95], "rot": [20, rad_to_deg(ang), 30], "scale": 1.6, "material": "accent", "motion": "orbit", "phase": ang, "size": 0.14})
	## Where Split Light leaves the lens.
	parts.append({"shape": "sphere", "at": [0, 1.0, 0.43], "scale": 0.02, "material": "accent", "motion": "bob", "phase": 0.0, "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth", "joint": [0, 1.0, 0.31]})
	return {"style": "shards", "sway": 1.4, "tint": "e08ad8", "accent": "8affd8", "anchor": 2.05, "shadow": 2.2, "ring": 1.1, "seed": "REFRACTOR_A", "parts": parts}

## The Glazier: a glass scorpion. A low three-plate body on eight short legs, two great pincers held
## out in front, a tail of five cut stones arched over its back that carries the diamond saw,
## its blade in the tail's plane.
static func _glazier() -> Dictionary:
	var parts: Array = [
		{"shape": "rock", "at": [0, 0.75, 0.35], "scale": [0.62, 0.36, 0.55], "material": "body", "motion": "core", "jitter": 0.1, "seed": 64, "name": "body"},
		{"shape": "rock", "at": [0, 0.7, -0.35], "scale": [0.55, 0.3, 0.45], "material": "body", "motion": "core", "phase": 0.5, "jitter": 0.1, "seed": 65, "name": "body"},
		{"shape": "rock", "at": [0, 0.65, -0.95], "scale": [0.45, 0.26, 0.4], "material": "body", "motion": "core", "phase": 1.0, "jitter": 0.1, "seed": 66, "name": "body"},
		_m(_dot([0.16, 0.95, 0.82], 0.07), {"name": "eye"}), _m(_dot([-0.16, 0.95, 0.82], 0.07), {"name": "eye"}),
		_m(_dot([0.3, 0.9, 0.7], 0.04), {"name": "eye"}), _m(_dot([-0.3, 0.9, 0.7], 0.04), {"name": "eye"})]
	## The saw spins on its own axle (no joint: the drill turn is about each piece's own axis). Its
	## blade stands in the tail's plane, parallel to the body, as the owner asked (the picked
	## model had it facing the party).
	for piece in _saw(Vector3(0, 2.85, 0.45), Vector3(1, 0, 0), 0.56):
		parts.append(_m(piece, {"name": "saw"}))
	## The tail, root to tip: each stone hinged at its root end, so it can curl stone by stone.
	var tail: Array = [Vector3(0, 0.7, -1.3), Vector3(0, 1.15, -1.75), Vector3(0, 1.85, -1.85), Vector3(0, 2.5, -1.5), Vector3(0, 2.85, -0.8), Vector3(0, 2.9, -0.05)]
	for i in range(5):
		var tip_end: Vector3 = tail[i + 1]
		var root_end: Vector3 = tail[i]
		var r: float = 0.17 - 0.015 * float(i)
		parts.append({"shape": "rock", "at": _v((tip_end + root_end) * 0.5), "aim": _v(tip_end - root_end), "scale": [r, tip_end.distance_to(root_end) * 0.62, r], "material": "body", "jitter": 0.08, "seed": 50 + i, "name": "tail", "joint": _v(root_end)})
	for side in [-1.0, 1.0]:
		var claw: String = "claw_l" if side > 0.0 else "claw_r"
		var finger: String = "finger_l" if side > 0.0 else "finger_r"
		var shoulder: Array = [side * 0.5, 0.72, 0.6]
		var wrist: Array = [side * 0.95, 0.76, 1.1]
		var ph: float = 0.0 if side > 0.0 else 1.5
		## A pincer swings from its shoulder as one piece, the gems on its tips too; the outer
		## finger is named apart so it can snap shut on the inner one.
		for piece in [
			{"shape": "cylinder", "from": shoulder, "to": wrist, "material": "body", "top": 0.09, "bottom": 0.11, "sides": 6, "name": claw},
			{"shape": "crystal", "from": wrist, "to": [side * 0.78, 0.8, 1.78], "material": "body", "radius": 0.11, "name": claw},
			{"shape": "crystal", "from": wrist, "to": [side * 1.22, 0.8, 1.72], "material": "body", "radius": 0.1, "name": finger},
			_m(_dot([side * 0.78, 0.8, 1.78], 0.04), {"name": claw}), _m(_dot([side * 1.22, 0.8, 1.72], 0.04), {"name": finger})]:
			parts.append(_m(piece, {"joint": shoulder, "motion": "swing", "phase": ph}))
		## Four legs a side, each hinged at its hip.
		for leg in range(4):
			var z: float = 0.45 - 0.3 * float(leg)
			var hip: Array = [side * 0.5, 0.6, z]
			var knee: Array = [side * 1.05, 1.05, z * 1.2]
			parts.append({"shape": "cylinder", "from": hip, "to": knee, "material": "body", "top": 0.05, "bottom": 0.07, "sides": 5, "name": "leg", "joint": hip})
			parts.append({"shape": "crystal", "from": knee, "to": [side * 1.45, 0.0, z * 1.6], "material": "body", "radius": 0.055, "sides": 5, "name": "leg", "joint": hip})
	return {"style": "low", "sway": 0.9, "tint": "c8b8ff", "accent": "ffffff", "anchor": 3.5, "warden": true, "shadow": 3.4, "ring": 1.7, "seed": "THE_GLAZIER_B", "parts": parts}

## The Kaleidoscope: a cut-gem eyeball with a faceted cornea and a lit iris band of eight facets
## round the pupil, a brow of crystals, three crystal tendrils under it, six prisms as petals
## turning round it with gems between.
static func _kaleidoscope() -> Dictionary:
	var eye := Vector3(0, 1.7, 0)
	var look: Dictionary = {"name": "eye", "joint": _v(eye)}
	var parts: Array = [
		_m({"shape": "rock", "at": _v(eye), "scale": 0.62, "material": "body", "motion": "block", "phase": 0.0, "jitter": 0.04, "seed": 90}, look),
		_m({"shape": "dome", "at": _v(eye + Vector3(0, 0, 0.4)), "material": "body", "motion": "block", "phase": 0.0, "radius": 0.46}, look),
		## The eye glances about (a turn, not a bob: a bob lifted it off its tendrils); the pupil,
		## cornea and iris turn with it.
		_m(_ball(_v(eye + Vector3(0, 0, 0.52)), 0.15, "core", "block", 0.0), look)]
	for piece in _rim(eye + Vector3(0, 0, 0.4), Vector3(0, 0, 1), 0.46, 0.08, 0.08, "accent", "block", 0.0, 8):
		parts.append(_m(piece, look))
	## The iris: eight lit facets round the pupil.
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		parts.append(_m({"shape": "prism", "at": _v(eye + Vector3(cos(ang) * 0.28, sin(ang) * 0.28, 0.47)), "rot": [0, 0, rad_to_deg(ang) - 90.0], "material": "core", "motion": "block", "phase": 0.0, "size": [0.1, 0.17, 0.04]}, look))
	## The brow: five crystals fanned over the eye.
	for k in range(5):
		var lean: float = deg_to_rad(-50.0 + 25.0 * float(k))
		var ray := Vector3(sin(lean), cos(lean), 0.35).normalized()
		var base: Vector3 = eye + ray * 0.56
		parts.append({"shape": "crystal", "from": _v(base), "to": _v(base + ray * (0.35 + 0.15 * cos(lean))), "material": "accent", "motion": "block", "phase": 0.0, "radius": 0.05, "name": "crest", "joint": _v(eye)})
	## Three tendrils, each swinging from its root.
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0 + PI / 2.0
		var root: Array = _v(eye + Vector3(cos(ang) * 0.22, -0.54, sin(ang) * 0.22))
		var mid: Array = _v(eye + Vector3(cos(ang) * 0.32, -0.9, sin(ang) * 0.32))
		var tip: Array = _v(eye + Vector3(cos(ang) * 0.4, -1.25, sin(ang) * 0.4))
		parts.append({"shape": "column", "from": root, "to": mid, "material": "body", "motion": "swing", "phase": float(i) * 1.3, "joint": root, "radius": 0.05, "sides": 4, "name": "tendril"})
		parts.append({"shape": "crystal", "from": mid, "to": tip, "material": "body", "motion": "swing", "phase": float(i) * 1.3, "joint": root, "radius": 0.045, "sides": 4, "name": "tendril"})
		parts.append(_m(_dot(tip, 0.06, "accent", "swing", float(i) * 1.3), {"joint": root, "name": "tendril"}))
	## The six petals and the gems between them turn round the eye as one wheel.
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0
		parts.append({"shape": "prism", "at": [cos(ang) * 1.3, 1.7 + sin(ang) * 1.3, 0.0], "rot": [0, 0, rad_to_deg(ang) - 90.0], "material": "body", "motion": "orbit", "phase": 0.0, "size": [0.7, 0.9, 0.06], "name": "petal", "joint": _v(eye)})
		var between: float = ang + PI / 6.0
		parts.append(_m(_dot([cos(between) * 1.2, 1.7 + sin(between) * 1.2, 0.05], 0.09, "accent", "orbit", 0.0), {"name": "petal", "joint": _v(eye)}))
	## Where Glare and Blind leave the pupil.
	parts.append({"shape": "sphere", "at": _v(eye + Vector3(0, 0, 0.68)), "scale": 0.02, "material": "accent", "motion": "block", "phase": 0.0, "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth", "joint": _v(eye)})
	return {"style": "shards", "sway": 0.9, "tint": "9b8cff", "accent": "ff8ae0", "anchor": 3.7, "warden": true, "shadow": 3.4, "ring": 1.6, "seed": "THE_KALEIDOSCOPE_A", "parts": parts}

## The Prismarch: a crowned crystal colossus. A lit heart in a gold rim, crystal shoulder pieces, a
## standing collar and a long mantle of prisms, a sceptre of light and an orb, a skirt of crystals
## pointing into the floor.
static func _prismarch() -> Dictionary:
	var neck: Array = [0, 2.75, 0.05]
	var head: Dictionary = {"name": "head", "joint": neck}
	var parts: Array = [
		## The waist turns a little on its axis (the first pivot must idle); the trunk stands still.
		{"shape": "column", "from": [0, 0.8, 0], "to": [0, 1.85, 0], "material": "body", "motion": "block", "sides": 6, "radius": 0.46, "name": "body"},
		_rock(Vector3(0, 2.2, 0), Vector3(0.78, 0.6, 0.5), "body", 0.06, 601, {"name": "body"}),
		_gem(Vector3(0, 2.22, 0.45), 0.17, "core", {"name": "heart"}),
		_rock(Vector3(0, 3.0, 0.05), Vector3(0.27, 0.32, 0.27), "body", 0.05, 602, head),
		_eye(Vector3(0.1, 3.03, 0.28), 0.05, "accent", head), _eye(Vector3(-0.1, 3.03, 0.28), 0.05, "accent", head),
		## The lit mouth slit rides the head, still (a pulse would swing it about the neck).
		{"shape": "box", "at": [0, 2.88, 0.27], "material": "core", "motion": "static", "size": [0.14, 0.03, 0.04], "name": "head", "joint": neck}]
	parts.append_array(_band(Vector3(0, 2.22, 0.43), Vector3(0, 0, 1), 0.21, 0.06, 0.06, "accent", 8, PI / 8.0))
	parts.append_array(_band(Vector3(0, 1.8, 0), Vector3.UP, 0.52, 0.1, 0.12, "accent", 8, PI / 8.0))
	## The crown rides the head's neck joint, which stands on the crown's own upright axis.
	_crown(parts, Vector3(0, 3.24, 0.05), 0.36, "accent", {"name": "crown", "joint": neck})
	## The skirt of crystals pointing into the floor.
	for i in range(12):
		var ang: float = TAU * float(i) / 12.0 + 0.13
		var top := Vector3(cos(ang) * 0.44, 1.8, sin(ang) * 0.4)
		var bottom := Vector3(cos(ang) * (1.0 + 0.14 * float(i % 2)), 0.02 + 0.1 * float(i % 3), sin(ang) * (0.92 + 0.14 * float(i % 2)))
		parts.append(_stick("crystal", top, bottom, 0.2 if i % 2 == 0 else 0.16, "body"))
	## The standing collar behind the head.
	for i in range(5):
		var x: float = (float(i) - 2.0) * 0.2
		parts.append(_stick("crystal", Vector3(x * 1.2, 2.55, -0.24), Vector3(x * 2.0, 3.45 - absf(x) * 0.4, -0.42), 0.08, "body" if i != 2 else "accent", {"motion": "crystal"}))
	## The mantle falling from the shoulders to the floor.
	for i in range(9):
		var x: float = (float(i) - 4.0) * 0.2
		parts.append(_stick("crystal", Vector3(x, 2.5, -0.3), Vector3(x * 1.55, 0.05 + 0.08 * float(i % 2), -1.0 - 0.1 * float(i % 2)), 0.15, "body"))
	## The shoulder pieces.
	for side in [-1.0, 1.0]:
		var sh := Vector3(side * 0.82, 2.5, 0.0)
		parts.append(_rock(sh, Vector3(0.32, 0.26, 0.32), "body", 0.06, 603))
		for k in range(3):
			var d := Vector3(side * (0.5 + 0.3 * float(k)), 1.0 - 0.25 * float(k), -0.2 + 0.2 * float(k)).normalized()
			parts.append(_stick("crystal", sh + d * 0.15, sh + d * (0.55 - 0.08 * float(k)), 0.07, "accent" if k == 1 else "body", {"motion": "crystal"}))
	## The sceptre arm (its own left, +x): arm and sceptre swing as one from the shoulder.
	var shoulder_l := Vector3(0.88, 2.42, 0.05)
	var arm_l: Dictionary = {"name": "arm_l", "joint": _v(shoulder_l)}
	var el := Vector3(1.15, 1.85, 0.28)
	var hand := Vector3(1.1, 1.45, 0.6)
	parts.append(_stone(shoulder_l, el, 0.17, "body", 0.06, 604, arm_l))
	parts.append(_stick("column", el, hand, 0.12, "body", arm_l))
	parts.append(_rock(hand, Vector3(0.14, 0.15, 0.14), "body", 0.08, 605, arm_l))
	var sceptre: Array = []
	_sceptre(sceptre, Vector3(1.1, 0.02, 0.62), Vector3(1.1, 3.2, 0.62), {"name": "sceptre", "joint": _v(shoulder_l)})
	## Its orb holds still: a pulse would swing it about the shoulder.
	sceptre[1]["motion"] = "static"
	parts.append_array(sceptre)
	## The orb arm (its own right, -x): arm and orb swing as one from the shoulder.
	var shoulder_r := Vector3(-0.88, 2.42, 0.05)
	var arm_r: Dictionary = {"name": "arm_r", "joint": _v(shoulder_r)}
	var orb: Dictionary = {"name": "orb", "joint": _v(shoulder_r)}
	var el2 := Vector3(-1.12, 1.95, 0.38)
	var hand2 := Vector3(-0.82, 1.84, 0.82)
	parts.append(_stone(shoulder_r, el2, 0.17, "body", 0.06, 606, arm_r))
	parts.append(_stick("column", el2, hand2, 0.12, "body", arm_r))
	parts.append(_rock(hand2, Vector3(0.15, 0.1, 0.15), "body", 0.08, 607, arm_r))
	parts.append(_gem(hand2 + Vector3(0, 0.25, 0.02), 0.19, "accent", {"name": "orb", "joint": _v(shoulder_r), "motion": "static"}))
	parts.append(_stick("crystal", hand2 + Vector3(0, 0.4, 0.02), hand2 + Vector3(0, 0.66, 0.02), 0.04, "accent", orb))
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0
		parts.append({"shape": "crystal", "at": [cos(ang) * 1.75, 0.9 + 0.55 * float(i), sin(ang) * 1.75], "rot": [15, 0, 15], "material": "body", "motion": "orbit", "phase": ang, "radius": 0.1, "height": 0.5})
	## Where Lancet's light leaves: the tip of the sceptre's spike.
	parts.append({"shape": "sphere", "at": [1.1, 3.82, 0.62], "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth", "joint": _v(shoulder_l)})
	return {"style": "tower", "sway": 0.5, "tint": "7a6ad8", "accent": "ffe08a", "anchor": 3.9, "warden": true, "shadow": 3.8, "ring": 1.8, "seed": "THE_PRISMARCH_A", "parts": parts}

## The Prism: today's model, kept as it was. A double-pointed crystal turning on its point under a
## glint.
static func _prism() -> Dictionary:
	var prism: Array = [
		{"shape": "crystal", "at": [0, 0.45, 0], "material": "body", "motion": "spin", "radius": 0.16, "height": 0.7},
		{"shape": "crystal", "at": [0, 0.45, 0], "rot": [180, 0, 0], "material": "body", "motion": "spin", "radius": 0.16, "height": 0.3},
		{"shape": "sphere", "at": [0, 0.8, 0], "scale": 0.1, "material": "accent", "motion": "bob", "radius": 1.0, "segments": 6, "rings": 3}]
	return {"style": "shards", "sway": 2.6, "tint": "c8b8ff", "accent": "ffffff", "anchor": 1.2, "shadow": 1.2, "ring": 0.6, "parts": prism}
