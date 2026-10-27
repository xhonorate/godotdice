extends RefCounted
## The Quarry's new creatures, its two Wardens and its boss, as recipes for
## tools/creature_bake.gd. The Foreman and the Mirror Regent were once the same two stacked
## blocks with shards on top in two colors; each now has a body of its own.

static func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func recipes() -> Dictionary:
	return {
		"THE_FOREMAN": {"style": "tower", "sway": 0.5, "tint": "ffd45a", "accent": "fff4d6", "anchor": 3.6, "warden": true, "shadow": 2.8, "ring": 1.35, "parts": _foreman()},
		"THE_REGENT": {"style": "tower", "sway": 0.4, "tint": "9a7dff", "accent": "f0ecff", "anchor": 3.3, "warden": true, "shadow": 3.0, "ring": 1.45, "parts": _regent()},
		"THE_DRILL": {"style": "tower", "sway": 0.4, "tint": "6b625c", "accent": "ff5a2a", "anchor": 3.5, "warden": true, "shadow": 3.6, "ring": 1.7, "parts": _drill()},
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
		"PIT_MOLE": {"style": "low", "sway": 2.0, "tint": "7a5a42", "accent": "ffd06a", "anchor": 1.3, "shadow": 2.4, "parts": [
			## A hunched velvet body half out of the floor, a pointed snout and two great crystal claws.
			{"shape": "rock", "at": [0, 0.5, -0.1], "scale": [0.8, 0.6, 0.85], "material": "body", "motion": "core", "jitter": 0.2},
			{"shape": "cone", "at": [0, 0.55, 0.75], "rot": [90, 0, 0], "scale": [0.3, 0.5, 0.3], "material": "body", "radius": 1.0, "height": 1.0, "sides": 7},
			{"shape": "sphere", "at": [0, 0.55, 1.0], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "crystal", "at": [0.55, 0.25, 0.55], "rot": [60, 0, 20], "material": "accent", "motion": "crystal", "radius": 0.08, "height": 0.55},
			{"shape": "crystal", "at": [0.7, 0.25, 0.45], "rot": [60, 0, 35], "material": "accent", "motion": "crystal", "radius": 0.07, "height": 0.45},
			{"shape": "crystal", "at": [-0.55, 0.25, 0.55], "rot": [60, 0, -20], "material": "accent", "motion": "crystal", "radius": 0.08, "height": 0.55},
			{"shape": "crystal", "at": [-0.7, 0.25, 0.45], "rot": [60, 0, -35], "material": "accent", "motion": "crystal", "radius": 0.07, "height": 0.45},
			{"shape": "rock", "at": [0, 0.12, 0], "scale": [1.3, 0.14, 1.3], "material": "body", "jitter": 0.35, "seed": 3},
			{"shape": "rock", "at": [0.9, 0.1, -0.5], "scale": [0.3, 0.2, 0.3], "material": "body", "jitter": 0.3, "seed": 4},
			{"shape": "rock", "at": [-0.8, 0.1, 0.3], "scale": [0.25, 0.18, 0.25], "material": "body", "jitter": 0.3, "seed": 5}]}}

