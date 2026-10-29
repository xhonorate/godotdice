extends RefCounted
## Recipes for tools/creature_bake.gd: the Furnace (see the bake's header for the format).
##
## Every model here is the owner's pick from the creature model review (Oct 2026), moved in
## from build/options/recipes/<batch>.gd under its plain key. A recipe's "seed" names the
## review recipe it came from, so its unseeded rocks, crystals and slabs are cut facet for
## facet as they were picked. The facets come from one random stream in part order: do not
## reorder, add or drop parts that draw from it (rocks, crystals, slabs, spikes, columns, caps,
## shards). A quiet marker (a sphere, box, cone, cylinder or prism with no "seed") may sit
## anywhere.
##
## The parts an animation will move carry a "name" (their pivots become <Name>01, <Name>02,
## ...), and the pieces of one head, jaw, leg, wing, tail or tool share one "joint": the point
## they hinge on. build/options/part_roles/furnace.md lists every role and how it moves. The
## creatures face +z (the party) with y up; a creature's own left (`_l`) is +x.
##
## The look: low poly and angular, made of crystals and gems. Bodies, necks and tails are rows
## of cut stones, hoops are bands of boxes, eyes and embers are five-sided gems, fire is
## `accent` crystal that flickers, and drums are hex.

static func recipes() -> Dictionary:
	return {
		"FORGE_IMP": {"seed": "FORGE_IMP_A", "style": "low", "sway": 3.0, "tint": "c83a2a", "accent": "ffb03a", "anchor": 1.55, "shadow": 1.8, "ring": 0.95, "parts": _forge_imp()},
		"SALAMANDER": {"seed": "SALAMANDER_C", "style": "low", "sway": 2.4, "tint": "e8622a", "accent": "ffd06a", "anchor": 1.7, "shadow": 2.8, "ring": 1.3, "parts": _salamander()},
		"SLAG_HOUND": {"seed": "SLAG_HOUND_C", "style": "low", "sway": 2.4, "tint": "3a2a26", "accent": "ff7a2a", "anchor": 1.7, "shadow": 2.6, "ring": 1.2, "parts": _slag_hound()},
		"EMBER_CRAWLER": {"seed": "EMBER_CRAWLER_A", "style": "low", "sway": 1.8, "tint": "5a2a1a", "accent": "ff8a2a", "anchor": 1.0, "shadow": 3.2, "ring": 1.5, "parts": _ember_crawler()},
		"THE_SMELTER": {"seed": "THE_SMELTER_C", "style": "tower", "sway": 0.5, "tint": "4a3a36", "accent": "ff8a2a", "anchor": 3.8, "warden": true, "shadow": 4.0, "ring": 1.9, "parts": _smelter()},
		"THE_ANVIL_KNIGHT": {"seed": "THE_ANVIL_KNIGHT_C", "style": "tower", "sway": 0.45, "tint": "6a6e78", "accent": "ff5a3a", "anchor": 4.1, "warden": true, "shadow": 3.0, "ring": 1.5, "parts": _anvil_knight()},
		"THE_KILN_WYRM": {"seed": "THE_KILN_WYRM_A", "style": "wings", "sway": 0.8, "tint": "c8401a", "accent": "ffd06a", "anchor": 3.9, "warden": true, "shadow": 4.6, "ring": 2.2, "parts": _kiln_wyrm()}}

## ---- Forge Imp (review batch r3a, option A) -------------------------------------------------

static func _forge_imp() -> Array:
	## Stands on stubby clawed legs, an iron hammer slung over its shoulder, a fist on its hip,
	## a tail behind. Drawn with the hammer at +x and mirrored at the end: it rests on the imp's
	## own right shoulder (-x), the fist on its left hip.
	var a: Array = [
		_rock(Vector3(0, 0.38, -0.04), Vector3(0.21, 0.21, 0.18), "body", 0.12, 201, {"motion": "core"}),
		_gem(Vector3(0, 0.34, 0.1), Vector3(0.13, 0.12, 0.08), "core", {"motion": "core"})]
	_imp_head(a, Vector3(0, 0.88, 0.04), 4.0, 16.0, 0.3)
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.12, 0.28, -0.04)
		var knee := Vector3(side * 0.17, 0.17, 0.1)
		var foot := Vector3(side * 0.17, 0.03, -0.02)
		var leg := _role("leg", hip)
		a.append(_rod(hip, knee, 0.07, 0.055, "body", leg, 5))
		a.append(_rod(knee, foot, 0.055, 0.04, "body", leg, 5))
		_toes(a, foot, Vector3(side * 0.25, 0, 1), 2, 0.13, 0.26, leg)
	var fist := _role("arm_l", Vector3(-0.17, 0.48, 0.0))
	a.append(_rod(Vector3(-0.17, 0.48, 0.0), Vector3(-0.3, 0.38, 0.04), 0.045, 0.04, "body", fist, 5))
	a.append(_rod(Vector3(-0.3, 0.38, 0.04), Vector3(-0.2, 0.3, 0.08), 0.04, 0.035, "body", fist, 5))
	## The hammer arm and the hammer on its shoulder swing from one shoulder joint.
	var shoulder := Vector3(0.17, 0.48, 0.02)
	a.append_array(_hang([
		_rod(shoulder, Vector3(0.33, 0.4, 0.14), 0.045, 0.04, "body", {}, 5),
		_rod(Vector3(0.33, 0.4, 0.14), Vector3(0.36, 0.52, 0.2), 0.04, 0.035, "body", {}, 5),
		_rock(Vector3(0.36, 0.53, 0.2), 0.06, "body", 0.12, 231)], shoulder, "bob", 0.5, "arm_r"))
	var head_a := Vector3(0.6, 1.02, -0.38)
	var haft_a: Vector3 = (head_a - Vector3(0.34, 0.42, 0.24)).normalized()
	var hammer: Array = []
	_hammer(hammer, Vector3(0.34, 0.42, 0.24), head_a, haft_a.cross(Vector3.UP), 0.03, 0.1, 0.42)
	a.append_array(_hang(hammer, shoulder, "bob", 0.5, "hammer"))
	a.append_array(_hang([
		_rod(Vector3(0, 0.3, -0.18), Vector3(0.08, 0.16, -0.42), 0.04, 0.025, "body", {}, 5),
		_rod(Vector3(0.08, 0.16, -0.42), Vector3(0.2, 0.24, -0.58), 0.025, 0.018, "body", {}, 5),
		_cone(Vector3(0.18, 0.22, -0.56), Vector3(0.28, 0.34, -0.66), 0.05, "accent", {}, 4)], Vector3(0, 0.3, -0.18), "swing", 1.1, "tail"))
	a.append(_eye(Vector3(0.36, 0.8, 0.3), 0.03, "accent", {"motion": "bob", "phase": 0.7, "name": "ember"}))
	a.append(_eye(Vector3(-0.34, 0.66, 0.24), 0.025, "accent", {"motion": "bob", "phase": 1.9, "name": "ember"}))
	return _mirror(a)

static func _imp_head(out: Array, h: Vector3, pitch_deg: float, open_deg: float, phase: float) -> void:
	## The imp's great head: a cut-stone skull, a glowing mouth, a slab of a jaw hanging open on
	## iron teeth, gem eyes under heavy brows, iron horns and a crown of flame, turning from the
	## neck. `h` is the skull's middle; `pitch_deg` tips it up, `open_deg` drops the jaw. The jaw
	## and its two fangs hinge on their own; a `mouth` marker sits between the teeth.
	var basis := Basis(Vector3.RIGHT, deg_to_rad(-pitch_deg))
	var p := func(x: float, y: float, z: float) -> Vector3: return h + basis * Vector3(x, y, z)
	var d: float = deg_to_rad(open_deg)
	var hinge := Vector3(0, -0.2, -0.16)
	var jaw_dir := Vector3(0, -sin(d), cos(d))
	var jaw_up := Vector3(0, cos(d), sin(d))
	var jaw := _role("jaw", h + basis * hinge)
	var pieces: Array = [
		_rock(h, Vector3(0.34, 0.3, 0.34), "body", 0.08, 212, {"rot": _rot(basis)}),
		_box(p.call(0, -0.14, 0.16), Vector3(0.44, 0.1, 0.42), "core", {"rot": _rot(basis * _euler(8, 0, 0))}),
		_slab(h + basis * (hinge + jaw_dir * 0.28), Vector3(0.5, 0.12, 0.56), "body", _m({"rot": _rot(basis * Basis(Vector3.RIGHT, d))}, jaw)),
		_eye(p.call(0.15, 0.1, 0.28), 0.065), _eye(p.call(-0.15, 0.1, 0.28), 0.065),
		_slab(p.call(0.16, 0.18, 0.26), Vector3(0.16, 0.04, 0.1), "body", {"rot": _rot(basis * _euler(20, 0, -15))}),
		_slab(p.call(-0.16, 0.18, 0.26), Vector3(0.16, 0.04, 0.1), "body", {"rot": _rot(basis * _euler(20, 0, 15))}),
		_cone(p.call(0.18, 0.2, -0.06), p.call(0.44, 0.48, -0.28), 0.06, "iron"),
		_cone(p.call(-0.18, 0.2, -0.06), p.call(-0.44, 0.48, -0.28), 0.06, "iron"),
		_flame(p.call(0.02, 0.26, -0.02), p.call(0.05, 0.44, -0.06), 0.03, 0.0),
		_flame(p.call(-0.06, 0.24, -0.1), p.call(-0.1, 0.4, -0.16), 0.025, 1.5)]
	for x in [-0.14, 0.0, 0.14]:
		pieces.append(_cone(p.call(x, -0.08, 0.28), p.call(x, -0.17, 0.29), 0.035, "iron", {}, 4))
	var front: Vector3 = hinge + jaw_dir * 0.48 + jaw_up * 0.06
	for x in [-0.12, 0.12]:
		pieces.append(_cone(h + basis * (front + Vector3(x, 0, 0)), h + basis * (front + Vector3(x, 0, 0) + jaw_up * 0.09), 0.035, "iron", jaw, 4))
	pieces.append(_marker(p.call(0, -0.22, 0.36), "mouth"))
	out.append_array(_head(pieces, p.call(0, -0.12, -0.06), phase))

