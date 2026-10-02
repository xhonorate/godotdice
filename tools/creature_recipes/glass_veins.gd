extends RefCounted
## Recipes for tools/creature_bake.gd: the Glass Veins. See tools/creature_bake.gd for the format.

static func recipes() -> Dictionary:
	var sprite: Array = [
		{"shape": "crystal", "at": [0, 0.75, 0], "rot": [180, 0, 0], "material": "body", "motion": "bob", "radius": 0.12, "height": 0.55},
		{"shape": "sphere", "at": [0, 1.0, 0], "scale": 0.13, "material": "accent", "motion": "core", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "crystal", "at": [0, 1.05, 0], "material": "body", "motion": "bob", "phase": 0.5, "radius": 0.09, "height": 0.4}]
	for side in [-1.0, 1.0]:
		for w in range(2):
			sprite.append({"shape": "prism", "at": [side * 0.12, 1.0 + float(w) * 0.08, -0.05 + float(w) * 0.12], "rot": [0, 0, side * (25.0 + float(w) * 20.0)], "material": "body", "motion": "wing", "side": side, "phase": float(w) * 0.8, "offset": [side * 0.3, 0.0, 0.0], "size": [0.6, 0.35 - float(w) * 0.1, 0.03]})
	var beetle: Array = [
		{"shape": "rock", "at": [0, 0.38, 0], "scale": [0.55, 0.3, 0.75], "material": "body", "motion": "core", "jitter": 0.1, "seed": 41},
		{"shape": "sphere", "at": [0, 0.6, -0.05], "scale": [0.42, 0.34, 0.5], "material": "accent", "motion": "core", "phase": 0.7, "radius": 1.0, "segments": 10, "rings": 5},
		{"shape": "sphere", "at": [0, 0.35, 0.78], "scale": 0.2, "material": "body", "motion": "bob", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "sphere", "at": [0.12, 0.42, 0.92], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.12, 0.42, 0.92], "scale": 0.05, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3}]
	for side in [-1.0, 1.0]:
		for leg in range(3):
			beetle.append({"shape": "cylinder", "at": [side * 0.5, 0.2, 0.4 - float(leg) * 0.4], "rot": [0, 0, side * 60.0], "material": "body", "motion": "swing", "phase": float(leg) * 1.2 + (0.0 if side > 0 else 1.5), "top": 0.03, "bottom": 0.035, "height": 0.5, "sides": 4})
	var refractor: Array = [
		{"shape": "crystal", "at": [0, 0.7, 0], "material": "body", "motion": "spin", "radius": 0.32, "height": 1.3},
		{"shape": "crystal", "at": [0, 0.7, 0], "rot": [180, 0, 0], "material": "body", "motion": "spin", "radius": 0.32, "height": 0.6},
		{"shape": "sphere", "at": [0, 1.15, 0], "scale": 0.2, "material": "core", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4}]
	for i in range(5):
		var a: float = float(i) * TAU / 5.0
		refractor.append({"shape": "shard", "at": [cos(a) * 0.85, 0.9 + sin(a * 2.0) * 0.25, sin(a) * 0.85], "rot": [20, rad_to_deg(a), 30], "scale": 1.6, "material": "accent", "motion": "orbit", "phase": a, "size": 0.14})
	var glazier: Array = [
		{"shape": "slab", "at": [0, 1.75, 0], "material": "body", "motion": "block", "size": [0.55, 1.1, 0.3], "jitter": 0.03},
		{"shape": "cylinder", "at": [0.14, 0.6, 0], "material": "body", "top": 0.07, "bottom": 0.09, "height": 1.2, "sides": 5},
		{"shape": "cylinder", "at": [-0.14, 0.6, 0], "material": "body", "top": 0.07, "bottom": 0.09, "height": 1.2, "sides": 5},
		{"shape": "sphere", "at": [0, 2.55, 0.02], "scale": [0.2, 0.26, 0.2], "material": "body", "motion": "bob", "radius": 1.0, "segments": 7, "rings": 4},
		{"shape": "sphere", "at": [0.09, 2.6, 0.2], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "sphere", "at": [-0.09, 2.6, 0.2], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
		{"shape": "box", "at": [0, 2.6, 0.17], "material": "core", "size": [0.3, 0.06, 0.06]},
		{"shape": "cylinder", "at": [0.5, 1.9, 0.15], "rot": [0, 0, -20], "material": "body", "top": 0.05, "bottom": 0.06, "height": 1.3, "sides": 5},
		{"shape": "cylinder", "at": [-0.5, 1.6, 0.35], "rot": [-40, 0, 25], "material": "body", "top": 0.05, "bottom": 0.06, "height": 1.3, "sides": 5},
		{"shape": "cylinder", "at": [-0.75, 1.3, 0.9], "rot": [0, 0, 90], "material": "body", "motion": "spin", "top": 0.5, "bottom": 0.5, "height": 0.06, "sides": 12},
		{"shape": "ring", "at": [-0.75, 1.3, 0.9], "rot": [0, 0, 90], "material": "accent", "motion": "spin", "radius": 0.55, "width": 0.08, "segments": 12},
		{"shape": "crystal", "at": [0.5, 2.6, 0.1], "material": "accent", "motion": "crystal", "radius": 0.06, "height": 0.4},
		{"shape": "crystal", "at": [0.25, 2.3, -0.2], "rot": [0, 0, -30], "material": "accent", "motion": "crystal", "radius": 0.05, "height": 0.3}]
	var kaleido: Array = [
		{"shape": "sphere", "at": [0, 1.6, 0], "scale": 0.55, "material": "body", "motion": "core", "radius": 1.0, "segments": 10, "rings": 5},
		{"shape": "sphere", "at": [0, 1.6, 0.42], "scale": 0.3, "material": "accent", "motion": "core", "phase": 0.5, "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "sphere", "at": [0, 1.6, 0.62], "scale": 0.13, "material": "core", "radius": 1.0, "segments": 6, "rings": 3}]
	for i in range(6):
		var a: float = float(i) * TAU / 6.0
		kaleido.append({"shape": "prism", "at": [cos(a) * 1.35, 1.6 + sin(a) * 1.35, 0.1], "rot": [0, 0, rad_to_deg(a) - 90.0], "material": "body", "motion": "orbit", "phase": a, "mesh_rot": [0, 0, 0], "size": [0.75, 0.9, 0.06]})
		kaleido.append({"shape": "sphere", "at": [cos(a) * 1.35, 1.6 + sin(a) * 1.35, 0.16], "scale": 0.09, "material": "accent", "motion": "orbit", "phase": a, "radius": 1.0, "segments": 5, "rings": 3})
	var prismarch: Array = [
		{"shape": "slab", "at": [0, 1.9, 0], "material": "body", "motion": "block", "size": [1.3, 1.3, 0.8], "jitter": 0.05},
		{"shape": "column", "at": [0.4, 0.0, 0], "material": "body", "sides": 6, "radius": 0.26, "height": 1.3},
		{"shape": "column", "at": [-0.4, 0.0, 0], "material": "body", "sides": 6, "radius": 0.26, "height": 1.3},
		{"shape": "sphere", "at": [0, 1.9, 0.42], "scale": 0.3, "material": "core", "motion": "core", "radius": 1.0, "segments": 8, "rings": 4},
		{"shape": "rock", "at": [0, 2.85, 0], "scale": [0.45, 0.4, 0.42], "material": "body", "motion": "bob", "jitter": 0.1, "seed": 51},
		{"shape": "sphere", "at": [0.14, 2.9, 0.4], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "sphere", "at": [-0.14, 2.9, 0.4], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 5, "rings": 3},
		{"shape": "column", "at": [0.95, 1.1, 0.1], "rot": [0, 0, -12], "material": "body", "sides": 6, "radius": 0.2, "height": 1.5},
		{"shape": "column", "at": [-0.95, 1.1, 0.1], "rot": [0, 0, 12], "material": "body", "sides": 6, "radius": 0.2, "height": 1.5}]
	for i in range(7):
		var a: float = float(i) * TAU / 7.0
		prismarch.append({"shape": "crystal", "at": [cos(a) * 0.35, 3.15, sin(a) * 0.35], "rot": [cos(a) * 25.0, 0, -sin(a) * 25.0], "material": "accent", "motion": "crystal", "phase": a, "radius": 0.07, "height": 0.55 + 0.15 * float(i % 2)})
	for i in range(3):
		var a: float = float(i) * TAU / 3.0
		prismarch.append({"shape": "crystal", "at": [cos(a) * 1.5, 2.0 + sin(a) * 0.3, sin(a) * 1.5], "rot": [15, 0, 15], "material": "core", "motion": "orbit", "phase": a, "radius": 0.12, "height": 0.6})
	var prism: Array = [
		{"shape": "crystal", "at": [0, 0.45, 0], "material": "body", "motion": "spin", "radius": 0.16, "height": 0.7},
		{"shape": "crystal", "at": [0, 0.45, 0], "rot": [180, 0, 0], "material": "body", "motion": "spin", "radius": 0.16, "height": 0.3},
		{"shape": "sphere", "at": [0, 0.8, 0], "scale": 0.1, "material": "accent", "motion": "bob", "radius": 1.0, "segments": 6, "rings": 3}]
	return {
		"ECHO_SPRITE": {"style": "wings", "sway": 3.6, "tint": "d8c8ff", "accent": "ffffff", "anchor": 1.7, "shadow": 1.4, "ring": 0.8, "parts": sprite},
		"LENS_BEETLE": {"style": "low", "sway": 2.0, "tint": "6a4ab0", "accent": "fff2a8", "anchor": 1.3, "shadow": 2.0, "parts": beetle},
		"REFRACTOR": {"style": "shards", "sway": 1.4, "tint": "e08ad8", "accent": "8affd8", "anchor": 1.9, "shadow": 2.2, "parts": refractor},
		"THE_GLAZIER": {"style": "tower", "sway": 0.8, "tint": "c8b8ff", "accent": "ffffff", "anchor": 3.3, "warden": true, "shadow": 3.0, "ring": 1.5, "parts": glazier},
		"THE_KALEIDOSCOPE": {"style": "shards", "sway": 0.9, "tint": "9b8cff", "accent": "ff8ae0", "anchor": 3.5, "warden": true, "shadow": 3.4, "ring": 1.6, "parts": kaleido},
		"THE_PRISMARCH": {"style": "tower", "sway": 0.5, "tint": "7a6ad8", "accent": "ffe08a", "anchor": 3.9, "warden": true, "shadow": 3.8, "ring": 1.8, "parts": prismarch},
		"PRISM": {"style": "shards", "sway": 2.6, "tint": "c8b8ff", "accent": "ffffff", "anchor": 1.2, "shadow": 1.2, "ring": 0.6, "parts": prism}}