static func _foreman() -> Array:
	## A broad old foreman: a barrel chest, a hard hat with its lamp lit, his pick raised high
	## in one fist and a lantern in the other, amber crystals grown out of his back. The pick
	## and the hat are dark iron, so he reads as a man with a tool, not a block of light.
	var neck := [0, 2.28, 0.02]
	var right := [0.64, 2.06, 0.0]
	var left := [-0.64, 2.06, 0.0]
	var parts: Array = [
		{"shape": "rock", "at": [0, 1.66, 0], "scale": [0.7, 0.62, 0.48], "material": "body", "motion": "core", "jitter": 0.1, "seed": 41},
		{"shape": "rock", "at": [0, 1.12, 0.02], "scale": [0.52, 0.34, 0.4], "material": "body", "jitter": 0.1, "seed": 42},
		{"shape": "cylinder", "at": [0, 1.2, 0.02], "scale": [1.0, 1.0, 0.8], "material": "iron", "top": 0.56, "bottom": 0.56, "height": 0.16, "sides": 10},
		{"shape": "box", "at": [0, 1.2, 0.46], "material": "core", "size": [0.2, 0.14, 0.06]}]
	for side in [-1.0, 1.0]:
		## Two stout legs in iron-capped boots.
		parts.append({"shape": "cylinder", "from": [side * 0.28, 0.22, 0.04], "to": [side * 0.32, 1.1, 0.0], "material": "body", "top": 0.19, "bottom": 0.16, "sides": 7})
		parts.append({"shape": "slab", "at": [side * 0.28, 0.13, 0.12], "material": "iron", "size": [0.32, 0.26, 0.54], "jitter": 0.02})
	## The head, the hat and its lamp turn a little together, from the neck.
	for head in [
		{"shape": "rock", "at": [0, 2.48, 0.06], "scale": 0.26, "material": "body", "jitter": 0.08, "seed": 43},
		{"shape": "slab", "at": [0, 2.34, 0.17], "material": "body", "size": [0.34, 0.16, 0.26], "jitter": 0.02},
		{"shape": "sphere", "at": [0.1, 2.5, 0.3], "scale": 0.045, "material": "core", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "sphere", "at": [-0.1, 2.5, 0.3], "scale": 0.045, "material": "core", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "cap", "at": [0, 2.6, 0.04], "material": "iron", "radius": 0.36, "height": 0.3, "sides": 10, "seed": 44},
		{"shape": "cylinder", "at": [0, 2.6, 0.09], "material": "iron", "top": 0.44, "bottom": 0.44, "height": 0.04, "sides": 12},
		{"shape": "cylinder", "from": [0, 2.72, 0.2], "to": [0, 2.74, 0.42], "material": "iron", "top": 0.075, "bottom": 0.085, "sides": 8},
		{"shape": "sphere", "at": [0, 2.74, 0.44], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 8, "rings": 4}]:
		head.merge({"joint": neck, "motion": "block", "phase": 0.3})
		parts.append(head)
	## Amber crystals grown out of his back, over the shoulders.
	for spec in [[[0.3, 2.0, -0.3], [0.58, 2.78, -0.5], 0.09], [[-0.25, 2.05, -0.32], [-0.52, 2.72, -0.55], 0.08],
			[[0.05, 2.0, -0.38], [0.1, 3.0, -0.62], 0.1], [[0.45, 1.75, -0.3], [0.88, 2.3, -0.45], 0.07]]:
		parts.append({"shape": "crystal", "from": spec[0], "to": spec[1], "material": "core", "motion": "crystal", "radius": spec[2]})
	## The right arm raised, the pick high in its fist; it all swings from the shoulder.
	var fist := Vector3(1.02, 2.85, 0.32)
	var haft := Vector3(0.15, 0.85, -0.45).normalized()
	var head_at: Vector3 = fist + haft * 0.85
	var across: Vector3 = Vector3.BACK.cross(haft).normalized()
	var pick_tip: Vector3 = (across - haft * 0.35).normalized()
	var blade: Vector3 = (-across - haft * 0.35).normalized()
	for arm in [
		{"shape": "rock", "at": [0.66, 2.1, 0.0], "scale": [0.26, 0.22, 0.26], "material": "body", "jitter": 0.1, "seed": 45},
		{"shape": "cylinder", "from": [0.66, 2.04, 0.0], "to": [1.06, 2.28, 0.14], "material": "body", "top": 0.14, "bottom": 0.17, "sides": 7},
		{"shape": "cylinder", "from": [1.06, 2.28, 0.14], "to": [1.02, 2.8, 0.3], "material": "body", "top": 0.12, "bottom": 0.14, "sides": 7},
		{"shape": "rock", "at": _v(fist), "scale": 0.15, "material": "body", "jitter": 0.1, "seed": 46},
		{"shape": "cylinder", "from": _v(fist - haft * 0.3), "to": _v(head_at), "material": "iron", "top": 0.06, "bottom": 0.065, "sides": 6},
		{"shape": "cylinder", "from": _v(head_at - haft * 0.12), "to": _v(head_at + haft * 0.14), "material": "iron", "top": 0.11, "bottom": 0.11, "sides": 6},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at + pick_tip * 0.78), "material": "iron", "radius": 0.11, "sides": 5},
		{"shape": "cone", "from": _v(head_at), "to": _v(head_at + blade * 0.56), "material": "iron", "radius": 0.1, "sides": 4}]:
		arm.merge({"joint": right, "motion": "swing", "phase": 0.6})
		parts.append(arm)
	## The left arm down, a lantern hung from its fist.
	for arm in [
		{"shape": "rock", "at": [-0.66, 2.1, 0.0], "scale": [0.26, 0.22, 0.26], "material": "body", "jitter": 0.1, "seed": 47},
		{"shape": "cylinder", "from": [-0.66, 2.04, 0.0], "to": [-0.9, 1.56, 0.12], "material": "body", "top": 0.14, "bottom": 0.17, "sides": 7},
		{"shape": "cylinder", "from": [-0.9, 1.56, 0.12], "to": [-0.9, 1.18, 0.36], "material": "body", "top": 0.12, "bottom": 0.14, "sides": 7},
		{"shape": "rock", "at": [-0.9, 1.13, 0.38], "scale": 0.14, "material": "body", "jitter": 0.1, "seed": 48}]:
		arm.merge({"joint": left})
		parts.append(arm)
	for lamp in [
		{"shape": "cylinder", "from": [-0.9, 1.08, 0.38], "to": [-0.9, 0.96, 0.38], "material": "iron", "top": 0.02, "bottom": 0.02, "sides": 4},
		{"shape": "cone", "at": [-0.9, 0.92, 0.38], "material": "iron", "radius": 0.13, "height": 0.1, "sides": 6},
		{"shape": "cylinder", "at": [-0.9, 0.78, 0.38], "material": "core", "top": 0.09, "bottom": 0.09, "height": 0.2, "sides": 6},
		{"shape": "cylinder", "at": [-0.9, 0.66, 0.38], "material": "iron", "top": 0.12, "bottom": 0.12, "height": 0.05, "sides": 6}]:
		lamp.merge({"joint": [-0.9, 1.08, 0.38], "motion": "swing", "phase": 1.4})
		parts.append(lamp)
	return parts

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