static func _hammer(out: Array, grip: Vector3, head_at: Vector3, across: Vector3, haft_r: float, head_r: float, head_len: float, extra: Dictionary = {}) -> void:
	## The imp's iron hammer: a haft from the grip to the head, a pommel, the hex head lying
	## across it with a collar, its striking face glowing hot.
	var a: Vector3 = across.normalized()
	var along: Vector3 = (head_at - grip).normalized()
	for piece in [
		_rod(grip - along * 0.05, head_at, haft_r * 1.1, haft_r, "iron"),
		_rock(grip - along * 0.06, haft_r * 1.8, "iron", 0.1, 230),
		_rod(head_at - a * head_len * 0.5, head_at + a * head_len * 0.5, head_r, head_r, "iron"),
		_rod(head_at - a * head_len * 0.12, head_at + a * head_len * 0.12, head_r * 1.18, head_r * 1.18, "body"),
		_rod(head_at + a * head_len * 0.5, head_at + a * (head_len * 0.5 + 0.025), head_r * 0.86, head_r * 0.86, "accent", {"motion": "core"})]:
		piece.merge(extra, true)
		out.append(piece)

static func _mirror(parts: Array) -> Array:
	## The whole model flipped left for right (x to -x), joints and turns with it.
	for part in parts:
		for key in ["at", "from", "to", "joint", "aim", "offset"]:
			if part.has(key):
				var p: Array = part[key]
				part[key] = [-float(p[0]), p[1], p[2]]
		for key in ["rot", "mesh_rot"]:
			if part.has(key):
				var r: Array = part[key]
				part[key] = [r[0], -float(r[1]), -float(r[2])]
	return parts

## ---- Salamander (review batch furnace, option C) ---------------------------------------------

static func _salamander() -> Array:
	## The ember-spitter: reared up with its forefeet on a slag rock, jaws wide with embers
	## drifting out, a mane of flames down the whole spine, a glowing chest, a flame on the tail tip.
	var neck_c := [0, 0.9, 0.46]
	## The mouth marker leads the list, so the scene's first pivot moves (tests/test_creatures.gd).
	var c: Array = _head([_marker(Vector3(0, 0.86, 0.92), "mouth")], neck_c, 0.3)
	c.append({"shape": "rock", "at": [0, 0.24, 0.6], "scale": [0.46, 0.25, 0.4], "material": "iron", "jitter": 0.22, "seed": 227})
	_rocks(c, [Vector3(0, 0.3, -0.6), Vector3(0, 0.42, -0.36), Vector3(0, 0.54, -0.12), Vector3(0, 0.66, 0.12), Vector3(0, 0.78, 0.36)],
		[0.2, 0.24, 0.25, 0.24, 0.2], "body", 259, {"motion": "core"}, 0.1, 0.9)
	c.append({"shape": "slab", "at": [0, 0.4, -0.03], "aim": [0, -0.89, 0.45], "material": "core", "motion": "core", "phase": 0.5, "size": [0.3, 0.1, 0.8], "jitter": 0.03, "name": "chest"})
	var jaw := _role("jaw", Vector3(0, 0.9, 0.56))
	c.append_array(_head([
		{"shape": "rock", "at": [0, 1.0, 0.56], "scale": [0.2, 0.15, 0.22], "material": "body", "jitter": 0.08, "seed": 264},
		_snout(Vector3(0, 1.04, 0.76), Vector3(0, 0.08, 0.28), 0.2, 0.3, 0.13),
		_m(_jaw(Vector3(0, 0.9, 0.56), 0.38, 0.2, 0.06, 40.0), jaw),
		_glow_gem([0, 0.92, 0.68], [0.09, 0.08, 0.1], "core"),
		_eye([0.13, 1.08, 0.6], 0.05), _eye([-0.13, 1.08, 0.6], 0.05)], neck_c, 0.3))
	## Its fangs turn with the head and the jaw they sit in.
	var fangs: Array = []
	_teeth(fangs, 1.02, 0.86, [-0.06, 0.06], 0.06, true)
	_teeth(fangs, 0.78, 0.8, [-0.05, 0.05], 0.06, false, "iron", jaw)
	c.append_array(_head(fangs, neck_c, 0.3))
	for spec in [[[0.05, 1.06, 1.06], 0.05, 0.0], [[-0.1, 1.18, 1.22], 0.04, 1.2], [[0.16, 0.98, 1.3], 0.035, 2.4], [[0.0, 1.3, 1.1], 0.03, 3.4]]:
		c.append(_m(_ember(spec[0], spec[1], spec[2]), {"name": "ember"}))
	for i in range(7):
		var t: float = float(i) / 6.0
		var at: Vector3 = Vector3(0, 0.5, -0.5).lerp(Vector3(0, 0.98, 0.34), t) + Vector3(0, 0.04, 0)
		var tall: float = 0.28 + 0.16 * sin(PI * (t * 0.8 + 0.1))
		c.append(_m(_flame(_v(at), _v(at + Vector3(0.04 * (1.0 if i % 2 == 0 else -1.0), tall, -0.14)), 0.05 + 0.02 * sin(PI * t), float(i) * 0.9), {"name": "mane"}))
	var root_c := Vector3(0, 0.3, -0.7)
	var tail := {"motion": "swing", "phase": 0.9, "joint": _v(root_c), "name": "tail"}
	_rocks(c, [root_c, Vector3(0.04, 0.28, -0.92), Vector3(0.1, 0.26, -1.15), Vector3(0.22, 0.33, -1.28), Vector3(0.36, 0.42, -1.4)],
		[0.1, 0.09, 0.075, 0.06, 0.045], "body", 265, tail, 0.1, 0.9)
	c.append(_m({"shape": "crystal", "from": [0.36, 0.42, -1.4], "to": [0.52, 0.74, -1.5], "material": "accent", "radius": 0.06, "sides": 5}, tail))
	for side in [-1.0, 1.0]:
		var fore := Vector3(side * 0.32, 0.46, 0.66)
		var hind := Vector3(side * 0.54, 0.03, -0.34)
		var shoulder := Vector3(side * 0.2, 0.66, 0.3)
		var hip := Vector3(side * 0.2, 0.3, -0.46)
		_limb(c, shoulder, Vector3(side * 0.4, 0.62, 0.5), fore, 0.06, "body", _role("leg", shoulder))
		_limb(c, hip, Vector3(side * 0.46, 0.38, -0.52), hind, 0.06, "body", _role("leg", hip))
		_toes(c, fore, Vector3(side * 0.4, 0, 1), 3, 0.13, 0.24, _role("leg", shoulder))
		_toes(c, hind, Vector3(side * 0.5, 0, 1), 3, 0.14, 0.24, _role("leg", hip))
	return c

## ---- Slag Hound (review batch furnace, option C) ---------------------------------------------

static func _slag_hound() -> Array:
	## The brute: a heavy hunched hound with shoulders above its hips, a ridge of slag shards down
	## the spine, a riveted iron collar with hot studs and a broken chain trailing, jaws wide and
	## drooling fire.
	var neck := _role("neck", Vector3(0, 0.92, 0.6))
	var c: Array = [
		{"shape": "rock", "at": [0, 0.82, -0.1], "rot": [100, 0, 0], "scale": [0.28, 0.5, 0.28], "material": "core", "motion": "core", "jitter": 0.06, "seed": 250},
		{"shape": "rock", "at": [0, 1.0, 0.3], "scale": [0.5, 0.42, 0.44], "material": "body", "jitter": 0.16, "seed": 251},
		{"shape": "rock", "at": [0, 0.72, -0.56], "scale": [0.34, 0.3, 0.38], "material": "body", "jitter": 0.16, "seed": 252},
		{"shape": "rock", "at": [0.3, 0.74, -0.1], "scale": [0.16, 0.2, 0.3], "material": "body", "jitter": 0.14, "seed": 253},
		{"shape": "rock", "at": [-0.3, 0.74, -0.1], "scale": [0.16, 0.2, 0.3], "material": "body", "jitter": 0.14, "seed": 254},
		_m({"shape": "cylinder", "from": [0, 0.92, 0.6], "to": [0, 0.78, 0.9], "material": "body", "top": 0.16, "bottom": 0.2, "sides": 6}, neck)]
	_hound_head(c, Vector3(0, 0.78, 0.9), 38.0, 0.4, false)
	_band(c, Vector3(0, 0.86, 0.72), _aim_rot(Vector3(0, -0.14, 0.3)), 0.24, 7, 0.12, 0.08, "iron", neck, 0.0, "box", 0.028)
	_chain(c, [Vector3(0.24, 0.78, 0.8), Vector3(0.36, 0.6, 0.86), Vector3(0.46, 0.4, 0.92), Vector3(0.54, 0.2, 0.98), Vector3(0.62, 0.04, 1.08)], 0.15, "iron", _role("chain", Vector3(0.24, 0.78, 0.8)))
	for i in range(5):
		var z: float = 0.46 - 0.26 * float(i)
		var y: float = 1.38 - 0.1 * float(i)
		c.append({"shape": "crystal", "from": [0, y - 0.1, z], "to": [0.04 * (1.0 if i % 2 == 0 else -1.0), y + 0.2 - 0.03 * float(i), z - 0.08], "material": "accent", "motion": "crystal", "phase": float(i) * 0.7, "radius": 0.045, "sides": 5, "name": "crest"})
	for side in [-1.0, 1.0]:
		var front := Vector3(side * 0.34, 0.03, 0.36)
		var back := Vector3(side * 0.26, 0.03, -0.5)
		var shoulder := Vector3(side * 0.3, 0.78, 0.36)
		var hip := Vector3(side * 0.22, 0.56, -0.54)
		_limb(c, shoulder, Vector3(side * 0.36, 0.42, 0.4), front, 0.09, "body", _role("leg", shoulder))
		_limb(c, hip, Vector3(side * 0.28, 0.34, -0.7), back, 0.065, "body", _role("leg", hip))
		_paw(c, front, 0.09, 9 + int(side > 0.0), _role("leg", shoulder))
		_paw(c, back, 0.07, 11 + int(side > 0.0), _role("leg", hip))
	c.append(_m(_drip([0.08, 0.62, 1.18], [0.1, 0.3, 1.2], 0.025, 2.0), {"name": "drool"}))
	c.append(_puddle([0.1, 0.03, 1.22], 0.12, 2.0, 0.12))
	var tail_c := Vector3(0, 0.76, -0.84)
	_rocks(c, [tail_c, Vector3(-0.03, 0.86, -0.97), Vector3(-0.06, 0.96, -1.1)], [0.045, 0.04, 0.03], "body", 255, {"motion": "swing", "phase": 0.6, "joint": _v(tail_c), "name": "tail"}, 0.12, 0.9)
	c.append_array(_head([_marker(Vector3(0, 0.5, 1.38), "mouth")], Vector3(0, 0.78, 0.9), 0.4))
	return c

