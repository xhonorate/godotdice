extends RefCounted
## Recipes for tools/creature_bake.gd: the Warrens. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var shambler: Array = [
		{"shape": "cylinder", "at": [0, 0.75, 0], "material": "body", "motion": "core", "top": 0.3, "bottom": 0.36, "height": 0.9, "sides": 7},
		{"shape": "cap", "at": [0, 1.2, 0], "material": "body", "motion": "bob", "radius": 0.95, "height": 0.5, "sides": 9},
		{"shape": "cylinder", "at": [0.18, 0.18, 0.05], "material": "body", "top": 0.12, "bottom": 0.15, "height": 0.36, "sides": 6},
		{"shape": "cylinder", "at": [-0.18, 0.18, 0.05], "material": "body", "top": 0.12, "bottom": 0.15, "height": 0.36, "sides": 6},
		{"shape": "sphere", "at": [0.14, 1.0, 0.33], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.14, 1.0, 0.33], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [0.4, 1.5, 0.3], "scale": 0.1, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.3, 1.58, -0.2], "scale": 0.12, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [0.1, 1.64, -0.45], "scale": 0.08, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.45, 1.42, 0.45], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	var weaver: Array = [
		{"shape": "sphere", "at": [0, 0.55, -0.25], "scale": [0.42, 0.36, 0.5], "material": "body", "motion": "core", "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "sphere", "at": [0, 0.5, 0.35], "scale": 0.22, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.08, 0.56, 0.55], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.08, 0.56, 0.55], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [0.16, 0.5, 0.52], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 4, "rings": 2},
		{"shape": "sphere", "at": [-0.16, 0.5, 0.52], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 4, "rings": 2},
		{"shape": "cylinder", "at": [0, 1.1, -0.25], "material": "core", "top": 0.01, "bottom": 0.01, "height": 1.1, "sides": 3},
		{"shape": "sphere", "at": [0.0, 0.62, -0.7], "scale": 0.09, "material": "accent", "motion": "core", "radius": 1.0, "segments": 5, "rings": 3}]
	for side in [-1.0, 1.0]:
		for leg in range(4):
			var z: float = 0.35 - float(leg) * 0.28
			weaver.append({"shape": "cylinder", "at": [side * 0.42, 0.55, z], "rot": [0, 0, side * 60.0], "material": "body", "motion": "swing", "phase": float(leg) * 0.9 + (0.0 if side > 0 else 1.6), "top": 0.025, "bottom": 0.03, "height": 0.7, "sides": 4})
			weaver.append({"shape": "cylinder", "at": [side * 0.78, 0.3, z], "rot": [0, 0, side * -70.0], "material": "body", "top": 0.02, "bottom": 0.025, "height": 0.62, "sides": 4})
	var puffball: Array = [
		{"shape": "rock", "at": [0, 0.5, 0], "scale": 0.55, "material": "body", "motion": "core", "jitter": 0.12, "seed": 61},
		{"shape": "sphere", "at": [0, 0.5, 0.0], "scale": 0.5, "material": "core", "motion": "core", "phase": 0.6, "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "cylinder", "at": [0, 0.12, 0], "material": "body", "top": 0.3, "bottom": 0.42, "height": 0.25, "sides": 7}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.3
		puffball.append({"shape": "sphere", "at": [cos(a) * 0.46, 0.62 + sin(a * 1.7) * 0.2, sin(a) * 0.46], "scale": 0.07, "material": "accent", "motion": "core", "phase": a, "radius": 1.0, "segments": 5, "rings": 3})
		if i % 2 == 0:
			puffball.append({"shape": "crystal", "at": [cos(a) * 0.3, 0.95, sin(a) * 0.3], "rot": [cos(a) * 30.0, 0, -sin(a) * 30.0], "material": "accent", "motion": "crystal", "phase": a, "radius": 0.03, "height": 0.22})
	var roots: Array = [
		{"shape": "rock", "at": [0, 0.7, 0], "scale": [0.7, 0.6, 0.6], "material": "body", "motion": "core", "jitter": 0.2, "seed": 71},
		{"shape": "torus", "at": [0, 0.75, 0.55], "rot": [90, 0, 0], "material": "body", "motion": "core", "phase": 0.8, "inner": 0.18, "outer": 0.36, "rings": 10, "segments": 6},
		{"shape": "sphere", "at": [0, 0.75, 0.5], "scale": 0.2, "material": "accent", "motion": "core", "phase": 0.8, "radius": 1.0, "segments": 6, "rings": 3}]
	for k in range(6):
		var a: float = float(k) * TAU / 6.0
		roots.append({"shape": "cone", "at": [cos(a) * 0.3, 0.75 + sin(a) * 0.3, 0.75], "rot": [90, 0, 0], "scale": [0.05, 0.14, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	for i in range(9):
		var a: float = float(i) * TAU / 9.0 + 0.2
		var reach: float = 0.9 + 0.3 * float(i % 3)
		roots.append({"shape": "capsule", "at": [cos(a) * reach * 0.6, 0.25 + 0.15 * float(i % 2), sin(a) * reach * 0.6 - 0.2], "rot": [sin(a) * 70.0, 0, -cos(a) * 70.0], "scale": [0.09 + 0.02 * float(i % 2), reach * 0.5, 0.09], "material": "body", "motion": "swing", "phase": a, "radius": 1.0, "height": 2.0, "segments": 5})
	## The Gardener: a great beetle with a garden growing on its back.
	var gardener: Array = [
		{"shape": "rock", "at": [0, 1.0, -0.1], "scale": [1.05, 0.55, 1.3], "material": "body", "motion": "core", "jitter": 0.1, "seed": 71},
		{"shape": "rock", "at": [0, 1.42, -0.15], "scale": [0.9, 0.22, 1.1], "material": "core", "motion": "core", "phase": 0.5, "jitter": 0.08, "seed": 72},
		{"shape": "rock", "at": [0, 0.85, 1.25], "scale": [0.45, 0.35, 0.4], "material": "body", "motion": "bob", "jitter": 0.1, "seed": 73}]
	for side in [-1.0, 1.0]:
		gardener.append({"shape": "spike", "at": [side * 0.18, 0.72, 1.5], "rot": [80, 0, -side * 22.0], "material": "body", "radius": 0.07, "height": 0.5, "sides": 4})
		gardener.append({"shape": "sphere", "at": [side * 0.2, 0.98, 1.55], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
		for leg in range(3):
			var z: float = 0.55 - 0.6 * float(leg)
			gardener.append({"shape": "cylinder", "at": [side * 1.1, 0.38, z], "rot": [0, 0, side * 34.0], "material": "body", "motion": "swing", "phase": float(leg) * 1.1 + (0.0 if side > 0 else 1.6), "top": 0.06, "bottom": 0.09, "height": 0.9, "sides": 5})
	var beds: Array = [[0.45, 0.2, 0.36], [-0.42, -0.35, 0.32], [0.12, -0.85, 0.4], [-0.18, 0.5, 0.24], [0.55, -0.55, 0.2], [-0.55, -0.95, 0.18]]
	for i in range(beds.size()):
		var bed: Array = beds[i]
		var tall: float = 0.2 + 0.35 * float(bed[2])
		gardener.append({"shape": "cylinder", "at": [bed[0], 1.5 + tall * 0.5, bed[1]], "material": "core", "top": 0.04, "bottom": 0.07, "height": tall, "sides": 5})
		gardener.append({"shape": "cap", "at": [bed[0], 1.5 + tall, bed[1]], "rot": [6.0 * float(i % 3 - 1), 0, 8.0 * float(i % 2 * 2 - 1)], "material": "accent", "motion": "bob", "phase": float(i) * 0.9, "radius": bed[2], "height": float(bed[2]) * 0.55, "sides": 7})
	for i in range(4):
		gardener.append({"shape": "crystal", "at": [-0.6 + 0.4 * float(i), 1.48, 0.3 - 0.5 * float(i)], "rot": [10, 0, 15.0 * float(i % 2 * 2 - 1)], "material": "core", "motion": "crystal", "phase": float(i) * 1.3, "radius": 0.04, "height": 0.35})
	var mother: Array = [
		{"shape": "sphere", "at": [0, 1.7, 0], "scale": [1.3, 1.1, 1.2], "material": "core", "motion": "core", "radius": 1.0, "segments": 10, "rings": 5},
		{"shape": "rock", "at": [0, 2.4, -0.2], "scale": [0.8, 0.5, 0.7], "material": "body", "motion": "core", "phase": 0.7, "jitter": 0.15, "seed": 81},
		{"shape": "sphere", "at": [0, 2.1, 1.0], "scale": 0.3, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.12, 2.18, 1.26], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.12, 2.18, 1.26], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.5
		mother.append({"shape": "cylinder", "at": [cos(a) * 0.9, 0.55, sin(a) * 0.9], "rot": [sin(a) * 28.0, 0, -cos(a) * 28.0], "material": "body", "motion": "swing", "phase": a, "top": 0.1, "bottom": 0.14, "height": 1.3, "sides": 5})
		mother.append({"shape": "sphere", "at": [cos(a) * 0.7, 0.85, sin(a) * 0.7], "scale": 0.17, "material": "accent", "motion": "core", "phase": a, "radius": 1.0, "segments": 6, "rings": 3})
		if i % 2 == 0:
			mother.append({"shape": "crystal", "at": [cos(a) * 0.5, 2.75, sin(a) * 0.5], "rot": [cos(a) * 25.0, 0, -sin(a) * 25.0], "material": "accent", "motion": "crystal", "phase": a, "radius": 0.07, "height": 0.5})
	var heart: Array = [
		{"shape": "sphere", "at": [0.45, 1.9, 0], "scale": [0.85, 0.9, 0.8], "material": "core", "motion": "core", "radius": 1.0, "segments": 9, "rings": 5},
		{"shape": "sphere", "at": [-0.45, 1.9, 0], "scale": [0.85, 0.9, 0.8], "material": "core", "motion": "core", "phase": 0.4, "radius": 1.0, "segments": 9, "rings": 5},
		{"shape": "cone", "at": [0, 0.95, 0], "rot": [180, 0, 0], "material": "core", "motion": "core", "phase": 0.8, "radius": 0.95, "height": 1.3, "sides": 8},
		{"shape": "sphere", "at": [0, 2.2, 0.72], "scale": 0.3, "material": "accent", "motion": "core", "phase": 1.2, "radius": 1.0, "segments": 7, "rings": 4}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.25
		heart.append({"shape": "column", "at": [cos(a) * 1.1, 0.0, sin(a) * 1.1], "rot": [-sin(a) * 25.0, 0, cos(a) * 25.0], "material": "body", "sides": 5, "radius": 0.2, "height": 1.2})
		heart.append({"shape": "capsule", "at": [cos(a) * 0.75, 2.0 + 0.3 * float(i % 2), sin(a) * 0.75 + 0.1], "rot": [sin(a) * 60.0, rad_to_deg(a), cos(a) * 60.0], "scale": [0.07, 0.6, 0.07], "material": "body", "motion": "swing", "phase": a, "radius": 1.0, "height": 2.0, "segments": 5})
	var tendril: Array = [
		{"shape": "cylinder", "at": [0, 0.45, 0], "material": "body", "motion": "core", "top": 0.18, "bottom": 0.26, "height": 0.9, "sides": 6},
		{"shape": "capsule", "at": [0, 1.15, 0.2], "rot": [25, 0, 0], "scale": [0.16, 0.5, 0.16], "material": "body", "motion": "swing", "phase": 0.4, "radius": 1.0, "height": 2.0, "segments": 6},
		{"shape": "capsule", "at": [0, 1.65, 0.6], "rot": [60, 0, 0], "scale": [0.12, 0.45, 0.12], "material": "body", "motion": "swing", "phase": 0.9, "radius": 1.0, "height": 2.0, "segments": 6},
		{"shape": "crystal", "at": [0, 1.75, 1.05], "rot": [100, 0, 0], "material": "accent", "motion": "crystal", "radius": 0.07, "height": 0.5},
		{"shape": "sphere", "at": [0, 0.9, 0.22], "scale": 0.08, "material": "accent", "motion": "core", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [0.05, 1.45, 0.5], "scale": 0.07, "material": "accent", "motion": "core", "phase": 0.5, "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "rock", "at": [0, 0.08, 0], "scale": [0.6, 0.1, 0.6], "material": "body", "jitter": 0.3, "seed": 91}]
	return {
		"CAP_SHAMBLER": {"style": "stack", "sway": 1.3, "tint": "c85a8a", "accent": "c8ff6a", "anchor": 1.9, "shadow": 2.2, "parts": shambler},
		"MYCEL_WEAVER": {"style": "low", "sway": 2.6, "tint": "4a6a3a", "accent": "c8ff6a", "anchor": 1.3, "shadow": 2.2, "parts": weaver},
		"PUFFBALL": {"style": "puff", "sway": 1.3, "tint": "e8e0a0", "accent": "a8c84a", "anchor": 1.3, "shadow": 1.6, "ring": 0.8, "parts": puffball},
		"ROOT_HORROR": {"style": "blob", "sway": 1.0, "tint": "6a5232", "accent": "e0ff8a", "anchor": 1.6, "shadow": 2.8, "ring": 1.3, "parts": roots},
		"THE_GARDENER": {"style": "low", "sway": 0.8, "tint": "5a7a3a", "accent": "ffb0e0", "anchor": 2.5, "warden": true, "shadow": 3.4, "ring": 1.7, "parts": gardener},
		"THE_SPORE_MOTHER": {"style": "blob", "sway": 0.8, "tint": "b8c84a", "accent": "ff8ae0", "anchor": 3.3, "warden": true, "shadow": 3.6, "ring": 1.7, "parts": mother},
		"THE_HEARTROT": {"style": "blob", "sway": 1.6, "tint": "5a7a2a", "accent": "ff5ab0", "anchor": 3.2, "warden": true, "shadow": 3.6, "ring": 1.7, "parts": heart},
		"TENDRIL": {"style": "long", "sway": 1.4, "tint": "5a7a2a", "accent": "ff5ab0", "anchor": 2.3, "shadow": 1.6, "ring": 0.8, "parts": tendril}}