static func _drill() -> Array:
	## A rusted mining rig on two iron tracks: a riveted boiler for a hull, a cab with a lit
	## window, a smokestack, and the great drill raised on its boom out front, so it shows
	## its whole length to the party instead of only its point.
	var axis := Vector3(0, 0.78, 0.62).normalized()
	var mount := Vector3(0, 2.0, 0.95)
	var parts: Array = [
		{"shape": "drill", "from": _v(mount + axis * 0.48), "to": _v(mount + axis * 2.08), "material": "accent", "motion": "drill", "radius": 0.44, "flutes": 3, "turns": 1.75},
		{"shape": "cylinder", "from": _v(mount - axis * 0.1), "to": _v(mount + axis * 0.5), "material": "body", "motion": "drill", "top": 0.32, "bottom": 0.36, "sides": 8},
		{"shape": "cylinder", "from": [0, 1.6, 0.3], "to": _v(mount), "material": "iron", "top": 0.13, "bottom": 0.15, "sides": 6},
		{"shape": "cylinder", "from": [0, 0.75, 0.42], "to": _v(mount + Vector3(0, -0.12, 0.02)), "material": "iron", "top": 0.09, "bottom": 0.1, "sides": 6},
		{"shape": "slab", "at": [0, 0.62, -0.35], "material": "iron", "size": [1.5, 0.3, 2.2], "jitter": 0.02},
		{"shape": "cylinder", "from": [0, 1.3, -1.45], "to": [0, 1.3, 0.3], "material": "body", "top": 0.6, "bottom": 0.64, "sides": 10},
		{"shape": "cylinder", "from": [0, 1.3, 0.28], "to": [0, 1.3, 0.36], "material": "iron", "top": 0.56, "bottom": 0.56, "sides": 10},
		{"shape": "box", "at": [0, 1.04, 0.38], "material": "accent", "size": [0.42, 0.14, 0.05]},
		{"shape": "slab", "at": [0, 2.12, -0.95], "material": "body", "size": [1.0, 0.78, 0.8], "jitter": 0.03},
		{"shape": "box", "at": [0, 2.25, -0.53], "material": "accent", "size": [0.7, 0.2, 0.05]},
		{"shape": "slab", "at": [0, 2.55, -0.95], "material": "iron", "size": [1.16, 0.1, 0.96], "jitter": 0.02},
		{"shape": "cylinder", "from": [0.42, 2.4, -1.35], "to": [0.42, 3.15, -1.35], "material": "iron", "top": 0.12, "bottom": 0.15, "sides": 8},
		{"shape": "sphere", "at": [0.42, 3.3, -1.35], "scale": 0.18, "material": "core", "motion": "flicker", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [-0.38, 2.7, -0.8], "scale": 0.12, "material": "accent", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "crystal", "from": [-0.3, 2.3, -1.35], "to": [-0.55, 2.95, -1.6], "material": "accent", "motion": "crystal", "radius": 0.1},
		{"shape": "crystal", "from": [0.05, 2.0, -1.5], "to": [0.1, 2.6, -1.85], "material": "accent", "motion": "crystal", "radius": 0.09}]
	## Riveted bands round the boiler.
	for z in [-1.15, -0.55, 0.05]:
		parts.append({"shape": "torus", "at": [0, 1.3, z], "aim": [0, 0, 1], "material": "iron", "inner": 0.6, "outer": 0.7, "rings": 12, "segments": 4})
	for side in [-1.0, 1.0]:
		## A track each side, its fender over it, three wheels turning on the outside.
		parts.append({"shape": "slab", "at": [side * 1.0, 0.42, -0.35], "material": "iron", "size": [0.56, 0.6, 2.0], "jitter": 0.02})
		for end in [-1.35, 0.65]:
			parts.append({"shape": "cylinder", "from": [side * 1.0 - 0.28, 0.42, end], "to": [side * 1.0 + 0.28, 0.42, end], "material": "iron", "top": 0.3, "bottom": 0.3, "sides": 10})
		parts.append({"shape": "slab", "at": [side * 1.0, 0.88, -0.35], "material": "body", "size": [0.6, 0.08, 2.5], "jitter": 0.02})
		for z in [-1.15, -0.35, 0.45]:
			parts.append({"shape": "cylinder", "from": [side * 1.42 - 0.04, 0.42, z], "to": [side * 1.42 + 0.04, 0.42, z], "material": "body", "motion": "spin", "phase": z, "top": 0.28, "bottom": 0.28, "sides": 6})
	return parts