static func _hound_head(out: Array, neck_top: Vector3, open_deg: float, phase: float, ears_back: bool = true) -> void:
	## A hound's head looking toward +z from the top of its neck: a cut-stone skull, a blocky
	## muzzle, a lower jaw open on a glowing mouth, dark fangs, ears and gem eyes, turning from
	## the neck. The jaw and its two lower fangs hinge on their own.
	var n: Vector3 = neck_top
	var jaw := _role("jaw", n + Vector3(0, -0.15, 0.12))
	var pieces: Array = [
		{"shape": "rock", "at": _v(n + Vector3(0, -0.02, 0.1)), "scale": [0.19, 0.17, 0.22], "material": "body", "jitter": 0.1, "seed": 239},
		_snout(n + Vector3(0, -0.08, 0.35), Vector3(0, -0.04, 0.34), 0.17, 0.36, 0.14),
		_m(_jaw(n + Vector3(0, -0.15, 0.12), 0.42, 0.16, 0.06, open_deg), jaw),
		{"shape": "box", "at": _v(n + Vector3(0, -0.14, 0.34)), "rot": [open_deg * 0.4, 0, 0], "material": "core", "motion": "core", "size": [0.13, 0.05, 0.3]},
		_eye(_v(n + Vector3(0.09, 0.05, 0.22)), 0.04), _eye(_v(n + Vector3(-0.09, 0.05, 0.22)), 0.04)]
	for x in [-0.06, 0.06]:
		pieces.append({"shape": "cone", "from": _v(n + Vector3(x, -0.1, 0.46)), "to": _v(n + Vector3(x, -0.18, 0.47)), "material": "iron", "radius": 0.025, "sides": 4})
	var drop: float = deg_to_rad(open_deg)
	for x in [-0.05, 0.05]:
		var on_jaw: Vector3 = n + Vector3(0, -0.15, 0.12) + Vector3(0, -sin(drop), cos(drop)) * 0.36 + Vector3(0, 0.03, 0)
		pieces.append(_m({"shape": "cone", "from": _v(on_jaw + Vector3(x, 0, 0)), "to": _v(on_jaw + Vector3(x, 0.08, -0.01)), "material": "iron", "radius": 0.022, "sides": 4}, jaw))
	for side in [-1.0, 1.0]:
		var tip: Vector3 = n + (Vector3(side * 0.2, 0.26, -0.1) if ears_back else Vector3(side * 0.18, 0.3, 0.04))
		pieces.append({"shape": "cone", "from": _v(n + Vector3(side * 0.1, 0.1, 0.04)), "to": _v(tip), "material": "body", "radius": 0.05, "sides": 4})
	out.append_array(_head(pieces, n, phase))

## ---- Ember Crawler (review batch furnace, option A) ------------------------------------------

static func _ember_crawler() -> Array:
	## The centipede on the floor: nine plates winding in an S with an ember glowing between every
	## pair, eighteen pointed legs, the front raised with pincers open and antennae out.
	var path_a: Array = []
	for i in range(9):
		var t: float = float(i) / 8.0
		var lift: float = maxf(0.0, 0.3 - t) / 0.3
		path_a.append(Vector3(sin(t * TAU * 1.05) * 0.36, 0.22 + 0.5 * lift * lift, 1.1 - 2.3 * t))
	var a: Array = []
	_crawler_body(a, path_a, Vector3(0.27, 0.16, 0.24), 0.52, 261, 3)
	_crawler_head(a, path_a[0] + Vector3(0, 0.02, 0.12), Vector3(0.1, -0.2, 1.0), 0.46, 0.3)
	var tail: Vector3 = path_a[8]
	for side in [-1.0, 1.0]:
		a.append({"shape": "cone", "from": _v(tail + Vector3(side * 0.06, 0.0, -0.1)), "to": _v(tail + Vector3(side * 0.22, 0.06, -0.46)), "material": "body", "radius": 0.03, "sides": 4, "name": "tail", "joint": _v(tail)})
	return a

static func _crawler_body(out: Array, path: Array, plate: Vector3, leg_len: float, seed_base: int, neck: int) -> void:
	## A centipede along `path`: a plate on every point turned to the path, an ember gem glowing
	## in each gap and a pair of pointed legs on every plate, each leg swinging from its own hip.
	## The first `neck` plates, each with the gem behind it, are the `neck` that rears: each one
	## hinges at its rear knuckle (that gem), so the front can curl up plate by plate.
	var n: int = path.size()
	for i in range(n):
		var p: Vector3 = path[i]
		var ahead: Vector3 = path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var flat: Vector3 = Vector3(ahead.x, 0, ahead.z)
		var yaw: float = rad_to_deg(atan2(ahead.x, ahead.z))
		var pitch: float = -rad_to_deg(atan2(ahead.y, flat.length()))
		var segment := {"shape": "rock", "at": _v(p), "rot": [pitch, yaw, 0], "scale": _v(plate), "material": "body", "motion": "core", "phase": float(i) * 0.6, "jitter": 0.1, "seed": seed_base + i}
		out.append(segment)
		if i < n - 1:
			var mid: Vector3 = (p + path[i + 1]) * 0.5 - Vector3(0, plate.y * 0.15, 0)
			var gem := _glow_gem(_v(mid), plate.y * 0.9, "core", {"phase": float(i) * 0.6 + 0.4})
			out.append(gem)
			if i < neck:
				segment.merge(_role("neck", mid))
				gem.merge(_role("neck", mid))
		var heading: Vector3 = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
		var right: Vector3 = Vector3(heading.z, 0, -heading.x)
		for side in [-1.0, 1.0]:
			var hip: Vector3 = p + right * side * plate.x * 0.7 - Vector3(0, plate.y * 0.3, 0)
			var drop: float = minf(hip.y - 0.04, leg_len * 0.8)
			var foot: Vector3 = hip + right * side * sqrt(maxf(leg_len * leg_len - drop * drop, 0.01)) + heading * 0.1 - Vector3(0, drop, 0)
			out.append(_m({"shape": "spike", "from": _v(hip), "to": _v(foot), "material": "body", "motion": "swing", "phase": float(i) * 1.3 + (0.0 if side > 0.0 else 1.6), "sides": 4, "radius": 0.038, "lean": 0.0}, _role("leg", hip)))

static func _crawler_head(out: Array, at: Vector3, forward: Vector3, scale: float, phase: float) -> void:
	## A head with pincers, eyes and antennae looking along `forward`, turning from its neck at
	## `at`. Each pincer (`claw_l` on its own left, +x, and `claw_r`) and each antenna pivots at
	## its root; a `mouth` marker sits between the pincers, where the spit leaves.
	var f: Vector3 = forward.normalized()
	var right: Vector3 = Vector3.UP.cross(f).normalized()
	var up: Vector3 = f.cross(right).normalized()
	var pieces: Array = [
		{"shape": "rock", "at": _v(at + f * scale * 0.4), "aim": _v(f), "scale": [scale * 0.42, scale * 0.5, scale * 0.3], "material": "body", "jitter": 0.1, "seed": 260},
		_eye(_v(at + f * scale * 0.72 + right * scale * 0.22 + up * scale * 0.16), scale * 0.09), _eye(_v(at + f * scale * 0.72 - right * scale * 0.22 + up * scale * 0.16), scale * 0.09)]
	for side in [-1.0, 1.0]:
		var root: Vector3 = at + f * scale * 0.8 + right * side * scale * 0.24 - up * scale * 0.1
		pieces.append(_m({"shape": "cone", "from": _v(root), "to": _v(root + f * scale * 0.42 - right * side * scale * 0.26), "material": "iron", "radius": scale * 0.07, "sides": 4}, _role("claw_l" if side > 0.0 else "claw_r", root)))
		var ant: Vector3 = at + f * scale * 0.7 + right * side * scale * 0.18 + up * scale * 0.24
		pieces.append(_m({"shape": "cylinder", "from": _v(ant), "to": _v(ant + f * scale * 0.5 + right * side * scale * 0.5 + up * scale * 0.4), "material": "body", "top": scale * 0.015, "bottom": scale * 0.025, "sides": 3}, _role("antenna", ant)))
	pieces.append(_marker(at + f * scale - up * scale * 0.1, "mouth"))
	out.append_array(_head(pieces, at, phase))

## ---- The Smelter (review batch r3b, option C) -----------------------------------------------

