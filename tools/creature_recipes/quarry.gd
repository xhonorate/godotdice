extends RefCounted
## The Quarry's creatures as recipes for tools/creature_bake.gd, one function a creature.
## Most are the models the owner picked in the model review of Oct 28 2026 (build/options):
## each keeps its review key as its "seed", so it bakes facet for facet as it was picked, and
## names the parts an animation moves (`head`, `jaw`, `leg`, `pick`, `drill`, ...; the roles
## are listed in build/options/part_roles/quarry.md). The Foreman, once a man with a pick, is
## now a rock-crab wearing his hard hat for a shell; The Drill, once a rig on tracks, is a
## drilling worm. The Rail Rat and The Regent keep their older models; the Quartz Golem and
## the Lantern Moth are hand-saved scenes with no recipe here.

static func recipes() -> Dictionary:
	return {
		"RAIL_RAT": {"style": "low", "sway": 3.4, "tint": "a8927a", "accent": "ffb24a", "anchor": 0.9, "shadow": 1.8, "ring": 0.9, "parts": [
			## A low body, a wedge of a head, a long tail, and amber crystals along the spine.
			{"shape": "rock", "at": [0, 0.28, 0], "scale": [0.55, 0.3, 0.42], "material": "body", "motion": "core", "jitter": 0.18},
			{"shape": "rock", "at": [0.0, 0.3, 0.42], "scale": [0.26, 0.2, 0.3], "material": "body", "motion": "bob", "phase": 0.4, "jitter": 0.14},
			{"shape": "cone", "at": [0.09, 0.42, 0.52], "rot": [-20, 0, 15], "scale": [0.08, 0.14, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cone", "at": [-0.09, 0.42, 0.52], "rot": [-20, 0, -15], "scale": [0.08, 0.14, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
			{"shape": "sphere", "at": [0.08, 0.3, 0.58], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "sphere", "at": [-0.08, 0.3, 0.58], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "crystal", "at": [0.0, 0.5, 0.1], "rot": [-25, 0, 0], "material": "accent", "motion": "crystal", "radius": 0.05, "height": 0.32},
			{"shape": "crystal", "at": [0.08, 0.46, -0.08], "rot": [-10, 0, 25], "material": "accent", "motion": "crystal", "radius": 0.045, "height": 0.26},
			{"shape": "crystal", "at": [-0.07, 0.46, -0.22], "rot": [10, 0, -30], "material": "accent", "motion": "crystal", "radius": 0.04, "height": 0.22},
			{"shape": "capsule", "at": [0, 0.22, -0.55], "rot": [80, 0, 0], "scale": [0.05, 0.4, 0.05], "material": "body", "motion": "swing", "radius": 1.0, "height": 2.0, "segments": 6},
			{"shape": "cylinder", "at": [0.22, 0.1, 0.25], "rot": [0, 0, 20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [-0.22, 0.1, 0.25], "rot": [0, 0, -20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [0.22, 0.1, -0.2], "rot": [0, 0, 20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [-0.22, 0.1, -0.2], "rot": [0, 0, -20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5}]},
		"CAVE_TICK": {"style": "low", "sway": 3.0, "tint": "58d878", "accent": "c8ffb0", "anchor": 1.05, "shadow": 1.9, "ring": 0.95, "seed": "CAVE_TICK_A", "parts": _cave_tick()},
		"MAGPIE": {"style": "wings", "sway": 2.6, "tint": "ff8a4a", "accent": "fff6c0", "anchor": 1.15, "shadow": 1.9, "ring": 0.95, "seed": "MAGPIE_A", "parts": _magpie()},
		"SILT_SLIME": {"style": "blob", "sway": 1.6, "tint": "58d878", "accent": "c8ffb0", "anchor": 1.25, "shadow": 2.2, "ring": 1.05, "seed": "SILT_SLIME_A", "parts": _silt_slime()},
		"CLOUDER": {"style": "puff", "sway": 1.2, "tint": "5a8cff", "accent": "d8e8ff", "anchor": 1.7, "shadow": 2.0, "ring": 1.0, "seed": "CLOUDER_A", "parts": _clouder()},
		## The Pit Mole is grown 1.2x from its picked size: smaller, it sank into the Quarry floor.
		"PIT_MOLE": {"style": "low", "sway": 1.8, "tint": "7a5a42", "accent": "ffd06a", "anchor": 1.2, "scale": 1.2, "shadow": 2.6, "ring": 1.2, "seed": "PIT_MOLE_A", "parts": _pit_mole()},
		"VEIN_WRAITH": {"style": "cluster", "sway": 1.2, "tint": "4fd6b8", "accent": "d0fff0", "anchor": 2.15, "shadow": 2.0, "ring": 1.0, "seed": "VEIN_WRAITH_A", "parts": _vein_wraith()},
		"GLASS_WYRM": {"style": "low", "sway": 1.4, "tint": "ff5a7a", "accent": "ffd0e0", "anchor": 1.8, "shadow": 2.6, "ring": 1.3, "seed": "GLASS_WYRM_B", "parts": _glass_wyrm()},
		"THE_FOREMAN": {"style": "low", "sway": 0.6, "tint": "ffd45a", "accent": "fff4d6", "anchor": 2.7, "warden": true, "shadow": 3.8, "ring": 1.8, "seed": "THE_FOREMAN_C", "parts": _foreman()},
		"THE_REGENT": {"style": "tower", "sway": 0.4, "tint": "9a7dff", "accent": "f0ecff", "anchor": 3.3, "warden": true, "shadow": 3.0, "ring": 1.45, "parts": _regent()},
		"THE_DRILL": {"style": "tower", "sway": 0.5, "tint": "6b625c", "accent": "ff5a2a", "anchor": 3.0, "warden": true, "shadow": 3.4, "ring": 1.6, "seed": "THE_DRILL_B", "parts": _drill()}}

## ---- helpers ----------------------------------------------------------------------------

static func _v(point: Vector3) -> Array:
	## A point as the [x, y, z] a recipe takes.
	return [point.x, point.y, point.z]

static func _merged(part: Dictionary, extra: Dictionary) -> Dictionary:
	## The part with `extra`'s fields laid over it.
	part.merge(extra, true)
	return part

static func _rot(basis: Basis) -> Array:
	## A basis as the degrees a part's `rot` takes (the bake reads them back in the same order).
	var e: Vector3 = basis.get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _euler(x: float, y: float, z: float) -> Basis:
	## A basis from degrees about x, y and z.
	return Basis.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))

static func _eye(at: Array, size: float = 0.05, motion: String = "", phase: float = 0.0) -> Dictionary:
	## A pentagonal gem of an eye (or a lamp): five segments, two rings.
	var eye: Dictionary = {"shape": "sphere", "at": at, "scale": size, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2}
	if motion != "":
		eye.merge({"motion": motion, "phase": phase})
	return eye

static func _gem_eye(at: Vector3, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## The same pentagonal gem laid at a Vector3, in any material: an eye, a pupil, a bubble.
	return _merged({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}, extra)

static func _gem(at: Array, scale: Variant, material: String = "core", motion: String = "core", phase: float = 0.0) -> Dictionary:
	## A cut stone cut from the recipe's own seed: a gem heart, a throat glow.
	var gem: Dictionary = {"shape": "rock", "at": at, "scale": scale, "material": material, "jitter": 0.08}
	if motion != "":
		gem.merge({"motion": motion, "phase": phase})
	return gem

static func _lens(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## The biggest cut gem allowed (six segments, three rings): a lamp's lens.
	var s: Variant = _v(size) if size is Vector3 else size
	return _merged({"shape": "sphere", "at": _v(at), "scale": s, "material": material, "radius": 1.0, "segments": 6, "rings": 3}, extra)

static func _rock(at: Vector3, size: Variant, material: String, jitter: float, grain: int, extra: Dictionary = {}) -> Dictionary:
	## A rock cut from its own seed (`grain`): low jitter is a cut stone, high a boulder.
	var s: Variant = _v(size) if size is Vector3 else size
	return _merged({"shape": "rock", "at": _v(at), "scale": s, "material": material, "jitter": jitter, "seed": grain}, extra)

static func _crystal(from: Vector3, to: Vector3, r: float, material: String = "accent", extra: Dictionary = {}, sides: int = 6) -> Dictionary:
	## A swaying crystal stood from `from` to `to`.
	return _merged({"shape": "crystal", "from": _v(from), "to": _v(to), "material": material, "motion": "crystal", "radius": r, "sides": sides}, extra)

static func _box(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	## A plain box.
	return _merged({"shape": "box", "at": _v(at), "material": material, "size": _v(size)}, extra)

static func _foot(at: Array, size: Array, rot: Array = [0, 0, 0]) -> Dictionary:
	## A slab of a foot, flat on the floor.
	return {"shape": "slab", "at": at, "rot": rot, "material": "body", "size": size, "jitter": 0.01}

static func _rubble(specs: Array) -> Array:
	## Loose rocks on the floor, each [at, scale], cut from seeds 71 up.
	var out: Array = []
	var which: int = 70
	for spec in specs:
		which += 1
		out.append({"shape": "rock", "at": spec[0], "scale": spec[1], "material": "body", "jitter": 0.3, "seed": which})
	return out

## ---- Cave Tick ----------------------------------------------------------------------------

static func _cave_tick() -> Array:
	## A proper tick: a crystal-grown scutum over a swollen abdomen, a small head with iron
	## mandibles, eight legs ending in crystal points, a glowing hex collar where belly meets chest.
	var parts: Array = [
		{"shape": "rock", "at": [0, 0.42, -0.18], "scale": [0.42, 0.34, 0.46], "material": "body", "motion": "core", "phase": 0.0, "jitter": 0.08, "seed": 10, "name": "body"},
		{"shape": "cap", "at": [0, 0.66, -0.18], "material": "iron", "motion": "core", "phase": 0.0, "radius": 0.32, "height": 0.16, "sides": 7, "seed": 11, "name": "shell"},
		{"shape": "column", "from": [0, 0.4, 0.1], "to": [0, 0.4, 0.2], "material": "core", "motion": "core", "phase": 0.8, "radius": 0.28, "sides": 6},
		{"shape": "rock", "at": [0, 0.36, 0.28], "scale": [0.27, 0.22, 0.26], "material": "body", "jitter": 0.1, "seed": 12}]
	## The head turns a little from its middle, eyes and mouthparts with it; each iron mandible
	## (`jaw`) hinges at its own root so the pair can snap.
	var head := [0, 0.33, 0.52]
	for piece in [
		{"shape": "rock", "at": head, "scale": [0.15, 0.12, 0.16], "material": "body", "jitter": 0.12, "seed": 13},
		_eye([0.09, 0.4, 0.58], 0.035), _eye([-0.09, 0.4, 0.58], 0.035),
		{"shape": "cone", "from": [0.08, 0.3, 0.63], "to": [0.02, 0.26, 0.84], "material": "iron", "radius": 0.03, "sides": 4, "name": "jaw", "joint": [0.08, 0.3, 0.63]},
		{"shape": "cone", "from": [-0.08, 0.3, 0.63], "to": [-0.02, 0.26, 0.84], "material": "iron", "radius": 0.03, "sides": 4, "name": "jaw", "joint": [-0.08, 0.3, 0.63]},
		{"shape": "cone", "from": [0, 0.31, 0.62], "to": [0, 0.3, 0.8], "material": "accent", "radius": 0.02, "sides": 4}]:
		piece.merge({"joint": head, "motion": "block", "phase": 0.4, "name": "head"})
		parts.append(piece)
	for side in [-1.0, 1.0]:
		for leg in range(4):
			var hip := Vector3(side * 0.2, 0.3, 0.42 - 0.17 * float(leg))
			var spread: float = 0.2 - 0.13 * float(leg)
			var knee := Vector3(side * 0.45, 0.52 - 0.02 * float(leg), hip.z + spread)
			var foot := Vector3(side * 0.62, 0.02, hip.z + spread * 2.0)
			_tick_leg(parts, hip, knee, foot, float(leg) * 1.1 + (0.0 if side > 0.0 else 1.6), 0.04, 0.028)
	## Crystals grown out of the scutum.
	for spec in [[[0, 0.7, -0.2], [0.04, 0.98, -0.28], 0.05], [[0.18, 0.64, -0.06], [0.34, 0.86, -0.02], 0.04], [[-0.2, 0.64, -0.16], [-0.38, 0.84, -0.2], 0.045], [[0.1, 0.62, -0.42], [0.18, 0.84, -0.58], 0.04], [[-0.08, 0.6, -0.46], [-0.12, 0.76, -0.64], 0.035]]:
		parts.append({"shape": "crystal", "from": spec[0], "to": spec[1], "material": "accent", "motion": "crystal", "radius": spec[2]})
	## Where the bite is: between the mandibles, riding with the head.
	parts.append({"shape": "sphere", "at": [0, 0.3, 0.66], "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth", "joint": head, "motion": "block", "phase": 0.4})
	return parts

static func _tick_leg(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, phase: float, upper: float, lower: float) -> void:
	## A jointed `leg` swinging from the hip: a five-sided column to the knee, a crystal from
	## there to its point.
	var thigh: Dictionary = {"shape": "cylinder", "from": _v(hip), "to": _v(knee), "material": "body", "top": upper * 0.7, "bottom": upper, "sides": 5}
	var shin: Dictionary = {"shape": "crystal", "from": _v(knee), "to": _v(foot), "material": "body", "radius": lower, "sides": 5}
	for piece in [thigh, shin]:
		piece.merge({"motion": "swing", "phase": phase, "joint": _v(hip), "name": "leg"}, true)
		out.append(piece)

## ---- Magpie -------------------------------------------------------------------------------

static func _magpie() -> Array:
	## A perched magpie mantling over its prize: upright body with a pale glowing breast, a
	## pyrite nugget in its iron beak, wings half raised and beating, a long fanned tail, feet
	## among dropped nuggets.
	var neck := [0, 0.64, 0.2]
	var parts: Array = [
		{"shape": "rock", "at": [0, 0.5, 0], "rot": [50, 0, 0], "scale": [0.2, 0.3, 0.22], "material": "body", "motion": "core", "jitter": 0.08, "seed": 20, "name": "body"},
		{"shape": "rock", "at": [0, 0.36, 0.1], "scale": 0.16, "material": "core", "motion": "core", "phase": 0.5, "jitter": 0.06, "seed": 19},
		{"shape": "cylinder", "from": [0, 0.64, 0.2], "to": [0, 0.78, 0.28], "material": "body", "top": 0.07, "bottom": 0.09, "sides": 6, "name": "neck", "joint": neck},
		{"shape": "rock", "at": [0.42, 0.04, 0.3], "scale": 0.055, "material": "accent", "jitter": 0.3, "seed": 22},
		{"shape": "rock", "at": [-0.3, 0.04, 0.45], "scale": 0.05, "material": "accent", "jitter": 0.3, "seed": 23}]
	## Head, eyes, beak and crest bob as one, hung from the base of the neck so a peck can dip
	## them. The nugget in the beak is the `prize`, hidden until the magpie has stolen.
	var head := [0, 0.78, 0.28]
	for piece in [
		{"shape": "rock", "at": head, "scale": [0.13, 0.12, 0.14], "material": "body", "jitter": 0.08, "seed": 18},
		_eye([0.09, 0.82, 0.34], 0.03), _eye([-0.09, 0.82, 0.34], 0.03),
		{"shape": "cone", "from": [0, 0.77, 0.38], "to": [0, 0.72, 0.6], "material": "iron", "radius": 0.045, "sides": 5},
		{"shape": "rock", "at": [0, 0.7, 0.58], "scale": 0.065, "material": "accent", "jitter": 0.3, "seed": 21, "name": "prize"},
		{"shape": "crystal", "from": [0, 0.86, 0.24], "to": [0.03, 1.02, 0.16], "material": "accent", "radius": 0.03},
		{"shape": "crystal", "from": [0.05, 0.85, 0.28], "to": [0.12, 0.97, 0.24], "material": "accent", "radius": 0.025}]:
		piece.merge({"joint": neck, "motion": "bob", "phase": 0.3}, true)
		piece.merge({"name": "head"})
		parts.append(piece)
	## The fanned tail swings from its root.
	for k in [-1.5, -0.5, 0.5, 1.5]:
		parts.append({"shape": "box", "at": [k * 0.045, 0.3, -0.46], "rot": [-28, k * 9.0, 0], "material": "body", "motion": "swing", "phase": 0.2, "joint": [0, 0.34, -0.22], "size": [0.05, 0.015, 0.5], "name": "tail"})
	for side in [-1.0, 1.0]:
		_magpie_wing(parts, Vector3(side * 0.13, 0.58, 0.02), side, 0.6, 0.5)
		_magpie_foot(parts, Vector3(side * 0.08, 0.32, 0.04), Vector3(side * 0.09, 0.12, 0.08))
	return parts

static func _magpie_wing(out: Array, shoulder: Vector3, side: float, lift: float, span: float) -> void:
	## A wing hung from the shoulder (`wing_l` on +x, `wing_r` on -x): a broad primary, a longer
	## secondary swept back, and three crystal finger feathers past the tip, beating as one.
	var dir := Vector3(side, lift, -0.15).normalized()
	var dir2 := Vector3(side, lift * 0.8, -0.42).normalized()
	var tip: Vector3 = shoulder + dir * span
	for piece in [
		{"shape": "prism", "at": _v(shoulder + dir * span * 0.5), "aim": _v(dir), "mesh_rot": [0, 90, 0], "material": "body", "size": [0.42, span, 0.03]},
		{"shape": "prism", "at": _v(shoulder + dir2 * span * 0.6 + Vector3(0, -0.03, 0)), "aim": _v(dir2), "mesh_rot": [0, 90, 0], "material": "body", "size": [0.3, span * 1.2, 0.03]},
		{"shape": "crystal", "from": _v(tip - dir * 0.1), "to": _v(tip + dir * 0.18), "material": "body", "radius": 0.022, "sides": 4},
		{"shape": "crystal", "from": _v(tip - dir * 0.14 + Vector3(0, 0, -0.08)), "to": _v(tip + dir * 0.12 + Vector3(0, -0.02, -0.16)), "material": "body", "radius": 0.022, "sides": 4},
		{"shape": "crystal", "from": _v(tip - dir * 0.18 + Vector3(0, 0, -0.16)), "to": _v(tip + dir * 0.04 + Vector3(0, -0.04, -0.28)), "material": "body", "radius": 0.022, "sides": 4}]:
		piece.merge({"joint": _v(shoulder), "motion": "wing", "side": side, "phase": 0.0, "name": "wing_l" if side > 0.0 else "wing_r"}, true)
		out.append(piece)

static func _magpie_foot(out: Array, hip: Vector3, ankle: Vector3) -> void:
	## A thin `leg` from the hip to the ankle and three toes splayed on the floor.
	out.append({"shape": "cylinder", "from": _v(hip), "to": _v(ankle), "material": "body", "top": 0.02, "bottom": 0.026, "sides": 4, "name": "leg", "joint": _v(hip)})
	for toe in [Vector3(-0.07, -0.12, 0.14), Vector3(0.0, -0.12, 0.17), Vector3(0.07, -0.12, 0.14)]:
		out.append({"shape": "cylinder", "from": _v(ankle), "to": _v(ankle + toe), "material": "body", "top": 0.01, "bottom": 0.016, "sides": 3, "name": "leg", "joint": _v(hip)})

## ---- Silt Slime ---------------------------------------------------------------------------

static func _silt_slime() -> Array:
	## The mound wears its miner's helmet straight and proud, lamp shining ahead; big gem eyes,
	## a wide grin. No pick.
	var grin := [0, 0.38, 0.55]
	var parts: Array = [
		_rock(Vector3(0, 0.42, 0), Vector3(0.6, 0.44, 0.56), "body", 0.16, 31, {"motion": "core", "name": "body"}),
		_rock(Vector3(0, 0.42, 0), Vector3(0.57, 0.42, 0.53), "core", 0.07, 30, {"motion": "core", "phase": 0.9, "name": "body"}),
		_rock(Vector3(0, 0.1, 0.05), Vector3(0.8, 0.12, 0.74), "body", 0.25, 32),
		_rock(Vector3(0.32, 0.3, -0.28), Vector3(0.3, 0.26, 0.3), "body", 0.16, 33, {"motion": "core", "phase": 1.6}),
		_rock(Vector3(0.32, 0.3, -0.28), Vector3(0.28, 0.24, 0.28), "core", 0.07, 29, {"motion": "core", "phase": 2.2}),
		## Each big eye and its iron pupil turn together from the eye's middle.
		_gem_eye(Vector3(0.15, 0.56, 0.5), 0.07, "accent", {"name": "eye", "joint": [0.15, 0.56, 0.5]}),
		_gem_eye(Vector3(-0.15, 0.56, 0.5), 0.07, "accent", {"name": "eye", "joint": [-0.15, 0.56, 0.5]}),
		_gem_eye(Vector3(0.15, 0.56, 0.565), 0.032, "iron", {"name": "eye", "joint": [0.15, 0.56, 0.5]}),
		_gem_eye(Vector3(-0.15, 0.56, 0.565), 0.032, "iron", {"name": "eye", "joint": [-0.15, 0.56, 0.5]}),
		## The grin is the mouth the ooze leaves from.
		_box(Vector3(0, 0.38, 0.55), Vector3(0.14, 0.035, 0.05), "iron", {"name": "mouth", "joint": grin}),
		_box(Vector3(0.11, 0.405, 0.53), Vector3(0.1, 0.035, 0.05), "iron", {"rot": [0, -15, 28], "name": "mouth", "joint": grin}),
		_box(Vector3(-0.11, 0.405, 0.53), Vector3(0.1, 0.035, 0.05), "iron", {"rot": [0, 15, -28], "name": "mouth", "joint": grin})]
	_helmet(parts, Vector3(0, 0.74, 0.04), _euler(-6, 0, 0), 0.28)
	_drip(parts, Vector3(0.5, 0.36, 0.22), Vector3(0.62, 0.04, 0.32), 0.05, 61)
	_drip(parts, Vector3(-0.48, 0.32, -0.18), Vector3(-0.62, 0.04, -0.24), 0.045, 62)
	_drip(parts, Vector3(-0.3, 0.3, 0.45), Vector3(-0.36, 0.04, 0.6), 0.04, 63)
	## Bubbles rising off it, and iron pebbles it has swallowed.
	for spec in [[Vector3(0.36, 0.7, 0.2), 0.035, 0.0], [Vector3(-0.38, 0.62, 0.12), 0.03, 1.4], [Vector3(-0.1, 0.84, -0.36), 0.028, 2.6]]:
		parts.append(_gem_eye(spec[0], spec[1], "accent", {"motion": "bob", "phase": spec[2]}))
	for spec in [[Vector3(0.4, 0.5, 0.3), 0.065, 34], [Vector3(-0.42, 0.44, -0.2), 0.06, 35], [Vector3(0.55, 0.14, -0.3), 0.05, 38]]:
		parts.append(_rock(spec[0], spec[1], "iron", 0.3, spec[2]))
	return parts

static func _helmet(out: Array, at: Vector3, basis: Basis, r: float) -> void:
	## A miner's hard hat sitting on `at` (the middle of its brim), tipped by `basis`: a hex
	## brim, a faceted crown and a lamp housing on its brow (`helmet`, turning from the brim's
	## middle), and the lamp's lens lit and pulsing on its own (`lamp`).
	var up: Vector3 = basis.y
	var fwd: Vector3 = basis.z
	var rot: Array = _rot(basis)
	var lamp: Vector3 = at + up * r * 0.46 + fwd * r * 0.9
	var pieces: Array = [
		{"shape": "cylinder", "at": _v(at), "rot": rot, "material": "iron", "top": r * 1.2, "bottom": r * 1.2, "height": r * 0.12, "sides": 6},
		{"shape": "cylinder", "at": _v(at + up * r * 0.36), "rot": rot, "material": "iron", "top": r * 0.84, "bottom": r, "height": r * 0.72, "sides": 6},
		{"shape": "cap", "at": _v(at + up * r * 0.7), "rot": rot, "material": "iron", "radius": r * 0.88, "height": r * 0.42, "sides": 6, "seed": 40},
		{"shape": "box", "at": _v(at + up * r * 0.9), "rot": rot, "material": "iron", "size": [r * 0.24, r * 0.2, r * 1.5]},
		{"shape": "cylinder", "at": _v(lamp), "rot": _rot(basis * Basis(Vector3.RIGHT, PI * 0.5)), "material": "iron", "top": r * 0.46, "bottom": r * 0.52, "height": r * 0.36, "sides": 6}]
	for piece in pieces:
		piece.merge({"name": "helmet", "joint": _v(at)}, true)
		out.append(piece)
	out.append(_lens(lamp + fwd * r * 0.2, Vector3(r * 0.42, r * 0.42, r * 0.18), "accent", {"rot": rot, "motion": "core", "name": "lamp"}))

static func _drip(out: Array, from: Vector3, to: Vector3, radius: float, grain: int) -> void:
	## A run of ooze narrowing to the floor and the flat puddle it feeds.
	out.append(_crystal(from, to, radius, "core", {"motion": "static"}, 5))
	out.append(_rock(Vector3(to.x, 0.02, to.z), Vector3(radius * 2.2, 0.02, radius * 2.2), "core", 0.1, grain))

## ---- Clouder ------------------------------------------------------------------------------

static func _clouder() -> Array:
	## A cumulus heap of cut stones of fog round a gem core, three eyes in the fog, wisps
	## trailing beneath, stones and sparks circling.
	var parts: Array = [
		{"shape": "rock", "at": [0, 0.98, 0], "scale": 0.42, "material": "core", "motion": "core", "phase": 0.0, "jitter": 0.06, "seed": 50, "name": "heart"},
		_merged(_eye([0.12, 1.0, 0.62], 0.05), {"name": "eye"}), _merged(_eye([-0.08, 1.0, 0.63], 0.05), {"name": "eye"}),
		_merged(_eye([-0.455, 1.08, 0.22], 0.035), {"name": "eye"})]
	## The fog: overlapping cut stones, each breathing on its own beat.
	var lumps: Array = [[Vector3(0.36, 1.05, 0.1), 0.32], [Vector3(-0.34, 1.0, -0.08), 0.33], [Vector3(0.1, 1.3, -0.05), 0.3], [Vector3(-0.12, 0.72, 0.22), 0.3], [Vector3(0.22, 0.72, -0.2), 0.28], [Vector3(-0.3, 1.3, 0.14), 0.22], [Vector3(0.3, 1.32, -0.26), 0.2], [Vector3(0.02, 0.92, 0.4), 0.26], [Vector3(-0.05, 0.62, -0.1), 0.22], [Vector3(0, 1.0, -0.4), 0.26]]
	for i in range(lumps.size()):
		parts.append({"shape": "rock", "at": _v(lumps[i][0]), "scale": lumps[i][1], "material": "body", "motion": "core", "phase": float(i) * 0.8, "jitter": 0.12, "seed": 51 + i, "name": "fog"})
	## Wisps trailing beneath, each swinging from where it leaves the fog.
	for wisp in [[[0.15, 0.62, 0.1], [0.3, 0.22, 0.25], 0.05], [[-0.2, 0.58, -0.1], [-0.38, 0.18, -0.22], 0.045], [[0.05, 0.55, -0.25], [0.0, 0.2, -0.45], 0.04], [[-0.05, 0.6, 0.3], [-0.1, 0.3, 0.48], 0.04]]:
		parts.append({"shape": "cone", "from": wisp[0], "to": wisp[1], "material": "body", "motion": "swing", "phase": float(wisp[1][0]) * 5.0, "joint": wisp[0], "radius": wisp[2], "sides": 5, "name": "wisp"})
	## Stray stones and sparks circling it.
	for spec in [[[0.62, 1.1, 0], 0.1, 62], [[-0.55, 0.8, 0.2], 0.09, 63], [[0.2, 1.5, 0.45], 0.08, 64]]:
		parts.append({"shape": "rock", "at": spec[0], "scale": spec[1], "material": "body", "motion": "orbit", "phase": float(spec[0][1]) * 3.0, "jitter": 0.1, "seed": spec[2]})
	for spec in [[[0.3, 0.95, 0.3], 0.03], [[-0.25, 1.2, -0.35], 0.025]]:
		var spark := _eye(spec[0], spec[1])
		spark.merge({"motion": "orbit", "phase": float(spec[0][1]) * 3.0}, true)
		parts.append(spark)
	return parts

## ---- Pit Mole -----------------------------------------------------------------------------

static func _pit_mole() -> Array:
	## A mole: velvet body and rump, pointed snout with a bright nose and whiskers, small eyes,
	## two great forearms ending in gold crystal claws dug into the floor, loose rock and ore
	## around it. The `mound` and the `rubble` stay put when it digs in.
	var parts: Array = [
		{"shape": "rock", "at": [0, 0.52, -0.1], "scale": [0.5, 0.44, 0.62], "material": "body", "motion": "core", "jitter": 0.07, "seed": 60, "name": "body"},
		{"shape": "rock", "at": [0, 0.46, -0.5], "scale": [0.4, 0.36, 0.34], "material": "body", "motion": "core", "phase": 0.6, "jitter": 0.08, "seed": 59, "name": "body"},
		{"shape": "rock", "at": [0, 0.06, 0], "scale": [1.15, 0.09, 1.25], "material": "body", "jitter": 0.35, "seed": 61, "name": "mound"},
		{"shape": "crystal", "from": [0, 0.4, -0.8], "to": [0.1, 0.3, -1.04], "material": "body", "motion": "swing", "joint": [0, 0.4, -0.8], "radius": 0.03, "sides": 5, "name": "tail"}]
	## The snout is its head: nose, eyes and whiskers turn with it.
	var snout := [0, 0.5, 0.5]
	for piece in [
		{"shape": "cone", "from": [0, 0.5, 0.42], "to": [0, 0.42, 0.96], "material": "body", "radius": 0.23, "sides": 6},
		_eye([0, 0.42, 0.97], 0.055),
		_eye([0.09, 0.56, 0.66], 0.025), _eye([-0.09, 0.56, 0.66], 0.025),
		{"shape": "cylinder", "from": [0.1, 0.44, 0.84], "to": [0.36, 0.48, 0.9], "material": "body", "top": 0.006, "bottom": 0.008, "sides": 3},
		{"shape": "cylinder", "from": [-0.1, 0.44, 0.84], "to": [-0.36, 0.48, 0.9], "material": "body", "top": 0.006, "bottom": 0.008, "sides": 3},
		{"shape": "cylinder", "from": [0.1, 0.4, 0.88], "to": [0.34, 0.36, 0.98], "material": "body", "top": 0.006, "bottom": 0.008, "sides": 3},
		{"shape": "cylinder", "from": [-0.1, 0.4, 0.88], "to": [-0.34, 0.36, 0.98], "material": "body", "top": 0.006, "bottom": 0.008, "sides": 3}]:
		piece.merge({"joint": snout, "motion": "block", "phase": 0.3, "name": "head"}, true)
		parts.append(piece)
	for side in [-1.0, 1.0]:
		## A forearm, its paw and four gold claws dig as one from the shoulder (`claw_l` on +x).
		var shoulder := Vector3(side * 0.3, 0.44, 0.28)
		var wrist := Vector3(side * 0.56, 0.2, 0.46)
		var arm: Array = [
			{"shape": "cylinder", "from": _v(shoulder), "to": _v(wrist), "material": "body", "top": 0.09, "bottom": 0.12, "sides": 6},
			{"shape": "rock", "at": _v(wrist + Vector3(side * 0.02, -0.02, 0.06)), "scale": [0.15, 0.09, 0.14], "material": "body", "jitter": 0.1, "seed": 70 + int(side)}]
		for k in range(4):
			var root: Vector3 = wrist + Vector3(side * (-0.1 + 0.07 * float(k)), -0.04, 0.12)
			var tip: Vector3 = root + Vector3(side * (-0.06 + 0.06 * float(k)), -0.14, 0.26 - 0.05 * float(k))
			arm.append({"shape": "crystal", "from": _v(root), "to": _v(tip), "material": "accent", "radius": 0.035})
		for piece in arm:
			piece.merge({"joint": _v(shoulder), "motion": "swing", "phase": 0.0 if side > 0.0 else 1.2, "name": "claw_l" if side > 0.0 else "claw_r"}, true)
			parts.append(piece)
		## A hind `leg` on a slab foot.
		var hip := [side * 0.3, 0.3, -0.4]
		parts.append({"shape": "cylinder", "from": hip, "to": [side * 0.44, 0.04, -0.34], "material": "body", "top": 0.05, "bottom": 0.07, "sides": 5, "name": "leg", "joint": hip})
		parts.append(_merged(_foot([side * 0.46, 0.03, -0.26], [0.13, 0.05, 0.2], [0, side * -10.0, 0]), {"name": "leg", "joint": hip}))
	## Loose rock and two lumps of ore thrown up round it.
	for spec in [[[0.72, 0.08, 0.2], 0.16, 62], [[-0.68, 0.07, 0.5], 0.12, 63], [[0.4, 0.06, -0.72], 0.14, 64], [[-0.52, 0.1, -0.5], 0.18, 65], [[0.1, 0.05, 1.12], 0.1, 66]]:
		parts.append({"shape": "rock", "at": spec[0], "scale": spec[1], "material": "body", "jitter": 0.3, "seed": spec[2], "name": "rubble"})
	parts.append({"shape": "rock", "at": [-0.75, 0.05, 0.1], "scale": 0.05, "material": "accent", "jitter": 0.3, "seed": 67, "name": "rubble"})
	parts.append({"shape": "rock", "at": [0.55, 0.05, 0.75], "scale": 0.045, "material": "accent", "jitter": 0.3, "seed": 68, "name": "rubble"})
	return parts

## ---- Vein Wraith --------------------------------------------------------------------------

static func _vein_wraith() -> Array:
	## The crystal jellyfish pared down: a stone hood with one crystal on its crown, a gem heart
	## and two eyes beneath, six long crystals hanging from the rim, three trailing shards.
	var parts: Array = [
		{"shape": "cap", "at": [0, 1.3, 0], "material": "body", "motion": "core", "phase": 0.0, "radius": 0.46, "height": 0.36, "sides": 7, "seed": 92, "name": "body"},
		_rock(Vector3(0, 1.05, 0), 0.15, "accent", 0.06, 91, {"motion": "core", "name": "heart"}),
		_gem_eye(Vector3(0.13, 1.2, 0.3), 0.045, "accent", {"name": "eye"}), _gem_eye(Vector3(-0.13, 1.2, 0.3), 0.045, "accent", {"name": "eye"}),
		_crystal(Vector3(0, 1.58, 0), Vector3(0.03, 1.98, -0.05), 0.07, "accent", {"name": "crest"})]
	## The fringe: six crystals hung from the rim, each swaying from where it hangs.
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0 + PI / 6.0
		var out := Vector3(cos(ang), 0, sin(ang))
		parts.append(_crystal(out * 0.42 + Vector3(0, 1.32, 0), out * 0.5 + Vector3(0, 0.78, 0), 0.055, "body", {"phase": float(i) * 0.9, "name": "tendril"}))
	## Three shards trailing below the heart, swinging from their tops.
	for i in range(3):
		var ang: float = TAU * float(i) / 3.0 + PI * 0.5
		var top := Vector3(cos(ang) * 0.1, 0.95, sin(ang) * 0.1)
		var end := Vector3(cos(ang) * 0.24, 0.18 + 0.1 * float(i), sin(ang) * 0.24 - 0.06)
		parts.append(_crystal(top, end, 0.04, "body", {"motion": "swing", "phase": float(i) * 1.3, "joint": _v(top), "name": "trail"}, 4))
	for spec in [[Vector3(0.62, 1.05, 0), 0.03, 0.0], [Vector3(-0.5, 0.75, 0.3), 0.025, 2.5]]:
		parts.append(_gem_eye(spec[0], spec[1], "accent", {"motion": "orbit", "phase": spec[2]}))
	return parts

## ---- Glass Wyrm ---------------------------------------------------------------------------

static func _glass_wyrm() -> Array:
	## Coiled flat on the floor, one and a half turns of stepped glass stones winding inward,
	## the head lifted from the centre with jaws open.
	var points: Array = []
	var radii: Array = []
	for i in range(17):
		var t: float = float(i) / 16.0
		var angle: float = PI * 0.5 + TAU * 1.5 * t
		var radius: float = lerpf(1.0, 0.3, t)
		points.append(Vector3(cos(angle) * radius, 0.12 + 0.5 * t * t, sin(angle) * radius))
		radii.append(lerpf(0.08, 0.19, t))
	## The neck rises from the centre of the coil and leans toward the party.
	for spec in [[0.18, 0.78, 0.0], [0.08, 1.02, 0.18], [0.0, 1.14, 0.4]]:
		points.append(Vector3(spec[0], spec[1], spec[2]))
		radii.append(0.19)
	var parts: Array = _chain(points, 0.19, 0.08, "crystal")
	## The outer four stones are the `tail` (its tip lies at the front), each hinged at its front
	## end so it can whip stone by stone; the last three are the `neck`, each hinged at its back
	## end; the coil between is the `body`.
	for i in range(parts.size()):
		if i < 4:
			parts[i].merge({"name": "tail", "joint": _v((points[i] + points[i + 1]) * 0.5)})
		elif i >= 17:
			parts[i].merge({"name": "neck", "joint": _v((points[i - 1] + points[i]) * 0.5)})
		else:
			parts[i].merge({"name": "body"})
	var head_at: Vector3 = points[19] + Vector3(0, 0.02, 0.1)
	var facing: Vector3 = Vector3(0, -0.15, 1).normalized()
	parts.append_array(_wyrm_head(head_at, facing, Vector3.UP, 1.0, points[19], "bob", 0.4))
	## Glass spines down its back; the last stands on the neck and bends with it.
	var spines: Array = _spines(points, radii, 0.3, 4, 19, 2)
	spines[spines.size() - 1].merge({"name": "neck", "joint": _v((points[17] + points[18]) * 0.5), "phase": 18.0 * 0.6}, true)
	parts.append_array(spines)
	## The tail's spike, riding on the tail's last stone.
	parts.append({"shape": "crystal", "from": _v(points[0]), "to": _v(points[0] + Vector3(0.1, 0.12, -0.5)), "material": "body", "motion": "crystal", "radius": 0.06, "name": "tail", "joint": _v((points[0] + points[1]) * 0.5), "phase": 0.0})
	parts.append({"shape": "rock", "at": [0, 0.04, 0], "scale": [0.6, 0.08, 0.6], "material": "core", "motion": "core", "jitter": 0.2, "seed": 54})
	## Where the crystal breath leaves: between the open jaws, riding with the head.
	parts.append({"shape": "sphere", "at": _v(head_at + facing * 0.35 - Vector3.UP * 0.125), "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2, "name": "mouth", "joint": _v(points[19]), "motion": "bob", "phase": 0.4})
	return parts

static func _chain(points: Array, r_head: float, r_tail: float, motion: String = "crystal", material: String = "body") -> Array:
	## A long body as stepped stones from the tail (first point) to the head (last): a cut rock,
	## then a slab, each aimed down the spine and overlapping its neighbours, thinning to the
	## tail. No beads.
	var out: Array = []
	var n: int = points.size()
	for i in range(n):
		var p: Vector3 = points[i]
		var t: Vector3 = points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]
		var seg: float = t.length() / (2.0 if 0 < i and i < n - 1 else 1.0)
		var r: float = lerpf(r_tail, r_head, float(i) / float(n - 1))
		var part: Dictionary
		if i % 2 == 0:
			part = {"shape": "rock", "at": _v(p), "aim": _v(t.normalized()), "scale": [r, seg * 0.66, r * 0.9], "material": material, "jitter": 0.1}
		else:
			part = {"shape": "slab", "at": _v(p), "aim": _v(t.normalized()), "size": [r * 1.7, seg * 1.0, r * 1.5], "material": material, "jitter": 0.03}
		if motion != "":
			part.merge({"motion": motion, "phase": float(i) * 0.6})
		out.append(part)
	return out

static func _spines(points: Array, radii: Array, length: float, first: int, last: int, skip: int = 1) -> Array:
	## Dorsal glass spines standing off the back of a spine of points.
	var out: Array = []
	for i in range(first, last, skip):
		var t: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var up: Vector3 = Vector3.UP - t * Vector3.UP.dot(t)
		if up.length() < 0.3:
			up = Vector3.BACK - t * Vector3.BACK.dot(t)
		up = up.normalized()
		var root: Vector3 = points[i] + up * float(radii[i]) * 0.8
		out.append({"shape": "crystal", "from": _v(root), "to": _v(root + (up + t * 0.5).normalized() * length * (0.7 + 0.3 * sin(float(i) * 1.3))), "material": "accent", "motion": "crystal", "phase": float(i) * 0.9, "radius": 0.05})
	return out

static func _wyrm_head(at: Vector3, dir: Vector3, up: Vector3, s: float, neck: Vector3, motion: String = "bob", phase: float = 0.0) -> Array:
	## A wyrm's `head`, turning from the top of the `neck`: a faceted skull, a tapered upper jaw,
	## gem eyes, two swept-back horns and a row of glass teeth. The lower jaw hangs open (`jaw`,
	## hinged at its root) and a gem glows in the throat (`throat`, pulsing on its own).
	var across: Vector3 = dir.cross(up).normalized()
	var hinge: Vector3 = at - up * 0.1 * s + dir * 0.02 * s
	var out: Array = [
		{"shape": "rock", "at": _v(at), "scale": [0.24 * s, 0.2 * s, 0.26 * s], "material": "body", "jitter": 0.1, "seed": 51},
		{"shape": "cone", "from": _v(at + dir * 0.08 * s), "to": _v(at + dir * 0.6 * s + up * 0.02 * s), "material": "body", "radius": 0.19 * s, "sides": 6},
		{"shape": "cone", "from": _v(hinge), "to": _v(at + dir * 0.5 * s - up * 0.26 * s), "material": "body", "radius": 0.13 * s, "sides": 6, "name": "jaw", "joint": _v(hinge)},
		_merged(_gem(_v(at + dir * 0.18 * s - up * 0.06 * s), 0.09 * s), {"name": "throat"})]
	for side in [-1.0, 1.0]:
		out.append(_eye(_v(at + dir * 0.16 * s + across * side * 0.15 * s + up * 0.1 * s), 0.055 * s))
		out.append({"shape": "crystal", "from": _v(at - dir * 0.02 * s + across * side * 0.12 * s + up * 0.12 * s), "to": _v(at - dir * 0.42 * s + across * side * 0.3 * s + up * 0.36 * s), "material": "body", "radius": 0.06 * s})
		for k in range(2):
			var f: float = 0.26 + 0.14 * float(k)
			out.append({"shape": "crystal", "from": _v(at + dir * f * s + across * side * (0.1 - 0.03 * float(k)) * s - up * 0.04 * s), "to": _v(at + dir * f * s + across * side * (0.09 - 0.03 * float(k)) * s - up * 0.17 * s), "material": "accent", "radius": 0.025 * s, "sides": 4})
	for part in out:
		if not part.has("motion"):
			part.merge({"motion": motion, "phase": phase})
		if not part.has("name"):
			part.merge({"name": "head", "joint": _v(neck)})
	return out

## ---- The Foreman --------------------------------------------------------------------------

static func _foreman() -> Array:
	## A rock-crab wearing the hard hat as its shell (lamp on the front), eyes on stalks, six
	## iron-tipped legs, a pick for one claw and the lantern swinging from the other.
	var parts: Array = [
		{"shape": "rock", "at": [0, 1.12, 0], "scale": [1.4, 0.55, 1.15], "material": "body", "motion": "core", "jitter": 0.12, "seed": 91, "name": "body"},
		{"shape": "rock", "at": [0, 0.9, 0.5], "scale": [1.0, 0.35, 0.7], "material": "body", "jitter": 0.1, "seed": 92},
		{"shape": "box", "at": [0, 0.95, 0.95], "material": "iron", "size": [0.5, 0.2, 0.3]}]
	parts.append_array(_hard_hat(Vector3(0, 1.42, -0.05), 1.05, {"name": "shell", "joint": [0, 1.42, -0.05]}))
	for side in [-1.0, 1.0]:
		## An eye on a `stalk`, the two turning from the stalk's root.
		var root := [side * 0.38, 1.15, 0.95]
		parts.append({"shape": "cylinder", "from": root, "to": [side * 0.5, 1.72, 1.2], "material": "body", "top": 0.045, "bottom": 0.06, "sides": 5, "name": "stalk", "joint": root})
		parts.append(_merged(_eye([side * 0.5, 1.76, 1.22], 0.1), {"name": "stalk", "joint": root}))
		## Three legs a side, each with an iron tip, hinged at the hip.
		for z in [0.55, 0.0, -0.55]:
			var hip := [side * 1.15, 0.95, z]
			var knee := Vector3(side * 1.65, 1.5, z * 1.35)
			var foot := Vector3(side * 2.05, 0.04, z * 1.65)
			for piece in [
				{"shape": "cylinder", "from": hip, "to": _v(knee), "material": "body", "top": 0.12, "bottom": 0.16, "sides": 6},
				{"shape": "cone", "from": _v(knee), "to": _v(foot), "material": "body", "radius": 0.13, "sides": 6},
				{"shape": "cone", "from": _v(foot + Vector3(0, 0.3, 0)), "to": _v(foot), "material": "iron", "radius": 0.08, "sides": 5}]:
				piece.merge({"name": "leg", "joint": hip})
				parts.append(piece)
	## Its left claw (+x) is the pick, raised: the arm turns from the shoulder (`arm_l`), the pick
	## swings from the fist (`pick`).
	var shoulder_l := [0.95, 0.95, 0.7]
	parts.append({"shape": "cylinder", "from": shoulder_l, "to": [1.45, 1.25, 1.3], "material": "body", "top": 0.11, "bottom": 0.15, "sides": 6, "name": "arm_l", "joint": shoulder_l})
	parts.append({"shape": "rock", "at": [1.48, 1.26, 1.34], "scale": 0.17, "material": "body", "jitter": 0.1, "seed": 93, "name": "arm_l", "joint": shoulder_l})
	parts.append_array(_pick(Vector3(1.48, 1.2, 1.32), Vector3(1.7, 2.25, 1.75), Vector3.BACK, 1.05, {"joint": [1.45, 1.25, 1.3], "motion": "swing", "phase": 0.6, "name": "pick"}))
	## Its right claw (-x) is an iron hook (`arm_r`), holding the lantern out.
	var shoulder_r := [-0.95, 0.95, 0.7]
	parts.append({"shape": "cylinder", "from": shoulder_r, "to": [-1.45, 1.3, 1.3], "material": "body", "top": 0.11, "bottom": 0.15, "sides": 6, "name": "arm_r", "joint": shoulder_r})
	parts.append({"shape": "cone", "from": [-1.45, 1.3, 1.3], "to": [-1.75, 1.6, 1.75], "material": "iron", "radius": 0.11, "sides": 5, "name": "arm_r", "joint": shoulder_r})
	parts.append({"shape": "cone", "from": [-1.45, 1.3, 1.3], "to": [-1.4, 1.6, 1.8], "material": "iron", "radius": 0.09, "sides": 5, "name": "arm_r", "joint": shoulder_r})
	parts.append_array(_lantern(Vector3(-1.6, 1.6, 1.78), 1.3, 1.4))
	parts.append_array(_amber([[[0.9, 1.3, -0.6], [1.3, 1.85, -0.9], 0.1], [[-0.95, 1.3, -0.5], [-1.4, 1.75, -0.75], 0.09], [[0.3, 1.25, -0.95], [0.5, 1.75, -1.4], 0.09], [[-0.4, 1.2, -0.95], [-0.6, 1.6, -1.35], 0.08]]))
	parts.append_array(_rubble([[[0.6, 0.08, -0.4], 0.2], [[-0.7, 0.08, 0.2], 0.18], [[0.1, 0.06, 1.4], 0.14]]))
	return parts

static func _hard_hat(base: Vector3, r: float, extra: Dictionary = {}) -> Array:
	## An iron hard hat sat with its rim at `base`: a six-sided dome on a hex brim, and the
	## lamp box on its front with its gem lit.
	var out: Array = [
		{"shape": "cap", "at": _v(base), "material": "iron", "radius": r, "height": r * 0.78, "sides": 6, "seed": 44},
		{"shape": "cylinder", "at": _v(base + Vector3(0, 0.03, r * 0.08)), "rot": [0, 30, 0], "material": "iron", "top": r * 1.22, "bottom": r * 1.22, "height": 0.045, "sides": 6},
		{"shape": "box", "at": _v(base + Vector3(0, r * 0.38, r * 0.84)), "material": "iron", "size": [r * 0.36, r * 0.34, r * 0.5]},
		_eye(_v(base + Vector3(0, r * 0.4, r * 1.14)), r * 0.17)]
	for part in out:
		part.merge(extra)
	return out

static func _lantern(hang: Vector3, s: float, phase: float) -> Array:
	## A miner's `lantern` hung from `hang` on a short chain, swinging from there as one piece
	## (its lit glass too, so it never parts from its frame).
	var out: Array = [
		{"shape": "cylinder", "from": _v(hang), "to": _v(hang - Vector3(0, 0.14 * s, 0)), "material": "iron", "top": 0.02 * s, "bottom": 0.02 * s, "sides": 4},
		{"shape": "cone", "at": _v(hang - Vector3(0, 0.2 * s, 0)), "material": "iron", "radius": 0.14 * s, "height": 0.11 * s, "sides": 6},
		{"shape": "cylinder", "at": _v(hang - Vector3(0, 0.35 * s, 0)), "material": "core", "top": 0.095 * s, "bottom": 0.095 * s, "height": 0.22 * s, "sides": 6},
		{"shape": "cylinder", "at": _v(hang - Vector3(0, 0.48 * s, 0)), "material": "iron", "top": 0.13 * s, "bottom": 0.13 * s, "height": 0.05 * s, "sides": 6}]
	for part in out:
		part.merge({"joint": _v(hang), "phase": phase, "motion": "swing", "name": "lantern"})
	return out

static func _pick(grip: Vector3, head_at: Vector3, across: Vector3, s: float, extra: Dictionary = {}) -> Array:
	## A miner's pick: an iron haft from `grip` to `head_at`, the head's bar across it, a long
	## point one way and a flat blade the other, both leaning back down the haft.
	var haft: Vector3 = (head_at - grip).normalized()
	var side: Vector3 = (across - haft * across.dot(haft)).normalized()
	var point: Vector3 = (side - haft * 0.35).normalized()
	var blade: Vector3 = (-side - haft * 0.35).normalized()
	var out: Array = [
		{"shape": "cylinder", "from": _v(grip), "to": _v(head_at), "material": "iron", "top": 0.06 * s, "bottom": 0.07 * s, "sides": 6},
		{"shape": "cylinder", "from": _v(head_at - haft * 0.13 * s), "to": _v(head_at + haft * 0.15 * s), "material": "iron", "top": 0.12 * s, "bottom": 0.12 * s, "sides": 6},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at + point * 0.85 * s), "material": "iron", "radius": 0.12 * s, "sides": 5},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at + blade * 0.6 * s), "material": "iron", "radius": 0.11 * s, "sides": 4}]
	for part in out:
		part.merge(extra)
	return out

static func _amber(specs: Array, material: String = "core") -> Array:
	## Amber crystals grown out of a body, swaying: each [from, to, radius].
	var out: Array = []
	for spec in specs:
		out.append({"shape": "crystal", "from": spec[0], "to": spec[1], "material": material, "motion": "crystal", "radius": spec[2]})
	return out

## ---- The Regent ---------------------------------------------------------------------------

static func _regent() -> Array:
	## A tall queen of cut glass: a six-sided gown, a high collar of crystal fanned behind her
	## head, a crown, and a mirror where a face should be. Her hands reach for two great
	## mirrors floating at her sides; little shards of glass circle her.
	var neck := [0, 2.3, 0]
	var parts: Array = []
	for side in [-1.0, 1.0]:
		## The mirrors first, since they are what moves: each bobs on its own beat.
		var centre := Vector3(side * 1.36, 1.95, 0.22)
		var facing := Vector3(-side * 0.3, 0, 1).normalized()
		var across := Vector3.UP.cross(facing)
		var turned: float = rad_to_deg(atan2(facing.x, facing.z))
		for mirror in [
			## Two strokes of light across the dark glass, the way a mirror is drawn.
			{"shape": "box", "at": _v(centre + facing * 0.04 - across * 0.1 + Vector3(0, 0.08, 0)), "rot": [0, turned, -40], "material": "accent", "size": [0.05, 0.42, 0.01]},
			{"shape": "box", "at": _v(centre + facing * 0.04 + across * 0.06 + Vector3(0, 0.02, 0)), "rot": [0, turned, -40], "material": "accent", "size": [0.035, 0.2, 0.01]},
			{"shape": "cylinder", "from": _v(centre - facing * 0.025), "to": _v(centre + facing * 0.025), "material": "iron", "top": 0.42, "bottom": 0.42, "sides": 6},
			{"shape": "torus", "at": _v(centre), "aim": _v(facing), "material": "accent", "inner": 0.4, "outer": 0.48, "rings": 6, "segments": 4},
			{"shape": "crystal", "from": _v(centre + Vector3(0, 0.44, 0)), "to": _v(centre + Vector3(0, 0.74, 0)), "material": "body", "radius": 0.055},
			{"shape": "crystal", "from": _v(centre - Vector3(0, 0.44, 0)), "to": _v(centre - Vector3(0, 0.66, 0)), "material": "body", "radius": 0.05}]:
			mirror.merge({"joint": _v(centre), "motion": "bob", "phase": 0.0 if side < 0.0 else 1.7})
			parts.append(mirror)
	parts.append_array([
		{"shape": "cylinder", "from": [0, 0.0, 0], "to": [0, 1.55, 0], "material": "body", "top": 0.3, "bottom": 0.84, "sides": 6},
		{"shape": "cylinder", "from": [0, 1.5, 0], "to": [0, 2.22, 0], "material": "body", "top": 0.44, "bottom": 0.27, "sides": 6},
		{"shape": "torus", "at": [0, 1.52, 0], "material": "core", "inner": 0.27, "outer": 0.35, "rings": 6, "segments": 4},
		{"shape": "sphere", "at": [0, 1.98, 0.4], "scale": [0.11, 0.15, 0.08], "material": "core", "motion": "core", "radius": 1.0, "segments": 4, "rings": 2},
		{"shape": "cylinder", "from": [0, 2.2, 0], "to": [0, 2.42, 0], "material": "body", "top": 0.08, "bottom": 0.1, "sides": 6}])
	## Crystals at the corners of the hem.
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0 + PI / 6.0
		var out := Vector3(cos(angle), 0, sin(angle))
		parts.append({"shape": "crystal", "from": _v(out * 0.66), "to": _v(out * 0.98 + Vector3(0, 0.5, 0)), "material": "body", "radius": 0.08})
	## A high collar fanned behind the head, longest in the middle.
	for k in range(7):
		var lean: float = deg_to_rad(-66.0 + 22.0 * float(k))
		var ray := Vector3(sin(lean), cos(lean), -0.28).normalized()
		var base := Vector3(0, 2.18, -0.2) + ray * 0.12
		parts.append({"shape": "crystal", "from": _v(base), "to": _v(base + ray * (0.5 + 0.3 * cos(lean))), "material": "body", "motion": "crystal", "phase": float(k) * 0.7, "radius": 0.045})
	## Arms out to the mirrors, crystal shoulders.
	for side in [-1.0, 1.0]:
		parts.append_array([
			{"shape": "crystal", "from": [side * 0.36, 2.14, 0], "to": [side * 0.74, 2.44, -0.04], "material": "body", "radius": 0.09},
			{"shape": "cylinder", "from": [side * 0.4, 2.1, 0.02], "to": [side * 0.68, 1.84, 0.12], "material": "body", "top": 0.06, "bottom": 0.08, "sides": 6},
			{"shape": "cylinder", "from": [side * 0.68, 1.84, 0.12], "to": [side * 0.9, 1.98, 0.22], "material": "body", "top": 0.05, "bottom": 0.06, "sides": 6},
			{"shape": "crystal", "from": [side * 0.88, 1.98, 0.22], "to": [side * 1.04, 2.03, 0.25], "material": "accent", "radius": 0.05}])
	## The head: a cut gem with a mirror for a face, under a crown.
	var head: Array = [
		{"shape": "crystal", "from": [0, 2.6, 0], "to": [0, 2.86, 0], "material": "body", "radius": 0.17},
		{"shape": "crystal", "from": [0, 2.64, 0], "to": [0, 2.36, 0], "material": "body", "radius": 0.17},
		{"shape": "cylinder", "from": [0, 2.62, 0.14], "to": [0, 2.62, 0.19], "material": "accent", "top": 0.12, "bottom": 0.12, "sides": 8},
		{"shape": "torus", "at": [0, 2.76, 0], "material": "accent", "inner": 0.15, "outer": 0.2, "rings": 6, "segments": 4}]
	for k in range(5):
		var tilt: float = deg_to_rad(-44.0 + 22.0 * float(k))
		var rise := Vector3(sin(tilt) * 0.7, 1.0, 0).normalized()
		var at := Vector3(sin(tilt) * 0.16, 2.76, 0)
		head.append({"shape": "crystal", "from": _v(at), "to": _v(at + rise * (0.3 if k == 2 else 0.22)), "material": "accent", "radius": 0.04})
	for piece in head:
		piece.merge({"joint": neck, "motion": "block", "phase": 0.3})
		parts.append(piece)
	## Shards of glass circling her at their own heights.
	for spec in [[Vector3(1.0, 0.6, 0.2), 0.0], [Vector3(-0.9, 1.15, -0.4), 2.1], [Vector3(0.6, 2.7, -0.75), 4.2]]:
		parts.append({"shape": "crystal", "at": _v(spec[0]), "rot": [20, 0, 30], "material": "accent", "motion": "orbit", "phase": spec[1], "radius": 0.06, "height": 0.3})
	return parts

## ---- The Drill ----------------------------------------------------------------------------

static func _drill() -> Array:
	## A drilling worm-machine: linked hex drums of iron joined by plates in its own colour,
	## furnace slits glowing in their sides, heaving out of the floor in an arch and coming down
	## at the party with the great bit for a head, headlamps and stacks along its back.
	var points: Array = []
	for i in range(9):
		var t: float = float(i) / 8.0
		points.append(Vector3(sin(t * 3.2) * 0.35 - 0.1, sin(PI * t * 0.82) * 2.3 - 0.15, -1.7 + 2.75 * t))
	var parts: Array = []
	for i in range(8):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var r: float = lerpf(0.3, 0.5, float(i) / 7.0)
		var t: Vector3 = (p1 - p0).normalized()
		var up: Vector3 = (Vector3.UP - t * Vector3.UP.dot(t)).normalized()
		var mid: Vector3 = (p0 + p1) * 0.5
		## Segment i is one `body` piece turning about its middle: its drum and furnace slit
		## breathing together, the plate linking it to the next, and its stack if it has one.
		## The smoke (`smoke`) flickers on its own.
		var segment := {"name": "body", "joint": _v(mid)}
		parts.append(_merged({"shape": "cylinder", "from": _v(p0), "to": _v(p1), "material": "iron", "motion": "core", "phase": float(i) * 0.5, "top": r + 0.03, "bottom": r - 0.03, "sides": 6}, segment))
		parts.append(_flange(p1, t, r + 0.1, 0.1, "body", segment))
		if i > 0:
			parts.append(_merged({"shape": "box", "at": _v(mid + up * (r - 0.02)), "aim": _v(up), "material": "accent", "motion": "core", "phase": float(i) * 0.5, "size": [0.08, 0.06, 0.36]}, segment))
		if i in [2, 5]:
			parts.append(_merged({"shape": "cylinder", "from": _v(mid + up * r * 0.8), "to": _v(mid + up * (r + 0.42)), "material": "iron", "top": 0.08, "bottom": 0.1, "sides": 6}, segment))
			parts.append_array(_exhaust(mid + up * (r + 0.42), 0.8))
	## The great bit and its hub bore on their own axis (`drill`; no joint, or the spin would
	## turn about the wrong axis). The headlamps are its `head`.
	var head: Vector3 = points[8]
	var nose: Vector3 = (points[8] - points[7]).normalized()
	parts.append({"shape": "cylinder", "from": _v(head - nose * 0.1), "to": _v(head + nose * 0.3), "material": "body", "motion": "drill", "top": 0.52, "bottom": 0.56, "sides": 6, "name": "drill"})
	parts.append({"shape": "drill", "from": _v(head + nose * 0.3), "to": _v(head + nose * 1.9), "material": "accent", "motion": "drill", "radius": 0.6, "flutes": 3, "turns": 1.6, "name": "drill"})
	var across: Vector3 = nose.cross(Vector3.UP).normalized()
	var over: Vector3 = across.cross(nose).normalized()
	for side in [-1.0, 1.0]:
		parts.append({"shape": "cylinder", "from": _v(head + across * side * 0.45 + over * 0.3), "to": _v(head + across * side * 0.5 + over * 0.32 + nose * 0.16), "material": "iron", "top": 0.11, "bottom": 0.12, "sides": 6, "name": "head", "joint": _v(head)})
		parts.append(_merged(_eye(_v(head + across * side * 0.5 + over * 0.32 + nose * 0.18), 0.1), {"name": "head", "joint": _v(head)}))
	## Its tail end, going down into the floor behind.
	parts.append({"shape": "cylinder", "from": _v(points[0] - (points[1] - points[0]).normalized() * 0.3), "to": _v(points[0]), "material": "iron", "top": 0.26, "bottom": 0.22, "sides": 6, "name": "tail"})
	parts.append_array(_rubble([[[0.5, 0.08, -1.3], 0.3], [[-0.6, 0.1, -1.6], 0.26], [[0.9, 0.08, 1.1], 0.22], [[-0.7, 0.08, 1.3], 0.2]]))
	return parts

static func _flange(at: Vector3, axis: Vector3, r: float, wide: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## A hex plate across a drum: a boiler band, the joint between two segments of a machine.
	var half: Vector3 = axis.normalized() * wide * 0.5
	var part: Dictionary = {"shape": "cylinder", "from": _v(at - half), "to": _v(at + half), "material": material, "top": r, "bottom": r, "sides": 6}
	part.merge(extra)
	return part

static func _exhaust(top: Vector3, s: float) -> Array:
	## Three lumps of `smoke` lit from below rising off a stack, each bigger and fainter.
	var out: Array = []
	for k in range(3):
		out.append({"shape": "rock", "at": _v(top + Vector3(0.06 * float(k), 0.12 + 0.24 * float(k), -0.04 * float(k)) * s), "scale": (0.14 + 0.07 * float(k)) * s,
			"material": "core" if k == 0 else "iron", "motion": "flicker", "phase": float(k) * 1.3, "jitter": 0.3, "name": "smoke"})
	return out
