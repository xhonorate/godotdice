extends RefCounted
## Recipes for tools/creature_bake.gd: the Seeps. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var eel: Array = []
	## A long body arching out of the water: nine beads along a sine, thinning to the tail.
	for i in range(9):
		var t: float = float(i) / 8.0
		var x: float = lerpf(-1.3, 1.3, t)
		var y: float = 0.35 + sin(t * PI) * 0.9
		var r: float = 0.26 - t * 0.12
		eel.append({"shape": "sphere", "at": [x, y, 0], "scale": r, "material": "body", "motion": "core", "phase": float(i) * 0.6, "radius": 1.0, "segments": 7, "rings": 4})
		if i % 2 == 0 and i < 8:
			eel.append({"shape": "sphere", "at": [x, y + r * 0.5, r * 0.75], "scale": 0.07, "material": "accent", "motion": "core", "phase": float(i) * 0.6, "radius": 1.0, "segments": 5, "rings": 3})
	eel.append({"shape": "prism", "at": [0.0, 1.55, 0], "rot": [0, 90, 0], "material": "body", "motion": "wing", "side": 1.0, "size": [1.6, 0.35, 0.04]})
	eel.append({"shape": "cone", "at": [-1.45, 0.42, 0.18], "rot": [0, 0, 90], "scale": [0.16, 0.42, 0.16], "material": "body", "radius": 1.0, "height": 1.0, "sides": 6})
	eel.append({"shape": "sphere", "at": [-1.3, 0.5, 0.2], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
	var miner: Array = [
		{"shape": "slab", "at": [0, 0.95, 0], "material": "body", "motion": "block", "size": [0.6, 0.7, 0.36], "jitter": 0.04},
		{"shape": "cylinder", "at": [0.16, 0.3, 0], "material": "body", "top": 0.11, "bottom": 0.13, "height": 0.6, "sides": 6},
		{"shape": "cylinder", "at": [-0.16, 0.3, 0], "material": "body", "top": 0.11, "bottom": 0.13, "height": 0.6, "sides": 6},
		{"shape": "sphere", "at": [0, 1.48, 0.02], "scale": 0.2, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "cylinder", "at": [0, 1.62, 0.02], "material": "body", "top": 0.26, "bottom": 0.26, "height": 0.14, "sides": 8},
		{"shape": "sphere", "at": [0, 1.62, 0.28], "scale": 0.08, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "cylinder", "at": [0.42, 0.85, 0.1], "rot": [0, 0, -15], "material": "body", "top": 0.07, "bottom": 0.08, "height": 0.7, "sides": 5},
		{"shape": "cylinder", "at": [-0.42, 0.85, 0.1], "rot": [0, 0, 15], "material": "body", "top": 0.07, "bottom": 0.08, "height": 0.7, "sides": 5},
		{"shape": "cylinder", "at": [0.52, 0.9, 0.3], "rot": [0, 0, 8], "material": "body", "top": 0.04, "bottom": 0.04, "height": 1.3, "sides": 5},
		{"shape": "slab", "at": [0.52, 1.52, 0.3], "material": "body", "size": [0.5, 0.1, 0.12], "jitter": 0.02},
		{"shape": "cone", "at": [0.2, 1.3, 0.2], "rot": [180, 0, 20], "scale": [0.05, 0.45, 0.05], "material": "core", "motion": "swing", "phase": 0.3, "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cone", "at": [-0.28, 1.35, 0.1], "rot": [180, 0, -25], "scale": [0.05, 0.55, 0.05], "material": "core", "motion": "swing", "phase": 1.3, "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cone", "at": [0.05, 1.58, -0.2], "rot": [160, 0, 0], "scale": [0.04, 0.4, 0.04], "material": "core", "motion": "swing", "phase": 2.1, "radius": 1.0, "height": 1.0, "sides": 4}]
	var knot: Array = []
	for i in range(3):
		var a: float = float(i) * TAU / 3.0
		knot.append({"shape": "capsule", "at": [cos(a) * 0.25, 0.18 + float(i) * 0.08, sin(a) * 0.25], "rot": [80 + float(i) * 6, rad_to_deg(a), 20], "scale": [0.16, 0.6, 0.16], "material": "body", "motion": "core", "phase": float(i) * 1.1, "radius": 1.0, "height": 2.0, "segments": 7})
		var hx: float = cos(a) * 0.55
		var hz: float = sin(a) * 0.55
		knot.append({"shape": "torus", "at": [hx, 0.22 + float(i) * 0.1, hz], "rot": [0, -rad_to_deg(a) + 90, 0], "material": "body", "motion": "bob", "phase": float(i) * 0.9, "inner": 0.09, "outer": 0.17, "rings": 8, "segments": 6})
		knot.append({"shape": "sphere", "at": [hx, 0.22 + float(i) * 0.1, hz], "scale": 0.08, "material": "accent", "motion": "core", "phase": float(i) * 0.9, "radius": 1.0, "segments": 6, "rings": 3})
	var crayfish: Array = [
		{"shape": "rock", "at": [0, 0.32, -0.1], "scale": [0.5, 0.26, 0.7], "material": "body", "motion": "core", "jitter": 0.14, "seed": 11},
		{"shape": "rock", "at": [0, 0.3, -0.75], "scale": [0.36, 0.18, 0.4], "material": "body", "motion": "swing", "jitter": 0.14, "seed": 12},
		{"shape": "prism", "at": [0, 0.3, -1.15], "rot": [90, 0, 0], "material": "body", "motion": "swing", "phase": 0.6, "size": [0.6, 0.4, 0.05]},
		{"shape": "slab", "at": [0.5, 0.3, 0.6], "rot": [0, -20, 0], "material": "body", "motion": "swing", "phase": 1.0, "size": [0.32, 0.22, 0.55], "jitter": 0.06},
		{"shape": "slab", "at": [-0.5, 0.3, 0.6], "rot": [0, 20, 0], "material": "body", "motion": "swing", "phase": 2.0, "size": [0.32, 0.22, 0.55], "jitter": 0.06},
		{"shape": "cone", "at": [0.55, 0.3, 0.98], "rot": [90, 0, 0], "scale": [0.1, 0.3, 0.08], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cone", "at": [-0.55, 0.3, 0.98], "rot": [90, 0, 0], "scale": [0.1, 0.3, 0.08], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4},
		{"shape": "cylinder", "at": [0.12, 0.42, 0.55], "rot": [-50, 0, 15], "material": "accent", "motion": "swing", "phase": 0.2, "top": 0.015, "bottom": 0.02, "height": 0.9, "sides": 4},
		{"shape": "cylinder", "at": [-0.12, 0.42, 0.55], "rot": [-50, 0, -15], "material": "accent", "motion": "swing", "phase": 1.7, "top": 0.015, "bottom": 0.02, "height": 0.9, "sides": 4},
		{"shape": "sphere", "at": [0.14, 0.46, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.14, 0.46, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	for side in [-1.0, 1.0]:
		for leg in range(3):
			crayfish.append({"shape": "cylinder", "at": [side * 0.5, 0.14, 0.25 - float(leg) * 0.3], "rot": [0, 0, side * 55.0], "material": "body", "top": 0.03, "bottom": 0.03, "height": 0.4, "sides": 4})
	var keeper: Array = [
		{"shape": "rock", "at": [0, 1.65, -0.1], "scale": [1.0, 0.8, 0.7], "material": "body", "motion": "core", "jitter": 0.12, "seed": 21},
		{"shape": "cylinder", "at": [0.35, 0.5, 0], "material": "body", "top": 0.22, "bottom": 0.26, "height": 1.0, "sides": 7},
		{"shape": "cylinder", "at": [-0.35, 0.5, 0], "material": "body", "top": 0.22, "bottom": 0.26, "height": 1.0, "sides": 7},
		{"shape": "sphere", "at": [0, 2.45, 0.15], "scale": 0.32, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.12, 2.5, 0.42], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.12, 2.5, 0.42], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "cylinder", "at": [0.9, 1.7, 0.3], "rot": [0, 0, -30], "material": "body", "top": 0.14, "bottom": 0.17, "height": 1.1, "sides": 6},
		{"shape": "cylinder", "at": [-0.9, 1.7, 0.3], "rot": [0, 0, 30], "material": "body", "top": 0.14, "bottom": 0.17, "height": 1.1, "sides": 6},
		{"shape": "torus", "at": [0, 1.45, 0.95], "rot": [90, 0, 0], "material": "accent", "motion": "spin", "inner": 0.5, "outer": 0.62, "rings": 10, "segments": 6},
		{"shape": "box", "at": [0, 1.45, 0.95], "material": "accent", "motion": "spin", "size": [1.1, 0.08, 0.08]},
		{"shape": "box", "at": [0, 1.45, 0.95], "rot": [0, 0, 90], "material": "accent", "motion": "spin", "size": [1.1, 0.08, 0.08]},
		{"shape": "slab", "at": [0, 1.9, -0.75], "material": "core", "motion": "block", "size": [1.5, 2.2, 0.18], "jitter": 0.02},
		{"shape": "box", "at": [0, 1.9, -0.86], "material": "body", "size": [1.7, 0.14, 0.12]},
		{"shape": "box", "at": [0, 2.6, -0.86], "material": "body", "size": [1.7, 0.14, 0.12]},
		{"shape": "box", "at": [0, 1.2, -0.86], "material": "body", "size": [1.7, 0.14, 0.12]}]
	var choir: Array = [
		{"shape": "rock", "at": [0, 1.0, 0], "scale": [1.3, 0.95, 0.9], "material": "body", "motion": "core", "jitter": 0.14, "seed": 31},
		{"shape": "rock", "at": [0, 0.3, 0], "scale": [1.5, 0.3, 1.1], "material": "body", "jitter": 0.2, "seed": 32}]
	for i in range(3):
		var x: float = [-0.6, 0.0, 0.6][i]
		var h: float = [2.0, 2.45, 2.15][i]
		choir.append({"shape": "cylinder", "at": [x, (h + 1.6) * 0.5, 0.1], "rot": [0, 0, -x * 18.0], "material": "body", "motion": "swing", "phase": float(i) * 1.2, "top": 0.14, "bottom": 0.2, "height": h - 1.6, "sides": 6})
		choir.append({"shape": "sphere", "at": [x * 1.08, h + 0.22, 0.15], "scale": 0.3, "material": "body", "motion": "bob", "phase": float(i) * 1.2, "radius": 1.0, "segments": 7, "rings": 4})
		choir.append({"shape": "torus", "at": [x * 1.08, h + 0.1, 0.42], "rot": [90, 0, 0], "material": "accent", "motion": "core", "phase": float(i) * 1.2, "inner": 0.05, "outer": 0.1, "rings": 6, "segments": 5})
		choir.append({"shape": "sphere", "at": [x * 1.08 + 0.1, h + 0.32, 0.4], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
		choir.append({"shape": "sphere", "at": [x * 1.08 - 0.1, h + 0.32, 0.4], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
		choir.append({"shape": "cone", "at": [x * 1.08 + 0.2, h + 0.1, -0.1], "rot": [180, 0, 15], "scale": [0.05, 0.6, 0.05], "material": "core", "motion": "swing", "phase": float(i) * 0.7, "radius": 1.0, "height": 1.0, "sides": 4})
	var undertow: Array = []
	## A thick coil: out of the floor at the back, over the top, and down into the jaws at the front.
	for i in range(11):
		var t: float = float(i) / 10.0
		var z: float = lerpf(-1.9, 1.3, t)
		var y: float = 0.2 + sin(t * PI) * 1.9
		var r: float = 0.42 - absf(t - 0.5) * 0.25
		undertow.append({"shape": "sphere", "at": [sin(t * TAU) * 0.3, y, z], "scale": r, "material": "body", "motion": "core", "phase": float(i) * 0.5, "radius": 1.0, "segments": 8, "rings": 4})
		if i % 2 == 1:
			undertow.append({"shape": "sphere", "at": [sin(t * TAU) * 0.3 + r * 0.8, y + r * 0.3, z], "scale": 0.09, "material": "accent", "motion": "core", "phase": float(i) * 0.5, "radius": 1.0, "segments": 5, "rings": 3})
			undertow.append({"shape": "prism", "at": [sin(t * TAU) * 0.3, y + r, z], "rot": [0, 0, 0], "material": "body", "motion": "wing", "side": 1.0, "phase": float(i) * 0.4, "size": [0.08, 0.5, 0.5]})
	undertow.append({"shape": "sphere", "at": [0, 0.55, 1.75], "scale": [0.55, 0.45, 0.6], "material": "body", "motion": "bob", "radius": 1.0, "segments": 8, "rings": 4})
	undertow.append({"shape": "slab", "at": [0, 0.3, 2.05], "rot": [20, 0, 0], "material": "body", "motion": "swing", "size": [0.9, 0.16, 0.7], "jitter": 0.04})
	for k in range(5):
		undertow.append({"shape": "cone", "at": [-0.36 + float(k) * 0.18, 0.72, 2.25], "rot": [180, 0, 0], "scale": [0.05, 0.22, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
		undertow.append({"shape": "cone", "at": [-0.36 + float(k) * 0.18, 0.36, 2.3], "scale": [0.05, 0.22, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	undertow.append({"shape": "sphere", "at": [0.3, 0.85, 2.0], "scale": 0.12, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3})
	undertow.append({"shape": "sphere", "at": [-0.3, 0.85, 2.0], "scale": 0.12, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3})
	return {
		"SEEP_EEL": {"style": "long", "sway": 1.4, "tint": "2f7f86", "accent": "7affe0", "anchor": 1.9, "shadow": 3.2, "ring": 1.5, "parts": eel},
		"DROWNED_MINER": {"style": "low", "sway": 1.1, "tint": "4c6e72", "accent": "ffe08a", "anchor": 2.0, "shadow": 1.6, "parts": miner},
		"LAMPREY_KNOT": {"style": "blob", "sway": 2.4, "tint": "b08a94", "accent": "ff7a8a", "anchor": 0.9, "shadow": 1.8, "parts": knot},
		"CAVE_CRAYFISH": {"style": "low", "sway": 1.8, "tint": "3a6a8a", "accent": "bfefff", "anchor": 1.0, "shadow": 2.4, "parts": crayfish},
		"THE_LOCKKEEPER": {"style": "tower", "sway": 0.6, "tint": "3a7a80", "accent": "ffd06a", "anchor": 3.3, "warden": true, "shadow": 3.4, "ring": 1.6, "parts": keeper},
		"THE_DROWNED_CHOIR": {"style": "tower", "sway": 0.7, "tint": "5fa8a0", "accent": "d8fff4", "anchor": 3.3, "warden": true, "shadow": 3.4, "ring": 1.6, "parts": choir},
		"THE_UNDERTOW": {"style": "long", "sway": 0.6, "tint": "1f5f66", "accent": "7affe0", "anchor": 2.6, "warden": true, "shadow": 4.0, "ring": 1.9, "parts": undertow}}