static func _smelter() -> Array:
	## The mountain: a tall ragged volcano of a shell with boulder crags up its slopes,
	## fire-crystal veins between them and lava running down, its crater roaring with flame;
	## elephant-pillar legs, a glowing iron crucible dangling from its beak.
	var shell := _role("shell", Vector3(0, 0.55, -0.1))
	var crater := _role("crater", Vector3(0, 2.72, -0.1))
	var lava := {"name": "lava"}
	var ember := {"name": "ember"}
	## The crater marker leads the list, so the scene's first pivot moves (tests/test_creatures.gd).
	var c: Array = [
		_marker(Vector3(0, 2.72, -0.1), "crater", _m({"motion": "core", "phase": 0.0}, crater)),
		_slab(Vector3(0, 0.55, -0.1), Vector3(2.0, 0.18, 2.1), "iron", shell),
		_drum(Vector3(0, 1.62, -0.1), 1.25, 0.42, 2.14, "body", shell),
		_drum(Vector3(0, 2.7, -0.1), 0.37, 0.37, 0.04, "accent", {"motion": "core", "name": "lava"}),
		_m(_flame(Vector3(0, 2.68, -0.1), Vector3(0.06, 3.5, -0.18), 0.2, 0.0), lava),
		_m(_flame(Vector3(0.18, 2.68, 0.0), Vector3(0.36, 3.18, 0.06), 0.1, 1.1), lava),
		_m(_flame(Vector3(-0.16, 2.68, -0.24), Vector3(-0.32, 3.2, -0.36), 0.11, 2.2), lava),
		_m(_flame(Vector3(-0.1, 2.68, 0.1), Vector3(-0.2, 3.05, 0.24), 0.07, 3.1), lava),
		_m(_ember(Vector3(0.2, 3.7, -0.1), 0.05, 0.0), ember), _m(_ember(Vector3(-0.2, 3.9, 0.0), 0.04, 1.4), ember), _m(_ember(Vector3(0.05, 4.05, -0.3), 0.035, 2.6), ember),
		_cone(Vector3(0, 0.6, -1.2), Vector3(0, 0.36, -1.6), 0.15, "body", _role("tail", Vector3(0, 0.6, -1.2)))]
	_ring(c, Vector3(0, 0.62, -0.1), 1.24, 8, 0.2, 0.2, "body", 10.0, 1.0, "slab", shell)
	var crags: Array = [[0.82, 1.16, 7, 0.36, 0.0], [1.42, 0.88, 6, 0.3, 25.0], [2.08, 0.6, 5, 0.22, 10.0]]
	var n_crag: int = 0
	for ring_spec in crags:
		for q in range(int(ring_spec[2])):
			var ang: float = deg_to_rad(float(ring_spec[4])) + TAU * float(q) / float(ring_spec[2])
			var dir := Vector3(sin(ang), 0, cos(ang))
			var s: float = ring_spec[3]
			c.append(_rock(Vector3(0, ring_spec[0], -0.1) + dir * float(ring_spec[1]), Vector3(s * 1.1, s, s), "body", 0.26, 4300 + n_crag, _m({"aim": _v(dir * 0.4 + Vector3(0, 1, 0))}, shell)))
			n_crag += 1
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0 + 0.2
		c.append(_rock(Vector3(sin(ang) * 0.42, 2.74, cos(ang) * 0.42 - 0.1), Vector3(0.15, 0.2 + 0.05 * float(i % 2), 0.15), "body", 0.3, 4340 + i, crater))
	for spec in [[35.0, 1.15, 0.0], [110.0, 1.75, 1.0], [200.0, 1.1, 2.0], [290.0, 1.7, 3.0], [-10.0, 1.95, 4.0]]:
		var ang: float = deg_to_rad(spec[0])
		var dir := Vector3(sin(ang), 0, cos(ang))
		var y: float = spec[1]
		var rad: float = 1.25 - (y - 0.55) / 2.14 * 0.83
		var at: Vector3 = Vector3(0, y, -0.1) + dir * rad * 0.82
		c.append(_crystal(at, at + (dir + Vector3(0, 0.7, 0)).normalized() * 0.45, 0.08, "accent", {"phase": spec[2], "name": "vein"}))
	for spec in [[70.0, 0.0], [160.0, 1.0], [330.0, 2.0]]:
		var ang: float = deg_to_rad(spec[0])
		var dir := Vector3(sin(ang), 0, cos(ang))
		c.append(_m(_drip(Vector3(0, 2.6, -0.1) + dir * 0.46, Vector3(0, 1.75, -0.1) + dir * 0.86, 0.06, spec[1]), lava))
	var head_c := Vector3(0, 1.08, 1.66)
	var hk: float = 1.35
	var beak: Vector3 = head_c + Vector3(0, -0.17, 0.5) * hk
	var crucible: Vector3 = beak + Vector3(0, -0.36, 0.06)
	_beak_head(c, Vector3(0, 0.78, 1.0), head_c, hk, 4350, [
		_rod(beak + Vector3(0.0, 0.02, -0.04), crucible + Vector3(0.2, 0.14, 0), 0.025, 0.025, "iron", {}, 4),
		_rod(beak + Vector3(0.0, 0.02, -0.04), crucible + Vector3(-0.2, 0.14, 0), 0.025, 0.025, "iron", {}, 4),
		_drum(crucible, 0.17, 0.24, 0.3, "iron"),
		_drum(crucible + Vector3(0, 0.14, 0), 0.21, 0.21, 0.03, "accent", {"motion": "core"}),
		_cone(crucible + Vector3(0, 0.12, 0.22), crucible + Vector3(0, 0.1, 0.38), 0.07, "iron", {}, 4),
		_flame(crucible + Vector3(0, 0.14, 0), crucible + Vector3(0.02, 0.36, -0.02), 0.06, 1.7),
		_rod(crucible + Vector3(0, 0.08, 0.36), Vector3(crucible.x, 0.06, crucible.z + 0.42), 0.05, 0.035, "accent", {"motion": "flicker", "phase": 0.8})])
	c.append(_puddle(Vector3(crucible.x, 0.03, crucible.z + 0.42), 0.3, 0.8))
	for side in [-1.0, 1.0]:
		for z in [0.62, -0.78]:
			_tortoise_leg(c, Vector3(side * 0.92, 0.62, z), Vector3(side * 1.06, 0.0, z * 1.18), 0.27, 4360 + int(side * 3.0 + z * 10.0))
	return c

static func _beak_head(out: Array, neck0: Vector3, head: Vector3, k: float, seed: int, crucible: Array) -> void:
	## A heavy hooked head on a thick neck: slag plates on the crown, iron brows over gem eyes,
	## an iron beak hooked down over an iron lower bill, and `crucible` hung from the beak's tip.
	## The neck turns at its base, the head on the neck's top, the beak at its root and the
	## crucible at the tip. The head is still in its idle (the volcano is the Smelter's idle), so
	## the crucible, turning slowly where it hangs, never drifts off the beak.
	var neck_top: Vector3 = head + Vector3(0, -0.04, -0.12) * k
	var neck := _role("neck", neck0)
	var skull := _role("head", neck_top)
	var beak := _role("beak", head + Vector3(0, -0.06, 0.18) * k)
	var pieces: Array = [
		_rod(neck0, neck_top, 0.22 * k, 0.17 * k, "body", neck),
		_rock(neck0.lerp(head, 0.45) + Vector3(0, 0.1, 0) * k, Vector3(0.2, 0.08, 0.16) * k, "body", 0.2, seed + 3, neck),
		_rock(head, Vector3(0.28, 0.24, 0.33) * k, "body", 0.08, seed, skull),
		_rock(head + Vector3(0, 0.2, -0.04) * k, Vector3(0.2, 0.08, 0.22) * k, "body", 0.2, seed + 1, skull),
		_cone(head + Vector3(0, 0.04, 0.2) * k, head + Vector3(0, -0.17, 0.5) * k, 0.14 * k, "iron", beak, 4),
		_slab(head + Vector3(0, -0.13, 0.24) * k, Vector3(0.22, 0.07, 0.28) * k, "iron", _m({"rot": [8, 0, 0]}, beak))]
	for side in [-1.0, 1.0]:
		pieces.append(_eye(head + Vector3(side * 0.18, 0.07, 0.15) * k, 0.07 * k, "accent", skull))
		pieces.append(_slab(head + Vector3(side * 0.15, 0.17, 0.15) * k, Vector3(0.17, 0.06, 0.2) * k, "iron", _m({"rot": [12, 0, side * -18.0]}, skull)))
	for piece in pieces:
		piece["motion"] = "static"
	out.append_array(pieces)
	out.append_array(_hang(crucible, head + Vector3(0, -0.17, 0.5) * k + Vector3(0, 0.02, -0.04), "block", 0.3, "crucible"))

static func _tortoise_leg(out: Array, top: Vector3, foot: Vector3, r: float, seed: int) -> void:
	## A stump of a leg: a scaled shoulder, a hex column, an iron shoe and three iron claws, one
	## `leg` hung from its shoulder at `top`.
	var leg := _role("leg", top)
	var fwd := Vector3(signf(foot.x) * 0.35, 0, signf(foot.z)).normalized()
	out.append(_rock(top, Vector3(r * 1.35, r * 1.1, r * 1.35), "body", 0.14, seed, leg))
	out.append(_rod(foot + Vector3(0, 0.12, 0), top, r * 1.08, r, "body", leg))
	out.append(_rock(top.lerp(foot, 0.5) + fwd * r * 0.7, Vector3(r * 0.55, r * 0.4, r * 0.3), "body", 0.2, seed + 1, _m({"aim": _v(fwd + Vector3(0, 1, 0))}, leg)))
	out.append(_drum(foot + Vector3(0, 0.08, 0), r * 1.32, r * 1.2, 0.16, "iron", leg))
	var side: Vector3 = Vector3.UP.cross(fwd).normalized()
	for s in [-1.0, 0.0, 1.0]:
		var root: Vector3 = foot + Vector3(0, 0.05, 0) + fwd * r * 1.1 + side * s * r * 0.6
		out.append(_cone(root, root + (fwd + side * s * 0.4).normalized() * r * 0.8 + Vector3(0, -0.03, 0), r * 0.22, "iron", leg, 4))

## ---- The Anvil Knight (review batch r3b, option C) -------------------------------------------

