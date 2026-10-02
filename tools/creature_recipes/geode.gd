extends RefCounted
## Recipes for tools/creature_bake.gd: the Geode. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var mimic: Array = [
		{"shape": "slab", "at": [0, 0.45, 0], "material": "body", "motion": "core", "size": [1.1, 0.6, 0.75], "jitter": 0.03},
		{"shape": "slab", "at": [0, 0.95, -0.3], "rot": [-35, 0, 0], "material": "body", "motion": "swing", "size": [1.12, 0.14, 0.75], "jitter": 0.03},
		{"shape": "sphere", "at": [0, 0.8, 0.05], "scale": [0.4, 0.18, 0.3], "material": "core", "motion": "core", "phase": 0.6, "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "box", "at": [0, 0.45, 0.39], "material": "accent", "size": [0.12, 0.3, 0.02]},
		{"shape": "cylinder", "at": [0.2, 0.08, 0.3], "material": "body", "top": 0.08, "bottom": 0.1, "height": 0.16, "sides": 5},
		{"shape": "cylinder", "at": [-0.2, 0.08, 0.3], "material": "body", "top": 0.08, "bottom": 0.1, "height": 0.16, "sides": 5}]
	for k in range(6):
		var x: float = -0.4 + float(k) * 0.16
		mimic.append({"shape": "cone", "at": [x, 0.78, 0.3], "rot": [180, 0, 0], "scale": [0.05, 0.16, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
		mimic.append({"shape": "cone", "at": [x + 0.08, 0.76, 0.33], "scale": [0.05, 0.14, 0.05], "material": "accent", "radius": 1.0, "height": 1.0, "sides": 4})
	for k in range(5):
		mimic.append({"shape": "cylinder", "at": [-0.5 + float(k) * 0.25, 0.04, 0.55 + 0.1 * float(k % 2)], "rot": [10, float(k) * 30.0, 0], "material": "accent", "top": 0.08, "bottom": 0.08, "height": 0.03, "sides": 8})
	var crab: Array = [
		{"shape": "rock", "at": [0, 0.35, 0], "scale": [0.75, 0.25, 0.55], "material": "body", "motion": "core", "jitter": 0.1, "seed": 141},
		{"shape": "slab", "at": [0.55, 0.32, 0.5], "rot": [0, -25, 0], "material": "body", "motion": "swing", "phase": 0.2, "size": [0.3, 0.2, 0.45], "jitter": 0.05},
		{"shape": "slab", "at": [-0.55, 0.32, 0.5], "rot": [0, 25, 0], "material": "body", "motion": "swing", "phase": 1.8, "size": [0.3, 0.2, 0.45], "jitter": 0.05},
		{"shape": "cylinder", "at": [0.12, 0.58, 0.45], "rot": [-20, 0, 0], "material": "body", "top": 0.02, "bottom": 0.025, "height": 0.3, "sides": 4},
		{"shape": "cylinder", "at": [-0.12, 0.58, 0.45], "rot": [-20, 0, 0], "material": "body", "top": 0.02, "bottom": 0.025, "height": 0.3, "sides": 4},
		{"shape": "sphere", "at": [0.12, 0.74, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.12, 0.74, 0.5], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	for k in range(7):
		var a: float = float(k) * 0.9
		crab.append({"shape": "cylinder", "at": [cos(a) * 0.38, 0.6, sin(a) * 0.25 - 0.05], "rot": [sin(a) * 15.0, 0, -cos(a) * 15.0], "material": "accent", "motion": "core", "phase": a, "top": 0.1, "bottom": 0.1, "height": 0.035, "sides": 8})
	for side in [-1.0, 1.0]:
		for leg in range(3):
			crab.append({"shape": "cylinder", "at": [side * 0.7, 0.2, 0.2 - float(leg) * 0.25], "rot": [0, 0, side * 60.0], "material": "body", "motion": "swing", "phase": float(leg) + (0.0 if side > 0 else 1.5), "top": 0.03, "bottom": 0.035, "height": 0.45, "sides": 4})
	var hydra: Array = [
		{"shape": "rock", "at": [0, 0.6, -0.2], "scale": [0.6, 0.5, 0.65], "material": "body", "motion": "core", "jitter": 0.16, "seed": 151},
		{"shape": "cone", "at": [0, 0.5, -1.0], "rot": [-110, 0, 0], "scale": [0.14, 0.6, 0.14], "material": "body", "motion": "swing", "radius": 1.0, "height": 1.0, "sides": 5}]
	for i in range(3):
		var x: float = [-0.45, 0.0, 0.45][i]
		var h: float = [1.4, 1.75, 1.5][i]
		var lean: float = [25.0, 5.0, -20.0][i]
		hydra.append({"shape": "capsule", "at": [x * 0.6, (h + 0.8) * 0.5, 0.2], "rot": [-20, 0, -lean], "scale": [0.11, (h - 0.8) * 0.55, 0.11], "material": "body", "motion": "swing", "phase": float(i) * 1.3, "radius": 1.0, "height": 2.0, "segments": 6})
		hydra.append({"shape": "rock", "at": [x, h, 0.5], "scale": [0.2, 0.17, 0.26], "material": "body", "motion": "bob", "phase": float(i) * 1.3, "jitter": 0.12, "seed": 160 + i})
		hydra.append({"shape": "sphere", "at": [x + 0.08, h + 0.05, 0.72], "scale": 0.045, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
		hydra.append({"shape": "sphere", "at": [x - 0.08, h + 0.05, 0.72], "scale": 0.045, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3})
		hydra.append({"shape": "crystal", "at": [x, h + 0.15, 0.4], "rot": [-20, 0, 0], "material": "accent", "motion": "crystal", "phase": float(i), "radius": 0.04, "height": 0.25})
	for side in [-1.0, 1.0]:
		hydra.append({"shape": "cylinder", "at": [side * 0.45, 0.2, 0.15], "rot": [0, 0, side * 20.0], "material": "body", "top": 0.08, "bottom": 0.1, "height": 0.45, "sides": 5})
		hydra.append({"shape": "cylinder", "at": [side * 0.45, 0.2, -0.55], "rot": [0, 0, side * 20.0], "material": "body", "top": 0.08, "bottom": 0.1, "height": 0.45, "sides": 5})
	var assayer: Array = [
		{"shape": "cone", "at": [0, 1.15, 0], "material": "body", "motion": "core", "radius": 0.62, "height": 2.3, "sides": 8},
		{"shape": "sphere", "at": [0, 2.45, 0.05], "scale": 0.28, "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "cone", "at": [0, 2.65, -0.05], "rot": [20, 0, 0], "material": "body", "radius": 0.36, "height": 0.6, "sides": 7},
		{"shape": "sphere", "at": [0.1, 2.45, 0.3], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.1, 2.45, 0.3], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "cylinder", "at": [0.55, 1.7, 0.5], "rot": [0, 0, -50], "material": "body", "top": 0.08, "bottom": 0.09, "height": 0.9, "sides": 5},
		{"shape": "cylinder", "at": [0.95, 2.1, 0.75], "material": "accent", "motion": "swing", "phase": 0.3, "top": 0.03, "bottom": 0.03, "height": 0.6, "sides": 4},
		{"shape": "box", "at": [0.95, 2.4, 0.75], "material": "accent", "motion": "swing", "phase": 0.3, "size": [1.3, 0.05, 0.05]},
		{"shape": "cylinder", "at": [0.4, 2.0, 0.75], "material": "accent", "motion": "swing", "phase": 0.3, "top": 0.02, "bottom": 0.02, "height": 0.7, "sides": 3},
		{"shape": "cylinder", "at": [1.5, 1.9, 0.75], "material": "accent", "motion": "swing", "phase": 0.3, "top": 0.02, "bottom": 0.02, "height": 0.9, "sides": 3},
		{"shape": "cylinder", "at": [0.4, 1.62, 0.75], "material": "core", "motion": "swing", "phase": 0.3, "top": 0.22, "bottom": 0.18, "height": 0.08, "sides": 8},
		{"shape": "cylinder", "at": [1.5, 1.42, 0.75], "material": "core", "motion": "swing", "phase": 0.3, "top": 0.22, "bottom": 0.18, "height": 0.08, "sides": 8},
		{"shape": "crystal", "at": [1.5, 1.5, 0.75], "material": "accent", "motion": "swing", "phase": 0.3, "radius": 0.06, "height": 0.25}]
	var collector: Array = [
		{"shape": "slab", "at": [0, 1.9, 0.1], "material": "body", "motion": "block", "size": [0.6, 1.3, 0.35], "jitter": 0.03},
		{"shape": "cylinder", "at": [0.16, 0.65, 0.1], "material": "body", "top": 0.08, "bottom": 0.1, "height": 1.3, "sides": 5},
		{"shape": "cylinder", "at": [-0.16, 0.65, 0.1], "material": "body", "top": 0.08, "bottom": 0.1, "height": 1.3, "sides": 5},
		{"shape": "sphere", "at": [0, 2.75, 0.15], "scale": [0.22, 0.28, 0.22], "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.08, 2.8, 0.35], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.08, 2.8, 0.35], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "cylinder", "at": [0.5, 1.7, 0.3], "rot": [0, 0, -15], "material": "body", "top": 0.06, "bottom": 0.07, "height": 1.4, "sides": 5},
		{"shape": "cylinder", "at": [-0.5, 1.7, 0.3], "rot": [0, 0, 15], "material": "body", "top": 0.06, "bottom": 0.07, "height": 1.4, "sides": 5}]
	for i in range(4):
		var y: float = 0.95 + float(i) * 0.62
		var x: float = 0.25 if i % 2 == 0 else -0.25
		collector.append({"shape": "box", "at": [x, y, -0.45], "material": "core", "motion": "block", "phase": float(i) * 0.7, "size": [0.55, 0.55, 0.45]})
		collector.append({"shape": "crystal", "at": [x, y - 0.2, -0.45], "material": "accent", "motion": "crystal", "phase": float(i), "radius": 0.08, "height": 0.35})
	var crown: Array = [
		{"shape": "rock", "at": [0, 1.45, 0], "scale": [1.5, 1.4, 1.4], "material": "body", "motion": "core", "jitter": 0.12, "seed": 171},
		{"shape": "sphere", "at": [0, 1.4, 0.9], "scale": [0.75, 0.9, 0.55], "material": "core", "motion": "core", "phase": 0.5, "radius": 1.0, "segments": 8, "rings": 5}]
	for k in range(9):
		var a: float = -1.1 + float(k) * 0.275
		crown.append({"shape": "crystal", "at": [sin(a) * 0.75, 1.4 + cos(a) * 0.95, 1.1], "rot": [-70 + cos(a) * 10.0, 0, -sin(a) * 50.0], "material": "accent", "motion": "crystal", "phase": float(k) * 0.5, "radius": 0.07, "height": 0.4 + 0.1 * float(k % 2)})
	for i in range(8):
		var a: float = float(i) * TAU / 8.0
		crown.append({"shape": "crystal", "at": [cos(a) * 0.9, 2.75, sin(a) * 0.9], "rot": [cos(a) * 18.0, 0, -sin(a) * 18.0], "material": "accent", "motion": "crystal", "phase": a, "radius": 0.12, "height": 0.75 + 0.25 * float(i % 2)})
	crown.append({"shape": "torus", "at": [0, 2.72, 0], "material": "accent", "inner": 0.82, "outer": 0.98, "rings": 12, "segments": 6})
	return {
		"HOARD_MIMIC": {"style": "low", "sway": 1.4, "tint": "8a5a2a", "accent": "ffd76a", "anchor": 1.4, "shadow": 2.0, "parts": mimic},
		"CROUPIER_CRAB": {"style": "low", "sway": 2.0, "tint": "d8a83a", "accent": "ffffff", "anchor": 1.1, "shadow": 2.4, "ring": 1.2, "parts": crab},
		"CRYSTAL_HYDRA": {"style": "stack", "sway": 1.2, "tint": "8a5ad8", "accent": "ffd76a", "anchor": 2.2, "shadow": 2.4, "ring": 1.2, "parts": hydra},
		"THE_ASSAYER": {"style": "tower", "sway": 0.7, "tint": "b08a3a", "accent": "fff0b0", "anchor": 3.2, "warden": true, "shadow": 3.0, "ring": 1.5, "parts": assayer},
		"THE_COLLECTOR": {"style": "tower", "sway": 0.7, "tint": "6a3a8a", "accent": "ffd76a", "anchor": 3.4, "warden": true, "shadow": 2.8, "ring": 1.4, "parts": collector},
		"THE_HOLLOW_CROWN": {"style": "blob", "sway": 0.5, "tint": "5a3a7a", "accent": "ffd76a", "anchor": 3.9, "warden": true, "shadow": 4.0, "ring": 1.9, "parts": crown}}
