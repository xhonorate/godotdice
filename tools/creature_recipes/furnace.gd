extends RefCounted
## Recipes for tools/creature_bake.gd: the Furnace. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var salamander: Array = [
		{"shape": "capsule", "at": [0, 0.3, 0], "rot": [90, 0, 0], "scale": [0.3, 0.75, 0.3], "material": "body", "motion": "core", "radius": 1.0, "height": 2.0, "segments": 7},
		{"shape": "sphere", "at": [0, 0.33, 0.95], "scale": [0.24, 0.2, 0.3], "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.1, 0.4, 1.12], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.1, 0.4, 1.12], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "capsule", "at": [0, 0.26, -1.15], "rot": [85, 0, 0], "scale": [0.1, 0.6, 0.1], "material": "body", "motion": "swing", "radius": 1.0, "height": 2.0, "segments": 5}]
	for i in range(5):
		salamander.append({"shape": "cone", "at": [0, 0.62, 0.6 - float(i) * 0.3], "rot": [-15, 0, 0], "scale": [0.12, 0.35 - float(absi(i - 2)) * 0.04, 0.1], "material": "accent", "motion": "flicker", "phase": float(i) * 0.9, "radius": 1.0, "height": 1.0, "sides": 5})
	for side in [-1.0, 1.0]:
		for leg in range(2):
			salamander.append({"shape": "cylinder", "at": [side * 0.36, 0.14, 0.5 - float(leg) * 0.9], "rot": [0, 0, side * 50.0], "material": "body", "top": 0.05, "bottom": 0.06, "height": 0.4, "sides": 5})
	var hound: Array = [
		{"shape": "rock", "at": [0, 0.75, -0.1], "scale": [0.5, 0.42, 0.8], "material": "body", "motion": "core", "jitter": 0.18, "seed": 101},
		{"shape": "rock", "at": [0, 0.95, 0.75], "scale": [0.36, 0.3, 0.42], "material": "body", "motion": "bob", "jitter": 0.16, "seed": 102},
		{"shape": "slab", "at": [0, 0.78, 1.05], "rot": [10, 0, 0], "material": "body", "motion": "swing", "size": [0.4, 0.14, 0.4], "jitter": 0.04},
		{"shape": "sphere", "at": [0.14, 1.05, 1.05], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.14, 1.05, 1.05], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "slab", "at": [0, 1.15, -0.1], "material": "accent", "motion": "core", "phase": 0.5, "size": [0.3, 0.1, 1.2], "jitter": 0.1},
		{"shape": "crystal", "at": [0.12, 1.15, -0.3], "rot": [10, 0, -20], "material": "accent", "motion": "crystal", "radius": 0.05, "height": 0.3},
		{"shape": "crystal", "at": [-0.1, 1.15, 0.2], "rot": [-10, 0, 25], "material": "accent", "motion": "crystal", "radius": 0.05, "height": 0.26},
		{"shape": "cone", "at": [0, 0.9, -0.85], "rot": [-120, 0, 0], "scale": [0.08, 0.35, 0.08], "material": "body", "motion": "swing", "radius": 1.0, "height": 1.0, "sides": 5}]
	for side in [-1.0, 1.0]:
		for leg in range(2):
			hound.append({"shape": "cylinder", "at": [side * 0.3, 0.3, 0.45 - float(leg) * 0.9], "rot": [0, 0, side * 10.0], "material": "body", "top": 0.08, "bottom": 0.1, "height": 0.6, "sides": 5})
	var imp: Array = [
		{"shape": "sphere", "at": [0, 0.6, 0], "scale": [0.26, 0.3, 0.24], "material": "body", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0, 1.02, 0.02], "scale": 0.2, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "cone", "at": [0.12, 1.22, 0], "rot": [0, 0, -25], "scale": [0.05, 0.25, 0.05], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
		{"shape": "cone", "at": [-0.12, 1.22, 0], "rot": [0, 0, 25], "scale": [0.05, 0.25, 0.05], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
		{"shape": "sphere", "at": [0.08, 1.05, 0.18], "scale": 0.045, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.08, 1.05, 0.18], "scale": 0.045, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "cylinder", "at": [0.1, 0.17, 0.02], "material": "body", "top": 0.06, "bottom": 0.07, "height": 0.34, "sides": 5},
		{"shape": "cylinder", "at": [-0.1, 0.17, 0.02], "material": "body", "top": 0.06, "bottom": 0.07, "height": 0.34, "sides": 5},
		{"shape": "cylinder", "at": [0.3, 0.9, 0.1], "rot": [0, 0, -40], "material": "body", "top": 0.04, "bottom": 0.05, "height": 0.5, "sides": 5},
		{"shape": "cylinder", "at": [0.5, 1.35, 0.1], "rot": [0, 0, 10], "material": "body", "motion": "swing", "phase": 0.3, "top": 0.03, "bottom": 0.03, "height": 0.8, "sides": 4},
		{"shape": "slab", "at": [0.57, 1.75, 0.1], "material": "accent", "motion": "swing", "phase": 0.3, "size": [0.36, 0.2, 0.2], "jitter": 0.02},
		{"shape": "cylinder", "at": [-0.3, 0.7, 0.1], "rot": [0, 0, 30], "material": "body", "top": 0.04, "bottom": 0.05, "height": 0.45, "sides": 5}]
	var crawler: Array = []
	for i in range(9):
		var t: float = float(i) / 8.0
		var z: float = lerpf(1.3, -1.3, t)
		var x: float = sin(t * TAU) * 0.3
		crawler.append({"shape": "sphere", "at": [x, 0.26, z], "scale": [0.2, 0.18, 0.22], "material": "body", "motion": "core", "phase": float(i) * 0.6, "radius": 1.0, "segments": 7, "rings": 4})
		if i < 8:
			var nx: float = sin((t + 0.125) * TAU) * 0.3
			crawler.append({"shape": "sphere", "at": [(x + nx) * 0.5, 0.26, z - 0.1625], "scale": 0.1, "material": "accent", "motion": "core", "phase": float(i) * 0.6 + 0.3, "radius": 1.0, "segments": 5, "rings": 3})
		if i % 2 == 0:
			for side in [-1.0, 1.0]:
				crawler.append({"shape": "cylinder", "at": [x + side * 0.26, 0.14, z], "rot": [0, 0, side * 60.0], "material": "body", "motion": "swing", "phase": float(i) + (0.0 if side > 0 else 1.5), "top": 0.025, "bottom": 0.03, "height": 0.32, "sides": 4})
	crawler.append({"shape": "cone", "at": [0.12, 0.3, 1.52], "rot": [90, 0, 10], "scale": [0.05, 0.22, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	crawler.append({"shape": "cone", "at": [-0.12, 0.3, 1.52], "rot": [90, 0, -10], "scale": [0.05, 0.22, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	var smelter: Array = [
		{"shape": "rock", "at": [0, 1.7, -0.1], "scale": [1.2, 0.95, 0.9], "material": "body", "motion": "core", "jitter": 0.14, "seed": 111},
		{"shape": "cylinder", "at": [0, 1.45, 0.55], "rot": [15, 0, 0], "material": "body", "top": 0.52, "bottom": 0.42, "height": 0.7, "sides": 8},
		{"shape": "cylinder", "at": [0, 1.78, 0.64], "rot": [15, 0, 0], "material": "accent", "motion": "core", "phase": 0.6, "top": 0.44, "bottom": 0.44, "height": 0.1, "sides": 8},
		{"shape": "sphere", "at": [0, 2.55, 0.1], "scale": 0.28, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.1, 2.6, 0.35], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.1, 2.6, 0.35], "scale": 0.06, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "cylinder", "at": [0.4, 0.5, 0], "material": "body", "top": 0.24, "bottom": 0.3, "height": 1.0, "sides": 7},
		{"shape": "cylinder", "at": [-0.4, 0.5, 0], "material": "body", "top": 0.24, "bottom": 0.3, "height": 1.0, "sides": 7},
		{"shape": "cylinder", "at": [1.05, 1.5, 0.1], "rot": [0, 0, -20], "material": "body", "motion": "swing", "phase": 0.2, "top": 0.2, "bottom": 0.24, "height": 1.3, "sides": 6},
		{"shape": "cylinder", "at": [-1.05, 1.5, 0.1], "rot": [0, 0, 20], "material": "body", "motion": "swing", "phase": 1.4, "top": 0.2, "bottom": 0.24, "height": 1.3, "sides": 6},
		{"shape": "crystal", "at": [0.2, 1.9, 0.75], "rot": [-15, 0, 10], "material": "accent", "motion": "flicker", "radius": 0.05, "height": 0.35},
		{"shape": "crystal", "at": [-0.25, 1.9, 0.7], "rot": [-15, 0, -15], "material": "accent", "motion": "flicker", "phase": 0.7, "radius": 0.05, "height": 0.3}]
	var knight: Array = [
		{"shape": "slab", "at": [0, 1.8, 0], "material": "body", "motion": "block", "size": [1.1, 1.2, 0.7], "jitter": 0.03},
		{"shape": "slab", "at": [0.3, 0.6, 0], "material": "body", "size": [0.38, 1.2, 0.42], "jitter": 0.03},
		{"shape": "slab", "at": [-0.3, 0.6, 0], "material": "body", "size": [0.38, 1.2, 0.42], "jitter": 0.03},
		{"shape": "cylinder", "at": [0, 2.75, 0.02], "material": "body", "motion": "bob", "top": 0.3, "bottom": 0.32, "height": 0.6, "sides": 8},
		{"shape": "cone", "at": [0, 3.15, 0.02], "material": "body", "radius": 0.33, "height": 0.3, "sides": 8},
		{"shape": "box", "at": [0, 2.78, 0.3], "material": "accent", "motion": "core", "size": [0.4, 0.06, 0.1]},
		{"shape": "cylinder", "at": [0.85, 1.75, 0.2], "rot": [0, 0, -20], "material": "body", "top": 0.17, "bottom": 0.19, "height": 1.0, "sides": 6},
		{"shape": "cylinder", "at": [-0.85, 1.75, 0.2], "rot": [0, 0, 20], "material": "body", "top": 0.17, "bottom": 0.19, "height": 1.0, "sides": 6},
		{"shape": "box", "at": [-1.15, 1.5, 0.55], "rot": [0, 20, 0], "material": "core", "motion": "swing", "phase": 0.4, "size": [0.9, 0.5, 0.35]},
		{"shape": "prism", "at": [-1.15, 1.0, 0.55], "rot": [180, 20, 0], "material": "core", "motion": "swing", "phase": 0.4, "size": [0.5, 0.5, 0.35]},
		{"shape": "cylinder", "at": [1.1, 2.2, 0.4], "rot": [0, 0, 15], "material": "body", "motion": "swing", "phase": 1.1, "top": 0.05, "bottom": 0.05, "height": 1.2, "sides": 5},
		{"shape": "slab", "at": [1.25, 2.8, 0.4], "material": "body", "motion": "swing", "phase": 1.1, "size": [0.5, 0.3, 0.3], "jitter": 0.02},
		{"shape": "crystal", "at": [0.0, 2.3, 0.37], "material": "accent", "motion": "crystal", "radius": 0.06, "height": 0.35}]
	var wyrm: Array = []
	for i in range(8):
		var t: float = float(i) / 7.0
		var z: float = lerpf(-2.1, 0.9, t)
		var y: float = 0.5 + sin(t * PI * 0.9) * 1.4 + t * 0.4
		var r: float = 0.46 - absf(t - 0.4) * 0.3
		wyrm.append({"shape": "rock", "at": [0, y, z], "scale": r, "material": "body", "motion": "core", "phase": float(i) * 0.5, "jitter": 0.14, "seed": 120 + i})
		if i % 2 == 1:
			wyrm.append({"shape": "crystal", "at": [0, y + r * 0.9, z], "rot": [-20, 0, 0], "material": "accent", "motion": "flicker", "phase": float(i) * 0.7, "radius": 0.08, "height": 0.4})
	wyrm.append({"shape": "rock", "at": [0, 2.55, 1.35], "scale": [0.5, 0.42, 0.62], "material": "body", "motion": "bob", "jitter": 0.12, "seed": 131})
	wyrm.append({"shape": "slab", "at": [0, 2.32, 1.7], "rot": [15, 0, 0], "material": "body", "motion": "swing", "size": [0.7, 0.14, 0.7], "jitter": 0.04})
	for k in range(4):
		wyrm.append({"shape": "cone", "at": [-0.27 + float(k) * 0.18, 2.5, 1.95], "rot": [180, 0, 0], "scale": [0.05, 0.2, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	wyrm.append({"shape": "sphere", "at": [0.25, 2.75, 1.65], "scale": 0.1, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3})
	wyrm.append({"shape": "sphere", "at": [-0.25, 2.75, 1.65], "scale": 0.1, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3})
	wyrm.append({"shape": "cone", "at": [0.2, 2.95, 1.15], "rot": [-30, 0, -20], "scale": [0.08, 0.4, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5})
	wyrm.append({"shape": "cone", "at": [-0.2, 2.95, 1.15], "rot": [-30, 0, 20], "scale": [0.08, 0.4, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5})
	for side in [-1.0, 1.0]:
		wyrm.append({"shape": "prism", "at": [side * 0.5, 2.2, -0.4], "rot": [0, 0, side * 20.0], "material": "body", "motion": "wing", "side": side, "offset": [side * 1.0, 0.3, 0.0], "size": [2.0, 1.2, 0.05]})
		wyrm.append({"shape": "cylinder", "at": [side * 0.55, 0.45, 0.4], "rot": [0, 0, side * 15.0], "material": "body", "top": 0.14, "bottom": 0.18, "height": 0.9, "sides": 6})
		wyrm.append({"shape": "cylinder", "at": [side * 0.6, 0.4, -1.3], "rot": [0, 0, side * 15.0], "material": "body", "top": 0.14, "bottom": 0.18, "height": 0.8, "sides": 6})
	wyrm.append({"shape": "cone", "at": [0, 0.5, -2.7], "rot": [-100, 0, 0], "scale": [0.2, 0.9, 0.2], "material": "body", "motion": "swing", "radius": 1.0, "height": 1.0, "sides": 6})
	return {
		"SALAMANDER": {"style": "low", "sway": 2.2, "tint": "e8622a", "accent": "ffd06a", "anchor": 1.1, "shadow": 2.8, "ring": 1.3, "parts": salamander},
		"SLAG_HOUND": {"style": "low", "sway": 2.4, "tint": "3a2a26", "accent": "ff7a2a", "anchor": 1.6, "shadow": 2.6, "ring": 1.2, "parts": hound},
		"FORGE_IMP": {"style": "low", "sway": 3.2, "tint": "c83a2a", "accent": "ffb03a", "anchor": 2.1, "shadow": 1.4, "ring": 0.8, "parts": imp},
		"EMBER_CRAWLER": {"style": "long", "sway": 1.6, "tint": "5a2a1a", "accent": "ff8a2a", "anchor": 0.9, "shadow": 3.2, "ring": 1.5, "parts": crawler},
		"THE_SMELTER": {"style": "tower", "sway": 0.6, "tint": "4a3a36", "accent": "ff8a2a", "anchor": 3.2, "warden": true, "shadow": 3.6, "ring": 1.7, "parts": smelter},
		"THE_ANVIL_KNIGHT": {"style": "tower", "sway": 0.5, "tint": "6a6e78", "accent": "ff5a3a", "anchor": 3.7, "warden": true, "shadow": 3.4, "ring": 1.7, "parts": knight},
		"THE_KILN_WYRM": {"style": "long", "sway": 0.7, "tint": "c8401a", "accent": "ffd06a", "anchor": 3.6, "warden": true, "shadow": 4.2, "ring": 2.0, "parts": wyrm}}