static func _anvil_knight() -> Array:
	## The empty suit: plate armour with a pillar of fire for a head and a broken spiked crown
	## floating in the flame, fire at the waist and chest, an anvil strapped to its back, both
	## gauntlets resting on a great hammer planted before it.
	var head := {"name": "head"}
	var crown := _m(_role("crown", Vector3(0, 3.3, 0)), {"motion": "bob", "phase": 0.0})
	## The head's marker leads the list, so the scene's first pivot moves (tests/test_creatures.gd).
	var c: Array = [_marker(Vector3(0, 2.9, 0), "head", {"motion": "core", "phase": 0.0})]
	for side in [-1.0, 1.0]:
		_knight_leg(c, Vector3(side * 0.3, 1.6, 0), Vector3(side * 0.38, 0.92, 0.1), Vector3(side * 0.4, 0.24, -0.02), 0.15, 1300 + int(side * 10.0), 0.0 if side > 0.0 else 1.3)
		c.append(_slab(Vector3(side * 0.27, 1.5, 0.28), Vector3(0.32, 0.46, 0.07), "body", {"rot": [-12, 0, side * -8.0]}))
		_pauldron(c, Vector3(side * 0.64, 2.74, 0), side, 0.32, 1320 + int(side * 5.0))
		c.append(_cone(Vector3(side * 0.68, 2.9, -0.08), Vector3(side * 0.84, 3.42, -0.2), 0.07, "iron"))
	c.append_array([
		_drum(Vector3(0, 1.7, 0), 0.47, 0.38, 0.3, "body"),
		_drum(Vector3(0, 1.92, 0), 0.32, 0.32, 0.16, "core", {"motion": "core"}),
		_drum(Vector3(0, 2.4, 0), 0.36, 0.58, 0.84, "body", {"scale": [1, 1, 0.72]}),
		_box(Vector3(0, 2.4, 0.0), Vector3(0.07, 1.0, 0.86), "iron", {"rot": [0, 0, 38]}),
		_flame(Vector3(0.12, 2.34, 0.22), Vector3(0.24, 2.56, 0.42), 0.05, 0.5),
		_flame(Vector3(-0.1, 2.18, 0.2), Vector3(-0.2, 2.34, 0.4), 0.04, 1.9),
		_drum(Vector3(0, 2.83, 0), 0.26, 0.26, 0.05, "core", {"motion": "core"}),
		_m(_flame(Vector3(0, 2.84, 0), Vector3(0.0, 3.82, -0.06), 0.21, 0.0), head),
		_m(_flame(Vector3(0.12, 2.86, 0.05), Vector3(0.32, 3.46, 0.02), 0.11, 1.0), head),
		_m(_flame(Vector3(-0.12, 2.86, -0.02), Vector3(-0.3, 3.52, -0.1), 0.12, 2.0), head),
		_m(_flame(Vector3(0, 2.86, -0.14), Vector3(0.04, 3.4, -0.42), 0.1, 3.0), head),
		_eye(Vector3(0.09, 3.1, 0.17), 0.055, "iron", {"motion": "bob", "phase": 0.0, "name": "eye"}),
		_eye(Vector3(-0.09, 3.1, 0.17), 0.055, "iron", {"motion": "bob", "phase": 0.0, "name": "eye"})])
	_ring(c, Vector3(0, 2.86, 0), 0.27, 6, 0.14, 0.08, "iron", 30.0)
	_ring(c, Vector3(0, 3.3, 0), 0.25, 6, 0.08, 0.05, "iron", 30.0, 1.04, "box", crown)
	for i in range(6):
		if i == 4:
			continue
		var ang: float = deg_to_rad(30.0 + 60.0 * float(i))
		var at := Vector3(sin(ang) * 0.25, 3.34, cos(ang) * 0.25)
		c.append(_cone(at, at + Vector3(sin(ang) * 0.06, 0.2 + 0.06 * float(i % 2), cos(ang) * 0.06), 0.045, "iron", crown, 4))
	c.append_array(_anvil_profile(Vector3(0.05, 2.98, -0.56), 1.0, 1.0, 0.3, 30.0))
	c.append(_box(Vector3(0, 2.4, 0.0), Vector3(0.07, 1.0, 0.86), "iron", {"rot": [0, 0, -38]}))
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.64, 2.6, 0)
		var arm: Array = _knight_arm(shoulder, Vector3(side * 0.74, 2.06, 0.3), Vector3(side * 0.13, 1.78, 0.66), 0.12, 1340 + int(side * 4.0), 0.5 + side)
		c.append_array(_hang(arm, shoulder, "block", 0.2, "arm_l" if side > 0.0 else "arm_r"))
	## The great hammer and its pommel gem hang from the middle of the shoulder line, so lifting
	## it is one turn about x for both arms and the hammer. It idles still: its glowing face and
	## spike would drift, pulsing about so far a joint.
	var hammer: Array = []
	_war_hammer(hammer, Vector3(0, 2.02, 0.7), Vector3(0, 0.25, 0.8), Vector3(1, 0, 0), 0.06, 0.25, 0.84)
	hammer.append(_gem(Vector3(0, 2.06, 0.7), 0.075, "accent"))
	for piece in hammer:
		piece.merge(_role("hammer", Vector3(0, 2.6, 0)), true)
		if piece.has("motion"):
			piece["motion"] = "static"
	c.append_array(hammer)
	return c

static func _knight_leg(out: Array, hip: Vector3, knee: Vector3, ankle: Vector3, r: float, seed: int, phase: float) -> void:
	## An armoured leg: an iron thigh, a hex greave with a plate down its front, a cut-stone knee
	## cop with forge-fire breaking out of the joint, and a long iron sabaton; one `leg` hung from
	## the hip. The knee fire holds still (swaying about the hip it would drift); the hip gem pulses.
	var leg := _role("leg", hip)
	var shin: Vector3 = knee - ankle
	out.append(_rod(hip, knee, r * 1.05, r * 0.9, "iron", leg))
	out.append(_rod(ankle, knee, r * 0.8, r * 1.0, "body", leg))
	out.append(_slab((knee + ankle) * 0.5 + Vector3(0, 0, r * 0.78), Vector3(r * 1.4, shin.length() * 0.8, 0.07), "body", _m({"aim": _v(shin)}, leg)))
	out.append(_rock(knee + Vector3(0, 0, r * 0.45), Vector3(r * 1.25, r * 1.1, r * 1.05), "body", 0.08, seed, leg))
	out.append(_crystal(knee + Vector3(r * 0.3 * signf(knee.x), 0.0, r * 0.7), knee + Vector3(r * 1.3 * signf(knee.x), r * 1.0, r * 1.5), r * 0.3, "accent", _m({"phase": phase, "motion": "static"}, leg)))
	out.append(_gem(hip + Vector3(0, -0.04, 0), r * 0.75, "core", _m({"phase": phase}, leg)))
	out.append(_slab(Vector3(ankle.x, 0.1, ankle.z + r * 0.7), Vector3(r * 2.0, 0.2, r * 3.4), "iron", leg))
	out.append(_slab(Vector3(ankle.x, 0.22, ankle.z + r * 0.35), Vector3(r * 1.7, 0.14, r * 2.0), "body", _m({"rot": [-12, 0, 0]}, leg)))

static func _knight_arm(shoulder: Vector3, elbow: Vector3, fist: Vector3, r: float, seed: int, phase: float) -> Array:
	## An armoured arm: iron upper arm, plated vambrace, a couter with fire spiking out of the
	## elbow, and an iron gauntlet.
	var out_dir := Vector3(signf(elbow.x) * 0.7, -0.1, -0.7).normalized()
	return [
		_rod(shoulder, elbow, r, r * 0.9, "iron"),
		_rod(elbow, fist, r * 1.12, r * 0.95, "body"),
		_rock(elbow, Vector3.ONE * r * 1.2, "body", 0.08, seed),
		_crystal(elbow, elbow + out_dir * r * 2.6, r * 0.38, "accent", {"phase": phase}),
		_rock(fist, Vector3(r * 1.35, r * 1.25, r * 1.35), "iron", 0.1, seed + 1)]

static func _pauldron(out: Array, at: Vector3, side: float, size: float, seed: int) -> void:
	## A shoulder of stacked plates with forge-fire crystals growing out of the top.
	out.append(_rock(at, Vector3(size, size * 0.72, size * 1.05), "body", 0.08, seed))
	out.append(_slab(at + Vector3(side * size * 0.3, -size * 0.6, 0), Vector3(size * 1.1, size * 0.22, size * 1.4), "body", {"rot": [0, 0, side * -28.0]}))
	out.append(_slab(at + Vector3(side * size * 0.55, -size * 0.95, 0), Vector3(size * 0.9, size * 0.2, size * 1.25), "body", {"rot": [0, 0, side * -40.0]}))
	out.append(_crystal(at + Vector3(side * size * 0.3, size * 0.4, 0), at + Vector3(side * size * 0.95, size * 1.7, -size * 0.2), size * 0.17))
	out.append(_crystal(at + Vector3(0, size * 0.45, -size * 0.4), at + Vector3(side * size * 0.35, size * 1.35, -size * 1.0), size * 0.13, "accent", {"phase": 1.2}))

static func _anvil_profile(centre: Vector3, k: float, horn_dir: float, depth: float = 0.3, yaw: float = 0.0) -> Array:
	## An anvil laid with its outline to the party (turned `yaw` degrees about y): wide feet, a
	## narrow waist, the broad face glowing hot along its top, the heel squared off on one end
	## and the horn on the other.
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var at := func(local: Vector3) -> Vector3: return centre + turn * (local * k)
	var r: Array = [0, yaw, 0]
	return [
		_slab(at.call(Vector3(0, -0.3, 0)), Vector3(0.8, 0.2, depth) * k, "iron", {"rot": r}),
		_slab(at.call(Vector3(0, -0.07, 0)), Vector3(0.38, 0.3, depth * 0.85) * k, "iron", {"rot": r}),
		_slab(at.call(Vector3(0, 0.17, 0)), Vector3(0.94, 0.26, depth) * k, "iron", {"rot": r}),
		_slab(at.call(Vector3(-horn_dir * 0.5, 0.15, 0)), Vector3(0.12, 0.2, depth * 0.9) * k, "iron", {"rot": r}),
		_cone(at.call(Vector3(horn_dir * 0.45, 0.2, 0)), at.call(Vector3(horn_dir * 1.02, 0.27, 0)), 0.13 * k, "iron", {}, 6),
		_box(at.call(Vector3(0, 0.31, 0)), Vector3(0.88, 0.025, depth * 0.9) * k, "accent", {"rot": r, "motion": "core"}),
		_box(at.call(Vector3(0, 0.17, depth * 0.5 + 0.01)), Vector3(0.8, 0.035, 0.01) * k, "core", {"rot": r, "motion": "core"}),
		_box(at.call(Vector3(0, 0.17, -depth * 0.5 - 0.01)), Vector3(0.8, 0.035, 0.01) * k, "core", {"rot": r, "motion": "core"}),
		_box(at.call(Vector3(-horn_dir * 0.28, 0.32, 0)), Vector3(0.08, 0.03, 0.08) * k, "iron", {"rot": r})]

static func _war_hammer(out: Array, grip: Vector3, head_at: Vector3, across: Vector3, haft_r: float, head_r: float, head_len: float, extra: Dictionary = {}) -> void:
	## The knight's iron war hammer: haft from the grip to the head, the hex head across it with a
	## glowing striking face on one end and a crystal spike on the other.
	var a: Vector3 = across.normalized()
	for piece in [
		_rod(grip, head_at, haft_r * 1.1, haft_r, "iron"),
		_rod(head_at - a * head_len * 0.5, head_at + a * head_len * 0.5, head_r, head_r, "iron"),
		_rod(head_at - a * head_len * 0.18, head_at + a * head_len * 0.18, head_r * 1.12, head_r * 1.12, "body"),
		_rod(head_at + a * head_len * 0.5, head_at + a * (head_len * 0.5 + 0.03), head_r * 0.86, head_r * 0.86, "accent", {"motion": "core"}),
		_crystal(head_at - a * head_len * 0.5, head_at - a * (head_len * 0.5 + head_r * 1.8), head_r * 0.55),
		_cone(grip, grip - (head_at - grip).normalized() * 0.16, haft_r * 1.3, "iron", {}, 5)]:
		piece.merge(extra, true)
		out.append(piece)

## ---- The Kiln Wyrm (review batch r3c, option A) ----------------------------------------------

