extends RefCounted
## Recipes for tools/creature_bake.gd: the Rift. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var echo: Array = [{"shape": "sphere", "at": [0, 1.0, 0], "scale": 0.25, "material": "core", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0
		echo.append({"shape": "shard", "at": [cos(a) * 0.6, 0.9 + sin(a * 1.5) * 0.3, sin(a) * 0.6], "rot": [20, rad_to_deg(a), 30], "scale": 1.8, "material": "body", "motion": "orbit", "phase": a, "size": 0.14})
	var shade: Array = [
		{"shape": "capsule", "at": [0, 1.15, 0], "scale": [0.3, 0.6, 0.22], "material": "body", "motion": "bob", "radius": 1.0, "height": 2.0, "segments": 7},
		{"shape": "sphere", "at": [0, 2.0, 0], "scale": [0.2, 0.25, 0.2], "material": "body", "motion": "bob", "phase": 0.4, "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "capsule", "at": [0.42, 1.2, 0], "rot": [0, 0, -12], "scale": [0.08, 0.55, 0.08], "material": "body", "motion": "swing", "phase": 0.3, "radius": 1.0, "height": 2.0, "segments": 5},
		{"shape": "capsule", "at": [-0.42, 1.2, 0], "rot": [0, 0, 12], "scale": [0.08, 0.55, 0.08], "material": "body", "motion": "swing", "phase": 1.6, "radius": 1.0, "height": 2.0, "segments": 5},
		{"shape": "cone", "at": [0, 0.35, 0], "rot": [180, 0, 0], "material": "body", "motion": "core", "radius": 0.3, "height": 0.7, "sides": 7},
		{"shape": "ring", "at": [0, 0.08, 0], "material": "accent", "motion": "spin", "radius": 0.45, "width": 0.07, "segments": 24},
		{"shape": "ring", "at": [0, 0.14, 0], "material": "accent", "motion": "spin", "phase": 1.0, "radius": 0.7, "width": 0.06, "segments": 28},
		{"shape": "ring", "at": [0, 0.2, 0], "material": "accent", "motion": "spin", "phase": 2.0, "radius": 0.95, "width": 0.05, "segments": 32}]
	var swarm: Array = [{"shape": "sphere", "at": [0, 1.0, 0], "scale": 0.16, "material": "core", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3}]
	for i in range(16):
		var a: float = float(i) * TAU / 16.0 * 3.0
		var r: float = 0.4 + 0.5 * float(i % 3) / 2.0
		swarm.append({"shape": "shard", "at": [cos(a) * r, 0.45 + float(i % 5) * 0.3, sin(a) * r], "rot": [float(i) * 37.0, float(i) * 61.0, 20], "scale": 1.3 + 0.5 * float(i % 2), "material": "accent" if i % 3 == 0 else "body", "motion": "orbit", "phase": a + float(i) * 0.3, "size": 0.12})
	var eye: Array = [
		{"shape": "sphere", "at": [0, 1.3, 0], "scale": 0.55, "material": "body", "motion": "bob", "radius": 1.0, "segments": 10, "rings": 6},
		{"shape": "sphere", "at": [0, 1.3, 0.42], "scale": 0.26, "material": "accent", "motion": "core", "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "sphere", "at": [0, 1.3, 0.62], "scale": 0.1, "material": "core", "radius": 1.0, "segments": 6, "rings": 3}]
	for i in range(8):
		var a: float = float(i) * TAU / 8.0
		eye.append({"shape": "crystal", "at": [cos(a) * 1.0, 1.3 + sin(a) * 1.0, 0], "rot": [0, 0, rad_to_deg(a) + 90.0], "material": "body", "motion": "orbit", "phase": a, "radius": 0.07, "height": 0.45})
	var unmade: Array = [
		{"shape": "slab", "at": [0, 2.1, 0], "material": "body", "motion": "block", "size": [1.4, 1.6, 0.8], "jitter": 0.04},
		{"shape": "column", "at": [0.4, 0.0, 0], "material": "body", "sides": 5, "radius": 0.3, "height": 1.4},
		{"shape": "column", "at": [-0.4, 0.0, 0], "material": "body", "sides": 5, "radius": 0.3, "height": 1.4},
		{"shape": "rock", "at": [0, 3.3, 0], "scale": [0.5, 0.55, 0.5], "material": "body", "motion": "bob", "jitter": 0.1, "seed": 181},
		{"shape": "column", "at": [1.05, 1.0, 0.1], "rot": [0, 0, -10], "material": "body", "sides": 5, "radius": 0.22, "height": 1.8},
		{"shape": "column", "at": [-1.05, 1.0, 0.1], "rot": [0, 0, 10], "material": "body", "sides": 5, "radius": 0.22, "height": 1.8},
		{"shape": "sphere", "at": [0, 2.2, 0.35], "scale": 0.22, "material": "core", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4}]
	var stars: Array = [[0.3, 2.6, 0.42], [-0.45, 2.3, 0.42], [0.1, 1.7, 0.42], [-0.2, 2.75, 0.42], [0.5, 1.95, 0.42], [-0.1, 3.35, 0.27], [0.25, 3.2, 0.3], [-0.55, 1.6, 0.42], [0.95, 1.3, 0.34], [-1.0, 0.7, 0.34]]
	for i in range(stars.size()):
		unmade.append({"shape": "sphere", "at": stars[i], "scale": 0.045 + 0.02 * float(i % 3), "material": "accent", "motion": "core", "phase": float(i) * 0.8, "radius": 1.0, "segments": 5, "rings": 3})
	return {
		"VOID_ECHO": {"style": "shards", "sway": 1.5, "tint": "4a3a8a", "accent": "c8b8ff", "anchor": 1.8, "shadow": 1.8, "parts": echo},
		"NULL_SHADE": {"style": "wings", "sway": 1.0, "tint": "1a1630", "accent": "8b7dff", "anchor": 2.5, "shadow": 2.2, "ring": 1.1, "parts": shade},
		"RIFTLING_SWARM": {"style": "shards", "sway": 2.4, "tint": "5a4ab0", "accent": "ff8ad8", "anchor": 2.1, "shadow": 2.4, "ring": 1.2, "parts": swarm},
		"ENTROPY_EYE": {"style": "shards", "sway": 1.1, "tint": "2a2048", "accent": "ff5ad8", "anchor": 2.6, "shadow": 2.4, "ring": 1.2, "parts": eye},
		"THE_UNMADE": {"style": "tower", "sway": 0.4, "tint": "0a0818", "accent": "ffffff", "anchor": 4.0, "warden": true, "shadow": 3.6, "ring": 1.8, "parts": unmade}}