static func _kiln_wyrm() -> Array:
	## The Kiln Dragon (renamed in the review; the key stays): standing on all four legs, great
	## wings raised high, an S-shaped neck up to a horned head roaring fire, a long tail curling
	## round to an obsidian blade; fire through zigzag cracks in its flanks.
	var head_at := Vector3(0, 3.2, 1.5)
	var head_turn: Basis = _look(Vector3(0, -0.35, 1))
	## The mouth marker leads the list, so the scene's first pivot moves (tests/test_creatures.gd).
	var a: Array = []
	_place(a, _head([_marker(Vector3(0, -0.15, 0.8), "mouth")], Vector3.ZERO, 0.3), head_at, head_turn, 1.15)
	a.append_array([
		_rock(Vector3(0, 1.62, 0.5), Vector3(0.66, 0.62, 0.66), "body", 0.1, 421),
		_rock(Vector3(0, 1.52, -0.28), Vector3(0.6, 0.55, 0.62), "body", 0.1, 422),
		_rock(Vector3(0, 1.45, -0.95), Vector3(0.54, 0.5, 0.56), "body", 0.1, 423)])
	for i in range(3):
		a.append({"shape": "slab", "at": [0, 1.06 + 0.04 * float(i), 0.75 - 0.5 * float(i)], "rot": [-8, 0, 0], "material": "core", "motion": "core", "phase": float(i) * 0.7, "size": [0.62 - 0.08 * float(i), 0.1, 0.42], "jitter": 0.04})
	_seams(a, Vector3(0, 1.62, 0.5), Vector3(0.66, 0.62, 0.66), 0.0)
	_seams(a, Vector3(0, 1.45, -0.95), Vector3(0.54, 0.5, 0.56), 1.5)
	var neck_a: Array = [Vector3(0, 2.0, 0.95), Vector3(0, 2.35, 1.2), Vector3(0, 2.7, 1.3), Vector3(0, 3.0, 1.34), Vector3(0, 3.18, 1.45)]
	var neck := _role("neck", neck_a[0])
	_rocks(a, neck_a, [0.38, 0.31, 0.27, 0.24, 0.22], "body", 431, neck, 0.1, 1.0, 0.62, true)
	for i in range(1, 4):
		a.append(_gem((neck_a[i] as Vector3) + Vector3(0, -0.12, 0.16), 0.09, "core", {"phase": float(i), "name": "throat"}))
	_place(a, _dragon_head(34.0, 0.3), head_at, head_turn, 1.15)
	var spines: int = a.size()
	_spines(a, [[Vector3(0, 2.62, 1.12), 0.26], [Vector3(0, 2.25, 0.75), 0.42], [Vector3(0, 2.2, 0.3), 0.55], [Vector3(0, 2.05, -0.2), 0.6], [Vector3(0, 1.98, -0.7), 0.5], [Vector3(0, 1.9, -1.15), 0.4]], Vector3(0, 0, -1))
	## The first spine stands on the neck and goes with it.
	a[spines].merge(neck)
	var tail_a: Array = [Vector3(0, 1.38, -1.4), Vector3(0, 1.12, -1.82), Vector3(0.1, 0.8, -2.2), Vector3(0.35, 0.48, -2.55), Vector3(0.8, 0.26, -2.75), Vector3(1.3, 0.17, -2.62), Vector3(1.7, 0.15, -2.28)]
	var tail := _role("tail", tail_a[0])
	_rocks(a, tail_a, [0.4, 0.33, 0.27, 0.22, 0.18, 0.14, 0.11], "body", 441, tail, 0.1, 0.85, 0.62, true)
	for i in range(1, 6):
		var t: Vector3 = tail_a[i]
		a.append(_stick("crystal", t + Vector3(0, 0.1, 0), t + Vector3(0, 0.38 - 0.04 * float(i), 0), 0.07 - 0.008 * float(i), "iron", tail))
	for spec in [[Vector3(2.15, 0.2, -1.95), 0.08], [Vector3(2.05, 0.42, -2.2), 0.06], [Vector3(1.95, 0.14, -2.45), 0.06]]:
		a.append(_stick("crystal", Vector3(1.7, 0.15, -2.28), spec[0], spec[1], "iron", tail))
	a.append(_stick("crystal", Vector3(1.7, 0.2, -2.28), Vector3(1.95, 0.55, -2.0), 0.05, "accent", {"motion": "flicker", "name": "tail"}))
	for side in [-1.0, 1.0]:
		_wing(a, Vector3(side * 0.45, 2.08, 0.35), Vector3(side * 1.45, 3.3, -0.05),
			[Vector3(side * 2.9, 2.95, -0.4), Vector3(side * 2.85, 1.95, -0.75), Vector3(side * 2.2, 1.2, -1.0)], Vector3(side * 0.42, 1.85, -0.95), side, 0.0)
		_dragon_leg(a, Vector3(side * 0.58, 1.55, 0.62), Vector3(side * 0.82, 0.9, 0.45), Vector3(side * 0.78, 0.4, 0.7), Vector3(side * 0.76, 0.06, 0.92), 0.26, 451, Vector3(side * 0.15, 0, 1))
		_dragon_leg(a, Vector3(side * 0.55, 1.42, -0.95), Vector3(side * 0.85, 0.92, -0.5), Vector3(side * 0.8, 0.42, -1.15), Vector3(side * 0.78, 0.06, -0.92), 0.3, 455, Vector3(side * 0.15, 0, 1))
	return a

static func _dragon_head(open_deg: float, phase: float) -> Array:
	## A horned dragon's head in its own frame, looking down +z from the top of its neck at the
	## origin: a cut-stone skull, a blocky muzzle, brows, the lower jaw hung open on a gem of fire
	## in the throat, fangs lit by it, flames out of the mouth, and two pairs of obsidian horns
	## swept back. The head turns on the neck and the jaw and its fangs hinge on their own; the
	## throat gem and the flames of its breath stay unjointed so they pulse and flicker in place.
	var p: Array = [
		_rock(Vector3(0, 0.1, 0.05), Vector3(0.36, 0.3, 0.42), "body", 0.08, 401),
		{"shape": "slab", "at": [0, 0.1, 0.55], "rot": [6, 0, 0], "material": "body", "size": [0.34, 0.2, 0.6], "jitter": 0.05, "seed": 402},
		_rock(Vector3(0, 0.1, 0.84), Vector3(0.16, 0.12, 0.12), "body", 0.1, 403),
		_stick("crystal", Vector3(0, 0.18, 0.66), Vector3(0, 0.4, 0.74), 0.05, "iron"),
		_stick("crystal", Vector3(0, 0.36, 0.0), Vector3(0, 0.6, -0.3), 0.06, "iron")]
	for side in [-1.0, 1.0]:
		p.append({"shape": "slab", "at": [side * 0.17, 0.28, 0.3], "rot": [-12, side * 12.0, side * -10.0], "material": "body", "size": [0.13, 0.07, 0.38], "jitter": 0.04})
		p.append(_eye(Vector3(side * 0.18, 0.2, 0.38), 0.07))
		p.append(_eye(Vector3(side * 0.08, 0.19, 0.86), 0.025))
		p.append(_stick("cone", Vector3(side * 0.15, 0.3, 0.05), Vector3(side * 0.5, 0.72, -0.48), 0.09, "iron"))
		p.append(_stick("cone", Vector3(side * 0.26, 0.12, 0.0), Vector3(side * 0.64, 0.14, -0.34), 0.06, "iron"))
		p.append(_stick("cone", Vector3(side * 0.3, -0.02, 0.12), Vector3(side * 0.52, -0.14, -0.1), 0.04, "iron"))
		p.append(_stick("cone", Vector3(side * 0.12, 0.02, 0.72), Vector3(side * 0.12, -0.17, 0.74), 0.035, "accent"))
	for x in [-0.05, 0.05]:
		p.append(_stick("cone", Vector3(x, 0.02, 0.8), Vector3(x, -0.1, 0.82), 0.025, "accent"))
	var drop: float = deg_to_rad(open_deg)
	var hinge := Vector3(0, -0.04, 0.18)
	var dir := Vector3(0, -sin(drop), cos(drop))
	var jaw := _role("jaw", hinge)
	p.append(_m({"shape": "slab", "at": _v(hinge + dir * 0.31), "rot": [open_deg, 0, 0], "material": "body", "size": [0.28, 0.09, 0.62], "jitter": 0.03}, jaw))
	for x in [-0.08, 0.08]:
		var tip: Vector3 = hinge + dir * 0.55 + Vector3(x, 0.03, 0)
		p.append(_stick("cone", tip, tip + Vector3(0, 0.13, 0.0).rotated(Vector3.RIGHT, drop), 0.03, "accent", jaw))
	_head(p, Vector3.ZERO, phase)
	p.append(_gem(Vector3(0, -0.03, 0.32), 0.14, "core", {"name": "throat"}))
	p.append(_m(_flame(Vector3(0, -0.06, 0.45), Vector3(0, -0.26, 1.25), 0.1, phase), {"name": "breath"}))
	p.append(_m(_flame(Vector3(0.06, -0.06, 0.45), Vector3(0.24, -0.14, 1.02), 0.06, phase + 1.3), {"name": "breath"}))
	p.append(_m(_flame(Vector3(-0.06, -0.08, 0.45), Vector3(-0.2, -0.32, 1.06), 0.06, phase + 2.6), {"name": "breath"}))
	return p

static func _wing(out: Array, shoulder: Vector3, wrist: Vector3, tips: Array, root: Vector3, side: float, phase: float) -> void:
	## A dragon's wing hung from the shoulder: an obsidian arm bone to the wrist, finger bones
	## fanned from it, red membrane panels between them, a hooked thumb. It beats slowly from the
	## shoulder, both wings rising together: `wing_l` on its own left (+x), `wing_r` on its right.
	var pieces: Array = [
		_stick("cylinder", shoulder, wrist, 0.1, "iron"),
		_rock(wrist, Vector3(0.12, 0.12, 0.12), "iron", 0.1, 411),
		_stick("cone", wrist, wrist + (wrist - shoulder).normalized() * 0.4 + Vector3(0, 0.12, 0.1), 0.06, "iron")]
	for i in range(tips.size()):
		var tip: Vector3 = tips[i]
		var next: Vector3 = tips[i + 1] if i + 1 < tips.size() else root
		pieces.append(_stick("cone", wrist, tip, 0.06, "iron"))
		pieces.append(_tri(wrist, tip, next, "body"))
		## A seam of fire running down each panel.
		pieces.append(_stick("crystal", wrist.lerp(tip, 0.35).lerp(next, 0.3), wrist.lerp(tip, 0.75).lerp(next, 0.45), 0.025, "core"))
	pieces.append(_tri(root, shoulder, wrist, "body"))
	var extra := {"joint": _v(shoulder), "motion": "swing", "phase": phase if side > 0.0 else phase + PI, "name": "wing_l" if side > 0.0 else "wing_r"}
	for piece in pieces:
		out.append(_m(piece, extra.duplicate()))

static func _dragon_leg(out: Array, hip: Vector3, knee: Vector3, ankle: Vector3, foot: Vector3, thick: float, seed: int, forward: Vector3, claws: int = 3) -> void:
	## A thigh of cut stone, a hex shin to the ankle and on to the foot, the foot a flat stone,
	## obsidian claws fanned forward: one `leg` hung from the hip.
	var leg := _role("leg", hip)
	out.append(_stone(hip, knee, thick, "body", 0.1, seed, leg))
	out.append(_stick("cylinder", knee, ankle, thick * 0.55, "body", leg))
	if ankle.distance_to(foot) > 0.05:
		out.append(_stick("cylinder", ankle, foot, thick * 0.45, "body", leg))
	out.append(_rock(foot + Vector3(0, 0.05, 0) + forward.normalized() * 0.06, Vector3(thick * 0.6, thick * 0.32, thick * 0.8), "body", 0.12, seed + 1, leg))
	var side: Vector3 = Vector3.UP.cross(forward).normalized()
	for i in range(claws):
		var spread: float = (float(i) - float(claws - 1) * 0.5) * 0.55
		var d: Vector3 = (forward.normalized() + side * spread).normalized()
		out.append(_stick("cone", foot + Vector3(0, 0.05, 0) + d * thick * 0.4, foot + d * (thick * 0.4 + 0.3) + Vector3(0, 0.01, 0), 0.05, "iron", leg))

static func _seams(out: Array, centre: Vector3, radii: Vector3, phase: float) -> void:
	## Fire showing through the cracks between the scales: a crack of glowing columns zigzagging
	## down each flank from the back toward the belly.
	for side in [-1.0, 1.0]:
		var pts: Array = [Vector3(0.55, 0.62, -0.45), Vector3(0.86, 0.3, -0.12), Vector3(0.9, 0.12, 0.2), Vector3(0.82, -0.3, 0.42)]
		for i in range(pts.size() - 1):
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			out.append(_stick("column", centre + Vector3(side * p.x, p.y, p.z) * radii, centre + Vector3(side * q.x, q.y, q.z) * radii, 0.035, "accent", {"sides": 4, "motion": "core", "phase": phase}))

static func _spines(out: Array, specs: Array, back: Vector3) -> void:
	## Obsidian crystals down the back, a smaller crystal of fire between every two.
	for i in range(specs.size()):
		var at: Vector3 = specs[i][0]
		var h: float = specs[i][1]
		var up: Vector3 = specs[i][2] if specs[i].size() > 2 else Vector3.UP
		out.append(_stick("crystal", at - up * 0.12, at + (up + back * 0.45).normalized() * h, h * 0.2, "iron"))
		if i + 1 < specs.size():
			var mid: Vector3 = (at + (specs[i + 1][0] as Vector3)) * 0.5
			out.append(_m(_flame(mid - up * 0.08, mid + (up + back * 0.3).normalized() * h * 0.5, h * 0.1, float(i) * 0.9), {"motion": "crystal"}))

## ---- shared helpers: naming ---------------------------------------------------------------

static func _role(role: String, joint: Variant) -> Dictionary:
	## The fields that make a part one piece of a named group hinged at `joint`.
	return {"name": role, "joint": _v(joint)}

static func _marker(at: Variant, role: String, extra: Dictionary = {}) -> Dictionary:
	## A gem too small to see that marks a point for the animation pass: a `mouth` where a breath,
	## a spit or a bite leaves, a `crater` where an eruption does. Draws no random numbers.
	var marker := _m({"shape": "sphere", "at": _v(at), "scale": 0.02, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2}, extra)
	marker["name"] = role
	return marker

static func _head(pieces: Array, neck: Variant, phase: float) -> Array:
	## The pieces of a head turning as one from `neck` (its slow idle turn, `block` at `phase`),
	## named `head`. A piece that already names its own joint (a jaw, a pincer, an antenna) keeps
	## it and turns the same way about it; a named marker rides with the head.
	for piece in pieces:
		var own: Variant = piece.get("joint", null)
		piece.merge({"joint": _v(neck), "motion": "block", "phase": phase}, true)
		if own != null:
			piece["joint"] = own
		if not piece.has("name"):
			piece["name"] = "head"
	return pieces

static func _hang(pieces: Array, joint: Variant, motion: String, phase: float, role: String = "") -> Array:
	## Every piece hung from one joint, moving as one (and named `role` when one is given).
	for piece in pieces:
		piece.merge({"joint": _v(joint), "motion": motion, "phase": phase}, true)
		if role != "":
			piece["name"] = role
	return pieces

## ---- shared helpers: points and turns -----------------------------------------------------

static func _v(p: Variant) -> Array:
	## A point as the [x, y, z] a part takes; an Array passes through as it is.
	if p is Vector3:
		var q: Vector3 = p
		return [q.x, q.y, q.z]
	return p

static func _vec(a: Variant) -> Vector3:
	## An [x, y, z] (or a Vector3) as a Vector3.
	if a is Vector3:
		return a
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

static func _m(part: Dictionary, extra: Dictionary) -> Dictionary:
	## `part` with `extra` merged over it.
	part.merge(extra, true)
	return part

static func _aimed(direction: Vector3) -> Basis:
	## Upright turned the shortest way round until its Y axis runs along `direction` (the bake's
	## own rule for `from`/`to` and `aim`).
	var up: Vector3 = direction.normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() < 0.0001:
		return Basis() if up.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(up))

static func _rot(basis: Basis) -> Array:
	## A basis as the degrees a part's `rot` takes (the bake reads them back in the same order).
	var e: Vector3 = basis.orthonormalized().get_euler()
	return [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

static func _aim_rot(direction: Vector3) -> Array:
	## The `rot` that stands a part's Y axis along `direction`.
	return _rot(_aimed(direction))

static func _euler(x: float, y: float, z: float) -> Basis:
	## A turn from degrees about x, y and z.
	return Basis.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))

static func _look(forward: Vector3) -> Basis:
	## A frame whose +z runs along `forward` and whose +y stays as near up as it can.
	var f: Vector3 = forward.normalized()
	var r: Vector3 = Vector3.UP.cross(f).normalized()
	return Basis(r, f.cross(r), f)

static func _place(out: Array, pieces: Array, origin: Vector3, basis: Basis, s: float) -> void:
	## Pieces drawn in their own frame (a head looking down +z) set into the creature at
	## `origin`, turned by `basis` and grown by `s`, joints with them.
	for piece in pieces:
		var q: Dictionary = (piece as Dictionary).duplicate(true)
		if q.has("from"):
			q["from"] = _v(origin + basis * (_vec(q["from"]) * s))
			q["to"] = _v(origin + basis * (_vec(q["to"]) * s))
			for key in ["radius", "top", "bottom"]:
				if q.has(key):
					q[key] = float(q[key]) * s
		else:
			q["at"] = _v(origin + basis * (_vec(q.get("at", [0, 0, 0])) * s))
			var local: Basis = _aimed(_vec(q["aim"])) if q.has("aim") else Basis.from_euler(_vec(q.get("rot", [0, 0, 0])) * (PI / 180.0))
			q.erase("aim")
			q["rot"] = _rot(basis * local)
			var sc: Variant = q.get("scale", 1.0)
			q["scale"] = [float(sc[0]) * s, float(sc[1]) * s, float(sc[2]) * s] if sc is Array else float(sc) * s
		if q.has("joint"):
			q["joint"] = _v(origin + basis * (_vec(q["joint"]) * s))
		out.append(q)

## ---- shared helpers: shapes ---------------------------------------------------------------

static func _rock(at: Vector3, size: Variant, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## A cut stone (`size` one number or three).
	var s: Variant = _v(size) if size is Vector3 else size
	return _m({"shape": "rock", "at": _v(at), "scale": s, "material": material, "jitter": jitter, "seed": seed}, extra)

static func _stone(from: Vector3, to: Vector3, r: float, material: String, jitter: float, seed: int, extra: Dictionary = {}) -> Dictionary:
	## One cut stone laid from `from` to `to`: a thigh, a forearm, a knuckle.
	return _m({"shape": "rock", "at": _v((from + to) * 0.5), "rot": _rot(_aimed(to - from)), "scale": [r, from.distance_to(to) * 0.6 + r * 0.2, r * 0.92], "material": material, "jitter": jitter, "seed": seed}, extra)

static func _rocks(out: Array, path: Array, widths: Array, material: String, seed_base: int, extra: Dictionary = {}, jitter: float = 0.1, flat: float = 1.0, reach: float = 0.62, turned: bool = false) -> void:
	## A long body, a neck or a tail as cut stones stepping along `path`: a rock at every point,
	## turned along the path, as wide as `widths` says there, `flat` of that tall and `reach` of
	## the step long, so each stone overlaps the next and the row visibly steps. The turn is an
	## `aim`, or the same turn written as a `rot` when `turned` (as the Kiln Wyrm's batch wrote it).
	var n: int = path.size()
	for i in range(n):
		var p: Vector3 = path[i]
		var prev: Vector3 = path[maxi(i - 1, 0)]
		var next: Vector3 = path[mini(i + 1, n - 1)]
		var step: float = maxf(p.distance_to(prev), p.distance_to(next))
		var w: float = widths[i]
		var piece := {"shape": "rock", "at": _v(p), "scale": [w, maxf(step * reach, w * 0.7), w * flat], "material": material, "jitter": jitter, "seed": seed_base + i}
		if turned:
			piece["rot"] = _rot(_aimed(next - prev))
		else:
			piece["aim"] = _v(next - prev)
		out.append(_m(piece, extra))

static func _slab(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	## A cut block, barely chipped.
	return _m({"shape": "slab", "at": _v(at), "material": material, "size": _v(size), "jitter": 0.02}, extra)

static func _box(at: Vector3, size: Vector3, material: String, extra: Dictionary = {}) -> Dictionary:
	## A plain box: a strap, a bar, a glowing strip.
	return _m({"shape": "box", "at": _v(at), "material": material, "size": _v(size)}, extra)

static func _rod(from: Vector3, to: Vector3, r0: float, r1: float, material: String = "body", extra: Dictionary = {}, sides: int = 6) -> Dictionary:
	## A hex stick, r0 thick at `from`, r1 at `to`.
	return _m({"shape": "cylinder", "from": _v(from), "to": _v(to), "material": material, "bottom": r0, "top": r1, "sides": sides}, extra)

static func _drum(at: Vector3, bottom: float, top: float, height: float, material: String, extra: Dictionary = {}) -> Dictionary:
	## An upright hex drum (a frustum when top and bottom differ).
	return _m({"shape": "cylinder", "at": _v(at), "material": material, "bottom": bottom, "top": top, "height": height, "sides": 6}, extra)

static func _cone(from: Vector3, to: Vector3, r: float, material: String = "body", extra: Dictionary = {}, sides: int = 5) -> Dictionary:
	## A cone from its base at `from` to its point at `to`.
	return _m({"shape": "cone", "from": _v(from), "to": _v(to), "material": material, "radius": r, "sides": sides}, extra)

static func _crystal(from: Vector3, to: Vector3, r: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## A swaying crystal grown from `from` to its point at `to`.
	return _m({"shape": "crystal", "from": _v(from), "to": _v(to), "material": material, "motion": "crystal", "radius": r}, extra)

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

static func _tri(a: Vector3, b: Vector3, c: Vector3, material: String, extra: Dictionary = {}, thick: float = 0.045) -> Dictionary:
	## A thin triangular panel, apex `a`, base `b`-`c`: a wing membrane.
	var x: Vector3 = (c - b).normalized()
	var mid: Vector3 = (b + c) * 0.5
	var up: Vector3 = a - mid
	up = up - x * up.dot(x)
	var h: float = maxf(up.length(), 0.01)
	var y: Vector3 = up / h
	return _m({"shape": "prism", "at": _v(mid + y * h * 0.5), "rot": _rot(Basis(x, y, x.cross(y))), "material": material, "size": [b.distance_to(c), h, thick]}, extra)

## ---- shared helpers: gems and fire --------------------------------------------------------

static func _eye(at: Variant, size: float, material: String = "accent", extra: Dictionary = {}) -> Dictionary:
	## A pentagonal gem: an eye, a stud, a mote.
	return _m({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "radius": 1.0, "segments": 5, "rings": 2}, extra)

static func _gem(at: Vector3, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## The biggest cut gem allowed (six by three), pulsing: a heart, a throat, a pommel.
	var s: Variant = _v(size) if size is Vector3 else size
	return _m({"shape": "sphere", "at": _v(at), "scale": s, "material": material, "motion": "core", "radius": 1.0, "segments": 6, "rings": 3}, extra)

static func _glow_gem(at: Variant, size: Variant, material: String, extra: Dictionary = {}) -> Dictionary:
	## A five-sided cut stone that glows and pulses: a throat of fire, an ember between plates.
	return _m({"shape": "sphere", "at": _v(at), "scale": size, "material": material, "motion": "core", "radius": 1.0, "segments": 5, "rings": 2}, extra)

static func _flame(from: Variant, to: Variant, radius: float, phase: float) -> Dictionary:
	## A tongue of fire: a crystal that grows from its root and licks about.
	return {"shape": "crystal", "from": _v(from), "to": _v(to), "material": "accent", "motion": "flicker", "phase": phase, "radius": radius, "sides": 5}

static func _ember(at: Variant, size: float, phase: float) -> Dictionary:
	## A drifting ember: a gem that bobs.
	return {"shape": "sphere", "at": _v(at), "scale": size, "material": "accent", "motion": "bob", "phase": phase, "radius": 1.0, "segments": 5, "rings": 2}

static func _drip(from: Variant, to: Variant, radius: float, phase: float) -> Dictionary:
	## Molten metal running or falling: a crystal needle pointing the way it runs, flickering.
	return {"shape": "crystal", "from": _v(from), "to": _v(to), "material": "accent", "motion": "flicker", "phase": phase, "radius": radius, "sides": 4}

static func _puddle(at: Variant, across: float, phase: float, along: float = 0.0) -> Dictionary:
	## Molten metal pooled on the floor: a flat hex plate, `along` long front to back when given.
	var pool := {"shape": "cylinder", "at": _v(at), "material": "accent", "motion": "core", "phase": phase, "top": across, "bottom": across, "height": 0.05, "sides": 6}
	if along > 0.0:
		pool["scale"] = [1.0, 1.0, along / across]
	return pool

## ---- shared helpers: beasts ---------------------------------------------------------------

static func _snout(at: Vector3, along: Vector3, width: float, length: float, height: float, extra: Dictionary = {}) -> Dictionary:
	## An upper muzzle as a cut block laid along `along`.
	var piece := {"shape": "slab", "at": _v(at), "aim": _v(along), "material": "body", "size": [width, length, height], "jitter": 0.05}
	piece.merge(extra, true)
	return piece

static func _jaw(hinge: Vector3, length: float, width: float, thick: float, drop_deg: float, material: String = "body") -> Dictionary:
	## A lower jaw hung from its hinge, open by `drop_deg`, for a head that looks toward +z.
	var drop: float = deg_to_rad(drop_deg)
	var centre: Vector3 = hinge + Vector3(0, -sin(drop), cos(drop)) * length * 0.5
	return {"shape": "slab", "at": _v(centre), "rot": [drop_deg, 0, 0], "material": material, "size": [width, thick, length], "jitter": 0.03}

static func _teeth(out: Array, at_y: float, z: float, xs: Array, length: float, down: bool, material: String = "iron", extra: Dictionary = {}) -> void:
	## A row of fangs at height `at_y`, pointing down from an upper jaw or up from a lower one.
	for x in xs:
		var tip: float = at_y - length if down else at_y + length
		out.append(_m({"shape": "cone", "from": [x, at_y, z], "to": [x, tip, z + 0.01], "material": material, "radius": length * 0.4, "sides": 4}, extra))

static func _limb(out: Array, hip: Vector3, knee: Vector3, foot: Vector3, thick: float, material: String = "body", extra: Dictionary = {}, sides: int = 5) -> void:
	## A two-stick leg: thigh to the knee, shin to the foot, five-sided so every stick has edges.
	var upper := {"shape": "cylinder", "from": _v(hip), "to": _v(knee), "material": material, "top": thick * 0.8, "bottom": thick, "sides": sides}
	var lower := {"shape": "cylinder", "from": _v(knee), "to": _v(foot), "material": material, "top": thick * 0.55, "bottom": thick * 0.8, "sides": sides}
	upper.merge(extra)
	lower.merge(extra)
	out.append(upper)
	out.append(lower)

static func _toes(out: Array, foot: Vector3, forward: Vector3, count: int, length: float, thick: float = 0.24, extra: Dictionary = {}) -> void:
	## Toes fanned from a foot, `thick` of their length wide at the root: the middle one straight
	## ahead, the others splayed.
	var side: Vector3 = Vector3.UP.cross(forward).normalized()
	for i in range(count):
		var spread: float = (float(i) - float(count - 1) * 0.5) * 0.6
		var dir: Vector3 = (forward + side * spread).normalized()
		out.append(_m({"shape": "cone", "from": _v(foot + Vector3(0, 0.02, 0)), "to": _v(foot + dir * length + Vector3(0, 0.01, 0)), "material": "body", "radius": length * thick, "sides": 4}, extra))

static func _paw(out: Array, foot: Vector3, size: float, seed: int = 0, extra: Dictionary = {}) -> void:
	## A paw: a flat cut stone under the foot.
	out.append(_m({"shape": "rock", "at": _v(foot + Vector3(0, 0.03, 0.04)), "scale": [size, size * 0.5, size * 1.3], "material": "body", "jitter": 0.14, "seed": 900 + seed}, extra))

## ---- shared helpers: iron ------------------------------------------------------------------

static func _band(out: Array, centre: Vector3, rot: Array, apothem: float, count: int, thick: float, deep: float, material: String, extra: Dictionary = {}, start_deg: float = 30.0, shape: String = "box", rivet: float = 0.0) -> void:
	## `count` boxes laid end to end round the Y axis of `rot`, each `apothem` from the centre:
	## an iron hoop, a collar, a rim. `thick` is along the axis, `deep` across it; `rivet` puts a
	## hot gem of that size on every box, so dark iron on a dark body still reads.
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2]))))
	var arc: float = 2.0 * apothem * tan(PI / float(count)) * 1.04
	for i in range(count):
		var a: float = deg_to_rad(start_deg) + TAU * float(i) / float(count)
		var r: Vector3 = basis.z * cos(a) + basis.x * sin(a)
		var t: Vector3 = basis.x * cos(a) - basis.z * sin(a)
		var piece := {"shape": shape, "at": _v(centre + r * apothem), "rot": _rot(Basis(t, basis.y, r)), "material": material, "size": [arc, thick, deep]}
		piece.merge(extra, true)
		out.append(piece)
		if rivet > 0.0:
			var stud := {"shape": "sphere", "at": _v(centre + r * (apothem + deep * 0.5)), "scale": rivet, "material": "accent", "radius": 1.0, "segments": 5, "rings": 2}
			stud.merge(extra, true)
			stud.erase("size")
			out.append(stud)

static func _ring(out: Array, centre: Vector3, apothem: float, count: int, high: float, deep: float, material: String, start_deg: float = 0.0, fill: float = 1.04, shape: String = "box", extra: Dictionary = {}) -> void:
	## `count` boxes (or slabs) laid round a level ring: a hoop, a collar, a course of stones.
	## `fill` under 1 leaves a gap between neighbours for the glow behind to show.
	var arc: float = 2.0 * apothem * tan(PI / float(count)) * fill
	for i in range(count):
		var a: float = deg_to_rad(start_deg) + TAU * float(i) / float(count)
		var r := Vector3(sin(a), 0, cos(a))
		var piece := {"shape": shape, "at": _v(centre + r * apothem), "rot": [0, rad_to_deg(a), 0], "material": material, "size": [arc, high, deep]}
		if shape == "slab":
			piece["jitter"] = 0.03
		out.append(_m(piece, extra))

static func _chain(out: Array, path: Array, link: float, material: String, extra: Dictionary = {}) -> void:
	## A chain: a flat link of iron on every step of `path`, every other one turned on edge.
	for i in range(path.size() - 1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var basis: Basis = _aimed(b - a)
		if i % 2 == 1:
			basis = basis * Basis(Vector3.UP, PI * 0.5)
		var piece := {"shape": "box", "at": _v((a + b) * 0.5), "rot": _rot(basis), "material": material, "size": [link * 0.7, a.distance_to(b) * 1.15, link * 0.28]}
		piece.merge(extra, true)
		out.append(piece)
